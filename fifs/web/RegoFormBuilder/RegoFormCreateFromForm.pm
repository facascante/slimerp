#
# $Header: svn://svn/SWM/trunk/web/RegoFormCreateFromForm.pm 11662 2014-05-23 04:25:52Z dhanslow $
#

package RegoFormCreateFromForm;
require Exporter;

@ISA =  qw(Exporter);
@EXPORT = qw(create_from_form);
@EXPORT_OK = qw(create_from_form);

use strict;

use lib '.', '..';

use DBI;
use CGI qw(param);
use Defs;
use Utils;


sub get_executed_query {
    my ($Data, $tableName, $formID, $filterFields, $filterProducts, $form) = @_;

    my $dbh = $Data->{'db'};
    my $currentLevel = $Data->{'clientValues'}{'currentLevel'};
    my $assocID = $Data->{'clientValues'}->{'assocID'} || 0;

    my $select = "SELECT $tableName.*";
    my $join   = '';
    my $where  = "WHERE $tableName.intRegoFormID=$formID";

    # copy the regoformfields and regoformrules as follows:
    #   if currentLevel is an assoc, copy the fields including national CFs but excluding any assoc CFs
    #   if currentLevel is a club, copy the fields including national CFs and, if the club belongs to the same assoc, copy the assoc CFs as well.

    if ($filterFields) {
        if (($currentLevel == $Defs::LEVEL_ASSOC) or (($currentLevel == $Defs::LEVEL_CLUB) and ($assocID != $form->{'intAssocID'}))) {
            $where .= qq[ AND (($tableName.strFieldName NOT LIKE '%Custom%') OR ($tableName.strFieldName LIKE '%NatCustom%'))];
        }
    }

    # copy the regoformproducts as follows:
    #   if currentLevel is an assoc, copy only national form products ie exclude assoc and club products
    #   if currentLevel is a club, copy national products and, if the club belongs to the same assoc, copy the assoc products as well. Exclude club products.

    if ($filterProducts) {
        if (($currentLevel == $Defs::LEVEL_ASSOC) or (($currentLevel == $Defs::LEVEL_CLUB) and ($assocID == $form->{'intAssocID'}))) {
            $select .= qq[, tblProducts.intCreatedLevel];
            $join   .= qq[INNER JOIN tblProducts ON $tableName.intProductID=tblProducts.intProductID];
            $where  .= qq[ AND tblProducts.intCreatedlevel>$Defs::LEVEL_ASSOC];
        }
    }

    my $sql = qq[
        $select
        FROM $tableName
        $join
        $where
    ];

    my $query = $dbh->prepare($sql);

    $query->execute();

    return $query;
}


sub create_from_form {
    my ($Data, $copyType, $formID, $clubID) = @_; 

    # set up the initial stuff

    my $currentLevel = $Data->{'clientValues'}{'currentLevel'};
    my $assocID = $Data->{'clientValues'}->{'assocID'} || 0;
    my $dbh = $Data->{'db'};

    $clubID ||= 0;

    if (!$clubID) {
        $clubID = ($currentLevel eq $Defs::LEVEL_CLUB)
            ? $Data->{'clientValues'}->{'clubID'}
            : -1;
    }

    # get the executed queries for the main table

    my $formQuery = get_executed_query($Data, 'tblRegoForm', $formID, 0, 0, undef);
    my $form = $formQuery->fetchrow_hashref();

    # ensure that the source form exists

    my $errmsg = '';

    if (!$form) {
        $errmsg = "Source form #$formID doesn't exist!";
    }
    elsif (($copyType == $Defs::RFCOPYTYPE_TEMPLATE_TO_ASSOC) or ($copyType == $Defs::RFCOPYTYPE_TEMPLATE_TO_CLUB)) {
        if (!$form->{'intTemplate'}) {
            $errmsg = "Form #$formID is not a template!";
        }
    }

    return (-1, $errmsg) if ($errmsg);

    # set filterflags according to copyType 

    my $filterFields   = 0;
    my $filterProducts = 0;

    if (($copyType == $Defs::RFCOPYTYPE_TEMPLATE_TO_ASSOC) or ($copyType == $Defs::RFCOPYTYPE_TEMPLATE_TO_CLUB)) {
        $filterFields   = 1;
        $filterProducts = 1;
    }

    # get the executed queries for all the associated tables

    my $fieldsQuery = get_executed_query($Data, 'tblRegoFormFields', $formID, $filterFields, 0, $form);
    my @fields = @{$fieldsQuery->fetchall_arrayref({})};

    my $configQuery = get_executed_query($Data, 'tblRegoFormConfig', $formID, 0, 0, undef);
    my @config = @{$configQuery->fetchall_arrayref({})};

    my $rulesQuery = get_executed_query($Data, 'tblRegoFormRules', $formID, $filterFields, 0, $form);
    my @rules = @{$rulesQuery->fetchall_arrayref({})};

    my $productsQuery = get_executed_query($Data, 'tblRegoFormProducts', $formID, 0, $filterProducts, $form);
    my @products = @{$productsQuery->fetchall_arrayref({})};

    my $compsQuery = '';
    my @comps = ();

    # copy comps if applicable 

    my $copyComps = 1;

    if (($copyType == $Defs::RFCOPYTYPE_TEMPLATE_TO_ASSOC) or ($copyType == $Defs::RFCOPYTYPE_TEMPLATE_TO_CLUB)) {
        $copyComps = 0 if ($assocID != $form->{'intAssocID'});
    }

    if ($copyComps) {
        $compsQuery = get_executed_query($Data, 'tblRegoFormComps', $formID, 0, 0, undef);
        @comps = @{$compsQuery->fetchall_arrayref({})};
    }

    # set up variables for the form's fields

    my $formName = '';
    $formName    = 'Copy of ' if (($copyType == $Defs::RFCOPYTYPE_WITHIN_ASSOC) or ($copyType == $Defs::RFCOPYTYPE_WITHIN_CLUB));
    $formName   .= $form->{'strRegoFormName'};

    $formName                  = dq($dbh->quote($formName)) || 'NULL';      
    my $formAssocID            = $form->{'intAssocID'};
    my $formRealmID            = $form->{'intRealmID'};
    my $formSubRealmID         = $form->{'intSubRealmID'};
    my $formRegoType           = $form->{'intRegoType'};
    my $formRegoTypeLevel      = $form->{'intRegoTypeLevel'};
    my $formNewRegosAllowed    = $form->{'intNewRegosAllowed'};
    my $formPlayer             = dq($dbh->quote($form->{'ynPlayer'}))        || 'NULL';      
    my $formCoach              = dq($dbh->quote($form->{'ynCoach'}))         || 'NULL';       
    my $formMatchOfficial      = dq($dbh->quote($form->{'ynMatchOfficial'})) || 'NULL';
    my $formOfficial           = dq($dbh->quote($form->{'ynOfficial'}))      || 'NULL';    
    my $formMisc               = dq($dbh->quote($form->{'ynMisc'}))          || 'NULL';        
    my $formVolunteer          = dq($dbh->quote($form->{'ynVolunteer'}))     || 'NULL';        
    my $formMemberRecordTypes  = $form->{'strAllowedMemberRecordTypes'}      || 'NULL';
    my $formStatus             = $form->{'intStatus'};
    my $formLinkedFormID       = $form->{'intLinkedFormID'}       || 0;
    my $formAllowMultipleAdult = $form->{'intAllowMultipleAdult'} || 0;
    my $formAllowMultipleChild = $form->{'intAllowMultipleChild'} || 0;
    my $formPreventTypeChange  = $form->{'intPreventTypeChange'}  || 0;
    my $formAllowClubSelection = $form->{'intAllowClubSelection'} || 0;
    my $formClubMandatory      = $form->{'intClubMandatory'}      || 0;
    my $formNewBits            = $form->{'intNewBits'}            || 0;
    my $formRenewalBits        = $form->{'intRenewalBits'}        || 0;
    my $formPaymentBits        = $form->{'intPaymentBits'}        || 0;

    # set up the db stuff for the regoform

    my $insertFormSQL = qq[
        INSERT INTO tblRegoForm (
            intAssocID,
            intRealmID,
            intSubRealmID,
            intClubID,
            strRegoFormName,
            intRegoType,
            intRegoTypeLevel,
            intNewRegosAllowed,
            ynPlayer,
            ynCoach,
            ynMatchOfficial,
            ynOfficial,
            ynMisc,
            ynVolunteer,
            strAllowedMemberRecordTypes,
            intStatus,
            intLinkedFormID,
            intAllowMultipleAdult,
            intAllowMultipleChild,
            intPreventTypeChange,
            intAllowClubSelection,
            intClubMandatory,
            intNewBits,
            intRenewalBits,
            intPaymentBits,
            dtCreated
        )
        VALUES (
            $assocID,
            $formRealmID,
            $formSubRealmID,
            $clubID,
            $formName,
            $formRegoType,         
            $formRegoTypeLevel,
            $formNewRegosAllowed,
            $formPlayer,
            $formCoach,
            $formMatchOfficial,
            $formOfficial,
            $formMisc,
            $formVolunteer,
            $formMemberRecordTypes,
            $formStatus,
            $formLinkedFormID,
            $formAllowMultipleAdult,
            $formAllowMultipleChild,
            $formPreventTypeChange,
            $formAllowClubSelection,
            $formClubMandatory,
            $formNewBits,
            $formRenewalBits,
            $formPaymentBits,
            NOW()
        )
    ];
warn $insertFormSQL;
    my $insertFormQuery = $dbh->prepare($insertFormSQL);

    # set up the db stuff for the regoformfields

    my $insertFieldsSQL = qq[
        INSERT INTO tblRegoFormFields (
            intRegoFormID,
            strFieldName,
            intType,
            intDisplayOrder,
            strText,
            intStatus,
            strPerm
        )
        VALUES (
            ?,
            ?,
            ?,
            ?,
            ?,
            ?,
            ?
        )
    ];

    my $insertFieldsQuery = $dbh->prepare($insertFieldsSQL);

    # set up the db stuff for the regoformconfig
                   
    my $insertConfigSQL = qq[
        INSERT INTO tblRegoFormConfig (
            intRegoFormID,
            intAssocID,
            intRealmID,
            intSubRealmID,
            strPageOneText,
            strTopText,
            strBottomText,
            strSuccessText,
            strAuthEmailText,
            strIndivRegoSelect,
            strTeamRegoSelect,
            strPaymentText,
            strTermsCondHeader,
            strTermsCondText,
            intTC_AgreeBox
        )
        VALUES (
            ?,
            $assocID,    
            $formRealmID, 
            $formSubRealmID,
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
    ];

    my $insertConfigQuery = $dbh->prepare($insertConfigSQL);

    # set up the sb fields for the regoformrules

    my $insertRulesSQL = qq[
        INSERT INTO tblRegoFormRules (
            intRegoFormID,
            intRegoFormFieldID,
	    strFieldName,
            strGender,
            dtMinDOB,
            dtMaxDOB,
            ynPlayer,
            ynCoach,
            ynMatchOfficial,
            ynOfficial,
            ynMisc,
            ynVolunteer,
            intStatus
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
    ];

    my $insertRulesQuery = $dbh->prepare($insertRulesSQL);

    # set up the db stuff for the regoformproducts

    my $insertProductsSQL = qq[
        INSERT INTO tblRegoFormProducts (
            intRegoFormID,
            intAssocID,
            intRealmID,
            intSubRealmID,
            intProductID,
            intRegoTypeLevel,
            intIsMandatory
        )
        VALUES (
            ?,
            $assocID,
            $formRealmID,
            $formSubRealmID,
            ?,
            ?,
            ?
        )
    ];

    my $insertProductsQuery = $dbh->prepare($insertProductsSQL);

    # set up the db stuff for the regoformcomps

    my $insertCompsQuery = '';

    if (($currentLevel eq $Defs::LEVEL_CLUB) and ($assocID eq $form->{'intAssocID'})) {
        my $insertCompsSQL = qq[
            INSERT INTO tblRegoFormComps (
                intRegoFormID,
                intAssocID,
                intRealmID,
                intSubRealmID,
                intCompID
            )
            VALUES (
                ?,
                $assocID,
                $formRealmID,
                $formSubRealmID,
                ?
            )
        ];

        $insertCompsQuery = $dbh->prepare($insertCompsSQL);
    }

    # insert the new regoform and get the id

    $insertFormQuery->execute();
                                                 
    my $newFormID = $insertFormQuery->{mysql_insertid};

    # insert the regoformfields

    foreach my $field (@fields) {
        $insertFieldsQuery->execute(
            $newFormID,
            $field->{'strFieldName'},
            $field->{'intType'},
            $field->{'intDisplayOrder'},
            $field->{'strText'},
            $field->{'intStatus'},
            $field->{'strPerm'},
        );
    }

    # insert the regoformconfig

    foreach my $config (@config) {
        $insertConfigQuery->execute(
            $newFormID,
            $config->{'strPageOneText'},
            $config->{'strTopText'},
            $config->{'strBottomText'},
            $config->{'strSuccessText'},
            $config->{'strAuthEmailText'},
            $config->{'strIndivRegoSelect'},
            $config->{'strTeamRegoSelect'},
            $config->{'strPaymentText'},
            $config->{'strTermsCondHeader'},
            $config->{'strTermsCondText'},
            $config->{'intTC_AgreeBox'},
        );
    }

    # insert the regoformrules

    foreach my $rule (@rules) {

	my $ruleLookup = qq[
                SELECT intRegoFormFieldID
                FROM tblRegoFormFields
                WHERE strFieldName = "$rule->{'strFieldName'}"
		AND intRegoFormID= $newFormID;
        ];
        my $rule_query = $dbh->prepare($ruleLookup) or query_error($ruleLookup);
    	$rule_query->execute or query_error($ruleLookup);
        my $aref = $rule_query->fetchrow_hashref();
	my $intRegoFormFieldID = $aref->{intRegoFormFieldID};

        $insertRulesQuery->execute(
            $newFormID,
            $intRegoFormFieldID,
	    $rule->{'strFieldName'},
            $rule->{'strGender'},
            $rule->{'dtMinDOB'},
            $rule->{'dtMaxDOB'},
            $rule->{'ynPlayer'},
            $rule->{'ynCoach'},
            $rule->{'ynMatchOfficial'},
            $rule->{'ynOfficial'},
            $rule->{'ynMisc'},
            $rule->{'ynVolunteer'},
            $rule->{'intStatus'},
        );

    }

    # insert the regoformproducts

    foreach my $product (@products) {
        $insertProductsQuery->execute(
            $newFormID,
            $product->{'intProductID'},
            $product->{'intRegoTypeLevel'},
            $product->{'intIsMandatory'},
        );
    }

    # insert the regoformcomps

    if (($currentLevel eq $Defs::LEVEL_CLUB) and ($assocID eq $form->{'intAssocID'})) {
        foreach my $comp (@comps) {
            $insertCompsQuery->execute(
                $newFormID,
                $comp->{'intCompID'},
            );
        }
    }

    # finalise all the queries

    $formQuery->finish;
    $fieldsQuery->finish;
    $configQuery->finish;
    $rulesQuery->finish;
    $productsQuery->finish;

    if (($currentLevel eq $Defs::LEVEL_CLUB) and ($assocID eq $form->{'intAssocID'})) {
        $compsQuery->finish;
    }

    my $torf = ($form->{'intTemplate'})
        ? "template"
        : "form";

    return ($newFormID, "Form #$newFormID successfully created from $torf #$formID");
}

sub dq {
    my $str = shift;
    $str =~ s/^'(.*)'$/"$1"/g;
    return $str;
}


1;
