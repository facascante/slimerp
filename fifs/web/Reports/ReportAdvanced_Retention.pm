#
# $Header: svn://svn/SWM/trunk/web/Reports/ReportAdvanced_Retention.pm 8251 2013-04-08 09:00:53Z rlee $
#

package Reports::ReportAdvanced_Retention;

use strict;
use lib ".","..";
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

  my $natnumname=$Data->{'SystemConfig'}{'NationalNumName'} || 'National Number';

  my $CommonVals = getCommonValues(
    $Data,
    {
      SubRealms => 1,
      Countries => 1,
      Seasons => 1,
      FieldLabels => 1,
			EntityCategories => 1,
    },
  );
  my $hideSeasons = $CommonVals->{'Seasons'}{'Hide'} || 0;


	my $preblock = '';
	{

    my $season1 = drop_down(
      '_EXTseason1',
			$CommonVals->{'Seasons'}{'Options'},
			$CommonVals->{'Seasons'}{'Order'},
			$CommonVals->{'Seasons'}{'Order'},
      1,
      0,
      ''
    );
    my $season2 = drop_down(
      '_EXTseason2',
			$CommonVals->{'Seasons'}{'Options'},
			$CommonVals->{'Seasons'}{'Order'},
			$CommonVals->{'Seasons'}{'Order'},
      1,
      0,
      ''
    );
    my $inornot = drop_down(
      '_EXTinornot',
      { in => 'IN', notin => 'NOT IN'},
      undef,
      'in',
      1,
      0,
      ''
    );

		$preblock = qq[
      <div style="margin:10px 0px;font-weight:bold;"> Where member in $season1 and $inornot $season2</div>
		];
	}

	my %config = (
		Name => 'Retention Report',

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
			strClubName => [
				$Data->{'LevelNames'}{$Defs::LEVEL_CLUB}.' Name',
				{
					enabled => (
						(!$SystemConfig->{'NoClubs'} 
						or $Data->{'Permissions'}{$Defs::CONFIG_OTHEROPTIONS}{'ShowClubs'}) 
						and $currentLevel > $Defs::LEVEL_CLUB 
					),
					displaytype=>'text',
					fieldtype=>'text',
					allowsort=>1,
					dbfield=>"tblClub.strName",
					dbfrom=>"
						LEFT JOIN tblMember_Clubs ON (
							tblMember.intMemberID=tblMember_Clubs.intMemberID  
								AND tblMember_Clubs.intStatus=$Defs::RECSTATUS_ACTIVE
						) 
						LEFT JOIN tblClub ON (
							tblClub.intClubID=tblMember_Clubs.intClubID 
						) 
						LEFT JOIN tblAssoc_Clubs ON (
							tblAssoc_Clubs.intAssocID=tblAssoc.intAssocID 
							AND tblAssoc_Clubs.intClubID=tblClub.intClubID
						)
					",
					optiongroup=>'affiliations',
					allowgrouping=>1,
			 }
			],
			intClubCategoryID=> [
				$Data->{'LevelNames'}{$Defs::LEVEL_CLUB}.' Category',
				{
					enabled => (
						(!$SystemConfig->{'NoClubs'} 
						or $Data->{'Permissions'}{$Defs::CONFIG_OTHEROPTIONS}{'ShowClubs'}) 
						and $currentLevel > $Defs::LEVEL_CLUB 
						and scalar(keys %{$CommonVals->{'EntityCategories'}{$Defs::LEVEL_CLUB}})
					),
					displaytype=>'lookup', 
					fieldtype=>'dropdown', 
					dropdownoptions=> $CommonVals->{'EntityCategories'}{$Defs::LEVEL_CLUB},
					allowsort=>1,
					dbfrom=>"
						LEFT JOIN tblMember_Clubs ON (
							tblMember.intMemberID=tblMember_Clubs.intMemberID  
								AND tblMember_Clubs.intStatus=$Defs::RECSTATUS_ACTIVE
						) 
						LEFT JOIN tblClub ON (
							tblClub.intClubID=tblMember_Clubs.intClubID 
						) 
						LEFT JOIN tblAssoc_Clubs ON (
							tblAssoc_Clubs.intAssocID=tblAssoc.intAssocID 
							AND tblAssoc_Clubs.intClubID=tblClub.intClubID
						)
					",
					optiongroup=>'affiliations',
					allowgrouping=>1,
			 }
			],

        strAssocName => [($clientValues->{assocID}!=-1 ? '' : $Data->{'LevelNames'}{$Defs::LEVEL_ASSOC}.' Name'),{displaytype=>'text', fieldtype=>'text', allowsort=>1, active=>1, dbfield=>'tblAssoc.strName', allowgrouping => 1, optiongroup=>'affiliations',}],
        intAssocTypeID => [((scalar(keys %{$CommonVals->{'SubRealms'}}) and  $currentLevel > $Defs::LEVEL_ASSOC)? ($Data->{'LevelNames'}{$Defs::LEVEL_ASSOC}.' Type') : ''),{displaytype=>'lookup', fieldtype=>'dropdown', dropdownoptions=> $CommonVals->{'SubRealms'}, allowsort=>1, allowgrouping => 1, optiongroup=>'affiliations',}],
        intAssocCategoryID => [((scalar(keys %{$CommonVals->{'EntityCategories'}{$Defs::LEVEL_CLUB}}) and  $currentLevel > $Defs::LEVEL_ASSOC)? ($Data->{'LevelNames'}{$Defs::LEVEL_ASSOC}.' Category') : ''),{displaytype=>'lookup', fieldtype=>'dropdown', dropdownoptions=> $CommonVals->{'EntityCategories'}{$Defs::LEVEL_ASSOC}, allowsort=>1, allowgrouping => 1, optiongroup=>'affiliations',}],
        strZoneName => [($currentLevel > $Defs::LEVEL_ZONE ? $Data->{'LevelNames'}{$Defs::LEVEL_ZONE}.' Name' : ''),{displaytype=>'text', fieldtype=>'text', allowsort=>1, dbfield => "IF(tblZone.intStatusID = $Defs::NODE_SHOW, tblZone.strName,'')", allowgrouping=>1, active=>1, optiongroup=>'affiliations',}],
        strRegionName => [($currentLevel > $Defs::LEVEL_REGION ? $Data->{'LevelNames'}{$Defs::LEVEL_REGION}.' Name' : ''),{displaytype=>'text', fieldtype=>'text', allowsort=>1, dbfield => "IF(tblRegion.intStatusID = $Defs::NODE_SHOW, tblRegion.strName,'')", allowgrouping=>1, active=>1, optiongroup=>'affiliations',}],
        strStateName => [($currentLevel > $Defs::LEVEL_STATE ? $Data->{'LevelNames'}{$Defs::LEVEL_STATE}.' Name' : ''),{displaytype=>'text', fieldtype=>'text', allowsort=>1, dbfield => "IF(tblState.intStatusID = $Defs::NODE_SHOW, tblState.strName,'')", allowgrouping=>1, active=>1, optiongroup=>'affiliations',}],
        strNationalName => [($currentLevel > $Defs::LEVEL_NATIONAL ? $Data->{'LevelNames'}{$Defs::LEVEL_NATIONAL}.' Name' : ''),{displaytype=>'text', fieldtype=>'text', allowsort=>1, dbfield => "IF(tblNational.intStatusID = $Defs::NODE_SHOW, tblNational.strName,'')", allowgrouping=>1, active=>1, optiongroup=>'affiliations',}],
        strIntZoneName => [($currentLevel > $Defs::LEVEL_INTZONE ? $Data->{'LevelNames'}{$Defs::LEVEL_INTZONE}.' Name' : ''),{displaytype=>'text', fieldtype=>'text', allowsort=>1, dbfield => "IF(tblIntZone.intStatusID = $Defs::NODE_SHOW, tblIntZone.strName,'')" , allowgrouping=>1, active=>1, optiongroup=>'affiliations',}],
        strIntRegionName => [($currentLevel > $Defs::LEVEL_INTREGION ? $Data->{'LevelNames'}{$Defs::LEVEL_INTREGION}.' Name' : ''),{displaytype=>'text', fieldtype=>'text', allowsort=>1, dbfield => " IF(tblIntRegion.intStatusID = $Defs::NODE_SHOW, tblIntRegion.strName,'') ", allowgrouping=>1, active=>1, optiongroup=>'affiliations',}],



			intPlayerStatus => [
        'Player in Season ?',
        {
          displaytype => 'lookup',
          fieldtype => 'dropdown',
          filteronly => 1,
          dropdownoptions=>{0=>'No', 1=>'Yes'},
          dropdownorder=>[0,1],
          dbfield => 'S1.intPlayerStatus = S2.intPlayerStatus AND S1.intPlayerStatus',
					optiongroup=>'types',
        }
      ],

			intCoachStatus => [
        'Coach in Season ?',
        {
          displaytype => 'lookup',
          fieldtype => 'dropdown',
          filteronly => 1,
          dropdownoptions=>{0=>'No', 1=>'Yes'},
          dropdownorder=>[0,1],
          dbfield => 'S1.intCoachStatus = S2.intCoachStatus AND S1.intCoachStatus',
					optiongroup=>'types',
        }
      ],
      intUmpireStatus => [
        'Match Official in Season ?',
        {
          displaytype => 'lookup',
          fieldtype => 'dropdown',
          filteronly => 1,
          dropdownoptions=>{0=>'No', 1=>'Yes'},
          dropdownorder=>[0,1],
          dbfield => 'S1.intUmpireStatus = S2.intUmpireStatus AND S1.intUmpireStatus',
					optiongroup=>'types',
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
			intGender
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
			strFax
			strEmail
			strEmail2
			strEmergContName
			strEmergContNo
			strEmergContNo2
			strClubName
			intClubCategoryID
      strAssocName 
      intAssocTypeID 
			intAssocCategoryID
      strZoneName 
      strRegionName 
      strStateName 
      strNationalName 
      strIntZoneName 
      strIntRegionName


			intPlayerStatus
			intCoachStatus
			intUmpireStatus
		)],
    OptionGroups => {
      details => ['Details',{}],
      contactdetails => ['Contact Details',{}],
			affiliations=> ['Affiliations',{}],
			types => ['Member Types',{}],
    },

		Config => {
			FormFieldPrefix => 'c',
			FormName => 'clearform_',
			EmailExport => 1,
			limitView  => 5000,
			EmailSenderAddress => $Defs::admin_email,
			SecondarySort => 1,
			RunButtonLabel => 'Run Report',
			ReturnProcessData => [qw(tblMember.strEmail tblMember.strPhoneMobile tblMember.strSurname tblMember.strFirstname tblMember.intMemberID)],
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

	$where_list=' AND '.$where_list if $where_list and ($where_levels or $current_where);
  $where_list=~s/\sAND\s*$//g;
  $where_list =~s/AND  AND/AND /;

  my $season1 = param('_EXTseason1') || $ActiveFields->{'_EXTseason1'} || 0;
  my $season2 = param('_EXTseason2') || $ActiveFields->{'_EXTseason2'} || 0;
  my $inornot = param('_EXTinornot') || $ActiveFields->{'_EXTinornot'} || 'in';

  my $MStablename = "tblMember_Seasons_$Data->{'Realm'}";
  my $MStablename1_alias = "S1";
  my $MStablename2_alias = "S2";
  my $clubID = (
		$Data->{'clientValues'}{'clubID'}
		and $Data->{'clientValues'}{'clubID'} != $Defs::INVALID_ID)
      ? $Data->{'clientValues'}{'clubID'}
      : 0;
  my $season1_clubwhere = '';
  my $season2_clubwhere = '';
  my $memberAssocLink1 = '';
  my $memberAssocLink2 = ''; 

  if($currentLevel<=5) {
     $memberAssocLink1 = qq[AND $MStablename1_alias.intAssocID = tblMember_Associations.intAssocID];
     $memberAssocLink2 = qq[AND $MStablename2_alias.intAssocID = tblMember_Associations.intAssocID];
  }
  if($clubID) {
    $season1_clubwhere = qq[ AND $MStablename1_alias.intClubID = $clubID ];
    $season2_clubwhere = qq[ AND $MStablename2_alias.intClubID = $clubID ];
  }
  elsif($from_list =~ /tblClub/) {
    $season1_clubwhere = qq[AND $MStablename1_alias.intClubID=tblClub.intClubID ] ;
    $season2_clubwhere = qq[AND $MStablename2_alias.intClubID=tblClub.intClubID ] ;
  }
  else  {
    $season1_clubwhere = qq[AND $MStablename1_alias.intClubID=0 ] ;
    $season2_clubwhere = qq[AND $MStablename2_alias.intClubID=0 ] ;
  }

  my $join = 'INNER';
  my $assocSeasonWHERE = '';
  if($inornot eq 'notin') {
    $join = 'LEFT';
    $assocSeasonWHERE .= qq[ AND $MStablename2_alias.intMemberSeasonID IS NULL ];
		$where_list =~ s/AND\s+S1.int\w+Status = S2.int\w+Status//g;
  }

  my $sql = '';
  { #Work out SQL

    $sql = qq[
			SELECT ###SELECT###
			FROM
				$from_levels
				$current_from
				$from_list
				INNER JOIN $MStablename AS $MStablename1_alias ON (
					$MStablename1_alias.intMemberID = tblMember_Associations.intMemberID
						$memberAssocLink1
						AND $MStablename1_alias.intMSRecStatus=1
						AND $MStablename1_alias.intSeasonID  = $season1
						$season1_clubwhere
				)
				$join JOIN $MStablename AS $MStablename2_alias ON (
					$MStablename2_alias.intMemberID = tblMember_Associations.intMemberID
						$memberAssocLink2
						AND $MStablename2_alias.intMSRecStatus=1
						AND $MStablename2_alias.intSeasonID  = $season2
						$season2_clubwhere
				)
			WHERE
				$where_levels
				$current_where
				$where_list
				$assocSeasonWHERE
				AND intDeceased <> 1
    ];
    return ($sql,'');
  }
}

1;
