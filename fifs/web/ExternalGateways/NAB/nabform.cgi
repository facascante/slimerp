#!/usr/bin/perl -w

#
# $Header: svn://svn/SWM/trunk/web/nabform.cgi 11004 2014-03-18 22:21:37Z dhanslow $
#

use strict;

use CGI qw(param unescape escape);
use MD5;
use LWP::UserAgent;
use HTTP::Request;

main();

sub main	{

    my $CCV= param('CCV') || 0;
    my $action = param('a') || 0;
    my $client = param('client') || 0;
    my $external= param('ext') || 0;
    my $clientTransRefID= param('ci') || 0;
    my $encryptedID= param('ei') || 0;
    my $noheader= param('nh') || 0;
    my $chkv= param('chkv') || 0;
    my $amount= param('amount') || 0;
    my $formID= param('formID') || 0;
    my $session= param('session') || 0;
    my $compulsory= param('compulsory') || 0;
    my %Data=();
    my %Order=();
    $Order{'chkv'} = $chkv;
    $Order{'amount'} = $amount;
    my %Transactions=();
    my $chkvalue= $amount . $clientTransRefID. 'NZD';
    my $m = new MD5;
    $m->reset();
    $m->add('1234A', $chkvalue);
    $chkvalue = $m->hexdigest();
    my $body = '';
    print qq[Content-type: text/html\n\n];
    if ($chkvalue ne $chkv) {
        $body = 'ERROR WITH CHECKSUM';
    }
    elsif ($action eq 's') {
        $body = NABProcess($client, $external, $amount, $clientTransRefID, $chkv, $formID, $session, $CCV);
    }
    else    {
        $body = NABPaymentForm(\%Data, $client, $clientTransRefID, \%Order, \%Transactions, $external);
    }
    print $body;
}

sub NABProcess  {
    #call SPOnline

    my ($client, $external, $amount, $logID, $chkv, $formID, $session, $CCV) = @_;

    my $respCode = $CCV || '';
    my $respText = 'Approved';
    $respText = 'Error' if ($respCode !~/^00|08|11$/);
    my $chkvalue= $respCode . $amount . $logID; #Different checkvalue for way back
    my $m = new MD5;
    $m->reset();
    $m->add('1234A', $chkvalue);
    $chkvalue = $m->hexdigest();
       
    my $url = qq[http://elwood/FIFASPOnline/web/gatewayprocess_dummy.cgi?a=S&amp;client=$client&amp;ext=$external&amp;ci=$logID&amp;chkv=$chkvalue&amp;formID=$formID&amp;session=$session&amp;restext=$respText&amp;rescode=$respCode&amp;txnid=111&amp;authid=123];
#    my $url = qq[http://elwood/FIFASPOnline/web/payments_process.cgi?a=S&amp;client=$client&amp;ext=$external&amp;ci=$logID&amp;chkv=$chkv&amp;formID=$formID&amp;session=$session&amp;responsetext=Approved&amp;responsecode=00&amp;txnid=111&amp;authid=123];

    my $agent = LWP::UserAgent->new(env_proxy => 1,keep_alive => 1, timeout => 30); 
    my $header = HTTP::Request->new(GET => $url); 
    my $request = HTTP::Request->new('GET', $url, $header); 
    my $response = $agent->request($request);

    return qq[
        PROCESSED<br>
        <b>RESPCODE</b> $respCode<br>
        <b>RESPTEXT</b> $respText<br>
        <b>AMOUNT</b> \$$amount<br>
        <br>$url
    ];
}

sub NABPaymentForm  {

	my ($Data, $client, $logID, $Order, $Transactions, $external) = @_;
	my $cgi = new CGI;

    my $currency='AUD';
    my $NABUsername='TESTUSR';
    my $NABPassword='PWD';
    my $NABAmount=$Order->{'TotalAmount'} || 0;

    my $NABReferenceID='Ref' . $logID;
    
    my %Values=();
    $Values{'EPS_FINGERPRINT'} = '1234';
    $Values{'chkv'} = $Order->{'chkv'};
    $Values{'amount'} = $Order->{'amount'};
    $Values{'client'} = $client;
    $Values{'currency'} = $currency;
    return displayNABCCPage($Data, $logID, \%Values);

}

sub displayNABCCPage    {
    my ($Data, $logID, $NAB_ref) = @_;
    my $base_url = 'http://elwood/FIFASPOnline/web';

  my $expiryMonth = qq[
		<span class="expirym">
    <select name="EPS_EXPIRYMONTH"> 
      <option value="" selected>MM</option> 
      <option value="01">01</option> 
      <option value="02">02</option> 
      <option value="03">03</option> 
      <option value="04">04</option> 
      <option value="05">05</option> 
      <option value="06">06</option> 
      <option value="07">07</option> 
      <option value="08">08</option> 
      <option value="09">09</option> 
      <option value="10">10</option> 
      <option value="11">11</option> 
      <option value="12">12</option> 
    </select>
		</span>
  ];
    
  my $expiryYear = qq[
    <span class="expiryy">
		<select name="EPS_EXPIRYYEAR">
      <option value="" selected>YY</option>
      <option value="14">14</option>
      <option value="15">15</option>
      <option value="16">16</option>
      <option value="17">17</option>
      <option value="18">18</option>
      <option value="19">19</option>
    </select>
		</span>
  ];

  my $ccType = qq[
    <span class="cardtype"><input type="radio" name="EPS_CARDTYPE" value="mastercard" id="mastercard">&nbsp;<label for="mastercard" class="cardlabel mcardlabel">Mastercard</label></span>
		<span class="cardtype"><input type="radio" name="EPS_CARDTYPE" value="visa" id="visa">&nbsp;<label for="visa" class="cardlabel visalabel">VISA</label></span>
  ];
    my $formID = $Data->{'formID'};
    my $session = $Data->{'sessionKey'};
    my $compulsory = $Data->{'CompulsoryPayment'} || 0;
	#my $NABURL = qq[$base_url/naburl_dummy.cgi?a=S&ci=$logID&amp;formID=$formID&amp;chkv=$NAB_ref->{'chkv'}];
	my $NABURL = qq[$base_url/naburl_dummy.cgi?a=S&ci=$logID&amp;formID=$formID&amp;chkv=$NAB_ref->{'chkv'}];
	my $EPS_RESULTURL =qq[$base_url/nabprocess_dummy.cgi?a=S&ci=$logID&amp;formID=$formID&amp;chkv=$NAB_ref->{'chkv'}];
  my $body = qq[
	<div id="site-wrap">
		<div id="bodycontent">
    	<form id="cc-form" action ="nabform.cgi" method="POST">
			<p>Please enter your credit card details below and click <b>Process Payment</b> to process</p>
				<div id="card-enter">
					  <div class="card-field"><div class="label">Credit Card Number</div><div class="input"><input class="required" type="text" name="EPS_CARDNUMBER" value="" size="20"></div><div class="label" style="text-align:left;"><i>(No Spaces)</i></div></div>
					  <div class="card-field"><div class="label">Credit Card Type</div><div class="input">$ccType</div></div>
					  <div class="card-field"><div class="label">Expiry Month</div><div class="input">$expiryMonth</div></div>
					  <div class="card-field"><div class="label">Expiry Year</div><div class="input">$expiryYear</div></div>
					  <div class="card-field"><div class="label">CCV</div><div class="input"><input class="required" type="text" name="CCV" value="" size="5"></div><div class="label" style="text-align:left;"> <i>(3 digit code found on the back of your card)</i></div></div>
					  <div class="card-field"><div class="label">Amount</div><div class="input">\$$NAB_ref->{'amount'}</div></div>
				</div>
						<div style="color:red"><b>PLEASE DO NOT DOUBLE CLICK THE PROCESS PAYMENT BUTTON.</b><br>Double clicking can result in the payment being processed twice</div>
					  <br><br><input type="submit" name="SUBMIT" value="Process Payment" style="height:30px;width:180px;margin-left:145px;margin-top:20px;" id="btnsubmit">
		<img src="images/nab-logo-registrations.png" style="float:right;padding-right:145px;"> 
     		<input type="hidden" name="EPS_CURRENCY" value="$NAB_ref->{'currency'}">
     		<input type="hidden" name="EPS_TIMESTAMP" value="$NAB_ref->{'EPS_TIMESTAMP'}">
      		<input type="hidden" name="EPS_AMOUNT" value="$NAB_ref->{'EPS_AMOUNT'}">
		    <input type="hidden" name="EPS_MERCHANT" value="$NAB_ref->{'EPS_MERCHANT'}">
      		<input type="hidden" name="EPS_PASSWORD" value="$NAB_ref->{'EPS_PASSWORD'}">
      		<input type="hidden" name="EPS_REFERENCEID" value="$NAB_ref->{'EPS_REFERENCEID'}">
      		<input type="hidden" name="EPS_FINGERPRINT" value="$NAB_ref->{'EPS_FINGERPRINT'}">
      		<input type="hidden" name="EPS_RESULTURL" value="$EPS_RESULTURL">

      		<input type="hidden" name="ci" value="$logID">
      		<input type="hidden" name="amount" value="$NAB_ref->{'amount'}">
      		<input type="hidden" name="chkv" value="$NAB_ref->{'chkv'}">
      		<input type="hidden" name="client" value="$NAB_ref->{'client'}">
      		<input type="hidden" name= "a" value="s">
		<input type="hidden" name= "session" value="$session">
			</form>
			<div class="spinner-wrap" style="display:none;">
				<p>Please wait while your payment is processed.</p>
				<div class="spinner">
      		<div class="rect1"></div>
      		<div class="rect2"></div>
      		<div class="rect3"></div>
      		<div class="rect4"></div>
      		<div class="rect5"></div>
    		</div>
			</div>
		</div>
	</div>
  ];
  return $body;

}

1;
