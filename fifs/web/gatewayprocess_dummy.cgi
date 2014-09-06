#!/usr/bin/perl -w

#
# $Header: svn://svn/SWM/trunk/web/nabprocess.cgi 8249 2013-04-08 08:14:07Z rlee $
#

use DBI;
use CGI qw(:cgi escape unescape);

use strict;

use Lang;
use Utils;
use Payments;
use SystemConfig;
use ConfigOptions;
use Reg_common;
use Products;
use PageMain;
use CGI qw(param unescape escape);

use NABGateway;
use Gateway_Common;
use TTTemplate;
use Data::Dumper;

use Crypt::CBC;

main();

sub main	{

	my $action = param('a') || 0;
	my $client = param('client') || 0;
	my $external= param('ext') || 0;
	my $logID= param('ci') || 0;
	my $encryptedID= param('ei') || 0;
	my $noheader= param('nh') || 0;
	my $chkv= param('chkv') || 0;
	my $formID= param('formID') || 0;
	my $session= param('session') || 0;

  warn "nabProcess $session ID::$session";
  my %returnVals = ();
  my $redirect =0;
  $returnVals{'GATEWAY_TXN_ID'}= param('txnid') || '';
  $returnVals{'GATEWAY_AUTH_ID'}= param('authid') || '';
  $returnVals{'GATEWAY_SIG'}= param('sig') || '';
  $returnVals{'GATEWAY_SETTLEMENT_DATE'}= param('settdate') || '';
  $returnVals{'GATEWAY_RESPONSE_CODE'}= param('rescode') || '';
  $returnVals{'GATEWAY_RESPONSE_TEXT'}= param('restext') || '';
  $returnVals{'ResponseCode'} = 'ERROR';

  $returnVals{'ResponseText'} = NABResponseCodes($returnVals{'GATEWAY_RESPONSE_CODE'});
  if ($returnVals{'GATEWAY_RESPONSE_CODE'} =~/^00|08|OK$/)  {
    $returnVals{'ResponseCode'} = 'OK';
  }
	
  my $db=connectDB();
	my %Data=();
	$Data{'db'}=$db;
    $Data{'formID'} = $formID;
	my $st = qq[
		INSERT IGNORE INTO tblTransLog_Counts
		(intTLogID, dtLog, strResponseCode)
		VALUES (?, NOW(), ?)
	];
	my $qry= $db->prepare($st);
	$qry->execute($logID, $returnVals{'GATEWAY_RESPONSE_CODE'});


	my ($Order, $Transactions) = gatewayTransactions(\%Data, $logID);
	 $Order->{'Status'} = $Order->{'TLStatus'} >=1 ? 1 : 0;
  $Data{'SystemConfig'}{'PaymentConfigID'} = $Data{'SystemConfig'}{'PaymentConfigUsedID'} ||  $Data{'SystemConfig'}{'PaymentConfigID'};

  my %clientValues = getClient($client);
	$clientValues{'assocID'} = $Order->{'AssocID'} if ($Order->{'AssocID'} and $Order->{'AssocID'}>0 and $clientValues{'assocID'} <= 0);
	$clientValues{'clubID'} = $Order->{'ClubID'} if ($Order->{'ClubID'} and $Order->{'ClubID'}>0 and $clientValues{'clubID'} <= 0);

  $Data{'clientValues'} = \%clientValues;
  $Data{'sessionKey'} = $session;
  getDBConfig(\%Data);
  $Data{'SystemConfig'}=getSystemConfig(\%Data);
  my $lang   = Lang->get_handle('', $Data{'SystemConfig'}) || die "Can't get a language handle!";
  $Data{'lang'}=$lang;

  my ($paymentSettings, undef) = getPaymentSettings(\%Data,$Order->{'PaymentType'}, $Order->{'PaymentConfigID'}, $external);

  $Data{'clientValues'}=\%clientValues;
  $client= setClient(\%clientValues);
  $Data{'client'}=$client;

  {
    my $chkvalue= param('rescode') . $Order->{'TotalAmount'}. $logID; ## NOTE: Different to one being sent
    my $m;
    $m = new MD5;
    $m->reset();
    $m->add($paymentSettings->{'gatewaySalt'}, $chkvalue);
    $chkvalue = $m->hexdigest();
    warn "chkv VS. chkvalue :: $chkv :::::  $chkvalue ";
    $Order->{'Status'} = -1 if ($chkv ne $chkvalue);
  }
   my $body='';
	if ($Order->{'Status'} != 0)	{
		$body  = qq[<div align="center" class="warningmsg" style="font-size:14px;">There was an error</div>BB$Order->{'Status'} $Order->{'AssocID'}];
		if ($Order->{'AssocID'})	{
			my $template_ref = getPaymentTemplate(\%Data, $Order->{'AssocID'});
			my $templateBody = $template_ref->{'strFailureTemplate'} || 'payment_failure.templ';
      my $trans_ref = gatewayTransLog(\%Data, $logID);
      if ($Order->{'Status'} == 1)	{
				$trans_ref->{'AlreadyPaid'} = 1;
				$trans_ref->{'CC_SOFT_DESC'} = $paymentSettings->{'gatewayCreditCardNote'} || '';
		  	$templateBody = $template_ref->{'strSuccessTemplate'} || 'payment_success.templ';
      }
      $trans_ref->{'headerImage'}= $template_ref->{'strHeaderHTML'} || '';
      my $result = runTemplate(
            undef,
            $trans_ref, ,
            'payment/'.$templateBody
      );
      $body = $result if($result);
		}
	}
	elsif ($action eq 'S')	{
		$body = NABUpdate(\%Data, $paymentSettings, $client, \%returnVals, $logID, $Order->{'AssocID'}); #, $Order, $external, $encryptedID);
	}
	disconnectDB($db);

 	print "Content-type: text/html\n\n";
  	print $body;
	
	
	

#  my $body=q{};
#    
#   #my $userData = finalize_registration(\%Data, $logID); #, $Order, $external, $encryptedID);
#   # warn "Status:: $Order->{'Status'}";
#  warn "ORDER STATUS:: $Order->{'Status'}//gatewayCreditCardNote:: $paymentSettings->{'gatewayCreditCardNote'}";
##return $body;
#    my $cipher = Crypt::CBC->new( -key    => "regoKey",
#                                  -cipher => 'Crypt::Blowfish' );
#    my $state = $cipher->encrypt_hex('bb' );
#
#    my $state_decoded = $cipher->decrypt_hex($state);
#
#    my $assocID = $clientValues{'assocID'};
#     #my $redirect_url = qq[$Defs::base_url/regoform.cgi?formID=$formID&amp;session=$sessionkey&amp;aID=$assocID];
#    #print redirect(-url=>$redirect_url);
#	if ($Order->{'Status'} != 0)	{
#	    $body  = qq[<div align="center" class="warningmsg" style="font-size:14px;">here was an error</div>BB$Order->{'Status'} $Order->{'AssocID'}];
#	    if ($Order->{'AssocID'})	{
#		my $template_ref = getPaymentTemplate(\%Data, $Order->{'AssocID'});
#		my $templateBody = $template_ref->{'strFailureTemplate'} || 'payment_failure.templ';
#		my $trans_ref = gatewayTransLog(\%Data, $logID);
#		if ($Order->{'Status'} == 1)	{
#			  if ($formID) {
#			       $redirect = 1;
#			  } else{
#			  
#				warn "ALREADY PAID:$logID";
#				#my $userData = get_user_data($                
#				$trans_ref->{'AlreadyPaid'} = 1;
#				$trans_ref->{'CC_SOFT_DESC'} = $paymentSettings->{'gatewayCreditCardNote'} || '';
#				print STDERR Dumper($trans_ref);
#				$templateBody = $template_ref->{'strSuccessTemplate'} || 'payment_success.templ';
#			  }
#		}
#		if ($formID) {
#		    $trans_ref->{'headerImage'}= $template_ref->{'strHeaderHTML'} || '';
#		    my $result = runTemplate(
#			  undef,
#			  $trans_ref, ,
#			  'payment/'.$templateBody
#		    );
#		    $body = $result if($result);
#		}
#	    }
#	}
#	elsif ($action eq 'S')	{
#		warn "Action in nab process is S";
#		$body = NABUpdate(\%Data, $paymentSettings, $client, \%returnVals, $logID, $Order->{'AssocID'}); #, $Order, $external, $encryptedID);
#		
#	}
#	disconnectDB($db);
#	my $typeofBody = ref($body);
#	warn "Type Od Body :: $typeofBody";
#	
#	#print STDERR Dumper($body);
#	
#	
#    if(ref($body) eq 'HASH' and $body->{'RegoFinal'} eq "1" or $redirect){ # is it's coming from rego form then it needs to load regofomr.cgi
#	warn "BODY == 1";
#        $st = qq[SELECT strSessionKey FROM tblTransLog WHERE intLogID = ?];
#	#warn "SESSION in tblTransLog:: $st::$logID ";
#        $qry= $db->prepare($st);
#        $qry->execute($logID);
#        my $sessionkey = $qry->fetchrow_array() || 0;
#        
#        my $redirect_url = qq[$Defs::base_url/regoform.cgi?aID=$assocID&amp;session=$sessionkey&amp;logID=$logID&amp;formID=$formID];
#        print redirect (-url=>$redirect_url);
#    }
#    else{
#        #FF redirect instead of printing the html
# 	    print "Content-type: text/html\n\n";
#  	    print $body;
#    }

}

1;
