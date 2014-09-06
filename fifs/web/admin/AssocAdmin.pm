#
# $Header: svn://svn/SWM/trunk/web/admin/AssocAdmin.pm 11307 2014-04-15 22:28:06Z ppascoe $
#

package AssocAdmin;

require Exporter;
@ISA =  qw(Exporter);
@EXPORT = qw(handle_assoc);
@EXPORT_OK = qw(handle_assoc);

use lib "..", "../..", "../sp_publisher", "../externallms";

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
use CompAdmin;
use Countries;
use AssocConfig;
use SWOLconfig;
use UtilsAdmin;
use AdminPageGen;
use PassportLink;
use MCache;
use BankAccount;
use Time::HiRes qw/gettimeofday/;
use AdminMemberHide;

sub handle_assoc	{
  my($db, $action, $target)=@_;
  my $assocID = param('intAssocID') || 0;
  my $realmID = '';
  
  my $body = '';
  my $menu = '';
  
if ($action ne 'ASSOC_list') {
 	if (!AdminCommon::verify_hash()) {
		return('Error in Querystring hash');
	}  
}

  $realmID = $assocID ? getAssocRealm($db, $assocID) : 0;
  if($action eq 'ASSOC_CLR') {
  	my $clr_password=param('clr_password') || '';
	$body = clearSyncHistory($db, $assocID, $clr_password);
	$action = 'ASSOC_upl';
  }	

    
 
  if ($action eq 'ERROR') {
  	# $body has already been setup
  }
  elsif($action eq 'ASSOC_update') {
		($body,$menu)=update_assoc($db, $action, $assocID, $target); 
  }
  elsif($action eq 'ASSOC_list') {
		($body,$menu)=list_assoc($db, $action, $assocID, $target); 
  }
  elsif($action eq 'ASSOC_upl') {
		($body,$menu)=list_uploads($db, $action, $assocID, $target); 
  }
  elsif($action eq 'ASSOC_passport') {
		($body,$menu)=passportLogins($db,  5, $assocID); 
  }
  elsif($action eq 'ASSOC_loc') {
		($body,$menu)=list_location($db, $action, $assocID, $target, $realmID); 
  }
  elsif($action eq 'ASSOC_lu') {
		($body,$menu)=update_loc($db, $assocID, $target); 
  }
  elsif($action eq 'ASSOC_new') {
		($body,$menu)=new_assoc($db, $target); 
  }
  elsif($action eq 'ASSOC_newlogin') {
    ($body,$menu) = additional_assoc_login_form($db,$assocID,$target,'NEW');
  }
  elsif($action eq 'ASSOC_editlogin') {
    ($body,$menu) = additional_assoc_login_form($db,$assocID,$target,'EDIT');
  }
  elsif($action eq 'ASSOC_addnewlogin') {
    ($body,$menu) = add_assoc_login($db,$assocID, $target);
  }
  elsif($action eq 'ASSOC_modifylogin') {
    ($body,$menu) = update_assoc_login($db,$assocID, $target);
  }
  elsif($action eq 'ASSOC_clubs') {
    ($body,$menu) = display_club_search_list($db, $action, $assocID, $target);
  }
  ###
  elsif($action eq 'ASSOC_teams') {
    ($body,$menu) = display_team_search_list($db, $action, $assocID, 0, $target);
  }
  elsif($action eq 'ASSOC_teams_delete') {
    ($body,$menu) = mark_team_as_deleted($db, $target);
  }
  elsif($action eq 'ASSOC_teams_undelete') {
    ($body,$menu) = mark_team_as_undeleted($db, $target);
  }
  ###
  elsif($action eq 'ASSOC_comps') {
    ($body, $menu) = display_comp_list($db, $action, $assocID, 0, $target);
  }
  elsif ($action eq 'ASSOC_comps_manage') {
    ($body, $menu) = handleManageLadderTeams($db, $target);
  }
  ###
  elsif($action eq 'ASSOC_clear_club') {
    ($body,$menu) = clear_team_club($db, $action, $assocID, 0, 0, $target);
  }
  elsif($action eq 'ASSOC_tstamp') {
    ($body,$menu) = update_timestamps_form($db,$assocID, $target);
  }
  elsif($action eq 'ASSOC_tstamp_reset') {
    ($body,$menu) = update_timestamps($db,$assocID, $target, $realmID);
  }
  elsif($action eq 'ASSOC_add_club') {
    ($body,$menu) = add_club($db, $target);
  }
  elsif($action eq 'ASSOC_add_club_form') {
    ($body,$menu) = add_club_form($db, $target);
  }
 elsif($action =~ /ASSOC_ASSOC_config/) {
    $body = AssocConfig($db,$target);
  }

 elsif($action =~ /ASSOC_paymentsplits/) {
    $body = ManagePaymentSplits($db,$assocID, 5);
  }
  elsif($action =~ /ASSOC_config/) {
    $body = SWOLconfig($db,$target);
  }
 elsif($action =~ /ASSOC_BankAccount/) {
    $body = BankAccount($db,$target);
  }
    elsif ( $action =~ /ASSOC_memberhide/ ) {
    $body = member_hide( $db, $assocID, $target );
    }
  else  {
    ($body,$menu)=assoc_details($db, $action, $assocID, $target);
  }
  return ($body,$menu);
}

# *********************SUBROUTINES BELOW****************************
sub ManagePaymentSplits {


my ($db, $entityID, $entityType) = @_;
my $paymentSplit = param("paymentSplitID");
my $paymentSplitAction = param("paymentSplitAction");
my $strOtherBankCode = param("strOtherBankCode") || '';
my $strOtherAccountName = param("strOtherAccountName") || '';
my $strOtherAccountNo = param("strOtherAccountNo") || '';
my $strMPEmail = param("strMPEmail") || '';
	if($paymentSplit>0 and $paymentSplitAction eq 'update')
	{
	  my $st = qq[
                UPDATE tblPaymentSplitItem
                SET
		strOtherBankCode = ?,
		strOtherAccountName = ?,
		strOtherAccountNo = ?,
                strMPEmail = ?
		WHERE intItemID=?
                LIMIT 1
        ];
        my $q = $db->prepare($st);
        $q->execute($strOtherBankCode, $strOtherAccountName, $strOtherAccountNo, $strMPEmail, $paymentSplit);
	}


	my $statement = qq[
		SELECT SI.*, PS.strSplitName 
		FROM tblPaymentSplit PS
		LEFT JOIN tblPaymentSplitItem SI ON (SI.intSplitID = PS.intSplitID)
		WHERE PS.intEntityID=? AND intEntityTypeID=?
		ORDER BY PS.strSplitName
	];
 	my $query = $db->prepare($statement) or query_error($statement);
        $query->execute($entityID, $entityType) or query_error($statement);
	my $body='';
	my $splitNameOld = '';
	my $splitItemID=0;
	my $splitAccNo = '';
	my $splitAccName =  '';
	my $splitBankCode =    '';
	my $showheader = "No";
	while (my $dref = $query->fetchrow_hashref())   {
	if($showheader eq "No")
	{
	$showheader = 'Yes';
	 $body .= qq[
        
  <table style="margin-left:auto;margin-right:auto;"><tr><td class="formbg">
        <h2>Payment Splits</h2><table  cellpadding=10 cellspacing=0 border=1 bordercolor="black">
                <tr>
                        <th>Bank Code</th>
                        <th>Account Number</th>
                        <th>Account Name</th>
                        <th>Paypal Email</th>
                        <th>&nbsp;</th>

                </tr>


	];
	}

	my $splitName = 	$dref->{strSplitName};
	my $splitItemID =       $dref->{intItemID};
	my $strMPEmail = $dref->{strMPEmail};
	my $splitAccNo =       $dref->{strOtherAccountNo};
	my $splitAccName =       $dref->{strOtherAccountName};
	my $splitBankCode =       $dref->{strOtherBankCode};
	if($splitNameOld ne $splitName)
	{
		$body .= qq[<tr><td colspan=99><h2 style="margin:0px;">$splitName</h2></td></tr>];
		$splitNameOld = $splitName;
	}



 	if($splitItemID==$paymentSplit and $paymentSplitAction eq 'edit') {

                    $body .= qq[

                           <form method="post" action="">
                         <input type="hidden" name="paymentSplitID" value="$splitItemID">
                         <input type="hidden" name="paymentSplitAction" value="update">
                         <input type="hidden" name="action" value="ASSOC_paymentsplits">
                         <input type="hidden" name="intAssocID" value="$entityID">
                         <tr>
                        <td><input type="text" name="strOtherBankCode" value="$splitBankCode"></td>
                        <td><input type="text" name="strOtherAccountNo" value="$splitAccNo"></td>
                        <td><input type="text" name="strOtherAccountName" value="$splitAccName"></td>
                        <td><input type="text" name="strMPEmail" value="$strMPEmail"></td>
                         <td><input type="submit" value="Edit" name="frmSubmit"></td></tr></form>




                         ];
                }
                else {

                $body .= qq[

                         <tr>
                        <td>$splitBankCode</td>
                        <td>$splitAccNo</td>
                        <td>$splitAccName</td>
                        <td>$strMPEmail</td>
                                <td><a href="?action=ASSOC_paymentsplits&intAssocID=$entityID&paymentSplitID=$splitItemID&paymentSplitAction=edit">Edit</a></td>

                        </tr>
                ];
                }
       }
	 if($showheader eq 'Yes')
        {
	$body .= qq[</table>];
	}else
	{
		$body = '<p align="center">There are no Payment Splits</p>';
	}





return $body;

	

}

sub clearSyncHistory	{

	my ($db, $assocID, $clr_password) = @_;

	$assocID ||= 0;
	$assocID = 0 if $assocID !~ /^\d*$/;

	return "WRONG ID" if ! $assocID;

	$clr_password ||= '';

	return "WRONG PASSWORD" if ($clr_password ne 'dolphinburger');
	

	my $st = qq[
		UPDATE tblAssoc
		SET strFirstSyncCode=''
		WHERE intAssocID=$assocID
		LIMIT 1
	];
	$db->do($st);

	$st = qq[
		DELETE FROM tblSync
		WHERE intAssocID=$assocID
	];
	$db->do($st);
	
	return "DONE";
}
sub assoc_details	{
	my ($db, $action, $intAssocID, $target) = @_;

	my $dref;
	my $realmID=$intAssocID ? getAssocRealm($db, $intAssocID) : param('DB_intRealmID') || 0;
	return 'Need to select Realm' if !$realmID;
	return 'Need to select Country ' if ! param('DB_strCountry') and $action eq 'ASSOC_add';
	return 'Need to select Reporting State' if ! param('DB_strState') and $action eq 'ASSOC_add';


	my($add, $edit,$view)=(0,0,0);
	if(!$intAssocID)	{$action='ASSOC_add';}
	if($action eq 'ASSOC_add')	{$add=1;}
	elsif($action eq 'ASSOC_edit')	{$edit=1;}
	else	{$view=1;}
	my %fields=();
	if ($edit or $view) {
		my $statement = qq[
			SELECT 
	tblAssoc.intQRStatsTemplateID,
	tblAssoc.intHideClubRollover,
	tblAssoc.intCurrentSeasonID,
	tblAssoc.intNewRegoSeasonID,
	tblAssoc.intAssocID, 
        
	tblAssoc.strName, 
        intDataAccess, 
        strUsername, 
        strPassword, 
        strRealmName, 
        tblAssoc.strCountry, 
				tblAssoc.strState,
        intAssocTypeID, 
        intDefaultRegoProductID, 
        strFirstSyncCode, 
        PP.curAmount, 
        tblRealmSubTypes.strSubTypeName, 
        intAllowPayment, 
        intAllowRegoForm,
			  CSCFG.intLiveStatsUserID,
			  CSCFG.strStadiumScoringKey,
			  tblAssoc.intPaymentConfigID,
				IF(PC.intGatewayType=1, 'Credit Card- ', IF(intGatewayType=2, 'PayPal- ', 'NAB- ')) as PaymentConfigType,
 				IF(RS.intSubTypeID, RS.strSubTypeName, '') as PaymentConfigRealm,			
	IF(PC.intRealmSubTypeID=1, 'Credit Card- ', IF(intGatewayType=2, 'PayPal- ', 'NAB- ')) as PaymentConfigType,
			  PC.intLevelID,
        intApproveClubPayment,
        intHideRegoFormNew,     
        intAssocFeeAllocationType,
        intAllowAutoDuplRes,
        intHideRollover,
			  intAllowFullTribunal,
			  intAllowClearances,
			  intUploadType,
			  intUploadUmpires,
        intNoPMSEmail,
        intCCAssocOnClubPayments,
        strSWWUsername,
        strSWWPassword,
        intSWWAssocID,
        intExcludeFromNationalRego,
        intSWOL_SportID,
		    strPaymentEmail,
        strExtKey
			FROM 
        tblAssoc
	 
        LEFT JOIN tblAuth ON (tblAuth.intID=tblAssoc.intAssocID AND tblAuth.intLevel=$Defs::LEVEL_ASSOC)
				LEFT JOIN tblPaymentApplication as PA ON (PA.intEntityID = tblAssoc.intAssocID AND PA.intEntityTypeID=5)
				LEFT JOIN tblProductPricing as PP ON (PP.intProductID = intDefaultRegoProductID and PP.intID = tblAssoc.intAssocID and PP.intLevel=5)
				LEFT JOIN tblRealms ON (tblAssoc.intRealmID = tblRealms.intRealmID)
				LEFT JOIN tblRealmSubTypes ON (tblAssoc.intAssocTypeID= tblRealmSubTypes.intSubTypeID)
				LEFT JOIN tblCourtsideConfig AS CSCFG ON CSCFG.intAssocID = tblAssoc.intAssocID
				LEFT JOIN tblPaymentConfig as PC ON (tblAssoc.intPaymentConfigID = PC.intPaymentConfigID)
				LEFT JOIN tblRealmSubTypes as RS ON (RS.intSubTypeID = PC.intRealmSubTypeID)
		WHERE 
        tblAssoc.intAssocID = $intAssocID
			ORDER BY 
        PA.intPaymentType DESC
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
		$dref->{'strPaymentConfig'} = $dref->{'PaymentConfigType'} . "- " . $Defs::LevelNames{$dref->{intLevelID}} . " level setup ".$dref->{'PaymentConfigRealm'};
	}
	elsif ($add) {
		my @fieldnames=qw( intAssocID strName strUsername intDefaultRegoProductID intAssocTypeID intAllowPayment intAllowRegoForm intAllowFullTribunal intAllowClearances intUploadType intApproveClubPayment intHideRegoFormNew intAllowAutoDuplRes intAssocFeeAllocationType intHideRollover intNoPMSEmail intCCAssocOnClubPayments intUploadUmpires strExtKey strCountry strState);
		for my $i (@fieldnames)	{ $dref->{$i}=''; }
		my @fieldnames_int=qw( intDefaultRegoProductID intAssocTypeID intAllowPayment intAllowRegoForm intAllowFullTribunal intAllowClearances intUploadType intApproveClubPayment intHideRegoFormNew intAllowAutoDuplRes intAssocFeeAllocationType intHideRollover intNoPMSEmail intCCAssocOnClubPayments intUploadUmpires);
		for my $i (@fieldnames_int)	{ $dref->{$i}=0; }

		my $st= "
			SELECT strRealmName
			FROM tblRealms
			WHERE intRealmID = ?
	  ";
	  my $query = $db->prepare($st);
	  $query->execute($realmID);
		($fields{'intRealmID'}) = $query->fetchrow_array();
		$query->finish();
		$fields{'intRealmID'} ||= '';
	}

	my %YesNo=(0 => 'No', 1 => 'Yes', 2 => 'Yes');
	{ #Sub Realms
		my $st= "
			SELECT intSubTypeID, strSubTypeName
			FROM tblRealmSubTypes
			WHERE intRealmID = $realmID
			ORDER BY strSubTypeName 
		";
		$fields{'intAssocTypeID'}=( $add) 
				? getDBdrop_down('DB_intAssocTypeID',$db,$st,$dref->{'intAssocTypeID'},'&nbsp;') 
				: $dref->{'strSubTypeName'};
	}
	{ #PAYMENT CONFIG
		my $st= "
			SELECT DISTINCT PC.intPaymentConfigID, CONCAT(IF(intGatewayType=1, 'Credit Card- ', IF(intGatewayType=2, 'PayPal- ', 'NAB- ')), IF(intLevelID=100, 'National', IF(intLevelID=5, 'Association', '')) , ' level setup ',  IF(RS.intSubTypeID, RS.strSubTypeName, ''), ' -CURRENCY:', PC.strCurrency) as PaymentConfig
			FROM tblPaymentConfig as PC
				LEFT JOIN tblTempNodeStructure as TNS ON (
					TNS.intAssocID = $intAssocID
				)
				LEFT JOIN tblRealmSubTypes as RS ON (RS.intSubTypeID = PC.intRealmSubTypeID)
			WHERE PC.intRealmID = $realmID
				AND PC.intRealmSubTypeID IN (0, $dref->{intAssocTypeID})
				AND (
					(PC.intLevelID=5 AND PC.intEntityID = $intAssocID)
					OR
					(PC.intLevelID=100 AND PC.intEntityID = int100_ID)
				)
		";
		$fields{'intPaymentConfigID'}=($edit) 
				? getDBdrop_down('DB_intPaymentConfigID',$db,$st,$dref->{'intPaymentConfigID'},'&nbsp;') 
				: $dref->{'strPaymentConfig'};
	}

	my $clear = $dref->{'strPaymentEmail'} ? qq[ <a href="$target?action=CLEAR_dollar&amp;intEntityID=$intAssocID&amp;intEntityTypeID=5">Clear Address</a>] : '';

	$fields{'strCountry'} = $dref->{'strCountry'} || param('DB_strCountry') || '';
	$fields{'strState'} = $dref->{'strState'} || param('DB_strState') || '';
	$fields{'strName'}=genTextBox('DB_strName',$dref->{strName},60,$add,$edit).'<a target="new_window" href="'.$Defs::base_url.'/authenticate.cgi?i='.$dref->{'intAssocID'}.'&amp;t='.$Defs::LEVEL_ASSOC.'">LOGIN</a>';
	$fields{'strUsername'}=genTextBox('DB_strUsername',$dref->{strUsername},40,$add,$edit);
	#$fields{'intAssocTypeID'}=genTextBox('DB_intAssocTypeID',$dref->{intAssocTypeID},40,$add,$edit);
	$fields{'intDefaultRegoProductID'}=genTextBox('DB_intDefaultRegoProductID',$dref->{intDefaultRegoProductID},40,$add,$edit);
	$fields{'intAllowPayment'}=genDropDown('DB_intAllowPayment',$dref->{intAllowPayment},$add,$edit);
	$fields{'intAllowAutoDuplRes'}=genDropDown('DB_intAllowAutoDuplRes',$dref->{intAllowAutoDuplRes},$add,$edit);
	$fields{'intAssocFeeAllocationType'}=genDropDown('DB_intAssocFeeAllocationType',$dref->{intAssocFeeAllocationType},$add,$edit,(''=>'',1=>'Inclusive',2=>'User Pays'));
	$fields{'intHideRollover'}=genDropDown('DB_intHideRollover',$dref->{intHideRollover},$add,$edit);
	$fields{'intNoPMSEmail'}=genDropDown('DB_intNoPMSEmail',$dref->{intNoPMSEmail},$add,$edit);
	$fields{'intCCAssocOnClubPayments'}=genDropDown('DB_intCCAssocOnClubPayments',$dref->{intCCAssocOnClubPayments},$add,$edit,0=>'Hide Emails',1=>'Send as Normal');
	$fields{'intApproveClubPayment'}=genDropDown('DB_intApproveClubPayment',$dref->{intApproveClubPayment},$add,$edit);
	$fields{'intAllowRegoForm'}=genDropDown('DB_intAllowRegoForm',$dref->{intAllowRegoForm},$add,$edit, (0=>'No',1=>'Yes',2=>'Disable Add / Forms On'));
	$fields{'intHideRegoFormNew'}=genDropDown('DB_intHideRegoFormNew',$dref->{intHideRegoFormNew},$add,$edit,(0=>,'No'=>1,'New'=> 2=>'New code',3=>'Both'));
	$fields{'intAllowFullTribunal'}=genDropDown('DB_intAllowFullTribunal',$dref->{intAllowFullTribunal},$add,$edit)."(NEEDS TO BE ON FOR SPORT)";
	$fields{'intAllowClearances'}=genDropDown('DB_intAllowClearances',$dref->{intAllowClearances},$add,$edit)."(NEEDS TO BE ON FOR SPORT)";
	$fields{'intUploadType'}=genDropDown('DB_intUploadType',$dref->{intUploadType},$add,$edit);
	$fields{'intUploadUmpires'}=genDropDown('DB_intUploadUmpires',$dref->{intUploadUmpires},$add,$edit);
	$fields{'curAmount'}=genTextBox('DB_curAmount',$dref->{curAmount},20,$add,$edit);
	$fields{'strPassword'}=$dref->{strPassword}||'';
	$fields{'strFirstSyncCode'}=$dref->{strFirstSyncCode}||'';
	$fields{'strPaymentConfig'}=$dref->{strPaymentConfig}||'';
	$fields{'intAllowPayment'}=' (payments cannot be on until Payment gateway configured)' if ! $dref->{'intPaymentConfigID'};
	$fields{'strPaymentConfig'}='-' if ! $dref->{'intPaymentConfigID'};
	$fields{'strPaymentEmail'}=$dref->{'strPaymentEmail'} . qq[ $clear];
	$fields{'strEmail'}=genTextBox('DB_strEmail',$dref->{strEmail},60,$add,$edit);
	$fields{'intLiveStatsUserID'}=genTextBox('DBLS_intLiveStatsUserID',$dref->{intLiveStatsUserID},10,$add,$edit);
	$fields{'strStadiumScoringKey'}=genTextBox('DBLS_strStadiumScoringKey',$dref->{strStadiumScoringKey},10,$add,$edit);
	$fields{'intQRStatsTemplateID'}=genTextBox('DB_intQRStatsTemplateID',$dref->{intQRStatsTemplateID},10,$add,$edit);
	$fields{'intAssocID'}=$dref->{intAssocID} ||'New';
	$fields{'strSWWUsername'}=genTextBox('DB_strSWWUsername',$dref->{strSWWUsername},40,$add,$edit);
	$fields{'strSWWPassword'}=genTextBox('DB_strSWWPassword',$dref->{strSWWPassword},40,$add,$edit);
	$fields{'intSWWAssocID'}=genTextBox('DB_intSWWAssocID',$dref->{intSWWAssocID},40,$add,$edit);
	$fields{'intExcludeFromNationalRego'}=genDropDown('DB_intExcludeFromNationalRego',$dref->{intExcludeFromNationalRego},$add,$edit, (0=>'No',1=>'Yes'));
	$fields{'intSWOL_SportID'}=genDropDown('DB_intSWOL_SportID',$dref->{intSWOL_SportID},$add,$edit,(''=>'', $Defs::SPORT_HOCKEY=>"Hockey", $Defs::SPORT_FOOTBALL=>"AFL", $Defs::SPORT_LACROSSE=>"Lacrosse", $Defs::SPORT_SOCCER=>"Soccer", $Defs::SPORT_NETBALL=>"Netball", $Defs::SPORT_BASKETBALL=>"Basketball", $Defs::SPORT_LEAGUE=>"Rugby League", 9=>"Generic", $Defs::SPORT_TOUCH_FOOTBALL=>"Touch", $Defs::SPORT_WATER_POLO=>"Water Polo", $Defs::SPORT_LAWN_BOWLS=>"Lawn Bowls", $Defs::SPORT_BASEBALL=>'Baseball',$Defs::SPORT_VOLLEYBALL=>'Volleyball', $Defs::SPORT_UNION=>'Rugby Union'));
	$fields{'strExtKey'}=genTextBox('DB_strExtKey',$dref->{strExtKey},40,$add,$edit);
	
my $seasonsSQL = qq[SELECT intSeasonID, strSeasonName, DATE_FORMAT(dtAdded, '%d/%m/%Y') AS dtAdded, intAssocID
                FROM tblSeasons
                WHERE intRealmID = $realmID
                        AND (intAssocID=$intAssocID OR intAssocID =0)
                        AND (intRealmSubTypeID=$dref->{'intAssocTypeID'} OR intRealmSubTypeID =0)
                        AND intArchiveSeason<>1
                ORDER BY intSeasonOrder, strSeasonName];
	$fields{'intCurrentSeasonID'}=genSeasonsDropDown('DB_intCurrentSeasonID',$dref->{intCurrentSeasonID},$add,$edit,$db,$seasonsSQL);
	$fields{'intNewRegoSeasonID'}=genSeasonsDropDown('DB_intNewRegoSeasonID',$dref->{intNewRegoSeasonID},$add,$edit,$db, $seasonsSQL);

	$fields{'intHideClubRollover'}=genDropDown('DB_intHideClubRollover',$dref->{intHideClubRollover},$add,$edit);

			my $menu='';
	if($view)	{
		$menu= qq[
			<a href="$target?action=ASSOC_edit&amp;intAssocID=$intAssocID"><img src="images/edit.gif" alt="Edit" title="Edit" width="40" height="40" border="0"></a> 
		];
	}

  my @display_fields=(
    ['intAssocID'],
    ['intRealmID'],
		['strCountry'],
		['strState'],
    ['strName'],
    ['intAssocTypeID'],


    ['intLiveStatsUserID'],
    ['strStadiumScoringKey'],
    ['intQRStatsTemplateID'],
	['intAllowAutoDuplRes'],
    ['intAllowFullTribunal'], 
    ['intAllowClearances'], 
    ['intHideRollover'], 
	['intUploadUmpires'],
	['intHideClubRollover'],

    ['strUsername'], 
	  ['strPassword'],
	  ['strFirstSyncCode'],
    ['intUploadType'], 
 ['strSWWUsername'], 
	  ['strSWWPassword'],
	  ['intSWWAssocID'],
	  ['intSWOL_SportID'],
	  ['strExtKey'],


    ['intAllowPayment'], 
    ['intPaymentConfigID'], 
    ['strPaymentEmail'], 
    ['strPaymentConfig'], 
    ['intDefaultRegoProductID'], 
    ['curAmount'], 
    ['intAllowRegoForm'], 
    ['intHideRegoFormNew'],
    ['intExcludeFromNationalRego'],
    ['intApproveClubPayment'],
    ['intAssocFeeAllocationType'],
    ['intNoPMSEmail'], 
    ['intCCAssocOnClubPayments'], 
 


 
 );

#if(check_access('','levelonly')>=90)
{
push(@display_fields,['intCurrentSeasonID']);
push(@display_fields,['intNewRegoSeasonID']);
}
#group is first field name
 my %groups=(
	"intAssocID"=>'Basic Info',
	'intAllowPayment'=>'Rego &amp; Payments',
	'strUsername'=>'SWW / Login Info',
	'intCurrentSeasonID'=>'Season Info',
	'intLiveStatsUserID'=>'Configs'); 
  my %labels=(
    intAssocID=>'Association ID',
    strUsername=>'Auth User',aPass=>'Auth Pass',
    strPassword=>'Association ID',
    strName=>'Association Name',
    strEmail=>'Email Address',
    strUsername=>'Username',
    intHideClubRollover=>'Turn off Member level re-reg bar for Club level and below',
    intDefaultRegoProductID=>'Default Rego ProductID',
    curAmount=>'Default Rego Product $$',
    strFirstSyncCode=>'First Sync Code',
    intAssocTypeID =>'Sub Realm',
    strPassword=>'Password',
    intRealmID=>'Realm',
    strCountry=>'Country',
    strState=>'State',
    intAllowRegoForm=>'Turn Rego Form ON',
    intHideRegoFormNew=>'Hide Rego Form New',
    intExcludeFromNationalRego=>'Exclude from National Registration',
    intAllowFullTribunal=>'Turn Tribunal ON',
    intAllowClearances=>'Turn Clearances ON',
    intUploadType=>'Use Sync Upload Type',
    intAllowPayment=>'Turn PAYMENTS ON',
    intApproveClubPayment=>'Approve ALL Clubs for PAYMENTS ON',
    intUploadUmpires=>'Allow Uploading of Umpires to Website',
    intPaymentConfigID=>'Payment Gateway Config',
    strPaymentEmail=>'Payment Email',
    intLiveStatsUserID =>'LiveStats User ID',
    strStadiumScoringKey =>'Stadium Scoring Key',
    intQRStatsTemplateID=>'QR Stats TemplateID',
    intAllowAutoDuplRes=>'Turn Bulk Duplicate Resolution ON',
    intAssocFeeAllocationType=>'Assoc Fee Allocation Type',
    intHideRollover=>'Hide Rollover icon for entire Assoc',
    intNoPMSEmail=>'No PMS Emails for Assoc',
    intCCAssocOnClubPayments=>'CC Assoc on Club Payment emails',
    strSWWUsername=>'SWW Username',
    strSWWPassword=>'SWW Password',
    intSWWAssocID=>'SWW Assoc ID',
    intSWOL_SportID=>'SWOL Sport',
    strExtKey=>'External Key',
    intCurrentSeasonID=>'CurrentSeasonID',	
    intNewRegoSeasonID=>'NewRegoSeasonID',
    #strPaymentConfig=>'Payment Config',
    #intAllowPayment=>'Turn Payments ON (1=yes, 0=no)',
);
  my %span=();
	my $body = qq[
	<form action="$target" method=post>
	<table width='100%'>
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
	if($intAssocID || (!$intAssocID and $display_fields[$i][$j] ne 'intNewRegoSeasonID' and $display_fields[$i][$j] ne 'intCurrentSeasonID'))	
	{	
			if( defined $groups{$display_fields[$i][$j]} and ($groups{$display_fields[$i][$j]} ne '')){$subBody .="</table> <table  align='center' style='width:590px;float:left;margin-right:40px;margin-left:40px;margin-top:20px;'><tr><td colspan=2 align='center'><h2>".$groups{$display_fields[$i][$j]}."</h2></td></tr><tr>";}
			$subBody.=qq[<tr>
					<td class="formbg fieldlabel">$label:</td>
					<td class="formbg" colspan="$span">$value</td>
			</tr>];
    }}
    if($found)  { $body.=qq[ $subBody ]; }
  }

 my $st = qq[
    SELECT
      ULC.*,
      C.intClubID,
      C.strName AS strAssocName,
      AC.strTitle AS strCompName
    FROM
      tblUmpireLevelConfig AS ULC
      INNER JOIN tblClub AS C ON (C.intClubID = ULC.intUmpireEntityID)
      LEFT JOIN tblAssoc_Comp AS AC ON (AC.intCompID = ULC.intComp_CompID)
    WHERE
    intComp_AssocID = ?
    ORDER BY
      C.strName
  ];
  my $q = $db->prepare($st);
  $q->execute($intAssocID);
  my $umpire_config = '';
  while (my $dref = $q->fetchrow_hashref()) {
    $dref->{'strCompName'} ||= qq[All Competitions];
    $umpire_config .= qq[$dref->{'strAssocName'} [$dref->{'intClubID'}] ($dref->{'strCompName'})  <br>];
  }
  $umpire_config ||= 'None';

  my $hash_value = AdminCommon::create_hash(0,0,$intAssocID,0,0);
  $body .= qq[
    </table><br />
    <table  align='center' style='width:590px;float:left;margin-right:40px;margin-left:40px;margin-top:20px;'><tr><td><h2>Umpire Configurations</h2>$umpire_config</td></tr></table>
    <input type="hidden" name="action" value="ASSOC_update">
    <input type="hidden" name="oldaction" value="$action">
		<input type="hidden" name="intAssocID" value="$intAssocID">
		<input type="hidden" name="DB_intRealmID" value="$realmID">
		<input type="hidden" name="DB_strCountry" value="$fields{'strCountry'}">
		<input type="hidden" name="DB_strState" value="$fields{'strState'}">
		<input type="hidden" name="hash" value="$hash_value">
	];

 #<a href="index.cgi?action=ASSOC_newlogin&intAssocID=$intAssocID">[Add Additional Login]</a><br>
  if(!$view)  {
    $body .= qq[
      <tr>
        <td class="formbg" colspan="4" align="center"><br>
          <input type=submit value="Update Association">
        </td>
      </tr>
    ];
  }

  $body .= qq[
  </form>
  ];
	return ($body,$menu);
}


sub update_assoc {
	my ($db, $action, $intAssocID, $target) = @_;

	my $cache=new MCache();
	$cache->delete('swm',"AssocObj-$intAssocID") if $cache;



  my %CompulsoryValues=(
      strName => "Association Name",
  );

	{
		my $st = qq[
    	    SELECT
    	        A.intAssocID,
    	        PC.intPaymentSplitRuleID,
    	        COUNT(intSplitID) as NumSplits
    	    FROM
    	        tblAssoc as A
    	        INNER JOIN tblPaymentConfig as PC ON (
    	            PC.intPaymentConfigID=A.intPaymentConfigID
    	        )
    	        LEFT JOIN tblPaymentSplit as PS ON (
    	            PS.intEntityID=A.intAssocID
    	            AND PS.intEntityTypeID=5
    	        )
    	    WHERE
    	        A.intAssocID = $intAssocID
    	    GROUP BY
    	        A.intAssocID
    	];
    	my $q = $db->prepare($st);
    	$q->execute();
    	while (my $dref = $q->fetchrow_hashref())   {
    	    next if ($dref->{NumSplits} > 0);
    	    createSplits($db, $dref->{intAssocID}, $dref->{intPaymentSplitRuleID}, 3);
    	    createSplits($db, $dref->{intAssocID}, $dref->{intPaymentSplitRuleID}, 5);
    	}
	}
	my $output=new CGI;
  #Get Parameters
  my %fields = $output->Vars;
my %TempFields=();
	#Get rid of non DB fields
	my $livestatsuserID = $fields{'DBLS_intLiveStatsUserID'};
	my $stadiumScoringKey = $fields{'DBLS_strStadiumScoringKey'};

	for my $key (keys %fields)	{
		if($key!~/^DB_/)	{delete $fields{$key};}
	}
	%TempFields=%fields;
	deQuote($db, \%fields);
	{
		my($valid,$msg)=checkusername($db,$fields{'DB_strUsername'},$intAssocID||0);
		$CompulsoryValues{'username'}=$msg if !$valid;
	}
	my $AssocName=$fields{'DB_strName'} || '';
	my($valuelist,$fieldlist)='';
	my $error='';
	if(!$intAssocID)	{
		$ENV{PATH}='';
		my $seconds = gettimeofday();
		my $ms      = int($seconds*1000); 
		my $timeGenPass = substr($ms,-8);
		$fields{'DB_strPassword'} = $timeGenPass;
		
		# old way for generating password 
		
		#$fields{'DB_strPassword'}=`$Defs::fs_base/misc/passwdgen -a1q`;
		$CompulsoryValues{'password'}='Problem Generating Password' if !$fields{'DB_strPassword'};
	}
	for my $key (keys %fields)	{
		next if($key eq 'DB_strUsername' or $key eq 'DB_strPassword' or $key eq 'DB_curAmount') ;
		my $newkey=$key;
		$newkey=~s/DB_//g;
    if($newkey=~/^str/ and $fields{$key}!~/^'.*'$/) {$fields{$key}="'$fields{$key}'";}
  	if($newkey=~/^dt/ and $fields{$key} ne "''")  {
      my $newdate='';
      if($error)  { next; }
      else  {$fields{$key}="'$newdate'";}
    }
    if($newkey=~/^int/ and !$fields{$key})  {$fields{$key}=0;}
    if($newkey=~/^cur/ and !$fields{$key})  {$fields{$key}=0;}
	 if(exists $CompulsoryValues{$newkey} and (defined $fields{$key} and $fields{$key} ne "" and $fields{$key} ne "''")) {
      delete $CompulsoryValues{$newkey};
    }

		if($intAssocID)	{
			#Update
			if(defined $valuelist and $valuelist ne "")	{$valuelist.=', ';}
			$valuelist.=qq[$newkey=$fields{$key}];
		}
		else	{
			#Insert
			if(defined $valuelist and $valuelist ne "")	{$valuelist.=', ';}
			if($fieldlist)	{$fieldlist.=', ';}
			$valuelist.=qq[$fields{$key}];
			$fieldlist.=qq[$newkey];
		}
	}
	
	# Time do update some courtside stuff

	# Livestats ID
	_update_courtside({
        'db' => $db,
        'assocID' => $intAssocID,
        'value' =>  $livestatsuserID,
        'field' => 'intLiveStatsUserID',
    });
    
    # Stadium Scoring Key
    _update_courtside({
        'db' => $db,
        'assocID' => $intAssocID,
        'value' =>  $stadiumScoringKey,
        'field' => 'strStadiumScoringKey',
    });
	

  my $missing_fields=join("<br>\n",values %CompulsoryValues);
  if($missing_fields) {
    my $return_string='';
    if($missing_fields) {
      $return_string.=qq[
      <p>Error: Missing Information!</p>
      <p>The following fields need to be filled in</p>
      <p>$missing_fields</p>
      ];
    }
    $return_string.=qq[<br>
      <p>Click your browser's 'back' button to return to the previous page</p><br>
    ];
    return ($return_string,'');
  }
	#'

	my $statement='';
	my $add=0;
	if($intAssocID)	{
		$statement=qq[
			UPDATE tblAssoc SET $valuelist
			WHERE intAssocID=$intAssocID
		];
	}
	else	{
		$add=1;
#		my $intAllowRegoForm=1;
		if ($fields{DB_intRealmID} == 2)	{
		#	$fieldlist .= qq[,intAllowClearances];
		#	$valuelist .= qq[,0];
		}
		if ($fields{DB_intRealmID} == 3)	{
		}
		my $seasons = qq[
			SELECT strOption, strValue
			FROM tblSystemConfig
			WHERE intRealmID =$fields{DB_intRealmID}
				AND (intSubTypeID = 0 or intSubTypeID =  $fields{DB_intAssocTypeID})
				AND strOption IN ('Seasons_defaultCurrentSeason', 'Seasons_defaultNewRegoSeason')
			ORDER BY intSubTypeID DESC
		];
		my $query = $db->prepare($seasons) or query_error($seasons);
		$query->execute() or query_error($seasons);
		my $currentSeasonID = 0;
		my $newRegoSeasonID = 0;
		if($currentSeasonID==0 and $newRegoSeasonID==0) {
			while (my $dref = $query->fetchrow_hashref())	{
				$currentSeasonID = $dref->{strValue} if (! $currentSeasonID and $dref->{strOption} eq 'Seasons_defaultCurrentSeason');
				$newRegoSeasonID = $dref->{strValue} if (! $newRegoSeasonID and $dref->{strOption} eq 'Seasons_defaultNewRegoSeason');
			}
		}
		my $allowSeasons = 1; #$fields{DB_intAssocTypeID} == 2 ? 1 : 0;
		$statement=qq[
 			INSERT INTO tblAssoc (intCurrentSeasonID, intNewRegoSeasonID, intAllowSeasons, $fieldlist)
                        VALUES ($currentSeasonID, $newRegoSeasonID, $allowSeasons, $valuelist)
#			INSERT INTO tblAssoc (intAllowSeasons, $fieldlist)
#			VALUES ($allowSeasons, $valuelist)
		];
	}
	if($add)	{
		#Check to see if the Assoc already exists
		my $checkstatement=qq[
			SELECT intAssocID
			FROM tblAssoc 
			WHERE strName=$AssocName
		];
		my $query = $db->prepare($checkstatement) or query_error($checkstatement);
		$query->execute() or query_error($checkstatement);
		my($existingID)=$query->fetchrow();
		if($existingID)	{
			return (qq[
      <p>Error: Duplicate!</p>
			<p>This association already exists as association $existingID</p>
			],'');
		}
	}
 
	my $query = $db->prepare($statement) or query_error($statement);
	$query->execute() or query_error($statement);
	if(!$intAssocID)	{$intAssocID=$query->{mysql_insertid};}
	if($add)	{
		my $st=qq[
			INSERT INTO tblAuth (strUsername, strPassword, intAssocID, intLevel, intID)
			VALUES ($fields{'DB_strUsername'}, '$fields{'DB_strPassword'}', $intAssocID, 5, $intAssocID)
		];
		$db->do($st);
	}
	else	{
		my $st=qq[
      UPDATE tblAuth SET strUsername=$fields{'DB_strUsername'}
			WHERE intAssocID=$intAssocID
        AND intLevel=5
		];
		$db->do($st);
	}

	my $st = qq[
	DELETE FROM
	tblProductPricing
	WHERE intID = $intAssocID
		AND intLevel=5 
		AND intProductID=$fields{'DB_intDefaultRegoProductID'}
	];
	$db->do($st);

	$st = qq[
		SELECT intProductPricingID 
		FROM tblProductPricing 
		WHERE intLevel=5
			 AND intProductID = $fields{'DB_intDefaultRegoProductID'} 
			 AND intID = $intAssocID
	];
	
	$query = $db->prepare($st) or query_error($st);
	$query->execute() or query_error($st);
	my $intProductPricingID = $query->fetchrow_array() || 0;

	$st = qq[
		SELECT intRealmID
		FROM tblAssoc
		WHERE intAssocID = $intAssocID
	];
	
	$query = $db->prepare($st) or query_error($st);
	$query->execute() or query_error($st);
	my $intRealmID= $query->fetchrow_array() || 0;
print STDERR "HERE: $intProductPricingID | $fields{'DB_intDefaultRegoProductID'}| $fields{'DB_curAmount'}\n";
	if ($intProductPricingID)	{
		$st = qq[
			UPDATE tblProductPricing 
			SET curAmount = $fields{'DB_curAmount'}
			WHERE intProductPricingID = $intProductPricingID
		];
		$db->do($st);
        updateProductTXNPricing($db, $intAssocID, $fields{'DB_intDefaultRegoProductID'}, $fields{'DB_curAmount'}) if ($TempFields{'DB_curAmount'} > 0);
	}
	elsif (! $intProductPricingID and $fields{'DB_intDefaultRegoProductID'} and $TempFields{'DB_curAmount'} > 0 )	{
		$st = qq[
			INSERT INTO tblProductPricing
			(intID, intLevel, intRealmID, intProductID, curAmount)
			VALUES ($intAssocID, 5, $intRealmID, $fields{'DB_intDefaultRegoProductID'}, $fields{'DB_curAmount'})
		];	
print STDERR $st;
		$db->do($st);
        updateProductTXNPricing($db, $intAssocID, $fields{'DB_intDefaultRegoProductID'}, $TempFields{'DB_curAmount'}) if ($TempFields{'DB_curAmount'} > 0);
	}
	return assoc_details($db, 'ASSOC_view', $intAssocID, $target); 
}


sub genTextBox	{
	my($name, $value, $length, $add, $edit)=@_;
	$length||='';
	$value||='';
	
  my $retVal=($edit or $add) ? qq[<input type="text" name="$name" value="$value" size="$length">] : $value;
	return $retVal;
}


sub genDropDown {
        my($name, $selected,$add,$edit,%additionalFields)=@_;
	if(keys %additionalFields==0)
	{
 		for (keys %additionalFields)
    		{
        		delete $additionalFields{$_};
    		}     
		$additionalFields{0} = 'No';
		$additionalFields{1} = 'Yes';
	}
	$selected||='';
	
	my $retVal= qq[<select name="$name">];

	foreach my $key (sort keys %additionalFields) {
    	my $checked = ($key eq $selected) ? qq[selected='selected'] : '';
    		$retVal .= qq[<option $checked value='$key'>$additionalFields{$key}</option>\n];
	}
	$retVal .='</select>';
print STDERR $edit.$add;
	if($edit==0 and $add==0) {$retVal =  $additionalFields{$selected};}
        return $retVal;
}
sub genSeasonsDropDown {
        my($name, $selected,$add,$edit,$db, $sql)=@_;
        $selected||='';
        my $st= qq[$sql];
my $query = $db->prepare($st);
        my %additionalFields = ();
        $query->execute();
        my $retVal= qq[<select name="$name">];
        while(my $dref= $query->fetchrow_hashref()) {
                foreach my $key (keys %{$dref}) { if(!defined $dref->{$key})  {$dref->{$key}='';} }
 	        my $checked = ($dref->{intSeasonID} eq $selected) ? qq[selected='selected'] : '';
                $retVal .= qq[<option $checked value="$dref->{intSeasonID}">$dref->{strSeasonName}</option>\n];
        }
        $retVal .='</select>';
	return $retVal;
}


sub displaySportSelect	{
	my($target)=@_;
	
	my $body=qq[
  <form action="$target" method="post">
		<div style="text-align:center">
    <input type="submit" name="submit" value="S U B M I T">
    <input type=hidden name="action" value="ASSOC_add">
		</div>
  </form><br>
	];
	return $body;
}


sub list_assoc	{
  my ($db, $action, $intAssocID, $target) = @_;

  my $assoc_name_IN  = param('assoc_name')  || '';
  my $assoc_fsc_IN   = param('assoc_fsc')   || '';
  my $assoc_email_IN = param('assoc_email') || '';
  my $realm_IN       = param('realmID')     || '';
  my $subRealm_IN    = param('subRealmID')  || '';
  my $assoc_un_IN    = param('assoc_un')    || '';
  my $assoc_id_IN    = param('assoc_id')    || '';
  my $assoc_swol_IN  = param("assoc_swol")  || "";
  my $inclDeleted    = param('inclDeleted') || '';

  if ($action eq 'ASSOC_list_IN') {
    $assoc_id_IN = $intAssocID;
    $action = 'ASSOC_list'; 
  }

  my $strWhere='';
  if ($assoc_name_IN) {
    $strWhere .= qq/ AND tblAssoc.strName LIKE '%$assoc_name_IN%' /;
  }
  if ($assoc_email_IN) {
    $strWhere .= qq/ AND tblAssoc.strEmail LIKE '%$assoc_email_IN%' /;
  }
  if ($assoc_fsc_IN) {
    #$strWhere .= "tblAssoc.strFirstSyncCode =  '".$assoc_fsc_IN."'";
    $strWhere .= qq/ AND tblAssoc.strFirstSyncCode LIKE '%$assoc_fsc_IN%' /;
  }
  if ($assoc_id_IN) {
    $strWhere .= qq/ AND tblAssoc.intAssocID = '$assoc_id_IN' /; 
  }
  if ($assoc_swol_IN) {
	my $assoc_swol_id=0;
	if($assoc_swol_IN ne 'No'){$assoc_swol_id=1;}
    $strWhere .= qq/ AND tblAssoc.intSWOL = '$assoc_swol_id' /;
  }
  if ($assoc_un_IN) {
    $strWhere .= qq/ AND tblAuth.strUsername= '$assoc_un_IN' /;
  }
  if ($subRealm_IN) {
    $strWhere .= qq/ AND tblAssoc.intAssocTypeID = '$subRealm_IN' /;
  }
  if ($realm_IN) {
    $strWhere .= qq/ AND tblAssoc.intRealmID = '$realm_IN' /;
  }
  if ($inclDeleted eq 'No') {
    $strWhere .= qq/ AND tblAssoc.intRecStatus <> -1 /;
  }
  $strWhere =~ s/^ AND //g if $strWhere;
  $strWhere = "WHERE $strWhere" if $strWhere;

print STDERR qq[AL : $Defs::LEVEL_ASSOC | $Defs::base_url \n\n];

  my $statement=qq[
		SELECT distinct tblNode.strName, strSubTypeName, tblAssoc.strName, tblAssoc.intAssocID, strRealmName, tblRealms.intRealmID, intRecStatus, intSWOL
    FROM 
      tblAssoc
      LEFT JOIN tblAuth ON (tblAuth.intAssocID=tblAssoc.intAssocID AND tblAuth.intLevel=$Defs::LEVEL_ASSOC)
			LEFT JOIN tblRealms ON (tblAssoc.intRealmID=tblRealms.intRealmID)
			LEFT JOIN tblRealmSubTypes ON (tblAssoc.intAssocTypeID = tblRealmSubTypes.intSubTypeID)
			LEFT JOIN tblTempNodeStructure ON (tblAssoc.intAssocID=tblTempNodeStructure.intAssocID)
			LEFT JOIN tblNode ON (tblTempNodeStructure.int100_ID=tblNode.intNodeID)
		$strWhere
		ORDER BY tblAssoc.strName
  ];
  my $query = $db->prepare($statement) or query_error($statement);
  $query->execute() or query_error($statement);
  my $count=0;
  my $body='';
  my $hash_value = '';
  while(my $dref= $query->fetchrow_hashref()) {
    foreach my $key (keys %{$dref}) { if(!defined $dref->{$key})  {$dref->{$key}='';} }
    $dref->{strName} = $dref->{strName} || '&nbsp;';
    $dref->{strEmail} = $dref->{strEmail} || '&nbsp;';
    $dref->{strUsername} = $dref->{strUsername} || '&nbsp;';
    $dref->{strPassword} = $dref->{strPassword} || '&nbsp;';
    $dref->{strRealmName} ||= '&nbsp;';
    $dref->{intReadOnly} || 0;
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
	my $readonly = ($dref->{'intReadOnly'}) ? 'RO' : '';
	my $loginlink = passportURL(
			{},
			{},
			'',
			"$Defs::base_url/authenticate.cgi?i=$dref->{intAssocID}&amp;t=$Defs::LEVEL_ASSOC",
		) ;
		
    $hash_value = AdminCommon::create_hash_qs(0,0,$dref->{intAssocID},0,0);
    $body.=qq[
      <tr>
        <td class="$classborder"><a $extralink href="$target?action=ASSOC_edit&amp;intAssocID=$dref->{intAssocID}&amp;hash=$hash_value">$dref->{strName}</a></td>
	      <td class="$classborder">$dref->{intAssocID}</td>
	      <td class="$classborder">$swol</td>
	      <td class="$classborder"><a target="new_window" href="$loginlink">$readonly LOGIN</a></td>
              <td class="$classborder">$dref->{strRealmName}</td>
    	      <td class="$classborder">$dref->{strSubTypeName}</td>
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
		 <table cellpadding="1" cellspacing="0" border="0" width="95%" align="center">
			<tr>
        <th style="text-align:left;">Name</th>
        <th style="text-align:left;">Assoc ID</th>
        <th style="text-align:left;">SWOL ?</th>
        <th style="text-align:left;">&nbsp;</th>
        <th style="text-align:left;">Realm</th>
	<th style="text-align:left;">SubRealm</th>
      </tr>

      $body
    </table><br>
    ];
  }

  return ($body,'');
}


sub list_uploads {
  my ($db, $action, $intAssocID, $target) = @_;
  my $body='';

  my $statement=qq[
		SELECT DATE_FORMAT(dtSync,"%a %d/%m/%Y - %H:%i") AS dtSyncFORMAT, strAppName, strAppVer, strStage, intReturnAcknowledged, intSyncID, intSyncNo
		FROM tblSync
		WHERE intAssocID=$intAssocID
		ORDER BY dtSync DESC
  ];

  my $query = $db->prepare($statement) or query_error($statement);
  $query->execute() or query_error($statement);
  my $count=0;
  while(my $dref= $query->fetchrow_hashref()) {
    my $class='';
    my $classborder='commentborder';
    if($count++%2==1) {
      $class=q[ class="commentshaded" ];
      $classborder="commentbordershaded";
    }
    foreach my $key (keys %{$dref}) { if(!$dref->{$key})  {$dref->{$key}='&nbsp;';} }
    $body.=qq[
      <tr>
        <td class="$classborder">$dref->{intSyncNo}</td>
        <td class="$classborder">$dref->{dtSyncFORMAT}</td>
        <td class="$classborder">$dref->{strAppName}</td>
        <td class="$classborder">$dref->{strAppVer}</td>
        <td class="$classborder">$dref->{strStage}</td>
        <td class="$classborder">$dref->{intReturnAcknowledged}</td>
      </tr>
    ];
  }
  if(!$body)  {
    $body.=qq[ <div class="warningmsg"><br> No Syncs were found<br><br></b></div> <br> ];
  }
  else  {
	my $hash_value = AdminCommon::create_hash(0,0,$intAssocID,0,0);
    $body=qq[
		<form action="$target" method="POST">
		<span class="fieldlabel" style="text-align:left">Remove SYNC history</span>
			<input type="hidden" name="action" value="ASSOC_CLR">
			<input type="hidden" name="hash" value="$hash_value">
			<div>
				Clear Password: <input type="text" name="clr_password" value="">
				<input type="hidden" name="intAssocID" value="$intAssocID">
				<input type="submit" value="Remove Sync History">
			</div>
		</form>
		 <table cellpadding="1" cellspacing="0" border="0" width="95%" align="center">
			<tr>
        <th style="text-align:left;">Sync Number</th>
        <th style="text-align:left;">Date/Time</th>
        <th style="text-align:left;">AppName</th>
        <th style="text-align:left;">AppVer</th>
        <th style="text-align:left;">Stage</th>
        <th style="text-align:left;">Ret Ack</th>
      </tr>

      $body
    </table><br>
    ];
  }

  return ($body,'');
}

sub checkusername	{
	my ($db,$username,$id)=@_;
	#Check that this password is valid and not already in use

	return (0,'Username cannot begin with a number') if $username=~/^'\d/;
	my $st=qq[ 
		SELECT intAuthID 
		FROM tblAuth 
		WHERE strUsername=?
			AND intLevel >= $Defs::LEVEL_ASSOC
			AND NOT (intLevel=$Defs::LEVEL_ASSOC AND intID=$id)
	];
	my $q=$db->prepare($st);
	$q->execute($username);
	my($found)=$q->fetchrow_array() || 0;
	$q->finish();
	if($found)	{
		return (0,'Username already in use');
	}
	return (1,'');
}

sub list_location {
  my ($db, $action, $intAssocID, $target, $realmID) = @_;
  my $body='';

  my $statement=qq[
		SELECT intNodeID, intTypeID, strName, intStatusID
		FROM tblNode
		WHERE tblNode.intRealmID=$realmID
		ORDER BY strName
  ];

  my $query = $db->prepare($statement) or query_error($statement);
  $query->execute() or query_error($statement);
  my $count=0;
	my %Nodes=();
	my @Zones=();
	my %Parents=();
  while(my $dref= $query->fetchrow_hashref()) {
		$Nodes{$dref->{'intNodeID'}}= [$dref->{'strName'},$dref->{'intStatusID'}];
		push @Zones, $dref->{'intNodeID'} if $dref->{'intTypeID'} == $Defs::LEVEL_ZONE;
	}

  $statement=qq[
		SELECT intParentNodeID, intChildNodeID
		FROM tblNodeLinks INNER JOIN tblNode ON (tblNodeLinks.intChildNodeID=tblNode.intNodeID AND tblNode.intRealmID=$realmID)
  ];
  $query = $db->prepare($statement) or query_error($statement);
  $query->execute() or query_error($statement);
	my %NodeParents=();
  while(my $dref= $query->fetchrow_hashref()) {
		$NodeParents{$dref->{'intChildNodeID'}}= $dref->{'intParentNodeID'};
	}

	#OK we now have the data lets process it
	my %ZoneData=();
	for my $zone (@Zones)	{
		if(!exists $Parents{$zone})	{
			getparentnode($zone,\%NodeParents,\%Nodes,\%Parents);
		}
		my $zname=" | $Nodes{$zone}[0] ";
		$zname = '' if $Nodes{$zone}[1] == $Defs::NODE_HIDE;
		$ZoneData{$zone}=	"$Parents{$zone}";
	}

	#Get Current
	my $st=qq[
		SELECT intNodeID 

		FROM tblAssoc_Node
		WHERE intAssocID=$intAssocID
			AND intPrimary=1
	];
  my $q= $db->prepare($st) or query_error($st);
  $q->execute() or query_error($st);
	my ($currentZone)=$q->fetchrow_array();
	$ZoneData{''}='';
	my $dropdown=drop_down('intZoneID',\%ZoneData,undef,$currentZone||0,1,0);
	my $hash_value = AdminCommon::create_hash(0,0,$intAssocID,0,0);

	$body=qq[
		<form action="$target" method="POST">
		<span class="fieldlabel" style="text-align:left">Choose Your Location </span> $dropdown
			<input type="hidden" name="action" value="ASSOC_lu">
			<input type="hidden" name="intAssocID" value="$intAssocID">
			<input type="hidden" name="hash" value="$hash_value">
<br><br>
			<input type="submit" value="Assign Location">
		</form>
	];

  return ($body,'');
}

sub getparentnode	{
	my($nodeID, $NodeLinks, $Nodes, $Parents)=@_;
	if(!exists $NodeLinks->{$nodeID})	{
		$Parents->{$nodeID}='';
		return '';
	}
	else	{
		getparentnode($NodeLinks->{$nodeID}, $NodeLinks, $Nodes, $Parents);
		my $n =$Nodes->{$nodeID}[1] == $Defs::NODE_HIDE ? '' :$Nodes->{$nodeID}[0];
		my $sep = ($Parents->{$NodeLinks->{$nodeID}}  and $n)?  ' | ' : '';
		$Parents->{$nodeID} = $Parents->{$NodeLinks->{$nodeID}} ." $sep $n";
	}
	return '';
}


sub update_loc	{
	my ($db,$intAssocID, $target)=@_;
    my $intNodeID= param('intZoneID') || '';

	return 'You must select a location ' if !$intNodeID;
	my $st=qq[DELETE FROM tblAssoc_Node WHERE intPrimary=1 AND intAssocID=$intAssocID];
	$db->do($st);

	$st=qq[INSERT INTO tblAssoc_Node  (intAssocID,intNodeID,intPrimary) VALUES ($intAssocID,$intNodeID,1)];
	$db->do($st);

	my $realmID = getAssocRealm($db, $intAssocID);
	my %Data=();
	$Data{'db'} = $db;
	createTempNodeStructure(\%Data, $realmID);

	my $cache = new MCache();
    my $group = "ES_".$Defs::LEVEL_ASSOC."_".$intAssocID;
    $cache->delgroup('swm', $group);

	return 'location updated';
}

sub getAssocRealm	{
	my ($db, $assocID)=@_;
	#Get Current
	my $st=qq[
		SELECT intRealmID
		FROM tblAssoc
		WHERE intAssocID=$assocID
	];
  my $q= $db->prepare($st) or query_error($st);
  $q->execute() or query_error($st);
	my ($realm)=$q->fetchrow_array();
	return $realm||0;
}


sub new_assoc	{
	my ($db, $target) = @_;

my $realmid = AdminCommon::get_realmid();

my $st = "";
if (undef == $realmid) {
	$st= "
		SELECT intRealmID, strRealmName
		FROM tblRealms
		ORDER BY strRealmName
	";
}
else {
	$st= "
		SELECT intRealmID, strRealmName
		FROM tblRealms
		WHERE intRealmID IN ($realmid)
		ORDER BY strRealmName
	";	
}
	my %fields=();
	$fields{'intRealmID'}=getDBdrop_down('DB_intRealmID',$db,$st,'','&nbsp;');

	my $menu='';
  my %span=();
	my @countries=getCountriesArray();
	my $countries = '';
	for my $c (@countries)  {
		$countries .= qq[<option value="$c">$c</option>];
	}

	my $state = qq[
		<select name="DB_strState">
			<option value="">--Select a State--</option>
			<option value="ACT">ACT</option>
			<option value="NSW">NSW</option>
			<option value="NT">NT</option>
			<option value="QLD">QLD</option>
			<option value="SA">SA</option>
			<option value="TAS">TAS</option>
			<option value="VIC">VIC</option>
			<option value="WA">WA</option>
			<option value="NATIONAL">NATIONAL</option>
			<option value=" ">Other</option>
		</select>
	];
	my $body = qq[
	<form action="$target" method=post>
		<table width="100%">
			<tr>
					<td class="formbg fieldlabel">Realm:</td>
					<td class="formbg">$fields{'intRealmID'}</td>
			</tr>
			<tr>
					<td class="formbg fieldlabel">Country:</td>
					<td class="formbg"><select name="DB_strCountry"><option value="">--Select a Country--</option>$countries</select></td>
			</tr>
			<tr>
					<td class="formbg fieldlabel">State:</td>
					<td class="formbg">$state</td>
			</tr>
      <tr>
        <td class="formbg" colspan="4" align="center"><br>
          <input type=submit value="Add Association"><br>
        </td>
			</tr>
    </table>
    <input type="hidden" name="action" value="ASSOC_add">
  </form>
  ];
	return ($body,$menu);
}


sub additional_assoc_login_form {
  my ($db, $assocID, $target, $action) = @_;
  my $intAuthID = param('intAuthID') || 0;
  my $st = qq[
    SELECT
      strName
    FROM
      tblAssoc
    WHERE
      intAssocID = ?
  ];
  my $q = $db->prepare($st);
  $q->execute($assocID);
  my ($assocName) = $q->fetchrow_array();
  my ($username, $password, $ro) = ('','','');
  if ($action eq "EDIT") {
    $st = qq[
      SELECT 
        strUsername,
        strPassword,
        intReadOnly
      FROM
        tblAuth
      WHERE
        intAuthID = ?
    ];
    my $q = $db->prepare($st);
    $q->execute($intAuthID);
    ($username, $password, $ro) = $q->fetchrow_array();
    $ro = 'SELECTED' if $ro == 1;
  }
  my $form_action = ($username and $action eq 'EDIT') ? 'ASSOC_modifylogin' : 'ASSOC_addnewlogin';
  my $form_button = ($username and $action eq 'EDIT') ? 'Update Login' : 'Add Login';
  my $body = qq[
    <form name="newlogin_form" action="$target" method="post">
    <table cellpadding="1" cellspacing="0" border="0" width="95%" align="center">
      <tr>
        <td class="formbg fieldlabel">Name</td>
        <td class="formbg"><input type="text" name="name" value="$assocName" readonly="true" size="50"></td>
      </tr>
      <tr>
        <td class="formbg fieldlabel">Username</td>
        <td class="formbg"><input type="text" name="username" value="$username" size="50"></td>
      </tr>
      <tr>
        <td class="formbg fieldlabel">Password</td>
        <td class="formbg"><input type="text" name="password" value="$password" size="50"></td>
      </tr
      <tr>
        <td class="formbg fieldlabel">Read Only</td>
        <td class="formbg"><select name="ro"><option value="0">No</option><option value="1" $ro>Yes</option></select></td>
      </tr
    </table>    
    <input type="hidden" name="action" value="$form_action">
    <input type="hidden" name="intAssocID" value="$assocID">
    <input type="hidden" name="intAuthID" value="$intAuthID">
    <input type="submit"  value="$form_button">
    </form>
  ];
  return ($body,'');
}

sub add_assoc_login {
  my ($db, $assocID, $target) = @_;
  my $username = param('username') || '';
  my $password = param('password') || '';
  my $ro = param('ro') || 0;
  my($valid,$msg) = checkusername($db,$username,$assocID||0);
  $msg = 'Password or Username is blank' unless ($password and $username);
  $msg = "ERROR :: Password is too short (min 6 chracters) !" unless (length($password) > 5);
  $msg = "ERROR :: Username is too short (min 6 chracters) !" unless (length($username) > 5);
  return ($msg,'') if ($msg);
  my $st = qq[
    INSERT INTO tblAuth (
      intLevel,
      intAssocID,
      intID,
      strUsername,
      strPassword,
      dtCreated,
      intReadOnly
    )
    VALUES (
      5,
      ?,
      ?,
      ?,
      ?,
      now(),
      ?
    )
  ];
  my $q = $db->prepare($st);
  $q->execute(
    $assocID,
    $assocID,
    $username,
    $password,
    $ro
  );
  return list_assoc($db, 'ASSOC_list_IN', $assocID, $target);
}

sub update_assoc_login {
  my ($db, $assocID, $target) = @_;
  my $username = param('username') || '';
  my $password = param('password') || '';
  my $ro = param('ro') || 0;
  my $authID = param('intAuthID') || 0;
  my($valid,$msg) = checkusername($db,$username,$assocID||0);
  $msg = 'Password or Username is blank' unless ($password and $username);
  $msg = 'No authID passed in' unless ($authID);
  $msg = "ERROR :: Password is too short (min 6 chracters) !" unless (length($password) > 5);
  $msg = "ERROR :: Username is too short (min 6 chracters) !" unless (length($username) > 5);
  return ($msg,'') if ($msg);
  my $st = qq[
    UPDATE 
      tblAuth
    SET
      strUsername = ?,
      strPassword = ?,
      intReadOnly = ?
    WHERE
      intAuthID = ?
    LIMIT 1
  ];
  my $q = $db->prepare($st);
  $q->execute(
    $username,
    $password,
    $ro,
    $authID
  );
  return list_assoc($db, 'ASSOC_list_IN', $assocID, $target);
}

sub createSplits    {
    my ($db, $assocID, $ruleID, $levelID) = @_;
    my $splitName='100 per cent to Club';
    $splitName='100 per cent to Association' if $levelID==5;
    my $st = qq[
        INSERT INTO tblPaymentSplit
            (
                intRuleID,
                intEntityTypeID,
                intEntityID,
                strSplitName
            )
        VALUES
            (
                ?,
                5,
                ?,
                ?
            )
    ];
    my $q = $db->prepare($st);
    $q->execute($ruleID, $assocID, $splitName);
    my $splitID=$q->{mysql_insertid};

    $st = qq[
        INSERT INTO tblPaymentSplitItem
            (
                intSplitID,
                intLevelID,
                intRemainder
            )
        VALUES
            (
                ?,
                ?,
                1
            )
    ];
    $q = $db->prepare($st);
    $q->execute($splitID, $levelID);
}

sub update_timestamps_form {
  my ($db, $assocID, $target) = @_;
  return qq[
    <form name="reset_tstamp_form" action="$target" method="post">
    <table cellpadding="1" cellspacing="0" border="0" width="50%" align="center">
      <tr>
        <td colspan="2" align="center" class="formbg">Select the modules for which you wish to reset the timestamps:</td>
      </tr>
      <tr><td class="formbg">&nbsp;</td></tr>
      <tr>
        <td class="formbg fieldlabel" width="50%">Venues</td>
        <td class="formbg"><input type="checkbox" name="chk_venue" value="1"></td>
      </tr>
      <tr>
        <td class="formbg fieldlabel">Comps</td>
        <td class="formbg"><input type="checkbox" name="chk_comp" value="1"></td>
      </tr>
      <tr>
        <td class="formbg fieldlabel">Matches in Current Season</td>
        <td class="formbg"><input type="checkbox" name="chk_curmatches" value="1"></td>
      </tr>
      <tr>
        <td class="formbg fieldlabel">Pools</td>
        <td class="formbg"><input type="checkbox" name="chk_pools" value="1"></td>
      </tr>
      <tr>
        <td class="formbg fieldlabel">Teams</td>
        <td class="formbg"><input type="checkbox" name="chk_team" value="1"></td>
      </tr>
      <tr>
        <td class="formbg fieldlabel">Match Actions (Play By Play)</td>
        <td class="formbg"><input type="checkbox" name="chk_actionlog" value="1"></td>
      </tr>
      <tr>
        <td class="formbg fieldlabel">Clubs</td>
        <td class="formbg"><input type="checkbox" name="chk_club" value="1"></td>
      </tr>
      <tr>
        <td class="formbg fieldlabel">Ladders</td>
        <td class="formbg"><input type="checkbox" name="chk_ladder" value="1"></td>
      </tr>
      <tr>
        <td class="formbg fieldlabel">Members</td>
        <td class="formbg"><input type="checkbox" name="chk_member" value="1"></td>
     </tr>
      <tr><td class="formbg">&nbsp;</td></tr>
      <tr>
        <td colspan="2" align="center" class="formbg">
          <input type="hidden" name="action" value="ASSOC_tstamp_reset">
          <input type="hidden" name="intAssocID" value="$assocID">
          <input type="submit"  value="Reset Timestamps">
        </td>
      </tr>
    </table>
    </form> 
  ]; 
}

sub update_timestamps {
  my ($db, $assocID, $target, $realmID) = @_;
  my $page = '';
  my $st = '';
  my $venue = param('chk_venue') || 0;
  if ($venue == 1) {
    $st = qq[
      UPDATE 
        tblDefVenue
      SET 
        tTimeStamp = now()
      WHERE 
        intAssocID = $assocID
    ];
    $db->do($st);
    $page .= qq[<li>tblDefVenue</li>];
  }
  my $comp = param('chk_comp') || 0;
  if ($comp == 1) {
    $st = qq[
      UPDATE
        tblAssoc_Comp
      SET
        tTimeStamp = now()
      WHERE
        intAssocID = $assocID

    ];
    $db->do($st);
    $page .= qq[<li>tblAssoc_Comp</li>];
    $st = qq[
      UPDATE
        tblComp_Teams AS CT
        INNER JOIN tblAssoc_Comp AS AC ON (AC.intCompID = CT.intCompID)
      SET
        CT.tTimeStamp = now()
      WHERE
        AC.intAssocID = $assocID

    ];
    $db->do($st);
    $page .= qq[<li>tblComp_Teams</li>];
    $st = qq[
      UPDATE
        tblCompMatches
      SET
        tTimeStamp = now()
      WHERE
        intAssocID = $assocID

    ];
    $db->do($st);
    $page .= qq[<li>tblCompMatches</li>];
    $st = qq[
      UPDATE
        tblCompMatchSelectedPlayers
      SET
        tTimeStamp = now()
      WHERE
        intAssocID = $assocID

    ];
    $db->do($st);
    $page .= qq[<li>tblCompMatchSelectedPlayers</li>];
    $st = qq[
      UPDATE
        tblCompMatchSelectedPlayerNumbers
      SET
        tTimeStamp = now()
      WHERE
        intAssocID = $assocID

    ];
    $db->do($st);
    $page .= qq[<li>tblCompMatchSelectedPlayerNumbers</li>];
    $st = qq[
      UPDATE
        tblCompMatchTeamStats AS CMTS
        INNER JOIN tblCompMatches AS CM ON (CM.intMatchID = CMTS.intMatchID)
      SET
        CMTS.tTimeStamp = now()
      WHERE
        CM.intAssocID = $assocID
    ];
    $page .= qq[<li>tblCompMatchTeamStats</li>];
    $st = qq[
      UPDATE
        tblCompRounds AS CR
        INNER JOIN tblAssoc_Comp AS AC ON (AC.intCompID = CR.intCompID)
      SET
        CR.tTimeStamp = now()
      WHERE
        AC.intAssocID = $assocID

    ];
    $db->do($st);
    $page .= qq[<li>tblCompRounds</li>];
  }

  my $currentMatches = param('chk_curmatches') || 0;
   if ($currentMatches == 1) {
    $st = qq[
      UPDATE
        tblCompMatches CM
	INNER JOIN tblAssoc A ON A.intAssocID = CM.intAssocID
        INNER JOIN tblAssoc_Comp AS AC ON (AC.intCompID = CM.intCompID AND AC.intNewSeasonID=A.intCurrentSeasonID)
      SET
        CM.tTimeStamp = now()
      WHERE
        AC.intAssocID = $assocID

    ];
    $db->do($st);
    $page .= qq[<li>Current Matches</li>];
  }
  my $pools = param('chk_pools') || 0;
  if ($pools == 1) {
    $st = qq[
      UPDATE
        tblComp_Pools AS CP
        INNER JOIN tblAssoc_Comp AS AC ON (AC.intCompID = CP.intCompID)
      SET
        CP.tTimeStamp = now()
      WHERE
        AC.intAssocID = $assocID

    ];
    $db->do($st);
    $page .= qq[<li>tblComp_Pools</li>];
    $st = qq[
      UPDATE
        tblComp_Teams_Pools AS CTP
        INNER JOIN tblAssoc_Comp AS AC ON (AC.intCompID = CTP.intCompID)
      SET
        CTP.tTimeStamp = now()
      WHERE
        AC.intAssocID = $assocID

    ];
    $db->do($st);
    $page .= qq[<li>tblComp_Team_Pools</li>];
    $st = qq[
      UPDATE
        tblComp_Stages AS CS
        INNER JOIN tblAssoc_Comp AS AC ON (AC.intCompID = CS.intCompID)
      SET
        CS.tTimeStamp = now()
      WHERE
        AC.intAssocID = $assocID

    ];
    $db->do($st);
    $page .= qq[<li>tblComp_Stages</li>];
  }

  my $team = param('chk_team') || 0;
  if ($team == 1) {
    $st = qq[
      UPDATE
        tblTeam
      SET
        tTimeStamp = now()
      WHERE
        intAssocID = $assocID
    ];
    $db->do($st);
    $page .= qq[<li>tblTeam</li>];
  }

  my $club = param('chk_club') || 0;
  if ($club == 1) {
    $st = qq[
      UPDATE
        tblAssoc_Clubs AS AC
        INNER JOIN tblClub AS C ON (C.intClubID = AC.intClubID)
      SET
        C.tTimeStamp = now(),
        AC.tTimeStamp = now()
      WHERE
        AC.intAssocID = $assocID
    ];
    $db->do($st);
    $page .= qq[<li>tblClub</li>];
    $page .= qq[<li>tblAssoc_Clubs</li>];
  }

  my $ladder = param('chk_ladder') || 0;
  if ($ladder == 1) {
    $st = qq[
      UPDATE
        tblLadder AS L
        INNER JOIN tblAssoc_Comp AS AC ON (AC.intCompID = L.intCompID)
      SET
        L.tTimeStamp = now()
      WHERE
        AC.intAssocID = $assocID
    ];
    $db->do($st);
    $page .= qq[<li>tblLadder</li>];
  }
 my $actionlog = param('chk_actionlog') || 0;
 if($actionlog == 1) {
    $page .= qq[<li>MatchActions</li>];
    $st = qq[
      UPDATE
        tblResults_MatchActionLog_$realmID
      SET
        tTimeStamp = now()
      WHERE
        intAssocID = $assocID
    ];
    $db->do($st);
  }
  my $member = param('chk_member') || 0;
  if ($member == 1) {
    $st = qq[
      UPDATE
        tblMember_Associations
      SET
        tTimeStamp = now()
      WHERE
        intAssocID = $assocID
    ];
    $db->do($st);
    $page .= qq[<li>tblMember_Associations</li>];
  }
  if ($page) {
    $page = qq[
      <p>The following tables have been reset: <br>
      <ul>$page</ul></p>
    ];
  }
  else {
    $page = qq[<p>No tables have been reset.</p>];
  }
  return $page;
}

sub add_club_form {
  my ($db, $target) = @_;
  my $body = qq[
  <form action="$target" method=post>
    <table width="100%">
      <tr>
          <td class="formbg fieldlabel">Assoc ID:</td>
          <td class="formbg"><input type="text" name="assocID" value=""></td>
      </tr>
      <tr>
          <td class="formbg fieldlabel">Club Name:</td>
          <td class="formbg"><input type="text" name="clubName" value="" size="100"></td>
      </tr>
      <tr>
          <td class="formbg fieldlabel">Club ExtKey:</td>
          <td class="formbg"><input type="text" name="clubExtKey" value=""></td>
      </tr>
      <tr>
        <td class="formbg" colspan="4" align="center"><br>
          <input type=submit value="Add Club"><br>
        </td>
      </tr>
    </table>
    <input type="hidden" name="action" value="ASSOC_add_club">
  </form>
  ];
  return ($body, '');
}

sub add_club {
  my ($db, $target) = @_;
  my $assocID = param('assocID') || 0;
  my $clubName = param('clubName') || '';
  my $clubExtKey = param('clubExtKey') || '';
  my $body = '';
  $assocID = 0 unless ($assocID =~ /^\d+$/);
  my $st = qq[
    SELECT
      intAssocID
    FROM
      tblAssoc
    WHERE
      intAssocID = ?
  ];
  my $q = $db->prepare($st);
  $q->execute($assocID);
  my $validAssoc = $q->fetchrow_array();
  $assocID = 0 unless($validAssoc);
  if ($assocID == 0 or $clubName eq '') {
    $body = qq[<p>Assoc ID is not valid</p>] if ($assocID == 0);
    $body .= qq[<p>Club Name is not valid</p>] if ($clubName eq '');
    my ($form, $menu) = add_club_form($db, $target); 
    $body .= $form;
    return ($body, '');
  }
  $st = qq[
    INSERT INTO tblClub (
      strName,
      strExtKey
    )
    VALUES (
      ?,
      ?
    )
  ];
  $q = $db->prepare($st);
  $q->execute($clubName, $clubExtKey);
  my $clubID = $q->{mysql_insertid} || 0;
  if ($assocID == 0) {
    $body = qq[<p>Club ID is not valid</p>] if ($clubID == 0);
    my ($form, $menu) = add_club_form($db, $target); 
    $body .= $form;
    return ($body, '');
  }
  $st = qq[
    INSERT INTO tblAssoc_Clubs (
      intAssocID,
      intClubID
    )
    VALUES (
      ?,
      ?
    )
  ];
  $q = $db->prepare($st);
  $q->execute($assocID, $clubID);
  $body = qq[<p>Club sucessfully added</p>];
  my ($form, $menu) = add_club_form($db, $target); 
  $body .= $form;
  return ($body, '');
}

sub _update_courtside{
    my $param = shift;
    my ($db, $assocID, $field, $value) = @{$param}{qw/ db assocID field value /};
    
    return 0 if ( !$db || !$assocID || !$field );
    
    $value = undef if (!$value);
    
    my $update_sql = qq[
        INSERT INTO tblCourtsideConfig
            (intAssocID, $field)
            VALUES (?, ?)
        ON DUPLICATE KEY UPDATE $field = VALUES($field)        
    ];

    my $update_stmt = $db->prepare($update_sql);
    $update_stmt->execute($assocID, $value);
    $update_stmt->finish();

    return 1;
}
1;
