#
# $Header: svn://svn/SWM/trunk/web/Reports/ReportAdvanced_Member.pm 11613 2014-05-20 03:02:24Z cgao $
#

package Reports::ReportAdvanced_Member;

use strict;
use lib ".";
use ReportAdvanced_Common;
use Reports::ReportAdvanced;
use Log;
use Data::Dumper;
our @ISA = qw(Reports::ReportAdvanced);

use strict;

sub _getConfiguration {
    my $self = shift;

    my $currentLevel = $self->{'EntityTypeID'} || 0;
    my $Data         = $self->{'Data'};
    my $clientValues = $Data->{'clientValues'};
    my $natnumname =
      $Data->{'SystemConfig'}{'NationalNumName'} || 'National Number';
    my $natteamname = $Data->{'SystemConfig'}{'NatTeamName'} || 'National Team';
    my $SystemConfig = $Data->{'SystemConfig'};
    my $CommonVals   = getCommonValues(
        $Data,
        {
            SubRealms        => 1,
            DefCodes         => 1,
            Countries        => 1,
            MemberPackages   => 1,
            CustomFields     => 1,
            Seasons          => 1,
            FieldLabels      => 1,
            AgeGroups        => 1,
            EventLookups     => 1,
            Products         => 1,
            Grades           => 1,
            SchoolGrades     => 1,
            EntityCategories => 1,
            RegoForms        => 1,
            RecordTypes      => 1,
            Optins           => 1,
            Terms            => 1,
        },
    );
    my $hideSeasons = $CommonVals->{'Seasons'}{'Hide'} || 0;
    my $enable_record_types = $Data->{'SystemConfig'}{'EnableMemberRecords'} || 0; 

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
    my $showAgentFields =
      ( $Data->{'SystemConfig'}{'clrHide_AgentFields'} == 1 ) ? '0' : '1';
    my $txt_Tribunal    = $Data->{'SystemConfig'}{'txtTribunal'} || 'Tribunal';
    my $txt_SeasonName  = $Data->{'SystemConfig'}{'txtSeason'}   || 'Season';
    my $txt_SeasonNames = $Data->{'SystemConfig'}{'txtSeasons'}  || 'Seasons';
    my $txt_AgeGroupName =
      $Data->{'SystemConfig'}{'txtAgeGroup'} || 'Age Group';
    my $txt_AgeGroupNames =
      $Data->{'SystemConfig'}{'txtAgeGroups'} || 'Age Groups';
    my $txt_MiscName = $Data->{'SystemConfig'}{'txtMiscName'} || 'Misc';
    my $txt_Transactions =
      $Data->{'SystemConfig'}{'txns_link_name'} || 'Transaction';
    my $officialName = $Data->{'SystemConfig'}{'TYPE_NAME_4'} || 'Official';

    my $MStablename = $enable_record_types? "tblMemberRecords_$Data->{'Realm'}" : "tblMember_Seasons_$Data->{'Realm'}";
    my $RealmLPF_Ids =
      ( $Data->{'SystemConfig'}{'LPF_ids'} )
      ? $Data->{'SystemConfig'}{'LPF_ids'}
      : 0;
    my $txn_WHERE = '';
    if ( $clientValues->{clubID} and $clientValues->{clubID} > 0 ) {
        $txn_WHERE = qq[ AND TX.intTXNClubID IN (0, $clientValues->{clubID})];
    }

    my $player_comp_stats_table = "tblPlayerCompStats_SG_" . $Data->{'Realm'};

    my %config = (
        Name => 'Detailed Member Report',

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
                    displaytype   => 'text',
                    fieldtype     => 'text',
                    allowsort     => 1,
                    optiongroup   => 'details',
                    allowgrouping => 1
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
            intDefaulter => [
                  $Data->{'SystemConfig'}{'Defaulter'}
                ? $Data->{'SystemConfig'}{'Defaulter'}
                : '',
                {
                    displaytype     => 'lookup',
                    fieldtype       => 'dropdown',
                    dropdownoptions => { 0 => 'No', 1 => 'Yes' },
                    dropdownorder => [ 0, 1 ],
                    dbfield       => 'tblMember.intDefaulter',
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

            strMiddlename => [
                'Middle Name',
                {
                    displaytype => 'text',
                    fieldtype   => 'text',
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

            strMaidenName => [
                'Maiden Name',
                {
                    displaytype => 'text',
                    fieldtype   => 'text',
                    allowsort   => 1,
                    optiongroup => 'details'
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
            strCountryOfBirth => [
                'Country Of Birth',
                {
                    displaytype     => 'lookup',
                    fieldtype       => 'dropdown',
                    dropdownoptions => $CommonVals->{'Countries'},
                    allowsort       => 1,
                    optiongroup     => 'details',
                    dbfield         => 'UCASE(strCountryOfBirth)',
                    allowgrouping   => 1
                }
            ],

            strMotherCountry => [
                'Country Of Birth (Mother)',
                {
                    displaytype     => 'lookup',
                    fieldtype       => 'dropdown',
                    dropdownoptions => $CommonVals->{'Countries'},
                    allowsort       => 1,
                    optiongroup     => 'parents',
                    dbfield         => 'UCASE(strMotherCountry)',
                    allowgrouping   => 1
                }
            ],
            strFatherCountry => [
                'Country Of Birth (Father)',
                {
                    displaytype     => 'lookup',
                    fieldtype       => 'dropdown',
                    dropdownoptions => $CommonVals->{'Countries'},
                    allowsort       => 1,
                    optiongroup     => 'parents',
                    dbfield         => 'UCASE(strFatherCountry)',
                    allowgrouping   => 1
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

            strPlaceofBirth => [
                'Place (Town) of Birth',
                {
                    displaytype   => 'text',
                    fieldtype     => 'text',
                    allowsort     => 0,
                    optiongroup   => 'details',
                    allowgrouping => 1
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
                    allowgrouping => 1,
                    allowsort     => 1
                }
            ],

            intDeceased => [
                'Deceased',
                {
                    displaytype     => 'lookup',
                    fieldtype       => 'dropdown',
                    dropdownoptions => { 0 => 'No', 1 => 'Yes' },
                    dropdownorder => [ 0, 1 ],
                    optiongroup   => 'details',
                    allowgrouping => 1,
                    defaultcomp   => 'equal',
                    defaultvalue  => '0',
                    active        => 1,
                }
            ],

            strEyeColour => [
                'Eye Colour',
                {
                    displaytype     => 'lookup',
                    fieldtype       => 'dropdown',
                    dropdownoptions => $CommonVals->{'DefCodes'}{-11},
                    optiongroup     => 'details',
                    allowgrouping   => 1
                }
            ],

            strHairColour => [
                'Hair Colour',
                {
                    displaytype     => 'lookup',
                    fieldtype       => 'dropdown',
                    dropdownoptions => $CommonVals->{'DefCodes'}{-10},
                    optiongroup     => 'details',
                    allowgrouping   => 1
                }
            ],

            intEthnicityID => [
                'Ethnicity',
                {
                    displaytype     => 'lookup',
                    fieldtype       => 'dropdown',
                    dropdownoptions => $CommonVals->{'DefCodes'}{-8},
                    optiongroup     => 'details',
                    allowgrouping   => 1
                }
            ],

            strHeight => [
                'Height',
                {
                    displaytype => 'text',
                    fieldtype   => 'text',
                    allowsort   => 0,
                    optiongroup => 'details',
                }
            ],

            strWeight => [
                'Weight',
                {
                    displaytype => 'text',
                    fieldtype   => 'text',
                    allowsort   => 0,
                    optiongroup => 'details'
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

            strCityOfResidence => [
                'City of Residence',
                {
                    displaytype   => 'text',
                    fieldtype     => 'text',
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

            strPager => [
                'Pager',
                {
                    displaytype => 'text',
                    fieldtype   => 'text',
                    optiongroup => 'contactdetails'
                }
            ],

            strFax => [
                'Fax',
                {
                    displaytype => 'text',
                    fieldtype   => 'text',
                    dbfield     => 'tblMember.strFax',
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

            strEmail2 => [
                'Email 2',
                {
                    displaytype => 'text',
                    fieldtype   => 'text',
                    dbfield     => 'tblMember.strEmail2',
                    optiongroup => 'contactdetails'
                }
            ],

            strEmergContName => [
                'Emergency Contact Name',
                {
                    displaytype => 'text',
                    fieldtype   => 'text',
                    allowsort   => 0,
                    optiongroup => 'contactdetails'
                }
            ],

            strEmergContRel => [
                'Emergency Contact Relationship',
                {
                    displaytype => 'text',
                    fieldtype   => 'text',
                    allowsort   => 0,
                    optiongroup => 'contactdetails'
                }
            ],

            strEmergContNo => [
                'Emergency Contact No',
                {
                    displaytype => 'text',
                    fieldtype   => 'text',
                    allowsort   => 0,
                    optiongroup => 'contactdetails',
                }
            ],

            strEmergContNo2 => [
                'Emergency Contact No 2',
                {
                    displaytype => 'text',
                    fieldtype   => 'text',
                    allowsort   => 0,
                    optiongroup => 'contactdetails',
                }
            ],

            #Interests
            intPlayer => [
                'Player',
                {
                    displaytype     => 'lookup',
                    fieldtype       => 'dropdown',
                    dropdownoptions => { 0 => 'No', 1 => 'Yes' },
                    dropdownorder => [ 0, 1 ],
                    optiongroup   => 'interests',
                    allowgrouping => 1
                }
            ],

            intCoach => [
                'Coach',
                {
                    displaytype     => 'lookup',
                    fieldtype       => 'dropdown',
                    dropdownoptions => { 0 => 'No', 1 => 'Yes' },
                    dropdownorder => [ 0, 1 ],
                    optiongroup   => 'interests',
                    allowgrouping => 1
                }
            ],

            intUmpire => [
                'Match Official',
                {
                    displaytype     => 'lookup',
                    fieldtype       => 'dropdown',
                    dropdownoptions => { 0 => 'No', 1 => 'Yes' },
                    dropdownorder => [ 0, 1 ],
                    optiongroup   => 'interests',
                    allowgrouping => 1
                }
            ],

            intOfficial => [
                'Official',
                {
                    displaytype     => 'lookup',
                    fieldtype       => 'dropdown',
                    dropdownoptions => { 0 => 'No', 1 => 'Yes' },
                    dropdownorder => [ 0, 1 ],
                    optiongroup   => 'interests',
                    allowgrouping => 1
                }
            ],

            intMisc => [
                'Misc',
                {
                    displaytype     => 'lookup',
                    fieldtype       => 'dropdown',
                    dropdownoptions => { 0 => 'No', 1 => 'Yes' },
                    dropdownorder => [ 0, 1 ],
                    optiongroup   => 'interests',
                    allowgrouping => 1
                }
            ],
            intPhotoUseApproval => [
                'Photo Use Approval',
                {
                    displaytype     => 'lookup',
                    fieldtype       => 'dropdown',
                    dropdownoptions => { 0 => 'No', 1 => 'Yes' },
                    dropdownorder => [ 0, 1 ],
                    optiongroup   => 'otherfields',
                    allowgrouping => 1
                }
            ],

            intVolunteer => [
                'Volunteer',
                {
                    displaytype     => 'lookup',
                    fieldtype       => 'dropdown',
                    dropdownoptions => { 0 => 'No', 1 => 'Yes' },
                    dropdownorder => [ 0, 1 ],
                    optiongroup   => 'interests',
                    allowgrouping => 1
                }
            ],

            strPreferredLang => [
                'Preferred Language',
                {
                    displaytype => 'text',
                    fieldtype   => 'text',
                    allowsort   => 0,
                    optiongroup => 'identifications'
                }
            ],

            strPassportIssueCountry => [
                'Passport Issue Country',
                {
                    displaytype     => 'lookup',
                    fieldtype       => 'dropdown',
                    dropdownoptions => $CommonVals->{'Countries'},
                    allowsort       => 1,
                    optiongroup     => 'identifications',
                    dbfield         => 'UCASE(strPassportIssueCountry)',
                    allowgrouping   => 1
                }
            ],

            strPassportNationality => [
                'Passport Nationality',
                {
                    displaytype     => 'lookup',
                    fieldtype       => 'dropdown',
                    dropdownoptions => $CommonVals->{'Countries'},
                    allowsort       => 1,
                    optiongroup     => 'identifications',
                    dbfield         => 'UCASE(strPassportNationality)',
                    allowgrouping   => 1
                }
            ],

            strPassportNo => [
                'Passport Number',
                {
                    displaytype => 'text',
                    fieldtype   => 'text',
                    allowsort   => 0,
                    optiongroup => 'identifications'
                }
            ],

            dtPassportExpiry => [
                'Passport Expiry',
                {
                    displaytype => 'date',
                    fieldtype   => 'date',
                    allowsort   => 1,
                    dbformat =>
                      'DATE_FORMAT(tblMember.dtPassportExpiry, "%d/%m/%Y")',
                    optiongroup => 'identifications',
                    dbfield     => 'tblMember.dtPassportExpiry'
                }
            ],

            strBirthCertNo => [
                'Birth Certificate Number',
                {
                    displaytype => 'text',
                    fieldtype   => 'text',
                    allowsort   => 0,
                    optiongroup => 'identifications'
                }
            ],

            strHealthCareNo => [
                'Health Care Number',
                {
                    displaytype => 'text',
                    fieldtype   => 'text',
                    allowsort   => 0,
                    optiongroup => 'identifications'
                }
            ],

            intIdentTypeID => [
                'Identification Type',
                {
                    displaytype     => 'lookup',
                    fieldtype       => 'dropdown',
                    dropdownoptions => $CommonVals->{'DefCodes'}{-31},
                    optiongroup     => 'identifications'
                }
            ],

            strIdentNum => [
                'Identification Number',
                {
                    displaytype => 'text',
                    fieldtype   => 'text',
                    allowsort   => 0,
                    optiongroup => 'identifications'
                }
            ],

            dtPoliceCheck => [
                  $Data->{'SystemConfig'}{'dtPoliceCheck_Text'}
                ? $Data->{'SystemConfig'}{'dtPoliceCheck_Text'}
                : $FieldLabels->{'dtPoliceCheck'},
                {
                    displaytype => 'date',
                    fieldtype   => 'date',
                    allowsort   => 1,
                    dbformat =>
                      'DATE_FORMAT(tblMember.dtPoliceCheck, "%d/%m/%Y")',
                    optiongroup => 'identifications',
                    dbfield     => 'tblMember.dtPoliceCheck'
                }
            ],

            dtPoliceCheckExp => [
                  $Data->{'SystemConfig'}{'dtPoliceCheckExp_Text'}
                ? $Data->{'SystemConfig'}{'dtPoliceCheckExp_Text'}
                : $FieldLabels->{'dtPoliceCheckExp'},
                {
                    displaytype => 'date',
                    fieldtype   => 'date',
                    allowsort   => 1,
                    dbformat =>
                      'DATE_FORMAT(tblMember.dtPoliceCheckExp, "%d/%m/%Y")',
                    optiongroup => 'identifications',
                    dbfield     => 'tblMember.dtPoliceCheckExp'
                }
            ],

            strPoliceCheckRef => [
                  $FieldLabels->{'strPoliceCheckRef'}
                ? $FieldLabels->{'strPoliceCheckRef'}
                : 'Police Check Number',
                {
                    displaytype => 'text',
                    fieldtype   => 'text',
                    allowsort   => 0,
                    optiongroup => 'identifications'
                }
            ],

            strP1Salutation => [
                'Parent/Guardian 1 Salutation',
                {
                    displaytype => 'text',
                    fieldtype   => 'text',
                    allowsort   => 1,
                    optiongroup => 'parents'
                }
            ],

            strP1FName => [
                'Parent/Guardian 1 Firstname',
                {
                    displaytype => 'text',
                    fieldtype   => 'text',
                    allowsort   => 0,
                    optiongroup => 'parents',
                }
            ],

            strP1SName => [
                'Parent/Guardian 1 Surname',
                {
                    displaytype => 'text',
                    fieldtype   => 'text',
                    allowsort   => 0,
                    optiongroup => 'parents',
                }
            ],

            intP1Gender => [
                'Parent/Guardian 1 Gender',
                {
                    displaytype => 'lookup',
                    fieldtype   => 'dropdown',
                    dropdownoptions =>
                      { '' => '&nbsp;', 1 => 'Male', 2 => 'Female' },
                    dropdownorder => [ '', 1, 2 ],
                    size          => 2,
                    multiple      => 1,
                    optiongroup   => 'parents',
                    allowgrouping => 1,
                }
            ],

            strP1Phone => [
                'Parent/Guardian 1 Phone',
                {
                    displaytype => 'text',
                    fieldtype   => 'text',
                    optiongroup => 'parents'
                }
            ],

            strP1Phone2 => [
                'Parent/Guardian 1 Phone 2',
                {
                    displaytype => 'text',
                    fieldtype   => 'text',
                    optiongroup => 'parents'
                }
            ],

            strP1PhoneMobile => [
                'Parent/Guardian 1 Mobile',
                {
                    displaytype => 'text',
                    fieldtype   => 'text',
                    optiongroup => 'parents'
                }
            ],

            strP1Email => [
                'Parent/Guardian 1 Email',
                {
                    displaytype => 'text',
                    fieldtype   => 'text',
                    optiongroup => 'parents'
                }
            ],

            strP1Email2 => [
                'Parent/Guardian 1 Email 2',
                {
                    displaytype => 'text',
                    fieldtype   => 'text',
                    optiongroup => 'parents'
                }
            ],

            intP1AssistAreaID => [
                'Parent/Guardian 1 Assistance Area',
                {
                    displaytype     => 'lookup',
                    fieldtype       => 'dropdown',
                    dropdownoptions => $CommonVals->{'DefCodes'}{-1002},
                    optiongroup     => 'parents',
                    allowgrouping   => 1
                }
            ],

            strP2Salutation => [
                'Parent/Guardian 2 Salutation',
                {
                    displaytype   => 'text',
                    fieldtype     => 'text',
                    allowsort     => 1,
                    optiongroup   => 'parents',
                    allowgrouping => 1
                }
            ],

            strP2FName => [
                'Parent/Guardian 2 Firstname',
                {
                    displaytype => 'text',
                    fieldtype   => 'text',
                    allowsort   => 0,
                    optiongroup => 'parents',
                }
            ],

            strP2SName => [
                'Parent/Guardian 2 Surname',
                {
                    displaytype => 'text',
                    fieldtype   => 'text',
                    allowsort   => 0,
                    optiongroup => 'parents',
                }
            ],

            intP2Gender => [
                'Parent/Guardian 2 Gender',
                {
                    displaytype => 'lookup',
                    fieldtype   => 'dropdown',
                    dropdownoptions =>
                      { '' => '&nbsp;', 1 => 'Male', 2 => 'Female' },
                    dropdownorder => [ '', 1, 2 ],
                    size          => 2,
                    multiple      => 1,
                    optiongroup   => 'parents',
                    allowgrouping => 1
                }
            ],

            strP2Phone => [
                'Parent/Guardian 2 Phone',
                {
                    displaytype => 'text',
                    fieldtype   => 'text',
                    optiongroup => 'parents'
                }
            ],

            strP2Phone2 => [
                'Parent/Guardian 2 Phone 2',
                {
                    displaytype => 'text',
                    fieldtype   => 'text',
                    optiongroup => 'parents'
                }
            ],

            strP2PhoneMobile => [
                'Parent/Guardian 2 Mobile',
                {
                    displaytype => 'text',
                    fieldtype   => 'text',
                    optiongroup => 'parents'
                }
            ],

            strP2Email => [
                'Parent/Guardian 2 Email',
                {
                    displaytype => 'text',
                    fieldtype   => 'text',
                    optiongroup => 'parents'
                }
            ],

            strP2Email2 => [
                'Parent/Guardian 2 Email 2',
                {
                    displaytype => 'text',
                    fieldtype   => 'text',
                    optiongroup => 'parents'
                }
            ],

            intP2AssistAreaID => [
                'Parent/Guardian 2 Assistance Area',
                {
                    displaytype     => 'lookup',
                    fieldtype       => 'dropdown',
                    dropdownoptions => $CommonVals->{'DefCodes'}{-1002},
                    optiongroup     => 'parents',
                    allowgrouping   => 1
                }
            ],

            intFinancialActive => [
                'Member Financial?',
                {
                    displaytype     => 'lookup',
                    fieldtype       => 'dropdown',
                    dropdownoptions => { 0 => 'No', 1 => 'Yes' },
                    dropdownorder => [ 0, 1 ],
                    optiongroup   => 'financial',
                    allowgrouping => 1
                }
            ],

            intMemberPackageID => [
                'Member Package',
                {
                    displaytype     => 'lookup',
                    fieldtype       => 'dropdown',
                    dropdownoptions => $CommonVals->{'MemberPackages'},
                    optiongroup     => 'financial',
                    allowgrouping   => 1
                }
            ],

            curMemberFinBal => [
                'Financial Balance',
                {
                    displaytype => 'currency',
                    fieldtype   => 'text',
                    allowsort   => 1,
                    optiongroup => 'financial'
                }
            ],

            intLifeMember => [
                'LifeMember',
                {
                    displaytype     => 'lookup',
                    fieldtype       => 'dropdown',
                    dropdownoptions => { 0 => 'No', 1 => 'Yes' },
                    dropdownorder => [ 0, 1 ],
                    optiongroup   => 'financial',
                    allowgrouping => 1
                }
            ],

            intMedicalConditions => [
                'Medical Conditions?',
                {
                    displaytype     => 'lookup',
                    fieldtype       => 'dropdown',
                    dropdownoptions => { 0 => 'No', 1 => 'Yes' },
                    dropdownorder => [ 0, 1 ],
                    optiongroup   => 'medical',
                    allowgrouping => 1
                }
            ],

            intAllergies => [
                'Allergies?',
                {
                    displaytype     => 'lookup',
                    fieldtype       => 'dropdown',
                    dropdownoptions => { 0 => 'No', 1 => 'Yes' },
                    dropdownorder => [ 0, 1 ],
                    optiongroup   => 'medical',
                    allowgrouping => 1
                }
            ],

            intAllowMedicalTreatment => [
                'Allow Medical Treatment?',
                {
                    displaytype     => 'lookup',
                    fieldtype       => 'dropdown',
                    dropdownoptions => { 0 => 'No', 1 => 'Yes' },
                    dropdownorder => [ 0, 1 ],
                    optiongroup   => 'medical',
                    allowgrouping => 1
                }
            ],

            strMemberMedicalNotes => [
                'Medical Notes',
                {
                    displaytype => 'text',
                    fieldtype   => 'text',
                    allowsort   => 0,
                    dbfield     => 'strMemberMedicalNotes',
                    optiongroup => 'medical',
                    dbfrom =>
'LEFT JOIN tblMemberNotes as MN ON (MN.intNotesMemberID = tblMember_Associations.intMemberID AND MN.intNotesAssocID = tblMember_Associations.intAssocID)'
                }
            ],

            intOccupationID => [
                'Occupation',
                {
                    displaytype     => 'lookup',
                    fieldtype       => 'dropdown',
                    dropdownoptions => $CommonVals->{'DefCodes'}{-9},
                    optiongroup     => 'otherfields',
                    allowgrouping   => 1
                }
            ],

            strLoyaltyNumber => [
                'Loyalty Number',
                {
                    displaytype => 'text',
                    fieldtype   => 'text',
                    allowsort   => 1,
                    optiongroup => 'otherfields'
                }
            ],

            intMailingList => [
                'MailingList?',
                {
                    displaytype     => 'lookup',
                    fieldtype       => 'dropdown',
                    dropdownoptions => { 0 => 'No', 1 => 'Yes' },
                    dropdownorder => [ 0, 1 ],
                    optiongroup   => 'otherfields',
                    allowgrouping => 1
                }
            ],

            intOptinID => [
                'Opt-in Agreements?',
                {
                    displaytype     => 'lookup',
                    fieldtype       => 'dropdown',
                    dropdownoptions => $CommonVals->{'Optins'}{'Options'},
                    dropdownorder   => $CommonVals->{'Optins'}{'Order'},
                    allowsort       => 1,
                    optiongroup     => 'otherfields',
                    multiple        => 1,
                    size            => 3,
                    dbfield         => 'tblOptin.intOptinID',
                    dbfrom          => "
        LEFT JOIN tblOptinMember ON (
            tblMember.intMemberID = tblOptinMember.intMemberID
            AND tblOptinMember.intEntityTypeID = $clientValues->{'currentLevel'}
            AND tblOptinMember.intAction = 1 )
        LEFT JOIN tblOptin ON (
            tblMember.intRealmID = tblOptin.intRealmID
            AND tblOptin.intOptinID = tblOptinMember.intOptinID )
                    "
                }
            ],

            strUnsubscribeURL => [
                'Opt-in UnsubscribeURL',
                {
                    displaytype     => 'text',
                    fieldtype       => 'text',
                    allowsort       => 1,
                    optiongroup     => 'otherfields',
                    dbfield         => 'tblOptinMember.strUnsubscribeURL',
                    dbfrom          => "
        LEFT JOIN tblOptinMember ON (
            tblMember.intMemberID = tblOptinMember.intMemberID
            AND tblOptinMember.intEntityTypeID = $clientValues->{'currentLevel'}
            AND tblOptinMember.intAction = 1 )
        LEFT JOIN tblOptin ON (
            tblMember.intRealmID = tblOptin.intRealmID
            AND tblOptin.intOptinID = tblOptinMember.intOptinID )
                    "
                }
            ],

            intTermsFormID => [
                'Terms & Conditions FormID',
                {
                    displaytype     => 'lookup',
                    fieldtype       => 'dropdown',
                    dropdownoptions => $CommonVals->{'Terms'}{'Options'},
                    dropdownorder   => $CommonVals->{'Terms'}{'Order'},
                    allowsort       => 1,
                    optiongroup     => 'otherfields',
                    multiple        => 1,
                    size            => 3,
                    dbfield         => 'tblTermsMember.intFormID',
                    dbfrom          => "
                        LEFT JOIN tblTermsMember ON (
                            tblMember.intMemberID = tblTermsMember.intMemberID
                            AND tblTermsMember.intLevel = $clientValues->{'currentLevel'} )
                    "
                }
            ],

            dtTermsCreated => [
                'Terms & Conditions Created Date',
                {
                    displaytype => 'date',
                    fieldtype   => 'date',
                    allowsort   => 0,
                    optiongroup => 'otherfields',
                    dbfield     => 'tblTermsMember.tTimestamp',
                    dbfrom          => "
                        LEFT JOIN tblTermsMember ON (
                            tblMember.intMemberID = tblTermsMember.intMemberID
                            AND tblTermsMember.intLevel = $clientValues->{'currentLevel'} )
                    "
                }
            ],

            FileName => [
                'Attached Document Name',
                {
                    displaytype => 'text',
                    fieldtype   => 'text',
                    allowsort   => 1,
                    optiongroup => 'otherfields',
                    dbfield     => 'tblUploadedFiles.strTitle',
                }
            ],
            FileDate => [
                'Document Uploaded Date',
                {
                    displaytype => 'date',
                    fieldtype   => 'date',
                    allowsort   => 0,
                    optiongroup => 'otherfields',
                    dbfield     => 'tblUploadedFiles.dtUploaded',
                    dbformat =>
                      ' DATE_FORMAT(tblUploadedFiles.dtUploaded, "%d/%m/%Y")',
                }
            ],

            strNatCustomStr1 => [
                $CommonVals->{'CustomFields'}->{'strNatCustomStr1'}[0],
                {
                    displaytype => 'text',
                    fieldtype   => 'text',
                    allowsort   => 0,
                    optiongroup => 'otherfields'
                }
            ],

            strNatCustomStr2 => [
                $CommonVals->{'CustomFields'}->{'strNatCustomStr2'}[0],
                {
                    displaytype => 'text',
                    fieldtype   => 'text',
                    allowsort   => 0,
                    optiongroup => 'otherfields'
                }
            ],

            strNatCustomStr3 => [
                $CommonVals->{'CustomFields'}->{'strNatCustomStr3'}[0],
                {
                    displaytype => 'text',
                    fieldtype   => 'text',
                    allowsort   => 0,
                    optiongroup => 'otherfields'
                }
            ],

            strNatCustomStr4 => [
                $CommonVals->{'CustomFields'}->{'strNatCustomStr4'}[0],
                {
                    displaytype => 'text',
                    fieldtype   => 'text',
                    allowsort   => 0,
                    optiongroup => 'otherfields'
                }
            ],

            strNatCustomStr5 => [
                $CommonVals->{'CustomFields'}->{'strNatCustomStr5'}[0],
                {
                    displaytype => 'text',
                    fieldtype   => 'text',
                    allowsort   => 0,
                    optiongroup => 'otherfields'
                }
            ],

            strNatCustomStr6 => [
                $CommonVals->{'CustomFields'}->{'strNatCustomStr6'}[0],
                {
                    displaytype => 'text',
                    fieldtype   => 'text',
                    allowsort   => 0,
                    optiongroup => 'otherfields'
                }
            ],

            strNatCustomStr7 => [
                $CommonVals->{'CustomFields'}->{'strNatCustomStr7'}[0],
                {
                    displaytype => 'text',
                    fieldtype   => 'text',
                    allowsort   => 0,
                    optiongroup => 'otherfields'
                }
            ],

            strNatCustomStr8 => [
                $CommonVals->{'CustomFields'}->{'strNatCustomStr8'}[0],
                {
                    displaytype => 'text',
                    fieldtype   => 'text',
                    allowsort   => 0,
                    optiongroup => 'otherfields'
                }
            ],

            strNatCustomStr9 => [
                $CommonVals->{'CustomFields'}->{'strNatCustomStr9'}[0],
                {
                    displaytype => 'text',
                    fieldtype   => 'text',
                    allowsort   => 0,
                    optiongroup => 'otherfields'
                }
            ],

            strNatCustomStr10 => [
                $CommonVals->{'CustomFields'}->{'strNatCustomStr10'}[0],
                {
                    displaytype => 'text',
                    fieldtype   => 'text',
                    allowsort   => 0,
                    optiongroup => 'otherfields'
                }
            ],

            strNatCustomStr11 => [
                $CommonVals->{'CustomFields'}->{'strNatCustomStr11'}[0],
                {
                    displaytype => 'text',
                    fieldtype   => 'text',
                    allowsort   => 0,
                    optiongroup => 'otherfields'
                }
            ],

            strNatCustomStr12 => [
                $CommonVals->{'CustomFields'}->{'strNatCustomStr12'}[0],
                {
                    displaytype => 'text',
                    fieldtype   => 'text',
                    allowsort   => 0,
                    optiongroup => 'otherfields'
                }
            ],

            strNatCustomStr13 => [
                $CommonVals->{'CustomFields'}->{'strNatCustomStr13'}[0],
                {
                    displaytype => 'text',
                    fieldtype   => 'text',
                    allowsort   => 0,
                    optiongroup => 'otherfields'
                }
            ],

            strNatCustomStr14 => [
                $CommonVals->{'CustomFields'}->{'strNatCustomStr14'}[0],
                {
                    displaytype => 'text',
                    fieldtype   => 'text',
                    allowsort   => 0,
                    optiongroup => 'otherfields'
                }
            ],

            strNatCustomStr15 => [
                $CommonVals->{'CustomFields'}->{'strNatCustomStr15'}[0],
                {
                    displaytype => 'text',
                    fieldtype   => 'text',
                    allowsort   => 0,
                    optiongroup => 'otherfields'
                }
            ],

            dblNatCustomDbl1 => [
                $CommonVals->{'CustomFields'}->{'dblNatCustomDbl1'}[0],
                {
                    displaytype => 'text',
                    fieldtype   => 'text',
                    allowsort   => 0,
                    optiongroup => 'otherfields'
                }
            ],

            dblNatCustomDbl2 => [
                $CommonVals->{'CustomFields'}->{'dblNatCustomDbl2'}[0],
                {
                    displaytype => 'text',
                    fieldtype   => 'text',
                    allowsort   => 0,
                    optiongroup => 'otherfields'
                }
            ],

            dblNatCustomDbl3 => [
                $CommonVals->{'CustomFields'}->{'dblNatCustomDbl3'}[0],
                {
                    displaytype => 'text',
                    fieldtype   => 'text',
                    allowsort   => 0,
                    optiongroup => 'otherfields'
                }
            ],

            dblNatCustomDbl4 => [
                $CommonVals->{'CustomFields'}->{'dblNatCustomDbl4'}[0],
                {
                    displaytype => 'text',
                    fieldtype   => 'text',
                    allowsort   => 0,
                    optiongroup => 'otherfields'
                }
            ],

            dblNatCustomDbl5 => [
                $CommonVals->{'CustomFields'}->{'dblNatCustomDbl5'}[0],
                {
                    displaytype => 'text',
                    fieldtype   => 'text',
                    allowsort   => 0,
                    optiongroup => 'otherfields'
                }
            ],

            dblNatCustomDbl6 => [
                $CommonVals->{'CustomFields'}->{'dblNatCustomDbl6'}[0],
                {
                    displaytype => 'text',
                    fieldtype   => 'text',
                    allowsort   => 0,
                    optiongroup => 'otherfields'
                }
            ],

            dblNatCustomDbl7 => [
                $CommonVals->{'CustomFields'}->{'dblNatCustomDbl7'}[0],
                {
                    displaytype => 'text',
                    fieldtype   => 'text',
                    allowsort   => 0,
                    optiongroup => 'otherfields'
                }
            ],

            dblNatCustomDbl8 => [
                $CommonVals->{'CustomFields'}->{'dblNatCustomDbl8'}[0],
                {
                    displaytype => 'text',
                    fieldtype   => 'text',
                    allowsort   => 0,
                    optiongroup => 'otherfields'
                }
            ],

            dblNatCustomDbl9 => [
                $CommonVals->{'CustomFields'}->{'dblNatCustomDbl9'}[0],
                {
                    displaytype => 'text',
                    fieldtype   => 'text',
                    allowsort   => 0,
                    optiongroup => 'otherfields'
                }
            ],

            dblNatCustomDbl10 => [
                $CommonVals->{'CustomFields'}->{'dblNatCustomDbl10'}[0],
                {
                    displaytype => 'text',
                    fieldtype   => 'text',
                    allowsort   => 0,
                    optiongroup => 'otherfields'
                }
            ],

            dtNatCustomDt1 => [
                $CommonVals->{'CustomFields'}->{'dtNatCustomDt1'}[0],
                {
                    displaytype => 'date',
                    fieldtype   => 'date',
                    allowsort   => 0,
                    optiongroup => 'otherfields',
                    dbformat =>
                      ' DATE_FORMAT(tblMember.dtNatCustomDt1, "%d/%m/%Y")',
                    dbfield => 'tblMember.dtNatCustomDt1'
                }
            ],

            dtNatCustomDt2 => [
                $CommonVals->{'CustomFields'}->{'dtNatCustomDt2'}[0],
                {
                    displaytype => 'date',
                    fieldtype   => 'date',
                    allowsort   => 0,
                    optiongroup => 'otherfields',
                    dbformat =>
                      ' DATE_FORMAT(tblMember.dtNatCustomDt2, "%d/%m/%Y")',
                    dbfield => 'tblMember.dtNatCustomDt2'
                }
            ],

            dtNatCustomDt3 => [
                $CommonVals->{'CustomFields'}->{'dtNatCustomDt3'}[0],
                {
                    displaytype => 'date',
                    fieldtype   => 'date',
                    allowsort   => 0,
                    optiongroup => 'otherfields',
                    dbformat =>
                      ' DATE_FORMAT(tblMember.dtNatCustomDt3, "%d/%m/%Y")',
                    dbfield => 'tblMember.dtNatCustomDt3'
                }
            ],

            dtNatCustomDt4 => [
                $CommonVals->{'CustomFields'}->{'dtNatCustomDt4'}[0],
                {
                    displaytype => 'date',
                    fieldtype   => 'date',
                    allowsort   => 0,
                    optiongroup => 'otherfields',
                    dbformat =>
                      ' DATE_FORMAT(tblMember.dtNatCustomDt4, "%d/%m/%Y")',
                    dbfield => 'tblMember.dtNatCustomDt4'
                }
            ],

            dtNatCustomDt5 => [
                $CommonVals->{'CustomFields'}->{'dtNatCustomDt5'}[0],
                {
                    displaytype => 'date',
                    fieldtype   => 'date',
                    allowsort   => 0,
                    optiongroup => 'otherfields',
                    dbformat =>
                      ' DATE_FORMAT(tblMember.dtNatCustomDt5, "%d/%m/%Y")',
                    dbfield => 'tblMember.dtNatCustomDt5'
                }
            ],

            intNatCustomLU1 => [
                $CommonVals->{'CustomFields'}->{'intNatCustomLU1'}[0],
                {
                    displaytype     => 'lookup',
                    fieldtype       => 'dropdown',
                    dropdownoptions => $CommonVals->{'DefCodes'}{-53},
                    optiongroup     => 'otherfields',
                    size            => 3,
                    multiple        => 1
                }
            ],

            intNatCustomLU2 => [
                $CommonVals->{'CustomFields'}->{'intNatCustomLU2'}[0],
                {
                    displaytype     => 'lookup',
                    fieldtype       => 'dropdown',
                    dropdownoptions => $CommonVals->{'DefCodes'}{-54},
                    optiongroup     => 'otherfields',
                    size            => 3,
                    multiple        => 1
                }
            ],

            intNatCustomLU3 => [
                $CommonVals->{'CustomFields'}->{'intNatCustomLU3'}[0],
                {
                    displaytype     => 'lookup',
                    fieldtype       => 'dropdown',
                    dropdownoptions => $CommonVals->{'DefCodes'}{-55},
                    optiongroup     => 'otherfields',
                    size            => 3,
                    multiple        => 1
                }
            ],

            intNatCustomLU4 => [
                $CommonVals->{'CustomFields'}->{'intNatCustomLU4'}[0],
                {
                    displaytype     => 'lookup',
                    fieldtype       => 'dropdown',
                    dropdownoptions => $CommonVals->{'DefCodes'}{-64},
                    optiongroup     => 'otherfields',
                    size            => 3,
                    multiple        => 1
                }
            ],

            intNatCustomLU5 => [
                $CommonVals->{'CustomFields'}->{'intNatCustomLU5'}[0],
                {
                    displaytype     => 'lookup',
                    fieldtype       => 'dropdown',
                    dropdownoptions => $CommonVals->{'DefCodes'}{-65},
                    optiongroup     => 'otherfields',
                    size            => 3,
                    multiple        => 1
                }
            ],

            intNatCustomLU6 => [
                $CommonVals->{'CustomFields'}->{'intNatCustomLU6'}[0],
                {
                    displaytype     => 'lookup',
                    fieldtype       => 'dropdown',
                    dropdownoptions => $CommonVals->{'DefCodes'}{-66},
                    optiongroup     => 'otherfields',
                    size            => 3,
                    multiple        => 1
                }
            ],

            intNatCustomLU7 => [
                $CommonVals->{'CustomFields'}->{'intNatCustomLU7'}[0],
                {
                    displaytype     => 'lookup',
                    fieldtype       => 'dropdown',
                    dropdownoptions => $CommonVals->{'DefCodes'}{-67},
                    optiongroup     => 'otherfields',
                    size            => 3,
                    multiple        => 1
                }
            ],

            intNatCustomLU8 => [
                $CommonVals->{'CustomFields'}->{'intNatCustomLU8'}[0],
                {
                    displaytype     => 'lookup',
                    fieldtype       => 'dropdown',
                    dropdownoptions => $CommonVals->{'DefCodes'}{-68},
                    optiongroup     => 'otherfields',
                    size            => 3,
                    multiple        => 1
                }
            ],

            intNatCustomLU9 => [
                $CommonVals->{'CustomFields'}->{'intNatCustomLU9'}[0],
                {
                    displaytype     => 'lookup',
                    fieldtype       => 'dropdown',
                    dropdownoptions => $CommonVals->{'DefCodes'}{-69},
                    optiongroup     => 'otherfields',
                    size            => 3,
                    multiple        => 1
                }
            ],

            intNatCustomLU10 => [
                $CommonVals->{'CustomFields'}->{'intNatCustomLU10'}[0],
                {
                    displaytype     => 'lookup',
                    fieldtype       => 'dropdown',
                    dropdownoptions => $CommonVals->{'DefCodes'}{-70},
                    optiongroup     => 'otherfields',
                    size            => 3,
                    multiple        => 1
                }
            ],

            intNatCustomBool1 => [
                $CommonVals->{'CustomFields'}->{'intNatCustomBool1'}[0],
                {
                    displaytype     => 'lookup',
                    fieldtype       => 'dropdown',
                    dropdownoptions => { 0 => 'No', 1 => 'Yes' },
                    dropdownorder => [ 0, 1 ],
                    optiongroup   => 'otherfields',
                }
            ],

            intNatCustomBool2 => [
                $CommonVals->{'CustomFields'}->{'intNatCustomBool2'}[0],
                {
                    displaytype     => 'lookup',
                    fieldtype       => 'dropdown',
                    dropdownoptions => { 0 => 'No', 1 => 'Yes' },
                    dropdownorder => [ 0, 1 ],
                    optiongroup   => 'otherfields',
                }
            ],

            intNatCustomBool3 => [
                $CommonVals->{'CustomFields'}->{'intNatCustomBool3'}[0],
                {
                    displaytype     => 'lookup',
                    fieldtype       => 'dropdown',
                    dropdownoptions => { 0 => 'No', 1 => 'Yes' },
                    dropdownorder => [ 0, 1 ],
                    optiongroup   => 'otherfields',
                }
            ],

            intNatCustomBool4 => [
                $CommonVals->{'CustomFields'}->{'intNatCustomBool4'}[0],
                {
                    displaytype     => 'lookup',
                    fieldtype       => 'dropdown',
                    dropdownoptions => { 0 => 'No', 1 => 'Yes' },
                    dropdownorder => [ 0, 1 ],
                    optiongroup   => 'otherfields',
                }
            ],

            intNatCustomBool5 => [
                $CommonVals->{'CustomFields'}->{'intNatCustomBool5'}[0],
                {
                    displaytype     => 'lookup',
                    fieldtype       => 'dropdown',
                    dropdownoptions => { 0 => 'No', 1 => 'Yes' },
                    dropdownorder => [ 0, 1 ],
                    optiongroup   => 'otherfields',
                }
            ],

            strCustomStr1 => [
                $CommonVals->{'CustomFields'}->{'strCustomStr1'}[0],
                {
                    displaytype => 'text',
                    fieldtype   => 'text',
                    allowsort   => 0,
                    optiongroup => 'otherfields',
                }
            ],

            strCustomStr2 => [
                $CommonVals->{'CustomFields'}->{'strCustomStr2'}[0],
                {
                    displaytype => 'text',
                    fieldtype   => 'text',
                    allowsort   => 0,
                    optiongroup => 'otherfields'
                }
            ],

            strCustomStr3 => [
                $CommonVals->{'CustomFields'}->{'strCustomStr3'}[0],
                {
                    displaytype => 'text',
                    fieldtype   => 'text',
                    allowsort   => 0,
                    optiongroup => 'otherfields'
                }
            ],

            strCustomStr4 => [
                $CommonVals->{'CustomFields'}->{'strCustomStr4'}[0],
                {
                    displaytype => 'text',
                    fieldtype   => 'text',
                    allowsort   => 0,
                    optiongroup => 'otherfields'
                }
            ],

            strCustomStr5 => [
                $CommonVals->{'CustomFields'}->{'strCustomStr5'}[0],
                {
                    displaytype => 'text',
                    fieldtype   => 'text',
                    allowsort   => 0,
                    optiongroup => 'otherfields'
                }
            ],

            strCustomStr6 => [
                $CommonVals->{'CustomFields'}->{'strCustomStr6'}[0],
                {
                    displaytype => 'text',
                    fieldtype   => 'text',
                    allowsort   => 0,
                    optiongroup => 'otherfields'
                }
            ],

            strCustomStr7 => [
                $CommonVals->{'CustomFields'}->{'strCustomStr7'}[0],
                {
                    displaytype => 'text',
                    fieldtype   => 'text',
                    allowsort   => 0,
                    optiongroup => 'otherfields'
                }
            ],

            strCustomStr8 => [
                $CommonVals->{'CustomFields'}->{'strCustomStr8'}[0],
                {
                    displaytype => 'text',
                    fieldtype   => 'text',
                    allowsort   => 0,
                    optiongroup => 'otherfields'
                }
            ],

            strCustomStr9 => [
                $CommonVals->{'CustomFields'}->{'strCustomStr9'}[0],
                {
                    displaytype => 'text',
                    fieldtype   => 'text',
                    allowsort   => 0,
                    optiongroup => 'otherfields'
                }
            ],

            strCustomStr10 => [
                $CommonVals->{'CustomFields'}->{'strCustomStr10'}[0],
                {
                    displaytype => 'text',
                    fieldtype   => 'text',
                    allowsort   => 0,
                    optiongroup => 'otherfields'
                }
            ],

            strCustomStr11 => [
                $CommonVals->{'CustomFields'}->{'strCustomStr11'}[0],
                {
                    displaytype => 'text',
                    fieldtype   => 'text',
                    allowsort   => 0,
                    optiongroup => 'otherfields'
                }
            ],

            strCustomStr12 => [
                $CommonVals->{'CustomFields'}->{'strCustomStr12'}[0],
                {
                    displaytype => 'text',
                    fieldtype   => 'text',
                    allowsort   => 0,
                    optiongroup => 'otherfields'
                }
            ],

            strCustomStr13 => [
                $CommonVals->{'CustomFields'}->{'strCustomStr13'}[0],
                {
                    displaytype => 'text',
                    fieldtype   => 'text',
                    allowsort   => 0,
                    optiongroup => 'otherfields'
                }
            ],

            strCustomStr14 => [
                $CommonVals->{'CustomFields'}->{'strCustomStr14'}[0],
                {
                    displaytype => 'text',
                    fieldtype   => 'text',
                    allowsort   => 0,
                    optiongroup => 'otherfields'
                }
            ],

            strCustomStr15 => [
                $CommonVals->{'CustomFields'}->{'strCustomStr15'}[0],
                {
                    displaytype => 'text',
                    fieldtype   => 'text',
                    allowsort   => 0,
                    optiongroup => 'otherfields'
                }
            ],

            strCustomStr16 => [
                $CommonVals->{'CustomFields'}->{'strCustomStr16'}[0],
                {
                    displaytype => 'text',
                    fieldtype   => 'text',
                    allowsort   => 0,
                    optiongroup => 'otherfields'
                }
            ],

            strCustomStr17 => [
                $CommonVals->{'CustomFields'}->{'strCustomStr17'}[0],
                {
                    displaytype => 'text',
                    fieldtype   => 'text',
                    allowsort   => 0,
                    optiongroup => 'otherfields'
                }
            ],

            strCustomStr18 => [
                $CommonVals->{'CustomFields'}->{'strCustomStr18'}[0],
                {
                    displaytype => 'text',
                    fieldtype   => 'text',
                    allowsort   => 0,
                    optiongroup => 'otherfields'
                }
            ],

            strCustomStr19 => [
                $CommonVals->{'CustomFields'}->{'strCustomStr19'}[0],
                {
                    displaytype => 'text',
                    fieldtype   => 'text',
                    allowsort   => 0,
                    optiongroup => 'otherfields'
                }
            ],

            strCustomStr20 => [
                $CommonVals->{'CustomFields'}->{'strCustomStr20'}[0],
                {
                    displaytype => 'text',
                    fieldtype   => 'text',
                    allowsort   => 0,
                    optiongroup => 'otherfields'
                }
            ],

            strCustomStr21 => [
                $CommonVals->{'CustomFields'}->{'strCustomStr21'}[0],
                {
                    displaytype => 'text',
                    fieldtype   => 'text',
                    allowsort   => 0,
                    optiongroup => 'otherfields'
                }
            ],

            strCustomStr22 => [
                $CommonVals->{'CustomFields'}->{'strCustomStr22'}[0],
                {
                    displaytype => 'text',
                    fieldtype   => 'text',
                    allowsort   => 0,
                    optiongroup => 'otherfields'
                }
            ],

            strCustomStr23 => [
                $CommonVals->{'CustomFields'}->{'strCustomStr23'}[0],
                {
                    displaytype => 'text',
                    fieldtype   => 'text',
                    allowsort   => 0,
                    optiongroup => 'otherfields'
                }
            ],

            strCustomStr24 => [
                $CommonVals->{'CustomFields'}->{'strCustomStr24'}[0],
                {
                    displaytype => 'text',
                    fieldtype   => 'text',
                    allowsort   => 0,
                    optiongroup => 'otherfields'
                }
            ],

            strCustomStr25 => [
                $CommonVals->{'CustomFields'}->{'strCustomStr25'}[0],
                {
                    displaytype => 'text',
                    fieldtype   => 'text',
                    allowsort   => 0,
                    optiongroup => 'otherfields'
                }
            ],

            dblCustomDbl1 => [
                $CommonVals->{'CustomFields'}->{'dblCustomDbl1'}[0],
                {
                    displaytype => 'text',
                    fieldtype   => 'text',
                    allowsort   => 0,
                    optiongroup => 'otherfields'
                }
            ],

            dblCustomDbl2 => [
                $CommonVals->{'CustomFields'}->{'dblCustomDbl2'}[0],
                {
                    displaytype => 'text',
                    fieldtype   => 'text',
                    allowsort   => 0,
                    optiongroup => 'otherfields'
                }
            ],

            dblCustomDbl3 => [
                $CommonVals->{'CustomFields'}->{'dblCustomDbl3'}[0],
                {
                    displaytype => 'text',
                    fieldtype   => 'text',
                    allowsort   => 0,
                    optiongroup => 'otherfields'
                }
            ],

            dblCustomDbl4 => [
                $CommonVals->{'CustomFields'}->{'dblCustomDbl4'}[0],
                {
                    displaytype => 'text',
                    fieldtype   => 'text',
                    allowsort   => 0,
                    optiongroup => 'otherfields'
                }
            ],

            dblCustomDbl5 => [
                $CommonVals->{'CustomFields'}->{'dblCustomDbl5'}[0],
                {
                    displaytype => 'text',
                    fieldtype   => 'text',
                    allowsort   => 0,
                    optiongroup => 'otherfields'
                }
            ],

            dblCustomDbl6 => [
                $CommonVals->{'CustomFields'}->{'dblCustomDbl6'}[0],
                {
                    displaytype => 'text',
                    fieldtype   => 'text',
                    allowsort   => 0,
                    optiongroup => 'otherfields'
                }
            ],

            dblCustomDbl7 => [
                $CommonVals->{'CustomFields'}->{'dblCustomDbl7'}[0],
                {
                    displaytype => 'text',
                    fieldtype   => 'text',
                    allowsort   => 0,
                    optiongroup => 'otherfields'
                }
            ],

            dblCustomDbl8 => [
                $CommonVals->{'CustomFields'}->{'dblCustomDbl8'}[0],
                {
                    displaytype => 'text',
                    fieldtype   => 'text',
                    allowsort   => 0,
                    optiongroup => 'otherfields'
                }
            ],

            dblCustomDbl9 => [
                $CommonVals->{'CustomFields'}->{'dblCustomDbl9'}[0],
                {
                    displaytype => 'text',
                    fieldtype   => 'text',
                    allowsort   => 0,
                    optiongroup => 'otherfields'
                }
            ],

            dblCustomDbl10 => [
                $CommonVals->{'CustomFields'}->{'dblCustomDbl10'}[0],
                {
                    displaytype => 'text',
                    fieldtype   => 'text',
                    allowsort   => 0,
                    optiongroup => 'otherfields'
                }
            ],

            dblCustomDbl11 => [
                $CommonVals->{'CustomFields'}->{'dblCustomDbl11'}[0],
                {
                    displaytype => 'text',
                    fieldtype   => 'text',
                    allowsort   => 0,
                    optiongroup => 'otherfields'
                }
            ],

            dblCustomDbl12 => [
                $CommonVals->{'CustomFields'}->{'dblCustomDbl12'}[0],
                {
                    displaytype => 'text',
                    fieldtype   => 'text',
                    allowsort   => 0,
                    optiongroup => 'otherfields'
                }
            ],

            dblCustomDbl13 => [
                $CommonVals->{'CustomFields'}->{'dblCustomDbl13'}[0],
                {
                    displaytype => 'text',
                    fieldtype   => 'text',
                    allowsort   => 0,
                    optiongroup => 'otherfields'
                }
            ],

            dblCustomDbl14 => [
                $CommonVals->{'CustomFields'}->{'dblCustomDbl14'}[0],
                {
                    displaytype => 'text',
                    fieldtype   => 'text',
                    allowsort   => 0,
                    optiongroup => 'otherfields'
                }
            ],

            dblCustomDbl15 => [
                $CommonVals->{'CustomFields'}->{'dblCustomDbl15'}[0],
                {
                    displaytype => 'text',
                    fieldtype   => 'text',
                    allowsort   => 0,
                    optiongroup => 'otherfields'
                }
            ],

            dblCustomDbl16 => [
                $CommonVals->{'CustomFields'}->{'dblCustomDbl16'}[0],
                {
                    displaytype => 'text',
                    fieldtype   => 'text',
                    allowsort   => 0,
                    optiongroup => 'otherfields'
                }
            ],

            dblCustomDbl17 => [
                $CommonVals->{'CustomFields'}->{'dblCustomDbl17'}[0],
                {
                    displaytype => 'text',
                    fieldtype   => 'text',
                    allowsort   => 0,
                    optiongroup => 'otherfields'
                }
            ],

            dblCustomDbl18 => [
                $CommonVals->{'CustomFields'}->{'dblCustomDbl18'}[0],
                {
                    displaytype => 'text',
                    fieldtype   => 'text',
                    allowsort   => 0,
                    optiongroup => 'otherfields'
                }
            ],

            dblCustomDbl19 => [
                $CommonVals->{'CustomFields'}->{'dblCustomDbl19'}[0],
                {
                    displaytype => 'text',
                    fieldtype   => 'text',
                    allowsort   => 0,
                    optiongroup => 'otherfields'
                }
            ],

            dblCustomDbl20 => [
                $CommonVals->{'CustomFields'}->{'dblCustomDbl20'}[0],
                {
                    displaytype => 'text',
                    fieldtype   => 'text',
                    allowsort   => 0,
                    optiongroup => 'otherfields'
                }
            ],

            dtCustomDt1 => [
                $CommonVals->{'CustomFields'}->{'dtCustomDt1'}[0],
                {
                    displaytype => 'date',
                    fieldtype   => 'date',
                    allowsort   => 0,
                    optiongroup => 'otherfields',
                    dbformat =>
' DATE_FORMAT(tblMember_Associations.dtCustomDt1, "%d/%m/%Y")',
                    dbfield => 'tblMember_Associations.dtCustomDt1'
                }
            ],

            dtCustomDt2 => [
                $CommonVals->{'CustomFields'}->{'dtCustomDt2'}[0],
                {
                    displaytype => 'date',
                    fieldtype   => 'date',
                    allowsort   => 0,
                    optiongroup => 'otherfields',
                    dbformat =>
' DATE_FORMAT(tblMember_Associations.dtCustomDt2, "%d/%m/%Y")',
                    dbfield => 'tblMember_Associations.dtCustomDt2'
                }
            ],

            dtCustomDt3 => [
                $CommonVals->{'CustomFields'}->{'dtCustomDt3'}[0],
                {
                    displaytype => 'date',
                    fieldtype   => 'date',
                    allowsort   => 0,
                    optiongroup => 'otherfields',
                    dbformat =>
' DATE_FORMAT(tblMember_Associations.dtCustomDt3, "%d/%m/%Y")',
                    dbfield => 'tblMember_Associations.dtCustomDt3'
                }
            ],

            dtCustomDt4 => [
                $CommonVals->{'CustomFields'}->{'dtCustomDt4'}[0],
                {
                    displaytype => 'date',
                    fieldtype   => 'date',
                    allowsort   => 0,
                    optiongroup => 'otherfields',
                    dbformat =>
' DATE_FORMAT(tblMember_Associations.dtCustomDt4, "%d/%m/%Y")',
                    dbfield => 'tblMember_Associations.dtCustomDt4'
                }
            ],

            dtCustomDt5 => [
                $CommonVals->{'CustomFields'}->{'dtCustomDt5'}[0],
                {
                    displaytype => 'date',
                    fieldtype   => 'date',
                    allowsort   => 0,
                    optiongroup => 'otherfields',
                    dbformat =>
' DATE_FORMAT(tblMember_Associations.dtCustomDt5, "%d/%m/%Y")',
                    dbfield => 'tblMember_Associations.dtCustomDt5'
                }
            ],

            dtCustomDt6 => [
                $CommonVals->{'CustomFields'}->{'dtCustomDt6'}[0],
                {
                    displaytype => 'date',
                    fieldtype   => 'date',
                    allowsort   => 0,
                    optiongroup => 'otherfields',
                    dbformat =>
' DATE_FORMAT(tblMember_Associations.dtCustomDt6, "%d/%m/%Y")',
                    dbfield => 'tblMember_Associations.dtCustomDt6'
                }
            ],

            dtCustomDt7 => [
                $CommonVals->{'CustomFields'}->{'dtCustomDt7'}[0],
                {
                    displaytype => 'date',
                    fieldtype   => 'date',
                    allowsort   => 0,
                    optiongroup => 'otherfields',
                    dbformat =>
' DATE_FORMAT(tblMember_Associations.dtCustomDt7, "%d/%m/%Y")',
                    dbfield => 'tblMember_Associations.dtCustomDt7'
                }
            ],

            dtCustomDt8 => [
                $CommonVals->{'CustomFields'}->{'dtCustomDt8'}[0],
                {
                    displaytype => 'date',
                    fieldtype   => 'date',
                    allowsort   => 0,
                    optiongroup => 'otherfields',
                    dbformat =>
' DATE_FORMAT(tblMember_Associations.dtCustomDt8, "%d/%m/%Y")',
                    dbfield => 'tblMember_Associations.dtCustomDt8'
                }
            ],

            dtCustomDt9 => [
                $CommonVals->{'CustomFields'}->{'dtCustomDt9'}[0],
                {
                    displaytype => 'date',
                    fieldtype   => 'date',
                    allowsort   => 0,
                    optiongroup => 'otherfields',
                    dbformat =>
' DATE_FORMAT(tblMember_Associations.dtCustomDt9, "%d/%m/%Y")',
                    dbfield => 'tblMember_Associations.dtCustomDt9'
                }
            ],

            dtCustomDt10 => [
                $CommonVals->{'CustomFields'}->{'dtCustomDt10'}[0],
                {
                    displaytype => 'date',
                    fieldtype   => 'date',
                    allowsort   => 0,
                    optiongroup => 'otherfields',
                    dbformat =>
' DATE_FORMAT(tblMember_Associations.dtCustomDt10, "%d/%m/%Y")',
                    dbfield => 'tblMember_Associations.dtCustomDt10'
                }
            ],

            dtCustomDt11 => [
                $CommonVals->{'CustomFields'}->{'dtCustomDt11'}[0],
                {
                    displaytype => 'date',
                    fieldtype   => 'date',
                    allowsort   => 0,
                    optiongroup => 'otherfields',
                    dbformat =>
' DATE_FORMAT(tblMember_Associations.dtCustomDt11, "%d/%m/%Y")',
                    dbfield => 'tblMember_Associations.dtCustomDt11'
                }
            ],

            dtCustomDt12 => [
                $CommonVals->{'CustomFields'}->{'dtCustomDt12'}[0],
                {
                    displaytype => 'date',
                    fieldtype   => 'date',
                    allowsort   => 0,
                    optiongroup => 'otherfields',
                    dbformat =>
' DATE_FORMAT(tblMember_Associations.dtCustomDt12, "%d/%m/%Y")',
                    dbfield => 'tblMember_Associations.dtCustomDt12'
                }
            ],

            dtCustomDt13 => [
                $CommonVals->{'CustomFields'}->{'dtCustomDt13'}[0],
                {
                    displaytype => 'date',
                    fieldtype   => 'date',
                    allowsort   => 0,
                    optiongroup => 'otherfields',
                    dbformat =>
' DATE_FORMAT(tblMember_Associations.dtCustomDt13, "%d/%m/%Y")',
                    dbfield => 'tblMember_Associations.dtCustomDt13'
                }
            ],

            dtCustomDt14 => [
                $CommonVals->{'CustomFields'}->{'dtCustomDt14'}[0],
                {
                    displaytype => 'date',
                    fieldtype   => 'date',
                    allowsort   => 0,
                    optiongroup => 'otherfields',
                    dbformat =>
' DATE_FORMAT(tblMember_Associations.dtCustomDt14, "%d/%m/%Y")',
                    dbfield => 'tblMember_Associations.dtCustomDt14'
                }
            ],

            dtCustomDt15 => [
                $CommonVals->{'CustomFields'}->{'dtCustomDt15'}[0],
                {
                    displaytype => 'date',
                    fieldtype   => 'date',
                    allowsort   => 0,
                    optiongroup => 'otherfields',
                    dbformat =>
' DATE_FORMAT(tblMember_Associations.dtCustomDt15, "%d/%m/%Y")',
                    dbfield => 'tblMember_Associations.dtCustomDt15'
                }
            ],

            intCustomLU1 => [
                $CommonVals->{'CustomFields'}->{'intCustomLU1'}[0],
                {
                    displaytype     => 'lookup',
                    fieldtype       => 'dropdown',
                    dropdownoptions => $CommonVals->{'DefCodes'}{-50},
                    optiongroup     => 'otherfields',
                    size            => 3,
                    multiple        => 1
                }
            ],

            intCustomLU2 => [
                $CommonVals->{'CustomFields'}->{'intCustomLU2'}[0],
                {
                    displaytype     => 'lookup',
                    fieldtype       => 'dropdown',
                    dropdownoptions => $CommonVals->{'DefCodes'}{-51},
                    optiongroup     => 'otherfields',
                    size            => 3,
                    multiple        => 1
                }
            ],

            intCustomLU3 => [
                $CommonVals->{'CustomFields'}->{'intCustomLU3'}[0],
                {
                    displaytype     => 'lookup',
                    fieldtype       => 'dropdown',
                    dropdownoptions => $CommonVals->{'DefCodes'}{-52},
                    optiongroup     => 'otherfields',
                    size            => 3,
                    multiple        => 1
                }
            ],

            intCustomLU4 => [
                $CommonVals->{'CustomFields'}->{'intCustomLU4'}[0],
                {
                    displaytype     => 'lookup',
                    fieldtype       => 'dropdown',
                    dropdownoptions => $CommonVals->{'DefCodes'}{-57},
                    optiongroup     => 'otherfields',
                    size            => 3,
                    multiple        => 1
                }
            ],

            intCustomLU5 => [
                $CommonVals->{'CustomFields'}->{'intCustomLU5'}[0],
                {
                    displaytype     => 'lookup',
                    fieldtype       => 'dropdown',
                    dropdownoptions => $CommonVals->{'DefCodes'}{-58},
                    optiongroup     => 'otherfields',
                    size            => 3,
                    multiple        => 1
                }
            ],

            intCustomLU6 => [
                $CommonVals->{'CustomFields'}->{'intCustomLU6'}[0],
                {
                    displaytype     => 'lookup',
                    fieldtype       => 'dropdown',
                    dropdownoptions => $CommonVals->{'DefCodes'}{-59},
                    optiongroup     => 'otherfields',
                    size            => 3,
                    multiple        => 1
                }
            ],

            intCustomLU7 => [
                $CommonVals->{'CustomFields'}->{'intCustomLU7'}[0],
                {
                    displaytype     => 'lookup',
                    fieldtype       => 'dropdown',
                    dropdownoptions => $CommonVals->{'DefCodes'}{-60},
                    optiongroup     => 'otherfields',
                    size            => 3,
                    multiple        => 1
                }
            ],

            intCustomLU8 => [
                $CommonVals->{'CustomFields'}->{'intCustomLU8'}[0],
                {
                    displaytype     => 'lookup',
                    fieldtype       => 'dropdown',
                    dropdownoptions => $CommonVals->{'DefCodes'}{-61},
                    optiongroup     => 'otherfields',
                    size            => 3,
                    multiple        => 1
                }
            ],

            intCustomLU9 => [
                $CommonVals->{'CustomFields'}->{'intCustomLU9'}[0],
                {
                    displaytype     => 'lookup',
                    fieldtype       => 'dropdown',
                    dropdownoptions => $CommonVals->{'DefCodes'}{-62},
                    optiongroup     => 'otherfields',
                    size            => 3,
                    multiple        => 1
                }
            ],

            intCustomLU10 => [
                $CommonVals->{'CustomFields'}->{'intCustomLU10'}[0],
                {
                    displaytype     => 'lookup',
                    fieldtype       => 'dropdown',
                    dropdownoptions => $CommonVals->{'DefCodes'}{-63},
                    optiongroup     => 'otherfields',
                    size            => 3,
                    multiple        => 1
                }
            ],
            intCustomLU11 => [
                $CommonVals->{'CustomFields'}->{'intCustomLU11'}[0],
                {
                    displaytype     => 'lookup',
                    fieldtype       => 'dropdown',
                    dropdownoptions => $CommonVals->{'DefCodes'}{-97},
                    optiongroup     => 'otherfields',
                    size            => 3,
                    multiple        => 1
                }
            ],
            intCustomLU12 => [
                $CommonVals->{'CustomFields'}->{'intCustomLU12'}[0],
                {
                    displaytype     => 'lookup',
                    fieldtype       => 'dropdown',
                    dropdownoptions => $CommonVals->{'DefCodes'}{-98},
                    optiongroup     => 'otherfields',
                    size            => 3,
                    multiple        => 1
                }
            ],
            intCustomLU13 => [
                $CommonVals->{'CustomFields'}->{'intCustomLU13'}[0],
                {
                    displaytype     => 'lookup',
                    fieldtype       => 'dropdown',
                    dropdownoptions => $CommonVals->{'DefCodes'}{-99},
                    optiongroup     => 'otherfields',
                    size            => 3,
                    multiple        => 1
                }
            ],
            intCustomLU14 => [
                $CommonVals->{'CustomFields'}->{'intCustomLU14'}[0],
                {
                    displaytype     => 'lookup',
                    fieldtype       => 'dropdown',
                    dropdownoptions => $CommonVals->{'DefCodes'}{-100},
                    optiongroup     => 'otherfields',
                    size            => 3,
                    multiple        => 1
                }
            ],
            intCustomLU15 => [
                $CommonVals->{'CustomFields'}->{'intCustomLU15'}[0],
                {
                    displaytype     => 'lookup',
                    fieldtype       => 'dropdown',
                    dropdownoptions => $CommonVals->{'DefCodes'}{-101},
                    optiongroup     => 'otherfields',
                    size            => 3,
                    multiple        => 1
                }
            ],
            intCustomLU16 => [
                $CommonVals->{'CustomFields'}->{'intCustomLU16'}[0],
                {
                    displaytype     => 'lookup',
                    fieldtype       => 'dropdown',
                    dropdownoptions => $CommonVals->{'DefCodes'}{-102},
                    optiongroup     => 'otherfields',
                    size            => 3,
                    multiple        => 1
                }
            ],
            intCustomLU17 => [
                $CommonVals->{'CustomFields'}->{'intCustomLU17'}[0],
                {
                    displaytype     => 'lookup',
                    fieldtype       => 'dropdown',
                    dropdownoptions => $CommonVals->{'DefCodes'}{-103},
                    optiongroup     => 'otherfields',
                    size            => 3,
                    multiple        => 1
                }
            ],
            intCustomLU18 => [
                $CommonVals->{'CustomFields'}->{'intCustomLU18'}[0],
                {
                    displaytype     => 'lookup',
                    fieldtype       => 'dropdown',
                    dropdownoptions => $CommonVals->{'DefCodes'}{-104},
                    optiongroup     => 'otherfields',
                    size            => 3,
                    multiple        => 1
                }
            ],
            intCustomLU19 => [
                $CommonVals->{'CustomFields'}->{'intCustomLU19'}[0],
                {
                    displaytype     => 'lookup',
                    fieldtype       => 'dropdown',
                    dropdownoptions => $CommonVals->{'DefCodes'}{-105},
                    optiongroup     => 'otherfields',
                    size            => 3,
                    multiple        => 1
                }
            ],
            intCustomLU20 => [
                $CommonVals->{'CustomFields'}->{'intCustomLU20'}[0],
                {
                    displaytype     => 'lookup',
                    fieldtype       => 'dropdown',
                    dropdownoptions => $CommonVals->{'DefCodes'}{-106},
                    optiongroup     => 'otherfields',
                    size            => 3,
                    multiple        => 1
                }
            ],
            intCustomLU21 => [
                $CommonVals->{'CustomFields'}->{'intCustomLU21'}[0],
                {
                    displaytype     => 'lookup',
                    fieldtype       => 'dropdown',
                    dropdownoptions => $CommonVals->{'DefCodes'}{-107},
                    optiongroup     => 'otherfields',
                    size            => 3,
                    multiple        => 1
                }
            ],
            intCustomLU22 => [
                $CommonVals->{'CustomFields'}->{'intCustomLU22'}[0],
                {
                    displaytype     => 'lookup',
                    fieldtype       => 'dropdown',
                    dropdownoptions => $CommonVals->{'DefCodes'}{-108},
                    optiongroup     => 'otherfields',
                    size            => 3,
                    multiple        => 1
                }
            ],
            intCustomLU23 => [
                $CommonVals->{'CustomFields'}->{'intCustomLU23'}[0],
                {
                    displaytype     => 'lookup',
                    fieldtype       => 'dropdown',
                    dropdownoptions => $CommonVals->{'DefCodes'}{-109},
                    optiongroup     => 'otherfields',
                    size            => 3,
                    multiple        => 1
                }
            ],
            intCustomLU24 => [
                $CommonVals->{'CustomFields'}->{'intCustomLU24'}[0],
                {
                    displaytype     => 'lookup',
                    fieldtype       => 'dropdown',
                    dropdownoptions => $CommonVals->{'DefCodes'}{-110},
                    optiongroup     => 'otherfields',
                    size            => 3,
                    multiple        => 1
                }
            ],
            intCustomLU25 => [
                $CommonVals->{'CustomFields'}->{'intCustomLU25'}[0],
                {
                    displaytype     => 'lookup',
                    fieldtype       => 'dropdown',
                    dropdownoptions => $CommonVals->{'DefCodes'}{-111},
                    optiongroup     => 'otherfields',
                    size            => 3,
                    multiple        => 1
                }
            ],

            intCustomBool1 => [
                $CommonVals->{'CustomFields'}->{'intCustomBool1'}[0],
                {
                    displaytype     => 'lookup',
                    fieldtype       => 'dropdown',
                    dropdownoptions => {
                        0 => 'No',
                        1 => 'Yes'
                    },
                    dropdownorder => [ 0, 1 ],
                    optiongroup   => 'otherfields'
                }
            ],

            intCustomBool2 => [
                $CommonVals->{'CustomFields'}->{'intCustomBool2'}[0],
                {
                    displaytype     => 'lookup',
                    fieldtype       => 'dropdown',
                    dropdownoptions => {
                        0 => 'No',
                        1 => 'Yes'
                    },
                    dropdownorder => [ 0, 1 ],
                    optiongroup   => 'otherfields'
                }
            ],

            intCustomBool3 => [
                $CommonVals->{'CustomFields'}->{'intCustomBool3'}[0],
                {
                    displaytype     => 'lookup',
                    fieldtype       => 'dropdown',
                    dropdownoptions => {
                        0 => 'No',
                        1 => 'Yes'
                    },
                    dropdownorder => [ 0, 1 ],
                    optiongroup   => 'otherfields'
                }
            ],

            intCustomBool4 => [
                $CommonVals->{'CustomFields'}->{'intCustomBool4'}[0],
                {
                    displaytype     => 'lookup',
                    fieldtype       => 'dropdown',
                    dropdownoptions => {
                        0 => 'No',
                        1 => 'Yes'
                    },
                    dropdownorder => [ 0, 1 ],
                    optiongroup   => 'otherfields'
                }
            ],

            intCustomBool5 => [
                $CommonVals->{'CustomFields'}->{'intCustomBool5'}[0],
                {
                    displaytype     => 'lookup',
                    fieldtype       => 'dropdown',
                    dropdownoptions => {
                        0 => 'No',
                        1 => 'Yes'
                    },
                    dropdownorder => [ 0, 1 ],
                    optiongroup   => 'otherfields'
                }
            ],

            intCustomBool6 => [
                $CommonVals->{'CustomFields'}->{'intCustomBool6'}[0],
                {
                    displaytype     => 'lookup',
                    fieldtype       => 'dropdown',
                    dropdownoptions => {
                        0 => 'No',
                        1 => 'Yes'
                    },
                    dropdownorder => [ 0, 1 ],
                    optiongroup   => 'otherfields'
                }
            ],

            intCustomBool7 => [
                $CommonVals->{'CustomFields'}->{'intCustomBool7'}[0],
                {
                    displaytype     => 'lookup',
                    fieldtype       => 'dropdown',
                    dropdownoptions => {
                        0 => 'No',
                        1 => 'Yes'
                    },
                    dropdownorder => [ 0, 1 ],
                    optiongroup   => 'otherfields'
                }
            ],

            intGradeID => [
                'School Grade',
                {
                    displaytype     => 'lookup',
                    fieldtype       => 'dropdown',
                    dropdownoptions => $CommonVals->{'SchoolGrades'}{'Options'},
                    dropdownorder   => $CommonVals->{'SchoolGrades'}{'Order'},
                    optiongroup     => 'otherfields',
                    allowsort       => 1,
                    size            => 3,
                    multiple        => 1,
                    dbfield         => 'tblMember.intGradeID',
                    allowgrouping   => 1,
                    enabled         => $Data->{'SystemConfig'}{'Schools'},
                }
            ],

            strSchoolName => [
                'School Name',
                {
                    displaytype   => 'text',
                    allowgrouping => 1,
                    fieldtype     => 'text',
                    allowsort     => 1,
                    dbfield       => 'tblSchool.strName',
                    optiongroup   => 'otherfields',
                    dbfrom =>
'LEFT JOIN tblSchool ON (tblMember.intSchoolID = tblSchool.intSchoolID)',
                    enabled => (
                             $Data->{'SystemConfig'}{'rptSchools'}
                          or $Data->{'SystemConfig'}{'Schools'}
                    ),
                }
            ],

            strSchoolSuburb => [
                (
                         $Data->{'SystemConfig'}{'rptSchools'}
                      or $Data->{'SystemConfig'}{'Schools'}
                ) ? 'School Suburb' : '',
                {
                    displaytype => 'text',
                    fieldtype   => 'text',
                    allowsort   => 1,
                    dbfield     => 'tblSchool.strSuburb',
                    optiongroup => 'otherfields',
                    dbfrom =>
'LEFT JOIN tblSchool ON (tblMember.intSchoolID = tblSchool.intSchoolID)',
                    allowgrouping => 1
                }
            ],

            intFavStateTeamID => [
                'State Team Supported',
                {
                    displaytype     => 'lookup',
                    fieldtype       => 'dropdown',
                    dropdownoptions => $CommonVals->{'DefCodes'}{-33},
                    optiongroup     => 'otherfields',
                    allowgrouping   => 1
                }
            ],

            intFavNationalTeamID => [
                $natteamname . ' Supported',
                {
                    displaytype     => 'lookup',
                    fieldtype       => 'dropdown',
                    dropdownoptions => $CommonVals->{'DefCodes'}{-34},
                    allowgrouping   => 1,
                    optiongroup     => 'otherfields'
                }
            ],

            intFavNationalTeamMember => [
                $natteamname . 'Member',
                {
                    displaytype     => 'lookup',
                    fieldtype       => 'dropdown',
                    dropdownoptions => {
                        0 => 'No',
                        1 => 'Yes'
                    },
                    dropdownorder => [ 0, 1 ],
                    dbfield       => 'tblMember.intFavNationalTeamMember',
                    optiongroup   => 'otherfields',
                    allowgrouping => 1
                }
            ],

            intAttendSportCount => [
                'Games attended',
                {
                    displaytype   => 'text',
                    fieldtype     => 'text',
                    allowgrouping => 1,
                    optiongroup   => 'otherfields'
                }
            ],

            intWatchSportHowOftenID => [
                'Watch sport on TV ?',
                {
                    displaytype     => 'lookup',
                    fieldtype       => 'dropdown',
                    dropdownoptions => $CommonVals->{'DefCodes'}{-1004},
                    allowgrouping   => 1,
                    optiongroup     => 'otherfields'
                }
            ],

            strMemberNotes => [
                'Notes',
                {
                    displaytype => 'text',
                    fieldtype   => 'text',
                    allowsort   => 0,
                    dbfield     => 'strMemberNotes',
                    optiongroup => 'otherfields',
                    dbfrom =>
'LEFT JOIN tblMemberNotes as MN ON (MN.intNotesMemberID = tblMember_Associations.intMemberID AND MN.intNotesAssocID = tblMember_Associations.intAssocID)'
                }
            ],

            strMemberCustomNotes1 => [
                $CommonVals->{'CustomFields'}->{'strMemberCustomNotes1'}[0],
                {
                    displaytype => 'text',
                    fieldtype   => 'text',
                    allowsort   => 0,
                    dbfield     => 'strMemberCustomNotes1',
                    optiongroup => 'otherfields',
                    dbfrom =>
'LEFT JOIN tblMemberNotes as MN ON (MN.intNotesMemberID = tblMember_Associations.intMemberID AND MN.intNotesAssocID = tblMember_Associations.intAssocID)'
                }
            ],

            strMemberCustomNotes2 => [
                $CommonVals->{'CustomFields'}->{'strMemberCustomNotes2'}[0],
                {
                    displaytype => 'text',
                    fieldtype   => 'text',
                    allowsort   => 0,
                    dbfield     => 'strMemberCustomNotes2',
                    optiongroup => 'otherfields',
                    dbfrom =>
'LEFT JOIN tblMemberNotes as MN ON (MN.intNotesMemberID = tblMember_Associations.intMemberID AND MN.intNotesAssocID = tblMember_Associations.intAssocID)'
                }
            ],

            strMemberCustomNotes3 => [
                $CommonVals->{'CustomFields'}->{'strMemberCustomNotes3'}[0],
                {
                    displaytype => 'text',
                    fieldtype   => 'text',
                    allowsort   => 0,
                    dbfield     => 'strMemberCustomNotes3',
                    optiongroup => 'otherfields',
                    dbfrom =>
'LEFT JOIN tblMemberNotes as MN ON (MN.intNotesMemberID = tblMember_Associations.intMemberID AND MN.intNotesAssocID = tblMember_Associations.intAssocID)'
                }
            ],

            strMemberCustomNotes4 => [
                $CommonVals->{'CustomFields'}->{'strMemberCustomNotes4'}[0],
                {
                    displaytype => 'text',
                    fieldtype   => 'text',
                    allowsort   => 0,
                    dbfield     => 'strMemberCustomNotes4',
                    optiongroup => 'otherfields',
                    dbfrom =>
'LEFT JOIN tblMemberNotes as MN ON (MN.intNotesMemberID = tblMember_Associations.intMemberID AND MN.intNotesAssocID = tblMember_Associations.intAssocID)'
                }
            ],

            strMemberCustomNotes5 => [
                $CommonVals->{'CustomFields'}->{'strMemberCustomNotes5'}[0],
                {
                    displaytype => 'text',
                    fieldtype   => 'text',
                    allowsort   => 0,
                    dbfield     => 'strMemberCustomNotes5',
                    optiongroup => 'otherfields',
                    dbfrom =>
'LEFT JOIN tblMemberNotes as MN ON (MN.intNotesMemberID = tblMember_Associations.intMemberID AND MN.intNotesAssocID = tblMember_Associations.intAssocID)'
                }
            ],

            intPhoto => [
                'Photo Present?',
                {
                    displaytype     => 'lookup',
                    fieldtype       => 'dropdown',
                    dropdownoptions => { 0 => 'No', 1 => 'Yes' },
                    dropdownorder => [ 0, 1 ],
                    dbfield       => 'tblMember.intPhoto',
                    optiongroup   => 'otherfields',
                    allowgrouping => 1
                }
            ],

            intTagID => [
                ( $SystemConfig->{'NoMemberTags'} ? '' : 'Tags' ),
                {
                    displaytype     => 'lookup',
                    fieldtype       => 'dropdown',
                    dropdownoptions => $CommonVals->{'DefCodes'}{-24},
                    optiongroup     => 'otherfields',
                    multiple        => 1,
                    size            => "7",
                    dbfield         => 'tblMemberTags.intTagID',
                    dbfrom =>
" LEFT JOIN tblMemberTags ON (tblMember.intMemberID=tblMemberTags.intMemberID AND tblMember_Associations.intAssocID=tblMemberTags.intAssocID AND tblMemberTags.intRecStatus <> $Defs::RECSTATUS_DELETED)"
                }
            ],

            dtFirstRegistered => [
                  $Data->{'SystemConfig'}{'FirstRegistered_title'}
                ? $Data->{'SystemConfig'}{'FirstRegistered_title'}
                : 'First Registered',
                {
                    displaytype => 'date',
                    fieldtype   => 'date',
                    allowsort   => 1,
                    dbformat =>
' DATE_FORMAT(tblMember_Associations.dtFirstRegistered, "%d/%m/%Y")',
                    dbfield     => 'tblMember_Associations.dtFirstRegistered',
                    optiongroup => 'otherfields'
                }
            ],

            dtLastRegistered => [
                'Last Registered',
                {
                    displaytype => 'date',
                    fieldtype   => 'date',
                    allowsort   => 1,
                    dbformat =>
' DATE_FORMAT(tblMember_Associations.dtLastRegistered, "%d/%m/%Y")',
                    optiongroup => 'otherfields',
                    dbfield     => 'tblMember_Associations.dtLastRegistered'
                }
            ],

            dtRegisteredUntil => [
                'Registered Until',
                {
                    displaytype => 'date',
                    fieldtype   => 'date',
                    allowsort   => 1,
                    dbformat =>
' DATE_FORMAT(IF(tblMember_Associations.dtRegisteredUntil IS NULL, "0000-00-00", dtRegisteredUntil), "%d/%m/%Y")',
                    optiongroup => 'otherfields',
                    dbfield     => 'tblMember_Associations.dtRegisteredUntil'
                }
            ],

            dtSuspendedUntil => [
                $Data->{'SystemConfig'}{'NoComps'} ? '' : 'Suspended Until',
                {
                    displaytype => 'date',
                    fieldtype   => 'date',
                    allowsort   => 1,
                    dbformat =>
                      ' DATE_FORMAT(tblMember.dtSuspendedUntil, "%d/%m/%Y")',
                    optiongroup => 'otherfields',
                    dbfield     => 'tblMember.dtSuspendedUntil'
                }
            ],

            dtLastUpdate => [
                'Last Updated',
                {
                    displaytype => 'date',
                    fieldtype   => 'datetime',
                    allowsort   => 1,
                    dbformat =>
' DATE_FORMAT(tblMember_Associations.tTimeStamp, "%d/%m/%Y")',
                    optiongroup => 'otherfields',
                    dbfield     => 'tblMember_Associations.tTimeStamp'
                }
            ],

            dtCreatedOnline => [
                'Date Created Online',
                {
                    displaytype => 'date',
                    fieldtype   => 'datetime',
                    allowsort   => 1,
                    dbformat =>
                      ' DATE_FORMAT(tblMember.dtCreatedOnline, "%d/%m/%Y")',
                    optiongroup => 'otherfields',
                    dbfield     => 'tblMember.dtCreatedOnline'
                }
            ],

            intHowFoundOutID => [
                'How did you find out about us?',
                {
                    displaytype     => 'lookup',
                    fieldtype       => 'dropdown',
                    dropdownoptions => $CommonVals->{'DefCodes'}{-1001},
                    optiongroup     => 'otherfields'
                }
            ],

            intConsentSignatureSighted => [
                $SystemConfig->{'SignatureSightedText'} || 'Signature Sighted?',
                {
                    displaytype     => 'lookup',
                    fieldtype       => 'dropdown',
                    dropdownoptions => { 0 => 'No', 1 => 'Yes' },
                    dropdownorder => [ 0, 1 ],
                    dbfield       => 'intConsentSignatureSighted',
                    optiongroup   => 'otherfields',
                    allowgrouping => 1
                }
            ],

            intCreatedFrom => [
                'Record creation',
                {
                    displaytype     => 'lookup',
                    fieldtype       => 'dropdown',
                    dropdownoptions => \%Defs::CreatedBy,
                    allowsort       => 1,
                    optiongroup     => 'otherfields',
                    dbfield =>
'IF(intCreatedFrom NOT IN (0, 1, 200), -1, intCreatedFrom)',
                    allowgrouping => 1
                }
            ],

            strUmpirePassword => [
                (
                    $Data->{'SystemConfig'}{'AllowCourtside'}
                    ? 'Umpire Password'
                    : ''
                ),
                {
                    displaytype   => 'text',
                    fieldtype     => 'text',
                    allowsort     => 1,
                    optiongroup   => 'otherfields',
                    allowgrouping => 1
                }
            ],

            # member record types
            strMemberRecordTypeList => [
                $Data->{'SystemConfig'}{'EnableMemberRecords'} ? "Member Record Type" : 'A',
                {
                    displaytype     => 'lookup',
                    allowsort   => 1,
                    fieldtype       => 'dropdown',
                    dropdownoptions => $CommonVals->{'RecordTypes'}{'Options'},
                    dropdownorder   => $CommonVals->{'RecordTypes'}{'Order'},
                    allowsort       => 1,
                    allowgrouping   => 1,
                    optiongroup     => 'records',
                    multiple        => 1,
                    size            => 3,
                    dbfield         => "$MStablename.intMemberRecordTypeID",
                    disable         => ( !$enable_record_types ),
                }
            ],

            dtMemberRecordIn => [
                'Registered Date',
                {
                    displaytype => 'date',
                    fieldtype   => 'datetime',
                    allowsort   => 1,
                    dbformat =>
                      qq[ DATE_FORMAT($MStablename.dtIn, "%d/%m/%Y")],
                    optiongroup => 'records',
                    dbfield     => "$MStablename.dtIn",
                    disable     => ( !$enable_record_types ),
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
                    displaytype => 'date',
                    fieldtype   => 'date',
                    dbfield     => 'tblMT_Player.dtDate1',
                    dbformat =>
                      ' DATE_FORMAT(tblMT_Player.dtDate1, "%d/%m/%Y")',
                    optiongroup => 'mt_player',
                    allowsort   => 1,
                }
            ],

            intCareerGames => [
                "$Data->{'LevelNames'}{$Defs::LEVEL_ASSOC} Career Games",
                {
                    displaytype => 'text',
                    fieldtype   => 'text',
                    dbfield     => 'tblMT_Player.intInt1',
                    optiongroup => 'mt_player',
                    allowsort   => 1,
                    sorttype    => 'number',

                }
            ],

            intPlayerJunior => [
                'Junior ?',
                {
                    displaytype     => 'lookup',
                    fieldtype       => 'dropdown',
                    dropdownoptions => { 0 => 'No', 1 => 'Yes' },
                    dropdownorder => [ 0, 1 ],
                    dbfield       => 'tblMT_Player.intInt2',
                    optiongroup   => 'mt_player'
                }
            ],

            intPlayerSenior => [
                'Senior ?',
                {
                    displaytype     => 'lookup',
                    fieldtype       => 'dropdown',
                    dropdownoptions => { 0 => 'No', 1 => 'Yes' },
                    dropdownorder => [ 0, 1 ],
                    dbfield       => 'tblMT_Player.intInt3',
                    optiongroup   => 'mt_player'
                }
            ],

            intPlayerVeteran => [
                'Veteran ?',
                {
                    displaytype     => 'lookup',
                    fieldtype       => 'dropdown',
                    dropdownoptions => { 0 => 'No', 1 => 'Yes' },
                    dropdownorder => [ 0, 1 ],
                    dbfield       => 'tblMT_Player.intInt4',
                    optiongroup   => 'mt_player'
                }
            ],

            #Coach Stuff
            strCoachRegNo => [
                $Data->{'SystemConfig'}{'FieldLabel_Accred.strString1'}
                  || 'Coach Registration Number',
                {
                    displaytype => 'text',
                    fieldtype   => 'text',
                    dbfield     => 'tblMT_Coach.strString1',
                    optiongroup => 'mt_coach'
                }
            ],
            strInstrucRegNo => [
                'Instructor Registration Number',
                {
                    displaytype => 'text',
                    fieldtype   => 'text',
                    dbfield     => 'tblMT_Coach.strString2',
                    optiongroup => 'mt_coach'
                }
            ],
            intCOCustomDDL_1 => [
                $Data->{'SystemConfig'}{'COACH_intInt6_Custom1'}
                ? "Coach " . $Data->{'SystemConfig'}{'COACH_intInt6_Custom1'}
                : '',
                {
                    displaytype     => 'lookup',
                    fieldtype       => 'dropdown',
                    dropdownoptions => $CommonVals->{'DefCodes'}{-43},
                    dbfield         => 'tblMT_Coach.intInt6',
                    optiongroup     => 'mt_coach'
                }
            ],
            intCOCustomDDL_2 => [
                $Data->{'SystemConfig'}{'COACH_intInt7_Custom1'}
                ? "Coach " . $Data->{'SystemConfig'}{'COACH_intInt7_Custom1'}
                : '',
                {
                    displaytype     => 'lookup',
                    fieldtype       => 'dropdown',
                    dropdownoptions => $CommonVals->{'DefCodes'}{-44},
                    dbfield         => 'tblMT_Coach.intInt7',
                    optiongroup     => 'mt_coach'
                }
            ],
            intCOCustomDDL_3 => [
                $Data->{'SystemConfig'}{'COACH_intInt8_Custom1'}
                ? "Coach " . $Data->{'SystemConfig'}{'COACH_intInt8_Custom1'}
                : '',
                {
                    displaytype     => 'lookup',
                    fieldtype       => 'dropdown',
                    dropdownoptions => $CommonVals->{'DefCodes'}{-45},
                    dbfield         => 'tblMT_Coach.intInt8',
                    optiongroup     => 'mt_coach'
                }
            ],
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
            intDeregisteredCoach => [
                'Deregistered Coach',
                {
                    displaytype     => 'lookup',
                    fieldtype       => 'dropdown',
                    dropdownoptions => { 0 => 'No', 1 => 'Yes' },
                    dropdownorder => [ 0, 1 ],
                    dbfield       => 'tblMT_Coach.intInt1',
                    optiongroup   => 'mt_coach'
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
            strCoachAccredResult => [
                $NRO{'Accreditation'}
                ? 'Coach Accred. ' . $FieldLabels->{'Accred.intInt6'}
                  || 'Coach Accred. Result'
                : '',
                {
                    displaytype     => 'lookup',
                    fieldtype       => 'dropdown',
                    dropdownoptions => $CommonVals->{'DefCodes'}{-1003},
                    dbfield         => 'tblMT_Ac_Coach.intInt6',
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

#Umpire Stuff
#intUmpireActive=> ['Match Official Active ?',{displaytype=>'lookup', fieldtype=>'dropdown', dropdownoptions=>{0=>'No', 1=>'Yes'}, dropdownorder=>[0,1], dbfield=>'tblMT_Umpire.intActive', optiongroup=>'mt_umpire'}],
            ## ADDED BY TC
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
            intDeregisteredUmpire => [
                'Deregistered Match Official',
                {
                    displaytype     => 'lookup',
                    fieldtype       => 'dropdown',
                    dropdownoptions => { 0 => 'No', 1 => 'Yes' },
                    dropdownorder => [ 0, 1 ],
                    dbfield       => 'tblMT_Umpire.intInt2',
                    optiongroup   => 'mt_umpire'
                }
            ],
            intMOCustomDDL_1 => [
                $Data->{'SystemConfig'}{'UMPIRE_intInt6_Custom1'}
                ? "Match Official "
                  . $Data->{'SystemConfig'}{'UMPIRE_intInt6_Custom1'}
                : '',
                {
                    displaytype     => 'lookup',
                    fieldtype       => 'dropdown',
                    dropdownoptions => $CommonVals->{'DefCodes'}{-40},
                    dbfield         => 'tblMT_Umpire.intInt6',
                    optiongroup     => 'mt_umpire'
                }
            ],
            intMOCustomDDL_2 => [
                $Data->{'SystemConfig'}{'UMPIRE_intInt7_Custom2'}
                ? "Match Official "
                  . $Data->{'SystemConfig'}{'UMPIRE_intInt7_Custom2'}
                : '',
                {
                    displaytype     => 'lookup',
                    fieldtype       => 'dropdown',
                    dropdownoptions => $CommonVals->{'DefCodes'}{-41},
                    dbfield         => 'tblMT_Umpire.intInt7',
                    optiongroup     => 'mt_umpire'
                }
            ],
            intMOCustomDDL_3 => [
                $Data->{'SystemConfig'}{'UMPIRE_intInt8_Custom3'}
                ? "Match Official "
                  . $Data->{'SystemConfig'}{'UMPIRE_intInt8_Custom3'}
                : '',
                {
                    displaytype     => 'lookup',
                    fieldtype       => 'dropdown',
                    dropdownoptions => $CommonVals->{'DefCodes'}{-42},
                    dbfield         => 'tblMT_Umpire.intInt8',
                    optiongroup     => 'mt_umpire'
                }
            ],
            intMOCustomDDL_4 => [
                $Data->{'SystemConfig'}{'UMPIRE_intInt9_Custom4'}
                ? "Match Official "
                  . $Data->{'SystemConfig'}{'UMPIRE_intInt9_Custom4'}
                : '',
                {
                    displaytype     => 'lookup',
                    fieldtype       => 'dropdown',
                    dropdownoptions => $CommonVals->{'DefCodes'}{-46},
                    dbfield         => 'tblMT_Umpire.intInt9',
                    optiongroup     => 'mt_umpire'
                }
            ],
            intMOCustomDDL_5 => [
                $Data->{'SystemConfig'}{'UMPIRE_intInt10_Custom5'}
                ? "Match Official "
                  . $Data->{'SystemConfig'}{'UMPIRE_intInt10_Custom5'}
                : '',
                {
                    displaytype     => 'lookup',
                    fieldtype       => 'dropdown',
                    dropdownoptions => $CommonVals->{'DefCodes'}{-47},
                    dbfield         => 'tblMT_Umpire.intInt10',
                    optiongroup     => 'mt_umpire'
                }
            ],

            ##
            strUmpireRegNo => [
                'Match Official Registration Number',
                {
                    displaytype => 'text',
                    fieldtype   => 'text',
                    dbfield     => 'tblMT_Umpire.strString1',
                    optiongroup => 'mt_umpire'
                }
            ],
            strUmpireType => [
                'Match Official Type',
                {
                    displaytype     => 'lookup',
                    fieldtype       => 'dropdown',
                    dropdownoptions => $CommonVals->{'DefCodes'}{-17},
                    dbfield         => 'tblMT_Umpire.intInt1',
                    optiongroup     => 'mt_umpire'
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
                    multiple        => 1,
                    size            => 7,
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
                    multiple        => 1,
                    size            => 7,
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
            strUmpireAccredResult => [
                $NRO{'Accreditation'}
                ? 'Match Official Accred. ' . $FieldLabels->{'Accred.intInt6'}
                  || 'Match Official Accred. Result'
                : '',
                {
                    displaytype     => 'lookup',
                    fieldtype       => 'dropdown',
                    dropdownoptions => $CommonVals->{'DefCodes'}{-1003},
                    dbfield         => 'tblMT_Ac_Umpire.intInt6',
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

              #Official Stuff

              intOfficialAccredActive => [
                $NRO{'Accreditation'} ? " $officialName Accred. Active ?" : '',
                {
                    displaytype     => 'lookup',
                    fieldtype       => 'dropdown',
                    dropdownoptions => { 0 => 'No', 1 => 'Yes' },
                    dropdownorder => [ 0, 1 ],
                    dbfield       => 'tblMT_Official.intActive',
                    optiongroup   => 'mt_official'
                }
              ],
              strOfficialPos => [
                $NRO{'Accreditation'} ? "$officialName Position" : '',
                {
                    displaytype     => 'lookup',
                    fieldtype       => 'dropdown',
                    dropdownoptions => $CommonVals->{'DefCodes'}{-14},
                    dbfield         => 'tblMT_Official.intInt2',
                    optiongroup     => 'mt_official'
                }
              ],
              strOfficialRegNo => [
                $NRO{'Accreditation'} ? $FieldLabels->{'Accred.strString1'}
                  || "$officialName Registration Number" : '',

                #$NRO{'Accreditation'} ? 'Official Registration Number': '',
                {
                    displaytype => 'text',
                    fieldtype   => 'text',
                    dbfield     => 'tblMT_Official.strString1',
                    optiongroup => 'mt_official'
                }
              ],
              dtOfficialStart => [
                $NRO{'Accreditation'} ? "$officialName Start Date" : '',
                {
                    displaytype => 'date',
                    fieldtype   => 'date',
                    dbfield     => 'tblMT_Official.dtDate1',
                    optiongroup => 'mt_official',
                    dbformat =>
                      'DATE_FORMAT(tblMT_Official.dtDate1,"%d/%m/%Y")',
                    dbfield => 'tblMT_Official.dtDate1'
                }
              ],
              dtOfficialEnd => [
                $NRO{'Accreditation'} ? "$officialName End Date" : '',
                {
                    displaytype => 'date',
                    fieldtype   => 'date',
                    dbfield     => 'tblMT_Official.dtDate2',
                    optiongroup => 'mt_official',
                    dbformat =>
                      'DATE_FORMAT(tblMT_Official.dtDate2,"%d/%m/%Y")',
                    dbfield => 'tblMT_Official.dtDate2'
                }
              ],
              dtOfficialAppDate => [
                $NRO{'Accreditation'} ? "$officialName Application Date" : '',
                {
                    displaytype => 'date',
                    fieldtype   => 'date',
                    dbfield     => 'tblMT_Official.dtDate3',
                    optiongroup => 'mt_official',
                    dbformat =>
                      'DATE_FORMAT(tblMT_Official.dtDate3,"%d/%m/%Y")',
                    dbfield => 'tblMT_Official.dtDate3'
                }
              ],

              strOfficialAccredType => [
                $NRO{'Accreditation'}
                ? "$officialName " . $FieldLabels->{'Accred.intInt1'}
                  || "$officialName Accred. Type"
                : '',
                {
                    displaytype     => 'lookup',
                    fieldtype       => 'dropdown',
                    multiple        => 1,
                    size            => 7,
                    dropdownoptions => $CommonVals->{'DefCodes'}{-35},
                    dbfield         => 'tblMT_Official.intInt1',
                    optiongroup     => 'mt_official',

                    #dbfrom => $umpire_dbfrom
                }
              ],
              strOfficialAccredLevel => [
                $NRO{'Accreditation'}
                ? "$officialName " . $FieldLabels->{'Accred.intInt2'}
                  || "$officialName Accred. Level"
                : '',
                {
                    displaytype     => 'lookup',
                    fieldtype       => 'dropdown',
                    multiple        => 1,
                    size            => 7,
                    dropdownoptions => $CommonVals->{'DefCodes'}{-15},
                    dbfield         => 'tblMT_Official.intInt2',
                    optiongroup     => 'mt_official',

                    #dbfrom => $umpire_dbfrom
                }
              ],
              strOfficialAccredProv => [
                $NRO{'Accreditation'}
                ? "$officialName " . $FieldLabels->{'Accred.intInt5'}
                  || "$officialName Accred. Provider"
                : '',
                {
                    displaytype     => 'lookup',
                    fieldtype       => 'dropdown',
                    dropdownoptions => $CommonVals->{'DefCodes'}{-32},
                    dbfield         => 'tblMT_Official.intInt5',
                    optiongroup     => 'mt_official',

                    #dbfrom => $umpire_dbfrom
                }
              ],
              strOfficialAccredResult => [
                $NRO{'Accreditation'}
                ? "$officialName " . $FieldLabels->{'Accred.intInt6'}
                  || "$officialName Accred. Result"
                : '',
                {
                    displaytype     => 'lookup',
                    fieldtype       => 'dropdown',
                    dropdownoptions => $CommonVals->{'DefCodes'}{-1003},
                    dbfield         => 'tblMT_Official.intInt6',
                    optiongroup     => 'mt_official',

                    #dbfrom => $umpire_dbfrom
                }
              ],
              intOfficialReAccreditation => [
                $NRO{'Accreditation'}
                ? "$officialName " . $FieldLabels->{'Accred.intInt7'}
                  || "$officialName Accred. Re Accreditation"
                : '',
                {
                    displaytype     => 'lookup',
                    fieldtype       => 'dropdown',
                    dropdownoptions => { 0 => 'No', 1 => 'Yes' },
                    dropdownorder => [ 0, 1 ],
                    dbfield       => 'tblMT_Official.intInt7',
                    optiongroup   => 'mt_official',

                    #dbfrom => $coach_dbfrom
                }
              ],

              #Misc
              intMiscAccredActive => [
                $NRO{'Accreditation'} ? qq[$txt_MiscName Accred. Active ?] : '',
                {
                    displaytype     => 'lookup',
                    fieldtype       => 'dropdown',
                    dropdownoptions => { 0 => 'No', 1 => 'Yes' },
                    dropdownorder => [ 0, 1 ],
                    dbfield       => 'tblMT_Misc.intActive',
                    optiongroup   => 'mt_misc'
                }
              ],
              strMiscPos => [
                $NRO{'Accreditation'} ? qq[$txt_MiscName Position] : '',
                {
                    displaytype     => 'lookup',
                    fieldtype       => 'dropdown',
                    multiple        => 1,
                    size            => 7,
                    dropdownoptions => $CommonVals->{'DefCodes'}{-16},
                    dbfield         => 'tblMT_Misc.intInt2',
                    optiongroup     => 'mt_misc'
                }
              ],
              strMiscLevel => [
                  $NRO{'Accreditation'}
                ? ( $Data->{'SystemConfig'}{'POS_Level_Label'} )
                      ? qq[$txt_MiscName $Data->{'SystemConfig'}{'POS_Level_Label'}]
                      : qq[$txt_MiscName Level]
                : '',
                  {
                    displaytype     => 'lookup',
                    fieldtype       => 'dropdown',
                    multiple        => 1,
                    size            => 7,
                    dropdownoptions => $CommonVals->{'DefCodes'}{-96},
                    dbfield         => 'tblMT_Misc.intInt4',
                    optiongroup     => 'mt_misc'
                  }
              ],
              strMiscRegNo => [
                  $NRO{'Accreditation'}
                ? $Data->{'SystemConfig'}{'POS_RegNo_Label'}
                      ? $Data->{'SystemConfig'}{'POS_RegNo_Label'}
                      : qq[$txt_MiscName Registration Number]
                : '',
                  {
                    displaytype => 'text',
                    fieldtype   => 'text',
                    dbfield     => 'tblMT_Misc.strString1',
                    optiongroup => 'mt_misc'
                  }
              ],
              strMiscRegNo2 => [
                (
                          $NRO{'Accreditation'}
                      and $Data->{'SystemConfig'}{'POS_RegNo2_Label'}
                )
                ? $Data->{'SystemConfig'}{'POS_RegNo2_Label'}
                : qq[$txt_MiscName Registration Number2],
                {
                    displaytype => 'text',
                    fieldtype   => 'text',
                    dbfield     => 'tblMT_Misc.strString2',
                    optiongroup => 'mt_misc'
                }
              ],
              strMiscAccredType => [
                $NRO{'Accreditation'}
                ? 'Misc Accred. ' . $FieldLabels->{'Accred.intInt1'}
                  || 'Misc Accred. Type'
                : '',
                {
                    displaytype     => 'lookup',
                    fieldtype       => 'dropdown',
                    multiple        => 1,
                    size            => 7,
                    dropdownoptions => $CommonVals->{'DefCodes'}{-35},
                    dbfield         => 'tblMT_Misc.intInt1',
                    optiongroup     => 'mt_misc',
                    dbfrom          => $coach_dbfrom
                }
              ],

              dtMiscStart => [
                $NRO{'Accreditation'} ? qq[$txt_MiscName Start Date] : '',
                {
                    displaytype => 'date',
                    fieldtype   => 'date',
                    dbfield     => 'tblMT_Misc.dtDate1',
                    optiongroup => 'mt_misc',
                    dbformat    => 'DATE_FORMAT(tblMT_Misc.dtDate1,"%d/%m/%Y")',
                    dbfield     => 'tblMT_Misc.dtDate1'
                }
              ],
              dtMiscEnd => [
                $NRO{'Accreditation'} ? qq[$txt_MiscName End Date] : '',
                {
                    displaytype => 'date',
                    fieldtype   => 'date',
                    dbfield     => 'tblMT_Misc.dtDate2',
                    optiongroup => 'mt_misc',
                    dbformat    => 'DATE_FORMAT(tblMT_Misc.dtDate2,"%d/%m/%Y")',
                    dbfield     => 'tblMT_Misc.dtDate2'
                }
              ],
              dtMiscAppDate => [
                $NRO{'Accreditation'} ? 'Application Date' : '',
                {
                    displaytype => 'date',
                    fieldtype   => 'date',
                    dbfield     => 'tblMT_Misc.dtDate3',
                    optiongroup => 'mt_misc',
                    dbformat    => 'DATE_FORMAT(tblMT_Misc.dtDate3,"%d/%m/%Y")',
                    dbfield     => 'tblMT_Misc.dtDate3'
                }
              ],

              #Seasons
              intSeasonID => [
                "$txt_SeasonName",
                {
                    displaytype     => 'lookup',
                    fieldtype       => 'dropdown',
                    dropdownoptions => $CommonVals->{'Seasons'}{'Options'},
                    dropdownorder   => $CommonVals->{'Seasons'}{'Order'},
                    allowsort       => 1,
                    optiongroup     => 'seasons',
                    active          => 0,
                    multiple        => 1,
                    size            => 3,
                    dbfield         => "$MStablename.intSeasonID",
                    disable         => $hideSeasons
                }
              ],
              intSeasonMemberPackageID => [
                "$txt_SeasonName Member Package",
                {
                    displaytype     => 'lookup',
                    fieldtype       => 'dropdown',
                    dropdownoptions => $CommonVals->{'MemberPackages'},
                    optiongroup     => 'seasons',
                    allowgrouping   => 1,
                    multiple        => 1,
                    disable         => $hideSeasons
                }
              ],
              intPlayerAgeGroupID => [
                "$txt_AgeGroupName",
                {
                    displaytype     => 'lookup',
                    fieldtype       => 'dropdown',
                    dropdownoptions => $CommonVals->{'AgeGroups'}{'Options'},
                    dropdownorder   => $CommonVals->{'AgeGroups'}{'Order'},
                    allowsort       => 1,
                    allowgrouping   => 1,
                    optiongroup     => 'seasons',
                    multiple        => 1,
                    size            => 3,
                    dbfield         => "$MStablename.intPlayerAgeGroupID",
                    disable         => ( $hideSeasons or $enable_record_types ),
                }
              ],
              intPlayerStatus => [
                "$txt_SeasonName Player ?",
                {
                    displaytype     => 'lookup',
                    fieldtype       => 'dropdown',
                    dropdownoptions => { 0 => 'No', 1 => 'Yes' },
                    dropdownorder => [ 0, 1 ],
                    optiongroup   => 'seasons',
                    allowgrouping => 1,
                    disable       => $hideSeasons
                }
              ],
              intCoachStatus => [
                "$txt_SeasonName Coach",
                {
                    displaytype     => 'lookup',
                    fieldtype       => 'dropdown',
                    dropdownoptions => { 0 => 'No', 1 => 'Yes' },
                    dropdownorder => [ 0, 1 ],
                    optiongroup   => 'seasons',
                    allowgrouping => 1,
                    disable       => $hideSeasons
                }
              ],
              intUmpireStatus => [
                "$txt_SeasonName Match Official",
                {
                    displaytype     => 'lookup',
                    fieldtype       => 'dropdown',
                    dropdownoptions => { 0 => 'No', 1 => 'Yes' },
                    dropdownorder => [ 0, 1 ],
                    optiongroup   => 'seasons',
                    allowgrouping => 1,
                    disable       => $hideSeasons
                }
              ],
              intOther1Status => [
                $Data->{'SystemConfig'}{'Seasons_Other1'}
                ? "$txt_SeasonName $Data->{'SystemConfig'}{'Seasons_Other1'} ?"
                : '',
                {
                    displaytype     => 'lookup',
                    fieldtype       => 'dropdown',
                    dropdownoptions => { 0 => 'No', 1 => 'Yes' },
                    dropdownorder => [ 0, 1 ],
                    optiongroup   => 'seasons',
                    allowgrouping => 1,
                    disable       => $hideSeasons
                }
              ],
              intOther2Status => [
                $Data->{'SystemConfig'}{'Seasons_Other2'}
                ? "$txt_SeasonName $Data->{'SystemConfig'}{'Seasons_Other2'} ?"
                : '',
                {
                    displaytype     => 'lookup',
                    fieldtype       => 'dropdown',
                    dropdownoptions => { 0 => 'No', 1 => 'Yes' },
                    dropdownorder => [ 0, 1 ],
                    optiongroup   => 'seasons',
                    allowgrouping => 1,
                    disable       => $hideSeasons
                }
              ],
              intPlayerFinancialStatus => [
                "$txt_SeasonName Player Financial ?",
                {
                    displaytype     => 'lookup',
                    fieldtype       => 'dropdown',
                    dropdownoptions => { 0 => 'No', 1 => 'Yes' },
                    dropdownorder => [ 0, 1 ],
                    optiongroup   => 'seasons',
                    allowgrouping => 1,
                    disable       => $hideSeasons
                }
              ],
              intCoachFinancialStatus => [
                "$txt_SeasonName Coach Financial ?",
                {
                    displaytype     => 'lookup',
                    fieldtype       => 'dropdown',
                    dropdownoptions => { 0 => 'No', 1 => 'Yes' },
                    dropdownorder => [ 0, 1 ],
                    optiongroup   => 'seasons',
                    allowgrouping => 1,
                    disable       => $hideSeasons
                }
              ],
              intUmpireFinancialStatus => [
                "$txt_SeasonName Match Official Financial ?",
                {
                    displaytype     => 'lookup',
                    fieldtype       => 'dropdown',
                    dropdownoptions => { 0 => 'No', 1 => 'Yes' },
                    dropdownorder => [ 0, 1 ],
                    optiongroup   => 'seasons',
                    allowgrouping => 1,
                    disable       => $hideSeasons
                }
              ],
              intOther1FinancialStatus => [
                $Data->{'SystemConfig'}{'Seasons_Other1'}
                ? "$txt_SeasonName $Data->{'SystemConfig'}{'Seasons_Other1'} Financial ?"
                : '',
                {
                    displaytype     => 'lookup',
                    fieldtype       => 'dropdown',
                    dropdownoptions => { 0 => 'No', 1 => 'Yes' },
                    dropdownorder => [ 0, 1 ],
                    optiongroup   => 'seasons',
                    allowgrouping => 1,
                    disable       => $hideSeasons
                }
              ],
              intOther2FinancialStatus => [
                $Data->{'SystemConfig'}{'Seasons_Other2'}
                ? "$txt_SeasonName $Data->{'SystemConfig'}{'Seasons_Other2'} Financial ?"
                : '',
                {
                    displaytype     => 'lookup',
                    fieldtype       => 'dropdown',
                    dropdownoptions => { 0 => 'No', 1 => 'Yes' },
                    dropdownorder => [ 0, 1 ],
                    optiongroup   => 'seasons',
                    allowgrouping => 1,
                    disable       => $hideSeasons
                }
              ],
              dtInPlayer => [
                "Date Player created in $txt_SeasonName",
                {
                    displaytype => 'date',
                    fieldtype   => 'date',
                    optiongroup => 'seasons',
                    dbformat    => 'DATE_FORMAT(dtInPlayer,"%d/%m/%Y")',
                    dbfield     => 'dtInPlayer',
                    disable     => $hideSeasons
                }
              ],
              dtInCoach => [
                "Date Coach created in $txt_SeasonName",
                {
                    displaytype => 'date',
                    fieldtype   => 'date',
                    optiongroup => 'seasons',
                    dbformat    => 'DATE_FORMAT(dtInCoach,"%d/%m/%Y")',
                    dbfield     => 'dtInCoach',
                    disable     => $hideSeasons
                }
              ],
              dtInUmpire => [
                "Date Umpire created in $txt_SeasonName",
                {
                    displaytype => 'date',
                    fieldtype   => 'date',
                    optiongroup => 'seasons',
                    dbformat    => 'DATE_FORMAT(dtInUmpire,"%d/%m/%Y")',
                    dbfield     => 'dtInUmpire',
                    disable     => $hideSeasons
                }
              ],
              dtLastUsedRegoForm => [
                "Date RegoForm last used in $txt_SeasonName",
                {
                    displaytype => 'date',
                    fieldtype   => 'date',
                    optiongroup => 'seasons',
                    dbformat    => 'DATE_FORMAT('
                      . $MStablename
                      . '.dtLastUsedRegoForm,"%d/%m/%Y")',
                    dbfield => "$MStablename.dtLastUsedRegoForm",
                    disable => $hideSeasons,
                }
              ],
              intUsedRegoFormID => [
                "RegoForm used in $txt_SeasonName",
                {
                    displaytype     => 'lookup',
                    fieldtype       => 'dropdown',
                    dropdownoptions => $CommonVals->{'RegoForms'}{'Options'},
                    dropdownorder   => $CommonVals->{'RegoForms'}{'Order'},
                    allowsort       => 1,
                    multiple        => 1,
                    allowgrouping   => 1,
                    optiongroup     => 'seasons',
                    dbfield         => "$MStablename.intUsedRegoFormID",
                    disable         => $hideSeasons,
                }
              ],
              dtInOther1 => [
                $Data->{'SystemConfig'}{'Seasons_Other1'}
                ? "Date $Data->{'SystemConfig'}{'Seasons_Other1'} created in $txt_SeasonName"
                : '',
                {
                    displaytype => 'date',
                    fieldtype   => 'date',
                    optiongroup => 'seasons',
                    dbformat    => 'DATE_FORMAT(dtInOther1,"%d/%m/%Y")',
                    dbfield     => 'dtInOther1',
                    disable     => $hideSeasons
                }
              ],
              dtInOther2 => [
                $Data->{'SystemConfig'}{'Seasons_Other2'}
                ? "Date $Data->{'SystemConfig'}{'Seasons_Other2'} created in $txt_SeasonName"
                : '',
                {
                    displaytype => 'date',
                    fieldtype   => 'date',
                    optiongroup => 'seasons',
                    dbformat    => 'DATE_FORMAT(dtInOther2,"%d/%m/%Y")',
                    dbfield     => 'dtInOther2',
                    disable     => $hideSeasons
                }
              ],

              #Affilitations

              strAssocName => [
                (
                    $clientValues->{assocID} != -1
                    ? ''
                    : $Data->{'LevelNames'}{$Defs::LEVEL_ASSOC} . ' Name'
                ),
                {
                    displaytype   => 'text',
                    fieldtype     => 'text',
                    allowsort     => 1,
                    dbfield       => 'tblAssoc.strName',
                    optiongroup   => 'affiliations',
                    allowgrouping => 1,
                    dbwhere => $enable_record_types?
                      " AND $MStablename.intEntityID = tblAssoc.intAssocID AND $MStablename.intEntityTypeID = $Defs::LEVEL_ASSOC":
                      " AND $MStablename.intAssocID = tblAssoc.intAssocID"
                }
              ],
            intExcludeFromNationalRego => [
                (
                    $currentLevel >= $Defs::LEVEL_NATIONAL and  $SystemConfig->{'AllowOnlineRego_node'}
                    ? $Data->{'LevelNames'}{$Defs::LEVEL_ASSOC} . ' excluded from National Registration'
                    : ''
                ),
                {
                    displaytype   => 'text',
                    fieldtype     => 'text',
                    allowsort     => 1,
                    dbfield       => 'tblAssoc.intExcludeFromNationalRego',
                    optiongroup   => 'affiliations',
                    allowgrouping => 1,
                    dbwhere => $enable_record_types?
                      " AND $MStablename.intEntityID = tblAssoc.intAssocID AND $MStablename.intEntityTypeID = $Defs::LEVEL_ASSOC":
                      " AND $MStablename.intAssocID = tblAssoc.intAssocID"
                }
              ],

              intAssocTypeID => [
                (
                    (
                              $CommonVals->{'SubRealms'}
                          and $currentLevel > $Defs::LEVEL_ASSOC
                    )
                    ? ( $Data->{'LevelNames'}{$Defs::LEVEL_ASSOC} . ' Type' )
                    : ''
                ),
                {
                    displaytype     => 'lookup',
                    fieldtype       => 'dropdown',
                    dropdownoptions => $CommonVals->{'SubRealms'},
                    allowsort       => 1,
                    optiongroup     => 'affiliations',
                    allowgrouping   => 1
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
                    optiongroup   => 'affiliations'
                }
              ],

              strTeamName => [
                  $SystemConfig->{'NoTeams'} ? ''
                : $Data->{'LevelNames'}{$Defs::LEVEL_TEAM} . ' Name',
                {
                    displaytype => 'text',
                    fieldtype   => 'text',
                    allowsort   => 1,
                    dbfield     => "tblTeam.strName",
                    dbfrom      => [
                        (
                            $currentLevel > $Defs::LEVEL_CLUB
                            ? "LEFT JOIN tblMember_Teams ON (tblMember.intMemberID=tblMember_Teams.intMemberID AND tblMember_Teams.intStatus = $Defs::RECSTATUS_ACTIVE) LEFT JOIN tblTeam ON (tblTeam.intTeamID=tblMember_Teams.intTeamID AND tblTeam.intAssocID=tblAssoc.intAssocID)"
                            : ''
                        ),
                        (
                            $currentLevel == $Defs::LEVEL_CLUB
                            ? "LEFT JOIN tblMember_Teams ON (tblMember.intMemberID=tblMember_Teams.intMemberID AND tblMember_Teams.intStatus = $Defs::RECSTATUS_ACTIVE) LEFT JOIN tblTeam ON (tblTeam.intTeamID=tblMember_Teams.intTeamID AND tblTeam.intClubID=tblClub.intClubID)"
                            : ''
                        ),
'LEFT JOIN tblComp_Teams ON (tblComp_Teams.intTeamID=tblTeam.intTeamID AND tblComp_Teams.intRecStatus = 1) LEFT JOIN tblAssoc_Comp ON (tblAssoc_Comp.intCompID=tblComp_Teams.intCompID AND tblAssoc_Comp.intAssocID=tblAssoc.intAssocID AND tblMember_Teams.intCompID=tblAssoc_Comp.intCompID)'
                    ],
                    optiongroup   => 'affiliations',
                    allowgrouping => 1
                }
              ],
              strTeamNumber => [
                ($SystemConfig->{'NoTeams'} or $currentLevel != $Defs::LEVEL_TEAM) ? '' : $Data->{'LevelNames'}{$Defs::LEVEL_TEAM} . ' Default Number',
                {
                    displaytype => 'text',
                    fieldtype   => 'text',
                    allowsort   => 1,
                    dbfield => "tblCompMatchSelectedPlayerNumbers.strJumperNum",
                    dbfrom =>
"LEFT JOIN tblCompMatchSelectedPlayerNumbers ON (tblCompMatchSelectedPlayerNumbers.intTeamID=tblMember_Teams.intTeamID AND tblCompMatchSelectedPlayerNumbers.intMemberID=tblMember_Teams.intMemberID AND tblCompMatchSelectedPlayerNumbers.intMatchID=-1)",
                    optiongroup   => 'otherfields',
                    allowgrouping => 1
                }
              ],
              strClubNumber => [
                (
                    (
                        (
                                !$SystemConfig->{'NoClubs'}
                              or $Data->{'Permissions'}
                              {$Defs::CONFIG_OTHEROPTIONS}{'ShowClubs'}
                        )
                          and $currentLevel == $Defs::LEVEL_CLUB
                    )
                    ? $Data->{'LevelNames'}{$Defs::LEVEL_CLUB}
                      . ' Default Number'
                    : ''
                ),
                {
                    displaytype => 'text',
                    fieldtype   => 'text',
                    allowsort   => 1,
                    dbfield     => "CMSPN.strJumperNum",
                    dbfrom =>
" LEFT JOIN tblCompMatchSelectedPlayerNumbers CMSPN ON (CMSPN.intClubID=tblMember_Clubs.intClubID and CMSPN.intMemberID=tblMember_Clubs.intMemberID and CMSPN.intMatchID=-1 AND (CMSPN.intTeamID=-1 or CMSPN.intTeamID=0))",
                    optiongroup   => 'otherfields',
                    allowgrouping => 1,
                }
              ],

              strClubName => [
                (
                    (
                        (
                                !$SystemConfig->{'NoClubs'}
                              or $Data->{'Permissions'}
                              {$Defs::CONFIG_OTHEROPTIONS}{'ShowClubs'}
                        )
                          and $currentLevel > $Defs::LEVEL_CLUB
                    ) ? $Data->{'LevelNames'}{$Defs::LEVEL_CLUB} . ' Name' : ''
                ),
                {
                    displaytype => 'text',
                    fieldtype   => 'text',
                    allowsort   => 1,
                    dbfield     => "C.strName",
                    dbfrom =>
"LEFT JOIN tblMember_Clubs ON (tblMember.intMemberID=tblMember_Clubs.intMemberID  AND tblMember_Clubs.intStatus=$Defs::RECSTATUS_ACTIVE) LEFT JOIN tblClub as C ON (C.intClubID=tblMember_Clubs.intClubID ) LEFT JOIN tblAssoc_Clubs as AC ON (AC.intAssocID=tblAssoc.intAssocID AND AC.intClubID=C.intClubID)",
                    optiongroup   => 'affiliations',
                    allowgrouping => 1,
                    dbwhere => $enable_record_types?
" AND (AC.intAssocID = tblAssoc.intAssocID OR tblMember_Clubs.intMemberID IS NULL) AND (($MStablename.intEntityID=C.intClubID AND $MStablename.intEntityTypeID= $Defs::LEVEL_CLUB) or tblMember_Clubs.intMemberID IS NULL)":
" AND (AC.intAssocID = tblAssoc.intAssocID OR tblMember_Clubs.intMemberID IS NULL) AND (($MStablename.intClubID=C.intClubID AND $MStablename.intMSRecStatus = 1) or tblMember_Clubs.intMemberID IS NULL)"
                }
              ],
              intClubCategoryID => [
                (
                    (
                        (
                                !$SystemConfig->{'NoClubs'}
                              or $Data->{'Permissions'}
                              {$Defs::CONFIG_OTHEROPTIONS}{'ShowClubs'}
                        )
                          and $currentLevel > $Defs::LEVEL_CLUB
                          and scalar(
                            keys %{
                                $CommonVals->{'EntityCategories'}
                                  {$Defs::LEVEL_CLUB}
                            }
                          )
                    )
                    ? $Data->{'LevelNames'}{$Defs::LEVEL_CLUB} . ' Category'
                    : ''
                ),
                {
                    displaytype => 'lookup',
                    fieldtype   => 'dropdown',
                    dropdownoptions =>
                      $CommonVals->{'EntityCategories'}{$Defs::LEVEL_CLUB},
                    allowsort => 1,
                    dbfield   => "C.intClubCategoryID",
                    dbfrom =>
"LEFT JOIN tblMember_Clubs ON (tblMember.intMemberID=tblMember_Clubs.intMemberID  AND tblMember_Clubs.intStatus=$Defs::RECSTATUS_ACTIVE) LEFT JOIN tblClub as C ON (C.intClubID=tblMember_Clubs.intClubID ) LEFT JOIN tblAssoc_Clubs as AC ON (AC.intAssocID=tblAssoc.intAssocID AND AC.intClubID=C.intClubID)",
                    optiongroup   => 'affiliations',
                    allowgrouping => 1,
                    dbwhere => $enable_record_types?
" AND (AC.intAssocID = tblAssoc.intAssocID OR tblMember_Clubs.intMemberID IS NULL) AND (($MStablename.intEntityID=C.intClubID AND $MStablename.intEntityTypeID= $Defs::LEVEL_CLUB) or tblMember_Clubs.intMemberID IS NULL)":
" AND (AC.intAssocID = tblAssoc.intAssocID OR tblMember_Clubs.intMemberID IS NULL) AND (($MStablename.intClubID=C.intClubID AND $MStablename.intMSRecStatus = 1) or tblMember_Clubs.intMemberID IS NULL)"
                }
              ],

              intPermit => [
                (
                    (
                             !$SystemConfig->{'NoClubs'}
                          and $currentLevel > $Defs::LEVEL_CLUB
                          and $Data->{SystemConfig}->{AllowSWOL}
                    )
                    ? ( 'On Permit to '
                          . $Data->{'LevelNames'}{$Defs::LEVEL_CLUB} )
                    : ''
                ),
                {
                    displaytype     => 'lookup',
                    fieldtype       => 'dropdown',
                    dropdownoptions => { 0 => 'No', 1 => 'Yes' },
                    dropdownorder => [ 0, 1 ],
                    allowsort     => 1,
                    dbfield       => "tblMember_Clubs.intPermit",
                    dbfrom =>
"LEFT JOIN tblMember_Clubs ON (tblMember.intMemberID=tblMember_Clubs.intMemberID  AND tblMember_Clubs.intStatus=$Defs::RECSTATUS_ACTIVE) LEFT JOIN tblClub as C ON (C.intClubID=tblMember_Clubs.intClubID ) LEFT JOIN tblAssoc_Clubs as AC ON (AC.intAssocID=tblAssoc.intAssocID AND AC.intClubID=C.intClubID)",
                    optiongroup   => 'affiliations',
                    allowgrouping => 1
                }
              ],

              intPermitClub => [
                (
                    (
                             !$SystemConfig->{'NoClubs'}
                          and $currentLevel == $Defs::LEVEL_CLUB
                          and $Data->{SystemConfig}->{AllowSWOL}
                    )
                    ? ( 'On Permit to '
                          . $Data->{'LevelNames'}{$Defs::LEVEL_CLUB} )
                    : ''
                ),
                {
                    displaytype     => 'lookup',
                    fieldtype       => 'dropdown',
                    dropdownoptions => { 0 => 'No', 1 => 'Yes' },
                    dropdownorder => [ 0, 1 ],
                    allowsort     => 1,
                    dbfield       => "tblMember_Clubs.intPermit",
                    optiongroup   => 'affiliations',
                    allowgrouping => 1
                }
              ],
              LastPlayedDate => [
                (
                    $Data->{SystemConfig}->{AllowSWOL} ? 'Date Last Played'
                    : ''
                ),
                {
                    displaytype => 'text',
                    dbfield     => "$player_comp_stats_table.dtStatTotal2",
                    dbformat =>
qq[DATE_FORMAT($player_comp_stats_table.dtStatTotal2,"%d/%m/%Y")],
                    dbfrom => [
                        (
                            $currentLevel == $Defs::LEVEL_CLUB
                            ? "LEFT JOIN tblMember_Teams ON (tblMember.intMemberID=tblMember_Teams.intMemberID AND tblMember_Teams.intStatus = $Defs::RECSTATUS_ACTIVE) LEFT JOIN tblTeam ON (tblTeam.intTeamID=tblMember_Teams.intTeamID AND tblTeam.intClubID=tblClub.intClubID)"
                            : ''
                        ),
                        (
                            $currentLevel > $Defs::LEVEL_CLUB
                            ? "LEFT JOIN tblMember_Teams ON (tblMember.intMemberID=tblMember_Teams.intMemberID AND tblMember_Teams.intStatus = $Defs::RECSTATUS_ACTIVE) LEFT JOIN tblTeam ON (tblTeam.intTeamID=tblMember_Teams.intTeamID AND tblTeam.intAssocID=tblAssoc.intAssocID)"
                            : ''
                        ),
"INNER JOIN $player_comp_stats_table ON ($player_comp_stats_table.intPlayerID = tblMember_Teams.intMemberID AND $player_comp_stats_table.intCompID = tblMember_Teams.intCompID AND $player_comp_stats_table.intTeamID  = tblMember_Teams.intTeamID) INNER JOIN tblComp_Teams AS LadderCompTeams ON (LadderCompTeams.intTeamID = $player_comp_stats_table.intTeamID AND LadderCompTeams.intCompID = $player_comp_stats_table.intCompID AND LadderCompTeams.intRecStatus <> $Defs::RECSTATUS_DELETED) INNER JOIN tblAssoc_Comp AS LadderAssocComp ON (LadderAssocComp.intCompID=$player_comp_stats_table.intCompID AND LadderAssocComp.intAssocID=tblAssoc.intAssocID)"
                    ],
                    fieldtype   => 'date',
                    allowsort   => 1,
                    optiongroup => 'affiliations'
                }
              ],

              MCStatus => [
                (
                    (
                             !$SystemConfig->{'NoClubs'}
                          and $currentLevel <= $Defs::LEVEL_ASSOC
                    )
                    ? ( 'Active in '
                          . $Data->{'LevelNames'}{$Defs::LEVEL_CLUB} )
                    : ''
                ),
                {
                    dbfrom =>
"LEFT JOIN tblMember_Clubs MC ON (tblMember.intMemberID=MC.intMemberID)  LEFT JOIN tblClub as C ON (C.intClubID=MC.intClubID ) LEFT JOIN tblAssoc_Clubs as AC ON (AC.intAssocID=tblAssoc.intAssocID AND AC.intClubID=C.intClubID)",
                    displaytype     => 'lookup',
                    fieldtype       => 'dropdown',
                    dropdownoptions => { 0 => 'No', 1 => 'Yes' },
                    dropdownorder => [ 0, 1 ],
                    allowsort     => 1,
                    dbfield       => "MC.intStatus",
                    optiongroup   => 'affiliations',
                    allowgrouping => 1
                }
              ],

              strCompName => [
                (
                     !$SystemConfig->{'NoComps'}
                    ? $Data->{'LevelNames'}{$Defs::LEVEL_COMP} . ' Name'
                    : ''
                ),
                {
                    displaytype => 'text',
                    fieldtype   => 'text',
                    allowsort   => 1,
                    dbfield     => "tblAssoc_Comp.strTitle",
                    dbfrom      => [
                        (
                            $currentLevel == $Defs::LEVEL_CLUB
                            ? "LEFT JOIN tblMember_Teams ON (tblMember.intMemberID=tblMember_Teams.intMemberID AND tblMember_Teams.intStatus = $Defs::RECSTATUS_ACTIVE) LEFT JOIN tblTeam ON (tblTeam.intTeamID=tblMember_Teams.intTeamID AND tblTeam.intClubID=tblClub.intClubID)"
                            : ''
                        ),
                        (
                            $currentLevel > $Defs::LEVEL_CLUB
                            ? "LEFT JOIN tblMember_Teams ON (tblMember.intMemberID=tblMember_Teams.intMemberID AND tblMember_Teams.intStatus = $Defs::RECSTATUS_ACTIVE) LEFT JOIN tblTeam ON (tblTeam.intTeamID=tblMember_Teams.intTeamID AND tblTeam.intAssocID=tblAssoc.intAssocID)"
                            : ''
                        ),
'LEFT JOIN tblComp_Teams ON (tblComp_Teams.intTeamID=tblTeam.intTeamID AND tblComp_Teams.intRecStatus = 1) LEFT JOIN tblAssoc_Comp ON (tblAssoc_Comp.intCompID=tblComp_Teams.intCompID AND tblAssoc_Comp.intAssocID=tblAssoc.intAssocID AND tblMember_Teams.intCompID=tblAssoc_Comp.intCompID)'
                    ],
                    optiongroup   => 'affiliations',
                    allowgrouping => 1
                }
              ],

              intCompLevelID => [
                (
                    ( !$SystemConfig->{'NoComps'} and $NRO{'RepCompLevel'} )
                    ? 'Competition Level'
                    : ''
                ),
                {
                    displaytype     => 'lookup',
                    fieldtype       => 'dropdown',
                    dropdownoptions => $CommonVals->{'DefCodes'}{-21},
                    dbfield         => 'tblAssoc_Comp.intCompLevelID',
                    dbfrom          => [
                        (
                            $currentLevel == $Defs::LEVEL_CLUB
                            ? "LEFT JOIN tblMember_Teams ON (tblMember.intMemberID=tblMember_Teams.intMemberID AND tblMember_Teams.intStatus = $Defs::RECSTATUS_ACTIVE) LEFT JOIN tblTeam ON (tblTeam.intTeamID=tblMember_Teams.intTeamID AND tblTeam.intClubID=tblClub.intClubID)"
                            : ''
                        ),
                        (
                            $currentLevel > $Defs::LEVEL_CLUB
                            ? "LEFT JOIN tblMember_Teams ON (tblMember.intMemberID=tblMember_Teams.intMemberID AND tblMember_Teams.intStatus = $Defs::RECSTATUS_ACTIVE) LEFT JOIN tblTeam ON (tblTeam.intTeamID=tblMember_Teams.intTeamID AND tblTeam.intAssocID=tblAssoc.intAssocID)"
                            : ''
                        ),
'LEFT JOIN tblComp_Teams ON (tblComp_Teams.intTeamID=tblTeam.intTeamID AND tblComp_Teams.intRecStatus = 1) LEFT JOIN tblAssoc_Comp ON (tblAssoc_Comp.intCompID=tblComp_Teams.intCompID AND tblAssoc_Comp.intAssocID=tblAssoc.intAssocID AND tblMember_Teams.intCompID=tblAssoc_Comp.intCompID)'
                    ],
                    optiongroup   => 'affiliations',
                    allowgrouping => 1
                }
              ],
              CompAgeGroupID => [
                (
                    ( !$SystemConfig->{'NoComps'} )
                    ? "$Data->{'LevelNames'}{$Defs::LEVEL_COMP} Default $txt_AgeGroupName"
                    : ''
                ),
                {
                    displaytype     => 'lookup',
                    fieldtype       => 'dropdown',
                    dropdownoptions => $CommonVals->{'AgeGroups'}{'Options'},
                    dropdownorder   => $CommonVals->{'AgeGroups'}{'Order'},
                    dbfield         => 'tblAssoc_Comp.intAgeGroupID',
                    dbfrom          => [
                        (
                            $currentLevel == $Defs::LEVEL_CLUB
                            ? "LEFT JOIN tblMember_Teams ON (tblMember.intMemberID=tblMember_Teams.intMemberID AND tblMember_Teams.intStatus = $Defs::RECSTATUS_ACTIVE) LEFT JOIN tblTeam ON (tblTeam.intTeamID=tblMember_Teams.intTeamID AND tblTeam.intClubID=tblClub.intClubID)"
                            : ''
                        ),
                        (
                            $currentLevel > $Defs::LEVEL_CLUB
                            ? "LEFT JOIN tblMember_Teams ON (tblMember.intMemberID=tblMember_Teams.intMemberID AND tblMember_Teams.intStatus = $Defs::RECSTATUS_ACTIVE) LEFT JOIN tblTeam ON (tblTeam.intTeamID=tblMember_Teams.intTeamID AND tblTeam.intAssocID=tblAssoc.intAssocID)"
                            : ''
                        ),
'LEFT JOIN tblComp_Teams ON (tblComp_Teams.intTeamID=tblTeam.intTeamID AND tblComp_Teams.intRecStatus = 1) LEFT JOIN tblAssoc_Comp ON (tblAssoc_Comp.intCompID=tblComp_Teams.intCompID AND tblAssoc_Comp.intAssocID=tblAssoc.intAssocID AND tblMember_Teams.intCompID=tblAssoc_Comp.intCompID)'
                    ],
                    optiongroup   => 'affiliations',
                    allowgrouping => 1
                }
              ],

              intNewSeasonID => [
                (
                    !$SystemConfig->{'NoComps'}
                    ? "$Data->{'LevelNames'}{$Defs::LEVEL_COMP} $txt_SeasonName"
                    : ''
                ),
                {
                    displaytype     => 'lookup',
                    fieldtype       => 'dropdown',
                    dropdownoptions => $CommonVals->{'Seasons'}{'Options'},
                    dropdownorder   => $CommonVals->{'Seasons'}{'Order'},
                    dbfield         => 'tblAssoc_Comp.intNewSeasonID',
                    dbfrom          => [
                        (
                            $currentLevel == $Defs::LEVEL_CLUB
                            ? "LEFT JOIN tblMember_Teams ON (tblMember.intMemberID=tblMember_Teams.intMemberID AND tblMember_Teams.intStatus = $Defs::RECSTATUS_ACTIVE) LEFT JOIN tblTeam ON (tblTeam.intTeamID=tblMember_Teams.intTeamID AND tblTeam.intClubID=tblClub.intClubID)"
                            : ''
                        ),
                        (
                            $currentLevel > $Defs::LEVEL_CLUB
                            ? "LEFT JOIN tblMember_Teams ON (tblMember.intMemberID=tblMember_Teams.intMemberID AND tblMember_Teams.intStatus = $Defs::RECSTATUS_ACTIVE) LEFT JOIN tblTeam ON (tblTeam.intTeamID=tblMember_Teams.intTeamID AND tblTeam.intAssocID=tblAssoc.intAssocID)"
                            : ''
                        ),
'LEFT JOIN tblComp_Teams ON (tblComp_Teams.intTeamID=tblTeam.intTeamID AND tblComp_Teams.intRecStatus = 1) LEFT JOIN tblAssoc_Comp ON (tblAssoc_Comp.intCompID=tblComp_Teams.intCompID AND tblAssoc_Comp.intAssocID=tblAssoc.intAssocID AND tblMember_Teams.intCompID=tblAssoc_Comp.intCompID)'
                    ],
                    optiongroup   => 'affiliations',
                    allowgrouping => 1,
                    disable       => $hideSeasons
                }
              ],

              intCompTypeID => [
                ( ( !$SystemConfig->{'NoComps'} ) ? 'Competition Type' : '' ),
                {
                    displaytype     => 'lookup',
                    fieldtype       => 'dropdown',
                    dropdownoptions => $CommonVals->{'DefCodes'}{-36},
                    dbfield         => 'tblAssoc_Comp.intCompTypeID',
                    dbfrom          => [
                        (
                            $currentLevel == $Defs::LEVEL_CLUB
                            ? "LEFT JOIN tblMember_Teams ON (tblMember.intMemberID=tblMember_Teams.intMemberID AND tblMember_Teams.intStatus = $Defs::RECSTATUS_ACTIVE) LEFT JOIN tblTeam ON (tblTeam.intTeamID=tblMember_Teams.intTeamID AND tblTeam.intClubID=tblClub.intClubID)"
                            : ''
                        ),
                        (
                            $currentLevel > $Defs::LEVEL_CLUB
                            ? "LEFT JOIN tblMember_Teams ON (tblMember.intMemberID=tblMember_Teams.intMemberID AND tblMember_Teams.intStatus = $Defs::RECSTATUS_ACTIVE) LEFT JOIN tblTeam ON (tblTeam.intTeamID=tblMember_Teams.intTeamID AND tblTeam.intAssocID=tblAssoc.intAssocID)"
                            : ''
                        ),
'LEFT JOIN tblComp_Teams ON (tblComp_Teams.intTeamID=tblTeam.intTeamID AND tblComp_Teams.intRecStatus = 1) LEFT JOIN tblAssoc_Comp ON (tblAssoc_Comp.intCompID=tblComp_Teams.intCompID AND tblAssoc_Comp.intAssocID=tblAssoc.intAssocID AND tblMember_Teams.intCompID=tblAssoc_Comp.intCompID)'
                    ],
                    optiongroup   => 'affiliations',
                    allowgrouping => 1
                }
              ],

              CompGradeID => [
                ( ( !$SystemConfig->{'NoComps'} ) ? 'Competition Grade' : '' ),
                {
                    displaytype     => 'lookup',
                    fieldtype       => 'dropdown',
                    dbfield         => 'tblAssoc_Comp.intGradeID',
                    dropdownoptions => $CommonVals->{'Grades'},
                    dbfield         => 'tblAssoc_Comp.intCompGradeID',
                    dbfrom          => [
                        (
                            $currentLevel == $Defs::LEVEL_CLUB
                            ? "LEFT JOIN tblMember_Teams ON (tblMember.intMemberID=tblMember_Teams.intMemberID AND tblMember_Teams.intStatus = $Defs::RECSTATUS_ACTIVE) LEFT JOIN tblTeam ON (tblTeam.intTeamID=tblMember_Teams.intTeamID AND tblTeam.intClubID=tblClub.intClubID)"
                            : ''
                        ),
                        (
                            $currentLevel > $Defs::LEVEL_CLUB
                            ? "LEFT JOIN tblMember_Teams ON (tblMember.intMemberID=tblMember_Teams.intMemberID AND tblMember_Teams.intStatus = $Defs::RECSTATUS_ACTIVE) LEFT JOIN tblTeam ON (tblTeam.intTeamID=tblMember_Teams.intTeamID AND tblTeam.intAssocID=tblAssoc.intAssocID)"
                            : ''
                        ),
'LEFT JOIN tblComp_Teams ON (tblComp_Teams.intTeamID=tblTeam.intTeamID AND tblComp_Teams.intRecStatus = 1) LEFT JOIN tblAssoc_Comp ON (tblAssoc_Comp.intCompID=tblComp_Teams.intCompID AND tblAssoc_Comp.intAssocID=tblAssoc.intAssocID AND tblMember_Teams.intCompID=tblAssoc_Comp.intCompID)'
                    ],
                    optiongroup   => 'affiliations',
                    allowgrouping => 1
                }
              ],

              intCompGender => [
                ( ( !$SystemConfig->{'NoComps'} ) ? 'Competition Gender' : '' ),
                {
                    displaytype     => 'lookup',
                    fieldtype       => 'dropdown',
                    dropdownoptions => \%Defs::genderInfo,
                    dbfield         => 'tblAssoc_Comp.intCompGender',
                    dbfrom          => [
                        (
                            $currentLevel == $Defs::LEVEL_CLUB
                            ? "LEFT JOIN tblMember_Teams ON (tblMember.intMemberID=tblMember_Teams.intMemberID AND tblMember_Teams.intStatus = $Defs::RECSTATUS_ACTIVE) LEFT JOIN tblTeam ON (tblTeam.intTeamID=tblMember_Teams.intTeamID AND tblTeam.intClubID=tblClub.intClubID)"
                            : ''
                        ),
                        (
                            $currentLevel > $Defs::LEVEL_CLUB
                            ? "LEFT JOIN tblMember_Teams ON (tblMember.intMemberID=tblMember_Teams.intMemberID AND tblMember_Teams.intStatus = $Defs::RECSTATUS_ACTIVE) LEFT JOIN tblTeam ON (tblTeam.intTeamID=tblMember_Teams.intTeamID AND tblTeam.intAssocID=tblAssoc.intAssocID)"
                            : ''
                        ),
'LEFT JOIN tblComp_Teams ON (tblComp_Teams.intTeamID=tblTeam.intTeamID AND tblComp_Teams.intRecStatus = 1) LEFT JOIN tblAssoc_Comp ON (tblAssoc_Comp.intCompID=tblComp_Teams.intCompID AND tblAssoc_Comp.intAssocID=tblAssoc.intAssocID AND tblMember_Teams.intCompID=tblAssoc_Comp.intCompID)'
                    ],
                    optiongroup   => 'affiliations',
                    allowgrouping => 1
                }
              ],

              strAgeLevel => [
                (
                    ( !$SystemConfig->{'NoComps'} ) ? 'Competition Age Level'
                    : ''
                ),
                {
                    displaytype     => 'lookup',
                    fieldtype       => 'dropdown',
                    dropdownoptions => \%Defs::CompAgeLevel,
                    dbfield         => 'tblAssoc_Comp.strAgeLevel',
                    dbfrom          => [
                        (
                            $currentLevel == $Defs::LEVEL_CLUB
                            ? "LEFT JOIN tblMember_Teams ON (tblMember.intMemberID=tblMember_Teams.intMemberID AND tblMember_Teams.intStatus = $Defs::RECSTATUS_ACTIVE) LEFT JOIN tblTeam ON (tblTeam.intTeamID=tblMember_Teams.intTeamID AND tblTeam.intClubID=tblClub.intClubID)"
                            : ''
                        ),
                        (
                            $currentLevel > $Defs::LEVEL_CLUB
                            ? "LEFT JOIN tblMember_Teams ON (tblMember.intMemberID=tblMember_Teams.intMemberID AND tblMember_Teams.intStatus = $Defs::RECSTATUS_ACTIVE) LEFT JOIN tblTeam ON (tblTeam.intTeamID=tblMember_Teams.intTeamID AND tblTeam.intAssocID=tblAssoc.intAssocID)"
                            : ''
                        ),
'LEFT JOIN tblComp_Teams ON (tblComp_Teams.intTeamID=tblTeam.intTeamID AND tblComp_Teams.intRecStatus = 1) LEFT JOIN tblAssoc_Comp ON (tblAssoc_Comp.intCompID=tblComp_Teams.intCompID AND tblAssoc_Comp.intAssocID=tblAssoc.intAssocID AND tblMember_Teams.intCompID=tblAssoc_Comp.intCompID)'
                    ],
                    optiongroup   => 'affiliations',
                    allowgrouping => 1
                }
              ],

              CompRecStatus => [
                ( !$SystemConfig->{'NoComps'} ? 'Competition Active' : '' ),
                {
                    displaytype     => 'lookup',
                    fieldtype       => 'dropdown',
                    dropdownoptions => { 0 => 'No', 1 => 'Yes' },
                    dropdownorder => [ 0, 1 ],
                    dbfield       => 'tblAssoc_Comp.intRecStatus',
                    optiongroup   => 'affiliations',
                    dbfrom        => [
                        (
                            $currentLevel == $Defs::LEVEL_CLUB
                            ? "LEFT JOIN tblMember_Teams ON (tblMember.intMemberID=tblMember_Teams.intMemberID AND tblMember_Teams.intStatus = $Defs::RECSTATUS_ACTIVE) LEFT JOIN tblTeam ON (tblTeam.intTeamID=tblMember_Teams.intTeamID AND tblTeam.intClubID=tblClub.intClubID)"
                            : ''
                        ),
                        (
                            $currentLevel > $Defs::LEVEL_CLUB
                            ? "LEFT JOIN tblMember_Teams ON (tblMember.intMemberID=tblMember_Teams.intMemberID AND tblMember_Teams.intStatus = $Defs::RECSTATUS_ACTIVE) LEFT JOIN tblTeam ON (tblTeam.intTeamID=tblMember_Teams.intTeamID AND tblTeam.intAssocID=tblAssoc.intAssocID)"
                            : ''
                        ),
'LEFT JOIN tblComp_Teams ON (tblComp_Teams.intTeamID=tblTeam.intTeamID AND tblComp_Teams.intRecStatus = 1) LEFT JOIN tblAssoc_Comp ON (tblAssoc_Comp.intCompID=tblComp_Teams.intCompID AND tblAssoc_Comp.intAssocID=tblAssoc.intAssocID AND tblMember_Teams.intCompID=tblAssoc_Comp.intCompID)'
                    ]
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
                    dbfield =>
"IF(tblZone.intStatusID = $Defs::NODE_SHOW, tblZone.strName,'')",
                    allowgrouping => 1,
                    optiongroup   => 'affiliations'
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
                    dbfield =>
"IF(tblRegion.intStatusID = $Defs::NODE_SHOW, tblRegion.strName,'')",
                    allowgrouping => 1,
                    optiongroup   => 'affiliations'
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
                    dbfield =>
"IF(tblState.intStatusID = $Defs::NODE_SHOW, tblState.strName,'')",
                    allowgrouping => 1,
                    optiongroup   => 'affiliations'
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
                    dbfield =>
"IF(tblNational.intStatusID = $Defs::NODE_SHOW, tblNational.strName,'')",
                    allowgrouping => 1,
                    optiongroup   => 'affiliations'
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
                    dbfield =>
"IF(tblIntZone.intStatusID = $Defs::NODE_SHOW, tblIntZone.strName,'')",
                    allowgrouping => 1,
                    optiongroup   => 'affiliations'
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
                    dbfield =>
" IF(tblIntRegion.intStatusID = $Defs::NODE_SHOW, tblIntRegion.strName,'') ",
                    allowgrouping => 1,
                    optiongroup   => 'affiliations'
                }
              ],

              #Event Selections
              strEventName => [
                $SystemConfig->{'AllowEvents'} ? 'Event Name' : '',
                {
                    displaytype => 'text',
                    fieldtype   => 'text',
                    allowsort   => 1,
                    dbfield     => 'tblEvent.strEventName',
                    optiongroup => 'eventsel'
                }
              ],
              strEventNo => [
                $SystemConfig->{'AllowEvents'} ? 'Event Number' : '',
                {
                    displaytype => 'text',
                    fieldtype   => 'text',
                    allowsort   => 1,
                    optiongroup => 'eventsel'
                }
              ],
              intCategory => [
                $SystemConfig->{'AllowEvents'} ? 'Accreditation Category' : '',
                {
                    displaytype => 'text',
                    fieldtype   => 'text',
                    allowsort   => 1,
                    dbfield =>
"CONCAT(tblEventCategories.strCategory, ' / ', tblEventCategories.strPopulation)",
                    optiongroup => 'eventsel'
                }
              ],
              intEventSportsID => [
                $SystemConfig->{'AllowEvents'} ? 'Selected Sport' : '',
                {
                    displaytype => 'text',
                    fieldtype   => 'text',
                    allowsort   => 1,
                    dbfield     => 'tblEventSports.strSportName',
                    optiongroup => 'eventsel'
                }
              ],
              intEventSportingEventID => [
                $SystemConfig->{'AllowEvents'} ? 'Selected Event' : '',
                {
                    displaytype => 'text',
                    fieldtype   => 'text',
                    allowsort   => 1,
                    dbfield => 'tblEventSportingEvents.strSportingEventName',
                    optiongroup => 'eventsel'
                }
              ],
              intReserve => [
                $SystemConfig->{'AllowEvents'} ? 'Selected as Reserve' : '',
                {
                    displaytype     => 'lookup',
                    fieldtype       => 'dropdown',
                    dropdownoptions => \%Defs::tfInfo,
                    allowsort       => 1,
                    optiongroup     => 'eventsel'
                }
              ],
              strJobTitle => [
                $SystemConfig->{'AllowEvents'} ? 'Job Title' : '',
                {
                    displaytype => 'text',
                    fieldtype   => 'text',
                    allowsort   => 1,
                    dbfield     => 'ES.strJobTitle',
                    optiongroup => 'eventsel'
                }
              ],
              strPreferredNameEvent => [
                $SystemConfig->{'AllowEvents'} ? 'Preferred Name' : '',
                {
                    displaytype => 'text',
                    fieldtype   => 'text',
                    allowsort   => 1,
                    dbfield     => 'ES.strPreferredName',
                    optiongroup => 'eventsel'
                }
              ],
              intNationalityTypeID => [
                $SystemConfig->{'AllowEvents'} ? 'Nationality Type' : '',
                {
                    displaytype     => 'lookup',
                    fieldtype       => 'dropdown',
                    dropdownoptions => \%Defs::NationalityType,
                    allowsort       => 1,
                    optiongroup     => 'eventsel'
                }
              ],

              dtMemCardPrinted => [
                'Member Card Printed',
                {
                    displaytype => 'date',
                    fieldtype   => 'date',
                    allowsort   => 1,
                    dbformat =>
' DATE_FORMAT(tblMemberCardPrinted.dtPrinted,"%d/%m/%Y %H:%i")',
                    optiongroup => 'otherfields',
                    dbfield     => 'tblMemberCardPrinted.dtPrinted',
                    dbfrom =>
'LEFT JOIN tblMemberCardPrinted ON tblMemberCardPrinted.intMemberID = tblMember.intMemberID'
                }
              ],

              dtCardPrinted => [
                ( $SystemConfig->{'AllowEvents'} ? 'Event Card Printed' : '' ),
                {
                    displaytype => 'date',
                    fieldtype   => 'date',
                    allowsort   => 1,
                    dbformat =>
                      ' DATE_FORMAT(tblCardPrinted.dtPrinted,"%d/%m/%Y %H:%i")',
                    optiongroup => 'eventsel',
                    dbfield     => 'tblCardPrinted.dtPrinted',
                    dbfrom =>
'LEFT JOIN tblCardPrinted ON tblCardPrinted.intEventSelectionID=ES.intEventSelectionID'
                }
              ],
              intEventApprovalID => [
                $SystemConfig->{'AllowEvents'} ? 'Status' : '',
                {
                    displaytype     => 'lookup',
                    fieldtype       => 'dropdown',
                    dropdownoptions => {
                        $Defs::SELECTION_STATUS_OK              => 'Selected',
                        $Defs::SELECTION_STATUS_LOCKED_BY_GOV   => 'Locked',
                        $Defs::SELECTION_STATUS_LOCKED_BY_EVENT => 'Approved'
                    },
                    allowsort   => 1,
                    optiongroup => 'eventsel',
                    dbfield =>
                      'IF(ES.intEventApprovalID >2, 2, ES.intEventApprovalID)'
                }
              ],

              ADdtArrival => [
                $SystemConfig->{'SystemForEvent'} ? 'Arrival Date' : '',
                {
                    displaytype   => 'date',
                    fieldtype     => 'date',
                    allowsort     => 1,
                    dbformat      => ' DATE_FORMAT(AD.dtArrival,"%d/%m/%Y")',
                    optiongroup   => 'eventsel',
                    dbfield       => 'AD.dtArrival',
                    allowgrouping => 1
                }
              ],
              ADtimeArrivalFlight => [
                $SystemConfig->{'SystemForEvent'} ? 'Flight Arrival Time' : '',
                {
                    displaytype   => 'text',
                    fieldtype     => 'text',
                    allowsort     => 1,
                    optiongroup   => 'eventsel',
                    dbfield       => 'AD.timeArrivalFlight',
                    allowgrouping => 1
                }
              ],
              ADintArrivalAirportID => [
                $SystemConfig->{'SystemForEvent'} ? 'Arrival Airport' : '',
                {
                    displaytype => 'lookup',
                    fieldtype   => 'dropdown',
                    allowsort   => 1,
                    dropdownoptions =>
                      $CommonVals->{'EventLookups'}{'Airports'}{'Values'},
                    dropdownorder =>
                      $CommonVals->{'EventLookups'}{'Airports'}{'Order'},
                    optiongroup   => 'eventsel',
                    dbfield       => 'AD.intArrivalAirportID',
                    allowgrouping => 1
                }
              ],
              ADintArrivalAirlineID => [
                $SystemConfig->{'SystemForEvent'} ? 'Arrival Airline' : '',
                {
                    displaytype => 'lookup',
                    fieldtype   => 'dropdown',
                    allowsort   => 1,
                    dropdownoptions =>
                      $CommonVals->{'EventLookups'}{'Airlines'}{'Values'},
                    dropdownorder =>
                      $CommonVals->{'EventLookups'}{'Airlines'}{'Order'},
                    optiongroup   => 'eventsel',
                    dbfield       => 'AD.intArrivalAirlineID',
                    allowgrouping => 1
                }
              ],
              ADstrArrivalFlightNum => [
                $SystemConfig->{'SystemForEvent'}
                ? 'Arrival Flight Number'
                : '',
                {
                    displaytype   => 'text',
                    fieldtype     => 'text',
                    allowsort     => 1,
                    optiongroup   => 'eventsel',
                    dbfield       => 'AD.strArrivalFlightNum',
                    allowgrouping => 1
                }
              ],
              ADdtDepart => [
                $SystemConfig->{'SystemForEvent'} ? 'Depart Date' : '',
                {
                    displaytype   => 'date',
                    fieldtype     => 'date',
                    allowsort     => 1,
                    dbformat      => ' DATE_FORMAT(AD.dtDepart,"%d/%m/%Y")',
                    optiongroup   => 'eventsel',
                    dbfield       => 'AD.dtDepart',
                    allowgrouping => 1
                }
              ],
              ADtimeDepartFlight => [
                $SystemConfig->{'SystemForEvent'} ? 'Flight Depart Time' : '',
                {
                    displaytype   => 'text',
                    fieldtype     => 'text',
                    allowsort     => 1,
                    optiongroup   => 'eventsel',
                    dbfield       => 'AD.timeDepartFlight',
                    allowgrouping => 1
                }
              ],
              ADintDepartAirportID => [
                $SystemConfig->{'SystemForEvent'} ? 'Depart Airport' : '',
                {
                    displaytype => 'lookup',
                    fieldtype   => 'dropdown',
                    allowsort   => 1,
                    dropdownoptions =>
                      $CommonVals->{'EventLookups'}{'Airports'}{'Values'},
                    dropdownorder =>
                      $CommonVals->{'EventLookups'}{'Airports'}{'Order'},
                    optiongroup   => 'eventsel',
                    dbfield       => 'AD.intDepartAirportID',
                    allowgrouping => 1
                }
              ],
              ADintDepartAirlineID => [
                $SystemConfig->{'SystemForEvent'} ? 'Depart Airline' : '',
                {
                    displaytype => 'lookup',
                    fieldtype   => 'dropdown',
                    allowsort   => 1,
                    dropdownoptions =>
                      $CommonVals->{'EventLookups'}{'Airlines'}{'Values'},
                    dropdownorder =>
                      $CommonVals->{'EventLookups'}{'Airlines'}{'Order'},
                    optiongroup   => 'eventsel',
                    dbfield       => 'AD.intDepartAirlineID',
                    allowgrouping => 1
                }
              ],
              ADstrDepartFlightNum => [
                $SystemConfig->{'SystemForEvent'} ? 'Depart Flight Number' : '',
                {
                    displaytype   => 'text',
                    fieldtype     => 'text',
                    allowsort     => 1,
                    optiongroup   => 'eventsel',
                    dbfield       => 'AD.strDepartFlightNum',
                    allowgrouping => 1
                }
              ],
              ADintHotelID => [
                $SystemConfig->{'SystemForEvent'} ? 'Hotel' : '',
                {
                    displaytype => 'lookup',
                    fieldtype   => 'dropdown',
                    allowsort   => 1,
                    dropdownoptions =>
                      $CommonVals->{'EventLookups'}{'Hotels'}{'Values'},
                    dropdownorder =>
                      $CommonVals->{'EventLookups'}{'Hotels'}{'Order'},
                    optiongroup   => 'eventsel',
                    dbfield       => 'AD.intHotelID',
                    allowgrouping => 1
                }
              ],
              ADstrNotes => [
                $SystemConfig->{'SystemForEvent'} ? 'Notes' : '',
                {
                    displaytype => 'text',
                    fieldtype   => 'text',
                    allowsort   => 0,
                    dbfield     => 'AD.strNotes',
                    optiongroup => 'eventsel'
                }
              ],

              #Transactions
              intTransactionID => [
                $SystemConfig->{'AllowTXNrpts'} ? 'Transaction ID' : '',
                {
                    displaytype => 'text',
                    fieldtype   => 'text',
                    allowsort   => 1,
                    optiongroup => 'transactions'
                }
              ],
              intProductSeasonID => [
                "Product Reporting $txt_SeasonName",
                {
                    displaytype     => 'lookup',
                    fieldtype       => 'dropdown',
                    dropdownoptions => $CommonVals->{'Seasons'}{'Options'},
                    dropdownorder   => $CommonVals->{'Seasons'}{'Order'},
                    allowsort       => 1,
                    optiongroup     => 'transactions',
                    active          => 0,
                    multiple        => 1,
                    size            => 3,
                    disable         => $hideSeasons
                }
              ],
              intProductID => [
                $SystemConfig->{'AllowTXNrpts'} ? 'Product' : '',
                {
                    displaytype     => 'lookup',
                    fieldtype       => 'dropdown',
                    dropdownoptions => $CommonVals->{'Products'}{'Options'},
                    dropdownorder   => $CommonVals->{'Products'}{'Order'},
                    allowsort       => 1,
                    optiongroup     => 'transactions',
                    multiple        => 1,
                    size            => 6,
                    dbfield         => 'TX.intProductID',
                    allowgrouping   => 1
                }
              ],
              strGroup => [
                $SystemConfig->{'AllowTXNrpts'} ? 'Product Group' : '',
                {
                    displaytype => 'text',
                    fieldtype   => 'text',
                    allowsort   => 1,
                    optiongroup => 'transactions',
                    ddbfield    => 'P.strGroup'
                }
              ],
              curAmount => [
                $SystemConfig->{'AllowTXNrpts'} ? 'Line Item Total' : '',
                {
                    displaytype => 'currency',
                    fieldtype   => 'text',
                    allowsort   => 1,
                    optiongroup => 'transactions',
                    total       => 1
                }
              ],
              intQty => [
                $SystemConfig->{'AllowTXNrpts'} ? 'Quantity' : '',
                {
                    displaytype => 'text',
                    fieldtype   => 'text',
                    allowsort   => 1,
                    optiongroup => 'transactions',
                    total       => 1
                }
              ],
              TLstrReceiptRef => [
                $SystemConfig->{'AllowTXNrpts'}
                ? 'Manual Receipt Reference'
                : '',
                {
                    displaytype => 'text',
                    fieldtype   => 'text',
                    optiongroup => 'transactions',
                    dbfield     => 'TL.strReceiptRef'
                }
              ],
              payment_type => [
                $SystemConfig->{'AllowTXNrpts'} ? 'Payment Type' : '',
                {
                    displaytype     => 'lookup',
                    fieldtype       => 'dropdown',
                    dropdownoptions => \%Defs::paymentTypes,
                    allowsort       => 1,
                    optiongroup     => 'transactions',
                    dbfield         => 'TL.intPaymentType',
                    allowgrouping   => 1
                }
              ],
              strTXN => [
                $SystemConfig->{'AllowTXNrpts'} ? 'Bank Reference Number' : '',
                {
                    displaytype => 'text',
                    fieldtype   => 'text',
                    optiongroup => 'transactions',
                    dbfield     => 'TL.strTXN'
                }
              ],
              intLogID => [
                $SystemConfig->{'AllowTXNrpts'} ? 'Payment Log ID' : '',
                {
                    displaytype => 'text',
                    fieldtype   => 'text',
                    optiongroup => 'transactions',
                    dbfield     => 'TL.intLogID'
                }
              ],
              intAmount => [
                $SystemConfig->{'AllowTXNrpts'} ? 'Order Total' : '',
                {
                    displaytype => 'currency',
                    fieldtype   => 'text',
                    allowsort   => 1,
                    total       => 1,
                    optiongroup => 'transactions',
                    dbfield     => 'TL.intAmount'
                }
              ],
              dtTransaction => [
                ( $SystemConfig->{'AllowTXNrpts'} ? 'Transaction Date' : '' ),
                {
                    displaytype => 'date',
                    fieldtype   => 'datetime',
                    allowsort   => 1,
                    dbformat =>
                      ' DATE_FORMAT(TX.dtTransaction,"%d/%m/%Y %H:%i")',
                    optiongroup => 'transactions',
                    dbfield     => 'TX.dtTransaction',
                    sortfield   => 'TX.dtTransaction'
                }
              ],
              dtPaid => [
                ( $SystemConfig->{'AllowTXNrpts'} ? 'Payment Date' : '' ),
                {
                    displaytype => 'date',
                    fieldtype   => 'datetime',
                    allowsort   => 1,
                    dbformat    => ' DATE_FORMAT(TX.dtPaid,"%d/%m/%Y %H:%i")',
                    optiongroup => 'transactions',
                    dbfield     => 'TX.dtPaid'
                }
              ],
              dtSettlement => [
                ( $SystemConfig->{'AllowTXNrpts'} ? 'Settlement Date' : '' ),
                {
                    displaytype   => 'date',
                    fieldtype     => 'date',
                    allowsort     => 1,
                    dbformat      => ' DATE_FORMAT(TL.dtSettlement,"%d/%m/%Y")',
                    optiongroup   => 'transactions',
                    dbfield       => 'TL.dtSettlement',
                    allowgrouping => 1,
                    sortfield     => 'TL.dtSettlement'
                }
              ],
              dtStart => [
                ( $SystemConfig->{'AllowTXNrpts'} ? 'Start Date' : '' ),
                {
                    displaytype => 'date',
                    fieldtype   => 'datetime',
                    allowsort   => 1,
                    dbformat    => ' DATE_FORMAT(TX.dtStart,"%d/%m/%Y")',
                    optiongroup => 'transactions',
                    dbfield     => 'TX.dtStart'
                }
              ],
              dtEnd => [
                ( $SystemConfig->{'AllowTXNrpts'} ? 'End Date' : '' ),
                {
                    displaytype => 'date',
                    fieldtype   => 'datetime',
                    allowsort   => 1,
                    dbformat    => ' DATE_FORMAT(TX.dtEnd,"%d/%m/%Y")',
                    optiongroup => 'transactions',
                    dbfield     => 'TX.dtEnd'
                }
              ],
              intTransStatusID => [
                $SystemConfig->{'AllowTXNrpts'} ? 'Transaction Status' : '',
                {
                    displaytype     => 'lookup',
                    fieldtype       => 'dropdown',
                    dropdownoptions => \%Defs::TransactionStatus,
                    allowsort       => 1,
                    optiongroup     => 'transactions',
                    dbfield         => 'TX.intStatus'
                }
              ],
              strTransNotes => [
                $SystemConfig->{'AllowTXNrpts'} ? 'Transaction Notes' : '',
                {
                    displaytype => 'text',
                    fieldtype   => 'text',
                    optiongroup => 'transactions',
                    dbfield     => 'TX.strNotes'
                }
              ],
              strTLNotes => [
                $SystemConfig->{'AllowTXNrpts'} ? 'Payment Record Notes' : '',
                {
                    displaytype => 'text',
                    fieldtype   => 'text',
                    optiongroup => 'transactions',
                    dbfield     => 'TL.strComments'
                }
              ],
              intExportAssocBankFileID => [
                $SystemConfig->{'AllowTXNrpts'} ? 'Distribution ID' : '',
                {
                    displaytype => 'text',
                    fieldtype   => 'text',
                    optiongroup => 'transactions',
                    dbfield     => 'intExportAssocBankFileID'
                }
              ],
              ClubPaymentID => [
                $SystemConfig->{'AllowTXNrpts'}
                ? qq[$Data->{'LevelNames'}{$Defs::LEVEL_CLUB} Payment for]
                : '',
                {
                    displaytype => 'text',
                    fieldtype   => 'text',
                    optiongroup => 'transactions',
                    dbfield     => 'PaymentClub.strName',
                    dbfrom =>
"LEFT JOIN tblClub as PaymentClub ON (PaymentClub.intClubID=intClubPaymentID)"
                }
              ],

          },

          Order => [
            qw(
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

              strP1Salutation
              strP1FName
              strP1SName
              intP1Gender
              strP1Phone
              strP1Phone2
              strP1PhoneMobile
              strP1Email
              strP1Email2
              intP1AssistAreaID
              strP2Salutation
              strP2FName
              strP2SName
              intP2Gender
              strP2Phone
              strP2Phone2
              strP2PhoneMobile
              strP2Email
              strP2Email2
              intP2AssistAreaID

              intFinancialActive
              intMemberPackageID
              curMemberFinBal
              intLifeMember
              intMedicalConditions
              intAllergies
              intAllowMedicalTreatment
              strMemberMedicalNotes
              dtMemCardPrinted
              intOccupationID
              strLoyaltyNumber
              intMailingList
              intOptinID
              strUnsubscribeURL
              intTermsFormID
              dtTermsCreated

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
              FileName
              FileDate
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
              strCustomStr16
              strCustomStr17
              strCustomStr18
              strCustomStr19
              strCustomStr20
              strCustomStr21
              strCustomStr22
              strCustomStr23
              strCustomStr24
              strCustomStr25
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
              dblCustomDbl11
              dblCustomDbl12
              dblCustomDbl13
              dblCustomDbl14
              dblCustomDbl15
              dblCustomDbl16
              dblCustomDbl17
              dblCustomDbl18
              dblCustomDbl19
              dblCustomDbl20
              dtCustomDt1
              dtCustomDt2
              dtCustomDt3
              dtCustomDt4
              dtCustomDt5
              dtCustomDt6
              dtCustomDt7
              dtCustomDt8
              dtCustomDt9
              dtCustomDt10
              dtCustomDt11
              dtCustomDt12
              dtCustomDt13
              dtCustomDt14
              dtCustomDt15
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
              intCustomLU11
              intCustomLU12
              intCustomLU13
              intCustomLU14
              intCustomLU15
              intCustomLU16
              intCustomLU17
              intCustomLU18
              intCustomLU19
              intCustomLU20
              intCustomLU21
              intCustomLU22
              intCustomLU23
              intCustomLU24
              intCustomLU25
              intCustomBool1
              intCustomBool2
              intCustomBool3
              intCustomBool4
              intCustomBool5
              intCustomBool6
              intCustomBool7
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

              intPhoto
              intPhotoUseApproval
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
              dtLastRecordedGame
              intCareerGames
              intPlayerJunior
              intPlayerSenior
              intPlayerVeteran
              intCoachActive
              strCoachRegNo
              strInstrucRegNo

              intCoachAccredActive
              strCoachAccredType
              intCOCustomDDL_1
              intCOCustomDDL_2
              intCOCustomDDL_3
              intCoachReAccreditation
              strCoachAccredLevel
              strCoachAccredProv
              strCoachAccredResult
              dtCoachAccredStart
              dtCoachAccredEnd
              dtCoachAccredAppDate
              intDeregisteredCoach
              intUmpireActive
              strUmpireRegNo
              strUmpireType
              intUmpireAccredActive
              intUmpireReAccreditation
              strUmpireAccredType
              strUmpireAccredLevel
              strUmpireAccredProv
              strUmpireAccredResult
              dtUmpireAccredStart
              dtUmpireAccredEnd
              dtUmpireAccredAppDate
              intDeregisteredUmpire
              intMOCustomDDL_1
              intMOCustomDDL_2
              intMOCustomDDL_3
              intMOCustomDDL_4
              intMOCustomDDL_5
              intOfficialAccredActive
              intOfficialReAccreditation
              strOfficialPos
              strOfficialRegNo
              dtOfficialStart
              dtOfficialEnd
              dtOfficialAppDate
              strOfficialAccredType
              strOfficialAccredLevel
              strOfficialAccredProv
              strOfficialAccredResult
              intMiscAccredActive
              strMiscPos
              strMiscLevel
              strMiscRegNo
              strMiscRegNo2

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
              intExcludeFromNationalRego
              intAssocTypeID
              intAssocCategoryID
              strTeamName
              strClubName
              strTeamNumber
              strClubNumber
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
              intPermitClub
              strEventName
              strEventNo
              intCategory
              intEventSportsID
              intEventSportingEventID
              intReserve
              strJobTitle
              strPreferredNameEvent
              intNationalityTypeID
              dtCardPrinted
              intEventApprovalID

              ADdtArrival
              ADtimeArrivalFlight
              ADintArrivalAirportID
              ADintArrivalAirlineID
              ADstrArrivalFlightNum
              ADdtDepart
              ADtimeDepartFlight
              ADintDepartAirportID
              ADintDepartAirlineID
              ADstrDepartFlightNum
              ADintHotelID
              ADstrNotes
              intTransactionID
              intProductSeasonID
              intProductID
              strGroup
              intQty
              curAmount
              dtTransaction
              intTransStatusID
              strTransNotes
              strTLNotes
              intLogID
              payment_type
              TLstrReceiptRef
              strTXN
              intAmount
              dtPaid
              dtSettlement
              dtStart
              dtEnd
              ClubPaymentID
              strUsername
              strPassword
              strMemberRecordTypeList
              dtMemberRecordIn
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
          ExportFormats => {
            MeetManager => {
                Name => 'Meet Manager',
                Select =>
"strSurname, strFirstname, IF(intGender<>1,'M','F') AS Gender, DATE_FORMAT(dtDOB, '%m/%d/%Y') AS dtDOB, tblMember.strAddress1, tblMember.strAddress2, tblMember.strSuburb, tblMember.strState, tblMember.strPostalCode, tblMember.strCountry, strPassportNationality, strPhoneHome, strPhoneWork, tblMember.strFax, tblMember.strEmail",
                Order => [
                    'I',                      'strSurname',
                    'strFirstname',           '',
                    'Gender',                 'dtDOB',
                    '',                       '',
                    '',                       '',
                    'strAddress1',            'strAddress2',
                    'strSuburb',              'strState',
                    'strPostalCode',          'strCountry',
                    'strPassportNationality', 'strPhoneHome',
                    'strPhoneWork',           'strFax',
                    '',                       '',
                    '',                       'strEmail'
                ],
                Headers        => 0,
                ExportFileName => 'export.txt',
                Delimiter      => ';',
            },
          },
          OptionGroups => {
            details         => [ 'Personal Details', { active => 1 } ],
            contactdetails  => [ 'Contact Details',  {} ],
            security        => [ 'Security',         {} ],
            interests       => [ 'Interests',        {} ],
            identifications => [ 'Identifications',  {} ],
            parents         => [ 'Parent/Guardian',  {} ],
            financial       => [ 'Financial',        {} ],
            medical         => [ 'Medical',          {} ],
            otherfields     => [ 'Other Fields',     {} ],
            affiliations    => [ 'Affiliations',     {} ],
            seasons         => [ $txt_SeasonNames,   {} ],
            records         => [ 'Member Records',   {} ],
            mt_player       => [
                'Member Type - Player',
                {
                    from =>
"LEFT JOIN tblMember_Types AS tblMT_Player ON (tblMember.intMemberID=tblMT_Player.intMemberID AND tblMT_Player.intTypeID=$Defs::MEMBER_TYPE_PLAYER AND tblMT_Player.intAssocID = tblMember_Associations.intAssocID AND tblMT_Player.intRecStatus = $Defs::RECSTATUS_ACTIVE)",
                }
            ],
            mt_coach => [
                'Member Type - Coach',
                {
                    from =>
"LEFT JOIN tblMember_Types AS tblMT_Coach ON (tblMember.intMemberID=tblMT_Coach.intMemberID AND tblMT_Coach.intTypeID=$Defs::MEMBER_TYPE_COACH AND tblMT_Coach.intAssocID = tblMember_Associations.intAssocID AND tblMT_Coach.intRecStatus = $Defs::RECSTATUS_ACTIVE AND tblMT_Coach.intSubTypeID=0)",
                }
            ],
            mt_umpire => [
                'Member Type - Match Official',
                {
                    from =>
"LEFT JOIN tblMember_Types AS tblMT_Umpire ON (tblMember.intMemberID=tblMT_Umpire.intMemberID AND tblMT_Umpire.intTypeID=$Defs::MEMBER_TYPE_UMPIRE AND tblMT_Umpire.intAssocID = tblMember_Associations.intAssocID AND tblMT_Umpire.intRecStatus = $Defs::RECSTATUS_ACTIVE AND tblMT_Umpire.intSubTypeID=0)",
                }
            ],
            mt_official => [
                $Data->{'SystemConfig'}{'TYPE_NAME_4'}
                ? 'Member Type - ' . $Data->{'SystemConfig'}{'TYPE_NAME_4'}
                : 'Member Type - Official',
                {
                    from =>
"LEFT JOIN tblMember_Types AS tblMT_Official ON (tblMember.intMemberID=tblMT_Official.intMemberID AND tblMT_Official.intTypeID=$Defs::MEMBER_TYPE_OFFICIAL AND tblMT_Official.intAssocID = tblMember_Associations.intAssocID  AND tblMT_Official.intRecStatus = $Defs::RECSTATUS_ACTIVE)",
                }
            ],
            mt_misc => [
                $Data->{'SystemConfig'}{'TYPE_NAME_5'}
                ? 'Member Type - ' . $Data->{'SystemConfig'}{'TYPE_NAME_5'}
                : 'Member Type - Misc',
                {
                    #            mt_misc => ['Member Type - Misc',{
                    from =>
"LEFT JOIN tblMember_Types AS tblMT_Misc ON (tblMember.intMemberID=tblMT_Misc.intMemberID AND tblMT_Misc.intTypeID=$Defs::MEMBER_TYPE_MISC  AND tblMT_Misc.intAssocID = tblMember_Associations.intAssocID  AND tblMT_Misc.intRecStatus = $Defs::RECSTATUS_ACTIVE)",
                }
            ],
            eventsel => [
                'Event Selections',
                {
                    from =>
"LEFT JOIN tblEventSelections AS ES ON (tblMember.intMemberID=ES.intMemberID)
                LEFT JOIN tblEventCategories ON (tblEventCategories.intEventCategoriesID=ES.intAccredCatID)
                LEFT JOIN tblEventSelectionSports AS ESS ON (ES.intEventSelectionID=ESS.intEventSelectionID)
                LEFT JOIN tblEventSportingEvents ON (tblEventSportingEvents.intEventSportingEventID =ESS.intSportingEventID)
                LEFT JOIN tblEventSports ON (tblEventSports.intEventSportsID=ESS.intSportID)
                LEFT JOIN tblEvent ON (tblEvent.intEventID=ES.intEventID)
                LEFT JOIN tblArrivalsDeparts AS AD ON (AD.intEventID=ES.intEventID AND AD.intMemberID=ES.intMemberID)
                ",
                }
            ],
            transactions => [
                $txt_Transactions,
                {
                    from =>
"LEFT JOIN tblTransactions AS TX ON (TX.intStatus<>-1 AND NOT ( TX.intProductID IN ($RealmLPF_Ids) AND TX.intStatus IN (0,-1)) AND tblMember.intMemberID=TX.intID AND TX.intTableType =1 AND TX.intAssocID = tblMember_Associations.intAssocID $txn_WHERE) LEFT JOIN tblTransLog as TL ON (TL.intLogID = TX.intTransLogID)",
                }
            ],

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
    if ( $SystemConfig->{'NoMemberTypes'} ) {
        for my $f (
            qw(intPlayerActive dtLastRecordedGame intCareerGames intPlayerJunior intPlayerSenior intPlayerVeteran intCoachActive strCoachRegNo strInstrucRegNo  intCoachAccredActive strCoachAccredType strCoachAccredLevel strCoachAccredProv dtCoachAccredStart dtCoachAccredEnd intUmpireActive strUmpireRegNo intUmpireAccredActive strUmpireAccredType strUmpireAccredLevel strUmpireAccredProv dtUmpireAccredStart dtUmpireAccredEnd intOfficialAccredActive strOfficialPos strOfficialRegNo dtOfficialStart dtOfficialEnd intMiscAccredActive strMiscPos strMiscRegNo dtMiscStart dtMiscEnd strUmpireType)
          )
        {
            $config{'Fields'}{$f}[0] = '';
        }
    }
    if ( $currentLevel > $Defs::LEVEL_ASSOC ) {
        $config{'Fields'}{'intMemberPackageID'} = [
            'Member Package',
            {
                displaytype   => 'text',
                fieldtype     => 'text',
                optiongroup   => 'financial',
                allowgrouping => 1,
                dbfrom =>
"INNER JOIN tblMemberPackages AS MP ON MP.intMemberPackagesID=tblMember_Associations.intMemberPackageID",
                dbfield => 'MP.strPackageName'
            }
        ];
    }

        $config{'Fields'} = {
            %{$config{'Fields'}},
            strUsername => [
                'Username',
                {
                    optiongroup => 'security',
                    displaytype => 'text',
                    fieldtype   => 'text',
                    allowsort   => 1,
                    dbfield     => "CONCAT('1',tblAuth.strUsername)",
                    dbfrom =>
                    "LEFT JOIN tblAuth ON (tblMember.intMemberID= tblAuth.intID and tblAuth.intLevel=1)"
                }
            ],
        };
    if ($Data->{'SystemConfig'}{'AssocConfig'}{'ShowPassword'}) {
        $config{'Fields'} = {
            %{$config{'Fields'}},
            strPassword => [
                'Password',
                {
                    optiongroup => 'security',
                    displaytype => 'text',
                    fieldtype   => 'text',
                    allowsort   => 1,
                    dbfield     => "strPassword",
                    dbfrom =>
                    "LEFT JOIN tblAuth ON (tblMember.intMemberID= tblAuth.intID and tblAuth.intLevel=1)"
                }
            ],
        };
    }

    $self->{'Config'} = \%config;
}

sub SQLBuilder {
    my ( $self, $OptVals, $ActiveFields ) = @_;
    my $currentLevel = $self->{'EntityTypeID'} || 0;
    my $Data         = $self->{'Data'};
    my $clientValues = $Data->{'clientValues'};
    my $SystemConfig = $Data->{'SystemConfig'};

    my $enable_record_types = $Data->{'SystemConfig'}{'EnableMemberRecords'} || 0; 
    my $MStablename = $enable_record_types? "tblMemberRecords_$Data->{'Realm'}" : "tblMember_Seasons_$Data->{'Realm'}";

    my $from_levels   = $OptVals->{'FROM_LEVELS'};
    my $from_list     = $OptVals->{'FROM_LIST'};
    my $where_levels  = $OptVals->{'WHERE_LEVELS'};
    my $where_list    = $OptVals->{'WHERE_LIST'};
    my $current_from  = $OptVals->{'CURRENT_FROM'};
    my $current_where = $OptVals->{'CURRENT_WHERE'};
    my $select_levels = $OptVals->{'SELECT_LEVELS'};
    my $sql           = '';

    my $clubID = ( $Data->{'clientValues'}{'clubID'} and $Data->{'clientValues'}{'clubID'} != $Defs::INVALID_ID ) ? $Data->{'clientValues'}{'clubID'}
               :                0
               ;

    my $assocSeasonWHERE = qq[];
    if ($enable_record_types) {
        # no club level for YA
    }
    else {
        $assocSeasonWHERE = qq[ AND $MStablename.intClubID=0];
        if ( $from_list =~ /tblMember_Clubs/ ) {
            $assocSeasonWHERE = qq[ AND ($MStablename.intClubID>0 or tblMember_Clubs.intMemberID IS NULL)];
        }
        if ($clubID) {
            $assocSeasonWHERE = qq[ AND $MStablename.intClubID = $clubID];
        }
    }

    if ( $clubID and $from_list =~ /MC/ ) {
        $where_list .= qq[ AND MC.intClubID = $clubID ];
    }
    if ( $where_list and ( $where_levels or $current_where ) ) {
        $where_list = ' AND ' . $where_list;
    }
    $where_list =~ s/\sAND\s*$//g;
    $where_list =~ s/AND  AND/AND /;

    my $mc_join = '';
    if ( $clubID
         and $from_levels !~ /tblMember_Clubs/
         and $current_from !~ /tblMember_Clubs/
         and $from_list !~ /tblMember_Clubs/ ) {
        $mc_join = qq[
            INNER JOIN tblMember_Clubs ON (
                tblMember.intMemberID = tblMember_Clubs.intMemberID 
                AND tblMember_Clubs.intStatus<>-1 
                AND tblMember_Clubs.intClubID = $clubID
            )
        ];
    }

    my $products_join = '';
    if ( $from_list =~ /tblTransactions/ ) {
        $products_join = qq[ LEFT JOIN tblProducts as P ON (P.intProductID=TX.intProductID)];
    }

    my $mtWHERE = '';
    if ( $from_list =~ /tblTeam/ and $from_list =~ /tblMember_Teams/ ) {
        $mtWHERE =
qq[ AND (tblTeam.intAssocID=tblMember_Associations.intAssocID OR tblMember_Teams.intTeamID IS NULL)];
    }

    my $seasonJOIN = qq[
        INNER JOIN tblSeasons as S ON (
            S.intSeasonID = $MStablename.intSeasonID
            AND S.intAssocID IN (0, $Data->{'clientValues'}{'assocID'})
        )
    ];
    if ( $Data->{'clientValues'}{'currentLevel'}> $Defs::LEVEL_ASSOC ) {
        $seasonJOIN = qq[
            INNER JOIN tblSeasons as S ON S.intSeasonID = $MStablename.intSeasonID
        ];
    }

    my $msJOIN = $enable_record_types ? qq[
        INNER JOIN $MStablename ON (
            $MStablename.intMemberID = tblMember_Associations.intMemberID 
            AND $MStablename.intEntityID = tblMember_Associations.intAssocID 
            AND $MStablename.intEntityTypeID = $Defs::LEVEL_ASSOC
            AND IF(tblAssoc.intAllowSeasons=1, $MStablename.intSeasonID > 0, $MStablename.intSeasonID = tblAssoc.intCurrentSeasonID)
        )]
               : qq[
        INNER JOIN $MStablename ON (
            $MStablename.intMemberID = tblMember_Associations.intMemberID 
            AND $MStablename.intAssocID = tblMember_Associations.intAssocID 
            AND $MStablename.intMSRecStatus=1 
            AND IF(tblAssoc.intAllowSeasons=1, $MStablename.intSeasonID > 0, $MStablename.intSeasonID = tblAssoc.intCurrentSeasonID)
        )]
               ;

    my $regoformJOIN = $enable_record_types ? qq[]
                     :                        qq[ LEFT JOIN tblRegoForm ON $MStablename.intUsedRegoFormID = tblRegoForm.intRegoFormID ];

    $sql = qq[
        SELECT ###SELECT###
        FROM
            $from_levels
            $current_from
            $from_list
            $mc_join
            $products_join
            $msJOIN
            $seasonJOIN    
            LEFT JOIN tblUploadedFiles ON tblMember.intMemberID = tblUploadedFiles.intEntityID AND tblUploadedFiles.intEntityTypeID=1
            $regoformJOIN
        WHERE
            $where_levels
            $current_where
            $where_list
            $assocSeasonWHERE
            $mtWHERE
    ];

    return ( $sql, '' );
}

1;
# vim: set et sw=4 ts=4:
