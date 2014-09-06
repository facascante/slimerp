#!/usr/bin/perl -w

#
# $Header: svn://svn/SWM/trunk/web/paypal.cgi 11005 2014-03-18 22:41:41Z fkhezri $
#

use DBI;
use CGI qw(:cgi escape unescape);

use strict;

use lib "RegoForm",'PaymentSplit';

use Lang;
use Utils;
use Payments;
use SystemConfig;
use ConfigOptions;
use Reg_common;
use Products;
use PageMain;
use CGI qw(param unescape escape);

use PayPal;
use Gateway_Common;

main();

sub main	{

	
	my $action = param('a') || 0;
	my $client = param('client') || 0;
	my $INtoken= param('token') || 0;
	my $external= param('ext') || 0;
	my $clientTransRefID= param('ci') || 0;
	my $encryptedID= param('ei') || 0;
	my $noheader= param('nh') || 0;
	my $formID= param('formID') || 0;
	my $session= param('session') || 0;
	my $compulsory= param('compulsory') || 0;
	
print STDERR "AAAAA: $action";
	my $db=connectDB();
	my %Data=();
	$Data{'db'}=$db;

	$Data{'formID'} = $formID;
	$Data{'sessionKey'} = $session;
	$Data{'CompulsoryPayment'} = $compulsory;
	
	my ($Order, $Transactions) = gatewayTransactions(\%Data, $clientTransRefID);
  $Data{'SystemConfig'}{'PaymentConfigID'} = 
		$Data{'SystemConfig'}{'PaymentConfigUsedID'} 
		||  $Data{'SystemConfig'}{'PaymentConfigID'};

	my %clientValues = getClient($client);
	$Data{'clientValues'} = \%clientValues;

	$Data{'db'}=$db;
	getDBConfig(\%Data);
 	my $assocID=getAssocID(\%clientValues) || '';
	$clientValues{'assocID'} = $assocID if ($assocID and $assocID =~ /^\d.*$/);
  $Data{'clientValues'} = \%clientValues;
  $Data{'SystemConfig'}=getSystemConfig(\%Data);
  my $lang   = Lang->get_handle('', $Data{'SystemConfig'}) || die "Can't get a language handle!";
  $Data{'lang'}=$lang;

  $Data{'LocalConfig'}=getLocalConfig(\%Data);


	#if (! $assocID or $assocID !~ /^\d.*$/)	{
    my $paymentType=0;
	{
		my $st = qq[
			SELECT 
				intEntityPaymentID, intPaymentType, intEntityLevel, tblTransLog.intRealmID
			FROM 
				tblTransLog LEFT JOIN tblEntity as E ON (intEntityPaymentID = intEntityID)
			WHERE
				intLogID = ?
			LIMIT 1
		];
		my $qry = $db->prepare($st);
		$qry->execute($clientTransRefID);
		my $TentityID= 0;
		my $entityType= 0;
        my $realmID=0;
        ($TentityID, $paymentType, $entityType, $realmID) = $qry->fetchrow_array();
		#$Data{'clientValues'}{'assocID'} = $assocID if ($assocID and $assocID > 0);
		#$clientValues{'assocID'} = $assocID if ($assocID and $assocID =~ /^\d.*$/);
        $Data{'Realm'} = $realmID if (! $Data{'Realm'});

	}
        # DO DATABASE THINGS
        #my $DataAccess_ref=getDataAccess(\%Data);
    #$Data{'Permissions'}=GetPermissions(
     # \%Data,
     # $Defs::LEVEL_ASSOC,
     # $assocID,
     # $Data{'Realm'},
     # $Data{'RealmSubType'},
     # $Defs::LEVEL_ASSOC,
     # 0,
    #);

     #   $Data{'DataAccess'}=$DataAccess_ref;

        $Data{'clientValues'}=\%clientValues;
#$Data{'clientValues'}{'assocID'} = $assocID if ($assocID and $assocID > 0);
        $client= setClient(\%clientValues);
  	$Data{'client'}=$client;

    my ($paymentSettings, undef) = getPaymentSettings(\%Data,$Order->{'PaymentType'}, $Order->{'PaymentConfigID'}, $external);
	$paymentSettings->{'PAYPAL'}=1;

    	my $header_css = $noheader ? ' #spheader {display:none;} ' : '';
        $Data{'noheader'}=$noheader;
    	$Data{'SystemConfig'}{'OtherStyle'} = "#pageholder { margin:0px;}#contentholder{margin-left:0;} $header_css";


	## Lets do a final check for 500 Internal Errors
	my $error='';
	{
		my $st_500 =qq[
			SELECT DISTINCT
	        	TXNLogs2.intTLogID
			FROM
			     tblTXNLogs as TXNLogs1
				LEFT JOIN tblTXNLogs as TXNLogs2 USING (intTXNID)
				LEFT JOIN tblTransLog as TL ON (TL.intLogID=TXNLogs2.intTLogID )
			WHERE
				TXNLogs1.intTLogID = ?
				AND TXNLogs2.intTLogID<>TXNLogs1.intTLogID
				AND strResponseCode='ERROR'
				AND TL.dtLog >= DATE_ADD(NOW(), INTERVAL -30 MINUTE)
				AND TL.strResponseText LIKE '500%'
				AND TL.intAmount=?
				AND TL.intAmount>0
			LIMIT 1
		];
		my $qry_500 = $db->prepare($st_500);
		$qry_500->execute($clientTransRefID, $Order->{'TotalAmount'});
		my $duplicateLogID = $qry_500->fetchrow_array() || 0;
		if ($duplicateLogID and $duplicateLogID > 0)	{
			$error = qq[
				<p>The SportingPulse Payments system has noticed an error with a previous payment attempt - although it appeared to give an error, it may have successfully been processed.<br>
				Please contact SportingPulse on 1300 139 970 before proceeding to prevent a possible double payment. We will check and confirm the status of the previous payment.<br>
				Payment Reference Number: $clientTransRefID</p>
			];
			$Order->{'Status'} = -1;
		}
	}

	if ($Order->{'Status'} != 0)	{
		$error = qq[There was an error] if ! $error;
		my $body  = qq[<div align="center" class="warningmsg" style="font-size:14px;">$error</div>];
		pageForm( 'Sportzware Membership', $body, $Data{'clientValues'}, q{}, \%Data);
	}
	elsif ($action eq 'P')	{
		## CALL SetExpressCheckoutAPI
print STDERR "DDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDD";
		my $body = payPalProcess(\%Data, $client, $paymentSettings, $clientTransRefID, $Order, $Transactions, $external);
		pageForm( 'Sportzware Membership', $body, $Data{'clientValues'}, q{}, \%Data) if $body;
		
	}
	elsif ($action eq 'C')	{
		my $msg = qq[<div align="center" class="warningmsg" style="font-size:14px;">You cancelled the Transaction</div>];
		my $body = displayPaymentResult(\%Data, $clientTransRefID, 1, $msg);
		$body .= qq[<br><p><a href="$Defs::base_url/main.cgi?client=$client&a=P_TXNLog_list&mode=p">Return to Membership System</a></p>] if ! $external;
		pageForm( 'Sportzware Membership', $body, $Data{'clientValues'}, q{}, \%Data);
	}
	elsif ($action eq 'S')	{
		my $body = payPalUpdate(\%Data, $paymentSettings, $client, $clientTransRefID, $INtoken, $Order, $external, $encryptedID);
		pageForm( 'Sportzware Membership', $body, $Data{'clientValues'}, q{}, \%Data);
	}
	disconnectDB($db);

}

1;
