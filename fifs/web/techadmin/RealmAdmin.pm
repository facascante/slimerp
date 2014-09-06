#
# $Header: svn://svn/SWM/trunk/web/techadmin/RealmAdmin.pm 10771 2014-02-21 00:20:57Z cgao $
#

package RealmAdmin;

require Exporter;
@ISA =  qw(Exporter);
@EXPORT = qw(handle_realm);
@EXPORT_OK = qw(handle_realm);

use lib "..","../..","../sp_publisher";
use DBI;
use CGI qw(param unescape escape);
use strict;

use Defs;
use Utils;
use TechAdminCommon;
use DeQuote;
use FormHelpers;

sub handle_realm {
  my($db, $action, $target) = @_;
  my $memberCardID_IN = param('mcID') || 0;
  my $assocID_IN = param('assocID') || 0;
  my $realmID_IN = param('realmID') || 0;
  my $body = '';
  my $menu = '';
  if($action eq 'R_new') {
		($body, $menu) = realm_form($db, $action, $target); 
  }
  elsif($action eq 'R_insert') {
		($body, $menu) = create_realm($db, $action, $target, $assocID_IN, $realmID_IN, $memberCardID_IN); 
  }
  else  {
    ($body, $menu) = list_realms($db, $action, $target);
  }
  return ($body, $menu);
}

# *********************SUBROUTINES BELOW****************************

sub list_realms	{
  my ($db, $action, $target) = @_;
  my $strWhere = '';
  my $statement = qq[
		SELECT 
      *
    FROM
      tblRealms
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
        <td class="$classborder">$dref->{intRealmID}</td>
        <td class="$classborder">$dref->{strRealmName}</td>
      </tr>
    ];
  }
  if(!$body)  {
    $body .= qq[
    <table cellpadding="1" cellspacing="0" border="0" width="90%" align="center">
      <tr>
				<td colspan="3" align="center"><b><br> No Realms were found <br><br></b></td>
      </tr>
    </table>
    <br>
    ];
  }
  else  {
    $body = qq[
    <p>[<a href="$target?action=R_new">Add New Realm</a>]</p>
		 <table cellpadding="1" cellspacing="0" border="0" width="95%" align="center">
			<tr>
        <th style="text-align:left;">ID</th>
        <th style="text-align:left;">Name</th>
      </tr>
      $body
    </table><br>
    ];
  }
  return ($body, '');
}

sub realm_form {
  my ($db, $action, $target) = @_;
	my $body = qq[
	<form action="$target" method=post>
		<table width="100%">
			<tr>
					<td class="formbg fieldlabel">Realm Name:</td>
					<td class="formbg"><input type="text" name="strRealmName" value=""></td>
			</tr>
			<tr>
					<td class="formbg fieldlabel">Default Season Name:</td>
					<td class="formbg"><input type="text" name="strDefaultSeasonName" value="2011"></td>
			</tr>
      <tr>
        <td class="formbg" colspan="2" align="center"><br>
          <input type=submit value="Add Realm"><br>
        </td>
			</tr>
    </table>
    <input type="hidden" name="action" value="R_insert">
  </form>
  ];
	return ($body, '');
}

sub create_realm {
  my ($db, $action, $target) = @_;
  my $strName = param('strRealmName') || '';
  my $strDefaultSeasonName = param('strDefaultSeasonName') || '';
  return qq[<p>No Realm Name passed in.</p>] unless($strName);
  return qq[<p>No Default Season Name passed in.</p>] unless($strDefaultSeasonName);
  my $st = qq[INSERT INTO tblRealms VALUES (0,?)];
  my $q = $db->prepare($st);
  $q->execute($strName);
  my $intRealmID = $q->{'mysql_insertid'} or return qq[<p>Unable to get RealmID</p>];
  $st = qq[
    CREATE TABLE tblMember_Seasons_$intRealmID (
      intMemberSeasonID         int(11) NOT NULL auto_increment,
      intMemberID               int(11) NOT  NULL default '0',
      intAssocID                int(11) NOT NULL default '0',
      intClubID                 int(11) NOT NULL default '0',
      intSeasonID               int(11) NOT NULL default '0',
      intMSRecStatus            tinyint NOT NULL DEFAULT 1,
      intSeasonMemberPackageID  int(11) default '0',
      intPlayerAgeGroupID       int(11) default '0',
      intPlayerStatus           tinyint(4) default '0',
      intPlayerFinancialStatus  tinyint(4) default '0',
      intCoachStatus            tinyint(4) default '0',
      intCoachFinancialStatus   tinyint(4) default '0',
      intUmpireStatus           tinyint(4) default '0',
      intUmpireFinancialStatus  tinyint(4) default '0',
      intMiscStatus             tinyint(4) default '0',
      intMiscFinancialStatus    tinyint(4) default '0',
      intVolunteerStatus          tinyint(4) default '0',
      intVolunteerFinancialStatus tinyint(4) default '0',
      intOther1Status           tinyint(4) default '0',
      intOther1FinancialStatus  tinyint(4) default '0',
      intOther2Status           tinyint(4) default '0',
      intOther2FinancialStatus  tinyint(4) default '0',
      dtInPlayer                DATE, -- Date Registered
      dtOutPlayer               DATE, -- Date Registered
      dtInCoach                 DATE, -- Date Registered
      dtOutCoach                DATE, -- Date Registered
      dtInUmpire                DATE, -- Date Registered
      dtOutUmpire               DATE, -- Date Registered
      dtInMisc                  DATE, -- Date Registered
      dtOutMisc                 DATE, -- Date Registered
      dtInVolunteer             DATE, -- Date Registered
      dtOutVolunteer            DATE, -- Date Registered
      dtInOther1                DATE, -- Date Registered
      dtOutOther1               DATE, -- Date Registered
      dtInOther2                DATE, -- Date Registered
      dtOutOther2               DATE, -- Date Registered
      intUsedRegoForm           TINYINT DEFAULT 0, 
      dtLastUsedRegoForm        datetime, 
      intUsedRegoFormID         INT DEFAULT 0,
      tTimeStamp                timestamp NOT NULL default CURRENT_TIMESTAMP on update CURRENT_TIMESTAMP,
      PRIMARY KEY               (intMemberSeasonID),
      UNIQUE KEY index_intIDs   (intMemberID, intAssocID, intSeasonID, intClubID),
      KEY index_intMAs (intMemberID, intClubID, intAssocID),
      KEY index_intSeasonID (intSeasonID),
      KEY index_intMSRecStatus (intMSRecStatus),
      KEY index_intAssocID (intAssocID),
      KEY index_intClubID (intClubID)
    );
  ];
  $q = $db->prepare($st);
  $q->execute();
  $st = qq[
    INSERT INTO tblSeasons (
      intRealmID, 
      strSeasonName, 
      dtAdded
    )
    VALUES (
      ?,
      ?,
      now()
    )
  ];
  $q = $db->prepare($st);
  $q->execute($intRealmID, $strDefaultSeasonName);
  my $intSeasonID = $q->{'mysql_insertid'} or return qq[<p>Unable to get SeasonID</p>];
  $st = qq[
    INSERT INTO tblSystemConfig VALUES (
      0,
      1,
      ?,
      ?,
      now(),
      ?,
      0
    )
  ];
  $q = $db->prepare($st);
  $q->execute(
    'Seasons_defaultCurrentSeason',
    $intSeasonID,
    $intRealmID
  );
  $q->execute(
    'Seasons_defaultNewRegoSeason',
    $intSeasonID,
    $intRealmID
  );
  $q->execute(
    'Seasons_DefaultID',
    $intSeasonID,
    $intRealmID
  );
  $q->execute(
    'AllowSeasons',
    1,
    $intRealmID
  );
  return list_realms($db, $action, $target);
}

1;
