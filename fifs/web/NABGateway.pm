#
# $Header: svn://svn/SWM/trunk/web/NABGateway.pm 9826 2013-10-30 00:28:36Z dhanslow $
#

package NABGateway;
require Exporter;
@ISA = qw(Exporter);
@EXPORT=qw(NABPaymentForm NABUpdate NABResponseCodes finalize_registration);
@EXPORT_OK=qw(NABPaymentForm NABUpdate NABResponseCodes finalize_registration);

use lib "RegoForm";
use strict;
use Reg_common;
use Utils;
use HTMLForm;
use MD5;
use DeQuote;
use CGI qw(param);
use Products qw(product_apply_transaction);
use TransLog qw(viewTransLog);
use SystemConfig;
use TTTemplate;
use Payments;
use Gateway_Common;

use HTTP::Request::Common qw(POST);
use LWP::UserAgent;
use CGI qw(param unescape escape);

use RegoForm_MemberFunctions qw(rego_addRealMember);
use RegoForm::RegoFormFactory;

use PageMain;
use Log;

sub NABResponseCodes	{

	my ($responseCode) = @_;

	my $responseType1='APPROVED';
	my $responseType2='DENIED';
	my $responseType3='ERROR';

	my %codes = (
		"00"=>$responseType1,
		"11"=>$responseType1,
		"08"=>$responseType1,
		"16"=>$responseType1,
		"16"=>$responseType1,

		"01"=>$responseType2,
		"02"=>$responseType2,
		"03"=>$responseType2,
		"04"=>$responseType2,
		"05"=>$responseType2,
		"06"=>$responseType2,
		"09"=>$responseType2,
		"09"=>$responseType2,
		"10"=>$responseType2,
		"12"=>$responseType2,
		"13"=>$responseType2,
		"14"=>$responseType2,
		"15"=>$responseType2,
		"17"=>$responseType2,
		"18"=>$responseType2,
		"19"=>$responseType2,
		"20"=>$responseType2,
		"21"=>$responseType2,
		"22"=>$responseType2,
		"23"=>$responseType2,
		"24"=>$responseType2,
		"25"=>$responseType2,
		"26"=>$responseType2,
		"27"=>$responseType2,
		"28"=>$responseType2,
		"29"=>$responseType2,
		"30"=>$responseType2,
		"31"=>$responseType2,
		"32"=>$responseType2,
		"33"=>$responseType2,
		"34"=>$responseType2,
		"35"=>$responseType2,
		"36"=>$responseType2,
		"37"=>$responseType2,
		"38"=>$responseType2,
		"39"=>$responseType2,
		"40"=>$responseType2,
		"41"=>$responseType2,
		"42"=>$responseType2,
		"43"=>$responseType2,
		"44"=>$responseType2,
		"51"=>$responseType2,
		"52"=>$responseType2,
		"53"=>$responseType2,
		"54"=>$responseType2,
		"55"=>$responseType2,
		"56"=>$responseType2,
		"57"=>$responseType2,
		"58"=>$responseType2,
		"59"=>$responseType2,
		"60"=>$responseType2,
		"61"=>$responseType2,
		"62"=>$responseType2,
		"63"=>$responseType2,
		"64"=>$responseType2,
		"65"=>$responseType2,
		"66"=>$responseType2,
		"67"=>$responseType2,
		"68"=>$responseType2,
		"75"=>$responseType2,
		"86"=>$responseType2,
		"87"=>$responseType2,
		"88"=>$responseType2,
		"89"=>$responseType2,
		"90"=>$responseType2,
		"91"=>$responseType2,
		"92"=>$responseType2,
		"93"=>$responseType2,
		"94"=>$responseType2,
		"95"=>$responseType2,
		"96"=>$responseType2,
		"97"=>$responseType2,
		"98"=>$responseType2,
		"99"=>$responseType2,

		"504"=>$responseType3,
		"505"=>$responseType3,
		"510"=>$responseType3,
		"511"=>$responseType3,
		"512"=>$responseType3,
		"513"=>$responseType3,
		"514"=>$responseType3,
		"515"=>$responseType3,
		"516"=>$responseType3,
		"517"=>$responseType3,
		"524"=>$responseType3,
		"545"=>$responseType3,
		"550"=>$responseType3,
		"575"=>$responseType3,
		"577"=>$responseType3,
		"580"=>$responseType3,
		"595"=>$responseType3,
	);

	my $responseText = $codes{$responseCode} || $responseCode;

	## Handle Special cases eg: wrong expiry date etc
	$responseText = 'Invalid Credit Card Number' if ($responseCode == 101);

	return $responseText;

}
sub NABUpdate {

  my ($Data, $paymentSettings, $client, $returnVals, $logID, $assocID)= @_;

  $logID ||= 0;
  $assocID ||= 0;
  my $txn = $returnVals->{'GATEWAY_TXN_ID'} || '';
  my $settlement_date=$returnVals->{'GATEWAY_SETTLEMENT_DATE'} || '0000-00-00';
  my $otherRef1 = 'AUTHID:'.$returnVals->{'GATEWAY_AUTH_ID'} || '';
  my $otherRef2 = '';
  my $otherRef3 = '';
  my $otherRef4 = '';
  my $responseText = $returnVals->{'ResponseText'} || '';

	my $exportOK = 0;
	$exportOK=1 if ($returnVals->{'ResponseCode'} eq 'OK');
  	processTransLog($Data->{'db'}, $txn, $returnVals->{'ResponseCode'}, $responseText, $logID, $paymentSettings, undef, $settlement_date, $otherRef1, $otherRef2, $otherRef3, $otherRef4, '', $exportOK);
  	my $template_ref = getPaymentTemplate($Data, $assocID);
  	my $templateBody = $template_ref->{'strFailureTemplate'} || 'payment_failure.templ';
    my $itemData;
  	if ($returnVals->{'ResponseCode'} eq 'OK')  {
    	UpdateCart($Data, $paymentSettings, $client, undef, undef, $logID);
    	#EmailPaymentConfirmation($Data, $paymentSettings, $logID, $client);
	    # finalize_registration eather returnes 0 (no compulsory, no temp all good!) 
	    $itemData = finalize_registration($Data,$logID);
    	product_apply_transaction($Data,$logID);
    	EmailPaymentConfirmation($Data, $paymentSettings, $logID, $client);
    	$templateBody = $template_ref->{'strSuccessTemplate'} || 'payment_success.templ';
  	} 
	my $trans_ref = gatewayTransLog($Data, $logID);
	$trans_ref->{'headerImage'}= $template_ref->{'strHeaderHTML'} || '';
	$trans_ref->{'CC_SOFT_DESC'} = $paymentSettings->{'gatewayCreditCardNote'} || '';
    
    my ($html_head, $page_header, $page_navigator, $paypal, $powered) = getPageCustomization($Data);
    $trans_ref->{'title'} = '';
    $trans_ref->{'head'} = $html_head;
    $trans_ref->{'page_begin'} = qq[ 
        <div id="global-nav-wrap">
        $page_navigator
        </div>
    ]; 
    my $body = ''; 
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
   	$templateBody= $result if($result);
  	return $templateBody;
}
# This function will run after payment is successfully finished, it will check to see if compulsory payment is set for 
# rego form. if so means we have a temp member in tblTempMember thats needs to be added to real DB and all the post add scripts needs to be run aswell.

sub finalize_registration {
    my($Data , $logID) = @_;
    my $db = $Data->{'db'};
    my $formID = $Data->{'formID'} || 0;
    my $compulsoryPay = $Data->{'CompulsoryPayment'} || 0;
    my $session = $Data->{'sessionKey'};
    my $intRealID;
    my %item_Data;
    my $realm = $Data->{'Realm'};
    if(!$compulsoryPay or $Data->{'SystemConfig'}{'NotUseCompulsoryPay'}){
        return q{};
    }
    if( !$formID ){
        # no form ID found. is this coming from a rego forms? probably not.
        return 0;
    }
    $Data->{'RegoFormID'} =$formID;
    if($compulsoryPay) {# only if compulsory payment is set and NotUseCompulsoryPay is not set we have a temp member and need to enter member in real DB
        warn "Fariba:finalize_registration/NAB:RELAM: $realm , formID:$formID, logID:$logID,session:$session";
        #only look for temp members in current session and who paid for transaction (inf intTransLogID has been set for them)
	    my $st = qq[
		    SELECT
			    intTempMemberID,strTransactions,intAssocID,intClubID
		    FROM
			    tblTempMember
		    WHERE
			    strSessionKey =?
                AND intTransLogID = ? 
		    ];
	    my $qry = $db->prepare($st) or query_error($st);
	    $qry->execute($session,$logID);
    
	    my $cgi = new CGI;

	    my $st_update_temp = qq[
				UPDATE
				    tblTempMember
                SET
                    intRealID = ?,
				    intStatus = ?
				 WHERE 
				    intTransLogID = ?
                    AND
				    intTempMemberID =?        
				];
	    my $st_update_session = qq[
				UPDATE
				    tblRegoFormSession
				SET 
				    intMemberID = ?
				 WHERE 
				    intTempID =?        
				];			    
	    my $action = 'add';
        my %rego_form_cache;
	    while (my $dref = $qry->fetchrow_hashref()) {
		    my $intTempID = $dref->{'intTempMemberID'};
            my $assocID = $dref->{'intAssocID'};
            my $clubID = $dref->{'intClubID'};
            $Data->{'spAssocID'} = $assocID;
            $Data->{'spClubID'} = $clubID;
            my $formObj;
            if ( defined $rego_form_cache{$assocID}{$clubID}){
                $formObj = $rego_form_cache{$assocID}{$clubID};
            }
            else{
                $formObj = getRegoFormObj(
                     $formID,
                     $Data,
                     $Data->{'db'},    
                );
                $rego_form_cache{$assocID}{$clubID} = $formObj;
            }
            my $form_entity_type = $formObj->FormEntityType();
        		
		    #Add Member
		    ($intRealID,undef) =  ($form_entity_type eq 'Member') ? rego_addRealMember($Data,$db,$intTempID,$session, $formObj) : (0,0);
            warn "NAB::CompulsoryPayment: RealID:: $intRealID";
		    my $st_update = qq[
					UPDATE tblTransactions
					SET
					    intID = ?
					WHERE 
					    intTempID = ? 
					];
		    # update transaction table 
		    my $update_qry = $db->prepare($st_update) or query_error($st_update);
		    $update_qry->execute($intRealID,$intTempID);
		
		    # keep  the RealID and intTransLogID  in temp table 
		    $update_qry = $db->prepare($st_update_temp) or query_error($st_update_temp);
		
		    $update_qry->execute($intRealID,1,$logID,$intTempID);
		
		    $update_qry = $db->prepare($st_update_session) or query_error($st_update_session);
		    $update_qry->execute($intRealID,$intTempID);
		
    	}   
 
    }# end if compulsory
    return \%item_Data;
}

sub NABPaymentForm  {

	my ($Data, $client, $paymentSettings, $logID, $Order, $Transactions, $external) = @_;
	my $cgi = new CGI;

  my $currency=$paymentSettings->{'currency'} || 'AUD';
	my $fingerprintURL = $paymentSettings->{'gatewayStatus'} == 1 ? $Defs::NAB_LIVE_FINGERPRINT_URL : $Defs::NAB_DEMO_FINGERPRINT_URL;

  my $NABUsername='';
  my $NABAmount=$Order->{'TotalAmount'} || 0;

  my $theGMTTime = getGMTTime();
  my $NABReferenceID=$paymentSettings->{'gatewayPrefix'}."-".$logID;
  my $merchant_ref = getMerchantDetails($Data, $Order->{'AssocID'}, $Order->{'ClubFormOwner'});
  my $NABPassword=$merchant_ref->{'strMerchantAccPassword'} || $Defs::NAB_GATEWAY_PWD;
	$NABUsername = 'TEST';#$merchant_ref->{'strMerchantAccUsername'};
    

	if (! $NABUsername)	{
		return "NO USERNAME FOUND!\n";
	}

	my %Values= (
        EPS_AMOUNT=>$NABAmount,
        EPS_TIMESTAMP=>$theGMTTime,
        EPS_MERCHANT=>$NABUsername,
        EPS_PASSWORD=>$NABPassword,
        EPS_REFERENCEID=>$NABReferenceID,
	);
    my $req = POST $fingerprintURL, \%Values;
    my $ua = LWP::UserAgent->new();
    $ua->timeout(360);

    my $content = $ua->request($req)->as_string;
    my %returnvals=();
    my $body = ''; #qq[ SENDING TO $fingerprintURL<br>RECEIVING: ];
    my $error=1;

    my $blankLineFound=0;
    for my $line (split /\n|&/,$content)  {
        $line=~s/[\n\r]$//g;
        next if ($line and ! $blankLineFound);
        if (!$line) {
          $blankLineFound=1;
          next;
        }
        $Values{'FINGERPRINT_RESPONSE'} = $line;
        last;
     }

	$error = 0 if (length($Values{'FINGERPRINT_RESPONSE'}) == 40);
    if ($error) {
    #    return qq[Error with Fingerprint identification];
    }
    $Values{'EPS_FINGERPRINT'} = $Values{'FINGERPRINT_RESPONSE'};
    $Values{'chkv'} = $Order->{'chkv'};
    $Values{'assocID'} = $Order->{'AssocID'};
    $Values{'client'} = $client;
    $Values{'currency'} = $currency;
    $body .= displayNABCCPage($Data, $logID, $paymentSettings, \%Values);

	return $body;
}

sub displayNABCCPage    {

  my ($Data, $logID, $paymentSettings, $NAB_ref) = @_;

  $logID ||= 0;

my $template_ref = getPaymentTemplate($Data, $NAB_ref->{'assocID'});

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
    my $NABURL;
    my $EPS_RESULTURL;
    my $formID = $Data->{'formID'};
    my $session = $Data->{'sessionKey'};
    my $compulsory = $Data->{'CompulsoryPayment'} || 0;
    $NABURL= $paymentSettings->{'gatewayStatus'} == 1 ? $Defs::NAB_LIVE_CC_URL: $Defs::NAB_DEMO_CC_URL;
    $EPS_RESULTURL=qq[$Defs::base_url/nabprocess.cgi?a=S&ci=$logID&amp;chkv=$NAB_ref->{'chkv'}];
    #This is for testing purposes only
    #$Data->{'SystemConfig'}{'TestPay'} = 1;
    if ($Data->{'SystemConfig'}{'TestPay'}) {        
	$NABURL = qq[$Defs::base_url/naburl_dummy.cgi?a=S&ci=$logID&amp;formID=$formID&amp;chkv=$NAB_ref->{'chkv'}];
	$EPS_RESULTURL =qq[$Defs::base_url/nabprocess_dummy.cgi?a=S&ci=$logID&amp;formID=$formID&amp;chkv=$NAB_ref->{'chkv'}];
    }	
  my $body = qq[
	<div id="site-wrap">
		<div id="bodycontent">
    	<form id="cc-form" action ="$NABURL" method="POST">
			<p>Please enter your credit card details below and click <b>Process Payment</b> to process</p>
				<div id="card-enter">
					  <div class="card-field"><div class="label">Credit Card Number</div><div class="input"><input class="required" type="text" name="EPS_CARDNUMBER" value="" size="20"></div><div class="label" style="text-align:left;"><i>(No Spaces)</i></div></div>
					  <div class="card-field"><div class="label">Credit Card Type</div><div class="input">$ccType</div></div>
					  <div class="card-field"><div class="label">Expiry Month</div><div class="input">$expiryMonth</div></div>
					  <div class="card-field"><div class="label">Expiry Year</div><div class="input">$expiryYear</div></div>
					  <div class="card-field"><div class="label">CCV</div><div class="input"><input class="required" type="text" name="EPS_CCV" value="" size="5"></div><div class="label" style="text-align:left;"> <i>(3 digit code found on the back of your card)</i></div></div>
					  <div class="card-field"><div class="label">Amount</div><div class="input">\$$NAB_ref->{'EPS_AMOUNT'}</div></div>
				</div>
						<div style="color:red"><b>PLEASE DO NOT DOUBLE CLICK THE PROCESS PAYMENT BUTTON.</b><br>Double clicking can result in the payment being processed twice</div>
					  <br><br><input type="submit" name="SUBMIT" value="Process Payment" style="height:30px;width:180px;margin-left:145px;margin-top:20px;" id="btnsubmit">
		<img src="images/nab-logo-registrations.png" style="float:right;padding-right:145px;"> 
     		<input type="hidden" name="EPS_CURRENCY" value="$NAB_ref->{'currency'}">
     		<input type="hidden" name="EPS_TIMESTAMP" value="$NAB_ref->{'EPS_TIMESTAMP'}">
      		<input type="hidden" name="EPS_AMOUNT" value="$NAB_ref->{'EPS_AMOUNT'}">
		    <input type="hidden" name="EPS_MERCHANT" value="$NAB_ref->{'EPS_MERCHANT'}">
      		<input type="hidden" name="EPS_CANAME" value="$paymentSettings->{'gatewayCreditCardNote'}">
      		<input type="hidden" name="EPS_PASSWORD" value="$NAB_ref->{'EPS_PASSWORD'}">
      		<input type="hidden" name="EPS_REFERENCEID" value="$NAB_ref->{'EPS_REFERENCEID'}">
      		<input type="hidden" name="EPS_FINGERPRINT" value="$NAB_ref->{'EPS_FINGERPRINT'}">
      		<input type="hidden" name="EPS_RESULTURL" value="$EPS_RESULTURL">

      		<input type="hidden" name="ci" value="$logID">
      		<input type="hidden" name="chkv" value="$NAB_ref->{'chkv'}">
      		<input type="hidden" name="client" value="$NAB_ref->{'client'}">
      		<input type="hidden" name= "a" value="s">
      		<input type="hidden" name= "formID" value="$formID">
      		<input type="hidden" name= "compulsory" value="$compulsory">
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

sub getGMTTime  {

  my ($second, $minute, $hour, $dayOfMonth, $month, $yearOffset, $dayOfWeek, $dayOfYear, $daylightSavings) = gmtime();
  my $year = 1900 + $yearOffset;
  $month++;
  $second= sprintf("%02s", $second);
  $minute= sprintf("%02s", $minute);
  $hour= sprintf("%02s", $hour);
  $month = sprintf("%02s", $month);
  $dayOfMonth = sprintf("%02s", $dayOfMonth);
  return "$year$month$dayOfMonth$hour$minute$second"
}

sub getMerchantDetails	{
	
	my ($Data, $assocID, $clubID) = @_;

	my $st = qq[
		SELECT
			strMerchantAccUsername,
			strMerchantAccPassword
		FROM
			tblBankAccount
		WHERE
			intEntityID = ?
			AND intEntityTypeID = ?
		LIMIT 1
	];
	my $entityID = $assocID;
	my $entityTypeID=5;
	if ($clubID and $clubID>0)	{
		$entityID = $clubID;
		$entityTypeID=3;

	}
  	my $qry= $Data->{'db'}->prepare($st) or query_error($st);
  	$qry->execute($entityID, $entityTypeID);

    my $dref = $qry->fetchrow_hashref();
    if ($Data->{'SystemConfig'}{'TestPay'}) {
	$dref->{'strMerchantAccUsername'} = 'XYZ0010';
	$dref->{'trMerchantAccPassword'} = 'abcd1234';
    }
	return $dref;
}
1;
