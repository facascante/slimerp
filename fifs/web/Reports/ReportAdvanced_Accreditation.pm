#
# $Header: svn://svn/SWM/trunk/web/Reports/ReportAdvanced_Member.pm 8367 2013-04-24 00:01:54Z cgao $
#

package Reports::ReportAdvanced_Accreditation ;

use strict;
use lib ".";
use ReportAdvanced_Common;
use Reports::ReportAdvanced;
our @ISA =qw(Reports::ReportAdvanced);

use strict;

sub _getConfiguration {
	my $self = shift;

	my $currentLevel = $self->{'EntityTypeID'} || 0;
	my $Data = $self->{'Data'};
	my $clientValues = $Data->{'clientValues'};
  my $natnumname=$Data->{'SystemConfig'}{'NationalNumName'} || 'National Number';
  my $natteamname=$Data->{'SystemConfig'}{'NatTeamName'} || 'National Team';
	my $SystemConfig = $Data->{'SystemConfig'};

	my $CommonVals = getCommonValues(
		$Data,
		{
			SubRealms => 1,
			DefCodes => 1,
			Countries => 1,
			MemberPackages => 1,
			CustomFields => 1,
			Seasons => 1,
			FieldLabels => 1,
			AgeGroups => 1,
			EventLookups => 1,
			Grades => 1,
			EntityCategories => 1,
			RegoForms => 1,
            AccreName =>1,
		},
	);
	my $hideSeasons = $CommonVals->{'Seasons'}{'Hide'} || 0;

	my $FieldLabels = $CommonVals->{'FieldLabels'} || undef;
	my %NRO=();
	$NRO{'Accreditation'}= (
		($clientValues->{assocID} >0 
			or $clientValues->{clubID} > 0) 
		? 1 
		:0
		) 
		|| $SystemConfig->{'RepAccred'} || 0; #National Report Options 
	$NRO{'RepCompLevel'}= (
			($clientValues->{assocID} >0 
				or $clientValues->{clubID} > 0) ? 1 :0) 
			|| $SystemConfig->{'RepCompLevel'} || 0; #National Report Options

  my $umpire_dbfrom = qq[
			LEFT JOIN tblMember_Types AS tblMT_Ac_Umpire ON (
				tblMember.intMemberID=tblMT_Ac_Umpire.intMemberID 
				AND tblMT_Ac_Umpire.intTypeID=$Defs::MEMBER_TYPE_UMPIRE 
				AND tblMT_Ac_Umpire.intSubTypeID=1 
				AND tblMT_Ac_Umpire.intAssocID = tblMember_Associations.intAssocID 
				AND tblMT_Ac_Umpire.intRecStatus = $Defs::RECSTATUS_ACTIVE
			)
	];
  my $coach_dbfrom = qq[
		LEFT JOIN tblMember_Types AS tblMT_Ac_Coach ON (
			tblMember.intMemberID=tblMT_Ac_Coach.intMemberID 
			AND tblMT_Ac_Coach.intTypeID=$Defs::MEMBER_TYPE_COACH 
			AND tblMT_Ac_Coach.intSubTypeID=1 
			AND tblMT_Ac_Coach.intAssocID = tblMember_Associations.intAssocID 
			AND tblMT_Ac_Coach.intRecStatus = $Defs::RECSTATUS_ACTIVE
		)
	];

  my $txt_Clr = $Data->{'SystemConfig'}{'txtCLR'} || 'Clearance';
	my $showAgentFields = ($Data->{'SystemConfig'}{'clrHide_AgentFields'} == 1) ? '0' : '1';
	my $txt_Tribunal= $Data->{'SystemConfig'}{'txtTribunal'} || 'Tribunal';
  my $txt_SeasonName= $Data->{'SystemConfig'}{'txtSeason'} || 'Season';
  my $txt_SeasonNames= $Data->{'SystemConfig'}{'txtSeasons'} || 'Seasons';
  my $txt_AgeGroupName= $Data->{'SystemConfig'}{'txtAgeGroup'} || 'Age Group';
  my $txt_AgeGroupNames= $Data->{'SystemConfig'}{'txtAgeGroups'} || 'Age Groups';
  my $txt_MiscName = $Data->{'SystemConfig'}{'txtMiscName'} || 'Misc';
  my $txt_Transactions = $Data->{'SystemConfig'}{'txns_link_name'} || 'Transaction';
  my $officialName = $Data->{'SystemConfig'}{'TYPE_NAME_4'} || 'Official';

  my $MStablename = "tblMember_Seasons_$Data->{'Realm'}";
	my $RealmLPF_Ids = ($Data->{'SystemConfig'}{'LPF_ids'}) 
		? $Data->{'SystemConfig'}{'LPF_ids'} 
		: 0;
  my $txn_WHERE = '';
	if ($clientValues->{clubID} and $clientValues->{clubID} > 0)  {
		$txn_WHERE= qq[ AND TX.intTXNClubID IN (0, $clientValues->{clubID})];
	}

  my $player_comp_stats_table = "tblPlayerCompStats_" . $Data->{'Realm'};

	my %config = (
		Name => 'Detailed Member Report',

		StatsReport => 0,
		MemberTeam => 0,
		ReportEntity => 1,
		ReportLevel => 0,
		#Template => 'default_adv_CSV',
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
			MemberID=> [
				'Member ID',
				{
					displaytype=>'text',
					fieldtype=>'text',
					allowsort=>1,
					optiongroup=>'details',
					dbfield=>'tblMember.intMemberID'
				}
			],
			strMemberNo=> [
				$Data->{'SystemConfig'}{'FieldLabel_strMemberNo'} || 'Member No.',
				{
					displaytype=>'text',
					fieldtype=>'text',
					allowsort=>1,
					optiongroup=>'details'
				}
			],
			intRecStatus=> [
				'Active Record',
				{
					displaytype=>'lookup',
					fieldtype=>'dropdown',
					dropdownoptions=>{ 0=>'No', 1=>'Yes'},
					dropdownorder=>[0, 1],
					dbfield=>'tblMember_Associations.intRecStatus',
					defaultcomp=>'equal',
					defaultvalue=>'1',
					active=>1,
					optiongroup=>'details'
				}
			],
			intDefaulter=> [
				$Data->{'SystemConfig'}{'Defaulter'} 
					? $Data->{'SystemConfig'}{'Defaulter'} 
					: '',
				{
					displaytype=>'lookup',
					fieldtype=>'dropdown',
					dropdownoptions=>{ 0=>'No', 1=>'Yes'},
					dropdownorder=>[0, 1],
					dbfield=>'tblMember.intDefaulter',
					optiongroup=>'details'
				}
			],

			strSalutation=> [
				'Salutation',
				{
					displaytype=>'text',
					fieldtype=>'text',
					allowsort=>1,
					optiongroup=>'details',
					allowgrouping=>1
				}
			],

			strFirstname=> [
				'First Name',
				{
					displaytype=>'text',
					fieldtype=>'text',
					active=>1,
					allowsort=>1,
					optiongroup=>'details'
				}
			],
 
			strMiddlename=> [
				'Middle Name',
				{
					displaytype=>'text',
					fieldtype=>'text',
					allowsort=>1,
					optiongroup=>'details'
				}
			],
 
			strSurname=> [
				'Family Name',
				{
					displaytype=>'text',
					fieldtype=>'text',
					active =>1,
					allowsort=>1,
					optiongroup=>'details',
					allowgrouping=>1
				}
			],

			strMaidenName=> [
				'Maiden Name',
				{
					displaytype=>'text',
					fieldtype=>'text',
					allowsort=>1,
					optiongroup=>'details'
				}
			],
 
			strPreferredName=> [
				'Preferred Name',
				{
					displaytype=>'text',
					fieldtype=>'text',
					allowsort=>1,
					optiongroup=>'details'
				}
			],
  strCountryOfBirth=> [
                                'Country Of Birth',
                                {
                                        displaytype=>'lookup',
                                        fieldtype=>'dropdown',
                                        dropdownoptions=> $CommonVals->{'Countries'},
                                        allowsort=>1,
                                        optiongroup=>'details',
                                        dbfield=>'UCASE(strCountryOfBirth)',
                                        allowgrouping=>1
                                }
                        ],

			dtDOB => [
				'Date of Birth',
				{
					displaytype=>'date',
					fieldtype=>'date',
					allowsort=>1,
					dbfield=>'tblMember.dtDOB',
					dbformat=>' DATE_FORMAT(tblMember.dtDOB, "%d/%m/%Y")',
					optiongroup=>'details'
				}
			],
 
			dtYOB => [
				'Year of Birth',
				{
					displaytype=>'date',
					fieldtype=>'text',
					allowgrouping=>1,
					allowsort=>1,
					dbfield=>'YEAR(tblMember.dtDOB)',
					dbformat=>' YEAR(tblMember.dtDOB)',
					optiongroup=>'details'
				}
			],

			strPlaceofBirth => [
				'Place (Town) of Birth',
				{
					displaytype=>'text',
					fieldtype=>'text',
					allowsort=>0,
					optiongroup=>'details',
					allowgrouping=>1
				}
			],

			intGender => [
				'Gender',
				{
					displaytype=>'lookup',
					fieldtype=>'dropdown',
					dropdownoptions=>{ ''=>'&nbsp;', 1=>'Male', 2=>'Female'},
					dropdownorder=>['', 1, 2],
					size=>2,
					multiple=>1,
					optiongroup=>'details',
					allowgrouping=>1
				}
			],
 
			intDeceased => [
				'Deceased',
				{
					displaytype=>'lookup',
					fieldtype=>'dropdown',
					dropdownoptions=>{ 0=>'No', 1=>'Yes'},
					dropdownorder=>[0, 1],
					optiongroup=>'details',
					allowgrouping=>1,
					defaultcomp=>'equal',
					defaultvalue=>'0',
					active=>1,
				} 
			],

			strEyeColour => [
				'Eye Colour',
				{
					displaytype=>'lookup',
					fieldtype=>'dropdown',
					dropdownoptions=>$CommonVals->{'DefCodes'}{-11},
					optiongroup=>'details',
					allowgrouping=>1
				}
			],

			strHairColour => [
				'Hair Colour',
				{
					displaytype=>'lookup',
					fieldtype=>'dropdown',
					dropdownoptions=>$CommonVals->{'DefCodes'}{ -10},
					optiongroup=>'details',
					allowgrouping=>1
				}
			],

			intEthnicityID => [
				'Ethnicity',
				{
					displaytype=>'lookup',
					fieldtype=>'dropdown',
					dropdownoptions=>$CommonVals->{'DefCodes'}{-8},
					optiongroup=>'details',
					allowgrouping=>1
				}
			],

			strHeight => [
				'Height',
				{
					displaytype=>'text',
					fieldtype=>'text',
					allowsort=>0,
					optiongroup=>'details',
				}
			],

			strWeight => [
				'Weight',
				{
					displaytype=>'text',
					fieldtype=>'text',
					allowsort=>0,
					optiongroup=>'details'
				}
			],

			strAddress1 => [
				'Address 1',
				{
					displaytype=>'text',
					fieldtype=>'text',
					dbfield=>'tblMember.strAddress1',
					optiongroup=>'contactdetails'
				}
			],
 
			strAddress2 => [
				'Address 2',
				{
					displaytype=>'text',
					fieldtype=>'text',
					dbfield=>'tblMember.strAddress2',
					optiongroup=>'contactdetails'
				}
			],
 
			strSuburb => [
				'Suburb',
				{
					displaytype=>'text',
					fieldtype=>'text',
					dbfield=>'tblMember.strSuburb',
					allowsort=>1,
					optiongroup=>'contactdetails',
					allowgrouping=>1
				}
			],
 
			strCityOfResidence => [
				'City of Residence',
				{
					displaytype=>'text',
					fieldtype=>'text',
					allowsort=>1,
					optiongroup=>'contactdetails',
					allowgrouping=>1
				}
			],

			strState => [
				'State',
				{
					displaytype=>'text',
					fieldtype=>'text',
					dbfield=>'tblMember.strState',
					allowsort=>1,
					optiongroup=>'contactdetails',
					allowgrouping=>1
				}
			],
 
			strCountry => [
				'Country',
				{
					displaytype=>'text',
					fieldtype=>'text',
					dbfield=>'tblMember.strCountry',
					allowsort=>1,
					optiongroup=>'contactdetails',
					allowgrouping=>1
				}
			],
 
			strPostalCode => [
				'Postal Code',
				{
				displaytype=>'text',
				fieldtype=>'text',
				dbfield=>'tblMember.strPostalCode',
				allowsort=>1,
				optiongroup=>'contactdetails',
				allowgrouping=>1
				}
			],
 
			strPhoneHome => [
				'Home Phone',
				{
					displaytype=>'text',
					fieldtype=>'text',
					optiongroup=>'contactdetails'
				}
			],
 
			strPhoneWork => [
				'Work Phone',
				{
					displaytype=>'text',
					fieldtype=>'text',
					optiongroup=>'contactdetails'
				}
			],
 
			strPhoneMobile => [
				'Mobile Phone',
				{
					displaytype=>'text',
					fieldtype=>'text',
					optiongroup=>'contactdetails'
				}
			],
 
			strPager => [
				'Pager',
				{
					displaytype=>'text',
					fieldtype=>'text',
					optiongroup=>'contactdetails'
				}
			],

			strFax => [
				'Fax',
				{
					displaytype=>'text',
					fieldtype=>'text',
					dbfield=>'tblMember.strFax',
					optiongroup=>'contactdetails'
				}
			],

			strEmail => [
				'Email',
				{
					displaytype=>'text',
					fieldtype=>'text',
					dbfield=>'tblMember.strEmail',
					optiongroup=>'contactdetails'
				}
			],

			strEmail2 => [
				'Email 2',
				{
					displaytype=>'text',
					fieldtype=>'text',
					dbfield=>'tblMember.strEmail2',
					optiongroup=>'contactdetails'
				}
			],
 
			strEmergContName => [
				'Emergency Contact Name',
				{
					displaytype=>'text',
					fieldtype=>'text',
					allowsort=>0,
					optiongroup=>'contactdetails'
				}
			],

			strEmergContRel => [
				'Emergency Contact Relationship',
				{
					displaytype=>'text',
					fieldtype=>'text',
					allowsort=>0,
					optiongroup=>'contactdetails'
				}
			],

			strEmergContNo => [
				'Emergency Contact No',
				{
					displaytype=>'text',
					fieldtype=>'text',
					allowsort=>0,
					optiongroup=>'contactdetails',
				}
			],

			strEmergContNo2 => [
				'Emergency Contact No 2',
				{
					displaytype=>'text',
					fieldtype=>'text',
					allowsort=>0,
					optiongroup=>'contactdetails',
				}
			],



#Player Stuff
#        intPlayerActive => [
#'Player Active ?',
#{
#displaytype=>'lookup',
# fieldtype=>'dropdown',
# dropdownoptions=>{ 0=>'No', 1=>'Yes'},
# dropdownorder=>[0, 1],
# dbfield=>'tblMT_Player.intActive',
# optiongroup=>'mt_player'
#}
#],
 
        dtLastRecordedGame => [
"Last Recorded $Data->{'LevelNames'}{$Defs::LEVEL_ASSOC} Game",
{
displaytype=>'date',
 fieldtype=>'date',
 dbfield=>'tblMT_Player.dtDate1',
 dbformat=>' DATE_FORMAT(tblMT_Player.dtDate1, "%d/%m/%Y")',
 optiongroup=>'mt_player'
}
],
 
				intCareerGames => [
"$Data->{'LevelNames'}{$Defs::LEVEL_ASSOC} Career Games",
{
displaytype=>'text',
 fieldtype=>'text',
 dbfield=>'tblMT_Player.intInt1',
 optiongroup=>'mt_player'
}
],
 
        intPlayerJunior => [
'Junior ?',
{
displaytype=>'lookup',
 fieldtype=>'dropdown',
 dropdownoptions=>{ 0=>'No', 1=>'Yes'},
 dropdownorder=>[0, 1],
 dbfield=>'tblMT_Player.intInt2',
 optiongroup=>'mt_player'
}
],
 
        intPlayerSenior => [
'Senior ?',
{
displaytype=>'lookup',
 fieldtype=>'dropdown',
 dropdownoptions=>{ 0=>'No', 1=>'Yes'},
 dropdownorder=>[0, 1],
 dbfield=>'tblMT_Player.intInt3',
 optiongroup=>'mt_player'
}
],
 
        intPlayerVeteran => [
'Veteran ?',
{
displaytype=>'lookup',
 fieldtype=>'dropdown',
 dropdownoptions=>{ 0=>'No', 1=>'Yes'},
 dropdownorder=>[0, 1],
 dbfield=>'tblMT_Player.intInt4',
 optiongroup=>'mt_player'
}
],
 
#Interests
            intPlayer => [
                'Player',
                {
                    displaytype=>'lookup',
                    fieldtype=>'dropdown',
                    dropdownoptions=>{ 0=>'No', 1=>'Yes'},
                    dropdownorder=>[0, 1],
                    optiongroup=>'interests',
                    allowgrouping=>1
                }
            ],

            intCoach => [
                'Coach',
                {
                    displaytype=>'lookup',
                    fieldtype=>'dropdown',
                    dropdownoptions=>{ 0=>'No', 1=>'Yes'},
                    dropdownorder=>[0, 1],
                    optiongroup=>'interests',
                    allowgrouping=>1
                }
            ],

            intUmpire => [
                'Match Official',
                {
                    displaytype=>'lookup',
                    fieldtype=>'dropdown',
                    dropdownoptions=>{ 0=>'No', 1=>'Yes'},
                    dropdownorder=>[0, 1],
                    optiongroup=>'interests',
                    allowgrouping=>1
                }
            ],
intOfficial => [
                'Official',
                {
                    displaytype=>'lookup',
                    fieldtype=>'dropdown',
                    dropdownoptions=>{ 0=>'No', 1=>'Yes'},
                    dropdownorder=>[0, 1],
                    optiongroup=>'interests',
                    allowgrouping=>1
                }
            ],

            intMisc => [
                'Misc',
                {
                    displaytype=>'lookup',
                    fieldtype=>'dropdown',
                    dropdownoptions=>{ 0=>'No', 1=>'Yes'},
                    dropdownorder=>[0, 1],
                    optiongroup=>'interests',
                    allowgrouping=>1
                }
            ],

            intVolunteer => [
                'Volunteer',
                {
                    displaytype=>'lookup',
                    fieldtype=>'dropdown',
                    dropdownoptions=>{ 0=>'No', 1=>'Yes'},
                    dropdownorder=>[0, 1],
                    optiongroup=>'interests',
                    allowgrouping=>1
                }
            ],
#affiliation
 strAssocName =>
                         [
                          ($self->{'EntityTypeID'}<=$Defs::LEVEL_ASSOC  ? '' : $Data->{'LevelNames'}{$Defs::LEVEL_ASSOC}.' Name'),
                          {
                           displaytype=>'text',
                           fieldtype=>'text',
                           allowsort=>1,
                           dbfield=>'tblAssoc.strName',
                           optiongroup=>'affiliations',
                           allowgrouping=>1,
                           dbwhere=> " AND $MStablename.intAssocID = tblAssoc.intAssocID"
                       }],

 intAssocTypeID=>[
                #(($CommonVals->{'SubRealms'} and  $currentLevel > $Defs::LEVEL_ASSOC)? ($Data->{'LevelNames'}{$Defs::LEVEL_ASSOC}.' Type') : ''),
                $Data->{'LevelNames'}{$Defs::LEVEL_ASSOC}.' Type' ,
                {
                    displaytype=>'lookup', 
                    fieldtype=>'dropdown', 
                    dropdownoptions=> $CommonVals->{'SubRealms'}, 
                    allowsort=>1, 
                    optiongroup=>'affiliations', 
                    allowgrouping=>1}
                ],
intAssocCategoryID=>[ 
            scalar(keys %{$CommonVals->{'EntityCategories'}{$Defs::LEVEL_ASSOC}}) ? "$Data->{'LevelNames'}{$Defs::LEVEL_ASSOC} Category" : '', 
                { 
                displaytype=>'lookup', 
                fieldtype=>'dropdown', 
                dropdownoptions=> $CommonVals->{'EntityCategories'}{$Defs::LEVEL_ASSOC}, 
                dbfield=>'tblAssoc.intAssocCategoryID', 
                allowgrouping=>1,
                optiongroup=>'affiliations' 
                } 
              ],
strTeamName => [
              $SystemConfig->{'NoTeams'} ? '' :$Data->{'LevelNames'}{$Defs::LEVEL_TEAM}.' Name' ,
               {
                displaytype=>'text',
                fieldtype=>'text',
                allowsort=>1,
                dbfield=>"tblTeam.strName",
                dbfrom=>[($currentLevel >= $Defs::LEVEL_CLUB?"LEFT JOIN tblMember_Teams ON (tblMember.intMemberID=tblMember_Teams.intMemberID AND tblMember_Teams.intStatus = $Defs::RECSTATUS_ACTIVE) LEFT JOIN tblTeam ON (tblTeam.intTeamID=tblMember_Teams.intTeamID AND tblTeam.intAssocID=tblAssoc.intAssocID)":''),'LEFT JOIN tblComp_Teams ON (tblComp_Teams.intTeamID=tblTeam.intTeamID AND tblComp_Teams.intRecStatus = 1) LEFT JOIN tblAssoc_Comp ON (tblAssoc_Comp.intCompID=tblComp_Teams.intCompID AND tblAssoc_Comp.intAssocID=tblAssoc.intAssocID AND tblMember_Teams.intCompID=tblAssoc_Comp.intCompID)'],
                 optiongroup=>'affiliations',
                 allowgrouping=>1
                 }
             ],
 strClubName => [
            (((!$SystemConfig->{'NoClubs'} or $Data->{'Permissions'}{$Defs::CONFIG_OTHEROPTIONS}{'ShowClubs'}) and $currentLevel > $Defs::LEVEL_CLUB )? $Data->{'LevelNames'}{$Defs::LEVEL_CLUB}.' Name' :''),
             {
                displaytype=>'text',
                fieldtype=>'text',
                allowsort=>1,
                dbfield=>"C.strName",
                dbfrom=>"LEFT JOIN tblMember_Clubs as MC ON (tblMember.intMemberID=MC.intMemberID  AND MC.intStatus=$Defs::RECSTATUS_ACTIVE) LEFT JOIN tblClub as C ON (C.intClubID=MC.intClubID ) LEFT JOIN tblAssoc_Clubs as AC ON (AC.intAssocID=tblAssoc.intAssocID AND AC.intClubID=C.intClubID)",
                optiongroup=>'affiliations',
                allowgrouping=>1,
                dbwhere=>" AND (AC.intAssocID = tblAssoc.intAssocID OR MC.intMemberID IS NULL) AND (($MStablename.intClubID=C.intClubID AND $MStablename.intMSRecStatus = 1) or MC.intMemberID IS NULL)"
                }
             ],
intClubCategoryID=> [
                (((!$SystemConfig->{'NoClubs'} or $Data->{'Permissions'}{$Defs::CONFIG_OTHEROPTIONS}{'ShowClubs'}) and $currentLevel > $Defs::LEVEL_CLUB and scalar(keys %{$CommonVals->{'EntityCategories'}{$Defs::LEVEL_CLUB}}) )? $Data->{'LevelNames'}{$Defs::LEVEL_CLUB}.' Category' :''),
                {
                displaytype=>'lookup',
                fieldtype=>'dropdown',
                dropdownoptions=> $CommonVals->{'EntityCategories'}{$Defs::LEVEL_CLUB},
                allowsort=>1,
                dbfield=>"C.intClubCategoryID",
                dbfrom=>"LEFT JOIN tblMember_Clubs as MC ON (tblMember.intMemberID=MC.intMemberID  AND MC.intStatus=$Defs::RECSTATUS_ACTIVE) LEFT JOIN tblClub as C ON (C.intClubID=MC.intClubID ) LEFT JOIN tblAssoc_Clubs as AC ON (AC.intAssocID=tblAssoc.intAssocID AND AC.intClubID=C.intClubID)",
                optiongroup=>'affiliations',
                allowgrouping=>1,
                dbwhere=>" AND (AC.intAssocID = tblAssoc.intAssocID OR MC.intMemberID IS NULL) AND (($MStablename.intClubID=C.intClubID AND $MStablename.intMSRecStatus = 1) or MC.intMemberID IS NULL)"
                 }
               ],
intPermit => [
             ((!$SystemConfig->{'NoClubs'} and $currentLevel >= $Defs::LEVEL_CLUB and $Data->{SystemConfig}->{AllowSWOL})? ('On Permit to '.$Data->{'LevelNames'}{$Defs::LEVEL_CLUB}) :''),
           {
                displaytype=>'lookup',
                fieldtype=>'dropdown',
                dropdownoptions=>{0=>'No', 1=>'Yes'},
                dropdownorder=>[0,1],
                allowsort=>1,
                dbfield=>"MC.intPermit",
                dbfrom=>"LEFT JOIN tblMember_Clubs as MC ON (tblMember.intMemberID=MC.intMemberID  AND MC.intStatus=$Defs::RECSTATUS_ACTIVE) LEFT JOIN tblClub as C ON (C.intClubID=MC.intClubID ) LEFT JOIN tblAssoc_Clubs as AC ON (AC.intAssocID=tblAssoc.intAssocID AND AC.intClubID=C.intClubID)",
                optiongroup=>'affiliations',
                allowgrouping=>1
                       }
                ],
LastPlayedDate => [
            ($Data->{SystemConfig}->{AllowSWOL} ? 'Date Last Played' : ''),
            {
                displaytype=>'text',
                dbfield=>"$player_comp_stats_table.dtStatTotal2",
                dbformat=>qq[DATE_FORMAT($player_comp_stats_table.dtStatTotal2,"%d/%m/%Y")] ,
                dbfrom => [($currentLevel >= $Defs::LEVEL_CLUB?"LEFT JOIN tblMember_Teams ON (tblMember.intMemberID=tblMember_Teams.intMemberID AND tblMember_Teams.intStatus = $Defs::RECSTATUS_ACTIVE) LEFT JOIN tblTeam ON (tblTeam.intTeamID=tblMember_Teams.intTeamID AND tblTeam.intAssocID=tblAssoc.intAssocID)":''), "INNER JOIN $player_comp_stats_table ON ($player_comp_stats_table.intPlayerID = tblMember_Teams.intMemberID AND $player_comp_stats_table.intCompID = tblMember_Teams.intCompID AND $player_comp_stats_table.intTeamID  = tblMember_Teams.intTeamID) INNER JOIN tblComp_Teams AS LadderCompTeams ON (LadderCompTeams.intTeamID = $player_comp_stats_table.intTeamID AND LadderCompTeams.intCompID = $player_comp_stats_table.intCompID AND LadderCompTeams.intRecStatus <> $Defs::RECSTATUS_DELETED) INNER JOIN tblAssoc_Comp AS LadderAssocComp ON (LadderAssocComp.intCompID=$player_comp_stats_table.intCompID AND LadderAssocComp.intAssocID=tblAssoc.intAssocID)"],
                fieldtype=>'date',
                allowsort => 1,
                optiongroup => 'affiliations'
                 }
              ],
MCStatus=> [
            ((!$SystemConfig->{'NoClubs'} and $currentLevel <= $Defs::LEVEL_CLUB )? ($Data->{'LevelNames'}{$Defs::LEVEL_CLUB} .' Status') :''),
            {
                displaytype=>'lookup', 
                fieldtype=>'dropdown', 
                dropdownoptions=>{0=>'No', 1=>'Yes'}, 
                dropdownorder=>[0,1], 
                allowsort=>1, 
                dbfield=>"tblMember_Clubs.intStatus", 
                optiongroup=>'affiliations', 
                allowgrouping=>1
              }
        ],
strCompName => [
        (!$SystemConfig->{'NoComps'} ? $Data->{'LevelNames'}{$Defs::LEVEL_COMP}.' Name' : ''),
        {
                displaytype=>'text', 
                fieldtype=>'text', 
                allowsort=>1, 
                dbfield=>"tblAssoc_Comp.strTitle", 
                dbfrom=>[($currentLevel >= $Defs::LEVEL_CLUB ? "LEFT JOIN tblMember_Teams ON (tblMember.intMemberID=tblMember_Teams.intMemberID AND tblMember_Teams.intStatus = $Defs::RECSTATUS_ACTIVE) LEFT JOIN tblTeam ON (tblTeam.intTeamID=tblMember_Teams.intTeamID AND tblTeam.intAssocID=tblAssoc.intAssocID)":''), 'LEFT JOIN tblComp_Teams ON (tblComp_Teams.intTeamID=tblTeam.intTeamID AND tblComp_Teams.intRecStatus = 1) LEFT JOIN tblAssoc_Comp ON (tblAssoc_Comp.intCompID=tblComp_Teams.intCompID AND tblAssoc_Comp.intAssocID=tblAssoc.intAssocID AND tblMember_Teams.intCompID=tblAssoc_Comp.intCompID)'], 
                optiongroup=>'affiliations', 
                allowgrouping=>1
            }
        ],
intCompLevelID=> [
            ((!$SystemConfig->{'NoComps'} and $NRO{'RepCompLevel'} )? 'Competition Level': ''),
        {
                displaytype=>'lookup', 
                fieldtype=>'dropdown', 
                dropdownoptions=>$CommonVals->{'DefCodes'}{-21}, 
                dbfield=>'tblAssoc_Comp.intCompLevelID', 
                dbfrom=>[($currentLevel >= $Defs::LEVEL_CLUB ? "LEFT JOIN tblMember_Teams ON (tblMember.intMemberID=tblMember_Teams.intMemberID AND tblMember_Teams.intStatus = $Defs::RECSTATUS_ACTIVE) LEFT JOIN tblTeam ON (tblTeam.intTeamID=tblMember_Teams.intTeamID AND tblTeam.intAssocID=tblAssoc.intAssocID)":''),'LEFT JOIN tblComp_Teams ON (tblComp_Teams.intTeamID=tblTeam.intTeamID AND tblComp_Teams.intRecStatus = 1) LEFT JOIN tblAssoc_Comp ON (tblAssoc_Comp.intCompID=tblComp_Teams.intCompID AND tblAssoc_Comp.intAssocID=tblAssoc.intAssocID AND tblMember_Teams.intCompID=tblAssoc_Comp.intCompID)'], 
                optiongroup=>'affiliations', 
                allowgrouping=>1
        }],
CompAgeGroupID=> [
            ((!$SystemConfig->{'NoComps'})? "$Data->{'LevelNames'}{$Defs::LEVEL_COMP} Default $txt_AgeGroupName": ''),{displaytype=>'lookup', fieldtype=>'dropdown', dropdownoptions => $CommonVals->{'AgeGroups'}{'Options'},  dropdownorder=>$CommonVals->{'AgeGroups'}{'Order'}, dbfield=>'tblAssoc_Comp.intAgeGroupID', dbfrom=>[($currentLevel >= $Defs::LEVEL_CLUB ? "LEFT JOIN tblMember_Teams ON (tblMember.intMemberID=tblMember_Teams.intMemberID AND tblMember_Teams.intStatus = $Defs::RECSTATUS_ACTIVE) LEFT JOIN tblTeam ON (tblTeam.intTeamID=tblMember_Teams.intTeamID AND tblTeam.intAssocID=tblAssoc.intAssocID)":''),'LEFT JOIN tblComp_Teams ON (tblComp_Teams.intTeamID=tblTeam.intTeamID AND tblComp_Teams.intRecStatus = 1) LEFT JOIN tblAssoc_Comp ON (tblAssoc_Comp.intCompID=tblComp_Teams.intCompID AND tblAssoc_Comp.intAssocID=tblAssoc.intAssocID AND tblMember_Teams.intCompID=tblAssoc_Comp.intCompID)'], optiongroup=>'affiliations', allowgrouping=>1}],
intNewSeasonID=> [
            (!$SystemConfig->{'NoComps'} ? "$Data->{'LevelNames'}{$Defs::LEVEL_COMP} $txt_SeasonName": ''),{displaytype=>'lookup', fieldtype=>'dropdown', dropdownoptions=>$CommonVals->{'Seasons'}{'Options'},  dropdownorder=>$CommonVals->{'Seasons'}{'Order'}, dbfield=>'tblAssoc_Comp.intNewSeasonID', dbfrom=>[($currentLevel >= $Defs::LEVEL_CLUB ? "LEFT JOIN tblMember_Teams ON (tblMember.intMemberID=tblMember_Teams.intMemberID AND tblMember_Teams.intStatus = $Defs::RECSTATUS_ACTIVE) LEFT JOIN tblTeam ON (tblTeam.intTeamID=tblMember_Teams.intTeamID AND tblTeam.intAssocID=tblAssoc.intAssocID)":''),'LEFT JOIN tblComp_Teams ON (tblComp_Teams.intTeamID=tblTeam.intTeamID AND tblComp_Teams.intRecStatus = 1) LEFT JOIN tblAssoc_Comp ON (tblAssoc_Comp.intCompID=tblComp_Teams.intCompID AND tblAssoc_Comp.intAssocID=tblAssoc.intAssocID AND tblMember_Teams.intCompID=tblAssoc_Comp.intCompID)'], optiongroup=>'affiliations', allowgrouping=>1, disable=>$hideSeasons}],

intCompTypeID=> [
            ((!$SystemConfig->{'NoComps'})? 'Competition Type': ''),{displaytype=>'lookup', fieldtype=>'dropdown', dropdownoptions=>$CommonVals->{'DefCodes'}{-36}, dbfield=>'tblAssoc_Comp.intCompTypeID', dbfrom=>[($currentLevel >= $Defs::LEVEL_CLUB ? "LEFT JOIN tblMember_Teams ON (tblMember.intMemberID=tblMember_Teams.intMemberID AND tblMember_Teams.intStatus = $Defs::RECSTATUS_ACTIVE) LEFT JOIN tblTeam ON (tblTeam.intTeamID=tblMember_Teams.intTeamID AND tblTeam.intAssocID=tblAssoc.intAssocID)":''),'LEFT JOIN tblComp_Teams ON (tblComp_Teams.intTeamID=tblTeam.intTeamID AND tblComp_Teams.intRecStatus = 1) LEFT JOIN tblAssoc_Comp ON (tblAssoc_Comp.intCompID=tblComp_Teams.intCompID AND tblAssoc_Comp.intAssocID=tblAssoc.intAssocID AND tblMember_Teams.intCompID=tblAssoc_Comp.intCompID)'], optiongroup=>'affiliations', allowgrouping=>1}],

CompGradeID=> [
            ((!$SystemConfig->{'NoComps'})? 'Competition Grade': ''),{displaytype=>'lookup', fieldtype=>'dropdown', dbfield=>'tblAssoc_Comp.intGradeID', dropdownoptions=>$CommonVals->{'Grades'}, dbfield=>'tblAssoc_Comp.intCompGradeID', dbfrom=>[($currentLevel >= $Defs::LEVEL_CLUB ? "LEFT JOIN tblMember_Teams ON (tblMember.intMemberID=tblMember_Teams.intMemberID AND tblMember_Teams.intStatus = $Defs::RECSTATUS_ACTIVE) LEFT JOIN tblTeam ON (tblTeam.intTeamID=tblMember_Teams.intTeamID AND tblTeam.intAssocID=tblAssoc.intAssocID)":''),'LEFT JOIN tblComp_Teams ON (tblComp_Teams.intTeamID=tblTeam.intTeamID AND tblComp_Teams.intRecStatus = 1) LEFT JOIN tblAssoc_Comp ON (tblAssoc_Comp.intCompID=tblComp_Teams.intCompID AND tblAssoc_Comp.intAssocID=tblAssoc.intAssocID AND tblMember_Teams.intCompID=tblAssoc_Comp.intCompID)'], optiongroup=>'affiliations', allowgrouping=>1}],
intCompGender=> [
            ((!$SystemConfig->{'NoComps'})? 'Competition Gender': ''),{displaytype=>'lookup', fieldtype=>'dropdown', dropdownoptions=>\%Defs::genderInfo, dbfield=>'tblAssoc_Comp.intCompGender', dbfrom=>[($currentLevel >= $Defs::LEVEL_CLUB ? "LEFT JOIN tblMember_Teams ON (tblMember.intMemberID=tblMember_Teams.intMemberID AND tblMember_Teams.intStatus = $Defs::RECSTATUS_ACTIVE) LEFT JOIN tblTeam ON (tblTeam.intTeamID=tblMember_Teams.intTeamID AND tblTeam.intAssocID=tblAssoc.intAssocID)":''),'LEFT JOIN tblComp_Teams ON (tblComp_Teams.intTeamID=tblTeam.intTeamID AND tblComp_Teams.intRecStatus = 1) LEFT JOIN tblAssoc_Comp ON (tblAssoc_Comp.intCompID=tblComp_Teams.intCompID AND tblAssoc_Comp.intAssocID=tblAssoc.intAssocID AND tblMember_Teams.intCompID=tblAssoc_Comp.intCompID)'], optiongroup=>'affiliations', allowgrouping=>1}],

strAgeLevel=> [
            ((!$SystemConfig->{'NoComps'})? 'Competition Age Level': ''),{displaytype=>'lookup', fieldtype=>'dropdown', dropdownoptions=>\%Defs::CompAgeLevel, dbfield=>'tblAssoc_Comp.strAgeLevel', dbfrom=>[($currentLevel >= $Defs::LEVEL_CLUB ? "LEFT JOIN tblMember_Teams ON (tblMember.intMemberID=tblMember_Teams.intMemberID AND tblMember_Teams.intStatus = $Defs::RECSTATUS_ACTIVE) LEFT JOIN tblTeam ON (tblTeam.intTeamID=tblMember_Teams.intTeamID AND tblTeam.intAssocID=tblAssoc.intAssocID)":''),'LEFT JOIN tblComp_Teams ON (tblComp_Teams.intTeamID=tblTeam.intTeamID AND tblComp_Teams.intRecStatus = 1) LEFT JOIN tblAssoc_Comp ON (tblAssoc_Comp.intCompID=tblComp_Teams.intCompID AND tblAssoc_Comp.intAssocID=tblAssoc.intAssocID AND tblMember_Teams.intCompID=tblAssoc_Comp.intCompID)'], optiongroup=>'affiliations', allowgrouping=>1}],

CompRecStatus=> [
            (!$SystemConfig->{'NoComps'} ? 'Competition Active': ''),{displaytype=>'lookup', fieldtype=>'dropdown', dropdownoptions=>{0=>'No', 1=>'Yes'}, dropdownorder=>[0,1], dbfield=>'tblAssoc_Comp.intRecStatus', optiongroup=>'affiliations',  dbfrom=>[($currentLevel >= $Defs::LEVEL_CLUB ? "LEFT JOIN tblMember_Teams ON (tblMember.intMemberID=tblMember_Teams.intMemberID AND tblMember_Teams.intStatus = $Defs::RECSTATUS_ACTIVE) LEFT JOIN tblTeam ON (tblTeam.intTeamID=tblMember_Teams.intTeamID AND tblTeam.intAssocID=tblAssoc.intAssocID)":''),'LEFT JOIN tblComp_Teams ON (tblComp_Teams.intTeamID=tblTeam.intTeamID AND tblComp_Teams.intRecStatus = 1) LEFT JOIN tblAssoc_Comp ON (tblAssoc_Comp.intCompID=tblComp_Teams.intCompID AND tblAssoc_Comp.intAssocID=tblAssoc.intAssocID AND tblMember_Teams.intCompID=tblAssoc_Comp.intCompID)']}],

strZoneName=> [
            ($currentLevel > $Defs::LEVEL_ZONE ? $Data->{'LevelNames'}{$Defs::LEVEL_ZONE}.' Name' : ''),{displaytype=>'text', fieldtype=>'text', allowsort=>1, dbfield => "IF(tblZone.intStatusID = $Defs::NODE_SHOW, tblZone.strName,'')", allowgrouping=>1, optiongroup=>'affiliations'}],
strRegionName=> [
            ($currentLevel > $Defs::LEVEL_REGION ? $Data->{'LevelNames'}{$Defs::LEVEL_REGION}.' Name' : ''),{displaytype=>'text', fieldtype=>'text', allowsort=>1, dbfield => "IF(tblRegion.intStatusID = $Defs::NODE_SHOW, tblRegion.strName,'')", allowgrouping=>1, optiongroup=>'affiliations'}],

strStateName=> [
            ($currentLevel > $Defs::LEVEL_STATE ? $Data->{'LevelNames'}{$Defs::LEVEL_STATE}.' Name' : ''),{displaytype=>'text', fieldtype=>'text', allowsort=>1, dbfield => "IF(tblState.intStatusID = $Defs::NODE_SHOW, tblState.strName,'')", allowgrouping=>1, optiongroup=>'affiliations'}],
strNationalName=> [
            ($currentLevel > $Defs::LEVEL_NATIONAL ? $Data->{'LevelNames'}{$Defs::LEVEL_NATIONAL}.' Name' : ''),{displaytype=>'text', fieldtype=>'text', allowsort=>1, dbfield => "IF(tblNational.intStatusID = $Defs::NODE_SHOW, tblNational.strName,'')", allowgrouping=>1, optiongroup=>'affiliations'}],

strIntZoneName=> [
            ($currentLevel > $Defs::LEVEL_INTZONE ? $Data->{'LevelNames'}{$Defs::LEVEL_INTZONE}.' Name' : ''),
            {
                displaytype=>'text', 
                fieldtype=>'text', 
                allowsort=>1, 
                dbfield => "IF(tblIntZone.intStatusID = $Defs::NODE_SHOW, tblIntZone.strName,'')" , 
                allowgrouping=>1, 
                optiongroup=>'affiliations'
            }
            ],
strIntRegionName=> [
            ($currentLevel > $Defs::LEVEL_INTREGION ? $Data->{'LevelNames'}{$Defs::LEVEL_INTREGION}.' Name' : ''),{displaytype=>'text', fieldtype=>'text', allowsort=>1, dbfield => " IF(tblIntRegion.intStatusID = $Defs::NODE_SHOW, tblIntRegion.strName,'') ", allowgrouping=>1, optiongroup=>'affiliations'}],

#Seasons
intSeasonID=> [
    "$txt_SeasonName",
    {
        displaytype=>'lookup', 
        fieldtype=>'dropdown', 
        dropdownoptions => $CommonVals->{'Seasons'}{'Options'},  
        dropdownorder=>$CommonVals->{'Seasons'}{'Order'}, 
        allowsort=>1,
        optiongroup => 'seasons',
        active=>0, multiple=>1, 
        size=>3, 
        dbfield=>"$MStablename.intSeasonID", 
        disable=>$hideSeasons 
    }
],
intSeasonMemberPackageID => ["$txt_SeasonName Member Package",{displaytype=>'lookup', fieldtype=>'dropdown', dropdownoptions=>$CommonVals->{'MemberPackages'}, optiongroup=>'seasons', allowgrouping=>1, multiple=>1, disable=>$hideSeasons} ],
                intPlayerAgeGroupID=> ["$txt_AgeGroupName",{displaytype=>'lookup', fieldtype=>'dropdown', dropdownoptions => $CommonVals->{'AgeGroups'}{'Options'},  dropdownorder=>$CommonVals->{'AgeGroups'}{'Order'}, allowsort=>1, allowgrouping=>1, optiongroup => 'seasons', multiple=>1, size=>3, dbfield=>"$MStablename.intPlayerAgeGroupID", disable=>$hideSeasons }],
                    intPlayerStatus=> ["$txt_SeasonName Player ?",{displaytype=>'lookup', fieldtype=>'dropdown', dropdownoptions=>{0=>'No', 1=>'Yes'}, dropdownorder=>[0,1], optiongroup=>'seasons', allowgrouping=>1, disable=>$hideSeasons }],
                    intCoachStatus=> ["$txt_SeasonName Coach",{displaytype=>'lookup', fieldtype=>'dropdown', dropdownoptions=>{0=>'No', 1=>'Yes'}, dropdownorder=>[0,1], optiongroup=>'seasons', allowgrouping=>1, disable=>$hideSeasons } ],
                    intUmpireStatus=> ["$txt_SeasonName Match Official",{displaytype=>'lookup', fieldtype=>'dropdown', dropdownoptions=>{0=>'No', 1=>'Yes'}, dropdownorder=>[0,1], optiongroup=>'seasons', allowgrouping=>1, disable=>$hideSeasons } ],
                    intOther1Status=> [$Data->{'SystemConfig'}{'Seasons_Other1'} ? "$txt_SeasonName $Data->{'SystemConfig'}{'Seasons_Other1'} ?" : '',{displaytype=>'lookup', fieldtype=>'dropdown', dropdownoptions=>{0=>'No', 1=>'Yes'}, dropdownorder=>[0,1], optiongroup=>'seasons', allowgrouping=>1, disable=>$hideSeasons }],
                    intOther2Status=> [$Data->{'SystemConfig'}{'Seasons_Other2'} ? "$txt_SeasonName $Data->{'SystemConfig'}{'Seasons_Other2'} ?" : '',{displaytype=>'lookup', fieldtype=>'dropdown', dropdownoptions=>{0=>'No', 1=>'Yes'}, dropdownorder=>[0,1], optiongroup=>'seasons', allowgrouping=>1, disable=>$hideSeasons }],
                    intPlayerFinancialStatus=> ["$txt_SeasonName Player Financial ?",{displaytype=>'lookup', fieldtype=>'dropdown', dropdownoptions=>{0=>'No', 1=>'Yes'}, dropdownorder=>[0,1], optiongroup=>'seasons', allowgrouping=>1, disable=>$hideSeasons }],
                    intCoachFinancialStatus=> ["$txt_SeasonName Coach Financial ?",{displaytype=>'lookup', fieldtype=>'dropdown', dropdownoptions=>{0=>'No', 1=>'Yes'}, dropdownorder=>[0,1], optiongroup=>'seasons', allowgrouping=>1, disable=>$hideSeasons } ],
                    intUmpireFinancialStatus=> ["$txt_SeasonName Match Official Financial ?",{displaytype=>'lookup', fieldtype=>'dropdown', dropdownoptions=>{0=>'No', 1=>'Yes'}, dropdownorder=>[0,1], optiongroup=>'seasons', allowgrouping=>1, disable=>$hideSeasons } ],
                    intOther1FinancialStatus=> [$Data->{'SystemConfig'}{'Seasons_Other1'} ? "$txt_SeasonName $Data->{'SystemConfig'}{'Seasons_Other1'} Financial ?" : '',{displaytype=>'lookup', fieldtype=>'dropdown', dropdownoptions=>{0=>'No', 1=>'Yes'}, dropdownorder=>[0,1], optiongroup=>'seasons', allowgrouping=>1, disable=>$hideSeasons }],
                    intOther2FinancialStatus=> [$Data->{'SystemConfig'}{'Seasons_Other2'} ? "$txt_SeasonName $Data->{'SystemConfig'}{'Seasons_Other2'} Financial ?" : '',{displaytype=>'lookup', fieldtype=>'dropdown', dropdownoptions=>{0=>'No', 1=>'Yes'}, dropdownorder=>[0,1], optiongroup=>'seasons', allowgrouping=>1, disable=>$hideSeasons }],
                    dtInPlayer=> ["Date Player created in $txt_SeasonName",{displaytype=>'date', fieldtype=>'date', optiongroup=>'seasons', dbformat=>'DATE_FORMAT(dtInPlayer,"%d/%m/%Y")', dbfield=>'dtInPlayer', disable=>$hideSeasons}],
                    dtInCoach=> ["Date Coach created in $txt_SeasonName",{displaytype=>'date', fieldtype=>'date', optiongroup=>'seasons', dbformat=>'DATE_FORMAT(dtInCoach,"%d/%m/%Y")', dbfield=>'dtInCoach', disable=>$hideSeasons}],
                    dtInUmpire=> ["Date Umpire created in $txt_SeasonName",{displaytype=>'date', fieldtype=>'date', optiongroup=>'seasons', dbformat=>'DATE_FORMAT(dtInUmpire,"%d/%m/%Y")', dbfield=>'dtInUmpire', disable=>$hideSeasons}],
                    dtLastUsedRegoForm=> ["Date RegoForm last used in $txt_SeasonName",{displaytype=>'date', fieldtype=>'date', optiongroup=>'seasons', dbformat=>'DATE_FORMAT(dtInUmpire,"%d/%m/%Y")', dbfield=>"$MStablename.dtLastUsedRegoForm", disable=>$hideSeasons}],
                    intUsedRegoFormID=> ["RegoForm used in $txt_SeasonName",{displaytype=>'lookup', fieldtype=>'dropdown', dropdownoptions => $CommonVals->{'RegoForms'}{'Options'}, dropdownorder => $CommonVals->{'RegoForms'}{'Order'}, allowsort=>1, multiple=>1, allowgrouping=>1, optiongroup=>'seasons', dbfield=>"$MStablename.intUsedRegoFormID", disable=>$hideSeasons } ],
                    dtInOther1=> [$Data->{'SystemConfig'}{'Seasons_Other1'} ? "Date $Data->{'SystemConfig'}{'Seasons_Other1'} created in $txt_SeasonName" : '',{displaytype=>'date', fieldtype=>'date', optiongroup=>'seasons', dbformat=>'DATE_FORMAT(dtInOther1,"%d/%m/%Y")', dbfield=>'dtInOther1', disable=>$hideSeasons}],
                    dtInOther2=> [$Data->{'SystemConfig'}{'Seasons_Other2'} ? "Date $Data->{'SystemConfig'}{'Seasons_Other2'} created in $txt_SeasonName" : '',{displaytype=>'date', fieldtype=>'date', optiongroup=>'seasons', dbformat=>'DATE_FORMAT(dtInOther2,"%d/%m/%Y")', dbfield=>'dtInOther2', disable=>$hideSeasons}],

		#Coach Stuff
		#Umpire Stuff
       #intUmpireActive=> ['Match Official Active ?',{displaytype=>'lookup', fieldtype=>'dropdown', dropdownoptions=>{0=>'No', 1=>'Yes'}, dropdownorder=>[0,1], dbfield=>'tblMT_Umpire.intActive', optiongroup=>'mt_umpire'}],
    ## ADDED BY TC
		#Official Stuff
#OtherFields
intOccupationID => [
                'Occupation',
                {
                    displaytype=>'lookup',
                    fieldtype=>'dropdown',
                    dropdownoptions=>$CommonVals->{'DefCodes'}{ -9},
                    optiongroup=>'otherfields',
                    allowgrouping=>1
                }
            ],

            strLoyaltyNumber => [
                'Loyalty Number',
                {
                    displaytype=>'text',
                    fieldtype=>'text',
                    allowsort=>1,
                    optiongroup=>'otherfields'
                }
            ],

            intMailingList => [
                'MailingList?',
                {
                    displaytype=>'lookup',
                    fieldtype=>'dropdown',
                    dropdownoptions=>{ 0=>'No', 1=>'Yes'},
                    dropdownorder=>[0, 1],
                    optiongroup=>'otherfields',
                    allowgrouping=>1
                }
            ],
 strNatCustomStr1 => [
                    $CommonVals->{'CustomFields'}->{'strNatCustomStr1'}[0],
                    {
                        displaytype=>'text',
                        fieldtype=>'text',
                        allowsort=>0,
                        optiongroup=>'otherfields'
                    }
                ],

                strNatCustomStr2 => [
                    $CommonVals->{'CustomFields'}->{'strNatCustomStr2'}[0],
                    {
                        displaytype=>'text',
                        fieldtype=>'text',
                        allowsort=>0,
                        optiongroup=>'otherfields'
                    }
                ],

                strNatCustomStr3 => [
                    $CommonVals->{'CustomFields'}->{'strNatCustomStr3'}[0],
                    {
                        displaytype=>'text',
                        fieldtype=>'text',
                        allowsort=>0,
                        optiongroup=>'otherfields'
                    }
                ],

                strNatCustomStr4 => [
                    $CommonVals->{'CustomFields'}->{'strNatCustomStr4'}[0],
                    {
                        displaytype=>'text',
                        fieldtype=>'text',
                        allowsort=>0,
                        optiongroup=>'otherfields'
                    }
                ],
strNatCustomStr5 => [
                    $CommonVals->{'CustomFields'}->{'strNatCustomStr5'}[0],
                    {
                        displaytype=>'text',
                        fieldtype=>'text',
                        allowsort=>0,
                        optiongroup=>'otherfields'
                    }
                ],

                strNatCustomStr6 => [
                    $CommonVals->{'CustomFields'}->{'strNatCustomStr6'}[0],
                    {
                        displaytype=>'text',
                        fieldtype=>'text',
                        allowsort=>0,
                        optiongroup=>'otherfields'
                    }
                ],

                strNatCustomStr7 => [
                    $CommonVals->{'CustomFields'}->{'strNatCustomStr7'}[0],
                    {
                        displaytype=>'text',
                        fieldtype=>'text',
                        allowsort=>0,
                        optiongroup=>'otherfields'
                    }
                ],

                strNatCustomStr8 => [
                    $CommonVals->{'CustomFields'}->{'strNatCustomStr8'}[0],
                    {
                        displaytype=>'text',
                        fieldtype=>'text',
                        allowsort=>0,
                        optiongroup=>'otherfields'
                    }
                ],
strNatCustomStr9 => [
                    $CommonVals->{'CustomFields'}->{'strNatCustomStr9'}[0],
                    {
                        displaytype=>'text',
                        fieldtype=>'text',
                        allowsort=>0,
                        optiongroup=>'otherfields'
                    }
                ],

                strNatCustomStr10 => [
                    $CommonVals->{'CustomFields'}->{'strNatCustomStr10'}[0],
                    {
                        displaytype=>'text',
                        fieldtype=>'text',
                        allowsort=>0,
                        optiongroup=>'otherfields'
                    }
                ],

                strNatCustomStr11 => [
                    $CommonVals->{'CustomFields'}->{'strNatCustomStr11'}[0],
                    {
                        displaytype=>'text',
                        fieldtype=>'text',
                        allowsort=>0,
                        optiongroup=>'otherfields'
                    }
                ],

                strNatCustomStr12 => [
                    $CommonVals->{'CustomFields'}->{'strNatCustomStr12'}[0],
                    {
                        displaytype=>'text',
                        fieldtype=>'text',
                        allowsort=>0,
                        optiongroup=>'otherfields'
                    }
                ],strNatCustomStr9 => [
                    $CommonVals->{'CustomFields'}->{'strNatCustomStr9'}[0],
                    {
                        displaytype=>'text',
                        fieldtype=>'text',
                        allowsort=>0,
                        optiongroup=>'otherfields'
                    }
                ],

                strNatCustomStr10 => [
                    $CommonVals->{'CustomFields'}->{'strNatCustomStr10'}[0],
                    {
                        displaytype=>'text',
                        fieldtype=>'text',
                        allowsort=>0,
                        optiongroup=>'otherfields'
                    }
                ],

                strNatCustomStr11 => [
                    $CommonVals->{'CustomFields'}->{'strNatCustomStr11'}[0],
                    {
                        displaytype=>'text',
                        fieldtype=>'text',
                        allowsort=>0,
                        optiongroup=>'otherfields'
                    }
                ],

                strNatCustomStr12 => [
                    $CommonVals->{'CustomFields'}->{'strNatCustomStr12'}[0],
                    {
                        displaytype=>'text',
                        fieldtype=>'text',
                        allowsort=>0,
                        optiongroup=>'otherfields'
                    }
                ],
strNatCustomStr13 => [
                    $CommonVals->{'CustomFields'}->{'strNatCustomStr13'}[0],
                    {
                        displaytype=>'text',
                        fieldtype=>'text',
                        allowsort=>0,
                        optiongroup=>'otherfields'
                    }
                ],

                strNatCustomStr14 => [
                    $CommonVals->{'CustomFields'}->{'strNatCustomStr14'}[0],
                    {
                        displaytype=>'text',
                        fieldtype=>'text',
                        allowsort=>0,
                        optiongroup=>'otherfields'
                    }
                ],

                strNatCustomStr15 => [
                    $CommonVals->{'CustomFields'}->{'strNatCustomStr15'}[0],
                    {
                        displaytype=>'text',
                        fieldtype=>'text',
                        allowsort=>0,
                        optiongroup=>'otherfields'
                    }
                ],

                dblNatCustomDbl1 => [
                    $CommonVals->{'CustomFields'}->{'dblNatCustomDbl1'}[0],
                    {
                        displaytype=>'text',
                        fieldtype=>'text',
                        allowsort=>0,
                        optiongroup=>'otherfields'
                    }
                ],
 dblNatCustomDbl2 => [
                    $CommonVals->{'CustomFields'}->{'dblNatCustomDbl2'}[0],
                    {
                        displaytype=>'text',
                        fieldtype=>'text',
                        allowsort=>0,
                        optiongroup=>'otherfields'
                    }
                ],

                dblNatCustomDbl3 => [
                    $CommonVals->{'CustomFields'}->{'dblNatCustomDbl3'}[0],
                    {
                        displaytype=>'text',
                        fieldtype=>'text',
                        allowsort=>0,
                        optiongroup=>'otherfields'
                    }
                ],

                dblNatCustomDbl4 => [
                    $CommonVals->{'CustomFields'}->{'dblNatCustomDbl4'}[0],
                    {
                        displaytype=>'text',
                        fieldtype=>'text',
                        allowsort=>0,
                        optiongroup=>'otherfields'
                    }
                ],

                dblNatCustomDbl5 => [
                    $CommonVals->{'CustomFields'}->{'dblNatCustomDbl5'}[0],
                    {
                        displaytype=>'text',
                        fieldtype=>'text',
                        allowsort=>0,
                        optiongroup=>'otherfields'
                    }
                ],
dblNatCustomDbl6 => [
                    $CommonVals->{'CustomFields'}->{'dblNatCustomDbl6'}[0],
                    {
                        displaytype=>'text',
                        fieldtype=>'text',
                        allowsort=>0,
                        optiongroup=>'otherfields'
                    }
                ],

                dblNatCustomDbl7 => [
                    $CommonVals->{'CustomFields'}->{'dblNatCustomDbl7'}[0],
                    {
                        displaytype=>'text',
                        fieldtype=>'text',
                        allowsort=>0,
                        optiongroup=>'otherfields'
                    }
                ],

                dblNatCustomDbl8 => [
                    $CommonVals->{'CustomFields'}->{'dblNatCustomDbl8'}[0],
                    {
                        displaytype=>'text',
                        fieldtype=>'text',
                        allowsort=>0,
                        optiongroup=>'otherfields'
                    }
                ],

                dblNatCustomDbl9 => [
                    $CommonVals->{'CustomFields'}->{'dblNatCustomDbl9'}[0],
                    {
                        displaytype=>'text',
                        fieldtype=>'text',
                        allowsort=>0,
                        optiongroup=>'otherfields'
                    }
                ],
dblNatCustomDbl10 => [
                    $CommonVals->{'CustomFields'}->{'dblNatCustomDbl10'}[0],
                    {
                        displaytype=>'text',
                        fieldtype=>'text',
                        allowsort=>0,
                        optiongroup=>'otherfields'
                    }
                ],

                dtNatCustomDt1 => [
                    $CommonVals->{'CustomFields'}->{'dtNatCustomDt1'}[0],
                    {
                        displaytype=>'date',
                        fieldtype=>'date',
                        allowsort=>0,
                        optiongroup=>'otherfields',
                        dbformat=>' DATE_FORMAT(tblMember.dtNatCustomDt1, "%d/%m/%Y")',
                        dbfield=>'tblMember.dtNatCustomDt1'
                    }
                ],

                dtNatCustomDt2 => [
                    $CommonVals->{'CustomFields'}->{'dtNatCustomDt2'}[0],
                    {
                        displaytype=>'date',
                        fieldtype=>'date',
                        allowsort=>0,
                        optiongroup=>'otherfields',
                        dbformat=>' DATE_FORMAT(tblMember.dtNatCustomDt2, "%d/%m/%Y")',
                        dbfield=>'tblMember.dtNatCustomDt2'
                    }
                ],
dtNatCustomDt3 => [
                    $CommonVals->{'CustomFields'}->{'dtNatCustomDt3'}[0],
                    {
                        displaytype=>'date',
                        fieldtype=>'date',
                        allowsort=>0,
                        optiongroup=>'otherfields',
                        dbformat=>' DATE_FORMAT(tblMember.dtNatCustomDt3, "%d/%m/%Y")',
                        dbfield=>'tblMember.dtNatCustomDt3'
                    }
                ],

                dtNatCustomDt4 => [
                    $CommonVals->{'CustomFields'}->{'dtNatCustomDt4'}[0],
                    {
                        displaytype=>'date',
                        fieldtype=>'date',
                        allowsort=>0,
                        optiongroup=>'otherfields',
                        dbformat=>' DATE_FORMAT(tblMember.dtNatCustomDt4, "%d/%m/%Y")',
                        dbfield=>'tblMember.dtNatCustomDt4'
                    }
                ],

                dtNatCustomDt5 => [
                    $CommonVals->{'CustomFields'}->{'dtNatCustomDt5'}[0],
                    {
                        displaytype=>'date',
                        fieldtype=>'date',
                        allowsort=>0,
                        optiongroup=>'otherfields',
                        dbformat=>' DATE_FORMAT(tblMember.dtNatCustomDt5, "%d/%m/%Y")',
                        dbfield=>'tblMember.dtNatCustomDt5'
                    }
                ],
intNatCustomLU1 => [
                    $CommonVals->{'CustomFields'}->{'intNatCustomLU1'}[0],
                    {
                        displaytype=>'lookup',
                        fieldtype=>'dropdown',
                        dropdownoptions=>$CommonVals->{'DefCodes'}{-53},
                        optiongroup=>'otherfields',
                        size=>3,
                        multiple=>1
                    }
                ],

        intNatCustomLU2 => [
                    $CommonVals->{'CustomFields'}->{'intNatCustomLU2'}[0],
                    {
                        displaytype=>'lookup',
                        fieldtype=>'dropdown',
                        dropdownoptions=>$CommonVals->{'DefCodes'}{-54},
                        optiongroup=>'otherfields',
                        size=>3,
                        multiple=>1
                    }
                ],

        intNatCustomLU3 => [
                    $CommonVals->{'CustomFields'}->{'intNatCustomLU3'}[0],
                    {
                        displaytype=>'lookup',
                        fieldtype=>'dropdown',
                        dropdownoptions=>$CommonVals->{'DefCodes'}{-55},
                        optiongroup=>'otherfields',
                        size=>3,
                        multiple=>1
                    }
                ],
intNatCustomLU4 => [
                    $CommonVals->{'CustomFields'}->{'intNatCustomLU4'}[0],
                    {
                        displaytype=>'lookup',
                        fieldtype=>'dropdown',
                        dropdownoptions=>$CommonVals->{'DefCodes'}{-64},
                        optiongroup=>'otherfields',
                        size=>3,
                        multiple=>1
                    }
                ],

        intNatCustomLU5 => [
                    $CommonVals->{'CustomFields'}->{'intNatCustomLU5'}[0],
                    {
                        displaytype=>'lookup',
                        fieldtype=>'dropdown',
                        dropdownoptions=>$CommonVals->{'DefCodes'}{-65},
                        optiongroup=>'otherfields',
                        size=>3,
                        multiple=>1
                    }
                ],

        intNatCustomLU6 => [
                    $CommonVals->{'CustomFields'}->{'intNatCustomLU6'}[0],
                    {
                        displaytype=>'lookup',
                        fieldtype=>'dropdown',
                        dropdownoptions=>$CommonVals->{'DefCodes'}{-66},
                        optiongroup=>'otherfields',
                        size=>3,
                        multiple=>1
                    }
                ],
intNatCustomLU7 => [
                    $CommonVals->{'CustomFields'}->{'intNatCustomLU7'}[0],
                    {
                        displaytype=>'lookup',
                        fieldtype=>'dropdown',
                        dropdownoptions=>$CommonVals->{'DefCodes'}{-67},
                        optiongroup=>'otherfields',
                        size=>3,
                        multiple=>1
                    }
                ],

                intNatCustomLU8 => [
                    $CommonVals->{'CustomFields'}->{'intNatCustomLU8'}[0],
                    {
                        displaytype=>'lookup',
                        fieldtype=>'dropdown',
                        dropdownoptions=>$CommonVals->{'DefCodes'}{-68},
                        optiongroup=>'otherfields',
                        size=>3,
                        multiple=>1
                    }
                ],

                intNatCustomLU9 => [
                    $CommonVals->{'CustomFields'}->{'intNatCustomLU9'}[0],
                    {
                        displaytype=>'lookup',
                        fieldtype=>'dropdown',
                        dropdownoptions=>$CommonVals->{'DefCodes'}{-69},
                        optiongroup=>'otherfields',
                        size=>3,
                        multiple=>1
                    }
                ],
intNatCustomLU10 => [
                    $CommonVals->{'CustomFields'}->{'intNatCustomLU10'}[0],
                    {
                        displaytype=>'lookup',
                        fieldtype=>'dropdown',
                        dropdownoptions=>$CommonVals->{'DefCodes'}{-70},
                        optiongroup=>'otherfields',
                        size=>3,
                        multiple=>1
                    }
                ],

                intNatCustomBool1 => [
                    $CommonVals->{'CustomFields'}->{'intNatCustomBool1'}[0],
                    {
                        displaytype=>'lookup',
                        fieldtype=>'dropdown',
                        dropdownoptions=>{ 0=>'No', 1=>'Yes'},
                        dropdownorder=>[0, 1],
                        optiongroup=>'otherfields',
                    }
                ],

                intNatCustomBool2 => [
                    $CommonVals->{'CustomFields'}->{'intNatCustomBool2'}[0],
                    {
                        displaytype=>'lookup',
                        fieldtype=>'dropdown',
                        dropdownoptions=>{ 0=>'No', 1=>'Yes'},
                        dropdownorder=>[0, 1],
                        optiongroup=>'otherfields',
                    }
                ],
intNatCustomBool3 => [
                    $CommonVals->{'CustomFields'}->{'intNatCustomBool3'}[0],
                    {
                        displaytype=>'lookup',
                        fieldtype=>'dropdown',
                        dropdownoptions=>{ 0=>'No', 1=>'Yes'},
                        dropdownorder=>[0, 1],
                        optiongroup=>'otherfields',
                    }
                ],

        intNatCustomBool4 => [
            $CommonVals->{'CustomFields'}->{'intNatCustomBool4'}[0],
            {
                displaytype=>'lookup',
                fieldtype=>'dropdown',
                dropdownoptions=>{ 0=>'No', 1=>'Yes'},
                dropdownorder=>[0, 1],
                optiongroup=>'otherfields',
            }
        ],

        intNatCustomBool5 => [
            $CommonVals->{'CustomFields'}->{'intNatCustomBool5'}[0],
            {
                displaytype=>'lookup',
                fieldtype=>'dropdown',
                dropdownoptions=>{ 0=>'No', 1=>'Yes'},
                dropdownorder=>[0, 1],
                optiongroup=>'otherfields',
            }
        ],
 strCustomStr1 => [
            $CommonVals->{'CustomFields'}->{'strCustomStr1'}[0],
            {
                displaytype=>'text',
                fieldtype=>'text',
                allowsort=>0,
                optiongroup=>'otherfields',
            }
        ],

        strCustomStr2 => [
            $CommonVals->{'CustomFields'}->{'strCustomStr2'}[0],
            {
                displaytype=>'text',
                fieldtype=>'text',
                allowsort=>0,
                optiongroup=>'otherfields'
            }
        ],

        strCustomStr3 => [
            $CommonVals->{'CustomFields'}->{'strCustomStr3'}[0],
            {
                displaytype=>'text',
                fieldtype=>'text',
                allowsort=>0,
                optiongroup=>'otherfields'
            }
        ],

        strCustomStr4 => [
            $CommonVals->{'CustomFields'}->{'strCustomStr4'}[0],
            {
                displaytype=>'text',
                fieldtype=>'text',
                allowsort=>0,
                optiongroup=>'otherfields'
            }
        ],
 strCustomStr5 => [
            $CommonVals->{'CustomFields'}->{'strCustomStr5'}[0],
            {
                displaytype=>'text',
                fieldtype=>'text',
                allowsort=>0,
                optiongroup=>'otherfields'
            }
        ],

        strCustomStr6 => [
            $CommonVals->{'CustomFields'}->{'strCustomStr6'}[0],
            {
                displaytype=>'text',
                fieldtype=>'text',
                allowsort=>0,
                optiongroup=>'otherfields'
            }
        ],

        strCustomStr7 => [
            $CommonVals->{'CustomFields'}->{'strCustomStr7'}[0],
            {
                displaytype=>'text',
                fieldtype=>'text',
                allowsort=>0,
                optiongroup=>'otherfields'
            }
        ],

        strCustomStr8 => [
            $CommonVals->{'CustomFields'}->{'strCustomStr8'}[0],
            {
                displaytype=>'text',
                fieldtype=>'text',
                allowsort=>0,
                optiongroup=>'otherfields'
            }
        ],
strCustomStr9 => [
            $CommonVals->{'CustomFields'}->{'strCustomStr9'}[0],
            {
                displaytype=>'text',
                fieldtype=>'text',
                allowsort=>0,
                optiongroup=>'otherfields'
            }
        ],

        strCustomStr10 => [
            $CommonVals->{'CustomFields'}->{'strCustomStr10'}[0],
            {
                displaytype=>'text',
                fieldtype=>'text',
                allowsort=>0,
                optiongroup=>'otherfields'
            }
        ],

        strCustomStr11 => [
            $CommonVals->{'CustomFields'}->{'strCustomStr11'}[0],
            {
                displaytype=>'text',
                fieldtype=>'text',
                allowsort=>0,
                optiongroup=>'otherfields'
            }
        ],

        strCustomStr12 => [
            $CommonVals->{'CustomFields'}->{'strCustomStr12'}[0],
            {
                displaytype=>'text',
                fieldtype=>'text',
                allowsort=>0,
                optiongroup=>'otherfields'
            }
        ],
strCustomStr13 => [
            $CommonVals->{'CustomFields'}->{'strCustomStr13'}[0],
            {
                displaytype=>'text',
                fieldtype=>'text',
                allowsort=>0,
                optiongroup=>'otherfields'
            }
        ],

        strCustomStr14 => [
            $CommonVals->{'CustomFields'}->{'strCustomStr14'}[0],
            {
                displaytype=>'text',
                fieldtype=>'text',
                allowsort=>0,
                optiongroup=>'otherfields'
            }
        ],

        strCustomStr15 => [
            $CommonVals->{'CustomFields'}->{'strCustomStr15'}[0],
            {
                displaytype=>'text',
                fieldtype=>'text',
                allowsort=>0,
                optiongroup=>'otherfields'
            }
        ],

        dblCustomDbl1 => [
            $CommonVals->{'CustomFields'}->{'dblCustomDbl1'}[0],
            {
                displaytype=>'text',
                fieldtype=>'text',
                allowsort=>0,
                optiongroup=>'otherfields'
            }
        ],
 dblCustomDbl2 => [
            $CommonVals->{'CustomFields'}->{'dblCustomDbl2'}[0],
            {
                displaytype=>'text',
                fieldtype=>'text',
                allowsort=>0,
                optiongroup=>'otherfields'
            }
        ],

        dblCustomDbl3 => [
            $CommonVals->{'CustomFields'}->{'dblCustomDbl3'}[0],
            {
                displaytype=>'text',
                fieldtype=>'text',
                allowsort=>0,
                optiongroup=>'otherfields'
            }
        ],

        dblCustomDbl4 => [
            $CommonVals->{'CustomFields'}->{'dblCustomDbl4'}[0],
            {
                displaytype=>'text',
                fieldtype=>'text',
                allowsort=>0,
                optiongroup=>'otherfields'
            }
        ],

        dblCustomDbl5 => [
            $CommonVals->{'CustomFields'}->{'dblCustomDbl5'}[0],
            {
                displaytype=>'text',
                fieldtype=>'text',
                allowsort=>0,
                optiongroup=>'otherfields'
            }
        ],
dblCustomDbl6 => [
            $CommonVals->{'CustomFields'}->{'dblCustomDbl6'}[0],
            {
                displaytype=>'text',
                fieldtype=>'text',
                allowsort=>0,
                optiongroup=>'otherfields'
            }
        ],

        dblCustomDbl7 => [
            $CommonVals->{'CustomFields'}->{'dblCustomDbl7'}[0],
            {
                displaytype=>'text',
                fieldtype=>'text',
                allowsort=>0,
                optiongroup=>'otherfields'
            }
        ],

        dblCustomDbl8 => [
            $CommonVals->{'CustomFields'}->{'dblCustomDbl8'}[0],
            {
                displaytype=>'text',
                fieldtype=>'text',
                allowsort=>0,
                optiongroup=>'otherfields'
            }
        ],

        dblCustomDbl9 => [
            $CommonVals->{'CustomFields'}->{'dblCustomDbl9'}[0],
            {
                displaytype=>'text',
                fieldtype=>'text',
                allowsort=>0,
                optiongroup=>'otherfields'
            }
        ],
dblCustomDbl10 => [
            $CommonVals->{'CustomFields'}->{'dblCustomDbl10'}[0],
            {
                displaytype=>'text',
                fieldtype=>'text',
                allowsort=>0,
                optiongroup=>'otherfields'
            }
        ],

        dtCustomDt1 => [
            $CommonVals->{'CustomFields'}->{'dtCustomDt1'}[0],
            {
                displaytype=>'date',
                fieldtype=>'date',
                allowsort=>0,
                optiongroup=>'otherfields',
                dbformat=>' DATE_FORMAT(tblMember_Associations.dtCustomDt1, "%d/%m/%Y")',
                dbfield=>'tblMember_Associations.dtCustomDt1'
            }
        ],

        dtCustomDt2 => [
            $CommonVals->{'CustomFields'}->{'dtCustomDt2'}[0],
            {
                displaytype=>'date',
                fieldtype=>'date',
                allowsort=>0,
                optiongroup=>'otherfields',
                dbformat=>' DATE_FORMAT(tblMember_Associations.dtCustomDt2, "%d/%m/%Y")',
                dbfield=>'tblMember_Associations.dtCustomDt2'
            }
        ],
dtCustomDt3 => [
            $CommonVals->{'CustomFields'}->{'dtCustomDt3'}[0],
            {
                displaytype=>'date',
                fieldtype=>'date',
                allowsort=>0,
                optiongroup=>'otherfields',
                dbformat=>' DATE_FORMAT(tblMember_Associations.dtCustomDt3, "%d/%m/%Y")',
                dbfield=>'tblMember_Associations.dtCustomDt3'
            }
        ],

        dtCustomDt4 => [
$CommonVals->{'CustomFields'}->{'dtCustomDt4'}[0],
{
displaytype=>'date',
fieldtype=>'date',
allowsort=>0,
optiongroup=>'otherfields',
dbformat=>' DATE_FORMAT(tblMember_Associations.dtCustomDt4, "%d/%m/%Y")',
dbfield=>'tblMember_Associations.dtCustomDt4'
}
],

                dtCustomDt5 => [
$CommonVals->{'CustomFields'}->{
'dtCustomDt5'}[0],
{
displaytype=>'date',
fieldtype=>'date',
allowsort=>0,
optiongroup=>'otherfields',
dbformat=>' DATE_FORMAT(tblMember_Associations.dtCustomDt5, "%d/%m/%Y")',
dbfield=>'tblMember_Associations.dtCustomDt5'
}
],
 intCustomLU1 => [
$CommonVals->{'CustomFields'}->{'intCustomLU1'}[0],
{
displaytype=>'lookup',
fieldtype=>'dropdown',
dropdownoptions=>$CommonVals->{'DefCodes'}{-50},
optiongroup=>'otherfields',
size=>3,
multiple=>1
}
],

        intCustomLU2 => [
$CommonVals->{'CustomFields'}->{'intCustomLU2'}[0],
{
displaytype=>'lookup',
fieldtype=>'dropdown',
dropdownoptions=>$CommonVals->{'DefCodes'}{-51},
optiongroup=>'otherfields',
size=>3,
multiple=>1
}
],

        intCustomLU3 => [
$CommonVals->{'CustomFields'}->{
'intCustomLU3'}[0],
{
displaytype=>'lookup',
fieldtype=>'dropdown',
dropdownoptions=>$CommonVals->{'DefCodes'}{
-52},
optiongroup=>'otherfields',
size=>3,
multiple=>1
}
],
 intCustomLU4 => [
$CommonVals->{'CustomFields'}->{
'intCustomLU4'}[0],
{
displaytype=>'lookup',
fieldtype=>'dropdown',
dropdownoptions=>$CommonVals->{'DefCodes'}{
-57},
optiongroup=>'otherfields',
size=>3,
multiple=>1
}
],

        intCustomLU5 => [
$CommonVals->{'CustomFields'}->{
'intCustomLU5'}[0],
{
displaytype=>'lookup',
fieldtype=>'dropdown',
dropdownoptions=>$CommonVals->{'DefCodes'}{
-58},
optiongroup=>'otherfields',
size=>3,
multiple=>1
}
],
intCustomLU6 => [
$CommonVals->{'CustomFields'}->{
'intCustomLU6'}[0],
{
displaytype=>'lookup',
fieldtype=>'dropdown',
dropdownoptions=>$CommonVals->{'DefCodes'}{
-59},
optiongroup=>'otherfields',
size=>3,
multiple=>1
}
],

        intCustomLU7 => [
$CommonVals->{'CustomFields'}->{
'intCustomLU7'}[0],
{
displaytype=>'lookup',
fieldtype=>'dropdown',
dropdownoptions=>$CommonVals->{'DefCodes'}{
-60},
optiongroup=>'otherfields',
size=>3,
multiple=>1
}
],
 intCustomLU8 => [
$CommonVals->{'CustomFields'}->{
'intCustomLU8'}[0],
{
displaytype=>'lookup',
 fieldtype=>'dropdown',
 dropdownoptions=>$CommonVals->{'DefCodes'}{
-61},
 optiongroup=>'otherfields',
 size=>3,
 multiple=>1
}
],

        intCustomLU9 => [
$CommonVals->{'CustomFields'}->{
'intCustomLU9'}[0],
{
displaytype=>'lookup',
 fieldtype=>'dropdown',
 dropdownoptions=>$CommonVals->{'DefCodes'}{
-62},
 optiongroup=>'otherfields',
 size=>3,
 multiple=>1
}
],

intCustomLU10 => [
$CommonVals->{'CustomFields'}->{
'intCustomLU10'}[0],
{
displaytype=>'lookup',
 fieldtype=>'dropdown',
 dropdownoptions=>$CommonVals->{'DefCodes'}{
-63},
 optiongroup=>'otherfields',
 size=>3,
 multiple=>1
}
],

        intCustomBool1 => [
$CommonVals->{'CustomFields'}->{
'intCustomBool1'}[0],
{
displaytype=>'lookup',
 fieldtype=>'dropdown',
 dropdownoptions=>{
0=>'No',
 1=>'Yes'},
 dropdownorder=>[0,
1],
 optiongroup=>'otherfields'} ],
  intCustomBool2 => [
$CommonVals->{'CustomFields'}->{
'intCustomBool2'}[0],
{
displaytype=>'lookup',
 fieldtype=>'dropdown',
 dropdownoptions=>{
0=>'No',
 1=>'Yes'},
 dropdownorder=>[0,
1],
 optiongroup=>'otherfields'} ],

        intCustomBool3 => [
$CommonVals->{'CustomFields'}->{
'intCustomBool3'}[0],
{
displaytype=>'lookup',
 fieldtype=>'dropdown',
 dropdownoptions=>{
0=>'No',
 1=>'Yes'},
 dropdownorder=>[0,
1],
 optiongroup=>'otherfields'} ],

intCustomBool4 => [
$CommonVals->{'CustomFields'}->{
'intCustomBool4'}[0],
{
displaytype=>'lookup',
 fieldtype=>'dropdown',
 dropdownoptions=>{
0=>'No',
 1=>'Yes'},
 dropdownorder=>[0,
1],
 optiongroup=>'otherfields'} ],

        intCustomBool5 => [
$CommonVals->{'CustomFields'}->{
'intCustomBool5'}[0],
{
displaytype=>'lookup',
 fieldtype=>'dropdown',
 dropdownoptions=>{
0=>'No',
 1=>'Yes'},
 dropdownorder=>[0,
1],
 optiongroup=>'otherfields'} ],
intGradeID => [
            'School Grade',
            {
                displaytype=>'lookup',
                fieldtype=>'dropdown',
                dropdownoptions => $CommonVals->{'SchoolGrades'}{'Options'},
                dropdownorder =>$CommonVals->{'SchoolGrades'}{'Order'},
                optiongroup=>'otherfields',
                allowsort=>1,
                size=>3,
                multiple=>1,
                dbfield=>'tblMember.intGradeID',
                allowgrouping=>1,
                enabled => $Data->{'SystemConfig'}{'Schools'},
            }
        ],

        strSchoolName  => [
            'School Name',
            {
                displaytype=>'text',
                allowgrouping=>1,
                fieldtype=>'text',
                allowsort=>1,
                dbfield=>'tblSchool.strName',
                optiongroup=>'otherfields',
                dbfrom=>'LEFT JOIN tblSchool ON (tblMember.intSchoolID = tblSchool.intSchoolID)',
                enabled => ($Data->{'SystemConfig'}{'rptSchools'} or $Data->{'SystemConfig'}{'Schools'}),
            }
        ],
 strSchoolSuburb  => [
($Data->{
'SystemConfig'}{
'rptSchools'} or $Data->{
'SystemConfig'}{
'Schools'}) ? 'School Suburb' : '',
{
displaytype=>'text',
 fieldtype=>'text',
 allowsort=>1,
 dbfield=>'tblSchool.strSuburb',
 optiongroup=>'otherfields',
 dbfrom=>'LEFT JOIN tblSchool ON (tblMember.intSchoolID = tblSchool.intSchoolID)',
 allowgrouping=>1
}
],


        intFavStateTeamID => [
'State Team Supported',
{
displaytype=>'lookup',
 fieldtype=>'dropdown',
 dropdownoptions=>$CommonVals->{'DefCodes'}{
-33},
 optiongroup=>'otherfields',
 allowgrouping=>1
}
],
intFavNationalTeamID => [
$natteamname.' Supported',
{
displaytype=>'lookup',
 fieldtype=>'dropdown',
 dropdownoptions=>$CommonVals->{'DefCodes'}{
-34},
 allowgrouping=>1,
 optiongroup=>'otherfields'
}
],

        intFavNationalTeamMember => [
$natteamname.'Member',
{
displaytype=>'lookup',
 fieldtype=>'dropdown',
 dropdownoptions=>{
0=>'No',
 1=>'Yes'},
 dropdownorder=>[0,
1],
 dbfield=>'tblMember.intFavNationalTeamMember',
 optiongroup=>'otherfields',
 allowgrouping=>1
}
],

        intAttendSportCount => [
'Games attended',
{
displaytype=>'text',
 fieldtype=>'text',
 allowgrouping=>1,
 optiongroup=>'otherfields'
}
],
intWatchSportHowOftenID => [
'Watch sport on TV ?',
{
displaytype=>'lookup',
 fieldtype=>'dropdown',
 dropdownoptions=>$CommonVals->{'DefCodes'}{
-1004},
 allowgrouping=>1,
 optiongroup=>'otherfields'
}
],

    strMemberNotes => [
'Notes',
{
displaytype=>'text',
 fieldtype=>'text',
 allowsort=>0,
 dbfield=>'strMemberNotes',
 optiongroup=>'otherfields',
 dbfrom=>'LEFT JOIN tblMemberNotes as MN ON (MN.intNotesMemberID = tblMember_Associations.intMemberID AND MN.intNotesAssocID = tblMember_Associations.intAssocID)'
}
],

    strMemberCustomNotes1 => [
$CommonVals->{'CustomFields'}->{'strMemberCustomNotes1'}[0],
{
displaytype=>'text',
 fieldtype=>'text',
 allowsort=>0,
 dbfield=>'strMemberCustomNotes1',
 optiongroup=>'otherfields',
 dbfrom=>'LEFT JOIN tblMemberNotes as MN ON (MN.intNotesMemberID = tblMember_Associations.intMemberID AND MN.intNotesAssocID = tblMember_Associations.intAssocID)'
}
],
 strMemberCustomNotes2 => [
$CommonVals->{'CustomFields'}->{'strMemberCustomNotes2'}[0],
{
displaytype=>'text',
 fieldtype=>'text',
 allowsort=>0,
 dbfield=>'strMemberCustomNotes2',
 optiongroup=>'otherfields',
 dbfrom=>'LEFT JOIN tblMemberNotes as MN ON (MN.intNotesMemberID = tblMember_Associations.intMemberID AND MN.intNotesAssocID = tblMember_Associations.intAssocID)'
}
],

    strMemberCustomNotes3 => [
$CommonVals->{'CustomFields'}->{'strMemberCustomNotes3'}[0],
{
displaytype=>'text',
 fieldtype=>'text',
 allowsort=>0,
 dbfield=>'strMemberCustomNotes3',
 optiongroup=>'otherfields',
 dbfrom=>'LEFT JOIN tblMemberNotes as MN ON (MN.intNotesMemberID = tblMember_Associations.intMemberID AND MN.intNotesAssocID = tblMember_Associations.intAssocID)'
}
],

    strMemberCustomNotes4 => [
$CommonVals->{'CustomFields'}->{'strMemberCustomNotes4'}[0],
{
displaytype=>'text',
 fieldtype=>'text',
 allowsort=>0,
 dbfield=>'strMemberCustomNotes4',
 optiongroup=>'otherfields',
 dbfrom=>'LEFT JOIN tblMemberNotes as MN ON (MN.intNotesMemberID = tblMember_Associations.intMemberID AND MN.intNotesAssocID = tblMember_Associations.intAssocID)'
}
],
strMemberCustomNotes5 => [
$CommonVals->{'CustomFields'}->{'strMemberCustomNotes5'}[0],
{
displaytype=>'text',
 fieldtype=>'text',
 allowsort=>0,
 dbfield=>'strMemberCustomNotes5',
 optiongroup=>'otherfields',
 dbfrom=>'LEFT JOIN tblMemberNotes as MN ON (MN.intNotesMemberID = tblMember_Associations.intMemberID AND MN.intNotesAssocID = tblMember_Associations.intAssocID)'
}
],

        intPhoto => [
'Photo Present?',
{
displaytype=>'lookup',
 fieldtype=>'dropdown',
 dropdownoptions=>{ 0=>'No', 1=>'Yes'},
 dropdownorder=>[0, 1],
 dbfield=>'tblMember.intPhoto',
 optiongroup=>'otherfields',
 allowgrouping=>1
}
],

        intTagID  => [
($SystemConfig->{'NoMemberTags'} ? '' : 'Tags'),
{
displaytype=>'lookup',
 fieldtype=>'dropdown',
 dropdownoptions=>$CommonVals->{'DefCodes'}{-24},
 optiongroup=>'otherfields',
 multiple=>1,
 size=>"7",
 dbfield=>'tblMemberTags.intTagID',
 dbfrom=>" LEFT JOIN tblMemberTags ON (tblMember.intMemberID=tblMemberTags.intMemberID AND tblMember_Associations.intAssocID=tblMemberTags.intAssocID AND tblMemberTags.intRecStatus <> $Defs::RECSTATUS_DELETED)"
}
],


                dtFirstRegistered => [
$Data->{'SystemConfig'}{'FirstRegistered_title'} ? $Data->{'SystemConfig'}{'FirstRegistered_title'} : 'First Registered',
{
displaytype=>'date',
 fieldtype=>'date',
 allowsort=>1,
 dbformat=>' DATE_FORMAT(tblMember_Associations.dtFirstRegistered, "%d/%m/%Y")',
 dbfield=>'tblMember_Associations.dtFirstRegistered',
 optiongroup=>'otherfields'
}
],

                dtLastRegistered => [
'Last Registered',
{
displaytype=>'date',
 fieldtype=>'date',
 allowsort=>1,
 dbformat=>' DATE_FORMAT(tblMember_Associations.dtLastRegistered, "%d/%m/%Y")',
 optiongroup=>'otherfields',
 dbfield=>'tblMember_Associations.dtLastRegistered'
}
],
dtRegisteredUntil => [
'Registered Until',
{
displaytype=>'date',
 fieldtype=>'date',
 allowsort=>1,
 dbformat=>' DATE_FORMAT(IF(tblMember_Associations.dtRegisteredUntil IS NULL, "0000-00-00", dtRegisteredUntil), "%d/%m/%Y")',
 optiongroup=>'otherfields',
 dbfield=>'tblMember_Associations.dtRegisteredUntil'
}
],

                dtSuspendedUntil => [
$Data->{'SystemConfig'}{'NoComps'} ? '' :'Suspended Until',
{
displaytype=>'date',
 fieldtype=>'date',
 allowsort=>1,
 dbformat=>' DATE_FORMAT(tblMember.dtSuspendedUntil, "%d/%m/%Y")',
 optiongroup=>'otherfields',
 dbfield=>'tblMember.dtSuspendedUntil'
}
],

                dtLastUpdate => [
'Last Updated',
{
displaytype=>'date',
 fieldtype=>'datetime',
 allowsort=>1,
 dbformat=>' DATE_FORMAT(tblMember_Associations.tTimeStamp, "%d/%m/%Y")',
 optiongroup=>'otherfields',
 dbfield=>'tblMember_Associations.tTimeStamp'
}
],
 dtCreatedOnline => [
'Date Created Online',
{
displaytype=>'date',
 fieldtype=>'datetime',
 allowsort=>1,
 dbformat=>' DATE_FORMAT(tblMember.dtCreatedOnline, "%d/%m/%Y")',
 optiongroup=>'otherfields',
 dbfield=>'tblMember.dtCreatedOnline'
}
],

        intHowFoundOutID  => [
'How did you find out about us?',
{
displaytype=>'lookup',
 fieldtype=>'dropdown',
 dropdownoptions=>$CommonVals->{'DefCodes'}{-1001},
 optiongroup=>'otherfields'
}
],

 intConsentSignatureSighted => [
$SystemConfig->{'SignatureSightedText'} || 'Signature Sighted?',
{
displaytype=>'lookup',
 fieldtype=>'dropdown',
 dropdownoptions=>{ 0=>'No', 1=>'Yes'},
 dropdownorder=>[0, 1],
 dbfield=>'intConsentSignatureSighted',
 optiongroup=>'otherfields',
 allowgrouping=>1
}
],

    intCreatedFrom => [
'Record creation',
{
displaytype=>'lookup',
 fieldtype=>'dropdown',
 dropdownoptions => \%Defs::CreatedBy,
 allowsort=>1,
 optiongroup => 'otherfields',
 dbfield=>'IF(intCreatedFrom NOT IN (0, 1, 200), -1, intCreatedFrom)',
 allowgrouping=>1
}
],

    strUmpirePassword => [
($Data->{'SystemConfig'}{'AllowCourtside'} ? 'Umpire Password' : ''),
{
displaytype=>'text',
 fieldtype=>'text',
 allowsort=>1,
 optiongroup => 'otherfields',
 allowgrouping=>1
}
],
            dtMemCardPrinted=> ['Member Card Printed',{displaytype=>'date', fieldtype=>'date', allowsort=>1, dbformat=>' DATE_FORMAT(tblMemberCardPrinted.dtPrinted,"%d/%m/%Y %H:%i")', optiongroup => 'otherfields', dbfield=>'tblMemberCardPrinted.dtPrinted', dbfrom=>'LEFT JOIN tblMemberCardPrinted ON tblMemberCardPrinted.intMemberID = tblMember.intMemberID'}],
		#Accreditation
			strAccname=> [
				'Accreditation Name',
				{
                    displaytype=>'lookup',
                    fieldtype=>'dropdown',
                    dropdownoptions => $CommonVals->{'AccreName'}{'Values'},
					active=>1,
                    multiple =>1,
					allowsort=>1,
                    dbfield=>'Q.intQualificationID',
					optiongroup=>'accreditation'
				}
			],
		    strAccType=> [
				'Type',
				{
                    displaytype=>'lookup',
                    fieldtype=>'dropdown',
                    dropdownoptions => $CommonVals->{'DefCodes'}{-505},
					active=>1,
                    multiple =>1,
					allowsort=>1,
                    dbfield =>'Q.intType',
					optiongroup=>'accreditation'
				}
			],
			strAccLevel=> [
				'Level',
				{
					displaytype=>'text',
					fieldtype=>'text',
					active=>1,
					allowsort=>1,
                    dbfield =>'LEVEL.strName',
					optiongroup=>'accreditation'
				}
			],
			strAccProvider=> [
				'Provider',
				{
                    displaytype=>'lookup',
                    fieldtype=>'dropdown',
                    dropdownoptions => $CommonVals->{'DefCodes'}{-503},
					multiple =>1,
                    active=>1,
					allowsort=>1,
                    dbfield =>'A.intProvider',
					optiongroup=>'accreditation'
				}
			],
			dtAccStart=> [
				'Start Date',
				{
                    displaytype=>'date',
                    fieldtype=>'date',
                    dbfield=>'A.dtStart',
                    dbformat=>' DATE_FORMAT(A.dtStart, "%d/%m/%Y")',
					optiongroup=>'accreditation',
				}
			],
			dtAccEnd=> [
				'End Date',
				{
                    displaytype=>'date',
                    fieldtype=>'date',
                    dbfield=>'A.dtExpiry',
                    dbformat=>' DATE_FORMAT(A.dtExpiry, "%d/%m/%Y")',
					optiongroup=>'accreditation',
					
				}
			],
			strCourse=> [
				'Course',
				{
                    displaytype=>'lookup',
                    fieldtype=>'dropdown',
                    dropdownoptions => $CommonVals->{'DefCodes'}{-506},
					active=>1,
                    multiple=>1,
					allowsort=>1,
                    dbfield =>'A.strCourseNumber',
					optiongroup=>'accreditation'
				}
			],
			strAccStatus=> [
				'Status',
				{
					displaytype=>'text',
					fieldtype=>'text',
					active=>1,
					allowsort=>1,
                    dbfield =>'STATUS.strName',
					optiongroup=>'accreditation'
				}
			],
			strAccRA=> [
				'RA',
				{
					displaytype=>'text',
					fieldtype=>'text',
					active=>1,
					allowsort=>1,
                    dbfield =>'A.intReaccreditation',
					optiongroup=>'accreditation'
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
								strMaidenName
								strPreferredName
								dtDOB
								dtYOB
								strPlaceofBirth
								strCountryOfBirth
								strMotherCountry
								strFatherCountry
								intGender
								intDeceased
								strEyeColour
								strHairColour
								intEthnicityID
								strHeight
								strWeight
								strAddress1
								strAddress2
								strSuburb

								strCityOfResidence
								strState
								strCountry
								strPostalCode
								strPhoneHome
								strPhoneWork
								strPhoneMobile
								strPager
								strFax
								strEmail
								strEmail2
								strEmergContName
								strEmergContRel
								strEmergContNo
								strEmergContNo2
								intPlayer
								intCoach
								intUmpire
								intOfficial
								intMisc
								intVolunteer
								strPreferredLang
								strPassportIssueCountry
								strPassportNationality
								strPassportNo
								dtPassportExpiry
								strBirthCertNo
								strHealthCareNo
								intIdentTypeID
								strIdentNum
								dtPoliceCheck
								dtPoliceCheckExp
								strPoliceCheckRef

								intPhoto
								intTagID
								dtFirstRegistered
								dtLastRegistered
								dtRegisteredUntil
								dtSuspendedUntil
								dtLastUpdate
								dtCreatedOnline
								intHowFoundOutID
								intConsentSignatureSighted
								intCreatedFrom
								strUmpirePassword
								intPlayerActive

                                dtMiscStart
                                dtMiscEnd
                                strMiscAccredType
                                dtMiscAppDate
                                intSeasonID
                                intPlayerAgeGroupID
                                intSeasonMemberPackageID
                                intPlayerGradeID
                                intPlayerStatus
                                intPlayerFinancialStatus
                                dtInPlayer
                                intCoachStatus
                                intCoachFinancialStatus
                                dtInCoach
                                intUmpireStatus
                                intUmpireFinancialStatus
                                dtInUmpire
                                dtLastUsedRegoForm
                                intUsedRegoFormID
                                intOther1Status
                                intOther1FinancialStatus
                                dtInOther1
                                intOther2Status
                                intOther2FinancialStatus
                                dtInOther2
                                strAssocName
                                intAssocTypeID
                                intAssocCategoryID
                                strTeamName
                                strClubName
                                intClubCategoryID
                                MCStatus
                                strCompName
                                intNewSeasonID
                                CompAgeGroupID
                                intCompLevelID
                                CompRecStatus
                                strZoneName
                                strRegionName
                                strStateName
                                strNationalName
                                strIntZoneName
                                strIntRegionName
                                intPermit

                                dtMemCardPrinted
                                intOccupationID
                                strLoyaltyNumber
                                intMailingList

                                strNatCustomStr1
                                strNatCustomStr2
                                strNatCustomStr3
                                strNatCustomStr4
                                strNatCustomStr5
                                strNatCustomStr6
                                strNatCustomStr7
                                strNatCustomStr8
                                strNatCustomStr9
                                strNatCustomStr10
                                strNatCustomStr11
                                strNatCustomStr12
                                strNatCustomStr13
                                strNatCustomStr14
                                strNatCustomStr15
                                dblNatCustomDbl1
                                dblNatCustomDbl2
                                dblNatCustomDbl3
                                dblNatCustomDbl4
                                dblNatCustomDbl5
                                dblNatCustomDbl6
                                dblNatCustomDbl7
                                dblNatCustomDbl8
                                dblNatCustomDbl9
                                dblNatCustomDbl10
                                dtNatCustomDt1
                                dtNatCustomDt2
                                dtNatCustomDt3
                                dtNatCustomDt4
                                dtNatCustomDt5
                                intNatCustomLU1
                                intNatCustomLU2
                                intNatCustomLU3
                                intNatCustomLU4
                                intNatCustomLU5
                                intNatCustomLU6
                                intNatCustomLU7
                                intNatCustomLU8
                                intNatCustomLU9
                                intNatCustomLU10
                                intNatCustomBool1

                                intNatCustomBool2
                                intNatCustomBool3
                                intNatCustomBool4
                                intNatCustomBool5

                                strCustomStr1
                                strCustomStr2
                                strCustomStr3
                                strCustomStr4
                                strCustomStr5
                                strCustomStr6
                                strCustomStr7
                                strCustomStr8
                                strCustomStr9
                                strCustomStr10
                                strCustomStr11
                                strCustomStr12
                                strCustomStr13
                                strCustomStr14
                                strCustomStr15
                                dblCustomDbl1
                                dblCustomDbl2
                                dblCustomDbl3
                                dblCustomDbl4
                                dblCustomDbl5
                                dblCustomDbl6
                                dblCustomDbl7
                                dblCustomDbl8
                                dblCustomDbl9
                                dblCustomDbl10
                                dtCustomDt1
                                dtCustomDt2
                                dtCustomDt3
                                dtCustomDt4
                                dtCustomDt5
                                intCustomLU1
                                intCustomLU2
                                intCustomLU3
                                intCustomLU4
                                intCustomLU5
                                intCustomLU6
                                intCustomLU7
                                intCustomLU8
                                intCustomLU9
                                intCustomLU10
                                intCustomBool1
                                intCustomBool2
                                intCustomBool3
                                intCustomBool4
                                intCustomBool5
                                intGradeID
                                strSchoolName
                                strSchoolSuburb
                                intFavStateTeamID
                                intFavNationalTeamID
                                intWatchSportHowOftenID
                                intAttendSportCount
                                intFavNationalTeamMember
                                strMemberNotes
                                strMemberCustomNotes1

                                strMemberCustomNotes2
                                strMemberCustomNotes3
                                strMemberCustomNotes4
                                strMemberCustomNotes5
                                strAccType
                                strAccname
                                strAccLevel
                                strAccProvider
                                dtAccStart
                                dtAccEnd
                                strCourse   
                                strAccStatus
                                strAccRA  
			)],
			Config => {
				EmailExport => 1,
				limitView  => 5000,
				EmailSenderAddress => $Defs::admin_email,
				SecondarySort => 1,
				RunButtonLabel => 'Run Report',
				ReturnProcessData => [qw(tblMember.strEmail tblMember.strPhoneMobile tblMember.strSurname tblMember.strFirstname tblMember.intMemberID)],
			},
			ExportFormats =>	{
				MeetManager =>	{
					Name => 'Meet Manager',
					Select => "strSurname, strFirstname, IF(intGender<>1,'M','F') AS Gender, DATE_FORMAT(dtDOB, '%m/%d/%Y') AS dtDOB, tblMember.strAddress1, tblMember.strAddress2, tblMember.strSuburb, tblMember.strState, tblMember.strPostalCode, tblMember.strCountry, strPassportNationality, strPhoneHome, strPhoneWork, tblMember.strFax, tblMember.strEmail",
					Order => ['I','strSurname', 'strFirstname', '', 'Gender', 'dtDOB', '','','','', 'strAddress1', 'strAddress2', 'strSuburb', 'strState', 'strPostalCode', 'strCountry', 'strPassportNationality', 'strPhoneHome', 'strPhoneWork', 'strFax', '','','','strEmail'],
					Headers => 0,
					ExportFileName => 'export.txt',
					Delimiter => ';',
				},
			},
			OptionGroups =>	{
				details=> ['Personal Details',{ active=>1}],
				contactdetails => ['Contact Details',{ }],
			    accreditation => ['Accreditation',{}],
			#	security=> ['Security',{}],
			    interests=> ['Interests',{}],
				#identifications => ['Identifications',{ }],
				#financial=> ['Financial',{}],
				#medical => ['Medical',{}],
				otherfields=> ['Other Fields',{}],
				affiliations=> ['Affiliations',{}],
				seasons=> [$txt_SeasonNames,{}],
              #   playeractivity => [$Data->{'SystemConfig'}{'AllowSWOL'} ? 'Player Activity' : '',
#                                    {
#                                     from => "INNER JOIN tblLadder ON (tblLadder.intPlayerID = tblMember.intMemberID AND intLatestStats = 1) 
#                                              INNER JOIN tblTeam AS LastPlayedTeam ON (LastPlayedTeam.intTeamID = tblLadder.intTeamID)
#                                              INNER JOIN tblClub AS LastPlayedClub ON (LastPlayedClub.intClubID = LastPlayedTeam.intClubID)
#                                              INNER JOIN tblAssoc_Comp AS LastPlayedComp ON (LastPlayedComp.intCompID = tblLadder.intCompID)"
#                                 }
              #                 ],
		},

	);
  if($SystemConfig->{'NoMemberTypes'})  {
    for my $f (qw(intPlayerActive dtLastRecordedGame intCareerGames intPlayerJunior intPlayerSenior intPlayerVeteran intCoachActive strCoachRegNo strInstrucRegNo  intCoachAccredActive strCoachAccredType strCoachAccredLevel strCoachAccredProv dtCoachAccredStart dtCoachAccredEnd intUmpireActive strUmpireRegNo intUmpireAccredActive strUmpireAccredType strUmpireAccredLevel strUmpireAccredProv dtUmpireAccredStart dtUmpireAccredEnd intOfficialAccredActive strOfficialPos strOfficialRegNo dtOfficialStart dtOfficialEnd intMiscAccredActive strMiscPos strMiscRegNo dtMiscStart dtMiscEnd strUmpireType)) {
     $config{'Fields'}{$f}[0]='';
    }
	}


	$self->{'Config'} = \%config;
}

sub SQLBuilder	{
	my($self, $OptVals, $ActiveFields) =@_ ;
	my $currentLevel = $self->{'EntityTypeID'} || 0;
	my $Data = $self->{'Data'};
	my $clientValues = $Data->{'clientValues'};
	my $SystemConfig = $Data->{'SystemConfig'};

  my $MStablename = "tblMember_Seasons_$Data->{'Realm'}";

	my $from_levels = $OptVals->{'FROM_LEVELS'};
	my $from_list = $OptVals->{'FROM_LIST'};
	my $where_levels = $OptVals->{'WHERE_LEVELS'};
	my $where_list = $OptVals->{'WHERE_LIST'};
	my $current_from = $OptVals->{'CURRENT_FROM'};
	my $current_where = $OptVals->{'CURRENT_WHERE'};
	my $select_levels = $OptVals->{'SELECT_LEVELS'};

	my $sql = '';
	{ #Work out SQL

    my $clubID = (
			$Data->{'clientValues'}{'clubID'} 
				and $Data->{'clientValues'}{'clubID'} != $Defs::INVALID_ID) 
			? $Data->{'clientValues'}{'clubID'} 
			: 0;
    #my $assocSeasonWHERE = ($from_list =~ /tblClub/) 
		#	? qq[ AND ($MStablename.intClubID>0 or MC.intMemberID IS NULL)] 
		#	: qq[ AND $MStablename.intClubID=0];

    my $assocSeasonWHERE = qq[ AND $MStablename.intClubID=0];

    $assocSeasonWHERE = ($from_list =~ /tblMember_Clubs/) 
			? qq[ AND ($MStablename.intClubID>0 or MC.intMemberID IS NULL)] 
			: $assocSeasonWHERE;

    $assocSeasonWHERE = qq[ AND $MStablename.intClubID = $clubID] if $clubID;


	if($clubID and $from_list =~ /MC/) {
		$where_list .= qq[ AND MC.intClubID = $clubID ];	
	}

    $where_list=' AND '.$where_list if $where_list and ($where_levels or $current_where);
    $where_list=~s/\sAND\s*$//g;
    $where_list =~s/AND  AND/AND /;

    my $mc_join='';
		if(
			$clubID 
			and $from_levels !~ /tblMember_Clubs/ 
			and $current_from !~ /tblMember_Clubs/ 
			and $from_list !~ /tblMember_Clubs/)	{
			$mc_join = qq[
				INNER JOIN tblMember_Clubs ON (
					tblMember.intMemberID = tblMember_Clubs.intMemberID 
					AND tblMember_Clubs.intStatus<>-1 
					AND tblMember_Clubs.intClubID = $clubID
				)
			];
		}
		my $products_join = '';
		if ($from_list =~ /tblTransactions/)	{
			$products_join = qq[ LEFT JOIN tblProducts as P ON (P.intProductID=TX.intProductID)];
		}
		my $mtWHERE = '';
		if ($from_list =~/tblTeam/ and $from_list =~/tblMember_Teams/)	{
			$mtWHERE = qq[ AND (tblTeam.intAssocID=tblMember_Associations.intAssocID OR tblMember_Teams.intTeamID IS NULL)];
		}
        my $realmID =$Data->{'Realm'};
    $sql = qq[
      SELECT ###SELECT###
      FROM $from_levels $current_from $from_list $mc_join $products_join
        INNER JOIN $MStablename ON (
					$MStablename.intMemberID = tblMember_Associations.intMemberID 
					AND $MStablename.intAssocID = tblMember_Associations.intAssocID 
					AND $MStablename.intMSRecStatus=1 
					AND IF(tblAssoc.intAllowSeasons=1, $MStablename.intSeasonID > 0, $MStablename.intSeasonID = tblAssoc.intCurrentSeasonID)
				)
	LEFT JOIN tblRegoForm ON $MStablename.intUsedRegoFormID = tblRegoForm.intRegoFormID
        INNER JOIN tblSeasons as S ON (
					S.intSeasonID = $MStablename.intSeasonID
          AND S.intAssocID IN (0, $Data->{'clientValues'}{'assocID'})
         )
        LEFT JOIN tblAccreditation AS A ON (A.intMEmberID =tblMember.intMemberID 
                                            AND A.intRealmID = $realmID
                                            AND A.intRecStatus <> -1
                                            )
        LEFT JOIN tblQualification AS Q ON (A.intQualificationID = Q.intQualificationID)
        LEFT JOIN tblDefCodes AS LEVEL ON (LEVEL.intCodeID = A.intLevel)
        LEFT JOIN tblDefCodes AS PROVIDER ON (PROVIDER.intCodeID = A.intProvider)
        LEFT JOIN tblDefCodes AS STATUS ON (STATUS.intCodeID = A.intStatus)
        LEFT JOIN tblDefCodes AS TYPE ON (TYPE.intCodeID = Q.intType)
      WHERE  $where_levels $current_where $where_list $assocSeasonWHERE $mtWHERE
		];

		#print STDERR $sql;
		return ($sql,'');
	}
}


1;
