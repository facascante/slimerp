#!/usr/bin/perl -w

#
# $Header: svn://svn/SWM/trunk/automatic/clearance_permits.pl 8250 2013-04-08 08:24:36Z rlee $
#

use lib "../web","..";
use Defs;
use Utils;
use DBI;
use strict;

{
my $db=connectDB();
my $lastupdate='';

	my $st = qq[
		SELECT 
			C.intMemberID, 
			C.intSourceClubID, 
			C.intDestinationClubID,
			C.dtPermitTo,
			C.intDestinationAssocID,
			C.intSourceAssocID
		FROM tblClearance as C
			INNER JOIN tblSystemConfig as SC ON (SC.intRealmID=C.intRealmID
				AND SC.strOption = 'AutoExpireClearancePermits'
			)
		WHERE 
			dtPermitTo >= DATE_ADD(CURRENT_DATE(), INTERVAL -1 DAY)
			AND dtPermitTo < CURRENT_DATE()
			AND intCreatedFrom=0
			AND C.intClearanceStatus=1
			AND intClearanceYear>=2009
			AND C.intSourceClubID >0
			AND C.intDestinationClubID >0
	];

        my $query = $db->prepare($st);
        $query->execute;
        while (my($intMemberID, $intSourceClubID, $intPermittedClubID, $dtPermitEnd, $intDestinationAssocID, $intSourceAssocID) = $query->fetchrow_array) {
		my $st_updateSource = qq[
			UPDATE 
				tblMember_Clubs
			SET
				intStatus = $Defs::RECSTATUS_ACTIVE
			WHERE 
				intMemberID = $intMemberID
				AND intClubID = $intSourceClubID
				AND intStatus = $Defs::RECSTATUS_INACTIVE
			ORDER BY intPermit
			LIMIT 1
		];
		$db->do($st_updateSource);
		my $st_updatePermittedClub= qq[
			UPDATE 
				tblMember_Clubs
			SET
				intStatus = $Defs::RECSTATUS_INACTIVE
			WHERE 
				intMemberID = $intMemberID
				AND intClubID = $intPermittedClubID
				AND intPermit = 1
				AND intStatus = $Defs::RECSTATUS_ACTIVE
				AND dtPermitEnd = "$dtPermitEnd"
		];
		$db->do($st_updatePermittedClub);
		my $st_updateassoc = qq[
			UPDATE
				tblMember_Associations
			SET 
				intRecStatus=0
			WHERE
				intMemberID = $intMemberID
				AND intAssocID = $intDestinationAssocID
		];
		$db->do($st_updateassoc);
		$st_updateassoc = qq[
			UPDATE
				tblMember_Associations
			SET 
				intRecStatus=1
			WHERE
				intMemberID = $intMemberID
				AND intAssocID = $intSourceAssocID
		];
		$db->do($st_updateassoc);
		my $st_clubsCleared = qq[
			DELETE
			FROM 
				tblMember_ClubsClearedOut
			WHERE
				intMemberID = $intMemberID
				AND intAssocID = $intSourceAssocID
				AND intClubID = $intSourceClubID
		];
		$db->do($st_clubsCleared);
	}
	
}


