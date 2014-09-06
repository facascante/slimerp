#
# $Header: svn://svn/SWM/trunk/web/RegoFormOptions.pm 11632 2014-05-21 05:23:27Z mstarcevic $
#

package RegoFormOptions;

require Exporter;

@ISA = qw(Exporter);
@EXPORT = qw(handle_regoform_options);
@EXPORT_OK = qw(handle_regoform_options);

use strict;
use lib '.', '..';
use Reg_common;
use Utils;
use CGI qw(unescape param);
use Defs;
use ConfigOptions;
use FieldLabels;
use CustomFields;
use RegoForm;
use FormHelpers;
use AuditLog;
use Date::Calc qw(Today);
use FieldConfig;
use List::Util qw(max sum first);
use Member qw(check_valid_date);
use RegoFormCreateFromTemplate qw(create_from_template);
use RegoFormStepper;
use RegoFormFields;
use Payments;
use RegoFormObj;
use RegoFormLayoutsObj;
use TTTemplate;
use RegoFormFieldSQL;
use RegoFormFieldAddedObj;
use RegoFormRuleAddedObj;
use RegoFormPrimaryObj;
use RegoFormAddedObj;
use RegoFormFieldObj;
use RegoFormRuleObj;
use RegoFormNrsUtils;
use TempNodeStructureObj;
use Log;

sub handle_regoform_options {
    my ($action, $Data, $assocID, $typeID)=@_;

    my $cgi = new CGI;
    my $client = setClient($Data->{'clientValues'});
    my $resultHTML   = q{};
    my $title        = q{};
    my $ret          = q{};
    my $breadcrumbs  = q{};
    my @templates    = ();
    my $templateID   = '';
    my $templatemsg  = '';
    my $stepper_mode = '';
    my $stepper_fid  = 0;

    if ($action =~/^A_ORF_s/) {
        ($ret,$title, $stepper_mode) = update_regoform_fields($action, $Data);
        if ($stepper_mode eq 'add') {
            ($ret, $title, $breadcrumbs)=regoform_field_order($action, $Data, $assocID, $client, $title);
            $action = 'A_ORF_dummy';
            $resultHTML.=$ret;
        }
        elsif ($stepper_mode eq 'edit') {
            $resultHTML.=$ret;
            ($ret, $title, $breadcrumbs) = regoform_fields($action, $Data, $assocID, $client);
            $action = 'A_ORF_dummy';
            $resultHTML.=$ret;
        }
        else {
            $action='A_ORF_f';
            $resultHTML.=$ret;
        }
    }
    elsif ($action =~/^A_ORF_rs/) {
        ($ret,$title)=update_regoform_status($action, $Data);
        $action='A_ORF_r';
        $resultHTML.=$ret;
    }
    elsif ($action =~/^A_ORF_tu/) {
        ($ret,$title, $stepper_mode)=update_regoformtext($Data);
        if ($stepper_mode eq 'add') {
            if (GetFormType($Data, 1, $title) == $Defs::REGOFORM_TYPE_TEAM_ASSOC) {
                ($ret, $title, $breadcrumbs) = regoform_teamcomps($Data, $title);
            }
            else {
                ($ret, $title, $breadcrumbs) = regoform_notifications($Data, $title);
            }
            $action = 'A_ORF_dummy';
        }
        else {
            $action='A_ORF_t';
        }
        $resultHTML.=$ret;
    }
    elsif ($action =~/^A_ORF_pu/) {
        ($ret,$title, $stepper_mode)=update_regoform_products($action, $Data, $assocID, $Defs::LEVEL_MEMBER, $client);
        if ($stepper_mode eq 'add') {
            ($ret, $title, $breadcrumbs) = regoform_text_edit($Data, $title);
            $action = 'A_ORF_dummy';
        }
        else {
            $action='A_ORF_p';
        }
        $resultHTML.=$ret;
    }
    elsif ($action =~/^A_ORF_tcu/) {
        ($ret,$title, $stepper_mode)=update_regoform_teamcomps($action, $Data, $assocID, $Defs::LEVEL_TEAM, $client);
        if ($stepper_mode eq 'add') {
            ($ret, $title, $breadcrumbs) = regoform_notifications($Data, $title);
            $action = 'A_ORF_dummy';
        }
        else {
            $action='A_ORF_tc';
        }
        $resultHTML.=$ret;
    }
    elsif ($action =~/^A_ORF_tpu/) {
        ($ret,$title, $stepper_mode)=update_regoform_products($action, $Data, $assocID, $Defs::LEVEL_TEAM, $client);
        if ($stepper_mode eq 'add') {
            ($ret, $title, $breadcrumbs) = regoform_text_edit($Data, $title);
            $action = 'A_ORF_dummy';
        }
        else {
            $action='A_ORF_tp';
        }
        $resultHTML.=$ret;
    }
    elsif ($action =~/^A_ORF_notiu/) {
        ($ret,$title, $stepper_mode)=update_regoform_notifications($action, $Data, $assocID, $Defs::LEVEL_TEAM, $client);
        if ($stepper_mode eq 'add') {
            $action = 'A_ORF_r';
        }
        else {
            $action='A_ORF_noti';
            $resultHTML.=$ret;
        }
    }
    elsif ($action =~/^A_ORF_anf/) {
        @templates = regoform_add_new_form($action, $Data, $client);
            $action = (@templates)
                ? 'A_ORF_st'
                : 'A_ORF_re';
    }
    elsif ($action =~ /^A_ORF_cft/) {
        ($templateID, $templatemsg) = regoform_create_from_template($action, $Data, $client);
        if ($templateID) {
            $resultHTML .= $templatemsg;
            $action = 'A_ORF_r'
        }
        else {
            $action = 'A_ORF_re';
        }
    }

        $Data->{'Permissions'}=GetPermissions(
            $Data,
            $Data->{'clientValues'}{'currentLevel'},
            getID($Data->{'clientValues'}, $Data->{'clientValues'}{'currentLevel'}),
            $Data->{'Realm'},
            $Data->{'RealmSubType'},
            $Data->{'clientValues'}{'authLevel'},
            0,
        );

    if ($action =~/^A_ORF_st/) {
        ($ret, $title, $breadcrumbs) = regoform_select_template($action, $Data, $client, \@templates);
        $resultHTML .= $ret;
    }
    elsif ($action =~ /^A_ORF_res/) {
        ($ret, $title, $stepper_mode, $stepper_fid) = regoform_upd_settings($action, $Data, $assocID);
        if ($stepper_mode eq 'add') {
            ($ret, $title, $breadcrumbs) = regoform_fields($action, $Data, $assocID, $client, $stepper_fid);
            $resultHTML.=$ret;
        }
        elsif ($stepper_mode eq 'edit') {
            $resultHTML.=$ret;
            ($ret, $title, $breadcrumbs) = regoform_edit_form($action, $Data, $assocID, $client);
            $resultHTML.=$ret;
        }
        else {
            $resultHTML .= $ret;
            ($ret, $title) = regoform_list($action, $Data, $assocID, $client);
            $resultHTML .= $ret;
        }
    }
    elsif ($action =~ /^A_ORF_re/) {
        ($ret, $title, $breadcrumbs) = regoform_edit_form($action, $Data, $assocID, $client);
        $resultHTML .= $ret;
    }
    elsif ($action =~ /^A_ORF_r/) {
        ($ret, $title) = regoform_list($action, $Data, $assocID, $client);
        $resultHTML .= $ret;
    }
    elsif ($action =~/^A_ORF_f/) {
        ($ret, $title, $breadcrumbs) = regoform_fields($action, $Data, $assocID, $client);
        $resultHTML.=$ret;
    }
    elsif ($action =~ /^A_ORF_oups/) {
        my ($rval, $msg, $stepper_mode) = update_regoform_field_rule($action, $Data, $assocID, $client);
        my $msg2 = ($stepper_mode) ? '' : $msg;
        if ($rval) {
            ($ret, $title, $breadcrumbs) = regoform_field_order($action, $Data, $assocID, $client);
        }
        else {
            ($ret,$title, $breadcrumbs) = regoform_field_rule_form($action, $Data, $assocID, $client);
        }
        $resultHTML .=  $msg2 . $ret;
    }
    elsif ($action =~ /^A_ORF_oup/) {
        ($ret, $title, $breadcrumbs) = regoform_field_rule_form($action, $Data, $assocID, $client);
        $resultHTML.=$ret;
    }
    elsif ($action =~/^A_ORF_ou/) {
        ($ret, $title, $breadcrumbs, $stepper_mode, $stepper_fid) = regoform_field_order_update($action, $Data, $assocID, $client);
        if ($stepper_mode eq 'add') {
            ($ret, $title, $breadcrumbs) = regoform_products($Data, $stepper_fid);
        }
        $resultHTML.=$ret;
    }
    elsif ($action =~/^A_ORF_o/) {
        ($ret, $title, $breadcrumbs) = regoform_field_order($action, $Data, $assocID, $client);
        $resultHTML.=$ret;
    }
    elsif ($action =~/^A_ORF_p/) {
         ($ret,$title, $breadcrumbs)=regoform_products($Data);
            $resultHTML.=$ret;
    }
    elsif ($action =~/^A_ORF_tc/) {
         ($ret, $title, $breadcrumbs) = regoform_teamcomps($Data);
            $resultHTML.=$ret;
    }
    elsif ($action =~/^A_ORF_tp/) {
         ($ret, $title, $breadcrumbs) = regoform_products($Data);
            $resultHTML.=$ret;
    }
    elsif ($action =~/^A_ORF_t/) {
         ($ret, $title, $breadcrumbs)=regoform_text_edit($Data);
            $resultHTML.=$ret;
    }
    elsif ($action =~/^A_ORF_noti/) {
         ($ret, $title, $breadcrumbs)=regoform_notifications($Data);
            $resultHTML.=$ret;
    }
    elsif ($action =~/^A_ORF_dummy/) {
        #do nothing
    }
    else    {
        ($ret, $title) = regoform_list($action, $Data, $assocID, $client);
        $resultHTML .= $ret;
    }

    return ($resultHTML, $title, $breadcrumbs);
}

sub regoform_list {
    my ($action, $Data, $assocID, $client) = @_;

    my $realmID = $Data->{'Realm'} || 0;
    my $clubID = $Data->{'clientValues'}->{'clubID'} || 0;
    $clubID = 0 if $clubID == -1;
    $assocID = $Data->{'clientValues'}->{'assocID'} || $assocID;

    my $cgi = new CGI;
    my $a_statement = qq[SELECT * FROM tblAssoc WHERE intAssocID = ?];
    my $a_query = $Data->{'db'}->prepare($a_statement);

    my $nodeIds = getNodeIds($Data);

    if ($Data->{'SystemConfig'}{'AssocConfig'}{'overide_regoform_HideAddForm'} and $Data->{'SystemConfig'}{'regoform_HideAddForm'}) {
        $Data->{'SystemConfig'}{'regoform_HideAddForm'} = 0;
    }
    $Data->{'SystemConfig'}{'regoform_HideAddForm'} = 0 if (exists $Data->{'SystemConfig'}{'regoform_HideAddForm'} and $Data->{'clientValues'}{'authLevel'} == $Data->{'SystemConfig'}{'regoform_HideAddForm'});

    $a_query->execute($assocID);

    my $assoc_ref = $a_query->fetchrow_hashref();

    #nationalrego. forms created by nodes will have an assocID of -1.
    my $statement = ($Data->{'SystemConfig'}{'AllowOnlineRego_node'} and !$assoc_ref->{'intExcludeFromNationalRego'})
        ? getRegoFormListNationalSQL($realmID, $assocID, $clubID, $nodeIds, $Data->{'clientValues'}{'currentLevel'})
        : getRegoFormListNotNationalSQL($realmID, $assocID, $clubID);

    my $query = $Data->{'db'}->prepare($statement);
    $query->execute();

    my $entityTypeID = ($clubID) ? $Defs::LEVEL_CLUB : $Defs::LEVEL_ASSOC;
    my $entityID     = ($clubID) ? $clubID : $assocID;
    my $key1         = $entityTypeID + $entityID + int(rand(1000));
    my $key2         = getRegoPassword($key1);

    my %templateData = (
        target       => $Data->{'target'},
        client       => $client,
        entityTypeID => $entityTypeID,
        entityID     => $entityID,
        key1         => $key1,
        key2         => $key2,
    );
    my $templateFile = 'regoform/backend/forms_list_top.templ';
    my $subBody = runTemplate($Data, \%templateData, $templateFile);

    my $hasNationalForms = 0;

    my $productsTabOnly = getProductsTabOnly($Data);

    my @nodeForms = (0,0,0,0,0);

    my $rowCount = 0;
    my $acfCount = 0;
    my $pbfCount = 0;

    my $currentPrimaryFormID = RegoFormPrimaryObj->getCurrentPrimaryFormID(dbh=>$Data->{'db'}, entityTypeID=>$entityTypeID, entityID=>$entityID);

    while (my $form_ref = $query->fetchrow_hashref()) {
        $rowCount++;
        $hasNationalForms = 1 if !$form_ref->{'intAssocID'};

        my $disabled = ($form_ref->{intStatus} == 0);

        my $formID   = $form_ref->{'intRegoFormID'};
        my $formType = $form_ref->{'intRegoType'};

        my $formnumber;

        if ($form_ref->{'intParentBodyFormID'}) {
            $formnumber = $form_ref->{'comboFormID'}
        }
        else {
            $formnumber = $formID;
            $formnumber .= ".$assocID" if !$form_ref->{'intAssocID'};
        }

        my $base_link = join(q{}, $Data->{'target'}, '?', join('&', map { $_->[0] . '=' . $_->[1] } ( [ client => $client ], [ fID => $formID ])));

        my $formname = $form_ref->{strRegoFormName};

        #nationalrego. set up url fields for forms created by nodes.
        my $assocKey = '';
        my $assocVal = '';
        my $clubKey  = '';
        my $clubVal  = '';
        my $pwdKey   = '';
        my $pwdVal   = '';

        if ($form_ref->{'intAssocID'} == -1 and $form_ref->{'intCreatedLevel'} > $Defs::LEVEL_ASSOC and $Data->{'clientValues'}{'currentLevel'} <= $Defs::LEVEL_ASSOC) {
            $nodeForms[$formType] = $formID;
            $pbfCount++;

            if ($assocID and $assocID != -1) {
                $assocKey = 'aID';
                $assocVal = $assocID;
            }
            if ($clubID) {
                 $clubKey = 'cID';
                 $clubVal = $clubID;
            }

            my  $clubNum  = $clubVal  || 0;
            my  $assocNum = $assocVal || 0;

            if ($assocNum or $clubNum) {
                $pwdKey = 'pKey';
                $pwdVal = getRegoPassword($assocNum + $clubNum + $formID);
            }
        }
        else {
            $acfCount++ if !$form_ref->{'intParentBodyFormID'};
        }

        #nationalrego. include these fields in the url.
        my $form_link = HTML_link('View', "$Defs::base_url/regoform.cgi", {-target=>'_blank', formID=>$formID, $assocKey=>$assocVal, $clubKey=>$clubVal, $pwdKey=>$pwdVal});

        my $copy_icon = qq[<img src="images/copyform.gif" title="Make a copy" alt="Make a copy">];
        my $confirm_copy = qq[return confirm('Are you sure you want to make a copy of form #$formID?')];
        my $allow_copy = 0;

        if ($assoc_ref->{intAllowRegoForm} != 2 and not $Data->{'SystemConfig'}{'regoform_HideAddForm'} and not $productsTabOnly) { #regoforms must be allowed; neither hideadd  nor  productsonlytab must not be turned on
            if ($Data->{'clientValues'}{'authLevel'} >= $Defs::LEVEL_ASSOC or ($clubID and $Data->{'clientValues'}{'authLevel'} >= $Defs::LEVEL_CLUB)) { # auth must be at 1) assoc level or above OR 2) club level and clubid must be set
                $allow_copy = 1;
            }
        }

        #nationalrego. allow edit, replicate and delete of forms as the default.
        my $allow_edit      = 1;
        my $allow_replicate = 1;
        my $allow_delete    = 1;

        #nationalrego. don't allow replicate of a node created form.
        #nationalrego. don't allow copy and delete of a node created form at assoc level and below.
        #nationalrego. don't allow edit of a node created form by a node other than the creating node.
        if ($form_ref->{'intAssocID'} == -1 and $form_ref->{'intCreatedLevel'} > $Defs::LEVEL_ASSOC) {
            $allow_replicate = 0;
            if ($Data->{'clientValues'}{'currentLevel'} <= $Defs::LEVEL_ASSOC) {
                $allow_copy   = 0;
                $allow_delete = 0;
            }
        }

        my $allow_promote = ($form_ref->{'intAssocID'} != -1 and $form_ref->{'intCreatedLevel'} <= $Defs::LEVEL_ASSOC and $allow_edit and $nodeForms[$form_ref->{'intRegoType'}] and !$form_ref->{'intParentBodyFormID'}) ? 1 : 0; #nationalrego.

        my $replicate_icon    = qq[<img src="images/copy2children_smaller.gif" title="Replicate to Clubs" alt="Replicate To Clubs">];
        my $confirm_replicate = qq[return confirm("Are you sure you want to replicate form #$formID to clubs?")];
        my $delete_icon       = qq[<img src="images/sml_delete_icon.gif" title="Delete Form" alt="Delete Form" >];
        my $confirm_delete    = qq[return confirm("Are you sure you want to delete the form $formname?");];

        my $prod_action = "A_ORF_p";
        $prod_action    = "A_ORF_tp" if (GetFormType( $Data, 0, $formID) eq 'Team');

        my $showPbf = qq[dialogform("regopbforms.cgi?client=$client&amp;fid=$formID",'Link Form #$formID to Parent Body Form',0,250);return false;]; #nationalrego.

        my $altFormName = ($form_ref->{'intParentBodyFormID'}) ? "&#62&#62&#62&#62 $formname" : $formname; #nationalrego.
        my $colClass    = ($form_ref->{'intParentBodyFormID'}) ? 'hilite' : 'nohilite'; #nationalrego.

        #nationalrego. a bit of a crude way of separating the pbf forms from the assoc/club forms. but works.
        if ($rowCount == 1 and $pbfCount == 1) {
            $subBody .= qq[
                <tr><th style="background:white">Parent Body Forms</th></tr>
                </table>
                <table class='listTable nat-reg-table'>
            ];
        }

        if ($acfCount == 1 and $pbfCount) {
            my $entity = ($clubID) ? 'Club' : 'Assoc';
            $subBody .= $cgi->Tr($cgi->td({-style=>"font-family:'DINBold',sans-serif;padding-left:5px;"},["$entity Forms",'','','','','','','','',''])) if ($rowCount > $pbfCount) and ($acfCount == 1);
        }

        my $primaryChecked = ($formID == $currentPrimaryFormID) ? 'checked' : '';
        my $primaryLabel   = ($formID == $currentPrimaryFormID) ? 'Primary' : 'Set Primary';

        $subBody .= $cgi->Tr(
            $cgi->td(
                {-class=>"$colClass"},
                [
                    "$altFormName (#$formnumber)",
                    GetFormType($Data, 2, $formID),

                    #setPrimaryForm.
                    (($Data->{'clientValues'}{'currentLevel'} <= $Defs::LEVEL_ASSOC) and ($form_ref->{'intParentBodyFormID'} > 0 or $form_ref->{'intCreatedLevel'} > $Defs::LEVEL_ASSOC))
                        ? qq[<input type="checkbox" id="chkPrimary_$formID" class="chkPrimary" $primaryChecked/><label for="chkPrimary_$formID" id="lblPrimary_$formID">$primaryLabel</label>]
                        : '',

                    #don't give view option for node levels.
                    ($Data->{'clientValues'}{'currentLevel'} <= $Defs::LEVEL_ASSOC)
                        ? $form_link
                        : '',

                    $Data->{'SystemConfig'}{'EnableRegoFormPBFLink'}
                        ? 
                        ( ($form_ref->{'intAssocID'} > 0 and $allow_promote)
                            ? HTML_link( 'Link', '#', {-onClick=>$showPbf})
                            : ($form_ref->{'intParentBodyFormID'} > 0 and $Data->{'clientValues'}{'authLevel'} > $Defs::LEVEL_CLUB )
                                ? HTML_link( 'Unlink', '#', {-onClick=>"unlinkFromPBF($formID, $entityTypeID, $entityID);"})
                                : '')
                        : '',

                    ($form_ref->{'intAssocID'} and ( $Data->{'clientValues'}{'authLevel'} >= $Defs::LEVEL_ASSOC or ! $Data->{'SystemConfig'}{'regoform_HideEdit'}) and $allow_edit)
                        ? qq[<a href="$base_link&a=A_ORF_re">Edit</a>]
                        : '',

                    ($form_ref->{'intAssocID'} and ( $Data->{'clientValues'}{'authLevel'} >= $Defs::LEVEL_ASSOC or ! $Data->{'SystemConfig'}{'regoform_HideEdit'}) and $productsTabOnly and $Data->{'SystemConfig'}{'regoform_ForceNotificationsTab'})
                        ? qq[<a href="$base_link&a=A_ORF_noti">Notifications</a>]
                        : '',

                    ($allow_copy)
                        ? HTML_link( $copy_icon, $base_link, { a => 'RFR_mac', -onClick => $confirm_copy, })
                        : q{},

                    ($form_ref->{'intAssocID'} and $Data->{'clientValues'}{'currentLevel'} >= $Defs::LEVEL_ASSOC and !$productsTabOnly and $allow_replicate)
                        ? HTML_link( $replicate_icon, $base_link, { a => 'RFR_rtc1', -onClick => $confirm_replicate, })
                        : q{},

                    ($form_ref->{'intAssocID'} and ($Data->{'clientValues'}{'authLevel'} >= $Defs::LEVEL_ASSOC or not $Data->{'SystemConfig'}{'regoform_HideDeleteForm'}) and !$productsTabOnly and $allow_delete)
                        ? HTML_link($delete_icon, $base_link, { a => 'A_ORF_rsd', -onClick => $confirm_delete, })
                        : q{},
                ]
            )
        );
    }

    $subBody .= '</table>';
    $subBody .= qq[<br><br><b>NOTE:</b> Any form that is added will inherit the National Form settings for Field Options.</form><br>] if $hasNationalForms;

    my $target = $Data->{'target'};

    if ($assoc_ref->{'intAllowRegoForm'} != 2 and not $Data->{'SystemConfig'}{'regoform_HideAddForm'} and not $productsTabOnly and
        ($Data->{'clientValues'}{'authLevel'} >= $Defs::LEVEL_ASSOC or ($clubID and $Data->{'clientValues'}{'authLevel'} >= $Defs::LEVEL_CLUB))) {
        $subBody .= qq[
            <br><br>
            <form action="$target">
              <input type='hidden' name='client' value="$client">
              <input type='hidden' name='a' value='A_ORF_anf'>
              <input type='submit' value='Add New Form' class="button proceed-button">
            </form>
            <br>
        ];
    }

    if (!$Data->{'SystemConfig'}{'regoform_HideTestAddForm'} and $clubID) { # and $clubID != -1) {
        $subBody .= qq[
                <div style = "clear:left;"></div>
            <p>Clicking on the &quot;Create Test Form&quot; button below will create a new sample form, and a &#36;1 test product.
         To complete your SP Registrations activation, use the sample form to create a new registration,
         complete the form and purchase the &#36;1 Test Product.
            </p>
            <br>
            <p>Please note that you should have configured your club/association for online payments prior to this step,
         and  this can be found by clicking on the &quot;dollar sign&quot icon in the menu.
            </p>
            <br>
            <form action='$target'>
              <input type='hidden' name='client' value="$client">
              <input type='hidden' name='a' value='A_ORF_res'>
              <input type='hidden' name='fID' value='0'>
              <input type='hidden' name='strRegoFormName' value='PayMySport test form'>
              <input type='hidden' name='intRegoType' value='4'>
              <input type='hidden' name='ynPlayer' value='Y'>
              <input type='hidden' name='intNewRegosAllowed' value='0'>
              <input type='hidden' name='defaultRego' value='1'>
              <input type='submit' value='Create Test Form' class = "button generic-button">
            </form>
        ];
    }

    return ($subBody, 'Registration Forms');
}

sub getNodeIds {
    my ($Data) = @_;

    my $dbh = $Data->{'db'};
    my ($entityTypeID, $entityID) = getEntityValues($Data->{'clientValues'});

    my $nodeIds = '';

    my $entityStructure = getEntityStructure($Data, $entityTypeID, $entityID, $Defs::LEVEL_NATIONAL, 1);

    foreach my $entityArr (@$entityStructure) {
        next if @$entityArr[0] <= $Defs::LEVEL_ASSOC;
        $nodeIds .= ',' if $nodeIds;
        $nodeIds .= @$entityArr[1];
    }
    
    return $nodeIds;
}

sub getRegoFormListNationalSQL {
    my ($realmID, $assocID, $clubID, $nodeIds, $currLevel) = @_;

    $assocID = 0 if $assocID < 0;

    my $sql = qq[
        SELECT
            RF.*,
            IF (RF.intParentBodyFormID>0, concat(RF.intParentBodyFormID,'.',RF.intRegoFormID), RF.intRegoFormID) AS comboFormID,
            IF (RF.intParentBodyFormID>0, (select RF2.intCreatedLevel FROM tblRegoForm AS RF2 where RF2.intRegoFormID=RF.intParentBodyFormID),RF.intCreatedLevel) AS createdLevel
        FROM
            tblRegoForm RF
        WHERE
            (RF.intAssocID IN (0, $assocID) OR (RF.intAssocID=-1 AND RF.intCreatedLevel>$Defs::LEVEL_ASSOC AND $currLevel<=RF.intCreatedLevel AND RF.intCreatedID IN (0, $nodeIds)))
            AND RF.intRealmID = $realmID
            AND RF.intStatus <> -1
        ];
    #forms created by nodes will have a clubID of -1. clubs can only see member-to-club forms created by nodes.
    if ($clubID) {
        $sql .= qq[
            AND (RF.intClubID = $clubID OR (RF.intClubID=-1 AND RF.intCreatedLevel>$Defs::LEVEL_ASSOC AND RF.intRegoType IN ($Defs::REGOFORM_TYPE_MEMBER_CLUB, $Defs::REGOFORM_TYPE_MEMBER_TEAM) AND RF.intCreatedID IN (0,$nodeIds)))
        ];
    }
    else {
        $sql .= " AND RF.intClubID = -1";
    }

    $sql .= qq[ ORDER BY createdLevel DESC, RF.intRegoType, comboFormID, intRegoFormID];

    return $sql;
}

sub getRegoFormListNotNationalSQL {
    my ($realmID, $assocID, $clubID) = @_;

    my $sql = qq[SELECT * FROM tblRegoForm WHERE intAssocID IN (0, $assocID) AND intRealmID = $realmID AND intStatus <> -1];

    if ($clubID and $clubID != -1) {
        $sql .= " AND intClubID = $clubID ";
    }
    else {
        $sql .= " AND intClubID = -1";
    }
    return $sql;
}

sub regoform_add_new_form {
    my ($action, $Data, $client) = @_;

    my $dbh = $Data->{'db'};
    my $realmID = $Data->{'Realm'};
    my $subRealmID = $Data->{'RealmSubType'};
    my $currentLevel = $Data->{'clientValues'}{'currentLevel'};

    return () if $currentLevel lt $Defs::LEVEL_ASSOC; # to make available to clubs, simply remove this line

    my $assocID = $Data->{'clientValues'}->{'assocID'} || 0;

    my ($y, $m, $d) = Today();
    my $today = sprintf('%02d%02d%02d', $y, $m, $d);

    my @templates = ();

    # check if templates available
    my $sql = qq[
        SELECT intRegoFormID, strRegoFormName, intRegoType, intTemplateLevel, intTemplateEntityID,
            DATE_FORMAT(dtTemplateExpiry, '%Y%m%d') AS dtTemplateExpiry,
            DATE_FORMAT(dtTemplateExpiry, '%d/%m/%Y') AS dtTemplateExpiry2
        FROM 
            tblRegoForm
        WHERE 
            intTemplate=1
            AND intStatus>-1
            AND intRealmID=$realmID
            AND intSubRealmID=$subRealmID
            AND ((dtTemplateExpiry IS NULL) OR (dtTemplateExpiry='00000000') OR (dtTemplateExpiry>=$today))
        ORDER BY 
            intRegoFormID
    ];

    my $query = $dbh->prepare($sql);
    $query->execute or query_error($sql);

    $sql = qq[
        SELECT int100_ID, int30_ID, int20_ID, int10_ID
        FROM tblTempNodeStructure
        WHERE intAssocID=$assocID;
    ];

    my $query2 = $dbh->prepare($sql);
    $query2->execute or query_error($sql);

    my ($nationalID, $stateID, $regionID, $zoneID) = $query2->fetchrow_array();

    while (my $template = $query->fetchrow_hashref()) {
        next if ($template->{'intTemplateLevel'} eq $Defs::LEVEL_NATIONAL) and ($nationalID ne $template->{'intTemplateEntityID'});
        next if ($template->{'intTemplateLevel'} eq $Defs::LEVEL_STATE) and ($stateID ne $template->{'intTemplateEntityID'});
        next if ($template->{'intTemplateLevel'} eq $Defs::LEVEL_REGION) and ($regionID ne $template->{'intTemplateEntityID'});
        next if ($template->{'intTemplateLevel'} eq $Defs::LEVEL_ZONE) and ($zoneID ne $template->{'intTemplateEntityID'});
        next if ($template->{'intTemplateLevel'} eq $Defs::LEVEL_ASSOC) and ($assocID ne $template->{'intTemplateEntityID'});

        push @templates, {
            'templateID'     => $template->{'intRegoFormID'},
            'templateName'   => $template->{'strRegoFormName'},
            'templateType'   => $template->{'intRegoType'},
            'templateExpiry' => $template->{'dtTemplateExpiry2'}
        };
    }

    $query->finish;
    $query2->finish;

    return @templates; # may be better as a ref?
}

sub regoform_select_template {
    my ($action, $Data, $client, $templates) = @_;

    my $dbh = $Data->{'db'};
    my $currentLevel = $Data->{'clientValues'}{'currentLevel'};

    my @typeDescs = ('Member to Association', 'Team to Association', 'Member to Team', 'Member to Club', '', 'Member to Program');

    my $breadcrumbs = getBreadcrumbs($client, '', 'Add New Form', '');

    my $title   = 'Select Template';

    my $subBody = qq[
        <script type="text/javascript" src="http://ajax.aspnetcdn.com/ajax/jquery.validate/1.8.1/jquery.validate.min.js"></script>
        <script type="text/javascript">
          \$().ready(function() {
            \$("#frmSelectTemplate").validate({
              rules: { tID: "required" },
              messages: { tID: "Either Blank Form or a Template must be selected!<br><br>" },
              errorLabelContainer: "#messagearea ul"
            });
          });
        </script>
        <style>
          table { width:70%; border-collapse:collapse; }
          table td { padding:3px; }
          table th { font-style:italic;  color:#000000; background-color:#DDDDDD; padding-bottom:5px; }
          .rowshade { background-color:#F0F0F0; }
        </style>
        <p>Start with either a blank form or one of the templates shown:</p>
        <br>
        <div id="messagearea">
          <ul></ul>
        </div>
        <form action ="$Data->{'target'}" method="POST" name="frmTemplate" id="frmSelectTemplate">
          <input type="radio" name="tID" value="0" style="margin-left:6px"/>Blank form
          <br> <br>
          <table>
            <th style="padding-left:20px">Template Name</th>
            <th>Template ID</th>
            <th>Template Type</th>
    ];

    my $found = 0;

    for my $template(@$templates) {
        $found++;
        my $tID   = $template->{'templateID'};
        my $tName = $template->{'templateName'};
        my $tType = $template->{'templateType'};

        my $rowshade = ($found%2 == 0)
            ? ' class="rowshade"'
            : '';

        $subBody .= qq[<tr><td$rowshade><input type="radio" name="tID" value="$tID"/>$tName</td><td$rowshade>$tID</td><td$rowshade>$typeDescs[$tType-1]</td></tr>];
    }

    $subBody .= qq[
          </table>
          <br>
          <input type="hidden" name="a" value="A_ORF_cft">
          <input type="hidden" name="client" value="$client">
          <input type="submit" name="btnNext" value="Next >>" class="submit">
        </form>
    ];

   return ($subBody, $title, $breadcrumbs);
}


sub regoform_create_from_template {
    my ($action, $Data, $client) = @_;

    my $dbh = $Data->{'db'};
    my $currentLevel = $Data->{'clientValues'}{'currentLevel'};

    my $templateID = param('tID') || 0;
    my $subBody = '';
    my $result = 0;
    my $message = '';

    if ($templateID) {
        ($result, $message) = create_from_template($Data, $templateID);
        $subBody = ($result gt 0)
            ? qq[<div class="OKmsg">$message</div>]
            : qq[<div class="warningmsg">$message</div>];
    }

    return ($result, $subBody);
}


sub regoform_edit_form {
    my ($action, $Data, $assocID, $client) = @_;

    my $cgi = new CGI;
    my $formID = $cgi->param('fID') || 0;
    my $clubID = $Data->{'clientValues'}->{'clubID'} || 0;
    my $edit = not not $formID;
    my $formName = GetFormName($Data);
    my $action_label = $edit ? 'Edit' : 'Add New Form';
    my $regoFormObj;
    my $form_name;
    my $form_type;
    my $allow_new;
    my $allow_player;
    my $allow_coach;
    my $allow_umpire;
    my $allow_official;
    my $allow_misc;
    my $allow_volunteer;
    my @allow_member_record_types;
    my $allow_new_is_0;
    my $allow_new_is_1;
    my $allow_new_is_2;
    my $allow_new_is_3;
    my $allow_new_is_4;
    my $allow_new_is_5;
    my $form_type_block;
    my $rego_type_block;
    my $allow_mult_adult;
    my $allow_mult_child;
    my $form_enabled;
    my $payment_compulsory;
    my $allow_club_selection;
    my $club_selection_mandatory;
    my $stepper_html = '';
    my $stepper_mode = '';
    my $sql = '';

    my ($currLevel, $currID) = getEntityValues($Data->{'clientValues'});

    my $nrsConfig = getNrsConfig($Data);

    if ($edit) {
        my $dbh = $Data->{'db'};

        $formName .= ' (#'.$formID.')';

        $regoFormObj = RegoFormObj->load(db=>$dbh, ID=>$formID);

        $form_name = $regoFormObj->getValue('strRegoFormName');
        $form_type = $regoFormObj->getValue('intRegoType');

        if (getProductsTabOnly($Data)) {
            my ($ret, $title, $breadcrumbs) = regoform_products($Data);
            return ($ret, $title, $breadcrumbs);
        }

        $stepper_html = regoform_navigation($Data, 'sett', $formID, $form_type, 1);
        $stepper_mode = 'edit';

        $form_enabled             = $regoFormObj->getValue('intStatus');
        $allow_club_selection     = $regoFormObj->getValue('intAllowClubSelection') ? 'checked' : q{};
        $club_selection_mandatory = $regoFormObj->getValue('intClubMandatory')      ? 'checked' : q{};

        #these next fields are subject to nrs config
        $payment_compulsory = $regoFormObj->getValue('intPaymentCompulsory') || 0;

        $allow_player       = ($regoFormObj->allowPlayer())    ? 'checked' : q{};
        $allow_coach        = ($regoFormObj->allowCoach())     ? 'checked' : q{};
        $allow_official     = ($regoFormObj->allowOfficial())  ? 'checked' : q{};
        $allow_misc         = ($regoFormObj->allowMisc())      ? 'checked' : q{};
        $allow_umpire       = ($regoFormObj->allowUmpire())    ? 'checked' : q{};
        $allow_volunteer    = ($regoFormObj->allowVolunteer()) ? 'checked' : q{};
        @allow_member_record_types = $regoFormObj->allowTypes();

        $allow_mult_adult   = $regoFormObj->getValue('intAllowMultipleAdult') ? 'checked': '';
        $allow_mult_child   = $regoFormObj->getValue('intAllowMultipleChild') ? 'checked': '';

        $allow_new          = $regoFormObj->getValue('intNewRegosAllowed');
        ############################################

        if ($nrsConfig->{'enabled'}) {
            if ($regoFormObj->isNodeForm() and $currLevel <= $Defs::LEVEL_ASSOC) {
                if ($nrsConfig->{'optCount'}) {

                    my %where = (intRegoFormID=>$formID, intEntityTypeID=>$currLevel, intEntityID=>$currID);
                    my $regoFormAddedObj = RegoFormAddedObj->loadWhere(dbh=>$dbh, where=>\%where);

                    if ($regoFormAddedObj->isDefined()) {
                        $payment_compulsory  = $regoFormAddedObj->getValue('intPaymentCompulsory') if ($nrsConfig->{'pcEnabled'}); #pc = payment compulsory
                        
                        if ($nrsConfig->{'raEnabled'}) { #ra = register as
                            $allow_player    = ($regoFormAddedObj->allowPlayer())    ? 'checked' : q{};
                            $allow_coach     = ($regoFormAddedObj->allowCoach())     ? 'checked' : q{};
                            $allow_official  = ($regoFormAddedObj->allowOfficial())  ? 'checked' : q{};
                            $allow_misc      = ($regoFormAddedObj->allowMisc())      ? 'checked' : q{};
                            $allow_umpire    = ($regoFormAddedObj->allowUmpire())    ? 'checked' : q{};
                            $allow_volunteer = ($regoFormAddedObj->allowVolunteer()) ? 'checked' : q{};
                            @allow_member_record_types = $regoFormAddedObj->allowTypes();
                        }
                        
                        if ($nrsConfig->{'mrEnabled'}) { #mr = multiple registrations
                            $allow_mult_adult = $regoFormAddedObj->getValue('intAllowMultipleAdult') ? 'checked': '';
                            $allow_mult_child = $regoFormAddedObj->getValue('intAllowMultipleChild') ? 'checked': '';
                        }
                        
                        $allow_new = $regoFormAddedObj->getValue('intNewRegosAllowed') if ($nrsConfig->{'roEnabled'}); #ro = registration options
                    }
                }
            }
        }

        my $form_type_name = $Defs::RegoFormTypeDesc{$form_type} || '';
        $form_type_block = qq[
            <tr>
                <td class="label">Type of Form:</td>
                <td>
                    <span class='value'>$form_type_name</span>
                    <input type='hidden' name='intRegoType' value=$form_type>
                </td>
            </tr>
        ];
    }
    else {
        $formName .= ' (New)';
        $regoFormObj = RegoFormObj->new(db=>$Data->{'db'}); #nationalrego.
        $stepper_html = regoform_navigation($Data, 'sett', 0, 1);
        $stepper_mode = 'add';

        my $member_to_assoc_button = '';
        my $member_to_team_button  = ''; #nationalrego. member to team not applicable to node created forms.
        my $team_to_assoc_button   = '';

        if ($clubID <= 0) {
            $member_to_assoc_button = qq[
                <br>
                <input type="radio" name="intRegoType" value=1 checked id="formtype_ma" onclick="displayFormOptions('member');">
                <label for="formtype_ma">Member registering to an Association</label>
            ];
            $team_to_assoc_button = qq[
                 <br>
                 <input type="radio" name="intRegoType" value="$Defs::REGOFORM_TYPE_TEAM_ASSOC" onclick="displayFormOptions('team');" id="formtype_ta">
                 <label for="formtype_ta">Team registering to an Association</label>
            ] unless $currLevel>$Defs::LEVEL_ASSOC; #nationalrego. don't want team to assoc available at node level.
        }

        #allow Member to Team form to be created unless it's a node level and the option hasn't been specifically enabled.
        my $allow_mttf = 1;

        if ($currLevel>$Defs::LEVEL_ASSOC) {
            $allow_mttf = 0 unless ($Data->{'SystemConfig'}{'AllowOnlineRego_node'} and $Data->{'SystemConfig'}{'nrs_allowMemberToTeamForm'});
        }

        $member_to_team_button = qq[
            <br>
            <input type="radio" name="intRegoType" value="$Defs::REGOFORM_TYPE_MEMBER_TEAM" id="formtype_mt" onclick="displayFormOptions('member');">
            <label for="formtype_mt">Member registering to a Team</label>
        ] unless !$allow_mttf;

        my $member_to_club_selected = ($clubID > 0) ? " checked" : q{};
        $form_type_block = qq[
            <tr>
                <td class="label">Type of Form:</td>
                <td>
        ];
        $form_type_block .= qq[
            $member_to_assoc_button
            <br>
            <input type="radio" name="intRegoType" value="$Defs::REGOFORM_TYPE_MEMBER_CLUB" $member_to_club_selected id="formtype_mc" onclick="displayFormOptions('member');">
            <label for="formtype_mc">Member registering to a Club</label>
            $member_to_team_button
        ] unless $Data->{SystemConfig}{regoForm_noMemberForm};
        
        if ($Data->{SystemConfig}{AllowProgramTemplateAddLevel} 
            && $Data->{'clientValues'}{'currentLevel'} >= $Data->{SystemConfig}{AllowProgramTemplateAddLevel}){
            $form_type_block .= qq[
                <br>
                <input type="radio" name="intRegoType" value="$Defs::REGOFORM_TYPE_MEMBER_PROGRAM"  id="formtype_mp" onclick="displayFormOptions('member');">
                <label for="formtype_mp">Member registering to a Program</label>
            ];
        }
        
        $form_type_block .= qq[
            $team_to_assoc_button
        ] unless $Data->{SystemConfig}{regoForm_noTeamForm};
        $form_type_block .= qq[
                </td>
            </tr>
        ];
    }

    $form_name ||= 'New Registration Form';

    if ($form_type != $Defs::REGOFORM_TYPE_TEAM_ASSOC) {
        unless ($allow_player or $allow_coach or $allow_official or $allow_misc or $allow_umpire or $allow_volunteer) { $allow_player = 'checked'; }
        #nationalrego. entire (HTML) block from here transferred to template.
        #nationalrego. player/coach/umpire/official label setting moved to template settings further on.
    }

    if ($currLevel<=$Defs::LEVEL_ASSOC) { #nationalrego. team to assoc not available at node level.
        if (!$form_type or $form_type == $Defs::REGOFORM_TYPE_TEAM_ASSOC) {
            #Team to Assoc Form
            #get list of Member

            #if at the club level, assocID will actually be the clubID
            my $assocID2 = $Data->{'clientValues'}->{'assocID'} || $assocID;

            my $sql = ($Data->{'SystemConfig'}{'AllowOnlineRego_node'} and $Data->{'SystemConfig'}{'nrs_allowMemberToTeamForm'} and $currLevel == $Defs::LEVEL_ASSOC)
                ? getMemberToTeamListNationalSQL($Data, $assocID2, $clubID)
                : getMemberToTeamListNotNationalSQL($assocID2, $clubID);

            my $warn = 'Do not link this form to a Member to Team form';
            my $linkedformlist = getDBdrop_down('intLinkedFormID', $Data->{'db'}, $sql, $regoFormObj->getValue('intLinkedFormID') || 0, $warn, 1, 0, 0,);

            my $hide = !$form_type ? qq[ style="display:none;" ] : '';
            $rego_type_block .= qq[
        <script>
        jQuery(document).ready(function(){
        displayFormOptions('team');
        });
        </script>

        <tbody id="regform_teamoptions"  style="display:none;" >
                    <tr>
                        <td class="label">Member Form for users to register to teams:</td>
                        <td>$linkedformlist </td>
                    </tr>
                    <tr>
                        <td class="label">Show Club Dropbox:</td>
                        <td><input type="checkbox" name="intAllowClubSelection" value="1" $allow_club_selection></td>
                    </tr>
                    <tr>
                        <td class="label">Make Club Mandatory:</td>
                        <td><input type="checkbox" name="intClubMandatory" value="1" $club_selection_mandatory></td>
                    </tr>
        </tbody>
            ];
        }
    }

    my $paymentsettings = getPaymentSettings($Data);
    my $is_payment_on =""; #intAllowPayment
    my $has_merchant;
    my $check_merchant = 0;
    my $useNAB = $paymentsettings->{'paymentType'} == $Defs::PAYMENT_ONLINENAB ? 1 : 0;
    my $check_bank = qq[<span style="color:red">Bank Account has not been verified. Contact support if you feel this is incorrect.</span>];
    if (Payments::getVerifiedBankAccount($Data, $useNAB)){
        $check_bank =qq[<span style="color:green">Bank Account has been verified.</span>];
    }

    $check_merchant = 1 if ($paymentsettings and $paymentsettings->{'gatewayType'} >0);
    $has_merchant = $check_merchant? qq[<span style="color:green">A Merchant account has been set up.</span>]: qq[<span style="color:red">No merchant account has been setup. Contact support if you feel this is incorrect.</span>];
    my $check_payment_sql;
    my $check_payment_qry;
    my $check_payment_ref;
    my $intAllowPayment;
    #if Club has logged in
    if($currLevel<$Defs::LEVEL_ASSOC) {
        # first check to see if assoc allows all clubs payment
        $check_payment_sql = qq[SELECT intApproveClubPayment FROM tblAssoc WHERE intAssocID = ?];
        $check_payment_qry = $Data->{'db'}->prepare($check_payment_sql);
        my $assocID_2 = $Data->{'clientValues'}{'assocID'};
        $check_payment_qry->execute($assocID_2);
        $check_payment_ref = $check_payment_qry->fetchrow_hashref();
        $intAllowPayment = $check_payment_ref->{intApproveClubPayment};

        if(!$intAllowPayment) { # if haven't set it n assoc level maybe we set it for indivisual clubs!
            $check_payment_sql = qq[SELECT intApprovePayment FROM tblClub WHERE intClubID = ?];
            $check_payment_qry = $Data->{'db'}->prepare($check_payment_sql);
            $check_payment_qry->execute($clubID);
            $check_payment_ref = $check_payment_qry->fetchrow_hashref();
            $intAllowPayment = $check_payment_ref->{intApprovePayment};
        }
        $is_payment_on =  $intAllowPayment? qq[<span style="color:green" > Payments are approved.</span>] :qq[<span style="color:red">Payments are not Approved. Contact support if you feel this is incorrect.</span>];

    } elsif($currLevel == $Defs::LEVEL_ASSOC){
        $check_payment_sql = qq[SELECT intAllowPayment FROM tblAssoc WHERE intAssocID = ?];
        $check_payment_qry = $Data->{'db'}->prepare($check_payment_sql);
        $check_payment_qry->execute($assocID);
        $check_payment_ref = $check_payment_qry->fetchrow_hashref();
        $intAllowPayment = $check_payment_ref->{intAllowPayment};
        $is_payment_on =  $intAllowPayment? qq[<span style="color:green" > Payments are enabled.</span>] :qq[<span style="color:red">Payments are not enabled. Contact support if you feel this is incorrect.</span>];

    }

    $allow_new_is_0 = ($allow_new == 0 ? 'selected' : q{});
    $allow_new_is_1 = ($allow_new == 1 ? 'selected' : q{});
    $allow_new_is_2 = ($allow_new == 2 ? 'selected' : q{});
    $allow_new_is_3 = ($allow_new == 3 ? 'selected' : q{});
    $allow_new_is_4 = ($allow_new == 4 ? 'selected' : q{});
    $allow_new_is_5 = ($allow_new == 5 ? 'selected' : q{});

    my $form_enabled_checked = ($form_enabled or not $edit) ? 'checked' : q{};
    my $payment_compulsory_checked = ($payment_compulsory) ? 'checked' : q{};

    my $allow_if_not_in_national_system = ($form_type != $Defs::REGOFORM_TYPE_TEAM_ASSOC) ? <<"EOS" : q{};
          <option value="1" $allow_new_is_1> Allow new registrations if not in national system </option>
          <option value="4" $allow_new_is_4> Allow new registrations only if in national system </option>
EOS

    my $override = ($form_type != $Defs::REGOFORM_TYPE_TEAM_ASSOC and $Data->{'SystemConfig'}{'rego_NewRegosOverRide'})  ? '<div><i>National Settings may override this selection</i></div>' : '';
    $override = '' if $currLevel>=$Defs::LEVEL_NATIONAL; #nationalrego. national override doesn't make sense at national level and above.

    my $breadcrumbs = getBreadcrumbs($client, $stepper_mode, $action_label, 'Settings');
    my $helpoptions = qq[
        <a href="http://link.brightcove.com/services/player/bcpid50619419001?bctid=52338302001" target="_new" >
          <img src="images/questionmark.gif" title="Do you need help understanding the different Registration Options? Click Here" >
        </a>
    ];
    $helpoptions = ''; #remove for the time being (whilst videos are somewhat outdated)

    my $continue_btn = ($stepper_mode eq 'add')
        ? qq[<input type="submit" value="Continue" class="button proceed-button">]
        : qq[<input type="submit" value="Save" class="button proceed-button">];

    my $pbfID   = ($regoFormObj->isLinkedForm()) ? $regoFormObj->getValue('intParentBodyFormID') : 0;
    my $pbfName = ($pbfID) ? GetFormName($Data, $pbfID) : '';

    my %templateData = (
        isNodeForm       => $regoFormObj->isNodeForm(),
        isLinkedForm     => $regoFormObj->isLinkedForm(),
        isNodeLevel      => $currLevel > $Defs::LEVEL_ASSOC,
        createdID        => $regoFormObj->getValue('intCreatedID'),
        currentID        => $currID,
        pbfID            => $pbfID,
        pbfName          => $pbfName,
        target           => $Data->{'target'},
        stepper_html     => $stepper_html,
        formID           => $formID,
        form_type        => $form_type,
        client           => $client,
        stepper_mode     => $stepper_mode,
        continue_btn     => $continue_btn,
        form_name        => $form_name,
        form_type_block  => $form_type_block,
        is_payment_on    => $is_payment_on,
        has_merchant     => $has_merchant,
        check_bank       => $check_bank,
        rego_type_block  => $rego_type_block,
        allow_new_is_0   => $allow_new_is_0,
        allow_new_is_1   => $allow_new_is_1,
        allow_new_is_2   => $allow_new_is_2,
        allow_new_is_3   => $allow_new_is_3,
        allow_new_is_4   => $allow_new_is_4,
        allow_new_is_5   => $allow_new_is_5,
        helpoptions      => $helpoptions,
        override         => $override,
        form_enabled_checked            => $form_enabled_checked,
        regoform_type_team_assoc        => $Defs::REGOFORM_TYPE_TEAM_ASSOC,
        payment_compulsory_checked      => $payment_compulsory_checked,
        allow_if_not_in_national_system => $allow_if_not_in_national_system,
        nrsConfig                       => $nrsConfig,
    );

    if ($form_type != $Defs::REGOFORM_TYPE_TEAM_ASSOC) {

        $templateData{'allow_player'}     = $allow_player,
        $templateData{'allow_coach'}      = $allow_coach,
        $templateData{'allow_umpire'}     = $allow_umpire,
        $templateData{'allow_official'}   = $allow_official,
        $templateData{'allow_misc'}       = $allow_misc,
        $templateData{'allow_volunteer'}  = $allow_volunteer,
        $templateData{'player_label'}     = $Data->{'SystemConfig'}{'PlayerLabel'}    || 'Player',
        $templateData{'coach_label'}      = $Data->{'SystemConfig'}{'CoachLabel'}     || 'Coach',
        $templateData{'umpire_label'}     = $Data->{'SystemConfig'}{'UmpireLabel'}    || 'Match Official',
        $templateData{'official_label'}   = $Data->{'SystemConfig'}{'OfficialLabel'}  || 'Official',
        $templateData{'misc_label'}       = $Data->{'SystemConfig'}{'MiscLabel'}      || 'Misc',
        $templateData{'volunteer_label'}  = $Data->{'SystemConfig'}{'VolunteerLabel'} || 'Volunteer',

        $templateData{'allow_mult_adult'} = $allow_mult_adult;
        $templateData{'allow_mult_child'} = $allow_mult_child;
    }

    my $templateFile = 'regoform/backend/settings.templ';
    my $subBody = runTemplate($Data, \%templateData, $templateFile);

    return ($subBody, $formName, $breadcrumbs);
}

sub getMemberToTeamListNationalSQL {
    my ($Data, $assocID, $clubID) = @_;

    my $nodeIds = getNodeIds($Data);

    my $sql = qq[
        SELECT 
            F.intRegoFormID, 
            F.strRegoFormName
        FROM   
            tblRegoForm F
            LEFT OUTER JOIN tblRegoFormPrimary P ON F.intRegoFormID=P.intRegoFormID
        WHERE 
            ((F.intAssocID=$assocID AND F.intClubID=$clubID) OR (F.intAssocID=-1 AND F.intCreatedLevel>$Defs::LEVEL_ASSOC AND F.intCreatedID IN (0, $nodeIds)))
            AND (F.intRegoType=3 AND F.intStatus<>-1)
        ORDER BY P.intRegoFormPrimaryID DESC, F.intRegoFormID
    ];

    return $sql;
}

sub getMemberToTeamListNotNationalSQL {
    my ($assocID, $clubID) = @_;

    my $sql = qq[
        SELECT intRegoFormID, strRegoFormName
        FROM   tblRegoForm
        WHERE  intAssocID=$assocID AND intClubID=$clubID AND intRegoType=3 AND intStatus<>-1
    ];

    return $sql;
}

sub regoform_upd_settings {
    my ($action, $Data, $assocID) = @_;

    $assocID = $Data->{'clientValues'}->{'assocID'} || $assocID;

    my $realmID    = $Data->{'Realm'}                    || 0;
    my $subRealmID = $Data->{'RealmSubType'}             || 0;
    my $clubID     = $Data->{'clientValues'}->{'clubID'} || 0;

    my $cgi = new CGI;

    my $formID = $cgi->param('fID') || 0;
    my $stepper_mode = $cgi->param('stepper');

    my @fields = qw(
        strRegoFormName
        intRegoType
        intLinkedFormID
        intAllowClubSelection
        intClubMandatory
        intStatus
    );

    my $nrsOverrideFields = getNrsOverrideFields();

    my $addToFields = 1;

    if ($formID) {
        my $nrsConfig = getNrsConfig($Data);

        if ($nrsConfig->{'enabled'}) {
            my $regoFormObj = RegoFormObj->load(db=>$Data->{'db'}, ID=>$formID);

            if ($regoFormObj->isNodeForm() and $Data->{'clientValues'}{'currentLevel'} <= $Defs::LEVEL_ASSOC) {
                #processNrsOptions will return 0. It's where settings added fields are updated (ie to tblRegoFormAdded).
                $addToFields = processNrsOptions($Data, $nrsConfig, $nrsOverrideFields, $formID, $cgi) if $nrsConfig->{'optCount'}; 
            }
        }
    }

    if ($addToFields) {
        foreach my $key(keys %$nrsOverrideFields) {
            push @fields, $nrsOverrideFields->{$key};
        }
    }

    my %fields;
    foreach my $field (@fields) {
        my @list = $cgi->param($field);
        $fields{$field} = (@list>1) ? join(',', @list) : $list[0];
    }

    $fields{'intStatus'} ||= 0;

    $fields{'strRegoFormName'} ||= 'New Registration Form';

    push @fields, 'intRegoTypeLevel';
    $fields{'intRegoTypeLevel'} = ($fields{'intRegoType'} == 2) ? $Defs::LEVEL_TEAM : $Defs::LEVEL_MEMBER;

    my $statement;

    if ($formID) {
        $statement = 'UPDATE tblRegoForm SET ' .  join(', ', map { $_ . ' = ?' } @fields) .  " WHERE intRegoFormID = $formID";
    }
    else {
        my ($new_char, $ren_char, $pay_char) = set_notif_bits($fields{'intRegoType'}, $clubID);

        my $entityID = getEntityID($Data->{'clientValues'});

        $statement =
            'INSERT INTO tblRegoForm (' .
            join(
                ', ',
                'intAssocID',
                'intRealmID',
                'intSubRealmID',
                'intClubID',
                'intNewBits',
                'intRenewalBits',
                'intPaymentBits',
                'intCreatedLevel',
                'intCreatedID',
                'dtCreated',
                @fields,
            ) .
            ") VALUES ( $assocID, $realmID, $subRealmID, $clubID, $new_char, $ren_char, $pay_char, $Data->{'clientValues'}{'currentLevel'}, $entityID, SYSDATE()," .
            join(', ', map { '?' } @fields ) .
            ')';
    }

    my $query = $Data->{'db'}->prepare($statement) or query_error($statement);
    $query->execute( @fields{ @fields } ) or query_error($statement);

    unless ($formID) {
        $formID = $query->{mysql_insertid};
        #addBubble($Data, $Data->{'clientValues'}{'assocID'}, $Data->{'clientValues'}{'clubID'}, 2, $formID,) if !$stepper_mode;

        if ($cgi->param('defaultRego')) {
            create_default_form_product($Data->{'db'}, $formID, $assocID, $realmID, $subRealmID, $clubID,);
        }
        auditLog($formID, $Data, 'Add', 'Registration Form');

        return ($cgi->div( { -class => 'OKmsg' }, $Data->{'lang'}->txt('Form Created'),), q{}, $stepper_mode, $formID);
    }

    auditLog($formID, $Data, 'Update', 'Registration Form');

    return ($cgi->div( { -class => 'OKmsg' }, $Data->{'lang'}->txt('Settings saved'),), q{}, $stepper_mode, $formID);
}

sub processNrsOptions {
    my ($Data, $nrsConfig, $nrsOverrideFields, $formID, $cgi) = @_;

    my $dbh = $Data->{'db'};

    my ($entityTypeID, $entityID) = getEntityValues($Data->{'clientValues'});

    #might not be anything there but doesn't matter
    my %where = (intRegoFormID=>$formID, intEntityTypeID=>$entityTypeID, intEntityID=>$entityID);
    RegoFormAddedObj->deleteWhere(dbh=>$dbh, where=>\%where);

    my $regoFormAddedObj = RegoFormAddedObj->new(db=>$dbh);
    my $dbfields    = 'dbfields';
    my $ondupfields = 'ondupfields';

    $regoFormAddedObj->{$dbfields}    = ();
    $regoFormAddedObj->{$ondupfields} = ();
    $regoFormAddedObj->{$dbfields}{'intRegoFormID'}   = $formID;
    $regoFormAddedObj->{$dbfields}{'intEntityTypeID'} = $entityTypeID;
    $regoFormAddedObj->{$dbfields}{'intEntityID'}     = $entityID;

    if ($nrsConfig->{'pcEnabled'}) { #pc = payment compulsory
        $regoFormAddedObj->{$dbfields}{$nrsOverrideFields->{'paymentCompulsory'}} = $cgi->param($nrsOverrideFields->{'paymentCompulsory'});
        push @{$regoFormAddedObj->{$ondupfields}}, $nrsOverrideFields->{'paymentCompulsory'};
    }

    if ($nrsConfig->{'raEnabled'}) { #ra = register as
        $regoFormAddedObj->{$dbfields}{$nrsOverrideFields->{'player'}}        = $cgi->param($nrsOverrideFields->{'player'})        || '';
        $regoFormAddedObj->{$dbfields}{$nrsOverrideFields->{'coach'}}         = $cgi->param($nrsOverrideFields->{'coach'})         || '';
        $regoFormAddedObj->{$dbfields}{$nrsOverrideFields->{'official'}}      = $cgi->param($nrsOverrideFields->{'official'})      || '';
        $regoFormAddedObj->{$dbfields}{$nrsOverrideFields->{'matchOfficial'}} = $cgi->param($nrsOverrideFields->{'matchOfficial'}) || '';
        $regoFormAddedObj->{$dbfields}{$nrsOverrideFields->{'misc'}}          = $cgi->param($nrsOverrideFields->{'misc'})          || '';
        $regoFormAddedObj->{$dbfields}{$nrsOverrideFields->{'volunteer'}}     = $cgi->param($nrsOverrideFields->{'volunteer'})     || '';

        my @list = $cgi->param($nrsOverrideFields->{'strAllowedMemberRecordTypes'});
        $regoFormAddedObj->{$dbfields}{$nrsOverrideFields->{'strAllowedMemberRecordTypes'}} = join(',', @list);

        # if none of member types chosen, choose player
        if (
            $regoFormAddedObj->{$dbfields}{$nrsOverrideFields->{'player'}} eq ''
            and $regoFormAddedObj->{$dbfields}{$nrsOverrideFields->{'coach'}} eq ''
            and $regoFormAddedObj->{$dbfields}{$nrsOverrideFields->{'official'}} eq ''
            and $regoFormAddedObj->{$dbfields}{$nrsOverrideFields->{'matchOfficial'}} eq ''
            and $regoFormAddedObj->{$dbfields}{$nrsOverrideFields->{'misc'}} eq ''
            and $regoFormAddedObj->{$dbfields}{$nrsOverrideFields->{'volunteer'}} eq ''
        ) {
            $regoFormAddedObj->{$dbfields}{$nrsOverrideFields->{'player'}} = 'Y';
        }

        push @{$regoFormAddedObj->{$ondupfields}}, $nrsOverrideFields->{'player'};
        push @{$regoFormAddedObj->{$ondupfields}}, $nrsOverrideFields->{'coach'};
        push @{$regoFormAddedObj->{$ondupfields}}, $nrsOverrideFields->{'official'};
        push @{$regoFormAddedObj->{$ondupfields}}, $nrsOverrideFields->{'matchOfficial'};
        push @{$regoFormAddedObj->{$ondupfields}}, $nrsOverrideFields->{'misc'};
        push @{$regoFormAddedObj->{$ondupfields}}, $nrsOverrideFields->{'volunteer'};
        push @{$regoFormAddedObj->{$ondupfields}}, $nrsOverrideFields->{'strAllowedMemberRecordTypes'};
    }

    if ($nrsConfig->{'mrEnabled'}) { #mr = multiple registrations
        $regoFormAddedObj->{$dbfields}{$nrsOverrideFields->{'multipleAdult'}} = $cgi->param($nrsOverrideFields->{'multipleAdult'}) || 0;
        $regoFormAddedObj->{$dbfields}{$nrsOverrideFields->{'multipleChild'}} = $cgi->param($nrsOverrideFields->{'multipleChild'}) || 0;

        push @{$regoFormAddedObj->{$ondupfields}}, $nrsOverrideFields->{'multipleAdult'};
        push @{$regoFormAddedObj->{$ondupfields}}, $nrsOverrideFields->{'multipleChild'};
    }

    if ($nrsConfig->{'roEnabled'}) { #ro = registration options
        $regoFormAddedObj->{$dbfields}{$nrsOverrideFields->{'newRegos'}} = $cgi->param($nrsOverrideFields->{'newRegos'}) || 0;
        push @{$regoFormAddedObj->{$ondupfields}}, $nrsOverrideFields->{'newRegos'};
    }

    my $regoFormAddedID = $regoFormAddedObj->save();

    return 0;
}

sub set_notif_bits {
    my ($form_type, $club_id) = @_;

    $club_id = 0 if $club_id < 0;

    my $new_char;
    my $ren_char;
    my $pay_char;

    if ($form_type == 1) {
        $new_char = pack_notif_bits(1, 0, 0, 1, 1);
        $ren_char = pack_notif_bits(1, 0, 0, 1, 1);
        $pay_char = pack_notif_bits(1, 0, 0, 1, 1);
    }
    elsif ($form_type == 2) {
        $new_char = pack_notif_bits(1, 0, 1, 0, 0);
        $ren_char = pack_notif_bits(1, 0, 1, 0, 0);
        $pay_char = pack_notif_bits(1, 0, 1, 0, 0);
    }
    elsif ($form_type == 3) {
        if (!$club_id) {
            $new_char = pack_notif_bits(1, 0, 1, 1, 1);
            $ren_char = pack_notif_bits(1, 0, 1, 0, 0);
            $pay_char = pack_notif_bits(1, 0, 0, 1, 0);
        }
        else {
            $new_char = pack_notif_bits(1, 1, 1, 1, 1);
            $ren_char = pack_notif_bits(1, 1, 1, 0, 0);
            $pay_char = pack_notif_bits(1, 1, 0, 1, 0);
        }
    }
    elsif ($form_type == 4) {
        $new_char = pack_notif_bits(1, 1, 0, 1, 1);
        $ren_char = pack_notif_bits(1, 1, 0, 1, 1);
        $pay_char = pack_notif_bits(1, 1, 0, 1, 1);
    }
    elsif ($form_type == $Defs::REGOFORM_TYPE_MEMBER_PROGRAM) { #TODO: Work out wtf to do with this crap
        $new_char = pack_notif_bits(1, 0, 0, 0, 0);
        $ren_char = pack_notif_bits(1, 0, 0, 0, 0);
        $pay_char = pack_notif_bits(1, 0, 0, 0, 0);
    }

    return ($new_char, $ren_char, $pay_char);
}

sub regoform_field_rule_form {
    my ($action, $Data, $assocID, $client) = @_;

    my $dbh     = $Data->{'db'};
    my $cgi     = new CGI;
    my $formID  = $cgi->param('fID') || 0;

    my $stepper_mode = $cgi->param('stepper');
    my $stepper_html = '';
    my $stepper_edit = 0;
    my $stepper_inpt = '';

    if ($stepper_mode) {
        $stepper_edit = 1 if $stepper_mode eq 'edit';
        $stepper_html = regoform_navigation($Data, 'lout', $formID, GetFormType($Data, 1, $formID), $stepper_edit);
        $stepper_inpt = qq[<input type="hidden" name="stepper" value="$stepper_mode">];
    }

    my $sourceFieldID = $cgi->param('selected_fieldID');
    my $source  = substr($sourceFieldID, 0, 1);
    my $fieldID = unpack "xxA*", $sourceFieldID; #strip first two chars

    my $added = ($source >= 3) ? 'Added' : '';
    my $regoFormFieldClass = 'RegoFormField'.$added.'Obj';
    my $regoFormFieldObj   = $regoFormFieldClass->load(db=>$dbh, ID=>$fieldID);

    my $fieldName = $regoFormFieldObj->getValue('strFieldName');
    my $fieldLabel = GetFieldLabel($Data, GetFormType($Data, 0, $formID), $fieldName);

    my $clubID = $Data->{'clientValues'}->{'clubID'} || 0;

    my $player_label    = $Data->{'SystemConfig'}{'PlayerLabel'}    || 'Player';
    my $coach_label     = $Data->{'SystemConfig'}{'CoachLabel'}     || 'Coach';
    my $misc_label      = $Data->{'SystemConfig'}{'MiscLabel'}      || 'Misc';
    my $umpire_label    = $Data->{'SystemConfig'}{'UmpireLabel'}    || 'Match Official';
    my $official_label  = $Data->{'SystemConfig'}{'OfficialLabel'}  || 'Official';
    my $volunteer_label = $Data->{'SystemConfig'}{'VolunteerLabel'} || 'Volunteer';

    my $allow_player;
    my $allow_coach;
    my $allow_official;
    my $allow_misc;
    my $allow_umpire;
    my $allow_volunteer;
    my $gender;
    my $dob_min;
    my $dob_max;

    my $dob_min_yyyy;
    my $dob_min_mm;
    my $dob_min_dd;
    my $dob_max_yyyy;
    my $dob_max_mm;
    my $dob_max_dd;

    my $m_selected;
    my $f_selected;

    my $regoFormRuleClass = 'RegoFormRule'.$added.'Obj';
    my $keyName = $regoFormFieldClass->getKeyName();
    my %where = (intRegoFormID=>$formID, $keyName=>$fieldID);
    my $regoFormRuleObj = $regoFormRuleClass->loadWhere(dbh=>$dbh, where=>\%where);
    my $regoFormObj = RegoFormObj->load(db=>$dbh, ID=>$formID);

    my $form_allows_player    = $regoFormObj->getValue('ynPlayer')        eq 'Y';
    my $form_allows_coach     = $regoFormObj->getValue('ynCoach')         eq 'Y';
    my $form_allows_official  = $regoFormObj->getValue('ynOfficial')      eq 'Y';
    my $form_allows_misc      = $regoFormObj->getValue('ynMisc')          eq 'Y';
    my $form_allows_umpire    = $regoFormObj->getValue('ynMatchOfficial') eq 'Y';
    my $form_allows_volunteer = $regoFormObj->getValue('ynVolunteer')     eq 'Y';

    if ($cgi->param('a') eq 'A_ORF_oups') {
        $allow_player    = ($cgi->param('ynPlayer')        eq 'Y') ? 'checked' : q{};
        $allow_coach     = ($cgi->param('ynCoach')         eq 'Y') ? 'checked' : q{};
        $allow_misc      = ($cgi->param('ynMisc')          eq 'Y') ? 'checked' : q{};
        $allow_official  = ($cgi->param('ynOfficial')      eq 'Y') ? 'checked' : q{};
        $allow_umpire    = ($cgi->param('ynMatchOfficial') eq 'Y') ? 'checked' : q{};
        $allow_volunteer = ($cgi->param('ynVolunteer')     eq 'Y') ? 'checked' : q{};
        $gender          =  $cgi->param('strGender')     || 0;
        $dob_min_yyyy    =  $cgi->param('dtMinDOB_yyyy') || q{};
        $dob_max_yyyy    =  $cgi->param('dtMaxDOB_yyyy') || q{};
        $dob_min_mm      =  $cgi->param('dtMinDOB_mm')   || q{};
        $dob_max_mm      =  $cgi->param('dtMaxDOB_mm')   || q{};
        $dob_min_dd      =  $cgi->param('dtMinDOB_dd')   || q{};
        $dob_max_dd      =  $cgi->param('dtMaxDOB_dd')   || q{};
        $m_selected      = ($cgi->param('strGender') == 1) ? 'selected' : q{};
        $f_selected      = ($cgi->param('strGender') == 2) ? 'selected' : q{};
    }
    elsif ($regoFormRuleObj->isDefined()) {
        $allow_player    = ($regoFormRuleObj->getValue('ynPlayer')        eq 'Y') ? 'checked' : q{};
        $allow_coach     = ($regoFormRuleObj->getValue('ynCoach')         eq 'Y') ? 'checked' : q{};
        $allow_official  = ($regoFormRuleObj->getValue('ynOfficial')      eq 'Y') ? 'checked' : q{};
        $allow_misc      = ($regoFormRuleObj->getValue('ynMisc')          eq 'Y') ? 'checked' : q{};
        $allow_umpire    = ($regoFormRuleObj->getValue('ynMatchOfficial') eq 'Y') ? 'checked' : q{};
        $allow_volunteer = ($regoFormRuleObj->getValue('ynVolunteer')     eq 'Y') ? 'checked' : q{};

        $gender  = $regoFormRuleObj->getValue('strGender') || 0;
        $dob_min = $regoFormRuleObj->getValue('dtMinDOB')  || q{};
        $dob_max = $regoFormRuleObj->getValue('dtMaxDOB')  || q{};

        if ($dob_min) {
            ($dob_min_yyyy, $dob_min_mm, $dob_min_dd) = split('-', $dob_min);
        }

        if ($dob_max) {
            ($dob_max_yyyy, $dob_max_mm, $dob_max_dd) = split('-', $dob_max);
        }

        $m_selected = ($gender == 1) ? 'selected' : q{};
        $f_selected = ($gender == 2) ? 'selected' : q{};
    }

    my @months = qw( Month Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec );

    my $i = 0;
    my $dob_min_mm_ddl = join(q{}, map { '<option value=' .  $i .  (($i++ == $dob_min_mm) ? ' selected' : q{} ) .  ">$_</option>" } @months);

    $i = 0;
    my $dob_max_mm_ddl = join(q{}, map { '<option value='.$i .  (($i++ == $dob_max_mm) ? ' selected' : q{} ) .  ">$_</option>" } @months);

    my @rego_types;
    my $hidden_field;

    if ($form_allows_player) {
        push @rego_types, ["<input type='checkbox' name='ynPlayer' value='Y' $allow_player>", "$player_label"];
        $hidden_field = "<input type='hidden' name='ynPlayer' value='Y'>";
    }

    if ($form_allows_coach) {
        push @rego_types, ["<input type='checkbox' name='ynCoach' value='Y' $allow_coach>", "$coach_label"];
        $hidden_field = "<input type='hidden' name='ynCoach' value='Y'>";
    }

    if ($form_allows_umpire) {
        push @rego_types, ["<input type='checkbox' name='ynMatchOfficial' value='Y' " .  "$allow_umpire>", "$umpire_label"];
        $hidden_field = "<input type='hidden' name='ynMatchOfficial' value='Y'>";
    }

    if ($form_allows_official) {
        push @rego_types, ["<input type='checkbox' name='ynOfficial' value='Y' " .  "$allow_official>", "$official_label"];
        $hidden_field = "<input type='hidden' name='ynOfficial' value='Y'>";
    }

    if ($form_allows_misc) {
        push @rego_types, ["<input type='checkbox' name='ynMisc' value='Y' $allow_misc>", "$misc_label"];
        $hidden_field = "<input type='hidden' name='ynMisc' value='Y'>";
    }

    if ($form_allows_volunteer) {
        push @rego_types, ["<input type='checkbox' name='ynVolunteer' value='Y' $allow_volunteer>", "$volunteer_label"];
        $hidden_field = "<input type='hidden' name='ynVolunteer' value='Y'>";
    }

    my $regoAs;
    if (scalar @rego_types < 2) {
        $regoAs = $hidden_field;
    }
    else {
        $regoAs .= qq[<div id="regoas"><span class='label ruleslabel ruleslabel2'>Registering as:</span>];
        $regoAs .= $cgi->table( map { $cgi->Tr( $cgi->td( $_ ) ) } @rego_types );
        $regoAs .= qq[</div>];
    }

   my $save_btn = qq[<input type="submit" value="Save" class="button proceed-button">];

    my %templateData = (
        client         => $client,
        stepper_html   => $stepper_html,
        stepper_inpt   => $stepper_inpt,
        formID         => $formID,
        fieldID        => $sourceFieldID,
        actn           => 'A_ORF_oups',
        dob_min_dd     => $dob_min_dd,
        dob_min_yyyy   => $dob_min_yyyy,
        dob_max_dd     => $dob_max_dd,
        dob_max_yyyy   => $dob_max_yyyy,
        dob_min_mm_ddl => $dob_min_mm_ddl,
        dob_max_mm_ddl => $dob_max_mm_ddl,
        fieldLabel     => $fieldLabel,
        m_selected     => $m_selected,
        f_selected     => $f_selected,
        regoAs         => $regoAs,
    );
    
    if ($Data->{SystemConfig}{AllowProgramTemplateAddLevel} 
        && $Data->{'clientValues'}{'currentLevel'} >= $Data->{SystemConfig}{AllowProgramTemplateAddLevel}
        && $regoFormObj->is_form_type($Defs::REGOFORM_TYPE_MEMBER_PROGRAM) ) {
        
        # Program Registration Type (New/Returning) Filter
        push @{$templateData{'fields'}}, {
            'field' => 'intProgramFilter',
            'type'  => 'select',
            'label' => 'Program Filter',
            'current_value' => $regoFormRuleObj->getValue('intProgramFilter') || 0 ,
            'options' => [
                { 
                    'value' => 0,
                    'label' => 'No Restrictions',
                },
                { 
                    'value' => $RegoFormRuleObj::PROGRAM_NEW,
                    'label' => 'New Members Only',
                },
                { 
                    'value' => $RegoFormRuleObj::PROGRAM_RETURNING,
                    'label' => 'Returning Members Only',
                },
            ],
        };
    }
    

    my $templateFile = 'regoform/backend/rules.templ';
    my $subBody = runTemplate($Data, \%templateData, $templateFile);

    my $formName = GetFormName($Data).' (#'.$formID.')';
    my $breadcrumbs = getBreadcrumbs($client, $stepper_mode, 'Edit', 'Layout');

    return ($subBody, $formName, $breadcrumbs);

}

sub update_regoform_field_rule {
    my ($action, $Data, $assocID, $client) = @_;

    my $dbh = $Data->{'db'};
    my $cgi = new CGI;
    my $formID  = $cgi->param('fID') || 0;
    my $fieldID = $cgi->param('selected_fieldID');
    my $stepper_mode = $cgi->param('stepper');

    my $source  = substr($fieldID, 0, 1);

    $fieldID = unpack "xxA*", $fieldID; #strip first two chars

    my $added = ($source >= 3) ? 'Added' : '';

    my $regoFormFieldClass = 'RegoFormField'.$added.'Obj';
    my $regoFormFieldObj   = $regoFormFieldClass->load(db=>$dbh, ID=>$fieldID);

    my $fieldName = $regoFormFieldObj->getValue('strFieldName');

    my @fields = qw(
        strGender
        dtMinDOB_dd
        dtMinDOB_mm
        dtMinDOB_yyyy
        dtMaxDOB_dd
        dtMaxDOB_mm
        dtMaxDOB_yyyy
        ynPlayer
        ynCoach
        ynMatchOfficial
        ynOfficial
        ynMisc
        ynVolunteer
        intProgramFilter
    );
    my %fields;

    foreach my $field (@fields) {
        $fields{$field} = $cgi->param($field) if defined $cgi->param($field);
    }

    foreach (qw(dtMinDOB dtMaxDOB) ) {

        if (sum(@fields{ $_ . '_yyyy', $_ . '_mm', $_ . '_dd' }) and not check_valid_date( sprintf( "%02d/%02d/%04d", @fields{ $_ . '_dd', $_ . '_mm', $_ . '_yyyy', }))) {
            return ( 0, $cgi->div( { -class => 'warningmsg' }, 'Invalid Date' ));
        }

        $fields{$_} = sprintf( "%04d-%02d-%02d", @fields{ $_ . '_yyyy', $_ . '_mm', $_ . '_dd', });

        delete $fields{$_ . '_yyyy'};
        delete $fields{$_ . '_mm'};
        delete $fields{$_ . '_dd'};

        delete $fields{$_} if $fields{$_} eq '0000-00-00';
    }

    delete $fields{'strGender'} if exists $fields{'strGender'} and !$fields{'strGender'};

    @fields = keys %fields;

    my $regoFormRuleClass = 'RegoFormRule'.$added.'Obj';
    my $keyName = $regoFormFieldClass->getKeyName();
    my %where = (intRegoFormID=>$formID, $keyName=>$fieldID);
    $regoFormRuleClass->deleteWhere(dbh=>$dbh, where=>\%where);
    
    if (@fields) {
        my $regoFormRuleObj = $regoFormRuleClass->new(db=>$dbh);
        my $dbfields = 'dbfields';

        $regoFormRuleObj->{$dbfields} = ();
        $regoFormRuleObj->{$dbfields}{'intRegoFormID'} = $formID;
        $regoFormRuleObj->{$dbfields}{$keyName}        = $fieldID;
        $regoFormRuleObj->{$dbfields}{'strFieldName'}  = $fieldName;
        if ($added) {
            my ($entityTypeID, $entityID) = getEntityValues($Data->{'clientValues'});
            $regoFormRuleObj->{$dbfields}{'intEntityTypeID'} = $entityTypeID;
            $regoFormRuleObj->{$dbfields}{'intEntityID'}     = $entityID;
        }

        foreach my $f(@fields) {
            $regoFormRuleObj->{$dbfields}{$f}  = $fields{$f};
        }

        my $regoFormRuleID = $regoFormRuleObj->save();
    }

    return (1, $cgi->div({ -class => 'OKmsg' }, $Data->{'lang'}->txt('Field Updated')), $stepper_mode);
}

sub regoform_fields {
    my ($action, $Data, $assocID, $client, $stepper_fid) = @_;

    my $cgi = new CGI;
    my $formID = 0;

    my $stepper_html = '';
    my $stepper_mode = '';
    my $stepper_edit = 0;
    my $stepper_inpt = '';

    if ($stepper_fid) {
        $formID = $stepper_fid;
        $stepper_mode = 'add';
    }
    else {
        $formID = $cgi->param('fID') || 0;
        $stepper_mode = $cgi->param('stepper');
    }

    my $formtype = GetFormType($Data, 0, $formID);

    if ($stepper_mode) {
        $stepper_edit = 1 if $stepper_mode eq 'edit';
        $stepper_html = regoform_navigation($Data, 'flds', $formID, GetFormType($Data, 1, $formID), $stepper_edit);
        $stepper_inpt = qq[<input type="hidden" name="stepper" value="$stepper_mode">];
    }

    my $clubID = $Data->{'clientValues'}->{'clubID'} || 0;

    $assocID = getAssocFromClub($Data->{'db'}, $clubID) if $assocID == $clubID;

    my $FieldLabels = ($formtype eq 'Team')
        ? getFieldLabels($Data, $Defs::LEVEL_TEAM)
        : getFieldLabels($Data, $Defs::LEVEL_MEMBER);

    my $CustomFieldNames = getCustomFieldNames($Data) || '';

    my ($entityTypeID, $entityID) = getEntityValues($Data->{'clientValues'});
    my $permission_options = FieldConfigPermissionOptions($Data, $formtype, 'RegoForm', $entityTypeID, $entityID);

    my $regoFormObj = RegoFormObj->load(db=>$Data->{'db'}, ID=>$formID);
    my $current_values = GetRegoFormFieldPermissions($Data, $formID, $regoFormObj);

    my $l = $Data->{'lang'};
    my $intro = $l->txt('FIELDS_intro');

    my %texts = ();
    $texts{'hid'} = $l->txt('Hidden');
    $texts{'rdo'} = $l->txt('Read Only');
    $texts{'edi'} = $l->txt('Editable');
    $texts{'aoc'} = $l->txt('Add Only (Compulsory)');
    $texts{'cmp'} = $l->txt('Compulsory');

    my $formName     = GetFormName($Data).' (#'.$formID.')';
    my $breadcrumbs  = getBreadcrumbs($client, $stepper_mode, 'Edit', 'Fields');
    my $continue_btn = ($stepper_mode eq 'add') ? 'Continue' : 'Save';
    my $unescclient  = unescape($client);
    my $memberFields = get_fields_list($Data, 'Member');
    my $teamFields   = get_fields_list($Data, 'Team');

    push @$memberFields, 'intSchoolID' if $Data->{'SystemConfig'}{'Schools'};
    push @$memberFields, 'intGradeID'  if $Data->{'SystemConfig'}{'Schools'};

    $FieldLabels->{'PhotoUpload'} = $l->txt('Photo');

    my @fieldPermissions = ();

    my $field_list = $formtype  eq 'Team' ? $teamFields : $memberFields;

    push @{$field_list}, 'PhotoUpload' if $formtype ne 'Team';

    my $i = 0;

    for my $f (@$field_list) {
        my $fl = $FieldLabels->{$f};
        $fl = $CustomFieldNames->{$f}[0] || '' if !$fl;
        next if !$fl;
        my $v = ($current_values->{$f}{'perm'} || '') || ($permission_options->{$f}{'current'} || '') || 'Hidden';
        my $source = $current_values->{$f}{'source'} || 'form';
        if (!AllowPermissionUpgrade($permission_options->{$f}{'current'}, $v))  {
            $v = $permission_options->{$f}{'current'}
        }
        $v = 'Hidden' if $v eq 'ChildDefine';
        $v ||= 'Hidden';
        my %alloptions = (
            Hidden            => 1,
            ReadOnly          => 1,
            Editable          => 1,
            Compulsory        => 1,
            AddOnlyCompulsory => 1,
        );
        if (!$permission_options->{$f} or !$permission_options->{$f}{'permissions'}) {
            $permission_options->{$f} = { current=>'Hidden', permissions=>\%alloptions };
        }

        if ($regoFormObj->isNodeForm() and !$regoFormObj->isOwnForm(entityID=>$entityID)) {
            if (($source !~ /^added/) or (($source =~ /^added/) and (extractSourceEntityTypeID($source) > $entityTypeID))) {
                if ($v eq 'Hidden') { #pretty much ignore fieldconfig permissions...
                    $v = $current_values->{$f}{'perm'} if $current_values->{$f}{'perm'} ne 'Hidden';
                }
                if ($v ne 'Hidden') {
                    $permission_options->{$f}{'permissions'}{'Compulsory'} = 0 if $Defs::FieldPermWeights{$v} > $Defs::FieldPermWeights{'Compulsory'};
                    $permission_options->{$f}{'permissions'}{'Editable'}   = 0 if $Defs::FieldPermWeights{$v} > $Defs::FieldPermWeights{'Editable'};
                    $permission_options->{$f}{'permissions'}{'ReadOnly'}   = 0 if $Defs::FieldPermWeights{$v} > $Defs::FieldPermWeights{'ReadOnly'};
                    $permission_options->{$f}{'permissions'}{'Hidden'}     = 0;
                }
            }
            else { #must be added and source entityTypeID <= entityTypeID (basically means that the current level has added the field).
                my $minPerm = $current_values->{$f}{'minperm'} || '';
                if ($minPerm) {
                    $permission_options->{$f}{'permissions'}{'Compulsory'} = 0 if $Defs::FieldPermWeights{$minPerm} > $Defs::FieldPermWeights{'Compulsory'};
                    $permission_options->{$f}{'permissions'}{'Editable'}   = 0 if $Defs::FieldPermWeights{$minPerm} > $Defs::FieldPermWeights{'Editable'};
                    $permission_options->{$f}{'permissions'}{'ReadOnly'}   = 0 if $Defs::FieldPermWeights{$minPerm} > $Defs::FieldPermWeights{'ReadOnly'};
                    $permission_options->{$f}{'permissions'}{'Hidden'}     = 0 if $Defs::FieldPermWeights{$minPerm} > $Defs::FieldPermWeights{'Hidden'};
                }
            }
        }

        my $aostr       = genFieldRadioButton($f, $permission_options->{$f}{'permissions'}{'AddOnlyCompulsory'} || 0, $v, 'AddOnlyCompulsory');
        my $compulsstr  = genFieldRadioButton($f, $permission_options->{$f}{'permissions'}{'Compulsory'}        || 0, $v, 'Compulsory');
        my $editablestr = genFieldRadioButton($f, $permission_options->{$f}{'permissions'}{'Editable'}          || 0, $v, 'Editable');
        my $rostr       = genFieldRadioButton($f, $permission_options->{$f}{'permissions'}{'ReadOnly'}          || 0, $v, 'ReadOnly');
        my $hidstr      = genFieldRadioButton($f, $permission_options->{$f}{'permissions'}{'Hidden'}            || 0, $v, 'Hidden');

        push @fieldPermissions, {
            label       => $fl,
            aostr       => $aostr,
            compulsstr  => $compulsstr,
            editablestr => $editablestr,
            rostr       => $rostr,
            hidstr      => $hidstr,
        };

    }

    my %templateData = (
        stepper_html     => $stepper_html,
        intro            => $intro,
        target           => $Data->{'target'},
        continue_btn     => $continue_btn,
        texts            => \%texts,
        fieldPermissions => \@fieldPermissions,
        action           => 'A_ORF_s',
        client           => $unescclient,
        formID           => $formID,
        stepper_inpt     => $stepper_inpt,
    );

    my $templateFile = 'regoform/backend/fields.templ';
    my $subBody = runTemplate($Data, \%templateData, $templateFile);

    return ($subBody, $formName, $breadcrumbs);
}

sub extractSourceEntityTypeID {
    my ($source) = @_;
    my @arr = split('\.', $source); #could also have been done by a regex... my ($entityTypeID) = $source =~ /^added.(\d+).\d+/;
    return $arr[1];
}

sub update_regoform_fields {
    my ($action, $Data)=@_;

    my $cgi          = new CGI;
    my $formID       = $cgi->param('fID') || 0;
    my $stepper_mode = $cgi->param('stepper');
    my $dbh          = $Data->{'db'};
    my $fieldsSaved  = $Data->{'lang'}->txt('Fields saved');
    my $successSQL   = qq[<div class="OKmsg">$fieldsSaved</div>];

    my $regoFormObj = RegoFormObj->load(db=>$dbh, ID=>$formID);
    my $form_name = $regoFormObj->getValue('strRegoFormName');
    my $form_type = $regoFormObj->getValue('intRegoType');
    my ($entityTypeID, $entityID) = getEntityValues($Data->{'clientValues'});

    if ($regoFormObj->isNodeForm() and !$regoFormObj->isOwnForm(entityID=>$entityID)) {
        nodeFormAddedFields($Data, $formID, $cgi, $regoFormObj);
        return ($successSQL, '', $stepper_mode);
    }

    my $st_order = qq[SELECT strFieldName, intDisplayOrder, strPerm FROM tblRegoFormFields WHERE intRegoFormID = ? AND intType = 0];
    my $order_query = $dbh->prepare($st_order);
    $order_query->execute($formID);

    my $order_href = $order_query->fetchall_hashref('strFieldName');

    #mark the current fields as deleted prior to adding the new ones.
    my %fields = (intStatus=>-1);
    my %where  = (intRegoFormID=>$formID, intType=>0, intStatus=>{'>=',1}); #for some reason there are fields with status of 2,3,4,5...
    RegoFormFieldObj->updateWhere(dbh=>$dbh, fields=>\%fields, where=>\%where);

    my $txt_prob = $Data->{'lang'}->txt('Problem updating Fields');

    return $cgi->div( -class => 'warningmsg', "$txt_prob (1)") if $DBI::err;

    my $st    = qq[INSERT INTO tblRegoFormFields (intRegoFormID, strFieldName, intType, intDisplayOrder, strPerm) VALUES (?, ?, 0, ?, ?)];
    my $stRFR = qq[UPDATE tblRegoFormRules SET intRegoFormFieldID = ? WHERE intRegoFormID = ? AND strFieldName = ?];

    my $config_query    = $dbh->prepare($st);
    my $config_queryRFR = $dbh->prepare($stRFR);

    my $memberFields    = get_fields_list($Data, 'Member');
    my $teamFields      = get_fields_list($Data, 'Team');
    my $field_list      = (GetFormType($Data) eq 'Team') ? $teamFields : $memberFields;
    my @checkfields     = @$field_list;

    push @checkfields, 'intSchoolID', 'intGradeID' if $Data->{'SystemConfig'}{'Schools'};
    push @checkfields, 'PhotoUpload' if GetFormType($Data) ne 'Team';

    my $order_max = max( map { defined $order_href->{$_}{intDisplayOrder} ? $order_href->{$_}{intDisplayOrder} : 0 } @checkfields);

    my $dbfields = 'dbfields';

    for my $k (@checkfields)    {
        my $hidden = not(defined $cgi->param("f_$k") and ($cgi->param("f_$k") ne 'Hidden'));
        my $perm = $cgi->param("f_$k") || 'Hidden';
        my $order = $perm eq 'Hidden' ? 0 : ($order_href->{$k}{intDisplayOrder} || ++$order_max);

        #if is one of the ones marked for deletion, reinstate...
        my %where = (intRegoFormID=>$formID, strFieldName=>$k, intStatus=>-1);
        my $regoFormFieldObj = RegoFormFieldObj->loadWhere(dbh=>$dbh, where=>\%where);
        
        if ($regoFormFieldObj->isDefined()) {
            $regoFormFieldObj->{$dbfields}{'intStatus'} = 1;
            $regoFormFieldObj->{$dbfields}{'intDisplayOrder'} = $order;
            $regoFormFieldObj->{$dbfields}{'strPerm'} = $perm;
            $regoFormFieldObj->save();
        }
        else {
            $config_query->execute($formID, $k, $order, $perm);
            my $regoFormFieldID = $config_query->{mysql_insertid};
            $config_queryRFR->execute($regoFormFieldID,$formID, $k);
            #possibly should include an update here for tblRegoFormOrder fields?
            #but anticipation is that it won't be needed.
            #in fact, if the field is new, it wouldn't have been in the table...
        }

        return $cgi->div( { -class => 'warningmsg'}, "$txt_prob (2)") if $DBI::err;
    }

    #now delete any rows with a status of -1 (shouldn't be any).
    %where = (intRegoFormID=>$formID, intType=>0, intStatus=>-1);
    RegoFormFieldObj->deleteWhere(dbh=>$dbh, where=>\%where);

    auditLog($formID, $Data, 'Update Fields', 'Registration Form');

    if ( $Data->{'SystemConfig'}{'AllowRegoFormNotifications'} ) {
        $order_query->execute($formID);
        my $order_updated_href = $order_query->fetchall_hashref('strFieldName');
        genRegoFormNotifications( $Data, $entityTypeID, $entityID, $formID, $form_type, $form_name, $order_href, $order_updated_href );
    }

    return ($successSQL, '', $stepper_mode);
}

sub nodeFormAddedFields {
    my ($Data, $formID, $cgi, $regoFormObj) = @_;

    my $dbh     = $Data->{'db'};
    my $assocID = $Data->{'clientValues'}{'assocID'} || 0;
    my $clubID  = $Data->{'clientValues'}{'clubID'}  || 0;

    $clubID = 0 if $clubID < 0;

    my $memberFields = get_fields_list($Data, 'Member');
    my @checkfields  = @$memberFields;

    push @checkfields, 'intSchoolID', 'intGradeID' if $Data->{'SystemConfig'}{'Schools'};
    push @checkfields, 'PhotoUpload' if GetFormType($Data) ne 'Team';

    my $type = 0;
    my $fieldNames = ('strFieldName, intDisplayOrder, strPerm');
    my $form_name = $regoFormObj->getValue('strRegoFormName');
    my $form_type = $regoFormObj->getValue('intRegoType');
    my ($entityTypeID, $entityID) = getEntityValues($Data->{'clientValues'});
    my $nodeFormFields = getNodeFormFields($dbh, $formID, $type, $fieldNames);

    #mark the current added fields as deleted prior to adding the new ones.
    my %fields = (intStatus=>-1);
    my %where  = (intRegoFormID=>$formID, intEntityTypeID=>$entityTypeID, intEntityID=>$entityID, intType=>0, intStatus=>1);
    RegoFormFieldAddedObj->updateWhere(dbh=>$dbh, fields=>\%fields, where=>\%where);

    #Filter for determining which fields to be added to tblRegoFormFieldsAdded:
    #if the fieldName doesn't exist in the cgi params => can't have been modified.
    #if the fieldName is designated as Hidden in the cgi params => isn't an added field.
    #if the fieldName exists on the node form and it's weighted heavier than that on incoming cgi params.
    #if the fieldName has been included by way of permissions by any of the levels above.
    #if the fieldName has been included by way of adding by any of the levels above.

    my $dbfields = 'dbfields';

    foreach my $fieldName (@checkfields) {
        next if !defined $cgi->param("f_$fieldName");
        my $thisPerm = $cgi->param("f_$fieldName");
        next if $thisPerm eq 'Hidden';
        next if (exists $nodeFormFields->{$fieldName}) and (!isHeavierPerm($thisPerm, $nodeFormFields->{$fieldName}{'strPerm'}));
        next if checkHierarchicalPerms($Data, $fieldName, $entityTypeID, $entityID, $regoFormObj->getValue('intCreatedLevel'));
        next if checkHierarchicalAdds($Data, $fieldName, $formID, $entityTypeID, $entityID, $regoFormObj->getValue('intCreatedLevel'), $thisPerm);

        my $perm = $cgi->param("f_$fieldName");

        #if is one of the ones marked for deletion, reinstate...
        my %where = (intRegoFormID=>$formID, intEntityTypeID=>$entityTypeID, intEntityID=>$entityID, strFieldName=>$fieldName, intStatus=>-1);
        my $currAddedObj = RegoFormFieldAddedObj->loadWhere(dbh=>$dbh, where=>\%where);
        
        if ($currAddedObj->isDefined()) {
            $currAddedObj->{$dbfields}{'intStatus'} = 1;
            $currAddedObj->{$dbfields}{'strPerm'}   = $perm;
            $currAddedObj->save();
        }
        else {
            my $displayOrder = 0; #don't give a seq, therefore forcing field to bottom.

            my $regoFormFieldAddedObj = RegoFormFieldAddedObj->new(db=>$dbh);

            $regoFormFieldAddedObj->{$dbfields} = ();
            $regoFormFieldAddedObj->{$dbfields}{'intRegoFormID'}   = $formID;
            $regoFormFieldAddedObj->{$dbfields}{'intEntityTypeID'} = $entityTypeID;
            $regoFormFieldAddedObj->{$dbfields}{'intEntityID'}     = $entityID;
            $regoFormFieldAddedObj->{$dbfields}{'strFieldName'}    = $fieldName;
            $regoFormFieldAddedObj->{$dbfields}{'intDisplayOrder'} = $displayOrder;
            $regoFormFieldAddedObj->{$dbfields}{'strPerm'}         = $perm;

            my $regoFormFieldAddedID = $regoFormFieldAddedObj->save();

            #this will cause any old rules to be picked up.
            my %fields = (intRegoFormFieldAddedID=>$regoFormFieldAddedID);
            %where     = (intRegoFormID=>$formID, intEntityTypeID=>$entityTypeID, intEntityID=>$entityID, strFieldName=>$fieldName);
            RegoFormRuleAddedObj->updateWhere(dbh=>$dbh, fields=>\%fields, where=>\%where);
        }
    }

    #delete any rules for added rows with a status of -1.
    my $source  = 'tblRegoFormRulesAdded AS RA';
    my $join    = 'INNER JOIN tblRegoFormFieldsAdded AS FA ON RA.intRegoFormFieldAddedID=FA.intRegoFormFieldAddedID';
    $source    .= ' '.$join;
    my @fields  = ('RA.intRegoFormRuleAddedID');
    %where  = ('RA.intRegoFormID'=>$formID, 'RA.intEntityTypeID'=>$entityTypeID, 'RA.intEntityID'=>$entityID, 'FA.intStatus'=>-1);
    my ($sql, @bindVals) = getSelectSQL($source, \@fields, \%where);

    my $q = $dbh->prepare($sql);
    $q->execute(@bindVals);

    my @raIds = ();

    while (my ($raId) = $q->fetchrow_array()) {
        push @raIds, $raId;
    }

    if (@raIds) {
        my %where = (intRegoFormRuleAddedID=>{-in=>[@raIds]});
        RegoFormRuleAddedObj->deleteWhere(dbh=>$dbh, where=>\%where);
    }

    #now delete any added rows with a status of -1.
    %where = (intRegoFormID=>$formID, intEntityTypeID=>$entityTypeID, intEntityID=>$entityID, intType=>0, intStatus=>-1);
    RegoFormFieldAddedObj->deleteWhere(dbh=>$dbh, where=>\%where);

    if ( $Data->{'SystemConfig'}{'AllowRegoFormNotifications'} ) {
        my $nodeFormFields_updated = getNodeFormFields($dbh, $formID, $type, $fieldNames);
        genRegoFormNotifications( $Data, $entityTypeID, $entityID, $formID, $form_type, $form_name, $nodeFormFields, $nodeFormFields_updated );
    }

    return 1;
}

sub getNodeFormFields {
    my ($dbh, $formID, $type, $fields) = @_;

    my $sql = getRegoFormFieldListSQL(dbh=>$dbh, formID=>$formID, type=>$type, fields=>$fields);
    my @bindVars = ($formID, $type);
    my $q = getQueryPreparedAndBound($dbh, $sql, \@bindVars);

    $q->execute();

    my $nodeFormFields = $q->fetchall_hashref('strFieldName');

    $q->finish();

    return $nodeFormFields;
}

sub regoform_field_order {
    my ($action, $Data, $assocID, $client, $stepper_fid) = @_;

    my $cgi = new CGI;
    my $formID = 0;

    my $stepper_html = '';
    my $stepper_mode = '';
    my $stepper_edit = 0;
    my $stepper_inpt = '';

    if ($stepper_fid) {
        $formID = $stepper_fid;
        $stepper_mode = 'add';
    }
    else {
        $formID = $cgi->param('fID') || 0;
        $stepper_mode = $cgi->param('stepper');
    }

    my $formKey = getRegoPassword($formID);

    if ($stepper_mode) {
        $stepper_edit = 1 if $stepper_mode eq 'edit';
        $stepper_html = regoform_navigation($Data, 'lout', $formID, GetFormType($Data, 1, $formID), $stepper_edit);
        $stepper_inpt = qq[<input type="hidden" name="stepper" value="$stepper_mode">];
    }

    my $clubID = $Data->{'clientValues'}->{'clubID'} || 0;
    my $realmID = $Data->{'Realm'} || 0;

    $assocID = getAssocFromClub($Data->{'db'}, $clubID) if $assocID == $clubID;

    my $formName = GetFormName($Data).' (#'.$formID.')';

    my $breadcrumbs = getBreadcrumbs($client, $stepper_mode, 'Edit', 'Layout');

    my $continue_btn = ($stepper_mode eq 'add')
        ? qq[<input type="submit" value="Continue" class="button proceed-button" name="submitbutton">]
        : '';

    my $dbh = $Data->{'db'};
    my $regoFormObj = RegoFormLayoutsObj->load(db=>$dbh, ID=>$formID); #RegoFormLayoutsObj is a subclass of RegoFormObj (just has as extra method).
    my ($entityTypeID, $entityID) = getEntityValues($Data->{'clientValues'});

    my $checkOwner = (($regoFormObj->isNodeForm() and !$regoFormObj->isOwnForm(entityID=>$entityID)) or $regoFormObj->isLinkedForm()) ? "$entityTypeID.$entityID" : '';

    my $fields = $regoFormObj->getLayouts(Data=>$Data, entityTypeID=>$entityTypeID, entityID=>$entityID);

    my $formtype = GetFormType($Data);

    my @fieldData = ();

    foreach my $field (@$fields ) { #already sorted
        my $field_name   = @$field[0]; #not used currently
        my $field_order  = @$field[1]; #not used currently
        my $field_text   = @$field[2]; #not used currently
        my $field_id     = @$field[3];
        my $field_type   = @$field[4];
        my $field_source = @$field[5];
        my $field_owner  = @$field[6];
        my $field_label  = GetFieldLabel($Data, $formtype, @$field);

        my @field_links = ();
        my $extra_class = '';

        my $createLinks = (!$checkOwner or ($checkOwner and $checkOwner eq $field_owner)) ? 1 : 0;

        if ('12' =~ /$field_type/) {
            if ($createLinks) {
                my $edttyp = ($field_type == 1) ? 'edthdr' : 'edttxt';
                push @field_links, {prefix=>'rem', class=>'remhdr thspecial',  text=>'Remove'};
                push @field_links, {prefix=>'cfg', class=>'config thspecial',  text=>'Rules'};
                push @field_links, {prefix=>'edt', class=>"$edttyp thspecial", text=>'Edit'};
            }
            $extra_class = ($field_type == 1) ? ' RO_headerblock' : ' RO_textblock';
        }
        elsif ($field_label !~ /Step 1$/) {
            push @field_links, {prefix=>'cfg', class=>'config', text=>'Rules'} unless !$createLinks;
        }

        push @fieldData, {
            field_id    => $field_source.'s'.$field_id,
            field_label => $field_label,
            field_links => \@field_links,
            extra_class => $extra_class,
        };
    }

    my %templateData = (
        target       => $Data->{'target'},
        client       => $client,
        stepper_html => $stepper_html,
        stepper_inpt => $stepper_inpt,
        continue_btn => $continue_btn,
        formID       => $formID,
        formKey      => $formKey,
        actn         => 'A_ORF_ou',
        fieldData    => \@fieldData,
        isNodeForm   => $regoFormObj->isNodeForm(),
        isOwnForm    => $regoFormObj->isOwnForm(entityID=>$entityID),
    );

    my $templateFile = 'regoform/backend/layout.templ';
    my $body = runTemplate($Data, \%templateData, $templateFile);

    return ($body, $formName, $breadcrumbs);
}

sub GetFieldLabel {
    my ($Data, $formtype, $field) = @_;

    my $level = $Defs::LEVEL_MEMBER;
    $level = $Defs::LEVEL_TEAM if $formtype eq 'Team';

    my $FieldLabels = getFieldLabels($Data, $level);
    my $CustomFieldNames=getCustomFieldNames($Data) || '';

    if ($field =~ /^RF(.*)\|regoform\|(.*)$/) {
        my $text = $2;
        $text ||= '';
        $text =~ s/\s+$//;
        my $text2 = $text;
        $text = substr($text, 0, 30);

        if (length($text2) gt length($text)) {
            $text =~ s/\s+$//;
            $text .= '...';
        }

        for ($1) {
            return "H-Block => $text" if (/^HEADER$/);
            return "T-Block => $text " if (/^TEXT$/);
        }
    }

    my $field_suffix = is_page_one_field($field) ? ' - Step 1' : q{};

    return $FieldLabels->{$field}.$field_suffix if ($FieldLabels->{$field});

    return $CustomFieldNames->{$field}[0].$field_suffix if ($CustomFieldNames->{$field});

    return $field;

}

sub regoform_field_order_update {
    #is now just a bare-bones section to facilitate stepper
    my ($action, $Data, $assocID, $client, $return_updated_field)=@_;
    my $cgi = new CGI;
    my $formID = $cgi->param('fID');

    my $stepper_mode = $cgi->param('stepper');

    my $msg = join( q{}, '<div class="OKmsg">', $Data->{'lang'}->txt('Field Order Updated'), '</div>',);

    my($m, $t, $b) = regoform_field_order(@_);
    return ($msg.$m, $t, $b, $stepper_mode, $formID);
}

sub GetRegoFormFieldPermissions {
    my ($Data, $formID, $regoFormObj) = @_;

    my $dbh     = $Data->{'db'};
    my $assocID = $Data->{'clientValues'}{'assocID'} || 0;
    my $clubID  = $Data->{'clientValues'}{'clubID'}  || 0;

    $clubID = 0 if $clubID < 0;

    my ($currLevel, $currID) = getEntityValues($Data->{'clientValues'});

    my %config = ();

    my $statement = qq[SELECT intRegoFormFieldID, strFieldName, strPerm FROM tblRegoFormFields WHERE intRegoFormID=? AND intType=0];

    my $query = $dbh->prepare($statement);
    $query->execute($formID);

    while (my $dref = $query->fetchrow_hashref()) {
        $config{$dref->{'strFieldName'}}{'perm'}    = $dref->{'strPerm'};
        $config{$dref->{'strFieldName'}}{'source'}  = 'form';
        $config{$dref->{'strFieldName'}}{'minperm'} = $dref->{'strPerm'} if $regoFormObj->isNodeForm() and !$regoFormObj->isOwnForm(entityID=>$currID);
    }

    if ($regoFormObj->isNodeForm() and !$regoFormObj->isOwnForm(entityID=>$currID)) {

        my $entityStructure = getEntityStructure($Data, $currLevel, $currID, $regoFormObj->getValue('intCreatedLevel'), 1); #get topdown.

        foreach my $entityArr (@$entityStructure) {
            my ($level, $entityID) = @$entityArr;

            my %where  = (intRegoFormID=>$formID, intEntityTypeID=>$level, intEntityID=>$entityID, intType=>0, intStatus=>1);

            my $regoFormFieldAddedObjs = RegoFormFieldAddedObj->getList(dbh=>$dbh, where=>\%where);

            foreach my $regoFormFieldAddedObj(@$regoFormFieldAddedObjs) {
                my $fieldName = $regoFormFieldAddedObj->getValue('strFieldName');
                my $thisPerm  = $regoFormFieldAddedObj->getValue('strPerm');
                if (exists $config{$fieldName}) {
                    if (isHeavierPerm($thisPerm, $config{$fieldName}{'perm'})) { #if this perm outweighs the existing one...
                        my $etid = $regoFormFieldAddedObj->getValue('intEntityTypeID');
                        my $eid  = $regoFormFieldAddedObj->getValue('intEntityID');
                        $config{$fieldName}{'minperm'} = $config{$fieldName}{'perm'}; #facilitates min permission to set fields grid to.
                        $config{$fieldName}{'perm'}    = $thisPerm;
                        $config{$fieldName}{'source'}  = "added.$etid.$eid";
                    }
                }
            }
        }
    }

    return \%config;
}

sub is_page_one_field {
    my($field) = @_;

    foreach ( qw(strFirstname strSurname dtDOB intGender intPlayer intCoach intUmpire intOfficial intMisc)) {
        return 1 if $field eq $_;
    }

    return;
}

sub not_compulsory_for_team_form {
    my($field) = @_;

    foreach ( qw(strFirstname strSurname dtDOB intGender strSuburb strPostalCode)) {
        return 1 if $field eq $_;
    }

    return;
}

sub getAssocFromClub {
    my ($db, $clubID) = @_;

    my $statement = qq[SELECT intAssocID FROM tblAssoc_Clubs WHERE intClubID = $clubID];

    my $query = $db->prepare($statement) or query_error($statement);
    $query->execute or query_error($statement);
    my ($assocID) = $query->fetchrow_array();
    return $assocID;
}

sub create_default_form_product {

    my ($db, $formID,  $assocID, $realmID, $subRealmID, $clubID ) = @_;
    my ($statement, $query);

    my $product_name = 'Default PayMySport testing product';

    $statement = <<"EOS";
SELECT intProductID
FROM   tblProducts
WHERE  intAssocID = $assocID
AND    intRealmID = $realmID
AND    intCreatedLevel = $Defs::LEVEL_CLUB
AND    intCreatedID  = $clubID
AND    strName = ?
EOS

    $query = $db->prepare($statement) or query_error($statement);
    $query->execute($product_name) or query_error($statement);

    my ($productID) = $query->fetchrow_array();

    unless ($productID) {
        $statement = <<"EOS";
INSERT INTO tblProducts (
    intAssocID,
    intMinSellLevel,
    intRealmID,
    strName,
    curDefaultAmount,
    intCreatedLevel,
    intCreatedID,
    strProductNotes,
    strGroup,
    intAllowMultiPurchase,
    intInactive,
    intAllowQtys,
    strGSTText,
    intMinChangeLevel,
    intIsEvent
)
VALUES (
    $assocID,
    0,
    $realmID,
    'Default PayMySport testing product',
    '1.00',
    $Defs::LEVEL_CLUB,
    $clubID,
    '',
    'Testing',
    1,
    0,
    1,
    'Includes GST',
    0,
    0
)
EOS

        $query = $db->prepare($statement) or query_error($statement);
        $query->execute or query_error($statement);
        $productID = $query->{mysql_insertid};
    }

    $statement = <<"EOS";
INSERT INTO tblRegoFormProducts (
    intRegoFormID,
    intAssocID,
    intRealmID,
    intSubRealmID,
    intProductID,
    intRegoTypeLevel
)
VALUES (
    $formID,
    $assocID,
    $realmID,
    $subRealmID,
    $productID,
    $Defs::LEVEL_MEMBER
)
EOS

    $query = $db->prepare($statement) or query_error($statement);
    $query->execute or query_error($statement);

    return;
}

sub genFieldRadioButton {
  my ($field, $available, $current_permission, $value) = @_;

  return '&nbsp;' if !$available;
  my $checked = $current_permission eq $value ? ' CHECKED ' : '';

  return qq[ <input type="radio" value="$value" name="f_$field" $checked class="nb">];
}

sub genRegoFormNotifications {
    my ( $Data, $entityTypeID, $entityID, $form_id, $form_type, $form_name, $old_fields_ref, $new_fields_ref ) = @_;

    my $dbh = $Data->{'db'};
    my $st_notification = qq[INSERT INTO tblRegoFormNotifications ( intEntityTypeID, intEntityID, intRegoFormID, dtCreated, strTitle, intNotifiedStatus ) VALUES ( ?, ?, ?, NOW(), ?, 0 )];
    my $q_notification = $dbh->prepare($st_notification);
    my $st_item = qq[INSERT INTO tblRegoFormNotificationItems ( intRegoFormNotificationID, strType, strTypeName, strOldValue, strNewValue, dtCreated ) VALUES ( ?, ?, ?, ?, ?, NOW() )];
    my $q_item = $dbh->prepare($st_item);

    my %permission_names = get_permission_names();
    my $timestamp = localtime(time);
    my $need_notified = 0;
    my @diffs = ();

    for my $field ( keys %$old_fields_ref ) {
        my $perm = $old_fields_ref->{$field}->{'strPerm'} || '';
        my $perm_updated = $new_fields_ref->{$field}->{'strPerm'} || '';
        if ( ( $perm eq 'Hidden' or $perm_updated eq 'Hidden' ) and ( $perm ne $perm_updated ) ) {
            my $field_label = GetFieldLabel( $Data, $form_type, $field );
            push @diffs, [ 'Field', $field_label, $permission_names{$perm}, $permission_names{$perm_updated} ];
            $need_notified = 1;
        }
    }

    if ($need_notified) {
        $q_notification->execute( $entityTypeID, $entityID, $form_id, qq[$form_name has been changed on $timestamp.] );
        my $notification_id = $q_notification->{mysql_insertid};
        for my $diff (@diffs) {
            $q_item->execute( $notification_id, @$diff );
        }
    }
}

1;
