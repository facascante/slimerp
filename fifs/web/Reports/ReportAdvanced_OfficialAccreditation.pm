#
# $Header: svn://svn/SWM/trunk/web/Reports/ReportAdvanced_OfficialAccreditation.pm 9966 2013-11-27 05:28:08Z sliu $
#

package Reports::ReportAdvanced_OfficialAccreditation;

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
    my $SystemConfig = $Data->{'SystemConfig'};
    my $natnumname =
      $Data->{'SystemConfig'}{'NationalNumName'} || 'National Number';

    my $AccredExposedIDs = $SystemConfig->{'AccredExpose'} || '';
    my $exposed_IDs = 0;
    if ($AccredExposedIDs) {
        my @ids = split /\s*\|\s*/, $AccredExposedIDs;
        $exposed_IDs = join( ',', @ids );
    }
    my $CommonVals = getCommonValues(
        $Data,
        {
            DefCodes    => 1,
            Countries   => 1,
            FieldLabels => 1,
        },
    );

    my $FieldLabels = $CommonVals->{'FieldLabels'} || undef;
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

    my $umpire_dbfrom = qq[
    LEFT JOIN tblMember_Types AS tblMT_Ac_Umpire ON (
        tblMember.intMemberID=tblMT_Ac_Umpire.intMemberID 
            AND tblMT_Ac_Umpire.intTypeID=$Defs::MEMBER_TYPE_UMPIRE 
            AND tblMT_Ac_Umpire.intSubTypeID=1 
            AND tblMT_Ac_Umpire.intAssocID IN ($exposed_IDs)
            AND tblMT_Ac_Umpire.intRecStatus = $Defs::RECSTATUS_ACTIVE
    )
    ];
    my $official_dbfrom = qq[
    LEFT JOIN tblMember_Types AS tblMT_Ac_Official ON (
        tblMember.intMemberID=tblMT_Ac_Official.intMemberID 
            AND tblMT_Ac_Official.intTypeID=$Defs::MEMBER_TYPE_OFFICIAL
            AND tblMT_Ac_Official.intSubTypeID=1 
            AND tblMT_Ac_Official.intAssocID IN ($exposed_IDs)
            AND tblMT_Ac_Official.intRecStatus = $Defs::RECSTATUS_ACTIVE
    )
    ];
    my $coach_dbfrom = qq[
    LEFT JOIN tblMember_Types AS tblMT_Ac_Coach ON (
        tblMember.intMemberID=tblMT_Ac_Coach.intMemberID
            AND tblMT_Ac_Coach.intTypeID=$Defs::MEMBER_TYPE_COACH
            AND tblMT_Ac_Coach.intSubTypeID=1
            AND tblMT_Ac_Coach.intAssocID IN ($exposed_IDs)
            AND tblMT_Ac_Coach.intRecStatus = $Defs::RECSTATUS_ACTIVE
    )
    ];

    my %config = (
        Name => 'National Accreditation Report',

        StatsReport  => 0,
        MemberTeam   => 0,
        ReportEntity => 1,
        ReportLevel  => 0,

        #Template => 'default_adv_CSV',
        Template       => 'default_adv',
        TemplateEmail  => 'default_adv_CSV',
        DistinctValues => 1,

        SQLBuilder => \&SQLBuilder,
        Fields     => {
            strNationalNum => [
                $natnumname,
                {
                    displaytype => 'text',
                    fieldtype   => 'text',
                    allowsort   => 1,
                    optiongroup => 'details'
                }
            ],
            MemberID => [
                'Member ID',
                {
                    displaytype => 'text',
                    fieldtype   => 'text',
                    allowsort   => 1,
                    optiongroup => 'details',
                    dbfield     => 'tblMember.intMemberID'
                }
            ],
            strMemberNo => [
                $Data->{'SystemConfig'}{'FieldLabel_strMemberNo'}
                  || 'Member No.',
                {
                    displaytype => 'text',
                    fieldtype   => 'text',
                    allowsort   => 1,
                    optiongroup => 'details'
                }
            ],
            intRecStatus => [
                'Active Record',
                {
                    displaytype     => 'lookup',
                    fieldtype       => 'dropdown',
                    dropdownoptions => { 0 => 'No', 1 => 'Yes' },
                    dropdownorder => [ 0, 1 ],
                    dbfield       => 'tblMember_Associations.intRecStatus',
                    defaultcomp   => 'equal',
                    defaultvalue  => '1',
                    active        => 1,
                    optiongroup   => 'details'
                }
            ],

            strSalutation => [
                'Salutation',
                {
                    displaytype   => 'text',
                    fieldtype     => 'text',
                    allowsort     => 1,
                    optiongroup   => 'details',
                    allowgrouping => 1
                }
            ],

            strFirstname => [
                'First Name',
                {
                    displaytype => 'text',
                    fieldtype   => 'text',
                    active      => 1,
                    allowsort   => 1,
                    optiongroup => 'details'
                }
            ],

            strSurname => [
                'Family Name',
                {
                    displaytype   => 'text',
                    fieldtype     => 'text',
                    active        => 1,
                    allowsort     => 1,
                    optiongroup   => 'details',
                    allowgrouping => 1
                }
            ],

            strPreferredName => [
                'Preferred Name',
                {
                    displaytype => 'text',
                    fieldtype   => 'text',
                    allowsort   => 1,
                    optiongroup => 'details'
                }
            ],

            dtDOB => [
                'Date of Birth',
                {
                    displaytype => 'date',
                    fieldtype   => 'date',
                    allowsort   => 1,
                    dbfield     => 'tblMember.dtDOB',
                    dbformat    => ' DATE_FORMAT(tblMember.dtDOB, "%d/%m/%Y")',
                    optiongroup => 'details'
                }
            ],

            dtYOB => [
                'Year of Birth',
                {
                    displaytype   => 'date',
                    fieldtype     => 'text',
                    allowgrouping => 1,
                    allowsort     => 1,
                    dbfield       => 'YEAR(tblMember.dtDOB)',
                    dbformat      => ' YEAR(tblMember.dtDOB)',
                    optiongroup   => 'details'
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
                    size          => 2,
                    multiple      => 1,
                    optiongroup   => 'details',
                    allowgrouping => 1
                }
            ],

            strAddress1 => [
                'Address 1',
                {
                    displaytype => 'text',
                    fieldtype   => 'text',
                    dbfield     => 'tblMember.strAddress1',
                    optiongroup => 'contactdetails'
                }
            ],

            strAddress2 => [
                'Address 2',
                {
                    displaytype => 'text',
                    fieldtype   => 'text',
                    dbfield     => 'tblMember.strAddress2',
                    optiongroup => 'contactdetails'
                }
            ],

            strSuburb => [
                'Suburb',
                {
                    displaytype   => 'text',
                    fieldtype     => 'text',
                    dbfield       => 'tblMember.strSuburb',
                    allowsort     => 1,
                    optiongroup   => 'contactdetails',
                    allowgrouping => 1
                }
            ],

            strState => [
                'State',
                {
                    displaytype   => 'text',
                    fieldtype     => 'text',
                    dbfield       => 'tblMember.strState',
                    allowsort     => 1,
                    optiongroup   => 'contactdetails',
                    allowgrouping => 1
                }
            ],

            strCountry => [
                'Country',
                {
                    displaytype   => 'text',
                    fieldtype     => 'text',
                    dbfield       => 'tblMember.strCountry',
                    allowsort     => 1,
                    optiongroup   => 'contactdetails',
                    allowgrouping => 1
                }
            ],

            strPostalCode => [
                'Postal Code',
                {
                    displaytype   => 'text',
                    fieldtype     => 'text',
                    dbfield       => 'tblMember.strPostalCode',
                    allowsort     => 1,
                    optiongroup   => 'contactdetails',
                    allowgrouping => 1
                }
            ],

            strPhoneHome => [
                'Home Phone',
                {
                    displaytype => 'text',
                    fieldtype   => 'text',
                    optiongroup => 'contactdetails'
                }
            ],

            strPhoneWork => [
                'Work Phone',
                {
                    displaytype => 'text',
                    fieldtype   => 'text',
                    optiongroup => 'contactdetails'
                }
            ],

            strPhoneMobile => [
                'Mobile Phone',
                {
                    displaytype => 'text',
                    fieldtype   => 'text',
                    optiongroup => 'contactdetails'
                }
            ],

            strEmail => [
                'Email',
                {
                    displaytype => 'text',
                    fieldtype   => 'text',
                    dbfield     => 'tblMember.strEmail',
                    optiongroup => 'contactdetails'
                }
            ],
            intEthnicityID => [
                'Ethnicity',
                {
                    displaytype     => 'lookup',
                    fieldtype       => 'dropdown',
                    dropdownoptions => $CommonVals->{'DefCodes'}{-8},
                    optiongroup     => 'details'
                }
            ],
            ## COACH STUFF
            intCoachReAccreditation => [
                $NRO{'Accreditation'} ? 'Coach Accred. Re Accreditation' : '',
                {
                    displaytype     => 'lookup',
                    fieldtype       => 'dropdown',
                    dropdownoptions => { 0 => 'No', 1 => 'Yes' },
                    dropdownorder => [ 0, 1 ],
                    dbfield       => 'tblMT_Ac_Coach.intInt7',
                    optiongroup   => 'mt_coach',
                    dbfrom        => $coach_dbfrom
                }
            ],
            intCoachAccredActive => [
                $NRO{'Accreditation'}
                ? 'Coach Accred. ' . $FieldLabels->{'Accred.intActive'}
                  || 'Coach Accred. Active ?'
                : '',
                {
                    displaytype     => 'lookup',
                    fieldtype       => 'dropdown',
                    dropdownoptions => { 0 => 'No', 1 => 'Yes' },
                    dropdownorder => [ 0, 1 ],
                    dbfield       => 'tblMT_Ac_Coach.intActive',
                    optiongroup   => 'mt_coach',
                    dbfrom        => $coach_dbfrom
                }
            ],
            strCoachAccredType => [
                $NRO{'Accreditation'}
                ? 'Coach Accred. ' . $FieldLabels->{'Accred.intInt1'}
                  || 'Coach Accred. Type'
                : '',
                {
                    displaytype     => 'lookup',
                    fieldtype       => 'dropdown',
                    multiple        => 1,
                    size            => 7,
                    dropdownoptions => $CommonVals->{'DefCodes'}{-35},
                    dbfield         => 'tblMT_Ac_Coach.intInt1',
                    optiongroup     => 'mt_coach',
                    dbfrom          => $coach_dbfrom
                }
            ],
            strCoachAccredLevel => [
                $NRO{'Accreditation'}
                ? 'Coach Accred. ' . $FieldLabels->{'Accred.intInt2'}
                  || 'Coach Accred. Level'
                : '',
                {
                    displaytype     => 'lookup',
                    fieldtype       => 'dropdown',
                    multiple        => 1,
                    size            => 7,
                    dropdownoptions => $CommonVals->{'DefCodes'}{-15},
                    dbfield         => 'tblMT_Ac_Coach.intInt2',
                    optiongroup     => 'mt_coach',
                    dbfrom          => $coach_dbfrom
                }
            ],
            strCoachAccredProv => [
                $NRO{'Accreditation'}
                ? 'Coach Accred. ' . $FieldLabels->{'Accred.intInt5'}
                  || 'Coach Accred. Provider'
                : '',
                {
                    displaytype     => 'lookup',
                    fieldtype       => 'dropdown',
                    dropdownoptions => $CommonVals->{'DefCodes'}{-32},
                    dbfield         => 'tblMT_Ac_Coach.intInt5',
                    optiongroup     => 'mt_coach',
                    dbfrom          => $coach_dbfrom
                }
            ],
            dtCoachAccredStart => [
                $NRO{'Accreditation'}
                ? 'Coach Accred. ' . $FieldLabels->{'Accred.dtDate1'}
                  || 'Coach Accred. Start Date'
                : '',
                {
                    displaytype => 'date',
                    fieldtype   => 'date',
                    dbfield     => 'tblMT_Ac_Coach.dtDate1',
                    optiongroup => 'mt_coach',
                    dbfrom      => $coach_dbfrom,
                    dbformat =>
                      'DATE_FORMAT(tblMT_Ac_Coach.dtDate1,"%d/%m/%Y")',
                    dbfield => 'tblMT_Ac_Coach.dtDate1'
                }
            ],
            dtCoachAccredEnd => [
                $NRO{'Accreditation'}
                ? 'Coach Accred. ' . $FieldLabels->{'Accred.dtDate2'}
                  || 'Coach Accred. End Date'
                : '',
                {
                    displaytype => 'date',
                    fieldtype   => 'date',
                    dbfield     => 'tblMT_Ac_Coach.dtDate2',
                    optiongroup => 'mt_coach',
                    dbfrom      => $coach_dbfrom,
                    dbformat =>
                      'DATE_FORMAT(tblMT_Ac_Coach.dtDate2,"%d/%m/%Y")',
                    dbfield => 'tblMT_Ac_Coach.dtDate2'
                }
            ],
            dtCoachAccredAppDate => [
                  $NRO{'Accreditation'}
                ? $FieldLabels->{'Accred.dtDate3'}
                      ? 'Coach Accred. ' . $FieldLabels->{'Accred.dtDate3'}
                      : '' || 'Coach Accred. Application Date'
                : '',
                {
                    displaytype => 'date',
                    fieldtype   => 'date',
                    dbfield     => 'tblMT_Ac_Coach.dtDate3',
                    optiongroup => 'mt_coach',
                    dbfrom      => $coach_dbfrom,
                    dbformat =>
                      'DATE_FORMAT(tblMT_Ac_Coach.dtDate3,"%d/%m/%Y")',
                    dbfield => 'tblMT_Ac_Coach.dtDate3'
                }
            ],
            ## Officials Stuff
            intOfficialReAccreditation => [
                $NRO{'Accreditation'}
                ? 'Official Accred. Re Accreditation'
                : '',
                {
                    displaytype     => 'lookup',
                    fieldtype       => 'dropdown',
                    dropdownoptions => { 0 => 'No', 1 => 'Yes' },
                    dropdownorder => [ 0, 1 ],
                    dbfield       => 'tblMT_Ac_Official.intInt7',
                    optiongroup   => 'mt_official',
                    dbfrom        => $official_dbfrom
                }
            ],
            intOfficialAccredActive => [
                $NRO{'Accreditation'}
                ? 'Official Accred. ' . $FieldLabels->{'Accred.intActive'}
                  || 'Official Accred. Active ?'
                : '',
                {
                    displaytype     => 'lookup',
                    fieldtype       => 'dropdown',
                    dropdownoptions => { 0 => 'No', 1 => 'Yes' },
                    dropdownorder => [ 0, 1 ],
                    dbfield       => 'tblMT_Ac_Official.intActive',
                    optiongroup   => 'mt_official',
                    dbfrom        => $official_dbfrom
                }
            ],
            strOfficialAccredType => [
                $NRO{'Accreditation'}
                ? 'Official Accred. ' . $FieldLabels->{'Accred.intInt1'}
                  || 'Official Accred. Type'
                : '',
                {
                    displaytype     => 'lookup',
                    fieldtype       => 'dropdown',
                    multiple        => 1,
                    size            => 7,
                    dropdownoptions => $CommonVals->{'DefCodes'}{-35},
                    dbfield         => 'tblMT_Ac_Official.intInt1',
                    optiongroup     => 'mt_official',
                    dbfrom          => $official_dbfrom
                }
            ],
            strOfficialAccredLevel => [
                $NRO{'Accreditation'}
                ? 'Official Accred. ' . $FieldLabels->{'Accred.intInt2'}
                  || 'Official Accred. Level'
                : '',
                {
                    displaytype     => 'lookup',
                    fieldtype       => 'dropdown',
                    multiple        => 1,
                    size            => 7,
                    dropdownoptions => $CommonVals->{'DefCodes'}{-15},
                    dbfield         => 'tblMT_Ac_Official.intInt2',
                    optiongroup     => 'mt_official',
                    dbfrom          => $official_dbfrom
                }
            ],
            strOfficialAccredProv => [
                $NRO{'Accreditation'}
                ? 'Official Accred. ' . $FieldLabels->{'Accred.intInt5'}
                  || 'Official Accred. Provider'
                : '',
                {
                    displaytype     => 'lookup',
                    fieldtype       => 'dropdown',
                    dropdownoptions => $CommonVals->{'DefCodes'}{-32},
                    dbfield         => 'tblMT_Ac_Official.intInt5',
                    optiongroup     => 'mt_official',
                    dbfrom          => $official_dbfrom
                }
            ],
            dtOfficialAccredStart => [
                $NRO{'Accreditation'}
                ? 'Official Accred. ' . $FieldLabels->{'Accred.dtDate1'}
                  || 'Official Accred. Start Date'
                : '',
                {
                    displaytype => 'date',
                    fieldtype   => 'date',
                    dbfield     => 'tblMT_Ac_Official.dtDate1',
                    optiongroup => 'mt_official',
                    dbfrom      => $official_dbfrom,
                    dbformat =>
                      'DATE_FORMAT(tblMT_Ac_Official.dtDate1,"%d/%m/%Y")',
                    dbfield => 'tblMT_Ac_Official.dtDate1'
                }
            ],
            dtOfficialAccredEnd => [
                $NRO{'Accreditation'}
                ? 'Official Accred. ' . $FieldLabels->{'Accred.dtDate2'}
                  || 'Official Accred. End Date'
                : '',
                {
                    displaytype => 'date',
                    fieldtype   => 'date',
                    dbfield     => 'tblMT_Ac_Official.dtDate2',
                    optiongroup => 'mt_official',
                    dbfrom      => $official_dbfrom,
                    dbformat =>
                      'DATE_FORMAT(tblMT_Ac_Official.dtDate2,"%d/%m/%Y")',
                    dbfield => 'tblMT_Ac_Official.dtDate2'
                }
            ],
            dtOfficialAccredAppDate => [
                  $NRO{'Accreditation'}
                ? $FieldLabels->{'Accred.dtDate3'}
                      ? 'Official Accred. ' . $FieldLabels->{'Accred.dtDate3'}
                      : '' || 'Official Accred. Application Date'
                : '',
                {
                    displaytype => 'date',
                    fieldtype   => 'date',
                    dbfield     => 'tblMT_Ac_Official.dtDate3',
                    optiongroup => 'mt_official',
                    dbfrom      => $official_dbfrom,
                    dbformat =>
                      'DATE_FORMAT(tblMT_Ac_Official.dtDate3,"%d/%m/%Y")',
                    dbfield => 'tblMT_Ac_Official.dtDate3'
                }
              ],

              #Umpire Stuff
              intUmpireReAccreditation => [
                $NRO{'Accreditation'}
                ? 'Match Official Accred. Re Accreditation'
                : '',
                {
                    displaytype     => 'lookup',
                    fieldtype       => 'dropdown',
                    dropdownoptions => { 0 => 'No', 1 => 'Yes' },
                    dropdownorder => [ 0, 1 ],
                    dbfield       => 'tblMT_Ac_Umpire.intInt7',
                    optiongroup   => 'mt_umpire',
                    dbfrom        => $umpire_dbfrom
                }
              ],
              intUmpireAccredActive => [
                $NRO{'Accreditation'}
                ? 'Match Official Accred. ' . $FieldLabels->{'Accred.intActive'}
                  || 'Match Official Accred. Active ?'
                : '',
                {
                    displaytype     => 'lookup',
                    fieldtype       => 'dropdown',
                    dropdownoptions => { 0 => 'No', 1 => 'Yes' },
                    dropdownorder => [ 0, 1 ],
                    dbfield       => 'tblMT_Ac_Umpire.intActive',
                    optiongroup   => 'mt_umpire',
                    dbfrom        => $umpire_dbfrom
                }
              ],
              strUmpireAccredType => [
                $NRO{'Accreditation'}
                ? 'Match Official Accred. ' . $FieldLabels->{'Accred.intInt1'}
                  || 'Match Official Accred. Type'
                : '',
                {
                    displaytype     => 'lookup',
                    fieldtype       => 'dropdown',
                    dropdownoptions => $CommonVals->{'DefCodes'}{-35},
                    dbfield         => 'tblMT_Ac_Umpire.intInt1',
                    optiongroup     => 'mt_umpire',
                    dbfrom          => $umpire_dbfrom
                }
              ],
              strUmpireAccredLevel => [
                $NRO{'Accreditation'}
                ? 'Match Official Accred. ' . $FieldLabels->{'Accred.intInt2'}
                  || 'Match Official Accred. Level'
                : '',
                {
                    displaytype     => 'lookup',
                    fieldtype       => 'dropdown',
                    dropdownoptions => $CommonVals->{'DefCodes'}{-15},
                    dbfield         => 'tblMT_Ac_Umpire.intInt2',
                    optiongroup     => 'mt_umpire',
                    dbfrom          => $umpire_dbfrom
                }
              ],
              strUmpireAccredProv => [
                $NRO{'Accreditation'}
                ? 'Match Official Accred. ' . $FieldLabels->{'Accred.intInt5'}
                  || 'Match Official Accred. Provider'
                : '',
                {
                    displaytype     => 'lookup',
                    fieldtype       => 'dropdown',
                    dropdownoptions => $CommonVals->{'DefCodes'}{-32},
                    dbfield         => 'tblMT_Ac_Umpire.intInt5',
                    optiongroup     => 'mt_umpire',
                    dbfrom          => $umpire_dbfrom
                }
              ],
              dtUmpireAccredStart => [
                $NRO{'Accreditation'}
                ? 'Match Official Accred. ' . $FieldLabels->{'Accred.dtDate1'}
                  || 'Match Official Accred. Start Date'
                : '',
                {
                    displaytype => 'date',
                    fieldtype   => 'date',
                    dbfield     => 'tblMT_Ac_Umpire.dtDate1',
                    optiongroup => 'mt_umpire',
                    dbfrom      => $umpire_dbfrom,
                    dbformat =>
                      'DATE_FORMAT(tblMT_Ac_Umpire.dtDate1,"%d/%m/%Y")',
                    dbfield => 'tblMT_Ac_Umpire.dtDate1'
                }
              ],
              dtUmpireAccredEnd => [
                $NRO{'Accreditation'}
                ? 'Match Official Accred. ' . $FieldLabels->{'Accred.dtDate2'}
                  || 'Match Official Accred. End Date'
                : '',
                {
                    displaytype => 'date',
                    fieldtype   => 'date',
                    dbfield     => 'tblMT_Ac_Umpire.dtDate2',
                    optiongroup => 'mt_umpire',
                    dbfrom      => $umpire_dbfrom,
                    dbformat =>
                      'DATE_FORMAT(tblMT_Ac_Umpire.dtDate2,"%d/%m/%Y")',
                    dbfield => 'tblMT_Ac_Umpire.dtDate2'
                }
              ],
              dtUmpireAccredAppDate => [
                  $NRO{'Accreditation'}
                ? $FieldLabels->{'Accred.dtDate3'}
                      ? 'Match Official Accred. '
                      . $FieldLabels->{'Accred.dtDate3'}
                      : '' || 'Match Official Accred. Application Date'
                : '',
                  {
                    displaytype => 'date',
                    fieldtype   => 'date',
                    dbfield     => 'tblMT_Ac_Umpire.dtDate3',
                    optiongroup => 'mt_umpire',
                    dbfrom      => $umpire_dbfrom,
                    dbformat =>
                      'DATE_FORMAT(tblMT_Ac_Umpire.dtDate3,"%d/%m/%Y")',
                    dbfield => 'tblMT_Ac_Umpire.dtDate3'
                  }
              ],
          },

          Order => [
            qw(
              strNationalNum
              MemberID
              strMemberNo
              intRecStatus
              strSalutation
              strFirstname
              strSurname
              strPreferredName
              dtDOB
              dtYOB
              intGender
              strAddress1
              strAddress2
              strSuburb
              strState
              strCountry
              strPostalCode
              strPhoneHome
              strPhoneWork
              strPhoneMobile
              strEmail
              intEthnicityID

              intCoachAccredActive
              strCoachAccredType
              intCoachReAccreditation
              strCoachAccredLevel
              strCoachAccredProv
              dtCoachAccredStart
              dtCoachAccredEnd
              dtCoachAccredAppDate
              intDeregisteredCoach

              strUmpireType
              intUmpireAccredActive
              intUmpireReAccreditation
              strUmpireAccredType
              strUmpireAccredLevel
              strUmpireAccredProv
              dtUmpireAccredStart
              dtUmpireAccredEnd
              dtUmpireAccredAppDate

              intOfficialAccredActive
              strOfficialAccredType
              intOfficialReAccreditation
              strOfficialAccredLevel
              strOfficialAccredProv
              dtOfficialAccredStart
              dtOfficialAccredEnd
              dtOfficialAccredAppDate
              intDeregisteredOfficial

              )
          ],
          Config => {
            EmailExport        => 1,
            limitView          => 5000,
            EmailSenderAddress => $Defs::admin_email,
            SecondarySort      => 1,
            RunButtonLabel     => 'Run Report',
            ReturnProcessData  => [
                qw(tblMember.strEmail tblMember.strPhoneMobile tblMember.strSurname tblMember.strFirstname tblMember.intMemberID)
            ],
          },
          OptionGroups => {
            details        => [ 'Personal Details', { active => 1 } ],
            contactdetails => [ 'Contact Details',  {} ],
            mt_coach       => [
                'Member Type - Coach',
                {
                    from => "LEFT JOIN tblMember_Types AS tblMT_Coach ON (
                tblMember.intMemberID=tblMT_Coach.intMemberID 
                    AND tblMT_Coach.intTypeID=$Defs::MEMBER_TYPE_COACH 
                    AND tblMT_Coach.intAssocID IN ($exposed_IDs)
                    AND tblMT_Coach.intRecStatus = $Defs::RECSTATUS_ACTIVE 
                    AND tblMT_Coach.intSubTypeID=0
                )",
                }
            ],
            mt_umpire => [
                'Member Type - Match Official',
                {
                    from => "LEFT JOIN tblMember_Types AS tblMT_Umpire ON (
                tblMember.intMemberID=tblMT_Umpire.intMemberID 
                    AND tblMT_Umpire.intTypeID=$Defs::MEMBER_TYPE_UMPIRE 
                    AND tblMT_Umpire.intAssocID IN ($exposed_IDs)
                    AND tblMT_Umpire.intRecStatus = $Defs::RECSTATUS_ACTIVE 
                    AND tblMT_Umpire.intSubTypeID=0
                )",
                }
            ],
            mt_official => [
                'Member Type - Official',
                {
                    from => "LEFT JOIN tblMember_Types AS tblMT_Official ON (
                tblMember.intMemberID=tblMT_Official.intMemberID
                    AND tblMT_Umpire.intTypeID=$Defs::MEMBER_TYPE_OFFICIAL
                    AND tblMT_Umpire.intAssocID IN ($exposed_IDs)
                    AND tblMT_Umpire.intRecStatus = $Defs::RECSTATUS_ACTIVE
                    AND tblMT_Umpire.intSubTypeID=0
                )",
                }
            ],

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

    my $from_levels   = $OptVals->{'FROM_LEVELS'};
    my $from_list     = $OptVals->{'FROM_LIST'};
    my $where_levels  = $OptVals->{'WHERE_LEVELS'};
    my $where_list    = $OptVals->{'WHERE_LIST'};
    my $current_from  = $OptVals->{'CURRENT_FROM'};
    my $current_where = $OptVals->{'CURRENT_WHERE'};
    my $select_levels = $OptVals->{'SELECT_LEVELS'};

    my $sql = '';
    {    #Work out SQL

        my $clubID =
          (       $Data->{'clientValues'}{'clubID'}
              and $Data->{'clientValues'}{'clubID'} != $Defs::INVALID_ID )
          ? $Data->{'clientValues'}{'clubID'}
          : 0;

        $where_list = ' AND ' . $where_list
          if $where_list and ( $where_levels or $current_where );
        $where_list =~ s/\sAND\s*$//g;
        $where_list =~ s/AND  AND/AND /;

        my $mc_join = '';
        if (    $clubID
            and $from_levels !~ /tblMember_Clubs/
            and $current_from !~ /tblMember_Clubs/
            and $from_list !~ /tblMember_Clubs/ )
        {
            $mc_join = qq[
            INNER JOIN tblMember_Clubs ON (
                tblMember.intMemberID = tblMember_Clubs.intMemberID 
                    AND tblMember_Clubs.intStatus<>-1 
                    AND tblMember_Clubs.intClubID = $clubID
            )
            ];
        }

        $sql = qq[
        SELECT ###SELECT###
        FROM $from_levels $current_from $from_list $mc_join
        WHERE  $where_levels $current_where $where_list 
        ];
        my $coachnull = '';
        my $umpnull   = '';
        if ( $sql =~ /tblMT_Umpire/ ) {
            $umpnull = " tblMT_Umpire.intMemberTypeID IS NOT NULL ";
        }
        if ( $sql =~ /tblMT_Ac_Umpire/ ) {
            $umpnull = " tblMT_Ac_Umpire.intMemberTypeID IS NOT NULL ";
        }
        if ( $sql =~ /tblMT_Coach/ ) {
            $coachnull = " tblMT_Coach.intMemberTypeID IS NOT NULL ";
            if ($umpnull) {
                $coachnull = ' OR ' . $coachnull;
            }
        }
        if ( $umpnull or $coachnull ) {
            $sql .= qq[
                AND (
                $umpnull
                $coachnull
            )
            ];
        }
        return ( $sql, '' );
    }
}

1;
# vim: set et sw=4 ts=4:
