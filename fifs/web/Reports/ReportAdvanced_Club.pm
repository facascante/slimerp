#
# $Header: svn://svn/SWM/trunk/web/Reports/ReportAdvanced_Club.pm 11233 2014-04-04 04:13:31Z dhanslow $
#

package Reports::ReportAdvanced_Club;

use strict;
use lib ".";
use ReportAdvanced_Common;
use Reports::ReportAdvanced;
our @ISA = qw(Reports::ReportAdvanced);

use strict;

sub _getConfiguration {
    my $self = shift;

    my $currentLevel = $self->{'EntityTypeID'} || 0;
    my $Data         = $self->{'Data'};
    my $clientValues = $Data->{'clientValues'};
    my $realm_id     = $Data->{'Realm'};
    my $CommonVals   = getCommonValues(
        $Data,
        {
            SubRealms           => 1,
            CustomFields        => 1,
            ContactRoles        => 1,
            FieldLabels         => 1,
            DefCodes            => 1,
            ClubCharacteristics => 1,
            EntityCategories    => 1,
        },
    );
    my $txt_Clr = $Data->{'SystemConfig'}{'txtCLR'} || 'Clearance';
    my %config = (
        Name => 'Detailed Club Report',

        StatsReport     => 1,
        MemberTeam      => 0,
        ReportEntity    => 3,
        ReportLevel     => 0,
        Template        => 'default_adv',
        TemplateEmail   => 'default_adv_CSV',
        DistinctValues  => 1,
        DefaultPermType => 'Club',

        Fields => {
            intRecStatus => [
                'Active',
                {
                    displaytype     => 'lookup',
                    fieldtype       => 'dropdown',
                    dropdownoptions => { 0 => 'No', 1 => 'Yes' },
                    dbfield         => 'tblAssoc_Clubs.intRecStatus',
                    dbwhere         => ( $currentLevel <= $Defs::LEVEL_ASSOC )
                    ? "AND tblAssoc_Clubs.intAssocID=$clientValues->{assocID}"
                    : '',
                }
            ],
            strName => [
                "$Data->{'LevelNames'}{$Defs::LEVEL_CLUB} Name",
                {
                    displaytype => 'text',
                    fieldtype   => 'text',
                    active      => 1,
                    allowsort   => 1,
                    dbfield     => 'tblClub.strName',
                }
            ],
            strAbbrev => [
                'Abbreviation',
                {
                    displaytype => 'text',
                    fieldtype   => 'text',
                    allowsort   => 1,
                    dbfield     => 'tblClub.strAbbrev',
                }
            ],
            strClubNo => [
                "$Data->{'LevelNames'}{$Defs::LEVEL_CLUB} No",
                {
                    displaytype => 'text',
                    fieldtype   => 'text',
                    allowsort   => 1,
                }
            ],
            intLogins => [
                'Number of Logins',
                {
                    displaytype => 'text',
                    fieldtype   => 'text',
                    allowsort   => 1,
                    dbfrom =>
"LEFT JOIN tblAuth ON (tblClub.intClubID = tblAuth.intID and tblAuth.intLevel=3)",
                }
            ],
            strIncNo => [
                'Incorporation Number',
                {
                    displaytype => 'text',
                    fieldtype   => 'text',
                    allowsort   => 1,
                    dbfield     => 'tblClub.strIncNo',
                }
            ],
            strColours => [
                "$Data->{'LevelNames'}{$Defs::LEVEL_CLUB} Colours",
                {
                    displaytype => 'text',
                    fieldtype   => 'text',
                    active      => 1,
                    allowsort   => 1,
                    dbfield     => 'tblClub.strColours',
                }
            ],
            strAddress1 => [
                'Address Line 1',
                {
                    displaytype => 'text',
                    fieldtype   => 'text',
                    allowsort   => 1,
                    dbfield     => 'tblClub.strAddress1',
                }
            ],
            strAddress2 => [
                'Address Line 2',
                {
                    displaytype => 'text',
                    fieldtype   => 'text',
                    allowsort   => 1,
                    dbfield     => 'tblClub.strAddress2',
                }
            ],
            strSuburb => [
                'Suburb',
                {
                    displaytype => 'text',
                    fieldtype   => 'text',
                    allowsort   => 1,
                    dbfield     => 'tblClub.strSuburb',
                }
            ],
            strState => [
                'State',
                {
                    displaytype   => 'text',
                    fieldtype     => 'text',
                    allowsort     => 1,
                    dbfield       => 'tblClub.strState',
                    allowgrouping => 1,
                }
            ],
            strLGA => [
                'Local Government Area',
                {
                    displaytype   => 'text',
                    fieldtype     => 'text',
                    allowsort     => 1,
                    allowgrouping => 1,
                    dbfield       => 'tblClub.strLGA',
                }
            ],
            strDevelRegion => [
                'Development Region',
                {
                    displaytype   => 'text',
                    fieldtype     => 'text',
                    allowsort     => 1,
                    dbfield       => 'tblClub.strDevelRegion',
                    enabled       => $Data->{'SystemConfig'}{'DevelRegions'},
                    allowgrouping => 1,
                }
            ],
            strClubZone => [
                'Zone',
                {
                    displaytype   => 'text',
                    fieldtype     => 'text',
                    allowsort     => 1,
                    dbfield       => 'tblClub.strClubZone',
                    enabled       => $Data->{'SystemConfig'}{'ClubZones'},
                    allowgrouping => 1,
                }
            ],

            intAgeTypeID => [
                'Age Type',
                {
                    displaytype     => 'lookup',
                    fieldtype       => 'dropdown',
                    dropdownoptions => \%Defs::ageLevel,
                    dbfield         => 'tblClub.intAgeTypeID',
                    allowgrouping   => 1,
                }
            ],
            intClubCategoryID => [
                scalar(
                    keys
                      %{ $CommonVals->{'EntityCategories'}{$Defs::LEVEL_CLUB} }
                  ) ? "$Data->{'LevelNames'}{$Defs::LEVEL_CLUB} Category" : '',
                {
                    displaytype => 'lookup',
                    fieldtype   => 'dropdown',
                    dropdownoptions =>
                      $CommonVals->{'EntityCategories'}{$Defs::LEVEL_CLUB},
                    dbfield       => 'tblClub.intClubCategoryID',
                    allowgrouping => 1,
                }
            ],
            intClubTypeID => [
                'Club Type',
                {
                    displaytype     => 'lookup',
                    fieldtype       => 'dropdown',
                    dropdownoptions => \%Defs::ClubType,
                    dbfield         => 'tblClub.intClubTypeID',
                    allowgrouping   => 1,
                }
            ],

            strPostalCode => [
                'Postal Code',
                {
                    displaytype => 'text',
                    fieldtype   => 'text',
                    allowsort   => 1,
                    dbfield     => 'tblClub.strPostalCode',
                }
            ],
            strPhone => [
                'Phone',
                {
                    displaytype => 'text',
                    fieldtype   => 'text',
                    allowsort   => 1,
                    dbfield     => 'tblClub.strPhone',
                }
            ],
            strFax => [
                'Fax',
                {
                    displaytype => 'text',
                    fieldtype   => 'text',
                    allowsort   => 1,
                    dbfield     => 'tblClub.strFax',
                }
            ],
            strEmail => [
                'Email',
                {
                    displaytype => 'text',
                    fieldtype   => 'text',
                    allowsort   => 1,
                    dbfield     => 'tblClub.strEmail',
                }
            ],

            strGroundName => [
                'Home Venue Name',
                {
                    displaytype   => 'text',
                    fieldtype     => 'text',
                    allowsort     => 1,
                    dbfield       => 'tblClub.strGroundName',
                    allowgrouping => 1,
                }
            ],
            strGroundAddress => [
                'Home Venue Address',
                {
                    displaytype => 'text',
                    fieldtype   => 'text',
                    allowsort   => 1,
                    dbfield     => 'tblClub.strGroundAddress',
                }
            ],
            strGroundSuburb => [
                'Home Venue Suburb',
                {
                    displaytype => 'text',
                    fieldtype   => 'text',
                    allowsort   => 1,
                    dbfield     => 'tblClub.strGroundSuburb',
                }
            ],
            strGroundPostalCode => [
                'Home Venue Postal Code',
                {
                    displaytype => 'text',
                    fieldtype   => 'text',
                    allowsort   => 1,
                    dbfield     => 'tblClub.strGroundPostalCode',
                }
            ],

            strAssocName => [
                $Data->{'LevelNames'}{$Defs::LEVEL_ASSOC} . ' Name',
                {
                    displaytype   => 'text',
                    fieldtype     => 'text',
                    allowsort     => 1,
                    active        => 1,
                    dbfield       => 'tblAssoc.strName',
                    enabled       => $clientValues->{assocID} == -1,
                    allowgrouping => 1,
                }
            ],

            intAssocTypeID => [
                $Data->{'LevelNames'}{$Defs::LEVEL_ASSOC} . ' Type',
                {
                    displaytype     => 'lookup',
                    fieldtype       => 'dropdown',
                    dropdownoptions => $CommonVals->{'SubRealms'},
                    allowsort       => 1,
                    enabled         => (
                        scalar( keys %{ $CommonVals->{'SubRealms'} } )
                          and $currentLevel > $Defs::LEVEL_ASSOC
                    ),
                    allowgrouping => 1,
                }
            ],
            intAssocCategoryID => [
                scalar(
                    keys
                      %{ $CommonVals->{'EntityCategories'}{$Defs::LEVEL_ASSOC} }
                  ) ? "$Data->{'LevelNames'}{$Defs::LEVEL_ASSOC} Category" : '',
                {
                    displaytype => 'lookup',
                    fieldtype   => 'dropdown',
                    dropdownoptions =>
                      $CommonVals->{'EntityCategories'}{$Defs::LEVEL_ASSOC},
                    dbfield       => 'tblAssoc.intAssocCategoryID',
                    allowgrouping => 1,
                }
            ],
            strZoneName => [
                $Data->{'LevelNames'}{$Defs::LEVEL_ZONE} . ' Name',
                {
                    displaytype => 'text',
                    fieldtype   => 'text',
                    allowsort   => 1,
                    dbfield =>
"IF(tblZone.intStatusID = $Defs::NODE_SHOW, tblZone.strName, '')",
                    allowgrouping => 1,
                    active        => 1,
                    enabled       => $currentLevel > $Defs::LEVEL_ZONE,
                }
            ],

            strRegionName => [
                $Data->{'LevelNames'}{$Defs::LEVEL_REGION} . ' Name',
                {
                    displaytype => 'text',
                    fieldtype   => 'text',
                    allowsort   => 1,
                    dbfield =>
"IF(tblRegion.intStatusID = $Defs::NODE_SHOW, tblRegion.strName, '')",
                    allowgrouping => 1,
                    active        => 1,
                    enabled       => $currentLevel > $Defs::LEVEL_REGION,
                }
            ],

            strStateName => [
                $Data->{'LevelNames'}{$Defs::LEVEL_STATE} . ' Name',
                {
                    displaytype => 'text',
                    fieldtype   => 'text',
                    allowsort   => 1,
                    dbfield =>
"IF(tblState.intStatusID = $Defs::NODE_SHOW, tblState.strName, '')",
                    allowgrouping => 1,
                    active        => 1,
                    enabled       => $currentLevel > $Defs::LEVEL_STATE,
                }
            ],

            strNationalName => [
                $Data->{'LevelNames'}{$Defs::LEVEL_NATIONAL} . ' Name',
                {
                    displaytype => 'text',
                    fieldtype   => 'text',
                    allowsort   => 1,
                    dbfield =>
"IF(tblNational.intStatusID = $Defs::NODE_SHOW, tblNational.strName, '')",
                    allowgrouping => 1,
                    active        => 1,
                    enabled       => $currentLevel > $Defs::LEVEL_NATIONAL,
                }
            ],

            strIntZoneName => [
                $Data->{'LevelNames'}{$Defs::LEVEL_INTZONE} . ' Name',
                {
                    displaytype => 'text',
                    fieldtype   => 'text',
                    allowsort   => 1,
                    dbfield =>
"IF(tblIntZone.intStatusID = $Defs::NODE_SHOW, tblIntZone.strName, '')",
                    allowgrouping => 1,
                    active        => 1,
                    enabled       => $currentLevel > $Defs::LEVEL_INTZONE,
                }
            ],

            strIntRegionName => [
                $Data->{'LevelNames'}{$Defs::LEVEL_INTREGION} . ' Name',
                {
                    displaytype => 'text',
                    fieldtype   => 'text',
                    allowsort   => 1,
                    dbfield =>
" IF(tblIntRegion.intStatusID = $Defs::NODE_SHOW, tblIntRegion.strName, '') ",
                    allowgrouping => 1,
                    active        => 1,
                    enabled       => $currentLevel > $Defs::LEVEL_INTREGION,
                }
            ],

            AServ_intPublicShow => [
                'Visible to Public ?',
                {
                    displaytype     => 'lookup',
                    fieldtype       => 'dropdown',
                    dropdownoptions => { 0 => 'No', 1 => 'Yes' },
                    dropdownorder => [ 0, 1 ],
                    optiongroup   => 'assoc_services',
                    dbfield       => 'AServ.intPublicShow',
                }
            ],
            AServ_strVenueName => [
                'Venue Name',
                {
                    displaytype => 'text',
                    fieldtype   => 'text',
                    allowsort   => 1,
                    optiongroup => 'assoc_services',
                    dbfield     => 'AServ.strVenueName',
                }
            ],
            AServ_strVenueAddress => [
                'Venue Address',
                {
                    displaytype => 'text',
                    fieldtype   => 'text',
                    allowsort   => 1,
                    optiongroup => 'assoc_services',
                    dbfield     => 'AServ.strVenueAddress',
                }
            ],
            AServ_strVenueAddress2 => [
                'Venue Address 2',
                {
                    displaytype => 'text',
                    fieldtype   => 'text',
                    allowsort   => 1,
                    optiongroup => 'assoc_services',
                    dbfield     => 'AServ.strVenueAddress2',
                }
            ],
            AServ_strVenueSuburb => [
                'Venue Suburb',
                {
                    displaytype => 'text',
                    fieldtype   => 'text',
                    allowsort   => 1,
                    optiongroup => 'assoc_services',
                    dbfield     => 'AServ.strVenueSuburb',
                }
            ],
            AServ_strVenueState => [
                'Venue State',
                {
                    displaytype => 'text',
                    fieldtype   => 'text',
                    allowsort   => 1,
                    optiongroup => 'assoc_services',
                    dbfield     => 'AServ.strVenueState',
                }
            ],
            AServ_strVenuePostalCode => [
                'Venue Postal Code',
                {
                    displaytype => 'text',
                    fieldtype   => 'text',
                    allowsort   => 1,
                    optiongroup => 'assoc_services',
                    dbfield     => 'AServ.strVenuePostalCode',
                }
            ],
            AServ_dblLat => [
                'Venue Latitude',
                {
                    displaytype => 'double',
                    fieldtype   => 'double',
                    allowsort   => 1,
                    optiongroup => 'assoc_services',
                    dbfield     => 'AServ.dblLat',
                }
            ],
            AServ_dblLong => [
                'Venue Longitude',
                {
                    displaytype => 'double',
                    fieldtype   => 'double',
                    allowsort   => 1,
                    optiongroup => 'assoc_services',
                    dbfield     => 'AServ.dblLong',
                }
            ],

            AServ_strVenueCountry => [
                'Venue Country',
                {
                    displaytype => 'text',
                    fieldtype   => 'text',
                    allowsort   => 1,
                    optiongroup => 'assoc_services',
                    dbfield     => 'AServ.strVenueCountry',
                }
            ],
            AServ_strEmail => [
                'Email',
                {
                    displaytype => 'text',
                    fieldtype   => 'text',
                    allowsort   => 1,
                    optiongroup => 'assoc_services',
                    dbfield     => 'AServ.strEmail',
                }
            ],
            AServ_strURL => [
                'Website',
                {
                    displaytype => 'text',
                    fieldtype   => 'text',
                    allowsort   => 1,
                    optiongroup => 'assoc_services',
                    dbfield     => 'AServ.strURL',
                }
            ],
            AServ_intMon => [
                'Monday',
                {
                    displaytype     => 'lookup',
                    fieldtype       => 'dropdown',
                    dropdownoptions => { 0 => 'No', 1 => 'Yes' },
                    dropdownorder => [ 0, 1 ],
                    optiongroup   => 'assoc_services',
                    dbfield       => 'AServ.intMon',
                }
            ],
            AServ_intTue => [
                'Tuesday',
                {
                    displaytype     => 'lookup',
                    fieldtype       => 'dropdown',
                    dropdownoptions => { 0 => 'No', 1 => 'Yes' },
                    dropdownorder => [ 0, 1 ],
                    optiongroup   => 'assoc_services',
                    dbfield       => 'AServ.intTue',
                }
            ],
            AServ_intWed => [
                'Wednesday',
                {
                    displaytype     => 'lookup',
                    fieldtype       => 'dropdown',
                    dropdownoptions => { 0 => 'No', 1 => 'Yes' },
                    dropdownorder => [ 0, 1 ],
                    optiongroup   => 'assoc_services',
                    dbfield       => 'AServ.intWed',
                }
            ],
            AServ_intThu => [
                'Thursday',
                {
                    displaytype     => 'lookup',
                    fieldtype       => 'dropdown',
                    dropdownoptions => { 0 => 'No', 1 => 'Yes' },
                    dropdownorder => [ 0, 1 ],
                    optiongroup   => 'assoc_services',
                    dbfield       => 'AServ.intThu',
                }
            ],
            AServ_intFri => [
                'Friday',
                {
                    displaytype     => 'lookup',
                    fieldtype       => 'dropdown',
                    dropdownoptions => { 0 => 'No', 1 => 'Yes' },
                    dropdownorder => [ 0, 1 ],
                    optiongroup   => 'assoc_services',
                    dbfield       => 'AServ.intFri',
                }
            ],
            AServ_intSat => [
                'Saturday',
                {
                    displaytype     => 'lookup',
                    fieldtype       => 'dropdown',
                    dropdownoptions => { 0 => 'No', 1 => 'Yes' },
                    dropdownorder => [ 0, 1 ],
                    optiongroup   => 'assoc_services',
                    dbfield       => 'AServ.intSat',
                }
            ],
            AServ_intSun => [
                'Sunday',
                {
                    displaytype     => 'lookup',
                    fieldtype       => 'dropdown',
                    dropdownoptions => { 0 => 'No', 1 => 'Yes' },
                    dropdownorder => [ 0, 1 ],
                    optiongroup   => 'assoc_services',
                    dbfield       => 'AServ.intSun',
                }
            ],
            AServ_strSessionDurations => [
                'Duration',
                {
                    displaytype => 'text',
                    fieldtype   => 'text',
                    allowsort   => 1,
                    optiongroup => 'assoc_services',
                    dbfield     => 'AServ.strSessionDurations',
                }
            ],
            AServ_strTimes => [
                'Times',
                {
                    displaytype => 'text',
                    fieldtype   => 'text',
                    allowsort   => 1,
                    optiongroup => 'assoc_services',
                    dbfield     => 'AServ.strTimes',
                }
            ],
            AServ_dtStart => [
                'Season Start Date',
                {
                    displaytype => 'text',
                    fieldtype   => 'date',
                    allowsort   => 1,
                    optiongroup => 'assoc_services',
                    dbfield     => 'AServ.dtStart',
                }
            ],
            AServ_PostalCodes => [
                'Postal Codes Serviced',
                {
                    optiongroup => 'assoc_services',
                    displaytype => 'text',
                    fieldtype   => 'text',
                    dbfrom =>
"LEFT JOIN tblAssocServicesPostalCode ON (tblAssocServicesPostalCode.intAssocID = tblAssoc.intAssocID and tblAssocServicesPostalCode.intClubID = tblClub.intClubID)",
                    dbfield => 'tblAssocServicesPostalCode.strPostalCode',
                }
            ],

            strClubCustomStr1 => [
                (
                    $CommonVals->{'CustomFields'}->{'strClubCustomStr1'}[0] !~
                      /^Custom Club Text/
                ) ? $CommonVals->{'CustomFields'}->{'strClubCustomStr1'}[0]
                : '',
                {
                    displaytype => 'text',
                    fieldtype   => 'text',
                    allowsort   => 0,
                    optiongroup => 'customfields'
                }
            ],
            strClubCustomStr2 => [
                (
                    $CommonVals->{'CustomFields'}->{'strClubCustomStr2'}[0] !~
                      /^Custom Club Text/
                ) ? $CommonVals->{'CustomFields'}->{'strClubCustomStr2'}[0]
                : '',
                {
                    displaytype => 'text',
                    fieldtype   => 'text',
                    allowsort   => 0,
                    optiongroup => 'customfields'
                }
            ],
            strClubCustomStr3 => [
                (
                    $CommonVals->{'CustomFields'}->{'strClubCustomStr3'}[0] !~
                      /^Custom Club Text/
                ) ? $CommonVals->{'CustomFields'}->{'strClubCustomStr3'}[0]
                : '',
                {
                    displaytype => 'text',
                    fieldtype   => 'text',
                    allowsort   => 0,
                    optiongroup => 'customfields'
                }
            ],
            strClubCustomStr4 => [
                (
                    $CommonVals->{'CustomFields'}->{'strClubCustomStr4'}[0] !~
                      /^Custom Club Text/
                ) ? $CommonVals->{'CustomFields'}->{'strClubCustomStr4'}[0]
                : '',
                {
                    displaytype => 'text',
                    fieldtype   => 'text',
                    allowsort   => 0,
                    optiongroup => 'customfields'
                }
            ],
            strClubCustomStr5 => [
                (
                    $CommonVals->{'CustomFields'}->{'strClubCustomStr5'}[0] !~
                      /^Custom Club Text/
                ) ? $CommonVals->{'CustomFields'}->{'strClubCustomStr5'}[0]
                : '',
                {
                    displaytype => 'text',
                    fieldtype   => 'text',
                    allowsort   => 0,
                    optiongroup => 'customfields'
                }
            ],
            strClubCustomStr6 => [
                (
                    $CommonVals->{'CustomFields'}->{'strClubCustomStr6'}[0] !~
                      /^Custom Club Text/
                ) ? $CommonVals->{'CustomFields'}->{'strClubCustomStr6'}[0]
                : '',
                {
                    displaytype => 'text',
                    fieldtype   => 'text',
                    allowsort   => 0,
                    optiongroup => 'customfields'
                }
            ],
            strClubCustomStr7 => [
                (
                    $CommonVals->{'CustomFields'}->{'strClubCustomStr7'}[0] !~
                      /^Custom Club Text/
                ) ? $CommonVals->{'CustomFields'}->{'strClubCustomStr7'}[0]
                : '',
                {
                    displaytype => 'text',
                    fieldtype   => 'text',
                    allowsort   => 0,
                    optiongroup => 'customfields'
                }
            ],
            strClubCustomStr8 => [
                (
                    $CommonVals->{'CustomFields'}->{'strClubCustomStr8'}[0] !~
                      /^Custom Club Text/
                ) ? $CommonVals->{'CustomFields'}->{'strClubCustomStr8'}[0]
                : '',
                {
                    displaytype => 'text',
                    fieldtype   => 'text',
                    allowsort   => 0,
                    optiongroup => 'customfields'
                }
            ],
            strClubCustomStr9 => [
                (
                    $CommonVals->{'CustomFields'}->{'strClubCustomStr9'}[0] !~
                      /^Custom Club Text/
                ) ? $CommonVals->{'CustomFields'}->{'strClubCustomStr9'}[0]
                : '',
                {
                    displaytype => 'text',
                    fieldtype   => 'text',
                    allowsort   => 0,
                    optiongroup => 'customfields'
                }
            ],
            strClubCustomStr10 => [
                (
                    $CommonVals->{'CustomFields'}->{'strClubCustomStr10'}[0] !~
                      /^Custom Club Text/
                ) ? $CommonVals->{'CustomFields'}->{'strClubCustomStr10'}[0]
                : '',
                {
                    displaytype => 'text',
                    fieldtype   => 'text',
                    allowsort   => 0,
                    optiongroup => 'customfields'
                }
            ],
            strClubCustomStr11 => [
                (
                    $CommonVals->{'CustomFields'}->{'strClubCustomStr11'}[0] !~
                      /^Custom Club Text/
                ) ? $CommonVals->{'CustomFields'}->{'strClubCustomStr11'}[0]
                : '',
                {
                    displaytype => 'text',
                    fieldtype   => 'text',
                    allowsort   => 0,
                    optiongroup => 'customfields'
                }
            ],
            strClubCustomStr12 => [
                (
                    $CommonVals->{'CustomFields'}->{'strClubCustomStr12'}[0] !~
                      /^Custom Club Text/
                ) ? $CommonVals->{'CustomFields'}->{'strClubCustomStr12'}[0]
                : '',
                {
                    displaytype => 'text',
                    fieldtype   => 'text',
                    allowsort   => 0,
                    optiongroup => 'customfields'
                }
            ],
            strClubCustomStr13 => [
                (
                    $CommonVals->{'CustomFields'}->{'strClubCustomStr13'}[0] !~
                      /^Custom Club Text/
                ) ? $CommonVals->{'CustomFields'}->{'strClubCustomStr13'}[0]
                : '',
                {
                    displaytype => 'text',
                    fieldtype   => 'text',
                    allowsort   => 0,
                    optiongroup => 'customfields'
                }
            ],
            strClubCustomStr14 => [
                (
                    $CommonVals->{'CustomFields'}->{'strClubCustomStr14'}[0] !~
                      /^Custom Club Text/
                ) ? $CommonVals->{'CustomFields'}->{'strClubCustomStr14'}[0]
                : '',
                {
                    displaytype => 'text',
                    fieldtype   => 'text',
                    allowsort   => 0,
                    optiongroup => 'customfields'
                }
            ],
            strClubCustomStr15 => [
                (
                    $CommonVals->{'CustomFields'}->{'strClubCustomStr15'}[0] !~
                      /^Custom Club Text/
                ) ? $CommonVals->{'CustomFields'}->{'strClubCustomStr15'}[0]
                : '',
                {
                    displaytype => 'text',
                    fieldtype   => 'text',
                    allowsort   => 0,
                    optiongroup => 'customfields'
                }
            ],

            dblClubCustomDbl1 => [
                (
                    $CommonVals->{'CustomFields'}->{'dblClubCustomDbl1'}[0] !~
                      /^Custom Club Number/
                ) ? $CommonVals->{'CustomFields'}->{'dblClubCustomDbl1'}[0]
                : '',
                {
                    displaytype => 'text',
                    fieldtype   => 'text',
                    allowsort   => 0,
                    optiongroup => 'customfields'
                }
            ],
            dblClubCustomDbl2 => [
                (
                    $CommonVals->{'CustomFields'}->{'dblClubCustomDbl2'}[0] !~
                      /^Custom Club Number/
                ) ? $CommonVals->{'CustomFields'}->{'dblClubCustomDbl2'}[0]
                : '',
                {
                    displaytype => 'text',
                    fieldtype   => 'text',
                    allowsort   => 0,
                    optiongroup => 'customfields'
                }
            ],
            dblClubCustomDbl3 => [
                (
                    $CommonVals->{'CustomFields'}->{'dblClubCustomDbl3'}[0] !~
                      /^Custom Club Number/
                ) ? $CommonVals->{'CustomFields'}->{'dblClubCustomDbl3'}[0]
                : '',
                {
                    displaytype => 'text',
                    fieldtype   => 'text',
                    allowsort   => 0,
                    optiongroup => 'customfields'
                }
            ],
            dblClubCustomDbl4 => [
                (
                    $CommonVals->{'CustomFields'}->{'dblClubCustomDbl4'}[0] !~
                      /^Custom Club Number/
                ) ? $CommonVals->{'CustomFields'}->{'dblClubCustomDbl4'}[0]
                : '',
                {
                    displaytype => 'text',
                    fieldtype   => 'text',
                    allowsort   => 0,
                    optiongroup => 'customfields'
                }
            ],
            dblClubCustomDbl5 => [
                (
                    $CommonVals->{'CustomFields'}->{'dblClubCustomDbl5'}[0] !~
                      /^Custom Club Number/
                ) ? $CommonVals->{'CustomFields'}->{'dblClubCustomDbl5'}[0]
                : '',
                {
                    displaytype => 'text',
                    fieldtype   => 'text',
                    allowsort   => 0,
                    optiongroup => 'customfields'
                }
            ],
            dblClubCustomDbl6 => [
                (
                    $CommonVals->{'CustomFields'}->{'dblClubCustomDbl6'}[0] !~
                      /^Custom Club Number/
                ) ? $CommonVals->{'CustomFields'}->{'dblClubCustomDbl6'}[0]
                : '',
                {
                    displaytype => 'text',
                    fieldtype   => 'text',
                    allowsort   => 0,
                    optiongroup => 'customfields'
                }
            ],
            dblClubCustomDbl7 => [
                (
                    $CommonVals->{'CustomFields'}->{'dblClubCustomDbl7'}[0] !~
                      /^Custom Club Number/
                ) ? $CommonVals->{'CustomFields'}->{'dblClubCustomDbl7'}[0]
                : '',
                {
                    displaytype => 'text',
                    fieldtype   => 'text',
                    allowsort   => 0,
                    optiongroup => 'customfields'
                }
            ],
            dblClubCustomDbl8 => [
                (
                    $CommonVals->{'CustomFields'}->{'dblClubCustomDbl8'}[0] !~
                      /^Custom Club Number/
                ) ? $CommonVals->{'CustomFields'}->{'dblClubCustomDbl8'}[0]
                : '',
                {
                    displaytype => 'text',
                    fieldtype   => 'text',
                    allowsort   => 0,
                    optiongroup => 'customfields'
                }
            ],
            dblClubCustomDbl9 => [
                (
                    $CommonVals->{'CustomFields'}->{'dblClubCustomDbl9'}[0] !~
                      /^Custom Club Number/
                ) ? $CommonVals->{'CustomFields'}->{'dblClubCustomDbl9'}[0]
                : '',
                {
                    displaytype => 'text',
                    fieldtype   => 'text',
                    allowsort   => 0,
                    optiongroup => 'customfields'
                }
            ],
            dblClubCustomDbl10 => [
                (
                    $CommonVals->{'CustomFields'}->{'dblClubCustomDbl10'}[0] !~
                      /^Custom Club Number/
                ) ? $CommonVals->{'CustomFields'}->{'dblClubCustomDbl10'}[0]
                : '',
                {
                    displaytype => 'text',
                    fieldtype   => 'text',
                    allowsort   => 0,
                    optiongroup => 'customfields'
                }
            ],
            dtClubCustomDt1 => [
                (
                    $CommonVals->{'CustomFields'}->{'dtClubCustomDt1'}[0] !~
                      /^Custom Club Date/
                ) ? $CommonVals->{'CustomFields'}->{'dtClubCustomDt1'}[0] : '',
                {
                    dbformat    => 'DATE_FORMAT(dtClubCustomDt1, "%d/%m/%Y")',
                    displaytype => 'text',
                    fieldtype   => 'text',
                    allowsort   => 0,
                    optiongroup => 'customfields'
                }
            ],
            dtClubCustomDt2 => [
                (
                    $CommonVals->{'CustomFields'}->{'dtClubCustomDt2'}[0] !~
                      /^Custom Club Date/
                ) ? $CommonVals->{'CustomFields'}->{'dtClubCustomDt2'}[0] : '',
                {
                    dbformat    => 'DATE_FORMAT(dtClubCustomDt2, "%d/%m/%Y")',
                    displaytype => 'text',
                    fieldtype   => 'text',
                    allowsort   => 0,
                    optiongroup => 'customfields'
                }
            ],
            dtClubCustomDt3 => [
                (
                    $CommonVals->{'CustomFields'}->{'dtClubCustomDt3'}[0] !~
                      /^Custom Club Date/
                ) ? $CommonVals->{'CustomFields'}->{'dtClubCustomDt3'}[0] : '',
                {
                    dbformat    => 'DATE_FORMAT(dtClubCustomDt3, "%d/%m/%Y")',
                    displaytype => 'text',
                    fieldtype   => 'text',
                    allowsort   => 0,
                    optiongroup => 'customfields'
                }
            ],
            dtClubCustomDt4 => [
                (
                    $CommonVals->{'CustomFields'}->{'dtClubCustomDt4'}[0] !~
                      /^Custom Club Date/
                ) ? $CommonVals->{'CustomFields'}->{'dtClubCustomDt4'}[0] : '',
                {
                    dbformat    => 'DATE_FORMAT(dtClubCustomDt4, "%d/%m/%Y")',
                    displaytype => 'text',
                    fieldtype   => 'text',
                    allowsort   => 0,
                    optiongroup => 'customfields'
                }
            ],
            dtClubCustomDt5 => [
                (
                    $CommonVals->{'CustomFields'}->{'dtClubCustomDt5'}[0] !~
                      /^Custom Club Date/
                ) ? $CommonVals->{'CustomFields'}->{'dtClubCustomDt5'}[0] : '',
                {
                    dbformat    => 'DATE_FORMAT(dtClubCustomDt5, "%d/%m/%Y")',
                    displaytype => 'text',
                    fieldtype   => 'text',
                    allowsort   => 0,
                    optiongroup => 'customfields'
                }
            ],

            intClubCustomLU1 => [
                (
                    $CommonVals->{'CustomFields'}->{'intClubCustomLU1'}[0] !~
                      /^Custom Club Look/
                ) ? $CommonVals->{'CustomFields'}->{'intClubCustomLU1'}[0] : '',
                {
                    displaytype     => 'lookup',
                    fieldtype       => 'dropdown',
                    dropdownoptions => $CommonVals->{'DefCodes'}{-81},
                    optiongroup     => 'customfields',
                    size            => 3,
                    multiple        => 1
                }
            ],
            intClubCustomLU2 => [
                (
                    $CommonVals->{'CustomFields'}->{'intClubCustomLU2'}[0] !~
                      /^Custom Club Look/
                ) ? $CommonVals->{'CustomFields'}->{'intClubCustomLU2'}[0] : '',
                {
                    displaytype     => 'lookup',
                    fieldtype       => 'dropdown',
                    dropdownoptions => $CommonVals->{'DefCodes'}{-82},
                    optiongroup     => 'customfields',
                    size            => 3,
                    multiple        => 1
                }
            ],
            intClubCustomLU3 => [
                (
                    $CommonVals->{'CustomFields'}->{'intClubCustomLU3'}[0] !~
                      /^Custom Club Look/
                ) ? $CommonVals->{'CustomFields'}->{'intClubCustomLU3'}[0] : '',
                {
                    displaytype     => 'lookup',
                    fieldtype       => 'dropdown',
                    dropdownoptions => $CommonVals->{'DefCodes'}{-83},
                    optiongroup     => 'customfields',
                    size            => 3,
                    multiple        => 1
                }
            ],
            intClubCustomLU4 => [
                (
                    $CommonVals->{'CustomFields'}->{'intClubCustomLU4'}[0] !~
                      /^Custom Club Look/
                ) ? $CommonVals->{'CustomFields'}->{'intClubCustomLU4'}[0] : '',
                {
                    displaytype     => 'lookup',
                    fieldtype       => 'dropdown',
                    dropdownoptions => $CommonVals->{'DefCodes'}{-84},
                    optiongroup     => 'customfields',
                    size            => 3,
                    multiple        => 1
                }
            ],
            intClubCustomLU5 => [
                (
                    $CommonVals->{'CustomFields'}->{'intClubCustomLU5'}[0] !~
                      /^Custom Club Look/
                ) ? $CommonVals->{'CustomFields'}->{'intClubCustomLU5'}[0] : '',
                {
                    displaytype     => 'lookup',
                    fieldtype       => 'dropdown',
                    dropdownoptions => $CommonVals->{'DefCodes'}{-85},
                    optiongroup     => 'customfields',
                    size            => 3,
                    multiple        => 1
                }
            ],
            intClubCustomLU6 => [
                (
                    $CommonVals->{'CustomFields'}->{'intClubCustomLU6'}[0] !~
                      /^Custom Club Look/
                ) ? $CommonVals->{'CustomFields'}->{'intClubCustomLU6'}[0] : '',
                {
                    displaytype     => 'lookup',
                    fieldtype       => 'dropdown',
                    dropdownoptions => $CommonVals->{'DefCodes'}{-86},
                    optiongroup     => 'customfields',
                    size            => 3,
                    multiple        => 1
                }
            ],
            intClubCustomLU7 => [
                (
                    $CommonVals->{'CustomFields'}->{'intClubCustomLU7'}[0] !~
                      /^Custom Club Look/
                ) ? $CommonVals->{'CustomFields'}->{'intClubCustomLU7'}[0] : '',
                {
                    displaytype     => 'lookup',
                    fieldtype       => 'dropdown',
                    dropdownoptions => $CommonVals->{'DefCodes'}{-87},
                    optiongroup     => 'customfields',
                    size            => 3,
                    multiple        => 1
                }
            ],
            intClubCustomLU8 => [
                (
                    $CommonVals->{'CustomFields'}->{'intClubCustomLU8'}[0] !~
                      /^Custom Club Look/
                ) ? $CommonVals->{'CustomFields'}->{'intClubCustomLU8'}[0] : '',
                {
                    displaytype     => 'lookup',
                    fieldtype       => 'dropdown',
                    dropdownoptions => $CommonVals->{'DefCodes'}{-88},
                    optiongroup     => 'customfields',
                    size            => 3,
                    multiple        => 1
                }
            ],
            intClubCustomLU9 => [
                (
                    $CommonVals->{'CustomFields'}->{'intClubCustomLU9'}[0] !~
                      /^Custom Club Look/
                ) ? $CommonVals->{'CustomFields'}->{'intClubCustomLU9'}[0] : '',
                {
                    displaytype     => 'lookup',
                    fieldtype       => 'dropdown',
                    dropdownoptions => $CommonVals->{'DefCodes'}{-89},
                    optiongroup     => 'customfields',
                    size            => 3,
                    multiple        => 1
                }
            ],
            intClubCustomLU10 => [
                (
                    $CommonVals->{'CustomFields'}->{'intClubCustomLU10'}[0] !~
                      /^Custom Club Look/
                ) ? $CommonVals->{'CustomFields'}->{'intClubCustomLU10'}[0]
                : '',
                {
                    displaytype     => 'lookup',
                    fieldtype       => 'dropdown',
                    dropdownoptions => $CommonVals->{'DefCodes'}{-90},
                    optiongroup     => 'customfields',
                    size            => 3,
                    multiple        => 1
                }
            ],
            intClubCustomBool1 => [
                (
                    $CommonVals->{'CustomFields'}->{'intClubCustomBool1'}[0] !~
                      /^Custom Club Check/
                ) ? $CommonVals->{'CustomFields'}->{'intClubCustomBool1'}[0]
                : '',
                {
                    displaytype => 'text',
                    fieldtype   => 'text',
                    allowsort   => 0,
                    optiongroup => 'customfields'
                }
            ],
            intClubCustomBool2 => [
                (
                    $CommonVals->{'CustomFields'}->{'intClubCustomBool2'}[0] !~
                      /^Custom Club Check/
                ) ? $CommonVals->{'CustomFields'}->{'intClubCustomBool2'}[0]
                : '',
                {
                    displaytype => 'text',
                    fieldtype   => 'text',
                    allowsort   => 0,
                    optiongroup => 'customfields'
                }
            ],
            intClubCustomBool3 => [
                (
                    $CommonVals->{'CustomFields'}->{'intClubCustomBool3'}[0] !~
                      /^Custom Club Check/
                ) ? $CommonVals->{'CustomFields'}->{'intClubCustomBool3'}[0]
                : '',
                {
                    displaytype => 'text',
                    fieldtype   => 'text',
                    allowsort   => 0,
                    optiongroup => 'customfields'
                }
            ],
            intClubCustomBool4 => [
                (
                    $CommonVals->{'CustomFields'}->{'intClubCustomBool4'}[0] !~
                      /^Custom Club Check/
                ) ? $CommonVals->{'CustomFields'}->{'intClubCustomBool4'}[0]
                : '',
                {
                    displaytype => 'text',
                    fieldtype   => 'text',
                    allowsort   => 0,
                    optiongroup => 'customfields'
                }
            ],
            intClubCustomBool5 => [
                (
                    $CommonVals->{'CustomFields'}->{'intClubCustomBool5'}[0] !~
                      /^Custom Club Check/
                ) ? $CommonVals->{'CustomFields'}->{'intClubCustomBool5'}[0]
                : '',
                {
                    displaytype => 'text',
                    fieldtype   => 'text',
                    allowsort   => 0,
                    optiongroup => 'customfields'
                }
            ],

            intContactRoleID => [
                'Role',
                {
                    displaytype     => 'lookup',
                    fieldtype       => 'dropdown',
                    dropdownoptions => $CommonVals->{'ContactRoles'}{'Values'},
                    dropdownorder   => $CommonVals->{'ContactRoles'}{'Order'},
                    allowsort       => 1,
                    size            => 3,
                    multiple        => 1,
                    dbfield         => 'intContactRoleID',
                    allowgrouping   => 1,
                    optiongroup     => 'contacts'
                }
            ],
            ContactType => [
                'Contact Type',
                {
                    displaytype     => 'lookup',
                    fieldtype       => 'dropdown',
                    dropdownoptions => {
                        0                  => 'All',
                        $Defs::LEVEL_CLUB  => 'Club',
                        $Defs::LEVEL_ASSOC => 'Association'
                    },
                    dropdownorder =>
                      [ 0, $Defs::LEVEL_CLUB, $Defs::LEVEL_ASSOC ],
                    optiongroup     => 'contacts',
                    dbfield =>
"IF(tblContacts.intClubID = 0, $Defs::LEVEL_ASSOC, $Defs::LEVEL_CLUB)"
                }
            ],

            strContactFirstname => [
                'Firstname',
                {
                    displaytype => 'text',
                    fieldtype   => 'text',
                    active      => 1,
                    allowsort   => 1,
                    dbfield     => 'strContactFirstname',
                    optiongroup => 'contacts'
                }
            ],
            strContactSurname => [
                'Surname',
                {
                    displaytype => 'text',
                    fieldtype   => 'text',
                    active      => 1,
                    allowsort   => 1,
                    dbfield     => 'strContactSurname',
                    optiongroup => 'contacts'
                }
            ],
            intContactGender => [
                'Gender',
                {
                    displaytype => 'lookup',
                    fieldtype   => 'dropdown',
                    dropdownoptions =>
                      { '' => '&nbsp;', 1 => 'Male', 2 => 'Female' },
                    dropdownorder => [ '', 1, 2 ],
                    size          => 2,
                    multiple      => 1,
                    optiongroup   => 'contacts',
                    allowgrouping => 1
                }
            ],
            strContactEmail => [
                'Email',
                {
                    displaytype => 'text',
                    fieldtype   => 'text',
                    active      => 1,
                    allowsort   => 1,
                    dbfield     => 'strContactEmail',
                    optiongroup => 'contacts'
                }
            ],
            strContactMobile => [
                'Mobile',
                {
                    displaytype => 'text',
                    fieldtype   => 'text',
                    active      => 1,
                    allowsort   => 1,
                    dbfield     => 'strContactMobile',
                    optiongroup => 'contacts'
                }
            ],
            intFnCompAdmin => [
                'Competition Admin',
                {
                    displaytype     => 'lookup',
                    fieldtype       => 'dropdown',
                    dropdownoptions => { 0 => 'No', 1 => 'Yes' },
                    dropdownorder => [ 0, 1 ],
                    optiongroup   => 'contacts'
                }
            ],
            intFnSocial => [
                'Social Activities',
                {
                    displaytype     => 'lookup',
                    fieldtype       => 'dropdown',
                    dropdownoptions => { 0 => 'No', 1 => 'Yes' },
                    dropdownorder => [ 0, 1 ],
                    optiongroup   => 'contacts'
                }
            ],
            intFnWebsite => [
                'Website and Publicity',
                {
                    displaytype     => 'lookup',
                    fieldtype       => 'dropdown',
                    dropdownoptions => { 0 => 'No', 1 => 'Yes' },
                    dropdownorder => [ 0, 1 ],
                    optiongroup   => 'contacts'
                }
            ],
            intFnClearances => [
                "$txt_Clr and Permits",
                {
                    displaytype     => 'lookup',
                    fieldtype       => 'dropdown',
                    dropdownoptions => { 0 => 'No', 1 => 'Yes' },
                    dropdownorder => [ 0, 1 ],
                    optiongroup   => 'contacts'
                }
            ],
            intFnSponsorship => [
                'Sponsors and Fundraising',
                {
                    displaytype     => 'lookup',
                    fieldtype       => 'dropdown',
                    dropdownoptions => { 0 => 'No', 1 => 'Yes' },
                    dropdownorder => [ 0, 1 ],
                    optiongroup   => 'contacts'
                }
            ],
            intFnSponsorship => [
                'Sponsors and Fundraising',
                {
                    displaytype     => 'lookup',
                    fieldtype       => 'dropdown',
                    dropdownoptions => { 0 => 'No', 1 => 'Yes' },
                    dropdownorder => [ 0, 1 ],
                    optiongroup   => 'contacts'
                }
            ],
            intFnPayments => [
                'Finance & Payments',
                {
                    displaytype     => 'lookup',
                    fieldtype       => 'dropdown',
                    dropdownoptions => { 0 => 'No', 1 => 'Yes' },
                    dropdownorder => [ 0, 1 ],
                    optiongroup   => 'contacts'
                }
            ],
            intFnLegal => [
                'Legal & Contracts',
                {
                    displaytype     => 'lookup',
                    fieldtype       => 'dropdown',
                    dropdownoptions => { 0 => 'No', 1 => 'Yes' },
                    dropdownorder => [ 0, 1 ],
                    optiongroup   => 'contacts'
                }
            ],
            intPrimaryContact => [
                'Primary Contact',
                {
                    displaytype     => 'lookup',
                    fieldtype       => 'dropdown',
                    dropdownoptions => { 0 => 'No', 1 => 'Yes' },
                    dropdownorder => [ 0, 1 ],
                    optiongroup   => 'contacts'
                }
            ],
            intShowInLocator => [
                'Show in Locator',
                {
                    displaytype     => 'lookup',
                    fieldtype       => 'dropdown',
                    dropdownoptions => { 0 => 'No', 1 => 'Yes' },
                    dropdownorder => [ 0, 1 ],
                    optiongroup   => 'contacts'
                }
            ],

            intCharacteristicID => [
                'Characteristics',
                {
                    displaytype => 'lookup',
                    fieldtype   => 'dropdown',
                    dropdownoptions =>
                      $CommonVals->{'ClubCharacteristics'}{'Values'},
                    dropdownorder =>
                      $CommonVals->{'ClubCharacteristics'}{'Order'},
                    optiongroup => 'characteristics',
                    size        => 3,
                    multiple    => 1
                }
            ],

            PrimaryRegoFormID => [
                'Primary Reg Form ID',
                {
                    displaytype     => 'text',
                    fieldtype       => 'text',
                    optiongroup     => 'regoform',
                    dbfield         => 'tblRegoFormPrimary.intRegoFormID',
                    dbfrom          => "
LEFT JOIN tblRegoFormPrimary ON (tblRegoFormPrimary.intEntityTypeID = $Defs::LEVEL_CLUB AND tblRegoFormPrimary.intEntityID = tblClub.intClubID)",
                }
            ],


            PrimaryRegoFormName => [
                'Primary Reg Form Name',
                {
                    displaytype     => 'text',
                    fieldtype       => 'text',
                    optiongroup     => 'regoform',
                    dbfield         => 'tblRegoFormPrimary.intRegoFormID',
                    dbfrom          => "
LEFT JOIN tblRegoFormPrimary ON (tblRegoFormPrimary.intEntityTypeID = $Defs::LEVEL_CLUB AND tblRegoFormPrimary.intEntityID = tblClub.intClubID)",
                }
            ],

            RegoFormID => [
                'Reg Form ID',
                {
                    displaytype     => 'text',
                    fieldtype       => 'text',
                    optiongroup     => 'regoform',
                    dbfield         => 'tblRegoForm.intRegoFormID',
                }
            ],

            RegoFormName => [
                'Reg Form Name',
                {
                    displaytype     => 'text',
                    fieldtype       => 'text',
                    optiongroup     => 'regoform',
                    dbfield         => 'tblRegoForm.strRegoFormName',
                }
            ],

            RegoFormType => [
                'Reg Form Type',
                {
                    displaytype     => 'text',
                    fieldtype       => 'text',
                    optiongroup     => 'regoform',
                    dbfield         => qq[
                        CASE tblRegoForm.intRegoType 
                            WHEN 1 THEN 'Member to Association'
                            WHEN 2 THEN 'Team to Association'
                            WHEN 3 THEN 'Member to Team'
                            WHEN 4 THEN 'Member to Club'
                        END
                    ],
                }
            ],

            IsPrimaryRegoForm => [
                'Is Primary Reg Form',
                {
                    displaytype     => 'lookup',
                    fieldtype       => 'dropdown',
                    dropdownoptions => { 0 => 'No', 1 => 'Yes', },
                    optiongroup     => 'regoform',
                    dbfield         => 'IF(tblRegoForm.intRegoFormID=tblRegoFormPrimary.intRegoFormID, 1, 0)',
                    dbfrom          => "
LEFT JOIN tblRegoFormPrimary ON (tblRegoFormPrimary.intEntityTypeID = $Defs::LEVEL_CLUB AND tblRegoFormPrimary.intEntityID = tblClub.intClubID)",
                }
            ],

            IsNationalRegoForm => [
                'Is National Reg Form',
                {
                    displaytype     => 'lookup',
                    fieldtype       => 'dropdown',
                    dropdownoptions => { 0 => 'No', 1 => 'Yes', },
                    optiongroup     => 'regoform',
                    dbfield         => "IF(tblRegoForm.intCreatedLevel > $Defs::LEVEL_ASSOC, 1, 0)",
                }
            ],

            IsLinkToNationalRegoForm => [
                'Is Link To National Reg Form',
                {
                    displaytype     => 'lookup',
                    fieldtype       => 'dropdown',
                    dropdownoptions => { 0 => 'No', 1 => 'Yes', },
                    optiongroup     => 'regoform',
                    dbfield         => "IF(LinkRegoForm.intRegoFormID IS NOT NULL, 1, 0)",
                    dbfrom          => "
LEFT JOIN tblRegoForm AS LinkRegoForm ON (LinkRegoForm.intRegoFormID = tblRegoForm.intParentBodyFormID AND LinkRegoForm.intCreatedLevel > $Defs::LEVEL_ASSOC AND LinkRegoForm.intStatus > 0)
                    "
                }
            ],

        },

        Order => [
            qw(
              intRecStatus
              strName
              intLogins
              strUsername
              strPassword
              strIncNo
              strAbbrev
              strColours
              strContactTitle
              strContact
              strAddress1
              strAddress2
              strSuburb
              strState
              strLGA
              strDevelRegion
              strClubZone
              intAgeTypeID
              intClubCategoryID
              intClubTypeID
              strPostalCode
              strPhone
              strFax
              strEmail
              strAssocName
              intAssocTypeID
              intAssocCategoryID
              strZoneName
              strRegionName
              strStateName
              strNationalName
              strIntZoneName
              strIntRegionName

              AServ_strPresidentName
              AServ_strPresidentEmail
              AServ_strPresidentPhone
              AServ_strSecretaryName
              AServ_strSecretaryEmail
              AServ_strSecretaryPhone
              AServ_strTreasurerName
              AServ_strTreasurerEmail
              AServ_strTreasurerPhone
              AServ_strRegistrarName
              AServ_strRegistrarEmail
              AServ_strRegistrarPhone
              AServ_strVenueName
              AServ_strVenueAddress
              AServ_strVenueAddress2
              AServ_strVenueSuburb
              AServ_strVenueState
              AServ_strVenuePostalCode
              AServ_strVenueCountry
              AServ_dblLat
              AServ_dblLong
              AServ_strEmail
              AServ_strURL
              AServ_intMon
              AServ_intTue
              AServ_intWed
              AServ_intThu
              AServ_intFri
              AServ_intSat
              AServ_intSun
              AServ_strSessionDurations
              AServ_strTimes
              AServ_intPublicShow
              AServ_dtStart
              AServ_PostalCodes
              strClubCustomStr1
              strClubCustomStr2

              strClubCustomStr3
              strClubCustomStr4
              strClubCustomStr5
              strClubCustomStr6
              strClubCustomStr7
              strClubCustomStr8
              strClubCustomStr9
              strClubCustomStr10
              strClubCustomStr11
              strClubCustomStr12
              strClubCustomStr13
              strClubCustomStr14
              strClubCustomStr15

              dblClubCustomDbl1
              dblClubCustomDbl2
              dblClubCustomDbl3
              dblClubCustomDbl4
              dblClubCustomDbl5
              dblClubCustomDbl6
              dblClubCustomDbl7
              dblClubCustomDbl8
              dblClubCustomDbl9
              dblClubCustomDbl10
              dtClubCustomDt1
              dtClubCustomDt2
              dtClubCustomDt3
              dtClubCustomDt4
              dtClubCustomDt5
              intClubCustomBool1
              intClubCustomBool2
              intClubCustomBool3
              intClubCustomBool4
              intClubCustomBool5
              intClubCustomLU1
              intClubCustomLU2
              intClubCustomLU3
              intClubCustomLU4
              intClubCustomLU5
              intClubCustomLU6
              intClubCustomLU7
              intClubCustomLU8
              intClubCustomLU9
              intClubCustomLU10

              intContactRoleID
              ContactType
              strContactFirstname
              strContactSurname
              intContactGender
              strContactEmail
              strContactMobile
              intFnCompAdmin
              intFnSocial
              intFnWebsite
              intFnClearances
              intFnSponsorship
              intFnPayments
              intFnLegal
              intPrimaryContact
              intShowInLocator

              intCharacteristicID

              PrimaryRegoFormID
              IsPrimaryRegoForm
              RegoFormID
              RegoFormName
              RegoFormType
              IsNationalRegoForm
              IsLinkToNationalRegoForm
              )
        ],
        OptionGroups => {
            default        => [ 'Details', {} ],
            assoc_services => [
                'Club Services',
                {
                    from =>
"LEFT JOIN tblAssocServices as AServ ON (tblAssoc.intAssocID = AServ.intAssocID AND tblClub.intClubID=AServ.intClubID)",
                    enabled => $Data->{'SystemConfig'}{'AssocClubServices'},
                }
            ],
            customfields => [ 'Other Fields', {} ],
            contacts     => [
                'Contacts',
                {
                    from =>
"LEFT JOIN tblContacts ON (tblContacts.intClubID = tblClub.intClubID)",
                }
            ],
            characteristics => [
                'Characteristics',
                {
                    from =>
"LEFT JOIN tblClubCharacteristics ON (tblClubCharacteristics.intClubID = tblClub.intClubID )",
                }
            ],
            regoform => [
                'Registration Form',
                {
                    from => "
LEFT JOIN tblRegoForm ON 
    (
        (
            (tblRegoForm.intAssocID = tblAssoc.intAssocID AND tblRegoForm.intClubID = tblClub.intClubID)
            OR 
            (tblRegoForm.intRealmID = $realm_id AND tblRegoForm.intAssocID = -1 AND tblRegoForm.intClubID = -1)
        )
        AND tblRegoForm.intStatus > 0
    )
                    ",
                }
            ],
        },

        Config => {
            FormFieldPrefix    => 'c',
            FormName           => 'clubform_',
            EmailExport        => 1,
            limitView          => 5000,
            EmailSenderAddress => $Defs::admin_email,
            SecondarySort      => 1,
            RunButtonLabel     => 'Run Report',
            ReturnProcessData  => [qw(tblClub.strEmail tblClub.strName)],
        },
    );

        $config{'Fields'} = {
            %{$config{'Fields'}},
            strUsername => [
                'Username',
                {
                    displaytype => 'text',
                    fieldtype   => 'text',
                    allowsort   => 1,
                    dbfield     => "CONCAT('3', tblAuth.strUsername)",
                    dbfrom =>
"LEFT JOIN tblAuth ON (tblClub.intClubID = tblAuth.intID and tblAuth.intLevel=3)",
                }
            ],
        };
    if ($Data->{'SystemConfig'}{'AssocConfig'}{'ShowPassword'}) {
        $config{'Fields'} = {
            %{$config{'Fields'}},
            strPassword => [
                'Password',
                {
                    displaytype => 'text',
                    fieldtype   => 'text',
                    allowsort   => 1,
                    dbfrom =>
"LEFT JOIN tblAuth ON (tblClub.intClubID = tblAuth.intID and tblAuth.intLevel=3)",
                }
            ],
        };
    }
    $self->{'Config'} = \%config;
}

1;

# vim: set et sw=4 ts=4:
