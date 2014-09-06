package ListPersons;

require Exporter;
@ISA =    qw(Exporter);
@EXPORT = qw(listPersons);
@EXPORT_OK = qw(listPersons);

use strict;
use CGI qw(param unescape escape);

use lib '.', "..";
use InstanceOf;
use Defs;
use Reg_common;
use FieldLabels;
use Utils;
use DBUtils;
use CustomFields;
use RecordTypeFilter;
use GridDisplay;
use AgeGroups;
use FormHelpers;
use AuditLog;
use Log;
use TTTemplate;

sub listPersons {
    my ($Data, $entityID, $action) = @_; 

    my $db            = $Data->{'db'};
    my $resultHTML    = '';
    my $client        = unescape($Data->{client});
    my $from_str      = '';
    my $sel_str       = '';
    my $type          = $Data->{'clientValues'}{'currentLevel'};
    my $levelName     = $Data->{'LevelNames'}{$type} || '';
    my $action_IN     = $action || '';
    my $target        = $Data->{'target'} || '';;
    my $realm_id      = $Data->{'Realm'};

    my ($AgeGroups, undef) = AgeGroups::getAgeGroups($Data);


    my $lang = $Data->{'lang'};
    my %textLabels = (
        'addPerson' => $lang->txt("Add"),
        'transferPerson' => $lang->txt('Transfer Person'),
        'modifyPersonList' => $lang->txt('Modify Person List'),
        'personsInLevel' => $lang->txt("$Data->{'LevelNames'}{$Defs::LEVEL_PERSON.'_P'} in $Data->{'LevelNames'}{$type}"),
        'invalidPageRequested' => $lang->txt('Invalid page requested.'),
    );

    my $groupBy = '';
    my $showRecordType=1;
    my $mtypefilter= $Data->{'CookiePersonTypeFilter'} ? qq[ AND $Data->{'CookiePersonTypeFilter'} = 1 ] : '';
    return textMessage($textLabels{'invalidPageRequested'}) if !$type;

    my $from_str_ORIG = $from_str || '';
    my $totalPersons=0;

    my $showfields = setupPersonListFields($Data);

    # do not display strStatus/intMCStatus if is_pending_registration
    my $memfieldlabels=FieldLabels::getFieldLabels($Data,$Defs::LEVEL_PERSON);
    my $CustomFieldNames=CustomFields::getCustomFieldNames($Data, $Data->{'SubRealm'} || 0) || '';
    if($Data->{'SystemConfig'}{'PersonListFields'})    {
        my @sf =split /,/, $Data->{'SystemConfig'}{'PersonListFields'} ;
        $showfields = \@sf;
    }

    my $select = '';
    my @headers = (
        {
            type => 'Selector',
            field => 'SelectLink',
        },
    );

    my $date_format = '%d/%m/%Y';
    my $datetime_format = '%d/%m/%Y %H:%i';
    my @select_fields = ();

    my $used_playerfields = 0;
    my $used_coachfields = 0;
    my $used_umpirefields = 0;
    my $used_miscfields = 0;
    my $used_volunteerfields = 0;
    my $used_schoolGrade    = 0;


    $memfieldlabels->{'MCStatus'} = "Active in $Data->{'LevelNames'}{$type}";

    for my $f (@{$showfields})    {
        my $label = '';
        my $skip_add_to_select = 0;
        $skip_add_to_select = 1 if $f =~ /^SKIP_/;
        $skip_add_to_select = 1 if $f =~ /strAgeGroupDesc/;
        $f=~s/^SKIP_//;
        if(exists $CustomFieldNames->{$f})    {
            $label = $CustomFieldNames->{$f}[0];
        }
        else    {
            $label = $memfieldlabels->{$f} || '';
        }
        my $field = $f;
        my $dbfield = $f;
        $field =~ s/\./_/g;
        if(!$skip_add_to_select)    {
            my $qualdbfield = _qualifyDBFields($dbfield);
            my $dbfield_str = '';
            push @select_fields, "$qualdbfield AS $dbfield".'_RAW' if $dbfield =~/^dt/;
            $dbfield_str = "DATE_FORMAT($qualdbfield,'$date_format')" if $dbfield =~/^dt/;
            $dbfield_str = "DATE_FORMAT($qualdbfield,'$datetime_format')" if $dbfield =~/^tTime/;
            $dbfield_str ||= $qualdbfield;
            $dbfield_str .= " AS $field" if($f=~/\./ or $dbfield_str =~ /FORMAT/);
            push @select_fields, $dbfield_str;
        }

        my ($type, $editor, $width) = getPersonListFieldOtherInfo($Data, $f);
        push @headers, {
            name   => $label || '',
            field  => $field,
            type   => $type,
            editor => $editor,
            width  => $width,
        };

    }

    my $clubID = $Data->{'clientValues'}{'clubID'} || 0;

    my $select_str = '';
    $select_str = ", ".join(',',@select_fields) if scalar(@select_fields);

    my $default_sort = ($Data->{'Permissions'}{'PersonList'}{'SORT'}[0]) ? $Data->{'Permissions'}{'PersonList'}{'SORT'}[0].", " : '';

    
    my $statement=qq[
        SELECT DISTINCT 
            P.intPersonID,
            P.strStatus,
            PR.strStatus as PRStatus,
            P.intSystemStatus
            $select_str
            $sel_str 
        FROM tblPerson  AS P
            INNER JOIN tblPersonRegistration_$realm_id AS PR
                ON P.intPersonID = PR.intPersonID

        LEFT JOIN tblPersonNotes ON tblPersonNotes.intPersonID = P.intPersonID
        WHERE P.strStatus <> 'DELETED'
            AND P.intRealmID = $Data->{'Realm'}
            AND PR.intEntityID = ?
        ORDER BY $default_sort strLocalSurname, strLocalFirstname
    ];

    my $query = exec_sql($statement, $entityID);
    my $found = 0;
    my @rowdata = ();
    my $newaction='P_HOME';
    my $lookupfields = personList_lookupVals($Data);

    my %tempClientValues = getClient($client);
    $tempClientValues{currentLevel} = $Defs::LEVEL_PERSON;
    while (my $dref = $query->fetchrow_hashref()) {
        next if (defined $dref->{strStatus} and $dref->{strStatus} eq 'DELETED');
        next if (defined $dref->{intSystemStatus} and $dref->{intSystemStatus} == $Defs::PERSONSTATUS_DELETED);
        $tempClientValues{personID} = $dref->{intPersonID};
        my $tempClient = setClient(\%tempClientValues);

        $dref->{'id'} = $dref->{'intPersonID'}.$found || 0;
        $dref->{'intAgeGroupID'} = -1 if (exists $dref->{'intAgeGroupID'} and $dref->{'intAgeGroupID'} eq 0);
        $dref->{'AgeGroups_strAgeGroupDesc'} = $dref->{'intAgeGroupID'}
        ? ($AgeGroups->{$dref->{'intAgeGroupID'}} || '')
        : '';
        $dref->{'intGender'} ||= 0;
        $dref->{'strLocalFirstname'} ||= '';
        $dref->{'strLocalSurname'} ||= '-';
        $dref->{'strLocalSurname'} .= '    (P)' if $dref->{'intPermit'};
        $dref->{'TxnTotalCount'} ||= 0;
        $dref->{'TxnTotalCount'} = ''. qq[<a href="$Data->{'target'}?client=$tempClient&amp;a=P_TXN_LIST">$dref->{TxnTotalCount}</a>];
        for my $k (keys %{$lookupfields})    {
            if($k and $dref->{$k} and $lookupfields->{$k} and $lookupfields->{$k}{$dref->{$k}}) {
                $dref->{$k} = $lookupfields->{$k}{$dref->{$k}};
            }
        }

        $dref->{'strStatus_Filter'}=$dref->{'strStatus'};
        if($dref->{'intSystemStatus'} ==$Defs::PERSONSTATUS_POSSIBLE_DUPLICATE )    {
            my %keepduplicatefields = (
                id => 1,
                intPersonID => 1,
                strLocalSurname => 1,
                strLocalFirstname=> 1,
                intPersonID=> 1,
                strStatus=> 1,
                intSeasonID=> 1,
                intAgeGroupID=> 1,
            );
            for my $k (keys %{$dref})    {
                if(!$keepduplicatefields{$k})    {
                    delete $dref->{$k};
                }
            }
            $dref->{'strStatus_Filter'}='1';
            $dref->{'strStatus'}='DUPLICATE';
        }

        if(allowedAction($Data, 'm_d') and $Data->{'SystemConfig'}{'AllowPersonDelete'})    {
            $dref->{'DELETELINK'} = qq[
            <a href="$Data->{'target'}?client=$tempClient&amp;a=P_DEL" 
                onclick="return confirm('Are you sure you want to Delete this $Data->{'LevelNames'}{$Defs::LEVEL_PERSON}');">Delete
            </a>
            ] 
        }
        $dref->{'SelectLink'} = "$target?client=$tempClient&amp;a=$newaction";
        push @rowdata, $dref;
        $found++;
    }


    my $error='';
    my $list_instruction = $Data->{'SystemConfig'}{"ListInstruction_$Defs::LEVEL_PERSON"} ? 
    qq[<div class="listinstruction">$Data->{'SystemConfig'}{"ListInstruction_$Defs::LEVEL_PERSON"}</div>] : '';
    $list_instruction=eval("qq[$list_instruction]") if $list_instruction;

    my $filterfields = [
        {
            field => 'strLocalSurname',
            elementID => 'id_textfilterfield',
            type => 'regex',
        }
    ];

        push @{$filterfields},
        {
            field => 'intAgeGroupID',
            elementID => 'dd_ageGroupfilter',
            allvalue => '-99',
        };
    my $msg_area_id   = '';
    my $msg_area_html = '';

    my $grid = showGrid(
        Data          => $Data,
        columns       => \@headers,
        rowdata       => \@rowdata,
        msgareaid     => $msg_area_id,
        gridid        => 'grid',
        width         => '99%',
        height        => '700',
        #filters       => $filterfields,
        client        => $client,
        #saveurl       => 'ajax/aj_persongrid_update.cgi',
        ajax_keyfield => 'intPersonID',
    );

    my %options = ();

    my $allowClubAdd = 1;

    if(allowedAction($Data, 'm_a'))    {
        $options{'addperson'} = [
        "$target?client=$client&amp;a=P_A&amp;l=$Defs::LEVEL_PERSON",
        $textLabels{'addPerson'}
        ];
        delete $options{'addperson'} if $Data->{'SystemConfig'}{'LockPerson'} or !$allowClubAdd;
    }


    if ($Data->{'clientValues'}{'authLevel'} == $Defs::LEVEL_CLUB and $Data->{'SystemConfig'}{'Club_PersonEditOnly'}) {
        delete $options{'rollover_persons'} ;
        delete $options{'activateperson'};
        delete $options{'addperson'};
    }

    my $modoptions = '';
    if(scalar(keys %options) )    {
        for my $i (qw(addperson modifyplayerlist bulkchangetags ))    {
            if(exists $options{$i})    {
                $modoptions .=qq~<span class = "button-small generic-button"><a href = "$options{$i}[0]">$options{$i}[1]</a></span>~;
            }
        }
        $modoptions = qq[<div class="changeoptions">$modoptions</div>] if $modoptions;
    }

    my $title=$textLabels{'personsInLevel'};
    $title = $modoptions.$title;
    #$title = 'Pending ' . $title if ($is_pending_registration);

    my $rectype_options=show_recordtypes(
        $Data,
        $Data->{'lang'}->txt('Family Name'),
        '',
        \%Defs::personStatus,
        { 'ALL' => $Data->{'lang'}->txt('All'), },
    ) || '';

    $resultHTML =qq[
        $list_instruction
        $msg_area_html
        <div class ="grid-filter-wrap">
            $rectype_options
            $grid
        </div>
        $error
    ];

    return ($resultHTML,$title);
}

sub setupPersonListFields    {
    my ($Data) = @_;

    #Setup default fields
    my @listfields=qw( 
        strLocalSurname 
        strLocalFirstname 
        intAgeGroupID
        strStatus 
        dtDOB 
        strSuburb 
        strPhoneMobile 
        strEmail
    );

    # These fields are only relevant to particular levels of person lists
    my $level_relevant = {
    };

    if($Data->{'Permissions'} and $Data->{'Permissions'}{'PersonList'}) {
        @listfields = sort {
            $Data->{'Permissions'}{'PersonList'}{$a}[0] <=> $Data->{'Permissions'}{'PersonList'}{$b}[0] 
        } keys %{$Data->{'Permissions'}{'PersonList'}};
    }
    my $count_fields = 0;
    my @showfields=();
    for my $f (@listfields) {
        if( $f eq 'SORT') {
            next;
        }
        if (exists $level_relevant->{$f} ){
            # Skip unless we are relevant to this level
            next unless $level_relevant->{$f}->{$Data->{'clientValues'}{'currentLevel'}};
        }
        $count_fields++;
        if($Data->{'Permissions'}
            and $Data->{'Permissions'}{'Person'}
            and $Data->{'Permissions'}{'Person'}{$f}
            and $Data->{'Permissions'}{'Person'}{$f} eq 'Hidden') {
                next;
        }
        push @showfields, $f;
    }

    return \@showfields;
}

sub getPersonListFieldOtherInfo {
    my ($Data, $field) = @_;

    my %IntegerFields;
    my %TextFields;

    my %CheckBoxFields=(
        strStatus=> $Defs::RECSTATUS_ACTIVE,
        intMSRecStatus=> 1,
        intPlayerPending=>1,
        intDeceased=> 1,
        intFinancialActive => 1,
        intLifePerson => 1,
        intMedicalConditions => 1,
        intAllergies => 1,
        intAllowMedicalTreatment => 1,
        intMailingList => 1,
        intFavNationalTeamPerson => 1,
        intConsentSignatureSighted => 1,
        'Player.intActive' => 1,
        'Player.intInt2' => 1,
        'Player.intInt3' => 1,
        'Player.intInt4' => 1,
        'Coach.intActive' => 1,
        'Coach.intInt1' => 1,
        'Umpire.intActive' => 1,
        'Umpire.intInt2' => 1,
        'Misc.intActive' => 1,
        'Misc.intInt2' => 1,
        'Volunteer.intActive' => 1,
        'Volunteer.intInt2' => 1,
        MCStatus=> $Defs::RECSTATUS_ACTIVE,
        'Seasons.intMSRecStatus' => 1,
        'Seasons.intPlayerStatus' => 1,
        'Seasons.intPlayerFinancialStatus' => 1,
        'Seasons.intCoachStatus' => 1,
        'Seasons.intCoachFinancialStatus' => 1,
        'Seasons.intUmpireStatus' => 1,
        'Seasons.intUmpireFinancialStatus' => 1,
        'Seasons.intMiscStatus' => 1,
        'Seasons.intMiscFinancialStatus' => 1,
        'Seasons.intVolunteerStatus' => 1,
        'Seasons.intVolunteerFinancialStatus' => 1,
        'Seasons.intOther1Status' => 1,
        'Seasons.intOther1FinancialStatus' => 1,
        'Seasons.intOther2Status' => 1,
        'Seasons.intOther2FinancialStatus' => 1,
        MTStatus=> $Defs::RECSTATUS_ACTIVE,
        MTCompStatus=> $Defs::RECSTATUS_ACTIVE,
        intCustomBool1 => 1,
        intCustomBool2 => 1,
        intCustomBool3 => 1,
        intCustomBool4 => 1,
        intCustomBool5 => 1,
        intNatCustomBool1 => 1,
        intNatCustomBool2 => 1,
        intNatCustomBool3 => 1,
        intNatCustomBool4 => 1,
        intNatCustomBool5 => 1,
        TXNStatus=>1,
    );
    my $type = '';
    my $editor = '';
    $type = 'tick' if $CheckBoxFields{$field};    
    if($Data->{'Permissions'}{'Person'})    {
        #Setup Check Box Fields
        for my $k (keys %CheckBoxFields)    {
            if($k=~/\./)    {
                delete $CheckBoxFields{$k} if !allowedAction($Data, 'mt_e');
            }
            else    {
                delete $CheckBoxFields{$k} if !allowedAction($Data, 'm_e');
                if ($k eq 'MCStatus' or $k eq 'MTStatus')    {
                    ## If permission set,allow club to reactivate an inactive person
                    delete $CheckBoxFields{$k} if ($Data->{'clientValues'}{'authLevel'} <= $Defs::LEVEL_CLUB and ! allowedAction($Data, 'm_ia'));
                }
                else    {
                    delete $CheckBoxFields{$k} if ((!$Data->{'Permissions'}{'Person'}{$k} or $Data->{'Permissions'}{'Person'}{$k} eq 'Hidden' or $Data->{'Permissions'}{'Person'}{$k} eq 'ReadOnly') and    $Data->{'clientValues'}{'authLevel'} < $Defs::LEVEL_ASSOC);
                }
            }
        }
        $CheckBoxFields{'TXNStatus'} = $Defs::TXN_PAID if(($Data->{'SystemConfig'}{'AllowProdTXNs'} or $Data->{'SystemConfig'}{'AllowTXNs'}) and allowedAction($Data, 'm_e') and $Data->{'clientValues'}{'authLevel'} >= $Defs::LEVEL_ASSOC);
    }
    $type='tick' if ($field eq 'TXNStatus');
    if( !allowedAction($Data, 'm_e') or $Data->{'SystemConfig'}{'LockPerson'}) {
        for my $i (qw( strStatus intMSRecStatus MCStatus intActive MTStatus MTCompStatus)) {
            delete $CheckBoxFields{$i};
        }
    }
    $editor = 'checkbox' if $CheckBoxFields{$field};
    $editor = 'text' if $TextFields{$field};    #todo: fix this to force integers?
    my $width = 0;
    $width = 50 if $field eq 'intGender';
    $type = 'HTML' if($field eq 'TxnTotalCount');
    $type = 'HTML' if $IntegerFields{$field}; 
    return (
        $type,
        $editor,
        $width,
    );

}

sub personList_lookupVals {
    my($Data)=@_;
    my %ynVals=( 1 => 'Y', 0 => 'N');
    my %lookupfields=(
        intGender => {
            $Defs::GENDER_MALE => 'M',
            $Defs::GENDER_FEMALE=> 'F',
            $Defs::GENDER_NONE=> '',
        },
    );

    return \%lookupfields;
}

sub _qualifyDBFields    {
    my ($field) = @_;
    return $field if $field =~/\./;
    my %FieldTables    = (
        strAddress1 => 'P',
        strAddress2 => 'P',
        strSuburb => 'P',
        strState => 'P',
        strCountry => 'P',
        strEmail => 'P',
        strPostalCode => 'P',
        strMobile => 'P',
        strStatus => 'P',
        tTimeStamp =>'P',
    );
    my $tablename = $FieldTables{$field} || '';

    return $tablename ? "$tablename.$field" : $field;
}



1;
# vim: set et sw=4 ts=4:
