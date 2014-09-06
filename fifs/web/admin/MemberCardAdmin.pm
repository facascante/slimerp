#
# $Header: svn://svn/SWM/trunk/web/admin/MemberCardAdmin.pm 8251 2013-04-08 09:00:53Z rlee $
#

package MemberCardAdmin;

require Exporter;
@ISA =  qw(Exporter);
@EXPORT = qw(handle_member_card);
@EXPORT_OK = qw(handle_member_card);

use lib "..","../..","../sp_publisher";
use DBI;
use CGI qw(param unescape escape);
use strict;

use Defs;
use Utils;
use TechAdminCommon;
use DeQuote;
use FormHelpers;

sub handle_member_card {
  my($db, $action, $target) = @_;
  my $memberCardID_IN = param('mcID') || 0;
  my $assocID_IN = param('assocID') || 0;
  my $realmID_IN = param('realmID') || param('intRealmID') || 0;
  my $body = '';
  my $menu = '';
  $action = substr $action, 6;
  if ($action eq 'MC_form') {
		($body, $menu) = member_card_form($db, $action, $target, $assocID_IN, $realmID_IN, $memberCardID_IN); 
  }
  elsif ($action eq 'MC_update') {
		($body, $menu) = update_member_card($db, $action, $target, $assocID_IN, $realmID_IN, $memberCardID_IN); 
  }
  elsif ($action eq 'MC_insert') {
		($body, $menu) = insert_member_card($db, $action, $target, $assocID_IN, $realmID_IN, $memberCardID_IN); 
  }
  elsif ($action eq 'MC_list_templates') {
    ($body, $menu) = list_member_card_templates($db, $action, $target, $assocID_IN, $realmID_IN);
  }
  elsif ($action eq 'MC_form_templates') {
    ($body, $menu) = member_card_form_template($db, $action, $target, $assocID_IN, $realmID_IN, $memberCardID_IN);
  }
  elsif ($action eq 'MC_update_template') {
    ($body, $menu) = update_member_card_template($db, $action, $target, $assocID_IN, $realmID_IN, $memberCardID_IN);
  }
  elsif ($action eq 'MC_insert_template') {
    ($body, $menu) = insert_member_card_template($db, $action, $target, $assocID_IN, $realmID_IN, $memberCardID_IN);
  }
  else  {
    ($body, $menu) = list_member_card($db, $action, $target, $assocID_IN, $realmID_IN);
  }
  return ($body, $menu);
}

# *********************SUBROUTINES BELOW****************************

sub list_member_card	{
  my ($db, $action, $target, $intAssocID, $intRealmID) = @_;
  my $strWhere = '';
  if ($intAssocID) {
    $strWhere .= " AND " if $strWhere;
    $strWhere .= qq[intAssocID = $intAssocID];
  }
  if ($intRealmID) {
    $strWhere .= " AND " if $strWhere;
    $strWhere .= qq[intRealmID = $intRealmID];
  }
	$strWhere = "WHERE $strWhere" if $strWhere;
  my $statement = qq[
		SELECT 
      tblMemberCardConfig.*,
      tblRealms.strRealmName,
      tblAssoc.strName AS strAssocName
    FROM
      tblMemberCardConfig
      LEFT JOIN tblRealms USING (intRealmID)
      LEFT JOIN tblAssoc USING (intAssocID)
		$strWhere
    ORDER BY
      tblMemberCardConfig.intRealmID,
      tblAssoc.strName
  ];
  my $query = $db->prepare($statement) or query_error($statement);
  $query->execute() or query_error($statement);
  my $count = 0;
  my $body = '';
  my $realm_name = '';
  while (my $dref = $query->fetchrow_hashref()) {
    foreach my $key (keys %{$dref}) { if(!defined $dref->{$key})  {$dref->{$key}='';} }
    my $class = '';
    my $classborder = 'commentborder';
    if($count++%2 == 1) {
      $class = q[ class="commentshaded" ];
      $classborder = "commentbordershaded";
    }
    if ($realm_name ne $dref->{strRealmName}) {
      $body .= qq[
      <tr>
        <th colspan="4" style="text-align:left;">$dref->{strRealmName}</th>
      </tr>
      ];
    }
    $realm_name = $dref->{strRealmName};
		my $extralink = '';
    $dref->{strAssocName} ||= "Realm/Sub Realm Based";
    $body .= qq[
      <tr>
        <td class="$classborder">$dref->{intMemberCardConfigID}</td>
        <td class="$classborder">$dref->{strAssocName}</td>
        <td class="$classborder">$dref->{strName}</td>
        <td class="$classborder">$dref->{strFilename}</td>
        <td class="$classborder">[<a $extralink href="$target?action=UTILS_MC_form&amp;mcID=$dref->{intMemberCardConfigID}">Edit</a>]</td>
      </tr>
    ];
  }
  if(!$body)  {
    $body .= qq[
    <table cellpadding="1" cellspacing="0" border="0" width="90%" align="center">
      <tr>
				<td colspan="3" align="center"><b><br> No Member Cards were found <br><br></b></td>
      </tr>
    </table>
    <br>
    ];
  }
  else  {
    $body = qq[
    <p><a href="$target?action=UTILS_MC_form">Add New Card</a> | <a href="$target?action=UTILS_MC_list_templates">List Templates</a></p>
		 <table cellpadding="1" cellspacing="0" border="0" width="95%" align="center">
      $body
    </table><br>
    ];
  }
  return ($body, '');
}

sub member_card_form {
  my ($db, $action, $target, $intAssocID, $intRealmID, $mcID) = @_;
	my $fields = {};
  $action = "UTILS_MC_insert";
  my $btn_text = "Add";
  if ($mcID) {
    my $st_get_card = qq[
      SELECT
        *
      FROM
        tblMemberCardConfig
      WHERE
        intMemberCardConfigID = ?
    ];
    my $q = $db->prepare($st_get_card) or query_error($st_get_card);
    $q->execute($mcID) or query_error($st_get_card);
    $fields = $q->fetchrow_hashref();
    $action = "UTILS_MC_update";
    $btn_text = "Update";
  }
	my $st = qq[
	 SELECT 
      intRealmID, 
      strRealmName
	 FROM 
      tblRealms
	 ORDER BY 
      strRealmName
	];
	$fields->{'intRealmID'} = getDBdrop_down('intRealmID', $db, $st, $fields->{'intRealmID'}, '&nbsp;');
  $st = qq[
    SELECT
      intMemberCardTemplateID,
      strMemberCardTemplateName
    FROM
      tblMemberCardTemplates
    ORDER BY 
      strMemberCardTemplateName
  ];
	$fields->{'intMemberCardTemplateID'} = getDBdrop_down('intMemberCardTemplateID', $db, $st, $fields->{'intMemberCardTemplateID'}, '&nbsp;');
  $fields->{'strName'} ||= '';
  $fields->{'intAssocID'} ||= '';
  $fields->{'intPrintFromLevelID'} ||= 5;
  $fields->{'intBulkPrintFromLevelID'} ||= 5;
  $fields->{'strFilename'} ||= '';
  $fields->{'strMemberCard'} ||= ''; 
	my $menu = '';
	my $body = qq[
	<form action="$target" method=post>
		<table width="100%">
			<tr>
					<td class="formbg fieldlabel">Name:</td>
					<td class="formbg"><input type="text" name="strName" value="$fields->{'strName'}"></td>
			</tr>
			<tr>
					<td class="formbg fieldlabel">Assoc:</td>
					<td class="formbg"><input type="text" name="assocID" value="$fields->{'intAssocID'}"></td>
			</tr>
			<tr>
					<td class="formbg fieldlabel">Realm:</td>
					<td class="formbg">$fields->{'intRealmID'}</td>
			</tr>
      <tr>
          <td class="formbg fieldlabel">Sub Realm:</td>
          <td class="formbg"><input type="text" name="intSubRealmID" value="$fields->{'intSubRealmID'}" size="3"></td>
      </tr>
      <tr>
          <td class="formbg fieldlabel">Print Level:</td>
          <td class="formbg"><input type="text" name="intPrintFromLevelID" value="$fields->{'intPrintFromLevelID'}" size="3"></td>
      </tr>
      <tr>
          <td class="formbg fieldlabel">Bulk Print Level:</td>
          <td class="formbg"><input type="text" name="intBulkPrintFromLevelID" value="$fields->{'intBulkPrintFromLevelID'}" size="3"></td>
      </tr>
      <tr>
          <td class="formbg fieldlabel">Filename:</td>
          <td class="formbg"><input type="text" name="strFilename" value="$fields->{'strFilename'}"></td>
      </tr>
      <tr>
          <td class="formbg fieldlabel">Template:</td>
          <td class="formbg">$fields->{'intMemberCardTemplateID'}</td>
      </tr>
      <tr>
          <td class="formbg fieldlabel" valign="top">Member Card:</td>
          <td class="formbg"><textarea name="strMemberCard" cols="140" rows="50">$fields->{'strMemberCard'}</textarea></td>
      </tr>
      <tr>
        <td class="formbg" colspan="2" align="center"><br>
          <input type="hidden" name="mcID" value="$mcID">
          <input type=submit value="$btn_text Member Card"><br>
        </td>
			</tr>
    </table>
    <input type="hidden" name="action" value="$action">
  </form>
  ];
	return ($body, $menu);
}

sub update_member_card {
  my ($db, $action, $target, $intAssocID, $intRealmID, $mcID) = @_;
  my $strName = param('strName') || '';
  my $intSubRealmID = param('intSubRealmID') || '';
  my $intPrintFromLevelID = param('intPrintFromLevelID') || '';
  my $intBulkPrintFromLevelID = param('intBulkPrintFromLevelID') || '';
  my $intMemberCardTemplateID = param('intMemberCardTemplateID') || '';
  my $strFilename = param('strFilename') || '';
  my $strMemberCard = param('strMemberCard') || '';
  my $st = qq[
    UPDATE 
      tblMemberCardConfig
    SET
      strName = ?,
      intAssocID = ?,
      intRealmID = ?,
      intSubRealmID = ?,
      intPrintFromLevelID = ?,
      intBulkPrintFromLevelID = ?,
      strFilename = ?,
      strMemberCard = ?,
      intMemberCardTemplateID = ?
    WHERE
      intMemberCardConfigID = ?
    LIMIT 1
  ];
  my $q = $db->prepare($st);
  $q->execute(
      $strName,
      $intAssocID,
      $intRealmID,
      $intSubRealmID,
      $intPrintFromLevelID,
      $intBulkPrintFromLevelID,
      $strFilename,
      $strMemberCard,
      $intMemberCardTemplateID,
      $mcID
  ) or query_error($st);
  return list_member_card($db, $action, $target, 0, 0);
}

sub insert_member_card {
  my ($db, $action, $target, $intAssocID, $intRealmID) = @_;
  my $strName = param('strName') || '';
  my $intSubRealmID = param('intSubRealmID') || '';
  my $intPrintFromLevelID = param('intPrintFromLevelID') || '';
  my $intBulkPrintFromLevelID = param('intBulkPrintFromLevelID') || '';
  my $intMemberCardTemplateID = param('intMemberCardTemplateID') || '';
  my $strFilename = param('strFilename') || '';
  my $strMemberCard = param('strMemberCard') || '';
  my $st = qq[
    INSERT INTO tblMemberCardConfig (
      strName,
      intAssocID,
      intRealmID,
      intSubRealmID,
      intPrintFromLevelID,
      intBulkPrintFromLevelID,
      strFilename,
      intMemberCardTemplateID,
      strMemberCard
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
      ?
    )
  ];
  my $q = $db->prepare($st);
  $q->execute(
      $strName,
      $intAssocID,
      $intRealmID,
      $intSubRealmID,
      $intPrintFromLevelID,
      $intBulkPrintFromLevelID,
      $strFilename,
      $intMemberCardTemplateID,
      $strMemberCard
  );
  return list_member_card($db, $action, $target, 0, 0);
}

sub list_member_card_templates  {
  my ($db, $action, $target, $intAssocID, $intRealmID) = @_;
  my $strWhere = '';
  if ($intAssocID) {
    $strWhere .= " AND " if $strWhere;
    $strWhere .= qq[intAssocID = $intAssocID];
  }
  if ($intRealmID) {
    $strWhere .= " AND " if $strWhere;
    $strWhere .= qq[intRealmID = $intRealmID];
  }
  $strWhere = "WHERE $strWhere" if $strWhere;
  my $statement = qq[
    SELECT
      *
    FROM
      tblMemberCardTemplates
    $strWhere
  ];
  my $query = $db->prepare($statement) or query_error($statement);
  $query->execute() or query_error($statement);
  my $count = 0;
  my $body = '';
  while (my $dref = $query->fetchrow_hashref()) {
    foreach my $key (keys %{$dref}) { if(!defined $dref->{$key})  {$dref->{$key}='';} }
    my $class = '';
    my $classborder = 'commentborder';
    if($count++%2 == 1) {
      $class = q[ class="commentshaded" ];
      $classborder = "commentbordershaded";
    }
    my $extralink = '';
    $body .= qq[
      <tr>
        <td class="$classborder">$dref->{intMemberCardTemplateID}</td>
        <td class="$classborder">$dref->{strMemberCardTemplateName}</td>
        <td class="$classborder">[<a $extralink href="$target?action=UTILS_MC_form_templates&amp;mcID=$dref->{intMemberCardTemplateID}">Edit</a>]</td>
      </tr>
    ];
  }
  if(!$body)  {
    $body .= qq[
    <p><a href="$target?action=UTILS_MC_form_templates">Add New Template</a></p>
    <table cellpadding="1" cellspacing="0" border="0" width="90%" align="center">
      <tr>
        <td colspan="3" align="center"><b><br> No Member Card Templates were found <br><br></b></td>
      </tr>
    </table>
    <br>
    ];
  }
  else {
    $body = qq[
    <p><a href="$target?action=UTILS_MC_form_templates">Add New Template</a></p>
    <table cellpadding="1" cellspacing="0" border="0" width="90%" align="center">
      $body
    </table>
    <br>
    ];
  }
  return $body;
}

sub member_card_form_template {
  my ($db, $action, $target, $intAssocID, $intRealmID, $mcID) = @_;
  my $fields = {};
  $action = "UTILS_MC_insert_template";
  my $btn_text = "Add";
  if ($mcID) {
    my $st_get_card = qq[
      SELECT
        *
      FROM
        tblMemberCardTemplates
      WHERE
        intMemberCardTemplateID = ?
    ];
    my $q = $db->prepare($st_get_card) or query_error($st_get_card);
    $q->execute($mcID) or query_error($st_get_card);
    $fields = $q->fetchrow_hashref();
    $action = "UTILS_MC_update_template";
    $btn_text = "Update";
  }
  my $menu = '';
  my $body = qq[
  <form action="$target" method=post>
    <table width="100%">
      <tr>
          <td class="formbg fieldlabel">Name:</td>
          <td class="formbg"><input type="text" name="strName" value="$fields->{'strMemberCardTemplateName'}"></td>
      </tr>
      <tr>
          <td class="formbg fieldlabel" valign="top">Template:</td>
          <td class="formbg"><textarea name="strMemberCard" cols="140" rows="50">$fields->{'strMemberCardTemplate'}</textarea></td>
      </tr>
      <tr>
        <td class="formbg" colspan="2" align="center"><br>
          <input type="hidden" name="mcID" value="$mcID">
          <input type=submit value="$btn_text Member Card Template"><br>
        </td>
      </tr>
    </table>
    <input type="hidden" name="action" value="$action">
  </form>
  ];
  return ($body, $menu);
}

sub update_member_card_template {
  my ($db, $action, $target, $intAssocID, $intRealmID, $mcID) = @_;
  my $strName = param('strName') || '';
  my $strMemberCard = param('strMemberCard') || '';
  my $st = qq[
    UPDATE
      tblMemberCardTemplates
    SET
      strMemberCardTemplateName= ?,
      strMemberCardTemplate = ?
    WHERE
      intMemberCardTemplateID = ?
    LIMIT 1
  ];
  my $q = $db->prepare($st);
  $q->execute(
      $strName,
      $strMemberCard,
      $mcID
  ) or query_error($st);
  return list_member_card_templates($db, $action, $target, 0, 0);
}

sub insert_member_card_template {
  my ($db, $action, $target, $intAssocID, $intRealmID) = @_;
  my $strName = param('strName') || '';
  my $strMemberCard = param('strMemberCard') || '';
  my $st = qq[
    INSERT INTO tblMemberCardTemplates (
      strMemberCardTemplateName,
      strMemberCardTemplate
    )
    VALUES (
      ?,
      ?
    )
  ];
  my $q = $db->prepare($st);
  $q->execute(
      $strName,
      $strMemberCard
  );
  return list_member_card_templates($db, $action, $target, 0, 0);
}


1;
