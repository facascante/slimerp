#
# $Header: svn://svn/SWM/trunk/web/RegoFormCreateFromTemplate.pm 10771 2014-02-21 00:20:57Z cgao $
#

package RegoFormCreateFromTemplate;
require Exporter;

@ISA =  qw(Exporter);
@EXPORT = qw(create_from_template);
@EXPORT_OK = qw(create_from_template);

use strict;

use lib '.', '..';

use DBI;
use CGI qw(param unescape escape);
use Defs;
use Utils;


sub get_executed_query {
    my ($Data, $tableName, $templateID, $filterFields, $filterProducts, $template) = @_;

    my $dbh = $Data->{'db'};
    my $currentLevel = $Data->{'clientValues'}{'currentLevel'};
    my $assocID = $Data->{'clientValues'}->{'assocID'} || 0;

    my $select = "SELECT $tableName.*";
    my $join   = '';
    my $where  = "WHERE $tableName.intRegoFormID=$templateID";

    # copy the regoformfields and regoformrules as follows:
    #   if currentLevel is an assoc, copy the fields including national CFs but excluding any assoc CFs
    #   if currentLevel is a club, copy the fields including national CFs and, if the club belongs to the same assoc, copy the assoc CFs as well.

    if ($filterFields) {
        if (($currentLevel eq $Defs::LEVEL_ASSOC) or (($currentLevel eq $Defs::LEVEL_CLUB) and ($assocID ne $template->{'intAssocID'}))) {
            $where .= qq[ AND (($tableName.strFieldName NOT LIKE '%Custom%') OR ($tableName.strFieldName LIKE '%NatCustom%'))];
        }
    }

    # copy the regoformproducts as follows:
    #   if currentLevel is an assoc, copy only national form products ie exclude assoc and club products
    #   if currentLevel is a club, copy national products and, if the club belongs to the same assoc, copy the assoc products as well. Exclude club products.

    if ($filterProducts) {
        if (($currentLevel eq $Defs::LEVEL_ASSOC) or (($currentLevel eq $Defs::LEVEL_CLUB) and ($assocID eq $template->{'intAssocID'}))) {
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


sub create_from_template {
    my ($Data, $templateID) = @_;

    # set up the initial stuff

    my $currentLevel = $Data->{'clientValues'}{'currentLevel'};
    my $assocID = $Data->{'clientValues'}->{'assocID'} || 0;
    my $dbh = $Data->{'db'};

    my $clubID = ($currentLevel eq $Defs::LEVEL_CLUB)
        ? $Data->{'clientValues'}->{'clubID'}
        : -1;

    # get the executed queries for the main table

    my $templateQuery = get_executed_query($Data, 'tblRegoForm', $templateID, 0, 0, undef);
    my $template = $templateQuery->fetchrow_hashref();

    # ensure that a record is returned  and that is, in fact, a template

    my $errmsg = '';

    if (!$template) {
        $errmsg = "Template #$templateID doesn't exist!";
    }
    elsif (!$template->{'intTemplate'}) {
        $errmsg = "Template #$templateID is not a template!";
    }

    return (-1, $errmsg) if ($errmsg);

    # get the executed queries for all the associated tables

    my $fieldsQuery = get_executed_query($Data, 'tblRegoFormFields', $templateID, 1, 0, $template);
    my @fields = @{$fieldsQuery->fetchall_arrayref({})};

    my $configQuery = get_executed_query($Data, 'tblRegoFormConfig', $templateID, 0, 0, undef);
    my @config = @{$configQuery->fetchall_arrayref({})};

    my $rulesQuery = get_executed_query($Data, 'tblRegoFormRules', $templateID, 1, 0, $template);
    my @rules = @{$rulesQuery->fetchall_arrayref({})};

    my $productsQuery = get_executed_query($Data, 'tblRegoFormProducts', $templateID, 0, 1, $template);
    my @products = @{$productsQuery->fetchall_arrayref({})};

    my $compsQuery = '';
    my @comps = ();

    if (($currentLevel eq $Defs::LEVEL_CLUB) and ($assocID eq $template->{'intAssocID'})) {
        $compsQuery = get_executed_query($Data, 'tblRegoFormComps', $templateID, 0, 0, undef);
        @comps = @{$compsQuery->fetchall_arrayref({})};
    }

    # set up variables for all the template fields

    my $tName               = dq($dbh->quote($template->{'strRegoFormName'})) || 'NULL';      
    my $tAssocID            = $template->{'intAssocID'};
    my $tRealmID            = $template->{'intRealmID'};
    my $tSubRealmID         = $template->{'intSubRealmID'};
    my $tRegoType           = $template->{'intRegoType'};
    my $tRegoTypeLevel      = $template->{'intRegoTypeLevel'};
    my $tNewRegosAllowed    = $template->{'intNewRegosAllowed'};
    my $tPlayer             = dq($dbh->quote($template->{'ynPlayer'}))        || 'NULL';      
    my $tCoach              = dq($dbh->quote($template->{'ynCoach'}))         || 'NULL';       
    my $tMatchOfficial      = dq($dbh->quote($template->{'ynMatchOfficial'})) || 'NULL';
    my $tOfficial           = dq($dbh->quote($template->{'ynOfficial'}))      || 'NULL';    
    my $tMisc               = dq($dbh->quote($template->{'ynMisc'}))          || 'NULL';        
    my $tVolunteer          = dq($dbh->quote($template->{'ynVolunteer'}))     || 'NULL';        
    my $tStatus             = $template->{'intStatus'};
    my $tLinkedFormID       = $template->{'intLinkedFormID'}       || 0;
    my $tAllowMultipleAdult = $template->{'intAllowMultipleAdult'} || 0;
    my $tAllowMultipleChild = $template->{'intAllowMultipleChild'} || 0;
    my $tPreventTypeChange  = $template->{'intPreventTypeChange'}  || 0;
    my $tAllowClubSelection = $template->{'intAllowClubSelection'} || 0;
    my $tClubMandatory      = $template->{'intClubMandatory'}      || 0;
    my $tNewBits            = $template->{'intNewBits'}            || 0;
    my $tRenewalBits        = $template->{'intRenewalBits'}        || 0;
    my $tPaymentBits        = $template->{'intPaymentBits'}        || 0;

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
            $tRealmID,
            $tSubRealmID,
            $clubID,
            $tName,
            $tRegoType,         
            $tRegoTypeLevel,
            $tNewRegosAllowed,
            $tPlayer,
            $tCoach,
            $tMatchOfficial,
            $tOfficial,
            $tMisc,
            $tVolunteer,
            $tStatus,
            $tLinkedFormID,
            $tAllowMultipleAdult,
            $tAllowMultipleChild,
            $tPreventTypeChange,
            $tAllowClubSelection,
            $tClubMandatory,
            $tNewBits,
            $tRenewalBits,
            $tPaymentBits,
            NOW()
        )
    ];

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
            $tRealmID, 
            $tSubRealmID,
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
            $tRealmID,
            $tSubRealmID,
            ?,
            ?,
            ?
        )
    ];

    my $insertProductsQuery = $dbh->prepare($insertProductsSQL);

    # set up the db stuff for the regoformcomps

    my $insertCompsQuery = '';

    if (($currentLevel eq $Defs::LEVEL_CLUB) and ($assocID eq $template->{'intAssocID'})) {
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
                $tRealmID,
                $tSubRealmID,
                ?
            )
        ];

        $insertCompsQuery = $dbh->prepare($insertCompsSQL);
    }

    # insert the new regoform and get the id

    $insertFormQuery->execute();
                                                 
    my $regoFormID = $insertFormQuery->{mysql_insertid};

    # insert the regoformfields

    foreach my $field (@fields) {
        $insertFieldsQuery->execute(
            $regoFormID,
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
            $regoFormID,
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
                AND intRegoFormID= $regoFormID;
        ];
        my $rule_query = $dbh->prepare($ruleLookup) or query_error($ruleLookup);
        $rule_query->execute or query_error($ruleLookup);
        my $aref = $rule_query->fetchrow_hashref();
        my $intRegoFormFieldID = $aref->{intRegoFormFieldID};



    $insertRulesQuery->execute(
            $regoFormID,
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
            $regoFormID,
            $product->{'intProductID'},
            $product->{'intRegoTypeLevel'},
            $product->{'intIsMandatory'},
        );
    }

    # insert the regoformcomps

    if (($currentLevel eq $Defs::LEVEL_CLUB) and ($assocID eq $template->{'intAssocID'})) {
        foreach my $comp (@comps) {
            $insertCompsQuery->execute(
                $regoFormID,
                $comp->{'intCompID'},
            );
        }
    }

    # finalise all the queries

    $templateQuery->finish;
    $fieldsQuery->finish;
    $configQuery->finish;
    $rulesQuery->finish;
    $productsQuery->finish;
    if (($currentLevel eq $Defs::LEVEL_CLUB) and ($assocID eq $template->{'intAssocID'})) {
        $compsQuery->finish;
    }

    return ($regoFormID, "Form #$regoFormID successfully created from Template #$templateID");
}

sub dq {
    my $str = shift;
    $str =~ s/^'(.*)'$/"$1"/g;
    return $str;
}


1;
