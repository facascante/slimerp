#
# $Header: svn://svn/SWM/trunk/web/admin/SystemConfigAdmin.pm 9602 2013-09-25 06:42:39Z dhanslow $
#

package SystemConfigAdmin;

require Exporter;
@ISA =  qw(Exporter);
@EXPORT = qw(handle_system_config handle_defcodes_config);
@EXPORT_OK = qw(handle_system_config handle_defcodes_config);

use lib "..","../..","../sp_publisher";
use DBI;
use CGI qw(param unescape escape);
use strict;

use Defs;
use Utils;
use TechAdminCommon;
use DeQuote;
use FormHelpers;
use DefCodes;
sub handle_system_config {
  my($db, $action, $target) = @_;
  my $memberCardID_IN = param('mcID') || 0;
  my $realmID = param('realmID') || 0;
  my $subRealmID = param('subRealmID') || 0;
  my $body = '';
  my $menu = '';
  if ($action eq 'REALM_SC_list_sc') {
    ($body, $menu) = list_sc($db, $action, $target, $realmID, $subRealmID);
  }
  elsif ($action eq 'REALM_SC_edit_blob' or $action eq 'REALM_SC_add_blob') {
    ($body, $menu) = system_config_form_blob($db, $action, $target, $realmID, $subRealmID);
  }
  elsif ($action eq 'REALM_SC_edit' or $action eq 'REALM_SC_add') {
    ($body, $menu) = system_config_form($db, $action, $target, $realmID, $subRealmID);
  }
  elsif ($action eq 'REALM_SC_update_blob' or $action eq 'REALM_SC_insert_blob') {
    ($body, $menu) = system_config_update_blob($db, $action, $target, $realmID, $subRealmID);
  }
  elsif ($action eq 'REALM_SC_update' or $action eq 'REALM_SC_insert') {
    ($body, $menu) = system_config_update($db, $action, $target, $realmID, $subRealmID);
  }
  elsif ($action eq 'REALM_SC_delete') {
    ($body, $menu) = system_config_delete($db, $action, $target, $realmID, $subRealmID);
  }
  else  {
    ($body, $menu) = list_sc_form($db, $action, $target, $realmID, $subRealmID);
  }
  return ($body, $menu);
}

# *********************SUBROUTINES BELOW****************************

sub list_sc_form	{
  my ($db, $action, $target, $realmID, $subRealmID) = @_;
  my $strWhere = '';
  my $body = qq[
  <form action="$target" method=post>
    <table width="100%">
      <tr>
          <td class="formbg fieldlabel">Realm ID:</td>
          <td class="formbg"><input type="text" name="realmID" value=""></td>
      </tr>
      <tr>
          <td class="formbg fieldlabel">Sub Realm ID:</td>
          <td class="formbg"><input type="text" name="subRealmID" value="none"> (none = show all sub realms)</td>
      </tr>
      <tr>
        <td class="formbg" colspan="2" align="center"><br>
          <input type=submit value="Search"><br>
        </td>
			</tr>
    </table>
    <input type="hidden" name="action" value="REALM_SC_list_sc">
  </form>
  <br>
  ];
  return ($body, '');
}

sub list_sc {
  my ($db, $action, $target, $realmID, $subRealmID) = @_;
  my $body = '';
  my $subRealm_WHERE = ($subRealmID ne 'none') ? qq[AND intSubTypeID = $subRealmID] : '';
  my $st = qq[
    SELECT
      *,
      SUBSTRING(strValue,1,76) AS strValue30
    FROM
      tblSystemConfig
    WHERE
      intRealmID = ?
      $subRealm_WHERE
  ];
  my $q = $db->prepare($st);
  $q->execute($realmID);
  my $count = 0;
  while (my $dref = $q->fetchrow_hashref()) {
    my $class = '';
    my $classborder = 'commentborder';
    if($count++%2 == 1) {
      $class = q[ class="commentshaded" ];
      $classborder = "commentbordershaded";
    }
    $dref->{'strValue30'} = 'Click Edit to view ...' if ($dref->{'strOption'} eq 'Header');
    $dref->{'strValue30'} = 'Click Edit to view ...' if ($dref->{'strOption'} eq 'HeaderBG');
    $dref->{'strValue30'} = 'Click Edit to view ...' if ($dref->{'strOption'} eq 'AccredExpose');
    $body .= qq[
      <tr>
        <td $class>$dref->{'intSystemConfigID'}</td>
        <td $class>$dref->{'strOption'}</td>
        <td $class>$dref->{'strValue30'}</td>
        <td $class>$dref->{'intRealmID'} | $dref->{'intSubTypeID'}</td>
        <td $class>$dref->{'tTimeStamp'}</td>
        <td $class>
          <a href="$target?action=REALM_SC_edit&scID=$dref->{'intSystemConfigID'}&realmID=$realmID&subRealmID=$subRealmID">Edit</a> |
          <a href="$target?action=REALM_SC_delete&scID=$dref->{'intSystemConfigID'}&realmID=$realmID&subRealmID=$subRealmID">Delete</a> |
          <a href="$target?action=REALM_SC_edit_blob&scID=$dref->{'intSystemConfigID'}&realmID=$realmID&subRealmID=$subRealmID">Blob</a>
       </td>
      </tr>
    ];
  }
  $body = qq[
    <p><a href="$target?action=REALM_SC_add&realmID=$realmID&subRealmID=$subRealmID"><<< ADD NEW CONFIG >>></a></p>
    <table width="100%">
      <tr>
        <th style="text-align:left;"><b>ID</b></th>
        <th style="text-align:left;"><b>Option</b></th>
        <th style="text-align:left;"><b>Value</b></th>
        <th style="text-align:left;"><b>R | SR</b></th>
        <th style="text-align:left;"><b>Timestamp</b></th>
        <th style="text-align:left;">&nbsp;</th>
      </tr>
      $body
    </table>
  ];
  return ($body, '');
}

sub system_config_form {
  my ($db, $action, $target, $intRealmID, $intSubRealmID) = @_;
  my $scID = param('scID') || 0;
  my $fields = {};
  $action = 'REALM_SC_insert';
  if ($scID) {
    my $st = qq[
      SELECT
        *
      FROM
        tblSystemConfig
      WHERE
        intSystemConfigID = ?
    ];
    my $q = $db->prepare($st);
    $q->execute($scID);
    $fields = $q->fetchrow_hashref();
    $action = 'REALM_SC_update';
  }
  $intRealmID = $fields->{'intRealmID'} if $fields->{'intRealmID'};
  $intSubRealmID = $fields->{'intSubTypeID'} if $fields->{'intSubTypeID'};
  $intSubRealmID = 0 if $intSubRealmID eq 'none';
  my $ddl = systemConfigDDL($db, $fields->{'strOption'});
  $fields->{'intSystemConfigID'} ||= 'New';
	$ddl =~ s/name='strOption'/name='strOption' class = "chzn-select"/g;
	my $body = qq[
	<form action="$target" method=post>
		<table width="100%">
			<tr>
					<td class="formbg fieldlabel">ID</td>
					<td class="formbg">$fields->{'intSystemConfigID'}</td>
			</tr>
			<tr>
					<td class="formbg fieldlabel">Option:</td>
					<td class="formbg">$ddl</td>
			</tr>
			<tr>
					<td class="formbg fieldlabel">Value:</td>
					<td class="formbg"><input type="text" name="strValue" size="100" value='$fields->{'strValue'}'></td>
			</tr>
			<tr>
					<td class="formbg fieldlabel">Realm:</td>
					<td class="formbg"><input type="text" name="realmID" size="10" value='$intRealmID'></td>
			</tr>
			<tr>
					<td class="formbg fieldlabel">Sub Realm:</td>
					<td class="formbg"><input type="text" name="subRealmID" size="10" value='$intSubRealmID'></td>
			</tr>
      <tr>
        <td class="formbg" colspan="2" align="center"><br>
          <input type=submit value="Submit"><br>
        </td>
			</tr>
    </table>
    <input type="hidden" name="action" value="$action">
    <input type="hidden" name="scID" value="$scID">
  </form>
  ];
	return ($body, '');
}
sub system_config_form_blob {
  my ($db, $action, $target, $intRealmID, $intSubRealmID) = @_;
  my $scID = param('scID') || 0;
  my $fields = {};
  $action = 'REALM_SC_insert_blob';
  if ($scID) {
    my $st = qq[
      SELECT
        B.*, S.intSystemConfigID
      FROM
	tblSystemConfig S
	LEFT JOIN tblSystemConfigBlob B ON (S.intSystemConfigID = B.intSystemConfigID)
      WHERE
        S.intSystemConfigID = ?
    ];
    my $q = $db->prepare($st);
    $q->execute($scID);
    $fields = $q->fetchrow_hashref();
    $action = 'REALM_SC_update_blob';
  }
	my $body = qq[
	<form action="$target" method=post>
		<table width="100%">
			<tr>
					<td class="formbg fieldlabel">ID</td>
					<td class="formbg">$fields->{'intSystemConfigID'}</td>
			</tr>
			<tr>
					<td class="formbg fieldlabel">Value:</td>
					<td class="formbg"><textarea cols=100 rows=10 type="text" name="strValue">$fields->{'strBlob'}</textarea></td>
					<input type="hidden" name="realmID" size="10" value='$intRealmID'></td>
					<input type="hidden" name="subRealmID" size="10" value='$intSubRealmID'></td>
			</tr>
      <tr>
        <td class="formbg" colspan="2" align="center"><br>
          <input type=submit value="Submit"><br>
        </td>
			</tr>
    </table>
    <input type="hidden" name="action" value="$action">
    <input type="hidden" name="scID" value="$scID">
  </form>
  ];
	return ($body, '');
}

sub system_config_update_blob {
  my ($db, $action, $target, $intRealmID, $intSubRealmID) = @_;
  my $strValue = param('strValue') || '';
  my $scID = param('scID') || '';
  if ($scID) {
    my $st = qq[
      INSERT INTO
        tblSystemConfigBlob
      SET
        intSystemConfigID = ?,
        strBlob = ?
      ON DUPLICATE KEY UPDATE
	strBlob = ?
    ];
    my $q = $db->prepare($st);
    $q->execute($scID, $strValue, $strValue);
  }
  return list_sc($db, $action, $target, $intRealmID, $intSubRealmID);
}

sub system_config_update {
  my ($db, $action, $target, $intRealmID, $intSubRealmID) = @_;
  my $strOption = param('strOption') || '';
  my $strValue = param('strValue') || '';
  $intSubRealmID = 0 if ($intSubRealmID eq 'none');
  my $scID = param('scID') || '';
  if ($scID) {
    my $st = qq[
      UPDATE 
        tblSystemConfig
      SET
        strOption = ?,
        strValue = ?
      WHERE
        intSystemConfigID = ?
    ];
    my $q = $db->prepare($st);
    $q->execute($strOption, $strValue, $scID);
  }
  else {
    my $st = qq[
      INSERT INTO tblSystemConfig (
        intTypeID,
        strOption,
        strValue,
        intRealmID,
        intSubTypeID
      )
      VALUES (
        1,
        ?,
        ?,
        ?,
        ?
      )
    ];
    my $q = $db->prepare($st);
    $q->execute($strOption, $strValue, $intRealmID, $intSubRealmID);
  }
  return list_sc($db, $action, $target, $intRealmID, $intSubRealmID);
}

sub system_config_delete {
  my ($db, $action, $target, $intRealmID, $intSubRealmID) = @_;
  my $scID = param('scID') || '';
  my $st = qq[
    DELETE FROM tblSystemConfig WHERE intSystemConfigID = ? LIMIT 1
  ];
  my $q = $db->prepare($st);
  $q->execute($scID);
  return list_sc($db, $action, $target, $intRealmID, $intSubRealmID);
}

sub systemConfigDDL {
  my ($db, $option) = @_;
  my $st = qq[
    SELECT
      DISTINCT strOption
    FROM
      tblSystemConfig
    WHERE strOption <> ''
];
  my $q = $db->prepare($st);
  $q->execute();
  my $ddl = qq[];
  while (my $value = $q->fetchrow_array()) {
    my $checked = ($value eq $option) ? qq[SELECTED] : '';
    $ddl .= qq[<option $checked>$value</option>];
  }
  return qq[<select name='strOption'><option></option>$ddl</select>];
}





sub handle_defcodes_config {
  my($db, $action, $target) = @_;
  my $memberCardID_IN = param('mcID') || 0;
  my $realmID = param('realmID') || 0;
  my $subRealmID = param('subRealmID') || 0;
  my $assocID = param('assocID') || 0;
  my $intType = param('intType') || 0;
  my $body = '';
  my $menu = '';
  if ($action eq 'REALM_DC_list_dc') {
    ($body, $menu) = list_dc($db, $action, $target, $realmID, $subRealmID, $assocID, $intType);
  }
  elsif ($action eq 'REALM_DC_edit' or $action eq 'REALM_DC_add') {
    ($body, $menu) = system_defcode_form($db, $action, $target, $realmID, $subRealmID, $assocID, $intType);
  }
  elsif ($action eq 'REALM_DC_update' or $action eq 'REALM_DC_insert') {
    ($body, $menu) = system_defcode_update($db, $action, $target, $realmID, $subRealmID, $assocID, $intType);
  }
  elsif ($action eq 'REALM_DC_delete') {
    ($body, $menu) = system_defcode_delete($db, $action, $target, $realmID, $subRealmID, $assocID, $intType);
  }
  else {
    ($body, $menu) = list_dc_form($db, $action, $target, $realmID, $subRealmID,$assocID, $intType);
  }
  return ($body, $menu);
}

# *********************SUBROUTINES BELOW****************************

sub list_dc_form	{
  my ($db, $action, $target, $realmID, $subRealmID, $assocID, $intType) = @_;
  my $strWhere = '';
  
 my $ddl = defCodesDDL($db, $intType);
  my $body = qq[
  <form action="$target" method=post>
    <table width="100%">
      <tr>
          <td class="formbg fieldlabel">Realm ID:</td>
          <td class="formbg"><input type="text" name="realmID" value=""></td>
      </tr>
      <tr>
          <td class="formbg fieldlabel">Sub Realm ID:</td>
          <td class="formbg"><input type="text" name="subRealmID" value="none"> (none = show all sub realms)</td>
      </tr>
      <tr>
          <td class="formbg fieldlabel">Assoc ID:</td>
          <td class="formbg"><input type="text" name="assocID" value="none"> (none = show all defcodes)</td>
      </tr>
      <tr>
          <td class="formbg fieldlabel">DefCode:</td>
          <td class="formbg">$ddl</td>
      </tr>
      <tr>
        <td class="formbg" colspan="2" align="center"><br>
          <input type=submit value="Search"><br>
        </td>
			</tr>
    </table>
    <input type="hidden" name="action" value="REALM_DC_list_dc">
  </form>
  <br>
  ];
  return ($body, '');
}

sub list_dc {
  my ($db, $action, $target, $realmID, $subRealmID, $assocID, $intType) = @_;
  my $body = '';
  my %DefCodeTypes = getDefCodesTypes();
  my $subRealm_WHERE = ($subRealmID ne 'none') ? qq[AND intSubTypeID = $subRealmID] : '';
  my $assoc_WHERE = ($assocID ne 'none') ? qq[AND intAssocID = $assocID] : '';
  my $st = qq[
    SELECT
      *
    FROM
      tblDefCodes
    WHERE
      intRealmID = ? AND
      intType = ?
      $subRealm_WHERE
      $assoc_WHERE
  ];
print STDERR $st."|".$realmID."|".$intType;
  my $q = $db->prepare($st);
  $q->execute($realmID, $intType);
  my $count = 0;
  while (my $dref = $q->fetchrow_hashref()) {
    my $class = '';
    my $classborder = 'commentborder';
    if($count++%2 == 1) {
      $class = q[ class="commentshaded" ];
      $classborder = "commentbordershaded";
    }
my $delete_code='';
  if($dref->{intRecStatus}<=0)
	{
$delete_code = '&status=1';
$class = 'style=background-color:red;';
	 }
    $body .= qq[
      <tr>
        <td $class>$dref->{'intCodeID'}</td>
        <td $class>$DefCodeTypes{$dref->{'intType'}} ($dref->{'intType'})</td>
        <td $class>$dref->{'strName'}</td>
        <td $class>$dref->{'intRealmID'} | $dref->{'intSubTypeID'} | $dref->{'intAssocID'} </td>
        <td $class>$dref->{'tTimeStamp'}</td>
        <td $class>
          <a href="$target?action=REALM_DC_edit&dcID=$dref->{'intCodeID'}&realmID=$realmID&subRealmID=$subRealmID&assocID=$assocID&intType=$dref->{'intType'}">Edit</a> |
          <a href="$target?action=REALM_DC_delete&dcID=$dref->{'intCodeID'}&realmID=$realmID&subRealmID=$subRealmID&assocID=$assocID&$delete_code&intType=$dref->{'intType'}">Delete</a>
       </td>
      </tr>
    ];
  }
  $body = qq[
    <p><a href="$target?action=REALM_DC_add&realmID=$realmID&subRealmID=$subRealmID&assocID=$assocID"><<< ADD NEW CONFIG >>></a></p>
    <table width="100%">
      <tr>
        <th style="text-align:left;"><b>ID</b></th>
        <th style="text-align:left;"><b>Type</b></th>
        <th style="text-align:left;"><b>Name</b></th>
        <th style="text-align:left;"><b>R | SR | A</b></th>
        <th style="text-align:left;"><b>Timestamp</b></th>
        <th style="text-align:left;">&nbsp;</th>
      </tr>
      $body
    </table>
  ];
  return ($body, '');
}

sub system_defcode_form {
  my ($db, $action, $target, $intRealmID, $intSubRealmID, $intAssocID, $intType) = @_;
  my $dcID = param('dcID') || 0;
  my $fields = {};
  $action = 'REALM_DC_insert';
  if ($dcID) {
    my $st = qq[
      SELECT
        *
      FROM
        tblDefCodes
      WHERE
        intCodeID = ?
    ];
    my $q = $db->prepare($st);
    $q->execute($dcID);
print STDERR qq[\n\n $st $dcID \n\n];
    $fields = $q->fetchrow_hashref();
    $action = 'REALM_DC_update';
  }
  $intRealmID = $fields->{'intRealmID'} if $fields->{'intRealmID'};
  $intSubRealmID = $fields->{'intSubTypeID'} if $fields->{'intSubTypeID'};
  $intAssocID = $fields->{'intAssocID'} if $fields->{'intAssocID'};
  my $ddl = defCodesDDL($db, $fields->{'intType'});
  $fields->{'intSystemConfigID'} ||= 'New';
	my $body = qq[
	<form action="$target" method=post>
		<table width="100%">
			<tr>
					<td class="formbg fieldlabel">ID</td>
					<td class="formbg">$fields->{'intCodeID'}</td>
			</tr>
			<tr>
					<td class="formbg fieldlabel">Type:</td>
					<td class="formbg">$ddl</td>
			</tr>
			<tr>
					<td class="formbg fieldlabel">Name:</td>
					<td class="formbg"><input type="text" name="strName" size="100" value='$fields->{'strName'}'></td>
			</tr>
			<tr>
					<td class="formbg fieldlabel">Realm:</td>
					<td class="formbg"><input type="text" name="realmID" size="10" value='$intRealmID'></td>
			</tr>
			<tr>
					<td class="formbg fieldlabel">Sub Realm:</td>
					<td class="formbg"><input type="text" name="subRealmID" size="10" value='$fields->{intSubTypeID}'></td>
			</tr>
			<tr>
					<td class="formbg fieldlabel">Assoc:</td>
					<td class="formbg"><input type="text" name="assocID" size="10" value='$intAssocID'></td>
			</tr>
      <tr>
        <td class="formbg" colspan="2" align="center"><br>
          <input type=submit value="Submit"><br>
        </td>
			</tr>
    </table>
    <input type="hidden" name="action" value="$action">
    <input type="hidden" name="dcID" value="$dcID">
  </form>
  ];
	return ($body, '');
}

sub system_defcode_update {
  my ($db, $action, $target, $intRealmID, $intSubRealmID, $intAssocID, $intType) = @_;
  $intType = param('intType') || '';
  my $strName = param('strName') || '';
  $intSubRealmID = 0 if ($intSubRealmID eq 'none');
  $intAssocID = 0 if($intAssocID eq 'none');

  my $dcID = param('dcID') || '';
	print STDERR $dcID;
  if ($dcID) {
    my $st = qq[
      UPDATE 
        tblDefCodes
      SET
        intType = ?,
        strName = ?
      WHERE
        intCodeID = ?
    ];
    my $q = $db->prepare($st);
    $q->execute($intType, $strName, $dcID);
  }
  else {
    my $st = qq[
      INSERT INTO tblDefCodes (
        intType,
        strName,
        intRealmID,
        intSubTypeID,
   	intAssocID  
    )
      VALUES (
        ?,
        ?,
        ?,
        ?,
	?
      )
    ];
    my $q = $db->prepare($st);
    $q->execute($intType, $strName, $intRealmID, $intSubRealmID, $intAssocID);
  }
  return list_dc($db, $action, $target, $intRealmID, $intSubRealmID, $intAssocID, $intType);
}

sub system_defcode_delete {
  my ($db, $action, $target, $intRealmID, $intSubRealmID, $intAssocID, $intType) = @_;
  my $dcID = param('dcID') || '';
  my $dcSTATUS = param('status') || -1;

my $st = qq[
    UPDATE tblDefCodes SET intRecStatus = $dcSTATUS  WHERE intCodeID = ? LIMIT 1
  ];
print STDERR"\n\n".$st."\n\n";
  my $q = $db->prepare($st);
  $q->execute($dcID);
  return list_dc($db, $action, $target, $intRealmID, $intSubRealmID, $intAssocID,$intType);
}




sub defCodesDDL {
  my ($db, $option) = @_;
  my %DefCodeTypes = getDefCodesTypes();
$DefCodeTypes{-2} =  'Discliplines';
$DefCodeTypes{-13} = 'Tribunal Offence Types';
$DefCodeTypes{-18} = 'Coach Types';
$DefCodeTypes{-19} = 'Discipline Types';
$DefCodeTypes{-92} = 'Other 1 Official Types'; #(SWC ONLY)
$DefCodeTypes{-93} = 'Other 2 Official Types';#(SWC ONLY)
$DefCodeTypes{-53} = 'National Custom Lookup 1'; # Not Editable
$DefCodeTypes{-54} = 'National Custom Lookup 2'; # Not Editable
$DefCodeTypes{-55} = 'National Custom Lookup 3'; # Not Editable
$DefCodeTypes{-64} = 'National Custom Lookup 4'; # Not Editable
$DefCodeTypes{-65} = 'National Custom Lookup 5'; # Not Editable
$DefCodeTypes{-66} = 'National Custom Lookup 6'; # Not Editable
$DefCodeTypes{-67} = 'National Custom Lookup 7'; # Not Editable
$DefCodeTypes{-68} = 'National Custom Lookup 8'; # Not Editable
$DefCodeTypes{-69} = 'National Custom Lookup 9'; # Not Editable
$DefCodeTypes{-70} = 'National Custom Lookup 10'; # Not Editable
  my $st = qq[
    SELECT
      DISTINCT strOption
    FROM
      tblSystemConfig
  WHERE strOption <> ''];
  my $q = $db->prepare($st);
  $q->execute();
  my $ddl = qq[];
foreach my $key (sort {$DefCodeTypes{$a} cmp $DefCodeTypes{$b} }
           keys %DefCodeTypes) {
    my $checked = ($key eq $option) ? qq[selected='selected'] : '';
    $ddl .= qq[<option $checked value='$key'>$DefCodeTypes{$key} ($key)</option>\n];
}



#  while (my ($key, $value) = sort keys each(%DefCodeTypes)) {
#    my $checked = ($key eq $option) ? qq[SELECTED] : '';
#    $ddl .= qq[<option $checked value='$key'>($key) $value</option>];
  return qq[<select name='intType' class="chzn-select"><option></option>$ddl</select>];
}

