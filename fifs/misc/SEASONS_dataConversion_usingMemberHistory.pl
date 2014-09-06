#!/usr/bin/perl -w

#
# $Header: svn://svn/SWM/trunk/misc/SEASONS_dataConversion_usingMemberHistory.pl 9478 2013-09-10 04:37:42Z tcourt $
#

use lib "..", "../..", "../web";
use DBI;
use CGI qw(param cookie escape);
use strict;
use Defs;
use Utils;
use DeQuote;

main();

sub main	{
	my $db=connectDB();

	
	my $intRealmID = 2;
	my $intRealmSubTypeID = -1;
	my $insertDefCodesSeason = 1;
	my $insertMHSeason = 1;
	my $insertMHMemberSeason = 1;
	my $insertRealmSeason = 1;
	my $insertSubRealmSeason = 1;
	my $updateAssocSeasons = 1;

	my $SINGLEassocID = 0;
	my $insertMemberAssocSeasonRecords = 1;
	my $insertMemberAssocClubSeasonRecords = 1;
	my $updateAssocCompSeason=1;

	my $st = qq[UPDATE tblAssoc_Grade as G INNER JOIN tblAssoc as A ON (A.intAssocID =G.intAssocID) SET G.intRealmID = A.intRealmID, intRealmSubTypeID = A.intAssocTypeID];
	my $query = $db->prepare($st);
        $query->execute;

	my $st_assocs = qq[
		SELECT intAssocID, intRealmID, intAssocTypeID
		FROM tblAssoc
	];
	
	$st_assocs .= qq[ WHERE intRealmID = $intRealmID] if $intRealmID > 0;
	$st_assocs .= qq[ AND intAssocID = $SINGLEassocID ] if $SINGLEassocID > 0;
	$st_assocs .= qq[ AND intAssocTypeID = $intRealmSubTypeID] if $intRealmSubTypeID > 0;

	my $query_assocs = $db->prepare($st_assocs);
        $query_assocs->execute;

	my %Assocs=();
        while(my ($assocID, $realmID, $realmSubTypeID)=$query_assocs->fetchrow_array())       {
		$Assocs{$assocID} = [$realmID, $realmSubTypeID];
	}
	
	my %MH_Seasons = ();
	my %MH_DefCodesSeasons = ();
	my %MH_OldIDSeasons = ();

	 if ($insertRealmSeason)      {
                my $st = qq[
                        INSERT INTO tblSeasons (intRealmID, intRealmSubTypeID, intAssocID, strSeasonName, intSeasonOrder, dtAdded)
                        SELECT R.intRealmID, 0, 0, 'Default', 0, NOW()
                        FROM tblRealms as R
                ];
                $st .= qq[ WHERE R.intRealmID = $intRealmID] if $intRealmID > 0;
                $st .= qq[ WHERE R.intRealmID NOT IN (1)] if $intRealmID <= 0;

                my $query = $db->prepare($st);
                $query->execute;

		$st = qq[
                        INSERT INTO tblSeasons (intRealmID, intRealmSubTypeID, intAssocID, strSeasonName, intSeasonOrder, dtAdded)
                        SELECT R.intRealmID, 0, 0, '2008', 0, NOW()
                        FROM tblRealms as R
                ];
                $st .= qq[ WHERE R.intRealmID = $intRealmID] if $intRealmID > 0;
                $st .= qq[ WHERE R.intRealmID NOT IN (1)] if $intRealmID <= 0;

                $query = $db->prepare($st);
                $query->execute;

        }

	if ($insertSubRealmSeason)	{
		my $st = qq[
			INSERT INTO tblSeasons (intRealmID, intRealmSubTypeID, intAssocID, strSeasonName, intSeasonOrder, dtAdded)
			SELECT R.intRealmID,  R.intSubTypeID, 0, CONCAT('Default - ', R.strSubTypeName), 0, NOW()
			FROM tblRealmSubTypes as R
		];
		$st .= qq[ WHERE R.intRealmID = $intRealmID] if $intRealmID > 0;
		$st .= qq[ AND R.intSubTypeID = $intRealmSubTypeID] if $intRealmSubTypeID > 0;

		my $query = $db->prepare($st);
        	$query->execute;
	}
	
	$st= qq[
		SELECT intSeasonID, strSeasonName, intRealmID, intAssocID, intRealmSubTypeID
		FROM tblSeasons
	];
		$st .= qq[ WHERE intRealmID = $intRealmID] if $intRealmID > 0;
		$st .= qq[ AND intSubTypeID = $intRealmSubTypeID] if $intRealmSubTypeID > 0;
		$st .= qq[ AND (intAssocID = 0 or intAssocID = $SINGLEassocID)] if $SINGLEassocID> 0;
	$query= $db->prepare($st);
        $query->execute;
        while(my $dref=$query->fetchrow_hashref())       {
		$MH_DefCodesSeasons{$dref->{'intAssocID'}}{$dref->{'strSeasonName'}}=$dref->{'intSeasonID'};
	}

	if ($insertDefCodesSeason)	{
		print STDERR "ENTERING: insertDefCodesSeason\n";
		foreach my $assocID (keys %Assocs)	{
			my $st_history = qq[
				SELECT DISTINCT strName
				FROM tblDefCodes
				WHERE intAssocID = $assocID
					AND intType=-5
			];
			my $query_history = $db->prepare($st_history);
        		$query_history->execute;
        		while(my ($strSeasonName)=$query_history->fetchrow_array())       {
				next if $MH_DefCodesSeasons{$assocID}{$strSeasonName};
				next if $MH_DefCodesSeasons{'0'}{'2008'} and $strSeasonName eq '2008';
				my $tempSeasonName = $strSeasonName;
				deQuote($db,\$tempSeasonName);
				my $st = qq[
					INSERT INTO tblSeasons (intRealmID, intRealmSubTypeID, intAssocID, strSeasonName, intSeasonOrder, dtAdded)
					VALUES ($Assocs{$assocID}[0], $Assocs{$assocID}[1], $assocID, $tempSeasonName, 0, NOW())
				];
				my $query = $db->prepare($st);
        			$query->execute;
				my $seasonID = $query->{mysql_insertid};
				$MH_DefCodesSeasons{$assocID}{$strSeasonName}=$seasonID;
			}
		}
	}
	if ($insertMHSeason)	{
		print STDERR "ENTERING: insertMHSeason\n";
			my $st_history = qq[
				SELECT DISTINCT intSeasonID, strSeasonName, A.intAssocID
				FROM tblMemberHistory as MH
					INNER JOIN tblAssoc as A ON (MH.intAssocID = A.intAssocID)
			];
			$st_history.= qq[ WHERE A.intRealmID = $intRealmID] if $intRealmID > 0;
			$st_history.= qq[ AND A.intAssocID = $SINGLEassocID ] if $SINGLEassocID > 0;
			$st_history.= qq[ AND A.intAssocTypeID = $intRealmSubTypeID] if $intRealmSubTypeID > 0;

			my $query_history = $db->prepare($st_history);
        		$query_history->execute;
        		while(my ($intOLDSeasonID, $strSeasonName, $assocID)=$query_history->fetchrow_array())       {
				next if $MH_DefCodesSeasons{$assocID}{$strSeasonName};
				next if $MH_DefCodesSeasons{'0'}{'2008'} and $strSeasonName eq '2008';
				my $st = qq[
					INSERT INTO tblSeasons (intRealmID, intRealmSubTypeID, intAssocID, strSeasonName, intSeasonOrder, dtAdded)
					VALUES ($Assocs{$assocID}[0], $Assocs{$assocID}[1], $assocID, $strSeasonName, 0, NOW())
				];
				my $query = $db->prepare($st);
        			$query->execute;
				my $seasonID = $query->{mysql_insertid};
				$MH_Seasons{$assocID}{$strSeasonName}=$seasonID;
				$MH_OldIDSeasons{$assocID}{$intOLDSeasonID}=$seasonID;
			}
	}

	if ($updateAssocSeasons)	{
	print STDERR "ENTERING: updateAssocSeasons\n";
		my $st = qq[
			SELECT intSeasonID, intRealmID, intRealmSubTypeID, intAssocID
			FROM tblSeasons
			WHERE strSeasonName LIKE '%Default%'
		];
		my $query = $db->prepare($st);
        	$query->execute;
		my %Seasons = ();
        	while(my ($seasonID, $realmID, $realmSubTypeID, $intAssocID)=$query->fetchrow_array())       {
			$Seasons{$realmID}{$realmSubTypeID}{$intAssocID} = $seasonID;
		}
			
		$st = qq[
			SELECT intAssocID, intRealmID, intAssocTypeID
			FROM tblAssoc
		];
	
		$st .= qq[ WHERE intRealmID = $intRealmID] if $intRealmID > 0;
		$st .= qq[ AND intAssocID = $SINGLEassocID ] if $SINGLEassocID > 0;
		$st .= qq[ AND intAssocTypeID = $intRealmSubTypeID] if $intRealmSubTypeID > 0;

		$query = $db->prepare($st);
        	$query->execute;
        	while(my ($assocID, $realmID, $realmSubTypeID)=$query->fetchrow_array())       {
			my $seasonID = $Seasons{$realmID}{$realmSubTypeID}{$assocID} || $Seasons{$realmID}{$realmSubTypeID}{0} || $Seasons{$realmID}{0} || -1;
			my $st_update  = qq[UPDATE tblAssoc SET intCurrentSeasonID = $seasonID, intNewRegoSeasonID = $seasonID WHERE intAssocID = $assocID];
			my $qry_update = $db->prepare($st_update);
        		$qry_update->execute;
		}
	}

	if ($insertMHMemberSeason)	{
	print STDERR "ENTERING: insertMHMemberSeason\n";
			my $st_history = qq[
				SELECT DISTINCT MH.intMemberID, MH.intClubID, MH.strSeasonName, A.intAssocID
				FROM tblMemberHistory as MH 
					INNER JOIN tblAssoc as A ON (MH.intAssocID = A.intAssocID)
			];
		$st_history .= qq[ WHERE A.intRealmID = $intRealmID] if $intRealmID > 0;
		$st_history .= qq[ AND A.intAssocID = $SINGLEassocID ] if $SINGLEassocID > 0;
		$st_history .= qq[ AND A.intAssocTypeID = $intRealmSubTypeID] if $intRealmSubTypeID > 0;
			my $query_history = $db->prepare($st_history);
        		$query_history->execute;
        		while(my $dref=$query_history->fetchrow_hashref())       {
				my $assocID = $dref->{intAssocID};
				next if ! $dref->{strSeasonName};
				my $seasonID =  $MH_DefCodesSeasons{$assocID}{$dref->{strSeasonName}} || $MH_Seasons{$assocID}{$dref->{strSeasonName}} || next;
				my $MStablename = "tblMember_Seasons_$Assocs{$assocID}[0]";
				my $st_insert = qq[
					INSERT IGNORE INTO $MStablename (intAssocID, intClubID, intMemberID, intSeasonID, intPlayerStatus) VALUES ($assocID, $dref->{intClubID}, $dref->{intMemberID}, $seasonID, 1)
				];
				my $qry_insert = $db->prepare($st_insert);
        			$qry_insert->execute;
				if ($dref->{intClubID})	{
					### CLUB LEVEL INSERTED, DO ASSOC LEVEL
					$st_insert = qq[
						INSERT IGNORE INTO $MStablename (intAssocID, intClubID, intMemberID, intSeasonID, intPlayerStatus) VALUES ($assocID, 0, $dref->{intMemberID}, $seasonID, 1)
					];
					$qry_insert = $db->prepare($st_insert);
        				$qry_insert->execute;
				}

			}
	}
	if ($insertMemberAssocSeasonRecords)	{
	print STDERR "ENTERING: insertMemberAssocSeasonRecords\n";
		my $st = qq[
			SELECT intAssocID, intRealmID, intCurrentSeasonID
			FROM tblAssoc
		];
	
		$st .= qq[ WHERE intRealmID = $intRealmID] if $intRealmID > 0;
		$st .= qq[ AND intAssocID = $SINGLEassocID ] if $SINGLEassocID > 0;
		$st .= qq[ AND intAssocTypeID = $intRealmSubTypeID] if $intRealmSubTypeID > 0;

		my $query = $db->prepare($st);
        	$query->execute;
        	while(my ($assocID, $realmID, $seasonID)=$query->fetchrow_array())       {
			$seasonID ||= -1;
			my $MStablename = "tblMember_Seasons_$realmID";
			my $st_insert = qq[INSERT IGNORE INTO $MStablename (intAssocID, intMemberID, intSeasonID, intPlayerStatus) SELECT $assocID, MA.intMemberID, $seasonID, 1 FROM tblMember_Associations as MA WHERE  MA.intAssocID=$assocID];
			my $qry_insert = $db->prepare($st_insert);
        		$qry_insert->execute;
			my $st_assocs= qq[
				SELECT DISTINCT MA.intMemberID, MA.intRecStatus
				FROM tblMember_Associations as MA
				WHERE MA.intAssocID = $assocID
			];
			my $qry_assocs= $db->prepare($st_assocs);
        		$qry_assocs->execute;
			my $seasonID_2008 = $MH_DefCodesSeasons{'0'}{'2008'} || $seasonID;
			my $seasonID_Default = $MH_DefCodesSeasons{'0'}{'Default'} || $seasonID;
        		while(my ($memberID, $recStatus, $player, $coach, $umpire)=$qry_assocs->fetchrow_array())       {
				my $st_insert = '';
				if ($recStatus eq '1')	{
					$st_insert = qq[INSERT IGNORE INTO $MStablename (intAssocID, intMemberID, intSeasonID, intClubID, intPlayerStatus) VALUES ($assocID, $memberID, $seasonID_2008, 0, 1)];
					my $qry_insert = $db->prepare($st_insert);
        				$qry_insert->execute;
				}
				$st_insert = qq[INSERT IGNORE INTO $MStablename (intAssocID, intMemberID, intSeasonID, intClubID, intPlayerStatus) VALUES ($assocID, $memberID, $seasonID_Default, 0, 1)];
				my $qry_insert = $db->prepare($st_insert);
        			$qry_insert->execute;
			}
		
		}
	}


	if ($insertMemberAssocClubSeasonRecords)	{
	print STDERR "ENTERING: insertMemberAssocClubSeasonRecords\n";
		my $st = qq[
			SELECT intAssocID, intRealmID, intCurrentSeasonID
			FROM tblAssoc
		];
	
		$st .= qq[ WHERE intRealmID = $intRealmID] if $intRealmID > 0;
		$st .= qq[ AND intAssocID = $SINGLEassocID ] if $SINGLEassocID > 0;
		$st .= qq[ AND intAssocTypeID = $intRealmSubTypeID] if $intRealmSubTypeID > 0;

		my $query = $db->prepare($st);
        	$query->execute;
        	while(my ($assocID, $realmID, $seasonID)=$query->fetchrow_array())       {
			$seasonID ||= -1;
			my $MStablename = "tblMember_Seasons_$realmID";

			my $st_clubs = qq[
				SELECT DISTINCT MC.intMemberID, MC.intClubID, MA.intRecStatus, MC.intStatus
				FROM tblMember_Clubs as MC
					INNER JOIN tblMember_Associations as MA ON (MA.intAssocID = $assocID AND MA.intMemberID = MC.intMemberID)
					INNER JOIN tblAssoc_Clubs as AC ON (AC.intClubID = MC.intClubID AND AC.intAssocID = $assocID)
			];
			my $qry_clubs = $db->prepare($st_clubs);
        		$qry_clubs->execute;

			my $seasonID_2008 = $MH_DefCodesSeasons{'0'}{'2008'} || $seasonID;
			my $seasonID_Default = $MH_DefCodesSeasons{'0'}{'Default'} || $seasonID;
        		while(my ($memberID, $clubID, $assocStatus, $clubStatus)=$qry_clubs->fetchrow_array())       {
				$clubID ||= 0;
				$clubID = 0 if ($clubID < 0);
				my $st_insert = '';
				if ($assocStatus eq '1' and $clubStatus eq '1')	{
					$st_insert = qq[INSERT IGNORE INTO $MStablename (intAssocID, intMemberID, intSeasonID, intClubID, intPlayerStatus) VALUES ($assocID, $memberID, $seasonID_2008, $clubID, 1)];
					my $qry_insert = $db->prepare($st_insert);
        				$qry_insert->execute;
				}
				$st_insert = qq[INSERT IGNORE INTO $MStablename (intAssocID, intMemberID, intSeasonID, intClubID, intPlayerStatus) VALUES ($assocID, $memberID, $seasonID_Default, $clubID, 1)];
				my $qry_insert = $db->prepare($st_insert);
        			$qry_insert->execute;
			}

			my $st_teams = qq[
				SELECT DISTINCT MT.intMemberID, T.intClubID, DC.strName
				FROM tblMember_Teams as MT
					INNER JOIN tblMember_Associations as MA ON (MA.intAssocID = $assocID AND MA.intMemberID = MT.intMemberID)
					INNER JOIN tblTeam as T ON (MT.intTeamID = T.intTeamID and T.intAssocID=$assocID)
					INNER JOIN tblAssoc_Comp as AC ON (AC.intCompID = MT.intCompID and AC.intAssocID = $assocID)
					LEFT JOIN tblDefCodes as DC ON (DC.intCodeID = AC.intSeasonID)
				WHERE MT.intStatus <> -1
			];
					#AND MT.intMemberID = 331155
			my $qry_teams = $db->prepare($st_teams);
        		$qry_teams->execute;
        		while(my ($memberID, $clubID, $seasonName)=$qry_teams->fetchrow_array())       {
				
				next if (! $seasonName);
				$clubID ||= 0;
				$clubID = 0 if ($clubID < 0);
				my $NewseasonID = $MH_DefCodesSeasons{$assocID}{$seasonName} || $MH_Seasons{$assocID}{$seasonName} || $seasonID;
				if ($NewseasonID)	{
					my $st_insert = qq[INSERT IGNORE INTO $MStablename (intAssocID, intMemberID, intSeasonID, intClubID, intPlayerStatus) VALUES ($assocID, $memberID, $NewseasonID, $clubID, 1)];
					my $qry_insert = $db->prepare($st_insert);
        				$qry_insert->execute;
					$st_insert = qq[INSERT IGNORE INTO $MStablename (intAssocID, intMemberID, intSeasonID, intClubID, intPlayerStatus) VALUES ($assocID, $memberID, $NewseasonID, 0, 1)];
					$qry_insert = $db->prepare($st_insert);
        				$qry_insert->execute;
				}
			}

		}
	}

	if ($updateAssocCompSeason)	{
	print STDERR "ENTERING: updateAssocCompSeason\n";
		foreach my $assocID (keys %Assocs)	{
			my $st_assoc = qq[
				SELECT intCurrentSeasonID
				FROM tblAssoc
				WHERE intAssocID = $assocID
			];
			my $query_assoc = $db->prepare($st_assoc);
        		$query_assoc->execute;
			my $currentSeasonID = $query_assoc->fetchrow_array() || 0;
			my $st_comps = qq[
				SELECT intCompID, intSeasonID, DC.strName
				FROM tblAssoc_Comp
					LEFT JOIN tblDefCodes as DC ON (DC.intCodeID = tblAssoc_Comp.intSeasonID)
				WHERE tblAssoc_Comp.intAssocID =$assocID
			];
			my $query_comps = $db->prepare($st_comps);
        		$query_comps->execute;
        		while(my ($compID , $seasonID, $seasonName)=$query_comps->fetchrow_array())       {
				my $newSeasonID = $seasonName eq '2008' ? $MH_DefCodesSeasons{'0'}{'2008'} : $MH_DefCodesSeasons{$assocID}{$seasonName} || $MH_Seasons{$assocID}{$seasonName} || $MH_OldIDSeasons{$assocID}{$seasonID} || $currentSeasonID || 0;
				my $st_update = qq[
					UPDATE tblAssoc_Comp
					SET intNewSeasonID = $newSeasonID
					WHERE intCompID = $compID
						AND intAssocID = $assocID
				];
				my $qry_update = $db->prepare($st_update);
        			$qry_update->execute;
			}
		}
	}

	print STDERR "\n\n--SEASONS CONVERSION DONE\n\n";

	print STDERR "REALMID : $intRealmID\n";
	print STDERR "REALMSUBID : $intRealmSubTypeID\n";
	print STDERR "INSERTDefCodesSEASON : $insertDefCodesSeason\n";
	print STDERR "INSERTMHSEASON : $insertMHSeason\n";
	print STDERR "INSERTREALMSEASON : $insertRealmSeason\n";
	print STDERR "INSERTSEASON_SUBREALM: $insertSubRealmSeason\n";
	print STDERR "UPDATE_ASSOC SETTINGS: $updateAssocSeasons\n";

	print STDERR "SINGLE ASSOC: $SINGLEassocID\n";
	print STDERR "INSERT_MS_RECORDS_FOR_ASSOC: $insertMemberAssocSeasonRecords\n";
	print STDERR "INSERT_MS_RECORDS_FOR_CLUB_ASSOC: $insertMemberAssocClubSeasonRecords\n";
	print STDERR "UPDATE COMP intNewSeasonID: $updateAssocCompSeason\n";
}
