#!/usr/bin/perl -w

#
# $Header: svn://svn/SWM/trunk/misc/auskick_total.pl 8250 2013-04-08 08:24:36Z rlee $
#

use lib "../web","..";
use Defs;
use Utils;
use DBI;
use strict;

my %Data=();
my $db=connectDB('reporting');

	my $realmID = 2;
	my $subRealmID = 2;
	my $seasonID = 0;

	#Get Season
	{
		my $st = qq[
			SELECT strValue
			FROM tblSystemConfig
			WHERE strOption = 'Seasons_defaultNewRegoSeason'
				AND intRealmID = ?
				AND intSubTypeID = 0
		];
		my $query = $db->prepare($st);
		$query->execute($realmID);
		($seasonID) = $query->fetchrow_array();
		$query->finish();
		exit if !$seasonID;
	}

	my $statement=qq[
SELECT
	COUNT(DISTINCT tblMember.intMemberID) AS Total
FROM
	tblMember
	INNER JOIN tblMember_Associations ON (
			tblMember.intMemberID = tblMember_Associations.intMemberID 
			AND tblMember_Associations.intRecStatus = 1
	)
	INNER JOIN tblMember_Seasons_$realmID ON (
			tblMember_Seasons_$realmID.intMemberID = tblMember_Associations.intMemberID
			AND tblMember_Seasons_$realmID.intAssocID = tblMember_Associations.intAssocID
			AND tblMember_Seasons_$realmID.intMSRecStatus = 1
	)
	INNER JOIN tblAssoc
		ON tblAssoc.intAssocID = tblMember_Associations.intAssocID
WHERE
	tblAssoc.intAssocTypeID = ?
	AND tblAssoc.intRealmID = ?
	AND tblMember.intRealmID = ?
	AND tblAssoc.intRecStatus <> -1
	AND tblMember.intStatus <> -1
	AND tblMember_Seasons_$realmID.intSeasonID = ?
	AND tblMember_Seasons_$realmID.intClubID = 0
	];

	my $query = $db->prepare($statement);
	$query->execute(
		$realmID,
		$realmID,
		$subRealmID,
		$seasonID,
	);
	my($total) = $query -> fetchrow_array();
	$query->finish();
	print $total || 0;

