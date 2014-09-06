#!/usr/bin/perl

#
# $Header: svn://svn/SWM/trunk/misc/set_regoform_notifs.pl 11606 2014-05-20 00:52:36Z mstarcevic $
#

use strict;
use lib '..','../web','../web/comp';
use Defs;
use Utils;

use Getopt::Long;
use SystemConfig;
use RegoFormObj;
use RegoFormUtils;
use AssocObj;

main ();

sub main {
    my ($Data, $lfh) = init();
    my ($realm_id, $assoc_id) = get_params();

    print_params($lfh, $realm_id, $assoc_id);

    my $assocs = get_assocs($Data, $lfh, $realm_id, $assoc_id);

    my $num = @$assocs;
    print $lfh "$num assocs to be processed\n";
    print_underline($lfh);

    my $upd_count   = 0;

    foreach my $ahash(@$assocs) {
        next if $ahash->{'realmid'} == 0;
        check_sysconfig($Data, $ahash);
        my $upd = process_assoc($Data, $lfh);
        $upd_count+= $upd;
    }

    print_underline($lfh);
    print $lfh "\n$upd_count regoforms updated in total\n\n";
    print $lfh "Complete...\n";

    exit;
}

sub init {
    my %Data = ();
    $Data{'db'} = connectDB();
    $Data{'Realm'} = 0;
    $Data{'RealmSubType'} = 0;

    my $logfile = '/tmp/set_regoform_notifs.log';
    open (my $lfh, ">$logfile") or die "Can't create logfile\n";
    print $lfh "Starting...\n";

    return (\%Data, $lfh);
}

sub check_sysconfig {
    my ($Data, $ahash) = @_;

    my $realm_id    = $ahash->{'realmid'};
    my $subrealm_id = $ahash->{'subrealmid'};
    my $assoc_id    = $ahash->{'associd'};

    if ($Data->{'Realm'} != $realm_id or $Data->{'RealmSubType'} != $subrealm_id) {
        $Data->{'Realm'} = $realm_id;
        $Data->{'RealmSubType'} = $subrealm_id;
        $Data->{'SystemConfig'} = getSystemConfig($Data);
    }

    $Data->{'assocID'} = $assoc_id;

    return;
}

sub get_assocs {
    my ($Data, $lfh, $realm_id, $assoc_id) = @_;

    my $sql = qq[SELECT intRealmID, intAssocTypeID, intAssocID, strName FROM tblAssoc WHERE 1=1];

    my $fieldname = '';
    my $entity_id = 0;

    if ($realm_id) {
        $fieldname = 'intRealmID';
        $entity_id = $realm_id
    }
    elsif ($assoc_id) {
        $fieldname = 'intAssocID';
        $entity_id = $assoc_id;
    }

    $sql .= qq[ AND $fieldname=?] if $entity_id;
    $sql .= qq[ ORDER BY intRealmID, intAssocTypeID, intAssocID];

    my $query = $Data->{'db'}->prepare($sql);

    if ($entity_id) {
        $query->execute($entity_id);
    }
    else {
        $query->execute();
    }

    my @assocs = ();

    while (my $href = $query->fetchrow_hashref()) {
        push @assocs, {realmid=>$href->{intRealmID}, subrealmid=>$href->{intAssocTypeID}, associd=>$href->{intAssocID}};
    }

    return \@assocs;
}

sub process_assoc {
    my ($Data, $lfh) = @_;

    my $assoc_id = $Data->{'assocID'};

    my $assoc_obj = new AssocObj('db'=>$Data->{'db'}, 'ID'=>$assoc_id, 'assocID'=>$assoc_id);
    $assoc_obj->load();

    die "Inconsistent data" if ($assoc_id != $assoc_obj->getValue('intAssocID'));

    my $noPMSEmail = $assoc_obj->getValue('intNoPMSEmail');
    my $ccAssocOnClubPayments = $assoc_obj->getValue('intCCAssocOnClubPayments');
    my $upd_count = process_regoforms($Data, $lfh, $assoc_id, $noPMSEmail, $ccAssocOnClubPayments);

    return $upd_count;
}

sub process_regoforms {
    my ($Data, $lfh, $assoc_id, $noPMSEmail, $ccAssocOnClubPayments) = @_;

    my $dbh              = $Data->{'db'};
    my $sendAuthEmail    = $Data->{'SystemConfig'}{'regoForm_sendAuthEmail'} || 0;
    my $ccParents        = $Data->{'SystemConfig'}{'regoForm_CC_Parents'}    || 0;
    my $ccAssocOnReceipt = $Data->{'SystemConfig'}{'paymentReceiptCC_Assoc'} || 0;

    my $sql = qq[SELECT intRegoFormID FROM tblRegoForm WHERE intAssocID=?];
    my $query = $dbh->prepare($sql);

    $query->execute($assoc_id);

    my $upd_count  = 0;

    while (my $href = $query->fetchrow_hashref()) {
        my $regoform_obj = RegoFormObj->load(db=>$dbh, ID=>$href->{intRegoFormID});

        my $assoc_id  = $regoform_obj->getValue('intAssocID');
        my $club_id   = $regoform_obj->getValue('intClubID');
        my $form_type = $regoform_obj->getValue('intRegoType');

        $club_id = 0 if $club_id < 0;

        my ($new_char, $ren_char, $pay_char) = set_notif_bits($form_type, $club_id, $sendAuthEmail, $ccParents, $ccAssocOnReceipt, $noPMSEmail, $ccAssocOnClubPayments);

        my $dbfields = 'dbfields';

        $regoform_obj->{$dbfields} = ();
        $regoform_obj->{$dbfields}{'intNewBits'}     = $new_char;
        $regoform_obj->{$dbfields}{'intRenewalBits'} = $ren_char;
        $regoform_obj->{$dbfields}{'intPaymentBits'} = $pay_char;

        $regoform_obj->save();
        $upd_count++;
    }

    print $lfh "assocID=$assoc_id => sendAuthEmail=$sendAuthEmail | ccParents=$ccParents | ccAssocOnReceipt=$ccAssocOnReceipt | noPMSEmail=$noPMSEmail | ccAssocOnClubPayments=$ccAssocOnClubPayments | upd_count=$upd_count\n" if $upd_count;

    return $upd_count;
}

sub set_notif_bits {
    my ($form_type, $club_id, $sendAuthEmail, $ccParents, $ccAssocOnReceipt, $noPMSEmail, $ccAssocOnClubPayments) = @_;

    $club_id = 0 if $club_id < 0;

    my $new_char;
    my $ren_char;
    my $pay_char;

    #firstly set defaults; this is exactly as per RegoFormOptions.
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

    #now apply the various fixes.

    #if {'SystemConfig'}{'regoform_CC_Parents'} is not set, don't send any emails at all for new regs and renewals.
    if (!$ccParents) {
        my ($new_assoc, $new_club, $new_team, $new_member, $new_parents) = get_notif_bits($new_char);
        my ($ren_assoc, $ren_club, $ren_team, $ren_member, $ren_parents) = get_notif_bits($ren_char);
        $new_parents = 0;
        $ren_parents = 0;
        $new_char = pack_notif_bits($new_assoc, $new_club, $new_team, $new_member, $new_parents);
        $ren_char = pack_notif_bits($ren_assoc, $ren_club, $ren_team, $ren_member, $ren_parents);
    }

    #if clubID and tblAssoc.intCCAssocOnClubPayments is set, then payments to assocs = yes. if not clubID, then payments to assoc = yes.
    if (!$club_id or ($club_id and $ccAssocOnClubPayments)) {
        my ($pay_assoc, $pay_club, $pay_team, $pay_member, $pay_parents) = get_notif_bits($pay_char);
        $pay_assoc = 1;
        $pay_char = pack_notif_bits($pay_assoc, $pay_club, $pay_team, $pay_member, $pay_parents);
    }

    #if tblAssoc.intNoPMSEmail is set, don't send any emails to assoc for new and renewals.
    if ($noPMSEmail) {
        my ($new_assoc, $new_club, $new_team, $new_member, $new_parents) = get_notif_bits($new_char);
        my ($ren_assoc, $ren_club, $ren_team, $ren_member, $ren_parents) = get_notif_bits($ren_char);
        $new_assoc = 0;
        $ren_assoc = 0;
        $new_char = pack_notif_bits($new_assoc, $new_club, $new_team, $new_member, $new_parents);
        $ren_char = pack_notif_bits($ren_assoc, $ren_club, $ren_team, $ren_member, $ren_parents);
    }

    #if {'SystemConfig'}{'paymentReceiptCC_Assoc'} is not set OR tblAssoc.intNoPMSEmail is set, don't send any payment emails to assoc or club.
    if (!$ccAssocOnReceipt or $noPMSEmail) {
        my ($pay_assoc, $pay_club, $pay_team, $pay_member, $pay_parents) = get_notif_bits($pay_char);
        $pay_assoc = 0;
        $pay_club  = 0;
        $pay_char = pack_notif_bits($pay_assoc, $pay_club, $pay_team, $pay_member, $pay_parents);
    }

    #if {'SystemConfig'}{'regoform_sendAuthEmail'} is not set, don't send any emails at all for new regs and renewals.
    if (!$sendAuthEmail) {
        $new_char = pack_notif_bits(0, 0, 0, 0, 0);
        $ren_char = pack_notif_bits(0, 0, 0, 0, 0);
    }

    return ($new_char, $ren_char, $pay_char);
}

sub print_params {
    my ($lfh, $realm_id, $assoc_id) = @_;
    my $line = '';
    $line  = "--realm=$realm_id " if $realm_id;
    $line .= "--assoc=$assoc_id " if $assoc_id;
    print $lfh "$line\n";
    print_underline($lfh);
    return 1;
}

sub print_underline {
    my ($lfh, $char) = @_;
    $char ||= '-';
    my $line = $char x 50;
    print $lfh "$line\n";
    return 1;
}

sub get_params {
    my $realm_id;
    my $assoc_id;

    GetOptions(
        'realm=i'=>\$realm_id, 
        'assoc=i'=>\$assoc_id, 
    );

    if (defined $realm_id and defined $assoc_id) {
        usage('cannot enter both a realm and assoc.');
        exit;
    }

    return ($realm_id, $assoc_id);
}

sub usage {
    my ($error) = @_;
    print "\nError:\n";
    print "\t$error\n";
    print "\tusage: $0 --realm=n --assoc=n\n\n";
}
