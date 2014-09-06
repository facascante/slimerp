#!/usr/bin/perl -w

#
# $Header: svn://svn/SWM/trunk/web/admin/pms_500.cgi 8530 2013-05-22 05:57:47Z cgao $
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

use HTTP::Request::Common qw(POST);
use LWP::UserAgent;
use DeQuote;
use PaymentSplitMoneyLog;
use Payments;



main();

sub main    {
	my $db    = connectDB();

	my $a= param('a') || 'LIST';
	my $logID= param('logID') || 0;
	my $body = qq[<div><a href="pms_500.cgi?a=LIST">List Errors</a></div><br>];
	$body .= PMS_list500($db) if ($a eq 'LIST');
     	$body .= PMS_500check($db, $logID) if ($a eq 'CHECK');
	disconnectDB($db) if $db;

    	print_adminpageGen($body, "", "");
}

sub PMS_list500  {

    my ($db) = @_ ;

    my $st = qq[
        SELECT 
            TL.* ,
		strRealmName,
            DATE_FORMAT(dtLog,'%d/%m/%Y %H:%i:%s') AS DateLog
        FROM tblTransLog as TL
		INNER JOIN tblRealms as R ON (
			R.intRealmID=TL.intRealmID)
	WHERE intPaymentType=11 AND dtLog>="2010-12-1" AND strResponseText LIKE '500%'
    ORDER BY dtLog
     ];

           
	my $query = $db->prepare($st);
	$query->execute;

    my $count=0;
    my $body = qq[
        <table width="90%" class="listtable">
            <tr>
                <th>Payment LogID</td>
                <th>Realm</td>
                <th>Total Amount</td>
                <th>Date of Log</td>
                <th>&nbsp;</td>
            </tr>
    ];
	while (my $dref =$query->fetchrow_hashref())	{
        my $returned = $dref->{'intMassPayReturnedOnID'} ? qq[<span style="color:red;">REVERSED</span>] : 'No';
        $body .= qq[
            <tr>
                <td>$dref->{intLogID}</td>
                <td>$dref->{strRealmName}</td>
                <td>\$ $dref->{intAmount}</td>
                <td>$dref->{DateLog}</td>
                <td><a href="pms_500.cgi?a=CHECK&amp;logID=$dref->{'intLogID'}">check</a></td>
            </tr>
        ];
        $count++;
    }

    $body .= qq[</table>];

    $body = qq[Nothing on Hold] if ! $count;

    return $body;

}

sub PMS_500check	{

	my ($db, $logID) = @_;	

	my $st = qq[
		SELECT 
			strPrefix,
			intLogID
		FROM
			tblTransLog as TL
			INNER JOIN tblPaymentConfig as PC ON (
				PC.intPaymentConfigID = TL.intPaymentConfigUsedID
			)
		WHERE 
			intLogID=?
	];
		#OR intLogID IN (1464861, 1461994)
		#intLogID IN (1464861, 1461994)
	my $q = $db->prepare($st);
	$q->execute($logID);

	my $dbSysDate = getDBSysDate($db);
my $body='';

	while(my $dref = $q->fetchrow_hashref())	{
        	my $live=1;
		my $APIusername= $live  == 1 ? $Defs::PAYPAL_LIVE_USERNAME : $Defs::PAYPAL_DEMO_USERNAME;
     		my $APIpassword= $live == 1 ? $Defs::PAYPAL_LIVE_PASSWORD : $Defs::PAYPAL_DEMO_PASSWORD;
     		my $APIsignature= $live == 1 ? $Defs::PAYPAL_LIVE_SIGNATURE : $Defs::PAYPAL_DEMO_SIGNATURE;
     		my $APIurl= $live == 1 ? $Defs::PAYPAL_LIVE_URL_MASSPAY : $Defs::PAYPAL_DEMO_URL_MASSPAY;
		my %values = (
			USER => $APIusername,
			PWD => $APIpassword,
			SIGNATURE => $APIsignature,
			VERSION => $Defs::PAYPAL_VERSION,
			METHOD => 'TransactionSearch',
			INVNUM => qq[$dref->{'strPrefix'}-$dref->{intLogID}],
	                STARTDATE => '2010-1-1T10:00:00Z',
                	ENDDATE => '2012-1-1T11:00:00Z',
		);

		$body = payPalCheckTXN($db, $live, $dref->{'intLogID'}, \%values);
	}

	return $body;
}

sub payPalCheckTXN {

	my ($db, $live, $logID, $values_ref) = @_; 
    use Data::Dumper; 

	my $var=  Dumper($values_ref);

	my %output=();
	my $ua = LWP::UserAgent->new();
    my $APIurl= $live == 1 ? $Defs::PAYPAL_LIVE_URL_EXPRESS : $Defs::PAYPAL_DEMO_URL_EXPRESS;
	my $req = POST $APIurl, $values_ref;
	my $res= $ua->request($req);
	my $retval = $res->content() || '';
my $body = '';
	my $outputstr = '';
	for my $line (split /&/,$retval) {
		my ($k,$v)=split /=/,$line,2;
		$output{$k}=$v;
		$outputstr .= "$k => ".unescape($v).qq[<br>];
		#$body .= qq[$k|$v<br>];
	}
$body .= $outputstr;
	
	if ($output{'ACK'} =~ /Success/ and $output{'L_STATUS0'} =~ /Completed/)	{
		my $txn = qq[PayPal TransactionID: $output{'L_TRANSACTIONID0'} - PayPal CorrelationID: $output{'CORRELATIONID'}];
        	my $otherRef3 = qq[TRANSACTIONID:$output{'L_TRANSACTIONID0'}];
        	my $otherRef4 = qq[CORRELATIONID:$output{'CORRELATIONID'}];
		$body .=  qq[$txn|$otherRef3|$otherRef4<br><span style="color:green;font-size:15px;"><b>SUCCESSFULL</b></span><br> - $logID | $values_ref->{'INVNUM'}<br>];
	}
	else	{
		$body .= qq[<span style="font-size:15px;color:red;"><b>NOT SUCCESSFULL</b></span><br> - $logID | $values_ref->{'INVNUM'}];
	}
	return $body;
}
1;
