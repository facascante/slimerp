#
# $Header: svn://svn/SWM/trunk/web/admin/PaymentAdmin.pm 11015 2014-03-19 00:21:52Z ppascoe $
#

package PaymentAdmin;

require Exporter;
@ISA =  qw(Exporter);
@EXPORT_OK = qw(payment_display_input_screen payment_update_db);

use lib "..","../..","../sp_publisher";
use DBI;
use CGI qw(param unescape escape);
use strict;
use Defs;
use Utils;
use AdminCommon;
use DeQuote;
use FormHelpers;
use PassportLink;

sub payment_display_input_screen {
  	my ($db, $action, $target, $msg, $parmRealmiD) = @_;
	
    my $rule_name           = param('rule_name') || '';
    my $realmID             = param('realmID') || '';
    if ($parmRealmiD) {
    	$realmID = $parmRealmiD;
    }
    my $subrealmID          = param('subrealmID') || '';
    my $fin_inst            = param('fin_inst') || '';
    my $mp_email            = param('mp_email') || '';
    my $myob_job_code       = param('myob_job_code') || '';
    my $levelID             = param('levelID') || '';
    my $entityID            = param('entityID') || '';
    my $currency            = param('currency') || '';
    my $client_currency     = param('client_currency') || '';
    my $notification_email  = param('notification_email') || '';
    my $status              = param('status') || '';
    my $prefix              = param('prefix') || '';
    my $ccnote              = param('ccnote') || '';
    my $gatewayID           = param('gatewayID') || '';
    my $gateway_type        = param('gateway_type') || '';
    my $fee_allocation_type = param('fee_allocation_type') || '';
    my $min_fee_type        = param('min_fee_type') || '';
    my $fee_rate        	= param('fee_rate') || '';
    my $curMinFeePoint      = param('curMinFeePoint') || '';
        		
  	my $button_title = "ADD PAYMENT";
  	my $form_action  = "REALM_PAYMENT_update";
	
  	if ($action eq 'REALM_PAYMENT') {
  		#First time in, so set some defaults
  		$fin_inst = 'NAB';
  		$currency = 'AUD';
  		$client_currency = 'AUD';
  		$levelID = '100';
  		$fee_allocation_type = 1;
  		$min_fee_type = 1;
  		$status = 1;
  		$gateway_type = 1;
  		$gatewayID = 1;
  		$fee_rate = 0.039;
  		$msg = '';
  		$curMinFeePoint = 25.65;
  	}  
	else {
  		#Subsequent time in - there must have been an error on data entry
		$msg = '<tr height="30px"><td colspan="2" style="color:red;">' . $msg . '</td></tr>';
	}			

	#Setup all the non-text HTML fields
  	my $st=qq[ SELECT intRealmID, strRealmName FROM tblRealms ORDER BY strRealmName];
  	my $realms=getDBdrop_down('realmID',$db,$st,$realmID,'&nbsp;') || '';
	$realms =~ s/class = ""/class = "chzn-select"/g;
	
	$st=qq[
		select S.intSubTypeID, concat(R.strRealmName," - ",S.strSubTypeName) as strSubRealmName
		FROM tblRealmSubTypes S
		INNER JOIN tblRealms R ON R.intRealmID = S.intRealmID 
		ORDER BY R.strRealmName, S.strSubTypeName;
	];
	my $subrealms=getDBdrop_down('subrealmID',$db,$st,$subrealmID,'&nbsp;') || '';
	$subrealms =~ s/class = ""/class = "chzn-select"/g;	
	
	my %button_fin_inst = (
		'NAB'=>'NAB',
		'Paypal'=>'Paypal',
		);
	my $button_fin_inst = fncRadioBtns($fin_inst,'fin_inst',\%button_fin_inst);

	my %button_status = (
		'1'=>'Live',
		'2'=>'Test',
		);
	my $button_status = fncRadioBtns($status,'status',\%button_status);

	my %button_currency = (
		'AUD'=>'AUD',
		'NZD'=>'NZD',
		'EUR'=>'EUR',
		'CAD'=>'CAD',
		'GBP'=>'GBP',
		'USD'=>'USD',
	);
	my $button_client_currency = fncRadioBtns($client_currency,'client_currency',\%button_currency);
	my $button_currency = fncRadioBtns($currency,'currency',\%button_currency);
	
	my %button_fee_allocation_type = (
		'1'=>'Default - fee included in product amount',
		'2'=>'Fee added as its own line item - AUSKICK MODEL',
		);
	my $button_fee_allocation_type = fncRadioBtns($fee_allocation_type,'fee_allocation_type',\%button_fee_allocation_type);
	
	my %button_min_fee_type = (
		'1'=>'Add entire fee',
		'2'=>'Round Up',
		);
	my $button_min_fee_type = fncRadioBtns($min_fee_type,'min_fee_type',\%button_min_fee_type);

	my %button_gateway_type = (
		'1'=>'1',	#PP Better description???
		'2'=>'2',	
		'3'=>'3',
	);
	my $button_gateway_type = fncRadioBtns($gateway_type,'gateway_type',\%button_gateway_type);

	# Create the form
	return qq[
  	<form action="$target" method="post">
  	<input type="hidden" name="action" value="$form_action">
  	<table style="margin-left:auto;margin-right:auto;">
  	$msg
	<tr>
		<td class="formbg fieldlabel">Rule name:</td>
		<td class="formbg"><input type="text" name="rule_name" value="$rule_name"></td>
	</tr>
	<tr>
		<td class="formbg fieldlabel">Realm:</td>
		<td class="formbg">$realms</td>
	</tr>
	<tr>
		<td class="formbg fieldlabel">SubRealm:</td>
		<td class="formbg">$subrealms</td>
	</tr>
	<tr>
		<td class="formbg fieldlabel">Financial Institution:</td>
		<td class="formbg">$button_fin_inst</td>
	</tr>
	<tr>
		<td class="formbg fieldlabel">Status:</td>
		<td class="formbg">$button_status</td>
	</tr>
	<tr>
		<td class="formbg fieldlabel">Fee Allocation Type:</td>
		<td class="formbg">$button_fee_allocation_type</td>
	</tr>
	<tr>
		<td class="formbg fieldlabel">Minimum Fee Type:</td>
		<td class="formbg">$button_min_fee_type</td>
	</tr>
	<tr>
		<td class="formbg fieldlabel">Currency:</td>
		<td class="formbg">$button_currency</td>
	</tr>
	<tr>
		<td class="formbg fieldlabel">Client Currency:</td>
		<td class="formbg">$button_client_currency</td>
	</tr>
	<tr>
		<td class="formbg fieldlabel">FSP Fee:</td>
		<td class="formbg"><input type="text" name="fee_rate" value="$fee_rate" style="width:50px;"></td>
	</tr>
    <tr>
        <td class="formbg fieldlabel">Minimum Fee Point:</td>
        <td class="formbg"><input type="text" name="curMinFeePoint" value="$curMinFeePoint" style="width:50px;"></td>
    </tr>	
	<tr>
		<td class="formbg fieldlabel">MP Email:</td>
		<td class="formbg"><input type="text" name="mp_email" value="$mp_email" style="width:300px;"></td>
	</tr>
	<tr>
		<td class="formbg fieldlabel">MYOB Job Code:</td>
		<td class="formbg"><input type="text" name="myob_job_code" value="$myob_job_code"></td>
	</tr>
	<tr>
		<td class="formbg fieldlabel">Level ID:</td>
		<td class="formbg"><input type="text" name="levelID" value="$levelID"></td>
	</tr>
	<tr>
		<td class="formbg fieldlabel">Entity ID:</td>
		<td class="formbg"><input type="text" name="entityID" value="$entityID"></td>
	</tr>
	<tr>
		<td class="formbg fieldlabel">Notification Email:</td>
		<td class="formbg"><input type="text" name="notification_email" value="$notification_email" style="width:300px;"></td>
	</tr>

    <tr><td class="formbg fieldlabel">Prefix:</td>
    <td class="formbg"><input type="text" name="prefix" value="$prefix"></td></tr>

    <tr><td class="formbg fieldlabel">CC Note:</td>
    <td class="formbg"><input type="text" name="ccnote" value="$ccnote"></td></tr>

	<tr>
		<td class="formbg fieldlabel">Payment Gateway ID:</td>
		<td class="formbg"><input type="text" name="gatewayID" value="$gatewayID"></td>
	</tr>
	<tr>
		<td class="formbg fieldlabel">Gateway Type:</td>
		<td class="formbg">$button_gateway_type</td>
	</tr>
	<tr>
    <td class="formbg" colspan="2" style="text-align:center;">
      <input type="submit" name="submit" value="$button_title">
    </td>
  </tr>
  </form>
    </table>
  ];
}

sub payment_update_db {
  my ($db, $action, $target) = @_;

	my $rule_name     		= param('rule_name') || '';
	my $realmID       		= param('realmID') || '';
	my $subrealmID    		= param('subrealmID') || '';	
	my $fin_inst      		= param('fin_inst') || '';
	my $mp_email      		= param('mp_email') || '';
	my $myob_job_code 		= param('myob_job_code') || '';
	my $levelID  			= param('levelID') || '';	
	my $entityID 			= param('entityID') || '';
	my $currency 			= param('currency') || '';
	my $client_currency 	= param('client_currency') || '';
	my $notification_email 	= param('notification_email') || '';
	my $status				= param('status') || '';
	my $prefix				= param('prefix') || '';
	my $ccnote				= param('ccnote') || '';	
	my $gatewayID			= param('gatewayID') || '';
	my $gateway_type		= param('gateway_type') || '';
    my $fee_allocation_type = param('fee_allocation_type') || '';
    my $min_fee_type        = param('min_fee_type') || '';
    my $fee_rate        	= param('fee_rate') || '';
    my $curMinFeePoint      = param('curMinFeePoint') || '';
            			
	my $pfx = 'Please enter the mandatory fields: ';
	my $msg = '';
	my $response = '';

  	my $st = '';
	my $q = '';
  	
	#Check for valid data from the screen
  	if (!$rule_name) {
  		$msg = $msg . $pfx . 'Rule Name';
  		$pfx = ', ';
  	}
    if (!$realmID and !$subrealmID) {
        $msg = $msg . $pfx . 'Realm/SubRealm ID';
        $pfx = ', ';
    } 
    if (!$mp_email) {
  		$msg = $msg . $pfx . 'MP Email';
  		$pfx = ', ';
  	}
  	if (!$myob_job_code) {
  		$msg = $msg . $pfx . 'MYOB Job Code';
  		$pfx = ', ';
  	}
  	if (!$levelID) {
  		$msg = $msg . $pfx . 'LevelID';
  		$pfx = ', ';
  	}
  	if (!$entityID) {
  		$msg = $msg . $pfx . 'EntityID';
  		$pfx = ', ';
  	}
  	if (!$currency) {
  		$msg = $msg . $pfx . 'Currency';
  		$pfx = ', ';
  	}
  	if (!$client_currency) {
  		$msg = $msg . $pfx . 'Client Currency';
  		$pfx = ', ';
  	}
  	if (!$notification_email) {
  		$msg = $msg . $pfx . 'Notification email';
  		$pfx = ', ';
  	}
  	if (!$prefix) {
        $msg = $msg . $pfx . ' Prefix';
        $pfx = ', ';
    }
    if (!$ccnote) {
        $msg = $msg . $pfx . ' CC note';
        $pfx = ', ';
    }
    if (!$gatewayID) {
        $msg = $msg . $pfx . ' GatewayID';
        $pfx = ', ';
    }
    if (!$gateway_type) {
        $msg = $msg . $pfx . ' Gateway type';
        $pfx = ', ';
    }
    if (!$fee_rate) {
        $msg = $msg . $pfx . ' FSP Fee (default 0.039)';
        $pfx = ', ';
    }
    if (!$curMinFeePoint) {
        $msg = $msg . $pfx . ' Minimum Fee Point (default 25.65)';
        $pfx = ', ';
    } else {
    	if ($curMinFeePoint > 0) {
    		#Any number > 0 is OK
    	}
    	else {
    	    $msg = $msg . '<br>Minimum Fee Point must be greater than zero';
            $pfx = ', ';
    	} 
    }
    
  	if ($realmID) {
  		$st = qq[
     	 	SELECT count(*) as NumRows
    		FROM tblSystemConfig
      		WHERE intRealmID = $realmID
			AND intSubTypeID = $subrealmID
			AND strOption = 'PaymentSplitRuleID'
		];
  	
		$q = $db->prepare($st);
		$q->execute();
		
		if ($q->fetchrow_array()) {
	  		$msg = $msg . '<br>Payments split rule already exists for this Realm/SubRealm ';
	  		$pfx = '<br>';			
		}
  	}
  	
    if ($subrealmID) {
	    if ($realmID) {
	    	 #If the user has specified both Realm an Subrealm, check to see that they match
	         $st = qq[
	            SELECT count(*) as NumRows
	            FROM tblRealmSubTypes
	            WHERE intRealmID = $realmID
	            AND intSubTypeID = $subrealmID
	        ];
	    
	        $q = $db->prepare($st);
	        $q->execute();
	        
	        if (!$q->fetchrow_array()) {
	            $msg = $msg . '<br>The SubRealm selected does not belong to this Realm ';
	            $pfx = '<br>';            
	        }
	    }
	    else {
             $st = qq[
                SELECT intRealmID
                FROM tblRealmSubTypes
                WHERE intSubTypeID = $subrealmID
            ];
        
            $q = $db->prepare($st);
            $q->execute();
            
            my $dref= $q->fetchrow_hashref();
            $realmID = $dref->{intRealmID};
	    }    	
    }
    else {
        $subrealmID = 0;
    }

      	  	
  	if ($msg) {
		#Redisplay the screen with the error message(s)
		return payment_display_input_screen($db, $action, $target, $msg, $realmID);
	}
	
	#Data seems to be OK, so now do DB updates
	$st = qq[
   		INSERT INTO tblPaymentSplitRule
		(
			strRuleName,
			strFinInst,
			intRealmID,
			intSubTypeID,
			strEmailSubject,
			strCurrencyCode,
			strMPEmail,
			strMYOBJobCode
		)
		VALUES
		(?,
		?,
		?,
		?,
		?,
		?,
		?,
		?)
		];
  	$q = $db->prepare($st);
  	$q->execute($rule_name,$fin_inst,$realmID,$subrealmID,'',$currency,$mp_email,$myob_job_code);
	if ($q->errstr) {
		return $q->errstr . '<br>' . $st
	}
  	my $payment_split_ruleID = $q->{mysql_insertid};
  	
	$st = qq[
	  	INSERT INTO tblPaymentConfig
		(
			intLevelID,
			intEntityID,
			strCurrency,
			strClientCurrency,
			intRealmID,
			intRealmSubTypeID,
			intPaymentGatewayID,
			strNotificationAddress,
			intStatus,
			intGatewayType,
			strPrefix,
			strCCNote,
			intPaymentSplitRuleID
		)
		VALUES (
			?,
			?,
			?,
			?,
			?,
			?,
			?,
			?,
			?,	
			?,
			?,
			?,
			?)
		];
 	$q = $db->prepare($st);
  	$q->execute(
  		$levelID,
  		$entityID,
  		$currency,
  		$client_currency,
  		$realmID,
  		$subrealmID,
		$gatewayID, 
		$notification_email,
		$status,
		$gateway_type, 
		$prefix,
		$ccnote,
		$payment_split_ruleID
  		);
	if ($q->errstr) {
		return $q->errstr . '<br>' . $st
	}
	
	$st = qq[
		INSERT INTO tblSystemConfig (
			intTypeID,
			strOption,
			strValue,
			intRealmID,
			intSubTypeID
		)
		VALUES (
			?,
			?,
			?,
			?,
			?)
		];
 	$q = $db->prepare($st);
  	$q->execute(
  		1,
  		'AllowPaymentSplits',
  		1,
  		$realmID,
  		$subrealmID
  		);
	if ($q->errstr) {
		return $q->errstr . '<br>' . $st
	}
  	$q->execute(
  		1,
  		'PaymentSplitRuleID',
  		$payment_split_ruleID,
  		$realmID,
  		$subrealmID
  		);
	if ($q->errstr) {
		return $q->errstr . '<br>' . $st
	}

	$st = qq[
		INSERT INTO tblPaymentSplit (
			intRuleID,
			intEntityTypeID,
			intEntityID,
			strSplitName
		)
		VALUES (?,
		?,
		?,
		'LOW PROCESSING FEE')
		];
 	$q = $db->prepare($st);
  	$q->execute($payment_split_ruleID, $levelID, $entityID);
	if ($q->errstr) {
		return $q->errstr . '<br>' . $st
	}
	my $payment_splitID = $q->{mysql_insertid};

	$st = qq[
	  	INSERT INTO tblProducts (
				strName,
				curDefaultAmount,
				intCreatedLevel,
				intCreatedID,
				intRealmID,
				intPaymentSplitID,
				intProductType
		)
		VALUES
		('LOW PROCESSING FEE',
			1,
			?,
			?,
			?,
			?,
			2)
		];
 	$q = $db->prepare($st);
  	$q->execute(
  		$levelID,
  		$entityID,
  		$realmID,
  		$payment_splitID
  		);
	if ($q->errstr) {
		return $q->errstr . '<br>' . $st
	}
	
	my $min_fee_productID = 0;
	if ($fin_inst eq 'PayPal') {
		$min_fee_productID = $q->{mysql_insertid};
	}

	$st = qq[
	  	INSERT INTO tblPaymentSplitFees
		(
			intRealmID,
			intSubTypeID,
			intFeesType,
			strBankCode,
			strAccountNo,
			strAccountName,
			curAmount,
			dblFactor,
			strMPEmail,
			curMinFeePoint,
			intMinFeeProductID,
			curMaxFeePoint,
			curMaxFee,
			intMinFeeType,
			intFeeAllocationType
		)
		VALUES (
			?,
			?,
			?,
			?,
			?,
			?,
			?,
			?,
			?,
			?,
			?,
			?,
			?,
			?,
			?)
		];
 	$q = $db->prepare($st);
  	$q->execute(
  		$realmID,
  		$subrealmID,
  		1,
  		'',
  		'',
  		'SportingPulse',
  		0.00,
  		$fee_rate,
  		'paypalfees@sportingpulse.com',  #PP what do we do here for NAB?
  		$curMinFeePoint,
  		$min_fee_productID,
  		0,
  		0,
  		$min_fee_type,
  		$fee_allocation_type
  		);
	if ($q->errstr) {
		return $q->errstr . '<br>' . $st
	}
	
  	$q->execute(
  		$realmID,
  		$subrealmID,
  		1,
  		'',
  		'',
  		'SportingPulse',
  		0.30,
  		0.011,
  		'',
  		0,
  		0,
  		0,
  		0,
  		0,
  		1
  		);
  	if ($q->errstr) {
		return $q->errstr . '<br>' . $st
	}	
  	return 'Database updated successfully';	
}

sub fncRadioBtns {
   	my ($field_value,$field_name, $button_fin_inst, $separator) = @_;
		
	my $txt = '';
	my $pfx = '';
	my $sfx = '';
	if (!$separator) {
		$separator = '&nbsp;'
	}
	
	#PP How do I get a sorted list?
	my $i = -1;
    foreach my $key(keys %{$button_fin_inst}) {
       	$i = $i + 1;
        if ($key eq $field_value) { 
            $sfx = ' checked ';
        }
        else {
            $sfx = '';
        }
        $txt = $txt . $pfx . '<input type=radio name="' . $field_name . '" value="' . $key . '"' . $sfx . '>' . $button_fin_inst->{$key};
        $pfx = $separator;
    }
	return $txt;
}

1;
