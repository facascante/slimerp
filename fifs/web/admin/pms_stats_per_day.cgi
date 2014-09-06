#!/usr/bin/perl -w

#
# $Header: svn://svn/SWM/trunk/web/admin/pms_stats.cgi 9448 2013-09-09 03:07:56Z dhanslow $
#

use strict;
use lib "../comp", "../..","..",".";
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

	my $realm= param('realm') || 0;
	my $sr= param('sr') || 0;
	my $pt= param('pt') || 0;
	my $dtFrom= param('dtFrom') || '';
	my $dtTo= param('dtTo') || '';
	my $tFrom= param('tFrom') || '';
	my $tTo= param('tTo') || '';
	my $body = runPMSReport($db, $realm, $dtFrom, $dtTo, $tFrom, $tTo, $sr,$pt);
	disconnectDB($db) if $db;

    	print_adminpageGen($body, "", "");
}


sub runPMSReport	{

	my ($db, $realm, $dtFrom, $dtTo, $tFrom, $tTo, $sr, $pt) = @_;

	$realm ||= 0;
	$pt||=0;

$sr||=0;
$tTo = qq[23:59:59] if ($dtFrom eq $dtTo and ! $tTo);
	my $subrealmWHERE = ($sr) 
		? qq[ AND ML.intRealmSubTypeID= $sr]
		: '';
	my $realmWHERE = ($realm) 
		? qq[ AND ML.intRealmID = $realm]
		: '';


	$tFrom = qq[ $tFrom] if ($tFrom);
	my $dtFromWHERE = ($dtFrom) 
		? qq[ AND TL.dtLog >= "$dtFrom$tFrom"]
		: '';
		#? qq[ AND ML.dtEntered >= "$dtFrom$tFrom"]

	$tTo = qq[ $tTo] if ($tTo);
	my $dtToWHERE = ($dtTo) 
		? qq[ AND TL.dtLog <= "$dtTo$tTo"]
		: '';

	my $ptWHERE = ($pt) 
		? qq[ AND TL.intPaymentType=$pt]
		: '';

	my $st = qq[
		SELECT 
			strRealmName, 
			strSubTypeName, 
			A.strName as AssocName, 
			A.intAssocID as AssocID, 
			C.strName as ClubName, 
			C.intClubID as ClubID, 
			ML.strCurrencyCode as CurrencyCode,
			COUNT(DISTINCT intTransLogID) as countTrans, 
			SUM(curMoney) as sumMoney,
			DATE(TL.dtLog) as DateLog
		FROM 
			tblMoneyLog as ML 
			INNER JOIN tblTransLog as TL ON (
				TL.intLogID=ML.intTransLogID
			) 
			INNER JOIN tblAssoc as A ON (
				A.intAssocID=ML.intAssocID
			) 
			INNER JOIN tblRealms as R ON (
				R.intRealmID=ML.intRealmID
			) 
			LEFT JOIN tblRealmSubTypes as RS ON (
				RS.intSubTypeID=ML.intRealmSubTypeID
			) 
			LEFT JOIN tblClub as C ON (
				C.intClubID=ML.intClubID
			) 
		WHERE 
			ML.intLogType IN (1,4,6) 
			AND TL.intAmount>0
			AND TL.intStatus=1
			$realmWHERE
			$subrealmWHERE
			$dtFromWHERE
			$dtToWHERE
			$ptWHERE
		GROUP BY
			DATE(TL.dtLog) 
			ML.intRealmID, 
			ML.intRealmSubTypeID, 
			ML.intAssocID, 
			ML.intClubID,
			ML.strCurrencyCode

	];
print STDERR $st;

	my $body = qq[
<table>
	<tr>
		<th>Date</th>	
		<th>Realm Name</th>	
		<th>Sub Realm Name</th>	
		<th>Assoc ID</th>	
		<th>Assoc Name</th>	
		<th>Club ID</th>	
		<th>Club Name</th>	
		<th>Count</th>	
		<th>Amount</th>	
		<th>Currency</th>	
	</tr>
	];

	my $query = $db->prepare($st);
	$query->execute;


	my $countTrans=0;
	my $sumMoney=0;
	my $count=0;
	while (my $dref =$query->fetchrow_hashref())	{
		$body .= qq[
			<tr>
				<td>$dref->{'DateLog'}</td>
				<td>$dref->{'strRealmName'}</td>
				<td>$dref->{'strSubTypeName'}</td>
				<td>$dref->{'AssocID'}</td>
				<td>$dref->{'AssocName'}</td>
				<td>$dref->{'ClubID'}</td>
				<td>$dref->{'ClubName'}</td>
				<td>$dref->{'countTrans'}</td>
				<td>$dref->{'sumMoney'}</td>
				<td>$dref->{'CurrencyCode'}</td>
			</tr>
		];
		$countTrans += $dref->{'countTrans'};
		$sumMoney += $dref->{'sumMoney'};
		$count++;
	}

	$body .= qq[</table>];
	$body .= qq[<p>Number of Entities: $count</p>];
	$body .= qq[<p>Total Number: $countTrans</p>];
	$body .= qq[<p>Total Money: \$$sumMoney</p>];
	return $body;


}
1;
