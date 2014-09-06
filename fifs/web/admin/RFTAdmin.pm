#
# $Header: svn://svn/SWM/trunk/web/admin/RFTAdmin.pm 10771 2014-02-21 00:20:57Z cgao $
#

package RFTAdmin;

require Exporter;
@ISA =  qw(Exporter);
@EXPORT = qw(handle_template);
@EXPORT_OK = qw(handle_template);

use lib "..","../..","../sp_publisher","../comp";
use DBI;
use CGI qw(param unescape escape);
use strict;
use Defs;
use Utils;
use AdminCommon;
use DeQuote;
use FormHelpers;
use HTMLForm;


sub handle_template {
    my ($action, $Data) = @_;
warn($action);
    my $resultHTML   = '';

    if ($action =~/^RFT_add/) {
        add_template($Data);
        $resultHTML = show_template($Data);
    }
    elsif ($action =~/^RFT_edit/) {
        edit_template($Data);
        $resultHTML = show_template($Data);
    }
    elsif ($action =~/^RFT_delete/) {
        delete_template($Data);
        $resultHTML = list_templates($Data);
    }
    elsif ($action =~/^RFT_updnew/) {
        update_new_template($Data);
        $resultHTML = show_template($Data);
    }
    elsif ($action =~/^RFT_updedit/) {
        update_edit_template($Data);
        $resultHTML = show_template($Data);
    }
    elsif ($action =~/^RFT_list/) {
        $resultHTML = list_templates($Data);
    }
    else {
        $resultHTML = show_search($Data);
    }

  return $resultHTML;
}


sub show_search {
    my ($Data) = @_;

    my $realms = getRealms($Data->{'db'});

    my $resultHTML = qq[
        <div class="pageHeading" style="padding-left:22px">Template Search</div>
        <br>
        <form action="$Data->{'target'}" method="post">
          <table style="margin-left:20px; margin-right:auto">
            <tr>
              <td class="label">Template Name:</td>
              <td class="value"><input type="text" name="templateName" size="50"></td>
            </tr>
            <tr>
              <td class="label">Realm:</td>
              <td class="value">$realms</td>
            </tr>
            <tr><td><input type="submit" name="submit" value="Search"></td></tr>
          </table>
          <input type="hidden" name="a" value="RFT_list">
        </form>
    ];

    return $resultHTML;
}


sub getRealms {
    my ($dbh) = @_;

    my $sql = qq[ 
        SELECT intRealmID, strRealmName 
        FROM tblRealms 
        ORDER BY strRealmName
    ];

  return getDBdrop_down('realmID', $dbh, $sql, '', '&nbsp;') || '';
}


sub show_template {
    my ($Data) = @_;

    my $tID         = 0;
    my $tName       = '';
    my $tSourceID   = ''; 
    my $tLevel      = ''; 
    my $tEntityID   = ''; 
    my $tExpiryDate = ''; 
    my $errmsg      = '';
    my $action      = '';

    if ($Data->{'templateValues'}{'name'}) {
        $tID         = $Data->{'templateValues'}{'ID'};
        $tName       = $Data->{'templateValues'}{'name'};
        $tSourceID   = $Data->{'templateValues'}{'sourceID'};
        $tLevel      = $Data->{'templateValues'}{'level'};
        $tEntityID   = $Data->{'templateValues'}{'entityID'};
        $tExpiryDate = $Data->{'templateValues'}{'expiryDate'};
        $action      = $Data->{'templateValues'}{'action'};
        if ($Data->{'templateValues'}{'errmsg'}) {
            my $msgclass = ($Data->{'templateValues'}{'errind'})
                ? "warningmsg"
                : "OKmsg";
            $errmsg = qq[
                <div class="$msgclass" style="width:500px">$Data->{'templateValues'}{'errmsg'}</div>
            ];
        }
    }

    $action ||= 'add';

    my $sourceID = '';
    my $subVal   = '';
    my $aVal     = '';

    if ($action eq 'add') {
        $sourceID = qq[
            <tr>
              <td class="label"><label for="tSourceID">Source Form ID</label>:</td>
              <td class="value">
                <input type="text" name="tSourceID" value="$tSourceID" id="tSourceID" maxlength="10" style="width:115px">
                <img src="images/compulsory.gif" alt="Compulsory Field" title="Compulsory Field">
              </td>
            </tr>
        ];
        $subVal = 'Add';
        $aVal   = 'RFT_updnew';
    }
    else {
        $subVal = 'Update';
        $aVal   = 'RFT_updedit';
    }

    $subVal .= ' Template';

    my %levelNames = ();  
    for my $i (keys %Defs::LevelNames) {
        if (($i > $Defs::LEVEL_MEMBER) and ($i <= $Defs::LEVEL_NATIONAL) and ($i >= $Defs::LEVEL_ASSOC)) {
            $levelNames{$i} = $Defs::LevelNames{$i};
        }
    }

    my @order = (qw(100 30 20 10 5));
    my $levelNamesdd = drop_down('tLevel', \%levelNames, \@order, $tLevel, 1, 0, 'margin-left:3px;margin-right:3px');

    my $resultHTML = qq[
        <link rel="stylesheet" type="text/css" href="../js/jquery-ui/css/redmond/jquery-ui-1.7.2.custom.css">
        <script type="text/javascript" src="http://ajax.aspnetcdn.com/ajax/jQuery/jquery-1.6.3.min.js"></script>
        <script type="text/javascript" src="http://ajax.aspnetcdn.com/ajax/jquery.validate/1.8.1/jquery.validate.min.js"></script>
        <script type="text/javascript" src="../js/jquery-ui/js/jquery-ui-1.7.2.custom.min.js"></script>

        <script type="text/javascript">
          \$().ready(function() {
              \$("#frmTemplate").validate({
                  rules: {
                      tName: "required",
                      tLevel: "required",
                      tSourceID: {required: true, digits: true},
                      tEntityID: {required: true, digits: true}
                  }
              });
          });
        </script>

		<script type="text/javascript">
		  \$().ready(function() {
		  	\$("#tExpiryDate").datepicker({ 
              dateFormat: 'dd/mm/yy',
              showButtonPanel: true,
              minDate: -1
            });
		  });
		</script>

        <div class="pageHeading" style="padding-left:22px">Add Template</div>
        $errmsg
        <form action="$Data->{'target'}" name="frmTemplate" id="frmTemplate" method="POST" style="margin-left:22px">    
        <p class="introtext">
          <b>Note:</b> All boxes marked with <img src="images/compulsory.gif" alt="Compulsory Field" title="Compulsory Field"/> must be completed.
        </p>
        <table cellpadding="2" cellspacing="0" border="0" >
          <tbody id="secmain">              
            <tr>
              <td class="label"><label for="tName">Template Name</label>:</td>
              <td class="value">
                <input type="text" name="tName" value="$tName" id="tName" size="40" maxlength="60">
                <img src="images/compulsory.gif" alt="Compulsory Field" title="Compulsory Field">
              </td>
            </tr>
            $sourceID
            <tr>
              <td class="label"><label for="level">Level</label>:</td>
              <td class="value">
                $levelNamesdd
                <img src="images/compulsory.gif" alt="Compulsory Field" title="Compulsory Field">
              </td>
            </tr>
            <tr>
              <td class="label"><label for="level">Entity ID</label>:</td>
              <td class="value">
                <input type="text" name="tEntityID" value="$tEntityID" id="tEntityID" maxlength="10" style="width:115px">
                <img src="images/compulsory.gif" alt="Compulsory Field" title="Compulsory Field">
              </td>
            </tr>
            <tr>
              <td class="label"><label for="tExpiryDate">Expiry Date</label>:</td>
              <td class="value">
                <input type="text" name="tExpiryDate" value="$tExpiryDate" id="tExpiryDate" maxlength="10" style="width:115px" readonly="yes">
              </td>
            </tr>
          </tbody>
        </table>
        <div class="HTbuttons">
          <input type="submit" name="subbut" value="$subVal" class="HF_submit" id="HFsubbut" style="margin-left:12px">
          <input type="hidden" name="a" value="$aVal">
          <input type="hidden" name="tID" value="$tID">
        </div>
        </form>
    ];

    return $resultHTML;
}


sub update_new_template {
    my ($Data) = @_;

    my $dbh = $Data->{'db'};

    my $tName       = param('tName')       || '';
    my $tSourceID   = param('tSourceID')   || 0;
    my $tLevel      = param('tLevel')      || '';
    my $tEntityID   = param('tEntityID')   || 0;
    my $tExpiryDate = param('tExpiryDate') || 0;

    create_templateValues($Data);
    $Data->{'templateValues'}{'name'}       = $tName;
    $Data->{'templateValues'}{'sourceID'}   = $tSourceID;
    $Data->{'templateValues'}{'level'}      = $tLevel;
    $Data->{'templateValues'}{'entityID'}   = $tEntityID;
    $Data->{'templateValues'}{'expiryDate'} = $tExpiryDate;

    my $errmsg = '';

    my $getSourceFormSQL = qq[
        SELECT *
        FROM tblRegoForm
        WHERE intRegoFormID=$tSourceID
        LIMIT 1
    ];

    my $getSourceFormQuery = $dbh->prepare($getSourceFormSQL);
    $getSourceFormQuery->execute;

    my $sourceForm = $getSourceFormQuery->fetchrow_hashref();

    if (!$sourceForm) {
        $errmsg = "Source Form ID specified doesn't exist!";
    }
    elsif ($sourceForm->{'intTemplate'}) {
        $errmsg = "Source Form ID specified is already a template!";
    }

    if (!$errmsg) {
       $errmsg = validate_entity($tLevel, $tEntityID, $sourceForm->{'intRealmID'}, $sourceForm->{'intSubRealmID'}, $dbh);
    }

    if ($errmsg) {
        $Data->{'templateValues'}{'action'} = 'add';
        $Data->{'templateValues'}{'errmsg'} = $errmsg;
        $Data->{'templateValues'}{'errind'} = 1;
        return;
    }

#----------------------------------------------------------------------------------------------

    my $getFieldsSQL = qq[
        SELECT *
        FROM tblRegoFormFields
        WHERE intRegoFormID = $tSourceID
    ];

    my $getFieldsQuery = $dbh->prepare($getFieldsSQL);
    $getFieldsQuery->execute();

    my @fields = @{ $getFieldsQuery->fetchall_arrayref({}) };

    my $getConfigSQL = qq[
        SELECT *
        FROM tblRegoFormConfig
        WHERE intRegoFormID = $tSourceID
    ];

    my $getConfigQuery = $dbh->prepare($getConfigSQL);
    $getConfigQuery->execute();

    my @config = @{ $getConfigQuery->fetchall_arrayref({}) };

    my $getRulesSQL = qq[
        SELECT *
        FROM tblRegoFormRules
        WHERE intRegoFormID = $tSourceID
    ];

    my $getRulesQuery = $dbh->prepare($getRulesSQL);
    $getRulesQuery->execute();

    my @rules = @{ $getRulesQuery->fetchall_arrayref({}) };

#----------------------------------------------------------------------------------------------

    my $getProductsSQL = qq[
        SELECT *
        FROM tblRegoFormProducts
        WHERE intRegoFormID = $tSourceID
    ];

    my $getProductsQuery = $dbh->prepare($getProductsSQL);
    $getProductsQuery->execute();

    my @products = @{ $getProductsQuery->fetchall_arrayref({}) };

#----------------------------------------------------------------------------------------------

    my $getCompsSQL = qq[
        SELECT *
        FROM tblRegoFormComps
        WHERE intRegoFormID = $tSourceID
    ];

    my $getCompsQuery = $dbh->prepare($getCompsSQL);
    $getCompsQuery->execute();

    my @comps = @{ $getCompsQuery->fetchall_arrayref({}) };

#----------------------------------------------------------------------------------------------

    my $sfAssocID            = $sourceForm->{'intAssocID'};
    my $sfRealmID            = $sourceForm->{'intRealmID'};
    my $sfSubRealmID         = $sourceForm->{'intSubRealmID'};
    my $sfRegoType           = $sourceForm->{'intRegoType'};
    my $sfRegoTypeLevel      = $sourceForm->{'intRegoTypeLevel'};
    my $sfNewRegosAllowed    = $sourceForm->{'intNewRegosAllowed'};
    my $sfPlayer             = dq($dbh->quote($sourceForm->{'ynPlayer'}))        || 'NULL';      
    my $sfCoach              = dq($dbh->quote($sourceForm->{'ynCoach'}))         || 'NULL';       
    my $sfMatchOfficial      = dq($dbh->quote($sourceForm->{'ynMatchOfficial'})) || 'NULL';
    my $sfOfficial           = dq($dbh->quote($sourceForm->{'ynOfficial'}))      || 'NULL';    
    my $sfMisc               = dq($dbh->quote($sourceForm->{'ynMisc'}))          || 'NULL';        
    my $sfVolunteer          = dq($dbh->quote($sourceForm->{'ynVolunteer'}))     || 'NULL';        
    my $sfStatus             = $sourceForm->{'intStatus'};
    my $sfAllowMultipleAdult = $sourceForm->{'intAllowMultipleAdult'} || 0;
    my $sfAllowMultipleChild = $sourceForm->{'intAllowMultipleChild'} || 0;
    my $sfPreventTypeChange  = $sourceForm->{'intPreventTypeChange'}  || 0;
    my $sfAllowClubSelection = $sourceForm->{'intAllowClubSelection'} || 0;
    my $sfClubMandatory      = $sourceForm->{'intClubMandatory'}      || 0;
    my $sfNewBits            = $sourceForm->{'intNewBits'}            || 0;
    my $sfRenewalBits        = $sourceForm->{'intRenewalBits'}        || 0;
    my $sfPaymentBits        = $sourceForm->{'intPaymentBits'}        || 0;

#----------------------------------------------------------------------------------------------

    my $createTemplateSQL = qq[
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
            dtCreated,
            intTemplate,
            intTemplateLevel,
            intTemplateSourceID,
            intTemplateAssocID,
            intTemplateEntityID,
            dtTemplateExpiry
        )
        VALUES (
            0,
            $sfRealmID,
            $sfSubRealmID,
            0,
            "$tName",
            $sfRegoType,         
            $sfRegoTypeLevel,
            $sfNewRegosAllowed,
            $sfPlayer,
            $sfCoach,
            $sfMatchOfficial,
            $sfOfficial,
            $sfMisc,
            $sfVolunteer,
            $sfStatus,
            0,
            $sfAllowMultipleAdult,
            $sfAllowMultipleChild,
            $sfPreventTypeChange,
            $sfAllowClubSelection,
            $sfClubMandatory,
            $sfNewBits,
            $sfRenewalBits,
            $sfPaymentBits,
            NOW(),
            1,
            $tLevel,
            $tSourceID,
            $sfAssocID,
            $tEntityID,
            STR_TO_DATE('$tExpiryDate', '%d/%m/%Y')
        )
    ];

    my $createTemplateQuery = $dbh->prepare($createTemplateSQL);

#----------------------------------------------------------------------------------------------

    my $createFieldsSQL = qq[
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

    my $createFieldsQuery = $dbh->prepare($createFieldsSQL);

#----------------------------------------------------------------------------------------------

    my $createConfigSQL = qq[
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
            0,
            $sfRealmID,
            $sfSubRealmID,
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

    my $createConfigQuery = $dbh->prepare($createConfigSQL);

#----------------------------------------------------------------------------------------------

    my $createRulesSQL = qq[
        INSERT INTO tblRegoFormRules (
            intRegoFormID,
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
            ?
        )
    ];

    my $createRulesQuery = $dbh->prepare($createRulesSQL);

#----------------------------------------------------------------------------------------------

    my $createProductsSQL = qq[
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
            0,
            $sfRealmID,
            $sfSubRealmID,
            ?,
            ?,
            ?
        )
    ];

    my $createProductsQuery = $dbh->prepare($createProductsSQL);

#----------------------------------------------------------------------------------------------

    my $createCompsSQL = qq[
        INSERT INTO tblRegoFormComps (
            intRegoFormID,
            intAssocID,
            intRealmID,
            intSubRealmID,
            intCompID
        )
        VALUES (
            ?,
            0,
            $sfRealmID,
            $sfSubRealmID,
            ?
        )
    ];

    my $createCompsQuery = $dbh->prepare($createCompsSQL);

#----------------------------------------------------------------------------------------------
    $createTemplateQuery->execute();

    my $tID = $createTemplateQuery->{mysql_insertid};

    foreach my $field (@fields) {
        $createFieldsQuery->execute(
            $tID,
            $field->{'strFieldName'},
            $field->{'intType'},
            $field->{'intDisplayOrder'},
            $field->{'strText'},
            $field->{'intStatus'},
            $field->{'strPerm'},
        );
    }

    foreach my $config (@config) {
        $createConfigQuery->execute(
            $tID,
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

    foreach my $rule (@rules) {
        $createRulesQuery->execute(
            $tID,
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

    foreach my $product (@products) {
        $createProductsQuery->execute(
            $tID,
            $product->{'intProductID'},
            $product->{'intRegoTypeLevel'},
            $product->{'intIsMandatory'},
        );
    }

    foreach my $comp (@comps) {
        $createCompsQuery->execute(
            $tID,
            $comp->{'intCompID'},
        );
    }

#----------------------------------------------------------------------------------------------

    $getSourceFormQuery->finish;
    $getFieldsQuery->finish;
    $getConfigQuery->finish;
    $getRulesQuery->finish;
    $getProductsQuery->finish;
    $getCompsQuery->finish;

    $Data->{'templateValues'}{'ID'}     = $tID;
    $Data->{'templateValues'}{'action'} = 'edit';
    $Data->{'templateValues'}{'errmsg'} = "Template $tID successfully added";

    return;
}


sub validate_entity {
    my ($tLevel, $tEntityID, $sfRealmID, $sfSubRealmID, $dbh) = @_;

# The levels coming through will be one of National, State,Region, Zone and#Assoc

# If an assoc,
#     => the resultant tblAssoc RealmID must be the same as that on the original form
#     => the resultant tblAssoc AssocTypeID must be the same as the SubRealm on the original form
#
# If not an assoc,
#     => select the node from the tblNode
#     => the resultant tblNode RealmID and SubTypeID must be the same as those on the original form
#     => the resultant tblNode TypeID must correspond to the template level specified

    my $sql = '';
    my $query = '';
    my $errmsg = '';

    if ($tLevel eq $Defs::LEVEL_ASSOC) {
        $sql = qq[
            SELECT 5, intRealmID, intAssocTypeID
            FROM tblAssoc
            WHERE intAssocID=$tEntityID
        ];
    }
    else {
        $sql = qq[
            SELECT intTypeID, intRealmID, intSubTypeID
            FROM tblNode
            WHERE intNodeID=$tEntityID
        ];
    }
    $query = $dbh->prepare($sql);
    $query->execute();

    my ($typeID, $realmID, $subRealmID) = $query->fetchrow_array();
    $query->finish;

    $typeID     ||= 0;
    $realmID    ||= 0;
    $subRealmID ||= 0;

    if ($typeID ne $tLevel) {
        $errmsg = "Specified entity doesn't match level selected";  
    }
    elsif (($realmID ne $sfRealmID)) {
        $errmsg = "Realm for specified entity doesn't match that on source form";
    }

    return $errmsg;
}


sub delete_template {
    my ($Data) = @_;

    my $dbh = $Data->{'db'};
    my $tID = param('tID') || 0;

    if ($tID) {
        $dbh->do("DELETE from tblRegoForm         where intRegoFormID=$tID");
        $dbh->do("DELETE from tblRegoFormConfig   where intRegoFormID=$tID");
        $dbh->do("DELETE from tblRegoFormFields   where intRegoFormID=$tID");
        $dbh->do("DELETE from tblRegoFormRules    where intRegoFormID=$tID");
        $dbh->do("DELETE from tblRegoFormProducts where intRegoFormID=$tID");
        $dbh->do("DELETE from tblRegoFormComps    where intRegoFormID=$tID");
    }
    return;
}


sub create_templateValues {
    my ($Data) = @_;

    my %templateValues = ();
    $templateValues{'ID'}         = 0;
    $templateValues{'name'}       = '';
    $templateValues{'sourceID'}   = 0;
    $templateValues{'level'}      = 0;
    $templateValues{'entityID'}   = 0;
    $templateValues{'expiryDate'} = '';
    $templateValues{'errind'}     = 0;
    $templateValues{'errmsg'}     = '';
    $templateValues{'action'}     = '';
    $Data->{'templateValues'} = \%templateValues;

    return;
}


sub add_template {
    my ($Data) = @_;
   warn("help"); 
    create_templateValues($Data);
    $Data->{'templateValues'}{'action'} = 'add';

    return;
}


sub edit_template {
    my ($Data) = @_;
    
    my $dbh = $Data->{'db'};
    my $tID = param('tID') || 0;

    my $sql = qq[
        SELECT strRegoFormName, intRegoType, intTemplateLevel, intTemplateSourceID, intTemplateEntityID, DATE_FORMAT(dtTemplateExpiry, '%d/%m/%Y') AS dtTemplateExpiry
        FROM tblRegoForm
        WHERE intRegoFormID=$tID
        LIMIT 1
    ];

    my $query = $dbh->prepare($sql) or query_error($sql);
    $query->execute() or query_error($sql);

    my $template = $query->fetchrow_hashref();
    $query->finish;

    $template->{dtTemplateExpiry} = '' if $template->{dtTemplateExpiry} eq '00/00/0000' ;

    create_templateValues($Data);
    $Data->{'templateValues'}{'ID'}         = $tID;
    $Data->{'templateValues'}{'name'}       = $template->{'strRegoFormName'};
    $Data->{'templateValues'}{'sourceID'}   = $template->{'intTemplateSourceID'};
    $Data->{'templateValues'}{'level'}      = $template->{'intTemplateLevel'};
    $Data->{'templateValues'}{'entityID'}   = $template->{'intTemplateEntityID'};
    $Data->{'templateValues'}{'expiryDate'} = $template->{'dtTemplateExpiry'};
    $Data->{'templateValues'}{'action'}     = 'edit';

    return;
}


sub update_edit_template {
    my ($Data) = @_;

    my $dbh = $Data->{'db'};

    my $tID = param('tID') || 0;
    return () if !$tID;

    my $tName       = param('tName')       || '';
    my $tLevel      = param('tLevel')      || 0;
    my $tEntityID   = param('tEntityID')   || 0;
    my $tExpiryDate = param('tExpiryDate') || '';

    create_templateValues($Data);
    $Data->{'templateValues'}{'ID'}         = $tID;
    $Data->{'templateValues'}{'name'}       = $tName;
    $Data->{'templateValues'}{'level'}      = $tLevel;
    $Data->{'templateValues'}{'entityID'}   = $tEntityID;
    $Data->{'templateValues'}{'expiryDate'} = $tExpiryDate;
    $Data->{'templateValues'}{'action'}     = 'edit';

    my $sql = qq[
        SELECT intRealmID, intSubRealmID
        FROM tblRegoForm
        WHERE intRegoFormID=$tID
    ];

    my $query = $dbh->prepare($sql);
    $query->execute();
    my ($realmID, $subRealmID) = $query->fetchrow_array();
    $query->finish;

    my $errmsg = validate_entity($tLevel, $tEntityID, $realmID, $subRealmID, $dbh);

    if ($errmsg) {
        $Data->{'templateValues'}{'errmsg'} = $errmsg;
        $Data->{'templateValues'}{'errind'} = 1;
        return;
    }

    $sql = qq[
        UPDATE tblRegoForm
        SET strRegoFormName='$tName', 
            intTemplateLevel=$tLevel,
            dtTemplateExpiry=STR_TO_DATE('$tExpiryDate', '%d/%m/%Y'),
            intTemplateEntityID=$tEntityID
        WHERE intRegoFormID=$tID
    ];

    $dbh->do($sql);

    $Data->{'templateValues'}{'errmsg'} = "Template $tID successfully updated";

    return;
}

sub get_entity_name {
    my ($level, $entityID, $dbh) = @_;

    my $tableName = '';
    my $fieldName = '';

    if ($level eq $Defs::LEVEL_ASSOC) {
        $tableName = 'tblAssoc';
        $fieldName = 'intAssocID';
    }
    else {
        $tableName = 'tblNode';
        $fieldName = 'intNodeID';
    }

    my $sql = qq[
        SELECT strName
        FROM $tableName
        WHERE $fieldName=$entityID
    ];

    my $query = $dbh->prepare($sql);
    $query->execute();

    my ($entityName) = $query->fetchrow_array();
    $query->finish;

    return $entityName;
}


sub list_templates  {
    my ($Data) = @_;

    my $dbh = $Data->{'db'};

    my $tName = param('tName')   || '';
    my $realm = param('realmID') || 0;

    my $strWhere = '';

    if ($tName) {
        $strWhere .= "strRegoFormName LIKE '%".$tName."%'";
    }

    if ($realm) {
        $strWhere .= " AND " if $strWhere;
        $strWhere .= "tblRegoForm.intRealmID=$realm";
    }

    $strWhere .= " AND " if $strWhere;
    $strWhere .= "intTemplate=1";

    $strWhere = "WHERE $strWhere" if $strWhere;

    my $sql = qq[
        SELECT intRegoFormID, strRegoFormName, intRegoType, intTemplateLevel, strRealmName, strSubTypeName, intTemplateEntityID, DATE_FORMAT(dtTemplateExpiry, '%d/%m/%Y') AS dtTemplateExpiry
        FROM tblRegoForm
            LEFT JOIN tblRealms ON tblRegoForm.intRealmID=tblRealms.intRealmID
            LEFT JOIN tblRealmSubTypes ON tblRegoForm.intRealmID=tblRealmSubTypes.intRealmID AND tblRegoForm.intSubRealmID=tblRealmSubTypes.intSubTypeID
        $strWhere
        ORDER BY intRegoFormID
    ];

    my $query = $dbh->prepare($sql) or query_error($sql);
    $query->execute() or query_error($sql);

    my $count = 0;
    my $resultHTML = '';

    while (my $sourceForm = $query->fetchrow_hashref()) {
        foreach my $key (keys %{$sourceForm}) { 
            if (!defined $sourceForm->{$key}) {
                $sourceForm->{$key} = '';
            } 
        }
        $sourceForm->{strRealmName}   ||= '&nbsp;';
        $sourceForm->{strSubTypeName} ||= '&nbsp;';
        $sourceForm->{dtTemplateExpiry} = '&nbsp;' if $sourceForm->{dtTemplateExpiry} eq '00/00/0000' ;

        my $class = '';
        my $classborder = 'commentborder';

        if ($count++ % 2 == 1) {
            $class = q[ class="commentshaded" ];
            $classborder="commentbordershaded";
        }

        my $extralink = '';
        if ($sourceForm->{intRecStatus} < 0) {
            $classborder .= " greytext";
            $extralink = qq[ class="greytext"];
        }

        my $typeDesc   = get_type_desc($sourceForm->{intRegoType});
        my $levelDesc  = $Defs::LevelNames{$sourceForm->{intTemplateLevel}} || $Defs::LevelNames{$Defs::LEVEL_NONE};
        my $entityName = get_entity_name($sourceForm->{intTemplateLevel}, $sourceForm->{intTemplateEntityID}, $dbh);

        $resultHTML .= qq[
          <tr>
            <td class="$classborder"><a $extralink href="$Data->{'target'}?a=RFT_edit&amp;tID=$sourceForm->{intRegoFormID}">$sourceForm->{strRegoFormName}</a></td>
            <td class="$classborder">$sourceForm->{intRegoFormID}</td>
            <td class="$classborder">$sourceForm->{strRealmName}</td>
            <td class="$classborder">$sourceForm->{strSubTypeName}</td>
            <td class="$classborder">$typeDesc</td>
            <td class="$classborder">$levelDesc</td>
            <td class="$classborder">$entityName</td>
            <td class="$classborder">$sourceForm->{dtTemplateExpiry}</td>
            <td class="$classborder">
              <a href="$Data->{'target'}?a=RFT_delete&amp;tID=$sourceForm->{intRegoFormID}" onclick="return confirm('Are you sure you want to delete template $sourceForm->{intRegoFormID}?');"><img src="../images/sml_delete_icon.gif" title="Delete template" alt="Delete template"></a>
            </td>
          </tr>
        ];
    }

    $query->finish;

    if ($resultHTML) {
        $resultHTML = qq[
            <table cellpadding="1" cellspacing="0" border="0" width="95%" style="margin-left:22px">
              <tr>
                <th style="text-align:left;">Template Name</th>
                <th style="text-align:left;">ID</th>
                <th style="text-align:left;">Realm</th>
                <th style="text-align:left;">SubRealm</th>
                <th style="text-align:left;">Type</th>
                <th style="text-align:left;">Level</th>
                <th style="text-align:left;">Entity</th>
                <th style="text-align:left;">Expiry Date</th>
              </tr>
              $resultHTML
            </table><br>
        ];
    }
    else  {
        $resultHTML .= qq[
            <table cellpadding="1" cellspacing="0" border="0" width="90%" align="center">
              <tr><td colspan="3" align="center"><b><br> No Search Results found<br><br></b></td></tr>
            </table>
            <br>
        ];
    }

    return $resultHTML;
}


sub get_type_desc {
    my ($tType) = @_;

    my @typeDescs = (
        'Member to Association',
        'Team to Association',
        'Member to Team',
        'Member to Club'
    );

    return $typeDescs[$tType-1];
}


sub dq {
    my $str = shift;
    $str =~ s/^'(.*)'$/"$1"/g;
    return $str;
}


1;
