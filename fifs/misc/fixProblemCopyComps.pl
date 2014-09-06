#!/usr/bin/perl

#
# $Header: svn://svn/SWM/trunk/misc/fixProblemCopyComps.pl 9482 2013-09-10 04:46:19Z tcourt $
#

use strict;
use lib '..','../web', '../web/comp', '../web/sportstats', '../web/SMS', '../web/dashboard', '../web/gendropdown';
use Utils;
use CompObj;
use Team;

my $update = 0;
my $problemCompID = $ARGV[0];

if (!$update) {
    print "Run through only, no updates will be performed\n\n";
    sleep 5;
}


if (!$problemCompID) { 
    &usage('Please provide ID of comp you want to fix.');
}

print "Problem Comp ID:   $problemCompID\n";


my $dbh = connectDB();

my $CopyCompTeams = CompObj->getTeams($dbh,$problemCompID);

my %TeamFields = (
                  'intTeamID'=>{action=>'skip'},
                  'tTimeStamp'=>{action=>'skip'}
              );

my %NewCompTeams = ();


my $log_file = 'fixProblemCopyComps.' . $problemCompID . '.log';

open (LOG, ">$log_file") || die "Unable to create log file\n$!\n";
print LOG "Processing Competition: $problemCompID\n";

print "Getting teams.\n";
foreach my $team (keys %{$CopyCompTeams}) {
    print " - Team: $team\n";   
    print LOG "Team: $team\n";
    # Create a new instance of this team.
    my $dref = $dbh->selectrow_hashref("SELECT * FROM tblTeam WHERE intTeamID = $team");
    my @Fields;
    my @Values;
    
    while (my($field,$value) = each %{$dref}) {
        next if exists($TeamFields{$field}->{action}) && $TeamFields{$field}->{action} eq 'skip';
        $value = $dbh->quote($value);
        push (@Values,$value);
        push (@Fields,$field);
        
    }
    
    my $fields = join (',',@Fields);
    my $values = join(',', @Values);
    my $sth = $dbh->prepare("INSERT INTO tblTeam ($fields) VALUES ($values)");
    
    $sth->execute() || die "Unable to create new team\n$!\n" if $update;
    
    my $new_team = $dbh->{mysql_insertid};
    
    print " - Updating tblComp_Teams and tblCompMatches to new teamID: $new_team\n\n";
    print LOG " - Updating tblComp_Teams and tblCompMatches to new teamID: $new_team\n\n";

    # Update tblComp_Teams 
    $dbh->do("UPDATE tblComp_Teams SET intTeamID = $new_team WHERE intCompID = $problemCompID AND intTeamID = $team") || die "Unable to update tblComp_Teams and set intTeamID to new team ID\n$!\n" if $update;
    
    
    # Update tblComp_Matches Home Team
    my $query3 = "UPDATE tblCompMatches SET intHomeTeamID = $new_team WHERE intCompID = $problemCompID AND intHomeTeamID = $team"; 
    $dbh->do($query3) || die "Unable to update tblComp_Matches and set intTeamID to new team ID\n$!\n" if $update;
    
    
    # Update tblComp_Matches Away Team
    $dbh->do("UPDATE tblCompMatches SET intAwayTeamID = $new_team WHERE intCompID = $problemCompID AND intAwayTeamID = $team") || die "Unable to update tblComp_Matches and set intTeamID to new team ID\n$!\n" if $update;
    
}

print LOG "\n";
print "\nDone!\n";
exit;

sub usage {
    my $error = shift;
    print "\nERROR:\n";
    print "\t$error\n";
    print "\tusage:./fixProblemCopyComps.pl ProblemCompID\n\n";

#    print "\tusage:./fixProblemCopyComps.pl ProblemCompID CopyCompID\n\n";
    exit;
}

