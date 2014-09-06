package RegoProducts;
require Exporter;
@ISA =  qw(Exporter);

@EXPORT = qw(getRegoProducts checkAllowedProductCount checkMandatoryProducts insertRegoTransaction);
@EXPORT_OK = qw(getRegoProducts checkAllowedProductCount checkMandatoryProducts insertRegoTransaction);

use strict;
use lib "..","../..";
use Products;
use Reg_common;
use AssocTime;
use TTTemplate;
use HTML::Entities;
use Utils;
use Date::Calc qw(Today Delta_YMD);

sub getRegoProducts {
    my (
        $Data,
        $products,
        $incExisting,
        $entityID,
        $regoID,
        $personID,
        $memdetails,
        $multipersonType,
        $regItemRules_ref
    ) = @_;

    my $currencySymbol = $Data->{'LocalConfig'}{'DollarSymbol'} || "\$";
    $incExisting ||= 0; ## Set to 1 to include existing in-cart items that aren't paid for the member

    $multipersonType ||= ''; 
    my $cl  = setClient($Data->{'clientValues'});

    my $regoProducts = getAllRegoProducts($Data, $entityID, $regoID, $personID, $incExisting, $products);

    my $productAttributes = Products::getFormProductAttributes($Data, 0) || {};

    my $i            = 0;
    my $count        = 0;
    my $anyAllowQty  = 0;
    my @unpaid_items = ();

    my $timeLocally = timeLocally($Data, '');

    my %product_seen;

    my @sorted = ();
    my $filter_params = {};

    @sorted = sort {
        lc($regoProducts->{$a}{'strGroup'})    cmp lc($regoProducts->{$b}{'strGroup'})    ||
        lc($regoProducts->{$a}{'intSequence'}) <=> lc($regoProducts->{$b}{'intSequence'}) ||
        lc($regoProducts->{$a}{'strName'})     cmp lc($regoProducts->{$b}{'strName'})     ||
        lc($regoProducts->{$a}{'intLevel'})    <=> lc($regoProducts->{$b}{'intLevel'})
    } keys %$regoProducts;

    foreach my $key (@sorted) {
        ## Filter here based on intUseExistingThisEntity, intUseExistingAnyEntity
        my $dref = $regoProducts->{$key};
        $dref->{strProductNotes}=~s/\n/<br>/g;
        next if $product_seen{$dref->{'intProductID'}};
        next if $dref->{intInactive};
        my $filter_display = productAllowedThroughFilter($dref, $memdetails, $timeLocally, $productAttributes, $filter_params);      
        $anyAllowQty ||= $dref->{'intAllowQtys'} || 0;
        my $amount = currency(getCorrectPrice($dref, $multipersonType)) || 0;
        my $paid = 0;
        my $unpaid = 0;
       #next if ($paid_product{$dref->{'intProductID'}} and !$dref->{intAllowMultiPurchase});
        my $photolink = '';
         
        if($dref->{'intPhoto'}){
            my $hash = authstring($dref->{'intProductID'});
            my $pa = $dref->{'intProductID'}.'f'.$hash;
            $photolink =qq[<img width ='20' height ='20' src ="getProductPhoto.cgi?pa=$pa&pID=$dref->{'intProductID'}&client=$cl">];
        }

        my %itemdata = (
            Amount => $amount || 0,
            ProductID => $dref->{'intProductID'},
            AllowQty => $dref->{'intAllowQtys'} || 0,
            Qty => $dref->{'intQty'} || 0,
            AllowMultiPurchase => $dref->{'intAllowMultiPurchase'} || 0,
            Group => $dref->{'strGroup'} || '',
            TransactionID => $dref->{'intTransactionID'} || 0,
            Status => $dref->{'intStatus'},
            ProductNotes => decode_entities($dref->{'strProductNotes'}) || '',
            Mandatory => $regItemRules_ref->{$dref->{'intProductID'}}{'Required'} || $dref->{'intIsMandatory'} || 0,
            Name => $dref->{'strName'} || '',
            Photo =>$photolink,
        );
        push @unpaid_items, \%itemdata if $filter_display;
        $count++;
        $product_seen{$dref->{intProductID}}=1;

    }
    return '' if !$count;

    my $AllowedCountText = '';
    my $AllowedCount = $Data->{'SystemConfig'}{'OnlineRego_productCount'} || 0;
    my $productscount = ($AllowedCount == 1) ? 'item' : 'items';
    $AllowedCountText = qq[You are only allowed to purchase $AllowedCount $productscount at a time] if $AllowedCount;
    my %PageData = (
        HideItemHeader => $Data->{'SystemConfig'}{'hideRegoFormItemsHeader'} || 0,
        HideQty => $Data->{'SystemConfig'}{'regoForm_HIDE_qty'} || !$anyAllowQty || 0,
        HideCost => $Data->{'SystemConfig'}{'regoForm_HIDE_cost'} || 0,
        HideAmountPaid => $Data->{'SystemConfig'}{'regoForm_HIDE_amountpaid'} || 0,
        HideNotes => $Data->{'SystemConfig'}{'regoForm_HIDE_Notes'} || 0,
        HideGroup => $Data->{'SystemConfig'}{'regoForm_HIDE_group'} || 0,
        AllowedCountText => $AllowedCountText || '',
        UnPaidItems => \@unpaid_items,
        CurrencySymbol => $currencySymbol,
    );
    my $pagedata = '';
    $pagedata = runTemplate($Data, \%PageData, 'regoform/common/products.templ');
    return $pagedata || '';
}

sub getAllRegoProducts {
    my ($Data, $entityID, $regoID, $personID, $incExisting, $productIds) = @_;

    my $productID_str = join(',',@{$productIds});
    return [] if !$productID_str;

    my $ExistingStatus = $incExisting ? 0 : 9999; ## Obviously none will have 9999
    my $sql = qq[
        SELECT DISTINCT 
            T.intStatus,
            T.intTransactionID,
            T.curAmount as AmountCharged,
            P.intProductID,
            P.strName,
            P.curDefaultAmount,
            P.intMinChangeLevel,
            P.intCreatedLevel,
            P.intPhoto,
            PP.curAmount,
            P.strGroup,
            P.intAllowMultiPurchase,
            P.strProductNotes,
            P.intInactive,
            P.intAllowQtys,
            P.intProductGender,
            PP.intPricingType,
            PP.curAmount_Adult1,
            PP.curAmount_Adult2,
            PP.curAmount_Adult3,
            PP.curAmount_AdultPlus,
            PP.curAmount_Child1,
            PP.curAmount_Child2,
            PP.curAmount_Child3,
            PP.curAmount_ChildPlus,
            dtDateAvailableFrom,
            dtDateAvailableTo
        FROM tblProducts as P
            LEFT JOIN tblTransactions as T ON (
                T.intID =?
                AND T.intTableType = $Defs::LEVEL_PERSON
                AND T.intProductID = P.intProductID
                AND T.intPersonRegistrationID IN (0, ?)
                AND T.intTXNEntityID IN (0, ?)
                AND T.intStatus = 0     
                AND T.intStatus=$ExistingStatus
            )
            LEFT JOIN tblProductPricing as PP ON (
                PP.intProductID = P.intProductID
                AND PP.intRealmID = P.intRealmID
            )
        WHERE
            P.intRealmID = ?
            AND P.intProductID IN ($productID_str)
        ORDER BY P.strGroup, P.strName, intLevel
    ];

    ## T.intStatus=999 to turn off existing for moment.
            #AND (P.intMinSellLevel <= ? or P.intMinSellLevel=0)

    my $q = $Data->{'db'}->prepare($sql);
    $q->execute($personID, $regoID, $entityID, $Data->{'Realm'});

    my $regoProducts = $q->fetchall_hashref('intProductID');

    return $regoProducts;
}

sub checkAllowedProductCount {
    my ($Data, $ID, $tableType, $formID, $params, $assocID, $realmID) = @_;

    my $st = qq[SELECT COUNT(*) AS CountProds FROM tblRegoFormProducts WHERE  intRegoFormID = ?];

    my $qry=$Data->{'db'}->prepare($st);
    $qry->execute($formID);
    my $countProds = $qry->fetchrow_array() || 0;
    return '' if ! $countProds;

    $Data->{'SystemConfig'}{'OnlineRego_productCount'} ||= 0;
    $Data->{'SystemConfig'}{'OnlineRego_minimumProductCount'} ||= 0;
    return if (!$Data->{'SystemConfig'}{'OnlineRego_productCount'} and !$Data->{'SystemConfig'}{'OnlineRego_minimumProductCount'});
    $ID||=0;
    my $AllowedCount = $Data->{'SystemConfig'}{'OnlineRego_productCount'};
    $tableType||=0;

    my $count=0;
    for my $k (keys %{$params})  {
        if($k=~/prod_/) {
            if($params->{$k}==1)    {
                $count++;
             }
        }
        if($k=~/txn_/)  {
            if($params->{$k}>=1)    {
                $count++;
            }
        }
    }
    my $products = '';
    my $resultHTML = '';
    if ($Data->{'SystemConfig'}{'OnlineRego_productCount'}) {
        $products = ($AllowedCount == 1) ? 'item' : 'items';
        $resultHTML = qq[<p>You are only allowed to purchase $AllowedCount $products</p>];
        return $resultHTML if ($count > $AllowedCount);
    }

    my $paidCount = 0;
    if ($Data->{'SystemConfig'}{'OnlineRego_productCountCheckPaid'})        {
        my $st = qq[
            SELECT COUNT(T.intTransactionID)
            FROM tblTransactions as T
                INNER JOIN tblProducts as P ON (P.intProductID = T.intProductID)
                INNER JOIN tblRegoFormProducts AS RFP ON (RFP.intProductID=T.intProductID)
            WHERE 
                T.intID = ? 
                AND T.intTableType = ?
                AND T.intRealmID = ?
                AND T.intAssocID = ?
                AND P.intInactive=0
                AND (
                    RFP.intAssocID IN (0, T.intAssocID)
                    OR RFP.intRegoFormID = ?
                )
                AND P.intProductType NOT IN (2)
        ];
        my $query = $Data->{'db'}->prepare($st);

        $query->execute($ID, $tableType, $realmID || 0, $assocID || 0, $formID,);

        ($paidCount)=$query->fetchrow_array() || 0;

        if ($count)     {
            ## If items ticked for purchase then check total count
            $count += $paidCount;
            $resultHTML = qq[<p>You are only allowed to purchase (or have previously purchased) $AllowedCount $products</p>];
            return $resultHTML if ($count > $AllowedCount and $AllowedCount);
        }
        else    {
            $count = $paidCount;
        }
    }
    my $minimumCount = $Data->{'SystemConfig'}{'OnlineRego_minimumProductCount'} ||= 0;
    return '' if (! $minimumCount);

  $products = ($minimumCount == 1) ? 'item' : 'items';
  $resultHTML = qq[<p>You registration has not been selected because you have no chosen at least $minimumCount $products<br>Your Registration has not been selected because you have not chosen at least one item.
Please click back on your Internet browser to return to the items selection screen and choose at least one item and then click .confirm. again to complete your Registration.</p>];
    return $resultHTML if ($count < $minimumCount);

    return '';

}

sub checkMandatoryProducts      {
    my ($Data, $ID, $tableType, $params) = @_;
    return ('', 0) if (! $Data->{'SystemConfig'}{'AllowOnlineRego_mandatoryCheck'});
    $ID||=0;
    $tableType||=0;

    my @productsselected=();

    my $products_list = '';
    my @trans_list;
    my @products_list;

    my %products_purch = ();
    for my $k (keys %{$params})  {
        if($k=~/prod_/) {
            if($params->{$k}==1)    {
                my $prod=$k;
                $prod=~s/[^\d]//g;
                $products_purch{$prod} = 1;
                push @products_list, $prod;
            }
        }
        if($k=~/txn_/)  {
            if($params->{$k}>=1)    {
                my $txn=$k;
                $txn=~s/[^\d]//g;
                push @trans_list, $txn;
            }
        }
    }
    return ('', 0) if (!scalar(@trans_list) and !scalar(@products_list));

    my $trans_list = join(',', map { '?' } @trans_list );

    my %mandProds = ();
    if ($ID or $trans_list)        {
        $trans_list ||= 0;
        ## LETS GET THE PRODUCTS FOR THE LOGGED IN MEMBER (and any paid ones)
        my $st = qq[
                SELECT T.intProductID
                FROM tblTransactions as T
                    INNER JOIN tblProducts as P ON (P.intProductID=T.intProductID)
                WHERE T.intID = ?
                    AND T.intTableType = ?
                    AND (T.intTransactionID IN($trans_list) or T.intStatus=1)
        ];
                    #AND P.intInactive=0
        my $query = $Data->{'db'}->prepare($st);
        $query->execute($ID, $tableType, @trans_list);

        while (my $dref = $query->fetchrow_hashref())   {
            push @products_list, $dref->{intProductID};
            $products_purch{$dref->{'intProductID'}} = 1;
        }
    }

    $products_list ||= '0';

    my $DependentProducts = ();
    if (scalar @products_list) {
        $DependentProducts = Products::getProductDependencies($Data, @products_list);
    }

    foreach my $dp (keys %{$DependentProducts}) {
        $mandProds{$dp} = 1;# if ($dref->{intMandatoryProductID});
    }

    @products_list = ();
    foreach my $key (keys %mandProds)     {
        next if (! $key or $key ==0 or exists $products_purch{$key});
        push @products_list, $key;

    }
    unless (scalar @products_list) {
        @products_list = ( 0 );
    }

    $products_list = join(',', map { '?' } @products_list );

    my $resultHTML = qq[<p>In order to continue with your online transaction, you must select the following mandatory items</p><br>];

    my $st = qq[
        SELECT strName, strGroup
        FROM tblProducts as P
        WHERE P.intProductID IN ($products_list)
                        AND P.intInactive=0
    ];
    my $query = $Data->{'db'}->prepare($st);
    $query->execute(@products_list);
    my $mand_errors = 0;
    while (my $dref = $query->fetchrow_hashref())   {
        $mand_errors ++;
        $resultHTML .= qq[<p>* $dref->{strName}];
        $resultHTML .= qq[($dref->{strGroup})] if ($dref->{strGroup});
        $resultHTML .= qq[</p>];
    }
    $resultHTML .= qq[<br><p>Please press the <b>back</b> button on your browser</p>];

    return ($resultHTML, 1) if ($mand_errors);
    return ('',0);
}

sub fix_qty {
    my ($qty) = @_;
    $qty = int($qty);
    #Ensuring reasonable value
    $qty=1 if($qty<=0 or $qty>5000);
    return $qty;
}


sub timeLocally   {
    my ($Data, $datestring) = @_;

    my $timezone = $Data->{'SystemConfig'}{'Timezone'} || 'UTC';
    my $time = timeatAssoc(
        $timezone || '', 
        $datestring || ''
    );
    return $time;
}   

sub productAllowedThroughFilter {
    my ($dref, $memdetails, $timeLocally, $productAttributes, $params) = @_;

    # Returns 1 if product passes filters
    # else 0 means product doesn't pass
    $dref->{strProductNotes}=~s/\n/<br>/g;

    if($dref->{'dtDateAvailableFrom'} and $dref->{'dtDateAvailableFrom'}ne '0000-00-00 00:00:00')   {
        return 0 if $dref->{'dtDateAvailableFrom'} gt $timeLocally;
    }

    if($dref->{'dtDateAvailableTo'} and $dref->{'dtDateAvailableTo'} ne '0000-00-00 00:00:00')  {
        return 0 if $dref->{'dtDateAvailableTo'} lt $timeLocally;
    }

    if ($memdetails) {
        if ( $memdetails->{'Gender'} and $dref->{'intProductGender'} ) {
            return 0 if $dref->{'intProductGender'} != $memdetails->{'Gender'};
        }

        if ( $productAttributes->{ $dref->{'intProductID'} } ) {

            if ( $memdetails->{'DOB'} and $productAttributes->{$dref->{'intProductID'}} ) {

                my $dt_DOB = $memdetails->{'DOB'};
                $dt_DOB =~ s#-#/#g;
                my($d,$m,$y) = split('/',$dt_DOB);
                $m ||= 0;
                $d ||= 0;
                $y ||= 0;
                $d='0'.$d if length($d) ==1;
                $m='0'.$m if length($m) ==1;
                my $dob = "$y-$m-$d";

                if($productAttributes->{$dref->{'intProductID'}}{$Defs::PRODUCT_DOB_MAX}
                    and $productAttributes->{$dref->{'intProductID'}}{$Defs::PRODUCT_DOB_MAX}[0] ne 'NULL' ) {
                    return 0 if ($dob gt $productAttributes->{$dref->{'intProductID'}}{$Defs::PRODUCT_DOB_MAX}[0]);
                }

                if($productAttributes->{$dref->{'intProductID'}}{$Defs::PRODUCT_DOB_MIN}
                    and $productAttributes->{$dref->{'intProductID'}}{$Defs::PRODUCT_DOB_MIN}[0] ne 'NULL' ) {
                    return 0 if ($dob lt $productAttributes->{$dref->{'intProductID'}}{$Defs::PRODUCT_DOB_MIN}[0]);
                }

                if ( $y and $m and $d ) {
                    my ( $today_year, $today_month, $today_day ) = Today();
                    my ( $age_year, $age_month, $age_day ) = Delta_YMD( $y, $m, $d, $today_year, $today_month, $today_day );

                    if( $productAttributes->{$dref->{'intProductID'}}{$Defs::PRODUCT_AGE_MAX}
	                    and $productAttributes->{$dref->{'intProductID'}}{$Defs::PRODUCT_AGE_MAX}[0] ne 'NULL' ) {
	                    return 0 if ( $age_year >= $productAttributes->{$dref->{'intProductID'}}{$Defs::PRODUCT_AGE_MAX}[0] );
	                }

	                if( $productAttributes->{$dref->{'intProductID'}}{$Defs::PRODUCT_AGE_MIN}
	                    and $productAttributes->{$dref->{'intProductID'}}{$Defs::PRODUCT_AGE_MIN}[0] ne 'NULL' ) {
	                    return 0 if ( $age_year < $productAttributes->{$dref->{'intProductID'}}{$Defs::PRODUCT_AGE_MIN}[0] );
	                }
                }
		    }

            #if($productAttributes->{$dref->{'intProductID'}}{$Defs::PRODUCT_MEMBER_TYPES} ) {
                #my $found = 0;
                #for my $i (@{$productAttributes->{$dref->{'intProductID'}}{$Defs::PRODUCT_MEMBER_TYPES}}) {
#
                    #$found = 1 if($i == $Defs::MEMBER_TYPE_PLAYER and $params->{'ynPlayer'});
                    #$found = 1 if($i == $Defs::MEMBER_TYPE_COACH and $params->{'ynCoach'});
                    #$found = 1 if($i == $Defs::MEMBER_TYPE_UMPIRE and $params->{'ynMatchOfficial'});
                    #$found = 1 if($i == $Defs::MEMBER_TYPE_OFFICIAL and $params->{'ynOfficial'});
                    #$found = 1 if($i == $Defs::MEMBER_TYPE_MISC and $params->{'ynMisc'});
                    #$found = 1 if($i == $Defs::MEMBER_TYPE_VOLUNTEER and $params->{'ynVolunteer'});
                #}
                #return 0 if !$found;
            #}

        }
    }

    return 1;
}

sub insertRegoTransaction {
    my($Data, $regoID, $intID, $params, $entityID, $entityLevel, $level, $session)=@_;
    my $db=$Data->{'db'};
    $entityID ||= getLastEntityID($Data->{'clientValues'});
    $entityLevel ||= getLastEntityLevel($Data->{'clientValues'});
    $session ||= undef;
    my $multipersonType = $session ? ($session->getNextRegoType())[0] || '' : '';
    $intID ||= 0;

use Data::Dumper;
print STDERR Dumper($params);
    #Get products selected
    my @productsselected=();
    my @already_in_cart_items=();
    for my $k (%{$params})  {
      if($k=~/prod_/) {
        if($params->{$k}==1)  {
          my $prod=$k;
          $prod=~s/[^\d]//g;
          push @productsselected, $prod;
        }
      }
      if($k=~/txn_/)  {
        if($params->{$k}>=1)  {
          my $txn=$k;
          $txn=~s/[^\d]//g;
          push @already_in_cart_items, $txn;
        }
      }
    }
    my $realmID=$Data->{'Realm'} || 0;
    my $realmSubTypeID=$Data->{'RealmSubType'} || 0;
    my $st_add= qq[
        INSERT INTO tblTransactions (
          intStatus, 
          curAmount, 
          curPerItem, 
          intProductID, 
          intQty, 
          dtTransaction, 
          intID, 
          intTableType, 
          intRealmID, 
          intRealmSubTypeID, 
          intTXNEntityID,
          intPersonRegistrationID
        )
        VALUES (?, ?, ?, ?, ?, SYSDATE(), ?, ?, ?, ?, ?, ?)
  ];
  my $q_add= $db->prepare($st_add);
  my @txns_added=();
  my $total_amount = 0;
    if (scalar(@productsselected) or scalar(@already_in_cart_items)) {
        if (scalar(@productsselected)) {
            foreach my $product (@productsselected)    {
                my $amount= getItemCost($Data, $entityID, $entityLevel, $multipersonType, $product);
                $total_amount += $amount;
            }
        }
        if (scalar(@already_in_cart_items)){
            my @query_params;
            my $clubWHERE;
            if ( $entityID and $entityID != $Defs::INVALID_ID ) {
                $clubWHERE
                    = qq[ OR (PP.intID = ?)];
                @query_params = ($realmID, $entityID , @already_in_cart_items);
            }
            else {
                @query_params = ($realmID, @already_in_cart_items);
            }
            my $already_list = join(',', map { '?' } @already_in_cart_items );
            my $st = qq[
                SELECT 
                    T.intTransactionID, 
                    T.intQty as CurrentQty,
                    T.intProductID,
                    T.curAmount as CurrentAmount,
                P.curDefaultAmount,
                P.intMinChangeLevel,
                P.intCreatedLevel,
                PP.curAmount,
                P.intCreatedID,
                PP.intPricingType,
                PP.curAmount_Adult1,
                PP.curAmount_Adult2,
                PP.curAmount_Adult3,
                PP.curAmount_AdultPlus,
                PP.curAmount_Child1,
                PP.curAmount_Child2,
                PP.curAmount_Child3,
                PP.curAmount_ChildPlus
        FROM 
                    tblTransactions as T
                    INNER JOIN tblProducts as P ON (T.intProductID=P.intProductID)
                    LEFT JOIN tblProductPricing as PP ON (
                        PP.intProductID = P.intProductID
                        AND PP.intRealmID = ?
                        AND ((intLevel = $Defs::LEVEL_NATIONAL)
                        $clubWHERE
                        )
                    )
        WHERE 
                    intTransactionID IN ($already_list)
                ORDER BY PP.intLevel
      ];
      my $query = $Data->{'db'}->prepare($st);
      $query->execute(@query_params);
            my $st_upd = qq[
                UPDATE tblTransactions
                SET intQty = ?, curAmount=?, curPerItem=?
                WHERE intTransactionID=?
                    AND intStatus=0
                    AND intProductID=?
                LIMIT 1
            ];
      my $qry_update = $Data->{'db'}->prepare($st_upd);
            my %product_seen;
      while(my $dref=$query->fetchrow_hashref())  {
                next if $product_seen{$dref->{'intProductID'}};
          my $amount= getCorrectPrice($dref, $multipersonType);
          my $qty = $params->{'txnQTY_'.$dref->{'intTransactionID'}} || $params->{'prodQTY_'.$dref->{'intTransactionID'}} ||  0;
        
#Fix QTY (Prevent bad chars)
    $qty = fix_qty($qty); 
    my $totalamount= $amount * $qty;
                if ($amount != $dref->{'CurrentAmount'} or $qty != $dref->{CurrentQty}) {
              $qry_update->execute($qty, $totalamount, $amount, $dref->{intTransactionID}, $dref->{intProductID});
                }
        $total_amount += $dref->{curAmount};
                $product_seen{$dref->{intProductID}}=1;
      }
    }
  }

    if (scalar(@productsselected)) {
        my %product_seen;
        foreach my $product (@productsselected)    {
            next if $product_seen{$product}++;
            my $amount= getItemCost($Data, $entityID, $entityLevel, $multipersonType, $product);
            my $status = ($total_amount eq '0.00' or $total_amount == 0) ? 1: 0;
            $status = 0 if $Data->{'SystemConfig'}{'RegoForm_DontPayZero'};
            my $qty = $params->{'txnQTY_'.$product} || $params->{'prodQTY_'.$product} || 1;
            $qty = fix_qty($qty);
            my $totalamount= $amount * $qty;
            $q_add->execute(
                $status,
                $totalamount,
                $amount,
                $product,
                $qty,
                $intID,
                $level,
                $realmID,
                $realmSubTypeID,
                $entityID,
                $regoID
            );
    
            
      my $tx_ID=$q_add->{mysql_insertid} || 0;
      if ($status and ($total_amount == 0 or $total_amount eq '0.00'))  {
        my $regoFormID = $Data->{'RegoFormID'} || 0;
        my $st = qq[
          INSERT INTO tblTransLog
          (dtLog, intAmount, intRealmID, intStatus, intPaymentType, intRegoFormID)
          VALUES (NOW(), 0, ?, 1, 0, ?)
        ];
        my $qry=$Data->{'db'}->prepare($st);
        $qry->execute( $Data->{'Realm'}, $regoFormID );
        my $transLogID = $qry->{'mysql_insertid'};

        $st = qq[
          INSERT INTO tblTXNLogs
          (intTXNID, intTLogID)
          VALUES (?, ?)
        ];
        $qry=$Data->{'db'}->prepare($st);
        $qry->execute( $tx_ID, $transLogID );
        $st = qq[
          UPDATE tblTransactions
            SET intTransLogID = ?, intStatus = $Defs::TXN_PAID, dtPaid=NOW()
          WHERE intTransactionID = ?
        ];
        $qry=$Data->{'db'}->prepare($st);
        $qry->execute( $transLogID, $tx_ID );
                Products::product_apply_transaction($Data,$transLogID);
      }
      push @txns_added, $tx_ID if $tx_ID;
    }
  }
  push @txns_added, @already_in_cart_items;
  return \@txns_added || [];
}

1;
