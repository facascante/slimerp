#!/usr/bin/perl

#
# $Header: svn://svn/SWM/trunk/web/ajax/aj_membergrid_update.cgi 11399 2014-04-28 16:14:39Z sliu $
#

use strict;
use warnings;
use lib "..",".","../..";
use CGI qw(param);
use Defs;
use Reg_common;
use Utils;
use DBUtils;
use JSON;
use Transactions;
use SystemConfig;
use ConfigOptions;
use PlayerAttributes;
use TemplateEmail;
use Log;
use Data::Dumper;

main();    

sub main    {
    my $cgi = new CGI();
    my $params = $cgi->Vars();
    DEBUG "aj_membergrid_update.cgi:", Dumper($params);
    # GET INFO FROM URL
    my $client = param('client') || '';
    my $colfield = param('col') || '';
    my $value = param('val') || 0;
    my $extraid = param('extraid') || 0;
    my $action = param('a') || '';
    my $id = param('id') || '';
    my $memberID = param('key') || '';
    $value = 1 if $value eq 'checked';
    my %Data=();
    my $target='main.cgi';
    $Data{'target'}=$target;
    my %clientValues = getClient($client);
    $Data{'clientValues'} = \%clientValues;
    my $db=allowedTo(\%Data);
    $Data{'db'} = $db;
    ($Data{'Realm'}, $Data{'RealmSubType'})=getRealm(\%Data);
    getDBConfig(\%Data);
    $Data{'SystemConfig'}=getSystemConfig(\%Data);
    $Data{'LocalConfig'}=getLocalConfig(\%Data);


    my $assocID=$Data{'clientValues'}{'assocID'} || '';
    $assocID ='' if $assocID == $Defs::INVALID_ID;
    my $level=$Data{'clientValues'}{'currentLevel'};
    return if !$assocID and $level <=$Defs::LEVEL_ASSOC;
    my $valid_mID = validate_MemberAccess(\%Data, $memberID);
    my $done = 0;
    if($db and $valid_mID)    {
        elsif ($colfield eq 'intPlayerPending') {
            $done = update_pending_status(\%Data, $memberID, $value);
        }
        else {
            my @updates = ([$memberID, $value,0]);
            if(
                $colfield eq 'intRecStatus'
                    or $colfield eq 'MCStatus'
                    or $colfield eq 'MTStatus'
            )   {
                update_Statuses(\%Data, $memberID, $value, $Defs::LEVEL_MEMBER, $colfield );
            }
            elsif($colfield eq 'TXNStatus') {
                update_paidStatuses(\%Data, \@updates);
            }
            elsif(  
                $colfield eq'intPlayer'     
                    or $colfield eq'intCoach'   
                    or $colfield eq'intUmpire' 
                    or $colfield eq'intOfficial' 
                    or $colfield eq'intMisc' 
                    or $colfield eq'intVolunteer' 
                    or $colfield eq'intDeceased' 
                    or $colfield eq'intFinancialActive' 
                    or $colfield eq'intLifeMember' 
                    or $colfield eq'intMedicalConditions' 
                    or $colfield eq'intAllergies' 
                    or $colfield eq'intAllowMedicalTreatment' 
                    or $colfield eq'intMailingList' 
                    or $colfield eq'intFavNationalTeamMember' 
                    or $colfield eq'intConsentSignatureSighted')    {
                update_membercheckboxes(\%Data, \@updates,$colfield);
            }
            elsif( 
                $colfield =~/Player\./ 
                    or $colfield=~/Coach\./ 
                    or $colfield=~/Umpire\./)   {
                update_membertypecheckboxes(\%Data, \@updates,$colfield);
            }
            elsif ($colfield =~ /Tag/) {
                update_tags(\%Data, \@updates);
            }
            elsif ($colfield =~ /intCustomBool/) {
                update_custom_bool_fields(\%Data, \@updates, $colfield);
            }
            elsif ($colfield =~ /intNatCustomBool/) {
                update_national_custom_bool_fields(\%Data, \@updates, $colfield);
            }
            update_seasonStatus(\%Data, $extraid, \@updates, $colfield);
            $done = 1;
        }            
    }

    my $json = to_json({
            complete => $done || 0,
            results => 1,
        });
    print "Content-type: application/x-javascript\n\n$json";
}
sub update_national_custom_bool_fields {
    my ($Data, $updates, $field) = @_;
    my $db = $Data->{'db'};
    my $st = qq[
    UPDATE
    tblMember
    SET
    $field = ?
    WHERE
    intMemberID = ?
    ];
    my $q = $db->prepare($st);
    for my $row (@{$updates}) {
        $q->execute($row->[1], $row->[0]);
    }
}


sub update_custom_bool_fields {
    my ($Data, $updates, $field) = @_;
    my $db = $Data->{'db'};
    my $assocID=$Data->{'clientValues'}{'assocID'} || '';
    my $st = qq[
    UPDATE
    tblMember_Associations
    SET
    $field = ?
    WHERE
    intAssocID = ?
        AND intMemberID = ?
    ];
    my $q = $db->prepare($st);
    for my $row (@{$updates}) {
        $q->execute($row->[1], $assocID, $row->[0]);
    }
}

## UPDATE TAGS ##
## Created by TC - 7/9/2007
## Last Updated by TC - 10/9/2007
##
## Updates the tags that have been selected/unselected as part of the
## bulk tag changing option. If a tag has not previously been selected
## a new record will be inserted otherwise the existing record will
## simply be updated.
##
## IN
## $Data - Contains generic data
## $updates - Contains lsit of updates
##
## OUT
## Nil

sub update_tags {
    my ($Data, $updates)=@_;
    my $db = $Data->{'db'};
    my $assocID=$Data->{'clientValues'}{'assocID'} || '';
    my $realmID=$Data->{'Realm'} || 0;
    my $st_update = qq[
    UPDATE tblMemberTags
    SET intRecStatus=?
    WHERE intTagID=?
        AND intMemberID=?
        AND intAssocID=$assocID
        AND intRealmID=$realmID
    ];
    my $q_update = $db->prepare($st_update);
    my $st_insert = qq[
    INSERT INTO tblMemberTags
    (intAssocID, intRealmID, intTagID, intMemberID, tTimeStamp, intRecStatus)
    VALUES ($assocID,$realmID,?,?,now(),$Defs::RECSTATUS_ACTIVE)
    ];
    my $q_insert = $db->prepare($st_insert);
    for my $row (@{$updates}) {
        my $mID = $row->[0];
        my $oldVal = $row->[1];
        my ($newVal,$recstatus) = split /\|/,$row->[2];
        if ($oldVal == 1 && $newVal != 0 && $recstatus == $Defs::RECSTATUS_DELETED) {
            $q_update->execute($Defs::RECSTATUS_ACTIVE,$newVal,$mID);
        }
        elsif ($oldVal == 1 && $newVal && $recstatus == 0) {
            $q_insert->execute($newVal,$mID);
        }
        elsif ($oldVal == 0 && $newVal && $recstatus == $Defs::RECSTATUS_ACTIVE) {
            $q_update->execute($Defs::RECSTATUS_DELETED,$newVal,$mID);
        }
    }
}


sub update_Statuses {
    my($Data, $ID, $value, $level, $field)=@_;

    my $assocID=$Data->{'clientValues'}{'assocID'} || '';
    $assocID ='' if $assocID == $Defs::INVALID_ID;

    my $clubID=$Data->{'clientValues'}{'clubID'} || '';
    $clubID ='' if $clubID == $Defs::INVALID_ID;

    my $currentlevel=$Data->{'clientValues'}{'currentLevel'};
    return if !$assocID and $currentlevel <=$Defs::LEVEL_ASSOC;
    my($st, $st_dt, $st_ct, $st_m)=('','','', '');
    if($level==$Defs::LEVEL_MEMBER)    {
        $st_m=qq[
        UPDATE tblMember SET intStatus=1
        WHERE intMemberID=?
            AND intStatus =0
        LIMIT 1
        ];
        $st=qq[
        UPDATE tblMember_Associations SET intRecStatus=?
        WHERE intMemberID=?
            AND intAssocID=$assocID
            AND intRecStatus <> $Defs::RECSTATUS_DELETED
        ];
        $st_dt=qq[
        UPDATE tblMember_Associations SET intRecStatus=?
        WHERE intMemberID=?
            AND intAssocID=$assocID
            AND intRecStatus <> $Defs::RECSTATUS_DELETED
        ];
        if ($clubID  and (! $Data->{'SystemConfig'}{'AllowClubsAssocStatus'} or $field eq 'MCStatus'))    {
            $st=qq[
            UPDATE tblMember_Clubs SET intStatus=?
            WHERE intMemberID=?
                AND intClubID=$clubID
                AND intStatus <> $Defs::RECSTATUS_DELETED
            ];
            $st_dt='';
        }
        $Data->{'cache'} ||= new MCache();
        if ($Data->{'cache'}){
            $Data->{'cache'}->delete( 'swm', "MemberObj-$ID-$assocID" ) ;
        }
    }
    elsif($level==$Defs::LEVEL_ASSOC) {
        $st=qq[ 
        UPDATE tblAssoc SET intRecStatus=? 
        WHERE intAssocID=?
            AND intRecStatus <> $Defs::RECSTATUS_DELETED
        ];
    }
    elsif($level==$Defs::LEVEL_CLUB) {
        $st=qq[ 
        UPDATE tblAssoc_Clubs SET intRecStatus=?
        WHERE intClubID=?
            AND intAssocID=$assocID
            AND intRecStatus <> $Defs::RECSTATUS_DELETED
        ];
    }
    return '' if !$st;
    my $q=$Data->{'db'}->prepare($st);
    my $q_ct=$Data->{'db'}->prepare($st_ct);
    my $q_dt=$Data->{'db'}->prepare($st_dt);
    my $q_m=$Data->{'db'}->prepare($st_m);

    my $id=$ID || return '';
    my $newstatus = ($value and $value == 1) ? $Defs::RECSTATUS_ACTIVE : $Defs::RECSTATUS_INACTIVE;
    if ($level == $Defs::LEVEL_MEMBER)    {
        $q_m->execute($id) if ($newstatus==1); 
    }
    if($newstatus == $Defs::RECSTATUS_ACTIVE and $st_dt)    {
        $q_dt->execute($newstatus, $id); 
    }
    else    { 
        if ($newstatus  == $Defs::RECSTATUS_ACTIVE and $level==$Defs::LEVEL_MEMBER and $clubID and ! $Data->{'SystemConfig'}{'AllowClubsAssocStatus'})    {
            $st .= qq[
            ORDER BY intPermit
            LIMIT 1
            ] if $st !~ /ORDER BY/;
            $q=$Data->{'db'}->prepare($st);
        }
        $q->execute($newstatus, $id); 
    }


    ## IF THE LEVEL IS BELOW ASSOCIATION, STATUS IS BEING CHANGED TO ACTIVE, SYSTEM CONFIG IS SET TO
    ## ALLOWCONTRACTSDETAILS AND THE LEVEL IS EQUAL TO MEMBER THEN SET CONTRACT DEFAULTS TO MEMBER
    if ($currentlevel<$Defs::LEVEL_ASSOC && $newstatus==$Defs::RECSTATUS_ACTIVE && 
        $Data->{'SystemConfig'}{'AllowContractDetails'} && $level == $Defs::LEVEL_MEMBER) { 
        my ($st_contract,$st_primaryclub)=('','');
        ## GET EXISTING CONTRACT YEAR FOR MEMBER
        ## GET EXISTING PRIMARY CLUBS
        my $statement = qq[
        SELECT intPrimaryClub
        FROM tblMember_Clubs
        WHERE intMemberID=?
            AND intPrimaryClub=1
            AND intStatus=$Defs::RECSTATUS_ACTIVE
        ];
        my $query=$Data->{'db'}->prepare($statement);
        $query->execute($id);
        my $ynPrimaryClub=0;
        while(my ($primary_club) = $query->fetchrow_array()) {
            $ynPrimaryClub++;
        }
        ## IF THERE ARE NO PRIMARY CLUBS SET MAKE THIS CLUB THE PRIMARY CLUB
        if ($ynPrimaryClub < 1) { $st_primaryclub=qq[intPrimaryClub=1];}

        ## GET THE AGE OF THE PLAYER AS OF THE 31/12 OF THE CURRENT YEAR
        my ($year,$month,$day) = Today();

        my $age_date = qq[$year-12-31];
        $statement = qq[
        SELECT DATE_FORMAT(FROM_DAYS(TO_DAYS("$age_date")-TO_DAYS(dtDOB)),'%Y')+0 AS AGE
        FROM tblMember
        WHERE intMemberID= ?
        ];
        $query=$Data->{'db'}->prepare($statement);
        $query->execute($id);
        my $age = $query->fetchrow_array();
        ## GET A LIST OF GRADES LESS THAN THE PLAYERS AGE AT THE 31/12 THEN SORT DESC AND LIMIT TO ONE
        ## IN ORDER TO GET THE GRADE THEY BELONG TO
        $statement = qq[
        SELECT intGradeID
        FROM tblClubGrades
        WHERE intAge <= ?
        ORDER BY intAge DESC
        LIMIT 1
        ];
        $query=$Data->{'db'}->prepare($statement);
        $query->execute($age);
        my $st_gradeID='';
        my ($intGradeID) = $query->fetchrow_array();
        $st_gradeID = ($intGradeID) ? qq[intGradeID=$intGradeID] : ''; ## GET THE GRADE
        ## UPDATE CONTRACT YEAR AND PRIMARY CLUB AS REQUIRED
        if ($st_primaryclub || $st_contract || $st_gradeID) {
            my $coma1 = ($st_primaryclub && $st_contract) ? "," : '';
            my $coma2 = (($st_primaryclub && $st_gradeID) || ($st_contract && $st_gradeID)) ? "," : '';
            $statement=qq[
            UPDATE tblMember_Clubs
            SET $st_contract $coma1 $st_primaryclub $coma2 $st_gradeID 
            WHERE intMemberID=?
                AND intClubID= ?
                AND intStatus <> $Defs::RECSTATUS_DELETED
            ];
            $query=$Data->{'db'}->prepare($statement);
            $query->execute($id, $clubID);
        }
    }
    ################################################################################################

    insertDefaultRegoTXN($Data->{'db'}, $Defs::LEVEL_MEMBER, $id, $assocID) if($level == $Defs::LEVEL_MEMBER and $newstatus == $Defs::RECSTATUS_ACTIVE);
}

sub update_paidStatuses {
    my($Data, $updates)=@_;
    my $assocID=$Data->{'clientValues'}{'assocID'} || '';
    $assocID ='' if $assocID == $Defs::INVALID_ID;
    return if !$assocID;
    my $defaultregoID=0;

    if($Data->{'SystemConfig'}{'AllowProdTXNs'} or $Data->{'SystemConfig'}{'AllowTXNs'})  {
        my $st=qq[SELECT intDefaultRegoProductID FROM tblAssoc WHERE intAssocID=$Data->{'clientValues'}{'assocID'}];
        my $q=$Data->{'db'}->prepare($st);
        $q->execute();
        ($defaultregoID)=$q->fetchrow_array();
        $defaultregoID||=0;
    }
    return if !$defaultregoID;

    for my $row (@{$updates})    {
        next if !$row->[1]; #Cannot set as unpaid

        my $id=$row->[0] || next;

        #Value has changed - update
        my $st = qq[
        SELECT intTransactionID, curAmount
        FROM tblTransactions 
        WHERE intID = $id
            AND intTableType=$Defs::LEVEL_MEMBER
            AND intAssocID=$assocID
            AND intProductID=$defaultregoID
            AND intStatus=0
        LIMIT 1
        ];
        my $q=$Data->{'db'}->prepare($st);
        $q->execute();
        my ($txnID, $curAmount) = $q->fetchrow_array();
        $txnID ||=0;
        $curAmount||=0;
        if ($txnID)    {
            $st = qq[
            INSERT INTO tblTransLog
            (dtLog, intAmount, intRealmID, intStatus, intPaymentType)
            VALUES (NOW(), $curAmount, $Data->{'Realm'}, 1, 0)
            ];
            my $qry=$Data->{'db'}->prepare($st);
            $qry->execute();
            my $transLogID = $qry->{'mysql_insertid'};

            $st = qq[
            INSERT INTO tblTXNLogs
            (intTXNID, intTLogID)
            VALUES ($txnID, $transLogID)
            ];
            $qry=$Data->{'db'}->prepare($st);
            $qry->execute();

            $st = qq[
            UPDATE tblTransactions
            SET intTransLogID = $transLogID, intStatus = $Defs::TXN_PAID, dtPaid=NOW()
            WHERE intTransactionID = $txnID
            ];
            $qry=$Data->{'db'}->prepare($st);
            $qry->execute();
        }
    }
}

sub update_seasonStatus    {
    my($Data, $seasonID, $updates, $field)=@_;
    my $assocID=$Data->{'clientValues'}{'assocID'} || '';
    $assocID ='' if $assocID == $Defs::INVALID_ID;
    my $clubID=$Data->{'clientValues'}{'clubID'} || '';
    $clubID =0 if $clubID == $Defs::INVALID_ID;
    return if !$assocID;
    my $MStablename = "tblMember_Seasons_$Data->{'Realm'}";

    my %memberFields=();
    $memberFields{'Seasons.intPlayerStatus'} = 'intPlayer';
    $memberFields{'Seasons.intCoachStatus'} = 'intCoach';
    $memberFields{'Seasons.intUmpireStatus'} = 'intUmpire';
    $memberFields{'Seasons.intMiscStatus'} = 'intMisc';
    $memberFields{'Seasons.intVolunteerStatus'} = 'intVolunteer';
    #$memberFields{'Seasons.intMSRecStatus'} = 'intMSRecStatus';
    my %MemberSeasonUpdates=();
    my %MemberSeasonAssocUpdates=();
    my %MemberUpdates=();
    return if $field !~ /Seasons/;
    $field =~s/^Seasons_/Seasons./;
    for my $row (@{$updates})    {
        my $id=$row->[0] || next;
        $row->[1]||=0;
        $MemberSeasonUpdates{$id} .= qq[, ] if exists $MemberSeasonUpdates{$id};
        $MemberSeasonUpdates{$id} .= qq~ $field = $row->[1]~;
        $MemberSeasonAssocUpdates{$id} .= qq~ $field = $row->[1]~ if $row->[1] == 1;
        if ($row->[1] eq '1' and exists $memberFields{$field})    {
            $MemberUpdates{$id} .= qq[, ] if exists $MemberUpdates{$id};
            $MemberUpdates{$id} .= qq~ $field = $row->[1]~;
        }
    }
    my $db = $Data->{'db'};
    for my $member (keys %MemberSeasonUpdates)    {
        my $st=qq[
        UPDATE $MStablename as Seasons
        SET $MemberSeasonUpdates{$member}
        WHERE intAssocID = ?
            AND intSeasonID = ?
            AND intClubID = ?
            AND intMemberID = ?
        ];
        my $q= $db->prepare($st);
        $q->execute(
            $assocID,
            $seasonID,
            $clubID,
            $member,
        );
        if ($clubID == 0 and $MemberSeasonUpdates{$member} =~ /intMSRecStatus = 0/)    {
            my $st=qq[
            UPDATE $MStablename as Seasons
            SET $MemberSeasonUpdates{$member}
            WHERE intAssocID = ?
                AND intSeasonID = ?
                AND intClubID > 0
                AND intMemberID = ?
            ];
            my $q= $db->prepare($st);
            $q->execute(
                $assocID,
                $seasonID,
                $member,
            );
            #checkMSRecordExistance($Data, $seasonID, $memberID);
        }
        if ($Data->{'SystemConfig'}{'Seasons_StatusClubToAssoc'} and defined $MemberSeasonAssocUpdates{$member} and $clubID)       {
            my $st=qq[
            UPDATE $MStablename as Seasons
            SET $MemberSeasonAssocUpdates{$member}
            WHERE intAssocID = ?
                AND intSeasonID = ?
                AND intClubID = 0
                AND intMemberID = ?
            ];
            my $q= $db->prepare($st);
            $q->execute(
                $assocID,
                $seasonID,
                $member,
            );
        }

    }
    for my $member (keys %MemberUpdates)    {
        my $field = $MemberUpdates{$member};
        $field =~s/Seasons\.intUmpireStatus/intUmpire/;
        $field =~s/Seasons\.intPlayerStatus/intPlayer/;
        $field =~s/Seasons\.intCoachStatus/intCoach/;
        $field =~s/Seasons\.intMiscStatus/intMisc/;
        $field =~s/Seasons\.intVolunteerStatus/intVolunteer/;
        my $st=qq[
        UPDATE tblMember
        SET $field
        WHERE intMemberID = ?
        LIMIT 1
        ];
        my $q= $db->prepare($st);
        $q->execute(
            $member,
        );
    }
}

sub update_membercheckboxes {
    my($Data, $updates, $field)=@_;
    my $assocID=$Data->{'clientValues'}{'assocID'} || '';
    $assocID ='' if $assocID == $Defs::INVALID_ID;
    return if !$assocID;
    return if !$field;

    my $st=qq[
    UPDATE tblMember
    INNER JOIN tblMember_Associations as MA ON (MA.intMemberID = tblMember.intMemberID AND MA.intAssocID = $assocID) 
    SET $field =?
    WHERE tblMember.intMemberID=?
        AND intStatus <> $Defs::RECSTATUS_DELETED
    ];
    my $q=$Data->{'db'}->prepare($st);

    for my $row (@{$updates})    {
        my $id=$row->[0] || next;
        $row->[1]||=0;
        $q->execute($row->[1], $id); 
    }
}


sub update_membertypecheckboxes    {
    my($Data, $updates, $field)=@_;
    my $assocID=$Data->{'clientValues'}{'assocID'} || '';
    $assocID ='' if $assocID == $Defs::INVALID_ID;

    return if !$assocID;
    return if !$field;
    my($pre,$f)=split /\./,$field;
    return 0 if (!$pre or !$f);
    my $typeID=0;
    $typeID = $Defs::MEMBER_TYPE_PLAYER if $pre eq 'Player';
    $typeID = $Defs::MEMBER_TYPE_COACH if $pre eq 'Coach';
    $typeID = $Defs::MEMBER_TYPE_UMPIRE if $pre eq 'Umpire';

    my $st=qq[ 
    UPDATE tblMember_Types SET $f=?
    WHERE intMemberID=?
        AND intAssocID = $assocID
        AND intTypeID= $typeID
        AND intSubTypeID = 0 
        AND intRecStatus <> $Defs::RECSTATUS_DELETED
    ];
    my $q=$Data->{'db'}->prepare($st);

    my $st_insert =qq[
    INSERT INTO tblMember_Types
    (intMemberID, intTypeID, intSubTypeID, intAssocID, intRecStatus, $f)
    VALUES (?, $typeID, 0, $assocID,  $Defs::RECSTATUS_ACTIVE, ?)
    ];
    my $q_ins=$Data->{'db'}->prepare($st_insert);

    for my $row (@{$updates})    {
        my $id=$row->[0] || next;
        $row->[1]||=0;
        my $num=$q->execute($row->[1], $id) || 0; 
        if($num eq '0E0')    {
            $q_ins->execute($id, $row->[1]);
        }
    }
}


sub validate_MemberAccess    {

    my ($Data, $memberID) = @_;

    my $level=$Data->{'clientValues'}{'currentLevel'};
    my $id = getID($Data->{'clientValues'});

    return if $level >$Defs::LEVEL_ASSOC;

    my $st = qq[
    SELECT intMemberID
    ];
    if($level == $Defs::LEVEL_ASSOC)    {
        $st .= qq[
        FROM tblMember_Associations 
        WHERE intMemberID = ?
            AND intAssocID = ?    
            AND intRecStatus <> -1
        ];
    }
    elsif($level == $Defs::LEVEL_CLUB)    {
        $st .= qq[
        FROM tblMember_Clubs
        WHERE intMemberID = ?
            AND intClubID = ?    
            AND intStatus <> -1
        ];
    }
    my $q = $Data->{'db'}->prepare($st);
    $q->execute(
        $memberID, 
        $id
    );

    my ($mID) = $q->fetchrow_array();
    return $mID || 0;
}


sub update_pending_status {
    my ($Data, $member_id, $value) = @_;
    my $dbh = $Data->{'db'};
    my $realm_id = $Data->{'Realm'};
    my $assoc_id = $Data->{'clientValues'}{'assocID'};
    my $club_id = $Data->{'clientValues'}{'clubID'};
    my $current_level = $Data->{'clientValues'}{'currentLevel'};

    my $result = '';
    my $ms_rec_status;
    if ($value == 0 )  {
        $result = 'approved';
        $ms_rec_status = 1
    } elsif ($value == 1) {
        $ms_rec_status = 0
    } elsif ($value == -1) {
        $result = 'denied';
        $ms_rec_status = -1;
    }

    my $record = query_one(qq[
        SELECT CONCAT(strFirstname, " " , strSurname) AS MemberName, strEmail AS MemberEmail FROM tblMember
        WHERE intMemberID = ?
        ], $member_id);

    my ( $member_name, $member_email ) = ( $record->{'MemberName'}, $record->{'MemberEmail'} );

    my $season_id = query_value(qq[
        SELECT intCurrentSeasonID FROM tblAssoc
        WHERE intAssocID = ?
        ], $assoc_id);

    exec_sql(qq[
        UPDATE tblMember_Seasons_$realm_id
        SET intPlayerPending = ?, intMSRecStatus = ?
        WHERE intMemberID = ? AND intSeasonID = ?
            AND intAssocID = ?
        ], $value, $ms_rec_status, $member_id, $season_id,$assoc_id);

    if ( $value != 1 and ( $current_level == $Defs::LEVEL_CLUB or $current_level == $Defs::LEVEL_ASSOC ) ) {
        my ( $entity_name, $entity_contact, $entity_email ) = ();

        if ( $current_level == $Defs::LEVEL_CLUB ) {
            $record = query_one(qq[
                SELECT strName AS EntityName, strContact AS EntityContact, strEmail as EntityEmail FROM tblClub
                WHERE intClubID = ?
                ], $club_id);
            ( $entity_name, $entity_contact, $entity_email ) = ( $record->{'EntityName'}, $record->{'EntityContact'}, $record->{'EntityEmail'} );
        }
        elsif ( $current_level == $Defs::LEVEL_ASSOC ) {
            $record = query_one(qq[
                SELECT strName AS EntityName, strContact AS EntityContact, strEmail as EntityEmail FROM tblAssoc
                WHERE intAssocID = ?
                ], $assoc_id);
            ( $entity_name, $entity_contact, $entity_email ) = ( $record->{'EntityName'}, $record->{'EntityContact'}, $record->{'EntityEmail'} );
        }
        else {
            # do nothing
        }

        my $template_data = {
            'Result' => $result,
            'MemberName' => $member_name,
            'EntityName' => $entity_name,
            'EntityContact' => $entity_contact,
            'EntityEmail' => $entity_email,
        };


        sendTemplateEmail(
            $Data,
            'regoform/pending_registration/result-notification-member.templ',
            $template_data,
            $member_email,
            "Registration $result for $entity_name ($member_name)",
            $Defs::donotreply_email,
        );
    }

    return 1;
}

1;
