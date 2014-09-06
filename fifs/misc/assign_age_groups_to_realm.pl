#!/usr/bin/perl -w

#
# $Header: svn://svn/SWM/trunk/misc/assign_age_groups_to_realm.pl 11459 2014-05-01 06:40:30Z fkhezri $
#

use lib "../web","..";
use Defs;
use Utils;
use DBI;
use strict;
use GenAgeGroup;
use SystemConfig;

my $realm = 13;
my $season = 7220 ;
my $assoc = " AND intAssocID  = 12317 ";

my %Data = ();
my $db = connectDB();
$Data{'db'} = $db;
$Data{'Realm'} = $realm;
$Data{'SystemConfig'} = getSystemConfig(\%Data);

my $st_update_age_group = qq[
	UPDATE 
    tblMember_Seasons_$realm
	SET 
    intPlayerAgeGroupID = ?,
    tTimeStamp = now()
	WHERE 
    intAssocID = ?
		AND intMemberID = ?
    AND intPlayerAgeGroupID = 0
];
my $q_update_age_group = $db->prepare($st_update_age_group);

my $st_select_members = qq[
	SELECT 
    MS.intMemberID, 
    intGender, 
    dtDOB
	FROM 
    tblMember_Seasons_$realm AS MS
		INNER JOIN tblMember AS M ON MS.intMemberID=M.intMemberID
	WHERE 
    MS.intAssocID= ?
    AND intSeasonID = ?
    AND intPlayerAgeGroupID = 0
];
my $q_select_members = $db->prepare($st_select_members);

my $st_select_assocs = qq[
  SELECT 
    intAssocID
  FROM
    tblAssoc
  WHERE
    intRealmID = ?
    $assoc
];
my $q_select_assocs = $db->prepare($st_select_assocs);

$q_select_assocs->execute($realm);
while (my ($assocID, $seasonID) = $q_select_assocs->fetchrow_array()) {
  $q_select_members->execute($assocID, $season);
  my $agegroup = new GenAgeGroup($Data{'db'},$Data{'Realm'}, 0 , $assocID);
  while( my ($id, $gender, $dob)=$q_select_members->fetchrow_array())	{
	  next if !$id;
	  $dob=~s/\-//g;
	  my $ag = $agegroup->getAgeGroup($gender, $dob);
	  $q_update_age_group->execute($ag, $assocID, $id);
  }
}
