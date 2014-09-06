#
# $Header: svn://svn/SWM/trunk/web/FieldConfig.pm 11450 2014-05-01 04:32:28Z sliu $
#

package FieldConfig;

require Exporter;
@ISA = qw(Exporter);
@EXPORT = qw(handleFieldConfig FieldConfigPermissionOptions get_permission_names);
@EXPORT_OK = qw(handleFieldConfig FieldConfigPermissionOptions get_permission_names);

use strict;
use Reg_common;
use CGI qw(unescape param popup_menu);
use ConfigOptions;
use FieldLabels;
use CustomFields;
use AuditLog;

sub handleFieldConfig {
    my (
        $action, 
        $Data, 
        $entityTypeID, 
        $entityID
    ) = @_;

    my $client = setClient($Data->{'clientValues'});
    my $resultHTML  = q{};
    my $title       = q{};
    my $ret         = q{};
    my $fieldtype = param('ft') || 'Member';
    if(!$entityTypeID or !$entityID)    {
        $entityTypeID = $Data->{'clientValues'}{'currentLevel'};
        $entityID = getID($Data->{'clientValues'}, $entityTypeID);
    }

    if ($action =~/^FC_C_s/) {
        ($ret,$title) = update_fieldconfig(
            $action, 
            $Data,
            $entityTypeID, 
            $entityID, 
            $client,
            $fieldtype,
        );
        $resultHTML.=$ret;
        $action = 'FC_C_d';
    }
    if ($action =~/^FC_C_d/) {
        ($ret,$title) = show_fieldconfig(
            $action, 
            $Data,
            $entityTypeID, 
            $entityID, 
            $client,
            $fieldtype,
        );
        $resultHTML.=$ret;
    }

    return (
        $resultHTML, 
        $title
    );
}

my %readonlyfields =( #These fields can only be Read only or hidden
    dtLastUpdate => 1,
    dtRegisteredUntil=> 1,
    strNationalNum => 1,
    #strMemberNo => 1,
    dtCreatedOnline => 1,
    Username => 1,
    ClubName => 1,
    TeamCode => 1,
);

my @hiddenfields    = (qw(
    strSchoolName
    strSchoolSuburb
    ));


sub show_fieldconfig {
    my (
        $action, 
        $Data,
        $entityTypeID, 
        $entityID, 
        $client,
    ) = @_;

    my $FieldLabels = undef;
    my $CustomFieldNames=getCustomFieldNames($Data) || '';
    my $realmID=$Data->{'Realm'} || 0;
    my $rawperms = GetPermissions(
        $Data,
        $entityTypeID, 
        $entityID, 
        $Data->{'Realm'} || 0,
        $Data->{'RealmSubType'} || 0,
        $Data->{'clientValues'}{'authLevel'} || 0,
        1,
    );

    my $currentLevel = $Data->{'clientValues'}{'currentLevel'} || 0,
    my $l=$Data->{'lang'};
    my $intro=$l->txt('FIELDS_intro');
    my %txts=();
    my %permissionNames = get_permission_names();
    $txts{'me'}=$l->txt('For my level');
    $txts{'child'}=$l->txt('For levels below');
    $txts{'rego'}=$l->txt('Registration Form');
    $txts{'hid'}=$l->txt($permissionNames{'Hidden'});
    $txts{'ro'}=$l->txt($permissionNames{'ReadOnly'});
    $txts{'ed'}=$l->txt($permissionNames{'Editable'});
    $txts{'ao'}=$l->txt($permissionNames{'AddOnlyCompulsory'});
    $txts{'com'}=$l->txt($permissionNames{'Compulsory'});
    $txts{'childdef'}=$l->txt($permissionNames{'ChildDefine'});

    my $unescclient=unescape($client);
    my $memberFields = getFieldsList($Data, 'Person');
    my $clubFields = getFieldsList($Data, 'Club');
    my $subBody = '';
    my @fieldtypelist = ();
    push @fieldtypelist, ['Member', $Data->{'LevelNames'}{$Defs::LEVEL_PERSON} || 'Member'];
    if($currentLevel > $Defs::LEVEL_CLUB and !$Data->{'SystemConfig'}{'NoClubs'})    {
        push @fieldtypelist, ['Club', $Data->{'LevelNames'}{$Defs::LEVEL_CLUB} || 'Club'];
    }

    for my $fieldtyperow (@fieldtypelist)    {
        my $fieldtype = $fieldtyperow->[0];

        $subBody .= qq[
        <div id ="fields_$fieldtype">
        <div style="float:right;font-size:9px;margin-bottom:5px;">
        <a href="" class ="expandall-link"><img src = "images/arrow_open.png"> EXPAND ALL</a> <a href="" class ="contractall-link"><img src = "images/arrow_opened.png"> CONTRACT ALL</a>
        </div>
        <table class="permsTable" style="width:100%;">
        ];
        my $field_list = undef;
        if($fieldtype eq 'Member')    {
            $field_list = $memberFields;
            $FieldLabels=getFieldLabels($Data, $Defs::LEVEL_PERSON);
        }
        elsif($fieldtype eq 'Club')    {
            $field_list = $clubFields;
            $FieldLabels=getFieldLabels($Data, $Defs::LEVEL_CLUB);
        }
        my $i;
        for my $f (@$field_list) {
            my $label=$FieldLabels->{$f};
            $label=$CustomFieldNames->{$f}[0]||'' if !$label;
            $label||='';
            $label=$l->txt($label);
            next if !$label;

            my ($my_options, $my_current) = optionrow(
                $rawperms,
                $fieldtype,
                '',
                $f,
                $entityTypeID,
            );
            my ($child_options, $child_current) = optionrow(
                $rawperms,
                $fieldtype
                ,'Child',
                $f,
                $entityTypeID,
            );
            my ($regform_options, $rego_current) = optionrow(
                $rawperms,
                $fieldtype
                ,'RegoForm',
                $f,
                $entityTypeID,
            );
            $regform_options = '' if ( $fieldtype eq 'Club' || $f =~ /^PlayerNumber/ );
            my $my_current_label = $l->txt($permissionNames{$my_current}) || '';
            my $child_current_label = $l->txt($permissionNames{$child_current}) || '';
            my $rego_current_label = $l->txt($permissionNames{$rego_current}) || '';

            my $fv = $fieldtype.'_'.$f;
            $fv =~ s/\./__/; # Convert full stops to double underscore for params
            $subBody.=qq[
            <tbody id = "fc_row_head_$fv" class="fc_row_head">
            <tr class = "fieldconfig-header">
            <td class=""> <a href="" class = "fc_label_open" id ="fc_label_open_$fv"> <img src = "images/arrow_opened.png">&nbsp; <b> $label</a></b></td>
            <td colspan = "2" style="font-size:9px;"><b>$txts{'me'}</b> $my_current_label</td>
            <td colspan = "2" style="font-size:9px;"><b>$txts{'child'}</b> $child_current_label</td>
            ];
            if($fieldtype eq 'Club')    {
                $subBody .= qq[
                <td colspan = "2" style="font-size:9px;">&nbsp;</td>
                ];
            }
            else    {
                $subBody .= qq[
                <td colspan = "2" style="font-size:9px;"><b>$txts{'rego'}</b> $rego_current_label</td>
                ];
            }
            $subBody .= qq[
            </tr>
            <tr><td style="padding:2px;"></td> </tr>
            </tbody>
            <tbody id = "fc_row_config_$fv" class="fc_row_config">
            <tr class = "fieldconfig-header">
            <td class=""> <a href="" class = "fc_label_close" id ="fc_label_close_$fv"> <img src = "images/arrow_open.png">&nbsp; <b> $label</a></b></td>
            <td style="font-size:9px;width:100px;text-align:center;"><a href = "" class = "fc_perm_label" id = "fcpermlabel_$fv].qq[_ChildDefine">$txts{'childdef'}</a></td>
            <td style="font-size:9px;width:100px;text-align:center;"><a href = "" class = "fc_perm_label" id = "fcpermlabel_$fv].qq[_Hidden">$txts{'hid'}</a></td>
            <td style="font-size:9px;width:100px;text-align:center;"><a href = "" class = "fc_perm_label" id = "fcpermlabel_$fv].qq[_ReadOnly">$txts{'ro'}</a></td>
            <td style="font-size:9px;width:100px;text-align:center;"><a href = "" class = "fc_perm_label" id = "fcpermlabel_$fv].qq[_Editable">$txts{'ed'}</a></td>
            <td style="font-size:9px;width:100px;text-align:center;"><a href = "" class = "fc_perm_label" id = "fcpermlabel_$fv].qq[_Compulsory">$txts{'com'}</a></td>
            <td style="font-size:9px;width:100px;text-align:center;"><a href = "" class = "fc_perm_label" id = "fcpermlabel_$fv].qq[_AddOnlyCompulsory">$txts{'ao'}</a></td>
            </tr>
            <tr>
            <td>&nbsp;<span style="font-size:10px;">$txts{'me'}</span></td>
            $my_options
            </tr>
            <tr>
            <td>&nbsp;<span style="font-size:10px;">$txts{'child'}</span></td>
            $child_options
            </tr>
            ];
            if($fieldtype ne 'Club')    {
                $subBody .= qq[
                <tr>
                <td>&nbsp;<span style="font-size:10px;">$txts{'rego'}</span></td>
                $regform_options
                </tr>
                ];
            }
            $subBody.=qq[
            </tbody>
            ];
        }
        $subBody.=qq[
        </table>
        </div>
        ];
    }
    my $tabs = '';
    if(scalar(@fieldtypelist) > 1)    {
        my $tabheaders = '';
        for my $fieldtype (@fieldtypelist)    {
            $tabheaders .= qq{<li><a href="#fields_$fieldtype->[0]">}.$l->txt($fieldtype->[1].' Fields').qq{</a></li>};
        }
        $tabs = q~
        <script type="text/javascript">
        jQuery(function() {
                jQuery('#fieldconfigtabs').tabs();
            });
        ~.qq[
        </script>
        <div id="fieldconfigtabs" style="float:left;clear:right;width:99%;">
        <ul>
        $tabheaders
        </ul>
        $subBody
        </div>
        ];
    }
    else    {
        $tabs = $subBody;
    }
    $tabs .=qq~
    <script type="text/javascript">
    jQuery(function() {
            jQuery('.fc_row_config').hide();
            jQuery('.contractall-link').click(function (e) {
                    e.preventDefault();
                    var pID = jQuery(this).parent().parent().attr("id");
                    jQuery('#' + pID + ' .fc_row_head').show();
                    jQuery('#' + pID + ' .fc_row_config').hide();
                });    
            jQuery('.expandall-link').click(function (e) {
                    e.preventDefault();
                    var pID = jQuery(this).parent().parent().attr("id");
                    jQuery('#' + pID + ' .fc_row_head').hide();
                    jQuery('#' + pID + ' .fc_row_config').show();
                });    
            jQuery('.fc_label_open, .fc_label_close').click(function (e) {
                    e.preventDefault();
                    var id_str = jQuery(this).attr("id");
                    var show = id_str.match(/_open_/);
                    id_str = id_str.replace(/fc_label_open_/i,'');
                    id_str = id_str.replace(/fc_label_close_/i,'');
                    if(show)    {
                        jQuery('#fc_row_config_' + id_str).show();
                        jQuery('#fc_row_head_' + id_str).hide();
                    }
                    else    {
                        jQuery('#fc_row_config_' + id_str).hide();
                        jQuery('#fc_row_head_' + id_str).show();
                    }
                });    

            jQuery('.fc_perm_label').click(function (e) {
                    e.preventDefault();
                    var id_str = jQuery(this).attr("id");
                    var options = id_str.split('_');
                    var fieldname = 'fc_' + options[1] + '_' + options[2];
                    jQuery('input:radio[name=' + fieldname + '][value="' + options[3] + '"]').attr('checked',true);
                    fieldname = 'fc_' + options[1] + 'Child' + '_' + options[2];
                    jQuery('input:radio[name=' + fieldname + '][value="' + options[3] + '"]').attr('checked',true);
                    fieldname = 'fc_' + options[1] + 'RegoForm' + '_' + options[2];
                    jQuery('input:radio[name=' + fieldname + '][value="' + options[3] + '"]').attr('checked',true);
                });    
        });
    </script>
    ~;
    my $body=qq[
    <p>$intro</p>
    <form action="$Data->{'target'}" method="POST">
    <input type="submit" value="].$l->txt('Save Options').qq[" class = "savebtn button proceed-button"><br><br>
    <div style = "clear:right;"></div>
    $tabs
    <div style = "clear:right;"></div><br><br>
    <input type="submit" value="].$l->txt('Save Options').qq[" class = "savebtn button proceed-button"><br><br>
    <input type="hidden" name="a" value="FC_C_s">
    <input type="hidden" name="client" value="$unescclient">
    </form>
    ];

    return ($body,$l->txt('Field Configuration'));

}

sub update_fieldconfig {
    my (
        $action, 
        $Data,
        $entityTypeID, 
        $entityID, 
        $client,
    )=@_;

    my $realmID=$Data->{'Realm'} || 0;
    my $st_del=qq[
    DELETE FROM tblFieldPermissions
    WHERE 
    intRealmID = ?
        AND intEntityTypeID = ?
        AND intEntityID = ?
        AND strFieldType = ?
        AND intRoleID =0
    ];
    my $q_del = $Data->{'db'}->prepare($st_del);

    my $txt_prob=$Data->{'lang'}->txt('Problem updating Fields');
    return qq[<div class="warningmsg">$txt_prob (1)</div>] if $DBI::err;
    my $st=qq[
    INSERT INTO tblFieldPermissions (
        intRealmID,
        intEntityTypeID,
        intEntityID,
        strFieldType,
        strFieldName,
        strPermission
    )
    VALUES (
        $realmID,
        ?,
        ?,
        ?,
        ?,
        ?
    )
    ];
    my $currentLevel = $Data->{'clientValues'}{'currentLevel'} || 0,
    my @fieldtypelist = ();
    push @fieldtypelist, ['Member', $Data->{'LevelNames'}{$Defs::LEVEL_PERSON} || 'Member'];
    if($currentLevel > $Defs::LEVEL_CLUB and !$Data->{'SystemConfig'}{'NoClubs'})    {
        push @fieldtypelist, ['Club', $Data->{'LevelNames'}{$Defs::LEVEL_CLUB} || 'Club'];
    }

    my $q=$Data->{'db'}->prepare($st);
    for my $fieldtyperow (@fieldtypelist)    {
        my $fieldtype = $fieldtyperow->[0];

        my @field_list = ();
        my $memberFields = getFieldsList($Data, 'Person');
        my $clubFields = getFieldsList($Data, 'Club');
        if($fieldtype eq 'Member')    {
            @field_list = @{$memberFields};
        }
        elsif($fieldtype eq 'Club')    {
            @field_list = @{$clubFields};
        }
        $q_del->execute(
            $realmID,
            $entityTypeID, 
            $entityID, 
            $fieldtype,
        );
        $q_del->execute(
            $realmID,
            $entityTypeID, 
            $entityID, 
            $fieldtype.'Child',
        );
        $q_del->execute(
            $realmID,
            $entityTypeID, 
            $entityID, 
            $fieldtype.'RegoForm',
        );

        for my $k (@field_list)    {
            my @types = (
                $fieldtype,
                $fieldtype.'Child',
                $fieldtype.'RegoForm',
            );

            for my $fn (@types)    {
                my $escaped_k = $k;
                $escaped_k =~ s/\./__/; # Convert full stops to double underscore for params
                if(param("fc_$fn"."_$escaped_k"))    {
                    $q->execute(
                        $entityTypeID,
                        $entityID,
                        $fn,
                        $k,
                        param("fc_$fn"."_$escaped_k"),
                    );
                }
            }
            return qq[<div class="warningmsg">$txt_prob (2)</div>] if $DBI::err;
        }
    }
    auditLog($entityID, $Data, 'Update', 'Field Options');
    return '<div class="OKmsg">'.$Data->{'lang'}->txt('Fields Updated').'</div>';
}


sub optionrow    {
    my (
        $rawperms,
        $fieldgroup,
        $fieldtype,
        $fieldname, 
        $entityTypeID,
    ) = @_;


    my @options = ();

    my $fieldprefix = '';

    # Convert full stops to double underscore so it plays nice with javascript
    my $escaped_field_name = $fieldname;
    $escaped_field_name =~ s/\./__/;

    my $f_name = "fc_$fieldgroup$fieldtype"."_$escaped_field_name";
    my @permissions = (qw(
        ChildDefine
        Hidden
        ReadOnly
        Editable
        Compulsory
        AddOnlyCompulsory
        ));
    my @levels_to_check = (
        'REALM',
        $Defs::LEVEL_NATIONAL,
        $Defs::LEVEL_STATE,
        $Defs::LEVEL_REGION,
        $Defs::LEVEL_ZONE,
        $Defs::LEVEL_CLUB,
    );

    my $currentvalue = '';

    my $setfromabove = 0;
    my $above = 1;
    my %optionsavail = ();
    for my $level (@levels_to_check)    {
        if(
            $above
            or $level eq $entityTypeID
        )    {
            my $type = $fieldtype;
            if(    
                $fieldtype eq '' 
                and $level ne $entityTypeID    
            )    {
                $type = 'Child';
            }

            my $v = $rawperms->{"$fieldgroup$type"}{$level}{$fieldname} || '';
            if($v and $v ne 'ChildDefine')    {
                #when permission is set in Filed Configration, the setting won't effect the current level when they access the regoform fields.  
                $currentvalue = $v;
                # changeing "nq" to ">=" in the next line will cause the permission setting to effect the current level as well, Example: Assoc sets a field hidden in field configuration, still can select other option "editable,.." when assoc accesses the field in rego form backened. 
                $setfromabove = $v if $level ne $entityTypeID;
            }
            if($level eq $entityTypeID)    {
                $above = 0;
            }
        }
    }
    $currentvalue ||= 'ChildDefine';
    if(!AllowPermissionUpgrade($setfromabove, $currentvalue))    {
        $currentvalue = $setfromabove;
    }
    for my $p (@permissions)    {
        my $selected = $p eq $currentvalue ? ' CHECKED ' : '';
        if($setfromabove
                and $currentvalue ne $p
                and !AllowPermissionUpgrade($setfromabove, $p)
        )    {
            $optionsavail{$p} = 0;
            push @options, '&nbsp;';
        }
        else    {
            if(
                $readonlyfields{$fieldname}
                    and $p ne 'Hidden'
                    and $p ne 'ChildDefine'
                    and $p ne 'ReadOnly'
            )    {
                push @options, '&nbsp;';
                $optionsavail{$p} = 0;
            }
            else    {
                push @options, qq[<input type="radio" value="$p" name="$f_name" class="nb" $selected >];
                $optionsavail{$p} = 1;
            }
        }
    }

    my $output = '';
    for my $o (@options)    {
        $output .= qq[<td style = "text-align:center;">$o</td>];
    }
    return ($output, $currentvalue, \%optionsavail);
}

sub FieldConfigPermissionOptions    {
    my (
        $Data,
        $fieldgroup, #Member|Club|Team,
        $fieldtype,  # ''|Child|RegoForm
        $entityTypeID,
        $entityID,
    ) = @_;

    my $realmID=$Data->{'Realm'} || 0;
    my $rawperms = GetPermissions(
        $Data,
        $entityTypeID, 
        $entityID, 
        $Data->{'Realm'} || 0,
        $Data->{'RealmSubType'} || 0,
        $Data->{'clientValues'}{'authLevel'} || 0,
        1,
    );
    my $memberFields = getFieldsList($Data, 'Person');
    my $clubFields = getFieldsList($Data, 'Club');
    my $field_list = undef;
    if($fieldgroup eq 'Member')    {
        # previous code don't have this field in list, it might should
        # but for now I just remove it from list to keep it same
        $memberFields = [grep {!/intGradeID/} @$memberFields] if $Data->{'SystemConfig'}{'Schools'};
        $field_list = $memberFields;
    }
    elsif($fieldgroup eq 'Club')    {
        $field_list = $clubFields;
    }
    my %fielddata = ();
    for my $f (@$field_list) {
        my (undef , $current, $availoptions) = optionrow(
            $rawperms,
            $fieldgroup,
            $fieldtype,
            $f,
            $entityTypeID,
        );
        $fielddata{$f} = {
            current => $current,
            permissions => $availoptions,
        };
    }
    return \%fielddata;
}

sub get_permission_names {
    my %permissionNames = (
        ChildDefine => 'Let levels below choose',
        Hidden => 'Hidden',
        ReadOnly => 'Read Only',
        Editable => 'Editable',
        Compulsory => 'Compulsory',
        AddOnlyCompulsory => 'Add Only (Compulsory)',
    );
    return %permissionNames;
}

1;
# vim: set et sw=4 ts=4:

