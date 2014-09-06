#!/usr/bin/perl -w

#
# $Header: svn://svn/SWM/trunk/web/admin/pms_doubleups.cgi 8530 2013-05-22 05:57:47Z cgao $
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

	my $dtFrom= param('dtFrom') || '';
	my $body = runPMSReport($db, $dtFrom);
	disconnectDB($db) if $db;

    	print_adminpageGen($body, "", "");
}


sub runPMSReport	{

	my ($db, $dtFrom) = @_;

	my $dtFromWHERE = ($dtFrom) 
		? qq[ AND TL.dtLog >= "$dtFrom"]
		: '';

	my $st = qq[
		SELECT 
			intTLogID , 
			MAX(TL.dtLog) as OrderDate, 
			COUNT(intTLogID ) as COUNTNUM , 
			intAssocTypeID, 
			a.intRealmID, 
			a.strName, 
			strRealmName, 
			strSubTypeName ,
			TL.intAmount
		FROM 
			tblTransLog_Counts as T 
			INNER JOIN tblTransLog as TL ON (TL.intLogID = intTLogID) 
			INNER JOIN tblAssoc as a ON (a.intAssocID = TL.intAssocPaymentID) 
			INNER JOIN tblRealms as R ON (R.intRealmID=a.intRealmID) 
			LEFT JOIN tblRealmSubTypes as RS ON (RS.intSubTypeID=intAssocTypeID) 
		WHERE 
			T.strResponseCode IN ('00', '08', '11') 
			$dtFromWHERE 
		GROUP BY intTLogID 
		HAVING COUNTNUM>1;
	];

	my $body = qq[
<table>
	<tr>
		<th>Payment ID</th>	
		<th>Count of Double Ups</th>	
		<th>Realm Name</th>	
		<th>Sub Realm Name</th>	
		<th>Assoc Name</th>	
		<th>Order Amount</th>	
		<th>Order Date</th>	
	</tr>
	];

	my $query = $db->prepare($st);
	$query->execute;


	my $countTrans=0;
	my $sumMoney=0;
	while (my $dref =$query->fetchrow_hashref())	{
		$body .= qq[
			<tr>
				<td>$dref->{'intTLogID'}</td>
				<td>$dref->{'COUNTNUM'}</td>
				<td>$dref->{'strRealmName'}</td>
				<td>$dref->{'strSubTypeName'}</td>
				<td>$dref->{'strName'}</td>
				<td>\$$dref->{'intAmount'}</td>
				<td>$dref->{'OrderDate'}</td>
			</tr>
		];
	}

	$body .= qq[</table>];
	return $body;


}
1;
