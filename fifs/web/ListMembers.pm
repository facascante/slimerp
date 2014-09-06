#
# $Header: svn://svn/SWM/trunk/web/ListMembers.pm 11631 2014-05-21 04:32:15Z sliu $
#

package ListMembers;

require Exporter;
@ISA =    qw(Exporter);
@EXPORT = qw(listMembers bulkMemberRollover listMemberSeasons bulkMemberRolloverUpdate);
@EXPORT_OK = qw(listMembers bulkMemberRollover listMemberSeasons bulkMemberRolloverUpdate);

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
use Seasons;
use FormHelpers;
use AuditLog;
use Log;
use TTTemplate;

sub listMembers {
    my ($Data, $id, $action, $tags) = @_; 

    my $is_pending_registration = ($Data->{'SystemConfig'}{'AllowPendingRegistration'} and $action =~ /^M_PRS_L/ );

    my $validate_pending_approval = 0;

    $validate_pending_approval = $Data->{'SystemConfig'}{'DuplicatePrevention_PendingApproval'} || 0 if $is_pending_registration;

    my $cellValidatorFuncs = getCellValidatorFuncs($Data, $validate_pending_approval);

    my $db            = $Data->{'db'};
    my $resultHTML    = '';
    my $client        = unescape($Data->{client});
    my $where_str     = '';
    my $from_str      = '';
    my $sel_str       = '';
    my $type          = $Data->{'clientValues'}{'currentLevel'};
    my $levelName     = $Data->{'LevelNames'}{$type} || '';
    my $mtCompID      = param('mtCompID') || 0;
    my $action_IN     = $action || '';
    my $target        = $Data->{'target'} || '';;
    my $realm_id      = $Data->{'Realm'};

    my $assocObj = getInstanceOf($Data, 'assoc', $Data->{'clientValues'}{'assocID'});

    my ($hideAssocRollover, $hideAllCheckbox, $defaultregoID) = $assocObj->getValue(['intHideRollover', 'intHideAllRolloverCheckbox', 'intDefaultRegoProductID']);

    if(! $Data->{'SystemConfig'}{'AllowProdTXNs'} and ! $Data->{'SystemConfig'}{'AllowTXNs'})    {
        $defaultregoID=0;
    }

    my $assocSeasons = Seasons::getDefaultAssocSeasons($Data);
    my ($Seasons, undef) = Seasons::getSeasons($Data);
    my ($AgeGroups, undef) = AgeGroups::getAgeGroups($Data);

    my $seasonID = $Data->{'ViewSeason'}    || 0;
    if( $seasonID <=-1 and !$assocSeasons->{'allowSeasons'}) {
        $seasonID = $assocSeasons->{'currentSeasonID'} 
    }
    if ($seasonID <= -1 or ($seasonID and exists $Seasons->{$seasonID})) {
        $seasonID =    $seasonID 
    }
    else    { 
        $seasonID = $assocSeasons->{'currentSeasonID'};
    }

    my $lang = $Data->{'lang'};
    my $txt_SeasonName= $Data->{'SystemConfig'}{'txtSeason'} || 'Season';
    my %textLabels = (
        'addMember' => $lang->txt("Add"),
        'transferMember' => $lang->txt('Transfer Member'),
        'modifyMemberList' => $lang->txt('Modify Member List'),
        'membersInLevel' => $lang->txt("$Data->{'LevelNames'}{$Defs::LEVEL_MEMBER.'_P'} in $Data->{'LevelNames'}{$type}"),
        'invalidPageRequested' => $lang->txt('Invalid page requested.'),
        'seasonRollover' => $lang->txt("$txt_SeasonName Rollover"),
    );

    my $groupBy = '';
    my $MStablename = "tblMember_Seasons_$realm_id";
    my $season_JOIN = '';

    if ( $is_pending_registration ) {
        $season_JOIN = qq[
            INNER JOIN $MStablename as Seasons ON (
                Seasons.intMemberID = tblMember.intMemberID 
                AND Seasons.intSeasonID = $assocSeasons->{'currentSeasonID'}
                AND Seasons.intAssocID = tblMember_Associations.intAssocID
                AND Seasons.intMSRecStatus <> $Defs::RECSTATUS_DELETED
            )
        ];
    }
    else {
        $season_JOIN = qq[
            INNER JOIN $MStablename as Seasons ON (
                Seasons.intMemberID = tblMember.intMemberID 
                AND Seasons.intAssocID = tblMember_Associations.intAssocID
                AND Seasons.intMSRecStatus = 1
            )
        ];
    }
    my $season_WHERE = '';
    my $showRecordType=1;

    my $mtypefilter= $Data->{'CookieMemberTypeFilter'} ? qq[ AND $Data->{'CookieMemberTypeFilter'} = 1 ] : '';
    my $season_SELECT = qq[
        Seasons.intPlayerStatus as Seasons_intPlayerStatus,
        Seasons.intSeasonID, Seasons.intPlayerAgeGroupID,
        Seasons.intPlayerFinancialStatus as Seasons_intPlayerFinancialStatus,
        Seasons.intCoachStatus as Seasons_intCoachStatus,
        Seasons.intCoachFinancialStatus as Seasons_intCoachFinancialStatus,
        Seasons.intUmpireStatus as Seasons_intUmpireStatus,
        Seasons.intUmpireFinancialStatus as Seasons_intUmpireFinancialStatus,
        Seasons.intMiscStatus as Seasons_intMiscStatus,
        Seasons.intMiscFinancialStatus as Seasons_intMiscFinancialStatus,
        Seasons.intVolunteerStatus as Seasons_intVolunteerStatus,
        Seasons.intVolunteerFinancialStatus as Seasons_intVolunteerFinancialStatus,
        Seasons.intOther1Status as Seasons_intOther1Status,
        Seasons.intOther1FinancialStatus as Seasons_intOther1FinancialStatus,
        Seasons.intOther2Status as Seasons_intOther2Status,
        Seasons.intOther2FinancialStatus as Seasons_intOther2FinancialStatus,
        Seasons.intMSRecStatus as Seasons_intMSRecStatus,
    ];


    if($type == $Defs::LEVEL_ASSOC) {
        $where_str=qq[ tblMember_Associations.intAssocID=$Data->{'clientValues'}{'assocID'} ];
        $season_WHERE .= qq[ AND Seasons.intClubID = 0];
    }
    elsif($type == $Defs::LEVEL_CLUB) {
        $sel_str=qq[ , IF(MCStatusJOIN.intStatus=1, 0, tblMember_Clubs.intPermit) as intPermit, MAX(tblMember_Clubs.intStatus) as MCStatus ];
        $from_str=qq[ INNER JOIN tblMember_Clubs LEFT JOIN tblMember_Clubs as MCStatusJOIN ON (MCStatusJOIN.intMemberID = tblMember.intMemberID AND MCStatusJOIN.intClubID= $Data->{'clientValues'}{'clubID'} AND MCStatusJOIN.intStatus=1 AND MCStatusJOIN.intPermit=0)];
        $where_str=qq[ 
            tblMember_Clubs.intStatus>-1
            AND (MCStatusJOIN.intStatus>-1 or MCStatusJOIN.intStatus IS NULL)
            AND tblMember_Clubs.intClubID=$Data->{'clientValues'}{'clubID'}
            AND tblMember.intMemberID=tblMember_Clubs.intMemberID
            AND tblMember_Associations.intAssocID=$Data->{'clientValues'}{'assocID'} 
        ];
        $groupBy = qq[ GROUP BY tblMember.intMemberID, Seasons.intSeasonID];
        $season_WHERE .= qq[ AND Seasons.intClubID = $Data->{'clientValues'}{'clubID'}];
    }
    return textMessage($textLabels{'invalidPageRequested'}) if !$type;

    my $from_str_ORIG = $from_str || '';
    my $where_str_ORIG = $where_str || '';
    if($defaultregoID or $Data->{'SystemConfig'}{'memberListShowTxnUnpaidCount'})    {
        my $txnDefault_ClubWHERE = '';
        my $txnTotal_ClubWHERE = '';
        my $RealmLPF_Ids = ($Data->{'SystemConfig'}{'LPF_ids'}) ? $Data->{'SystemConfig'}{'LPF_ids'} : 0;
        if ($type == $Defs::LEVEL_CLUB and $Data->{'clientValues'}{'clubID'})     {
            $txnDefault_ClubWHERE = qq[ AND TxnDefault.intTXNClubID IN (0, $Data->{'clientValues'}{'clubID'})];
            $txnTotal_ClubWHERE = qq[ AND TxnTotal.intTXNClubID IN (0, $Data->{'clientValues'}{'clubID'})];
        }
        $sel_str.=", TxnDefault.intStatus AS TXNStatus, COUNT(DISTINCT TxnTotal.intTransactionID) as TxnTotalCount";
        my $prodfrom=qq[ LEFT JOIN tblTransactions as TxnDefault ON (
            TxnDefault.intID=tblMember.intMemberID AND TxnDefault.intTableType=$Defs::LEVEL_MEMBER
                AND TxnDefault.intProductID = $defaultregoID AND TxnDefault.intStatus<2 AND    TxnDefault.intAssocID = $Data->{'clientValues'}{'assocID'} $txnDefault_ClubWHERE)
        LEFT JOIN tblTransactions as TxnTotal ON (
            TxnTotal.intID=tblMember.intMemberID AND TxnTotal.intTableType=$Defs::LEVEL_MEMBER
                AND TxnTotal.intStatus=0 AND TxnTotal.intAssocID = $Data->{'clientValues'}{'assocID'} $txnTotal_ClubWHERE AND TxnTotal.intProductID NOT IN ($RealmLPF_Ids))
        ];
        my $prodwhere= " AND TxnDefault.intStatus != 2";
        $groupBy = qq[ GROUP BY tblMember.intMemberID, TXNStatus, Seasons.intSeasonID];
        $prodwhere = $action eq 'M_LPD' ?    $prodwhere." AND TxnDefault.intStatus = $Defs::TXN_UNPAID " : '';
        $from_str.=$prodfrom;
        $where_str.= $prodwhere;
    }
    my $totalMembers=0;

    my $showfields = setupMemberListFields($Data);

    # do not display intRecStatus/intMCStatus if is_pending_registration
    if ($is_pending_registration) {
        $showfields = [grep { $_ ne 'intRecStatus' and $_ ne 'MCStatus' } @{$showfields}];
        push @{$showfields}, 'intPlayerPending';
    }

    my $memfieldlabels=FieldLabels::getFieldLabels($Data,$Defs::LEVEL_MEMBER);
    my $CustomFieldNames=CustomFields::getCustomFieldNames($Data, $Data->{'SubRealm'} || 0) || '';
    if($Data->{'SystemConfig'}{'MemberListFields'})    {
        my @sf =split /,/, $Data->{'SystemConfig'}{'MemberListFields'} ;
        $showfields = \@sf;
    }

    if ($defaultregoID or $Data->{'SystemConfig'}{'memberListShowTxnUnpaidCount'}) {
        if($defaultregoID) {
            push @{$showfields}, 'SKIP_TXNStatus';
            $memfieldlabels->{'TXNStatus'} = $Data->{'lang'}->txt('Paid Default Product?');
        }
        push @{$showfields}, 'SKIP_TxnTotalCount';
        $memfieldlabels->{'TxnTotalCount'} = $Data->{'lang'}->txt("Total Unpaid");
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

    push @{$showfields}, 'SKIP_MCStatus' if $type == $Defs::LEVEL_CLUB and !$is_pending_registration;

    $memfieldlabels->{'MCStatus'} = "Active in $Data->{'LevelNames'}{$type}";
    $memfieldlabels->{'MTStatus'} = "Active in $Data->{'LevelNames'}{$type}";
    $memfieldlabels->{'MTCompStatus'} = "Active in $Data->{'LevelNames'}{$Defs::LEVEL_COMP}";
    $memfieldlabels->{'tblSchoolGrades.strName'} = "School Grade";

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

        my ($type, $editor, $width) = getMemberListFieldOtherInfo($Data, $f);
        push @headers, {
            name   => $label || '',
            field  => $field,
            type   => $type,
            editor => $editor,
            width  => $width,
        };

        $used_playerfields = 1    if $f =~/Player\./    or $Data->{'Permissions'}{'MemberList'}{'SORT'}[0]=~/Player\./;
        $used_coachfields = 1     if $f =~/Coach\./     or $Data->{'Permissions'}{'MemberList'}{'SORT'}[0]=~/Coach\./;
        $used_umpirefields = 1    if $f =~/Umpire\./    or $Data->{'Permissions'}{'MemberList'}{'SORT'}[0]=~/Umpire\./;
        $used_miscfields = 1      if $f =~/Misc\./      or $Data->{'Permissions'}{'MemberList'}{'SORT'}[0]=~/Misc\./;
        $used_volunteerfields = 1 if $f =~/Volunteer\./ or $Data->{'Permissions'}{'MemberList'}{'SORT'}[0]=~/Volunteer\./;

    }

    if ($is_pending_registration) {
        for my $header (@headers) {
            if ($header->{'field'} eq 'intPlayerPending') {
                $header->{'type'}      = 'selectlist';
                $header->{'editor'}    = 'selectbox';
                $header->{'options'}   = "-1,Reject|1,Pending|0,Approve";
                $header->{'validator'} = "pendingApproval" if exists $cellValidatorFuncs->{'pendingApproval'};
            }
        }
    }

    my $clubID = $Data->{'clientValues'}{'clubID'} || 0;

    my $select_str = '';
    $select_str = ", ".join(',',@select_fields) if scalar(@select_fields);
    my $playerjoin = $used_playerfields
    ? qq[
    LEFT JOIN tblMember_Types AS Player ON (
        Player.intMemberID=tblMember.intMemberID 
            AND Player.intAssocID= $Data->{'clientValues'}{'assocID'} 
            AND Player.intTypeID = $Defs::MEMBER_TYPE_PLAYER 
            AND Player.intSubTypeID = 0 
            AND Player.intRecStatus>$Defs::RECSTATUS_DELETED
    )
    ]
    : '';
    my $coachjoin = $used_coachfields
    ? qq[
    LEFT JOIN tblMember_Types AS Coach ON (
        Coach.intMemberID=tblMember.intMemberID 
            AND Coach.intAssocID= $Data->{'clientValues'}{'assocID'} 
            AND Coach.intTypeID = $Defs::MEMBER_TYPE_COACH 
            AND Coach.intSubTypeID=0 
            AND Coach.intRecStatus>$Defs::RECSTATUS_DELETED
    )
    ]
    : '';
    my $umpirejoin = $used_umpirefields
    ? qq[
    LEFT JOIN tblMember_Types AS Umpire ON (
        Umpire.intMemberID=tblMember.intMemberID 
            AND Umpire.intAssocID= $Data->{'clientValues'}{'assocID'} 
            AND Umpire.intTypeID = $Defs::MEMBER_TYPE_UMPIRE 
            AND Umpire.intSubTypeID=0 
            AND Umpire.intRecStatus>$Defs::RECSTATUS_DELETED
    )
    ]
    : '';
    my $miscjoin = $used_miscfields
    ? qq[
    LEFT JOIN tblMember_Types AS Misc ON (
        Misc.intMemberID=tblMember.intMemberID 
            AND Misc.intAssocID= $Data->{'clientValues'}{'assocID'} 
            AND Misc.intTypeID = $Defs::MEMBER_TYPE_MISC
            AND Misc.intSubTypeID=0 
            AND Misc.intRecStatus>$Defs::RECSTATUS_DELETED
    )
    ]
    : '';
    my $volunteerjoin = $used_volunteerfields
    ? qq[
    LEFT JOIN tblMember_Types AS Volunteer ON (
        Volunteer.intMemberID=tblMember.intMemberID 
            AND Volunteer.intAssocID= $Data->{'clientValues'}{'assocID'} 
            AND Volunteer.intTypeID = $Defs::MEMBER_TYPE_VOLUNTEER
            AND Volunteer.intSubTypeID=0 
            AND Volunteer.intRecStatus>$Defs::RECSTATUS_DELETED
    )
    ]
    : '';

    $season_SELECT='';
    if($seasonID > 0)    {
        $season_WHERE .= qq[ AND Seasons.intSeasonID = $seasonID] if(!$is_pending_registration);
        $season_SELECT = qq[, Seasons.intSeasonID, Seasons.intPlayerAgeGroupID];
    }

    if ($seasonID == -2 and !$is_pending_registration)    {
        $season_JOIN =~ s/INNER/LEFT/;
        $season_JOIN =~ s/\)/ AND Seasons.intClubID = $Data->{'clientValues'}{'clubID'}\)/ if ($Data->{'clientValues'}{'clubID'} and $type == $Defs::LEVEL_CLUB);
        $season_WHERE = qq[ AND Seasons.intMemberSeasonID IS NULL];
        $season_SELECT = qq[];
    }

    if ( $is_pending_registration ) {
        $season_WHERE .= qq[ AND Seasons.intPlayerPending=1 ];
    }


    my ($record_type_join, $record_type_select, $record_type_filter);
   if($mtypefilter) {
        if( $Data->{'CookieMemberTypeFilter'} eq 'intPlayer')     {
            $sel_str .= qq[, 
                Player.intActive AS Player_intActive, 
                DATE_FORMAT(Player.dtDate1,"%d/%m/%Y") AS Player_dtDate1, 
                Player.intInt1 AS Player_intInt1, 
                Player.intInt2 AS Player_intInt2, 
                Player.intInt3 AS Player_intInt3, 
                Player.intInt4 AS Player_intInt4 
            ];
            $from_str.=qq[ 
                LEFT JOIN tblMember_Types AS Player ON (
                    Player.intMemberID=tblMember.intMemberID 
                    AND Player.intAssocID= $Data->{'clientValues'}{'assocID'} 
                    AND Player.intTypeID = $Defs::MEMBER_TYPE_PLAYER 
                    AND Player.intSubTypeID=0 
                    AND Player.intStatus=$Defs::RECSTATUS_ACTIVE
                ) 
            ];
        }
        elsif( $Data->{'CookieMemberTypeFilter'} eq 'intCoach') {
            $sel_str.=qq[, 
                Coach.intActive AS Coach_intActive, 
                DATE_FORMAT(Coach.dtDate1,"%d/%m/%Y") AS Coach_dtDate1, 
                Coach.intInt1 AS Coach_intInt1, 
                Coach.intInt2 AS Coach_intInt2, 
                Coach.intInt3 AS Coach_intInt3, 
                Coach.intInt4 AS Coach_intInt4, 
                Coach.strString1 AS Coach_strString1, 
                Coach.strString2 AS Coach_strString2, 
                Coach.strString3 AS Coach_strString3, 
                Coach.strString4 AS Coach_strString4 
            ];
            $from_str.=qq[ 
                LEFT JOIN tblMember_Types AS Coach ON (
                    Coach.intMemberID=tblMember.intMemberID 
                    AND Coach.intAssocID= $Data->{'clientValues'}{'assocID'} 
                    AND Coach.intTypeID = $Defs::MEMBER_TYPE_COACH 
                    AND Coach.intSubTypeID=0 
                    AND Coach.intRecStatus=$Defs::RECSTATUS_ACTIVE
                ) 
            ];
        }
        elsif( $Data->{'CookieMemberTypeFilter'} eq 'intUmpire')                {
            $sel_str.=qq[, 
                Umpire.intActive AS Umpire_intActive, 
                DATE_FORMAT(Umpire.dtDate1,"%d/%m/%Y") AS Umpire_dtDate1, 
                Umpire.intInt1 AS Umpire_intInt1, 
                Umpire.intInt2 AS Umpire_intInt2, 
                Umpire.intInt3 AS Umpire_intInt3, 
                Umpire.intInt4 AS Umpire_intInt4, 
                Umpire.strString1 AS Umpire_strString1, 
                Umpire.strString2 AS Umpire_strString2, 
                Umpire.strString3 AS Umpire_strString3, 
                Umpire.strString4 AS Umpire_strString4 
            ];
            $from_str.=qq[ 
                LEFT JOIN tblMember_Types AS Umpire ON (
                    Umpire.intMemberID=tblMember.intMemberID 
                    AND Umpire.intAssocID= $Data->{'clientValues'}{'assocID'} 
                    AND Umpire.intTypeID = $Defs::MEMBER_TYPE_UMPIRE 
                    AND Umpire.intSubTypeID=0 
                    AND Umpire.intRecStatus=$Defs::RECSTATUS_ACTIVE
                 ) 
             ];
        }
        elsif( $Data->{'CookieMemberTypeFilter'} eq 'intMisc') {
            $sel_str.=qq[, 
                Misc.intActive AS Misc_intActive, 
                DATE_FORMAT(Misc.dtDate1,"%d/%m/%Y") AS Misc_dtDate1, 
                Misc.intInt1 AS Misc_intInt1, 
                Misc.intInt2 AS Misc_intInt2, 
                Misc.intInt3 AS Misc_intInt3, 
                Misc.intInt4 AS Misc_intInt4, 
                Misc.strString1 AS Misc_strString1, 
                Misc.strString2 AS Misc_strString2, 
                Misc.strString3 AS Misc_strString3, 
                Misc.strString4 AS Misc_strString4 
            ];
            $from_str.=qq[ 
                LEFT JOIN tblMember_Types AS Misc ON (
                    Misc.intMemberID=tblMember.intMemberID 
                    AND Misc.intAssocID= $Data->{'clientValues'}{'assocID'} 
                    AND Misc.intTypeID = $Defs::MEMBER_TYPE_MISC 
                    AND Misc.intSubTypeID=0 
                    AND Misc.intRecStatus=$Defs::RECSTATUS_ACTIVE
                ) 
            ];
        }
        elsif( $Data->{'CookieMemberTypeFilter'} eq 'intVolunteer') {
            $sel_str.=qq[, 
                Volunteer.intActive AS Volunteer_intActive, 
                DATE_FORMAT(Volunteer.dtDate1,"%d/%m/%Y") AS Volunteer_dtDate1, 
                Volunteer.intInt1 AS Volunteer_intInt1, 
                Volunteer.intInt2 AS Volunteer_intInt2, 
                Volunteer.intInt3 AS Volunteer_intInt3, 
                Volunteer.intInt4 AS Volunteer_intInt4, 
                Volunteer.strString1 AS Volunteer_strString1, 
                Volunteer.strString2 AS Volunteer_strString2, 
                Volunteer.strString3 AS Volunteer_strString3, 
                Volunteer.strString4 AS Volunteer_strString4 
            ];
            $from_str.=qq[ 
                LEFT JOIN tblMember_Types AS Volunteer ON (
                    Volunteer.intMemberID=tblMember.intMemberID 
                    AND Volunteer.intAssocID= $Data->{'clientValues'}{'assocID'} 
                    AND Volunteer.intTypeID = $Defs::MEMBER_TYPE_VOLUNTEER 
                    AND Volunteer.intSubTypeID=0 
                    AND Volunteer.intRecStatus=$Defs::RECSTATUS_ACTIVE
                ) 
            ];
        }
    }

    my $default_sort = ($Data->{'Permissions'}{'MemberList'}{'SORT'}[0]) ? $Data->{'Permissions'}{'MemberList'}{'SORT'}[0].", " : '';

    my $statement=qq[
        SELECT DISTINCT 
            tblMember.intMemberID,
            tblMember.intStatus,
            tblMember_Associations.intRecStatus
            $season_SELECT
            $record_type_select
            $select_str
            $sel_str 
        FROM tblMember 
        INNER JOIN tblMember_Associations ON (tblMember_Associations.intMemberID=tblMember.intMemberID)    
        LEFT JOIN tblMemberPackages ON (tblMember_Associations.intMemberPackageID=tblMemberPackages.intMemberPackagesID)    
        $from_str 
        $season_JOIN
        $playerjoin
        $coachjoin
        $umpirejoin
        $miscjoin
        $volunteerjoin
        $record_type_join
        LEFT JOIN tblSchoolGrades ON (tblMember.intGradeID = tblSchoolGrades.intGradeID)
        LEFT JOIN tblMemberNotes ON tblMemberNotes.intNotesMemberID = tblMember.intMemberID
        WHERE tblMember.intStatus <> $Defs::RECSTATUS_DELETED 
            AND tblMember.intRealmID = $Data->{'Realm'}
            AND $where_str
            $mtypefilter 
            $record_type_filter
            $season_WHERE
        $groupBy
        ORDER BY $default_sort strSurname, strFirstname
    ];

    my $query = exec_sql($statement);
    my $found = 0;
    my @rowdata = ();
    my $newaction=($Data->{'SystemConfig'}{'DefaultListAction'} || 'DT') eq 'SUMM' ? 'M_SEL_l' : 'M_HOME';
    my $lookupfields = memberList_lookupVals($Data);

    my %tempClientValues = getClient($client);
    $tempClientValues{currentLevel} = $Defs::LEVEL_MEMBER;
    while (my $dref = $query->fetchrow_hashref()) {
        $dref->{intPlayerPending} = int($dref->{intPlayerPending}) if exists $dref->{intPlayerPending};
        next if (defined $dref->{intRecStatus} and $dref->{intRecStatus} == $Defs::RECSTATUS_DELETED);
        $tempClientValues{memberID} = $dref->{intMemberID};
        my $tempClient = setClient(\%tempClientValues);

        $dref->{'id'} = $dref->{'intMemberID'}.$found || 0;
        $dref->{'strSeasonName'} = $dref->{'intSeasonID'} 
        ? ($Seasons->{$dref->{'intSeasonID'}} || '') 
        : '';
        $dref->{'extraid'} = $dref->{'intSeasonID'} || 0;
        $dref->{'intPlayerAgeGroupID'} = -1 if (exists $dref->{'intPlayerAgeGroupID'} and $dref->{'intPlayerAgeGroupID'} eq 0);
        $dref->{'AgeGroups_strAgeGroupDesc'} = $dref->{'intPlayerAgeGroupID'}
        ? ($AgeGroups->{$dref->{'intPlayerAgeGroupID'}} || '')
        : '';
        $dref->{'intPermit'} ||= 0;
        $dref->{'intGender'} ||= 0;
        $dref->{'strFirstname'} ||= '';
        $dref->{'strSurname'} ||= '-';
        $dref->{'strSurname'} .= '    (P)' if $dref->{'intPermit'};
        $dref->{'TxnTotalCount'} ||= 0;
        $dref->{'TxnTotalCount'} = ''. qq[<a href="$Data->{'target'}?client=$tempClient&amp;a=M_TXN_LIST">$dref->{TxnTotalCount}</a>];
        for my $k (keys %{$lookupfields})    {
            if($k and $dref->{$k} and $lookupfields->{$k} and $lookupfields->{$k}{$dref->{$k}}) {
                $dref->{$k} = $lookupfields->{$k}{$dref->{$k}};
            }
        }

        $dref->{'intRecStatus_Filter'}=$dref->{'intRecStatus'};
        if($dref->{'intStatus'}==$Defs::MEMBERSTATUS_POSSIBLE_DUPLICATE and !$is_pending_registration)    {
            my %keepduplicatefields = (
                id => 1,
                intMemberID => 1,
                strSurname => 1,
                strFirstname=> 1,
                intMemberID=> 1,
                intStatus=> 1,
                intRecStatus=> 1,
                intSeasonID=> 1,
                intAgeGroupID=> 1,
            );
            for my $k (keys %{$dref})    {
                if(!$keepduplicatefields{$k})    {
                    delete $dref->{$k};
                }
            }
            $dref->{'intRecStatus_Filter'}='1';
            $dref->{'intRecStatus'}='D';
        }

        if(allowedAction($Data, 'm_d') and $Data->{'SystemConfig'}{'AllowMemberDelete'})    {
            $dref->{'DELETELINK'} = qq[
            <a href="$Data->{'target'}?client=$tempClient&amp;a=M_DEL" 
                onclick="return confirm('Are you sure you want to Delete this $Data->{'LevelNames'}{$Defs::LEVEL_MEMBER}');">Delete
            </a>
            ] 
        }
        $dref->{'SelectLink'} = "$target?client=$tempClient&amp;a=$newaction";
        push @rowdata, $dref;
        $found++;
    }


    my $error='';
    my $list_instruction = $Data->{'SystemConfig'}{"ListInstruction_$Defs::LEVEL_MEMBER"} ? 
    qq[<div class="listinstruction">$Data->{'SystemConfig'}{"ListInstruction_$Defs::LEVEL_MEMBER"}</div>] : '';
    $list_instruction=eval("qq[$list_instruction]") if $list_instruction;

    my $filterfields = [
        {
            field => 'strSurname',
            elementID => 'id_textfilterfield',
            type => 'regex',
        }
    ];

    if($assocSeasons->{'allowSeasons'}) {
        push @{$filterfields},
        {
            field => 'intPlayerAgeGroupID',
            elementID => 'dd_ageGroupfilter',
            allvalue => '-99',
        };
    }
    if( not $is_pending_registration and $type == $Defs::LEVEL_ASSOC) {
        push @{$filterfields}, {
            field => 'intRecStatus_Filter',
            elementID => 'dd_actstatus',
            allvalue => '2',
        };
    }
    if( not $is_pending_registration and $type == $Defs::LEVEL_CLUB) {
        push @{$filterfields}, {
            field => 'MCStatus',
            elementID => 'dd_MCStatus',
            allvalue => '2',
        };
    }

    my $cellValidator = '';
    foreach my $cvf (keys %$cellValidatorFuncs) {
        $cellValidator .= $cellValidatorFuncs->{$cvf};
    }

    my $msg_area_id   = '';
    my $msg_area_html = '';

    if ($is_pending_registration) {
        $msg_area_id   = "msgarea";
        $msg_area_html = qq[<div id="$msg_area_id" class="warningmsg" style="display:none"></div>];
    }

    my $grid = showGrid(
        Data          => $Data,
        columns       => \@headers,
        rowdata       => \@rowdata,
        cellValidator => $cellValidator,
        msgareaid     => $msg_area_id,
        gridid        => 'grid',
        width         => '99%',
        height        => '700',
        filters       => $filterfields,
        client        => $client,
        saveurl       => 'ajax/aj_membergrid_update.cgi',
        ajax_keyfield => 'intMemberID',
    );

    my %options = ();

    my $allowClubAdd = 1;
    if (!$Data->{'SystemConfig'}{'NationalRegoAllowClubManualAdd'} and $Data->{'SystemConfig'}{'AllowOnlineRego_node'} and !$assocObj->getValue('intExcludeFromNationalRego')) {
        if ($type == $Defs::LEVEL_CLUB and $Data->{'clientValues'}{'authLevel'} == $Defs::LEVEL_CLUB) {
            $allowClubAdd = 0;
        }
    }

    if(allowedAction($Data, 'm_a'))    {
        $options{'addmember'} = [
        "$target?client=$client&amp;a=M_A&amp;l=$Defs::LEVEL_MEMBER",
        $textLabels{'addMember'}
        ];
        delete $options{'addmember'} if $Data->{'SystemConfig'}{'LockMember'} or !$allowClubAdd;
    }


    if ($Data->{'clientValues'}{'authLevel'} == $Defs::LEVEL_CLUB and $Data->{'SystemConfig'}{'Club_MemberEditOnly'}) {
        delete $options{'rollover_members'} ;
        delete $options{'activatemember'};
        delete $options{'addmember'};
    }

    my $modoptions = '';
    if(scalar(keys %options) )    {
        for my $i (qw(addmember modifyplayerlist bulkchangetags ))    {
            if(exists $options{$i})    {
                $modoptions .=qq~<span class = "button-small generic-button"><a href = "$options{$i}[0]">$options{$i}[1]</a></span>~;
            }
        }
        $modoptions = qq[<div class="changeoptions">$modoptions</div>] if $modoptions;
    }

    my $title=$textLabels{'membersInLevel'};
    $title = $modoptions.$title;
    $title = 'Pending ' . $title if ($is_pending_registration);
    my $omit_status = ($type == $Defs::LEVEL_CLUB or $is_pending_registration) ? 1 : 0;
    my $omit_season = 1 if $is_pending_registration;

    my $rectype_options = show_recordtypes($Data, $Defs::LEVEL_MEMBER, 1, $memfieldlabels, 'Family Name',1, $omit_status, $omit_season);

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

sub getCellValidatorFuncs {
    my ($Data, $pending_approval) = @_;

    my %cellValidatorFuncs = ();

    if ($pending_approval) {
        my $client = setClient($Data->{'clientValues'});

        my $assocID = $Data->{'clientValues'}{'assocID'};
        my $clubID  = $Data->{'clientValues'}{'clubID'};

        my ($entityTypeID, $entityID) = getEntityValues($Data->{'clientValues'});
        my $key1 = $entityTypeID + $entityID + int(rand(1000));
        my $key2 = getRegoPassword($key1);

        my %templateData = (
            client  => $client,
            assocID => $assocID,
            clubID  => $clubID,
            key1    => $key1,
            key2    => $key2,
        );

        my $templateFile = 'listmembers/pending_approval.templ';
        $cellValidatorFuncs{'pendingApproval'} = runTemplate($Data, \%templateData, $templateFile);
    }

    return \%cellValidatorFuncs;
}

sub setupMemberListFields    {
    my ($Data) = @_;

    #Setup default fields
    my @listfields=qw( 
        strSurname 
        strFirstname 
        intPlayerAgeGroupID
        intRecStatus 
        dtDOB 
        strSuburb 
        strPhoneMobile 
        strEmail
    );

    # These fields are only relevant to particular levels of member lists
    my $level_relevant = {
    };

    if($Data->{'Permissions'} and $Data->{'Permissions'}{'MemberList'}) {
        @listfields = sort {
            $Data->{'Permissions'}{'MemberList'}{$a}[0] <=> $Data->{'Permissions'}{'MemberList'}{$b}[0] 
        } keys %{$Data->{'Permissions'}{'MemberList'}};
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
            and $Data->{'Permissions'}{'Member'}
            and $Data->{'Permissions'}{'Member'}{$f}
            and $Data->{'Permissions'}{'Member'}{$f} eq 'Hidden') {
                next;
        }
        push @showfields, $f;
    }

    return \@showfields;
}

sub getMemberListFieldOtherInfo {
    my ($Data, $field) = @_;

    my %IntegerFields;
    my %TextFields;

    my %CheckBoxFields=(
        intRecStatus=> $Defs::RECSTATUS_ACTIVE,
        intMSRecStatus=> 1,
        intPlayerPending=>1,
        intDeceased=> 1,
        intFinancialActive => 1,
        intLifeMember => 1,
        intMedicalConditions => 1,
        intAllergies => 1,
        intAllowMedicalTreatment => 1,
        intMailingList => 1,
        intFavNationalTeamMember => 1,
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
    if($Data->{'Permissions'}{'Member'})    {
        #Setup Check Box Fields
        for my $k (keys %CheckBoxFields)    {
            if($k=~/\./)    {
                delete $CheckBoxFields{$k} if !allowedAction($Data, 'mt_e');
            }
            else    {
                delete $CheckBoxFields{$k} if !allowedAction($Data, 'm_e');
                if ($k eq 'MCStatus' or $k eq 'MTStatus')    {
                    ## If permission set,allow club to reactivate an inactive member
                    delete $CheckBoxFields{$k} if ($Data->{'clientValues'}{'authLevel'} <= $Defs::LEVEL_CLUB and ! allowedAction($Data, 'm_ia'));
                }
                else    {
                    delete $CheckBoxFields{$k} if ((!$Data->{'Permissions'}{'Member'}{$k} or $Data->{'Permissions'}{'Member'}{$k} eq 'Hidden' or $Data->{'Permissions'}{'Member'}{$k} eq 'ReadOnly') and    $Data->{'clientValues'}{'authLevel'} < $Defs::LEVEL_ASSOC);
                }
            }
        }
        $CheckBoxFields{'TXNStatus'} = $Defs::TXN_PAID if(($Data->{'SystemConfig'}{'AllowProdTXNs'} or $Data->{'SystemConfig'}{'AllowTXNs'}) and allowedAction($Data, 'm_e') and $Data->{'clientValues'}{'authLevel'} >= $Defs::LEVEL_ASSOC);
    }
    $type='tick' if ($field eq 'TXNStatus');
    if( !allowedAction($Data, 'm_e') or $Data->{'SystemConfig'}{'LockMember'}) {
        for my $i (qw( intRecStatus intMSRecStatus MCStatus intActive MTStatus MTCompStatus)) {
            delete $CheckBoxFields{$i};
        }
    }
    for my $k (keys %CheckBoxFields) {
        if (not $k=~/\./) { 
            delete $CheckBoxFields{$k} if !allowedAction($Data, 'm_e');
            if($k eq 'intRecStatus') {

                delete $CheckBoxFields{$k} if ($Data->{'clientValues'}{'currentLevel'} < $Defs::LEVEL_ASSOC );
            }
            elsif ($k eq 'MCStatus' or $k eq 'MTStatus')     {
                delete $CheckBoxFields{$k} if ($Data->{'clientValues'}{'currentLevel'} >= $Defs::LEVEL_ASSOC or ($Data->{'clientValues'}{'authLevel'} == $Defs::LEVEL_CLUB and ! allowedAction($Data, 'm_ia')));
                #             delete $CheckBoxFields{$k} if ($Data->{'clientValues'}{'authLevel'} <= $Defs::LEVEL_CLUB and ! allowedAction($Data, 'm_ia'));
            }
            elsif($k eq 'TXNStatus') {
                delete $CheckBoxFields{$k} if((!$Data->{'SystemConfig'}{'AllowProdTXNs'} and !$Data->{'SystemConfig'}{'AllowTXNs'}) or !allowedAction($Data, 'm_e') or $Data->{'clientValues'}{'authLevel'}< $Defs::LEVEL_ASSOC);
            }
            else        {
                delete $CheckBoxFields{$k} if ((!$Data->{'Permissions'}{'Member'}{$k} or $Data->{'Permissions'}{'Member'}{$k} eq 'Hidden' or $Data->{'Permissions'}{'Member'}{$k} eq 'ReadOnly') and    $Data->{'clientValues'}{'authLevel'} <= $Defs::LEVEL_ASSOC);
            }
        }
    }

    for my $i (
        'Seasons.intMSRecStatus',
        'Seasons.intPlayerStatus',
        'Umpire.intActive', 
        'Player.intActive',
        'Coach.intActive',
        'Misc.intActive',
        'Volunteer.intActive',
        'Seasons.intCoachStatus',
        'Seasons.intUmpireStatus',
        'Seasons.intMiscStatus',
        'Seasons.intVolunteerStatus',
        'Seasons.intOther1Status',
        'Seasons.intOther2Status',
    )    {
        delete $CheckBoxFields{$i};
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

sub memberList_lookupVals {
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
        strAddress1 => 'tblMember',
        strAddress2 => 'tblMember',
        strSuburb => 'tblMember',
        strState => 'tblMember',
        strCountry => 'tblMember',
        strEmail => 'tblMember',
        strPostalCode => 'tblMember',
        strMobile => 'tblMember',
        intRecStatus => 'tblMember_Associations',
        tTimeStamp =>'tblMember',
    );
    my $tablename = $FieldTables{$field} || '';

    return $tablename ? "$tablename.$field" : $field;
}

sub bulkMemberRolloverUpdate {

    my(
        $Data, 
        $action, 
    ) = @_;
    my $body = '';
    my $seasonToID = param('Seasons_rolloverTo') || 0;
    my $rolloverClubID = param('rolloverClubID') || '';
    my $rolloverAssocID = param('rolloverAssocID') || '';
    my $rolloverIDs= param('rolloverIDs') || '';
    my $client = setClient($Data->{'clientValues'});
    my $count=0;
    my @MembersToRollover = split /\|/, $rolloverIDs;
    return $Data->{'lang'}->txt("No $Data->{'LevelNames'}{$Defs::LEVEL_MEMBER.'_P'} selected") if (! scalar @MembersToRollover);
    if (! $rolloverClubID)    {
        $count = Seasons::seasonRollover($Data, $Defs::LEVEL_MEMBER, \@MembersToRollover);
    }
    else    {
        $count = Seasons::seasonToClubRollover($Data, $rolloverClubID, \@MembersToRollover);
    }
    auditLog(-1, $Data, 'Bulk Rollover', 'Seasons');
    return $Data->{'lang'}->txt('[_1] [_2] have been rolled over', $count, $Data->{'LevelNames'}{$Defs::LEVEL_MEMBER.'_P'});
}

sub bulkMemberRollover {
    my(
        $Data, 
        $action, 
    ) = @_;

    my $body = '';
    my $seasonToID = param('Seasons_rolloverTo') || 0;
    my $seasonFromID = param('Seasons_rolloverFrom') || 0;
    my $rolloverClubID = param('rolloverClubID') || '';
    my $rolloverAssocID = param('rolloverAssocID') || '';
    my $client = setClient($Data->{'clientValues'});
    if(!$seasonToID or ($rolloverAssocID and ! $rolloverClubID))    {
        $body = rollover_choose_season($Data, $action, $client, $rolloverAssocID);
    }
    else    {
        my $realmID = $Data->{'Realm'};
        my $assocID = $Data->{'clientValues'}{'assocID'};
        my $clubID = $Data->{'clientValues'}{'clubID'} || $rolloverClubID || 0;
        my $clubJOIN = '';
        my $clubMSWHERE= '';
        my $clubClearedWhere= '';
        my $clubMSFROMWHERE= '';
        if ($clubID and $clubID != $Defs::INVALID_ID)    {

            $clubClearedWhere = qq[AND MCCO.intMemberID IS NULL ];
            $clubJOIN = qq[
            LEFT JOIN tblMember_ClubsClearedOut MCCO ON (
                MCCO.intClubID=$clubID
                    AND MCCO.intCurrentSeasonID = $seasonFromID
                    AND MCCO.intMemberID = tblMember.intMemberID
            )

            INNER JOIN tblMember_Clubs as MC ON (
                MC.intClubID=$clubID
                    AND MC.intStatus=1
                    AND MC.intMemberID=tblMember.intMemberID
            )
            ];
            $clubMSFROMWHERE= qq[
                AND SeasonsFrom.intClubID=$clubID
            ];
            $clubMSWHERE= qq[
                AND SeasonsTo.intClubID=$rolloverClubID
            ];
            $clubMSWHERE= qq[
                AND SeasonsTo.intClubID=$clubID
            ] if(!$rolloverClubID);
        }

        my $st = qq[
        SELECT
        DISTINCT
        tblMember.intMemberID,
        tblMember.strSurname,
        tblMember.strFirstname,
        DATE_FORMAT(tblMember.dtDOB,"%d/%m/%Y") AS dtDOB,
        tblMember.dtDOB AS dtDOB_RAW,
        tblMember.strNationalNum

        FROM tblMember 
        INNER JOIN tblMember_Associations ON (
            tblMember_Associations.intMemberID=tblMember.intMemberID
        )     

        INNER JOIN tblMember_Seasons_$realmID as SeasonsFrom ON (
            SeasonsFrom.intMemberID = tblMember.intMemberID
                AND SeasonsFrom.intSeasonID = ?
                AND SeasonsFrom.intAssocID = tblMember_Associations.intAssocID
                AND SeasonsFrom.intMSRecStatus = $Defs::RECSTATUS_ACTIVE
            $clubMSFROMWHERE
        )
        LEFT JOIN tblMember_Seasons_$realmID as SeasonsTo ON (
            SeasonsTo.intMemberID = tblMember.intMemberID
                AND SeasonsTo.intSeasonID = ?
                AND SeasonsTo.intAssocID = tblMember_Associations.intAssocID
                AND SeasonsTo.intMSRecStatus = $Defs::RECSTATUS_ACTIVE
            $clubMSWHERE
        )
        $clubJOIN
        WHERE tblMember.intStatus <> $Defs::RECSTATUS_DELETED
        $clubClearedWhere 
            AND tblMember.intRealmID = ?
            AND SeasonsTo.intMemberID IS NULL
            AND tblMember_Associations.intAssocID = ?
            AND tblMember.intDeRegister!=1
            AND tblMember_Associations.intRecStatus = $Defs::RECSTATUS_ACTIVE        
        ORDER BY strSurname, strFirstname
        ];
        my $q = $Data->{'db'}->prepare($st);
        $q->execute(
            $seasonFromID,
            $seasonToID,
            $realmID,
            $assocID,
        );
        my @rowdata    = ();
        while (my $dref = $q->fetchrow_hashref()) {
            my %row = ();
            for my $i (qw(intMemberID strSurname strFirstname dtDOB dtDOB_RAW strNationalNum))    {
                $row{$i} = $dref->{$i};
            }
            $row{'id'} = $dref->{'intMemberID'};
            push @rowdata, \%row;
        }

        my $memfieldlabels=FieldLabels::getFieldLabels($Data,$Defs::LEVEL_MEMBER);
        my @headers = (
            {
                type => 'RowCheckbox',
            },
            {
                name => $memfieldlabels->{'strNationalNum'} || $Data->{'lang'}->txt('National Num.'),
                field => 'strNationalNum',
            },
            {
                name => $memfieldlabels->{'strSurname'} || $Data->{'lang'}->txt('Family Name'),
                field => 'strSurname',
            },
            {
                name => $memfieldlabels->{'strFirstname'} || $Data->{'lang'}->txt('First Name'),
                field => 'strFirstname',
            },
            {
                name => $memfieldlabels->{'dtDOB'} || $Data->{'lang'}->txt('Date of Birth'),
                field => 'dtDOB',
            },

        );
        my $grid = showGrid(Data=>$Data, columns=>\@headers, rowdata=>\@rowdata, gridid=>'grid', width=>'99%', height=>700);
        my $Rollover_fields = '';
        my $txt_SeasonName= $Data->{'SystemConfig'}{'txtSeason'} || 'Season';
        my $txt_SeasonNames= $Data->{'SystemConfig'}{'txtSeasons'} || 'Seasons';

        my $lang = $Data->{'lang'};
        my $To_Season = $lang->txt("To $txt_SeasonName");
        my ($Seasons, undef) = Seasons::getSeasons($Data);

        my $type = $Data->{'clientValues'}{'currentLevel'};

        my $seasonname = $Seasons->{$seasonToID} || '';

        if ($type == $Defs::LEVEL_ASSOC) {
            my $club_records_label = $lang->txt("Include $Data->{'LevelNames'}{$Defs::LEVEL_CLUB} Records in Rollover");

            $Rollover_fields .= qq[
            <input type="checkbox" name="Seasons_includeClubs" CHECKED value="1"> 
            $club_records_label<br><br>
            ];
            if(! $Data->{'SystemConfig'}{'Seasons_activateMembers'}) {
                my $make_active_label = $lang->txt( "Make selected members Active in $Data->{'LevelNames'}{$Defs::LEVEL_ASSOC}    during Rollover");
                $Rollover_fields .= qq[
                <input type="checkbox" name="Seasons_activateMembers" value="1"> 
                $make_active_label<br><br>
                ];
            }
        }


        my $memberClubRollover= qq[<br>];
        $body = qq~
        <p>Please select the people you wish to register from the list below and click on the update button to commit your change.</p>
        <form action="$Data->{'target'}" method="POST">
        <b>$To_Season :</b> $seasonname
        $memberClubRollover
        <br>
        <br>
        $Rollover_fields<br>
        <script>
        function update_selected()    {
            var rows = grid_grid.getSelectedRows();
            var changedIDs = [];
            for(var i=0, len=rows.length; i < len; i++){
                changedIDs.push(dataView_grid.getItem(rows[i]).id);
            }
            jQuery('#rolloverIDs').val(changedIDs.join('|'));
        }
        </script>
        <input type="submit" value="Update" onclick = "update_selected();return true;" class="button proceed-button">
        <input type="hidden" name="rolloverIDs" value="" id = "rolloverIDs">
        <input type="hidden" name="a" value="M_LSROup">
        <input type="hidden" name="client" value="$client">
        <input type="hidden" name="rolloverClubID" value="$rolloverClubID">
        <input type="hidden" name="rolloverAssocID" value="$rolloverAssocID">
        <input type="hidden" name="Seasons_rolloverTo" value="$seasonToID">
        <input type="hidden" name="Seasons_rolloverFrom" value="$seasonFromID">
        </form>
        <br>
        <br>
        $grid
        ~;

    }
    my $title = $Data->{'lang'}->txt('Member Rollover');
    return ($body, $title);
}


sub rollover_choose_season {
    my(
        $Data, 
        $action, 
        $client,
        $rolloverAssocID
    ) = @_;

    $rolloverAssocID ||= 0;
    my $assocSeasons = Seasons::getDefaultAssocSeasons($Data);
    my ($Seasons, undef) = Seasons::getSeasons($Data);
    my $lang = $Data->{'lang'};

    my $type = $Data->{'clientValues'}{'currentLevel'};
    my $body = '';
    my $season_dropdown = drop_down('Seasons_rolloverTo',$Seasons,undef,0 || $assocSeasons->{'newRegoSeasonID'}, 1,0);
    my $season_dropdownFrom = drop_down('Seasons_rolloverFrom',$Seasons,undef,0 || $assocSeasons->{'currentSeasonID'}, 1,0);

    my $show_members_button_label = $lang->txt( "Show $Data->{'LevelNames'}{$Defs::LEVEL_MEMBER.'_P'} for " .    'Rollover');
    my $SeasonsText = $lang->txt('ROLLOVER_INSTRUCTIONS', $show_members_button_label);
    my $Rollover_fields = '';

    if ($type == $Defs::LEVEL_ASSOC) {
        my $club_records_label = $lang->txt("Include $Data->{'LevelNames'}{$Defs::LEVEL_CLUB} Records in Rollover");

        $Rollover_fields .= qq[
        <input type="checkbox" name="Seasons_includeClubs" CHECKED value="1"> 
        $club_records_label<br><br>
        ];
        if(! $Data->{'SystemConfig'}{'Seasons_activateMembers'}) {
            my $make_active_label = $lang->txt( "Make selected members Active in $Data->{'LevelNames'}{$Defs::LEVEL_ASSOC}    during Rollover");
            $Rollover_fields .= qq[
            <input type="checkbox" name="Seasons_activateMembers" value="1"> 
            $make_active_label<br><br>
            ];
        }
    }

    my $rolloverClubID=0;
    my $rolloverStep=1;
    my $memberClubTransfer = '';
    if ($Data->{'SystemConfig'}{'allowMS_to_Club_rollover'}) {
        if (! $rolloverAssocID) {
            $memberClubTransfer = qq[<b>OR<br><br>Select $Data->{'LevelNames'}{$Defs::LEVEL_ASSOC} to push Members to:</b>&nbsp;]. getRolloverToAssocList($Data) . qq[<br>];
            $rolloverStep=1;
        }
        elsif ($rolloverAssocID and ! $rolloverClubID)    {
            $memberClubTransfer = qq[<p>Select the $Data->{'LevelNames'}{$Defs::LEVEL_CLUB} you wish to push the Members to.</p>];
            $memberClubTransfer .= qq[<br>] . getRolloverToClubList($Data, $rolloverAssocID) . qq[<br><br>];
            $memberClubTransfer .= qq[<input type="hidden" name="rolloverAssocID" value="$rolloverAssocID">];
            #         $rollover=1;
            $rolloverStep=2;
        }
    }


    my $txt_SeasonName= $Data->{'SystemConfig'}{'txtSeason'} || 'Season';
    my $txt_SeasonNames= $Data->{'SystemConfig'}{'txtSeasons'} || 'Seasons';

    my $To_Season = $lang->txt("To $txt_SeasonName");
    my $From_Season = $lang->txt("From $txt_SeasonName");

    $body = qq[
    <form action="$Data->{'target'}" method="POST">
    $SeasonsText
    <b>$From_Season :</b> $season_dropdownFrom
    <b>$To_Season :</b> $season_dropdown
    <br>
    $Rollover_fields<br>
    $memberClubTransfer
    <input type="submit" value="$show_members_button_label" class="button proceed-button">
    <input type="hidden" name="a" value="M_LSRO">
    <input type="hidden" name="client" value="$client">
    </form>
    ];
    return $body;
}

sub listMemberSeasons     {
    my ($Data, $memberID)=@_;
    my $assocID=$Data->{'clientValues'}{'assocID'} || 0; #Current Association
    my $client=setClient($Data->{'clientValues'});
    my $MStablename = "tblMember_Seasons_$Data->{'Realm'}";
    my $assocSeasons = Seasons::getDefaultAssocSeasons($Data);
    return '' if ! $assocSeasons->{'allowSeasons'};
    my $txt_Name= $Data->{'SystemConfig'}{'txtSeason'} || 'Season';
    my $txt_Names= $Data->{'SystemConfig'}{'txtSeasons'} || 'Seasons';
    my $txt_AgeGroupName= $Data->{'SystemConfig'}{'txtAgeGroup'} || 'Age Group';
    my $txt_AgeGroupNames= $Data->{'SystemConfig'}{'txtAgeGroups'} || 'Age Groups';

    ### set up all the text labels for translation ###
    my $lang = $Data->{'lang'};
    my %textLabels = ( #in lexicon
        'addSeasonClubRecord' => $lang->txt("Add $txt_Name $Data->{'LevelNames'}{$Defs::LEVEL_CLUB} Record"),
        'addSeasonRecord' => $lang->txt("Add $txt_Name Record"),
        'ageGroup' => $lang->txt($txt_AgeGroupName),
        'ageGroups' => $lang->txt($txt_AgeGroupNames),
        'assocName' => $lang->txt("$Data->{'LevelNames'}{$Defs::LEVEL_ASSOC} Name"),
        'assocSeasonMemberPackage' => $lang->txt("$Data->{'LevelNames'}{$Defs::LEVEL_ASSOC} $txt_Name Member Package"), 
        'clubName' => $lang->txt("$Data->{'LevelNames'}{$Defs::LEVEL_CLUB} Name"),
        'clubSeasonMemberPackage' => $lang->txt("$Data->{'LevelNames'}{$Defs::LEVEL_CLUB} $txt_Name Member Package"), 
        'coach' => $lang->txt('Coach?'),
        'coachInAssoc' => $lang->txt("Coach in<br>$Data->{'LevelNames'}{$Defs::LEVEL_ASSOC}?"),
        'coachInClub' => $lang->txt("Coach in<br>$Data->{'LevelNames'}{$Defs::LEVEL_CLUB}?"),
        'matchOfficial' => $lang->txt('Match Official?'),
        'matchOfficialInAssoc' => $lang->txt("Match Official in<br>$Data->{'LevelNames'}{$Defs::LEVEL_ASSOC}?"),
        'matchOfficialInClub' => $lang->txt("Match Official in<br>$Data->{'LevelNames'}{$Defs::LEVEL_CLUB}?"), 
        'misc' => $lang->txt('Misc?'),
        'miscInAssoc' => $lang->txt("Misc in<br>$Data->{'LevelNames'}{$Defs::LEVEL_ASSOC}?"),
        'miscInClub' => $lang->txt("Misc in<br>$Data->{'LevelNames'}{$Defs::LEVEL_CLUB}?"),
        'volunteer' => $lang->txt('Volunteer?'),
        'volunteerInAssoc' => $lang->txt("Volunteer in<br>$Data->{'LevelNames'}{$Defs::LEVEL_ASSOC}?"),
        'volunteerInClub' => $lang->txt("Volunteer in<br>$Data->{'LevelNames'}{$Defs::LEVEL_CLUB}?"),
        'player' => $lang->txt('Player?'),
        'playerAgeGroup' => $lang->txt("Player $txt_AgeGroupName"), 
        'playerInAssoc' => $lang->txt("Player in<br>$Data->{'LevelNames'}{$Defs::LEVEL_ASSOC}?"),
        'playerInClub' => $lang->txt("Player in<br>$Data->{'LevelNames'}{$Defs::LEVEL_CLUB}?"),
        'season' => $lang->txt($txt_Name),
        'seasonMemberPackage' => $lang->txt("$txt_Name Member Package"),
        'seasons' => $lang->txt($txt_Names),
        seasonsOther1 => '',
        seasonsOther1InAssoc => '',
        seasonsOther1InClub => '',
        seasonsOther2 => '',
        seasonsOther2InAssoc => '',
        seasonsOther2InClub => '',
    );

    if ($Data->{'SystemConfig'}{'Seasons_Other1'}) {
        $textLabels{'seasonsOther1'} = $lang->txt("$Data->{'SystemConfig'}{'Seasons_Other1'}?");
        $textLabels{'seasonsOther1InAssoc'} = $lang->txt("$Data->{'SystemConfig'}{'Seasons_Other1'} in <br>$Data->{'LevelNames'}{$Defs::LEVEL_ASSOC}?");
        $textLabels{'seasonsOther1InClub'} = $lang->txt("$Data->{'SystemConfig'}{'Seasons_Other1'} in <br>$Data->{'LevelNames'}{$Defs::LEVEL_CLUB}?");
    };

    if ($Data->{'SystemConfig'}{'Seasons_Other2'}) {
        $textLabels{'seasonsOther2'} = $lang->txt("$Data->{'SystemConfig'}{'Seasons_Other2'}?");
        $textLabels{'seasonsOther2InAssoc'} = $lang->txt("$Data->{'SystemConfig'}{'Seasons_Other2'} in <br>$Data->{'LevelNames'}{$Defs::LEVEL_ASSOC}?");
        $textLabels{'seasonsOther2InClub'} = $lang->txt("$Data->{'SystemConfig'}{'Seasons_Other2'} in <br>$Data->{'LevelNames'}{$Defs::LEVEL_CLUB}?");
    };

    my $st=qq[
    SELECT 
    MS.intClubID,
    MS.intMemberSeasonID,
    MS.intPlayerStatus,
    MS.intCoachStatus,
    MS.intUmpireStatus,
    MS.intMiscStatus,
    MS.intVolunteerStatus,
    MS.intOther1Status,
    MS.intOther2Status,
    S.strSeasonName, 
    IF(C.intRecStatus=-1, CONCAT(C.strName, " (Deleted)"), C.strName) as ClubName, 
    G.strAgeGroupDesc, 
    MP.strPackageName, 
    A.strName as AssocName, 
    S.intAssocID as SeasonAssocID, 
    C.intRecStatus
    FROM $MStablename as MS
    INNER JOIN tblSeasons as S ON (S.intSeasonID = MS.intSeasonID)
    INNER JOIN tblAssoc as A ON (A.intAssocID = MS.intAssocID)
    LEFT JOIN tblClub as C ON (C.intClubID = MS.intClubID)
    LEFT JOIN tblAgeGroups as G ON (G.intAgeGroupID = MS.intPlayerAgeGroupID)
    LEFT JOIN tblMemberPackages as MP ON (MP.intMemberPackagesID = MS.intSeasonMemberPackageID)
    WHERE intMemberID = ?
        AND MS.intMSRecStatus = 1
    ORDER BY 
    intSeasonOrder, 
    strSeasonName, 
    AssocName, 
    ClubName
    ];
    my $memberObj = getInstanceOf($Data, 'member');
    my $deRegisteredMember =    $memberObj->{'DBData'}{'intDeRegister'};
    my $query = $Data->{'db'}->prepare($st);
    $query->execute(
        $memberID
    );

    my @headers_ALL = (
        {
            name => $textLabels{'season'},
            field => 'strSeasonName',
        },
        {
            name => $textLabels{'assocName'},
            field => 'AssocName',
        },
        {
            name => $textLabels{'clubName'},
            field => 'ClubName',
        },
        {
            name => $textLabels{'seasonMemberPackage'},
            field => 'strPackageName',
        },
        {
            name => $textLabels{'ageGroup'},
            field => 'strAgeGroupDesc',
        },
        {
            name => $textLabels{'player'},
            field => 'intPlayerStatus',
            type => 'tick',
        },
        {
            name => $textLabels{'coach'},
            field => 'intCoachStatus',
            type => 'tick',
        },
        {
            name => $textLabels{'matchOfficial'},
            field => 'intUmpireStatus',
            type => 'tick',
        },
        {
            name => $textLabels{'misc'},
            field => 'intMiscStatus',
            type => 'tick',
        },
        {
            name => $textLabels{'volunteer'},
            field => 'intVolunteerStatus',
            type => 'tick',
        },
        {
            name => $textLabels{'seasonsOther1'},
            field => 'intOther1Status',
            hide => !$Data->{'SystemConfig'}{'Seasons_Other1'},
            type => 'tick',
        },
        {
            name => $textLabels{'seasonsOther2'},
            field => 'intOther2Status',
            hide => !$Data->{'SystemConfig'}{'Seasons_Other2'},
            type => 'tick',
        },
    );

    my @headers_Assoc = (
        {
            type => 'Selector',
            field => 'SelectLink',
        },
        {
            name => $textLabels{'season'},
            field => 'strSeasonName',
        },
        {
            name => $textLabels{'assocName'},
            field => 'AssocName',
        },
        {
            name => $textLabels{'assocSeasonMemberPackage'},
            field => 'strPackageName',
        },
        {
            name => $textLabels{'ageGroup'},
            field => 'strAgeGroupDesc',
        },
        {
            name => $textLabels{'playerInAssoc'},
            field => 'intPlayerStatus',
            type => 'tick',
        },
        {
            name => $textLabels{'coachInAssoc'},
            field => 'intCoachStatus',
            type => 'tick',
        },
        {
            name => $textLabels{'matchOfficialInAssoc'},
            field => 'intUmpireStatus',
            type => 'tick',
        },
        {
            name => $textLabels{'miscInAssoc'},
            field => 'intMiscStatus',
            type => 'tick',
        },
        {
            name => $textLabels{'volunteerInAssoc'},
            field => 'intVolunteerStatus',
            type => 'tick',
        },
        {
            name => $textLabels{'seasonsOther1InAssoc'},
            field => 'intOther1Status',
            type => 'tick',
            hide => !$Data->{'SystemConfig'}{'Seasons_Other1'},
        },
        {
            name => $textLabels{'seasonsOther2InAssoc'},
            field => 'intOther2Status',
            hide => !$Data->{'SystemConfig'}{'Seasons_Other2'},
            type => 'tick',
        },
    );

    my @headers_Club = (
        {
            type => 'Selector',
            field => 'SelectLink',
        },
        {
            name => $textLabels{'season'},
            field => 'strSeasonName',
        },
        {
            name => $textLabels{'clubName'},
            field => 'ClubName',
        },
        {
            name => $textLabels{'clubSeasonMemberPackage'},
            field => 'strPackageName',
        },
        {
            name => $textLabels{'ageGroup'},
            field => 'strAgeGroupDesc',
        },
        {
            name => $textLabels{'playerInClub'},
            field => 'intPlayerStatus',
            type => 'tick',
        },
        {
            name => $textLabels{'coachInClub'},
            field => 'intCoachStatus',
            type => 'tick',
        },
        {
            name => $textLabels{'matchOfficialInClub'},
            field => 'intUmpireStatus',
            type => 'tick',
        },
        {
            name => $textLabels{'miscInClub'},
            field => 'intMiscStatus',
            type => 'tick',
        },
        {
            name => $textLabels{'volunteerInClub'},
            field => 'intVolunteerStatus',
            type => 'tick',
        },
        {
            name => $textLabels{'seasonsOther1InClub'},
            field => 'intOther1Status',
            hide => !$Data->{'SystemConfig'}{'Seasons_Other1'},
            type => 'tick',
        },
        {
            name => $textLabels{'seasonsOther2InClub'},
            field => 'intOther2Status',
            hide => !$Data->{'SystemConfig'}{'Seasons_Other2'},
            type => 'tick',
        },
    );

    my $assocaddLink = (
        $Data->{'clientValues'}{'authLevel'} >= $Defs::LEVEL_ASSOC 
            and !$Data->{'ReadOnlyLogin'})
    ? qq[<a href="$Data->{'target'}?client=$client&amp;a=SN_MSviewADD">$textLabels{'addSeasonRecord'}</a>] 
    : '';

    my $clubaddLink = $Data->{'clientValues'}{'authLevel'}>=$Defs::LEVEL_CLUB 
    ? qq[<a href="$Data->{'target'}?client=$client&amp;a=SN_MSviewCADD">$textLabels{'addSeasonClubRecord'}</a>] 
    : '';
    $clubaddLink = '' if $Data->{'ReadOnlyLogin'};
    $clubaddLink = '' if ($Data->{'clientValues'}{'authLevel'} == $Defs::LEVEL_CLUB and $Data->{'SystemConfig'}{'Club_MemberEditOnly'});

    if(
        $Data->{'SystemConfig'}{'memberReReg_notInactive'}
            and (
            ! $Data->{'MemberActiveInClub'}
                or $Data->{'MemberClrdOut_ofClub'}
        )
    )
    {
        $clubaddLink = '';
    }

    # LockSeasons and LockSeasonsCRL are workign together: If LockSeasons is 0 but LockSeasonsCRL is 1 then adding season is locked for levels below national.
    $assocaddLink = '' if ($Data->{'SystemConfig'}{'LockSeasons'} or ($Data->{'SystemConfig'}{'LockSeasonsCRL'} and $Data->{'clientValues'}{'authLevel'} < $Defs::LEVEL_NATIONAL ));
    $clubaddLink = '' if ($Data->{'SystemConfig'}{'LockSeasons'} or ($Data->{'SystemConfig'}{'LockSeasonsCRL'} and $Data->{'clientValues'}{'authLevel'} < $Defs::LEVEL_NATIONAL ));
    $clubaddLink = '' if($Data->{'SystemConfig'}{'AssocConfig'}{'LockdownSeasonAddClub'});
    $assocaddLink = '' if($deRegisteredMember);
    $clubaddLink = '' if($deRegisteredMember);
    my $assocCount=0;
    my $clubCount=0;
    my $count=0;
    my $currentAssoc='';
    my @rowdata = ();
    my @rowdata_Assoc = ();
    my @rowdata_Club = ();
    my @rowdata_all = ();
    while(my $dref=$query->fetchrow_hashref())            {
        $dref->{'AssocName'} = '' if $currentAssoc eq $dref->{'AssocName'} and $dref->{'intClubID'}>0;
        $currentAssoc=$dref->{'AssocName'};

        my %row = (
            id => $dref->{'intMemberSeasonID'} || next,
            SelectLink => "$Data->{'target'}?client=$client&amp;a=SN_MSview&amp;msID=$dref->{intMemberSeasonID}",

        );
        for my $f (qw(
            strSeasonName 
            AssocName 
            ClubName 
            strPackageName 
            strAgeGroupDesc 
            intPlayerStatus 
            intCoachStatus 
            intUmpireStatus 
            intMiscStatus 
            intVolunteerStatus 
            intOther1Status 
            intOther2Status 
            ))    {
            $row{$f} = $dref->{$f};
        }

        push @rowdata, \%row;
        push @rowdata_Assoc, \%row if (! $dref->{'intClubID'});
        push @rowdata_Club, \%row if ($dref->{'intClubID'});
        push @rowdata, \%row;
        next if ($Data->{'SystemConfig'}{'Seasons_SummaryNationalOnly'} and $dref->{SeasonAssocID});
        next if ($Data->{'SystemConfig'}{'Seasons_DefaultID'} == $dref->{intSeasonID} and $Data->{'SystemConfig'}{'Seasons_SummaryNotDefault'}); 
        push @rowdata_all, \%row;

    }
    my $assocBody =     showGrid(
        Data => $Data,
        columns => \@headers_Assoc,
        rowdata => \@rowdata_Assoc,
        gridid => 'grid_assoc',
        width => '99%',
        simple => 1,
    );

    my $clubBody =     showGrid(
        Data => $Data,
        columns => \@headers_Club,
        rowdata => \@rowdata_Club,
        gridid => 'grid_club',
        width => '99%',
        simple => 1,
    );

    my $AllBody =     showGrid(
        Data => $Data,
        columns => \@headers_ALL,
        rowdata => \@rowdata_all,
        gridid => 'grid_all',
        width => '99%',
        simple => 1,
    );


    $assocBody .= $assocaddLink;
    $clubBody .= $clubaddLink;

    my @vals = ();
    push @vals, qq[ <div id="assocseason_dat"> $assocBody </div>] ;
    push @vals, qq[ <div id="clubseason_dat"> $clubBody</div>] ;
    push @vals, qq[ <div id="allseason_dat"> $AllBody</div>] ;

    return (\@vals,    join('',@vals));
}

sub getRolloverToAssocList    {

    my ($Data) = @_;

    my $st = qq[
    SELECT
    intAssocID,
    strName
    FROM
    tblAssoc
    WHERE
    intRealmID=?
        AND intAssocTypeID IN(?)
        AND intRecStatus=1
    ORDER BY
    strName
    ];
    my $query = $Data->{'db'}->prepare($st);
    $query->execute($Data->{'Realm'}, $Data->{'SystemConfig'}{'MS_to_Club_rollover_AssocTypeID'} || 0);

    my $body = qq[
    <select name="rolloverAssocID" class="chzn-select">
    <option value="">--Select $Data->{'LevelNames'}{$Defs::LEVEL_ASSOC} --</option>
    ];

    while (my $dref= $query->fetchrow_hashref())    {
        $body .= qq[<option value="$dref->{intAssocID}">$dref->{strName}</option>];
    }
    $body .= qq[</select>];

    return $body;
}
sub getRolloverToClubList {

    my ($Data, $rolloverAssocID) = @_;

    my $st = qq[
    SELECT
    C.intClubID,
    C.strName
    FROM
    tblAssoc_Clubs as AC
    INNER JOIN tblClub as C ON (
        C.intClubID=AC.intClubID
    )
    WHERE
    AC.intAssocID=?
        AND AC.intRecStatus=1
        AND C.intRecStatus=1
    ORDER BY
    strName
    ];
    my $query = $Data->{'db'}->prepare($st);
    $query->execute($rolloverAssocID);

    my $body = qq[
    <select name="rolloverClubID" class="chzn-select">
    <option value="">--Select $Data->{'LevelNames'}{$Defs::LEVEL_CLUB} --</option>
    ];

    while (my $dref= $query->fetchrow_hashref())    {
        $body .= qq[<option value="$dref->{intClubID}">$dref->{strName}</option>];
    }
    $body .= qq[</select>];

    return $body;
}

sub getRolloverClub {

    my ($Data, $rolloverClubID) = @_;

    return '' if ! $rolloverClubID;

    my $st = qq[
    SELECT
    A.intAssocID,
    A.strName as AssocName,
    C.intClubID,
    C.strName as ClubName,
    A.intNewRegoSeasonID
    FROM
    tblClub as C
    INNER JOIN tblAssoc_Clubs as AC ON (
        AC.intClubID = C.intClubID
    )
    INNER JOIN tblAssoc as A ON (
        A.intAssocID = AC.intAssocID
    )
    WHERE
    C.intRecStatus=1
        AND AC.intRecStatus=1
        AND A.intAssocID<>?
        AND C.intClubID=?
    LIMIT 1
    ];
    my $query = $Data->{'db'}->prepare($st);
    $query->execute($Data->{'clientValues'}{'assocID'} || 0, $rolloverClubID || 0);

    my ($assocID, $assocName, $clubID, $clubName, $toSeasonID) = $query->fetchrow_array();

    return ($assocID || 0, $assocName || '', $clubID ||0, $clubName || '', $toSeasonID || 0);

}

1;
# vim: set et sw=4 ts=4:
