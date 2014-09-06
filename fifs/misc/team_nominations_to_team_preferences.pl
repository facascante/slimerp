#!/usr/bin/perl

#
# $Header: svn://svn/SWM/trunk/misc/team_nominations_to_team_preferences.pl 8250 2013-04-08 08:24:36Z rlee $
#

use strict;
use lib '..','../web', '../web/comp';
use Utils;
use Defs;

my $log_file = 'team_nominations_to_team_preferences.log'; 
open (LOG, ">$log_file") || die "Unable to create log file\n$!\n";


my $dbh = connectDB();
my $query = qq[SELECT 
               tblTeamNominations.*, tblTeam.strName AS TeamName, tblDefVenue.strName AS VenueName
               FROM tblTeamNominations
               INNER JOIN tblTeam ON (tblTeam.intTeamID = tblTeamNominations.intTeamID)
               INNER JOIN tblDefVenue ON (tblDefVenue.intDefVenueID = tblTeamNominations.intPrefVenueID) 
               WHERE intStatus = $Defs::TEAM_ENTRY_STATUS_ACCEPTED AND (intPrefVenueID IS NOT NULL AND strPrefStartTime IS NOT NULL)
               AND tblTeamNominations.intTeamID > 0
               AND tblTeamNominations.intAssocID = 16414
               ORDER BY intCompID
               ];

my $sth = $dbh->prepare($query); 
$sth->execute();

while (my $dref = $sth->fetchrow_hashref()) {
    my $team_name = $dref->{TeamName};
    my $team_id = $dref->{intTeamID};
    my $venue_name = $dref->{VenueName};
    my $venue_id = $dref->{intPrefVenueID};
    my $starttime = $dref->{strPrefStartTime};
    my $nomination_id = $dref->{intTeamNominationID};
    $starttime .= ':00' if $starttime;
    print "\nUpdating team nomination: $nomination_id for team:$team_name - $team_id\n";
    
    if ($venue_id) {
        print "Setting team venue preference to $venue_name\n";
        print LOG "$team_id:intVenue1ID:$venue_id\n";
        $dbh->do(qq[UPDATE tblTeam SET intVenue1ID = $venue_id WHERE intTeamID = $team_id AND intVenue1ID != 0 LIMIT 1]);
    }
    if ($starttime) {
        print "Setting team starttime preference to $starttime\n";
        print LOG "$team_id:dtStartTime1:$starttime\n";
        $dbh->do(qq[UPDATE tblTeam SET dtStartTime1 = '$starttime' WHERE intTeamID = $team_id AND dtStartTime1 IS NULL LIMIT 1])
    }
}
close LOG;

exit;
