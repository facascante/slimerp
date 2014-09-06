#
# $Header: svn://svn/SWM/trunk/web/RegoForm/RegoForm_Notifications.pm 11237 2014-04-04 06:40:02Z apurcell $
#

package RegoForm_Notifications;
require Exporter;
@ISA =  qw(Exporter);

@EXPORT = qw(sendAuthEmail sendTeamAuthEmail);
@EXPORT_OK = qw(sendAuthEmail sendTeamAuthEmail);

use lib '.', '..', '../..', "../comp", '../RegoForm', "../dashboard", "../RegoFormBuilder",'../PaymentSplit', "../user";
use strict;
use RegoForm_Common;
use TemplateEmail;
use ServicesContacts;
use CGI;
use InstanceOf;
use RegoFormUtils;
use ContactsObj;
use Log;
use Data::Dumper;

sub sendAuthEmail {
    my $self = shift;
    my ($Data, $assocID, $memberID, $strUsername, $password, $teamID, $rereg) = @_;

    my $formID       = $self->{'Data'}{'RegoFormID'}    || 0;
    my $realmID      = $self->{'Data'}{'Realm'}         || 0;
    my $realmSubType = $self->{'Data'}{'RealmSubType'}  || 0;
    my $clubID       = $self->{'RunDetails'}{'ClubID'};
    my $regoType     = $self->FormType();
    my $team_obj     = getInstanceOf($Data, 'team', $teamID);
    my $program_obj  = $self->{'programObj'};
    my $dbh          = $Data->{'db'};

    $clubID = 0 if $clubID < 0;

    my $st = qq[
        SELECT 
            CONCAT(M.strFirstname, " " , M.strSurname) as MemberName, 
            CONCAT(M.strP1FName, " " , M.strP1SName) as Parent1Name, 
            CONCAT(M.strP2FName, " " , M.strP2SName) as Parent2Name, 
            M.strEmail, 
            M.strEmail2,
            A.strName AS AssocName,
            strAuthEmailText, 
            A.strEmail as AssocEmail,
            strP1Email, 
            strP1Email2, 
            strP2Email,
            strP2Email2,
            C.strEmail as ClubEmail,
            C.strName as ClubName,
            C.intClubID,
            intNoPMSEmail
        FROM tblMember as M
            INNER JOIN tblMember_Associations AS MA 
                ON (M.intMemberID = MA.intMemberID AND MA.intAssocID = ?)
            INNER JOIN tblAssoc AS A 
                ON (A.intAssocID = MA.intAssocID)
            LEFT JOIN tblRegoFormConfig as RC 
                ON ((RC.intAssocID=0 OR RC.intAssocID=MA.intAssocID) AND (RC.intSubRealmID = ? OR RC.intSubRealmID=0) AND RC.intRealmID = ?  AND RC.intRegoFormID IN (0, ?))
            LEFT JOIN tblClub as C 
                ON (C.intClubID = ?)
        WHERE M.intMemberID = ?
        ORDER BY RC.intAssocID DESC, RC.intSubRealmID DESC
        LIMIT 1
    ];

    my $query = $dbh->prepare($st);
    $query->execute($assocID, $realmSubType, $realmID, $formID, $clubID, $memberID);

    my $dref = $query->fetchrow_hashref() || undef;
    $query->finish();

    my $memberName = $dref->{MemberName};
    my $clubName = $dref->{ClubName};
    my $signed_up_to = $clubName;
    my $assocName = $dref->{AssocName};
    my $entityName = '';
    my $entityEmail = '';
    my $entityRegEmail = '';

    if ( $regoType == $Defs::REGOFORM_TYPE_MEMBER_ASSOC ) {
        $entityName = $dref->{'AssocName'};
        $entityEmail = $dref->{'AssocEmail'};
        $entityRegEmail = get_emails_list(ContactsObj->getList(dbh=>$dbh, associd=>$assocID, getregistrations=>1), 1) || get_emails_list(ContactsObj->getList(dbh=>$dbh, associd=>$assocID, getprimary=>1), 1) || '';
    }
    elsif ( $regoType == $Defs::REGOFORM_TYPE_MEMBER_CLUB ) {
        $entityName = $dref->{'ClubName'};
        $entityEmail = $dref->{'ClubEmail'};
        $entityRegEmail = get_emails_list(ContactsObj->getList(dbh=>$dbh, associd=>$assocID, clubid=>$clubID, getregistrations=>1), 1) || get_emails_list(ContactsObj->getList(dbh=>$dbh, associd=>$assocID, clubid=>$clubID, getprimary=>1), 1) || '';
    }
    else {
        # do nothing
    }

    my $productName = '';

    {
        my $st_pn = qq[
            SELECT P.strName
            FROM tblTransactions T
                INNER JOIN  tblProducts P ON T.intProductID = P.intProductID
            WHERE T.intID = ?
            ORDER BY T.intTransactionID DESC
            LIMIT  1
        ];
        my $pn_query = $dbh->prepare($st_pn);
        $pn_query->execute($memberID);
        ($productName) = $pn_query->fetchrow_array();
    }

    my ($send_to_assoc, $send_to_club, $send_to_team, $send_to_member, $send_to_parents) = get_send_tos($self);

    my $templatefile = '';
    my $registration_status = $Data->{'SystemConfig'}{'AllowPendingRegistration'} && !$rereg ? 'Pending' : 'Successful';
    my $subject = "$registration_status Registration for $entityName ($memberName)";

    if ( $Data->{'SystemConfig'}{'AllowPendingRegistration'} and !$rereg ) {
        $templatefile = 'regoform/pending_registration/registration-member.templ';
    }
    elsif($regoType == $Defs::REGOFORM_TYPE_MEMBER_ASSOC)  {
        if ($realmSubType == 1) { # TODO should be System Config setting
            $templatefile = 'regoform/member-to-assoc/signup-member-afl-leagues.templ';
        }
        else {
            $templatefile = 'regoform/member-to-assoc/signup-member.templ';
        }
    }
    elsif($regoType == $Defs::REGOFORM_TYPE_MEMBER_TEAM) {
        $templatefile = 'regoform/member-to-team/signup-member.templ';
    }
    elsif($regoType == $Defs::REGOFORM_TYPE_MEMBER_CLUB) {
        $subject = "$registration_status Registration for $dref->{ClubName} ($dref->{MemberName})";
        if ($realmSubType == 1) { # TODO should be System Config setting
            $templatefile = 'regoform/member-to-club/signup-member-afl-leagues.templ';
        }
        else {
            $templatefile = 'regoform/member-to-club/signup-member.templ';
        }
    }
    elsif($regoType == $Defs::REGOFORM_TYPE_MEMBER_PROGRAM) {
        my $program_name = $program_obj->name();
        $subject = "$registration_status Registration for $program_name ($dref->{MemberName})";
        #TODO: Program configuration item
        $templatefile = 'regoform/member-to-program/signup-member-aussiehoops.templ';
    }
    
    my $assoc_emails_aref = ($send_to_assoc) ? get_emails_list(ContactsObj->getList(dbh=>$dbh, associd=>$assocID, getregistrations=>1)) : '';
    my $club_emails_aref  = ($send_to_club and $clubID) ? get_emails_list(ContactsObj->getList(dbh=>$dbh, associd=>$assocID, clubid=>$clubID, getregistrations=>1)) : '';

    my $team_email    = ($send_to_team)    ? $team_obj->{'DBData'}{'strEmail'} : '';
    my $member_email  = ($send_to_member)  ? $dref->{'strEmail'}    : '';
    my $member_email2 = ($send_to_member)  ? $dref->{'strEmail2'}   : '';
    my $p1_email      = ($send_to_parents) ? $dref->{'strP1Email'}  : '';
    my $p1_email2     = ($send_to_parents) ? $dref->{'strP1Email2'} : '';
    my $p2_email      = ($send_to_parents) ? $dref->{'strP2Email'}  : '';
    my $p2_email2     = ($send_to_parents) ? $dref->{'strP2Email2'} : '';

    #remove dupes

    $member_email2 = '' if $member_email2 and ($member_email2 eq $member_email);

    my @emails = ();
    push @emails, $member_email  if $member_email;
    push @emails, $member_email2 if $member_email2;

    if ($p1_email) {
        $p1_email = clear_if_dupe(\@emails, $p1_email);
        push @emails, $p1_email if $p1_email;
    }

    if ($p1_email2) {
        $p1_email2 = clear_if_dupe(\@emails, $p1_email2);
        push @emails, $p1_email2 if $p1_email2;
    }

    if ($p2_email) {
        $p2_email = clear_if_dupe(\@emails, $p2_email);
        push @emails, $p2_email if $p2_email;
    }

    if ($p2_email2) {
        $p2_email2 = clear_if_dupe(\@emails, $p2_email2);
        push @emails, $p2_email2 if $p2_email2;
    }

    if ($team_email) {
        $team_email = clear_if_dupe(\@emails, $team_email);
        push @emails, $team_email if $team_email;
    }

    #assoc & club emails dupes will already be filtered out. however, still need to be checked against the rest.
    my $assoc_emails = get_uniq_emails($assoc_emails_aref, \@emails);
    my $club_emails  = get_uniq_emails($club_emails_aref, \@emails);

    $assoc_emails = get_emails_list(ContactsObj->getList(dbh=>$dbh, associd=>$assocID, getprimary=>1), 1) if $send_to_assoc and !$assoc_emails;
    $club_emails  = get_emails_list(ContactsObj->getList(dbh=>$dbh, associd=>$assocID, clubid=>$clubID, getprimary=>1), 1) if $send_to_club and !$club_emails and $clubID;

    #anything to send?
    my $count = 0;
    $count++ if $assoc_emails;
    $count++ if $club_emails;
    $count++ if $team_email;
    $count++ if $member_email;
    $count++ if $member_email2;
    $count++ if $p1_email;
    $count++ if $p1_email2;
    $count++ if $p2_email;
    $count++ if $p2_email2;
    return undef if !$count;

    my $to_address   = $member_email; 

    my $from_address;
    if($self->FormType() == $Defs::REGOFORM_TYPE_MEMBER_ASSOC or $self->FormType() == $Defs::REGOFORM_TYPE_TEAM_ASSOC) {
        if($assoc_emails){
             $from_address =$assocName if($assocName);
        }   
    }
       elsif($self->FormType() == $Defs::REGOFORM_TYPE_MEMBER_TEAM) {
        if($team_email){
             $from_address =$team_obj->{'DBData'}{'strName'} if($team_obj->{'DBData'}{'strName'});
        }
    }
      elsif($self->FormType() == $Defs::REGOFORM_TYPE_MEMBER_CLUB) {
        if($club_emails) {
             $from_address =$clubName if ($clubName);
        }
    }
    elsif ($self->FormType() == $Defs::REGOFORM_TYPE_MEMBER_PROGRAM){
        #TODO: Program Configuration item
        if($assoc_emails){
             $from_address = $assocName if($assocName);
        }
    }

    $from_address = qq[$from_address <$Defs::donotreply_email>];

 my $authEmailText = $dref->{'strAuthEmailText'} || '';
        if($authEmailText !~ /<br.>/)       {
                $authEmailText =~s/\n/<br>/g;
        }



    my %RegEmailData = (
        UsePassport => $Data->{'SystemConfig'}{'usePassportInRegos'},
	    ClubID        => $clubID,
        TeamID        => $teamID,
        AssocID       => $assocID,
        MemberID      => $memberID,
        MemberName    => $memberName,
        Username      => $strUsername,
        Password      => $password,
        FormID        => $formID,
        RealmID       => $realmID,
        TeamName      => $team_obj->{'DBData'}{'strName'} || '',
        TeamEmail     => $team_email,
        ClubName      => $clubName                        || '',
        ProductName   => $productName                     || '',
        SignedUpTo    => $signed_up_to                    || '',
        AuthEmailText => $authEmailText			  || '',
        Email         => $to_address,
        AssocName     => $dref->{'AssocName'}             || '',
        EntityName    => $entityName,
        EntityEmail   => $entityEmail,
        regoEmail_HideThankYou      => $Data->{'SystemConfig'}{'regoEmail_HideThankYou'},
        parent_1_name  => $dref->{Parent1Name},
        parent_2_name  => $dref->{Parent2Name},
        program_obj    => $program_obj,
        new_to_program => $self->getCarryFields('program_new') || 0,
    );

    my $cc;
    $cc .= $member_email2.';' if $member_email2;
    $cc .= $p1_email.';'      if $p1_email;
    $cc .= $p1_email2.';'     if $p1_email2;
    $cc .= $p2_email.';'      if $p2_email;
    $cc .= $p2_email2.';'     if $p2_email2;
    $cc .= $team_email.';'    if $team_email;

    my $bcc = $assoc_emails.$club_emails;
    my $sent = sendTemplateEmail(
        $self->{'Data'},
        $templatefile,
        \%RegEmailData,
        $to_address,
        $subject,
        $from_address,
        $cc,
        $bcc,
    );

    if ( $Data->{'SystemConfig'}{'AllowPendingRegistration'} and !$rereg ) {
        $sent = sendTemplateEmail(
            $self->{'Data'},
            'regoform/pending_registration/registration-notification-entity.templ',
            \%RegEmailData,
            $entityRegEmail,
            $subject,
            $from_address,
        );
    }

    return $member_email || 0; #return something else instead?
}

sub sendTeamAuthEmail {
    my $self = shift;
    my ($teamID, $TeamRegoData) = @_;

    my $formID       = $self->{'Data'}{'RegoFormID'}   || 0;
    my $realmID      = $self->{'Data'}{'Realm'}        || 0;
    my $realmSubType = $self->{'Data'}{'RealmSubType'} || 0;
    my $assocID      = $self->AssocID();
    my $dbh          = $self->{'Data'}{'db'};

    my $st = qq[
        SELECT T.strName as TeamName, 
            T.strEmail AS TeamEmail, 
            A.strName AS AssocName, 
            strAuthEmailText, 
            T.strContact as TeamContact, 
            C.intClubID,
            intNoPMSEmail
        FROM tblTeam as T 
            INNER JOIN tblAssoc as A ON (A.intAssocID=T.intAssocID)
            LEFT JOIN tblRegoFormConfig as RC ON (
                (RC.intAssocID=0 or RC.intAssocID=T.intAssocID) AND 
                (RC.intSubRealmID=? OR RC.intSubRealmID=0)      AND 
                (RC.intRealmID=?)                               AND 
                (RC.intRegoFormID IN (0, ?))
            )
            LEFT JOIN tblClub as C ON C.intClubID=T.intClubID
        WHERE T.intTeamID=? AND T.intAssocID=?
        ORDER BY RC.intAssocID DESC, RC.intSubRealmID DESC
        LIMIT 1
    ];

    my $query = $dbh->prepare($st);
    $query->execute($realmSubType, $realmID, $formID, $teamID, $assocID);

    my $dref = $query->fetchrow_hashref() || undef;
    $dref->{'TeamContact'} ||= 'Team Contact';

    for my $i (qw(TeamEmail AssocName strAuthEmailText TeamContact)) {
        $TeamRegoData->{$i} = $dref->{$i} || '';
    }
    my ($send_to_assoc, $send_to_club, $send_to_team, $send_to_member, $send_to_parents) = get_send_tos($self);

    my $clubID = $dref->{'intClubID'};
    $clubID = 0 if $clubID < 0;

    my $team_email = ($send_to_team) ? $dref->{'TeamEmail'} : '';
    
#    my $passport = new Passport(db=>$dbh);
 #   my ($passportID, $passportStatus) = $passport->isMember($team_email);
    my $templatefile = 'regoform/team/signup-coordinator.templ';
#	$templatefile = 'regoform/team/signup-afl9-coordinator.templ' if($realmSubType==7);
#	$templatefile = 'regoform/team/signup-afl9-coordinator-new.templ' if($realmSubType==7 and !$passportID);

    my $assoc_emails_aref = ($send_to_assoc) ? get_emails_list(ContactsObj->getList(dbh=>$dbh, associd=>$assocID, getregistrations=>1)) : '';
    my $club_emails_aref  = ($send_to_club and $clubID)  ? get_emails_list(ContactsObj->getList(dbh=>$dbh, associd=>$assocID, clubid=>$clubID, getregistrations=>1)) : '';


    my @emails = ();
    push @emails, $team_email if $team_email;

    #assoc & club emails dupes will already be filtered out. however, still need to be checked against the rest.
    my $assoc_emails = get_uniq_emails($assoc_emails_aref, \@emails);
    my $club_emails  = get_uniq_emails($club_emails_aref, \@emails);

    #anything to send?
    my $count = 0;
    $count++ if $assoc_emails;
    $count++ if $club_emails;
    $count++ if $team_email;
    return undef if !$count;

    my $subject ="Registration details for $dref->{AssocName} ($dref->{TeamName})";

    my $to_address = $team_email;
    my $from_address = $dref->{'assoc_emails'} || $Defs::donotreply_email;
    $from_address = "$TeamRegoData->{'AssocName'} <$from_address>";

    my $bcc = $assoc_emails.$club_emails;

  my $Data = $self->{'Data'};
	$TeamRegoData->{'UsePassport'} = $Data->{'SystemConfig'}{'usePassportInRegos'};
    my $sent = sendTemplateEmail(
        $self->{'Data'},
        $templatefile,
        $TeamRegoData,
        $to_address,
        $subject,
        $from_address,
        '',
        $bcc,
    );

    return $team_email;
}

sub get_send_tos {
    my ($self) = @_;

    my $renewal = $self->{'RunDetails'}{'ReRegister'} * 1;
    my $newrego = !$renewal * 1;

    my $send_to_assoc   = 0;
    my $send_to_club    = 0;
    my $send_to_team    = 0;
    my $send_to_member  = 0;
    my $send_to_parents = 0;

    if ($newrego) {
        my $new_char = $self->{'DBData'}{'intNewBits'} || '';
        ($send_to_assoc, $send_to_club, $send_to_team, $send_to_member, $send_to_parents) = get_notif_bits($new_char) if $new_char;
    }
    else {
        my $ren_char = $self->{'DBData'}{'intRenewalBits'} || '';
        ($send_to_assoc, $send_to_club, $send_to_team, $send_to_member, $send_to_parents) = get_notif_bits($ren_char) if $ren_char;
    }

    return ($send_to_assoc, $send_to_club, $send_to_team, $send_to_member, $send_to_parents);
}

sub get_uniq_emails {
    my ($source_emails_aref, $emails_aref) = @_;

    my @emails_uniq = ();

    if ($source_emails_aref) {
        foreach my $email (@$source_emails_aref) {
            $email = clear_if_dupe($emails_aref, $email);
            if ($email) {
                push @$emails_aref, $email;
                push @emails_uniq, $email;
            }
        }
    }

    my $emails = join(';', @emails_uniq);
    $emails   .= ';' if $emails;

    return $emails;
}

sub clear_if_dupe {
    my ($emails, $email) = @_;

    foreach (@$emails) {
        if ($email eq $_) {
            $email = '';
            last;
        }
    }

    return $email;
}

1;
