#
# $Header: svn://svn/SWM/trunk/web/PaymentSplitValueCheck.pm 10054 2013-12-01 22:38:53Z tcourt $
#

package PaymentSplitValueCheck;

require Exporter   ;
@ISA       = qw(Exporter);
@EXPORT    = qw(checkPaymentSplitValue );
@EXPORT_OK = qw(checkPaymentSplitValue );

use strict;
use CGI qw(unescape Vars param);
use lib '.', '..';
use Defs;
use List;
use PaymentSplitFeesObj;
use PaymentApplication;


sub checkPaymentSplitValue {
    my ($Data, $client, $splitID, $splitName) = @_;

    my $splitItems = getSplitItems();
    my $prods      = getProducts($Data, $splitID);

    my $errCnt     = 0;
    my $rows       = '';
    my $numlist    = '';
    my $headings   = '';
    my $body       = '';
    my $header     = '';
		my $entityID = $Data->{'clientValues'}{'assocID'} || 0;
		my $entityTypeID = $Defs::LEVEL_ASSOC;
		if ($Data->{'clientValues'}{'clubID'} and $Data->{'clientValues'}{'clubID'} != $Defs::INVALID_ID) {
			$entityID = $Data->{'clientValues'}{'clubID'} || 0;
			$entityTypeID = $Defs::LEVEL_CLUB;
		}
		my $feeType= getFeeTypeDefault($Data, $entityTypeID, $entityID);

    for my $prod(@{$prods}) {

        my $productPrice = $prod->{'price'};
        my $splitValue   = 0;
        my $itemsValue   = 0;

        # accum fees
        my ($feesAmount, $feesFactor) = PaymentSplitFeesObj->getTotalFees($Data->{'Realm'}, $Data->{'RealmSubType'}, $Data->{'db'});
        my $feesValue = $feesAmount + $productPrice * $feesFactor;

        # accum split value (for split items)
        for my $splitItem(@{$splitItems}) {
            my $amount = $splitItem->{'amount'};
            my $factor = $splitItem->{'factor'};
            $itemsValue += ($amount)
                ? $amount
                : $productPrice * $factor;
        }

        $splitValue = $feesValue + $itemsValue;
        $splitValue = sprintf("%.2f", $splitValue); # do the rounding before comparing

        if ($splitValue > $productPrice and $feeType !=2) {
            $errCnt++;
            $prod->{'itemsValue'} = sprintf("%.2f", $itemsValue);
            $prod->{'feesValue'}  = sprintf("%.2f", $feesValue);
            $prod->{'splitValue'} = $splitValue;
            $rows .= List::list_row($prod, [qw(name price feesValue itemsValue splitValue)], [], ($errCnt)%2 == 0);
        }
    }

    if ($errCnt) {
        $headings  = List::list_headers(['Product name', 'Product price', 'Fees value', 'Items value', 'Split value']) || '';
        $numlist   = ($errCnt and $errCnt > 1) ? qq[<div class="tablecount">$errCnt rows found</div>] : '';

        $body = qq[ 
            <div class="warningmsg">Unable to update this Payment Split because the calculated value exceeds the pricing structure for the product(s) listed below.</div><br>
	 	    <a href="$Data->{'target'}?client=$client&amp;splitID=$splitID&amp;splitName=$splitName;a=A_PS_editsplit">Return to editing $splitName</a><br><br>
            <table class="listTable">
                $headings
                $rows
            </table>$numlist
        ];

        $header = "Update Payment Split - $splitName";
    }
    return ($body, $header);
}


sub getSplitItems {

    my $remainder_split  = $Defs::PS_MAX_SPLITS + 1;

    my $percentage = 0;
    my $factor     = 0;
    my $amount     = 0.00;
    my @items      = ();

    for my $splitNo (1 .. $remainder_split) {
        my $rbMethod = param("rbMethod$splitNo") || '';
        my $byAmount = ($rbMethod eq 'amount');

        if ($splitNo < $remainder_split) {
            if ($rbMethod) {
                if ($byAmount) {
                    $amount     = param("txtAmount$splitNo") * 1 || 0;
                    $percentage = 0;
                }
                else {
                    $amount     = 0;
                    $percentage = param("txtPercentage$splitNo") || '';
                    $factor = ($percentage) ? $percentage / 100 : 0;
                }
                if ($amount or $factor) {
                    push @items, {
                        'amount' => $amount, 
                        'factor' => $factor};
                }
            }
        }
    }
    return \@items;
}


sub getProducts {
    my ($Data, $splitID) = @_;
    
    my $sql = qq[
        SELECT intProductID, strName
        FROM tblProducts
        WHERE intPaymentSplitID=$splitID
        ORDER BY intProductID
    ];

    my $query = $Data->{'db'}->prepare($sql);

    $query->execute();

    my @prods = ();

    while (my ($intProductID, $strName) = $query->fetchrow_array()) {
        my $productPrice = getProductPrice($Data, $intProductID);
        push @prods, {
            'productID'  => $intProductID, 
            'name'       => $strName, 
            'price'      => $productPrice,
            'itemsValue' => 0,    # inserted for use in main sub
            'feesValue'  => 0,    # ditto
            'splitValue' => 0,    # ditto
            'error'      => 0};
    }
 
    $query->finish;

    return \@prods;
}


sub getProductPrice {
    my($Data, $productID) = @_;
    
    my $currentLevel = $Data->{'clientValues'}{'currentLevel'};

    my $sql = qq[
        (SELECT intLevel, curAmount 
        FROM tblProductPricing 
        WHERE intProductID=$productID AND intLevel>=$currentLevel)

        UNION ALL
        (SELECT $Defs::LEVEL_NATIONAL, curDefaultAmount 
        FROM tblProducts 
        WHERE intProductID=$productID)

        UNION ALL (SELECT $Defs::LEVEL_NATIONAL, 0.00) 
        ORDER BY intLevel
        LIMIT 1;
    ]; # the last union just ensures that something comes back

    my $query = $Data->{'db'}->prepare($sql);

    $query->execute();

    my ($intLevel, $price) = $query->fetchrow_array();

    return $price;
}

1;
