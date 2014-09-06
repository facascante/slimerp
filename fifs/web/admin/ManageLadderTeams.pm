#
# $Header: svn://svn/SWM/trunk/web/admin/ManageLadderTeams.pm 10127 2013-12-03 03:59:01Z tcourt $
#

package ManageLadderTeams;

require Exporter;
@ISA = qw(Exporter);
@EXPORT = qw( handleManageLadderTeams );
@EXPORT_OK = qw( handleManageLadderTeams );

use strict;

use lib '.', "..", "../..", "../sportstats";

use Utils;
use Reg_common;
use CGI qw( param escape unescape );

sub handleManageLadderTeams {

	my ($action, $Data) = @_;

  my $resultHTML = '';
  my $title = '';
  my $lang = $Data->{'lang'};
  my $type = $Data->{'clientValues'}{'currentLevel'};
  my $compID = $Data->{'clientValues'}{'compID'};
  my $assocID = $Data->{'clientValues'}{'assocID'};

	if ($action =~ /MLT_reset_comp_teams/) {
		_reset_comp_teams($Data);
	}
	elsif ($action =~ /MLT_reset_regradelog/) {
		_reset_regradelog($Data);
	}
	elsif ($action =~ /MLT_cs_/) {
		_change_comp_status($Data, $action);
	}
	elsif ($action =~ /MLT_t_/) {
		_change_team_status($Data, $action);
	}
	elsif ($action =~ /MLT_rl_delete/) {
		_delete_regrade_log_record($Data, $action);
	}
	elsif ($action =~ /MLT_rl_insert/) {
		_insert_regrade_log_record($Data, $action);
	}
	elsif ($action =~ /MLT_reset_match_num/) {
		_reset_match_numbers_in_fixture($Data);
	}
	$resultHTML = _display_menu($Data);
	$title = 'Manage Ladder Teams';

	return ($resultHTML, $title);
}

sub _display_menu {
	my ($Data) = @_;
	my $client = setClient($Data->{'clientValues'});
	my $add_remove_teams_status = _display_regrade_log($Data, $client);
	my $comp_teams_status = _display_comp_team_table($Data, $client);
	my $current_teams = _display_teams_in_fixture($Data);
	my $resultHTML = qq[
		<p style="color:red;font-size:16px;font-weight:bold;">The following utilities should only be used with caution.</p>
		<br>
		<p><a href="main.cgi?client=$client&a=MLT_reset_comp_teams" onclick="return confirm('Are you sure you wish to regenerate Competition Team Statuses ?')">Regenerate Competition Teams Status</a>: This will regenerate the below list to only show teams that are fixtured in a match for this competition.</p>
		<br>
		$comp_teams_status
		<br> 
		<br> 
		<p><a href="main.cgi?client=$client&a=MLT_reset_regradelog" onclick="return confirm('Are you sure you reset the timestamps ?')">Reset Add/Remove Timestamps</a>: This will reset the timestamps for the below table back to earliest date in the fixture. Any team that does not appear in the fixture will also be removed from the below table. If you have regraded teams in and/or out of the competition then do not use this option.</p>
		<br>
		$add_remove_teams_status
		<br>
		<br>
		<p>The following teams currently appear in the fixture:</p>
		<br>
		$current_teams
		<br>
		<br>
		<p><a href="main.cgi?client=$client&a=MLT_reset_match_num" onclick="return confirm('Are you sure you wish to reset the match numbers in the Fixture ?')">Regenerates Match Numbers for a Competition</a>: This will reset the match numbers for a competition to remove any duplicates that may be causing matches or rounds not to display.</p>
		<br>
		<br>
		<p>If the above utilities do not resolve your Ladder issues, please contact SportingPulse Support and quote Competition ID $Data->{'clientValues'}{'compID'} and the ID of the problem team(s).</p>
	];
	return $resultHTML;
}

sub _display_regrade_log {
	my ($Data, $client) = @_;
	my $teams = _get_teams_in_fixture($Data);
	my $teams_ddl = ();
  foreach my $key (keys %{$teams}) {
    next if $key eq 'earliest_fixture_date';
		next if ($key == -1);
    $teams_ddl .= qq[<option value="$key">$teams->{$key}</option>];
  }
	my $st = qq[
		SELECT
			tblRegradeLog.*,
			tblTeam.strName
		FROM
			tblRegradeLog
			LEFT JOIN tblTeam USING(intTeamID)
		WHERE
			tblRegradeLog.intAssocID = ?
			AND tblRegradeLog.intCompID = ?
	];
	my $q = $Data->{'db'}->prepare($st);
	$q->execute($Data->{'clientValues'}{'assocID'}, $Data->{'clientValues'}{'compID'});
	my $regrade_log_html = '';
	while (my $href = $q->fetchrow_hashref()) {
		$regrade_log_html .= qq[
			<tr>
				<td>$href->{'intTeamID'}</td>
				<td>$href->{'strName'}</td>
				<td>$href->{'strAction'}</td>
				<td>$href->{'tTimeStamp'}</td>
				<td>[<a href="main.cgi?client=$client&a=MLT_rl_delete&id=$href->{'intRegradeLogID'}">Delete</a>]</td>
			</tr>
		];
	}
	$regrade_log_html = qq[<tr><td colspan="4">No records found</td>] unless($regrade_log_html);
	$regrade_log_html = qq[
		<table class="listTable">
			<tr><th>Team ID</th><th>Team</th><th>Action</th><th>Time Stamp</th><th>&nbsp;</th></tr>
			$regrade_log_html
			<form>
				<tr>
					<td></td>
					<td><select name="teamID">$teams_ddl</select></td>
					<td><select name="log_action"><option>Team Added</option><option>Team Removed</option></select></td>
					<td><input type="text" name="tTimeStamp" value=""> (yyyy-mm-dd)</td>
					<td><input type="submit" value="Add Record"></td>
				</tr>
				<input type="hidden" name="a" value="MLT_rl_insert">
				<input type="hidden" name="client" value="$client">
			</form>
		</table>
	];
	return $regrade_log_html;
}

sub _display_comp_team_table {
  my ($Data, $client) = @_;
  my $st = qq[
    SELECT
      tblComp_Teams.*,
      tblTeam.strName,
      tblTeam.intRecStatus AS intTeamStatus
    FROM
      tblComp_Teams
      LEFT JOIN tblTeam USING(intTeamID)
    WHERE
      tblComp_Teams.intCompID = ?
  ];
  my $q = $Data->{'db'}->prepare($st);
  $q->execute($Data->{'clientValues'}{'compID'});
  my $comp_teams_html = '';
  while (my $href = $q->fetchrow_hashref()) {
		my $status = '';
		my $team_status = '';
		$status = 'Deleted' if ($href->{'intRecStatus'} == -1);
		$status = 'Active' if ($href->{'intRecStatus'} == 1);
		$status = 'Inactive' if ($href->{'intRecStatus'} == 0);
		$team_status = 'Deleted' if ($href->{'intTeamStatus'} == -1);
		$team_status = 'Active' if ($href->{'intTeamStatus'} == 1);
		$team_status = 'Inactive' if ($href->{'intTeamStatus'} == 0);
		my $comp_status_link = '';
		if ($status eq 'Active') {
			$comp_status_link = qq[[<a href="main.cgi?client=$client&a=MLT_cs_inactive&id=$href->{'intCompNO'}" onclick="return confirm('Are you sure you wish to set the Status in Competition to Inactive ?')">Make Inactive</a>]];
		}
		else {
			$comp_status_link = qq[[<a href="main.cgi?client=$client&a=MLT_cs_active&id=$href->{'intCompNO'}" onclick="return confirm('Are you sure you wish to set the Status in Competition to Active ?')">Make Active</a>]];
		}
		my $team_status_link = '';
    if ($team_status eq 'Active') {
      $team_status_link = qq[[<a href="main.cgi?client=$client&a=MLT_t_inactive&id=$href->{'intTeamID'}" onclick="return confirm('Are you sure you wish to set the Team Status to Inactive ?')">Make Inactive</a>]];
    }
    else {
      $team_status_link = qq[[<a href="main.cgi?client=$client&a=MLT_t_active&id=$href->{'intTeamID'}" onclick="return confirm('Are you sure you wish to set the Team Status to Active ?')">Make Active</a>]];
    }
		my $team_delete_link = '';
    if ($team_status eq 'Active' or $team_status eq 'Inactive') {
      $team_delete_link = qq[[<a href="main.cgi?client=$client&a=MLT_t_delete&id=$href->{'intTeamID'}" onclick="return confirm('Are you sure you wish to set the Team Status to Deleted ?')">Delete</a>]];
    }

		
		if ($href->{intTeamID} == -1) {
			$href->{'strName'} = 'Bye';
			$comp_status_link = '';
			$team_status_link = '';
			$team_delete_link = '';
			$status = 'N/A';
			$team_status = 'N/A';
		}

    $comp_teams_html .= qq[
			<tr>
				<td>$href->{'intTeamID'}</td>
				<td>$href->{'strName'}</td>
				<td>$status &nbsp; $comp_status_link</td>
				<td>$team_status &nbsp; $team_status_link &nbsp; $team_delete_link</td>
			</tr>
		];
  }
  $comp_teams_html = qq[<tr><td colspan="4">No records found</td>] unless($comp_teams_html);
  $comp_teams_html = qq[
    <table class="listTable">
      <tr><th>Team ID</th><th>Team</th><th>Status in Competition</th><th>Team Status</th></tr>
      $comp_teams_html
    </table>
  ] if $comp_teams_html;
  return $comp_teams_html;
}

sub _display_teams_in_fixture {
  my ($Data) = @_;
	my $teams = _get_teams_in_fixture($Data);
	my $teams_in_fixture_html = '';
	foreach my $key (keys %{$teams}) {
    next if $key eq 'earliest_fixture_date';
		$teams->{$key} = 'Bye' if $key == -1;
		$teams_in_fixture_html .= qq[<tr><td>$key</td><td>$teams->{$key}</td></tr>];
	}
  $teams_in_fixture_html = qq[<tr><td colspan="4">No records found</td>] unless($teams_in_fixture_html);
  $teams_in_fixture_html = qq[
    <table class="listTable">
      <tr><th>Team ID</th><th>Team</th></tr>
      $teams_in_fixture_html
    </table>
  ] if $teams_in_fixture_html;
	return $teams_in_fixture_html;
}

sub _reset_comp_teams {
  my ($Data) = @_;
	my $teams = _get_teams_in_fixture($Data);
	return unless($Data->{'clientValues'}{'compID'} and $Data->{'clientValues'}{'compID'} > 0);
	my $st_select_teams = qq[
		SELECT
			intTeamID,
			intRecStatus
		FROM
			tblComp_Teams
		WHERE
			intCompID = ?
	];
  my $q_select_teams = $Data->{'db'}->prepare($st_select_teams);
	$q_select_teams->execute($Data->{'clientValues'}{'compID'});
	my %existing_teams = ();
	while (my $href = $q_select_teams->fetchrow_hashref()) {
		$existing_teams{$href->{'intTeamID'}} = $href->{'intRecStatus'};
	}

  my $st_update_all_comp_team = qq[
    UPDATE tblComp_Teams
    SET
      intRecStatus = -1
    WHERE
      intCompID = ?
  ];
  my $q_update_all_comp_team = $Data->{'db'}->prepare($st_update_all_comp_team);

	
	my $st_update_comp_team = qq[
		UPDATE tblComp_Teams 
		SET 
			intRecStatus = ?
		WHERE
			intCompID = ?
			AND intTeamID = ?
	];
  my $q_update_comp_team = $Data->{'db'}->prepare($st_update_comp_team);

	my $st_insert_comp_team = qq[
		INSERT INTO tblComp_Teams (
			intCompID,
			intTeamID,
			intRecStatus
		)
		VALUES (
			?,
			?,
			1
		)
	];
  my $q_insert_comp_team = $Data->{'db'}->prepare($st_insert_comp_team);

	my $st_update_team = qq[
		UPDATE tblTeam
		SET 
			intRecStatus = 1,
			tTimeStamp = now()
		WHERE intTeamID = ?
		LIMIT 1
	];
	my $q_update_team = $Data->{'db'}->prepare($st_update_team);

	$q_update_all_comp_team->execute($Data->{'clientValues'}{'compID'});

	foreach my $key (keys %{$teams}) {
		next if $key eq 'earliest_fixture_date';
		next if $key eq -1;
		if ($existing_teams{$key}) {
			$q_update_comp_team->execute(1, $Data->{'clientValues'}{'compID'}, $key);
		}
		else {
			$q_insert_comp_team->execute($Data->{'clientValues'}{'compID'}, $key);
		}
		$q_update_team->execute($key);
	}
}

sub _reset_regradelog {
  my ($Data) = @_;
	my $teams = _get_teams_in_fixture($Data);
	return unless($Data->{'clientValues'}{'compID'} and $Data->{'clientValues'}{'compID'} > 0);
	return unless($Data->{'clientValues'}{'assocID'} and $Data->{'clientValues'}{'assocID'} > 0);
	my $st = qq[
		UPDATE tblRegradeLog 
		SET 
			intCompID = intCompID * -1, 
			intTeamID = intTeamID * -1 
		WHERE 
			intCompID = ?
			AND intAssocID = ?
	];
  my $q = $Data->{'db'}->prepare($st);
  $q->execute($Data->{'clientValues'}{'compID'}, $Data->{'clientValues'}{'assocID'});
  $st = qq[
    INSERT INTO tblRegradeLog (
      intCompID,
      intAssocID,
      intTeamID,
			strAction,
      tTimeStamp
    )
    VALUES (
      ?,
      ?,
			?,
      'Team Added',
			?
    )
  ];
  $q = $Data->{'db'}->prepare($st);
  foreach my $key (keys %{$teams}) {
		next if $key eq 'earliest_fixture_date';
    $q->execute(
			$Data->{'clientValues'}{'compID'}, 
			$Data->{'clientValues'}{'assocID'}, 
			$key,
			$teams->{'earliest_fixture_date'}
		);
  }
}

sub _reset_match_numbers_in_fixture {
  my ($Data) = @_;
  my $st = qq[
    SELECT
			CM.intMatchID,
      CM.intHomeTeamID,
      CM.intAwayTeamID,
      CM.dtMatchTime,
			CM.intMatchNum
    FROM
      tblCompMatches AS CM
    WHERE
      CM.intCompID = ?
      AND CM.intRecStatus <> -1
  ];
  my $q = $Data->{'db'}->prepare($st);
  $q->execute($Data->{'clientValues'}{'compID'});
	my $st_update = qq[
		UPDATE tblCompMatches
		SET
			intMatchNum = ?
		WHERE
			intMatchID = ?
		LIMIT 1;
	];
  my $q_update = $Data->{'db'}->prepare($st_update);
	my $i = 1;
  $q->execute($Data->{'clientValues'}{'compID'});
  while (my $href = $q->fetchrow_hashref()) {
		$q_update->execute($i, $href->{'intMatchID'});
		$i++;
  }
  return;
}


sub _get_teams_in_fixture {
  my ($Data) = @_;
	my $st = qq[
		SELECT
			CM.intHomeTeamID,
			CM.intAwayTeamID,
			CM.dtMatchTime,
			T1.strName AS strHomeTeam,
			T2.strName AS strAwayTeam
		FROM
			tblCompMatches AS CM
			LEFT JOIN tblTeam AS T1 ON (T1.intTeamID = CM.intHomeTeamID)
			LEFT JOIN tblTeam AS T2 ON (T2.intTeamID = CM.intAwayTeamID)
		WHERE
			CM.intCompID = ?
			AND CM.intRecStatus <> -1
	];
  my $q = $Data->{'db'}->prepare($st);
  $q->execute($Data->{'clientValues'}{'compID'});
	my %teams = ();
  while (my $href = $q->fetchrow_hashref()) {
		$teams{$href->{'intHomeTeamID'}} = $href->{'strHomeTeam'};
		$teams{$href->{'intAwayTeamID'}} = $href->{'strAwayTeam'};
		if (not defined $teams{'earliest_fixture_date'} or  $href->{'dtMatchTime'} < $teams{'earliest_fixture_date'}) {
			$teams{'earliest_fixture_date'} = $href->{'dtMatchTime'};
		}
	}
	return \%teams;
}

sub _change_comp_status {
  my ($Data, $action) = @_;
	my $compNo = param('id') || 0;
	return unless ($compNo and $compNo > 0);
	my $status = -1;
	if ($action eq 'MLT_cs_inactive') {
		$status = 0;
	}
	elsif ($action eq 'MLT_cs_active') {
		$status = 1;
	}
	return if ($status == -1);
  my $st = qq[
		UPDATE tblComp_Teams
		SET
			intRecStatus = ?
		WHERE
			intCompNo = ?
			AND intCompID = ?
  ];
  my $q = $Data->{'db'}->prepare($st);
  $q->execute($status, $compNo, $Data->{'clientValues'}{'compID'});
}

sub _change_team_status {
  my ($Data, $action) = @_;
  my $teamID = param('id') || 0;
  return unless ($teamID and $teamID > 0);
  my $status = -1;
  if ($action eq 'MLT_t_inactive') {
    $status = 0;
  }
  elsif ($action eq 'MLT_t_active') {
    $status = 1;
  }
  return if ($status == -1);
  my $st = qq[
    UPDATE tblTeam
    SET
      intRecStatus = ?,
			tTimeStamp = now()
    WHERE
      intTeamID = ?
		LIMIT 1
  ];
  my $q = $Data->{'db'}->prepare($st);
  $q->execute($status, $teamID);
}

sub _delete_regrade_log_record {
  my ($Data, $action) = @_;
  my $regrade_log_ID = param('id') || 0;
  return unless ($regrade_log_ID and $regrade_log_ID > 0);
  my $st = qq[
    UPDATE tblRegradeLog
    SET
      intCompID = intCompID * -1,
      intTeamID = intTeamID * -1
    WHERE
      intRegradeLogID = ?
    LIMIT 1
  ];
  my $q = $Data->{'db'}->prepare($st);
  $q->execute($regrade_log_ID);
}

sub _insert_regrade_log_record {
  my ($Data, $action) = @_;
  my $team_ID = param('teamID');
  $action = param('log_action');
  my $time_stamp = param('tTimeStamp');
  return unless ($team_ID and $team_ID > 0);
  my $st = qq[
    INSERT INTO tblRegradeLog (
			intAssocID,
			intCompID,
			intTeamID,
			strAction,
			tTimeStamp
		)
		VALUES (
			?,
			?,
			?,
			?,
			?
		)
  ];
  my $q = $Data->{'db'}->prepare($st);
  $q->execute(
		$Data->{'clientValues'}{'assocID'},
		$Data->{'clientValues'}{'compID'},
		$team_ID,
		$action,
		$time_stamp
	);
}

1;
