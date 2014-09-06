#
# $Header: svn://svn/SWM/trunk/web/admin/PMSAdmin.pm 10488 2014-01-20 04:28:47Z fkhezri $
#

package PMSAdmin;

require Exporter;
@ISA =  qw(Exporter);
@EXPORT = qw(handle_paymentapplication);
@EXPORT_OK = qw(handle_paymentapplication);

use lib "..","../..","../sp_publisher";
use DBI;
use CGI qw(param unescape escape);
use strict;

use Defs;
use Utils;
use AdminCommon;
use DeQuote;
use FormHelpers;
use NodeStructure;
use Products;
use ClubAdmin;
use TeamAdmin;
use UploadFiles;
use Reg_common qw(setClient);
use HTMLForm;

sub handle_paymentapplication	{
  my($db, $action, $target)=@_;
  my $appID=param('intApplicationID') || 0;
  my $EntityID=param('EntityID') || 0;
  my $EntityTypeID=param('EntityTypeID') || 0;
  my $body='';
  my $menu='';
  my $exportOK = param('export');
  if($action eq 'APP_update') {
		($body,$menu)=update_application($db, $action, $appID, $target); 
  }
  if($action eq 'APP_list') {
		($body,$menu)=list_applications($db, $action, $appID, $target); 
  }
  if($action eq 'APP_view') {
    ($body,$menu)=application_details($db, $action, $appID, $target, 0);
  }
  if($action eq 'APP_edit') {
    ($body,$menu)=application_details($db, $action, $appID, $target, 1);
  }
  if($action eq 'APP_detedit') {
    ($body,$menu)=detailed_edit($db, $action, $appID, $target);
  }
  if($action eq 'APP_BA_detedit') {
      ($body,$menu)=ba_detailed_edit($db, $action, $appID, $target);
  }
  if($action eq 'Bank_Detail_list') {
		($body,$menu)=bankDetails_list($db, $action, $appID, $target); 
  }
  if($action eq 'Bank_Detail_view') {
		($body,$menu)=bankDetails_view($db, $action, $EntityID,$EntityTypeID, $target,0); 
  }
  if($action eq 'Bank_Detail_NabExport') {
		($body,$menu)=update_NAB_export($db, $action, $EntityID,$EntityTypeID, $target,$exportOK); 
  }
  return ($body,$menu);

}

# *********************SUBROUTINES BELOW****************************

sub ba_detailed_edit {
    my ($db, $action, $app_id, $target, $edit) = @_;
    
    my $field = get_bank_account_details($db, $app_id);
	my $option = 'edit';
    
    my $entity_id = $field->{intEntityID};
    my $entity_type_id = $field->{intEntityTypeID};
    
		print STDERR "$field->{'strAccountNo'}\n";
	my %FieldDefinitions=
        (
         fields=>	{
                     strBankCode => {
                                    label => 'Bank Code',
                                    value => $field->{strBankCode},
                                    type  => 'text',
                                    validate => 'NUMBER',                                     
                                    size  => '20',
                                    maxsize => '6',
                                    sectionname => 'badetails',
                                },
                     strAccountNo => {
                                      label => 'Bank Account Number',
                                      value => $field->{strAccountNo},
                                      type  => 'text',
                                      #validate => 'NUMBER',                                     
                                      size  => '30',
                                      maxsize => '9',
                                      sectionname => 'badetails',
                                  },
                     strAccountName => {
                                        label => 'Bank Account Name',
                                        value => $field->{strAccountName},
                                        type  => 'text',
                                        size  => '50',
                                        maxsize => '250',
                                        sectionname => 'badetails',
                                  },
                 },
         order => [
                   qw(strBankCode strAccountNo strAccountName)
                  ],
         options =>
         {
		  labelsuffix => ':',
		  hideblank => 1,
		  target => $target,
		  formname => 'n_form',
          submitlabel => "Save",
          introtext => '',
		  NoHTML => 1, 
		  FormEncoding=>'multipart/form-data',
          updateSQL => qq[
                          UPDATE tblBankAccount
                          SET --VAL--
                          WHERE intEntityTypeID = $entity_type_id
                          AND intEntityID = $entity_id
				          LIMIT 1
			],
          
          beforeupdateFunction => \&before_update_ba_details,
          beforeupdateParams => [$db],
          afterupdateFunction => \&after_update_ba_details,
          afterupdateParams => [$db, $app_id],
          
          LocaleMakeText => undef,
		  },
          sections => [
                 ['badetails','Bank Account Details'],
             ],
          carryfields =>	{
                             action => $action,
                             intApplicationID => $app_id,
                             intEntityID => $entity_id,
                             intEntityTypeID => $entity_type_id
                             },
	);
	my $resultHTML='';

	my $ok = 0;

	($resultHTML, $ok)=handleHTMLForm(\%FieldDefinitions, undef, $option, '',$db);
	my $title='Bank Account Details';

	$resultHTML .= qq[
		<-- <a href = "$target?action=APP_view&intApplicationID=$app_id"> Return to Application</a>
	];
	return ($resultHTML,$title);
}

sub get_bank_account_details {
    my ($db, $app_id)  = @_;
    
    my $st = qq[
                SELECT
                     tblBankAccount.*
                FROM tblBankAccount
                INNER JOIN tblPaymentApplication ON 
                (
                 tblPaymentApplication.intEntityID = tblBankAccount.intEntityID 
                 AND tblPaymentApplication.intEntityTypeID = tblBankAccount.intEntityTypeID
                )
                WHERE
                    tblPaymentApplication.intApplicationID = ?
                LIMIT 1
            ];
    
    my $query = $db->prepare($st);
    $query->execute($app_id);
    my $data = $query->fetchrow_hashref();

    return $data;

}

sub before_update_ba_details {
    my ($params, $db) = @_;
    
    my $st = qq[
                INSERT IGNORE INTO tblBankAccount (intEntityID, intEntityTypeID)
                VALUES (?, ?) 
            ];

    my $q = $db->prepare($st);
    
    $q->execute(
                $params->{'intEntityTypeID'},
                $params->{'intEntityID'}
            );
    
    $q->finish();
    
    return 1;
    
}


sub after_update_ba_details {
    my ($id, $params, $db, $app_id) = @_;
    
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
   				    AND TL.intPaymentType = $Defs::PAYMENT_ONLINENAB
		];

    my $q = $db->prepare($st);
    $q->execute(
                $params->{'d_strBankCode'},
                $params->{'d_strAccountNo'},
                $params->{'d_strAccountName'},
                $params->{'intEntityTypeID'},
                $params->{'intEntityID'}
            );
    
    $q->finish();
    
    return 1;
    
}


sub application_details	{
	my ($db, $action, $appID, $target, $edit) = @_;

	my $dref;
	my %fields=();
	my $view=1;
	my $statement = qq[
		SELECT DISTINCT
			A.intAssocID as AssocID, 
			A.strName as AssocName, 
			C.intClubID as ClubID,
			C.strName as ClubName, 
			N.strName as NodeName, 
			N.intNodeID as NodeID, 
			strRealmName,
			PA.intPaymentType,
			PA.*,
			BA.*,
			PC.intGatewayType,
			PA.strBSB as PAstrBSB,
			PA.strAccountNum as PAstrAccountNum
		FROM 
			tblPaymentApplication as PA
			LEFT JOIN tblBankAccount as BA ON (
				PA.intEntityTypeID=BA.intEntityTypeID
				AND PA.intEntityID=BA.intEntityID
			)
			LEFT JOIN tblAssoc_Clubs as AC ON (
				(
					AC.intClubID=PA.intEntityID 
					AND PA.intEntityTypeID=3
				)
				OR 
				(
					AC.intAssocID = PA.intEntityID
					AND PA.intEntityTypeID=5
				)
			)
			LEFT JOIN tblAssoc as A ON (
				(
					A.intAssocID=PA.intEntityID
					AND PA.intEntityTypeID=5
				)
				OR
				(
					A.intAssocID=AC.intAssocID
				)
			)
			LEFT JOIN tblPaymentConfig as PC ON (
				PC.intPaymentConfigID=A.intPaymentConfigID
			)
			LEFT JOIN tblClub as C ON (
				C.intClubID=PA.intEntityID
				AND AC.intAssocID = A.intAssocID
				AND PA.intEntityTypeID=3
			)
			LEFT JOIN tblNode as N ON (
				N.intNodeID=PA.intEntityID 
				AND PA.intEntityTypeID>5
			)
			LEFT JOIN tblRealms ON (PA.intRealmID=tblRealms.intRealmID)
			WHERE
				PA.intApplicationID=$appID
		ORDER BY 
			A.strName
			LIMIT 1
	  ];

	  my $query = $db->prepare($statement) or query_error($statement);
	  $query->execute() or query_error($statement);

		$dref= $query->fetchrow_hashref();
		$query->finish();
		foreach my $key (keys %{$dref})	{ 
			if(!defined $dref->{$key})	{
				if ($key =~ /intAllow|intAssocFee/)	{
					$dref->{$key}=0;
				}
				else	{
					$dref->{$key}='';
				}
			} 
		}
		$fields{'intRealmID'}=$dref->{'strRealmName'} || '';
		$dref->{'strPaymentConfig'} = $dref->{'PaymentConfigType'} . "- " . $Defs::LevelNames{$dref->{intLevelID}} . " level setup";

	my $add=0;
	$fields{'intApplicationID'}=$dref->{intApplicationID} || 0;
	$fields{'AssocName'}= qq[<a href="index.cgi?action=ASSOC_edit&amp;intAssocID=$dref->{AssocID}">$dref->{'AssocName'}</a>];
	$fields{'ClubName'}=$dref->{ClubName} || '';
	$fields{'NodeName'}=$dref->{NodeName} || '';
	$fields{'PaymentConfig'} = '';
	$fields{'PaymentConfig'} = qq[ <b>OLD CC GATEWAY -- SEE BAFF</b>] if ($dref->{'intGatewayType'} == $Defs::GATEWAY_CC);
	$fields{'PaymentConfig'} = qq[ <b>PAYPAL GATEWAY</b>] if ($dref->{'intGatewayType'} == $Defs::GATEWAY_PAYPAL);
	$fields{'PaymentConfig'} = qq[ <b>NAB GATEWAY</b>] if ($dref->{'intGatewayType'} == $Defs::GATEWAY_NAB);
	$fields{'strMerchantAccUsername'}=genTextBox('strMerchantAccUsername',$dref->{strMerchantAccUsername},10,$add,$edit);
	$fields{'strApplicationNotes'}=genTextArea('strApplicationNotes',$dref->{strApplicationNotes},$add,$edit);
	$fields{'intNABPaymentOK'}=genTextBox('intNABPaymentOK',$dref->{intNABPaymentOK},3,$add,$edit);
	$fields{'intStopNABExport'}=genTextBox('intStopNABExport',$dref->{intStopNABExport},3,$add,$edit);
	$fields{'strARBN'}=$dref->{'strARBN'};
	$fields{'strOrgType'}=$dref->{'strOrgType'};
	$fields{'intLocked'}=genTextBox('intLocked',$dref->{intLocked},3,$add,$edit);
	$fields{'strOrgTypeOther'}=$dref->{'strOrgTypeOther'};

	my $appStatus =qq[<select name="intApplicationStatus">];
	foreach my $k (keys %Defs::applicationStatus) { 
		my $selected = '';
		$selected = 'SELECTED' if ($k == $dref->{'intApplicationStatus'});
		$appStatus.= qq[<option $selected value="$k">$Defs::applicationStatus{$k}</option>];
	}
	$appStatus .=qq[</select>];
	$fields{'intApplicationStatus'}=$edit ? $appStatus : $Defs::applicationStatus{$dref->{'intApplicationStatus'}};

	my %hasbankaccount_options = (
		1 => 'Yes',
		2 => 'No, but plan to',
		3 => 'No',
	);
	#$fields{'strBankCode'}=genTextBox('strBankCode',$dref->{strBankCode},40,$add,$edit);
	#$fields{'strAccountNo'}=genTextBox('strAccountNo',$dref->{strAccountNo},40,$add,$edit);
	#$fields{'strAccountName'}=genTextBox('strAccountName',$dref->{strAccountName},40,$add,$edit);
	#$fields{'strMPEmail'}=genTextBox('strMPEmail',$dref->{strMPEmail},40,$add,$edit);
	$fields{'strOrgName'}=$dref->{strOrgName};
    
    my $short_bus_name_event_handler = qq[onkeyup="if (this.value.length > 40) { alert('Please provide a name that is 40 characters or less'); this.value = this.value.substr(0,40);}"];
    $fields{'strShortLegalName'} = genTextBox('strShortLegalName', $dref->{strShortLegalName}, 40, $add, $edit, $short_bus_name_event_handler);

    my $short_bank_name_event_handler = qq[onkeyup="if (this.value.length > 18) { alert('Please provide a name that is 18 characters or less'); this.value = this.value.substr(0,40);}"];
    $fields{'strShortBankName'} = genTextBox('strShortBankName', $dref->{strShortBankName}, 18, $add, $edit, $short_bank_name_event_handler);
    
	$fields{'strACN'}=$dref->{strACN};
	$fields{'strABN'}=$dref->{strABN};
	$fields{'strContact'}=$dref->{strContact};
	$fields{'strContactPhone'}=$dref->{strContactPhone};
	$fields{'strMailingAddress'}=$dref->{strMailingAddress};
	$fields{'strSuburb'}=$dref->{strSuburb};
	$fields{'strPostalCode'}=$dref->{strPostalCode};
	$fields{'strOrgPhone'}=$dref->{strOrgPhone};
	$fields{'strOrgFax'}=$dref->{strOrgFax};
	$fields{'strOrgEmail'}=$dref->{strOrgEmail};
	$fields{'strPaymentEmail'}=$dref->{strPaymentEmail};
	$fields{'strAgreedBy'}=$dref->{strAgreedBy};
	$fields{'dtCreated'}=$dref->{dtCreated};
	$fields{'strState'}=$dref->{strState};
	$fields{'strSoftDescriptor'}=genTextBox('strSoftDescriptor',$dref->{strSoftDescriptor},40,$add,$edit);
	$fields{'strParentCode'}=genTextBox('strParentCode',$dref->{strParentCode},40,$add,$edit);
	$fields{'strApplicantTitle'}=$dref->{strApplicantTitle};
	$fields{'strApplicantFirstName'}=$dref->{strApplicantFirstName};
	$fields{'strApplicantInitial'}=$dref->{strApplicantInitial};
	$fields{'strApplicantFamilyName'}=$dref->{strApplicantFamilyName};
	$fields{'strApplicantPosition'}=$dref->{strApplicantPosition};
	$fields{'strApplicantEmail'}=$dref->{strApplicantEmail};
	$fields{'strApplicantPhone'}=$dref->{strApplicantPhone};
	$fields{'strShortBusName'}=$dref->{strShortBusName};
	$fields{'strStreetAddress1'}=$dref->{strStreetAddress1};
	$fields{'strStreetAddress2'}=$dref->{strStreetAddress2};
	$fields{'strURL'}=$dref->{strURL};
	$fields{'intIncorpStatus'}=$dref->{intIncorpStatus};
	$fields{'intGST'}=$dref->{intGST};
	$fields{'intNumberTxns'}=$dref->{intNumberTxns};
	$fields{'intAvgCost'}=$dref->{intAvgCost};
	$fields{'intTotalTurnover'}=$dref->{intTotalTurnover};
	$fields{'intEstimateGatewayRev'}=$dref->{intEstimateGatewayRev};
	$fields{'strOB1_FirstName'}=$dref->{strOB1_FirstName};
	$fields{'strOB1_FamilyName'}=$dref->{strOB1_FamilyName};
	$fields{'strOB1_Position'}=$dref->{strOB1_Position};
	$fields{'strOB1_Phone'}=$dref->{strOB1_Phone};
	$fields{'strOB1_Email'}=$dref->{strOB1_Email};
	$fields{'strOB2_FirstName'}=$dref->{strOB2_FirstName};
	$fields{'strOB2_FamilyName'}=$dref->{strOB2_FamilyName};
	$fields{'strOB2_Position'}=$dref->{strOB2_Position};
	$fields{'strOB2_Phone'}=$dref->{strOB2_Phone};
	$fields{'strOB2_Email'}=$dref->{strOB2_Email};

	$fields{'intHasBankAccount'}=$hasbankaccount_options{$dref->{intHasBankAccount}} || '';
	$fields{'PAstrBSB'}=$dref->{PAstrBSB};
	$fields{'PAstrAccountNum'}=$dref->{PAstrAccountNum};
	$fields{'strBankCode'}=$dref->{strBankCode};
	$fields{'strAccountNo'}=$dref->{strAccountNo};
	$fields{'strAccountName'}=$dref->{strAccountName};
	$fields{'strMPEmail'}=$dref->{strMPEmail};
	$fields{'intPreviousApplication'}=$dref->{intPreviousApplication};
	$fields{'strVoucherCode'}=$dref->{strVoucherCode};
	$fields{'strParentMerchantCode'}=$dref->{strParentMerchantCode};
	$fields{'strParentMerchantName'}=$dref->{strParentMerchantName};

	my $menu='';
	if($view)	{
		$menu= qq[
			<a href="$target?action=APP_edit&amp;intApplicationID=$appID"><img src="images/edit.gif" alt="Edit" title="Edit" width="40" height="40" border="0"></a> 
		];
	}

  my @display_fields=(
    ['intApplicationID'],
    ['intRealmID'],
    ['AssocName'],
    ['ClubName'],
    ['NodeName'],
		['intPreviousApplication'],
    ['PaymentConfig'],
    ['strMerchantAccUsername'],
    ['intNABPaymentOK'],
    ['intStopNABExport'],
    ['intLocked'],
		['strSoftDescriptor'],
		['strParentCode'],
		['intApplicationStatus'],
    ['strApplicationNotes'],
		['intHasBankAccount'],
    ['PAstrBSB'],
    ['PAstrAccountNum'],
    ['strBankCode'],
    ['strAccountNo'],
    ['strAccountName'],
    ['strMPEmail'],
		['strOrgName'],
        ['strShortLegalName'],
        ['strShortBankName'],
		['strACN'],
		['strABN'],
		['strARBN'],
		['strOrgType'],
		['strOrgTypeOther'],
		['strContact'],
		['strContactPhone'],
		['strMailingAddress'],
		['strSuburb'],
		['strPostalCode'],
		['strOrgPhone'],
		['strOrgFax'],
		['strOrgEmail'],
		['strPaymentEmail'],
		['strAgreedBy'],
		['dtCreated'],
		['strState'],
		['strApplicantTitle'],
		['strApplicantFirstName'],
		['strApplicantInitial'],
		['strApplicantFamilyName'],
		['strApplicantPosition'],
		['strApplicantEmail'],
		['strApplicantPhone'],
		['strShortBusName'],
		['strStreetAddress1'],
		['strStreetAddress2'],
		['strURL'],
		['intIncorpStatus'],
		['intGST'],
		['intNumberTxns'],
		['intAvgCost'],
		['intTotalTurnover'],
		['intEstimateGatewayRev'],
		['strOB1_FirstName'],
		['strOB1_FamilyName'],
		['strOB1_Position'],
		['strOB1_Phone'],
		['strOB1_Email'],
		['strOB2_FirstName'],
		['strOB2_FamilyName'],
		['strOB2_Position'],
		['strOB2_Phone'],
		['strOB2_Email'],
		['strVoucherCode'],
		['strParentMerchantCode'],
		['strParentMerchantName'],
  );
  
  my %labels=(
    intApplicationID=>'Application ID',
    strParentMerchantCode=>'Parent Body Merchant Code',
    strParentMerchantName=>'Parent Body Merchant Name',
    AssocName=>'Association Name',
    PaymentConfig=>'Current Payment Config',
		'intPreviousApplication' => 'Previously applied (1=yes)',
    ClubName=>'Club Name',
    intHasBankAccount =>'Has NAB Bank Account',
    NodeName=>'Node/Level Name',
    strEmail=>'Email Address',
    intRealmID=>'Realm',
    intApplicationStatus=>'Application Status',
    PAstrBSB=>'Application BSB',
    PAstrAccountNum=>'Application Account Number',
    strBankCode=>'Current BSB',
    strAccountNo=>'Current Account Number',
    strAccountName=>'Current Account Name',
    strMPEmail=>'MP Email Address',
    strMerchantAccUsername=>'NAB Merchant Username',
    strApplicationNotes=>'NAB Application Notes/Comments',
    intNABPaymentOK=>'NAB OK to Accept Payment ? (1=Yes, 0=No)',
    intStopNABExport=>'STOP NAB Sending Money ? (1=STOP, 0=Continue Sending)',
		strSoftDescriptor=>'Soft Descriptor',
		strParentCode=>'Parent Code',
		strOrgName=>'Organisation Name',
        strShortLegalName=>'Short Legal Name',
        strShortBankName=>'Short Bank Name (18 chars)',
		strACN=>'ACN',
		strABN=>'ABN',
		strContact=>'Contact',
		strContactPhone=>'Contact Phone',
		strMailingAddress=>'Mailing Address',
		strSuburb=>'Suburb',
		strPostalCode=>'Postal Code',
		strOrgPhone=>'Phone',
		strOrgFax=>'Fax',
		strOrgEmail=>'Email',
		strPaymentEmail=>'Payment Email',
		strAgreedBy=>'Agreed By',
		dtCreated=>'Date Created',
		strState=>'State',
		strApplicantTitle=>'Applicant Title',
		strApplicantFirstName=>'Applicant First name',
		strApplicantInitial=>'Applicant Initial',
		strApplicantFamilyName=>'Applicant Family Name',
		strApplicantPosition=>'Applicant Position',
		strApplicantEmail=>'Applicant Email',
		strApplicantPhone=>'Applicant Phone',
		strShortBusName=>'Short Business Name',
		strStreetAddress1=>'Street Address 1',
		strStreetAddress2=>'Street Address 2',
		strURL=>'URL',
		intIncorpStatus=>'Incorp Status',
		intGST=>'GST ?',
		intNumberTxns=>'Number of TXNs',
		intAvgCost=>'Average Cost',
		intTotalTurnover=>'Total Business Turnover',
		intEstimateGatewayRev=>'Estimated revenue that goes through gateway',
		strOB1_FirstName=>'OB1 First Name',
		strOB1_FamilyName=>'OB1 Family Name',
		strOB1_Position=>'OB1 Position',
		strOB1_Phone=>'OB1 Phone',
		strOB1_Email=>'OB1 Email',
		strOB2_FirstName=>'OB2 First Name',
		strOB2_FamilyName=>'OB2 Family Name',
		strOB2_Position=>'OB2 Position',
		strOB2_Phone =>'OB2 Phone',
		strOB2_Email=>'OB2 Email',
    intLocked =>'Application Locked (1=LOCKED, 0 = Unlocked)',
    strARBN=>'ARBN',
    strOrgType=>'Org Type',
    strOrgTypeOther=>'Org Type - Other',
    strVoucherCode =>'Promo Code',

	);

  my %span=();
	my $body = qq[
	<form action="$target" method=post>
		<table width="100%">
	];

  for my $i (0 .. $#display_fields) {
    my $found=0;
    my $subBody='';
    for my $j (0 .. $#{$display_fields[$i]})  {
      if($display_fields[$i][$j]) {$found=1;}
      my $value=$fields{$display_fields[$i][$j]} ;
			if(!defined $value)	{$value= '&nbsp;';}
      my $label=$labels{$display_fields[$i][$j]} || '';
      if(!$label) { next; }
      my $span= $span{$display_fields[$i][$j]} || 1;
			$subBody.=qq[
					<td class="formbg fieldlabel">$label:</td>
					<td class="formbg" colspan="$span">$value</td>
			];
    }
    if($found)  { $body.=qq[ <tr> $subBody </tr> ]; }
  }

	my $clear = $dref->{'strPaymentEmail'} ? qq[ <a href="$target?action=CLEAR_dollar&amp;intEntityID=$dref->{'intEntityID'}&amp;intEntityTypeID=$dref->{'intEntityTypeID'}">Clear Paypal Address</a>] : '';
  $body .= qq[
    </table>
		<div>$clear</div>
		<!--<b>NEED TO HANDLE UPDATING THE tblMoneyLog for Unsent if they change the BSB-AccountNum ??? OR MPEmail ???</b> OR have a different function for this. Clear to if test on BankCode etc above $clear-->
<br>
<br>
			<p><a href="$target?action=APP_detedit&amp;intApplicationID=$appID">{ Edit Application Details }</a></p>
			<p><a href="$target?action=APP_BA_detedit&amp;intApplicationID=$appID">{ Edit Bank Account Details }</a></p>
    <input type="hidden" name="action" value="APP_update">
    <input type="hidden" name="oldaction" value="$action">
		<input type="hidden" name="intApplicationID" value="$appID">
	];

	if($edit)  {
    $body .= qq[<input type=submit value="Update Application">];
	}
  $body .= qq[ </form> ];
	
	my $etID = $Defs::LEVEL_ASSOC;
	my $eID = $dref->{'AssocID'};
	if($dref->{'ClubID'})	{
		$etID = $Defs::LEVEL_CLUB;
		$eID = $dref->{'ClubID'};
	}
	my %tempclient = (
		userName => 'SYSADMIN',
    authLevel => 'iu5hm039m45hf2937y5gtr',
	);
	my $tempclient = setClient(\%tempclient);

  my $files = getUploadedFiles(
		{
			db => $db,
		},
		$etID,
		$eID,
    $Defs::UPLOADFILETYPE_APPLICATION,
    $tempclient,
  );
	for my $f (@{$files})	{
		next if !$f->{'URL'};
		$body .= qq~
			<div>
				<a href = "$f->{'URL'}">Bank Statement</a>
			</div>
		~;
	}

	return ($body,$menu);
}


sub update_application	{
	my ($db, $action, $appID, $target) = @_;

	my $st = qq[
		SELECT 
			intApplicationID,
			intEntityTypeID,
      intEntityID
		FROM
			tblPaymentApplication
		WHERE
			intApplicationID = ?
		LIMIT 1
	];
  my $query = $db->prepare($st);
  $query->execute($appID);
  my $dref= $query->fetchrow_hashref();

	return 'ERROR' if ! $dref->{intApplicationID};
  #Get Parameters
	my $output=new CGI;
  my %fields = $output->Vars;
	$st = qq[
      INSERT INTO tblBankAccount (
        intEntityTypeID,
        intEntityID,
				strMerchantAccUsername,
				intNABPaymentOK,
				intStopNABExport
      )
      VALUES (
        ?,
        ?,
        ?,
				?,
				?
      )
      ON DUPLICATE KEY UPDATE strMerchantAccUsername=?, intNABPaymentOK=?, intStopNABExport=?
  ];
	my $q = $db->prepare($st);
  $q->execute(
      $dref->{intEntityTypeID},
      $dref->{intEntityID},
			$fields{'strMerchantAccUsername'}, 
			$fields{'intNABPaymentOK'}, 
			$fields{'intStopNABExport'}, 
			$fields{'strMerchantAccUsername'}, 
			$fields{'intNABPaymentOK'}, 
			$fields{'intStopNABExport'}, 
  );
  $q->finish();


	$st = qq[
		UPDATE 
			tblPaymentApplication
		SET
			intApplicationStatus=?,
			intLocked=?,
			strSoftDescriptor = ?,
			strApplicationNotes = ?,
			strParentCode = ?,
            strShortBankName = ?,
            strShortLegalName = ?
		WHERE
			intApplicationID = ?
		LIMIT 1
	];
	$q = $db->prepare($st);
  $q->execute(
      $fields{'intApplicationStatus'},
      $fields{'intLocked'} || 0,
      $fields{'strSoftDescriptor'},
      $fields{'strApplicationNotes'},
      $fields{'strParentCode'},
      $fields{'strShortBankName'},
      $fields{'strShortLegalName'},
              $appID
	);
	return application_details($db, 'APP_view', $appID, $target); 
}
sub genTextArea	{
	my($name, $value, $add, $edit)=@_;
	$value||='';
	
  my $retVal=($edit or $add) ? qq[<textarea cols="30" rows="10" name="$name">$value</textarea>] : $value;
	return $retVal;
}



sub genTextBox	{
	my($name, $value, $length, $add, $edit, $event_handler)=@_;
	$length||='';
	$value||='';
	
    my $retVal=($edit or $add) ? qq[<input type="text" name="$name" value="$value" size="$length" $event_handler >] : $value;
	return $retVal;
}

sub list_applications {
  my ($db, $action, $intAssocID, $target) = @_;

  my $application_id_IN		= param('paymentapp_id') || '';
  my $paymentapp_type_IN	= param('paymentapp_type') || '';
  my $merchant_username_IN= param('merchant_username') || '';
  my $paymentapp_status_IN= param('paymentapp_status');
  my $pms_email_IN				= param('pms_email') || '';
  my $assoc_name_IN 			= param('assoc_name') || '';
  my $club_id_IN 					= param('club_id') || '';
  my $club_name_IN 				= param('club_name') || '';
  my $assoc_id_IN 				= param('assoc_id') || '';
  my $realm_IN 						= param('realmID') || '';
  my $sub_realm_IN 						= param('sub_realm_id') || '';
  my $promo_code = param('promo_code') || '';
  my $start_date = param('start_date') || ''; 
  my $end_date = param('end_date') || ''; 
  my $strWhere='';
 
if($start_date!='')
{
   $strWhere .= " AND " if $strWhere;
   $strWhere .= qq[DATE_FORMAT(dtCreated, "%Y-%m-%d") >= '$start_date' ];
}
if($end_date!='')
{
   $strWhere .= " AND " if $strWhere;
   $strWhere .= qq[DATE_FORMAT(dtCreated, "%Y-%m-%d")  <= '$end_date' ];
}
if ($paymentapp_status_IN or $paymentapp_status_IN eq '0') {
    $strWhere .= " AND " if $strWhere;
    $strWhere .= qq[PA.intApplicationStatus = $paymentapp_status_IN ];
  }
  if ($application_id_IN) {
    $strWhere .= " AND " if $strWhere;
    $strWhere .= qq[PA.intApplicationID = $application_id_IN];
  }
  if ($paymentapp_type_IN) {
    $strWhere .= " AND " if $strWhere;
    $strWhere .= qq[PA.intPaymentType= $paymentapp_type_IN];
  }
  if ($merchant_username_IN) {
    $strWhere .= " AND " if $strWhere;
    $strWhere .= qq[strMerchantAccUsername LIKE "%] . $merchant_username_IN . qq[%"];
  }
  if ($club_name_IN) {
    $strWhere .= " AND " if $strWhere;
    $strWhere .= qq[C.strName LIKE "%] . $club_name_IN . qq[%"];
  }
  if ($assoc_name_IN) {
    $strWhere .= " AND " if $strWhere;
    $strWhere .= qq[A.strName LIKE "%] . $assoc_name_IN . qq[%"];
  }
  if ($pms_email_IN) {
    $strWhere .= " AND " if $strWhere;
    $strWhere .= "BA.strMPEmail LIKE '%".$pms_email_IN."%'";
  }
  if ($promo_code ) {
    $strWhere .= " AND " if $strWhere;
		$promo_code =~s/'/''/;
    $strWhere .= "PA.strVoucherCode LIKE '%".$promo_code."%'";
  }
  if ($assoc_id_IN) {
    $strWhere .= " AND " if $strWhere;
    $strWhere .= qq[ (A.intAssocID = $assoc_id_IN OR AC.intAssocID = $assoc_id_IN) ]; 
  }
  if ($club_id_IN) {
    $strWhere .= " AND " if $strWhere;
    $strWhere .= qq[ AC.intClubID = $club_id_IN ];
  }
  if ($realm_IN) {
    $strWhere .= " AND " if $strWhere;
    $strWhere .= "PA.intRealmID = $realm_IN ";
  }
  if ($sub_realm_IN) {
    $strWhere .= " AND " if $strWhere;
    $strWhere .= "RSS.intSubTypeID = $sub_realm_IN ";
  }
	$strWhere = "WHERE $strWhere" if $strWhere;

  my $statement=qq[
		SELECT DISTINCT
			PA.intApplicationID,
			A.intAssocID as AssocID, 
			A.strName as AssocName, 
			C.intClubID as ClubID,
			C.strName as ClubName, 
			N.strName as NodeName, 
			N.intNodeID as NodeID, 
			strRealmName,
			PA.intPaymentType,
			PA.intApplicationStatus,
		DATE_FORMAT(PA.dtCreated,"%d/%m/%Y %H:%i") AS dtCreated,
			PA.strSoftDescriptor,
			PA.strParentCode,
			BA.strBankCode,
			BA.strAccountNo,
			BA.strMerchantAccUsername,
			PA.intPreviousApplication,
      PA.strShortBusName,
			PA.strPaymentEmail,
			RSS.strSubTypeName,
			PA.strApplicantTitle,
			PA.strApplicantFirstName,
			PA.strApplicantFamilyName,
			PA.strVoucherCode,
			PA.strShortBankName
		FROM 
			tblPaymentApplication as PA
			LEFT JOIN tblBankAccount as BA ON (
				PA.intEntityTypeID=BA.intEntityTypeID
				AND PA.intEntityID=BA.intEntityID
			)
			LEFT JOIN tblAssoc_Clubs as AC ON (
					AC.intClubID=PA.intEntityID 
					AND PA.intEntityTypeID=3
			)
			LEFT JOIN tblAssoc as A ON (
				(
					A.intAssocID=PA.intEntityID
					AND PA.intEntityTypeID=5
				)
				OR
				(
					A.intAssocID=AC.intAssocID
				)
			)
			LEFT JOIN tblClub as C ON (
				C.intClubID=PA.intEntityID
				AND AC.intAssocID = A.intAssocID
				AND PA.intEntityTypeID=3
			)
			LEFT JOIN tblNode as N ON (
				N.intNodeID=PA.intEntityID 
				AND PA.intEntityTypeID>5
			)
			LEFT JOIN tblRealms ON (PA.intRealmID=tblRealms.intRealmID)
			LEFT JOIN tblRealmSubTypes as RSS ON (A.intAssocTypeID= RSS.intSubTypeID)
		$strWhere
		ORDER BY 
			A.strName
  ];

  my $query = $db->prepare($statement) or query_error($statement);
  $query->execute() or query_error($statement);
  my $count=0;
  my $body='';
  while(my $dref= $query->fetchrow_hashref()) {
    foreach my $key (keys %{$dref}) { if(!defined $dref->{$key})  {$dref->{$key}='';} }
    $dref->{AssocName} = $dref->{AssocName} || '&nbsp;';
    $dref->{ClubName} = $dref->{ClubName} || '&nbsp;';
    $dref->{NodeName} = $dref->{NodeName} || '&nbsp;';
    $dref->{strRealmName} ||= '&nbsp;';
    my $class='';
    my $classborder='commentborder';
    if($count++%2==1) {
      $class=q[ class="commentshaded" ];
      $classborder="commentbordershaded";
    }
		my $extralink='';
		if($dref->{intRecStatus}<0)	{
			$classborder.=" greytext";
			$extralink=qq[ class="greytext"];
		}
        my $swol = ($dref->{'intSWOL'}) ? 'YES' : '-';
				my $previously = $dref->{'intPreviousApplication'} == 1 ? 'YES' : '-';
    $body.=qq[
      <tr>
	<td class="$classborder">$count</td>
        <td class="$classborder"><a $extralink href="$target?action=APP_view&amp;intApplicationID=$dref->{intApplicationID}">[view]</a></td>
	      <td class="$classborder">$dref->{ClubName}</td>
	      <td class="$classborder">$dref->{AssocName}</td>
	      <td class="$classborder">$dref->{strShortBusName}</td>
	      <td class="$classborder">$dref->{strShortBankName}</td>
        <td class="$classborder">$dref->{strRealmName}</td>
        <td class="$classborder">$dref->{strSubTypeName}</td>
        <td class="$classborder">$Defs::paymentTypes{$dref->{intPaymentType}}</td>
        <td class="$classborder">$Defs::applicationStatus{$dref->{intApplicationStatus}}</td>
        <td class="$classborder">$dref->{dtCreated}</td>
        <td class="$classborder">$dref->{strPaymentEmail}</td>
        <td class="$classborder">$dref->{strSoftDescriptor}</td>
        <td class="$classborder">$dref->{strParentCode}</td>
        <td class="$classborder">$dref->{strBankCode}</td>
        <td class="$classborder">$dref->{strAccountNo}</td>
        <td class="$classborder">$dref->{strMerchantAccUsername}</td>
        <td class="$classborder">$previously</td>
        <td class="$classborder">$dref->{strApplicantTitle}</td>
        <td class="$classborder">$dref->{strApplicantFirstName}</td>
        <td class="$classborder">$dref->{strApplicantFamilyName}</td>
        <td class="$classborder">$dref->{strVoucherCode}</td>
      </tr>
    ];
  }
  if(!$body)  {
    $body.=qq[
    <table cellpadding="1" cellspacing="0" border="0" width="90%" align="center">
      <tr>
				<td colspan="3" align="center"><b><br> No Search Results were found<br><br></b></td>
      </tr>
    </table>
    <br>
    ];
  }
  else  {
    $body=qq[
		 <table cellpadding="1" cellspacing="0" border="0" width="95%" align="left">
			<tr>
        <th colspan=2 style="text-align:left;">&nbsp;</th>
        <th style="text-align:left;">Club Name</th>
        <th style="text-align:left;">Association Name</th>
        <th style="text-align:left;">Short Name</th>
        <th style="text-align:left;">Short BANK Name</th>
        <th style="text-align:left;">Realm</th>
        <th style="text-align:left;">Sub Realm</th>
        <th style="text-align:left;">Application Type</th>
        <th style="text-align:left;">Application Status</th>
        <th style="text-align:left;">Application Created Date</th>
        <th style="text-align:left;">Application Email</th>
        <th style="text-align:left;">Soft Descriptor</th>
        <th style="text-align:left;">ParentCode</th>
        <th style="text-align:left;">BSB Code</th>
        <th style="text-align:left;">Account Number</th>
        <th style="text-align:left;">NAB Merchant</th>
        <th style="text-align:left;">Previously Applied ?</th>
        <th style="text-align:left;">Applicants Title</th>
        <th style="text-align:left;">Applicants Firstname</th>
        <th style="text-align:left;">Applicants Surname</th>
        <th style="text-align:left;">Promo Code</th>
      </tr>

      $body
    </table><br>
    ];
  }

  return ($body,'');
}


#--------------

sub detailed_edit	{
	my (
		$db,
		$action,
		$appID,
		$target,
	) = @_;

	my $option= 'edit';
	my $field = undef;
	{
		my $st = qq[
			SELECT * 
			FROM tblPaymentApplication
			WHERE intApplicationID = ?
		];
		my $q = $db->prepare($st);
		$q->execute($appID);
		$field = $q->fetchrow_hashref();
		$q->finish();
	}

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
				sectionname => 'orgdetails',
			},
      intPreviousApplication => {
        label => 'Have you previously applied for merchant status with NAB (through SportingPulse) for this Legal Name?',
        value => $field->{intPreviousApplication},
        type  => 'lookup',
        options => {1 => 'Yes', 0 => 'No'},
        firstoption => ['',''],
				sectionname => 'orgdetails',
      },
			strShortBusName => {
				label => 'Shortened Business Name',
				value => $field->{strShortBusName},
				type  => 'text',
				size  => '20',
				maxsize => '24',
				sectionname => 'orgdetails',
				posttext => q[<div style=";font-style:italic;">20 characters maximum.</div>],
			},

			strStreetAddress1 => {
				label => 'Street Address 1',
				value => $field->{strStreetAddress1},
				type  => 'text',
				size  => '50',
				maxsize => '25',
				sectionname => 'orgdetails',
			},
			strStreetAddress2 => {
				label => 'Street Address 2',
				value => $field->{strStreetAddress2},
				type  => 'text',
				size  => '50',
				maxsize => '25',
				sectionname => 'orgdetails',
			},			
			strSuburb => {
				label => 'Suburb',
				value => $field->{strSuburb},
				type  => 'text',
				size  => '30',
				maxsize => '200',
				sectionname => 'orgdetails',
			},
			strState => {
				label => 'State',
				value => $field->{strState},
				firstoption => ['',' '],
				type  => 'lookup',
				size  => '1',
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
				sectionname => 'orgdetails',
			},
			strPostalCode => {
				label => 'Postal Code',
				value => $field->{strPostalCode},
				type  => 'text',
				size  => '15',
				maxsize => '15',
				sectionname => 'orgdetails',
			},

			strOrgPhone => {
				label => 'Organisation Phone',
				value => $field->{strOrgPhone},
				type  => 'text',
				size  => '20',
				maxsize => '20',
				sectionname => 'orgdetails',
			},
			strURL => {
				label => 'Organisation Website',
				value => $field->{strURL},
				type  => 'text',
				size  => '35',
				maxsize => '250',
				sectionname => 'orgdetails',
			},

      intIncorpStatus => {
        label => 'Is your organisation incorporated?',
        value => $field->{intIncorpStatus},
        type  => 'lookup',
        options => {1 => 'Yes', 0 => 'No'},
        firstoption => ['',''],
				sectionname => 'orgdetails',
				posttext => q[<div style=";font-style:italic;">If <b>Yes</b> then an ACN or ARBN must be supplied.</div>],
      },
      intGST => {
        label => 'Is your organisation registered for GST?',
        value => $field->{intGST},
        type  => 'lookup',
        options => {1 => 'Yes', 0 => 'No'},
        firstoption => ['',''],
				sectionname => 'orgdetails',
				posttext => q[<div style=";font-style:italic;">If <b>Yes</b> then an ABN must be supplied.</div>],
      },
			strABN => {
				label => 'ABN',
				value => $field->{strABN},
				type  => 'text',
				size  => '30',
				maxsize => '50',
				sectionname => 'orgdetails',
			},
			strACN => {
				label => 'ACN (Australian Company Number)',
				value => $field->{strACN},
				type  => 'text',
				size  => '30',
				maxsize => '50',
				sectionname => 'orgdetails',
			},
			strARBN=> {
				label => 'ARBN (Australian Registered Business Number)',
				value => $field->{strARBN},
				type  => 'text',
				size  => '30',
				maxsize => '50',
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
      },
			strOrgTypeOther => {
				label => 'If other, please list here:',
				value => $field->{strOrgTypeOther},
				type  => 'text',
				size  => '30',
				maxsize => '50',
				sectionname => 'orgdetails',
			},

      strApplicantTitle => {
        label => 'Applicant Title',
        value => $field->{strApplicantTitle},
        type  => 'text',
        size  => '5',
        maxsize => '5',
        sectionname => 'applicant',
      },
      strApplicantFirstName => {
        label => 'Applicant First Name',
        value => $field->{strApplicantFirstName},
        type  => 'text',
        size  => '50',
        maxsize => '50',
        sectionname => 'applicant',
      },
      strApplicantInitial => {
        label => 'Applicant Middle Initial',
        value => $field->{strApplicantInitial},
        type  => 'text',
        size  => '1',
        maxsize => '1',
        sectionname => 'applicant',
      },      
			strApplicantFamilyName => {
        label => 'Applicant Family Name',
        value => $field->{strApplicantFamilyName},
        type  => 'text',
        size  => '50',
        maxsize => '50',
        sectionname => 'applicant',
      },
			strApplicantPosition => {
        label => 'Applicant Position',
        value => $field->{strApplicantPosition},
        type  => 'text',
        size  => '50',
        maxsize => '50',
        sectionname => 'applicant',
      },
      strApplicantEmail => {
        label => 'Applicant Email',
        value => $field->{'strApplicantEmail'},
        type  => 'text',
        size  => '50',
        maxsize => '250',
        sectionname => 'applicant',
				validate => 'EMAIL',
      },
      strApplicantPhone => {
        label => 'Applicant Phone',
        value => $field->{strApplicantPhone},
        type  => 'text',
        size  => '20',
        maxsize => '20',
        sectionname => 'applicant',
      },

      strOB1_FirstName => {
        label => 'First Name',
        value => $field->{strOB1_FirstName} || '',
        type  => 'text',
        size  => '50',
        maxsize => '50',
        sectionname => 'officebearer1',
      },
      strOB1_FamilyName => {
        label => 'Family Name',
        value => $field->{strOB1_FamilyName} || '',
        type  => 'text',
        size  => '50',
        maxsize => '50',
        sectionname => 'officebearer1',
      },
      strOB1_Position => {
        label => 'Position',
        value => $field->{strOB1_Position} || '',
        type  => 'text',
        size  => '50',
        maxsize => '50',
        sectionname => 'officebearer1',
      },
      strOB1_Phone => {
        label => 'Phone',
        value => $field->{strOB1_Phone} || '',
        type  => 'text',
        size  => '20',
        maxsize => '50',
        sectionname => 'officebearer1',
      },
      strOB1_Email => {
        label => 'Email',
        value => $field->{strOB1_Email} || '',
        type  => 'text',
        size  => '50',
        maxsize => '250',
        sectionname => 'officebearer1',
				validate => 'EMAIL',
      },
      strOB2_FirstName => {
        label => 'First Name',
        value => $field->{strOB2_FirstName} || '',
        type  => 'text',
        size  => '50',
        maxsize => '50',
        sectionname => 'officebearer2',
      },
      strOB2_FamilyName => {
        label => 'Family Name',
        value => $field->{strOB2_FamilyName} || '',
        type  => 'text',
        size  => '50',
        maxsize => '50',
        sectionname => 'officebearer2',
      },
      strOB2_Position => {
        label => 'Position',
        value => $field->{strOB2_Position} || '',
        type  => 'text',
        size  => '50',
        maxsize => '50',
        sectionname => 'officebearer2',
      },
      strOB2_Phone => {
        label => 'Phone',
        value => $field->{strOB2_Phone} || '',
        type  => 'text',
        size  => '20',
        maxsize => '50',
        sectionname => 'officebearer2',
      },
      strOB2_Email => {
        label => 'Email',
        value => $field->{strOB2_Email} || '',
        type  => 'text',
        size  => '50',
        maxsize => '250',
        sectionname => 'officebearer2',
				validate => 'EMAIL',
      },

      intNumberTxns => {
        label => 'How many members does your organisation have?',
        value => $field->{intNumberTxns},
        type  => 'text',
        size  => '7',
        maxsize => '7',
        sectionname => 'txns',
				validate => 'NUMBER',
      },
      intAvgCost => {
        label => 'What is your average registration fee?',
        value => $field->{intAvgCost},
        type  => 'text',
        size  => '7',
        maxsize => '7',
        sectionname => 'txns',
				validate => 'NUMBER',
      },
      intTotalTurnover => {
        label => "What is your organisation's total annual income?",
        value => $field->{intTotalTurnover},
        type  => 'text',
        size  => '9',
        maxsize => '9',
        sectionname => 'txns',
				validate => 'NUMBER',
      },

      intEstimateGatewayRev => {
        label => "How much revenue do you anticipate will go through this gateway?",
        value => $field->{intEstimateGatewayRev},
        type  => 'text',
        size  => '9',
        maxsize => '9',
        sectionname => 'txns',
                validate => 'NUMBER',
      },
			strPaymentEmail => {
				label => 'Accounts Email',
				value => $field->{strPaymentEmail},
				type  => 'text',
				size  => '35',
				maxsize => '250',
				validate => 'EMAIL',
				posttext => qq[<div style="float:right;width:340px;font-style:italic;">Note: This is where your invoices will be sent.</div>],
        sectionname => 'other',
			},
			strVoucherCode => {
				label => 'Promo Code',
				value => $field->{strVoucherCode},
				type  => 'text',
				size  => '25',
				maxsize => '250',
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

			intNumberTxns
			intAvgCost
			intTotalTurnover
			intEstimateGatewayRev
			intHasBankAccount

			strPaymentEmail 
			strVoucherCode
		)],
		options => {
			labelsuffix => ':',
			hideblank => 1,
			target => $target,
			formname => 'n_form',
      submitlabel => "Save",
      introtext => '',
			NoHTML => 1, 
			FormEncoding=>'multipart/form-data',
      updateSQL => qq[
        UPDATE tblPaymentApplication
        SET --VAL--
        WHERE intApplicationID = $appID
				LIMIT 1
			],

      LocaleMakeText => undef,
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
			action => $action,
			intApplicationID => $appID,
		},
	);
	my $resultHTML='';
	my $ok = 0;
	($resultHTML, $ok)=handleHTMLForm(\%FieldDefinitions, undef, $option, '',$db);
	my $title='Payment Application';

	$resultHTML .= qq[

		<-- <a href = "$target?action=APP_view&intApplicationID=$appID"> Return to Application</a>
	];
	return ($resultHTML,$title);
}


sub bankDetails_list {
  my ($db, $action, $intAssocID, $target) = @_;
  my $entityTypeID 			= param('entityTypeID') || '';
  my $entityID 			= param('entityID') || '';
  my $name_IN 			= param('name_in') || '';
  my $realm_IN 						= param('realmID') || '';
  my $strWhere='';
    if(!$entityID and !$name_IN){
        return "Please provide more detail in ID or Name field and try again!";
    }
    if($entityID){
        $strWhere .= " AND " if $strWhere;
        $strWhere= qq[ PA.intEntityID = $entityID ];
    }
  if ($name_IN) {
    $strWhere .= " AND " if $strWhere;
    $strWhere .= qq[A.strName LIKE "%] . $name_IN . qq[%"];
  }
  if ($realm_IN) {
    $strWhere .= " AND " if $strWhere;
    $strWhere .= "A.intRealmID = $realm_IN ";
  }
	$strWhere = "WHERE $strWhere" if $strWhere;
    my $strJoin ='';
    if($entityTypeID eq $Defs::LEVEL_CLUB){
        $strJoin = qq[LEFT JOIN tblAssoc_Clubs as AC ON (
                    AC.intClubID=PA.intEntityID
                    AND PA.intEntityTypeID=$Defs::LEVEL_CLUB
            )
            LEFT JOIN tblAssoc as A ON (
                (
                    A.intAssocID=PA.intEntityID
                    AND PA.intEntityTypeID=$Defs::LEVEL_ASSOC
                )
                OR
                (
                    A.intAssocID=AC.intAssocID
                )
            )
            LEFT JOIN tblClub as C ON (
                C.intClubID=PA.intEntityID
                AND AC.intAssocID = A.intAssocID
                AND PA.intEntityTypeID = $Defs::LEVEL_CLUB
            )
            ];
    }
    if($entityTypeID eq $Defs::LEVEL_ASSOC){
        $strJoin = qq[  LEFT JOIN tblAssoc as A ON (
                (
                    A.intAssocID=PA.intEntityID
                    AND PA.intEntityTypeID= $Defs::LEVEL_ASSOC
                )
            )];
    }
    if($entityTypeID eq $Defs::LEVEL_ZONE){
        $strJoin = qq[  LEFT JOIN tblNode as A ON (
                (
                    A.intNodeID=PA.intEntityID
                    AND A.intTypeID = intEntityTypeID
                    AND PA.intEntityTypeID= $Defs::LEVEL_ZONE
                )
            )];
    }
    if($entityTypeID eq $Defs::LEVEL_REGION){
             $strJoin = qq[  LEFT JOIN tblNode as A ON (
                (
                    A.intNodeID=PA.intEntityID
                    AND A.intTypeID = intEntityTypeID
                    AND PA.intEntityTypeID= $Defs::LEVEL_REGION
                )
            )];
    }
    if($entityTypeID eq $Defs::LEVEL_STATE){
           $strJoin = qq[  LEFT JOIN tblNode as A ON (
                (
                    A.intNodeID=PA.intEntityID
                    AND A.intTypeID = intEntityTypeID
                    AND PA.intEntityTypeID= $Defs::LEVEL_STATE
                )
            )]; 
    }
    if($entityTypeID eq $Defs::LEVEL_NATIONAL){
           $strJoin = qq[  LEFT JOIN tblNode as A ON (
                (
                    A.intNodeID=PA.intEntityID
                    AND A.intTypeID = intEntityTypeID
                    AND PA.intEntityTypeID= $Defs::LEVEL_NATIONAL
                )
            )]; 
    }
    my $statement = qq[
        SELECT DISTINCT
            PA.intEntityID,
            PA.intEntityTypeID,
            A.strName as Name,
        DATE_FORMAT(PA.dtBankAccount,"%d/%m/%Y %H:%i") AS dtBankAccount,
            PA.strBankCode,
            PA.strAccountNo,
            PA.strAccountName,
            PA.strMerchantAccUsername,
            PA.strMPEmail,
            PA.intNABPaymentOK,
            PA.intStopNABExport
        FROM
            tblBankAccount as PA
            $strJoin
            LEFT JOIN tblRealms ON (A.intRealmID=tblRealms.intRealmID)
        $strWhere
        ORDER BY
            A.strName
    ];
  my $query = $db->prepare($statement) or query_error($statement);
  $query->execute() or query_error($statement);
  my $count=0;
  my $body='';
  while(my $dref= $query->fetchrow_hashref()) {
    foreach my $key (keys %{$dref}) { if(!defined $dref->{$key})  {$dref->{$key}='';} }
    $dref->{AssocName} = $dref->{AssocName} || '&nbsp;';
    $dref->{ClubName} = $dref->{ClubName} || '&nbsp;';
    $dref->{NodeName} = $dref->{NodeName} || '&nbsp;';
    $dref->{strRealmName} ||= '&nbsp;';
    my $class='';
    my $classborder='commentborder';
    if($count++%2==1) {
      $class=q[ class="commentshaded" ];
      $classborder="commentbordershaded";
    }
		my $extralink='';
		if($dref->{intRecStatus}<0)	{
			$classborder.=" greytext";
			$extralink=qq[ class="greytext"];
		}
     my $sql = qq[
            SELECT *
            FROM
                tblUploadedFiles
            WHERE
                intEntityID = ?
                AND intEntityTypeID = ?
                AND intFileType = $Defs::UPLOADFILETYPE_STATEMENT] ;
    my $query_file = $db->prepare($sql) or query_error($sql);
    my $EntityID = $dref->{intEntityID};
    my $EntityTypeID = $dref->{intEntityTypeID};
    $query_file->execute($EntityID , $EntityTypeID) or query_error($sql);
    my $statement_link ='No Bank Statement';

    my %tempclient = (
        userName => 'SYSADMIN',
    authLevel => 'iu5hm039m45hf2937y5gtr',
    );
    my $tempclient = setClient(\%tempclient);

  my $files = getUploadedFiles(
        {
            db => $db,
        },
        $EntityTypeID,
        $EntityID,
    $Defs::UPLOADFILETYPE_STATEMENT,
    $tempclient,
  );
    for my $f (@{$files})   {
        next if !$f->{'URL'};
        #my  $extention = $dref->{'strExtension'};
        
       $statement_link= qq[<a href ="$f->{'URL'}">[View Bank Statment]</a>];

    }

    #while(my $dref= $query_file->fetchrow_hashref()) {
    #    my  $extention = $dref->{'strExtension'};
    #    $statement_link= qq[<a href ="$Defs::uploaded_url/files/$dref->{'strPath'}$dref->{'intFileID'}.$extention">[View Bank Statment]</a>];
    #}
    my $status = ($dref->{intStopNABExport})?qq[<a style ='color:red' href ="$target?action=Bank_Detail_NabExport&EntityID=$EntityID&EntityTypeID=$EntityTypeID&export=0" >No</a>]:qq[<a href ="$target?action=Bank_Detail_NabExport&EntityID=$EntityID&EntityTypeID=$EntityTypeID&export=1" >Yes</a>];
    $body.=qq[
      <tr>
	<td class="$classborder">$count</td>
        <td class="$classborder">$statement_link</td>
	      <td class="$classborder">$dref->{Name}</td>
	      <td class="$classborder">$dref->{intEntityID}</td>
        <td class="$classborder">$dref->{dtBankAccount}</td>
        <td class="$classborder">$dref->{strMPEmail}</td>
        <td class="$classborder">$dref->{strBankCode}</td>
        <td class="$classborder">$dref->{strAccountNo}</td>
        <td class="$classborder">$dref->{strAccountName}</td>
        <td class="$classborder">$dref->{strMerchantAccUsername}</td>
        <td class="$classborder">$dref->{intNABPaymentOK}</td>
        <td class="$classborder">$status</td>
      </tr>
    ];
  }
  if(!$body)  {
    $body.=qq[
    <table cellpadding="1" cellspacing="0" border="0" width="90%" align="center">
      <tr>
				<td colspan="3" align="center"><b><br> No Search Results were found<br><br></b></td>
      </tr>
    </table>
    <br>
    ];
  }
  else  {
    $body=qq[
		 <table cellpadding="1" cellspacing="0" border="0" width="95%" align="left">
			<tr>
        <th colspan=2 style="text-align:left;">&nbsp;</th>
        <th style="text-align:left;">Name</th>
        <th style="text-align:left;">ID</th>
        <th style="text-align:left;">Updated on</th>
        <th style="text-align:left;">MP Email</th>
        <th style="text-align:left;">BSB Code</th>
        <th style="text-align:left;">Account Number</th>
        <th style="text-align:left;">Account Name</th>
        <th style="text-align:left;">NAB Merchant</th>
        <th style="text-align:left;">Nab Payment</th>
        <th style="text-align:left;">NAB Export</th>
      </tr>

      $body
    </table><br>
    ];
  }

  return ($body,'');
}

sub bankDetails_view {
    my ($db, $action, $EntityID,$EntityTypeID, $target, $edit) = @_;

    return ('','');
}
sub update_NAB_export{
    my ($db, $action, $EntityID,$EntityTypeID, $target, $export) = @_;
    my $menu = qq[Nab Export status change];
    my $header = $export?qq[<h2>Nab Export is prevented now.</h2>]:qq[<h2>Nab export is allowed now.</h2>];
    my $body = qq[$header <a href="$target?action=Bank_Detail_list&entityID=$EntityID&entityTypeID=$EntityTypeID">Click to return to previous page</a> ];
    my $query = qq[ 
                            UPDATE tblBankAccount
                            SET intStopNABExport =?
                            WHERE 
                                intEntityID =?
                                AND intEntityTypeID =?
                            ];
    my $update_query = $db->prepare($query) or query_error($query);
    $update_query->execute($export, $EntityID, $EntityTypeID);
    return ($body,$menu);
}
1;
