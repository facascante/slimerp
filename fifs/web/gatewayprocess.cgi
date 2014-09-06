#!/usr/bin/perl -w

#
# $Header: svn://svn/SWM/trunk/web/nabprocess.cgi 11110 2014-03-25 01:24:21Z fkhezri $
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
use PageMain;

main();

sub main {

    my $action = param('a') || 0;
    my $client = param('client') || 0;
    my $external= param('ext') || 0;
    my $logID= param('ci') || 0;
    my $encryptedID= param('ei') || 0;
    my $noheader= param('nh') || 0;
    my $chkv= param('chkv') || 0;
    my $formID= param('formID') || 0;
    my $session= param('session') || 0;
    my $compulsory= param('compulsory') || 0;

    my %returnVals = ();
    $returnVals{'GATEWAY_TXN_ID'}= param('txnid') || '';
    $returnVals{'GATEWAY_AUTH_ID'}= param('authid') || '';
    $returnVals{'GATEWAY_SIG'}= param('sig') || '';
    $returnVals{'GATEWAY_SETTLEMENT_DATE'}= param('settdate') || '';
    $returnVals{'GATEWAY_RESPONSE_CODE'}= param('rescode') || '';
    $returnVals{'GATEWAY_RESPONSE_TEXT'}= param('restext') || '';
    $returnVals{'ResponseCode'} = 'ERROR';

    use Data::Dumper;
    $returnVals{'ResponseText'} = NABResponseCodes($returnVals{'GATEWAY_RESPONSE_CODE'});
    if ($returnVals{'GATEWAY_RESPONSE_CODE'} =~/^00|08|OK$/)  {
        $returnVals{'ResponseCode'} = 'OK';
    }
#print STDERR Dumper(\%returnVals);
    print STDERR "NAB FOR $logID | $returnVals{'GATEWAY_RESPONSE_CODE'} | $returnVals{'GATEWAY_RESPONSE_TEXT'}\n";

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

    my $lang   = Lang->get_handle('', $Data{'SystemConfig'}) || die "Can't get a language handle!";
    $Data{'lang'}=$lang;
    my %clientValues = getClient($client);
    $clientValues{'clubID'} = $Order->{'ClubID'} if ($Order->{'ClubID'} and $Order->{'ClubID'}>0 and $clientValues{'clubID'} <= 0);

    $Data{'clientValues'} = \%clientValues;
    my $realm = $Data{'Realm'};
    if(!$realm){
        my $st = qq[
        SELECT intRealmID FROM tblEntity WHERE intEntityID= ?
        ];
        my $qry= $db->prepare($st);
        $qry->execute($Data->{'clientValues'}{'clubID'});

        $realm = $qry->fetchrow_array() || 0;
        $Data{'Realm'}= $realm;
    }

    getDBConfig(\%Data);
    $Data{'SystemConfig'}=getSystemConfig(\%Data);
    my ($paymentSettings, undef) = getPaymentSettings(\%Data,$Order->{'PaymentType'}, $Order->{'PaymentConfigID'}, $external);

    $Data{'clientValues'}=\%clientValues;
    $client= setClient(\%clientValues);
    $Data{'client'}=$client;
    $Data{'sessionKey'} = $session;
    $Data{'CompulsoryPayment'} = $compulsory;
    #{
    #    my $chkvalue= $Order->{'TotalAmount'}. $logID. $Order->{'Currency'};
    #    my $m;
    #    $m = new MD5;
    #    $m->reset();
    #    $m->add($paymentSettings->{'gatewaySalt'}, $chkvalue);
    #    $chkvalue = $m->hexdigest();
    #    $Order->{'Status'} = -1 if ($chkv ne $chkvalue);
    #}
    {
     my $chkvalue= param('rescode') . $Order->{'TotalAmount'}. $logID; ## NOTE: Different to one being sent
     my $m;
     $m = new MD5;
     $m->reset();
     $m->add($paymentSettings->{'gatewaySalt'}, $chkvalue);
     $chkvalue = $m->hexdigest();
     $Order->{'Status'} = -1 if ($chkv ne $chkvalue);
   }

    my ($html_head, $page_header, $page_navigator, $paypal, $powered) = getPageCustomization(\%Data);
    
    my $body='';
    if ($Order->{'Status'} != 0) {
        $body  = qq[<div align="center" class="warningmsg" style="font-size:14px;">here was an error</div>BB$Order->{'Status'}];
        if ($Order->{'AssocID'}) {
            my $template_ref = getPaymentTemplate(\%Data, $Order->{'AssocID'});
            my $templateBody = $template_ref->{'strFailureTemplate'} || 'payment_failure.templ';
            my $trans_ref = gatewayTransLog(\%Data, $logID);
            if ($Order->{'Status'} == 1) {
                $trans_ref->{'AlreadyPaid'} = 1;
                $trans_ref->{'CC_SOFT_DESC'} = $paymentSettings->{'gatewayCreditCardNote'} || '';
                $templateBody = $template_ref->{'strSuccessTemplate'} || 'payment_success.templ';
            }
            my $title = '';
            $trans_ref->{'title'} = $title;
            $trans_ref->{'head'} = $html_head;
            $trans_ref->{'page_begin'} = qq[ 
                <div id="global-nav-wrap">
                $page_navigator
                </div>
            ];  
            $trans_ref->{'page_header'} = $page_header;
            $trans_ref->{'page_content'} = $body;
            $trans_ref->{'page_footer'} = qq [
                $paypal
                $powered
            ];  
            $trans_ref->{'page_end'} = qq [
                <script type="text/javascript">
                $Data{'TagManager'}
                </script>
            ];

            $trans_ref->{'headerImage'}= $template_ref->{'strHeaderHTML'} || '';
            my $result = runTemplate(
                undef,
                $trans_ref, ,
                'payment/'.$templateBody
            );
            $body = $result if($result);
        }
    }
    elsif ($action eq 'S') {
        $body = NABUpdate(\%Data, $paymentSettings, $client, \%returnVals, $logID, $Order->{'AssocID'}); #, $Order, $external, $encryptedID);
    }
    disconnectDB($db);

    print "Content-type: text/html\n\n";
    print $body;
}

1;
