#!/usr/bin/perl -w

#
# $Header: svn://svn/SWM/trunk/misc/SEASONS_dataConversion_take3.pl 9477 2013-09-10 04:36:20Z tcourt $
#

use lib "..", "../..", "../web";
use DBI;
use CGI qw(param cookie escape);
use strict;
use DeQuote;

main();

sub main	{
	my $db=connectDB();

	
	my $intRealmID = 3;
	my $MStablename = "tblMember_Seasons_$intRealmID";
	my $intRealmSubTypeID = 0;
	my $SINGLEassocID = 0;

	my $TOdb = 'regoSWM_live';

	#When I do a second run, make sure insertRealmSeason is 0
	my $insertRealmSeason = 1;

	my $insertDefCodesSeason = 1;
	my $updateAssocSeasons = 1;

	my $insertMHMemberSeason = 1;
	my $insertMemberAssocSeasonRecords = 1;
	my $insertMemberAssocClubSeasonRecords = 1;
	my $updateAssocCompSeason=1;

	my $starttime=scalar localtime();
	print STDERR "START TIME: $starttime\n";

	my $st_assocs = qq[
		SELECT intAssocID, intRealmID, intAssocTypeID
		FROM $TOdb.tblAssoc
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

	 if ($insertRealmSeason)      {
                my $st = qq[
                        INSERT INTO $TOdb.tblSeasons (intRealmID, intRealmSubTypeID, intAssocID, strSeasonName, intSeasonOrder, dtAdded)
                        SELECT R.intRealmID, 0, 0, 'Default', 0, NOW()
                        FROM tblRealms as R
                ];
                $st .= qq[ WHERE R.intRealmID = $intRealmID] if $intRealmID > 0;
                $st .= qq[ WHERE R.intRealmID NOT IN (1)] if $intRealmID <= 0;

                my $query = $db->prepare($st);
                $query->execute;
		my $defaultSeasonID = $query->{mysql_insertid};

		$st = qq[ DELETE FROM tblSystemConfig WHERE intRealmID = $intRealmID AND strOption IN ('Seasons_defaultNewRegoSeason', 'Seasons_defaultCurrentSeason'); ];
                $query = $db->prepare($st);
                $query->execute;

		if ($defaultSeasonID)	{
			$st = qq[ INSERT INTO tblSystemConfig VALUES (0, 1, 'Seasons_defaultCurrentSeason', $defaultSeasonID, NOW(), $intRealmID, 0) ];
	                $query = $db->prepare($st);
	                $query->execute;

			$st = qq[ INSERT INTO tblSystemConfig VALUES (0, 1, 'Seasons_defaultNewRegoSeason', $defaultSeasonID, NOW(), $intRealmID, 0) ];
	                $query = $db->prepare($st);
	                $query->execute;
		}
		for my $i (1995 .. 2009)	{
			$st = qq[
                	        INSERT INTO $TOdb.tblSeasons (intRealmID, intRealmSubTypeID, intAssocID, strSeasonName, intSeasonOrder, dtAdded)
				VALUES ($intRealmID, 0, 0, $i , 0, NOW())
                	];
                	$query = $db->prepare($st);
                	$query->execute;
		}

        }

	my $st= qq[
		SELECT intSeasonID, strSeasonName, intRealmID, intAssocID, intRealmSubTypeID
		FROM $TOdb.tblSeasons
	];
		$st .= qq[ WHERE intRealmID = $intRealmID] if $intRealmID > 0;
		$st .= qq[ AND intSubTypeID = $intRealmSubTypeID] if $intRealmSubTypeID > 0;
		$st .= qq[ AND (intAssocID = 0 or intAssocID = $SINGLEassocID)] if $SINGLEassocID> 0;
	my $query= $db->prepare($st);
        $query->execute;
        while(my $dref=$query->fetchrow_hashref())       {
		$MH_Seasons{$dref->{intAssocID}}{$dref->{'strSeasonName'}}=$dref->{'intSeasonID'};
	}

	if ($insertDefCodesSeason)	{
		print STDERR "ENTERING: insertDefCodesSeason- ".scalar localtime()."\n";
			my $st_history = qq[
				SELECT DISTINCT strName, intAssocID
				FROM tblDefCodes
				WHERE intType=-5
			];
			$st_history .= qq[ AND intRealmID = $intRealmID] if $intRealmID > 0;
			$st_history .= qq[ AND intSubTypeID = $intRealmSubTypeID] if $intRealmSubTypeID > 0;
			$st_history .= qq[ AND (intAssocID = 0 or intAssocID = $SINGLEassocID)] if $SINGLEassocID> 0;
			my $query_history = $db->prepare($st_history);
        		$query_history->execute;
        		while(my ($strSeasonName, $intAssocID)=$query_history->fetchrow_array())       {
				next if $MH_Seasons{0}{$strSeasonName} or $MH_Seasons{$intAssocID}{$strSeasonName};
				next if $MH_Seasons{0}{'2008'} and $strSeasonName eq '2008';
				my $tempSeasonName = $strSeasonName;
				deQuote($db,\$tempSeasonName);
				my $st = qq[
					INSERT INTO $TOdb.tblSeasons (intRealmID, intRealmSubTypeID, intAssocID, strSeasonName, intSeasonOrder, dtAdded)
					VALUES ($intRealmID, $intRealmSubTypeID, $intAssocID, $tempSeasonName, 0, NOW())
				];
				my $query = $db->prepare($st);
        			$query->execute;
				my $seasonID = $query->{mysql_insertid};
				$MH_Seasons{$intAssocID}{$strSeasonName} = $seasonID;
			}
	}

	if ($updateAssocSeasons)	{
		print STDERR "ENTERING: updateAssocSeasons- ".scalar localtime()."\n";
		my $st_update  = qq[UPDATE $TOdb.tblAssoc LEFT JOIN $TOdb.tblSeasons as S ON (S.intRealmID = tblAssoc.intRealmID AND strSeasonName = 'Default' AND S.intAssocID=0) SET intCurrentSeasonID = S.intSeasonID, intNewRegoSeasonID = S.intSeasonID WHERE tblAssoc.intRealmID = $intRealmID and tblAssoc.intCurrentSeasonID = 0];
		$st_update .= qq[ AND tblAssoc.intAssocID = $SINGLEassocID ] if $SINGLEassocID > 0;
		$st_update .= qq[ AND intAssocTypeID = $intRealmSubTypeID] if $intRealmSubTypeID > 0;
		my $qry_update = $db->prepare($st_update);
        	$qry_update->execute;
	}

	if ($insertMHMemberSeason and ($intRealmID <= 18 or $intRealmID == 26))	{
		print STDERR "ENTERING: $intRealmID-insertMHMemberSeason- ".scalar localtime()."\n";
			my $st_history = qq[
				SELECT DISTINCT MH.intMemberID, MH.intClubID, MH.strSeasonName, A.intAssocID
				FROM tblMemberHistory as MH 
					INNER JOIN $TOdb.tblAssoc as A ON (MH.intAssocID = A.intAssocID)
			];
		$st_history .= qq[ WHERE A.intRealmID = $intRealmID] if $intRealmID > 0;
		$st_history .= qq[ AND A.intAssocID = $SINGLEassocID ] if $SINGLEassocID > 0;
		$st_history .= qq[ AND A.intAssocTypeID = $intRealmSubTypeID] if $intRealmSubTypeID > 0;


			my $query_history = $db->prepare($st_history);
        		$query_history->execute;
        		while(my $dref=$query_history->fetchrow_hashref())       {
				my $assocID = $dref->{intAssocID};
				next if ! $dref->{strSeasonName};
				my $seasonID =  $MH_Seasons{0}{$dref->{strSeasonName}} || $MH_Seasons{$dref->{'intAssocID'}}{$dref->{strSeasonName}} || next;
				my $st_insert = qq[
					INSERT IGNORE INTO $TOdb.$MStablename (intAssocID, intClubID, intMemberID, intSeasonID, intPlayerStatus) VALUES ($assocID, $dref->{intClubID}, $dref->{intMemberID}, $seasonID, 1)
				];
				my $qry_insert = $db->prepare($st_insert);
        			$qry_insert->execute;
				if ($dref->{intClubID})	{
					### CLUB LEVEL INSERTED, DO ASSOC LEVEL
					$st_insert = qq[
						INSERT IGNORE INTO $TOdb.$MStablename (intAssocID, intClubID, intMemberID, intSeasonID, intPlayerStatus) VALUES ($assocID, 0, $dref->{intMemberID}, $seasonID, 1)
					];
					$qry_insert = $db->prepare($st_insert);
        				$qry_insert->execute;
				}

			}
	}

	#print STDERR "STOPPING: - ".scalar localtime()."\n";
	#return '';
	if ($insertMemberAssocSeasonRecords)	{
		print STDERR "ENTERING: insertMemberAssocSeasonRecords- ".scalar localtime()."\n";
                my $st_insert = qq[
			INSERT IGNORE INTO $TOdb.$MStablename (intAssocID, intMemberID, intSeasonID, intPlayerStatus) 
			SELECT MA.intAssocID, MA.intMemberID, A.intCurrentSeasonID, 1 FROM tblMember_Associations as MA 
				INNER JOIN $TOdb.tblAssoc as A ON A.intAssocID = MA.intAssocID
		];	
		$st_insert .= qq[ WHERE A.intRealmID = $intRealmID] if $intRealmID > 0;
		$st_insert .= qq[ AND A.intAssocID = $SINGLEassocID ] if $SINGLEassocID > 0;
		$st_insert .= qq[ AND A.intAssocTypeID = $intRealmSubTypeID] if $intRealmSubTypeID > 0;
                my $qry_insert = $db->prepare($st_insert);
                $qry_insert->execute;  

		my $st_assocs= qq[
			SELECT DISTINCT A.intAssocID, A.intCurrentSeasonID, MA.intMemberID, MA.intRecStatus
			FROM tblMember_Associations as MA
			INNER JOIN $TOdb.tblAssoc as A ON (A.intAssocID = MA.intAssocID)
		];
		$st_assocs .= qq[ WHERE A.intRealmID = $intRealmID] if $intRealmID > 0;
		$st_assocs .= qq[ AND A.intAssocID = $SINGLEassocID ] if $SINGLEassocID > 0;
		$st_assocs .= qq[ AND A.intAssocTypeID = $intRealmSubTypeID] if $intRealmSubTypeID > 0;
		my $qry_assocs= $db->prepare($st_assocs);
        	$qry_assocs->execute;
        	while(my ($assocID, $seasonID, $memberID, $recStatus, $player, $coach, $umpire)=$qry_assocs->fetchrow_array())       {
			my $seasonID_2008 = $MH_Seasons{0}{'2008'} || $seasonID;
			my $seasonID_Default = $MH_Seasons{0}{'Default'} || $seasonID;
			my $st_insert = '';
			if ($recStatus eq '1')	{
				$st_insert = qq[INSERT IGNORE INTO $TOdb.$MStablename (intAssocID, intMemberID, intSeasonID, intClubID, intPlayerStatus) VALUES ($assocID, $memberID, $seasonID_2008, 0, 1)];
				my $qry_insert = $db->prepare($st_insert);
        			$qry_insert->execute;
			}
			$st_insert = qq[INSERT IGNORE INTO $TOdb.$MStablename (intAssocID, intMemberID, intSeasonID, intClubID, intPlayerStatus) VALUES ($assocID, $memberID, $seasonID_Default, 0, 1)];
			my $qry_insert = $db->prepare($st_insert);
        		$qry_insert->execute;
		}
	}


	if ($insertMemberAssocClubSeasonRecords)	{
		print STDERR "ENTERING: insertMemberAssocClubSeasonRecords- ".scalar localtime()."\n";

		my $st_clubs = qq[
			SELECT DISTINCT A.intAssocID, A.intCurrentSeasonID, MC.intMemberID, MC.intClubID, MA.intRecStatus, MC.intStatus
			FROM tblMember_Clubs as MC
			INNER JOIN tblMember_Associations as MA ON (MA.intMemberID = MC.intMemberID)
			INNER JOIN tblAssoc_Clubs as AC ON (AC.intClubID = MC.intClubID AND AC.intAssocID = MA.intAssocID)
			INNER JOIN $TOdb.tblAssoc as A ON (A.intAssocID = AC.intAssocID)
		];
		$st_clubs .= qq[ WHERE A.intRealmID = $intRealmID] if $intRealmID > 0;
		$st_clubs .= qq[ AND A.intAssocID = $SINGLEassocID ] if $SINGLEassocID > 0;
		$st_clubs .= qq[ AND A.intAssocTypeID = $intRealmSubTypeID] if $intRealmSubTypeID > 0;
		my $qry_clubs = $db->prepare($st_clubs);
        	$qry_clubs->execute;

        	while(my ($assocID, $seasonID, $memberID, $clubID, $assocStatus, $clubStatus)=$qry_clubs->fetchrow_array())       {
			my $seasonID_2008 = $MH_Seasons{0}{'2008'} || $seasonID;
			my $seasonID_Default = $MH_Seasons{0}{'Default'} || $seasonID;
			$clubID ||= 0;
			$clubID = 0 if ($clubID < 0);
			my $st_insert = '';
			if ($assocStatus eq '1' and $clubStatus eq '1')	{
				$st_insert = qq[INSERT IGNORE INTO $TOdb.$MStablename (intAssocID, intMemberID, intSeasonID, intClubID, intPlayerStatus) VALUES ($assocID, $memberID, $seasonID_2008, $clubID, 1)];
				my $qry_insert = $db->prepare($st_insert);
        			$qry_insert->execute;
			}
			$st_insert = qq[INSERT IGNORE INTO $TOdb.$MStablename (intAssocID, intMemberID, intSeasonID, intClubID, intPlayerStatus) VALUES ($assocID, $memberID, $seasonID_Default, $clubID, 1)];
			my $qry_insert = $db->prepare($st_insert);
        		$qry_insert->execute;
		}

		my $st_teams = qq[
			SELECT DISTINCT A.intAssocID, A.intCurrentSeasonID, MT.intMemberID, T.intClubID, DC.strName
			FROM tblMember_Teams as MT
				INNER JOIN tblMember_Associations as MA ON (MA.intMemberID = MT.intMemberID)
				INNER JOIN tblTeam as T ON (MT.intTeamID = T.intTeamID and T.intAssocID=MA.intAssocID)
				INNER JOIN tblAssoc_Comp as AC ON (AC.intCompID = MT.intCompID and AC.intAssocID = MA.intAssocID)
				LEFT JOIN tblDefCodes as DC ON (DC.intCodeID = AC.intSeasonID)
				INNER JOIN $TOdb.tblAssoc as A ON (A.intAssocID = AC.intAssocID)
			WHERE MT.intStatus <> -1
		];
		$st_teams .= qq[ AND A.intRealmID = $intRealmID] if $intRealmID > 0;
		$st_teams .= qq[ AND A.intAssocID = $SINGLEassocID ] if $SINGLEassocID > 0;
		$st_teams .= qq[ AND A.intAssocTypeID = $intRealmSubTypeID] if $intRealmSubTypeID > 0;
		#$st_teams .= qq[ LIMIT 5];
		my $qry_teams = $db->prepare($st_teams);
        	$qry_teams->execute;
        	while(my ($assocID, $seasonID, $memberID, $clubID, $seasonName)=$qry_teams->fetchrow_array())       {
			next if (! $seasonName);
			$clubID ||= 0;
			$clubID = 0 if ($clubID < 0);
			#print STDERR "$assocID|$seasonID|$memberID|$clubID|$seasonName\n";
			my $NewseasonID = $MH_Seasons{0}{$seasonName} || $MH_Seasons{$assocID}{$seasonName} || $seasonID;
			#print STDERR "NEWSEASONID:$NewseasonID\n";
			if ($NewseasonID)	{
				my $st_insert = qq[INSERT IGNORE INTO $TOdb.$MStablename (intAssocID, intMemberID, intSeasonID, intClubID, intPlayerStatus) VALUES ($assocID, $memberID, $NewseasonID, $clubID, 1)];
				my $qry_insert = $db->prepare($st_insert);
        			$qry_insert->execute;
				$st_insert = qq[INSERT IGNORE INTO $TOdb.$MStablename (intAssocID, intMemberID, intSeasonID, intClubID, intPlayerStatus) VALUES ($assocID, $memberID, $NewseasonID, 0, 1)];
				$qry_insert = $db->prepare($st_insert);
        			$qry_insert->execute;
			}
		}
	}

	if ($updateAssocCompSeason)	{
		print STDERR "ENTERING: updateAssocCompSeason- ".scalar localtime()."\n";
		foreach my $assocID (keys %Assocs)	{
			my $st_assoc = qq[
				SELECT intCurrentSeasonID
				FROM $TOdb.tblAssoc
				WHERE intAssocID = $assocID
			];
			my $query_assoc = $db->prepare($st_assoc);
        		$query_assoc->execute;
			my $currentSeasonID = $query_assoc->fetchrow_array() || 0;
			my $st_comps = qq[
				SELECT intCompID, intSeasonID, DC.strName
				FROM $TOdb.tblAssoc_Comp
					LEFT JOIN tblDefCodes as DC ON (DC.intCodeID = tblAssoc_Comp.intSeasonID)
				WHERE tblAssoc_Comp.intAssocID =$assocID
					AND intNewSeasonID = 0
			];
			my $query_comps = $db->prepare($st_comps);
        		$query_comps->execute;
        		while(my ($compID , $seasonID, $seasonName)=$query_comps->fetchrow_array())       {
				$seasonName ||= '';
				my $newSeasonID = $seasonName eq '2008' ? $MH_Seasons{0}{'2008'} : $MH_Seasons{0}{$seasonName};
				$newSeasonID = $newSeasonID || $MH_Seasons{$assocID}{$seasonName} || $currentSeasonID || 0;
				my $st_update = qq[
					UPDATE $TOdb.tblAssoc_Comp
					SET intNewSeasonID = $newSeasonID, tTimeStamp = tTimestamp
					WHERE intCompID = $compID
						AND intAssocID = $assocID
				];
				my $qry_update = $db->prepare($st_update);
        			$qry_update->execute;
			}
		}
	}

	my $endtime=scalar localtime();
	print STDERR "END TIME: $endtime\n";
	print STDERR "\n\n--SEASONS CONVERSION DONE\n\n";

}

sub connectDB {

  my $db = DBI->connect("DBI:mysql:regoSWM_live", "root", "");
  if (!defined $db) { return "Database Error"; }
  else  { return $db; }

}


# DISCONNECT FROM DATABASE

sub disconnectDB {
  my($db)=@_;
  if(defined $db) {
    $db->disconnect;
  }
}

