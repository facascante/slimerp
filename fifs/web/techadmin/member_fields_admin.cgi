#!/usr/bin/perl 

#
# $Header: svn://svn/SWM/trunk/web/techadmin/member_fields_admin.cgi 10107 2013-12-03 01:30:08Z tcourt $
#

use lib "../..","..",".";
#use lib "/u/regonew_live","/u/regonew_live/web","/u/regonew_live/web/admin";
use DBI;
use CGI qw(param unescape escape);
use Defs;
use Utils;
use strict;
use TechAdminPageGen;
use TechAdminCommon;
use FormHelpers;

main();

sub main	{
	my $header = "Content-type: text/html\n\n";
	my $body = "";
	my $page_title = "$Defs::sitename Member Fields Layout Administration";
  my $page_heading = "Member Field Layout Admin";
	my $output=new CGI;
  my $db=connectDB();
	my $action = param('a') || '';
  my $home_link = qq[<p><a href="member_fields_admin.cgi">[Home]</a></p>];
  $home_link = '' unless($action);
  if ($action eq 'editFL') {
    $body = get_member_field_layout($db);
    $page_heading = 'Update Member Field Order';
  }
  elsif ($action eq 'editFG') {
    $body = get_member_field_groups($db);
    $page_heading = 'Update Member Field Groups';
  }
  elsif ($action eq "update_groups") {
    $body = update_member_field_groups($db);
    $page_heading = 'Update Member Field Groups';
  }
  elsif ($action eq "update") {
    $body = update_member_field_layout($db);
    $page_heading = 'Update Member Field Order';
  }
  elsif ($action eq "addF") {
    $body = add_field_to_layout($db);
    $page_heading = 'Add Field to Member Fields List';
  }
  elsif ($action eq "deleteF") {
    $body = delete_field_from_layout($db);
    $page_heading = 'Delete Field from Member Fields List';
  }
  elsif ($action eq "insertF" or $action eq "removeF") {
    $body = alter_field_layout($db, $action);
    $page_heading = 'Add Field to Member Fields List' if $action eq 'insertF';
    $page_heading = 'Delete Field from Member Fields List' if $action eq 'removeF';
  }
  elsif ($action eq "newL") {
    $body = add_custom_layout();
    $page_heading = 'Add new Member Fields List';
  }
  elsif ($action eq "addL") {
    $body = insert_custom_layout($db);
    $page_heading = 'Add new Member Fields List';
  }
  elsif ($action eq "deleteL") {
    $body = confirm_delete_layout();
    $page_heading = 'Delete Member Fields List';
  }
  elsif ($action eq "confirmDeleteL") {
    $body = delete_custom_layout($db);
    $page_heading = 'Delete Member Fields List';
  }
  else {
    $body = get_realms_with_custom_layouts($db);
  }
  $body = qq[<div style="padding:10px;"><h1>$page_heading</h1> $body $home_link</div>];
  print_adminpageGen($body, $page_title, $page_heading, undef)
}

sub get_realms_with_custom_layouts {
  my ($db) = @_;
  my $body = '';
  my $st = qq[
    SELECT
      SC.intSystemConfigID,
      R.strRealmName,
      RST.strSubTypeName
    FROM
      tblSystemConfig AS SC
      INNER JOIN tblRealms AS R ON (SC.intRealmID = R.intRealmID)
      LEFT JOIN tblRealmSubTypes RST ON (SC.intSubTypeID = RST.intSubTypeID)
    WHERE
      SC.strOption = 'MemberFormReLayout'
  ];
  my $q = $db->prepare($st);
  $q->execute();
  while (my $href = $q->fetchrow_hashref()) {
    $body .= qq[$href->{'strRealmName'}];
    $body .= qq[ ($href->{'strSubTypeName'})] if $href->{'strSubTypeName'};
    $body .= qq[ [<a href="member_fields_admin.cgi?a=editFL&scID=$href->{'intSystemConfigID'}">Edit Field Layout</a>]];
    $body .= qq[ [<a href="member_fields_admin.cgi?a=editFG&scID=$href->{'intSystemConfigID'}">Edit Field Groups</a>]];
    $body .= qq[ [<a href="member_fields_admin.cgi?a=addF&scID=$href->{'intSystemConfigID'}">Add Field</a>]];
    $body .= qq[ [<a href="member_fields_admin.cgi?a=deleteF&scID=$href->{'intSystemConfigID'}">Delete Field</a>]];
    $body .= qq[ [<a href="member_fields_admin.cgi?a=deleteL&scID=$href->{'intSystemConfigID'}">Delete Layout</a>]];
    $body .= qq[ <br><br> ];
  }
  $body .= qq[<p><a href="member_fields_admin.cgi?a=newL">[Add new layout]</a></p>];
  return $body;
}

sub get_member_field_layout {
  my ($db) = @_;
  my $scID = param('scID') || 0;
  return qq[ERROR:: No ID passed in.] unless $scID;
  my $body = '';
  my ($configchanges, $realmID, $stID)  = get_field_layout_blob($db, $scID);
  $body = qq[
    <script language="JavaScript" type="text/javascript">
      function hasOptions(obj){
        if(obj!=null && obj.options!=null){
          return true;
        }
        return false;
      }
      function swapOptions(obj,i,j){
        var o = obj.options;
        var i_selected = o[i].selected;
        var j_selected = o[j].selected;
        var temp = new Option(o[i].text, o[i].value, o[i].defaultSelected, o[i].selected);
        var temp2= new Option(o[j].text, o[j].value, o[j].defaultSelected, o[j].selected);
        o[i] = temp2;
        o[j] = temp;
        o[i].selected = j_selected;
        o[j].selected = i_selected;
      }
      function moveOptionUp(obj){
        if(!hasOptions(obj)) { 
          return;  
        }
        for(i=0;i<obj.options.length;i++){
          if(obj.options[i].selected){
            if(i != 0 && !obj.options[i-1].selected){
              swapOptions(obj,i,i-1);
              obj.options[i-1].selected = true;
            }
          }
        }
        updateorder(document.form.updownlist, document.form.newOrder);
      }
      function moveOptionDown(obj){
        if(!hasOptions(obj)){
          return;
        }
        for(i=obj.options.length-1;i>=0;i--){
          if(obj.options[i].selected){
            if(i !=(obj.options.length-1) && ! obj.options[i+1].selected){
              swapOptions(obj,i,i+1);
              obj.options[i+1].selected = true;
            }
          }
        }
        updateorder(document.form.updownlist, document.form.newOrder);
      }
      function updateorder(list,updatefield) {
        var neworder= '';
        for (i = 0; i <= list.options.length-1; i++) {
          neworder+= list.options[i].value;
          if (i != list.options.length-1) neworder+= " ";
        }
        updatefield.value=neworder;   
      }
    </script>
    <form name="form" action="member_fields_admin.cgi" post="post">
      <table border="0" cellpadding="1" cellspacing="1">
        <tr>
          <td align="center" valign="middle">
          <select name="updownlist" multiple="MULTIPLE" size="20">
  ];
  my $sectionname = '';
  for my $field (@{$configchanges->{'order'}}) {
    $body .= qq[ <option value="$field"> $field ($configchanges->{'sectionname'}{$field})</option> ];
    $sectionname .= qq[, ] if $sectionname;
    $sectionname .= qq[$field=>'$configchanges->{'sectionname'}{$field}'];
  }
  $body .= qq[
          </select>
          </td>
          <td>
            <input onClick="moveOptionUp(this.form['updownlist']); return false;" type="image" src="../images/up2.gif" title="Up" border="0"> 
            <br><br>
            <input onClick="moveOptionDown(this.form['updownlist']); return false;" type="image" src="../images/down2.gif" title="Down" border="0">
          </td>
        </tr>
        <tr><td>&nbsp;</td></tr>
        <tr>
          <td colspan="2">
            <input type="submit" name="SUBMIT" value="UPDATE ORDER" onClick="updateorder(document.form.updownlist, document.form.newOrder)">
            <input type="hidden" name="newOrder" value="">
            <input type="hidden" name="a" value="update">
            <input type="hidden" name="rID" value="$realmID">
            <input type="hidden" name="stID" value="$stID">
            <input type="hidden" name="scID" value="$scID">
            <input type="hidden" name="sectionname" value="$sectionname">
          </td>
        </tr>
    </table>
    </form>
  ];
  return $body;
}

sub get_member_field_groups {
  my ($db) = @_;
  my $scID = param('scID') || 0;
  return qq[ERROR:: No ID passed in.] unless $scID;
  my $body = '';
  my ($configchanges, $realmID, $stID) = get_field_layout_blob($db, $scID);
  $body = qq[
    <form name="form" action="member_fields_admin.cgi" post="post">
    <table border="0">
  ];
  my $field_order = '';
  for my $field (@{$configchanges->{'order'}}) {
    $body .= qq[ 
      <tr>
        <td>$field</td>
        <td>].generate_groups_ddl($field, $configchanges->{'sectionname'}{$field}).qq[</td>
      </tr>
    ];
    $field_order .= qq[ ] if $field_order;
    $field_order .= qq[$field];
  }
  $body .= qq[
        <tr><td>&nbsp;</td></tr>
        <tr>
          <td colspan="2">
            <input type="submit" name="SUBMIT" value="UPDATE GROUPS">
            <input type="hidden" name="newOrder" value="$field_order">
            <input type="hidden" name="a" value="update_groups">
            <input type="hidden" name="realmID" value="$realmID">
            <input type="hidden" name="stID" value="$stID">
            <input type="hidden" name="scID" value="$scID">
            <input type="hidden" name="sectionname" value="">
          </td>
        </tr>
    </table>
    </form>
  ];
  return $body;
}

sub update_member_field_layout {
  my ($db) = @_;
  my $realmID = param('realmID') || 0;
  my $stID = param('stID') || 0;
  my $scID = param('scID') || 0;
  my $neworder = param('newOrder') || '';
  my $sectionname = param('sectionname') || '';
  my $blob = qq[(order=>[qw($neworder)], sectionname=>{$sectionname})];
  my $st = qq[
    UPDATE
      tblSystemConfigBlob
    SET
      strBlob = ?
    WHERE
      intSystemConfigID = ?
  ];
  my $q = $db->prepare($st);
  $q->execute($blob, $scID);
  return qq[<p>Member List Updated</p>];
}

sub update_member_field_groups {
  my ($db) = @_;
  my $realmID = param('realmID') || 0;
  my $stID = param('stID') || 0;
  my $scID = param('scID') || 0;
  my $field_order = param('newOrder') || '';
  my $sectionname = '';
  my @fields = split ' ', $field_order;
  for my $field (@fields) {
    my $group = param('group_'.$field) || '';
    $sectionname .= qq[, ] if $sectionname;
    $sectionname .= qq[$field => '$group'];
  }
  my $blob = qq[(order=>[qw($field_order)], sectionname=>{$sectionname})];
  my $st = qq[
    UPDATE
      tblSystemConfigBlob
    SET
      strBlob = ?
    WHERE
      intSystemConfigID = ?
  ];
  my $q = $db->prepare($st);
  $q->execute($blob, $scID);
  return qq[<p>Member Groups Updated</p>];
}

sub get_field_layout_blob {
  my ($db, $intSystemConfigID) = @_;
  my $st = qq[
    SELECT
      SC.intSystemConfigID,
      SC.intRealmID,
      SC.intSubTypeID,
      SCB.strBlob
    FROM
      tblSystemConfig AS SC
      LEFT JOIN tblSystemConfigBlob AS SCB ON (SC.intSystemConfigID = SCB.intSystemConfigID)
    WHERE
      SC.intSystemConfigID = ?
  ];
  my $q = $db->prepare($st);
  $q->execute($intSystemConfigID);
  my ($scID, $realmID, $stID, $blob) = $q->fetchrow_array();
  my %configchanges = eval($blob);
  return (\%configchanges, $realmID, $stID);
}

sub generate_groups_ddl {
  my ($field, $group_IN) = @_;
  my @groups = qw(contact details financial identification interests medical other parent custom1);
  my $ddl = '';
  for my $group (@groups) {
    if ($group eq $group_IN) {
      $ddl .= qq[<option SELECTED>$group</option>];
    }
    else {
      $ddl .= qq[<option>$group</option>];
    }
  }
  return qq[<select name="group_$field">$ddl</select>];
}

sub add_field_to_layout {
  my ($db) = @_;
  my $scID = param('scID') || 0;
  my $group_ddl = generate_groups_ddl('','');
  my $body = qq[
    <form name="form" action="member_fields_admin.cgi" post="post">
      Field Name: 
      <input type="text" name="field" value=""> 
      $group_ddl 
      <input type="hidden" name="scID" value="$scID">
      <input type="hidden" name="a" value="insertF">
      <input type="submit" value="ADD FIELD">
    </form>
  ];
  return $body;
}

sub delete_field_from_layout {
  my ($db) = @_;
  my $scID = param('scID') || 0;
  my ($configchanges, $realmID, $stID) = get_field_layout_blob($db, $scID);
  my $body = qq[
    <table border="0">
  ];
  for my $field (@{$configchanges->{'order'}}) {
    $body .= qq[
      <tr>
        <td>$field</td>
        <td><a href="member_fields_admin.cgi?a=removeF&scID=$scID&field=$field">[Delete]</a></td>
      </tr>
    ];
  }
  $body .= qq[
    </table>
  ];
  return $body;
}

sub alter_field_layout {
  my ($db, $action) = @_;
  my $scID = param('scID') || 0;
  return qq[<p>Error: No ID passed in] unless $scID;
  my $field_IN = param('field') || '';
  my $group_IN = param('group_') || '';
  my ($configchanges, $realmID, $stID) = get_field_layout_blob($db, $scID);
  my $order = '';
  my $sectionname = '';
  for my $field (@{$configchanges->{'order'}}) {
    next if ($field eq $field_IN and $action eq 'removeF');
    $sectionname .= ', ' if $sectionname;
    $sectionname .= "$field=>'$configchanges->{'sectionname'}{$field}'";
    $order .= ' ' if $order;;
    $order .= "$field";
  }
  $sectionname .= ", $field_IN=>'$group_IN'" if ($action eq "insertF");
  $order .= " $field_IN" if ($action eq "insertF");
  my $blob = qq[(order=>[qw($order)], sectionname=>{$sectionname})];
  my $st = qq[
    UPDATE
      tblSystemConfigBlob
    SET
      strBlob = ?
    WHERE
      intSystemConfigID = ?
  ];
  my $q = $db->prepare($st);
  $q->execute($blob, $scID);
  return qq[<p>$field_IN Inserted</p>] if $action eq "insertF";
  return qq[<p>$field_IN Removed</p>] if $action eq "removeF";
}

sub add_custom_layout {
  return qq[
    <form name="form" action="member_fields_admin.cgi" post="post">
    Realm ID: <input type="text" name="realmID" value=""> <br>
    Sub Type ID: <input type="text" name="stID" value=""> <br>
    <input type="submit" value="ADD NEW LAYOUT">
    <input type="hidden" name="a" value="addL">
    </form>
  ];
}

sub insert_custom_layout {
  my ($db) = @_;
  my $realmID = param('realmID') || 0;
  my $stID = param('stID') || 0;
  return qq[<p>Error:: No realm id passed in</p>] unless $realmID;
  my %layout = (
    'strNationalNum' => 'details',
    'strMemberNo' => 'details',
    'intRecStatus' => 'details',
    'intMemberToHideID' => 'details',
    'intDefaulter' => 'details',
    'strSalutation' => 'details',
    'strFirstname' => 'details',
    'strMiddlename' => 'details',
    'strSurname' => 'details',
    'strMaidenName' => 'details',
    'strPreferredName' => 'details',
    'dtDOB' => 'details',
    'strPlaceofBirth' => 'details',
    'intGender' => 'details',
    'strAddress1' => 'contact',
    'strAddress2' => 'contact',
    'strSuburb' => 'contact',
    'strState' => 'contact',
    'strCityOfResidence' => 'contact',
    'strCountry' => 'contact',
    'strPostalCode' => 'contact',
    'strPhoneHome' => 'contact',
    'strPhoneWork' => 'contact',
    'strPhoneMobile' => 'contact',
    'strPager' => 'contact',
    'strFax' => 'contact',
    'strEmail' => 'contact',
    'strEmail2' => 'contact',
    'intOccupationID' => 'other',
    'intEthnicityID' => 'details',
    'intMailingList' => 'other',
    'intLifeMember' => 'financial',
    'intDeceased' => 'details',
    'strLoyaltyNumber' => 'other',
    'intFinancialActive' => 'financial',
    'intMemberPackageID' => 'financial',
    'curMemberFinBal' => 'financial',
    'strPreferredLang' => 'identification',
    'strPassportIssueCountry' => 'identification',
    'strPassportNationality' => 'identification',
    'strPassportNo' => 'identification',
    'dtPassportExpiry' => 'identification',
    'strBirthCertNo' => 'identification',
    'strHealthCareNo' => 'identification',
    'intIdentTypeID' => 'identification',
    'strIdentNum' => 'identification',
    'dtPoliceCheck' => 'identification',
    'dtPoliceCheckExp' => 'identification',
    'strPoliceCheckRef' => 'dentification',
    'intFavStateTeamID' => 'other',
    'intFavNationalTeamID' => 'other',
    'intFavNationalTeamMember' => 'other',
    'intAttendSportCount' => 'other',
    'intWatchSportHowOftenID' => 'other',
    'strEmergContName' => 'contact',
    'strEmergContNo' => 'contact',
    'strEmergContNo2' => 'contact',
    'strEmergContRel' => 'contact',
    'strP1Salutation' => 'parent',
    'strP2Salutation' => 'parent',
    'intP1Gender' => 'parent',
    'intP2Gender' => 'parent',
    'strP1FName' => 'parent',
    'strP1SName' => 'parent',
    'strP2FName' => 'parent',
    'strP2SName' => 'parent',
    'strP1Phone' => 'parent',
    'strP2Phone' => 'parent',
    'strP1Phone2' => 'parent',
    'strP2Phone2' => 'parent',
    'strP1PhoneMobile' => 'parent',
    'strP2PhoneMobile' => 'parent',
    'strP1Email' => 'parent',
    'strP2Email' => 'parent',
    'strP1Email2' => 'parent',
    'strP2Email2' => 'parent',
    'strEyeColour' => 'other',
    'strHairColour' => 'other',
    'strHeight' => 'other',
    'strWeight' => 'other',
    'intPlayer' => 'interests',
    'intCoach' => 'interests',
    'intUmpire' => 'interests',
    'intOfficial' => 'interests',
    'intMisc' => 'interests',
    'intVolunteer' => 'interests',
    'dtFirstRegistered' => 'other',
    'dtLastRegistered' => 'other',
    'dtRegisteredUntil' => 'other',
    'dtLastUpdate' => 'other',
    'dtCreatedOnline' => 'other',
    'dtSuspendedUntil' => 'other',
    'strNotes' => 'other',
    'intHowFoundOutID' => 'other',
    'intP1AssistAreaID' => 'parent',
    'intP2AssistAreaID' => 'parent',
    'intMedicalConditions' => 'medical',
    'intAllergies' => 'medical',
    'intAllowMedicalTreatment' => 'medical',
    'strMedicalNotes' => 'medical',
    'strSchoolName' => 'other',
    'strSchoolSuburb' => 'other',
    'intSchoolID' => 'other',
    'intGradeID' => 'other',
    'intConsentSignatureSighted' => 'other'
  );
  my @order = qw(strNationalNum strMemberNo intRecStatus intDefaulter strSalutation strFirstname strMiddlename strSurname strMaidenName strPreferredName dtDOB strPlaceofBirth intGender strAddress1 strAddress2 strSuburb strCityOfResidence strState strPostalCode strCountry strPhoneHome strPhoneWork strPhoneMobile strPager strFax strEmail strEmail2 SPcontact intOccupationID intDeceased strLoyaltyNumber intMailingList intFinancialActive intMemberPackageID curMemberFinBal intLifeMember strPreferredLang strPassportIssueCountry strPassportNationality strPassportNo dtPassportExpiry strBirthCertNo strHealthCareNo intIdentTypeID strIdentNum dtPoliceCheck dtPoliceCheckExp strPoliceCheckRef intPlayer intCoach intUmpire intOfficial intMisc intVolunteer strEmergContName strEmergContNo strEmergContNo2 strEmergContRel strP1Salutation strP1FName strP1SName intP1Gender strP1Phone strP1Phone2 strP1PhoneMobile strP1Email strP1Email2 intP1AssistAreaID strP2Salutation strP2FName strP2SName intP2Gender strP2Phone strP2Phone2 strP2PhoneMobile strP2Email strP2Email2 intP2AssistAreaID strEyeColour strHairColour intEthnicityID strHeight strWeight strNatCustomStr1 strNatCustomStr2 strNatCustomStr3 strNatCustomStr4 strNatCustomStr5 strNatCustomStr6 strNatCustomStr7 strNatCustomStr8 strNatCustomStr9 strNatCustomStr10 strNatCustomStr11 strNatCustomStr12 strNatCustomStr13 strNatCustomStr14 strNatCustomStr15 dblNatCustomDbl1 dblNatCustomDbl2 dblNatCustomDbl3 dblNatCustomDbl4 dblNatCustomDbl5 dblNatCustomDbl6 dblNatCustomDbl7 dblNatCustomDbl8 dblNatCustomDbl9 dblNatCustomDbl10 dtNatCustomDt1 dtNatCustomDt2 dtNatCustomDt3 dtNatCustomDt4 dtNatCustomDt5 intNatCustomLU1 intNatCustomLU2 intNatCustomLU3 intNatCustomLU4 intNatCustomLU5 intNatCustomLU6 intNatCustomLU7 intNatCustomLU8 intNatCustomLU9 intNatCustomLU10 intNatCustomBool1  intNatCustomBool2 intNatCustomBool3 intNatCustomBool4 intNatCustomBool5 strCustomStr1 strCustomStr2 strCustomStr3 strCustomStr4 strCustomStr5 strCustomStr6 strCustomStr7 strCustomStr8 strCustomStr9 strCustomStr10 strCustomStr11 strCustomStr12 strCustomStr13 strCustomStr14 strCustomStr15 dblCustomDbl1 dblCustomDbl2 dblCustomDbl3 dblCustomDbl4 dblCustomDbl5 dblCustomDbl6 dblCustomDbl7 dblCustomDbl8 dblCustomDbl9 dblCustomDbl10 dtCustomDt1 dtCustomDt2 dtCustomDt3 dtCustomDt4 dtCustomDt5 intCustomLU1 intCustomLU2 intCustomLU3 intCustomLU4 intCustomLU5 intCustomLU6 intCustomLU7 intCustomLU8 intCustomLU9 intCustomLU10 intCustomBool1 intCustomBool2 intCustomBool3 intCustomBool4 intCustomBool5 strMemberCustomNotes1  strMemberCustomNotes2 strMemberCustomNotes3 strMemberCustomNotes4 strMemberCustomNotes5 intSchoolID strSchoolName strSchoolSuburb intGradeID intFavStateTeamID intFavNationalTeamID strNotes SPdetails dtFirstRegistered dtLastRegistered dtRegisteredUntil dtLastUpdate dtCreatedOnline intHowFoundOutID intMedicalConditions intAllergies intAllowMedicalTreatment strMedicalNotes intConsentSignatureSighted intAttendSportCount intWatchSportHowOftenID intFavNationalTeamMember);
  my $st = qq[
    INSERT INTO
      tblSystemConfig
    VALUES (
      0,
      1,
      'MemberFormReLayout',
      '1',
      now(),
      ?,
      ?
    )
  ];
  my $q = $db->prepare($st);
  $q->execute($realmID, $stID);
  my $scID = $q->{mysql_insertid} || 0;
  return qq[<p>Error:: No SystemConfig ID returned</p>] unless $scID;
  my $blob = ''; 
  my $sectionname = '';
  my $order = '';
  for my $field (@order) {
    if ($layout{$field}) {
      $sectionname .= ', ' if $sectionname;
      $sectionname .= "$field=>'$layout{$field}'";
      $order .= ' ' if $order;;
      $order .= "$field";
    }
  }
  $blob = qq[(order=>[qw($order)], sectionname=>{$sectionname})];
  $st = qq[
    INSERT INTO
      tblSystemConfigBlob
    VALUES (
      ?,
      ?
    )
  ];
  $q = $db->prepare($st);
  $q->execute($scID, $blob);
  return qq[<p>Layout Inserted</p>];
}

sub confirm_delete_layout {
  my $scID = param('scID') || 0;
  return qq[<p>Error:: No id passed in</p>] unless $scID;
  return qq[
    <form name="form" action="member_fields_admin.cgi" post="post">
    <input type="hidden" name="scID" value="$scID"> <br>
    <input type="submit" value="CONFIRM">
    <input type="hidden" name="a" value="confirmDeleteL">
    </form>
  ];
}

sub delete_custom_layout {
  my ($db) = @_;
  my $scID = param('scID') || 0;
  return qq[<p>Error:: No id passed in</p>] unless $scID;
  my $st = qq[
    DELETE FROM tblSystemConfig WHERE intSystemConfigID = ?
  ];
  my $q = $db->prepare($st);
  $q->execute($scID);
  $st = qq[
    DELETE FROM tblSystemConfigBlob WHERE intSystemConfigID = ?
  ];
  $q = $db->prepare($st);
  $q->execute($scID);
  return qq[<p>Layout Deleted</p>];
}
