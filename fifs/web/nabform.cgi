#!/usr/bin/perl -w

#
# $Header: svn://svn/SWM/trunk/web/nabform.cgi 11004 2014-03-18 22:21:37Z dhanslow $
#

use DBI;
use CGI qw(:cgi escape unescape);

use strict;

use lib '.', '..', "comp", 'RegoForm', "dashboard", "RegoFormBuilder",'PaymentSplit', "user";

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
use NABGateway;
use TTTemplate;
use Log;
use Data::Dumper;
use PageMain;

main();

sub main	{

    my $action = param('a') || 0;
    my $client = param('client') || 0;
    my $external= param('ext') || 0;
    my $clientTransRefID= param('ci') || 0;
    my $encryptedID= param('ei') || 0;
    my $noheader= param('nh') || 0;
    my $chkv= param('chkv') || 0;
    my $formID= param('formID') || 0;
    my $session= param('session') || 0;
    my $compulsory= param('compulsory') || 0;
    my %Data=();
warn("######$action");

    my %clientValues = getClient($client);
    $Data{'clientValues'} = \%clientValues;

    my $db=connectDB();
    $Data{'db'}=$db;

    ( $Data{'Realm'}, $Data{'RealmSubType'} ) = getRealm( \%Data );
    getDBConfig( \%Data );
    $Data{'SystemConfig'} = getSystemConfig( \%Data );
    $Data{'LocalConfig'}  = getLocalConfig( \%Data );
    my $assocID = getAssocID( \%clientValues ) || '';


    $Data{'formID'} = $formID;
    $Data{'sessionKey'} = $session;
    $Data{'CompulsoryPayment'} = $compulsory;
    my ($Order, $Transactions) = gatewayTransactions(\%Data, $clientTransRefID);
    $Order->{'Status'} = $Order->{'TLStatus'} >=1 ? 1 : 0;

    $Data{'SystemConfig'}{'PaymentConfigID'} = $Data{'SystemConfig'}{'PaymentConfigUsedID'} ||  $Data{'SystemConfig'}{'PaymentConfigID'};
    my $paymentConfigUsedID = $Data{'SystemConfig'}{'PaymentConfigUsedID'} || 0;
    my $paymentConfigID = $Data{'SystemConfig'}{'PaymentConfigID'} || 0;

    my $lang   = Lang->get_handle('', $Data{'SystemConfig'}) || die "Can't get a language handle!";
    $Data{'lang'}=$lang;
    $Data{'db'}=$db;
    getDBConfig(\%Data);
    $assocID=getAssocID(\%clientValues) || '';
    # DO DATABASE THINGS
    my $DataAccess_ref=getDataAccess(\%Data);
    $Data{'Permissions'}=GetPermissions(\%Data, $assocID, $Defs::LEVEL_ASSOC,$Data{'Realm'});
    $Data{'DataAccess'}=$DataAccess_ref;

    $Data{'clientValues'}=\%clientValues;
    $client= setClient(\%clientValues);
    $Data{'client'}=$client;

    $Data{'SystemConfig'}{'PaymentConfigID'} = $paymentConfigUsedID || $paymentConfigID;
    my $paymentSettings = getPaymentSettings(\%Data, $Defs::PAYMENT_ONLINENAB, 0, $external);
    $paymentSettings->{'NAB'}=1;

    my $header_css = $noheader ? ' #spheader {display:none;} ' : '';
    $Data{'noheader'}=$noheader;
    $Data{'SystemConfig'}{'OtherStyle'} = "#pageholder { margin:0px;}#contentholder{margin-left:0;} $header_css";

    DEBUG("DDDN", Dumper($Data{'SystemConfig'}{'Header'}));
    my $m;
    my $chkvalue= $Order->{'TotalAmount'}. $clientTransRefID. $paymentSettings->{'currency'};
    $m = new MD5;
    $m->reset();
    $m->add($paymentSettings->{'gatewaySalt'}, $chkvalue);
    $chkvalue = $m->hexdigest();
    if ($chkv ne $chkvalue)	{
        $Order->{'Status'} = -1;
        $Order->{'TransLogStatus'} = -1;
    }

    my $template_ref = getPaymentTemplate(\%Data, $assocID);
    if ($Order->{'Status'} != 0)	{
        my $body='';
        my $trans_ref=undef;
        my $templateBody='';
        if ($Order->{'TransLogStatus'}==1)	{
            $trans_ref = gatewayTransLog(\%Data, $clientTransRefID);
            $trans_ref->{'AlreadyPaid'} = 1;
            $trans_ref->{'CC_SOFT_DESC'} = $paymentSettings->{'gatewayCreditCardNote'} || '';
            $templateBody = $template_ref->{'strSuccessTemplate'} || 'payment_success.templ';
            $body .= $trans_ref->{'ResponseCode'};
        }
        else	{
            $templateBody = $template_ref->{'strErrorTemplate'} || 'payment_error.templ';
        }
        $trans_ref->{'headerImage'} = $template_ref->{'strHeaderHTML'};

        my ($html_head, $page_header, $page_navigator, $paypal, $powered) = getPageCustomization(\%Data);
        $trans_ref->{'title'} = '';
        $trans_ref->{'head'} = $html_head;
        $trans_ref->{'page_begin'} = qq[ 
            <div id="global-nav-wrap">
            $page_navigator
            </div>
        ];  
        $trans_ref->{'page_header'} = $page_header;
        $trans_ref->{'page_content'} = '';
        $trans_ref->{'page_footer'} = qq [
            $paypal
            $powered
        ];  
        $trans_ref->{'page_end'} = '';

        my $result = runTemplate(
            undef,
            $trans_ref, ,
            'payment/'.$templateBody
        );
        $body= $result if($result);
        print qq[Content-type: text/html\n\n];
        print $body;
        #pageForm( 'Sportzware Membership', $body, $Data{'clientValues'}, q{}, \%Data) if $body;

    }
    elsif ($action eq 'P')	{
        $Order->{'chkv'} = $chkv;
        my $body = NABPaymentForm(\%Data, $client, $paymentSettings, $clientTransRefID, $Order, $Transactions, $external);
        $Data{'SystemConfig'}{'NoSPLogo'}=1;
        ccPageForm( 'Payment Processing', $body, $Data{'clientValues'}, q{}, \%Data) if $body;

    }
    disconnectDB($db);

}

1;
