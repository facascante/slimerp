#!/usr/bin/perl -w

#
# $Header: svn://svn/SWM/trunk/automatic/snapshots.pl 8250 2013-04-08 08:24:36Z rlee $
#

use lib "../web","..";
use Defs;
use Utils;
use DBI;
use strict;


main();


sub main	{
	my $db=connectDB();

	my %Data=();
	$Data{'db'}=$db;

	my @date = (localtime)[3..5]; # grabs day/month/year values
	my $year = $date[2] + 1900;
	my $month = $date[1] + 1;
#	my $lastRunDate = getLastRunDate($db);
	#$year=2012;
	#$month=6;  #Month data for, ie: 6=June
$month=$date[1];
$year-- if $month==0;
    $month = 12 if $month==0;

  my $nextmonth = $month+1;
	my $nextyear = $year;
	if($nextmonth > 12) {
		$nextmonth = '1';
		$nextyear++;
	}
	$nextmonth = '0'.$nextmonth if length $nextmonth == 1;
	my $monthstart = "$year-$month-01";
	my $nextstart = "$nextyear-$nextmonth-01";
print "STARTED AT:". localtime() . "\n";


#print "THIS: $monthstart | MEXT: $nextstart\n";

#return;

	my $st_r = qq[	
		SELECT
			intRealmID
		FROM
			tblRealms
		WHERE intRealmID NOT IN (6,14,31,35)
	];
	my $q_realms = $db->prepare($st_r);
	$q_realms->execute();

	my $debugAssoc = '';
	#$debugAssoc = qq[ AND intAssocID=12607]; 

	while (my $rref = $q_realms->fetchrow_hashref())	{
		my $realmID = $rref->{'intRealmID'};
		my $moneyData = get_MoneyData($db, $year, $month, $realmID, $monthstart, $nextstart);
		cleanupTables($db, $year, $month, $realmID);
		my $st_a = qq[
			SELECT
				intAssocID,
				intCurrentSeasonID
			FROM 
				tblAssoc
			WHERE 
				intRecStatus = $Defs::RECSTATUS_ACTIVE
				AND intRealmID=$realmID
				$debugAssoc
		];
		my $q = $db->prepare($st_a);
		$q->execute();
		while(my $dref = $q->fetchrow_hashref())	{
			my $queries = setupQueries($db, $year, $month, $realmID, $monthstart, $nextstart);
			my $seasonID = $dref->{'intCurrentSeasonID'};
			processMemberCounts($db, $realmID, $dref->{'intAssocID'}, $Defs::LEVEL_CLUB, $queries, $monthstart, $nextstart);
			processMemberCounts($db, $realmID, $dref->{'intAssocID'}, $Defs::LEVEL_ASSOC, $queries, $monthstart, $nextstart);
			processEntityCounts($db, $realmID, $dref->{'intCurrentSeasonID'}, $dref->{'intAssocID'}, $queries, $moneyData);
		}

		my $st_10 = qq[
			SELECT DISTINCT
				int10_ID as nodeID,
				T.intRealmID,
				N.intSubTypeID as intAssocTypeID
			FROM
				tblTempNodeStructure as T
				INNER JOIN tblNode as N ON (
					N.intNodeID=T.int10_ID
				)
			WHERE 
				N.intStatusID=1
				AND T.intRealmID=$realmID
				$debugAssoc
		];
		$q = $db->prepare($st_10);
		$q->execute();
		while(my $dref = $q->fetchrow_hashref())	{
			my $queries = setupQueries($db, $year, $month, $realmID,  $monthstart, $nextstart);
			processMemberCounts($db, $realmID, $dref->{'nodeID'}, $Defs::LEVEL_ZONE,  $queries, $monthstart, $nextstart);
			updateNode($db, $realmID, $dref->{'nodeID'}, $Defs::LEVEL_ZONE, $year, $month, $moneyData);
		}
		my $st_20 = qq[
			SELECT DISTINCT
				int20_ID as nodeID,
				T.intRealmID,
				N.intSubTypeID as intAssocTypeID
			FROM
				tblTempNodeStructure as T
				INNER JOIN tblNode as N ON (
					N.intNodeID=T.int20_ID
				)
			WHERE 
				N.intStatusID=1
				AND T.intRealmID=$realmID
				$debugAssoc
		];
		$q = $db->prepare($st_20);
		$q->execute();
		while(my $dref = $q->fetchrow_hashref())	{
			my $queries = setupQueries($db, $year, $month, $realmID,  $monthstart, $nextstart);
			processMemberCounts($db, $realmID, $dref->{'nodeID'}, $Defs::LEVEL_REGION,  $queries, $monthstart, $nextstart);
			updateNode($db, $realmID, $dref->{'nodeID'}, $Defs::LEVEL_REGION, $year, $month, $moneyData);
		}

		my $st_30 = qq[
			SELECT DISTINCT
				int30_ID as nodeID,
				T.intRealmID,
				N.intSubTypeID as intAssocTypeID
			FROM
				tblTempNodeStructure as T
				INNER JOIN tblNode as N ON (
					N.intNodeID=T.int30_ID
				)
			WHERE 
				N.intStatusID=1
				AND T.intRealmID=$realmID
				$debugAssoc
		];
		$q = $db->prepare($st_30);
		$q->execute();
		while(my $dref = $q->fetchrow_hashref())	{
			my $queries = setupQueries($db, $year, $month, $realmID,  $monthstart, $nextstart);
			processMemberCounts($db, $realmID, $dref->{'nodeID'}, $Defs::LEVEL_STATE,  $queries, $monthstart, $nextstart);
			updateNode($db, $realmID, $dref->{'nodeID'}, $Defs::LEVEL_STATE, $year, $month, $moneyData);
		}

		my $st_100 = qq[
			SELECT DISTINCT
				int100_ID as nodeID,
				T.intRealmID,
				N.intSubTypeID as intAssocTypeID
			FROM
				tblTempNodeStructure as T
				INNER JOIN tblNode as N ON (
					N.intNodeID=T.int100_ID
				)
			WHERE 
				N.intStatusID=1
				AND T.intRealmID=$realmID
				$debugAssoc
		];
		$q = $db->prepare($st_100);
		$q->execute();
		while(my $dref = $q->fetchrow_hashref())	{
			my $queries = setupQueries($db, $year, $month, $realmID,  $monthstart, $nextstart);
			processMemberCounts($db, $realmID, $dref->{'nodeID'}, $Defs::LEVEL_NATIONAL,  $queries, $monthstart, $nextstart);
			updateNode($db, $realmID, $dref->{'nodeID'}, $Defs::LEVEL_NATIONAL, $year, $month, $moneyData);
		}
	print "REALMID$realmID IS DONE\n";
	}

	insertSnapShotStamp($db, $year, $month);
print "\nDONE AT:" . localtime() . "\n\n";
}

sub processEntityCounts	{
	my(
			$db,
			$realmID,
			$seasonID,
			$assocID,
			$queries,
			$moneyData
	) = @_;

	return 0 if  ! $assocID or ! $realmID;

 my $insert_qry = $queries->{'insertEntityCounts'};
 my $comp_qry = $queries->{'comps'};
  $comp_qry->execute(
    $assocID,
    $seasonID,
  );
  my($numcomps, $numteams) = $comp_qry->fetchrow_array();
  $comp_qry->finish();

  my %Teams=();
  my $totalTeams = 0;
  my $teams_qry = $queries->{'Teams'};
  $teams_qry->execute(
    $assocID,
  );
  while (my $dref = $teams_qry->fetchrow_hashref()) {
    $Teams{$dref->{'intClubID'}} = $dref->{'NumTeams'};
    $totalTeams += $dref->{'NumTeams'};
  }
  $Teams{'total'} = $totalTeams;
  $teams_qry->finish();

  my $clubs_qry = $queries->{'Clubs'};
  $clubs_qry->execute($assocID);
  my($numClubs) = $clubs_qry->fetchrow_array();
  $clubs_qry->finish();

  my $clrData = get_clrData($db, $assocID, $queries);
  my $tribunalData = get_TribunalData($db, $assocID, $queries);
  #my $moneyData = get_MoneyData($db, $assocID, $queries);

	my $st = qq[
		SELECT
			DISTINCT
			AC.intClubID
		FROM
			tblAssoc_Clubs as AC
			INNER JOIN tblClub as C ON (
				C.intClubID=AC.intClubID
			)
		WHERE
			AC.intRecStatus = 1
			AND C.intRecStatus=1
			AND AC.intAssocID=$assocID
	];

	my $q= $db->prepare($st);
	$q->execute();
	while (my $dref= $q->fetchrow_hashref())	{
		my $clubID = $dref->{'intClubID'};
		my $clrIn = $clrData->{'In'}{$clubID} || 0;
	  my $clrOut = $clrData->{'Out'}{$clubID} || 0;
		my $clrPermitIn = $clrData->{'PermitIn'}{$clubID} || 0;
		my $clrPermitOut = $clrData->{'PermitOut'}{$clubID} || 0;
		my $tribunal = $tribunalData->{$clubID} || 0;
		my $key = $clubID ."_3";
		my $money = $moneyData->{$key}{'amount'} || 0;
		my $txnCount = $moneyData->{$key}{'count'} || 0;
 		$insert_qry->execute(
    	3,
			$dref->{'intClubID'},
			$seasonID,
			1,
			0,
			$numteams,
			$Teams{$dref->{'intClubID'}},
			$clrIn,
			$clrOut,
			$clrPermitIn,
			$clrPermitOut,
			$txnCount,
			$money,
			$tribunal
		);
	}
	my $clrIn = $clrData->{'In'}{'Total'} || 0;
	my $clrOut = $clrData->{'Out'}{'Total'} || 0;
	my $clrPermitIn = $clrData->{'PermitIn'}{'Total'} || 0;
	my $clrPermitOut = $clrData->{'PermitOut'}{'Total'} || 0;
	my $tribunal = $tribunalData->{'Total'} || 0;
	my $key = $assocID ."_5";
	my $money = $moneyData->{$key}{'amount'} || 0;
	my $txnCount = $moneyData->{$key}{'count'} || 0;
 	$insert_qry->execute(
   	$Defs::LEVEL_ASSOC,
		$assocID,
		$seasonID,
		$numClubs,
		$numcomps,
		$numteams,
		$totalTeams,
		$clrIn,
		$clrOut,
		$clrPermitIn,
		$clrPermitOut,
		$txnCount,
		$money,
		$tribunal
	);
	return;
}

sub updateNode	{

	my ($db, $realm, $nodeID, $level, $year, $month, $moneyData) = @_;

	my $structureWHERE = qq[ T.int10_ID= $nodeID ];
	$structureWHERE = qq[ T.int20_ID= $nodeID ] if $level == 20;
	$structureWHERE = qq[ T.int30_ID= $nodeID ] if $level == 30;
	$structureWHERE = qq[ T.int100_ID= $nodeID ] if $level == 100;
	my $st = qq[
		SELECT
			SUM(intComps) as SumComps,
			SUM(intCompTeams) as SumCompTeams,
			SUM(intTotalTeams) as SumTotalTeams,
			SUM(intClubs) as SumClubs,
			SUM(intClrIn) as SumClrIn,
			SUM(intClrOut) as SumClrOut,
			SUM(intClrPermitIn) as SumPermitIn,
			SUM(intClrPermitOut) as SumPermitOut,
			SUM(intNewTribunal) as SumTribunal
		FROM
			tblSnapShotEntityCounts_$realm as SNP
			INNER JOIN tblTempNodeStructure as T ON (
				T.intAssocID = SNP.intEntityID
				AND SNP.intEntityTypeID=5
			)
		WHERE
			$structureWHERE	
			AND SNP.intYear = $year
			AND SNP.intMonth = $month
	];
	my $q= $db->prepare($st);
	$q->execute();
	my $dref= $q->fetchrow_hashref();


	my $st_entitycounts = qq[
		INSERT INTO tblSnapShotEntityCounts_$realm
		( intEntityID, intEntityTypeID, intYear, intMonth, intComps, intCompTeams, intTotalTeams, intClubs, intClrIn, intClrOut, intClrPermitIn, intClrPermitOut, intNewTribunal, intTxns, curTxnValue)
		VALUES ( $nodeID, $level, $year, $month, ?,?,?,?,?,?,?,?,?,?,?)
	];

	my $key = $nodeID . "_$level";
	my $money = $moneyData->{$key}{'amount'} || 0;
	my $TXNCount= $moneyData->{$key}{'count'} || 0;
	my $q_entitycounts= $db->prepare($st_entitycounts);
	$q_entitycounts->execute(
		$dref->{'SumComps'} || 0,
		$dref->{'SumCompTeams'} || 0,
		$dref->{'SumTotalTeams'} || 0,
		$dref->{'SumClubs'} || 0,
		$dref->{'SumClrIn'} || 0,
		$dref->{'SumClrOut'} || 0,
		$dref->{'SumPermitIn'} || 0,
		$dref->{'SumPermitOut'} || 0,
		$dref->{'SumTribunal'} || 0,
		$TXNCount,
		$money
	);
}

sub getLastRunDate	{

	my ($db) = @_;

	my $st = qq[
		SELECT 
			MAX(dtLastRun)
		FROM
			tblSnapShotRuns
	];
	my $q = $db->prepare($st);
	$q->execute();
	my $dt = $q->fetchrow_array() || '0000-00-00';
	return $dt;
}

sub getDefaultSeasons	{
	my ($db) = @_;

	my $st = qq[
		SELECT
			intRealmID,
			intSubTypeID,
			strValue
		FROM
			tblSystemConfig
		WHERE strValue = 'Seasons_defaultCurrentSeason'
	];
	my $q = $db->prepare($st);
	$q->execute();
	my %defaults = ();
	while(my $dref = $q->fetchrow_hashref())	{
		$defaults{$dref->{'intRealmID'}}{$dref->{'intSubTypeID'}} = $dref->{'strValue'} || next;
	}
	return \%defaults;
}

sub processMemberCounts	{
	my(
			$db,
			$realmID,
			$ID,
			$level,
			$queries,
			$monthstart, 
			$nextmonth
	) = @_;

	my $clubWHERE = $level == $Defs::LEVEL_CLUB ? qq[ AND MS.intClubID>0 AND MC.intMemberClubID > 0] : qq[ AND MS.intClubID=0];
	my $tempStructureJOIN = '';
	my $assocWHERE = '';
	if ($level > $Defs::LEVEL_ASSOC)	{
		my $structureWHERE = qq[ AND T.int10_ID= $ID ];
		$structureWHERE = qq[ AND T.int20_ID= $ID ] if $level == 20;
		$structureWHERE = qq[ AND T.int30_ID= $ID ] if $level == 30;
		$structureWHERE = qq[ AND T.int100_ID= $ID ] if $level == 100;
		$tempStructureJOIN  =qq[
			INNER JOIN tblTempNodeStructure as T ON (
				T.intAssocID = MS.intAssocID
				$structureWHERE
			)
		];
	}
	else	{
		$assocWHERE = qq[ AND MS.intAssocID = $ID ];
	}
	return 0 if  ! $realmID;

	my $memberclubJOIN = qq[
				LEFT JOIN tblMember_Clubs as MC ON (
					MC.intMemberID=MS.intMemberID
					AND MC.intClubID=MS.intClubID
					AND MC.intStatus=1
				)
	];
	$memberclubJOIN = '' unless $level == $Defs::LEVEL_CLUB;
	my $mstable = "tblMember_Seasons_$realmID";
	my $insert_qry = $queries->{'insert'};
	my $seasonID=0;
	my $st = qq[
		SELECT DISTINCT
			MS.intClubID,	
			intGender as Gender,
			intPlayerAgeGroupID as AgeGroupID,
			MS.intMemberID,
			MS.intSeasonID,
			intPlayerStatus AS Player,
			intCoachStatus AS Coach,
			intUmpireStatus AS Umpire,
			intOther1Status AS Other1,
			intOther2Status AS Other2,
			IF(dtCreatedOnline>"$monthstart" and dtCreatedOnline<="$nextmonth",1,0) as NumNewMembers,
			intUsedRegoForm as NumUsedRegoForm
		FROM $mstable AS MS
			INNER JOIN tblMember_Associations AS MA ON (
					MS.intAssocID = MA.intAssocID
					AND MS.intMemberID = MA.intMemberID
					AND MA.intRecStatus <> $Defs::RECSTATUS_DELETED
				)
				INNER JOIN tblMember as M ON (
					M.intMemberID=MS.intMemberID
					AND M.intRealmID=$realmID
				)
				INNER JOIN tblAssoc as A ON (
					A.intAssocID=MS.intAssocID
				)
				$tempStructureJOIN
				$memberclubJOIN
		WHERE 
			MS.intSeasonID = A.intCurrentSeasonID
			$assocWHERE
			$clubWHERE
			AND MS.intMSRecStatus = $Defs::RECSTATUS_ACTIVE
		GROUP BY
			MS.intMemberID,
			MS.intClubID,
			M.intGender,
			MS.intPlayerAgeGroupID
	];
			#AND M.intStatus<> $Defs::RECSTATUS_DELETED
	my $q = $db->prepare($st);
	$q->execute();
	my %defaults = ();
	my %Counts=();
	my %Records=();
	while(my $dref = $q->fetchrow_hashref())	{
		$seasonID = $dref->{'intSeasonID'} || 0;
		my $clubID = $dref->{'intClubID'} || 0;
		my $gender= $dref->{'Gender'} || 0;
		my $agegroup = $dref->{'AgeGroupID'} || 0;
		my $key = "$gender"."_$agegroup"."_$clubID";
		if (! exists $Records{$key})	{
		$Counts{$gender}{$agegroup}{$clubID}{'Members'}=0;# if (! defined $Counts{$gender}{$agegroup}{$clubID}{'Members'});
		$Counts{$gender}{$agegroup}{$clubID}{'Player'}=0;# if (! defined $Counts{$gender}{$agegroup}{$clubID}{'Player'});
		$Counts{$gender}{$agegroup}{$clubID}{'Coach'}=0;# if (! defined $Counts{$gender}{$agegroup}{$clubID}{'Coach'});
		$Counts{$gender}{$agegroup}{$clubID}{'Umpire'}=0;# if (! defined $Counts{$gender}{$agegroup}{$clubID}{'Umpire'});
		$Counts{$gender}{$agegroup}{$clubID}{'Other1'}=0;# if (! defined $Counts{$gender}{$agegroup}{$clubID}{'Other1'});
		$Counts{$gender}{$agegroup}{$clubID}{'Other2'}=0;# if (! defined $Counts{$gender}{$agegroup}{$clubID}{'Other2'});
		$Counts{$gender}{$agegroup}{$clubID}{'NumNewMembers'}=0;# if (! defined $Counts{$gender}{$agegroup}{$clubID}{'NumNewMembers'});
		$Counts{$gender}{$agegroup}{$clubID}{'NumUsedRegoForm'}=0;# if (! defined $Counts{$gender}{$agegroup}{$clubID}{'NumUsedRegoForm'});
		}
		$Records{$key}=1;

		$Counts{$gender}{$agegroup}{$clubID}{'Members'}++;
		$Counts{$gender}{$agegroup}{$clubID}{'Player'}++ if ($dref->{'Player'});
		$Counts{$gender}{$agegroup}{$clubID}{'Coach'}++ if ($dref->{'Coach'});
		$Counts{$gender}{$agegroup}{$clubID}{'Umpire'}++ if ($dref->{'Umpire'});
		$Counts{$gender}{$agegroup}{$clubID}{'Other1'}++ if ($dref->{'Other1'});
		$Counts{$gender}{$agegroup}{$clubID}{'Other2'}++ if ($dref->{'Other2'});
		$Counts{$gender}{$agegroup}{$clubID}{'NumNewMembers'}++ if ($dref->{'NumNewMembers'});
		$Counts{$gender}{$agegroup}{$clubID}{'NumUsedRegoForm'}++ if ($dref->{'NumUsedRegoForm'});
	}
	foreach my $gender (keys %Counts)	{
		foreach my $agegroup (keys %{$Counts{$gender}})	{
			foreach my $club (keys %{$Counts{$gender}{$agegroup}})	{
				my $type=$club ? $Defs::LEVEL_CLUB : $Defs::LEVEL_ASSOC;
				my $id = $club || $ID ;
				#BAFF
 				$insert_qry->execute(
      		$level,
      		$id,
      		$seasonID,
      		$gender,
      		$agegroup,
      		$Counts{$gender}{$agegroup}{$club}{'Members'},
      		$Counts{$gender}{$agegroup}{$club}{'NumUsedRegoForm'},
      		$Counts{$gender}{$agegroup}{$club}{'NumNewMembers'},
      		$Counts{$gender}{$agegroup}{$club}{'Player'},
      		$Counts{$gender}{$agegroup}{$club}{'Coach'},
      		$Counts{$gender}{$agegroup}{$club}{'Umpire'},
      		$Counts{$gender}{$agegroup}{$club}{'Other1'},
      		$Counts{$gender}{$agegroup}{$club}{'Other2'}
    		);
			}
		}
	}
}

sub setupQueries {
	my(
		$db,
		$year,
		$month,
		$realm,
		$monthstart,
		$nextstart
	) = @_;
	
	my %queries = ();

	my $st_ie = qq[
		INSERT IGNORE INTO tblSnapShotEntityCounts_$realm (
			intYear,
			intMonth,
			intEntityTypeID,
			intEntityID,
			intSeasonID,
			intClubs,
			intComps,
  		intCompTeams,
  		intTotalTeams,
  		intClrIn,
  		intClrOut,
  		intClrPermitIn,
  		intClrPermitOut,
  		intTxns,
  		curTxnValue,
  		intNewTribunal
		)
		VALUES (
			$year,
			$month,
			?,
			?,
			?,
			?,
			?,
			?,
			?,
			?,
			?,
			?,
			?,
			?,
			?,
			?
		)

	];
	$queries{'insertEntityCounts'} = $db->prepare($st_ie);



	my $st_i = qq[
		INSERT IGNORE INTO tblSnapShotMemberCounts_$realm (
			intYear,
			intMonth,
			intEntityTypeID,
			intEntityID,
			intSeasonID,
			intGender,
			intAgeGroupID,
			intMembers,
			intRegoFormMembers,
			intNewMembers,
			intPlayer,
			intCoach,
			intUmpire,
			intOther1,
			intOther2
		)
		VALUES (
			$year,
			$month,
			?,
			?,
			?,
			?,
			?,
			?,
			?,
			?,
			?,
			?,
			?,
			?,
			?
		)

	];
	$queries{'insert'} = $db->prepare($st_i);

	my $st_c = qq[
		SELECT
			COUNT(DISTINCT AC.intCompID),
			COUNT(DISTINCT T.intTeamID)
		FROM
			tblAssoc_Comp AS AC
				LEFT JOIN  tblComp_Teams AS CT
					ON (
						AC.intCompID = CT.intCompID
						AND CT.intRecStatus = $Defs::RECSTATUS_ACTIVE
					)
				LEFT JOIN  tblTeam AS T
					ON (
						CT.intTeamID = T.intTeamID
						AND T.intRecStatus = $Defs::RECSTATUS_ACTIVE
				)
		WHERE 
			AC.intAssocID = ?
			AND AC.intNewSeasonID = ?
			AND AC.intRecStatus = $Defs::RECSTATUS_ACTIVE
	];
	$queries{'comps'} = $db->prepare($st_c);

	my $st_Tribunal = qq[
		SELECT
			intClubID,
			COUNT(intTribunalID)
		FROM
			tblTribunal 
		WHERE 
			intAssocID = ?
			AND dtCreated>= '$monthstart'
			AND dtCreated < '$nextstart'
		GROUP BY intClubID
	];
	$queries{'Tribunal'} = $db->prepare($st_Tribunal);

	#my $st_Money= qq[
	#	SELECT
	#		intClubPaymentID,
	#		SUM(intAmount),
	#		COUNT(intLogID)
	#	FROM
	#		tblTransLog
	#	WHERE 
	#		intAssocPaymentID = ?
	#		AND intPaymentType IN ($Defs::PAYMENT_ONLINEPAYPAL, $Defs::PAYMENT_ONLINENAB)
	#		AND intStatus=1
	#		AND dtLog >= '$monthstart'
	#		AND dtLog < '$nextstart'
	#		AND intRealmID=$realm
	#	GROUP BY intClubPaymentID
	#];
	#$queries{'Money'} = $db->prepare($st_Money);


	my $st_Teams= qq[
		SELECT
			intClubID,
			COUNT(intTeamID) as NumTeams
		FROM
			tblTeam
		WHERE 
			intAssocID = ?
		GROUP BY 
			intClubID
	];
	$queries{'Teams'} = $db->prepare($st_Teams);

	my $st_Clubs= qq[
		SELECT
			COUNT(DISTINCT C.intClubID)
		FROM
			tblClub as C 
			INNER JOIN tblAssoc_Clubs as AC ON (AC.intClubID=C.intClubID)
		WHERE 
			C.intRecStatus=1
			AND AC.intRecStatus=1
			AND intAssocID = ?
	];
	$queries{'Clubs'} = $db->prepare($st_Clubs);



	my $st_clrIN = qq[
		SELECT
			intDestinationClubID,
			COUNT(intClearanceID)
		FROM
			tblClearance
		WHERE 
			intDestinationAssocID = ?
			AND intClearanceStatus = $Defs::CLR_STATUS_APPROVED
			AND intPermitType=0
			AND dtFinalised >= '$monthstart'
			AND dtFinalised < '$nextstart'
		GROUP BY
			intDestinationClubID
	];
	$queries{'clrIn'} = $db->prepare($st_clrIN);

	my $st_clrOUT = qq[
		SELECT
			intSourceClubID,
			COUNT(intClearanceID)
		FROM
			tblClearance
		WHERE 
			intSourceAssocID = ?
			AND intClearanceStatus = $Defs::CLR_STATUS_APPROVED
			AND dtFinalised >= '$monthstart'
			AND dtFinalised < '$nextstart'
			AND intPermitType=0
		GROUP BY
			intSourceClubID
	];
	$queries{'clrOut'} = $db->prepare($st_clrOUT);

	my $st_clrPermitIN = qq[
		SELECT
			intDestinationClubID,
			COUNT(intClearanceID)
		FROM
			tblClearance
		WHERE 
			intDestinationAssocID = ?
			AND intClearanceStatus = $Defs::CLR_STATUS_APPROVED
			AND dtFinalised >= '$monthstart'
			AND dtFinalised < '$nextstart'
			AND intPermitType>0
		GROUP BY
			intDestinationClubID
	];
	$queries{'clrPermitIn'} = $db->prepare($st_clrPermitIN);

	my $st_clrPermitOUT = qq[
		SELECT
			intSourceClubID,
			COUNT(intClearanceID)
		FROM
			tblClearance
		WHERE 
			intSourceAssocID = ?
			AND intClearanceStatus = $Defs::CLR_STATUS_APPROVED
			AND dtFinalised >= '$monthstart'
			AND dtFinalised < '$nextstart'
			AND intPermitType>0
		GROUP BY
			intSourceClubID
	];
	$queries{'clrPermitOut'} = $db->prepare($st_clrPermitOUT);


	return \%queries;
}

sub get_TribunalData	{
	my($db, $assocID, $queries) = @_;

	my $qry = $queries->{'Tribunal'};
	$qry->execute($assocID);
	my $total = 0;
	my %Data = ();
	while(my($club, $count) = $qry->fetchrow_array())	{
		$club ||= 0;
		$total += $count;
		$Data{$club} = $count;
	};
	$Data{'Total'} = $total;
	return \%Data;
}
sub get_MoneyData	{
	my($db, $year, $month, $realm, $monthstart, $nextstart) = @_;

 	my $st_money = qq[
    SELECT
			intEntityID,
			intEntityType,
      SUM(curMoney) as SumMoney,
      COUNT(DISTINCT intTransLogID) as CountTXNs
    FROM
      tblMoneyLog as ML
      INNER JOIN tblTransLog as TL ON (TL.intLogID=ML.intTransLogID)
    WHERE
      intLogType=6
      AND intPaymentType IN ($Defs::PAYMENT_ONLINEPAYPAL, $Defs::PAYMENT_ONLINENAB)
      AND TL.intRealmID=$realm
			AND dtLog >='$monthstart'
      AND dtLog < '$nextstart'
		GROUP BY
			intEntityID,
			intEntityType
  ];
  my $q_money= $db->prepare($st_money);
  $q_money->execute();
	my %Data=();
	while(my $dref = $q_money->fetchrow_hashref())	{
		my $key = "$dref->{'intEntityID'}_$dref->{'intEntityType'}";
		$Data{$key}{'amount'} = $dref->{'SumMoney'};
		$Data{$key}{'count'} = $dref->{'CountTXNs'};
	}
	return \%Data;
}



sub get_clrData	{
	my($db, $assocID, $queries) = @_;

	my $clr_qry = $queries->{'clrIn'};
	$clr_qry->execute($assocID) ;
	my $total = 0;
	my %clrData = ();
	while(my($club, $count) = $clr_qry->fetchrow_array())	{
		$club ||= 0;
		$total += $count;
		$clrData{'In'}{$club} = $count;
	};
	$clrData{'In'}{'Total'} = $total;

	$clr_qry = $queries->{'clrPermitIn'};
	$clr_qry->execute($assocID);
	$total = 0;
	while(my($club, $count) = $clr_qry->fetchrow_array())	{
		$club ||= 0;
		$total += $count;
		$clrData{'PermitIn'}{$club} = $count;
	};
	$clrData{'PermitIn'}{'Total'} = $total;



	$clr_qry = $queries->{'clrOut'};
	$clr_qry->execute($assocID);
	$total = 0;
	while(my($club, $count) = $clr_qry->fetchrow_array())	{
		$club ||= 0;
		$total += $count;
		$clrData{'Out'}{$club} = $count;
	};
	$clrData{'Out'}{'Total'} = $total;

	$clr_qry = $queries->{'clrPermitOut'};
	$clr_qry->execute($assocID);
	$total = 0;
	while(my($club, $count) = $clr_qry->fetchrow_array())	{
		$club ||= 0;
		$total += $count;
		$clrData{'PermitOut'}{$club} = $count;
	};
	$clrData{'PermitOut'}{'Total'} = $total;


	return \%clrData;
}

sub insertSnapShotStamp	{

	my ($db, $year, $month) = @_;

	my $st = qq[
		INSERT INTO tblSnapShotRuns (intYear, intMonth, dtLastRun)
		VALUES ($year, $month, NOW())
	];
	$db->do($st);
}
sub cleanupTables	{

	my ($db, $year, $month, $realmID) = @_;

	my $st = qq[ DELETE FROM tblSnapShotEntityCounts_$realmID WHERE intYear=$year AND intMonth=$month];
	$db->do($st);

	$st = qq[ DELETE FROM tblSnapShotMemberCounts_$realmID WHERE intYear=$year AND intMonth=$month];
	$db->do($st);

	$st = qq[ DELETE FROM tblSnapShotRuns WHERE intYear=$year AND intMonth=$month];
	$db->do($st);
}

1;

