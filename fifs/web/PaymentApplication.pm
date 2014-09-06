#
# $Header: svn://svn/SWM/trunk/web/PaymentApplication.pm 11647 2014-05-22 04:35:46Z gyeong $
#

package PaymentApplication;
require Exporter;
@ISA = qw(Exporter);
@EXPORT=qw(handlePaymentApplication haveApplied isEmailValidated getFeeTypeDefault);
@EXPORT_OK=qw(handlePaymentApplication haveApplied isEmailValidated getFeeTypeDefault);

use strict;
use CGI qw(param);
use Reg_common;
use Utils;
use HTMLForm;
use TTTemplate;
use AuditLog;
use UploadFiles;

require Payments;

sub handlePaymentApplication {
	my ($action, $Data, $entityID, $entityTypeID, $type)=@_;

	my $resultHTML='';
	my $title='';
	$type ||= param('paytype') || '';
	if ($action =~/^PY_A/) {
			if($type eq 'paypal')	{
				($resultHTML,$title)=application_details(
					$action, 
					$Data, 
					$entityID, 
					$entityTypeID
				);
			}
			elsif($type eq 'nab')	{
				($resultHTML,$title)=nab_application_details(
					$action, 
					$Data, 
					$entityID, 
					$entityTypeID
				);
			}	
	}

	return ($resultHTML,$title);
}

sub application_details	{
	my (
		$action, 
		$Data, 
		$entityID, 
		$entityTypeID,
	)=@_;

    my $hasApplied = haveApplied($Data, $entityTypeID, $entityID) || 0;
    my $option=$hasApplied ? 'edit' : 'add';
	my $field=loadDefaultDetails(
		$Data, 
		$Data->{'db'}, 
		$entityTypeID,
		$entityID,
		11,
	) || ();
	my $realmID = $Data->{'Realm'} || 0;
	
	my $client=setClient($Data->{'clientValues'}) || '';
	my $termstemplate = $Data->{'SystemConfig'}{'TCTemplate'} || 'payment/termsandconditions.templ';
	my $terms = runTemplate($Data, undef, $termstemplate);
	$terms = qq[
			<div style="border:1px solid #555;height:200px;overflow:auto;padding:3px;margin:4px;">$terms</div><br>

		<p>By submitting this application form, you agree to be bound by the terms and conditions. If you are submitting this application on behalf of an association, club or team, you are bound to the terms both in your individual capacity and as an agent of the governing body, association, club or team, and your actions will bind the governing body, association, club or team. You represent and warrant to SportingPulse that you have the capacity and authority to enter into this agreement on your own behalf, as well as on behalf of the relevant governing body, association, club or team.</p><br><br>

	];
    my $resend = $hasApplied ? qq[<br><a href="$Data->{'target'}?client=$client&amp;a=BA_FORMRESEND">Click here to resend application email</a>] : '';
	my $feeexplanation = qq[

<p>Selecting the <b>Inclusive model</b> method means that the processing fee is included within your pricing, therefore you need to calculate the price of your products to include the processing fee. If your products value is below the threshold a 'processing fee' may be added.</p>
<p>Selecting the <b>User Pays</b> method means that the processing fee is displayed to the person making the payment, and it is included "on top" of the total. </p>
<p><a href="http://corp.sportingpulse.com/index.php?id=171" target="moreinfo">Click here for more detail</a></p>
	];
	my $ppexplanation = q[
		<div style="margine:5px;background-color:#F6FF68;padding:6px; border: 1px solid #FFE24F;"><p><b>IMPORTANT NOTE:</b> - PayMySport works by sending your funds to your organisation's PayPal account. Enter the PayPal account email address into the field below.  If you don't have a PayPal account, you will need to open a FREE PayPal Business account.</p>
<p><b><a href="https://www.paypal.com/au/cgi-bin/webscr?cmd=_registration-run" target="ppregister">Click here if you need to create your PayPal Business account (opens in new window).</a></p>
		</div>

	];
	my $validationmessage='';
	if($field->{'strPaymentEmail'})  {
        my $validated = isEmailValidated($Data->{'db'}, $field->{'strPaymentEmail'}) || 0;
        if($validated)  {
            $validationmessage = qq[
                <div class="OKmsg">This email address has been validated</div>
            ];
        }
        else    {
            $validationmessage = qq[
                <div style="border:1px solid #888; padding:10px;display:table;">
                    <div class="warningmsg">This email address has not been validated</div><br>
                    <p>To use this email address for payment it must be validated.  To validate this address you must click the link in the email you were sent.</p><br>
                    <p>To receive the validation email again please click <b>'Resend validation email'</b> button below</p>
                </div>
            ];
        }
    }
	#Hard coded to 1 (Inclusive) on 2012-10-02 as per request by Sales (Daniel Smith)
	my $feedefault = 1;#getFeeTypeDefault($Data, $entityTypeID, $entityID);
	if($Data->{'SystemConfig'}{'OverrideFeeTypeDefault'} =="1" or $hasApplied) {
    	$feedefault = getFeeTypeDefault($Data, $entityTypeID, $entityID);
	} 
    my $paymentSettings = Payments::getPaymentSettings($Data, 0); 
    my $softDescriptor = Payments::getSoftDescriptor($Data, $paymentSettings, $entityTypeID, $entityID);
    my $charCount = 22-length($softDescriptor)-1; ## Extra 1 for space after current text

	my %FieldDefinitions=(
		fields=>	{
			strOrgName => {
				label => 'Legal (Trading)  Name of Organisation',
				value => $field->{strOrgName},
				type  => 'text',
				size  => '40',
				maxsize => '40',
				compulsory => 1,
                readonly => $hasApplied,
                noedit=>$hasApplied,
			},
			strACN => {
				label => 'Incorporation Number or ACN',
				value => $field->{strACN},
				type  => 'text',
				size  => '30',
				maxsize => '50',
				posttext => q[<div style="float:right;width:340px;font-style:italic;">Note: You must be a registered legal entity to use this system.],
				compulsory => 1,
                readonly => $hasApplied,
			},
			strContact => {
				label => 'Organisational Contact',
				value => $field->{strContact},
				type  => 'text',
				size  => '30',
				maxsize => '200',
				compulsory => 1,
                readonly => $hasApplied,
			},
			strContactPhone  => {
				label => 'Phone Contact',
				value => $field->{strContactPhone},
				type  => 'text',
				size  => '15',
				maxsize => '50',
				compulsory => 1,
                readonly => $hasApplied,
			},
			strMailingAddress => {
				label => 'Mailing Address',
				value => $field->{strMailingAddress},
				type  => 'text',
				size  => '50',
				maxsize => '255',
                readonly => $hasApplied,
			},
			strSuburb => {
				label => 'Suburb',
				value => $field->{strSuburb},
				type  => 'text',
				size  => '30',
				maxsize => '200',
				compulsory => 1,
				readonly => $hasApplied,
			},
			strPostalCode => {
				label => 'Postal Code',
				value => $field->{strPostalCode},
				type  => 'text',
				size  => '15',
				maxsize => '15',
                readonly => $hasApplied,
				compulsory => 1,
			},
			strOrgPhone => {
				label => 'Organisation Phone',
				value => $field->{strOrgPhone},
				type  => 'text',
				size  => '20',
				maxsize => '20',
                readonly => $hasApplied,
				compulsory => 1,
			},
			strOrganisationFax => {
				label => 'Organisation Fax',
				value => $field->{strOrganisationFax},
				type  => 'text',
				size  => '20',
				maxsize => '20',
                readonly => $hasApplied,
			},
			strOrgEmail => {
				label => 'Organisation Email',
                readonly => $hasApplied,
				value => $field->{strOrgEmail},
				type  => 'text',
				size  => '35',
				maxsize => '250',
				validate => 'EMAIL',
				compulsory => 1,
			},
			ppexplanation => {
				label => 'pp explanation',
				value => $ppexplanation,
				type  => 'textvalue',
			},
			strSoftDescriptor=> {
				label => 'PayPal Credit Card Descriptor',
				value => $field->{strSoftDescriptor},
				type  => 'text',
				size  => '20',
				maxsize => $charCount,
				posttext => qq[<div style="float:right;width:340px;font-style:italic;">Note: This is the Descriptor that payees will see on their Credit Card statement. It will begin with <b>$softDescriptor</b>.  The field has <b>maximum 22 characters</b>, of which $charCount is allowed for your custom Descriptor</div>],
			},
			strPaymentEmail => {
				label => 'PayPal account Email',
				value => $field->{strPaymentEmail},
                readonly => $hasApplied,
				type  => 'text',
				size  => '35',
				maxsize => '250',
				validate => 'EMAIL',
				posttext => qq[<div style="float:right;width:340px;font-style:italic;">Note: This is the PayPal account to which your funds will be sent and should have limited access appropriate for staff dealing with payments.</div>$resend$validationmessage],
				compulsory => 1,
			},
			strAgreedBy => {
				label => 'Person Agreeing on behalf of the Organisation',
                readonly => $hasApplied,
				value => $field->{strAgreedBy},
				type  => 'text',
				size  => '35',
				maxsize => '250',
				compulsory => 1,
			},
			terms => {
				label => $hasApplied ? '' :'terms and conditions',
				value => $terms,
				type  => 'textvalue',
			},
			FeeType => {
				label => 'Processing fee model',
				type  => 'lookup',
				compulsory => 1,
				value => $feedefault,
				options => {
					1 => 'Inclusive Model',
					2 => 'User Pays',
				},
				SkipProcessing => 1,
				posttext => $feeexplanation,
                readonly => $hasApplied,
			},
		},
		order => [qw(
			strOrgName 
			strACN
			strContact
			strContactPhone
			strMailingAddress
			strSuburb 
			strPostalCode 
			strOrgPhone 
			strOrgFax 
			strOrgEmail 
			ppexplanation
            strSoftDescriptor
			strPaymentEmail 
			terms
			FeeType
			strAgreedBy 
		)],
		options => {
			labelsuffix => ':',
			hideblank => 1,
			target => $Data->{'target'},
			formname => 'n_form',
      submitlabel => "I Agree",
      introtext => '',
			NoHTML => 1, 
      addSQL => qq[
        INSERT INTO tblPaymentApplication
          (intPaymentType, intRealmID, intEntityTypeID, intEntityID, dtCreated,  --FIELDS-- )
          VALUES (11, $realmID, $entityTypeID, $entityID, NOW(), --VAL-- )
			],
      updateSQL => qq[
        UPDATE tblPaymentApplication
        SET --VAL--
        WHERE intEntityTypeID = $entityTypeID 
            AND intEntityID = $entityID
					AND intPaymentType = 11
            LIMIT 1
			],
      afteraddFunction => \&postApplicationAdd,
      afteraddParams => [$option,$Data,$Data->{'db'}],
      beforeaddFunction => \&preApplicationAdd,
      beeforeaddParams => [$option,$Data,$Data->{'db'}, $entityID, $entityTypeID],
      afterupdateFunction => \&postApplicationUpdate,
      afterupdateParams => [$option,$Data,$Data->{'db'}, $entityID, $entityTypeID],

      auditFunction=> \&auditLog,
      auditAddParams => [
        $Data,
        'Create',
        'Payment Application'
      ],
      auditEditParams => [
        $entityID,
        $Data,
        'Update',
        'Payment Application'
      ],

      LocaleMakeText => $Data->{'lang'},
		},
		carryfields =>	{
			client => $client,
			a=> $action,
			paytype => 'paypal',
		},
	);
	my $resultHTML='';
	($resultHTML, undef )=handleHTMLForm(\%FieldDefinitions, undef, $option, '',$Data->{'db'});
	my $title=$field->{strName};
	$resultHTML = qq[
		<div class="pageHeading">PayPal Account Application</div>
		$resultHTML
	];

	return ($resultHTML,$title);
}

sub preApplicationAdd {
  my($params,$action,$Data,$db, $entityID, $entityTypeID)=@_;
  return undef if !$db;
  return if ! $entityID;
  return if ! $entityTypeID;

  my $st = qq[
    DELETE FROM tblPaymentApplication
    WHERE intEntityTypeID=$entityTypeID
    AND intEntityID = $entityID
		AND intPaymentType = 11
    LIMIT 1
  ];
  $db->do($st);
    return (1,'');
}

sub checkSoftDescriptor {

    my ($db,$softDescriptor, $entityID, $entityTypeID) = @_;

    $entityID ||= 0;
    $entityTypeID ||= 0;
    return if !$entityID or !$entityTypeID;

    $softDescriptor =~ s/[^a-zA-Z\-\*\.0-9 ]//g;

    my $st = qq[
        UPDATE
            tblPaymentApplication
        SET
            strSoftDescriptor=?
        WHERE
            intEntityID=$entityID
            and intEntityTypeID=$entityTypeID
        LIMIT 1
    ];
    my $query = $db->prepare($st);
    $query->execute($softDescriptor);

}

sub postApplicationUpdate   {

  my($id,$params,$action,$Data,$db, $entityID, $entityTypeID)=@_;
  return undef if !$db or !$entityID or ! $entityTypeID;

    checkSoftDescriptor($db, $params->{'d_strSoftDescriptor'}, $entityID, $entityTypeID);
}
sub postApplicationAdd {
  my($id,$params,$action,$Data,$db)=@_;
  return undef if !$db;


	my $cl=setClient($Data->{'clientValues'}) || '';
	my %cv=getClient($cl);
	my $entityTypeID = $cv{'currentLevel'};
	my $entityID = getID(\%cv, $entityTypeID);

    checkSoftDescriptor($db, $params->{'d_strSoftDescriptor'}, $entityID, $entityTypeID);

	if($params->{'d_FeeType'})	{

		updateFeeType($Data, $entityTypeID, $entityID, $params->{'d_FeeType'} || 0);

	}

  if($action eq 'add')  {
		{
			my $st = qq[
				INSERT INTO tblBankAccount (
					intEntityTypeID,
					intEntityID,
					strMPEmail
				)
				VALUES (
					?,
					?,
					?
				)
				ON DUPLICATE KEY UPDATE strMPEmail = ?
			];
			my $q = $db->prepare($st);
			$q->execute(
				$entityTypeID,
				$entityID,
				$params->{'d_strPaymentEmail'},
				$params->{'d_strPaymentEmail'},
			);
			$q->finish();
			$st = qq[
                        UPDATE tblMoneyLog
                        SET
                                strMPEmail = ?
                        WHERE
                                intEntityType = ?
                                AND intEntityID = ?
                                AND intExportBankFileID = 0
                                AND intRealmID=$Data->{'Realm'}
				                AND intLogType=6
                ];
                $q = $Data->{'db'}->prepare($st);
                $q->execute(
			$params->{'d_strPaymentEmail'},
                        $entityTypeID,
                        $entityID
                );
                $q->finish();
		}
		require BankAccountSetup;
		my $emailvalidated = BankAccountSetup::isEmailValidated($db, $params->{'d_strPaymentEmail'});
		BankAccountSetup::sendValidationEmail($Data, $params->{'d_strPaymentEmail'}) if !$emailvalidated;

		my $emailtext = qq[
<p>An email has been sent to the PayPal account email you entered - you need to click on the link in that email to validate the email address. </p>
<br>
<p><b>Please note: Until you validate the address, funds cannot be sent to your PayPal account. </b></p>
<br>
		];
		$emailtext = '' if $emailvalidated;
		return (0,qq[
			<div class="OKmsg">Your Application form has been submitted</div><br>

			<h2>What do I do next?</h2>
<br>
			<p>Now that you've signed up for PayMySport, you need to set up your registration form (if you haven't already) and the products you want members to pay for, then make your registration form available for people to use. </p>
<br>
<p>To view a recorded webinar on setting up your forms and how PayMySport works, click this link (opens in a new tab/window).</p>

<p><a href="http://supportwiki.sportingpulse.com/index.php/Online_Registration_and_Payment_-_Overview">http://supportwiki.sportingpulse.com/index.php/Online_Registration_and_Payment_-_Overview</a></p>
<br>
$emailtext
<p>For more information, please visit the Member Centre on www.paymysport.com . </p>
 
		]);
  }
}


sub loadDefaultDetails	{
	my (
		$Data,
    $db,
    $entityTypeID,
    $entityID,
		$paymenttype,
  ) = @_;

	return undef if !$entityID;
	return undef if !$entityTypeID;
	my $st = '';

    $st = qq[
        SELECT *
        FROM tblPaymentApplication
        WHERE intEntityID=?
            AND intEntityTypeID= ?
					AND intPaymentType = ?
    ];
    my $query = $db->prepare($st);
    $query->execute($entityID, $entityTypeID, $paymenttype);
	my $field=$query->fetchrow_hashref();
    $query->finish;
    $st = '';
    foreach my $key (keys %{$field})  { if(!defined $field->{$key}) {$field->{$key}='';} }
    return $field if $field->{intApplicationID};
	if($entityTypeID == $Defs::LEVEL_ASSOC)	{
		$st = qq[
			SELECT 
				strIncNo AS strACN,
				strContact,
				strPhone AS strContactPhone,
				strAddress1 AS strMailingAddress,
				strSuburb,
				strPostalCode,
				strPhone AS strOrgPhone,
				strFax AS strOrgFax,
				strEmail AS strOrgEmail
			FROM tblAssoc 
			WHERE intAssocID = ?
		];
	}
 	elsif($entityTypeID == $Defs::LEVEL_CLUB)	{
		$st = qq[
			SELECT 
				strIncNo AS strACN,
				strContact,
				strPhone AS strContactPhone,
				strAddress1 AS strMailingAddress,
				strSuburb,
				strPostalCode,
				strPhone AS strOrgPhone,
				strFax AS strOrgFax,
				strEmail AS strOrgEmail
			FROM tblClub 
			WHERE intClubID = ?
		];
	}
 	elsif($entityTypeID > $Defs::LEVEL_ASSOC )	{
		$st = qq[
			SELECT 
				strContact,
				strPhone AS strContactPhone,
				strAddress1 AS strMailingAddress,
				strSuburb,
				strPostalCode,
				strPhone AS strOrgPhone,
				strFax AS strOrgFax,
				strEmail AS strOrgEmail
			FROM tblNode 
			WHERE intNodeID = ?
		];
	} 
	return undef if !$st;
   $query = $db->prepare($st);
  $query->execute($entityID);
	$field=$query->fetchrow_hashref();
  $query->finish;
                                                                                                        
  foreach my $key (keys %{$field})  { if(!defined $field->{$key}) {$field->{$key}='';} }

	my @contacts = ();
	{
		my $assocID = getID($Data->{'clientValues'}, $Defs::LEVEL_ASSOC);
		$assocID = 0 if $assocID < 0;
		my $clubID = getID($Data->{'clientValues'}, $Defs::LEVEL_CLUB);
		$clubID = 0 if $clubID < 0;
		my $st = qq[
			SELECT
				strContactFirstname,
				strContactSurname,
				strContactMobile,
				strContactEmail,
				strRoleName
			FROM tblContacts AS C
				INNER JOIN tblContactRoles AS CR
					ON C.intContactRoleID = CR.intRoleID
			WHERE intAssocID = ?
				AND intClubID = ?
			ORDER BY intRoleOrder ASC

		];
    my $q= $db->prepare($st);
		$q->execute(
			$assocID,
			$clubID,
		);
		while (my $field = $q->fetchrow_hashref())	{
			push @contacts, $field;
		}
		$q->finish;
		$field->{'Contacts'} = \@contacts;
	}
	
  return $field;
}

sub haveApplied	{
	my ($Data, $entityTypeID, $entityID, $appType)=@_;

	$appType ||= 0;

	my $st = qq[
		SELECT intApplicationID,
			strOrgName,
			DATE_FORMAT(dtCreated,'%d/%m/%Y %H:%i') AS dtCreated,
			intLocked

		FROM tblPaymentApplication
		WHERE 
			intEntityTypeID = ?
			AND intEntityID = ?
			AND intPaymentType = ?
            AND strPaymentEmail<>''
	];
  my $query = $Data->{'db'}->prepare($st);
  $query->execute($entityTypeID, $entityID, $appType);
	my ($appID, $name, $date, $locked)=$query->fetchrow_array();
  $query->finish;
	if(wantarray)	{
		return ($appID, $name, $date, $locked);
	}
	else	{
		return $appID ? 1 : 0;
	}
}

sub getFeeTypeDefault	{
	my ($Data, $entityTypeID, $entityID)=@_;

	my $defaultvalue = 0;

	#First try individual entity
	{
		my $st = '';
		if($entityTypeID == $Defs::LEVEL_ASSOC)	{
			$st = qq[
				SELECT intAssocFeeAllocationType
				FROM tblAssoc
				WHERE intAssocID = ?
			];
		}
		elsif($entityTypeID == $Defs::LEVEL_CLUB)	{
			$st = qq[
				SELECT intClubFeeAllocationType
				FROM tblClub
				WHERE intClubID = ?
			];
		}
		if($st)	{
			my $q = $Data->{'db'}->prepare($st);
			$q->execute($entityID);
			($defaultvalue) = $q->fetchrow_array();
			$q->finish();
		}
	}
	if(!$defaultvalue)	{
		#Entity doesn't have one, now try realm
		my $st = qq[
			SELECT intFeeAllocationType
			FROM tblPaymentSplitFees as PSF
			WHERE PSF.intRealmID = $Data->{'Realm'}
				AND PSF.intSubTypeID IN (0,$Data->{'RealmSubType'})
				AND PSF.intFeesType=1
			ORDER BY PSF.intSubTypeID DESC
			LIMIT 1
		];
		my $q= $Data->{'db'}->prepare($st);
		$q->execute();
		($defaultvalue) = $q->fetchrow_array();
		$q->finish();
	}
	return $defaultvalue || 0;
}

sub updateFeeType {
	my ($Data, $entityTypeID, $entityID, $value)=@_;

	my $st = '';
	if($entityTypeID == $Defs::LEVEL_ASSOC)	{
		$st = qq[
			UPDATE tblAssoc
			SET intAssocFeeAllocationType = ?
			WHERE intAssocID = ?
		];
	}
	elsif($entityTypeID == $Defs::LEVEL_CLUB)	{
		$st = qq[
			UPDATE tblClub
			SET intClubFeeAllocationType = ?
			WHERE intClubID = ?
		];
	}
	if($st)	{
		my $q = $Data->{'db'}->prepare($st);
		$q->execute($value, $entityID);
		$q->finish();
		return 1;
	}
	return 0;
}
sub isEmailValidated {
    my($db, $email) = @_;


    my $st = qq[
        SELECT
            dtVerified
        FROM tblVerifiedEmail
        WHERE strEmail = ?
            AND dtVerified > '1900-01-01'
    ];
    my $qv = $db->prepare($st);
    $qv->execute($email);
    my($found) = $qv->fetchrow_array();
    $qv->finish();

    return $found || 0;
}

sub nab_application_details	{
	my (
		$action, 
		$Data, 
		$entityID, 
		$entityTypeID,
	) = @_;

	my ($appID, $name, $date, $locked) = haveApplied($Data, $entityTypeID, $entityID, $Defs::PAYMENT_ONLINENAB);

	my $header = $appID 
		? qq[<p><b>Application Submitted $date</b></p>]
		: '';
	my $option=$appID ? 'edit' : 'add';
	my $hasApplied = $locked || 0;
	$option = 'display' if $locked;
	my $field=loadDefaultDetails(
		$Data, 
		$Data->{'db'}, 
		$entityTypeID,
		$entityID,
		$Defs::PAYMENT_ONLINENAB,
	) || ();
	my $realmID = $Data->{'Realm'} || 0;
	
	my $client=setClient($Data->{'clientValues'}) || '';
	my $termstemplate = $Data->{'SystemConfig'}{'TCTemplateNAB'} || 'payment/termsandconditionsNAB.templ';
	my $terms = runTemplate($Data, undef, $termstemplate);
	$terms = qq[
			<div style="border:1px solid #555;height:200px;overflow:auto;padding:3px;margin:4px;">$terms</div><br>

		<p>By submitting this application form, you agree to be bound by the terms and conditions. If you are submitting this application on behalf of an association, club or team, you are bound to the terms both in your individual capacity and as an agent of the governing body, association, club or team, and your actions will bind the governing body, association, club or team. You represent and warrant to SportingPulse that you have the capacity and authority to enter into this agreement on your own behalf, as well as on behalf of the relevant governing body, association, club or team.</p><br><br>

<p><b>Please Note: </b> There is a fee of \$65 for your organisation to be accepted and set up as a sub-merchant. You will receive an invoice for this one off fee.  A percentage fee on each transaction will be charged with a minimum of \$1.00.
</p>
<br>
	];
    my $resend = $hasApplied ? qq[<br><a href="$Data->{'target'}?client=$client&amp;a=BA_FORMRESEND">Click here to resend application email</a>] : '';
	my $feeexplanation = qq[

<p>Selecting the <b>Inclusive model</b> method means that the processing fee is included within your pricing, therefore you need to calculate the price of your products to include the processing fee.  If your products value is below the threshold a 'processing fee' may be added.</p>
<p>Selecting the <b>User Pays</b> method means that the processing fee is displayed to the person making the payment, and it is included "on top" of the total. </p>
<p><a href="http://corp.sportingpulse.com/index.php?id=171" target="moreinfo">Click here for more detail</a></p>
	];
	my $ppexplanation = q[
		<div style="margine:5px;background-color:#F6FF68;padding:6px; border: 1px solid #FFE24F;"><p><b>IMPORTANT NOTE:</b> - PayMySport works by sending your funds to your organisation's PayPal account. Enter the PayPal account email address into the field below.  If you don't have a PayPal account, you will need to open a FREE PayPal Business account.</p>
<p><b><a href="https://www.paypal.com/au/cgi-bin/webscr?cmd=_registration-run" target="ppregister">Click here if you need to create your PayPal Business account (opens in new window).</a></p>
		</div>

	];
	my $validationmessage='';
	if($field->{'strPaymentEmail'})  {
        my $validated = isEmailValidated($Data->{'db'}, $field->{'strPaymentEmail'}) || 0;
        if($validated)  {
            $validationmessage = qq[
                <div class="OKmsg">This email address has been validated</div>
            ];
        }
        else    {
            $validationmessage = qq[
                <div style="border:1px solid #888; padding:10px;display:table;">
                    <div class="warningmsg">This email address has not been validated</div><br>
                    <p>To use this email address for payment it must be validated.  To validate this address you must click the link in the email you were sent.</p><br>
                    <p>To receive the validation email again please click <b>'Resend validation email'</b> button below</p>
                </div>
            ];
        }
    }
	#Hard coded to 1 (Inclusive) on 2012-10-02 as per request by Sales (Daniel Smith)
	my $feedefault = 1;#getFeeTypeDefault($Data, $entityTypeID, $entityID);
	if($Data->{'SystemConfig'}{'OverrideFeeTypeDefault'} =="1" or $hasApplied) {
        	$feedefault = getFeeTypeDefault($Data, $entityTypeID, $entityID);
        }
	
	my $paymentSettings = Payments::getPaymentSettings($Data, 0); 
	my $softDescriptor = Payments::getSoftDescriptor($Data, $paymentSettings, $entityTypeID, $entityID);
	my $charCount = 22-length($softDescriptor)-1; ## Extra 1 for space after current text

	my $contact1 = $field->{'Contacts'} ? $field->{'Contacts'}[0]  : ();
	my $contact2 = $field->{'Contacts'} ? $field->{'Contacts'}[1]  : ();
	my %hasaccount = (1 => '', 2 => '', 3 => '');
	$hasaccount{$field->{'intHasBankAccount'}} = 'checked';

	my %FieldDefinitions=(
		fields=>	{
			strOrgName => {
				label => 'Legal (Trading)  Name of Organisation',
				value => $field->{strOrgName},
				type  => 'text',
				size  => '40',
				maxsize => '250',
				compulsory => 1,
				readonly => $hasApplied,
				noedit=>$hasApplied,
				sectionname => 'orgdetails',
			},
      intPreviousApplication => {
        label => 'Have you previously applied for merchant status with NAB through Fox Sports Pulse for this Legal Name?',
        value => $field->{intPreviousApplication},
        type  => 'lookup',
        options => {1 => 'Yes', 0 => 'No'},
        firstoption => ['',''],
				sectionname => 'orgdetails',
				readonly => $hasApplied,
				compulsory => 1,
      },
			strShortBusName => {
				label => 'Shortened Business Name',
				value => $field->{strShortBusName},
				type  => 'text',
				size  => '20',
				maxsize => '24',
				compulsory => 1,
				readonly => $hasApplied,
				noedit=>$hasApplied,
				sectionname => 'orgdetails',
				posttext => q[<div style=";font-style:italic;">20 characters maximum.</div>],
			},

			strStreetAddress1 => {
				label => 'Street Address 1',
				value => $field->{strStreetAddress1},
				type  => 'text',
				size  => '50',
				maxsize => '100',
				readonly => $hasApplied,
				sectionname => 'orgdetails',
				posttext => q[<div style=";font-style:italic;">This may be your club room or place where you play. It cannot be a PO Box. Nothing will be posted here.</div>],
				compulsory => 1,
			},
			strStreetAddress2 => {
				label => 'Street Address 2',
				value => $field->{strStreetAddress2},
				type  => 'text',
				size  => '50',
				maxsize => '100',
				readonly => $hasApplied,
				sectionname => 'orgdetails',
			},			
			strSuburb => {
				label => 'Suburb',
				value => $field->{strSuburb},
				type  => 'text',
				size  => '30',
				maxsize => '200',
				compulsory => 1,
				readonly => $hasApplied,
				sectionname => 'orgdetails',
			},
			strState => {
				label => 'State',
				value => $field->{strState},
				firstoption => ['',' '],
				type  => 'lookup',
				size  => '1',
				compulsory => 1,
				options => {
					"Australian Capital Territory" => "Australian Capital Territory",
					"New South Wales" => "New South Wales",
					"Northern Territory" => "Northern Territory",
					"Queensland" => "Queensland",
					"South Australia" => "South Australia",
					"Tasmania" => "Tasmania",
					"Victoria" => "Victoria",
					"Western Australia" => "Western Australia",
                    "New Zealand" => "New Zealand"
				},
                order=> ["optgroup label ='Australian states'", 
                            "Australian Capital Territory",
                            "New South Wales",
                            "Northern Territory", 
                            "Queensland" ,
                            "South Australia" ,
                            "Tasmania",
                            "Victoria",
                            "Western Australia",
                        "/optgroup",
                        "optgroup label ='Other'" ,
                            "New Zealand",
                        "/optgroup"
                        ],
				readonly => $hasApplied,
				sectionname => 'orgdetails',
			},
			strPostalCode => {
				label => 'Postal Code',
				value => $field->{strPostalCode},
				type  => 'text',
				size  => '15',
				maxsize => '15',
				readonly => $hasApplied,
				compulsory => 1,
				sectionname => 'orgdetails',
			},

			strOrgPhone => {
				label => 'Organisation Phone',
				value => $field->{strOrgPhone},
				type  => 'text',
				size  => '20',
				maxsize => '20',
				readonly => $hasApplied,
				compulsory => 1,
				sectionname => 'orgdetails',
			},
			strURL => {
				label => 'Organisation Website',
				readonly => $hasApplied,
				value => $field->{strURL},
				type  => 'text',
				size  => '35',
				maxsize => '250',
				compulsory => 1,
				sectionname => 'orgdetails',
				readonly => $hasApplied,
			},

      intIncorpStatus => {
        label => 'Is your organisation incorporated?',
        value => $field->{intIncorpStatus},
        type  => 'lookup',
        options => {1 => 'Yes', 0 => 'No'},
        firstoption => ['',''],
				sectionname => 'orgdetails',
				readonly => $hasApplied,
				compulsory => 1,
				posttext => q[<div style=";font-style:italic;">If <b>Yes</b> then an ACN or ARBN (or New Zealand equivalent)  must be supplied.</div>],
      },
      intGST => {
        label => 'Is your organisation registered for GST?',
        value => $field->{intGST},
        type  => 'lookup',
        options => {1 => 'Yes', 0 => 'No'},
        firstoption => ['',''],
				sectionname => 'orgdetails',
				readonly => $hasApplied,
				compulsory => 1,
				posttext => q[<div style=";font-style:italic;">If <b>Yes</b> then an ABN must be supplied. (Not applicable to New Zealand) </div>],
      },
			strABN => {
				label => 'ABN',
				value => $field->{strABN},
				type  => 'text',
				size  => '30',
				maxsize => '50',
				readonly => $hasApplied,
				sectionname => 'orgdetails',
			},
			strACN => {
				label => 'ACN (Australian Company Number)',
				value => $field->{strACN},
				type  => 'text',
				size  => '30',
				maxsize => '50',
				readonly => $hasApplied,
				sectionname => 'orgdetails',
			},
			strARBN=> {
				label => 'ARBN (Australian Registered Business Number)',
				value => $field->{strARBN},
				type  => 'text',
				size  => '30',
				maxsize => '50',
				readonly => $hasApplied,
				sectionname => 'orgdetails',
				posttext => q[<div style=";font-style:italic;">Used for a foreign company registered in Australia</div>],
			},
      strOrgType => {
        label => 'What does your Organisation do?',
        value => $field->{strOrgType},
        type  => 'lookup',
        options => {'League or Sporting Club' => 'League or Sporting Club', 'Private Sport Provider' => 'Private Sport Provider', 'Other' => 'Other'},
        firstoption => ['',''],
				sectionname => 'orgdetails',
				readonly => $hasApplied,
				compulsory => 1,
      },
			strOrgTypeOther => {
				label => 'If other, please list here:',
				value => $field->{strOrgTypeOther},
				type  => 'text',
				size  => '30',
				maxsize => '50',
				readonly => $hasApplied,
				sectionname => 'orgdetails',
			},

      strApplicantTitle => {
        label => 'Applicant Title',
        value => $field->{strApplicantTitle},
        type  => 'text',
        size  => '5',
        maxsize => '5',
        readonly => $hasApplied,
        sectionname => 'applicant',
      },
      strApplicantFirstName => {
        label => 'Applicant First Name',
        value => $field->{strApplicantFirstName},
        type  => 'text',
        size  => '50',
        maxsize => '50',
        readonly => $hasApplied,
        sectionname => 'applicant',
				compulsory => 1,
      },
      strApplicantInitial => {
        label => 'Applicant Middle Initial',
        value => $field->{strApplicantInitial},
        type  => 'text',
        size  => '1',
        maxsize => '1',
        readonly => $hasApplied,
        sectionname => 'applicant',
      },      
			strApplicantFamilyName => {
        label => 'Applicant Family Name',
        value => $field->{strApplicantFamilyName},
        type  => 'text',
        size  => '50',
        maxsize => '50',
        readonly => $hasApplied,
        sectionname => 'applicant',
				compulsory => 1,
      },
			strApplicantPosition => {
        label => 'Applicant Position',
        value => $field->{strApplicantPosition},
        type  => 'text',
        size  => '50',
        maxsize => '50',
        readonly => $hasApplied,
        sectionname => 'applicant',
				compulsory => 1,
      },
      strApplicantEmail => {
        label => 'Applicant Email',
        value => $field->{'strApplicantEmail'},
        type  => 'text',
        size  => '50',
        maxsize => '250',
        readonly => $hasApplied,
        sectionname => 'applicant',
				validate => 'EMAIL',
				compulsory => 1,
      },
      strApplicantPhone => {
        label => 'Applicant Phone',
        value => $field->{strApplicantPhone},
        type  => 'text',
        size  => '20',
        maxsize => '20',
        readonly => $hasApplied,
        sectionname => 'applicant',
				compulsory => 1,
      },

      strOB1_FirstName => {
        label => 'First Name',
        value => $field->{strOB1_FirstName} || $contact1->{'strContactFirstname'},
        type  => 'text',
        size  => '50',
        maxsize => '50',
        readonly => $hasApplied,
        sectionname => 'officebearer1',
				compulsory => 1,
      },
      strOB1_FamilyName => {
        label => 'Family Name',
        value => $field->{strOB1_FamilyName} || $contact1->{'strContactSurname'},
        type  => 'text',
        size  => '50',
        maxsize => '50',
        readonly => $hasApplied,
        sectionname => 'officebearer1',
				compulsory => 1,
      },
      strOB1_Position => {
        label => 'Position',
        value => $field->{strOB1_Position} || $contact1->{'strRoleName'},
        type  => 'text',
        size  => '50',
        maxsize => '50',
        readonly => $hasApplied,
        sectionname => 'officebearer1',
				compulsory => 1,
      },
      strOB1_Phone => {
        label => 'Phone',
        value => $field->{strOB1_Phone} || $contact1->{'strContactMobile'},
        type  => 'text',
        size  => '20',
        maxsize => '50',
        readonly => $hasApplied,
        sectionname => 'officebearer1',
				compulsory => 1,
      },
      strOB1_Email => {
        label => 'Email',
        value => $field->{strOB1_Email} || $contact1->{'strContactEmail'},
        type  => 'text',
        size  => '50',
        maxsize => '250',
        readonly => $hasApplied,
        sectionname => 'officebearer1',
				validate => 'EMAIL',
				compulsory => 1,
      },
      strOB2_FirstName => {
        label => 'First Name',
        value => $field->{strOB2_FirstName} || $contact2->{'strContactFirstname'},
        type  => 'text',
        size  => '50',
        maxsize => '50',
        readonly => $hasApplied,
        sectionname => 'officebearer2',
      },
      strOB2_FamilyName => {
        label => 'Family Name',
        value => $field->{strOB2_FamilyName} || $contact2->{'strContactSurname'},
        type  => 'text',
        size  => '50',
        maxsize => '50',
        readonly => $hasApplied,
        sectionname => 'officebearer2',
      },
      strOB2_Position => {
        label => 'Position',
        value => $field->{strOB2_Position} || $contact2->{'strRoleName'},
        type  => 'text',
        size  => '50',
        maxsize => '50',
        readonly => $hasApplied,
        sectionname => 'officebearer2',
      },
      strOB2_Phone => {
        label => 'Phone',
        value => $field->{strOB2_Phone} || $contact2->{'strContactMobile'},
        type  => 'text',
        size  => '20',
        maxsize => '50',
        readonly => $hasApplied,
        sectionname => 'officebearer2',
      },
      strOB2_Email => {
        label => 'Email',
        value => $field->{strOB2_Email} || $contact2->{'strContactEmail'},
        type  => 'text',
        size  => '50',
        maxsize => '250',
        readonly => $hasApplied,
        sectionname => 'officebearer2',
				validate => 'EMAIL',
      },
			txnexplanation => {
				label => !$hasApplied ? 'txn_explanation' : '',
				value => 'Note: The following information is required by the bank to assess risk.
						<!--<img src="https://reg.sportingpulse.com/images/nab-logo-email.png" style="float:right;padding:3px;">-->',
				type  => 'textvalue',
        sectionname => 'txns',
			},

      intNumberTxns => {
        label => 'How many members does your organisation have?',
        value => $field->{intNumberTxns},
        type  => 'text',
        size  => '7',
        maxsize => '7',
        readonly => $hasApplied,
        sectionname => 'txns',
				compulsory => 1,
        validate => 'NUMBER',
      },
      intAvgCost => {
        label => 'What is your average registration fee?',
        value => $field->{intAvgCost},
        type  => 'text',
        size  => '7',
        maxsize => '7',
        readonly => $hasApplied,
        sectionname => 'txns',
				compulsory => 1,
        validate => 'NUMBER',
      },
      intTotalTurnover => {
        label => "What is your organisation's total annual income?",
        value => $field->{intTotalTurnover},
        type  => 'text',
        size  => '9',
        maxsize => '9',
        readonly => $hasApplied,
        sectionname => 'txns',
				compulsory => 1,
        validate => 'NUMBER',
      },
      intEstimateGatewayRev => {
        label => "How much revenue do you anticipate will go through this gateway?",
        value => $field->{intEstimateGatewayRev},
        type  => 'text',
        size  => '9',
        maxsize => '9',
        readonly => $hasApplied,
        sectionname => 'txns',
                compulsory => 1,
        validate => 'NUMBER',
      },

			ppexplanation => {
				label => 'pp explanation',
				value => $ppexplanation,
				type  => 'textvalue',
        sectionname => 'other',
			},
			strSoftDescriptor=> {
				label => 'Credit Card Descriptor',
				value => $field->{strSoftDescriptor},
				type  => 'text',
				size  => '20',
				maxsize => $charCount,
				posttext => qq[<div style="float:right;width:340px;font-style:italic;">Note: This is the Descriptor that payees will see on their Credit Card statement. It will begin with <b>$softDescriptor</b>.  The field has <b>maximum 22 characters</b>, of which $charCount is allowed for your custom Descriptor</div>],
        sectionname => 'other',
				compulsory => 1,
				readonly => $hasApplied,
			},
			strPaymentEmail => {
				label => 'Accounts Email',
				value => $field->{strPaymentEmail},
                readonly => $hasApplied,
				type  => 'text',
				size  => '35',
				maxsize => '250',
				validate => 'EMAIL',
				compulsory => 1,
				posttext => qq[<div style="float:right;width:340px;font-style:italic;">Note: This is where your invoices will be sent.</div>],
        sectionname => 'other',
			},
			terms => {
				label => 'terms and conditions',
				value => $terms,
				type  => 'textvalue',
        sectionname => 'other',
			},
			FeeType => {
				label => 'Processing fee model',
				type  => 'lookup',
				compulsory => 1,
				value => $feedefault,
				options => {
					1 => 'Inclusive Model',
					2 => 'User Pays',
				},
				SkipProcessing => 1,
				posttext => $feeexplanation,
				readonly => $hasApplied,
        sectionname => 'other',
			},
			bankstatement => {
				label => !$hasApplied ? 'Bank Statement' : '',
				value => qq[<p>To validate your organsational status, please provide a scanned copy of your latest bank statement.</p>
                            <p>Please ensure that the attached bank statement includes the following, and that they are the same as the bank account details given<br /> 1. Acccount Name<br />2. Account No.<br />3. BSB<br /></p>
                            <input type="file" name="bankstatement"> <img src="images/compulsory.gif" alt="Compulsory Field" title="Compulsory Field">],
				type  => 'textvalue',
				SkipProcessing => 1,
        sectionname => 'doco',
			},
			intHasBankAccount => {
				label => !$hasApplied ? 'Bank Account Details' : '',
				value => qq[

					<div>
								<label for = "baccount_bsb">BSB : </label><input type="text" name="bsb" id = "baccount_bsb" maxlength = "6" size = "6" value = "$field->{'strBSB'}"> <i>No Spaces</i><br>
								<label for = "baccount_num">Account Number : </label><input type="text" name="ba_num" id = "baccount_num" maxlength = "9" size = "9" value = "$field->{'strAccountNum'}"><i>No Spaces</i></br>
								<label for = "baccount_num">Account Name : </label><input type="text" name="ba_name" id = "baccount_name" maxlength = "" size = "" value = "$field->{'strAccountName'}">
					</div>
				],
				type  => 'htmlblock',
        sectionname => 'txns',
                posttext => qq[<div style="float:right;width:340px;font-style:italic;">Note: New Zealand customers should enter first 6 digits in bsb box and remaining numbers in account number box.</div>],
			},
      strVoucherCode => {
        label => 'Promotional Code',
        readonly => $hasApplied,
        value => $field->{'strVoucherCode'},
        type  => 'text',
        size  => '25',
        maxsize => '250',
        compulsory => 0,
        posttext => qq[<div style="float:right;width:340px;font-style:italic;">Note: If you have a promotional code, please enter it here.  </div>],
        sectionname => 'other',
      },

      strParentMerchantCode => {
        label => 'Parent Body Merchant Code',
        readonly => $hasApplied,
        value => $field->{'strParentMerchantName'},
        type  => 'text',
        size  => '25',
        maxsize => '250',
        compulsory => 0,
        posttext => qq[<div style="float:right;width:340px;font-style:italic;">Please fill in the following two fields only if you have been provided a merchant code by your parent body.</div>],
        sectionname => 'other',
      },
      strParentMerchantName => {
        label => 'Parent Body Merchant Name',
        readonly => $hasApplied,
        value => $field->{'strParentMerchantName'},
        type  => 'text',
        size  => '25',
        maxsize => '250',
        compulsory => 0,
        posttext => qq[],
        sectionname => 'other',
      },
		},
		order => [qw(
			strOrgName 
			intPreviousApplication
			strShortBusName
			strStreetAddress1
			strStreetAddress2
			strSuburb 
			strState
			strPostalCode
			strOrgPhone 
			intIncorpStatus
			strACN
			strARBN
			intGST
			strABN	
			strOrgType
			strOrgTypeOther

			strApplicantTitle
			strApplicantFirstName
			strApplicantInitial
			strApplicantFamilyName
			strApplicantPosition
			strApplicantPhone
			strApplicantEmail
	
			strOB1_FirstName
			strOB1_FamilyName
			strOB1_Position
			strOB1_Phone
			strOB1_Email

			strOB2_FirstName
			strOB2_FamilyName
			strOB2_Position
			strOB2_Phone
			strOB2_Email

			txnexplanation
			intNumberTxns
			intAvgCost
			intTotalTurnover
            intEstimateGatewayRev
			intHasBankAccount
			bankstatement

			strSoftDescriptor
			strPaymentEmail 
			FeeType
			strVoucherCode
			strParentMerchantCode
			strParentMerchantName
			terms
		)],
		options => {
			labelsuffix => ':',
			hideblank => 1,
			target => $Data->{'target'},
			formname => 'n_form',
      submitlabel => "I Agree",
      introtext => '',
			NoHTML => 1, 
			FormEncoding=>'multipart/form-data',
      addSQL => qq[

        INSERT INTO tblPaymentApplication
          (intPaymentType, intRealmID, intEntityTypeID, intEntityID, dtCreated,  --FIELDS-- )
          VALUES ($Defs::PAYMENT_ONLINENAB, $realmID, $entityTypeID, $entityID, NOW(), --VAL-- )
			],
      updateSQL => qq[
        UPDATE tblPaymentApplication
        SET intApplicationStatus = 0, intLocked = 1, --VAL--
        WHERE intEntityTypeID = $entityTypeID 
            AND intEntityID = $entityID
					AND intPaymentType = $Defs::PAYMENT_ONLINENAB
            LIMIT 1
			],
      afteraddFunction => \&postNABApplicationAdd,
      afteraddParams => [$option,$Data,$Data->{'db'}, $entityID, $entityTypeID],
      beforeaddFunction => \&preNABApplicationAdd,
      beforeaddParams => [$option,$Data,$Data->{'db'}, $entityID, $entityTypeID],
      beforeupdateFunction => \&preNABApplicationAdd,
      beforeupdateParams => [$option,$Data,$Data->{'db'}, $entityID, $entityTypeID],
      afterupdateFunction => \&postNABApplicationAdd,
      afterupdateParams => [$option,$Data,$Data->{'db'}, $entityID, $entityTypeID],

      auditFunction=> \&auditLog,
      auditAddParams => [
        $Data,
        'Create',
        'Payment Application'
      ],
      auditEditParams => [
        $entityID,
        $Data,
        'Update',
        'Payment Application'
      ],

      LocaleMakeText => $Data->{'lang'},
		},
    sections => [
      ['orgdetails','Organisation Details'],
      ['applicant','Applicant'],
      ['officebearer1','Office Bearer 1'],
      ['officebearer2','Office Bearer 2'],
      ['txns','Transactional Information'],
      ['other','Other Details'],
      ['doco','Documentation'],
		],

		carryfields =>	{
			client => $client,
			a=> $action,
			paytype => 'nab',
		},
	);
	my $resultHTML='';
	my $ok = 0;
	($resultHTML, $ok)=handleHTMLForm(\%FieldDefinitions, undef, $option, '',$Data->{'db'});
	my $title='Payment Application';
	if(
		(
			$option eq 'add' 
			or $option eq 'edit' 
		)
		and !$ok
	)	{
		$resultHTML = qq[
	<div style="margin:5px;background-color:#F6FF68;padding:6px; border: 1px solid #FFE24F;">
	The person filling out this form (applicant) must be an approved applicant by the executive of the organisation.  If the applicant is also one of the nominated office bearers, the information needs to be repeated as such.

<br>
<p>
<b>As part of this application process, you will need to provide a scanned copy of your organisation's bank statement.  Please make sure you have this file available before beginning this process.</b></p>

</div>
			$resultHTML
		];
	}

	$resultHTML = qq[
		$header
		$resultHTML
	];
	return ($resultHTML,$title);
}

sub postNABApplicationAdd {
  my($id,$params,$action,$Data,$db)=@_;
  return undef if !$db;


	my $cl=setClient($Data->{'clientValues'}) || '';
	my %cv=getClient($cl);
	my $entityTypeID = $cv{'currentLevel'};
	my $entityID = getID(\%cv, $entityTypeID);

	checkSoftDescriptor($db, $params->{'d_strSoftDescriptor'}, $entityID, $entityTypeID);

	my $outputtext = '
		<div class="OKmsg">Your Application form has been submitted</div><br>
	';
	if($params->{'ba_num'} and $params->{"bsb"} and $params->{'ba_name'})	{
		my $bsb = $params->{'bsb'} || '';
		#update bank details
		my $st = qq[
			UPDATE tblPaymentApplication
			SET 
				strBSB = ?, 
				strAccountNum = ?
			WHERE 
				intApplicationID = ?
		];
		my $q = $db->prepare($st);
		$q->execute(
			$bsb || '',
			$params->{'ba_num'} || '',
			$id,
		);
		if($bsb)	{
			$bsb =~s/[\s\-]//g;
		#	$bsb = '08'.$bsb;
		}
		$st = qq[
			INSERT INTO tblBankAccount (
				intEntityTypeID,
				intEntityID,
				strBankCode,
				strAccountNo,
				strAccountName,
				dtBankAccount
			)
			VALUES (
				?,
				?,
				?,
				?,
				?,
				NOW()
			)
			ON DUPLICATE KEY UPDATE strBankCode = ?, strAccountNo = ?, strAccountName = ?, dtBankAccount=NOW()
		];
		$q = $db->prepare($st);
		$q->execute(
			$entityTypeID,
			$entityID,
			$bsb || '',
			$params->{'ba_num'} || '',
			$params->{'ba_name'} || '',
			$bsb || '',
			$params->{'ba_num'} || '',
			$params->{'ba_name'} || '',
		);

		$outputtext .= qq[
            <br><h2>What do I do next?</h2><br><br>
            <p>All requirements are complete and we will let you know as soon as your application is accepted.<br>
            Your application will take about 5 business days to be approved.<br> 
            If you would like your payments application fast tracked so that you can transact straight away, please contact paymentsadmin\@foxsportspulse.com with that request.</p>
		];
	}
	elsif($params->{'d_intHasBankAccount'} == 2)	{
		$outputtext .= qq[
<p><b>We plan to open a NAB bank account and take advantage of the regular transfers of our funds from our sub merchant facility.</b></p>

	<br><h2>What do I do next?</h2><br>
<p> Please visit your closest NAB branch with the following documents to open your account:
	<ul class = "list">
		<li>Letter of introduction <a href="">Print Here</a></li>
		<li>A copy of your organisation's Certificate of Incorporation (if applicable)</li>
		<li>A letter on Letterhead indicating who the signatories to the account will be (or minutes of a committee meeting confirming the signatories)</li>
		<li>Tax file number (optional)</li>
		<li>Full business contact details</li>
		<li>Valid email address</li>
	</ul>
<br>

<p>You closest NAB branch can be found by using the 'Branch Locator' on the NAB website, <a href = "http://www.nab.com.au" target = "nab">www.nab.com.au</a>.</p>
		];
	}
	elsif($params->{'d_intHasBankAccount'} == 3)	{
		$outputtext .= qq[
<p><b>We don't wish to open a NAB bank account</b></p>
	<br><h2>What do I do next?</h2><br>
<p>All requirements are complete and we will let you know as soon as your application is accepted.</p>
<p>You will receive any monies through your SportingPulse Sub Merchant on a Wednesday for the previous week (Tuesday morning till Monday midnight).</p>
		];
	}

	if($params->{'d_FeeType'})	{

		updateFeeType($Data, $entityTypeID, $entityID, $params->{'d_FeeType'} || 0);

	}

  #if($action eq 'add')  {

		my @files = (
			['Bank Statement', 'bankstatement', 2,],
		);
		my $retvalue = processUploadFile(
			$Data,
			\@files,
			$entityTypeID,
			$entityID,
			$Defs::UPLOADFILETYPE_APPLICATION,
		);

		return (0,$outputtext);
  #}
	return (0, $outputtext);
}

sub preNABApplicationAdd {
  my($params,$action,$Data,$db, $entityID, $entityTypeID)=@_;
  return undef if !$db;
  return if ! $entityID;
  return if ! $entityTypeID;

	my $error = '';
	if(!$params->{'bankstatement'})	{
		$error .= qq[<li>You must upload a copy of your bank statement</li>];
	}

	if((!$params->{'ba_num'} and !$params->{"bsb"} and !$params->{'ba_name'})
	or ($params->{'ba_num'} and $params->{"bsb"} and $params->{'ba_name'}))	{}
	else {
#	if(!$params->{'d_intHasBankAccount'})	{
		$error .= qq[<li>You must fill in your entire Bank Account Details</li>];
	}
	my $errormsg = '';
	if($error)	{
		$errormsg = qq[
			<div class = "warningmsg">
				<ul>$error</ul>
			</div>
			<p>Click your browser's back button to return to your application</p>
		];
		return(0,$errormsg);
	}


	if($action eq 'add')	{
		my $st = qq[
			DELETE FROM tblPaymentApplication
			WHERE intEntityTypeID=$entityTypeID
			AND intEntityID = $entityID
			AND intPaymentType = $Defs::PAYMENT_ONLINENAB
			LIMIT 1
		];
		#$db->do($st);
	}
    return (1,'');
}


1;

