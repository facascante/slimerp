#!/usr/bin/perl

#
# $Header: svn://svn/SWM/trunk/misc/regoform_convert.pl 8250 2013-04-08 08:24:36Z rlee $
#

use strict;
use DBI;
use Data::Dumper;

my $dsn = 'DBI:mysql:regoSWM_live';
my $user = 'root';
my $passwd = q{};

my $db = DBI->connect($dsn, $user, $passwd);

$main::debug          = 1;
$main::debug_insertid = 1;

##============================================================================
## SQL Statements
##============================================================================

my $indiv_forms_statement = <<"EOS";

SELECT DISTINCT intEntityID as intAssocID,
       intRealmID,
       intSubTypeID as intSubRealmID
FROM   tblConfig
WHERE  intTypeID = 5

EOS

my $indiv_forms_query = $db->prepare($indiv_forms_statement);

##----------------------------------------------------------------------------

my $team_forms_statement = <<"EOS";
SELECT DISTINCT intAssocID, intRealmID, intSubRealmID
FROM   tblRegoFormComps
EOS

my $team_forms_query = $db->prepare($team_forms_statement);

##----------------------------------------------------------------------------

my $field_order_statement = <<"EOS";
SELECT    C.strValue,
          C.strPerm as strFieldName,
          RFO.intDisplayOrder
FROM      tblConfig as C

LEFT JOIN tblRegoFormOrder as RFO
ON        (RFO.intAssocID=intEntityID
AND       C.strPerm = RFO.strFieldName)
WHERE     intEntityID = ?
AND       C.intRealmID = ?
AND       intSubTypeID IN (0,?)
AND       intTypeID = 5
AND       strValue IN (1,2,4,5)
ORDER BY  IF(RFO.intDisplayOrder IS NULL, 1, 0) ASC, RFO.intDisplayOrder, C.intConfigID
EOS

my $field_order_query = $db->prepare($field_order_statement);

##----------------------------------------------------------------------------

my $field_label_statement = <<"EOS";
SELECT   1 AS strValue,
         strFieldName,
         intDisplayOrder
FROM     tblRegoFormOrder
WHERE    strFieldName LIKE 'RF%'
AND      intAssocID = ?
AND      intRealmID = ?
AND      intSubRealmID = ?
AND      intStatus = 1
ORDER BY intDisplayOrder
EOS

my $field_label_query = $db->prepare($field_label_statement);

##----------------------------------------------------------------------------

my $new_form_statement = <<"EOS";
INSERT INTO tblRegoForm(
    intAssocID,
    intRealmID,
    intSubRealmID,
    strRegoFormName,
    intRegoType,
    intRegoTypeLevel,
    intClubID
)
VALUES (
    ?,
    ?,
    ?,
    ?,
    ?,
    ?,
    -1
)
EOS

my $new_form_query = $db->prepare($new_form_statement);

##----------------------------------------------------------------------------

my $new_field_statement = <<"EOS";
INSERT INTO tblRegoFormFields(
    intRegoFormID,
    strFieldName,
    intType,
    intDisplayOrder,
    strText,
    intStatus
)
VALUES (
    ?,
    ?,
    ?,
    ?,
    ?,
    ?
)
EOS

my $new_field_query = $db->prepare($new_field_statement);

##----------------------------------------------------------------------------

my $update_form_config_statement = <<"EOS";
UPDATE tblRegoFormConfig
SET    intRegoFormID = ?
WHERE  intAssocID = ?
AND    intRealmID = ?
AND    intSubRealmID IN (0, ?)
EOS

my $update_form_config_query = $db->prepare($update_form_config_statement);

##----------------------------------------------------------------------------

my $new_form_config_statement = <<"EOS";
INSERT INTO tblRegoFormConfig (
    intRegoFormID,
    intAssocID,
    intRealmID,
    intSubRealmID,
    strTopText,
    strBottomText,
    strSuccessText,
    strAuthEmailText,
    strIndivRegoSelect,
    strTeamRegoSelect,
    strPaymentText,
    strTermsCondText,
    intTC_AgreeBox
)
VALUES (
    ?,
    ?,
    ?,
    ?,
    ?,
    ?,
    ?,
    ?,
    ?,
    ?,
    ?,
    ?,
    ?
)
EOS

my $new_form_config_query = $db->prepare($new_form_config_statement);

##----------------------------------------------------------------------------

my $update_form_comps_statement = <<"EOS";
UPDATE tblRegoFormComps
SET    intRegoFormID = ?
WHERE  intAssocID = ?
AND    intRealmID = ?
AND    intSubRealmID IN (0, ?)
EOS

my $update_form_comps_query = $db->prepare($update_form_comps_statement);

##----------------------------------------------------------------------------

my $new_form_comps_statement = <<"EOS";
INSERT INTO tblRegoFormComps (
    intRegoFormID,
    intAssocID,
    intRealmID,
    intSubRealmID,
    intCompID
)
VALUES (
    ?,
    ?,
    ?,
    ?,
    ?
)
EOS

my $new_form_comps_query = $db->prepare($new_form_comps_statement);

##----------------------------------------------------------------------------

my $update_form_products_statement = <<"EOS";
UPDATE tblRegoFormProducts
SET    intRegoFormID = ?
WHERE  intAssocID = ?
AND    intRealmID = ?
AND    intSubRealmID IN (0, ?)
EOS

my $update_form_products_query = $db->prepare($update_form_products_statement);

##----------------------------------------------------------------------------

my $new_form_products_statement = <<"EOS";
INSERT INTO tblRegoFormProducts (
    intRegoFormID,
    intAssocID,
    intRealmID,
    intSubRealmID,
    intProductID,
    intRegoTypeLevel
)
VALUES (
    ?,
    ?,
    ?,
    ?,
    ?,
    ?
)
EOS

my $new_form_products_query = $db->prepare($new_form_products_statement);

##----------------------------------------------------------------------------

##============================================================================


my @form_label = (
    q{},
    'Member to Association',
    'Team to Association',
    'Member to Team',
    'Member to Club',
);

my %master_regoform_id;

## - Individual Forms -

$indiv_forms_query->execute();
my $forms = $indiv_forms_query->fetchall_arrayref({});

foreach my $form ( @$forms ) {

    unless ($form->{intSubRealmID}) {
        $form->{intSubRealmID} =
            confirm_subrealm($db, $form->{intAssocID});
    }

    $field_order_query->execute(
        $form->{intAssocID},
        $form->{intRealmID},
        $form->{intSubRealmID},
    );

    $field_label_query->execute(
        $form->{intAssocID},
        $form->{intRealmID},
        $form->{intSubRealmID},
    );

    my $fields = $field_order_query->fetchall_arrayref({});
    my $labels = $field_label_query->fetchall_arrayref({});

    my $default_order = getDefaultOrdering();

    $fields = [
        sort {
            !($a->{intDisplayOrder}) <=> !($b->{intDisplayOrder})
                    or
            $a->{intDisplayOrder} <=> $b->{intDisplayOrder}
                    or
            (($b->{strFieldName} =~ /^RF/) <=>
                ($a->{strFieldName} =~ /^RF/))
                    or
            !($default_order->{$a->{strFieldName}}) <=>
                !($default_order->{$b->{strFieldName}})
                    or
            $default_order->{$a->{strFieldName}} <=>
                $default_order->{$b->{strFieldName}}
                    or
            $a->{strFieldName} cmp $b->{strFieldName}
        } ( @$fields, @$labels )
    ];

    my $config;
    my $comps;
    my $products;


    foreach my $form_type (1 .. 4) {

        next if $form_type == 2; ## Team Forms are handled seperately

        $form->{intRegoFormID} = process_query(
            $new_form_query,
            $form->{intAssocID},
            $form->{intRealmID},
            $form->{intSubRealmID},
            'Imported Form - ' . $form_label[$form_type],
            $form_type,
            ($form_type == 2) ? 2 : 1,
        );

        if ($form_type == 1) {

            my @args = (
                $form->{intRegoFormID},
                $form->{intAssocID},
                $form->{intRealmID},
                $form->{intSubRealmID},
            );

            process_query( $update_form_config_query, @args );
            process_query( $update_form_products_query, @args );

            $master_regoform_id{$form->{intAssocID}}
                = $form->{intRegoFormID};
        }

        populate_regoform(
            $master_regoform_id{$form->{intAssocID}},
            $form->{intRegoFormID},
            $form_type,
            $fields,
        );
    }
}

## - Team Forms -

my $field_order;
my $fields = [
    map { {
        strValue        => 1,
        strFieldName    => $_,
        intDisplayOrder => $field_order++,
    } } ( qw(
        strName
        strNickname
        strContact
        strAddress1
        strAddress2
        strSuburb
        strState
        strCountry
        strPostalCode
        strPhone1
        strPhone2
        strEmail
        strContactName2
        strContactEmail2
        strContactPhone2
        strTeamCustomStr1
        strTeamCustomStr2
        strTeamCustomStr3
        strTeamCustomStr4
        strTeamCustomStr5
        strTeamCustomStr6
        strTeamCustomStr7
        strTeamCustomStr8
        strTeamCustomStr9
        strTeamCustomStr10
        strTeamCustomStr11
        strTeamCustomStr12
        strTeamCustomStr13
        strTeamCustomStr14
        strTeamCustomStr15
        dblTeamCustomDbl1
        dblTeamCustomDbl2
        dblTeamCustomDbl3
        dblTeamCustomDbl4
        dblTeamCustomDbl5
        dblTeamCustomDbl6
        dblTeamCustomDbl7
        dblTeamCustomDbl8
        dblTeamCustomDbl9
        dblTeamCustomDbl10
        dtTeamCustomDt1
        dtTeamCustomDt2
        dtTeamCustomDt3
        dtTeamCustomDt4
        dtTeamCustomDt5
        intTeamCustomLU1
        intTeamCustomLU2
        intTeamCustomLU3
        intTeamCustomLU4
        intTeamCustomLU5
        intTeamCustomLU6
        intTeamCustomLU7
        intTeamCustomLU8
        intTeamCustomLU9
        intTeamCustomLU10
        intTeamCustomBool1
        intTeamCustomBool2
        intTeamCustomBool3
        intTeamCustomBool4
        intTeamCustomBool
    ))
];

$team_forms_query->execute();
$forms = $team_forms_query->fetchall_arrayref({});

foreach my $form ( @$forms ) {

    unless ($form->{intSubRealmID}) {
        $form->{intSubRealmID} =
            confirm_subrealm($db, $form->{intAssocID});
    }

    $form->{intRegoFormID} = process_query(
        $new_form_query,
        $form->{intAssocID},
        $form->{intRealmID},
        $form->{intSubRealmID},
        'Imported Form - Team',
        2,
        2,
    );

    my @args = (
        $form->{intRegoFormID},
        $form->{intAssocID},
        $form->{intRealmID},
        $form->{intSubRealmID},
    );

    process_query( $update_form_comps_query, @args );

    my $from_formID;
    if ($master_regoform_id{$form->{intAssocID}}) {
        $from_formID = $master_regoform_id{$form->{intAssocID}};
    }
    else {
        process_query( $update_form_config_query, @args );
        process_query( $update_form_products_query, @args );
        $from_formID = $form->{intRegoFormID};
    }

    populate_regoform(
        $from_formID,
        $form->{intRegoFormID},
        2,   
        $fields,
    );

}

#=============================================================================

sub generate_copy_form_config_query {

    my($regoFormID) = @_;

    my $copy_form_config_statement = <<"EOS";
INSERT INTO tblRegoFormConfig(
    intRegoFormID,
    intAssocID,
    intRealmID,
    intSubRealmID,
    strTopText,
    strBottomText,
    strSuccessText,
    strAuthEmailText,
    strIndivRegoSelect,
    strTeamRegoSelect,
    strPaymentText,
    strTermsCondText,
    intTC_AgreeBox
)
SELECT  $regoFormID,
        intAssocID,
        intRealmID,
        intSubRealmID,
        strTopText,
        strBottomText,
        strSuccessText,
        strAuthEmailText,
        strIndivRegoSelect,
        strTeamRegoSelect,
        strPaymentText,
        strTermsCondText,
        intTC_AgreeBox
FROM    tblRegoFormConfig
WHERE   intRegoFormID = ?
EOS

    return $db->prepare($copy_form_config_statement);
    
}

sub generate_copy_form_comps_query {

    my($regoFormID) = @_;

    my $copy_form_comps_statement = <<"EOS";
INSERT INTO tblRegoFormComps (
    intRegoFormID,
    intAssocID,
    intRealmID,
    intSubRealmID,
    intCompID
)
SELECT  $regoFormID,
        intAssocID,
        intRealmID,
        intSubRealmID,
        intCompID
FROM    tblRegoFormComps
WHERE   intRegoFormID = ?
EOS

    return $db->prepare($copy_form_comps_statement);
}

sub generate_copy_form_products_query {

    my($regoFormID) = @_;

    my $copy_form_products_statement = <<"EOS";
INSERT INTO tblRegoFormProducts (
    intRegoFormID,
    intAssocID,
    intRealmID,
    intSubRealmID,
    intProductID,
    intRegoTypeLevel
)
SELECT  $regoFormID,
        intAssocID,
        intRealmID,
        intSubRealmID,
        intProductID,
        intRegoTypeLevel
FROM    tblRegoFormProducts
WHERE   intRegoFormID = ?
EOS

    return $db->prepare($copy_form_products_statement);
}

#=============================================================================

sub confirm_subrealm {

    my ( $db, $assocID ) = @_;

    my $get_subrealm_query = $db->prepare(<<"EOS");
SELECT temp.intSubRealmID
FROM (
SELECT intSubRealmID FROM tblRegoFormConfig WHERE intAssocID = $assocID
UNION
SELECT intSubRealmID FROM tblRegoFormProducts WHERE intAssocID = $assocID
) AS temp
ORDER BY intSubRealmID DESC
LIMIT 1
EOS

    $get_subrealm_query->execute();
    my($subRealmID) = $get_subrealm_query->fetchrow_array() || 0;

    return $subRealmID;
}

#=============================================================================

sub populate_regoform {

    my ($from_regoform_id, $to_regoform_id, $form_type, $fields) = @_;

    foreach my $field (@$fields) {

        my $display_order;

        my $fieldname;
        my $fieldtext;

        if ( $field->{strFieldName} =~ /^RF(TEXT|HEADER)(.*)\|(.*)$/) {
            $fieldname = join(q{}, 'RF', $1, $2, '|');
            $fieldtext = $3;
            $field->{intType} = ($1 eq 'HEADER') ? 1 : 2;
        }
        else {
            $fieldname = $field->{strFieldName};
            $fieldtext = q{};
            $field->{intType} = 0;
        }

        process_query(
            $new_field_query,
            $to_regoform_id,
            $fieldname || '',
            $field->{intType} || 0,
            ++$display_order,
            $fieldtext || '',
            $field->{strValue} || ''
        );
    }

    if ($from_regoform_id eq $to_regoform_id) {
        return;
    }

    process_query(
        generate_copy_form_config_query($to_regoform_id),
        $from_regoform_id,
    );

    if ($form_type == 2) {

        process_query(
            generate_copy_form_comps_query($to_regoform_id),
            $from_regoform_id,
        );
    }

    process_query(
        generate_copy_form_products_query($to_regoform_id),
        $from_regoform_id,
    );
}

sub getDefaultOrdering {

    my $i;
    return {
        map { $_ => $i++ } ( qw( 
            strNationalNum
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
            strPlaceofBirth
            intGender
            strAddress1
            strAddress2
            strSuburb
            strCityOfResidence
            strState
            strPostalCode
            strCountry
            strPhoneHome
            strPhoneWork
            strPhoneMobile
            strPager
            strFax
            strEmail
            strEmail2
            SPcontact
            intOccupationID
            intDeceased
            strLoyaltyNumber
            intMailingList
            intFinancialActive
            intMemberPackageID
            curMemberFinBal
            intLifeMember
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
            intPlayer
            intCoach
            intUmpire
            intOfficial
            intMisc
            intVolunteer
            strEmergContName
            strEmergContNo
            strEmergContNo2
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
            strEyeColour
            strHairColour
            intEthnicityID
            strHeight
            strWeight
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
            strMemberCustomNotes1
            strMemberCustomNotes2
            strMemberCustomNotes3
            strMemberCustomNotes4
            strMemberCustomNotes5
            intSchoolID
            strSchoolName
            strSchoolSuburb
            intGradeID
            intFavStateTeamID
            intFavNationalTeamID
            strNotes
            SPdetails
            dtFirstRegistered
            dtLastRegistered
            dtRegisteredUntil
            dtLastUpdate
            dtCreatedOnline
            intHowFoundOutID
            intMedicalConditions
            intAllergies
            intAllowMedicalTreatment
            strMedicalNotes
            intConsentSignatureSighted
            intAttendSportCount
            intWatchSportHowOftenID
            intFavNationalTeamMember
        ))
    };
}

sub process_query {

    my ($query, @args) = @_;

    if ($main::debug) {

        my $no_binds = ($query->{Statement} =~ tr/?/?/);

        if ($no_binds != (scalar(@args))) {
            print "Bind Variable Mismatch with Query: \n" . $query->{Statement};
            exit;
        }

        print $query->{Statement};
        print Dumper(\@args);
        print '-' x 60;
        print "\n";

        return "DEBUG: " . $main::debug_insertid++;
    }

    #print "DANGER!"; exit;
    #print STDERR join(',',@args)."ST $query->{Statement}\n";

    if (!$query->execute(@args)) {
        exit;
    }

    return $query->{mysql_insertid} || 0;
}
