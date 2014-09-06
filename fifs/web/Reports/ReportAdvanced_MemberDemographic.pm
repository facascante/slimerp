#
# $Header: svn://svn/SWM/trunk/web/Reports/ReportAdvanced_MemberDemographic.pm 9966 2013-11-27 05:28:08Z sliu $
#

package Reports::ReportAdvanced_MemberDemographic;

use strict;
use lib ".";
use ReportAdvanced_Common;
use Reg_common;
use Reports::ReportAdvanced;
our @ISA = qw(Reports::ReportAdvanced);

use strict;

sub _getConfiguration {
    my $self = shift;

    my $currentLevel = $self->{'EntityTypeID'} || 0;
    my $Data         = $self->{'Data'};
    my $clientValues = $Data->{'clientValues'};
    my $SystemConfig = $Data->{'SystemConfig'};
    my $CommonVals   = getCommonValues(
        $Data,
        {
            SubRealms        => 1,
            DefCodes         => 1,
            Countries        => 1,
            Seasons          => 1,
            FieldLabels      => 1,
            AgeGroups        => 1,
            CustomFields     => 1,
            EntityCategories => 1,
        },
    );
    my $hideSeasons = $CommonVals->{'Seasons'}{'Hide'} || 0;

    my $FieldLabels = $CommonVals->{'FieldLabels'} || undef;

    my $txt_SeasonName  = $Data->{'SystemConfig'}{'txtSeason'}  || 'Season';
    my $txt_SeasonNames = $Data->{'SystemConfig'}{'txtSeasons'} || 'Seasons';
    my $txt_AgeGroupName =
      $Data->{'SystemConfig'}{'txtAgeGroup'} || 'Age Group';
    my $txt_AgeGroupNames =
      $Data->{'SystemConfig'}{'txtAgeGroups'} || 'Age Groups';
    my $txt_MiscName = $Data->{'SystemConfig'}{'txtMiscName'} || 'Misc';
    my $officialName = $Data->{'SystemConfig'}{'TYPE_NAME_4'} || 'Official';

    my %NRO = ();
    $NRO{'Accreditation'} = (
        (
                 $clientValues->{assocID} > 0
              or $clientValues->{clubID} > 0
        )
        ? 1
        : 0
      )
      || $SystemConfig->{'RepAccred'}
      || 0;    #National Report Options
    $NRO{'RepCompLevel'} = (
        (
                 $clientValues->{assocID} > 0
              or $clientValues->{clubID} > 0
        ) ? 1 : 0
      )
      || $SystemConfig->{'RepCompLevel'}
      || 0;    #National Report Options

    my $MStablename = "tblMember_Seasons_$Data->{'Realm'}";

    my $using_member_teams = 0;
    my $selfields = $self->{'FormParams'}{'d_ROselectedfieldlist'} || '';
    if (
        $selfields
        and (  $selfields =~ /strCompName/
            or $selfields =~ /intCompLevelID/
            or $selfields =~ /strTeamName/ )
      )
    {
        $using_member_teams = 1;
    }

    my %config = (
        Name => 'Member Demographic Report',

        StatsReport => 1,
        MemberTeam  => $using_member_teams,

        ReportEntity => 1,
        ReportLevel  => 0,

        #Template => 'default_adv_CSV',
        Template       => 'default_adv',
        TemplateEmail  => 'default_adv_CSV',
        DistinctValues => 1,

        SQLBuilder => \&SQLBuilder,
        Fields     => {
            intSeasonID => [
                "$txt_SeasonName",
                {
                    displaytype     => 'lookup',
                    fieldtype       => 'dropdown',
                    dropdownoptions => $CommonVals->{'Seasons'}{'Options'},
                    dropdownorder   => $CommonVals->{'Seasons'}{'Order'},
                    allowsort       => 1,
                    active          => 0,
                    multiple        => 1,
                    size            => 3,
                    dbfield         => "$MStablename.intSeasonID",
                    disable         => $hideSeasons
                }
            ],

            MemberintRecStatus => [
                'Member Active ?',
                {
                    displaytype     => 'lookup',
                    fieldtype       => 'dropdown',
                    filteronly      => 1,
                    dropdownoptions => { 0 => 'No', 1 => 'Yes' },
                    dropdownorder => [ 0, 1 ],
                    dbfield       => 'tblMember_Associations.intRecStatus'
                }
            ],
            intPermit => [
                'On Permit?',
                {
                    displaytype     => 'lookup',
                    fieldtype       => 'dropdown',
                    filteronly      => 1,
                    dropdownoptions => { 0 => 'No', 1 => 'Yes' },
                    dropdownorder => [ 0, 1 ],
                    dbfield       => 'intPermit'
                }
            ],
            MCStatus => [
                "Active in $Data->{'LevelNames'}{$Defs::LEVEL_CLUB} ?",
                {
                    displaytype => 'lookup',
                    fieldtype   => 'dropdown',
                    filteronly  => 1,
                    dropdownoptions =>
                      { -1 => 'Deleted', 0 => 'No', 1 => 'Yes' },
                    dropdownorder => [ 0, 1 ],
                    dbfield       => 'MCStatus'
                }
            ],

            intEthnicityID => [
                'Ethnicity',
                {
                    displaytype     => 'lookup',
                    fieldtype       => 'dropdown',
                    dropdownoptions => $CommonVals->{'DefCodes'}{-8},
                    allowgrouping   => 1,
                    filteronly      => 1
                }
            ],
            intPlayerStatus => [
                'Player in Season ?',
                {
                    displaytype     => 'lookup',
                    fieldtype       => 'dropdown',
                    filteronly      => 1,
                    dropdownoptions => { 0 => 'No', 1 => 'Yes' },
                    dropdownorder => [ 0, 1 ],
                    dbfield       => 'intPlayerStatus'
                }
            ],
            intCoachStatus => [
                'Coach in Season ?',
                {
                    displaytype     => 'lookup',
                    fieldtype       => 'dropdown',
                    filteronly      => 1,
                    dropdownoptions => { 0 => 'No', 1 => 'Yes' },
                    dropdownorder => [ 0, 1 ],
                    dbfield       => 'intCoachStatus'
                }
            ],
            intUmpireStatus => [
                'Match Official in Season ?',
                {
                    displaytype     => 'lookup',
                    fieldtype       => 'dropdown',
                    filteronly      => 1,
                    dropdownoptions => { 0 => 'No', 1 => 'Yes' },
                    dropdownorder => [ 0, 1 ],
                    dbfield       => 'intUmpireStatus'
                }
            ],
            intOfficialInterest => [
                'Official Active ?',
                {
                    displaytype     => 'lookup',
                    fieldtype       => 'dropdown',
                    filteronly      => 1,
                    dropdownoptions => { 0 => 'No', 1 => 'Yes' },
                    dropdownorder => [ 0, 1 ],
                    dbfield       => 'tblMember.intOfficial'
                }
            ],
            intMiscInterest => [
                'Misc Active ?',
                {
                    displaytype     => 'lookup',
                    fieldtype       => 'dropdown',
                    filteronly      => 1,
                    dropdownoptions => { 0 => 'No', 1 => 'Yes' },
                    dropdownorder => [ 0, 1 ],
                    dbfield       => 'tblMember.intMisc'
                }
            ],
            intVolunteerInterest => [
                'Volunteer Active ?',
                {
                    displaytype     => 'lookup',
                    fieldtype       => 'dropdown',
                    filteronly      => 1,
                    dropdownoptions => { 0 => 'No', 1 => 'Yes' },
                    dropdownorder => [ 0, 1 ],
                    dbfield       => 'tblMember.intVolunteer'
                }
            ],
            dtCreatedOnline => [
                'Date Created Online',
                {
                    displaytype => 'date',
                    fieldtype   => 'date',
                    filteronly  => 1,
                    dbfield     => 'tblMember.dtCreatedOnline'
                }
            ],
            dtDate1 => [
                $SystemConfig->{'AllowSWOL'}
                ? 'Last Recorded Game (Not for Sportzware Online Users)'
                : 'Last Recorded Game',
                {
                    displaytype => 'date',
                    fieldtype   => 'date',
                    filteronly  => 1,
                    dbfield     => 'tblMember_Types.dtDate1',
                    dbfrom =>
"LEFT JOIN tblMember_Types ON (tblMember.intMemberID=tblMember_Types.intMemberID AND tblMember_Types.intTypeID=$Defs::MEMBER_TYPE_PLAYER AND tblMember_Types.intSubTypeID=0 AND tblMember_Types.intAssocID = tblMember_Associations.intAssocID AND tblMember_Types.intRecStatus = $Defs::RECSTATUS_ACTIVE)",
                }
            ],

            strZoneName => [
                (
                      $currentLevel > $Defs::LEVEL_ZONE
                    ? $Data->{'LevelNames'}{$Defs::LEVEL_ZONE} . ' Name'
                    : ''
                ),
                {
                    displaytype => 'text',
                    fieldtype   => 'text',
                    allowsort   => 1,
                    active      => 1,
                    dbfield =>
"IF(tblZone.intStatusID = $Defs::NODE_SHOW, tblZone.strName,'')",
                    allowgrouping => 1
                }
            ],
            strRegionName => [
                (
                      $currentLevel > $Defs::LEVEL_REGION
                    ? $Data->{'LevelNames'}{$Defs::LEVEL_REGION} . ' Name'
                    : ''
                ),
                {
                    displaytype => 'text',
                    fieldtype   => 'text',
                    allowsort   => 1,
                    active      => 1,
                    dbfield =>
"IF(tblRegion.intStatusID = $Defs::NODE_SHOW, tblRegion.strName,'')",
                    allowgrouping => 1
                }
            ],
            strStateName => [
                (
                      $currentLevel > $Defs::LEVEL_STATE
                    ? $Data->{'LevelNames'}{$Defs::LEVEL_STATE} . ' Name'
                    : ''
                ),
                {
                    displaytype => 'text',
                    fieldtype   => 'text',
                    allowsort   => 1,
                    active      => 1,
                    dbfield =>
"IF(tblState.intStatusID = $Defs::NODE_SHOW, tblState.strName,'')",
                    allowgrouping => 1
                }
            ],
            strNationalName => [
                (
                      $currentLevel > $Defs::LEVEL_NATIONAL
                    ? $Data->{'LevelNames'}{$Defs::LEVEL_NATIONAL} . ' Name'
                    : ''
                ),
                {
                    displaytype => 'text',
                    fieldtype   => 'text',
                    allowsort   => 1,
                    active      => 1,
                    dbfield =>
"IF(tblNational.intStatusID = $Defs::NODE_SHOW, tblNational.strName,'')",
                    allowgrouping => 1
                }
            ],
            strIntZoneName => [
                (
                      $currentLevel > $Defs::LEVEL_INTZONE
                    ? $Data->{'LevelNames'}{$Defs::LEVEL_INTZONE} . ' Name'
                    : ''
                ),
                {
                    displaytype => 'text',
                    fieldtype   => 'text',
                    allowsort   => 1,
                    active      => 1,
                    dbfield =>
"IF(tblIntZone.intStatusID = $Defs::NODE_SHOW, tblIntZone.strName,'')",
                    allowgrouping => 1
                }
            ],
            strIntRegionName => [
                (
                      $currentLevel > $Defs::LEVEL_INTREGION
                    ? $Data->{'LevelNames'}{$Defs::LEVEL_INTREGION} . ' Name'
                    : ''
                ),
                {
                    displaytype => 'text',
                    fieldtype   => 'text',
                    allowsort   => 1,
                    active      => 1,
                    dbfield =>
" IF(tblIntRegion.intStatusID = $Defs::NODE_SHOW, tblIntRegion.strName,'') ",
                    allowgrouping => 1
                }
            ],
            strAssocName => [
                (
                      $currentLevel > $Defs::LEVEL_ASSOC
                    ? $Data->{'LevelNames'}{$Defs::LEVEL_ASSOC} . ' Name'
                    : ''
                ),
                {
                    displaytype   => 'text',
                    fieldtype     => 'text',
                    active        => 1,
                    allowsort     => 1,
                    dbfield       => 'tblAssoc.strName',
                    allowgrouping => 1
                }
            ],
            intAssocTypeID => [
                (
                    (
                        scalar( keys %{ $CommonVals->{'SubRealms'} } )
                          and $currentLevel > $Defs::LEVEL_ASSOC
                    ) ? ( $Data->{'LevelNames'}{$Defs::LEVEL_ASSOC} . ' Type' )
                    : ''
                ),
                {
                    displaytype     => 'lookup',
                    fieldtype       => 'dropdown',
                    dropdownoptions => $CommonVals->{'SubRealms'},
                    allowsort       => 1,
                    filteronly      => 1
                }
            ],
            intAssocCategoryID => [
                (
                    $currentLevel > $Defs::LEVEL_ASSOC and !scalar(
                        keys %{
                            $CommonVals->{'EntityCategories'}
                              {$Defs::LEVEL_ASSOC}
                        }
                    )
                ) ? ''
                : ( $Data->{'LevelNames'}{$Defs::LEVEL_ASSOC} || '' )
                  . ' Category',
                {
                    displaytype => 'lookup',
                    fieldtype   => 'dropdown',
                    dropdownoptions =>
                      $CommonVals->{'EntityCategories'}{$Defs::LEVEL_ASSOC},
                    allowsort     => 1,
                    allowgrouping => 1,
                    filteronly    => 1,
                }
            ],
            strClubName => [
                (
                         $currentLevel < $Defs::LEVEL_ASSOC
                      or $Data->{'SystemConfig'}{'NoClubs'}
                ) ? ''
                : ( $Data->{'LevelNames'}{$Defs::LEVEL_CLUB} || '' ) . ' Name',
                {
                    displaytype   => 'text',
                    fieldtype     => 'text',
                    allowsort     => 1,
                    dbfield       => 'tblClub.strName',
                    allowgrouping => 1,
                    dbfrom =>
" LEFT JOIN tblClub ON ($MStablename.intClubID = tblClub.intClubID) INNER JOIN tblAssoc_Clubs ON (tblAssoc_Clubs.intAssocID=tblAssoc.intAssocID AND tblAssoc_Clubs.intClubID=tblClub.intClubID) "
                }
            ],
            intClubCategoryID => [
                (
                    (
                             $currentLevel < $Defs::LEVEL_ASSOC
                          or $Data->{'SystemConfig'}{'NoClubs'}
                    )
                      and !scalar(
                        keys %{
                            $CommonVals->{'EntityCategories'}{$Defs::LEVEL_CLUB}
                        }
                      )
                ) ? ''
                : ( $Data->{'LevelNames'}{$Defs::LEVEL_CLUB} || '' )
                  . ' Category',
                {
                    filteronly  => 1,
                    dbfield     => 'tblClub.intClubCategoryID',
                    displaytype => 'lookup',
                    fieldtype   => 'dropdown',
                    dropdownoptions =>
                      $CommonVals->{'EntityCategories'}{$Defs::LEVEL_CLUB},
                    allowsort     => 1,
                    allowgrouping => 1,
                    dbfrom =>
" LEFT JOIN tblClub ON ($MStablename.intClubID = tblClub.intClubID) INNER JOIN tblAssoc_Clubs ON (tblAssoc_Clubs.intAssocID=tblAssoc.intAssocID AND tblAssoc_Clubs.intClubID=tblClub.intClubID) "
                }
            ],
            strTeamName => [
                $Data->{'SystemConfig'}{'NoTeams'} ? ''
                : ( $Data->{'LevelNames'}{$Defs::LEVEL_TEAM} || '' ) . ' Name',
                {
                    displaytype   => 'text',
                    fieldtype     => 'text',
                    active        => 0,
                    allowsort     => 1,
                    dbfield       => 'tblTeam.strName',
                    allowgrouping => 1
                }
            ],

            strCompName => [
                $Data->{'SystemConfig'}{'NoComps'} ? ''
                : ( $Data->{'LevelNames'}{$Defs::LEVEL_COMP} || '' ) . ' Name',
                {
                    displaytype   => 'text',
                    fieldtype     => 'text',
                    allowsort     => 1,
                    dbfield       => "tblAssoc_Comp.strTitle",
                    allowgrouping => 1,
                }
            ],
            intCompLevelID => [
                ( $NRO{'RepCompLevel'} and $Data->{'SystemConfig'}{'NoComps'} )
                ? ''
                : ( $Data->{'LevelNames'}{$Defs::LEVEL_COMP} || '' ) . ' Level',
                {
                    displaytype     => 'lookup',
                    fieldtype       => 'dropdown',
                    dropdownoptions => $CommonVals->{'DefCodes'}{-21},
                    allowgrouping   => 1,
                }
            ],
            strCompSeason => [
                $Data->{'SystemConfig'}{'NoComps'} ? ''
                : ( $Data->{'LevelNames'}{$Defs::LEVEL_COMP} || '' )
                  . ' Seasons',
                {
                    displaytype     => 'lookup',
                    fieldtype       => 'dropdown',
                    dropdownoptions => $CommonVals->{'Seasons'}{'Options'},
                    dropdownorder   => $CommonVals->{'Seasons'}{'Order'},
                    allowsort       => 1,
                    dbfield         => "tblAssoc_Comp.intNewSeasonID",
                    allowgrouping   => 1,
                    multiple        => 1,
                    size            => 3
                }
            ],
            intNatCustomLU10 => [
                $Data->{'RealmSubType'} == 19
                  and $CommonVals->{'CustomFields'}->{'intNatCustomLU10'}[0]
                ? $CommonVals->{'CustomFields'}->{'intNatCustomLU10'}[0]
                : '',
                {
                    displaytype     => 'lookup',
                    fieldtype       => 'dropdown',
                    dropdownoptions => $CommonVals->{'DefCodes'}{-70},
                    size            => 3,
                    multiple        => 1,
                }
            ],
            intGender => [
                'Gender',
                {
                    displaytype => 'lookup',
                    fieldtype   => 'dropdown',
                    dropdownoptions =>
                      { '' => '&nbsp;', 1 => 'Male', 2 => 'Female' },
                    dropdownorder => [ '', 1, 2 ],
                    size          => 3,
                    multiple      => 1,
                    allowgrouping => 1
                }
            ],

        },

        Order => [
            qw(
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
              intCompLevelID
              strCompSeason
              intGender
              intPermit
              MCStatus
              intEthnicityID
              MemberintRecStatus
              intPlayerStatus
              intCoachStatus
              intUmpireStatus
              dtCreatedOnline
              dtDate1
              intNatCustomLU10
              )
        ],
        Config => {
            EmailExport        => 1,
            limitView          => 5000,
            EmailSenderAddress => $Defs::admin_email,
            SecondarySort      => 1,
            RunButtonLabel     => 'Run Report',
            NoSummaryData      => 1,
        },
        OptionGroups => {
            default => [ 'Details', {} ],
        },
    );
    $self->{'Config'} = \%config;
}

sub SQLBuilder {
    my ( $self, $OptVals, $ActiveFields ) = @_;
    my $currentLevel = $self->{'EntityTypeID'} || 0;
    my $Data         = $self->{'Data'};
    my $clientValues = $Data->{'clientValues'};
    my $SystemConfig = $Data->{'SystemConfig'};

    my $MStablename = "tblMember_Seasons_$Data->{'Realm'}";

    my $from_levels   = $OptVals->{'FROM_LEVELS'};
    my $from_list     = $OptVals->{'FROM_LIST'};
    my $where_levels  = $OptVals->{'WHERE_LEVELS'};
    my $where_list    = $OptVals->{'WHERE_LIST'};
    my $current_from  = $OptVals->{'CURRENT_FROM'};
    my $current_where = $OptVals->{'CURRENT_WHERE'};
    my $select_levels = $OptVals->{'SELECT_LEVELS'};
    my $having_list   = $OptVals->{'HAVING_LIST'};

    my $sql = '';

    use DBIx::SQLCrosstab;
    use DBIx::SQLCrosstab::Format;
    {    #Work out SQL

        my $tname = $ActiveFields->{'strTeamName'} ? ', strTeamName' : '';
        my $cmpname =
          $ActiveFields->{'strCompName'} ? ', tblAssoc_Comp.strTitle ' : '';
        my $cmplname =
          $ActiveFields->{'intCompLevelID'}
          ? ', tblAssoc_Comp.intCompLevelID '
          : '';
        my $notmemberteam = ( $tname or $cmpname or $cmplname ) ? 0 : 1;

        my $permitWHERE = '';
        if ( $where_list =~ /intPermit/ ) {
            $permitWHERE = $where_list;
            $permitWHERE =~ s/^.*intPermit/intPermit/;
            $permitWHERE =~ s/AND.*//;
            $where_list =~ s/intPermit.*?AND//;
            $where_list =~ s/intPermit.*//;
            $where_list =~ s/AND\s*AND\s*$//;
            $where_list =~ s/AND\s*$//;
            $where_list = '' if ( $where_list =~ /^\s*AND\s*$/ );
            $permitWHERE = qq[ AND MC2.$permitWHERE];
        }
        my $mcStatusWHERE = '';
        if ( $where_list =~ /MCStatus/ ) {
            $mcStatusWHERE = $where_list;
            $mcStatusWHERE =~ s/^.*MCStatus/intStatus/;
            $mcStatusWHERE =~ s/AND.*//;
            $where_list =~ s/MCStatus.*?AND//;
            $where_list =~ s/MCStatus.*//;
            $where_list =~ s/AND\s*AND\s*$//;
            $where_list =~ s/AND\s*$//;
            $where_list = '' if ( $where_list =~ /^\s*AND\s*$/ );
            $mcStatusWHERE = qq[ AND MC2.$mcStatusWHERE];
        }

        $where_list = ' AND ' . $where_list
          if $where_list and ( $where_levels or $current_where );
        $where_list = ' ' . $where_list if $where_list;
        $where_list =~ s/AND\s*AND/AND /;
        $where_list =~ s/AND\s*AND/AND /;

        my $clubID =
          (       $Data->{'clientValues'}{'clubID'}
              and $Data->{'clientValues'}{'clubID'} != $Defs::INVALID_ID )
          ? $Data->{'clientValues'}{'clubID'}
          : 0;

        my $assocSeasonWHERE =
          ( $from_list =~ /tblClub/ )
          ? qq[ AND $MStablename.intClubID=tblClub.intClubID AND tblClub.intRecStatus <> -1 ]
          : qq[ AND $MStablename.intClubID=0];
        $assocSeasonWHERE = qq[ AND $MStablename.intClubID=$clubID ]
          if ($clubID);
        $assocSeasonWHERE = qq[ AND tblTeam.intClubID=$MStablename.intClubID ]
          if ( $from_levels =~ /tblTeam/ );
        $assocSeasonWHERE =
          qq[ AND $MStablename.intClubID=tblAssoc_Clubs.intClubID ]
          if ( $from_levels =~ /tblAssoc_Clubs/ );
        $assocSeasonWHERE .=
qq[ AND tblMember.intMemberID IN (SELECT DISTINCT MC2.intMemberID FROM tblMember_Clubs as MC2 WHERE MC2.intMemberID=tblMember.intMemberID AND MC2.intClubID=$MStablename.intClubID $mcStatusWHERE $permitWHERE)]
          if ( $from_list =~ /tblMember_Clubs|tblClub/ or $clubID );

        my $from = qq[$from_levels $current_from
        INNER JOIN $MStablename ON (
            $MStablename.intMemberID = tblMember_Associations.intMemberID 
                AND $MStablename.intAssocID = tblMember_Associations.intAssocID 
                AND $MStablename.intMSRecStatus=1 
        ) $from_list
        INNER JOIN tblSeasons as S ON (S.intSeasonID = $MStablename.intSeasonID
                AND S.intAssocID IN (0, $Data->{'clientValues'}{'assocID'})
        )
        ];
        my $where =
          qq[$where_levels $current_where $where_list $assocSeasonWHERE];
        $where .= qq[ AND tblComp_Teams.intRecStatus<>-1 ]
          if $from =~ /tblComp_Teams/;

        my @agegroups = ();
        my $aID = getAssocID($clientValues) || 0;
        $aID = 0 if $aID == -1;

        my $st_a = qq[
        SELECT intAgeGroupID, strAgeGroupDesc, intAgeGroupGender
        FROM tblAgeGroups
        WHERE intRealmID=$Data->{'Realm'}
            AND (intAssocID = $aID OR intAssocID = 0)
            AND (intRealmSubTypeID = $Data->{'RealmSubType'} OR intRealmSubTypeID= 0)
            AND intRecStatus=1
        ORDER BY strAgeGroupDesc
        ];
        my $query = $self->{'db'}->prepare($st_a);
        $query->execute;
        my $cnt        = 1;
        my @ageoptions = ();
        my @validIDs   = ();
        while ( my $dref = $query->fetchrow_hashref() ) {
            push @validIDs,   $dref->{'intAgeGroupID'};
            push @ageoptions, $dref;
        }
        push @ageoptions,
          {
            intAgeGroupID     => 0,
            strAgeGroupDesc   => 'Unknown',
            intAgeGroupGender => 0,
          };
        for my $dref (@ageoptions) {
            my $gender =
              $dref->{intAgeGroupGender}
              ? qq[- ($Defs::genderInfo{$dref->{intAgeGroupGender}})]
              : '';
            my $id  = $dref->{'intAgeGroupID'};
            my $val = qq[$dref->{strAgeGroupDesc}$gender] || '';
            my %t   = ( id => $id, value => $val );
            push @agegroups, \%t;
            my $num = sprintf( "%03d", $cnt );
            $self->{'Config'}{'Fields'}{"xfld$num"} = [
                $val, { displaytype => 'text', fieldtype => 'text', total => 1 }
            ];
            $ActiveFields->{"xfld$num"} = 1;
            push @{ $self->{'Config'}{'Order'} },    "xfld$num";
            push @{ $self->{'RunParams'}{'Order'} }, "xfld$num";
            push @{ $self->{'Config'}{'Labels'} }, [ "xfld$num", $val ];
            $cnt++;
        }
        my $validID_str = join( ',', @validIDs );

        $self->{'Config'}{'Fields'}{"total"} = [
            'Total', { displaytype => 'text', fieldtype => 'text', total => 1 }
        ];
        $ActiveFields->{"total"} = 1;
        push @{ $self->{'Config'}{'Order'} },    "total";
        push @{ $self->{'RunParams'}{'Order'} }, "total";
        push @{ $self->{'Config'}{'Labels'} }, [ "total", 'Total' ];
        my $xtab_params = {
            dbh => $self->{'db'},
            op  => [ [ 'COUNT', "$MStablename.intMemberSeasonID" ] ]
            ,    #Used to be tblMember.intMemberID
            from => $from,
            rows => [

            ],
            col_total => 1,
            cols      => [
                {
                    id =>
"IF($MStablename.intPlayerAgeGroupID IN ($validID_str),$MStablename.intPlayerAgeGroupID, 0)",
                    from     => 'tblAgeGroups',
                    col_list => \@agegroups,
                },
            ],
            where => $where,
        };
        push @{ $xtab_params->{'rows'} },
          { col => "$MStablename.intSeasonID", alias => "intSeasonID" }
          if $ActiveFields->{"intSeasonID"};
        push @{ $xtab_params->{'rows'} },
          { col => "intAssocTypeID", alias => "intAssocTypeID" }
          if $ActiveFields->{"intAssocTypeID"};
        for my $i (qw(Region Zone IntZone intRegion Assoc Club Team)) {
            push @{ $xtab_params->{'rows'} },
              { col => "tbl$i.strName ", alias => "str$i" . "Name" }
              if $ActiveFields->{ "str$i" . 'Name' };
        }
        push @{ $xtab_params->{'rows'} },
          { col => "tblAssoc_Comp.strTitle", alias => "strCompName" }
          if $ActiveFields->{"strCompName"};
        push @{ $xtab_params->{'rows'} },
          { col => "intCompLevelID", alias => "intCompLevelID" }
          if $ActiveFields->{"intCompLevelID"};
        push @{ $xtab_params->{'rows'} },
          { col => "intGender", alias => "intGender" }
          if $ActiveFields->{"intGender"};

        my $xtab = DBIx::SQLCrosstab->new($xtab_params)
          or die "error in creation ($DBIx::SQLCrosstab::errstr)\n";

        my $statement = $xtab->get_query("#")
          or die "error in query building $DBIx::SQLCrosstab::errstr\n";

        $statement =~ s/AND\s*AND/AND /;

        $statement =~
s/\(CASE WHEN IF\(tblMember_Seasons/\(DISTINCT CASE WHEN IF\(tblMember_Seasons/g;

#    $statement =~ s/COUNT\(tblMember.intMemberID\) AS total/COUNT\(DISTINCT tblMember.intMemberID\) AS total/;
        $statement =~
s/COUNT\($MStablename.intMemberSeasonID\) AS total/COUNT\(DISTINCT $MStablename.intMemberSeasonID\) AS total/;

        return ( $statement, '' );
    }
}

1;

# vim: set et sw=4 ts=4:
