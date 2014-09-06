#
# $Header: svn://svn/SWM/trunk/web/BankAccountSetup.pm 8841 2013-07-02 06:43:38Z fkhezri $
#

package BankAccountSetup;
require Exporter;
@ISA = qw(Exporter);
@EXPORT=qw(handleBankAccount paypal_details );
@EXPORT_OK=qw(handleBankAccount paypal_details );

use strict;
use Reg_common;
use HTMLForm;
use CGI qw(param escape unescape);
use TemplateEmail;
use Payments;
use PaymentApplication qw(handlePaymentApplication haveApplied isEmailValidated);
use AuditLog;
use UploadFiles;
use Email;

sub handleBankAccount	{
	my ($action, $Data, $EntityID, $EntityTypeID)=@_;

    my $resultHTML='';
	my $bankaccountName=
	my $title='Bank Account';
	my $paypal = 0;
	my $nab = 0;
	my $paytype ||= param('paytype') || '';

	my $paymentsettings = getPaymentSettings($Data, $paytype);

	$paypal = 1 if(!$Data->{'SystemConfig'}{'DisallowPaypalSignup'} and $paymentsettings and $paymentsettings->{'paymentType'} == $Defs::PAYMENT_ONLINEPAYPAL);
	$nab = 1 if($paymentsettings and $paymentsettings->{'paymentType'} == $Defs::PAYMENT_ONLINENAB);

	$nab = 1 if ($Data->{'SystemConfig'}{'AllowNABSignup'}  and $EntityTypeID == $Defs::LEVEL_ASSOC);
	$nab = 1 if ($Data->{'SystemConfig'}{'AllowNABSignupClub'} and $EntityTypeID == $Defs::LEVEL_CLUB);

	if($action eq 'BA_RESEND')	{
	   my $field=loadBankAccountDetails($Data->{'db'}, $EntityID, $EntityTypeID) || ();
	   sendValidationEmail($Data, $field->{'strMPEmail'});
		($resultHTML,$title)=paypal_details($action, $Data, $EntityID, $EntityTypeID);
    $resultHTML = qq[<div class="OKmsg">Validation email has been re-sent to $field->{'strMPEmail'}</div><br>] . $resultHTML;
    }
	#Check if T&Cs are signed before allowing to continue
	if($paypal and !$nab){#  and !haveApplied($Data, $EntityTypeID, $EntityID))	{
		if ($action eq 'BA_FORMRESEND')    {
			($resultHTML,$title)=paypal_details($action, $Data, $EntityID, $EntityTypeID);
			return ($resultHTML,$title);
		}
		#my $type = 'paypal';
		#($resultHTML,$title) = handlePaymentApplication('PY_A', $Data, $EntityID, $EntityTypeID, $type) ;
		#return ($resultHTML,$title);
	}
	if($action eq 'BA_' )	{
		($resultHTML,$title) = paymentMenu(
			$Data, 
			$EntityID, 
			$EntityTypeID,
			$paymentsettings,
			$paypal, 
			$nab,
		) ;
		return ($resultHTML,$title);
	}


	if ($action =~/^BA_DT/) {
		if($paypal and $paytype eq 'paypal') 	{
			if($action eq 'BA_DTU')	{
				($resultHTML,$title)=paypal_detailsupdate($action, $Data, $EntityID, $EntityTypeID);
				$action = 'BA_DTE' if !$resultHTML;
			}
			if($action eq 'BA_DTE')	{
				($resultHTML,$title)=paypal_details($action, $Data, $EntityID, $EntityTypeID);
			}
		}
		else	{
			#BankAccount Details
			if($nab and param('d_strBankCode') and param('d_strAccountNo'))	{
				# If NAB and BSB/ACC then lets go and update tblMoneyLog
				nab_detailsupdate($action, $Data, $EntityID, $EntityTypeID);
			}
			($resultHTML,$title)=bankaccount_details($action, $Data, $EntityID, $EntityTypeID);
		}
	}

	return ($resultHTML,$title);
}

sub nab_detailsupdate	{
	# If NAB and BSB/ACC then lets go and update tblMoneyLog

	my ($action, $Data, $EntityID, $EntityTypeID) = @_;

	my $field=loadBankAccountDetails($Data->{'db'}, $EntityID, $EntityTypeID) || ();

	my $oldbsb= $field->{'strBankCode'} || '';
	my $oldaccno = $field->{'strAccountNo'} || '';
	my $newbsb= param('d_strBankCode') || '';
	my $newaccno= param('d_strAccountNo') || '';
	my $newaccname= param('d_strAccountName') || '';

	if($oldbsb ne $newbsb or $oldaccno ne $newaccno)	{
			my $st = qq[
				UPDATE 
					tblMoneyLog as ML
					INNER JOIN tblTransLog as TL ON (
						TL.intLogID=ML.intTransLogID
					)
				SET 
				ML.strBankCode= ?,
				ML.strAccountNo = ?,
				ML.strAccountName = ?
			WHERE 
				ML.intEntityType = ?
				AND ML.intEntityID = ?
				AND ML.intExportBankFileID = 0
				AND ML.intLogType=6
        AND ML.intRealmID=$Data->{'Realm'}
				AND TL.intPaymentType = $Defs::PAYMENT_ONLINENAB
		];
		my $q = $Data->{'db'}->prepare($st);
		$q->execute(
			$newbsb,
			$newaccno,
			$newaccname,
			$EntityTypeID,	
			$EntityID
		);
		$q->finish();

	}
	return;
}

sub bankaccount_details	{
	my ($action, $Data, $EntityID, $EntityTypeID)=@_;

	my $field=loadBankAccountDetails($Data->{'db'}, $EntityID, $EntityTypeID) || ();
	my $option='display';
	if($action eq 'BA_DTE' and $Data->{'clientValues'}{'authLevel'} >= $EntityTypeID)	{
		if($field->{'intEntityID'} and $field->{'intEntityTypeID'})	{
			$option='edit';
		}
		else	{
			$option='add';
		}
	}
	
	my $client=setClient($Data->{'clientValues'}) || '';
	my %FieldDefinitions=(
		fields=>	{
			strBankCode => {
				label => 'Branch Code (BSB)',
				value => $field->{'strBankCode'},
				type  => 'text',
				size  => '10',
				maxsize => '50',
			},
			strAccountNo=> {
				label => 'Account Number',
				value => $field->{'strAccountNo'},
				type  => 'text',
				size  => '30',
				maxsize => '50',
			},
			strAccountName => {
				label => 'Account Name',
				value => $field->{'strAccountName'},
				type  => 'text',
				size  => '50',
				maxsize => '50',
			},
        bankstatement => {
                label => 'Bank Statement' ,
                value => qq[<p>To validate your bank details, please provide a scanned copy of your latest bank statement.</p><input type="file" name="bankstatement"> <img src="images/compulsory.gif" alt="Compulsory Field" title="Compulsory Field">],
                type  => 'textvalue',
                SkipProcessing => 1,
            },
		},
		order => [qw(strBankCode strAccountNo strAccountName bankstatement)],
		options => {
			labelsuffix => ':',
			hideblank => 1,
			target => $Data->{'target'},
			formname => 'ba_form',
            FormEncoding =>'multipart/form-data',
      submitlabel => "Update",
      introtext => $Data->{'lang'}->txt('HTMLFORM_INTROTEXT'),
			NoHTML => 1, 
			updateSQL => qq[
        UPDATE tblBankAccount
          SET --VAL--
        WHERE intEntityID = $EntityID
        	AND intEntityTypeID = $EntityTypeID
			],
			addSQL => qq[
        INSERT INTO tblBankAccount
          (intEntityTypeID, intEntityID, dtBankAccount,intStopNABExport, --FIELDS--)
					VALUES ($EntityTypeID, $EntityID, NOW(),1,  --VAL-- )
			],
        afteraddParams => [$option,$Data,$Data->{'db'}, $EntityID, $EntityTypeID],
        afteraddFunction => \&postApplicationAdd,
        afterupdateFunction => \&postApplicationAdd,
        afterupdateParams => [$option,$Data,$Data->{'db'}, $EntityID, $EntityTypeID],
      auditFunction=> \&auditLog,
      auditAddParams => [
        $Data,
        'Setup',
        'Bank Account'
      ],
      auditEditParams => [
        $EntityID,
        $Data,
        'Update',
        'Bank Account'
      ],

      LocaleMakeText => $Data->{'lang'},
		},
		carryfields =>	{
			client => $client,
			a=> $action,
			paytype => '',
		},
	);
	my $resultHTML='';
	($resultHTML, undef )=handleHTMLForm(\%FieldDefinitions, undef, $option, '',$Data->{'db'});
	my $title='Bank Account';
  if($option eq 'display')  {
    my $chgoptions='';
    $chgoptions.=qq[<div style="float:right;"><a href="$Data->{'target'}?client=$client&amp;a=BA_DTE"><img src="images/edit_icon.gif" border="0" alt="Edit"></a></div> ] if($Data->{'clientValues'}{'authLevel'} >= $EntityTypeID and allowedAction($Data, 'ba_e'));
    $resultHTML=$resultHTML;
		$title=$chgoptions.$title;
  }

	return ($resultHTML,$title);
}

sub postApplicationAdd {
    my ($id,$params,$action,$Data,$db)=@_;
    my $cl=setClient($Data->{'clientValues'}) || '';
    my %cv=getClient($cl);
    my $entityTypeID = $cv{'currentLevel'};
    my $entityID = getID(\%cv, $entityTypeID);
    my @files = (
            ['Bank Statement', 'bankstatement', 2,],
        );
        my $retvalue = processUploadFile(
            $Data,
            \@files,
            $entityTypeID,
            $entityID,
            $Defs::UPLOADFILETYPE_STATEMENT,
        );
    my $level_name = $Data->{'LevelNames'}{$entityTypeID};
    my $body_html = qq[New bank account was added:<br >
                        Level : $level_name($entityTypeID)<br >
                        ID : $entityID <br > <br >
                        <a href="http://reg.sportingpulse.com/admin/pms_admin.cgi?action=BANK">Click here</a> to activate the bank account.];
     sendEmail($Defs::notify_payment_email,$Defs::donotreply_email, 'New Bank Account','', $body_html, '','New Bank Account');
    return "Done";
}
sub loadBankAccountDetails {
  my($db, $EntityID, $EntityTypeID) = @_;
                                                                                                        
  my $statement=qq[
		SELECT
			strBankCode,
			strAccountNo,
			strAccountName,
			intEntityID,
			intEntityTypeID,
			strMPEmail
		FROM tblBankAccount
		WHERE intEntityTypeID = ?
			AND intEntityID = ?
  ];
  my $query = $db->prepare($statement);
  $query->execute($EntityTypeID, $EntityID);
	my $field=$query->fetchrow_hashref();
  $query->finish;
                                                                                                        
  foreach my $key (keys %{$field})  { if(!defined $field->{$key}) {$field->{$key}='';} }
  return $field;
}

sub paypal_details	{
	my ($action, $Data, $EntityID, $EntityTypeID)=@_;

	my $field=loadBankAccountDetails($Data->{'db'}, $EntityID, $EntityTypeID) || ();
  my $client=setClient($Data->{'clientValues'}) || '';

	$field->{'strMPEmail'} ||= '';

	my $validationmessage = '';

	my $validated = 0;
	if($field->{'strMPEmail'})	{
		$validated = isEmailValidated($Data->{'db'}, $field->{'strMPEmail'}) || 0;
		if($validated)	{
			$validationmessage = qq[
                <br><br>
				<div class="OKmsg">This email address has been validated</div>
			];
		}
		else	{
			$validationmessage = qq[
                <br><br>
				<div style="border:1px solid #888; padding:10px;display:table;">
					<div class="warningmsg">This email address has not been validated</div><br>
					<p>To use this email address for payment it must be validated.  To validate this address you must click the link in the email you were sent.</p><br>
                    <p>To receive the validation email again please click <b>'Resend validation email'</b> button below</p>
				</div>
			];
		}
	}

	my $emailAddress= qq[ <b>$field->{'strMPEmail'}</b><br><br><i>To change the email address for this account, please contact SportingPulse on 1300 139 970 or support\@sportingpulse.com</i>];
    my $formStart   = '';
    my $formEnd     = '';
    if (! $field->{'strMPEmail'}) {
	    $emailAddress= qq[<input type="text" name="d_strMPEmail" value="$field->{'strMPEmail'}" id="l_strMPEmail"  size="30"   maxlength="127">];
	    $formStart= qq[
            <form action="$Data->{'target'}" method="POST">
			<p class="introtext">Enter the email address for your PayPal account in the box below.  When you have finished click the 'Update' button.</p>
        ];
        $formEnd = qq[
            <input type="submit" name="subbut" value="Update" class="HF_submit" id="HFsubbut"> </div>
			<input type="hidden" name="client" value="$client">
			<input type="hidden" name="a" value="BA_DTU">
			<input type="hidden" name="paytype" value="paypal">
		</form>
        ];
    }
    elsif (! $validated)    {
        $formStart= qq[
            <form action="$Data->{'target'}" method="POST">
        ];
        $formEnd = qq[
            <input type="submit" name="subbut" value="Resend validation email" class="HF_submit" id="HFsubbut"> </div>
			<input type="hidden" name="client" value="$client">
			<input type="hidden" name="a" value="BA_RESEND">
		</form>
        ];
    }
	my $resultHTML = qq[
            $formStart
			<br>
			<div>
				<label for="l_strMPEmail">PayPal Email Address</label>:$emailAddress
			</div>
			$validationmessage
			<br>

			$formEnd 
	];

	my $history = '';

	{
		my $st = qq[
			SELECT
				strEmail,
				DATE_FORMAT(tTimeStamp, "%d/%m/%Y %H:%i:%s") AS timestamp,
				strUsername
			FROM tblPayPalEmailLog
			WHERE
				intEntityTypeID = ?
				AND intEntityID = ?
			ORDER BY tTimestamp DESC
		];
		my $q = $Data->{'db'}->prepare($st);
		$q->execute(
			$EntityTypeID,	
			$EntityID,	
		);
		while(my $dref = $q->fetchrow_hashref())	{
			$history .= qq[
				<tr>
					<td>$dref->{'timestamp'}</td>
					<td>$dref->{'strEmail'}</td>
					<td>$dref->{'strUsername'}</td>
				</tr>
			];


		}
		$history = qq[
			<div class="sectionheader">Email Change History</div>
			<table class="listTable">
				<tr>
					<th>Date/Time</th>
					<th>Previous Emails</th>
					<th>Username</th>
				</tr>
				$history
			</table>
		] if $history;
		$resultHTML .= $history;


	}
	my $title = 'PayPal Account Configuration';
	return ($resultHTML, $title);	
}

sub paypal_detailsupdate	{
	my ($action, $Data, $EntityID, $EntityTypeID)=@_;

	my $field=loadBankAccountDetails($Data->{'db'}, $EntityID, $EntityTypeID) || ();
  my $client=setClient($Data->{'clientValues'}) || '';

	my $oldemail = $field->{'strMPEmail'} || '';
	my $newemail = param('d_strMPEmail') || '';

	my $resultHTML = '';

	if($oldemail ne $newemail)	{
        return if $oldemail;
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
		my $q = $Data->{'db'}->prepare($st);
		$q->execute(
			$EntityTypeID,	
			$EntityID,
			$newemail,
			$newemail
		);
		$q->finish();
		$st = qq[
			INSERT INTO tblPayPalEmailLog (
				intEntityTypeID,
				intEntityID,
				strEmail,
				intLoginEntityTypeID,
				intLoginEntityID,
				strUsername
			)
			VALUES (
				?,
				?,
				?,
				?,
				?,
				?	
			)
		];
		$q = $Data->{'db'}->prepare($st);
		my $userID = getID($Data->{'clientValues'}, $Data->{'clientValues'}{'authLevel'});
		$q->execute(
			$EntityTypeID,	
			$EntityID,
			$newemail,
			$Data->{'clientValues'}{'authLevel'},
			$userID,
			$Data->{'UserName'},
		);
		$q->finish();
		my $validated = isEmailValidated($Data->{'db'}, $newemail) || 0;
		$st = qq[
			UPDATE tblMoneyLog as ML
					INNER JOIN tblTransLog as TL ON (
						TL.intLogID=ML.intTransLogID
					)
			SET 
				ML.strMPEmail = ?
			WHERE 
				ML.intEntityType = ?
				AND ML.intEntityID = ?
				AND ML.intExportBankFileID = 0
				AND ML.intLogType=6
        AND ML.intRealmID=$Data->{'Realm'}
				AND TL.intPaymentType = $Defs::PAYMENT_ONLINEPAYPAL
		];
		$q = $Data->{'db'}->prepare($st);
		$q->execute(
			$newemail,
			$EntityTypeID,	
			$EntityID
		);
		$q->finish();

		if($validated)	{
			$resultHTML=qq[
				<div class="OKmsg">Your paypal email address has been updated</div>
			];
		}
		else	{
			$resultHTML=qq[
				<div class="OKmsg">Your PayPal email address has been updated</div><br>
				<div class="warningmsg">You MUST validate your email address before it can be used for payments.</div><br>
				<p>You have been sent an email to $newemail.</p><p>  You MUST click on the link in this email to validate this new email address.</p>
			];
			sendValidationEmail($Data, $newemail);
		}
	}
	my $title = 'PayPal Account Configuration';
	return($resultHTML, $title);
}

sub sendValidationEmail	{
	my($Data, $email) = @_;

	#See if already in table
	my $st = qq[
		SELECT 
			strKey
			dtVerified
		FROM tblVerifiedEmail
		WHERE strEmail = ?
	];
	my $qv = $Data->{'db'}->prepare($st);
	$qv->execute($email);
	my($key, $date) = $qv->fetchrow_array();
	$qv->finish();
	if($date and $date gt '1900-01-01')	{
		#already verified
		return '';
	}
	if(!$key)	{
		#Not in database - insert into table and generate key
		{
			srand(time() ^ ($$ + ($$ << 15)) );
			my $salt=(rand()*100000);
			my $salt2=(rand()*100000);
			$key=crypt($salt2,$salt);
			#Clean out some rubbish in the key
			$key=~s /['\/\.\%\&]//g;
			$key=substr($key,0,20);
		}
		my $st_i = qq[
			INSERT INTO tblVerifiedEmail
				(strEmail, strKey)
				VALUES(?,?)
		];
		my $qi = $Data->{'db'}->prepare($st_i);
		$qi->execute($email, $key);
		$qi->finish();
	}

	
	my $link = $Defs::base_url."/validateemail.cgi?e=".escape($email)."&amp;k=$key";
	my %tdata = (
		Key => $key,
		Email => $email,
		LinkAddress => $link,
	);
	return sendTemplateEmail(
		$Data,
		'confirmemail.templ',
		\%tdata,
		$email,
		'Confirm your email address',	
		''
	);
}

sub paymentMenu {
	my (
		$Data, 
		$EntityID, 
		$EntityTypeID,
		$paymentsettings,
		$paypal,
		$nab,
	)=@_;
	my $resultHTML = '';
    my $info_text = qq[The Application below allows your organization to take card payments online with funds transfered directly to your bank account. <a href ='http://corp.sportingpulse.com/index.php?id=171' target ='_blank'>Click here</a> for more information.];
    my $client=setClient($Data->{'clientValues'}) || '';
	my $unesc_client = unescape($client);
	if(
		$nab
		and 	(
			$EntityTypeID == $Defs::LEVEL_ASSOC
			or $EntityTypeID == $Defs::LEVEL_CLUB
		)
	)	{
		my ($appID, $name, $date) = haveApplied($Data, $EntityTypeID, $EntityID, $Defs::PAYMENT_ONLINENAB);
		my $button_name = 'Payments Application';
		if($appID)	{
		    $resultHTML .= qq[
			    <div class="sectionheader">Apply to receive funds</div>
		    ];
			$resultHTML .= qq[
					<h3>Payments Application for $name submitted on $date</h3><br><br>
			];
			$button_name = 'View Payments Application';
		}
        else{
            $resultHTML .= $info_text;
		    $resultHTML .= qq[
			    <div class="sectionheader">Apply to receive funds</div>
		    ];
        }
		$resultHTML .= qq[
			<form action="$Data->{'target'}" method = "POST">
				<input type="hidden" name = "client" value ="$unesc_client">
				<input type="hidden" name = "a" value ="PY_A">
				<input type="hidden" name = "paytype" value ="nab">
				<input type="submit" value = "$button_name" class = "button generic-button">
			</form>
		];
	}
    
	if($paypal)	{
		$resultHTML .= $info_text; 
		$resultHTML .= qq[
			<form action="$Data->{'target'}" method = "POST">
				<input type="hidden" name = "client" value ="$unesc_client">
				<input type="hidden" name = "a" value ="PY_A">
				<input type="hidden" name = "paytype" value ="paypal">
				<input type="submit" value = "PayPal Payment Application" class = "button generic-button">
			</form>
		];
	}
	if($nab)	{
		my $details = loadBankAccountDetails($Data->{'db'}, $EntityID, $EntityTypeID);
		my $details_str = '';
		if($details and $details->{'strAccountNo'})	{
			$details_str = qq[
				<table cellpadding="2" cellspacing="0" border="0" >
					<tr>
						<td class="label">Branch Code (BSB)</td>
						<td class="value">$details->{'strBankCode'}</td>
					</tr>
					<tr>
						<td class="label">Account Number</td>
						<td class="value">$details->{'strAccountNo'}</td>
					</tr>
					<tr>
						<td class="label">Account Name</td>
						<td class="value">$details->{'strAccountName'}</td>
					</tr>
				</table><br><br>
			];
		}
		$resultHTML .= qq[
			<div style = "clear:both;"></div>
			<div class="sectionheader">Your Bank Account Details</div>
				$details_str
		];
		if(!$details_str)	{
			$resultHTML .=qq[
					<form action="$Data->{'target'}" method = "POST">
						<input type="hidden" name = "client" value ="$unesc_client">
						<input type="hidden" name = "a" value ="BA_DTE">
						<input type="submit" value = "Bank Account Details" class = "button generic-button">
					</form>
			];
		}
	}
	if($paypal)	{
		$resultHTML .= qq[
			<div class="sectionheader">Configure your PayPal Details</div>
					<form action="$Data->{'target'}" method = "POST">
						<input type="hidden" name = "client" value ="$unesc_client">
						<input type="hidden" name = "a" value ="BA_DTE">
						<input type="submit" value = "Setup PayPal Address" class = "button generic-button">
							<input type="hidden" name = "paytype" value ="paypal">
					</form>
			];
	}
	

	return ($resultHTML,'Payment Configuration');
}

1;
