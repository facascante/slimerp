#
# $Header: svn://svn/SWM/trunk/web/techadmin/SystemConfigAdmin.pm 10107 2013-12-03 01:30:08Z tcourt $
#

package SystemConfigAdmin;

require Exporter;
@ISA =  qw(Exporter);
@EXPORT = qw(handle_system_config);
@EXPORT_OK = qw(handle_system_config);

use lib "..","../..","../sp_publisher";
use DBI;
use CGI qw(param unescape escape);
use strict;

use Defs;
use Utils;
use TechAdminCommon;
use DeQuote;
use FormHelpers;

sub handle_system_config {
  my($db, $action, $target) = @_;
  my $memberCardID_IN = param('mcID') || 0;
  my $realmID = param('realmID') || 0;
  my $subRealmID = param('subRealmID') || 0;
  my $body = '';
  my $menu = '';
  if ($action eq 'SC_list_sc') {
    ($body, $menu) = list_sc($db, $action, $target, $realmID, $subRealmID);
  }
  elsif ($action eq 'SC_edit' or $action eq 'SC_add') {
    ($body, $menu) = system_config_form($db, $action, $target, $realmID, $subRealmID);
  }
  elsif ($action eq 'SC_update' or $action eq 'SC_insert') {
    ($body, $menu) = system_config_update($db, $action, $target, $realmID, $subRealmID);
  }
  elsif ($action eq 'SC_delete') {
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
    <input type="hidden" name="action" value="SC_list_sc">
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
          <a href="$target?action=SC_edit&scID=$dref->{'intSystemConfigID'}&realmID=$realmID&subRealmID=$subRealmID">Edit</a> |
          <a href="$target?action=SC_delete&scID=$dref->{'intSystemConfigID'}&realmID=$realmID&subRealmID=$subRealmID">Delete</a>
       </td>
      </tr>
    ];
  }
  $body = qq[
    <p><a href="$target?action=SC_add&realmID=$realmID&subRealmID=$subRealmID"><<< ADD NEW CONFIG >>></a></p>
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
  $action = 'SC_insert';
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
    $action = 'SC_update';
  }
  $intRealmID = $fields->{'intRealmID'} if $fields->{'intRealmID'};
  $intSubRealmID = $fields->{'intSubTypeID'} if $fields->{'intSubTypeID'};
  $intSubRealmID = 0 if $intSubRealmID eq 'none';
  my $ddl = systemConfigDDL($db, $fields->{'strOption'});
  $fields->{'intSystemConfigID'} ||= 'New';
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

1;
