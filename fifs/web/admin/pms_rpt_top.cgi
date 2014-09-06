#!/usr/bin/perl -w

#
# $Header: svn://svn/SWM/trunk/web/admin/pms_rpt_top.cgi 8530 2013-05-22 05:57:47Z cgao $
#

use strict;
use lib "../..","..",".";
use DBI;
use CGI qw(param unescape escape);
use Defs;
use Utils;
use Defs;
use Date::Calc qw(Today);
use ExportEmailData;
use AdminPageGen;

main();

sub main    {
	my $db    = connectDB();

	my $realm= param('r') || 0;
	my $sr= param('sr') || 0;
	my $pt= param('pt') || 0;
	my $y= param('y') || 0;
	my $m= param('m') || 0;
	my $d= param('d') || 0;
	my $logID= param('logID') || 0;
	my $body = '';
	my $target = "pms_rpt_top.cgi";
	$body = runPMSReport($db, $target, $realm, $sr,$pt);
	$body = runPMSReport_Month($db, $target, $realm, $sr,$pt, $y, $m) if ($m and $y and ! $d);
	$body = runPMSReport_Daily($db, $target, $realm, $sr,$pt, $y, $m, $d) if ($m and $y and $d);
	$body = runPMSReport_TransLog($db, $logID) if ($logID);
	disconnectDB($db) if $db;

    	print_adminpageGen($body, "", "");
}


sub runPMSReport	{

	my ($db, $target, $realm, $sr, $pt) = @_;

	$realm ||= 0;
	$pt||=0;

$sr||=0;
	my $subrealmWHERE = ($sr) 
		? qq[ AND ML.intRealmSubTypeID= $sr]
		: '';
	my $realmWHERE = ($realm) 
		? qq[ AND ML.intRealmID = $realm]
		: '';


	my $ptWHERE = ($pt) 
		? qq[ AND TL.intPaymentType=$pt]
		: '';

	my $st = qq[
		SELECT 
			ML.intRealmID, 
			R.strRealmName, 
			ML.intRealmSubTypeID,
			RSS.strSubTypeName,
			MONTH(dtEntered) as dtMonth, 
			YEAR(dtEntered) as dtYear, 
			SUM(curMoney) as TotalMoney 
		FROM 
			tblMoneyLog as ML 
			INNER JOIN tblRealms as R ON (R.intRealmID = ML.intRealmID) 
			INNER JOIN tblTransLog as TL ON (TL.intLogID = ML.intTransLogID)
			LEFT JOIN tblRealmSubTypes as RSS ON (ML.intRealmSubTypeID = RSS.intSubTypeID)
		WHERE 
			intLogType IN (1,4,5) 
			$ptWHERE
			$subrealmWHERE
			$realmWHERE
		GROUP BY 
			ML.intRealmID, 
			ML.intRealmSubTypeID,
			MONTH(dtEntered), 
			YEAR(dtEntered)
		ORDER BY
			dtYear DESC,
			dtMonth DESC
	];

	my $body = qq[
<table>
	<tr>
		<th>Realm Name</th>	
		<th>Sub Realm Name</th>	
		<th>Month</th>	
		<th>Year</th>	
		<th>Amount</th>	
	</tr>
	];

	my $query = $db->prepare($st);
	$query->execute;


	my $sumMoney=0;
	while (my $dref =$query->fetchrow_hashref())	{
		$body .= qq[
			<tr>
				<td><a href="$target?r=$dref->{'intRealmID'}&amp;sr=$dref->{'intRealmSubTypeID'}&amp;pt=$pt&amp;m=$dref->{'dtMonth'}&amp;y=$dref->{'dtYear'}">$dref->{'strRealmName'}</a></td>
				<td>$dref->{'strSubTypeName'}</td>
				<td><a href="$target?pt=$pt&amp;m=$dref->{'dtMonth'}&amp;y=$dref->{'dtYear'}">$dref->{'dtMonth'}</a></td>
				<td>$dref->{'dtYear'}</td>
				<td>$dref->{'TotalMoney'}</td>
			</tr>
		];
		$sumMoney += $dref->{'TotalMoney'};
	}

	$body .= qq[</table>];
	$body .= qq[<p>Total Money: \$$sumMoney</p>];
	return $body;


}
sub runPMSReport_Month {

	my ($db, $target, $realm, $sr, $pt, $y, $m) = @_;

	$realm ||= 0;
	$pt||=0;

$sr||=0;
	my $subrealmWHERE = ($sr) 
		? qq[ AND ML.intRealmSubTypeID= $sr]
		: '';
	my $realmWHERE = ($realm) 
		? qq[ AND ML.intRealmID = $realm]
		: '';


	my $ptWHERE = ($pt) 
		? qq[ AND TL.intPaymentType=$pt]
		: '';

	my $dtWHERE = qq[
		AND MONTH(dtEntered) = $m and YEAR(dtEntered) =$y
	];

	my $st = qq[
		SELECT 
			ML.intRealmID, 
			R.strRealmName, 
			ML.intRealmSubTypeID,
			RSS.strSubTypeName,
			DAY(dtEntered) as dtDay, 
			MONTH(dtEntered) as dtMonth, 
			YEAR(dtEntered) as dtYear, 
			SUM(curMoney) as TotalMoney 
		FROM 
			tblMoneyLog as ML 
			INNER JOIN tblRealms as R ON (R.intRealmID = ML.intRealmID) 
			INNER JOIN tblTransLog as TL ON (TL.intLogID = ML.intTransLogID)
			LEFT JOIN tblRealmSubTypes as RSS ON (ML.intRealmSubTypeID = RSS.intSubTypeID)
		WHERE 
			intLogType IN (1,4,5) 
			$ptWHERE
			$subrealmWHERE
			$realmWHERE
			$dtWHERE
		GROUP BY 
			ML.intRealmID, 
			ML.intRealmSubTypeID,
			DAY(dtEntered), 
			MONTH(dtEntered), 
			YEAR(dtEntered)
		ORDER BY
			dtDay
	];

	my $body = qq[
<div><b>Report for: $m - $y</b></div>
<table>
	<tr>
		<th>Day</th>	
		<th>Realm Name</th>	
		<th>Sub Realm Name</th>	
		<th>Amount</th>	
	</tr>
	];

	my $query = $db->prepare($st);
	$query->execute;


	my $sumMoney=0;
	while (my $dref =$query->fetchrow_hashref())	{
		$body .= qq[
			<tr>
				<td><a href="$target?pt=$pt&amp;m=$dref->{'dtMonth'}&amp;y=$dref->{'dtYear'}&amp;d=$dref->{'dtDay'}">$dref->{'dtDay'}</a></td>
				<td><a href="$target?r=$dref->{'intRealmID'}&amp;sr=$dref->{'intRealmSubTypeID'}&amp;pt=$pt&amp;m=$dref->{'dtMonth'}&amp;y=$dref->{'dtYear'}&amp;d=$dref->{'dtDay'}">$dref->{'strRealmName'}</a></td>
				<td>$dref->{'strSubTypeName'}</td>
				<td>$dref->{'TotalMoney'}</td>
			</tr>
		];
		$sumMoney += $dref->{'TotalMoney'};
	}

	$body .= qq[</table>];
	$body .= qq[<p>Total Money: \$$sumMoney</p>];
	return $body;


}

sub runPMSReport_Daily {

	my ($db, $target, $realm, $sr, $pt, $y, $m, $d) = @_;

	$realm ||= 0;
	$pt||=0;

$sr||=0;
	my $subrealmWHERE = ($sr) 
		? qq[ AND ML.intRealmSubTypeID= $sr]
		: '';
	my $realmWHERE = ($realm) 
		? qq[ AND ML.intRealmID = $realm]
		: '';
	my $ptWHERE = ($pt) 
		? qq[ AND TL.intPaymentType=$pt]
		: '';

	my $dtWHERE = qq[
		AND MONTH(dtEntered) = $m and YEAR(dtEntered) =$y AND DAY(dtEntered) = $d
	];

	my $st = qq[
		SELECT 
			TL.intLogID,
			ML.intRealmID, 
			R.strRealmName, 
			RSS.strSubTypeName,
			DAY(dtEntered) as dtDay, 
			MONTH(dtEntered) as dtMonth, 
			YEAR(dtEntered) as dtYear, 
			SUM(curMoney) as TotalMoney,
			TIME(dtLog) as dtLog
		FROM 
			tblMoneyLog as ML 
			INNER JOIN tblRealms as R ON (R.intRealmID = ML.intRealmID) 
			INNER JOIN tblTransLog as TL ON (TL.intLogID = ML.intTransLogID)
			LEFT JOIN tblRealmSubTypes as RSS ON (ML.intRealmSubTypeID = RSS.intSubTypeID)
		WHERE 
			intLogType IN (1,4,5) 
			$ptWHERE
			$subrealmWHERE
			$realmWHERE
			$dtWHERE
		GROUP BY 
			TL.intLogID
		ORDER BY 
			dtLog,
			TL.intLogID
	];

	my $body = qq[
<p>Report for $d/$m/$y
<table>
	<tr>
		<th>Realm Name</th>	
		<th>Sub Realm Name</th>	
		<th>Time</th>
		<th>Payment Ref</th>	
		<th>Amount</th>	
	</tr>
	];

	my $query = $db->prepare($st);
	$query->execute;

	my $sumMoney=0;
	while (my $dref =$query->fetchrow_hashref())	{
		$body .= qq[
			<tr>
				<td>$dref->{'strRealmName'}</td>
				<td>$dref->{'strSubTypeName'}</td>
				<td>$dref->{'dtLog'}</td>
				<td><a href="$target?logID=$dref->{'intLogID'}">$dref->{'intLogID'}</a></td>
				<td>$dref->{'TotalMoney'}</td>
			</tr>
		];
		$sumMoney += $dref->{'TotalMoney'};
	}

	$body .= qq[</table>];
	$body .= qq[<p>Total Money: \$$sumMoney</p>];
	return $body;


}
sub runPMSReport_TransLog {

	my ($db, $logID) = @_;

	my $st = qq[
		SELECT 
			TL.intLogID,
			ML.intRealmID, 
			R.strRealmName, 
			ML.intLogType,
			A.strName as AssocName,
			C.strName as ClubName,
			RSS.strSubTypeName,
			strFrom,
			curMoney,
			intPaymentType,
			intAmount,
			dtLog,
			ML.strMPEmail,
			ML.strBankCode,
			ML.strAccountNo,
			ML.intExportBankFileID,
			TL.intRegoFormID
		FROM 
			tblMoneyLog as ML 
			INNER JOIN tblRealms as R ON (R.intRealmID = ML.intRealmID) 
			INNER JOIN tblTransLog as TL ON (TL.intLogID = ML.intTransLogID)
			LEFT JOIN tblRealmSubTypes as RSS ON (ML.intRealmSubTypeID = RSS.intSubTypeID)
			LEFT JOIN tblAssoc as A ON (A.intAssocID = ML.intAssocID)
			LEFT JOIN tblClub as C ON (C.intClubID = intClubPaymentID)
		WHERE 
			intLogID = $logID
			AND intLogType NOT IN (5)
		ORDER BY
			intLogType
	];

	my $body = qq[
<table>
	<tr>
		<th>Log Type</th>	
		<th></th>	
		<th>Line Amount</th>	
		<th>PayPal Email</th>	
		<th>BSB</th>	
		<th>Account No.</th>	
		<th>Export ID</th>	
	</tr>
	];

	my $query = $db->prepare($st);
	$query->execute;

	my $sumMoney=0;
	my $paymentType=0;
	my $realmName = '';
	my $totalAmount = 0;
	my $dtLog = '';
	my $assocName = '';
	my $clubName = '';
	my $rfID = '';

	while (my $dref =$query->fetchrow_hashref())	{
		$paymentType=$dref->{'intPaymentType'} || 0;
		$realmName = $dref->{'strRealmName'};
		$dtLog = $dref->{'dtLog'};
		$totalAmount = $dref->{'intAmount'} || 0;
		$assocName = $dref->{'AssocName'} || '';
		$clubName = $dref->{'ClubName'} || '';
		$rfID = $dref->{'intRegoFormID'} || '';
		$body .= qq[
			<tr>
				<td>$dref->{'intLogType'}</td>
				<td>$dref->{'strFrom'}</td>
				<td>\$$dref->{'curMoney'}</td>
				<td>$dref->{'strMPEmail'}</td>
				<td>$dref->{'strBankCode'}</td>
				<td>$dref->{'strAccountNo'}</td>
				<td>$dref->{'intExportBankFileID'}</td>
			</tr>
		];
	}

	$body .= qq[</table>];
	$body = qq[
		<br>
		<table>
			<tr><td><b>Payment Ref ID (log ID):</b></td><td><b>$logID</b></td></tr>
			<tr><td>Realm Name:</td><td>$realmName</td></tr>
			<tr><td>Payment Type:</td><td>$Defs::paymentTypes{$paymentType}</td></tr>
			<tr><td>Payment Date:</td><td>$dtLog</td></tr>
			<tr><td>Total Payment:</td><td>\$$totalAmount</td></tr>
			<tr><td>Assoc:</td><td>$assocName</td></tr>
			<tr><td>Club:</td><td>$clubName</td></tr>
			<tr><td>Rego Form ID:</td><td>$rfID</td></tr>
		</table>
		<br><br>
		$body
	];
	return $body;


}
1;
