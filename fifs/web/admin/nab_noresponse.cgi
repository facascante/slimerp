#!/usr/bin/perl -w

#
# $Header: svn://svn/SWM/trunk/web/admin/pms_stats.cgi 9861 2013-11-11 02:56:53Z fkhezri $
#

use strict;
use lib "../..","..",".","../comp";
use DBI;
use CGI qw(param unescape escape);
use Defs;
use Utils;
use HTMLForm qw(_date_selection_box);
use Defs;
use Date::Calc qw(Today);
use ExportEmailData;
use AdminPageGen;

main();

sub main    {
	my $db    = connectDB();

	my $dtFrom= param('dtFrom') || '';
	my $dtTo= param('dtTo') || '';
	my $body = runPMSReport($db, $dtFrom, $dtTo);
	disconnectDB($db) if $db;

    	print_adminpageGen($body, "", "");
}


sub runPMSReport	{

	my ($db, $dtFrom, $dtTo) = @_;

	my $dtFromWHERE = ($dtFrom) 
		? qq[ AND TLC.dtLog >= "$dtFrom"]
		: '';
	my $dtToWHERE = ($dtTo) 
		? qq[ AND TLC.dtLog <= "$dtTo"]
		: '';
	
	my $st = qq[
select A.strName AssocName, C.strName ClubName, C.intClubID ClubID, A.intAssocID AssocID, BAA.strMerchantAccUsername BAAMerch, BAC.strMerchantAccUsername BACMerch, group_concat(distinct(OTHERCODES.strResponseCode)) as OtherResponse,
TLC.dtLog dtLog, TLC.intTLogID as LogID,
TXNL.intTLogID, TXNL.intTXNID as TiD,
T.dtTransaction as dtTrans, T.dtPaid as dtPaid, T.intStatus, T.intID,
M.strFirstname as strFirstname, M.strSurname as strSurname, M.strEmail as strEmail
FROM tblTransLog_Counts TLC
LEFT JOIN tblTransLog_Counts OTHERCODES ON OTHERCODES.intTLogID = TLC.intTLogID and OTHERCODES.strResponseCode!=''
LEFT JOIN tblTXNLogs TXNL ON TXNL.intTLogID = TLC.intTLogID
LEFT JOIN tblTransLog TL ON TL.intLogID = TLC.intTLogID
LEFT JOIN tblTransactions T ON TXNL.intTXNID = T.intTransactionID
LEFT JOIN tblMember M ON T.intID = M.intMemberID AND T.intTableType=1
LEFT JOIN tblClub C ON TL.intClubPaymentID = C.intClubID
LEFT JOIN tblAssoc A ON TL.intAssocPaymentID = A.intAssocID
LEFT JOIN tblBankAccount BAA ON TL.intAssocPaymentID = BAA.intEntityID AND BAA.intEntityTypeID=5
LEFT JOIN tblBankAccount BAC ON TL.intClubPaymentID = BAC.intEntityID AND BAC.intEntityTypeID=3

WHERE TLC.strResponseCode = ''
$dtFromWHERE
$dtToWHERE
GROUP BY TLC.intTLogID
ORDER BY TLC.dtLog desc
	];
warn "$st";
	my $body = qq[
<table cellpadding='4' cellspacing='0' border=1 style='padding:5px;'>
	<tr>
		<th>Logged From NAB</th>	
		<th>Invoice ID</th>	
		<th>Transaction ID</th>	
		<th>Other Attempts</th>	
		<th>Date Transaction</th>	
		<th>Date Paid</th>	
		<th>Member Name (Email)</th>	
		<th>Assocation</th>	
		<th>Club</th>	
	</tr>
	];

	my $query = $db->prepare($st);
	$query->execute;


	while (my $dref =$query->fetchrow_hashref())	{
		$body .= qq[
			<tr>
				<td>$dref->{'dtLog'}</td>
				<td>$dref->{'LogID'}</td>
				<td>$dref->{'TiD'}</td>
				<td>$dref->{'OtherResponse'}</td>
				<td>$dref->{'dtTrans'}</td>
				<td>$dref->{'dtPaid'}</td>
				<td>$dref->{'strFirstname'} $dref->{'strSurname'} <i>$dref->{'strEmail'}</i></td>
				<td>$dref->{'AssocName'} <i>$dref->{'AssocID'}</i> <b>$dref->{'BAAMerch'}</b></td>
				<td>$dref->{'ClubName'} <i>$dref->{'ClubID'}</i> <b>$dref->{'BACMerch'}</b></td>
			</tr>
		];
	}

	$body .= qq[</table>];
	return $body;


}
1;
