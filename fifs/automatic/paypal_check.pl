#!/usr/bin/perl

#
# $Header: svn://svn/SWM/trunk/automatic/paypal_check.pl 8250 2013-04-08 08:24:36Z rlee $
#

use strict;

use lib "..","../web","../web/comp";

use Defs;
use Utils;
use DBI;
use HTTP::Request::Common qw(POST);
use LWP::UserAgent;
use CGI qw(unescape);

main();

sub main	{

	my %Data = ();
	my $db = connectDB();
	$db->{mysql_auto_reconnect} = 1;
        $db->{wait_timeout} = 3700;
        $db->{mysql_wait_timeout} = 3700;
	$Data{'db'} = $db;

	my $st = qq[
		SELECT 
			intRuleID,
			intRealmID,
			intSubTypeID
		FROM
			tblPaymentSplitRule 
		WHERE 
			strFinInst = 'PAYPAL_NAB'
			AND intRealmID NOT IN (35)
		ORDER BY intSubTypeID DESC
	];
	my $q = $db->prepare($st);
	$q->execute();

	my $dbSysDate = getDBSysDate($db);

	while(my $dref = $q->fetchrow_hashref())	{
		my $ruleID = $dref->{'intRuleID'};

		my $subRealmWHERE = '';
		$subRealmWHERE = qq[ AND ML.intRealmSubTypeID = $dref->{'intSubTypeID'}] if $dref->{'intSubTypeID'}; 

		my $st_ml = qq[
			SELECT 	
				DISTINCT TL.*
			FROM 
				tblMoneyLog as ML
				INNER JOIN tblTransLog as TL ON (TL.intLogID = ML.intTransLogID)
			WHERE 
				ML.intRuleID = $ruleID
				AND ML.intRealmID = $dref->{'intRealmID'}
				AND ML.dtEntered<= DATE_ADD(CURRENT_DATE(), INTERVAL -2 DAY)
				$subRealmWHERE
	            		AND ML.intExportBankFileID = 0
				AND ML.intLogType IN (1,4,6)
				AND TL.intPaymentType IN ($Defs::PAYMENT_ONLINEPAYPAL)
                		AND TL.intExportOK=0
		];
					#AND TL.intLogID IN (1408395,1407904)

		my $qry_ml = $db->prepare($st_ml);
		$qry_ml->execute();
        my $live=1;
		my $APIusername= $live  == 1 ? $Defs::PAYPAL_LIVE_USERNAME : $Defs::PAYPAL_DEMO_USERNAME;
     	my $APIpassword= $live == 1 ? $Defs::PAYPAL_LIVE_PASSWORD : $Defs::PAYPAL_DEMO_PASSWORD;
     	my $APIsignature= $live == 1 ? $Defs::PAYPAL_LIVE_SIGNATURE : $Defs::PAYPAL_DEMO_SIGNATURE;
     	my $APIurl= $live == 1 ? $Defs::PAYPAL_LIVE_URL_MASSPAY : $Defs::PAYPAL_DEMO_URL_MASSPAY;
		my %values=();
		my %header = (
			USER => $APIusername,
			PWD => $APIpassword,
			SIGNATURE => $APIsignature,
			VERSION => $Defs::PAYPAL_VERSION,

			METHOD => 'GetTransactionDetails',
		);

		while (my $mlref = $qry_ml->fetchrow_hashref())	{
		    	%values=%header;
		    	my $otherRef1 = $mlref->{'strOtherRef3'};
            		$otherRef1 =~ s/TRANSACTIONID://;
		    	$values{'TRANSACTIONID'} = $otherRef1 || next;
			payPalCheckTXN($db, $live, $mlref->{'intLogID'}, \%values);
		}
	}

	exit;
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
	my $outputstr = '';
	for my $line (split /&/,$retval) {
		my ($k,$v)=split /=/,$line,2;
		$output{$k}=$v;
		$outputstr .= "$k => ".unescape($v)."\n";
	}
	
	if($output{'PAYMENTSTATUS'} =~/^Completed/)	{
        	updateOKtoExport($db, $logID);
	}
}

sub updateOKtoExport   {

	my ($db, $logID) = @_;

    $logID || return;
	my $st = qq[
		UPDATE tblTransLog
        SET intExportOK=1
        WHERE intLogID=$logID
        LIMIT 1
	];
	
	$db->do($st);


}
1;
