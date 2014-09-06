#
# $Header: svn://svn/SWM/trunk/web/Reports/ReportAdvanced_Umpires.pm 8251 2013-04-08 09:00:53Z rlee $
#

package Reports::ReportAdvanced_Umpires;

use strict;
use lib ".";
use ReportAdvanced_Common;
use Reports::ReportAdvanced;
use Reg_common;
use FormHelpers;
use CGI qw(param);
our @ISA =qw(Reports::ReportAdvanced);


use strict;

sub _getConfiguration {
	my $self = shift;

	my $currentLevel = $self->{'EntityTypeID'} || 0;
	my $Data = $self->{'Data'};
	my $SystemConfig = $self->{'SystemConfig'};
	my $clientValues = $Data->{'clientValues'};

  my $txt_Clr = $SystemConfig->{'txtCLR'} || 'Clearance';
	my $showAgentFields = ($SystemConfig->{'clrHide_AgentFields'} == 1) ? '0' : '1';
  my $natnumname=$SystemConfig->{'NationalNumName'} || 'National Number';

	my $assocID=getAssocID($Data->{'clientValues'});
	my $assoc_where = '';
	$assoc_where = qq[ AND intUmpireAssocID = $assocID ];
	my $club_where = '';
	if ($Data->{clientValues}{clubID} and $Data->{clientValues}{clubID} > 0)	{
		$club_where = qq[ AND intUmpireEntityID = $Data->{clientValues}{clubID} ];
	}
	my $st_assoc = qq[
		SELECT
			DISTINCT
			intCompID,
			CONCAT(A.strName , '-' , strSeasonName, '- ', strTitle) as Title
		FROM
			tblUmpireLevelConfig as ULC
			INNER JOIN tblAssoc_Comp as AC ON (
				AC.intAssocID = intComp_AssocID
			)
			LEFT JOIN tblSeasons as S ON (
				S.intSeasonID=intNewSeasonID
			)
			INNER JOIN tblAssoc as A ON (
				A.intAssocID=AC.intAssocID
			)
		WHERE
			ULC.intRealmID=?
			AND intSystemType=1
			AND AC.intRecStatus <> -1
			$assoc_where
			$club_where
		ORDER BY 
			A.strName, 
			dtStart DESC,
			strTitle
	];
	my $comps = qq[ 
		<select name="_EXTcompID">
		<option value="0" SELECTED>Please select a $Data->{LevelNames}{$Defs::LEVEL_COMP}</option>
	];
		
	my $q_assoc = $Data->{'db'}->prepare($st_assoc);
	$q_assoc->execute($Data->{'Realm'});
	while (my $dref=$q_assoc->fetchrow_hashref())	{
		$comps .= qq[<option value="$dref->{intCompID}">$dref->{Title}</option>];
	}
	$comps .= qq[</select>];

	## TO DO:
		## - Adjust Comp select to only be COMPS they UMPIRE
		## - SELECT for Umpire expenses for column names and build up config

	my $preblock = qq[
<div style="margin:10px 0px;font-weight:bold;"> Select competition (<i>Optional)</li> $comps</div>
	];

	my $st_exp = qq[
		SELECT
			*
		FROM
			tblUmpireExpRealmConfig
		WHERE
			intRealmID = ?
	];
	my $q = $Data->{'db'}->prepare($st_exp);
	$q->execute($Data->{'Realm'});
	my $Exp = $q->fetchrow_hashref() || undef;

	my %config = (
		Name => 'Match Players',

		StatsReport => 0,
		MemberTeam => 0,
		ReportEntity => 1,
		ReportLevel => 0,
		Template => 'default_adv',
    TemplateEmail => 'default_adv_CSV',
		DistinctValues => 1,
    SQLBuilder => \&SQLBuilder,
    PreBlock => $preblock,

		Fields => {

			strNationalNum => [
				 $natnumname,
				{
					display=>'text',
					fieldtype=>'text',
					dbfield=>'M.strNationalNum',
					allowgrouping=>1,
				},
		  ],
			Firstname => [
				 'First name',
				{
					displaytype=>'text',
					fieldtype=>'text',
					allowsort=>1,
					dbfield=>'M.strFirstname',
					active=>1
				},
			],
			Surname => [
				'Family Name',
				{
					displaytype=>'text',
					fieldtype=>'text',
					allowgrouping=>1,
					allowsort=>1,
					dbfield=>'M.strSurname',
					active=>1
				},
			 ],
			MstrAddress1=> [
				 'Address 1',
				{
					displaytype=>'text',
					fieldtype=>'text',
					allowsort=>1,
					dbfield=>'M.strAddress1',
					optiongroup=>'member',
					active=>1
				},
			],
			MstrAddress2=> [
				 'Address 2',
				{
					displaytype=>'text',
					fieldtype=>'text',
					allowsort=>1,
					dbfield=>'M.strAddress2',
					optiongroup=>'member',
					active=>1
				},
			],
			MstrSuburb=> [
				 'Suburb',
				{
					displaytype=>'text',
					fieldtype=>'text',
					allowsort=>1,
					dbfield=>'M.strSuburb',
					optiongroup=>'member',
					active=>1
				},
			],
			MstrState=> [
				 'State',
				{
					displaytype=>'text',
					fieldtype=>'text',
					allowsort=>1,
					dbfield=>'M.strState',
					optiongroup=>'member',
					active=>1
				},
			],
			MstrPostalCode=> [
				 'Postal Code',
				{
					displaytype=>'text',
					fieldtype=>'text',
					allowsort=>1,
					dbfield=>'M.strPostalCode',
					optiongroup=>'member',
					active=>1
				},
			],
			MstrPhoneHome=> [
				 'Phone - Home',
				{
					displaytype=>'text',
					fieldtype=>'text',
					allowsort=>1,
					dbfield=>'M.strPhoneHome',
					optiongroup=>'member',
					active=>1
				},
			],
			MstrPhoneWork=> [
				 'Phone - Work',
				{
					displaytype=>'text',
					fieldtype=>'text',
					allowsort=>1,
					dbfield=>'M.strPhoneWork',
					optiongroup=>'member',
					active=>1
				},
			],
			MstrPhoneMobile=> [
				 'Phone - Mobile',
				{
					displaytype=>'text',
					fieldtype=>'text',
					allowsort=>1,
					dbfield=>'M.strPhoneMobile',
					optiongroup=>'member',
					active=>1
				},
			],
			MstrEmail=> [
				 'Email',
				{
					displaytype=>'text',
					fieldtype=>'text',
					allowsort=>1,
					dbfield=>'M.strEmail',
					optiongroup=>'member',
					active=>1
				},
			],

			strUmpireType=> [
				'Match Official Type',
				{
					displaytype=>'text',
					fieldtype=>'text',
					allowsort=>1,
					dbfield=>'strUmpireType',
					allowgrouping=>1,
					active=>1
				},
			 ],
			AssocName=> [
				"Association Running $Data->{LevelNames}{$Defs::LEVEL_COMP}",
				{
					displaytype=>'text',
					fieldtype=>'text',
					allowsort=>1,
					dbfield=>'A.strName',
					allowgrouping=>1,
					active=>1
				},
			 ],
			strTitle=> [
				'Competition Title',
				{
					displaytype=>'text',
					fieldtype=>'text',
					allowgrouping=>1,
					allowsort=>1,
					dbfield=>'Comp.strTitle',
					active=>1
				},
			 ],
			intMatchNum=> [
				'Match Number',
				{
					displaytype=>'text',
					fieldtype=>'text',
					allowsort=>1,
					allowgrouping=>1,
					dbfield=>'intMatchNum',
					active=>1
				},
			 ],
			strMatchAbbrev=> [
				'Match Abbreviation',
				{
					displaytype=>'text',
					fieldtype=>'text',
					allowsort=>1,
					allowgrouping=>1,
					dbfield=>'strMatchAbbrev',
					active=>1
				},
			 ],
			strMatchName=> [
				'Match Name',
				{
					displaytype=>'text',
					fieldtype=>'text',
					allowsort=>1,
					dbfield=>'strMatchName',
					allowgrouping=>1,
					active=>1
				},
			 ],
			intRoundNumber => [
				'Round Number',
				{
					displaytype=>'text',
					fieldtype=>'text',
					allowsort=>1,
					dbfield=>'Rounds.intRoundNumber ',
					allowgrouping=>1,
					active=>1
				},
			 ],
			strRoundName=> [
				'Round Name',
				{
					displaytype=>'text',
					fieldtype=>'text',
					allowsort=>1,
					allowgrouping=>1,
					dbfield=>'Rounds.strRoundName',
					active=>1
				},
			 ],
			 dtMatchTime=> [
                'Match Date/Time',
                {
                    active=>1,
                    displaytype=>'date',
                    fieldtype=>'datetime',
                    allowsort=>1,
                    dbformat=>' DATE_FORMAT(dtMatchTime,"%d/%m/%Y %H:%i")',
                    dbfield=>'dtMatchTime',
					allowgrouping=>1,
                    sortfield=>'dtMatchTime'
                }
            ],
			HomeTeamName=> [
				"Home Team Name",
				{
					displaytype=>'text',
					fieldtype=>'text',
					allowsort=>1,
					dbfield => 'HomeTeam.strName',
					#active=> 1
				},
			],
			AwayTeamName=> [
				"Away Team Name",
				{
					displaytype=>'text',
					fieldtype=>'text',
					allowsort=>1,
					dbfield => 'AwayTeam.strName',
					#active=> 1
				},
			],
			HomeClub => ['Home Team Club',{displaytype=>'text', fieldtype=>'text', allowsort=>1, active=>1, dbfield=>'HomeTeamClub.strName'}],
			AwayClub => ['Away Team Club',{displaytype=>'text', fieldtype=>'text', allowsort=>1, active=>1, dbfield=>'AwayTeamClub.strName'}],

			VenueName=> [
				'Venue Name',
				{
					displaytype=>'text',
					fieldtype=>'text',
					allowsort=>1,
					dbfield=>'V.strName',
					allowgrouping=>1,
					active=>1
				},
			 ],
			SeasonName=> [
				'Season',
				{
					displaytype=>'text',
					fieldtype=>'text',
					allowsort=>1,
					dbfield=>'strSeasonName',
					allowgrouping=>1,
					active=>1
				},
			 ],
			intKilometres=> [
				'KM Driven',
				{
					displaytype=>'text',
					fieldtype=>'text',
					allowsort=>1,
					dbfield=>'UA.intKilometres',
					active=>1,
					optiongroup=>'expenses',
				},
			 ],
			curKMRate=> [
				'KM Rate',
				{
					displaytype=>'text',
					fieldtype=>'text',
					allowsort=>1,
					dbfield=>'UA.curKMRate',
					active=>1,
					optiongroup=>'expenses',
				},
			 ],
			curKMTotal=> [
				'KM Total Expense',
				{
					displaytype=>'text',
					fieldtype=>'text',
					allowsort=>1,
					dbfield=>'UA.curKMTotal',
					active=>1,
					optiongroup=>'expenses',
					total => 1,
				},
			 ],
			intLeagueKilometres=> [
				'League KM Driven',
				{
					displaytype=>'text',
					fieldtype=>'text',
					allowsort=>1,
					dbfield=>'UA.intLeagueKilometres',
					active=>1,
					optiongroup=>'expenses',
				},
			 ],
			curKMLeagueRate=> [
				'League KM Rate',
				{
					displaytype=>'text',
					fieldtype=>'text',
					allowsort=>1,
					dbfield=>'UA.curKMLeagueRate',
					active=>1,
					optiongroup=>'expenses',
				},
			 ],
			curKMLeagueTotal=> [
				'League KM Total Expense',
				{
					displaytype=>'text',
					fieldtype=>'text',
					allowsort=>1,
					dbfield=>'UA.curKMLeagueTotal',
					active=>1,
					optiongroup=>'expenses',
					total => 1,
				},
			 ],
			ExpTotal=> [
				'Expenses Total',
				{
					displaytype=>'text',
					fieldtype=>'text',
					allowsort=>1,
					dbfield=>'UA.curTotal',
					active=>1,
					optiongroup=>'expenses',
					total => 1,
				},
			 ],
			PayRateTotal=> [
				'Pay Rate Total',
				{
					displaytype=>'text',
					fieldtype=>'text',
					allowsort=>1,
					dbfield=>'UA.curPayRateTotal',
					active=>1,
					optiongroup=>'expenses',
					total => 1,
				},
			 ],
			ExpTotal=> [
				'Total Cost',
				{
					displaytype=>'text',
					fieldtype=>'text',
					allowsort=>1,
					dbfield=>'UA.curTotal',
					active=>1,
					optiongroup=>'expenses',
					total => 1,
				},
			 ],
			Exp1=> [
				$Exp->{'strExpense1'} ? $Exp->{'strExpense1'} : '',
				{
                    active=>1,
                    displaytype=>'text',
                    dbfield=>'UA.curExpense1',
                    sortfield=>'UA.curExpense1',
					optiongroup=>'expenses',
				},
			],
			Exp2=> [
				$Exp->{'strExpense2'} ? $Exp->{'strExpense2'} : '',
				{
                    active=>1,
                    displaytype=>'text',
                    dbfield=>'UA.curExpense2',
                    sortfield=>'UA.curExpense2',
					optiongroup=>'expenses',
				},
			],
			Exp3=> [
				$Exp->{'strExpense3'} ? $Exp->{'strExpense3'} : '',
				{
                    active=>1,
                    displaytype=>'text',
                    dbfield=>'UA.curExpense3',
                    sortfield=>'UA.curExpense3',
					optiongroup=>'expenses',
				},
			],
			Exp4=> [
				$Exp->{'strExpense4'} ? $Exp->{'strExpense4'} : '',
				{
                    active=>1,
                    displaytype=>'text',
                    dbfield=>'UA.curExpense4',
                    sortfield=>'UA.curExpense4',
					optiongroup=>'expenses',
				},
			],
			Exp5=> [
				$Exp->{'strExpense5'} ? $Exp->{'strExpense5'} : '',
				{
                    active=>1,
                    displaytype=>'text',
                    dbfield=>'UA.curExpense5',
                    sortfield=>'UA.curExpense5',
					optiongroup=>'expenses',
				},
			],
			Exp6=> [
				$Exp->{'strExpense6'} ? $Exp->{'strExpense6'} : '',
				{
                    active=>1,
                    displaytype=>'text',
                    dbfield=>'UA.curExpense6',
                    sortfield=>'UA.curExpense6',
					optiongroup=>'expenses',
				},
			],
			Exp7=> [
				$Exp->{'strExpense7'} ? $Exp->{'strExpense7'} : '',
				{
                    active=>1,
                    displaytype=>'text',
                    dbfield=>'UA.curExpense7',
                    sortfield=>'UA.curExpense7',
					optiongroup=>'expenses',
				},
			],
			Exp8=> [
				$Exp->{'strExpense8'} ? $Exp->{'strExpense8'} : '',
				{
                    active=>1,
                    displaytype=>'text',
                    dbfield=>'UA.curExpense8',
                    sortfield=>'UA.curExpense8',
					optiongroup=>'expenses',
				},
			],
			Exp9=> [
				$Exp->{'strExpense9'} ? $Exp->{'strExpense9'} : '',
				{
                    active=>1,
                    displaytype=>'text',
                    dbfield=>'UA.curExpense9',
                    sortfield=>'UA.curExpense9',
					optiongroup=>'expenses',
				},
			],
			Exp10=> [
				$Exp->{'strExpense10'} ? $Exp->{'strExpense10'} : '',
				{
                    active=>1,
                    displaytype=>'text',
                    dbfield=>'UA.curExpense10',
                    sortfield=>'UA.curExpense10',
					optiongroup=>'expenses',
				},
			],
			Exp11=> [
				$Exp->{'strExpense11'} ? $Exp->{'strExpense11'} : '',
				{
                    active=>1,
                    displaytype=>'text',
                    dbfield=>'UA.curExpense11',
                    sortfield=>'UA.curExpense11',
					optiongroup=>'expenses',
				},
			],
			Exp12=> [
				$Exp->{'strExpense12'} ? $Exp->{'strExpense12'} : '',
				{
                    active=>1,
                    displaytype=>'text',
                    dbfield=>'UA.curExpense12',
                    sortfield=>'UA.curExpense12',
					optiongroup=>'expenses',
				},
			],
			Exp13=> [
				$Exp->{'strExpense13'} ? $Exp->{'strExpense13'} : '',
				{
                    active=>1,
                    displaytype=>'text',
                    dbfield=>'UA.curExpense13',
                    sortfield=>'UA.curExpense13',
					optiongroup=>'expenses',
				},
			],
			Exp14=> [
				$Exp->{'strExpense14'} ? $Exp->{'strExpense14'} : '',
				{
                    active=>1,
                    displaytype=>'text',
                    dbfield=>'UA.curExpense14',
                    sortfield=>'UA.curExpense14',
					optiongroup=>'expenses',
				},
			],
			Exp15=> [
				$Exp->{'strExpense15'} ? $Exp->{'strExpense15'} : '',
				{
                    active=>1,
                    displaytype=>'text',
                    dbfield=>'UA.curExpense15',
                    sortfield=>'UA.curExpense15',
					optiongroup=>'expenses',
				},
			],
		},

		Order => [qw(
			strNationalNum 
			Firstname 
			Surname 
			MstrEmail
			MstrAddress1
			MstrAddress2
			MstrSuburb
			MstrState
			MstrPostalCode
			MstrPhoneHome
			MstrPhoneWork
			MstrPhoneMobile
			strUmpireType
			AssocName
			strTitle
			SeasonName
			intRoundNumber
			strRoundName
			strMatchName
			strMatchAbbrev
			intMatchNum
			dtMatchTime
			HomeTeamName
			HomeClub
			AwayTeamName
			AwayClub
			VenueName
			intKilometres
			curKMRate
			curKMTotal
			intLeagueKilometres
			curKMLeagueRate
			curKMLeagueTotal
			PayRateTotal
			Exp1
			Exp2
			Exp3
			Exp4
			Exp5
			Exp6
			Exp7
			Exp8
			Exp9
			Exp10
			Exp11
			Exp12
			Exp13
			Exp14
			Exp15
			ExpTotal
		)],
    OptionGroups => {
      default => ['Details',{}],
      expenses=> ['Expenses',{}],
      member=> ['Member Contact Details',{}],
    },

		Config => {
			FormFieldPrefix => 'c',
			FormName => 'rpform_',
			EmailExport => 1,
			limitView  => 5000,
			EmailSenderAddress => $Defs::admin_email,
			SecondarySort => 1,
			RunButtonLabel => 'Run Report',
		},
	);
	$self->{'Config'} = \%config;
}

sub SQLBuilder  {
  my($self, $OptVals, $ActiveFields) =@_ ;
  my $currentLevel = $self->{'EntityTypeID'} || 0;
  my $Data = $self->{'Data'};
  my $clientValues = $Data->{'clientValues'};
  my $SystemConfig = $Data->{'SystemConfig'};

  my $from_levels = $OptVals->{'FROM_LEVELS'};
  my $from_list = $OptVals->{'FROM_LIST'};
  my $where_levels = $OptVals->{'WHERE_LEVELS'};
  my $where_list = $OptVals->{'WHERE_LIST'};
  my $current_from = $OptVals->{'CURRENT_FROM'};
  my $current_where = $OptVals->{'CURRENT_WHERE'};
  my $select_levels = $OptVals->{'SELECT_LEVELS'};

  my $sql = '';
  { #Work out SQL

    my $compID = param('_EXTcompID') || $ActiveFields->{'_EXTcompID'} || 0;

		$compID =~ /^(\d+)$/;
		$compID=$1;
    #return ('', 'No Competition Selected') if !$compID;

		my $assocID=getAssocID($Data->{'clientValues'});

    my $extra_where = '';
    my $currentLevel =  $Data->{'clientValues'}{currentLevel};
    if ($currentLevel == $Defs::LEVEL_CLUB) {
			$extra_where .= qq[ AND intAllocatedEntityID =$Data->{clientValues}{clubID} ];
    }
    if ($currentLevel <= $Defs::LEVEL_ASSOC) {
			$extra_where .= qq[ AND intUmpireAssocID =$assocID ];
    }
	if ($compID)	{
		$extra_where .= qq[ AND UA.intCompID = $compID ];
	}

    if ($currentLevel > $Defs::LEVEL_ASSOC || $currentLevel <= $Defs::LEVEL_TEAM) {
			return ('','Report does not support current user level');
    }

    if ($where_list ne '') {
			$where_list = 'AND ' . $where_list;
    }

	$sql = qq[
 	SELECT ###SELECT###
    FROM
        tblUmpireAllocations as UA
        LEFT JOIN tblUmpireExpRealmConfig as UEC ON (UEC.intRealmID=UA.intRealmID)
        INNER JOIN tblUmpireTypes AS UT ON (UT.intUmpireTypeID = UA.intUmpireTypeID)
        INNER JOIN tblCompMatches ON (tblCompMatches.intMatchID = UA.intMatchID)
        LEFT JOIN tblTeam as HomeTeam ON (HomeTeam.intTeamID=tblCompMatches.intHomeTeamID)
        LEFT JOIN tblTeam as AwayTeam ON (AwayTeam.intTeamID=tblCompMatches.intAwayTeamID)
        LEFT JOIN tblClub as HomeTeamClub ON (HomeTeamClub.intClubID=HomeTeam.intClubID)
        LEFT JOIN tblClub as AwayTeamClub ON (AwayTeamClub.intClubID=AwayTeam.intClubID)
        INNER JOIN tblMember AS M ON (M.intMemberID = UA.intMemberID)
        LEFT JOIN tblDefVenue as V ON (V.intDefVenueID = tblCompMatches.intVenueID)
        INNER JOIN tblAssoc_Comp as Comp ON (Comp.intCompID=tblCompMatches.intCompID)
        INNER JOIN tblAssoc as A ON (A.intAssocID = Comp.intAssocID)
        LEFT JOIN tblSeasons as S ON (S.intSeasonID=Comp.intNewSeasonID)
        LEFT JOIN tblCompRounds as Rounds ON (Rounds.intRoundID = tblCompMatches.intRoundID)
        INNER JOIN tblUmpireLevelConfig as ULC ON (
ULC.intComp_AssocID = UA.intAssocID
            AND ULC.intRealmID = $Data->{'Realm'}
            AND intUmpireEntityID= intAllocatedEntityID
            AND intUmpireLevel = 3
        )
        INNER JOIN tblClub as C ON (C.intClubID = intUmpireEntityID)
        INNER JOIN tblMember_Associations as MA ON (
            MA.intMemberID = M.intMemberID
            AND MA.intAssocID = intUmpireAssocID
        )
        WHERE
            tblCompMatches.intRecStatus != -1
            AND Rounds.intRecStatus != -1
            AND intAllocatedLevel = 3
            AND UA.intCompID=tblCompMatches.intCompID
			AND UA.intSystemType=1
			$extra_where
			$where_list
	];
    return ($sql,'');
  }
}

1;
