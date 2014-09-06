#
# $Header: svn://svn/SWM/trunk/web/admin/RealmAdmin.pm 11452 2014-05-01 04:51:31Z ppascoe $
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
require AdminCommon;

sub handle_realm {
  my($db, $action, $target) = @_;
  my $memberCardID_IN = param('mcID') || 0;
  my $assocID_IN = param('assocID') || 0;
  my $realmID_IN = param('realmID') || 0;
  my $body = '';
  my $menu = '';
  if($action eq 'REALM_SUBADD') {
		($body, $menu) = subrealm_form($db, $action, $target); 
  }
  elsif($action eq 'REALM_SUBinsert') {
		($body, $menu) = create_subrealm($db, $action, $target, $assocID_IN, $realmID_IN, $memberCardID_IN); 
  }
  elsif($action eq 'REALM_ADD') {
		($body, $menu) = realm_form($db, $action, $target); 
  }
  elsif($action eq 'REALM_insert') {
		($body, $menu) = create_realm($db, $action, $target, $assocID_IN, $realmID_IN, $memberCardID_IN); 
  }
  elsif($action eq 'REALM_CREATE_SQL') {
		($body, $menu) = create_sql_realm($db, $action, $target, $realmID_IN); 
  }
  else  {
    ($body, $menu) = list_realms($db, $action, $target);
  }
  return ($body, $menu);
}

# *********************SUBROUTINES BELOW****************************
sub list_realms {
  my ($db) = @_;
  
my $butid = AdminPageGen::get_business_unit_type();
my $realmid = AdminCommon::get_realmid();

#use Data::Dumper;
# simple procedural interface
# print Dumper($realmid);
  
my $statement = "";

if ($butid != $AdminCommon::BUSINESS_USER_TYPE_SPANZ) {
    $statement = qq[
   SELECT
      R.intRealmID,
      R.strRealmName,
      RST.intSubTypeID,
      RST.strSubTypeName
    FROM
      tblRealms AS R
      LEFT JOIN tblRealmSubTypes AS RST ON RST.intRealmID = R.intRealmID
      WHERE R.intBusinessUnitType = $butid
	  OR (R.intBusinessUnitType = $AdminCommon::BUSINESS_USER_TYPE_SPANZ AND RST.intBusinessUnitType = $butid)
    ORDER BY
      R.intRealmID, RST.strSubTypeName
  ];
}
elsif (undef == $realmid) {
    $statement = qq[
                SELECT
      R.intRealmID,
      R.strRealmName,
      RST.intSubTypeID,
      RST.strSubTypeName
    FROM
      tblRealms AS R
      LEFT JOIN tblRealmSubTypes AS RST ON (RST.intRealmID = R.intRealmID)
    ORDER BY
      R.intRealmID, RST.strSubTypeName
  ];
}
else
{
    $statement = qq[
                SELECT
      R.intRealmID,
      R.strRealmName,
      RST.intSubTypeID,
      RST.strSubTypeName
    FROM
      tblRealms AS R
      LEFT JOIN tblRealmSubTypes AS RST ON (RST.intRealmID = R.intRealmID)
      WHERE R.intRealmID IN ($realmid)
    ORDER BY
      R.intRealmID
  ];	
}

  my $query = $db->prepare($statement) or query_error($statement);
  $query->execute() or query_error($statement);
  my $count = 0;
  my $body = '';
  my $last_realm_name = '';
  my $hash_value = '';
  
  while(my $dref= $query->fetchrow_hashref()) {
    if ($last_realm_name eq $dref->{strRealmName}) {
      $dref->{strRealmName} = '';
    }
    else {
      $last_realm_name = $dref->{strRealmName};
    }
    my $class='';
    my $classborder='commentborder';
    if($count++%2==1) {
      $class=q[ class="commentshaded" ];
      $classborder="commentbordershaded";
    }
    
    my $pfx = '';
    my $sfx = '';
    
    if ($realmid) {
    	$pfx = '';
    	$sfx = '';
    }
    else {
    	$hash_value = AdminCommon::create_hash_qs($dref->{intRealmID},0,0,0);
        $pfx = "<a href=\"index.cgi?action=REALM_CREATE_SQL&realmID=$dref->{intRealmID}&hash=$hash_value\">";
    	$sfx = '</a>';
    }
        
    $body .= qq[
      <tr>
        <td class="$classborder">$dref->{strRealmName}</td>
              <td class="$classborder">$pfx$dref->{intRealmID}$sfx</td>
              <td class="$classborder">&nbsp;</td>
        <td class="$classborder">$dref->{strSubTypeName}</td>
              <td class="$classborder">$dref->{intSubTypeID}</td>
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

sub create_sql_realm {

	my ($db, $action, $target, $realmID_IN) = @_;
	my $body = '';
	my @tables = (
		'tblMember_Seasons_2',
		'tblPlayerCareerStats_2',
		'tblPlayerCompStats_2',
		'tblPlayerCompStats_ME_2',
		'tblPlayerCompStats_SG_2',
		'tblPlayerRoundStats_2',
		'tblResults_MatchActionLog_2', 
		'tblSnapShotEntityCounts_2',
	);
	my $createSQL = '';
	my $newItem = '';
	foreach my $item (@tables)
	{
	  $newItem = $item;
	  my $statement = qq[ SHOW CREATE TABLE $item  ];
	  my $query = $db->prepare($statement) or query_error($statement);
	  $query->execute() or query_error($statement);
	  $createSQL = $query->fetchrow_array();
	$newItem =~s/2/$realmID_IN/g; 
	 $createSQL =~ s/$item/$newItem/g;
	  $body .= '<pre>'.$createSQL.';</pre>';
	  $body .= "<pre>ALTER TABLE `$newItem` AUTO_INCREMENT = 1;</pre>";
	}
	return $body;
}


sub subrealm_form {
  my ($db, $action, $target) = @_;
	 my $st=qq[ SELECT intRealmID, strRealmName FROM tblRealms ORDER BY strRealmName];
        my $realms=getDBdrop_down('realmID',$db,$st,'','&nbsp;') || '';
	$realms =~ s/class = ""/class = "chzn-select"/g;
	my $body = qq[
	<form action="$target" method=post>
		<table width="100%">
			<tr>
					<td class="formbg fieldlabel">Realm Name:</td>
					<td class="formbg">$realms</td>
			</tr>
			<tr>
					<td class="formbg fieldlabel">Sub Realm Name:</td>
					<td class="formbg"><input type="text" name="strSubRealm" value=""></td>
			</tr>
      <tr>
        <td class="formbg" colspan="2" align="center"><br>
          <input type=submit value="Add Realm"><br>
        </td>
			</tr>
    </table>
    <input type="hidden" name="action" value="REALM_SUBinsert">
  </form>
  ];
	return ($body, '');
}
sub create_subrealm {
  my ($db, $action, $target) = @_;
  my $intRealmID = param('realmID') || '';
  my $strSubRealm = param('strSubRealm') || '';
  return qq[<p>No Realm Name passed in.</p>] unless($intRealmID);
  return qq[<p>No SubRealm passed in.</p>] unless($strSubRealm);
 
  my $st = qq[
    INSERT INTO tblRealmSubTypes (intRealmID,strSubTypeName) VALUES ( ? , ? );
  ];
  my $q = $db->prepare($st);
  $q->execute($intRealmID,$strSubRealm);
  return qq[Sub Realm $strSubRealm created];
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
    <input type="hidden" name="action" value="REALM_insert">
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
  my $st = qq[INSERT INTO tblRealms (intRealmID, strRealmName) VALUES (0,?)];
  my $q = $db->prepare($st);
  $q->execute($strName);
  my $intRealmID = $q->{'mysql_insertid'} or return qq[<p>Unable to get RealmID</p>];
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
  return create_sql_realm($db, $action, $target, $intRealmID);
}

1;
