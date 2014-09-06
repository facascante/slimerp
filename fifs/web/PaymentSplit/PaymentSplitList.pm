#
# $Header: svn://svn/SWM/trunk/web/PaymentSplitList.pm 8251 2013-04-08 09:00:53Z rlee $
#

package PaymentSplitList;

require Exporter;
@ISA       = qw(Exporter);
@EXPORT    = qw(listPaymentSplits);
@EXPORT_OK = qw(listPaymentSplits);

use strict;

use CGI qw(param unescape escape);

use PaymentSplitObj;
use Reg_common;
use GridDisplay;


sub listPaymentSplits {
    my ($Data, $entityID, $typeID) = @_;

    my $type  = $Data->{'clientValues'}{'currentLevel'};
    my $title = "Payment Splits in $Data->{'LevelNames'}{$type}";

    my $client = unescape($Data->{client});
    my %tempClientValues = getClient($client);
    my $addText = 'Add payment split';

    my $addSplit = qq[
        <div class="changeoptions">
					<span class = "button-small generic-button">
            <a href="$Data->{'target'}?client=$client&amp;a=A_PS_newsplit&amp;l=$tempClientValues{currentLevel}">Add</a>
					</span>
        </div>
    ];

    $title = $addSplit.$title;

    my $resultHTML = '';
    my $found      = 0;

    my $paymentSplits = PaymentSplitObj->getList($entityID, $typeID, $Data->{'db'});

		my @rowdata = ();
    for my $dref(@{$paymentSplits}) {
        $found++;
				push @rowdata, {
					strSplitName => $dref->{'strSplitName'},
					SelectLink => "$Data->{'target'}?client=$client&amp;a=A_PS_showitems&amp;splitID=$dref->{'intSplitID'}&amp;splitName=$dref->{'strSplitName'}",
					id => $dref->{'intSplitID'},
				}
    }

		my @headers = (
			{
				type => 'Selector',
				field => 'SelectLink',
			},
			{
				name =>   $Data->{'lang'}->txt('Name'),
				field =>  'strSplitName',
			},
		);

		my $grid  = showGrid(
			Data => $Data,
			columns => \@headers,
			rowdata => \@rowdata,
			gridid => 'grid',
			width => '99%',
		);
		$resultHTML = qq[
			<div class = "grid-filter-wrap">
			$grid
			</div>
		];


    return ($resultHTML, $title);
}


1;

