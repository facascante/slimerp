#!/usr/bin/perl -w

#
# $Header: svn://svn/SWM/trunk/misc/assign_nat_num.pl 9479 2013-09-10 04:40:14Z tcourt $
#

use lib "..", "../web", "../web/comp", "../web/sportstats";
use Defs;
use Utils;
use DBI;
use strict;
use Member qw(getAutoMemberNum);
use SystemConfig;

#This program will assign national numbers to members in a realm
# that do not have one.

my $realm=13; #Realm to check
my $assocID=5522;


my %Data=();
my $db=connectDB();
$Data{'db'}=$db;
$Data{'Realm'}=$realm;
$Data{'SystemConfig'}=getSystemConfig(\%Data);

my $st=qq[
	SELECT intMemberID
	FROM tblMember
	WHERE (strNationalNum = '' OR strNationalNum IS NULL)
		AND intRealmID=$realm
];
if($assocID)	{
	$st=qq[
		SELECT M.intMemberID
		FROM tblMember AS M
			INNER JOIN tblMember_Associations AS MA ON M.intMemberID=MA.intMemberID
		WHERE (strNationalNum = '' OR strNationalNum IS NULL)
			AND intAssocID=$assocID
	];
}
my $q=$db->prepare($st) or query_error($st);
$q->execute() or query_error($st);

my $genCode=new GenCode ($Data{'db'},$Data{'Realm'});

while( my ($id)=$q->fetchrow_array())	{
	next if !$id;
	getAutoMemberNum(\%Data, $genCode, $id, 0);
}


