#
# $Header: svn://svn/SWM/trunk/web/RegoForm.pm 10840 2014-02-27 23:24:15Z apurcell $
#

package RegoForm;

require Exporter;

@ISA =  qw(Exporter);

@EXPORT = qw(
    getRegoFormText
    regoform_text_edit
    update_regoformtext
    regoform_products
    update_regoform_products
    regoform_teamcomps
    update_regoform_teamcomps
    GetFormType
    GetFormName
    update_regoform_status
    getBreadcrumbs
    HTML_breadcrumbs
    hidden_fields
    getProductsTabOnly
    regoform_notifications
    update_regoform_notifications
    pack_notif_bits
);

use strict;
use lib ".", "RegoForm/";

use CGI qw(param unescape Vars);
use Reg_common;
use ConfigOptions qw(getAssocSubType);
use Products;
use Utils;
use MD5;
use AuditLog;
use RegoFormStepper;
use RegoFormObj;
use RegoFormUtils;
use ContactsObj;
use TTTemplate;

use RegoFormCreateFromTemplate qw(create_from_template);
use RegoFormStepper;
use RegoFormFields;


use RegoFormProductAddedObj;
use RegoFormProductAddedSQL;
use RegoFormConfigAddedObj;
use RegoFormConfigAddedSQL;

sub getRegoFormText {
    my ($Data)=@_;

    my $cgi = new CGI;
    my $formID = $Data->{'RegoFormID'} || untaint_number($cgi->param('fID')) || 0;
    my $realmID=$Data->{'Realm'} || 0;
    my $realmSubType=$Data->{'RealmSubType'} || 0;
    my $assocID=$Data->{'clientValues'}{'assocID'} || -1;
    my $subtype=getAssocSubType($Data->{'db'},$assocID) || 0;
    my $st = q[
        SELECT intAssocID,
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
               intTC_AgreeBox,
               intRegoFormID
        FROM tblRegoFormConfig
        WHERE (intAssocID=0 or intAssocID = ?)
            AND (intSubRealmID = ? or intSubRealmID=0)
            AND intRealmID = ?
            AND intRegoFormID IN(0, ?)
        ORDER BY intSubRealmID ASC, intAssocID ASC, intRegoFormID ASC
    ];
    my $query = $Data->{'db'}->prepare($st);
    $query->execute( $assocID, $realmSubType, $realmID, $formID);
    my %Text=();

    my @textfields = qw(
        strPageOneText
        strTopText
        strTermsCondHeader
        strTermsCondText
        intTC_AgreeBox
        strBottomText
        strSuccessText
        strAuthEmailText
        strIndivRegoSelect
        strTeamRegoSelect
        strPaymentText
    );

    #nationalrego.
    my $dbh = $Data->{'db'};
    my $regoFormObj = RegoFormObj->load(db=>$dbh, ID=>$formID);

    LEVEL: while (my $dref = $query->fetchrow_hashref()) {

        if (($dref->{'intSubRealmID'} and $dref->{'intSubRealmID'} != $subtype) ) {
            next LEVEL if($assocID>0);
        }
        
        FIELD: foreach my $textfield ( @textfields ) {
            next FIELD unless $dref->{$textfield};

            $Text{$textfield} = $dref->{$textfield} if ($dref->{$textfield});

            $Text{'SetByRealm'} = 1 unless (($dref->{'intAssocID'} and $dref->{'intRegoFormID'}) or $regoFormObj->isNodeForm());
            $Text{'SetByRealm_'.$textfield} = 1 if ($Text{'SetByRealm'} and $Text{'SetByRealm'} == 1  and (! $dref->{'intAssocID'} or ! $dref->{'intRegoFormID'}));
        }
    }
    if ($regoFormObj->isNodeForm()) {
        my ($currLevel, $entityID) = getEntityValues($Data->{'clientValues'});
        
        if (!$regoFormObj->isOwnForm(entityID=>$entityID)) {
            my $regoFormConfigAddedObj = RegoFormConfigAddedObj->loadByFormEntityTypeEntityID(dbh=>$dbh, formID=>$formID, entityID=>$entityID, entityTypeID=>$currLevel);
            if ($regoFormConfigAddedObj) {
                $Text{'strTermsCondHeader'} = $regoFormConfigAddedObj->getValue('strTermsCondHeader');; 
                $Text{'strTermsCondText'}   = $regoFormConfigAddedObj->getValue('strTermsCondText');
            }
            else {
                $Text{'strTermsCondHeader'} = '';
                $Text{'strTermsCondText'}   = '';
            }
        }
    }

    my @rego_as;

    foreach my $rego_type (qw( Player Coach Umpire Official Misc Volunteer )) {
        my $rt_name = "d_int$rego_type";
        next unless param($rt_name);

        my $rego_label;

        if ($Data->{'SystemConfig'}{$rego_type.'Label'}) {
            $rego_label = $Data->{'SystemConfig'}{$rego_type.'Label'};
        }
        elsif ($rego_type eq 'Umpire') {
            $rego_label = 'Match Official';
        }
        else {
            $rego_label = $rego_type;
        }

        my $rt_field = hidden_fields( $rt_name => 1 );

        push @rego_as, "$rego_label $rt_field";
    }

    if (scalar @rego_as) {
        $Text{strRegoAs} = join(
            q{},
            'Registering as ',

            ((scalar @rego_as == 1)
                ? $rego_as[0]
                : $cgi->ul( $cgi->li( \@rego_as ) )
            ),

            '<br><br>',
        );
    }

    my $TC_AgreeBox_text = $Data->{'SystemConfig'}{'regoform_CustomTCText'} || 'I have read and agree to the Terms and Conditions';

    $Text{'TC_AgreeBox'} = $Text{'intTC_AgreeBox'} 
        ? qq[
            <span style="font-size:14px;color:red;">
              <b>$TC_AgreeBox_text <input type="checkbox" value="1" name="tcagree"></b> <img src="images/compulsory.gif" alt="" border=0>
            </span>
          ]
        : q{};
            
    return \%Text;
}

sub regoform_text_edit  {
    my($Data, $stepper_fid)=@_;

    my ($formID, $formType, $stepper_html, $stepper_mode, $stepper_edit, $stepper_inpt) = get_stepper_stuff($Data, $stepper_fid, 'mess');
    $formType = GetFormType($Data);
    my $realmID=$Data->{'Realm'} || 0;
    my $target=$Data->{'target'};
    my $cl  = setClient($Data->{'clientValues'});
    my $unesc_cl=unescape($cl);
    my $assocID=$Data->{'clientValues'}{'assocID'} || $Defs::INVALID_ID;

    my $RegoText=getRegoFormText($Data);
    #nationalrego.
    my $dbh         = $Data->{'db'};
    my $currLevel   = $Data->{'clientValues'}{'currentLevel'};
    my $currID      = getEntityID($Data->{'clientValues'});
    my $regoFormObj = RegoFormObj->load(db=>$dbh, ID=>$formID);
    my $disableText = ($regoFormObj->isNodeForm() and !$regoFormObj->isOwnForm(entityID=>$currID)) ? 1 : 0;

    my $body='';
    my $checked = $RegoText->{'intTC_AgreeBox'} ? 'checked' : '';

    my $formName = GetFormName($Data).' (#'.$formID.')';
    my $breadcrumbs = getBreadcrumbs($cl, $stepper_mode, 'Edit', 'Text Messages');
    
    my $continue_btn = ($stepper_mode eq 'add')
        ? qq[<input type="submit" value="Continue" class="button proceed-button">]
        : qq[<input type="submit" value="Save" class="button proceed-button">];

    # The below form code is changed to display (as read only) the Realm set fields and allow others
    # to be edited by the club/assoc
    $body=qq[
        <script type="text/javascript">
            jQuery(function() {
                jQuery('#texttabs').tabs({ selected: 0 });
            });
        </script>
        $stepper_html
        <p>Customise the text that displays at various stages of the registration process.</p>

        <form action="$target" method="POST">
            <input type="hidden" name="a" value="A_ORF_tu">
            <input type="hidden" name="client" value="$unesc_cl">
            <input type="hidden" name="fID" value="$formID">
            $stepper_inpt
            $continue_btn
    ];

    my $initialinfo = ($formType eq 'Member')
        ? qq[<li><a href="#firstTextTab">Initial Information</a></li>]
        : '';

    $body .= qq[
        <br>
        <div id="texttabs" style="float:left;width:80%;margin-top:0;margin-bottom:0;">
            <ul>
                <li><a href="#individualTextTab">Choose Type</a></li>
                                $initialinfo
                <li><a href="#fullInfoTab">Full Information</a></li>
                <li><a href="#completionTextTab">Summary</a></li>
                <li><a href="#ccardTextTab">Credit Card Payment</a></li>
                <li><a href="#emailTextTab">Confirmation Email</a></li>
            </ul>
            <div id="individualTextTab">
    ];
    if ($formType eq 'Member') {
        $body .= qq[
            <span class="label">This text will appear on the first page above the login section.</span><br>
        ];
#       $body .= $RegoText->{'SetByRealm_strIndivRegoSelect'} 
        $body .= ($RegoText->{'SetByRealm_strIndivRegoSelect'} or $disableText)
            ? qq[ <div>$RegoText->{'strIndivRegoSelect'}</div><br>] 
            : qq[ <textarea name="indivregoselect" cols="70" rows="17">$RegoText->{'strIndivRegoSelect'}</textarea>];
    }

    if ($formType eq 'Team') {
        $body .= qq[
            <span class="label">This text will appear on the first page above the login section.</span><br>
        ];        

        $body .= $RegoText->{'SetByRealm_strTeamRegoSelect'} 
            ? qq[ <div>$RegoText->{'strTeamRegoSelect'}</div><br>] 
            : qq[ <textarea name="teamregoselect" cols="70" rows="17">$RegoText->{'strTeamRegoSelect'}</textarea>];
    }

    $body .= qq[</div>];
    if ($formType eq 'Member') {
        $body .= qq[
            <div id="firstTextTab">
            <span class="label">This text will appear at the top of the 'Initial Information' page.</span>
            <br>
        ];

#       $body .= $RegoText->{'SetByRealm_strPageOneText'}
        $body .= ($RegoText->{'SetByRealm_strPageOneText'} or $disableText)
            ? qq[ <div>$RegoText->{'strPageOneText'}</div><br>]
            : qq[ <textarea name="pageone_text" cols="70" rows="17">$RegoText->{'strPageOneText'}</textarea>];
                
        $body .= qq[ </div> ];

    }
    $body .= qq[
            <div id="fullInfoTab">
            <span class="label">This text will appear at the top of the 'Full Information' page.</span><br>
    ];

#   $body .= $RegoText->{'SetByRealm_strTopText'} 
    $body .= ($RegoText->{'SetByRealm_strTopText'} or $disableText)
           ? qq[ <div>$RegoText->{'strTopText'}</div><br>] 
           : qq[ <textarea name="toptext" cols="70" rows="15">$RegoText->{'strTopText'}</textarea><br>];

    $body .= qq[ <span class="label">This text will appear at the bottom of the 'Full Information' page, above any Terms & Conditions or Opt Ins.</span><br> ];           

#   $body .= (exists $RegoText->{'SetByRealm_strBottomText'} )
    $body .= (exists $RegoText->{'SetByRealm_strBottomText'} or $disableText)
        ? qq[ <div>$RegoText->{'strBottomText'}</div><br>]
        : qq[ <textarea name="bottomtext" cols="70" rows="15">$RegoText->{'strBottomText'}</textarea><br> ];

    $body .= $RegoText->{'SetByRealm_strTermsCondText'} 
        ? qq[ <span class="label">These Terms & Conditions will appear at the very bottom of the 'Full Information' page.</span><br>]
        : qq[ <span class="label">This is where any Terms & Conditions should be entered, the smaller of the two boxes being for an optional header. <br>The T&Cs will appear at the very bottom of the 'Full Information' page, under the product selection area.</span><br>];

    $body .= $RegoText->{'SetByRealm_strTermsCondHeader'} 
        ? qq[<div style="display:block;background-color:#f9f9f9;margin-left:2px;width:478px;height:20px;border-style:solid;border-width:1px;border-color:silver;margin-bottom:2px;line-height:20px;">$RegoText->{'strTermsCondHeader'}</div>]
        : qq[<input type="text" name="tchdr" value="$RegoText->{'strTermsCondHeader'}" style="display:block;width:478px">];

    $body .= $RegoText->{'SetByRealm_strTermsCondText'} 
        ? qq[ <div style="background-color:#f9f9f9;margin-left:2px;width:478px;height:264px;overflow:auto;border-style:solid;border-width:1px;border-color:silver"><pre>$RegoText->{'strTermsCondText'}</pre></div><br>] 
        : qq[ <textarea name="tctext" cols="70" rows="15">$RegoText->{'strTermsCondText'}</textarea><br><br>];

    $body .= $RegoText->{'SetByRealm_intTC_AgreeBox'} 
        ? qq[ <div>Yes</div><br>]
        : qq[ <input type="checkbox" name="tcagree" value="1" $checked>];

    $body .= qq[<span class="label">Include an "I Agree to the above Terms & Conditions" mandatory checkbox?</span>];           

    $body .= qq[</div><div id="completionTextTab">];
    $body .= qq[<span class="label">This text will appear at the bottom of the 'Summary' section.</span><br>];           

#   $body .= $RegoText->{'SetByRealm_strSuccessText'} 
    $body .= ($RegoText->{'SetByRealm_strSuccessText'}  or $disableText)
        ? qq[ <div>$RegoText->{'strSuccessText'}</div><br>] 
        : qq[ <textarea name="successtext" cols="70" rows="17">$RegoText->{'strSuccessText'}</textarea>];

    $body .= qq[</div><div id="emailTextTab">];

    $body .= qq[<span class="label">This text will appear at the bottom of the registration confirmation email containing participants username & password.</span>];           

#   $body .= $RegoText->{'SetByRealm_strAuthEmailText'} 
    $body .= ($RegoText->{'SetByRealm_strAuthEmailText'} or $disableText)
        ? qq[ <div>$RegoText->{'strAuthEmailText'}</div><br>] 
        : qq[ <textarea name="authemailtext" cols="70" rows="16">$RegoText->{'strAuthEmailText'}</textarea>];

    $body .= qq[</div>];

    $body .= qq[<div id="ccardTextTab">];

    $body .= qq[<span class="label">This text will appear at the top of the credit card payments page.</span><br>];

#   $body .= $RegoText->{'SetByRealm_strPaymentText'} 
    $body .= ($RegoText->{'SetByRealm_strPaymentText'}  or $disableText)
        ? qq[ <div>$RegoText->{'strPaymentText'}</div><br>] 
        : qq[ <textarea name="paymenttext" cols="70" rows="17">$RegoText->{'strPaymentText'}</textarea>];

    $body .= qq[</div></div>];

    $body .= qq[
        <div style="clear:both;"></div>
        $continue_btn
        </form>
    ];

    return ($body, $formName, $breadcrumbs);
}

sub update_regoformtext {
    my($Data)=@_;

    my $realmID=$Data->{'Realm'} || 0;
    my $RealmSubType=$Data->{'RealmSubType'} || 0;
    my $assocID=$Data->{'clientValues'}{'assocID'} || $Defs::INVALID_ID;

    my $cgi = new CGI;
    my $formID = $cgi->param('fID') || 0;

    #my $stepper_mode = $cgi->param('stepper');
    #my $successSQL ='';

    my $db           = $Data->{'db'};
    my $regoFormObj = RegoFormObj->load(db=>$db, ID=>$formID);
    my ($entityTypeID, $entityID) = getEntityValues($Data->{'clientValues'});
    return nodeFormAddedConfig($Data, $formID, $cgi, $regoFormObj, $entityID, $entityTypeID) if $regoFormObj->isNodeForm() and !$regoFormObj->isOwnForm(entityID=>$entityID);

    my $stepper_mode = $cgi->param('stepper');
    my $successSQL ='';
    my $st_del = q[
        DELETE FROM tblRegoFormConfig
        WHERE intAssocID = ?
            AND intRealmID = ?
            AND intRegoFormID = ?
    ];

    $Data->{'db'}->do(
        $st_del,
        undef, 
        $assocID, 
        $realmID, 
        $formID
    );

    my %RegoText=();
    $RegoText{'strPageOneText'}     = param('pageone_text')    || '';
    $RegoText{'strTopText'}         = param('toptext')         || '';
    $RegoText{'strTermsCondHeader'} = param('tchdr')           || '';
    $RegoText{'strTermsCondText'}   = param('tctext')          || '';
    $RegoText{'intTC_AgreeBox'}     = param('tcagree')         || 0;
    $RegoText{'strBottomText'}      = param('bottomtext')      || '';
    $RegoText{'strAuthEmailText'}   = param('authemailtext')   || '';
    $RegoText{'strIndivRegoSelect'} = param('indivregoselect') || '';
    $RegoText{'strTeamRegoSelect'}  = param('teamregoselect')  || '';
    $RegoText{'strSuccessText'}     = param('successtext')     || '';
    $RegoText{'strPaymentText'}     = param('paymenttext')     || '';

    for my $k (keys %RegoText)  { $RegoText{$k}||=''; $RegoText{$k}=~s/<br>/\n/g;   }
    
    my $st_insert = q[
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
        VALUES ( ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ? )
    ];

    $Data->{'db'}->do(
        $st_insert,
        undef,
        $formID,
        $assocID,
        $realmID,
        $RealmSubType,
        $RegoText{'strPageOneText'},
        $RegoText{'strTopText'},
        $RegoText{'strBottomText'},
        $RegoText{'strSuccessText'},
        $RegoText{'strAuthEmailText'},
        $RegoText{'strIndivRegoSelect'},
        $RegoText{'strTeamRegoSelect'},
        $RegoText{'strPaymentText'},
        $RegoText{'strTermsCondHeader'},
        $RegoText{'strTermsCondText'},
        $RegoText{'intTC_AgreeBox'}
    );

    my $subBody = ($DBI::err)
        ? qq[<div class="warningmsg">There was a problem changing the text</div>]
        : qq[<div class="OKmsg">Messages saved</div>]; 

    auditLog($formID, $Data, 'Update Text', 'Registration Form');
    
    return ($subBody, '', $stepper_mode);
}

sub regoform_teamcomps {
    my($Data, $stepper_fid)=@_;

    my ($formID, $formType, $stepper_html, $stepper_mode, $stepper_edit, $stepper_inpt) = get_stepper_stuff($Data, $stepper_fid, 'comp');

    my $realmID=$Data->{'Realm'} || 0;
    my $target=$Data->{'target'};
    my $cl  = setClient($Data->{'clientValues'});
    my $unesc_cl=unescape($cl);
    my $assocID=$Data->{'clientValues'}{'assocID'} || $Defs::INVALID_ID;
    my %currentComps=();

    my $formName = GetFormName($Data).' (#'.$formID.')';

    my $breadcrumbs = getBreadcrumbs($cl, $stepper_mode, 'Edit', 'Team Competitions');

    my $st=qq[
        SELECT intCompID
        FROM tblRegoFormComps
        WHERE intRealmID = ?
            AND (intAssocID = ? OR intAssocID=0)
            AND (intSubRealmID=0 OR intSubRealmID = ? )
            AND intRegoFormID = ?
    ];

    my $query = $Data->{'db'}->prepare($st);

    $query->execute(
            $realmID,
            $assocID,
            $Data->{'RealmSubType'},
            $formID,
    );

    while (my ($id)=$query->fetchrow_array()) {
        $currentComps{$id}=1;
    }

    my $comps='';

    $st = qq[
        SELECT C.intCompID, C.strTitle, DATE_FORMAT(dtStart,'%d/%m/%Y') as dtStart
        FROM tblAssoc_Comp as C
        WHERE C.intAssocID = ? AND C.intRecStatus = ?
        ORDER BY C.dtStart DESC, C.strTitle
    ];

    $query = $Data->{'db'}->prepare($st);
    $query->execute( $assocID, $Defs::RECSTATUS_ACTIVE ) ;

    my $body='';
    my $i=0;
    while (my $dref=$query->fetchrow_hashref()) {
        my $shade=$i%2==0? 'class="rowshade" ' : '';
        $i++;
        my $checked= $currentComps{$dref->{'intCompID'}} ? ' CHECKED ' : '';

        my $field =  qq[ <input type="checkbox" name="rfcomp_$dref->{'intCompID'}" value="1" $checked>];

        $comps.=qq[
            <tr>
                <td $shade>$field</td>
                <td $shade>$dref->{'strTitle'}</td>
                <td $shade>$dref->{'dtStart'}</td>
            </tr>
        ];
    }
    $comps=qq[
        <div style="width:95%">
            <table class="listTable" id="comps">
                <thead>
                    <tr>
                        <th>Active</th>
                        <th>Competition Name</th>
                        <th>Start Date</th>
                    </tr>
                </thead>
                $comps
            </table>
        </div>
    ] if $comps;

    my $choose_comps = '';
    my $save_comps1 = '';
    my $save_comps2 = '';

    if ($comps) {
        $save_comps1 = ($stepper_mode eq 'add')
           ? qq[<input type="submit" value="Continue" class="button proceed-button">]
           : qq[<input type="submit" value="Save" class="button proceed-button">];
        $save_comps2 = $save_comps1;
        $choose_comps = qq[<p>Choose which competitions to make available for selection on the registration form.</p>];
    }
    elsif ($stepper_mode eq 'add') {
        $save_comps2 = qq[<input type="submit" value="Continue" class="button proceed-button">];
    }

    $comps ||= qq[<div class="warningmsg">No Competitions could be found for inclusion on the registration form.</div>];

    $body = qq[
        <link rel="stylesheet" type="text/css" href="css/tablescroll.css"/>
        <script src="js/jquery.tablescroll.js"></script>
        <script type="text/javascript">
            jQuery().ready(function() {
                jQuery("#comps").tableScroll({
                    height: 330
                });
            });
        </script>
        $stepper_html
        <form action="$target" method="POST">
            $choose_comps
            $save_comps1
            $comps
            <input type="hidden" name="a" value="A_ORF_tcu">
            <input type="hidden" name="client" value="$unesc_cl">
            <input type="hidden" name="fID" value="$formID">
            $stepper_inpt
            $save_comps2
        </form>
    ];

    return ( $body, $formName, $breadcrumbs);
}

sub regoform_products {
    my ($Data, $stepper_fid) = @_;

    my ($formID, $formType, $stepper_html, $stepper_mode, $stepper_edit, $stepper_inpt) = get_stepper_stuff($Data, $stepper_fid, 'prod');

    my $dbh      = $Data->{'db'};
    my $realmID  = $Data->{'Realm'} || 0;
    my $cl       = setClient($Data->{'clientValues'});
    my $unesc_cl = unescape($cl);
    my $assocID  = $Data->{'clientValues'}{'assocID'} || $Defs::INVALID_ID;
    #Since nationalrego, get the clubID from clientValues rather than from the form. 
    #For a node form, clubID i(on the form) will always be -1. If we're processing the form at club level, clubID should be set truly.
    my $clubID   = $Data->{'clientValues'}{'clubID'}  || $Defs::INVALID_ID;

    my $regoFormObj  = RegoFormObj->load(db=>$dbh, ID=>$formID);
    my $regoType     = $regoFormObj->getValue('intRegoType');
    my ($currLevel, $currID) = getEntityValues($Data->{'clientValues'});

    $regoType ||= 0;
    $clubID   ||= 0;
    $clubID = 0 if $clubID < 0;

    my %currentProducts          = ();
    my %currentProductsMandatory = ();
    my %currentProductsSequence  = ();

    my $mprods = ($formType != $Defs::REGOFORM_TYPE_TEAM_ASSOC) ? 1 : 0; #mprods = member prods (as distinct from team prods)

    my $where = ' WHERE  intRegoFormID = ?';
    $where .= ' AND intAssocID IN (0, ?, ?)' if $mprods;
    
    #assocID selection only meaningful for mprods
    my $st = qq[SELECT intProductID, intIsMandatory, intSequence, intAssocID FROM  tblRegoFormProducts $where];

    my $query = $dbh->prepare($st);

    if ($mprods) {
        #the clubID bit doesn't seem correct here. Think for club form, assocID is set to clubID?
        $query->execute($formID, $assocID, $Data->{'clientValues'}{'clubID'}); 
    }
    else {
        $query->execute($formID);
    }

    while (my ($id, $mandatory, $sequence, $productAssocID) = $query->fetchrow_array()) {
        $productAssocID = 1 if !$mprods;
        $productAssocID ||= -1;
        $mandatory ||= 0;
        $sequence  ||= 0;
        $currentProducts{$id} = $productAssocID;
        $currentProductsMandatory{$id} = $mandatory;
        $currentProductsSequence{$id}  = $sequence;
    }

    my $level = ($mprods) ? $Defs::LEVEL_MEMBER : $Defs::LEVEL_TEAM;

    $st = get_products_sql();
    $query = $Data->{'db'}->prepare($st);

    $query->execute(
        $Defs::LEVEL_CLUB,
        $Defs::LEVEL_ASSOC,
        $assocID,
        $Defs::LEVEL_ASSOC,
        $realmID,
        $Defs::LEVEL_CLUB,
        $realmID,
        $assocID,
        $Data->{'RealmSubType'},
        $Data->{'clientValues'}{'authLevel'}
    );

    my @products = ();
    my $currentAddedProducts = '';
    my $splits_count  = 0;

    if ($regoFormObj->isNodeForm() and !$regoFormObj->isOwnForm(entityID=>$currID)) {
        my $fields  = 'intProductID, intIsMandatory, intSequence';
        $currentAddedProducts = getCurrentAddedProducts($dbh, $formID, $assocID, $clubID, $fields);
    }

    while (my $dref = $query->fetchrow_hashref()) {
        #When at club level, the sql in the get_products_sql actually returns all club level products for the assoc before
        #filtering out those not belonging to the club via the next if below. Probably should correct the sql but loathe to change 
        #something that's working even though it's not necessarily done the correct way.
        next if ($clubID and $dref->{'intCreatedLevel'} == $Defs::LEVEL_CLUB and $dref->{'intCreatedID'} != $clubID);

        my $productID     = $dref->{'intProductID'};
        my $checked       = $currentProducts{$productID} ? ' CHECKED ' : '';
        my $mandatory     = $currentProductsMandatory{$productID} ? ' CHECKED ' : '';
        my $sequence      = $currentProductsSequence{$productID};
        my $tempProductID = $currentProducts{$productID};

        my $active      = '';
        my $disable     = '';

        if ($currentAddedProducts) {
            if (!$checked) {
                $checked   = $currentAddedProducts->{$productID} ? ' CHECKED ' : '';
            }
            $mandatory = 'Yes' if $mandatory;
            if (!$mandatory) {
                $mandatory = $currentAddedProducts->{$productID}{'intIsMandatory'} ? ' CHECKED ' : '';
            }
            $sequence      = $currentAddedProducts->{$productID}{'intSequence'}  if !$sequence;
            $tempProductID = $currentAddedProducts->{$productID}{'intProductID'} if !$tempProductID;
        }

        if ($regoType == 1 and !$clubID and Products::checkProductClubSplit($Data, $productID)) {
            $active = '*Club Split';
            $disable = ' disabled';
            $splits_count++;
        }
   
        #$active = 'Compulsory' if !$active and $defaultProductID == $productID;

         if (!$active and $mprods and $tempProductID == -1) {
             $active = ($regoFormObj->isNodeForm() and $regoFormObj->isOwnForm(entityID=>$currID)) ? '' : 'Yes';
         }

        next if !$active and $regoFormObj->isNodeForm() and $regoFormObj->isParentBodyForm(level=>$currLevel) and $dref->{'intCreatedLevel'} == $regoFormObj->getValue('intCreatedLevel');

        my $prod_price = currency($dref->{'curAmount'} || $dref->{'curDefaultAmount'} || 0);

        push @products, {
            active      => $active,
            checked     => $checked,
            productID   => $productID,
            sequence    => $sequence,
            mandatory   => $mandatory,
            disable     => $disable,
            strGroup    => $dref->{'strGroup'},
            strName     => $dref->{'strName'},
            prodPrice   => $prod_price,
            createdName => $dref->{'CreatedName'},
        };
    }

    my $continueBtn = (@products) ? ($stepper_mode eq 'add') ? 'Continue' : 'Save' : '';

    my $actn = ($mprods) ? 'A_ORF_pu' : 'A_ORF_tpu';
    my $formName = GetFormName($Data).' (#'.$formID.')';
    my $breadcrumbs = getBreadcrumbs($cl, $stepper_mode, 'Edit', 'Products');
    my $productsTabOnly = (getProductsTabOnly($Data)) ? 1 : 0;
    my $clubSplits = ($regoType == 1 and @products and $splits_count) ? 1 : 0;

    my %templateData = (
        stepper_html     => $stepper_html,
        stepper_inpt     => $stepper_inpt,
        stepper_mode     => $stepper_mode,
        target           => $Data->{'target'},
        continueBtn      => $continueBtn,
        productsTabOnly  => $productsTabOnly,
        products         => \@products,
        clubSplits       => $clubSplits,
        action           => $actn,
        client           => $unesc_cl,
        formID           => $formID,
    );

    my $templateFile = 'regoform/backend/products.templ';
    my $body = runTemplate($Data, \%templateData, $templateFile);

    return ($body, $formName, $breadcrumbs);
}

sub getCurrentAddedProducts {
    my ($dbh, $formID, $assocID, $clubID, $fields) = @_;

    my $sql = getRegoFormProductAddedListSQL(dbh=>$dbh, formID=>$formID, assocID=>$assocID, clubID=>$clubID, fields=>$fields);

    my @bindVars = ($formID, $assocID, $clubID);
    my $q = getQueryPreparedAndBound($dbh, $sql, \@bindVars);
   
    $q->execute();

    my $currentAddedProducts = $q->fetchall_hashref('intProductID');

    $q->finish();
    
    return $currentAddedProducts;
}

sub get_products_sql {
    # Providing a list of products - no pricing (can ignore family pricing)
    my $st = qq[
        SELECT 
            P.intProductID, 
            P.strName, 
            P.intAssocID, 
            P.curDefaultAmount, 
            P.intMinChangeLevel, 
            P.intCreatedLevel, 
            PP.curAmount, 
            P.strGroup, 
            IF((P.intCreatedLevel = ?), CONCAT(C.strName, ' (CLUB)'),
                IF((P.intCreatedLevel = ?), 'Association',
                IF(P.intAssocID=0, 'National',''))
            ) as CreatedName, 
            P.intCreatedID
        FROM tblProducts as P           
        LEFT JOIN tblProductPricing as PP ON (
            PP.intProductID = P.intProductID 
            AND intID = ?
            AND intLevel = ?
            AND PP.intRealmID = ?
        )
        LEFT JOIN tblClub as C ON (
            C.intClubID = P.intCreatedID 
            AND P.intCreatedLevel = ?
        )
        WHERE P.intRealmID = ?
            AND (P.intAssocID = ? OR P.intAssocID=0)
            AND P.intInactive=0
            AND P.intProductType NOT IN (2)
            AND P.intProductSubRealmID IN (0, ?)
            AND (intMinSellLevel <= ? OR intMinSellLevel=0)
        ORDER BY P.strGroup, P.strName
    ];
    return $st;
}

sub update_regoform_teamcomps   {
    my ($action, $Data, $assocID, $level, $client) = @_;

    my $cgi = new CGI;
    my $formID = $cgi->param('fID') || 0;

    my $stepper_mode = $cgi->param('stepper');

    $assocID = $Data->{'clientValues'}{'assocID'};

    my $realmID=$Data->{'Realm'} || 0;
    my $st_del=qq[
        DELETE FROM tblRegoFormComps
        WHERE intAssocID = ?
        AND intRealmID = ?
        AND intRegoFormID = ?
    ];
    $Data->{'db'}->do($st_del, undef, $assocID, $realmID, $formID);
    my $txt_prob=$Data->{'lang'}->txt('Problem updating Fields');
    return qq[<div class="warningmsg">$txt_prob (1)</div>] if $DBI::err;

    my $st = q[
        INSERT INTO tblRegoFormComps(intRegoFormID, intAssocID, intRealmID, intCompID)
        VALUES (?, ?, ?, ?)
    ];

    my $q=$Data->{'db'}->prepare($st);
    my %params=Vars();
    for my $k (keys %params) {
        if($k=~/rfcomp_/)   {
            my $id=$k;
            $id=~s/rfcomp_//g;
            $q->execute($formID, $assocID, $realmID, $id);
        }
        return qq[<div class="warningmsg">$txt_prob (2)</div>] if $DBI::err;
    }

    my $subBody = qq[<div class="OKmsg">Team Competitions Updated</div>];

    return ($subBody, '', $stepper_mode);
}

sub update_regoform_products    {
    my ($action, $Data, $assocID, $level, $client) = @_;

    my $dbh = $Data->{'db'};
    my $cgi = new CGI;
    my $formID = $cgi->param('fID');

    my $stepper_mode = $cgi->param('stepper');

    $assocID = $Data->{'clientValues'}{assocID} || $assocID;

    my $successSQL = qq[<div class="OKmsg">Products saved</div>];

    my $regoFormObj = RegoFormObj->load(db=>$dbh, ID=>$formID);
    my $entityID    = getEntityID($Data->{'clientValues'});

    if ($regoFormObj->isNodeForm() and !$regoFormObj->isOwnForm(entityID=>$entityID)) {
         nodeFormAddedProducts($Data, $formID, $cgi, $regoFormObj);
         return ($successSQL, '', $stepper_mode, $formID);
    }

    my $assocID2 = $assocID;
    $assocID2 = 0 if $assocID2 == -1;

    my $st_del = qq[DELETE FROM tblRegoFormProducts WHERE intRegoFormID = ? AND intAssocID = ?];

    $Data->{'db'}->do($st_del, undef, $formID, $assocID2);
    my $txt_prob=$Data->{'lang'}->txt('Problem updating Fields');
    return qq[<div class="warningmsg">$txt_prob (1) $formID</div>] if $DBI::err;

    my $st = qq[
        INSERT INTO tblRegoFormProducts(
            intRegoFormID, intProductID, intAssocID, intRealmID, intIsMandatory, intSequence
        )
        VALUES (?, ?, ?, ?, ?, ?)
    ];

    my $q=$Data->{'db'}->prepare($st);
    my %params=Vars();
    for my $k (keys %params)    {
        if($k=~/rfprod_/)   {
            my $id=$k;
            $id=~s/rfprod_//g;
            my $isMandatory = $params{'rfprodmandatory_'.$id} || 0;
            my $prod_seq = $params{'rfprodseq_'.$id} || 0;
            $q->execute($formID, $id, $assocID2, $Data->{'Realm'}, $isMandatory, $prod_seq);
        }
        return qq[<div class="warningmsg">$txt_prob (2)</div>] if $DBI::err;
    }
    auditLog($formID, $Data, 'Update Products','Registration Form');

    return ($successSQL, '', $stepper_mode, $formID);
}

sub nodeFormAddedProducts {
    my ($Data, $formID, $cgi, $regoFormObj) = @_;

    my $dbh     = $Data->{'db'};
    my $assocID = $Data->{'clientValues'}{'assocID'} || 0;
    my $clubID  = $Data->{'clientValues'}{'clubID'}  || 0;

    $clubID = 0 if $clubID < 0;

    #delete the current added products prior to re-adding the new ones.
    RegoFormProductAddedObj->bulkDelete(dbh=>$dbh, formID=>$formID, assocID=>$assocID, clubID=>$clubID);

    my %params = $cgi->Vars();

    foreach my $key (keys %params) {
        next if $key !~ /rfprod(active|)_/; #rfprodactive is specifically for picking up here.

        my $productID   = $key;
        $productID      =~ s/rfprod(active|)_//g;
        my $isMandatory = $params{'rfprodmandatory_'.$productID} || 0;
        my $sequence    = $params{'rfprodseq_'.$productID}       || 0;

        my $regoFormProductAddedObj = RegoFormProductAddedObj->new(db=>$dbh);
        my $dbfields = 'dbfields';

        $regoFormProductAddedObj->{$dbfields} = ();
        $regoFormProductAddedObj->{$dbfields}{'intRegoFormID'}  = $formID;
        $regoFormProductAddedObj->{$dbfields}{'intAssocID'}     = $assocID;
        $regoFormProductAddedObj->{$dbfields}{'intClubID'}      = $clubID;
        $regoFormProductAddedObj->{$dbfields}{'intProductID'}   = $productID;
        $regoFormProductAddedObj->{$dbfields}{'intIsMandatory'} = $isMandatory;
        $regoFormProductAddedObj->{$dbfields}{'intSequence'}    = $sequence;

        my $regoFormProductAddedID = $regoFormProductAddedObj->save();

        auditLog($regoFormProductAddedID, $Data, 'Insert added product', 'Node Registration Form');
    }

    return 1;
}

sub update_regoform_status {

    my ($action, $Data) = @_;

    my $realmID      = $Data->{'Realm'}                 || 0;
    my $RealmSubType = $Data->{'RealmSubType'}          || 0;
    my $assocID      = $Data->{'clientValues'}{assocID} || $Defs::INVALID_ID;

    my $cgi = new CGI;
    my $formID = $cgi->param('fID') || 0;

    my $intStatus;
    my $action_text;

    for ($action) {
        if (/^A_ORF_rsd$/) {
            $action_text = 'Delete';
            $intStatus   = -1;
        }
        elsif (/^A_ORF_rse$/) {
            $action_text = 'Enable';
            $intStatus   = 1;
        }
        elsif (/^A_ORF_rsh$/) {
            $action_text = 'Hide';
            $intStatus   = 0;
        }
        else {
            return;
        }
    }

    my $st = qq[UPDATE tblRegoForm SET intStatus = ? WHERE intRegoFormID = ?];

    my $q = $Data->{'db'}->prepare($st);
    $q->execute($intStatus, $formID);
    auditLog($formID, $Data, $action_text,'Registration Form');
    return;
}

sub regoform_notifications {
    my ($Data, $stepper_fid) = @_;

    my ($form_id, $form_type, $stepper_html, $stepper_mode, $stepper_edit, $stepper_inpt) = get_stepper_stuff($Data, $stepper_fid, 'noti');

    my $client    = setClient($Data->{'clientValues'});
    my $ue_client = unescape($client);

    my $dbh = $Data->{'db'};
    my $RegoFormObj = RegoFormObj->load(db=>$dbh, ID=>$form_id);

    my $assoc_id = $RegoFormObj->getValue('intAssocID');
    my $club_id  = $RegoFormObj->getValue('intClubID');
    my $nationalForm =  $RegoFormObj->isNodeForm();
    my $new_char = $RegoFormObj->getValue('intNewBits')     || '';
    my $ren_char = $RegoFormObj->getValue('intRenewalBits') || '';
    my $pay_char = $RegoFormObj->getValue('intPaymentBits') || '';

    my ($new_assoc, $new_club, $new_team, $new_member, $new_parents) = get_notif_bits($new_char);
    my ($ren_assoc, $ren_club, $ren_team, $ren_member, $ren_parents) = get_notif_bits($ren_char);
    my ($pay_assoc, $pay_club, $pay_team, $pay_member, $pay_parents) = get_notif_bits($pay_char);

    my $new_notifs = [$new_assoc, $new_club, $new_team, $new_member, $new_parents];
    my $ren_notifs = [$ren_assoc, $ren_club, $ren_team, $ren_member, $ren_parents];
    my $pay_notifs = [$pay_assoc, $pay_club, $pay_team, $pay_member, $pay_parents];

    my $ar_contacts = ContactsObj->getList(dbh=>$dbh, associd=>$assoc_id, getregistrations=>1);
    my $assoc_rego_contacts = get_emails_list($ar_contacts);
    my $arCount = scalar(@$assoc_rego_contacts);

    my $af_contacts = ContactsObj->getList(dbh=>$dbh, associd=>$assoc_id, getpayments=>1);
    my $assoc_finc_contacts = get_emails_list($af_contacts);
    my $afCount = scalar(@$assoc_finc_contacts);
    my $ap_contact = ContactsObj->getList(dbh=>$dbh, associd=>$assoc_id, getprimary=>1);
    my $assoc_primary_contact = get_emails_list($ap_contact, 1);
    chop($assoc_primary_contact);

    my $club_rego_contacts;
    my $club_finc_contacts;
    my $club_primary_contact;

    if ($club_id > 0) {
        my $cr_contacts = ContactsObj->getList(dbh=>$dbh, associd=>$assoc_id, clubid=>$club_id, getregistrations=>1);
        $club_rego_contacts = get_emails_list($cr_contacts);

        my $cf_contacts = ContactsObj->getList(dbh=>$dbh, associd=>$assoc_id, clubid=>$club_id, getpayments=>1);
        $club_finc_contacts = get_emails_list($cf_contacts);

        my $cp_contact = ContactsObj->getList(dbh=>$dbh, associd=>$assoc_id, clubid=>$club_id, getprimary=>1);
        $club_primary_contact = get_emails_list($cp_contact, 1);
        chop($club_primary_contact);
    }

    my $crCount = (defined $club_rego_contacts ) ? scalar(@$club_rego_contacts) : 0;
    my $cfCount = (defined $club_finc_contacts) ? scalar(@$club_finc_contacts) : 0;

    my %template_data = (
        formID          => $form_id,
        national        => $nationalForm,
        formType        => $form_type,
        clubID          => $club_id,
        newEmails       => $new_notifs,
        rnwEmails       => $ren_notifs,
        payEmails       => $pay_notifs,
        copyParents     => 1,
        registrations   => 'Registrations',
        arCount         => $arCount,
        arContacts      => $assoc_rego_contacts,
        aPrimaryContact => $assoc_primary_contact,
        crCount         => $crCount,
        crContacts      => $club_rego_contacts,
        finance         => 'Finance & Payments',
        afCount         => $afCount,
        afContacts      => $assoc_finc_contacts,
        cfCount         => $cfCount,
        cfContacts      => $club_finc_contacts,
        cPrimaryContact => $club_primary_contact,
        target          => $Data->{'target'},
        client          => $ue_client,
        action          => 'A_ORF_notiu',
        stepperHTML     => $stepper_html,
        stepperMode     => $stepper_mode,
    );

    my $body        = runTemplate($Data, \%template_data, 'regoform/backend/notifications.templ');
    my $form_name   = GetFormName($Data).' (#'.$form_id.')';
    my $breadcrumbs = getBreadcrumbs($client, $stepper_mode, 'Edit', 'Notifications');

    return ($body, $form_name, $breadcrumbs);
}

sub update_regoform_notifications {
    my ($action, $Data) = @_;

    my $cgi = new CGI;
    my $form_id = $cgi->param('fID');

    my $stepper_mode = $cgi->param('stepper');

    my $new_assoc   = $cgi->param('new_assoc')   || 0;
    my $new_club    = $cgi->param('new_club')    || 0;
    my $new_team    = $cgi->param('new_team')    || 0;
    my $new_member  = $cgi->param('new_member')  || 0;
    my $new_parents = $cgi->param('new_parents') || 0;
    my $new_char    = pack_notif_bits($new_assoc, $new_club, $new_team, $new_member, $new_parents);

    my $ren_assoc   = $cgi->param('ren_assoc')   || 0;
    my $ren_club    = $cgi->param('ren_club')    || 0;
    my $ren_team    = $cgi->param('ren_team')    || 0;
    my $ren_member  = $cgi->param('ren_member')  || 0;
    my $ren_parents = $cgi->param('ren_parents') || 0;
    my $ren_char    = pack_notif_bits($ren_assoc, $ren_club, $ren_team, $ren_member, $ren_parents);

    my $pay_assoc   = $cgi->param('pay_assoc')   || 0;
    my $pay_club    = $cgi->param('pay_club')    || 0;
    my $pay_team    = $cgi->param('pay_team')    || 0;
    my $pay_member  = $cgi->param('pay_member')  || 0;
    my $pay_parents = $cgi->param('pay_parents') || 0;
    my $pay_char    = pack_notif_bits($pay_assoc, $pay_club, $pay_team, $pay_member, $pay_parents);

    my $dbh = $Data->{'db'};
    my $RegoFormObj = RegoFormObj->load(db=>$dbh, ID=>$form_id);

    my $dbfields = 'dbfields';
    $RegoFormObj->{$dbfields} = ();
    $RegoFormObj->{$dbfields}{'intNewBits'}     = $new_char;
    $RegoFormObj->{$dbfields}{'intRenewalBits'} = $ren_char;
    $RegoFormObj->{$dbfields}{'intPaymentBits'} = $pay_char;
    $RegoFormObj->save();

    my $subBody = qq[<div class="OKmsg">Notifications saved</div>];

    return ($subBody, '', $stepper_mode, $form_id);
}

sub get_stepper_stuff {
    my ($Data, $stepper_fid, $func_code) = @_;

    my $cgi = new CGI;
    my $form_id = 0;

    my $stepper_html = '';
    my $stepper_mode = '';
    my $stepper_edit = 0;
    my $stepper_inpt = '';

    if ($stepper_fid) {
        $form_id = $stepper_fid;
        $stepper_mode = 'add';
    }
    else {
        $form_id = $cgi->param('fID') || 0;
        $stepper_mode = $cgi->param('stepper');
    }

    my $form_type = GetFormType($Data, 1, $form_id);

    if ($stepper_mode) {
        $stepper_edit = 1 if $stepper_mode eq 'edit';
        $stepper_html = regoform_navigation($Data, $func_code, $form_id, $form_type, $stepper_edit);
        $stepper_inpt = qq[<input type="hidden" name="stepper" value="$stepper_mode">]; 
    }

    return ($form_id, $form_type, $stepper_html, $stepper_mode, $stepper_edit, $stepper_inpt);
}

sub GetFormType {
    my ($Data, $return_rego_type, $formID) = @_;

    my $cgi = new CGI;

    $formID ||= $Data->{'RegoFormID'} || $cgi->param('fID') || $cgi->param('formID') || 0;

    $formID = untaint_number($formID);

    my $statement = q[SELECT intRegoType FROM tblRegoForm WHERE intRegoFormID = ?];

    my $query = $Data->{'db'}->prepare($statement);
    $query->execute($formID);

    my($regoType) = $query->fetchrow_array();

    return $regoType if ($return_rego_type == 1);

    if ($return_rego_type == 2) { #TODO: What is the 5th element meant to be?
        return (q{}, 'Member to Association', 'Team to Association', 'Member to Team', 'Member to Club', '', 'Member to Program')[$regoType];
    }

    return 'Team'    if ($regoType == $Defs::REGOFORM_TYPE_TEAM_ASSOC);
    return 'Member';
}

sub GetFormName {

    my ($Data, $formID) = @_;

    my $cgi = new CGI;
    $formID ||= $Data->{'RegoFormID'} || $cgi->param('fID') || $cgi->param('formID') || 0;

    my $statement = q[SELECT strRegoFormName FROM tblRegoForm WHERE intRegoFormID = ?];

    my $query = $Data->{'db'}->prepare($statement);
    $query->execute($formID);

    my($formName) = $query->fetchrow_array();

    return $formName || 'Registration Form';
}

sub getBreadcrumbs {
    my ($client, $stepper_mode, $aore, $step) = @_;

    my $bcae = '';

    if ($stepper_mode eq 'add') {
        $bcae = 'Add New Form'
    }
    elsif ($stepper_mode eq 'edit') {
        $bcae = 'Edit'
    }
    else {
        $bcae = $aore;
    }
    my $breadcrumbs = HTML_breadcrumbs(['Registration Forms', 'main.cgi', {client => $client, a => 'A_ORF_r'}], [$bcae], [$step]);

    return $breadcrumbs;
}

sub HTML_breadcrumbs {
    my @html_links;

    while ( my $link_params = shift ) {
        push @html_links, HTML_link( @{ $link_params } );
    }

    my $cgi = new CGI;

    return $cgi->div( { -class => 'config-bcrumbs', }, join('&nbsp;&raquo;&nbsp;', grep(/^.+$/, @html_links)),) ;
}

sub hidden_fields {
    my $returnHTML;
    my $cgi = new CGI;
    while (@_) {
        $returnHTML .= $cgi->hidden(-override => 1, -name => shift, -default => shift);
    }
    return $returnHTML;
}

sub getProductsTabOnly {
    my ($Data) = @_;

    my $productsTabOnly = 0;
    
    $productsTabOnly = $Data->{'SystemConfig'}{'regoform_ProductsTabOnly'} if exists $Data->{'SystemConfig'}{'regoform_ProductsTabOnly'};
    $productsTabOnly = $Data->{'SystemConfig'}{'AssocConfig'}{'regoform_ProductsTabOnly'} if exists $Data->{'SystemConfig'}{'AssocConfig'}{'regoform_ProductsTabOnly'};

    $productsTabOnly = 0 if (exists $Data->{'SystemConfig'}{'regoform_ProductsTabOnly'} and $Data->{'clientValues'}{'authLevel'} == $Data->{'SystemConfig'}{'regoform_ProductsTabOnly'});
    $productsTabOnly = 0 if (exists $Data->{'SystemConfig'}{'AssocConfig'}{'regoform_ProductsTabOnly'} and $Data->{'clientValues'}{'authLevel'} == $Data->{'SystemConfig'}{'AssocConfig'}{'regoform_ProductsTabOnly'});
    $productsTabOnly = 1 if ($productsTabOnly > 1);

    return $productsTabOnly;
}


sub nodeFormAddedConfig{
    my ($Data, $formID, $cgi, $regoFormObj, $entityID, $entityTypeID) =@_;
    my $dbh     = $Data->{'db'};

    RegoFormConfigAddedObj->delete(dbh=>$dbh, formID=>$formID, entityID=>$entityID, entityTypeID=>$entityTypeID);
    my $stepper_mode = $cgi->param('stepper');

    my $TermsCondHeader = param('tchdr')           || '';
    my $TermsCondText   = param('tctext')          || '';
    my $TC_AgreeBox     = param('tcagree')         || 0;
     my $st_insert = q[
        INSERT INTO tblRegoFormConfigAdded (
            intRegoFormID,
            intEntityTypeID,
            intEntityID,
            strTermsCondHeader,
            strTermsCondText,
            intTC_AgreeBox
        )
        VALUES (?, ?, ?, ?, ?, ? )
    ];

    my $qry= $Data->{'db'}->prepare($st_insert);
    $qry->execute(
        $formID, $entityTypeID ,$entityID, $TermsCondHeader,$TermsCondText,$TC_AgreeBox)
     or query_error($st_insert);

    my $subBody = ($DBI::err)
        ? qq[<div class="warningmsg">There was a problem changing the text</div>]
        : qq[<div class="OKmsg">Messages saved</div>];

    auditLog($formID, $Data, 'Update Text', 'Registration Form');

    return ($subBody, '', $stepper_mode);

}

1;
