#!/usr/bin/perl

#
# $Header: svn://svn/SWM/trunk/misc/moveClubMembers.pl 8250 2013-04-08 08:24:36Z rlee $
#

use strict;
use lib '..','../web', '../web/comp';
use Utils;
use Getopt::Long;
use ClubObj;

my $update = 1;
my $fromClub;
my $toClub;
my $season;


GetOptions ('from=i'=>\$fromClub,'to=i'=>\$toClub, 'season=i'=>\$season);

if (!$fromClub || !$toClub || !$season) { 
    &usage('Please provide the from and to club IDs and the season');
}

my $dbh = connectDB();
my $seasonName = seasonName($season);

my ($fromClubName,$fromClubAssocID,$fromClubAssocName,$fromSeason) = clubAssocDetails($fromClub);
my ($toClubName,$toClubAssocID,$toClubAssocName,$toSeason) = clubAssocDetails($toClub);

print "\nMoving members from $fromClubName - $fromClubAssocName to $toClubName - $toClubAssocName, Continue? (Y/N):";
my $response = <STDIN>;
chomp $response;

if (uc($response) ne 'Y') {
    print "Scripting terminating...\n";
    print "You have chosen not to move the members\n\n";
    exit;
}

my $clubObj = new ClubObj(('db'=>$dbh, 'assocID'=>$fromClubAssocID, 'ID'=>$fromClub));

my $Players = $clubObj->playersNotClearedOut();


my $NonPlayers = $clubObj->activeNonPlayers($season);
print "Count of Players: ", scalar keys %{$Players}, "\n";
print "Count of Non Players: ", scalar keys %{$NonPlayers}, "\n";


my $Members = $Players;

my $seasonPlayerCount = 0;
my $otherSeasonPlayerCount = 0;
foreach my $player(keys %{$Players}) {
    my $SeasonRecord = $clubObj->seasonClubRecord($player,$season);
    if ($SeasonRecord) {
        $seasonPlayerCount++;
    }
    else {
        $otherSeasonPlayerCount++;
    }
}


my $officialAndPlayer = 0;
foreach my $nonplayer (keys %{$NonPlayers}) {
    if (exists($Members->{$nonplayer})) {
        $Members->{$nonplayer}->{playerofficial} = 1;
        print "Member:$nonplayer is a player and a nonplayer\n";
        $officialAndPlayer++;
    }
    else {
        $Members->{$nonplayer} = $NonPlayers->{$nonplayer};
    }
}
print "Count of PlayerOfficials: $officialAndPlayer\n";

print "Count of All Members: ", scalar keys %{$Members}, "\n";

my $log_file = 'moveClubMembers_' . $fromClub . '-' . $toClub . '.log';

open(LOG,">$log_file") || die "Couldn't open log file $log_file:$!\n";
print LOG "$fromClubName,$fromClubAssocName to $toClubName,$toClubAssocName\n";

my $count = 0;

foreach my $memberID (keys %{$Members}) {
    my $name = $Members->{$memberID}->{firstname} . ' ' .  $Members->{$memberID}->{surname};
    print LOG "Member:$memberID\n" if $update;
    print "Moving member: $memberID - $name\n";# if $update;
 
    if ($update) {
        $clubObj->copyMemberToNewClub($memberID, $Members->{$memberID}, $toClub, $toClubAssocID, $season);
    }
    $count++;
}

print "Moved $count members\n\n";
print "Season $season count: $seasonPlayerCount\n";
print "Season other count: $otherSeasonPlayerCount\n";

close LOG;
exit;

sub clubAssocDetails {
    my $ID = shift;
    
    my ($clubName,$assocID,$assocName,$seasonID) = 
        $dbh->selectrow_array(qq[
                                 SELECT tblClub.strName,tblAssoc.intAssocID,tblAssoc.strName,intCurrentSeasonID
                                 FROM tblAssoc_Clubs 
                                 INNER JOIN tblClub ON (tblClub.intClubID = tblAssoc_Clubs.intClubID)
                                 INNER JOIN tblAssoc ON (tblAssoc.intAssocID = tblAssoc_Clubs.intAssocID)
                                 WHERE tblClub.intClubID = $ID]);

    return ($clubName,$assocID,$assocName,$seasonID);
}


sub seasonName {
    my $ID  = shift;
   
    my ($seasonName) = $dbh->selectrow_array(qq[
                                                SELECT strSeasonName FROM tblSeasons WHERE intSeasonID = $ID
                                            ]);
    
    return $seasonName;
    
}

sub usage {
    my $error = shift;
    print "\nERROR:\n";
    print "\t$error\n";
    print "\tusage:./moveClubMembers.pl --from from_club_id --to to_club_id --season season_id\n\n";

    exit;
}
