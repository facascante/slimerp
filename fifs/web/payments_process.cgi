#!/usr/bin/perl -w

#
# $Header: svn://svn/SWM/trunk/web/payments_process.cgi 8249 2013-04-08 08:14:07Z rlee $
#

use DBI;
use CGI qw(:cgi escape unescape);

use strict;

use lib "..",".",'PaymentSplit';
#use lib "/u/rego_v6","/u/rego_v6/web";

use Lang;
use Utils;
use Date::Calc qw(:all);
use DeQuote;

use MD5;
use Payments;
use Reg_common;

use SystemConfig;
use ConfigOptions;
use Email;
use Products;

main();


sub main	{

	my $client = param('client') || 0;
	my $clientTransRefID= param('ci') || 0;
    my $paymentType=0;

warn("AAAAAAAAAAAAAAAAAAAA$clientTransRefID");
    my $db=connectDB();
	my %Data=();
	my $st = qq[
		SELECT T.intRealmSubTypeID, T.intRealmID, TL.intPaymentConfigID, TL.intPaymentConfigID, intPaymentType
			FROM tblTransactions as T
			INNER JOIN tblTXNLogs as TLogs ON (T.intTransactionID = TLogs.intTXNID and TLogs.intTLogID = ?)
			INNER JOIN tblTransLog as TL ON (TL.intLogID = TLogs.intTLogID )
		LIMIT 1
	];
    my $qry= $db->prepare($st) or query_error($st);
    $qry->execute($clientTransRefID) or query_error($st);
	($Data{'RealmSubType'}, $Data{'Realm'}, $Data{'SystemConfig'}{'PaymentConfigID'}, $Data{'SystemConfig'}{'PaymentConfigUsedID'}, $paymentType) = $qry->fetchrow_array();
	$Data{'SystemConfig'}{'PaymentConfigID'} = $Data{'SystemConfig'}{'PaymentConfigUsedID'} ||  $Data{'SystemConfig'}{'PaymentConfigID'};
	my $paymentConfigID = $Data{'SystemConfig'}{'PaymentConfigID'} || 0;
	
	### NEED TO CREATE $DATA !!!
    my $target='main.cgi';
    $Data{'target'}=$target;
    my %clientValues = getClient($client);
    $Data{'clientValues'} = \%clientValues;

	$Data{'db'}=$db;
	getDBConfig(\%Data);
  $Data{'SystemConfig'}=getSystemConfig(\%Data);
  my $lang   = Lang->get_handle('', $Data{'SystemConfig'}) || die "Can't get a language handle!";
  $Data{'lang'}=$lang;

  $Data{'LocalConfig'}=getLocalConfig(\%Data);
  my $assocID=getAssocID(\%clientValues) || '';
        # DO DATABASE THINGS

        my $resultHTML = '';
        my $pageHeading= '';
        my $ID=getID(\%clientValues);
        my $report=0;
        $Data{'clientValues'}=\%clientValues;
        $client= setClient(\%clientValues);
  $Data{'client'}=$client;

	my $body = '';
	## GENERAL VARIABLES
	my $responsecode= param('responsecode') || '';
	my $responsetext= param('responsetext') || '';
	my $txn = param('txn') || 0;
	my $chkv = param('chkv') || 0;

	my $settlement_date = param('dtSettlement') || '';
	$Data{'SystemConfig'}{'PaymentConfigID'} = $paymentConfigID;
	
	my ($paymentSettings, undef) = getPaymentSettings(\%Data,$paymentType, $paymentConfigID, 0);

	my $intLogID = processTransLog($db, $txn, $responsecode, $responsetext, $clientTransRefID, $paymentSettings, $chkv, $settlement_date,'', '', '', '', '');
warn("ABOUT TO BEALL OK FOR $intLogID $paymentType");
	if ($intLogID and ($responsecode eq "00" or $responsecode eq "08" or $responsecode eq "OK" or $responsecode eq "1"))    {
warn("ALL OK");
		UpdateCart(\%Data, $paymentSettings, $client, $txn, $responsecode, $clientTransRefID);
		#EmailPaymentConfirmation(\%Data, $paymentSettings, $clientTransRefID, $client);
        #product_apply_transaction(\%Data,$intLogID);
	}

disconnectDB($db);
print qq[Content-type: text/html\n\n] if ! $body;

}
exit;

