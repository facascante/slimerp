#
# $Header: svn://svn/SWM/trunk/web/PaymentSplitItemList.pm 8251 2013-04-08 09:00:53Z rlee $
#

package PaymentSplitItemList;

require Exporter;
@ISA       = qw(Exporter);
@EXPORT    = qw(listPaymentSplitItems);
@EXPORT_OK = qw(listPaymentSplitItems);

use strict;

use CGI qw(param unescape escape);

use PaymentSplitItemObj;
use Reg_common;
use List;
use Defs;

sub listPaymentSplitItems {
    my ($Data, $splitID, $splitName) = @_;

    my $client = unescape($Data->{client});

    my $editText   = 'Edit Payment Split';
    my $deleteText = 'Delete Payment Split';

    my $title = qq[<div class="changeoptions"><span class = "button-small generic-button"><a href="$Data->{'target'}?client=$client&amp;a=A_PS_editsplit&amp;splitID=$splitID&amp;splitName=$splitName">Edit</a></span>];
    $title   .= qq[ <span class = "button-small generic-button"><a href="$Data->{'target'}?client=$client&amp;a=A_PS_deletesplit&amp;splitID=$splitID&amp;splitName=$splitName">Delete</a></span></div>];
    $title   .= "Payment Split - $splitName";

    my $paymentSplitItems = PaymentSplitItemObj->getList($splitID, $Data->{'db'});
    my $headings          = '';
    my $rows              = '';
    my $numlist           = '';
    my $resultHTML        = '';
    my $found             = 0;

    for my $dref(@{$paymentSplitItems}) {
        $found++;
        $rows .= list_row2($dref, [qw(curAmount dblFactor intLevelID strOtherBankCode strOtherAccountNo strOtherAccountName)], ($found)%2 == 0);
    }

    if ($found) {
        $headings = List::list_headers(['Amount', 'Percentage', 'Recipient', 'Branch No.', 'Account No.', 'Account Name']) || '';
        $numlist = ($found and $found > 1) ? qq[<div class="tablecount">$found rows found</div>] : '';
    }
    else {
        $resultHTML = textMessage("No Payment Split items found");
    }

    $resultHTML = qq[ 
        <table class="listTable">
            $headings
            $rows
        </table>$numlist
    ];

    return ($resultHTML, $title);
}


sub list_row2 {
	my ($dref, $fields, $shade) = @_;

	my $row = '';
	return '' if (!$dref or !$fields);

    if (!$dref->{'intRemainder'}) {
        if ($dref->{'curAmount'} != '0.00') {
            $dref->{'dblFactor'} = '&nbsp';
        }
        else {
            $dref->{'curAmount'} = '&nbsp';
            $dref->{'dblFactor'} = sprintf('%.2f', $dref->{'dblFactor'} * 100);
        }
    }
    else {
        $dref->{'curAmount'} = 'Remainder';
        $dref->{'dblFactor'} = '&nbsp';
    }

    if ($dref->{'intLevelID'} == $Defs::LEVEL_NATIONAL) {
        $dref->{'intLevelID'} = 'National';
    }
    elsif ($dref->{'intLevelID'} == $Defs::LEVEL_STATE) {
        $dref->{'intLevelID'} = 'State';
    }
    elsif ($dref->{'intLevelID'} == $Defs::LEVEL_REGION) {
        $dref->{'intLevelID'} = 'Region';
    }
    elsif ($dref->{'intLevelID'} == $Defs::LEVEL_ZONE) {
        $dref->{'intLevelID'} = 'Zone';
    }
    elsif ($dref->{'intLevelID'} == $Defs::LEVEL_ASSOC) {
        $dref->{'intLevelID'} = 'Association';
    }
    elsif ($dref->{'intLevelID'} == $Defs::LEVEL_CLUB) {
        $dref->{'intLevelID'} = 'Club';
    }
    else {
        $dref->{'intLevelID'} = '&nbsp';
    }

	my $shade_str = ($shade)
        ? 'class="rowshade" ' 
        : '';

	for my $i (0 .. $#{$fields}) {
		my $fieldname       = $fields->[$i];
		$fieldname          =~ s/\./_/g;
		$dref->{$fieldname} = '' if !defined $dref->{$fieldname};
		my $val             = $dref->{$fieldname};
		$val                = '' if !defined $val;
		$row               .= "<td $shade_str>$val</td>\n";
	}

	return qq[<tr>$row</tr>];
}


1;
