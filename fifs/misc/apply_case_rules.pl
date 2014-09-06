#!/usr/bin/perl

#
# $Header: svn://svn/SWM/trunk/misc/apply_case_rules.pl 9997 2013-11-28 22:51:19Z tcourt $
#

use strict;
use lib '..','../web', '../web/comp';
use Defs;
use Utils;

use Getopt::Long;
use FieldCaseRule;

main ();

sub main {
    my ($realm_id, $subrealm_id, $assoc_id, $clubs_also, $clubs_only, $comps_also, $comps_only, $teams_also, $teams_only, $update) = get_params();
    my $dbh = connectDB();

    my $logfile = 'apply_case_rules.log';
    open (my $lfh, ">$logfile") or die "Can't create logfile\n";
    print $lfh "Starting...\n";
    print_params($lfh, $realm_id, $subrealm_id, $assoc_id, $clubs_also, $clubs_only, $comps_also, $comps_only, $teams_also, $teams_only, $update);

    my @assocs = ();

    if ($realm_id) {
        get_assocs($dbh, $lfh, $realm_id, $subrealm_id, \@assocs);
    }
    else {
        $realm_id = get_realm_id($dbh, $lfh, $assoc_id, \@assocs);
    }

    my $num = @assocs;
    print_count($lfh, 'assoc', $num, 'to be processed');
    print_underline($lfh);

    my $diff_count_me = 0;
    my $diff_count_cl = 0;
    my $diff_count_co = 0;
    my $diff_count_te = 0;

    my $upd_count_me  = 0;
    my $upd_count_cl  = 0;
    my $upd_count_co  = 0;
    my $upd_count_te  = 0;

    foreach my $assoc(@assocs) {
        my $case_rules = get_field_case_rules({dbh=>$dbh, realmID=>$realm_id, subrealmID=>$assoc->{'subrealmid'}});
        next if !$case_rules;

        my ($diff_me, $upd_me, $diff_cl, $upd_cl, $diff_co, $upd_co, $diff_te, $upd_te) = 
            process_assoc($dbh, $lfh, $assoc, $clubs_also, $clubs_only, $comps_also, $comps_only, $teams_also, $teams_only, $case_rules, $update);

        $diff_count_me+= $diff_me  if $diff_me;
        $diff_count_cl+= $diff_cl  if $diff_cl;
        $diff_count_co+= $diff_co  if $diff_co;
        $diff_count_te+= $diff_te  if $diff_te;

        $upd_count_me+=  $upd_me   if $upd_me;
        $upd_count_cl+=  $upd_cl   if $upd_cl;
        $upd_count_co+=  $upd_co   if $upd_co;
        $upd_count_te+=  $upd_te   if $upd_te;
    }

    if (!$clubs_only and !$comps_only and !$teams_only) {
        print_count($lfh, 'member', $diff_count_me, 'different in total');
        print_count($lfh, 'member', $upd_count_me,  'updated in total') if $update;
    }
    
    if ($clubs_also or $clubs_only) {
        print_count($lfh, 'club', $diff_count_cl, 'different in total');
        print_count($lfh, 'club', $upd_count_cl,  'updated in total') if $update;
    }
    
    if ($comps_also or $comps_only) {
        print_count($lfh, 'comp', $diff_count_co, 'different in total');
        print_count($lfh, 'comp', $upd_count_co,  'updated in total') if $update;
    }
    
    if ($teams_also or $teams_only) {
        print_count($lfh, 'team', $diff_count_te, 'different in total');
        print_count($lfh, 'team', $upd_count_te,  'updated in total') if $update;
    }

    print $lfh "Complete...\n";
}

sub get_realm_id {
    my ($dbh, $lfh, $assoc_id, $assocs) = @_;

    my $sql = qq[SELECT intRealmID, strName, intAssocTypeID FROM tblAssoc WHERE intAssocID=?];
    my $query = $dbh->prepare($sql);

    $query->execute($assoc_id);

    my ($realm_id, $assoc_name, $subrealm_id) = $query->fetchrow_array();

    push @$assocs, {associd=>$assoc_id, assocname=>$assoc_name, subrealmid=>$subrealm_id};

    print $lfh "Got realm id ($realm_id) and subrealm id ($subrealm_id) for assoc.\n";

    return $realm_id;
}

sub get_assocs {
    my ($dbh, $lfh, $realm_id, $subrealm_id, $assocs) = @_;

    my $sql = qq[SELECT intAssocID, strName, intAssocTypeID FROM tblAssoc WHERE intRealmID=?];

    my $query = $dbh->prepare($sql);

    $query->execute($realm_id);

    while (my $href = $query->fetchrow_hashref()) {
        next if (defined $subrealm_id) and ($href->{intAssocTypeID} != $subrealm_id);
        push @$assocs, {associd=>$href->{intAssocID}, assocname=>$href->{strName}, subrealmid=>$href->{intAssocTypeID}};
    }

    return;
}

sub process_assoc {
    my ($dbh, $lfh, $assoc_ref, $clubs_also, $clubs_only, $comps_also, $comps_only, $teams_also, $teams_only, $case_rules, $update) = @_;

    my $assoc_id    = $assoc_ref->{'associd'};
    my $assoc_name  = $assoc_ref->{'assocname'};
    my $subrealm_id = $assoc_ref->{'subrealmid'};
    print $lfh "assocID=$assoc_id|assocName=$assoc_name|subrealmID=$subrealm_id\n\n";

    my $diff_count_me = 0;
    my $diff_count_cl = 0;
    my $diff_count_co = 0;
    my $diff_count_te = 0;

    my $upd_count_me = 0;
    my $upd_count_cl = 0;
    my $upd_count_co = 0;
    my $upd_count_te = 0;

    if (!$clubs_only and !$comps_only and !$teams_only) {
        my ($diff, $upd) = process_members($dbh, $lfh, $assoc_id, $case_rules, $update);
        $diff_count_me+= $diff if $diff;
        $upd_count_me+=  $upd  if $upd;
    }

    if ($clubs_also or $clubs_only) {
        my ($diff, $upd) = process_clubs($dbh, $lfh, $assoc_id, $case_rules, $update);
        $diff_count_cl+= $diff if $diff;
        $upd_count_cl+=  $upd  if $upd;
    }

    if ($comps_also or $comps_only) {
        my ($diff, $upd) = process_comps($dbh, $lfh, $assoc_id, $case_rules, $update);
        $diff_count_co+= $diff if $diff;
        $upd_count_co+=  $upd  if $upd;
    }

    if ($teams_also or $teams_only) {
        my ($diff, $upd) = process_teams($dbh, $lfh, $assoc_id, $case_rules, $update);
        $diff_count_te+= $diff if $diff;
        $upd_count_te+=  $upd  if $upd;
    }

    return ($diff_count_me, $upd_count_me, $diff_count_cl, $upd_count_cl, $diff_count_co, $upd_count_co, $diff_count_te, $upd_count_te);
}

sub process_members {
    my ($dbh, $lfh, $assoc_id, $case_rules, $update) = @_;

    my $sql = qq[
        SELECT m.intMemberID, m.strSurname, m.strFirstname, m.strSuburb
        FROM tblMember_Associations ma
            INNER JOIN tblMember m ON ma.intMemberID=m.intMemberID
        WHERE intAssocID=?];
    my $query = $dbh->prepare($sql);

    $query->execute($assoc_id);

    my $diff_count = 0;
    my $upd_count  = 0;
    while (my $href = $query->fetchrow_hashref()) {
        my ($diff, $upd) = process_member($dbh, $lfh, $href, $case_rules, $update);
        $diff_count+= $diff if $diff;
        $upd_count+=  $upd  if $upd;
    }

    print_count($lfh, 'member', $diff_count, 'different in assoc') if $diff_count;
    print_count($lfh, 'member', $upd_count,  'updated in assoc') if $update and $upd_count;
    print_underline($lfh) if $diff_count or $upd_count;

    return ($diff_count, $upd_count);
}

sub process_member {
    my ($dbh, $lfh, $mem_ref, $case_rules, $update) = @_;

    my $type = 'Member';
    my $first_name  = $mem_ref->{'strFirstname'};
    my $surname     = $mem_ref->{'strSurname'};
    my $suburb      = $mem_ref->{'strSuburb'};
    my $name_before = $first_name.' '.$surname;
    my $new_first_name = apply_field_case_rule($case_rules, $type, 'strFirstname', $first_name);
    my $new_surname    = apply_field_case_rule($case_rules, $type, 'strSurname',   $surname);
    my $new_suburb     = apply_field_case_rule($case_rules, $type, 'strSuburb',    $suburb);
    my $name_after  = $new_first_name.' '.$new_surname;
    my $diff = 0;
    my $upd  = 0;

    if (($name_before ne $name_after) or ($suburb ne $new_suburb)) {
        $diff++;
        print $lfh "memberID=$mem_ref->{'intMemberID'}|$name_before|$name_after\n" if $name_before ne $name_after;
        print $lfh "memberID=$mem_ref->{'intMemberID'}|name=$name_after|$suburb|$new_suburb\n" if $suburb ne $new_suburb;
        if ($update) {
            my $member_id = $mem_ref->{'intMemberID'};
            my $st = qq[UPDATE tblMember SET strFirstname=?, strSurname=?, strSuburb=?  WHERE intMemberID=?];
            my $q = $dbh->prepare($st);
            $q->execute($new_first_name, $new_surname, $new_suburb, $member_id);
            $q->finish;
            $upd++;
        }
    }

    return ($diff, $upd);
}

sub process_clubs {
    my ($dbh, $lfh, $assoc_id, $case_rules, $update) = @_;

    my $sql = qq[
        SELECT ac.intClubID, c.strName 
        FROM tblAssoc_Clubs ac 
            INNER JOIN tblClub c ON ac.intClubID=c.intClubID
        WHERE ac.intAssocID=?];
    my $query = $dbh->prepare($sql);

    $query->execute($assoc_id);

    my $diff_count = 0;
    my $upd_count  = 0;

    while (my $href = $query->fetchrow_hashref()) {
        my ($diff, $upd) = process_club($dbh, $lfh, $href, $case_rules, $update);
        $diff_count++ if $diff;
        $upd_count++   if $upd;
    }

    print_count($lfh, 'club', $diff_count, 'different in assoc') if $diff_count;
    print_count($lfh, 'club', $upd_count, 'updated in assoc') if $update and $upd_count;
    print_underline($lfh) if $diff_count or $upd_count;

    return ($diff_count, $upd_count);

}

sub process_club {
    my ($dbh, $lfh, $club_ref, $case_rules, $update) = @_;

    my $type = 'Club';
    my $name = $club_ref->{'strName'};
    my $new_name = apply_field_case_rule($case_rules, $type, 'strName', $name);
    my $diff = 0;
    my $upd  = 0;

    if ($name ne $new_name) {
        $diff++;
        print $lfh "clubID=$club_ref->{'intClubID'}|$name|$new_name\n";
        if ($update) {
            my $club_id = $club_ref->{'intClubID'};
            my $st = qq[UPDATE tblClub SET strName=? WHERE intClubID=?];
            my $q = $dbh->prepare($st);
            $q->execute($new_name, $club_id);
            $q->finish;
            $upd++;
        }
    }

    return ($diff, $upd);
}

sub process_comps {
    my ($dbh, $lfh, $assoc_id, $case_rules, $update) = @_;

    my $sql = qq[SELECT intCompID, strTitle FROM tblAssoc_Comp WHERE intAssocID=?];
    my $query = $dbh->prepare($sql);

    $query->execute($assoc_id);

    my $diff_count = 0;
    my $upd_count  = 0;

    while (my $href = $query->fetchrow_hashref()) {
        my ($diff, $upd) = process_comp($dbh, $lfh, $href, $case_rules, $update);
        $diff_count++ if $diff;
        $upd_count++   if $upd;
    }

    print_count($lfh, 'comp', $diff_count, 'different in assoc') if $diff_count;
    print_count($lfh, 'comp', $upd_count, 'updated in assoc') if $update and $upd_count;
    print_underline($lfh) if $diff_count or $upd_count;

    return ($diff_count, $upd_count);

}

sub process_comp {
    my ($dbh, $lfh, $comp_ref, $case_rules, $update) = @_;

    my $type = 'Comp';
    my $title = $comp_ref->{'strTitle'};
    my $new_title = apply_field_case_rule($case_rules, $type, 'strTitle', $title);
    my $diff = 0;
    my $upd  = 0;

    if ($title ne $new_title) {
        $diff++;
        print $lfh "compID=$comp_ref->{'intCompID'}|$title|$new_title\n";
        if ($update) {
            my $comp_id = $comp_ref->{'intCompID'};
            my $st = qq[UPDATE tblAssoc_Comp SET strTitle=? WHERE intCompID=?];
            my $q = $dbh->prepare($st);
            $q->execute($new_title, $comp_id);
            $q->finish;
            $upd++;
        }
    }

    return ($diff, $upd);
}

sub process_teams {
    my ($dbh, $lfh, $assoc_id, $case_rules, $update) = @_;

    my $sql = qq[SELECT intTeamID, strName FROM tblTeam WHERE intAssocID=?];
    my $query = $dbh->prepare($sql);

    $query->execute($assoc_id);

    my $diff_count = 0;
    my $upd_count  = 0;

    while (my $href = $query->fetchrow_hashref()) {
        my ($diff, $upd) = process_team($dbh, $lfh, $href, $case_rules, $update);
        $diff_count++ if $diff;
        $upd_count++   if $upd;
    }

    print_count($lfh, 'team', $diff_count, 'different in assoc') if $diff_count;
    print_count($lfh, 'team', $upd_count, 'updated in assoc') if $update and $upd_count;
    print_underline($lfh) if $diff_count or $upd_count;

    return ($diff_count, $upd_count);

}

sub process_team {
    my ($dbh, $lfh, $team_ref, $case_rules, $update) = @_;

    my $type = 'Team';
    my $name = $team_ref->{'strName'};
    my $new_name = apply_field_case_rule($case_rules, $type, 'strName', $name);
    my $diff = 0;
    my $upd  = 0;

    if ($name ne $new_name) {
        $diff++;
        print $lfh "teamID=$team_ref->{'intTeamID'}|$name|$new_name\n";
        if ($update) {
            my $team_id = $team_ref->{'intTeamID'};
            my $st = qq[UPDATE tblTeam SET strName=? WHERE intTeamID=?];
            my $q = $dbh->prepare($st);
            $q->execute($new_name, $team_id);
            $q->finish;
            $upd++;
        }
    }

    return ($diff, $upd);
}

sub print_params {
    my ($lfh, $realm_id, $subrealm_id, $assoc_id, $clubs_also, $clubs_only, $comps_also, $comps_only, $teams_also, $teams_only, $update) = @_;
    my $line = '';
    $line  = "--realm=$realm_id "       if $realm_id;
    $line .= "--subrealm=$subrealm_id " if defined $subrealm_id;
    $line .= "--assoc=$assoc_id "       if $assoc_id;
    $line .= "--clubs_also "            if $clubs_also;
    $line .= "--clubs_only "            if $clubs_only;
    $line .= "--comps_also "            if $comps_also;
    $line .= "--comps_only "            if $comps_only;
    $line .= "--teams_also "            if $teams_also;
    $line .= "--teams_only "            if $teams_only;
    $line .= "--update\n"               if $update;
    print $lfh "$line\n";
    print_underline($lfh);
    return 1;
}

sub print_count {
    my ($lfh, $what, $count, $text) = @_;

    my $hm_text = "$count $what";
    $hm_text .= 's' if $count != 1;

    print  $lfh "$hm_text $text.\n";

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
    my $realm_id    = 0;
    my $subrealm_id;
    my $assoc_id    = 0;
    my $clubs_also  = 0;
    my $clubs_only  = 0;
    my $comps_also  = 0;
    my $comps_only  = 0;
    my $teams_also  = 0;
    my $teams_only  = 0;
    my $update      = 0;

    GetOptions(
        'realm=i'=>\$realm_id, 
        'subrealm=i'=>\$subrealm_id, 
        'assoc=i'=>\$assoc_id, 
        'clubs_also'=>\$clubs_also, 
        'clubs_only'=>\$clubs_only, 
        'comps_also'=>\$comps_also, 
        'comps_only'=>\$comps_only, 
        'teams_also'=>\$teams_also, 
        'teams_only'=>\$teams_only, 
        'update'=>\$update
   );

    if (defined $subrealm_id and !$realm_id) {
        usage('A subrealmID cannot be entered without a realmID.');
        exit;
    }

    if (!($realm_id or $assoc_id) or ($realm_id and $assoc_id)) {
        usage('Either a realmID, realmID/subrealmID or an assocID must be entered.');
        exit;
    }

    if ($clubs_also and $clubs_only) {
        usage('clubs_also and clubs_only are mutually exclusive.');
        exit;
    }

    if ($comps_also and $comps_only) {
        usage('comps_also and comps_only are mutually exclusive.');
        exit;
    }

    if ($teams_also and $teams_only) {
        usage('teams_also and teams_only are mutually exclusive.');
        exit;
    }

    if ($clubs_only and $comps_only and $teams_only) {
        usage('clubs_only, comps_only and teams_only are mutually exclusive.');
        exit;
    }

    return ($realm_id, $subrealm_id, $assoc_id, $clubs_also, $clubs_only, $comps_also, $comps_only, $teams_also, $teams_only, $update);
}

sub usage {
    my ($error) = @_;
    print "\nError:\n";
    print "\t$error\n";
    print "\tusage: $0 --realm=n --subrealm=n --assoc=n --clubs_also --clubs_only --comps_also --comps_only --teams_also --teams_only --update\n\n";
}
