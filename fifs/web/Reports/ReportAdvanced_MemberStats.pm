#
# $Header: svn://svn/SWM/trunk/web/Reports/ReportAdvanced_MemberStats.pm 10522 2014-01-23 05:57:33Z dhanslow $
#

package Reports::ReportAdvanced_MemberStats;

use strict;
use lib ".";
use ReportAdvanced_Common;
use Reports::ReportAdvanced;
our @ISA = qw(Reports::ReportAdvanced);

use lib '..','../..','../sportstats';

use strict;
use PlayerCompStatsFactory;

sub _getConfiguration {
	my $self = shift;

	my $currentLevel = $self->{'EntityTypeID'} || 0;
	my $Data = $self->{'Data'};
	my $clientValues = $Data->{'clientValues'};
  my $natnumname = $Data->{'SystemConfig'}{'NationalNumName'} || 'National Number';
  my $natteamname = $Data->{'SystemConfig'}{'NatTeamName'} || 'National Team';
	my $SystemConfig = $Data->{'SystemConfig'};

	my $CommonVals = getCommonValues(
		$Data,
		{
			SubRealms => 1,
			DefCodes => 1,
			Seasons => 1,
			FieldLabels => 1,
			AgeGroups => 1,
			Assocs => 1,
		},
	);
	my $hideSeasons = $CommonVals->{'Seasons'}{'Hide'} || 0;

	my $FieldLabels = $CommonVals->{'FieldLabels'} || undef;

  my $txt_SeasonName= $Data->{'SystemConfig'}{'txtSeason'} || 'Season';
  my $txt_SeasonNames= $Data->{'SystemConfig'}{'txtSeasons'} || 'Seasons';
  my $txt_AgeGroupName= $Data->{'SystemConfig'}{'txtAgeGroup'} || 'Age Group';
  my $txt_AgeGroupNames= $Data->{'SystemConfig'}{'txtAgeGroups'} || 'Age Groups';

  my $MStablename = "tblMember_Seasons_$Data->{'Realm'}";
	my $RealmLPF_Ids = ($Data->{'SystemConfig'}{'LPF_ids'})	? $Data->{'SystemConfig'}{'LPF_ids'} : 0;

  #my $player_comp_stats_table = "tblPlayerCompStats_" . $Data->{'Realm'};
  my $player_comp_stats_table = "compStats";

  ## -- DODGEY CODE TO GET ASSOC ID TO CREATE OBJECT -- ##
  my $assocID = $Data->{'assocID'} || 0;
  my $sportID = 0;
  unless ($assocID) {
    my $st = qq[
      SELECT
        intAssocID,
        intSWOL_SportID
      FROM
        tblAssoc
      WHERE
        intRealmID = $Data->{'Realm'}
        AND intRecStatus <> $Defs::RECSTATUS_DELETED
        AND intSWOL = 1
      LIMIT 1
    ];
    my $q = $Data->{'db'}->prepare($st);
    $q->execute();
    my ($db_assocID, $db_sportID) = $q->fetchrow_array();
    $assocID = $db_assocID if ($db_assocID);
    $sportID = $db_sportID;
  }
  ## -- END  -- ##

  my %args = (
    Data => $Data,
    CompetitionID => $clientValues->{compID} || -1,
    AssocID => $assocID,
    SportID => $sportID,
  );
  my $player_comp_stats = PlayerCompStatsFactory->create(%args);

  my $stat_fields = $player_comp_stats->get_stat_report_fields();

	my %config = (
		Name => 'Games Played Report',
		StatsReport => 0,
		MemberTeam => 0,
		ReportEntity => 1,
		ReportLevel => 0,
		Template => 'default_adv',
    TemplateEmail => 'default_adv_CSV',
		DistinctValues => 1,
		SQLBuilder => \&SQLBuilder,
		Fields => {
			strNationalNum => [
				$natnumname,
				{
					displaytype => 'text',
					fieldtype => 'text',
					allowsort => 1,
					optiongroup => 'details'
				}
			],
			MemberID => [
				'Member ID',
				{
					displaytype => 'text',
					fieldtype => 'text',
					allowsort => 1,
					optiongroup =>'details',
					dbfield => 'tblMember.intMemberID'
				}
			],
			strMemberNo => [
				$Data->{'SystemConfig'}{'FieldLabel_strMemberNo'} || 'Member No.',
				{
					displaytype => 'text',
					fieldtype => 'text',
					allowsort => 1,
					optiongroup => 'details'
				}
			],
			intRecStatus => [
				'Active Record',
				{
					displaytype => 'lookup',
					fieldtype => 'dropdown',
					dropdownoptions => { 0=>'No', 1=>'Yes'},
					dropdownorder => [0, 1],
					dbfield => 'tblMember.intStatus',
					defaultcomp => 'equal',
					defaultvalue => '1',
					active => 1,
					optiongroup => 'details'
				}
			],
			strFirstname => [
				'First Name',
				{
					displaytype => 'text',
					fieldtype => 'text',
					active => 1,
					allowsort => 1,
					optiongroup => 'details'
				}
			],
			strSurname => [
				'Family Name',
				{
					displaytype => 'text',
					fieldtype => 'text',
					active => 1,
					allowsort => 1,
					optiongroup => 'details',
				}
			],
			strPreferredName => [
				'Preferred Name',
				{
					displaytype => 'text',
					fieldtype => 'text',
					allowsort => 1,
					optiongroup => 'details'
				}
			],
			dtDOB => [
				'Date of Birth',
				{
					displaytype => 'date',
					fieldtype => 'date',
					allowsort => 1,
					dbfield => 'tblMember.dtDOB',
					dbformat => ' DATE_FORMAT(tblMember.dtDOB,"%d/%m/%Y")',
					optiongroup => 'details'
				}
			],
			dtYOB => [
				'Year of Birth',
				{
					displaytype => 'date',
					fieldtype => 'text',
					allowsort => 1,
					dbfield => 'YEAR(tblMember.dtDOB)',
					dbformat => ' YEAR(tblMember.dtDOB)',
					optiongroup => 'details'
				}
			],
			intGender => [
				'Gender',
				{
					displaytype => 'lookup',
					fieldtype => 'dropdown',
					dropdownoptions => { ''=>'&nbsp;', 1=>'Male', 2=>'Female'},
					dropdownorder => ['', 1, 2],
					size => 2,
					multiple => 1,
					optiongroup => 'details',
				}
			],
			intDeceased => [
				'Deceased',
				{
					displaytype => 'lookup',
					fieldtype => 'dropdown',
					dropdownoptions => { 0=>'No', 1=>'Yes'},
					dropdownorder => [0, 1],
					optiongroup => 'details',
					defaultcomp => 'equal',
					defaultvalue => '0',
					active => 1,
				} 
			],
      ## OTHER
      dtCreatedOnline => [
        'Date Created Online',
        {
          displaytype => 'date',
          fieldtype => 'datetime',
          allowsort => 1,
          dbformat => ' DATE_FORMAT(tblMember.dtCreatedOnline,"%d/%m/%Y")',
          optiongroup => 'otherfields',
          dbfield => 'tblMember.dtCreatedOnline'
        }
      ],
      # AFFILIATIONS
      strAssocName => [
        ($clientValues->{assocID} != -1 ? '' : $Data->{'LevelNames'}{$Defs::LEVEL_ASSOC} . ' Name'),
          {
            displaytype => 'lookup',
            fieldtype => 'dropdown',
            dropdownoptions => $CommonVals->{'Assocs'},
            #displaytype => 'text', 
            #fieldtype => 'text', 
            allowsort => 1, 
            dbfield => 'tblAssoc.intAssocID', 
            optiongroup => 'affiliations', 
          }
      ], 
      strTeamName => [
        $SystemConfig->{'NoTeams'} ? '' :$Data->{'LevelNames'}{$Defs::LEVEL_TEAM}.' Name' ,
        {
          displaytype => 'text', 
          allowgrouping => 1, 
          fieldtype => 'text', 
          allowsort => 1, 
          dbfield => "tblTeam.strName", 
          optiongroup => 'affiliations', 
        }
      ],
      strClubName => [
        (
          (
            (!$SystemConfig->{'NoClubs'} or $Data->{'Permissions'}{$Defs::CONFIG_OTHEROPTIONS}{'ShowClubs'}) 
            and $currentLevel > $Defs::LEVEL_CLUB 
          ) ? $Data->{'LevelNames'}{$Defs::LEVEL_CLUB}.' Name' : ''
        ),
        {
          displaytype => 'text', 
          fieldtype => 'text', 
          allowsort => 1, 
          allowgrouping => 1, 
          dbfield => "tblClub.strName", 
          optiongroup => 'affiliations', 
        }
      ],
      strCompName => [
        (!$SystemConfig->{'NoComps'} ? $Data->{'LevelNames'}{$Defs::LEVEL_COMP}.' Name' : ''),
        {
          displaytype => 'text', 
          fieldtype => 'text', 
          allowsort => 1, 
          dbfield => "tblAssoc_Comp.strTitle", 
          allowgrouping => 1, 
          optiongroup => 'affiliations', 
        }
      ],
      strZoneName => [
        ($currentLevel > $Defs::LEVEL_ZONE ? $Data->{'LevelNames'}{$Defs::LEVEL_ZONE}.' Name' : ''),
        {
          displaytype => 'text', 
          fieldtype => 'text', 
          allowsort => 1, 
          dbfield => "IF(tblZone.intStatusID = $Defs::NODE_SHOW, tblZone.strName,'')", 
          optiongroup => 'affiliations'
        }
      ],
      strRegionName => [
        ($currentLevel > $Defs::LEVEL_REGION ? $Data->{'LevelNames'}{$Defs::LEVEL_REGION}.' Name' : ''),
        {
          displaytype => 'text', 
          fieldtype => 'text', 
          allowsort => 1, 
          dbfield  => "IF(tblRegion.intStatusID = $Defs::NODE_SHOW, tblRegion.strName,'')", 
          optiongroup => 'affiliations'
        }
      ],
      strStateName => [
        ($currentLevel > $Defs::LEVEL_STATE ? $Data->{'LevelNames'}{$Defs::LEVEL_STATE}.' Name' : ''),
        {
          displaytype => 'text', 
          fieldtype => 'text', 
          allowsort => 1, 
          dbfield => "IF(tblState.intStatusID = $Defs::NODE_SHOW, tblState.strName,'')", 
          optiongroup => 'affiliations'
        }
      ],
      strNationalName=> [
        ($currentLevel > $Defs::LEVEL_NATIONAL ? $Data->{'LevelNames'}{$Defs::LEVEL_NATIONAL}.' Name' : ''),
        {
          displaytype => 'text', 
          fieldtype => 'text', 
          allowsort => 1, 
          dbfield => "IF(tblNational.intStatusID = $Defs::NODE_SHOW, tblNational.strName,'')", 
          optiongroup => 'affiliations'
        }
      ],
      strIntZoneName => [
        ($currentLevel > $Defs::LEVEL_INTZONE ? $Data->{'LevelNames'}{$Defs::LEVEL_INTZONE}.' Name' : ''),
        {
          displaytype => 'text', 
          fieldtype => 'text', 
          allowsort => 1, 
          dbfield => "IF(tblIntZone.intStatusID = $Defs::NODE_SHOW, tblIntZone.strName,'')" , 
          optiongroup => 'affiliations'
        }
      ],
      strIntRegionName => [
        ($currentLevel > $Defs::LEVEL_INTREGION ? $Data->{'LevelNames'}{$Defs::LEVEL_INTREGION}.' Name' : ''),
        {
          displaytype => 'text', 
          fieldtype => 'text', 
          allowsort => 1, 
          dbfield  => " IF(tblIntRegion.intStatusID = $Defs::NODE_SHOW, tblIntRegion.strName,'') ", 
          optiongroup => 'affiliations'
        }
      ],
      ## STATS
      GamesPlayed => [
        ($Data->{SystemConfig}->{AllowSWOL} ? 'Games' : ''),
        {
          displaytype => 'text', 
          #dbfield => "$player_comp_stats_table.intStatTotal1",
          #dbformat => qq[SUM($player_comp_stats_table.intStatTotal1)], 
          dbfield => qq[SUM(intStatTotal1)], 
          allowsort => 1, 
          optiongroup => 'stats'
        }
      ],

      ( map { (
        "STAT_".$_->[1] => [
          $_->[0],
          {
            displaytype => 'text',
            #dbfield     => "$player_comp_stats_table.$_->[1]",
            #dbformat    => qq[SUM($player_comp_stats_table.$_->[1])], 
            dbfield     => qq[SUM($_->[1])], 
            sorttype    => 'number',
            allowsort   => 1, 
            optiongroup => 'stats'
          }
        ],
      ) } ( @{$stat_fields} ) ),

      ## SEASONS
      intNewSeasonID => [
        "$txt_SeasonName",
        {
          displaytype => 'lookup', 
          fieldtype => 'dropdown', 
          dropdownoptions => $CommonVals->{'Seasons'}{'Options'},  
          dropdownorder => $CommonVals->{'Seasons'}{'Order'}, 
          allowsort => 1, 
          optiongroup => 'seasons', 
          active => 0, 
          multiple => 1, 
          size => 3, 
          disable => $hideSeasons 
        }
      ],
      intAgeGroupID => [
        "$txt_AgeGroupName",
        {
          displaytype => 'lookup', 
          fieldtype => 'dropdown', 
          dropdownoptions => $CommonVals->{'AgeGroups'}{'Options'},  
          dropdownorder => $CommonVals->{'AgeGroups'}{'Order'}, 
          allowsort => 1, 
          allowgrouping => 1, 
          optiongroup => 'seasons', 
          multiple => 1, 
          size => 3, 
          dbfield => "CS.intAgeGroupID", 
          disable => $hideSeasons 
        }
      ],
		},
    Order => [qw( 
	    strNationalNum
			MemberID
			strMemberNo
			intRecStatus
			intDefaulter
			strSalutation
			strFirstname
			strMiddlename
			strSurname
			strPreferredName
			dtDOB
			dtYOB
			intGender
			intDeceased
			dtCreatedOnline
			strAssocName
			strTeamName
			strClubName
			strCompName
			strZoneName
			strRegionName
			strStateName
			strNationalName
			strIntZoneName
			strIntRegionName
      intNewSeasonID
      intAgeGroupID
      GamesPlayed
		),
      ( map { (
        "STAT_".$_->[1]
      ) } ( @{$stat_fields} ) ),
    ],
		Config => {
		  EmailExport => 1,
			limitView  => 5000,
			EmailSenderAddress => $Defs::admin_email,
			SecondarySort => 1,
			RunButtonLabel => 'Run Report',
			ReturnProcessData => [qw(
        tblMember.strEmail 
        tblMember.strPhoneMobile 
        tblMember.strSurname 
        tblMember.strFirstname 
        tblMember.intMemberID
      )],
		},
		ExportFormats =>	{
		},
		OptionGroups =>	{
		  details => ['Personal Details', {active=>1}],
			otherfields => ['Other Fields', {}],
			affiliations => ['Affiliations', {}],
			seasons => ['Seasons', {}],
			stats => ['Statistics', {}],
	  },
	);
	$self->{'Config'} = \%config;
}

sub SQLBuilder	{
	my ($self, $OptVals, $ActiveFields) = @_ ;

	my $currentLevel = $self->{'EntityTypeID'} || 0;
	my $Data = $self->{'Data'};
	my $clientValues = $Data->{'clientValues'};
	my $SystemConfig = $Data->{'SystemConfig'};

  #my $PCStablename = "tblPlayerCompStats_$Data->{'Realm'}";
  my $PCStablename = "CS";

	my $from_levels = $OptVals->{'FROM_LEVELS'};
	my $from_list = $OptVals->{'FROM_LIST'};
	my $where_levels = $OptVals->{'WHERE_LEVELS'};
	my $where_list = $OptVals->{'WHERE_LIST'};
	my $current_from = $OptVals->{'CURRENT_FROM'};
	my $current_where = $OptVals->{'CURRENT_WHERE'};
	my $select_levels = $OptVals->{'SELECT_LEVELS'};

  return ('', '') if ($currentLevel == $Defs::LEVEL_NONE);

	my $sql = '';
	{ #Work out SQL

    my $from_SQL = '';
    my $where_SQL = '';
    if ($currentLevel > $Defs::LEVEL_ASSOC) {
      $from_SQL = qq[
        INNER JOIN tblTempNodeStructure ON (
          tblTempNodeStructure.intAssocID = tblAssoc.intAssocID
        )
        LEFT JOIN tblNode AS tblState ON (
          tblState.intNodeID = tblTempNodeStructure.int30_ID
        )
        LEFT JOIN tblNode AS tblRegion ON (
          tblRegion.intNodeID = tblTempNodeStructure.int20_ID
        )
        LEFT JOIN tblNode AS tblZone ON (
          tblZone.intNodeID = tblTempNodeStructure.int10_ID
        )
      ];
      $where_SQL .= qq[AND tblTempNodeStructure.int30_ID = $clientValues->{'stateID'}] if ($currentLevel == 30);
      $where_SQL .= qq[AND tblTempNodeStructure.int20_ID = $clientValues->{'regionID'}] if ($currentLevel == 20);
      $where_SQL .= qq[AND tblTempNodeStructure.int10_ID = $clientValues->{'zoneID'}] if ($currentLevel == 10);
    }
    if ($currentLevel == $Defs::LEVEL_ASSOC) {
      $where_SQL .= qq[AND tblAssoc.intAssocID = $clientValues->{'assocID'}];
    }
    if ($currentLevel == $Defs::LEVEL_CLUB) {
      $where_SQL .= qq[AND tblClub.intClubID = $clientValues->{'clubID'}];
    }
    if ($currentLevel == $Defs::LEVEL_TEAM) {
      $where_SQL .= qq[AND tblTeam.intTeamID = $clientValues->{'teamID'}];
    }
    if($currentLevel == $Defs::LEVEL_COMP) {
      $where_SQL .= qq[AND tblAssoc_Comp.intCompID = $clientValues->{'compID'}];
    }

    $where_list = 'AND ' . $where_list if ($where_list);
    my @grouping = ();
    if (
          $ActiveFields->{'MemberID'} 
          or $ActiveFields->{'strMemberNo'} 
          or $ActiveFields->{'strFirstname'} 
          or $ActiveFields->{'strSurname'}
          or $ActiveFields->{'strNationalNum'}
    ) {
      push @grouping, 'tblMember.intMemberID';
    }
    push @grouping, 'tblNational.intNodeID' if $ActiveFields->{'strNationalName'};
    push @grouping, 'tblState.intNodeID' if $ActiveFields->{'strStateName'};
    push @grouping, 'tblZone.intNodeID' if $ActiveFields->{'strZoneName'};
    push @grouping, 'tblRegion.intNodeID' if $ActiveFields->{'strRegionalName'};
    push @grouping, 'tblAssoc.intAssocID' if $ActiveFields->{'strAssocName'};
    push @grouping, 'tblClub.intClubID' if $ActiveFields->{'strClubName'};
    push @grouping, 'tblAssoc_Comp.intCompID' if $ActiveFields->{'strCompName'};
    push @grouping, 'tblTeam.intTeamID' if $ActiveFields->{'strTeamName'};
	my @additional_selects = @grouping;
    push @grouping, 'intNewSeasonID' if $ActiveFields->{'intNewSeasonID'};
    push @grouping, "$PCStablename.intAgeGroupID" if $ActiveFields->{'intAgeGroupID'};
    my $grp_line = join(',',@grouping) || '';
    $grp_line = "GROUP BY $grp_line" if $grp_line;

	my @selects = split(",",$OptVals->{'SELECT'});
	my @select_array = ();
	foreach my $field ( @selects ) {
		next if($field =~/DATE_FORMAT/);
		my @field_parts = split(" ",$field);
		if($field_parts[-1] =~ /STAT_/ or $field_parts[-1] eq 'GamesPlayed') {
		push @select_array, "SUM(".$field_parts[-1].") as $field_parts[-1]";
		}else {
		push @select_array, $field_parts[-1];
		}
	}
	my @additional_selects_final = (); 
	foreach my $field ( @additional_selects )
	{
		next if($field eq 'tblMember.intMemberID' and $ActiveFields->{'MemberID'});
		$field = "tblMember.intMemberID as MemberID" if($field eq 'tblMember.intMemberID');
		push @additional_selects_final, $field;
	}
    my $select = join(',',@select_array) || '';
	my @major_group_array = ();
	foreach my $field ( @grouping )
	{
		
		$field = "MemberID" if($field eq 'tblMember.intMemberID');
		my @field_parts = split('\.',$field);
		my $part_name = $field_parts[-1] || $field;
		push @major_group_array, $part_name;
	}
    $select = join(',',@select_array) || '';
    my $additional_selects = join(',',@additional_selects_final) || '';
    $additional_selects = $additional_selects." , " if($additional_selects);
	my $grp_line_final = join(',',@major_group_array) || '';
    $grp_line_final = "GROUP BY $grp_line_final" if $grp_line_final;
    $sql = qq[
	SELECT $select FROM (
	SELECT
         $additional_selects ###SELECT###
      FROM
        tblPlayerCompStats_SG_$Data->{'Realm'} CS
        INNER JOIN tblAssoc ON (
          tblAssoc.intAssocID = CS.intAssocID
          AND tblAssoc.intRecStatus <> -1
        )
        LEFT JOIN tblClub ON (
          tblClub.intClubID = CS.intClubID
        )
        LEFT JOIN tblTeam ON (
          tblTeam.intTeamID = CS.intTeamID
        )
        INNER JOIN tblMember ON (
          tblMember.intMemberID = CS.intPlayerID
          AND tblMember.intStatus <> -1
        )
        LEFT JOIN tblAssoc_Comp ON (
          tblAssoc_Comp.intCompID = CS.intCompID
        )
        $from_SQL
      WHERE
        (tblTeam.intRecStatus <> -1 OR CS.intCompID IS NULL OR  CS.intCompID=0)
        AND (tblClub.intRecStatus <> -1 OR CS.intCompID IS NULL OR CS.intCompID=0)
        AND (tblAssoc_Comp.intStatus <> -1 OR CS.intCompID IS NULL OR CS.intCompID=0)
        $where_SQL
        $where_list
      $grp_line

	UNION

	SELECT
        $additional_selects ###SELECT### 
      FROM
	tblPlayerCompStats_ME_$Data->{'Realm'} CS
        INNER JOIN tblAssoc ON (
          tblAssoc.intAssocID = CS.intAssocID
          AND tblAssoc.intRecStatus <> -1
        )
        LEFT JOIN tblClub ON (
          tblClub.intClubID = CS.intClubID
        )
        LEFT JOIN tblTeam ON (
          tblTeam.intTeamID = CS.intTeamID
        )
        INNER JOIN tblMember ON (
          tblMember.intMemberID = CS.intPlayerID
          AND tblMember.intStatus <> -1
        )
        LEFT JOIN tblAssoc_Comp ON (
          tblAssoc_Comp.intCompID = CS.intCompID
        )
        $from_SQL
      WHERE
        (tblTeam.intRecStatus <> -1 OR CS.intCompID IS NULL OR CS.intCompID=0)
        AND (tblClub.intRecStatus <> -1 OR CS.intCompID IS NULL OR CS.intCompID=0)
        AND (tblAssoc_Comp.intStatus <> -1 OR CS.intCompID IS NULL OR  CS.intCompID=0)
        $where_SQL
        $where_list
      $grp_line
   	) AS compStats
	$grp_line_final];
		return ($sql,'');
	}
}

1;
