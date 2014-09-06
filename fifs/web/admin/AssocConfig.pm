#
# $Header: svn://svn/SWM/trunk/web/admin/AssocConfig.pm 11324 2014-04-17 01:20:47Z sliu $
#

package AssocConfig;

use lib "..","../..";
use CGI qw(param);
use DBI;

require Exporter;
@ISA =  qw(Exporter);
@EXPORT = qw(AssocConfig);
@EXPORT_OK = qw(AssocConfig);



use strict;

use Utils;
use Defs;
use ConfigOptions;
use DeQuote;
use AdminPageGen;

use ConfigOptions;
use Log;


sub AssocConfig	{
my($db,$target)=@_;


	my $body  = '';
	my $assocID = param('aID') || param("intAssocID") || 0;
	my $sectionID = param('sID') || 0;
	my $action = param('action') || '';
	my $new_strKey= param('new_strKey') || '';
	my $new_strValue= param('new_strValue') || '';
	my $strDB_Name= param('db_name') || '';

    my %assocConfig;
    my $statement = qq[
        SELECT
            strOption,
            strValue
        FROM
            tblAssocConfig
        WHERE
            intAssocID = $assocID
    ];
    my $query = $db->prepare($statement) or query_error($statement);
    $query->execute() or query_error($statement);
    while(my $dref= $query->fetchrow_hashref())  {
        $assocConfig{$dref->{strOption}}{$dref->{strKey}} = $dref->{strValue} || $dref->{strValue_Long};
    }


	#$body .= getHeader();

	my %available_keys = ();
	#CONFIG AREA, DEFAULT, DESCRIPTION
	my $DEFAULT_ITEM = 1;

### SELECT DISTINCT strConfigArea , strKey FROM tblCompSWOLConfig WHERE strConfigArea NOT IN ('TIME','TEAM_SHEET', 'SCORES', 'FINAL_RESULTS', 'DETAILED_PLAYERS', 'DETAILED_RESULTS', 'PLAYER_POS', 'PLAYERS') ORDER BY strConfigArea, strKey;
$available_keys{'feedPeopleToSchedulaUsingSeasonNames'} = ['ASSOC CONFIG',0,"Some Schedula Assocs don't use national seasons so their Umpires will be in a different season. This is to set them by Season Name rather than Season ID (assumes Umpire Seasons are spelt identically)",0];

$available_keys{'feedFixturesToSchedula'} = ['ASSOC CONFIG',0,'Enable Schedula to get Fixtures',0];
$available_keys{'StopBonusPenaltyForChampPoints'} = ['ASSOC CONFIG',0,'Fixes an Issue with Bonus Points being calculated into Points which was doubling up in Champ Points (NRL)',0];
$available_keys{'IgnorePermitReReg'} = ['ASSOC CONFIG',0,'On Member Dashboard (Right Status Box) - Allows Registration for Permitted Members (SANFL)',0];
$available_keys{'LadderDisplayOldRounds'} = ['ASSOC CONFIG',0,'Let admins see old ladders of previous rounds',0];
$available_keys{'allowSchedulaIntegration'} = ['ASSOC CONFIG',0,'Turn On Schedula Integration',0];
$available_keys{'RegoForm_AutoLoadTeamsIntoClubID'} = ['ASSOC CONFIG',0,'Automatically Feed all RegoForm Team->Assoc Forms into a club',0];
$available_keys{'RegoForm_AutoLoadMembersIntoClubID'} = ['ASSOC CONFIG',0,'Automatically Feed all RegoForm Member->Assoc Forms into a club',0];
$available_keys{'allowFixtureImporter'} = ['ASSOC CONFIG',0,'Turn On Fixture Importer',0];
$available_keys{'AllowNABSignup'} = ['ASSOC CONFIG',0,'Allow Associations NAB signup',0];
$available_keys{'AllowNABSignupClub'} = ['ASSOC CONFIG',0,'Allow Clubs NAB Signup',0];
#$available_keys{'AllowNABSignupClubs'} = ['ASSOC CONFIG',0,'',0];
#$available_keys{'allowSchedulaIntegration'} = ['ASSOC CONFIG',0,'',0];
$available_keys{'allowTeamEntry'} = ['ASSOC CONFIG',0,'Team Entry Page in Assoc',0];
$available_keys{'allowTeamEntryClub'} = ['ASSOC CONFIG',0,'Team Entry Page in Club',0];
$available_keys{'AssocPaymentExtraDetails'} = ['ASSOC CONFIG',0,'Custom Payment Receipt Text',0];
$available_keys{'AssocPaymentOrgName'} = ['ASSOC CONFIG',0,'Custom Payment Receipt Org Name',0];
$available_keys{'clrAllowMultiplePermits'} = ['ASSOC CONFIG',0,'Allow Multiple Permits',0];
$available_keys{'copyComp_notUseExisting'} = ['ASSOC CONFIG',0,'Disallow use of existing teams when copying competitions',0];
$available_keys{'hideDefCodes'} = ['ASSOC CONFIG',0,'Hiding DefCodes Values',0];
#$available_keys{'olrv5_classic'} = ['ASSOC CONFIG',0,'',0];
$available_keys{'olrv6'} = ['ASSOC CONFIG',0,'Uses online results v6',0];
$available_keys{'showRebelCampaign'} = ['ASSOC CONFIG',0,'Show Rebel Campaign in Rego Form',0];
$available_keys{'LockdownSeasonAddClub'} = ['ASSOC CONFIG',0,'Stop Clubs being able to edit Season records.',0];
$available_keys{'allowMatchDayPaperwork'} = ['ASSOC CONFIG',0,'Enable Match Day Paperwork"',0];
$available_keys{'allowManualFixturing'} = ['ASSOC CONFIG',0,'Skip "Generate Fixture" in Competitions',0];
#$available_keys{'SwitchOnSelectedPlayers'} = ['ASSOC CONFIG',0,'',0];
$available_keys{'NoClashOnFixtureGrid'} = ['ASSOC CONFIG',0,'No Clashing on the Fixture Grid [For People who COmplain about Fixture Grid Speed',0];
$available_keys{'DisableClubCardPrinting'} = ['ASSOC CONFIG',0,'Disable Clubs From Printing Cards',0];
$available_keys{'allowTeamIfNotInSeason'} = ['ASSOC CONFIG',0,'Allow teams not in new rego season to have "Assign to Comp"',0];
$available_keys{'forceSeasonSelectinTeamRollover'} = ['ASSOC CONFIG',0,'Force Selection of Team Rollover Screen',0];
$available_keys{'DontAllowManualPayments'} = ['ASSOC CONFIG',0,'DontAllowManualPayments',0];
$available_keys{'ClubFinancialMakesAssocFinancial'} = ['ASSOC CONFIG',0,'ClubFinancial Products Makes Assoc Financial as well',0];
$available_keys{'PublisherTimeout'} = ['ASSOC CONFIG',0,'Customise time between publishes(in minutes)',0];
$available_keys{'AllowFixtureRedrawRoundSelect'} = ['ASSOC CONFIG',0,'Enable ability to redraw fixtures from a selected round',0];

$available_keys{'copyComp_allowMembers'} = ['ASSOC CONFIG',0,'Copy Comp allows copying of members in their respective teams',0];
$available_keys{'loadTeams_allowMembersCopy'} = ['ASSOC CONFIG',0,'Allow Members to copy when loading teams',0];
$available_keys{'allowCompLoadTeams'} = ['ASSOC CONFIG',0,'Allow to load teams when Manege Teams In Competition',0];
$available_keys{'showAssignTeamToCompBTN'} = ['ASSOC CONFIG',0,'Display the button Assign To competition in Team page',0];
$available_keys{'AllowFixtureEqualisation'} = ['ASSOC CONFIG',0,'enable the Redraw Fixtures via Fixture Equalisation component',0];
$available_keys{'AllowBulkCompRollover'} = ['ASSOC CONFIG',0,'enable bulk competition rollover',0];
$available_keys{'unLockSeasons'} = ['ASSOC CONFIG',0,'Enable season rollover when locked from realm level',0];
$available_keys{'AllowBulkLivestatsUpload'} = ['ASSOC CONFIG',0,'Allow the use of Livestats Bulk Uploader',0];
$available_keys{'useAssignPlayersToTeamV2'} = ['ASSOC CONFIG',0,'Use new Assign Players To Team screen',0];
$available_keys{'LockdownDOBIfSetOnTeamEdit'} = ['ASSOC CONFIG',0,'When editing team lists, lock down the DOB field if competition the team is in has DOB restrictions',0];
$available_keys{'LockdownGenderIfSetOnTeamEdit'} = ['ASSOC CONFIG',0,'When editing team lists, lock down the gender field if competition the team is in has gender restrictions',0];
$available_keys{'AllowExternalCourtsideVenueID'} = ['ASSOC CONFIG',0,'Allow the use of external courtside venue IDs from other associations',0];
$available_keys{'Rollover_AddRollover_Override'} = ['ASSOC CONFIG',0,'Force Member Rollover to appear (overrides all system configs)',0];
$available_keys{'AllowPrograms'} = ['ASSOC CONFIG',0,'Allow the use of Programs',0];
$available_keys{'AlwaysAllowManageTeamsInComp'} = ['ASSOC CONFIG',0,'Stops the "started season" from stopping Manage Teams in Comp"',0];
$available_keys{'AllowRefereeLogin'} = ['ASSOC CONFIG',0,'Allows referees to login by linking their referee ID to a passport. Passports will be created automatically if required.',0];
$available_keys{'ShowPassword'} = ['ASSOC CONFIG',0,'Passwords are visible in Password Manage Screen and Reports.',0];
	
	my %sports = ();
	$sports{1} = 'Hockey';
	$sports{2} = 'Cricket';
	$sports{3} = 'Football';
	$sports{4} = 'Lacrosse';
	$sports{5} = 'Soccer';
	$sports{6} = 'Netball';
	$sports{7} = 'Basketball';
	$sports{8} = 'Rugby League';
	$sports{9} = 'Water Polo';

	

	if ($action eq 'ASSOC_ASSOC_config_SC')	{
		#Save Assoc Config Settings
		$body.=updateAssocConfigs($db, $assocID);
		$action = 'ASSOC_ASSOC_config_VC';
	}
	if ($action eq 'ASSOC_ASSOC_config_IC')	{
		#INSERT Assoc Config Item
		$body.=insertAssocConfigItem($db, $assocID, $new_strKey, $new_strValue);
		$action = 'ASSOC_ASSOC_config_VC';
	}
	if ($action eq "ASSOC_ASSOC_config" or $action eq 'ASSOC_ASSOC_config_VC')	{
		#View All Assoc Config Items
		$body.=viewAssocConfigs($db, $assocID, \%available_keys);
	}
}

sub viewAssocConfigs	{

	my ($db, $intAssocID, $available_keys) = @_;
	$intAssocID ||= 0;

	my $body = '<table style="margin-left:auto;margin-right:auto;"><tr><td class="formbg">';

	my $statement = qq[
		SELECT strName
		FROM tblAssoc
		WHERE intAssocID = $intAssocID
	];
	my $query = $db->prepare($statement) or query_error($statement);
    $query->execute or query_error($statement);
	my $aref = $query->fetchrow_hashref();
	$statement = qq[
		SELECT *
		FROM tblAssocConfig
		WHERE intAssocID = $intAssocID
		ORDER BY strOption
	];


	$body .= qq[
		<div style="font-size:18px;">ASSOCIATION NAME: <b>$aref->{strName}</b></div>
		<div class="displaybox" style="clear:both;margin-top:20px;">
		<form method="post" action="">
		<input type="hidden" name="aID" value="$intAssocID">
		<input type="hidden" name="action" value="ASSOC_ASSOC_config_SC">
		<table border="1" cellpadding="3" cellspacing="3" bordercolor="black" style="margin-left:auto;margin-right:auto;" align="center">
	
	];

	$query = $db->prepare($statement) or query_error($statement);
    	$query->execute or query_error($statement);
	my @keys = ();
	
	my $priorConfigArea = '';
	my $counter=0;
	my $bgcolor='';
	while (my $dref = $query->fetchrow_hashref())	{

		if($priorConfigArea ne 1) {
		$body .= qq[
			 <tr>
					 <td colspan="4" style='color:white;background-color:#1376B0;padding:0px;'><h1 style='padding-left:15px;margin-bottom:0px;padding-5px;';>Association Config</h1></td>
			 </tr>
			<tr>
                        <th>Setting Name</th>
                        <th>Config Value</th>
                        <th>Description</th>
                </tr>

			];

			$priorConfigArea = 1;
		}
		
		if($counter%2==0){
		$bgcolor='#ffffff';
		}
		else{
		$bgcolor='#90D3F9';
		}
		my $style = qq[style="background-color:$bgcolor"];
		$body .= qq[
			<tr>
				<td $style><b>$dref->{strOption}</b></td>
				<td $style><input type="text" size="30" name="DB_$dref->{strOption}" value="$dref->{strValue}"></td>
				<td $style>$available_keys->{$dref->{strOption}}[2]</td>
			</tr>
		];
		delete $available_keys->{$dref->{strOption}};
		$counter++;	
		}

	$body .= qq[
		</table>
		<input type="submit" name="save" value="U P D A T E">
		</form>
	];
	if (scalar keys %{$available_keys})	{
		$body .= qq[
			<br><br>
			<form method="post" action="">
			<input type="hidden" name="aID" value="$intAssocID">
			<input type="hidden" name="action" value="ASSOC_ASSOC_config_IC">
			<select name="new_strKey" class="chzn-select">
			<option value="" SELECTED>--Select New Config Item--</option>
		];
	
		foreach my $key (sort keys %{$available_keys})    {
			$body .= qq[<option value="$key">$available_keys->{$key}[0] : $key - $available_keys->{$key}[2]</option>];
		}
		
		$body .= qq[
			</select>
			<input type="text" name="new_strValue" value="">
			<br>
			<input type="submit" name="new" value="A D D  I T E M">
			</form>
		];
	}
	
	$body .= qq[
		<br><br>
				<br>
		</div></td></tr></table>	];

	return $body;
}

sub updateAssocConfigs	{

	my ($db, $intAssocID) = @_;
	$intAssocID ||= 0;

	my $output=new CGI;
    my %fields = $output->Vars;

    #Get rid of non stat fields
	my $strError = '';
	my @statements = ();
	
	for my $key (keys %fields)	{
        if($key=~/^DB_/)	{
			my $newkey=$key;
        	$newkey=~s/^DB_//g;
			my $statement = qq[
				UPDATE tblAssocConfig
				SET strValue = "$fields{$key}"
				WHERE intAssocID = $intAssocID
					AND strOption = "$newkey"
			];
			push @statements, $statement;
		    DEBUG $statement;
		}
	}

	if ($strError)	{
		return $strError;
	}
	else	{
		for my $statement (@statements)	{
			my $query = $db->prepare($statement) or query_error($statement);
    		$query->execute or query_error($statement);
		}
		return "OK";
	}
	
}

sub insertAssocConfigItem	{

	my ($db, $intAssocID, $strKey, $strValue) = @_;
	$intAssocID ||= 0;

	if ($strValue!~/^\d+$/)	{
#		return "MUST BE NUMBERIC\n";
	}

	my $statement = qq[
		INSERT INTO tblAssocConfig
		(intAssocID, strOption, strValue)
		VALUES ($intAssocID, "$strKey", "$strValue")
	];
	my $query = $db->prepare($statement) or query_error($statement);
    $query->execute or query_error($statement);

	return "ADDED SUCCESSFULLY\n";
}

