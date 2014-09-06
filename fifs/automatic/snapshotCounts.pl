#!/usr/bin/perl -w

#
# $Header: svn://svn/SWM/trunk/automatic/snapshotCounts.pl 9471 2013-09-10 02:55:03Z tcourt $
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


	#The script will loop through each Assoc (and its clubs) and create snapshot data
  # of counts at a point in time	

	my @date = (localtime)[3..5]; # grabs day/month/year values
	my $year = $date[2] + 1900;
	my $month = $date[1] + 1;

	my $lastRunDate = getLastRunDate($db);


	my $defaultSeasons = getDefaultSeasons($db);
	
	#Loop through associations
	my $st_a = qq[
		SELECT
			intAssocID,
			intRealmID,
			intAssocTypeID,
			intCurrentSeasonID,
			intAllowSeasons
		FROM 
			tblAssoc
		WHERE 
			intRecStatus = $Defs::RECSTATUS_ACTIVE
			AND intAssocID=12607
	];
	my $q = $db->prepare($st_a);
	$q->execute();
	while(my $dref = $q->fetchrow_hashref())	{
		my $queries = setupQueries($db, $year, $month, $dref->{'intRealmID'});
		processAssoc(
			$db,
			$dref,
			$defaultSeasons,
			$queries,
			$lastRunDate
		);

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
			AND intAssocID=12607
	];
	$q = $db->prepare($st_a);
	$q->execute();
	while(my $dref = $q->fetchrow_hashref())	{
		my $queries = undef;
		processNode(
			$db,
			$dref,
			$defaultSeasons,
			$queries,
			$lastRunDate,
			10
		);
		updateNode($db, $dref->{'intRealmID'}, $dref->{'nodeID'}, 10, $year, $month);
	}

	insertSnapShotStamp($db);
}

sub updateNode	{

	my ($db, $realm, $nodeID, $level, $year, $month) = @_;

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
			tblSnapShotCounts_$realm as SNP
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


	my $st_money = qq[
		SELECT
			SUM(curMoney)
		FROM
			tblMoneyLog
		WHERE
			intEntityID=$nodeID
			AND intEntityTypeID=$level
			AND intLogType=6
			AND intPaymentTypeID IN ($Defs::PAYMENT_ONLINEPAYPAL, $Defs::PAYMENT_ONLINENAB)
  ];

			
	my $st_update = qq[
		UPDATE
			tblSnapShotCounts_$realm
		SET 
			intComps = ?,
			intCompTeams = ?,
			intTotalTeams = ?,
			intClubs = ?,
			intClrIn = ?,
			intClrOut = ?,
			intClrPermitIn = ?,
			intClrPermitOut = ?,
			intNewTribunal = ?,
			intTxns = ?,
			curTxnValue = ?
		WHERE
			intEntityID = $nodeID
			AND intEntityTypeID = $level
			AND intYear = $year
			AND intMonth = $month
		LIMIT 1
	];

	my $q_update = $db->prepare($st_update);
	$q_update->execute(
		$dref->{'SumComps'},
		$dref->{'SumCompTeams'},
		$dref->{'SumTotalTeams'},
		$dref->{'SumClubs'},
		$dref->{'SumClrIn'},
		$dref->{'SumClrOut'},
		$dref->{'SumPermitIn'},
		$dref->{'SumPermitOut'},
		$dref->{'SumTribunal'}
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

sub processNode	{
	my(
			$db,
			$assocref,
			$defaultSeasons,
			$queries,
			$lastRunDate,
			$levelRun
	) = @_;

	my $realmID = $assocref->{'intRealmID'} || return;
	my $seasonID = $assocref->{'intCurrentSeasonID'} 
		|| $defaultSeasons->{$assocref->{'intRealmID'}}{$assocref->{'intAssocTypeID'}};

	return 0 if !$seasonID;

	my $mstable = "tblMember_Seasons_$assocref->{'intRealmID'}";
	my $insert_qry = $queries->{'insert'};
	
	# LastRun Date ?
	# MA RecStatus Grouping ?
	# MC.intStatus if at club level ?
	# seperate tables 
	my $structureWHERE = qq[ AND T.int10_ID= $assocref->{'nodeID'} ];
	$structureWHERE = qq[ AND T.int20_ID= $assocref->{'nodeID'} ] if $levelRun == 20;
	$structureWHERE = qq[ AND T.int30_ID= $assocref->{'nodeID'} ] if $levelRun == 30;
	$structureWHERE = qq[ AND T.int100_ID= $assocref->{'nodeID'} ] if $levelRun == 100;
	my $st = qq[
		SELECT 
			intSeasonID,
			intGender as Gender,
			intPlayerAgeGroupID as AgeGroupID,
			COUNT(DISTINCT MS.intMemberID) AS Members,
			SUM(intPlayerStatus) AS Player,
			SUM(intCoachStatus) AS Coach,
			SUM(intUmpireStatus) AS Umpire,
			SUM(intOther1Status) AS Other1,
			SUM(intOther2Status) AS Other2,
			SUM(IF(dtCreatedOnline>$lastRunDate,1,0)) as NumNewMembers,
			SUM(intUsedRegoForm) as NumUsedRegoForm
		FROM $mstable AS MS
			INNER JOIN tblMember_Associations AS MA ON (
					MS.intAssocID = MA.intAssocID
					AND MS.intMemberID = MA.intMemberID
					AND MA.intRecStatus <> $Defs::RECSTATUS_DELETED
				)
				INNER JOIN tblMember as M ON (
					M.intMemberID=MS.intMemberID
				)
				INNER JOIN tblTempNodeStructure as T ON (
					T.intAssocID=MA.intAssocID
				)
				INNER JOIN tblAssoc as A ON (
					A.intAssocID=T.intAssocID
				)
		WHERE 
			MS.intSeasonID = A.intCurrentSeasonID
			AND MS.intClubID=0
			$structureWHERE
			AND MS.intMSRecStatus = $Defs::RECSTATUS_ACTIVE
			AND M.intStatus<> $Defs::RECSTATUS_DELETED
		GROUP BY
			M.intGender,
			MS.intPlayerAgeGroupID
	];
	my $q = $db->prepare($st);
	$q->execute();
	my %defaults = ();
	while(my $dref = $q->fetchrow_hashref())	{
		my $type = '';
		my $id = 0;
		my $money = 0;
		my $txnCount = 0;
			$id = $assocref->{'intAssocID'};
			$insert_qry->execute(
			$levelRun,
			$assocref->{'nodeID'},
			$dref->{'intSeasonID'},
			$dref->{'Gender'},
			$dref->{'AgeGroupID'},
			$dref->{'Members'},
			$dref->{'NumUsedRegoForm'},
			$dref->{'Player'},
			$dref->{'Coach'},
			$dref->{'Umpire'},
			$dref->{'Other1'},
			$dref->{'Other2'},
			0, #intComps,
			0, #intTeams,
			0, #intTotalTeams,
			0, #intClubs
			0, #intClrIn,
			0, #intClrOut,
			0, #intClrIn,
			0, #intClrOut,
			0, #intTxns,
			0, #curTxnValue,
			0
		);
	}
}

sub processAssoc	{
	my(
			$db,
			$assocref,
			$defaultSeasons,
			$queries,
			$lastRunDate
	) = @_;

  my $clubLevel = '';
	my $clubWHERE = $clubLevel ? qq[ AND MS.intClubID>0] : qq[ AND MS.intClubID=0];
	my $realmID = $assocref->{'intRealmID'} || return;
	my $seasonID = $assocref->{'intCurrentSeasonID'} || $defaultSeasons->{$assocref->{'intRealmID'}}{$assocref->{'intAssocTypeID'}};
	return 0 if !$seasonID;

	my $mstable = "tblMember_Seasons_$assocref->{'intRealmID'}";
	my $insert_qry = $queries->{'insert'};
	my $comp_qry = $queries->{'comps'};
	$comp_qry->execute(
		$assocref->{'intAssocID'},
		$seasonID,
	);
	my($numcomps, $numteams) = $comp_qry->fetchrow_array();
	$comp_qry->finish();


	my %Teams=();
	my $totalTeams = 0;
	my $teams_qry = $queries->{'Teams'};
	$teams_qry->execute(
		$assocref->{'intAssocID'},
	);
	while (my $dref = $teams_qry->fetchrow_hashref())	{
		$Teams{$dref->{'intClubID'}} = $dref->{'NumTeams'};
		$totalTeams += $dref->{'NumTeams'};
	}
	$Teams{'total'} = $totalTeams;
	$teams_qry->finish();

	my $clubs_qry = $queries->{'Clubs'};
	$clubs_qry->execute(
		$assocref->{'intAssocID'},
	);
	my($numClubs) = $clubs_qry->fetchrow_array();
	$clubs_qry->finish();

	my $clrData = get_clrData($db, $assocref, $queries);
	my $tribunalData = get_TribunalData($db, $assocref, $queries);
	my $moneyData = get_MoneyData($db, $assocref, $queries);
	
	my $st = qq[
		SELECT 
			MS.intClubID,	
			intGender as Gender,
			intPlayerAgeGroupID as AgeGroupID,
			COUNT(MS.intMemberID) AS Members,
			SUM(intPlayerStatus) AS Player,
			SUM(intCoachStatus) AS Coach,
			SUM(intUmpireStatus) AS Umpire,
			SUM(intOther1Status) AS Other1,
			SUM(intOther2Status) AS Other2,
			SUM(IF(dtCreatedOnline>$lastRunDate,1,0)) as NumNewMembers,
			SUM(intUsedRegoForm) as NumUsedRegoForm
		FROM $mstable AS MS
			INNER JOIN tblMember_Associations AS MA ON (
					MS.intAssocID = MA.intAssocID
					AND MS.intMemberID = MA.intMemberID
					AND MA.intRecStatus <> $Defs::RECSTATUS_DELETED
				)
				INNER JOIN tblMember as M ON (
					M.intMemberID=MS.intMemberID
				)
				INNER JOIN tblMember_Clubs as MC ON (
					MC.intMemberID=MS.intMemberID
					AND MC.intClubID=MS.intClubID
					AND MC.intStatus=1
				)
		WHERE 
			MS.intSeasonID = ?
			AND MS.intAssocID = ?
			$clubWHERE
			AND MS.intMSRecStatus = $Defs::RECSTATUS_ACTIVE
			AND M.intStatus<> $Defs::RECSTATUS_DELETED
		GROUP BY
			MS.intClubID,
			M.intGender,
			MS.intPlayerAgeGroupID
	];
	my $q = $db->prepare($st);
	$q->execute(
		$seasonID,
		$assocref->{'intAssocID'},
	);
	my %defaults = ();
	while(my $dref = $q->fetchrow_hashref())	{
		my $type = '';
		my $id = 0;
		my $clrIn = 0;
		my $clrOut = 0;
		my $clrPermitIn = 0;
		my $clrPermitOut = 0;
		my $tribunal = 0;
		my $totalTeams = 0;
		my $clubs = 0;
		my $money = 0;
		my $txnCount = 0;
		if($dref->{'intClubID'})	{
			$totalTeams = $Teams{$dref->{'intClubID'}} || 0;
			$type = $Defs::LEVEL_CLUB;
			$id = $dref->{'intClubID'};
			$clrIn = $clrData->{'In'}{$id} || 0;
			$clrOut = $clrData->{'Out'}{$id} || 0;
			$clrPermitIn = $clrData->{'PermitIn'}{$id} || 0;
			$clrPermitOut = $clrData->{'PermitOut'}{$id} || 0;
			$tribunal = $tribunalData->{$id} || 0;
			$money = $moneyData->{$id}{'amount'} || 0;
			$txnCount = $moneyData->{$id}{'count'} || 0;
			$numcomps=0;
			$numteams=0;
			$clubs=0;
		}
		else	{
			$clubs=$numClubs;
			$totalTeams = $Teams{'total'} || 0;
			$type = $Defs::LEVEL_ASSOC;
			$id = $assocref->{'intAssocID'};
			$clrIn = $clrData->{'In'}{'Total'} || 0;
			$clrOut = $clrData->{'Out'}{'Total'} || 0;
			$clrPermitIn = $clrData->{'PermitIn'}{'Total'} || 0;
			$clrPermitOut = $clrData->{'PermitTotal'}{'Total'} || 0;
			$tribunal = $tribunalData->{'Total'} || 0;
			$money = $moneyData->{'0'}{'amount'} || 0;
			$txnCount= $moneyData->{'0'}{'count'} || 0;
		}

		$insert_qry->execute(
			$type,
			$id,
			$seasonID,
			$dref->{'Gender'},
			$dref->{'AgeGroupID'},
			$dref->{'Members'},
			$dref->{'NumUsedRegoForm'},
			$dref->{'Player'},
			$dref->{'Coach'},
			$dref->{'Umpire'},
			$dref->{'Other1'},
			$dref->{'Other2'},
			$numcomps, #intComps,
			$numteams, #intTeams,
			$totalTeams, #intTotalTeams,
			$clubs, #intClubs
			$clrIn, #intClrIn,
			$clrOut, #intClrOut,
			$clrPermitIn, #intClrIn,
			$clrPermitOut, #intClrOut,
			$txnCount, #intTxns,
			$money, #curTxnValue,
			$tribunal
		);
	}
}

sub setupQueries {
	my(
		$db,
		$year,
		$month,
		$realm
	) = @_;
	
	my %queries = ();

	my $st_i = qq[
		INSERT IGNORE INTO tblSnapShotCounts_$realm (
			intYear,
			intMonth,
			intEntityTypeID,
			intEntityID,
			intSeasonID,
			intGender,
			intAgeGroupID,
			intMembers,
			intRegoFormMembers,
			intPlayer,
			intCoach,
			intUmpire,
			intOther1,
			intOther2,
			intComps,
			intCompTeams,
			intTotalTeams,
			intClubs,
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
			AND AC.intSeasonID = ?
			AND AC.intRecStatus = $Defs::RECSTATUS_ACTIVE
	];
	my $nextmonth = $month++;
	my $nextyear = $year;
	if($nextmonth > 12)	{
		$nextmonth = '1';
		$nextyear++;
	}
	$nextmonth = '0'.$nextmonth if length $nextmonth == 1;
	my $monthstart = "$year-$month-01";
	my $nextstart = "$nextyear-$nextmonth-01";
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
	];
	$queries{'Tribunal'} = $db->prepare($st_Tribunal);

	my $st_Money= qq[
		SELECT
			intClubPaymentID,
			SUM(intAmount),
			COUNT(intLogID)
		FROM
			tblTransLog
		WHERE 
			intAssocPaymentID = ?
			AND intPaymentType IN ($Defs::PAYMENT_ONLINEPAYPAL, $Defs::PAYMENT_ONLINENAB)
			AND intStatus=1
			AND dtLog >= '$monthstart'
			AND dtLog < '$nextstart'
	];
	$queries{'Money'} = $db->prepare($st_Money);


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
			COUNT(intClubID)
		FROM
			tblClub
		WHERE 
			intAssocID = ?
	];
	$queries{'Clubs'} = $db->prepare($st_Teams);



	my $st_clrIN = qq[
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
			AND intPermitType=0
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
	my($db, $assocref, $queries) = @_;

	my $qry = $queries->{'Tribunal'};
	$qry->execute(
		$assocref->{'intAssocID'},
	);
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
	my($db, $assocref, $queries) = @_;

	my $qry = $queries->{'Money'};
	$qry->execute(
		$assocref->{'intAssocID'},
	);
	my $total = 0;
	my $totalCount = 0;
	my %Data = ();
	while(my($club, $sum, $count) = $qry->fetchrow_array())	{
		$sum ||= 0;
		$club ||= 0;
		$total += $sum;
		$totalCount += $count;
		$Data{$club}{'amount'} = $sum;
		$Data{$club}{'count'} = $count;
	};
	$Data{'0'}{'amount'} = $total;
	$Data{'0'}{'Count'} = $totalCount;
	return \%Data;
}



sub get_clrData	{
	my($db, $assocref, $queries) = @_;

	my $clr_qry = $queries->{'clrIn'};
	$clr_qry->execute(
		$assocref->{'intAssocID'},
	);
	my $total = 0;
	my %clrData = ();
	while(my($club, $count) = $clr_qry->fetchrow_array())	{
		$club ||= 0;
		$total += $count;
		$clrData{'In'}{$club} = $count;
	};
	$clrData{'In'}{'Total'} = $total;

	$clr_qry = $queries->{'clrPermitIn'};
	$clr_qry->execute(
		$assocref->{'intAssocID'},
	);
	$total = 0;
	while(my($club, $count) = $clr_qry->fetchrow_array())	{
		$club ||= 0;
		$total += $count;
		$clrData{'PermitIn'}{$club} = $count;
	};
	$clrData{'PermitIn'}{'Total'} = $total;



	$clr_qry = $queries->{'clrOut'};
	$clr_qry->execute(
		$assocref->{'intAssocID'},
	);
	$total = 0;
	while(my($club, $count) = $clr_qry->fetchrow_array())	{
		$club ||= 0;
		$total += $count;
		$clrData{'Out'}{$club} = $count;
	};
	$clrData{'Out'}{'Total'} = $total;

	$clr_qry = $queries->{'clrPermitOut'};
	$clr_qry->execute(
		$assocref->{'intAssocID'},
	);
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

	my ($db) = @_;

	my $st = qq[
		INSERT INTO tblSnapShotRuns
		VALUES (NOW())
	];
	$db->do($st);
}
1;

