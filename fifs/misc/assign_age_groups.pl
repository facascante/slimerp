#!/usr/bin/perl -w

#
# $Header: svn://svn/SWM/trunk/misc/assign_age_groups.pl 8250 2013-04-08 08:24:36Z rlee $
#

use lib "../web","..";
use Defs;
use Utils;
use DBI;
use strict;
use GenAgeGroup;
use SystemConfig;

#This program will assign national numbers to members in a realm
# that do not have one.

my $realm=1; #Realm to check
my $assocID=1;


my %Data=();
my $db=connectDB();
$Data{'db'}=$db;
$Data{'Realm'}=$realm;
$Data{'SystemConfig'}=getSystemConfig(\%Data);

my $stu=qq[
	UPDATE tblMember_Seasons_$realm
	SET intPlayerAgeGroupID = ?
	WHERE intAssocID=$assocID
		AND intMemberID = ?
];
my $qu=$db->prepare($stu);

my $st=qq[
	SELECT MS.intMemberID, intGender, dtDOB
	FROM tblMember_Seasons_$realm AS MS
		INNER JOIN tblMember AS M ON MS.intMemberID=M.intMemberID
	WHERE MS.intAssocID= ?
];
my $q=$db->prepare($st);
$q->execute($assocID);

my $agegroup=new GenAgeGroup($Data{'db'},$Data{'Realm'}, 0 , $assocID);

while( my ($id, $gender, $dob)=$q->fetchrow_array())	{
debug("KKK $id");
	next if !$id;
	$dob=~s/\-//g;
	my $ag=$agegroup->getAgeGroup($gender, $dob);
	debug("$gender:$dob:$ag");
	$qu->execute($ag, $id);
}


