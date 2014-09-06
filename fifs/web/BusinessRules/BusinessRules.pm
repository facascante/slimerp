#
# $Header: svn://svn/SWM/trunk/web/BusinessRules/BusinessRules.pm 9493 2013-09-10 05:18:40Z tcourt $
#

package BusinessRules;
require Exporter;
@ISA = qw(Exporter);
@EXPORT=qw(checkVenues checkMemberDOBInComp checkCompMemberGender checkMemberInMultiClubsOverComps checkMemberInMultiTeamsOverComps checkMemberInMultiTeamsOverComps_SameClub checkMemberPlayingRegistered);
@EXPORT_OK=qw(checkVenues checkMemberDOBInComp checkCompMemberGender checkMemberInMultiClubsOverComps checkMemberInMultiTeamsOverComps checkMemberInMultiTeamsOverComps_SameClub checkMemberPlayingRegistered);

use lib '.', '..', '../..', "../sportstats";

use strict;
use Reg_common;
use Utils;
use HTMLForm;
use AssocOptions;
use DefCodes;
use AuditLog;
use CGI qw(param unescape escape);

sub checkVenues	{
    my ($Data, $schedule_ref)=@_;
		$schedule_ref->{'strRuleOption'} || next;
		my $ruleOption = ($schedule_ref->{'strRuleOption'}) ? qq[ AND $schedule_ref->{'strRuleOption'}] : '';

		my @params=();
		push @params, $schedule_ref->{'intScheduleByID'};
    my $st = qq[
				SELECT 
					intDefVenueID, 
					strName 
				FROM 
					tblDefVenue 
				WHERE intAssocID=? 
					AND intRecStatus=$Defs::RECSTATUS_ACTIVE 
					$ruleOption
    ];
		if ($schedule_ref->{'intAcknowledgeDtLastRun'})	{
			$st .= qq[ AND tTimeStamp>=? ];
			push @params, $schedule_ref->{'dtLastRun'};
		}
    my $qry= $Data->{'db'}->prepare($st);
    $qry->execute(@params) or query_error($st);

		my $count=0;

		my @Rows=();
		while (my $dref = $qry->fetchrow_hashref())	{
			$count++;
			my %result=();
			$result{'venue_id'}= $dref->{'intDefVenueID'};
			$result{'venue_name'} = $dref->{'strName'};
			$result{'url'} = '';
			$result{'venue_link'} = qq[<a href="$Data->{'target'}?client=XXX_CLIENT_XXX&amp;a=VENUE_DTE&venueID=$dref->{'intDefVenueID'}">$dref->{'strName'}</a>];
			push @Rows, \%result;
		}
		return ($count, \@Rows);
}

sub checkMemberDOBInComp	{
    my ($Data, $schedule_ref)=@_;

		my @params=();
		push @params, $schedule_ref->{'intScheduleByID'};
		my $st_params = qq[
			SELECT
				intParamTableType,
				intParamID
			FROM
				tblBusinessRuleScheduleParams
			WHERE
				intBusinessRuleScheduleID = ?
		];

    my $st = qq[
				SELECT 
					DISTINCT
					M.intMemberID,
					M.strFirstname,
					M.strSurname,
					DATE_FORMAT(M.dtDOB, "%Y/%M/%d") as dateDOB,
					T.intTeamID,
					T.strName as TeamName,
					AC.strTitle as CompName,
					DATE_FORMAT(Mtch.dtMatchTime, "%d/%m/%Y") as dateMatchTime
				FROM
					tblCompMatches as Mtch
					INNER JOIN tblAssoc_Comp as AC ON (
						AC.intCompID = Mtch.intCompID
					)
					INNER JOIN tblCompMatchSelectedPlayers as SP ON (
						SP.intMatchID=Mtch.intMatchID
					)
					INNER JOIN tblTeam as T ON (
						T.intTeamID = SP.intTeamID
					)
					INNER JOIN tblMember as M ON (
						M.intMemberID = SP.intMemberID
					)
				WHERE 
					AC.intAssocID=?
		];
		if ($schedule_ref->{'strRuleOption'} eq 'TOO YOUNG')	{
			$st .= qq[
					AND M.dtDOB > AC.dtMaxDOB
					AND AC.dtMaxDOB >'0000-00-00'
					AND AC.dtMaxDOB IS NOT NULL
			];
		}
		else	{
		## BY DEFAULT CHECK PEOPLE TOO OLD
			$st .= qq[
					AND M.dtDOB < AC.dtMinDOB
					AND AC.dtMinDOB >'0000-00-00'
					AND AC.dtMinDOB IS NOT NULL
			];
		}
		$st .= qq[ AND AC.intNewSeasonID =? ] if ($schedule_ref->{'intParamTableType'}== 101);
		$st .= qq[ AND AC.intCompID =? ] if ($schedule_ref->{'intParamTableType'}== $Defs::LEVEL_COMP);

		$st .= qq[ AND (SP.tTimeStamp>=?) ] if ($schedule_ref->{'intAcknowledgeDtLastRun'});
    my $qry= $Data->{'db'}->prepare($st);
		
    my $qry_params = $Data->{'db'}->prepare($st_params);
    $qry_params->execute($schedule_ref->{'intBusinessRuleScheduleID'}) or query_error($st_params);

		my $multirows = '';
		my $count=0;
		my @Rows=();
		while (my $params_ref = $qry_params->fetchrow_hashref())	{
			push @params, $params_ref->{'intParamID'};
			push @params, $schedule_ref->{'dtLastRun'} if ($schedule_ref->{'intAcknowledgeDtLastRun'});
    	$qry->execute(@params) or query_error($st);
			while (my $dref = $qry->fetchrow_hashref())	{
				$count++;
				my %result=();
				$result{'member_id'}= $dref->{'intMemberID'};
				$result{'member_name'} = qq[$dref->{'strFirstname'} $dref->{'strSurname'}];
				$result{'team_name'} = $dref->{'TeamName'};
				$result{'comp_name'} = $dref->{'CompName'};
				$result{'matchdate'} = $dref->{'dateMatchTime'};
				$result{'url'} = '';
				$result{'member_link'} = qq[<a target="new_window" href="$Data->{'target'}?client=XXX_MEMBERCLIENT$dref->{'intMemberID'}_XXX&amp;a=M_HOME">$dref->{'strFirstname'} $dref->{'strSurname'}</a>];
				$result{'team_link'} = qq[<a target="new_window" href="$Data->{'target'}?client=XXX_TEAMCLIENT$dref->{'intTeamID'}_XXX&amp;a=T_DT">$dref->{'TeamName'}</a>];
				push @Rows, \%result;
			}
		}
		my $body = $schedule_ref->{'strNotificationHeaderText'} . qq[<br>].$multirows;

		return ($count, \@Rows);
}

sub checkCompMemberGender	{
    my ($Data, $schedule_ref)=@_;

		my $ruleOption = ($schedule_ref->{'strRuleOption'}) ? qq[ AND $schedule_ref->{'strRuleOption'}] : '';
		my @params=();
		push @params, $schedule_ref->{'intScheduleByID'};
		my $st_params = qq[
			SELECT
				intParamTableType,
				intParamID
			FROM
				tblBusinessRuleScheduleParams
			WHERE
				intBusinessRuleScheduleID = ?
		];

		my $MStablename = qq[tblMember_Seasons_$schedule_ref->{'intRealmID'}];
    my $st = qq[
				SELECT 
					DISTINCT
					M.intMemberID,
					M.strFirstname,
					M.strSurname,
					DATE_FORMAT(M.dtDOB, "%Y/%M/%d") as dateDOB,
					T.intTeamID,
					T.strName as TeamName,
					AC.strTitle as CompName,
					DATE_FORMAT(Mtch.dtMatchTime, "%d/%m/%Y") as dateMatchTime
				FROM
					tblCompMatches as Mtch
					INNER JOIN tblAssoc_Comp as AC ON (
						AC.intCompID = Mtch.intCompID
					)
					INNER JOIN tblCompMatchSelectedPlayers as SP ON (
						SP.intMatchID=Mtch.intMatchID
					)
					INNER JOIN tblTeam as T ON (
						T.intTeamID = SP.intTeamID
					)
					INNER JOIN tblMember as M ON (
						M.intMemberID = SP.intMemberID
					)
					LEFT JOIN $MStablename as MS ON (
						MS.intMemberID=SP.intMemberID
						AND MS.intAssocID=AC.intAssocID
						AND MS.intSeasonID=AC.intNewSeasonID
						AND MS.intClubID=T.intClubID
					)
				WHERE 
					M.intGender <> AC.intCompGender
					AND M.intGender>0
					AND AC.intCompGender <> 3
					AND AC.intAssocID=?
					$ruleOption
    ];
		$st .= qq[ AND AC.intNewSeasonID =? ] if ($schedule_ref->{'intParamTableType'}== 101);
		$st .= qq[ AND AC.intCompID =? ] if ($schedule_ref->{'intParamTableType'}== $Defs::LEVEL_COMP);

		$st .= qq[ AND (SP.tTimeStamp>=?) ] if ($schedule_ref->{'intAcknowledgeDtLastRun'});

		$st .= qq[ 
			ORDER BY
				strSurname, 
				strFirstname,
				dtMatchTime
		];
    my $qry= $Data->{'db'}->prepare($st);
		
    my $qry_params = $Data->{'db'}->prepare($st_params);
    $qry_params->execute($schedule_ref->{'intBusinessRuleScheduleID'}) or query_error($st_params);

		my $multirows = '';
		my $count=0;
		my @Rows=();
		while (my $params_ref = $qry_params->fetchrow_hashref())	{
			push @params, $params_ref->{'intParamID'};
			push @params, $schedule_ref->{'dtLastRun'} if ($schedule_ref->{'intAcknowledgeDtLastRun'});
    	$qry->execute(@params) or query_error($st);
			while (my $dref = $qry->fetchrow_hashref())	{
				$count++;
				my %result=();
				$result{'member_id'}= $dref->{'intMemberID'};
				$result{'member_name'} = qq[$dref->{'strFirstname'} $dref->{'strSurname'}];
				$result{'team_name'} = $dref->{'TeamName'};
				$result{'comp_name'} = $dref->{'CompName'};
				$result{'matchdate'} = $dref->{'dateMatchTime'};
				$result{'url'} = '';
				$result{'member_link'} = qq[<a target="new_window" href="$Data->{'target'}?client=XXX_MEMBERCLIENT$dref->{'intMemberID'}_XXX&amp;a=M_HOME">$dref->{'strFirstname'} $dref->{'strSurname'}</a>];
				$result{'team_link'} = qq[<a target="new_window" href="$Data->{'target'}?client=XXX_TEAMCLIENT$dref->{'intTeamID'}_XXX&amp;a=T_DT">$dref->{'TeamName'}</a>];
				push @Rows, \%result;
			}
		}
		my $body = $schedule_ref->{'strNotificationHeaderText'} . qq[<br>].$multirows;

		return ($count, \@Rows);
}

sub checkMemberInMultiClubsOverComps {
    my ($Data, $schedule_ref)=@_;
		my $ruleOption = ($schedule_ref->{'strRuleOption'}) ? qq[ AND $schedule_ref->{'strRuleOption'}] : '';

		my @params=();
		push @params, $schedule_ref->{'intScheduleByID'};
		my $st_params = qq[
			SELECT
				intParamTableType,
				intParamID
			FROM
				tblBusinessRuleScheduleParams
			WHERE
				intBusinessRuleScheduleID = ?
		];
		my $param_values = '';
    my $qry_params = $Data->{'db'}->prepare($st_params);
    $qry_params->execute($schedule_ref->{'intBusinessRuleScheduleID'}) or query_error($st_params);
		while (my $pref = $qry_params->fetchrow_hashref())	{
			$param_values .= qq[, ] if ($param_values);
			$param_values .= $pref->{'intParamID'};
		}

    my $st = qq[
				SELECT 
					M.intMemberID,
					M.strFirstname,
					M.strSurname,
					COUNT(DISTINCT T.intClubID) as ClubCount
				FROM
					tblCompMatches as Mtch
					INNER JOIN tblAssoc_Comp as AC ON (
						AC.intCompID = Mtch.intCompID
					)
					INNER JOIN tblCompMatchSelectedPlayers as SP ON (
						SP.intMatchID=Mtch.intMatchID
					)
					INNER JOIN tblTeam as T ON (
						T.intTeamID = SP.intTeamID
					)
					INNER JOIN tblMember as M ON (
						M.intMemberID = SP.intMemberID
					)
				WHERE 
					AC.intAssocID=?
					$ruleOption
    ];
		$st .= qq[ AND AC.intNewSeasonID =$param_values ] if ($schedule_ref->{'intParamTableType'}== 101);
		$st .= qq[ AND AC.intCompID IN ($param_values) ] if ($schedule_ref->{'intParamTableType'}== $Defs::LEVEL_COMP);
		$st .= qq[ AND (SP.tTimeStamp>=?) ] if ($schedule_ref->{'intAcknowledgeDtLastRun'});

		$st .= qq[
			GROUP BY
				M.intMemberID
			HAVING 
				ClubCount>1
		];
    my $qry= $Data->{'db'}->prepare($st);

		my $multirows = '';
		my $count=0;
		my @Rows=();
		push @params, $schedule_ref->{'dtLastRun'} if ($schedule_ref->{'intAcknowledgeDtLastRun'});
    $qry->execute(@params) or query_error($st);
		while (my $dref = $qry->fetchrow_hashref())	{
			$count++;
			my %result=();
			$result{'member_id'}= $dref->{'intMemberID'};
			$result{'member_name'} = qq[$dref->{'strFirstname'} $dref->{'strSurname'}];
			$result{'ruleName'} = $schedule_ref->{'ScheduleName'};
			$result{'ClubCount'} = $dref->{'ClubCount'};
			$result{'url'} = '';
				$result{'member_link'} = qq[<a target="new_window" href="$Data->{'target'}?client=XXX_MEMBERCLIENT$dref->{'intMemberID'}_XXX&amp;a=M_HOME">$dref->{'strFirstname'} $dref->{'strSurname'}</a>];


			push @Rows, \%result;
		}
		my $body = $schedule_ref->{'strNotificationHeaderText'} . qq[<br>].$multirows;

		return ($count, \@Rows);
}

sub checkMemberInMultiTeamsOverComps {
    my ($Data, $schedule_ref)=@_;
		my $ruleOption = ($schedule_ref->{'strRuleOption'}) ? qq[ AND $schedule_ref->{'strRuleOption'}] : '';

		my @params=();
		push @params, $schedule_ref->{'intScheduleByID'};
		my $st_params = qq[
			SELECT
				intParamTableType,
				intParamID
			FROM
				tblBusinessRuleScheduleParams
			WHERE
				intBusinessRuleScheduleID = ?
		];
		my $param_values = '';
    my $qry_params = $Data->{'db'}->prepare($st_params);
    $qry_params->execute($schedule_ref->{'intBusinessRuleScheduleID'}) or query_error($st_params);
		while (my $pref = $qry_params->fetchrow_hashref())	{
			$param_values .= qq[, ] if ($param_values);
			$param_values .= $pref->{'intParamID'};
		}

    my $st = qq[
				SELECT 
					M.intMemberID,
					M.strFirstname,
					M.strSurname,
					COUNT(DISTINCT T.intTeamID) as TeamCount
				FROM
					tblCompMatches as Mtch
					INNER JOIN tblAssoc_Comp as AC ON (
						AC.intCompID = Mtch.intCompID
					)
					INNER JOIN tblCompMatchSelectedPlayers as SP ON (
						SP.intMatchID=Mtch.intMatchID
					)
					INNER JOIN tblTeam as T ON (
						T.intTeamID = SP.intTeamID
					)
					INNER JOIN tblMember as M ON (
						M.intMemberID = SP.intMemberID
					)
				WHERE 
					AC.intAssocID=?
					$ruleOption
    ];
		$st .= qq[ AND AC.intNewSeasonID =$param_values ] if ($schedule_ref->{'intParamTableType'}== 101);
		$st .= qq[ AND AC.intCompID IN ($param_values) ] if ($schedule_ref->{'intParamTableType'}== $Defs::LEVEL_COMP);
		$st .= qq[ AND (SP.tTimeStamp>=?) ] if ($schedule_ref->{'intAcknowledgeDtLastRun'});

		$st .= qq[
			GROUP BY
				M.intMemberID
			HAVING 
				TeamCount>1
		];
    my $qry= $Data->{'db'}->prepare($st);

		my $multirows = '';
		my $count=0;
		my @Rows=();
		push @params, $schedule_ref->{'dtLastRun'} if ($schedule_ref->{'intAcknowledgeDtLastRun'});
    $qry->execute(@params) or query_error($st);
		while (my $dref = $qry->fetchrow_hashref())	{
			$count++;
			my %result=();
			$result{'member_id'}= $dref->{'intMemberID'};
			$result{'member_name'} = qq[$dref->{'strFirstname'} $dref->{'strSurname'}];
			$result{'ruleName'} = $schedule_ref->{'ScheduleName'};
			$result{'TeamCount'} = $dref->{'TeamCount'};
			$result{'url'} = '';
				$result{'member_link'} = qq[<a target="new_window" href="$Data->{'target'}?client=XXX_MEMBERCLIENT$dref->{'intMemberID'}_XXX&amp;a=M_HOME">$dref->{'strFirstname'} $dref->{'strSurname'}</a>];
			push @Rows, \%result;
		}
		my $body = $schedule_ref->{'strNotificationHeaderText'} . qq[<br>].$multirows;

		return ($count, \@Rows);
}

sub checkMemberInMultiTeamsOverComps_SameClub {

    my ($Data, $schedule_ref)=@_;
		my $ruleOption = ($schedule_ref->{'strRuleOption'}) ? qq[ AND $schedule_ref->{'strRuleOption'}] : '';

		my @params=();
		push @params, $schedule_ref->{'intScheduleByID'};
		my $st_params = qq[
			SELECT
				intParamTableType,
				intParamID
			FROM
				tblBusinessRuleScheduleParams
			WHERE
				intBusinessRuleScheduleID = ?
		];
		my $param_values = '';
    my $qry_params = $Data->{'db'}->prepare($st_params);
    $qry_params->execute($schedule_ref->{'intBusinessRuleScheduleID'}) or query_error($st_params);
		while (my $pref = $qry_params->fetchrow_hashref())	{
			$param_values .= qq[, ] if ($param_values);
			$param_values .= $pref->{'intParamID'};
		}

    my $st = qq[
				SELECT 
					M.intMemberID,
					M.strFirstname,
					M.strSurname,
					COUNT(DISTINCT T.intTeamID) as TeamCount,
					C.strName as ClubName,
					C.intClubID
				FROM
					tblCompMatches as Mtch
					INNER JOIN tblAssoc_Comp as AC ON (
						AC.intCompID = Mtch.intCompID
					)
					INNER JOIN tblCompMatchSelectedPlayers as SP ON (
						SP.intMatchID=Mtch.intMatchID
					)
					INNER JOIN tblTeam as T ON (
						T.intTeamID = SP.intTeamID
					)
					INNER JOIN tblMember as M ON (
						M.intMemberID = SP.intMemberID
					)
					INNER JOIN tblClub as C ON (
						C.intClubID = T.intClubID 
					)
				WHERE 
					AC.intAssocID=?
					$ruleOption
    ];
		$st .= qq[ AND AC.intNewSeasonID =$param_values ] if ($schedule_ref->{'intParamTableType'}== 101);
		$st .= qq[ AND AC.intCompID IN ($param_values) ] if ($schedule_ref->{'intParamTableType'}== $Defs::LEVEL_COMP);
		$st .= qq[ AND (SP.tTimeStamp>=?) ] if ($schedule_ref->{'intAcknowledgeDtLastRun'});

		$st .= qq[
			GROUP BY
				M.intMemberID,
				C.intClubID 
			HAVING 
				TeamCount>1
		];
    my $qry= $Data->{'db'}->prepare($st);

		my $multirows = '';
		my $count=0;
		my @Rows=();
		push @params, $schedule_ref->{'dtLastRun'} if ($schedule_ref->{'intAcknowledgeDtLastRun'});
    $qry->execute(@params) or query_error($st);
		while (my $dref = $qry->fetchrow_hashref())	{
			$count++;
			my %result=();
			$result{'member_id'}= $dref->{'intMemberID'};
			$result{'member_name'} = qq[$dref->{'strFirstname'} $dref->{'strSurname'}];
			$result{'ruleName'} = $schedule_ref->{'ScheduleName'};
			$result{'TeamCount'} = $dref->{'TeamCount'};
			$result{'ClubName'} = $dref->{'ClubName'};
			$result{'url'} = '';
				$result{'member_link'} = qq[<a target="new_window" href="$Data->{'target'}?client=XXX_MEMBERCLIENT$dref->{'intMemberID'}_XXX&amp;a=M_HOME">$dref->{'strFirstname'} $dref->{'strSurname'}</a>];
			push @Rows, \%result;
		}
		my $body = $schedule_ref->{'strNotificationHeaderText'} . qq[<br>].$multirows;

		return ($count, \@Rows);
}

sub checkMemberSuspendedInComp	{
    my ($Data, $schedule_ref)=@_;

		my @params=();
		push @params, $schedule_ref->{'intScheduleByID'};
		my $st_params = qq[
			SELECT
				intParamTableType,
				intParamID
			FROM
				tblBusinessRuleScheduleParams
			WHERE
				intBusinessRuleScheduleID = ?
		];

    my $st = qq[
				SELECT 
					DISTINCT
					M.intMemberID,
					M.strFirstname,
					M.strSurname,
					DATE_FORMAT(M.dtDOB, "%Y/%M/%d") as dateDOB,
					T.strName as TeamName,
					AC.strTitle as CompName,
					DATE_FORMAT(Mtch.dtMatchTime, "%d/%m/%Y") as dateMatchTime
				FROM
					tblCompMatches as Mtch
					INNER JOIN tblAssoc_Comp as AC ON (
						AC.intCompID = Mtch.intCompID
					)
					INNER JOIN tblCompMatchSelectedPlayers as SP ON (
						SP.intMatchID=Mtch.intMatchID
					)
					INNER JOIN tblTeam as T ON (
						T.intTeamID = SP.intTeamID
					)
					INNER JOIN tblMember as M ON (
						M.intMemberID = SP.intMemberID
					)
					INNER JOIN tblTribunal as Trib ON (
						Trib.intMemberID=M.intMemberID
						AND Trib.intAssocID=AC.intAssocID
				WHERE 
					AC.intAssocID=?
					AND Mtch.dtMatchTime < Trib.dtPenaltyExp
					AND Mtch.dtMatchTime > Trib.dtCharged
			];
		$st .= qq[ AND AC.intNewSeasonID =? ] if ($schedule_ref->{'intParamTableType'}== 101);
		$st .= qq[ AND AC.intCompID =? ] if ($schedule_ref->{'intParamTableType'}== $Defs::LEVEL_COMP);

		$st .= qq[ AND (SP.tTimeStamp>=?) ] if ($schedule_ref->{'intAcknowledgeDtLastRun'});
    my $qry= $Data->{'db'}->prepare($st);
		
    my $qry_params = $Data->{'db'}->prepare($st_params);
    $qry_params->execute($schedule_ref->{'intBusinessRuleScheduleID'}) or query_error($st_params);

		my $multirows = '';
		my $count=0;
		my @Rows=();
		while (my $params_ref = $qry_params->fetchrow_hashref())	{
			push @params, $params_ref->{'intParamID'};
			push @params, $schedule_ref->{'dtLastRun'} if ($schedule_ref->{'intAcknowledgeDtLastRun'});
    	$qry->execute(@params) or query_error($st);
			while (my $dref = $qry->fetchrow_hashref())	{
				$count++;
				my %result=();
				$result{'member_id'}= $dref->{'intMemberID'};
				$result{'member_name'} = qq[$dref->{'strFirstname'} $dref->{'strSurname'}];
				$result{'team_name'} = $dref->{'TeamName'};
				$result{'comp_name'} = $dref->{'CompName'};
				$result{'matchdate'} = $dref->{'dateMatchTime'};
				$result{'url'} = '';
				$result{'member_link'} = qq[<a target="new_window" href="$Data->{'target'}?client=XXX_MEMBERCLIENT$dref->{'intMemberID'}_XXX&amp;a=M_HOME">$dref->{'strFirstname'} $dref->{'strSurname'}</a>];
				push @Rows, \%result;
			}
		}
		my $body = $schedule_ref->{'strNotificationHeaderText'} . qq[<br>].$multirows;

		return ($count, \@Rows);
}

sub checkMemberPlayingRegistered	{
    my ($Data, $schedule_ref)=@_;
		my $ruleOption = ($schedule_ref->{'strRuleOption'}) ? qq[ AND $schedule_ref->{'strRuleOption'}] : '';
		my $MStablename = qq[tblMember_Seasons_$schedule_ref->{'intRealmID'}];

		## CHECK AGAINST MEMBER SEASON FINANCIAL... maybe do MS.intClUBID=T.intClubID in the rule as a parameter

		my @params=();
		push @params, $schedule_ref->{'intScheduleByID'};
		my $st_params = qq[
			SELECT
				intParamTableType,
				intParamID
			FROM
				tblBusinessRuleScheduleParams
			WHERE
				intBusinessRuleScheduleID = ?
		];

    my $st = qq[
				SELECT 
					DISTINCT
					M.intMemberID,
					M.strFirstname,
					M.strSurname,
					DATE_FORMAT(M.dtDOB, "%Y/%M/%d") as dateDOB,
					AC.strTitle as CompName
				FROM
					tblCompMatches as Mtch
					INNER JOIN tblAssoc_Comp as AC ON (
						AC.intCompID = Mtch.intCompID
					)
					INNER JOIN tblCompMatchSelectedPlayers as SP ON (
						SP.intMatchID=Mtch.intMatchID
					)
					INNER JOIN tblTeam as T ON (
						T.intTeamID = SP.intTeamID
					)
					INNER JOIN tblMember as M ON (
						M.intMemberID = SP.intMemberID
					)
					LEFT JOIN $MStablename as MS ON (
						MS.intMemberID=SP.intMemberID
						AND MS.intAssocID=AC.intAssocID
						AND MS.intSeasonID=AC.intNewSeasonID
						AND MS.intClubID=T.intClubID
					)
					LEFT JOIN tblMember_Associations as MA ON (
						MA.intMemberID=SP.intMemberID
						AND MA.intAssocID=AC.intAssocID
					)
				WHERE 
					AC.intAssocID=?
					$ruleOption
    ];

					#( 
					#	MS.intPlayerFinancial=0
					#	OR MS.intMSRecStatus <> 1
					#	OR MA.intRecStatus<>1
					#)
		$st .= qq[ AND $schedule_ref->{'strRuleOption'}] if ($schedule_ref->{'strRuleOption'});
		$st .= qq[ AND AC.intNewSeasonID =? ] if ($schedule_ref->{'intParamTableType'}== 101);
		$st .= qq[ AND AC.intCompID =? ] if ($schedule_ref->{'intParamTableType'}== $Defs::LEVEL_COMP);
		$st .= qq[ AND (SP.tTimeStamp>=?) ] if ($schedule_ref->{'intAcknowledgeDtLastRun'});

    my $qry= $Data->{'db'}->prepare($st);
		
    my $qry_params = $Data->{'db'}->prepare($st_params);
    $qry_params->execute($schedule_ref->{'intBusinessRuleScheduleID'}) or query_error($st_params);

		my $multirows = '';
		my $count=0;
		my @Rows=();
		while (my $params_ref = $qry_params->fetchrow_hashref())	{
			push @params, $params_ref->{'intParamID'};
			push @params, $schedule_ref->{'dtLastRun'} if ($schedule_ref->{'intAcknowledgeDtLastRun'});
    	$qry->execute(@params) or query_error($st);
			while (my $dref = $qry->fetchrow_hashref())	{
				$count++;
				my %result=();
				$result{'member_id'}= $dref->{'intMemberID'};
				$result{'member_name'} = qq[$dref->{'strFirstname'} $dref->{'strSurname'}];
				$result{'team_name'} = $dref->{'TeamName'};
				$result{'comp_name'} = $dref->{'CompName'};
				$result{'matchdate'} = $dref->{'dateMatchTime'};
				$result{'url'} = '';
				$result{'member_link'} = qq[<a target="new_window" href="$Data->{'target'}?client=XXX_MEMBERCLIENT$dref->{'intMemberID'}_XXX&amp;a=M_HOME">$dref->{'strFirstname'} $dref->{'strSurname'}</a>];
				push @Rows, \%result;
			}
		}
		my $body = $schedule_ref->{'strNotificationHeaderText'} . qq[<br>].$multirows;

		return ($count, \@Rows);
}
1;
