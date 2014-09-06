#
# $Header: svn://svn/SWM/trunk/web/PayPal.pm 11170 2014-03-31 00:52:32Z fkhezri $
#

package PayPal;
require Exporter;
@ISA = qw(Exporter);
@EXPORT=qw(payPalProcess payPalUpdate);
@EXPORT_OK=qw(payPalProcess payPalUpdate);

use strict;
use MD5;
use CGI qw(param);
use Products qw(product_apply_transaction);
use Payments;

use HTTP::Request::Common qw(POST);
use LWP::UserAgent;
use MD5;
use CGI qw(param unescape escape);

use RegoForm_MemberFunctions qw(rego_addRealMember);
use RegoForm::RegoFormFactory;

sub payPalProcess	{

 ## CALL SetExpressCheckoutAPI

	my ($Data, $client, $paymentSettings, $logID, $Order, $Transactions, $external) = @_;
	my $cgi = new CGI;

    my $returnPayPalURL = $Defs::base_url . $paymentSettings->{'gatewayReturnURL'} . qq[&amp;ci=$logID&client=$client]; ##$Defs::paypal_RETURN_URL
    my $cancelPayPalURL = $Defs::base_url . $paymentSettings->{'gatewayCancelURL'} . qq[&amp;ci=$logID&client=$client]; ##$Defs::paypal_CANCEL_URL

	my $m = new MD5;
    $m->reset();
    $m->add($Defs::REGO_FORM_SALT, $logID);
    my $encryptedID = $m->hexdigest();

    my $currency=$paymentSettings->{'currency'} || 'AUD';
    my $payPalAction = "Sale";
    my $payPalMethod = "SetExpressCheckout";
	my $header=qq[$Defs::base_url/images/memb_hdr_750.jpg];
	$header=qq[$Defs::base_url/images/$Data->{'SystemConfig'}{'PayPalHeader'}] if $Data->{'SystemConfig'}{'PayPalHeader'};
	$header='' if $Data->{'noheader'};

	my $bgcolor = $Data->{'SystemConfig'}{'PayPalHeaderBGColor'} ?  $Data->{'SystemConfig'}{'PayPalHeaderBGColor'} : 'FFFFFF';
	my $bordercolor = $Data->{'SystemConfig'}{'PayPalHeaderBorderColor'} ?  $Data->{'SystemConfig'}{'PayPalHeaderBorderColor'} : 'FFFFFF';

	my $APIusername= $paymentSettings->{'gatewayUsername'};
	my $APIpassword= $paymentSettings->{'gatewayPassword'};
	my $APIsignature= $paymentSettings->{'gatewaySignature'};
	my $gatewayVersion= $paymentSettings->{'gatewayVersion'};


    my $formID = $Data->{'formID'} ||0 ;
    my $session = $Data->{'sessionKey'} ||0;
    my $compulsory = $Data->{'CompulsoryPayment'} ||0;

	my $amount=0;
	my %Values= (
USER=>$APIusername,
PWD=>$APIpassword,
SIGNATURE=>$APIsignature,
VERSION=>$gatewayVersion,
METHOD=>$payPalMethod,
PAYMENTACTION=>$payPalAction,
RETURNURL=>$returnPayPalURL.qq[&amp;ext=$external&amp;ei=$encryptedID&amp;nh=$Data->{'noheader'}&amp;formID=$formID&amp;session=$session;compulsory=$compulsory],
CANCELURL=>$cancelPayPalURL.qq[&amp;ext=$external&amp;ei=$encryptedID&amp;nh=$Data->{'noheader'}&amp;formID=$formID&amp;session=$session;compulsory=$compulsory],
CURRENCYCODE=>$currency,
HDRIMG=>$header,
HDRBACKCOLOR=>$bgcolor,
HDRBORDERCOLOR=>$bordercolor,
NOSHIPPING=>1,
LOCALECODE=>'AU',
SOFTDESCRIPTOR=>$paymentSettings->{'gatewayCreditCardNote'},
CUSTOM=>"$Order->{'Realm'} - $Order->{'AssocName'} TLID-$logID",
INVNUM=>$paymentSettings->{'gatewayPrefix'}.'-'.$logID,
SOLUTIONTYPE=>"Sole",
LANDINGPAGE=>"Billing",
	);
	foreach my $count( keys %{$Transactions}) {
		$Values{"L_NAME$count"} = $Transactions->{$count}{'name'};
		$Values{"L_NUMBER$count"} = $Transactions->{$count}{'number'};
		$Values{"L_DESC$count"} = $Transactions->{$count}{'desc'};
		$Values{"L_QTY$count"} = $Transactions->{$count}{'qty'};
		$Values{"L_AMT$count"} = $Transactions->{$count}{'amount'};
		if ($Transactions->{$count}{'qty'} > 1)	{
			$Values{"L_AMT$count"} = $Transactions->{$count}{'amountPerItem'};
		}
	}
	$Values{"AMT"} = $Order->{TotalAmount};
	$Values{"MAXAMT"} = $Order->{TotalAmount};


	my $APIurl= $paymentSettings->{'gateway_url'}; #$Defs::paypal_LIVE_URL_EXPRESS
        my $req = POST $APIurl, \%Values;
        my $ua = LWP::UserAgent->new();
        $ua->timeout(360);
        my $content = $ua->request($req)->as_string;
        my %returnvals=();
        for my $line (split /\n|&/,$content)  {
warn("LLLLine: $line");
                $line=~s/[\n\r]$//g;
                my($key,$val)=split /=/,$line;
                $returnvals{$key}=$val;
        }


        ## Redirect to paypal
        my $token = $returnvals{'TOKEN'};
        $token =~ s/\%2d/-/g;
	    $APIurl= $paymentSettings->{'gateway_url2'}; #$Defs::paypal_LIVE_URL_REDIRECT
        my $url = $APIurl . qq[&amp;token=$token&amp;useraction=commit];

	if ($returnvals{'ACK'} =~ /Success/)	{
        	print $cgi->redirect($url);
	}
	else	{
		my $body .= displayPaymentResult($Data, $logID, 1);
		$body .= qq[<br><p><a href="$Defs::base_url/main.cgi?client=$client&a=P_TXNLog_list&mode=p">Return to Membership System</a></p>] if ! $external;
		return $body;
	}
	return '';
}




sub payPalUpdate	{

	my ($Data, $paymentSettings, $client, $logID, $token, $Order, $external, $encryptedID) = @_;

	## CALL SetExpressCheckoutAPI
	my $itemData;
	my $m = new MD5;
        $m->reset();
        $m->add($Defs::REGO_FORM_SALT, $logID);
        my $temp_encryptedID = $m->hexdigest();

	if ($temp_encryptedID ne $encryptedID)	{
		my $body = qq[<p>There was an error with your payment</p>];
		$body .= qq[<br><p><a href="$Defs::base_url/main.cgi?client=$client&a=P_TXNLog_list&mode=p">Return to Membership System</a></p>] if ! $external;
		return $body;
	}

        $token =~ s/\%2d/-/g;
        my $currency=$paymentSettings->{'currency'} || 'AUD';
	my $payPalMethod = "GetExpressCheckoutDetails";

	my $APIusername= $paymentSettings->{'gatewayUsername'};
	my $APIpassword= $paymentSettings->{'gatewayPassword'};
	my $APIsignature= $paymentSettings->{'gatewaySignature'};
	my $gatewayVersion= $paymentSettings->{'gatewayVersion'};
	my $APIurl= $paymentSettings->{'gateway_url'}; #$Defs::paypal_LIVE_URL_EXPRESS

        my $req = POST $APIurl, [
USER=>$APIusername,
PWD=>$APIpassword,
SIGNATURE=>$APIsignature,
VERSION=>$gatewayVersion,
METHOD=>$payPalMethod,
SOFTDESCRIPTOR=>$paymentSettings->{'gatewayCreditCardNote'},
TOKEN=>$token];

	my $ua = LWP::UserAgent->new();
    	$ua->timeout(360);

	my $content = $ua->request($req)->as_string;
    	my %returnvals=();
    	for my $line (split /\n|&/,$content)  {
        	$line=~s/[\n\r]$//g;
        	my($key,$val)=split /=/,$line;
        	$returnvals{$key}=$val;
print STDERR "LOGID: $logID PP1: $key | $val\n";
		$returnvals{'ResponseText'} = '500 Server closed 1' if ($val =~ /500 Server/ or $key =~ /500 Server/);
	}

	my $payerID = $returnvals{'PAYERID'};
	if ($returnvals{'ACK'} !~ /Success/)	{	
		my $body = qq[<p>There was an error with your payment</p>];
		$body .= qq[<br><p><a href="$Defs::base_url/main.cgi?client=$client&a=P_TXNLog_list&mode=p">Return to Membership System</a></p>] if ! $external;
		return $body;
	}

	$payPalMethod = "DoExpressCheckoutPayment";
        my $payPalAction = "Sale";
        $req = POST $APIurl, [
USER=>$APIusername,
PWD=>$APIpassword,
SIGNATURE=>$APIsignature,
VERSION=>$gatewayVersion,
AMT=>$Order->{'TotalAmount'},
MAXAMT=>$Order->{'TotalAmount'},
CURRENCYCODE=>$currency,
PAYMENTACTION=>$payPalAction,
METHOD=>$payPalMethod,
PAYERID=>$payerID,
SOFTDESCRIPTOR=>$paymentSettings->{'gatewayCreditCardNote'},
TOKEN=>$token];

	$ua = LWP::UserAgent->new();
    	$ua->timeout(360);

	$content = $ua->request($req)->as_string;
    	%returnvals=();
    	for my $line (split /\n|&/,$content)  {
        	$line=~s/[\n\r]$//g;
        	my($key,$val)=split /=/,$line;
        	$returnvals{$key}=$val;
print STDERR "LOGID: $logID PP2: $key | $val\n";
		$returnvals{'ResponseText'} = '500 Server closed' if ($val =~ /500 Server/ or $key =~ /500 Server/ and ! $returnvals{'ResponseText'});
	}

	#if ($returnvals{'ResponseText'} eq '500 Server closed')	{
	if ($returnvals{'ACK'} !~ /Success/)	{
			print STDERR "RETRYING paypal FOR $logID\n";
		## RECHECK
        my %values = (
            USER => $APIusername,
            PWD => $APIpassword,
            SIGNATURE => $APIsignature,
            VERSION => $gatewayVersion,
            METHOD => 'TransactionSearch',
	INVNUM=>$paymentSettings->{'gatewayPrefix'}.'-'.$logID,
            STARTDATE => '2014-1-1T10:00:00Z',
            ENDDATE => '2019-1-1T11:00:00Z',
        );
		my $live = ($paymentSettings->{'gatewayStatus'}==1) ? 1 : 0;
		payPalCheckTXN($Data->{'db'}, $paymentSettings, $live, $logID, \%values, \%returnvals);
		$returnvals{'ResponseText'} = 'Self Fixed' if ($returnvals{'ACK'}  =~ /Success/);
		if ($returnvals{'ACK'} !~ /Success/)	{
			print STDERR "RETRYING PayPal AGAIN FOR $logID\n";
			sleep(2);
			print STDERR "RETRYING SLEEP DONE AWAKE - paypal AGAIN FOR $logID\n";
			payPalCheckTXN($Data->{'db'}, $paymentSettings, $live, $logID, \%values, \%returnvals);
			$returnvals{'ResponseText'} = 'Self Fixed' if ($returnvals{'ACK'}  =~ /Success/);
		}
	}
	my $settlement_date = unescape($returnvals{'ORDERTIME'});
	$settlement_date =~ s/T|Z/ /g;

print STDERR "RT:$returnvals{'ACK'}|\n";
	$returnvals{'ResponseCode'} = ($returnvals{'ACK'} =~ /^Success/) ? 'OK' : 'ERROR';
	my $txn = qq[PayPal TransactionID: $returnvals{'TRANSACTIONID'} - PayPal CorrelationID: $returnvals{'CORRELATIONID'}];

	my $otherRef1 = qq[TOKEN:$token];
	my $otherRef2 = qq[PAYERID:$payerID];
	my $otherRef3 = qq[TRANSACTIONID:$returnvals{'TRANSACTIONID'}];
	my $otherRef4 = qq[CORRELATIONID:$returnvals{'CORRELATIONID'}];
	
	processTransLog($Data->{'db'}, $txn, $returnvals{'ResponseCode'}, $returnvals{'ResponseText'}, $logID, $paymentSettings, undef, $settlement_date, $otherRef1, $otherRef2, $otherRef3, $otherRef4, '');
	if ($returnvals{'ResponseCode'} eq 'OK')	{	
		UpdateCart($Data, $paymentSettings, $client, undef, undef, $logID);
print STDERR "paypal CART DONE ABOUT TO EMAIL FOR $logID\n";
		$itemData = finalize_registration($Data,$logID);
        	EmailPaymentConfirmation($Data, $paymentSettings, $logID, $client);
        	product_apply_transaction($Data,$logID);
		
		#$itemData = finalize_registration($Data,$logID);
		
		
		if (1==2 and $external and $paymentSettings->{'return_url'})	{
			my $cgi = new CGI;
        		print $cgi->redirect($paymentSettings->{'return_url'} . "&ci=$logID");
			return '';
		}
			
	}
	else	{
			if (1==2 and $external and $paymentSettings->{'return_failure_url'})	{
				my $cgi = new CGI;
        			print $cgi->redirect($paymentSettings->{'return_failure_url'}."&ci=$logID");
				return '';
			}
	}
	my $body = displayPaymentResult($Data, $logID, 1);
	$body .= qq[<br><p><a href="$Defs::base_url/main.cgi?client=$client&a=P_TXNLog_list&mode=p">Return to Membership System</a></p>] if ! $external;
	return $body;
}

# This function will run after payment is successfully finished, it will check to see if compulsory payment is set for 
# rego form. if so means we have a temp member in tblTempMember thats needs to be added to real DB and all the post add scripts needs to be run aswell.

sub finalize_registration {
    my($Data , $logID) = @_;
    my $db = $Data->{'db'};
    my $formID = $Data->{'formID'} || 0;
    my $session = $Data->{'sessionKey'};
    my $compulsoryPay = $Data->{'CompulsoryPayment'} || 0;
    my $intRealID;
    my $realm = $Data->{'Realm'}; 
    my %item_Data;
    if(!$compulsoryPay or $Data->{'SystemConfig'}{'NotUseCompulsoryPay'}){
        return q{};
    }
    if(! $formID ){
        return 0;
    }
    $Data->{'RegoFormID'} =$formID;
    if($compulsoryPay) {# only if compulsory payment is set and NotUseCompulsoryPay is not set we have a temp member and need to enter member in real DB
        warn "Fariba:finalize_registration/Paypal REALM: $realm , formID:$formID, logID:$logID,session:$session , Compulsory:: $compulsoryPay";

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
	$qry->execute($session, $logID);
    
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
        warn "paypal::CompulsoryPayment: RealID:: $intRealID";
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
		
		# keepp  the RealID and intTransLogID  in temp table 
		$update_qry = $db->prepare($st_update_temp) or query_error($st_update_temp);
		
		$update_qry->execute($intRealID,1,$logID,$intTempID);
		
		$update_qry = $db->prepare($st_update_session) or query_error($st_update_session);
		$update_qry->execute($intRealID,$intTempID);
		
	    }
 
    }# end if compulsory
    return \%item_Data;
}


sub payPalCheckTXN {

    my ($db, $paymentSettings, $live, $logID, $values_ref, $returnvals_ref) = @_;


    my %output=();
    my $ua = LWP::UserAgent->new();
	my $APIurl= $paymentSettings->{'gateway_url'}; #$Defs::paypal_LIVE_URL_EXPRESS
    my $req = POST $APIurl, $values_ref;
    my $res= $ua->request($req);
    my $retval = $res->content() || '';
    for my $line (split /&/,$retval) {
        my ($k,$v)=split /=/,$line,2;
        $output{$k}=$v;
		print STDERR "PP try again: $k | $v\n";
    }

	if ($output{'ACK'} =~ /Success/ and $output{'L_STATUS0'} =~ /Completed/)    {
		foreach my $key (keys %output)	{
			$returnvals_ref->{$key}=$output{$key} if $output{$key};
		}
		$returnvals_ref->{'TRANSACTIONID'} = $output{'L_TRANSACTIONID0'} || '';
	}
}
1;
