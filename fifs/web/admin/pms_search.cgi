#!/usr/bin/perl -w

#
# $Header: svn://svn/SWM/trunk/web/admin/pms_search.cgi 8530 2013-05-22 05:57:47Z cgao $
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

	my $a= param('a') || '';
	my $body = '';
	$body .= PMSSearchForm($db) if ! $a;
	$body .= runPMSSearch($db) if ($a eq 'RUN');
	disconnectDB($db) if $db;

    	print_adminpageGen($body, "", "");
}

sub PMSSearchForm	{

	my ($db) = @_;

	my $body .= qq[
		<form name="pms_search" action="pms_search.cgi" method="post">	
			<p>Select fields to run PMS Report by</p>
			<br>
			<table>
				<tr>
					<td>Currency:</td>
					<td><select name="d_currency">
						<option SELECTED value="">--All Currencies</option>
						<option value="AUD">AUD</option>
						<option value="NZD">NZD</option>
						</select>
					</td>
				</tr>
				<tr>
					<td>PAYPAL TRANSACTIONID:</td>
					<td><input type="text" name="d_paypaltxn" value="" size="20"></td>
				</tr>
				<tr>
					<td>SP Payment Log ID:</td>
					<td><input type="text" name="d_tlogID" value="" size="20"></td>
				</tr>
				<tr>
					<td>Date PAID (from):</td>
					<td><input type="text" name="d_paidFrom" value="" size="20"> (yyyy-mm-dd)</td>
				</tr>
				<tr>
					<td>Date PAID (to):</td>
					<td><input type="text" name="d_paidTo" value="" size="20"> (yyyy-mm-dd)</td>
				</tr>
				<tr>
					<td>MYOB Run ID (file number):</td>
					<td><input type="text" name="d_myob" value="" size="20"></td>
				</tr>
				<tr>
					<td>Log Type ID:</td>
					<td><input type="text" name="d_logType" value="" size="20"></td>
				</tr>
				<tr>
					<td>MassPay Email:</td>
					<td><input type="text" name="d_email" value="" size="20"></td>
				</tr>
				<tr>
					<td>Realm ID:</td>
					<td><input type="text" name="d_realm" value="" size="20"></td>
				</tr>
				<tr>
					<td>Date Masspay (from):</td>
					<td><input type="text" name="d_mpFrom" value="" size="20"> (yyyy-mm-dd)</td>
				</tr>
				<tr>
					<td>Date Masspay (to):</td>
					<td><input type="text" name="d_mpTo" value="" size="20"> (yyyy-mm-dd)</td>
				</tr>
			</table>
			<input type="hidden" name="a" value="RUN">
			<input type="submit" name="submit" value="Run Report">
		</form>
	];

}

sub runPMSSearch	{

	my ($db) = @_;

	my $realm = param("d_realm") || 0;
	my $currency= param("d_currency") || '';
	my $PPtxnID= param("d_paypaltxn") || '';
	my $tLogID= param("d_tlogID") || '';
	my $dtFrom= param("d_paidFrom") || '';
	my $dtTo= param("d_paidTo") || '';
	my $myob= param("d_myob") || '';
	my $logType= param("d_logType") || '';
	my $dtMPFrom= param("d_mpFrom") || '';
	my $dtMPTo= param("d_mpTo") || '';
	my $email= param("d_email") || '';

	my $realmWHERE = ($realm) 
		? qq[ AND ML.intRealmID = $realm]
		: '';

	my $currencyWHERE= ($currency) 
		? qq[ AND ML.strCurrencyCode= "$currency"]
		: '';

	my $dtFromWHERE = ($dtFrom) 
		? qq[ AND ML.dtEntered >= "$dtFrom"]
		: '';

	my $dtToWHERE = ($dtTo) 
		? qq[ AND ML.dtEntered <= "$dtTo"]
		: '';

	my $PPtxnWHERE= ($PPtxnID) 
		? qq[ AND TL.strOtherRef3 ="TRANSACTIONID:$PPtxnID"]
		: '';

	my $myobWHERE= ($myob) 
		? qq[ AND ML.intMYOBExportID = $myob ]
		: '';

	my $tLogWHERE= ($tLogID) 
		? qq[ AND TL.intLogID= $tLogID]
		: '';

	my $logTypeWHERE= ($logType) 
		? qq[ AND ML.intLogType=$logType]
		: '';

	my $dtMPFromWHERE = ($dtMPFrom) 
		? qq[ AND BFE.dtRun >= "$dtMPFrom"]
		: '';

	my $dtMPToWHERE = ($dtMPTo) 
		? qq[ AND BFE.dtRun <= "$dtMPTo 23:59:59"]
		: '';

	my $emailWHERE = ($email) 
		? qq[ AND ML.strMPEmail = "$email"]
		: '';


	my $st = qq[
		SELECT 
			ML.intRealmID,
			ML.intRealmSubTypeID,
			ML.intAssocID,
			ML.intClubID,
			ML.intTransLogID,
			strRealmName, 
			strSubTypeName, 
			A.strName as AssocName, 
			C.strName as ClubName, 
			curMoney,
			TL.intAmount,
			intLogType,
			ML.intExportBankFileID,
			intMyobExportID,
			strOtherRef3,
			strFrom,
			DATE_FORMAT(BFE.dtRun,'%d/%m/%Y') as dtRunFORMATTED,
			DATE_FORMAT(ML.dtEntered,'%d/%m/%Y') as dtEnteredFORMATTED,
            strMPEmail
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
			LEFT JOIN tblExportBankFile as BFE ON (
                		BFE.intExportBSID= ML.intExportBankFileID
            		)
		WHERE 
			TL.intPaymentType IN ($Defs::PAYMENT_ONLINENAB, $Defs::PAYMENT_ONLINEPAYPAL)
			$realmWHERE
			$dtFromWHERE
			$dtToWHERE
			$myobWHERE
			$tLogWHERE
			$currencyWHERE
			$PPtxnWHERE
			$logTypeWHERE
			$dtMPFromWHERE
			$dtMPToWHERE
			$emailWHERE
		ORDER BY 
			ML.dtEntered DESC,
			ML.intLogType
	];

	my $body = qq[
<table>
	<tr>
		<th>PP TRANSACTIONID</th>	
		<th>SP Payment ID</th>	
		<th>Payment Date</th>	
		<th>Log Type</th>	
		<th>Realm Name</th>	
		<th>Sub Realm Name</th>	
		<th>Assoc Name</th>	
		<th>Club Name</th>	
		<th>MYOB Run ID</th>	
		<th>MassPay Email</th>	
		<th>MassPay Run ID</th>	
		<th>Masspay Date</th>	
		<th>Log Line Amount</th>	
		<th>Order Amount</th>	
	</tr>
	];

	my $query = $db->prepare($st);
	$query->execute;

	my $countTrans=0;
	my $sumLineAmount=0;
	while (my $dref =$query->fetchrow_hashref())	{
		my $ppRef = $dref->{'strOtherRef3'} || '';
		$ppRef =~ s/TRANSACTIONID://;
		$body .= qq[
			<tr>
				<td>$ppRef</td>
				<td>$dref->{'intTransLogID'}</td>
				<td>$dref->{'dtEnteredFORMATTED'}</td>
				<td>$dref->{'intLogType'} ($dref->{'strFrom'})</td>
				<td>$dref->{'strRealmName'}</td>
				<td>$dref->{'strSubTypeName'}</td>
				<td>$dref->{'AssocName'}</td>
				<td>$dref->{'ClubName'}</td>
				<td>$dref->{'intMyobExportID'}</td>
				<td>$dref->{'strMPEmail'}</td>
				<td>$dref->{'intExportBankFileID'}</td>
				<td>$dref->{'dtRunFORMATTED'}</td>
				<td align="center">\$$dref->{'curMoney'}</td>
				<td align="center">\$$dref->{'intAmount'}</td>
			</tr>
		];
		$sumLineAmount+= $dref->{'curMoney'};
	}

	$body .= qq[</table>];
	#$body .= qq[<p>Total Number: $countTrans</p>];
	$body .= qq[<p>Total Line Amount Money: \$$sumLineAmount</p>];
	return $body;


}
1;
