#
# $Header: svn://svn/SWM/trunk/web/Reports/ReportAdvanced_MemberSummary.pm 8251 2013-04-08 09:00:53Z rlee $
#

package Reports::ReportAdvanced_MemberSummary;

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
			Seasons => 1,
			FieldLabels => 1,
			AgeGroups => 1,
			EntityCategories =>1,
		},
	);
	my $hideSeasons = $CommonVals->{'Seasons'}{'Hide'} || 0;

	my $FieldLabels = $CommonVals->{'FieldLabels'} || undef;

  my $txt_SeasonName= $Data->{'SystemConfig'}{'txtSeason'} || 'Season';
  my $txt_SeasonNames= $Data->{'SystemConfig'}{'txtSeasons'} || 'Seasons';
  my $txt_AgeGroupName= $Data->{'SystemConfig'}{'txtAgeGroup'} || 'Age Group';
  my $txt_AgeGroupNames= $Data->{'SystemConfig'}{'txtAgeGroups'} || 'Age Groups';
  my $txt_MiscName = $Data->{'SystemConfig'}{'txtMiscName'} || 'Misc';
  my $officialName = $Data->{'SystemConfig'}{'TYPE_NAME_4'} || 'Official';

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

  my $MStablename = "tblMember_Seasons_$Data->{'Realm'}";

	my %config = (
		Name => 'Member Summary Report',

		StatsReport => 1,
		MemberTeam => 0,
		ReportEntity => 1,
		ReportLevel => 0,
		#Template => 'default_adv_CSV',
		Template => 'default_adv',
    TemplateEmail => 'default_adv_CSV',
		DistinctValues => 1,

		SQLBuilder => \&SQLBuilder,
		Fields => {
			intSeasonID=> ["$txt_SeasonName",{displaytype=>'lookup', fieldtype=>'dropdown', dropdownoptions => $CommonVals->{'Seasons'}{'Options'},  dropdownorder=>$CommonVals->{'Seasons'}{'Order'}, allowsort=>1, active=>0, multiple=>1, size=>3, dbfield=>"$MStablename.intSeasonID", disable=>$hideSeasons }],
			strZoneName=> [($currentLevel > $Defs::LEVEL_ZONE ? $Data->{'LevelNames'}{$Defs::LEVEL_ZONE}.' Name' : ''),{displaytype=>'text', fieldtype=>'text', allowsort=>1, active=>1, dbfield => "IF(tblZone.intStatusID = $Defs::NODE_SHOW, tblZone.strName,'')", allowgrouping=>1}],
			strRegionName=> [($currentLevel > $Defs::LEVEL_REGION ? $Data->{'LevelNames'}{$Defs::LEVEL_REGION}.' Name' : ''),{displaytype=>'text', fieldtype=>'text', allowsort=>1, active=>1, dbfield => "IF(tblRegion.intStatusID = $Defs::NODE_SHOW, tblRegion.strName,'')", allowgrouping=>1}],
			strStateName=> [($currentLevel > $Defs::LEVEL_STATE ? $Data->{'LevelNames'}{$Defs::LEVEL_STATE}.' Name' : ''),{displaytype=>'text', fieldtype=>'text', allowsort=>1, active=>1, dbfield => "IF(tblState.intStatusID = $Defs::NODE_SHOW, tblState.strName,'')", allowgrouping=>1}],
			strNationalName=> [($currentLevel > $Defs::LEVEL_NATIONAL ? $Data->{'LevelNames'}{$Defs::LEVEL_NATIONAL}.' Name' : ''),{displaytype=>'text', fieldtype=>'text', allowsort=>1, active=>1, dbfield => "IF(tblNational.intStatusID = $Defs::NODE_SHOW, tblNational.strName,'')", allowgrouping=>1}],        strIntZoneName=> [($currentLevel > $Defs::LEVEL_INTZONE ? $Data->{'LevelNames'}{$Defs::LEVEL_INTZONE}.' Name' : ''),{displaytype=>'text', fieldtype=>'text', allowsort=>1, active=>1, dbfield => "IF(tblIntZone.intStatusID = $Defs::NODE_SHOW, tblIntZone.strName,'')" , allowgrouping=>1}],
			strIntRegionName=> [($currentLevel > $Defs::LEVEL_INTREGION ? $Data->{'LevelNames'}{$Defs::LEVEL_INTREGION}.' Name' : ''),{displaytype=>'text', fieldtype=>'text', allowsort=>1, active=>1, dbfield => " IF(tblIntRegion.intStatusID = $Defs::NODE_SHOW, tblIntRegion.strName,'') ", allowgrouping=>1}],
			strAssocName=> [($currentLevel > $Defs::LEVEL_ASSOC ? $Data->{'LevelNames'}{$Defs::LEVEL_ASSOC}.' Name' : ''),{displaytype=>'text', fieldtype=>'text', active=>1, allowsort=>1, dbfield => 'tblAssoc.strName', allowgrouping=>1}],
			intAssocTypeID=> [((scalar(keys %{$CommonVals->{'SubRealms'}}) and  $currentLevel > $Defs::LEVEL_ASSOC)? ($Data->{'LevelNames'}{$Defs::LEVEL_ASSOC}.' Type') : ''),{displaytype=>'lookup', fieldtype=>'dropdown', dropdownoptions=> $CommonVals->{'SubRealms'}, allowsort=>1, filteronly=>0}],
			intAssocCategoryID=> [($currentLevel > $Defs::LEVEL_ASSOC and ! scalar(keys %{$CommonVals->{'EntityCategories'}{$Defs::LEVEL_ASSOC}})) ? '' : ($Data->{'LevelNames'}{$Defs::LEVEL_ASSOC}||'').' Category',{displaytype=>'lookup', fieldtype=>'dropdown', dropdownoptions=> $CommonVals->{'EntityCategories'}{$Defs::LEVEL_ASSOC}, allowsort=>1,allowgrouping=>1}],
			strClubName=> [$Data->{'SystemConfig'}{'NoClubs'} ? '' : ($Data->{'LevelNames'}{$Defs::LEVEL_CLUB}||'').' Name',{displaytype=>'text', fieldtype=>'text', allowsort=>1, dbfield => 'tblClub.strName', allowgrouping=>1, dbfrom=>" LEFT JOIN tblMember_Clubs ON (tblMember.intMemberID=tblMember_Clubs.intMemberID  AND tblMember_Clubs.intStatus=$Defs::RECSTATUS_ACTIVE ) LEFT JOIN tblAssoc_Clubs ON (tblAssoc_Clubs.intClubID = tblMember_Clubs.intClubID AND tblAssoc_Clubs.intAssocID=tblAssoc.intAssocID) LEFT JOIN tblClub ON (tblAssoc_Clubs.intClubID = tblClub.intClubID) "}],
			intClubCategoryID=> [(! $Data->{'SystemConfig'}{'NoClubs'} and scalar(keys %{$CommonVals->{'EntityCategories'}{$Defs::LEVEL_CLUB}}))? ($Data->{'LevelNames'}{$Defs::LEVEL_CLUB}||'').' Category' : '',{displaytype=>'lookup', fieldtype=>'dropdown', dropdownoptions=> $CommonVals->{'EntityCategories'}{$Defs::LEVEL_CLUB}, allowsort=>1, allowgrouping=>1, dbfrom=>" LEFT JOIN tblMember_Clubs ON (tblMember.intMemberID=tblMember_Clubs.intMemberID  AND tblMember_Clubs.intStatus=$Defs::RECSTATUS_ACTIVE ) LEFT JOIN tblAssoc_Clubs ON (tblAssoc_Clubs.intClubID = tblMember_Clubs.intClubID AND tblAssoc_Clubs.intAssocID=tblAssoc.intAssocID) LEFT JOIN tblClub ON (tblAssoc_Clubs.intClubID = tblClub.intClubID) "}],
			strTeamName=> [$Data->{'SystemConfig'}{'NoTeams'} ? '' : ($Data->{'LevelNames'}{$Defs::LEVEL_TEAM}||'').' Name',{displaytype=>'text', fieldtype=>'text', active=>0, allowsort=>1, dbfield => 'tblTeam.strName', allowgrouping=>1}],
			strTeamContact=> [$Data->{'SystemConfig'}{'NoTeams'} ? '' : ($Data->{'LevelNames'}{$Defs::LEVEL_TEAM}||'').' Contact Person',{displaytype=>'text', fieldtype=>'text', allowsort=>1, dbfield => 'tblTeam.strContact'}],
			strTeamEmail=> [$Data->{'SystemConfig'}{'NoTeams'} ? '' : ($Data->{'LevelNames'}{$Defs::LEVEL_TEAM}||'').' Email',{displaytype=>'text', fieldtype=>'text', allowsort=>1, dbfield => 'tblTeam.strEmail'}],
			TeamintRecStatus=> ['Team Active ?',{displaytype=>'lookup', fieldtype=>'dropdown', filteronly=>1, dropdownoptions=>{0=>'No', 1=>'Yes'}, dropdownorder=>[0,1], dbfield=>'tblMember_Teams.intStatus'}],
			strCompName => [$Data->{'SystemConfig'}{'NoComps'} ? '' : ($Data->{'LevelNames'}{$Defs::LEVEL_COMP}||'').' Name',{displaytype=>'text', fieldtype=>'text', allowsort=>1, dbfield=>"tblAssoc_Comp.strTitle", allowgrouping=>1}],
			intCompLevelID=> [($NRO{'RepCompLevel'} and $Data->{'SystemConfig'}{'NoComps'}) ? '' : ($Data->{'LevelNames'}{$Defs::LEVEL_COMP}||'').' Level' ,{displaytype=>'lookup', fieldtype=>'dropdown', dropdownoptions=>$CommonVals->{'DefCodes'}{-21}, allowgrouping=>1}],
			intNewSeasonID=> [$Data->{'SystemConfig'}{'NoComps'} ? '' : ($Data->{'LevelNames'}{$Defs::LEVEL_COMP}||'')." $txt_SeasonName",{displaytype=>'lookup', fieldtype=>'dropdown', dropdownoptions => $CommonVals->{'Seasons'}{'Options'},  dropdownorder=>$CommonVals->{'Seasons'}{'Order'}, allowsort=>1, active=>0, multiple=>1, size=>3, allowgrouping=>1,dbfield=>"tblAssoc_Comp.intNewSeasonID", disable=>$hideSeasons }],
			CompRecStatus=> [$Data->{'SystemConfig'}{'NoComps'} ? '' : ($Data->{'LevelNames'}{$Defs::LEVEL_COMP}||'')." Active ?",{displaytype=>'lookup', fieldtype=>'dropdown', filteronly=>1, dropdownoptions=>{0=>'No', 1=>'Yes'}, dropdownorder=>[0,1], dbfield=>'tblAssoc_Comp.intRecStatus'}],
			CompAgeGroupID=> [($NRO{'RepCompLevel'} and $Data->{'SystemConfig'}{'NoComps'}) ? '' : ($Data->{'LevelNames'}{$Defs::LEVEL_COMP}||''). " Default $txt_AgeGroupName",{displaytype=>'lookup', fieldtype=>'dropdown', dropdownoptions => $CommonVals->{'AgeGroups'}{'Options'},  dropdownorder=>$CommonVals->{'AgeGroups'}{'Order'}, allowsort=>1, allowgrouping=>1, multiple=>1, size=>3, dbfield=>"tblAssoc_Comp.intAgeGroupID"}],

## TC HERE
        CompintRecStatus=> ['Competition Active ?',{displaytype=>'lookup', fieldtype=>'dropdown', filteronly=>1, dropdownoptions=>{0=>'No', 1=>'Yes'}, dropdownorder=>[0,1], dbfield=>'tblAssoc_Comp.intRecStatus'}],

        numMembers=> ["Number of Members",{displaytype=>'none', fieldtype=>'text', active=>1, dbfield => 'COUNT(DISTINCT tblMember.intMemberID)', total=>1, allowsort=>1, sortfield=>'numMembers', usehaving => 1}],
        numActive=> ["Number of Active Members",{displaytype=>'none', fieldtype=>'text', active=>1, dbfield => "COUNT( DISTINCT IF(tblMember_Associations.intRecStatus = $Defs::RECSTATUS_ACTIVE, tblMember_Associations.intMemberID,NULL))", total=>1, allowsort=>1, sortfield=>'numActive', usehaving => 1}],
        numPlayers=> ["Number of Players in $txt_SeasonName",{displaytype=>'none', fieldtype=>'text', active=>1, dbfield => "COUNT( DISTINCT IF(intPlayerStatus=$Defs::RECSTATUS_ACTIVE, tblMember.intMemberID, NULL))", total=>1, usehaving => 1}],
        numPlayersActive=> ["Number of Active Players",{displaytype=>'none', fieldtype=>'text', active=>1, dbfield => "COUNT( DISTINCT IF(tblMT_Player.intActive=$Defs::RECSTATUS_ACTIVE, tblMember.intMemberID, NULL))", total=>1, dbfrom => "LEFT JOIN tblMember_Types AS tblMT_Player ON (tblMember.intMemberID=tblMT_Player.intMemberID AND tblMT_Player.intTypeID=$Defs::MEMBER_TYPE_PLAYER AND tblMember_Associations.intRecStatus=$Defs::RECSTATUS_ACTIVE AND tblMT_Player.intSubTypeID=0 AND tblMT_Player.intRecStatus = $Defs::RECSTATUS_ACTIVE)", usehaving => 1 }],

        numCoaches=> ["Number of Coaches in $txt_SeasonName",{displaytype=>'none', fieldtype=>'text', active=>1, dbfield => "COUNT( DISTINCT IF(intCoachStatus=$Defs::RECSTATUS_ACTIVE, tblMember.intMemberID, NULL))", total=>1, usehaving => 1}],
        numCoachActive=> ["Number of Active Coaches",{displaytype=>'none', fieldtype=>'text', active=>1, dbfield => "COUNT( DISTINCT IF(tblMT_Coach.intActive=$Defs::RECSTATUS_ACTIVE, tblMember.intMemberID, NULL))", total=>1, dbfrom => "LEFT JOIN tblMember_Types AS tblMT_Coach ON (tblMember.intMemberID=tblMT_Coach.intMemberID AND tblMT_Coach.intTypeID=$Defs::MEMBER_TYPE_COACH  AND tblMember_Associations.intRecStatus=$Defs::RECSTATUS_ACTIVE AND tblMT_Coach.intSubTypeID=0 AND tblMT_Coach.intRecStatus = $Defs::RECSTATUS_ACTIVE)", usehaving => 1 }],
        numUmpires=> ["Number of Match Officials in $txt_SeasonName",{displaytype=>'none', fieldtype=>'text', active=>1, dbfield => "COUNT( DISTINCT IF(intUmpireStatus=$Defs::RECSTATUS_ACTIVE, tblMember.intMemberID, NULL))", total=>1, usehaving => 1}],
        numUmpireActive=> ["Number of Active Match Officials",{displaytype=>'none', fieldtype=>'text', active=>1, dbfield => "COUNT( DISTINCT IF(tblMT_Umpire.intActive=$Defs::RECSTATUS_ACTIVE, tblMember.intMemberID, NULL))", total=>1, dbfrom => "LEFT JOIN tblMember_Types AS tblMT_Umpire ON (tblMember.intMemberID=tblMT_Umpire.intMemberID AND tblMT_Umpire.intTypeID=$Defs::MEMBER_TYPE_UMPIRE  AND tblMember_Associations.intRecStatus=$Defs::RECSTATUS_ACTIVE AND tblMT_Umpire.intSubTypeID=0 AND tblMT_Umpire.intRecStatus = $Defs::RECSTATUS_ACTIVE)", usehaving => 1 }],
        numOfficials=> ["Number of Officials",{displaytype=>'none', fieldtype=>'text', active=>1, dbfield => "COUNT( DISTINCT IF(tblMember.intOfficial=$Defs::RECSTATUS_ACTIVE, tblMember.intMemberID, NULL))", total=>1, usehaving => 1}],
        numMisc=> ["Number of Miscellaneous",{displaytype=>'none', fieldtype=>'text', active=>1, dbfield => "COUNT( DISTINCT IF(tblMember.intMisc=$Defs::RECSTATUS_ACTIVE, tblMember.intMemberID, NULL))", total=>1, usehaving => 1}],
        numVolunteer=> ["Number of Volunteers",{displaytype=>'none', fieldtype=>'text', active=>1, dbfield => "COUNT( DISTINCT IF(tblMember.intVolunteer=$Defs::RECSTATUS_ACTIVE, tblMember.intMemberID, NULL))", total=>1, usehaving => 1}],
        dtDOB=> ['Date of Birth',{displaytype=>'date', fieldtype=>'date', dbfield=>'tblMember.dtDOB', dbformat=>' DATE_FORMAT(tblMember.dtDOB,"%d/%m/%Y")', filteronly=>1, uusehaving => 1}],
        MemberEmail=> ['Email',{displaytype=>'date', fieldtype=>'text', dbfield=>'tblMember.strEmail', filteronly=>1, uusehaving => 1}],
        MemberPostCode=> ['Postal Code',{displaytype=>'date', fieldtype=>'text', dbfield=>'tblMember.strPostalCode', filteronly=>1, uusehaving => 1}],
        intGender=> ['Gender',{displaytype=>'lookup', fieldtype=>'dropdown', dropdownoptions=>{''=>'&nbsp;', 1=>'Male', 2=>'Female'}, dropdownorder=>['',1,2], size=>3, multiple=>1, filteronly=>1}],
				intPermit => [((!$SystemConfig->{'NoClubs'} and $currentLevel > $Defs::LEVEL_CLUB)? 'On Permit' :''),{displaytype=>'lookup', fieldtype=>'dropdown', dropdownoptions=>{0=>'No', 1=>'Yes'}, dropdownorder=>[0,1], allowsort=>1, dbfield=>"MC.intPermit", dbfrom=>"LEFT JOIN tblMember_Clubs AS MC ON (tblMember.intMemberID=MC.intMemberID  AND MC.intStatus=$Defs::RECSTATUS_ACTIVE)", filteronly=>1}],

     dtDateCreatedOnline=> [
        'Date Created Online',
        {
          displaytype=>'date',
          fieldtype=>'date',
          dbfield=>'tblMember.dtCreatedOnline',
          filteronly=>1,
          uusehaving => 1
        }
      ],

        ## ARLD CHANGE FOR QRL - ADDED 13/06/08
        ## ACTIVATED BY ADD IN A SYSCONFIG VALUE intPrimaryClub_Filter TO MAKE IT APPEAR
        intPrimaryClub=> [$Data->{'SystemConfig'}{'intPrimaryClub_Filter'} || '',{displaytype=>'lookup', fieldtype=>'dropdown', dropdownoptions=>{1=>'Yes', 0=>'No'}, dropdownorder=>[1,0], size=>2, filteronly=>1, dbfield=>'tblMember_Clubs.intPrimaryClub', dbfrom=>" LEFT JOIN tblMember_Clubs ON (tblMember.intMemberID=tblMember_Clubs.intMemberID  AND tblMember_Clubs.intStatus=$Defs::RECSTATUS_ACTIVE ) LEFT JOIN tblClub ON (tblMember_Clubs.intClubID = tblClub.intClubID) INNER JOIN tblAssoc_Clubs ON (tblAssoc_Clubs.intAssocID=tblAssoc.intAssocID AND tblAssoc_Clubs.intClubID=tblClub.intClubID) "}],
        intMailingList=> [($Data->{'SystemConfig'}{'SystemForEvent'} ? '' : 'Mailing List'),{displaytype=>'lookup', fieldtype=>'dropdown', dropdownoptions=>{''=>'&nbsp;', 0=>'No', 1=>'Yes'}, dropdownorder=>['',0,1], size=>3, multiple=>1, filteronly=>0, allowgrouping=>1}],
        strSchoolName => [($Data->{'SystemConfig'}{'rptSchools'} or $Data->{'SystemConfig'}{'Schools'}) ? 'School Name' : '',{displaytype=>'text', fieldtype=>'text', allowsort=>1, dbfield=>'tblSchool.strName', dbfrom=>'LEFT JOIN tblSchool ON (tblMember.intSchoolID = tblSchool.intSchoolID)', allowgrouping=>1}],
        strSchoolSuburb => [($Data->{'SystemConfig'}{'rptSchools'} or $Data->{'SystemConfig'}{'Schools'}) ? 'School Suburb' : '',{displaytype=>'text', fieldtype=>'text', allowsort=>1, dbfield=>'tblSchool.strSuburb', dbfrom=>'LEFT JOIN tblSchool ON (tblMember.intSchoolID = tblSchool.intSchoolID)', allowgrouping=>1}],

        intFavNationalTeamID=> [($Data->{'SystemConfig'}{'SystemForEvent'} ? '' :$natteamname.' Supported'),{displaytype=>'lookup', fieldtype=>'dropdown', dropdownoptions=>$CommonVals->{'DefCodes'}{-34}, allowgrouping=>1}],
      intCategory=> [$SystemConfig->{'SystemForEvent'} ? 'Accreditation Category' : '',{displaytype=>'text', fieldtype=>'text', allowsort=>1, dbfield=>"CONCAT(tblEventCategories.strCategory, ' / ', tblEventCategories.strPopulation)", dbfrom => "LEFT JOIN tblEventSelections AS ES ON (tblMember.intMemberID=ES.intMemberID)
                    LEFT JOIN tblEventCategories ON (tblEventCategories.intEventCategoriesID=ES.intAccredCatID)"}],

			},

			Order => [qw( 
				CompintRecStatus
				intSeasonID
				strIntRegionName
				strIntZoneName
				strNationalName
				strStateName
				strRegionName
				strZoneName
				strAssocName
				intAssocTypeID
				intAssocCategoryID
				strClubName
				intClubCategoryID
				strTeamName
				strCompName
				CompAgeGroupID
				intCompLevelID
				intNewSeasonID
				CompRecStatus
				numMembers
				numActive
				numPlayers
				numCoaches
				numUmpires
				numOfficials
				numMisc
				numVolunteer
				intPlayerAgeGroupID
				dtDOB
				intGender
				MemberEmail
				MemberPostCode
				intPermit
				intPrimaryClub
				intMailingList
				strSchoolName
				strSchoolSuburb
				intFavNationalTeamID
				intCategory
				dtDateCreatedOnline
			)],
			Config => {
				EmailExport => 1,
				limitView  => 5000,
				EmailSenderAddress => $Defs::admin_email,
				SecondarySort => 1,
				RunButtonLabel => 'Run Report',
        NoSummaryData => 1,
			},
			OptionGroups =>	{
				default => ['Details',{}],
			},

	);
  if($SystemConfig->{'NoMemberTypes'})  {
		for my $f (qw( strClubName strTeamName strCompName intCompLevelID intNewSeasonID CompRecStatus CompAgeGroupID numPlayers numCoaches numUmpires numOfficials numMisc)) {
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
	my $having_list = $OptVals->{'HAVING_LIST'};

	my $sql = '';
	{ #Work out SQL

   	my @grouping = (); 
    push @grouping, 'tblIntRegion.strName' if ($currentLevel > $Defs::LEVEL_INTREGION and $ActiveFields->{'strIntRegionName'});
    push @grouping, 'tblIntZone.strName' if ($currentLevel > $Defs::LEVEL_INTZONE and $ActiveFields->{'strIntZoneName'});
    push @grouping, 'tblNational.strName' if ($currentLevel > $Defs::LEVEL_NATIONAL and $ActiveFields->{'strNationalName'});
    push @grouping, 'tblState.strName' if ($currentLevel > $Defs::LEVEL_REGION and $ActiveFields->{'strStateName'});
    push @grouping, 'tblRegion.strName' if ($currentLevel > $Defs::LEVEL_ZONE and $ActiveFields->{'strRegionName'});
    push @grouping, 'tblZone.strName' if ($currentLevel > $Defs::LEVEL_ASSOC and $ActiveFields->{'strZoneName'});
    push @grouping, 'strAssocName' if $ActiveFields->{'strAssocName'};
    push @grouping, 'strClubName' if $ActiveFields->{'strClubName'};
    push @grouping, 'strTeamName' if $ActiveFields->{'strTeamName'};
    push @grouping, 'intMailingList' if $ActiveFields->{'intMailingList'};
    push @grouping, 'strSchoolName' if $ActiveFields->{'strSchoolName'};
    push @grouping, 'strSchoolSuburb' if $ActiveFields->{'strSchoolSuburb'};
    push @grouping, 'intFavNationalTeamID' if $ActiveFields->{'intFavNationalTeamID'};
    push @grouping, 'intAssocTypeID' if $ActiveFields->{'intAssocTypeID'};
    push @grouping, 'tblAssoc_Comp.intCompLevelID' if $ActiveFields->{'intCompLevelID'};
    push @grouping, 'tblAssoc_Comp.intNewSeasonID' if $ActiveFields->{'intNewSeasonID'};
    push @grouping, 'tblAssoc_Comp.intRecStatus' if $ActiveFields->{'CompRecStatus'};
    push @grouping, 'tblAssoc_Comp.intAgeGroupID ' if $ActiveFields->{'CompAgeGroupID'};
    push @grouping, 'tblAssoc_Comp.strTitle' if $ActiveFields->{'strCompName'};
    push @grouping, 'intCategory' if $ActiveFields->{'intCategory'};
    push @grouping, 'intSeasonID' if $ActiveFields->{'intSeasonID'};
    push @grouping, 'intPlayerAgeGroupID' if $ActiveFields->{'intPlayerAgeGroupID'};
    my $cname=$ActiveFields->{'strClubName'} ? ', tblClub.strName' : '';
    my $tname=$ActiveFields->{'strTeamName'} ? ', strTeamName' : '';
    my $cmpname=$ActiveFields->{'strCompName'} ? ', tblAssoc_Comp.strTitle ' : '';
    my $cmplname=$ActiveFields->{'intCompLevelID'} ? ', tblAssoc_Comp.intCompLevelID ' : '';
    my $cmpseason=$ActiveFields->{'intNewSeasonID'} ? ', tblAssoc_Comp.intNewSeasonID' : '';
    my $cmpactive=$ActiveFields->{'CompRecStatus'} ? ', tblAssoc_Comp.intRecStatus' : '';
    my $cmpagegrp=$ActiveFields->{'CompAgeGroupID'} ? ', tblAssoc_Comp.intAgeGroupID ' : '';
    my $memberteam=($tname or $cmpname or $cmplname or $cmpagegrp or $cmpseason or $cmpactive)? 1 : 0;

    my $grp_line=join(',',@grouping) || '';
    $grp_line="GROUP BY $grp_line" if $grp_line;
    $where_list=' AND '.$where_list if $where_list and ($where_levels or $current_where);

    $where_list =~s/AND  AND/AND /;
    $having_list||='';
    $having_list = "HAVING $having_list " if $having_list;

    my $assocSeasonWHERE = ($from_list =~ /tblClub/) 
			? qq[ AND $MStablename.intClubID>0 AND $MStablename.intClubID=tblAssoc_Clubs.intClubID ] 
			: qq[ AND $MStablename.intClubID=0 ];
    my $compTeamsWHERE = (
			$from_list =~ /tblComp_Teams/ 
				or $from_levels =~  /tblComp_Teams/ 
				or $current_from =~ /tblComp_Teams/
			) 
				? qq[ AND tblComp_Teams.intRecStatus IN (0,1) ] 
				: '';
    $sql = qq[
      SELECT ###SELECT###
      FROM $from_levels $current_from
        INNER JOIN $MStablename ON (
					$MStablename.intMemberID = tblMember_Associations.intMemberID 
						AND $MStablename.intAssocID = tblMember_Associations.intAssocID 
						AND $MStablename.intMSRecStatus = 1
				)
        INNER JOIN tblSeasons as S ON (
					S.intSeasonID = $MStablename.intSeasonID
						AND S.intAssocID IN (0, $Data->{'clientValues'}{'assocID'})
        )
        $from_list
      WHERE  $where_levels $current_where $where_list $assocSeasonWHERE $compTeamsWHERE
      $grp_line
      $having_list
    ];
		return ($sql,'');
	}
}

sub afterSubmission {
  my $self = shift;
	my $ActiveFields = $self->{'RunParams'}{'ActiveFields'};

	my $tname=$ActiveFields->{'strTeamName'} ? ', strTeamName' : '';
	my $cmpname=$ActiveFields->{'strCompName'} ? ', tblAssoc_Comp.strTitle ' : '';
	my $cmplname=$ActiveFields->{'intCompLevelID'} ? ', tblAssoc_Comp.intCompLevelID ' : '';
	my $cmpseason=$ActiveFields->{'intNewSeasonID'} ? ', tblAssoc_Comp.intNewSeasonID' : '';
	my $cmpactive=$ActiveFields->{'CompRecStatus'} ? ', tblAssoc_Comp.intRecStatus' : '';
	my $cmpagegrp=$ActiveFields->{'CompAgeGroupID'} ? ', tblAssoc_Comp.intAgeGroupID ' : '';
	my $memberteam=($tname or $cmpname or $cmplname or $cmpagegrp or $cmpseason or $cmpactive)? 1 : 0;

	if($memberteam)	{
		$self->{'Config'}{'MemberTeam'} = 1;
	}
  return undef;
}


1;
