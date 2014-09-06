#!/usr/bin/perl

#
# $Header: svn://svn/SWM/trunk/misc/find_players_multiple_clubs.pl 10189 2013-12-08 21:51:32Z tcourt $
#

use strict;
use lib '..','../web', '../web/comp';
use Getopt::Long;
use List::Util qw(max);

use Defs;
use DBI;
use Utils;

use constant PRIMARY_CLUB_LOG  => 'primary_club_set.log';
use constant INACTIVE_CLUB_LOG => 'marked_as_inactive_in_club.log';
use constant COMBINED_CLUB_LOG => 'combined_club.log';

my $debug = 1;

my $realm;
my $sub_realm;
my $yob;
my $national_num;

GetOptions('realm=i'=>\$realm, 'subrealm:i'=>\$sub_realm, 'year-of-birth-before:i'=>\$yob, 'national-num:s'=>\$national_num);

if (!$realm || !$sub_realm){ 
    &usage('Please provide the realm you wish to report on.');
}

my $yob_where = '';
if ($yob) {
    if ($yob !~/^\d{4}$/){
        print "Please check the year-of-birth-less-than value you supplied ($yob).\n";
        print "Script terminating...\n";
        exit;
    }
    else {
        $yob_where = qq[AND YEAR(dtDOB) < $yob];
    }
}

my $nationalnum_where ='';
if ($national_num) {
    #$nationalnum_where = qq[AND strNationalNum = "$national_num"];
    $nationalnum_where = qq[
        AND concat(strSurname, '|', strFirstName, '|', date_format(dtDOB, '%d/%m/%Y'))=
            (select concat(m2.strSurname, '|', m2.strFirstName, '|', date_format(m2.dtDOB, '%d/%m/%Y')) from tblMember as m2 where m2.strNationalNum="$national_num")
    ];
}

my $member_query = qq[
                      SELECT 
                          DISTINCT strSurname, strFirstname, dtDOB, tblMember.intMemberID, strNationalNum, dtCreatedOnline,
                                   tblClub.strName AS ClubName, tblClub.intClubID, tblClub.intAgeTypeID, tblNode.strName AS StateLeague, tblAssoc.strName AS AssocName, tblAssoc.intAssocID
                      FROM tblMember
                      INNER JOIN tblMember_Clubs ON (tblMember_Clubs.intMemberID = tblMember.intMemberID)
                      INNER JOIN tblMember_Seasons_$realm AS MS ON (MS.intMemberID = tblMember.intMemberID AND MS.intClubID = tblMember_Clubs.intClubID AND MS.intMSRecStatus != $Defs::RECSTATUS_DELETED AND MS.intPlayerStatus = 1)
                      INNER JOIN tblClub ON (tblClub.intClubID = tblMember_Clubs.intClubID)
                      INNER JOIN tblAssoc_Clubs ON (tblAssoc_Clubs.intClubID = tblClub.intClubID) 
                      INNER JOIN tblAssoc ON (tblAssoc.intAssocID = tblAssoc_Clubs.intAssocID) 
                      INNER JOIN tblTempNodeStructure ON (tblTempNodeStructure.intAssocID = tblAssoc.intAssocID)
                      INNER JOIN tblNode ON (tblNode.intNodeID = int20_ID)
                      LEFT JOIN tblMember_ClubsClearedOut as MCCO ON (MCCO.intMemberID=tblMember.intMemberID and MCCO.intClubID=tblMember_Clubs.intClubID)
                      WHERE tblAssoc.intRealmID = $realm
                      AND tblAssoc.intAssocTypeID = $sub_realm
                      AND tblMember_Clubs.intPermit = 0
                      AND tblMember.intStatus IN (0,1,2)
                      AND tblMember_Clubs.intStatus IN (0,1)
                      AND strSurname IS NOT NULL AND strFirstname IS NOT NULL
                      AND MCCO.intMemberID IS NULL
                      $nationalnum_where
                      $yob_where
                     ];


my $dbh = connectDB();
my $sth = $dbh->prepare($member_query); 
$sth->execute();

my %multiple_clubs = ();
my %players = ();
my $count = 1;

while (my $href = $sth->fetchrow_hashref()) {
    my $surname = $href->{strSurname};
    my $firstname = $href->{strFirstname};
    my $dob = $href->{dtDOB};
    my $footywebnum = $href->{strNationalNum};
#print "surname=$surname | firstname=$firstname | dob=$dob | footywebnum=$footywebnum\n"; #micktemp
    my $member_id = $href->{intMemberID};
    my $club_id = $href->{intClubID};

    # Make sure they weren't only on permit to this club.
    if (check_permits($dbh, $member_id, $club_id)) {
        next;
    }
    
    # This shouldn't happen but make sure club is only from the leagues realm.
    if (!check_club($dbh, $club_id)) {
        next;
    }

    my $key = lc("$surname$firstname$dob$footywebnum"); 
    if (exists $players{$key}) { # We've already encountered a person with this name and date of birth.
        if (not exists $multiple_clubs{$key}) {
            my $first_record = $players{$key};
            push @{$multiple_clubs{$key}}, $first_record;
        }
        push @{$multiple_clubs{$key}}, $href;
    }
    else {
         $players{$key} = $href;
     } 
}

$sth->finish();


my %players_by_state = ();

foreach my $player(keys %multiple_clubs) {
    print "Player:$player\n";

    
    my %last_played = ();
    my %player_states = ();
    my @player_clubs = ();
    my $player_state = '';
    my $club_count = scalar @{$multiple_clubs{$player}};
    print "Club count: $club_count\n";
    
    my $has_last_played_date = 0;
    my %season_records = ();
    my $member_id = '';
    my $footyweb_num = '';
    my $primary_club_set = 0;
    my %clubs_set_as_inactive = ();
    
    # General Glub
    if (!all_clubs_general($multiple_clubs{$player})) {
        for (my $i = $#{$multiple_clubs{$player}}; $i > -1; $i--) {
            # Check that all club aren't General Club
            my $club_id = $multiple_clubs{$player}[$i]->{intClubID};
            my $club_name = $multiple_clubs{$player}[$i]->{ClubName};
            $member_id = $multiple_clubs{$player}[$i]->{intMemberID};
            $footyweb_num = $multiple_clubs{$player}[$i]->{strNationalNum};
            
            if ($club_count == 1) { # Mark this as their primary club and move onto next member.
                set_as_primary_club($dbh, $member_id, $footyweb_num, $club_id);
                $primary_club_set =1;
                last;
            }
            
            if ($club_name eq 'General Club' && $club_count != 1) {
                set_as_inactive_in_club($dbh, $member_id, $footyweb_num, $club_id, 'General Club') if !defined $clubs_set_as_inactive{$club_id};
                $clubs_set_as_inactive{$club_id} = 1;
                $club_count--;
                splice @{$multiple_clubs{$player}}, $i, 1;
                next; # might be multiple General Clubs, so keep checking.
            }
        }
    }
    
    next if $primary_club_set;
    
    
    # 2 If club is a club that a member shouldn't have as his primary club.
    #foreach my $club (@{$multiple_clubs{$player}}) {
    if (!all_clubs_not_allowed_as_primary_club($multiple_clubs{$player})) {
        for (my $i = $#{$multiple_clubs{$player}}; $i > -1; $i--) {
            my $club_id = $multiple_clubs{$player}[$i]->{intClubID};
            my $club_name = $multiple_clubs{$player}[$i]->{ClubName};
            $member_id = $multiple_clubs{$player}[$i]->{intMemberID};
            $footyweb_num = $multiple_clubs{$player}[$i]->{strNationalNum};
            
            if ($club_count == 1) { # Mark this as there primary club and move onto next member along as it's a club that's OK to have as a primary club.
                set_as_primary_club($dbh, $member_id, $footyweb_num, $club_id);
                $primary_club_set =1;
                last;
            }
            
            my ($assoc_id) = $dbh->selectrow_array(qq[SELECT intAssocID FROM tblAssoc_Clubs WHERE intClubID = $club_id]);
            if ($assoc_id =~/^(4138|8164)$/ && $club_count != 1) {
                set_as_inactive_in_club($dbh, $member_id, $footyweb_num, $club_id, 'Not a club that a player can have as their primary club') if !defined $clubs_set_as_inactive{$club_id};
                $clubs_set_as_inactive{$club_id} = 1;
                $club_count--;
                splice @{$multiple_clubs{$player}}, $i, 1;
                next;
            }
        }
    }
    next if $primary_club_set;
    
    
    # 3 If they're over the age of 18 and club is a junior club mark them as inactive.
    if (!all_clubs_junior($multiple_clubs{$player})) {
        for (my $i = $#{$multiple_clubs{$player}}; $i > -1; $i--) {
            #    foreach my $club (@{$multiple_clubs{$player}}) {
            my $club_age_type =  $multiple_clubs{$player}[$i]->{intAgeTypeID};
            my $club_id = $multiple_clubs{$player}[$i]->{intClubID};
            my $club_name = $multiple_clubs{$player}[$i]->{ClubName};
            $member_id = $multiple_clubs{$player}[$i]->{intMemberID};
            $footyweb_num = $multiple_clubs{$player}[$i]->{strNationalNum};
            
            my ($year, $month, $day) = split(/\D/,$multiple_clubs{$player}[$i]->{dtDOB});
            my $age = get_age_from_dob($year, int(--$month), int($day));
            if ($club_count == 1) { # Mark this as there primary club and move onto next member as long it's also not a junior club.
                set_as_primary_club($dbh, $member_id, $footyweb_num, $club_id);
                $primary_club_set = 1;
                last;
            }
            
            if ($club_age_type == 1 && $age > 18 && $club_count != 1) { #
                set_as_inactive_in_club($dbh, $member_id, $footyweb_num, $club_id, 'Junior Club') if !defined $clubs_set_as_inactive{$club_id};
                $clubs_set_as_inactive{$club_id} = 1;
                $club_count--;
                splice @{$multiple_clubs{$player}}, $i, 1;
                next;
            } 
            
        }
    }
        
    next if $primary_club_set;
    
    for (my $i = $#{$multiple_clubs{$player}}; $i > -1; $i--) {
        my $club_id = $multiple_clubs{$player}[$i]->{intClubID};
        $member_id = $multiple_clubs{$player}[$i]->{intMemberID};
        $footyweb_num = $multiple_clubs{$player}[$i]->{strNationalNum};
        my $club_name = $multiple_clubs{$player}[$i]->{ClubName};
        
        $player_states{$multiple_clubs{$player}[$i]->{StateLeague}} = 1;
        $player_state = $multiple_clubs{$player}[$i]->{StateLeague};
        
        my $last_played_data  = get_last_played_date($dbh, $realm, $member_id, $club_id);
        my $last_played_date = $last_played_data->{'dtStatTotal2'};
        print "Last played for: $club_name - $last_played_date\n";
        
        $last_played_date =~ s/-//g;
        if ($last_played_date && $last_played_date ne '00000000') {
            $has_last_played_date = 1;
        }
        
        $multiple_clubs{$player}[$i]->{LastPlayed} = $last_played_date;
        my $last_season = get_last_season_record($dbh, $member_id, $club_id, $realm);
        push @{$season_records{$last_season}}, $club_id;
        push @player_clubs, $multiple_clubs{$player}[$i];
    }
    
    my $most_recent_season =  max keys %season_records;
    if ((scalar(@{$season_records{$most_recent_season}}) == 1) && $most_recent_season) {
        foreach my $season (keys %season_records){
            foreach my $club_id (@{$season_records{$season}}) {
                if ($season == $most_recent_season) {
                    set_as_primary_club($dbh, $member_id, $footyweb_num, $club_id);
                }
                else {
                    set_as_inactive_in_club($dbh, $member_id, $footyweb_num, $club_id, 'More recent season record for another club') if !defined $clubs_set_as_inactive{$club_id};
                    $clubs_set_as_inactive{$club_id} = 1;
                }
            }
        }
    }
    elsif ($has_last_played_date) {
        my $last_played_club_id = '';
        my $last_played_club_date = '';
        my @clubs_to_set_as_inactive = ();
        foreach my $club (@player_clubs) {
            my $last_played_date = $club->{LastPlayed};
            if ($last_played_date > $last_played_club_date) {
                $last_played_club_date = $last_played_date;
                if ($last_played_club_id) {
                    push @clubs_to_set_as_inactive, $last_played_club_id;
                }
                $last_played_club_id = $club->{intClubID};
            }
            else {
                push @clubs_to_set_as_inactive, $club->{intClubID};
            }
        }
        foreach my $inactive_club_id (@clubs_to_set_as_inactive) {
            set_as_inactive_in_club($dbh, $member_id, $footyweb_num, $inactive_club_id, 'Played more recently for another club')  if !defined $clubs_set_as_inactive{$inactive_club_id};
            $clubs_set_as_inactive{$inactive_club_id} = 1;
        }
        set_as_primary_club($dbh, $member_id, $footyweb_num, $last_played_club_id);
    } 
    else { # Can't determine there primary club, need to report out.
        print "Unable to determine Primary Club\n";
        if (scalar (keys %player_states) > 1) {
            push @{$players_by_state{'multiple_states'}{$player}}, \@player_clubs;
        }
        else {
            push @{$players_by_state{$player_state}{$player}}, \@player_clubs;
        }
    }   
}

foreach my $state(sort keys %players_by_state) {
    

    (my $state_name = $state) =~s/\s+//g;
    my $log_file = 'players_multiple_clubs_' . $realm . '_' . $state_name .'.csv';
    open my $fh, ">", $log_file or die "$!\n";

    print $fh "-----------------------------------------------------------------------------------------------------\n";
    print $fh "STATE:$state\n";
    print $fh "-----------------------------------------------------------------------------------------------------\n";
    
    foreach my $player (keys %{$players_by_state{$state}}) {
        foreach my $clubs (@{$players_by_state{$state}{$player}}) {
            foreach my $club(@{$clubs}) {
                print $fh $club->{intMemberID}, '|';
                print $fh $club->{strNationalNum}, '|';
                print $fh $club->{strFirstname}, '|';
                print $fh $club->{strSurname}, '|';
                print $fh $club->{dtDOB}, '|';
                print $fh $club->{dtCreatedOnline}, '|';
                print $fh $club->{LastPlayed}, '|';
                print $fh $club->{AssocName}, '|';
                print $fh $club->{intClubID}, '|';
                print $fh $club->{ClubName};
                print $fh "\n";
            }
        }
    }
    close $fh;
}

sub all_clubs_general {
    my $player  = shift;
   
    my $all_clubs_general =1; 
    foreach my $club (@{$player}) {
        if ($club->{ClubName} ne 'General Club') {
            $all_clubs_general = 0;
            last;
        }
    } 
    
    return $all_clubs_general;
}

sub all_clubs_junior {
    my $player = shift;
    
    my $all_clubs_junior = 1;
    foreach my $club (@{$player}) {
        if ($club->{intAgeTypeID} != 1) {
            $all_clubs_junior = 0;
            last;
        }
    } 
    
    return $all_clubs_junior;
}

sub all_clubs_not_allowed_as_primary_club {
    my $player = shift;
    
    my $all_clubs_not_allowed_as_primary_club = 1;
    foreach my $club (@{$player}) {
        if ($club->{intAssocID} !~/(4138|8164)/) {
            $all_clubs_not_allowed_as_primary_club = 0;
            last;
        }
    } 

    return $all_clubs_not_allowed_as_primary_club;
}

sub is_allowed_as_primary_club {
    my ($dbh, $club_id)  = @_;
    
    my ($assoc_id) = $dbh->selectrow_array(qq[SELECT intAssocID FROM tblAssoc_Clubs WHERE intClubID = $club_id]);
    
    if ($assoc_id =~/^(4138|8164)$/) {
        return 0;
    }
    else {
        return 1;
    }
}

sub is_general_club {
    my $club_name = shift;
    
    if ($club_name eq 'General Club') {
        return 1;
    }
    else {
        return 0;
    }
}

sub is_junior_club {
    my ($club_age_type) = shift;

    if ($club_age_type == 1) {
        return 1;
    }
    else {
        return 0;
    }
}

sub unable_to_determine_primary_club {
    my ($player) = shift; 
    
    
    #if (scalar (keys %{$player_states}) > 1) {
    #    push @{$players_by_state{'multiple_states'}{$player}}, $player_clubs;
    #}
    #else {
    #    push @{$players_by_state{$player_state}{$player}}, $player_clubs;
    #}
    exit;
    
    return;
}


sub set_as_inactive_in_club {
    my ($dbh, $member_id, $footyweb_num, $club_id, $reason) = @_;

    my $update = qq[UPDATE tblMember_Clubs
                    SET intStatus = 0 
                    WHERE intMemberID = $member_id
                    AND intClubID = $club_id
                    AND intStatus = 1
                ];
    
    my $sth = $dbh->prepare($update);
    $sth->execute() if !$debug;

    my ($club_name, $assoc_id, $assoc_name)  = $dbh->selectrow_array(qq[SELECT C.strName, AC.intAssocID, A.strName
                                                           FROM tblClub AS C 
                                                           INNER JOIN tblAssoc_Clubs AS AC ON (C.intClubID = AC.intClubID) 
                                                           INNER JOIN tblAssoc AS A ON (A.intAssocID = AC.intAssocID)
                                                           WHERE C.intClubID = $club_id
                                                           AND AC.intRecStatus != $Defs::RECSTATUS_DELETED
                                                           ]);
    
    my $insert = qq[INSERT INTO tblMember_ClubsClearedOut
                   (
                    intMemberID, 
                    intRealmID, 
                    intAssocID,
                    intClubID
                    )
                    VALUES 
                    (
                     $member_id, 
                     $realm, 
                     $assoc_id, 
                     $club_id
                    )
                ];
    
    my $sth2 = $dbh->prepare($insert);
    $sth2->execute() if !$debug;

    # Make sure they're inactive in this association.
    my $assoc_update = qq[UPDATE tblMember_Assocations 
                          SET intRecStatus = 0
                          WHERE intMemberID = $member_id
                          AND intAssocID = $assoc_id
                      ];

    my $sth3 = $dbh->prepare($assoc_update);
    $sth3->execute() if !$debug;
    
    my ($first_name, $surname)  = $dbh->selectrow_array(qq[SELECT strFirstname, strSurname FROM tblMember WHERE intMemberID = $member_id]);
                              
    print "Set as inactive and cleared out from $club_name. ($reason)\n";     
    my $log_file = INACTIVE_CLUB_LOG;
    open (LOG, ">>$log_file") || die "Unable to create log file\n$!\n";
    print LOG "SET AS INACTIVE IN AND CLEARED FROM CLUB:$first_name $surname $member_id-$footyweb_num-$club_id:$assoc_name - $club_name|$reason\n";
    close LOG;
   
    my $combined_log_file = COMBINED_CLUB_LOG;
    open (COMBINED_LOG, ">>$combined_log_file") || die "Unable to create log file\n$!\n";
    print COMBINED_LOG "SET AS INACTIVE IN AND CLEARED FROM CLUB:$first_name $surname $member_id-$footyweb_num-$club_id:$assoc_name - $club_name|$reason\n";
    close COMBINED_LOG;
    
    return;
}

sub set_as_primary_club {
    my ($dbh, $member_id, $footyweb_num, $club_id) = @_;
    
    my $update = qq[UPDATE tblMember_Clubs
                    SET intPrimaryClub = 1 
                    WHERE intMemberID = $member_id
                    AND intClubID = $club_id
                ];
    
    my $sth = $dbh->prepare($update);
    $sth->execute() if !$debug;

    my ($first_name, $surname)  = $dbh->selectrow_array(qq[SELECT strFirstname, strSurname FROM tblMember WHERE intMemberID = $member_id]);
    
    my ($club_name, $assoc_name, $assoc_id)  = $dbh->selectrow_array(
                                                                     qq[
                                                                        SELECT C.strName, A.strName, A.intAssocID
                                                                        FROM tblClub AS C 
                                                                        INNER JOIN tblAssoc_Clubs AC ON (C.intClubID = AC.intClubID)
                                                                        INNER JOIN tblAssoc AS A ON (AC.intAssocID = A.intAssocID)
                                                                        WHERE C.intClubID = $club_id
                                                                        AND AC.intRecStatus != $Defs::RECSTATUS_DELETED
                                                                       ]
                                                                 ); 

    # Make sure they're active in the assoc that their primary club belongs to.
    my $update_assoc = qq[UPDATE tblMember_Associations
                          SET intRecStatus = 1
                          WHERE intMemberID = $member_id
                          AND intAssocID = $assoc_id];


    $sth = $dbh->prepare($update_assoc);
    $sth->execute() if !$debug;

    print "Primary Club set as: $club_name\n";
    
    my $log_file = PRIMARY_CLUB_LOG;
    open (LOG, ">>$log_file") || die "Unable to create log file\n$!\n";
    print LOG "PRIMARY CLUB SET:$first_name $surname $member_id-$footyweb_num,$club_id:$assoc_name - $club_name\n";
    close LOG;
    
    my $combined_log_file = COMBINED_CLUB_LOG;
    open (COMBINED_LOG, ">>$combined_log_file") || die "Unable to create log file\n$!\n";
    print COMBINED_LOG "PRIMARY CLUB SET:$first_name $surname $member_id-$footyweb_num,$club_id:$assoc_name - $club_name\n";
    close COMBINED_LOG;
    
    return;
}



sub get_last_played_date {
    my ($dbh, $realm, $member_id, $club_id) = @_;
    
    my $query = qq[SELECT dtStatTotal2
                   FROM tblPlayerCompStats_$realm
                   WHERE intClubID = $club_id
                   AND intPlayerID = $member_id
                   ORDER BY dtStatTotal2 DESC
                   LIMIT 1
                   ];
    
    my $href= $dbh->selectrow_hashref($query);
    return $href;
}

sub get_age_from_dob {
    my ($birth_day, $birth_month, $birth_year) = @_;
    
    my ($day, $month, $year) = (localtime)[3..5];
    $year += 1900;
    
    my $age = $year - $birth_year;
    $age-- unless sprintf("%02d%02d", $month, $day) >= sprintf("%02d%02d", $birth_month, $birth_day);
    return $age;
}

sub get_last_season_record {
    my ($db, $member_id, $club_id, $realm) = @_;
    
    my $table_member_seasons = 'tblMember_Seasons_' . $realm;
    
    my $update = qq[SELECT intSeasonID 
                    FROM $table_member_seasons
                    WHERE intMemberID = ?
                    AND intClubID = ?
                    AND intMSRecStatus != $Defs::RECSTATUS_DELETED
                    ORDER BY intSeasonID DESC
                    LIMIT 1
                ];
    
    my $sth = $dbh->prepare($update);

    $sth->execute($member_id, $club_id);
    my ($season_id) = $sth->fetchrow_array();
    
    return $season_id;
}

sub check_club {
    my ($dbh, $club_id) = @_;

    my $result = 1;
    my $query = qq[SELECT intAssocTypeID
                   FROM tblAssoc INNER JOIN tblAssoc_Clubs ON (tblAssoc_Clubs.intAssocID = tblAssoc.intAssocID)
                   WHERE intClubID = $club_id];

    my $club_sub_realm = $dbh->selectrow_array($query);
    
    if ($club_sub_realm != $sub_realm) {
        $result = 0;
    }

    return $result;
}


sub check_permits {
    my ($dbh, $member_id, $club_id) = @_;

    my $query = qq[SELECT intPermitType, dtFinalised FROM tblClearance WHERE intDestinationClubID = $club_id AND intMemberID = $member_id ORDER BY dtFinalised];
    my $permits = $dbh->selectall_arrayref($query);
    
    my $result = 0;
    foreach my $clearance (@{$permits}) {
        if ($clearance->[0] == 0) {
            $result = 0; # It wasn't a permit, so could be their primary club.
        }
        else { # It was only a permit, so can't be a club that's considered their primary club.
            $result = 1;
        }
    }

    return $result;
}

sub usage {
    my $error = shift;
    print "\nERROR:\n";
    print "\t$error\n";
    print "\tusage:./find_players_multiple_clubs.pl --realm realm_id --subrealm sub_realm_id --year-of-birth-before --national-num national_number\n\n";
    exit;
}


