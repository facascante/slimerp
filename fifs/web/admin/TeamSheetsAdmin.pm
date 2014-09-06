#
# $Header: svn://svn/SWM/trunk/web/admin/TeamSheetsAdmin.pm 8252 2013-04-08 23:42:17Z fkhezri $
#

package TeamSheetsAdmin;

require Exporter;
@ISA =  qw(Exporter);
@EXPORT = qw(handle_teamsheets);
@EXPORT_OK = qw(handle_teamsheets);

use lib "..","../..","../sp_publisher";
use DBI;
use CGI qw(param unescape escape);
use strict;

use Defs;
use Utils;
use TechAdminCommon;
use DeQuote;
use FormHelpers;

sub handle_teamsheets {
  my($db, $action, $target) = @_;
  my $teamsheetID_IN = param('mcID') || 0;
  my $body = '';
  my $menu = '';
  $action = substr $action, 6;
  if ($action eq 'TS_form') {
		($body, $menu) = team_sheet_form($db, $action, $target, $teamsheetID_IN); 
  }
  elsif ($action eq 'TS_update') {
		($body, $menu) = update_team_sheet($db, $action, $target, $teamsheetID_IN); 
  }
  elsif ($action eq 'TS_insert') {
                ($body, $menu) = insert_team_sheet($db, $action, $target, $teamsheetID_IN);
  }
  else  {
    ($body, $menu) = list_team_sheet($db, $action, $target);
  }
  return ($body, $menu);
}

# *********************SUBROUTINES BELOW****************************

sub list_team_sheet	{
  my ($db, $action, $target) = @_;
  my $strWhere = '';
  my $statement = qq[
	SELECT *
    FROM  tblTeamSheets
    ORDER BY
      strName, strFilename
  ];
  my $query = $db->prepare($statement) or query_error($statement);
  $query->execute() or query_error($statement);
  my $count = 0;
  my $body = '';
  my $realm_name = '';
  $body .= qq[<tr>
        <td>ID</td>
        <td>Name</td>
        <td>Number of Teams</td>
        <td>File name</td>
        <td>Edit</td>
      </tr>];
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
        <td class="$classborder">$dref->{intTeamSheetID}</td>
        <td class="$classborder">$dref->{strName}</td>
        <td class="$classborder">$dref->{intNumTeams}</td>
	<td class="$classborder">$dref->{strFilename}</td>
        <td class="$classborder">[<a $extralink href="$target?action=UTILS_TS_form&amp;mcID=$dref->{intTeamSheetID}">Edit</a>]</td>
      </tr>
    ];
  }
  if(!$body)  {
    $body .= qq[
    <table cellpadding="1" cellspacing="0" border="0" width="90%" align="center">
      <tr>
				<td colspan="3" align="center"><b><br> No Team Sheet Templates were found <br><br></b></td>
      </tr>
    </table>
    <br>
    ];
  }
  else  {
    $body = qq[
    <p><a href="$target?action=UTILS_TS_form">Add New Team Sheet</a></p>
		 <table cellpadding="1" cellspacing="0" border="0" width="95%" align="center">
      $body
    </table><br>
    ];
  }
  return ($body, '');
}

sub team_sheet_form {
  my ($db, $action, $target, $mcID) = @_;
	my $fields = {};
  $action = "UTILS_TS_insert";
  my $btn_text = "Add";
  if ($mcID) {
    my $st_get_card = qq[
      SELECT
        *
      FROM
        tblTeamSheets
      WHERE
        intTeamSheetID = ?
    ];
    my $q = $db->prepare($st_get_card) or query_error($st_get_card);
    $q->execute($mcID) or query_error($st_get_card);
    $fields = $q->fetchrow_hashref();
    $action = "UTILS_TS_update";
    $btn_text = "Update";
  }
  $fields->{'strName'} ||= '';
  $fields->{'strFilename'} ||= '';
	my $menu = '';
	my $body = qq[
	<form action="$target" method=post>
		<table width="100%">
			<tr>
					<td class="formbg fieldlabel">Name:</td>
					<td class="formbg"><input type="text" name="strName" value="$fields->{'strName'}"></td>
			</tr>
      <tr>
          <td class="formbg fieldlabel">Filename:</td>
          <td class="formbg"><input type="text" name="strFilename" value="$fields->{'strFilename'}"></td>
      <tr>
          <td class="formbg fieldlabel">Number of Teams:</td>
          <td class="formbg"><input type="text" name="intNumTeams" value="$fields->{'intNumTeams'}"></td>
      </tr>
	<tr>
          <td class="formbg fieldlabel"></td>
          <td class="formbg" style ="color:red">*Number of Teams Appear in TeamSheet</td>
      </tr>
      <tr>
          <td class="formbg fieldlabel">Description:</td>
      <td class="formbg"><input type="text" name="strDescription" value="$fields->{'strDescription'}"></td>
      </tr>

      <tr>
        <td class="formbg" colspan="2" align="center"><br>
          <input type="hidden" name="mcID" value="$mcID">
          <input type=submit value="$btn_text Team Sheet Template"><br>
        </td>
			</tr>
    </table>
    <input type="hidden" name="action" value="$action">
  </form>
  ];
	return ($body, $menu);
}

sub update_team_sheet {
  my ($db, $action, $target, $mcID) = @_;
  my $strName = param('strName') || '';
  my $strFilename = param('strFilename') || '';
  my $intNumTeams = param('intNumTeams') || '';
  my $strDescription = param('strDescription') || '';
  my $st = qq[
    UPDATE 
      tblTeamSheets
    SET
      strName = ?,
      strFilename = ?,
      intNumTeams =?,
      strDescription =?
    WHERE
      intTeamSheetID = ?
    LIMIT 1
  ];
  my $q = $db->prepare($st);
  $q->execute(
      $strName,
      $strFilename,
      $intNumTeams,
      $strDescription,
      $mcID
  ) or query_error($st);
  return list_team_sheet($db, $action, $target);
}

sub insert_team_sheet {
  my ($db, $action, $target) = @_;
  my $strName = param('strName') || '';
  my $strFilename = param('strFilename') || '';
  my $intNumTeams = param('intNumTeams') || '';
  my $strDescription = param('strDescription') || '';
  my $st = qq[
    INSERT INTO tblTeamSheets (
      strName,
      strFilename,
	  intNumTeams,
	  strDescription
	)
    VALUES (
      ?,
      ?,
	  ?,
	  ?
    )
  ];
  my $q = $db->prepare($st);
  $q->execute(
      $strName,
      $strFilename,
 	  $intNumTeams,
	  $strDescription
  );
  return list_team_sheet($db, $action);
}
1;
