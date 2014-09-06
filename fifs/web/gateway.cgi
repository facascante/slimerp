#!/usr/bin/perl -w

#
# $Header: svn://svn/SWM/trunk/web/gateway.cgi 10144 2013-12-03 21:36:47Z tcourt $
#

use DBI;
use CGI qw(:cgi escape unescape);

use strict;

use lib '.', '..', 'comp';

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
use NABGateway;

main();

sub main	{

	
	my $action = param('a') || 0;
	my $client = param('client') || 0;
	my $INtoken= param('token') || 0;
	my $external= param('ext') || 0;
	my $clientTransRefID= param('ci') || 0;
	my $encryptedID= param('ei') || 0;
	my $noheader= param('nh') || 0;
	
    print STDERR "START OF NAB : CLIENT:$client: CTRef: $clientTransRefID: \n";
    my $db=connectDB();
	my %Data=();
	$Data{'db'}=$db;

	my ($Order, $Transactions) = payPalTransactions(\%Data, $clientTransRefID);
        $Data{'SystemConfig'}{'PaymentConfigID'} = $Data{'SystemConfig'}{'PaymentConfigUsedID'} ||  $Data{'SystemConfig'}{'PaymentConfigID'};

        my %clientValues = getClient($client);
        $Data{'clientValues'} = \%clientValues;

        $Data{'db'}=$db;
        getDBConfig(\%Data);
  	$Data{'SystemConfig'}=getSystemConfig(\%Data);
  	$Data{'LocalConfig'}=getLocalConfig(\%Data);
    my $lang   = Lang->get_handle('', $Data{'SystemConfig'}) || die "Can't get a language handle!";
    $Data{'lang'}=$lang;

  	my $assocID=getAssocID(\%clientValues) || '';
        # DO DATABASE THINGS
        my $DataAccess_ref=getDataAccess(\%Data);
		$Data{'Permissions'}=GetPermissions(
			\%Data,
			$Defs::LEVEL_ASSOC,
			$assocID,
			$Data{'Realm'},
			$Data{'RealmSubType'},
			$Defs::LEVEL_ASSOC,
			0,
		);


        $Data{'DataAccess'}=$DataAccess_ref;

        $Data{'clientValues'}=\%clientValues;
        $client= setClient(\%clientValues);
  	$Data{'client'}=$client;

	my $paymentSettings = getPaymentSettings(\%Data,$Defs::PAYMENT_ONLINEPAYPAL);
	$paymentSettings->{'PAYPAL'}=1;

    	my $header_css = $noheader ? ' #spheader {display:none;} ' : '';
        $Data{'noheader'}=$noheader;
    	$Data{'SystemConfig'}{'OtherStyle'} = "#pageholder { margin:0px;}#contentholder{margin-left:0;} $header_css";


	if ($Order->{'Status'} != 0)	{
		my $body  = qq[<div align="center" class="warningmsg" style="font-size:14px;">There was an error</div>];
		pageForm( 'Sportzware Membership', $body, $Data{'clientValues'}, q{}, \%Data);
	}
	elsif ($action eq 'P')	{
		## CALL SetExpressCheckoutAPI
		my $body = NABPaymentForm(\%Data, $client, $paymentSettings, $clientTransRefID, $Order, $Transactions, $external);
		pageForm( 'Sportzware Membership', $body, $Data{'clientValues'}, q{}, \%Data) if $body;
		
	}
	elsif ($action eq 'C')	{
		my $msg = qq[<div align="center" class="warningmsg" style="font-size:14px;">You cancelled the Transaction</div>];
		my $body = displayPaymentResult(\%Data, $clientTransRefID, 1, $msg);
		$body .= qq[<br><p><a href="$Defs::base_url/main.cgi?client=$client&a=M_TXNLog_list&mode=p">Return to Membership System</a></p>] if ! $external;
		pageForm( 'Sportzware Membership', $body, $Data{'clientValues'}, q{}, \%Data);
	}
	elsif ($action eq 'S')	{
		my $body = nabUpdate(\%Data, $paymentSettings, $client, $clientTransRefID, $INtoken, $Order, $external, $encryptedID);
		pageForm( 'Sportzware Membership', $body, $Data{'clientValues'}, q{}, \%Data);
	}
	elsif ($action eq 'S')	{
		my $body = qq[TEST WORKED FOR $clientTransRefID];
		pageForm( 'Sportzware Membership', $body, $Data{'clientValues'}, q{}, \%Data);
	}
	disconnectDB($db);

}

1;
