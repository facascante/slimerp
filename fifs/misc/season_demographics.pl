#!/usr/bin/perl

#
# $Header: svn://svn/SWM/trunk/misc/season_demographics.pl 9486 2013-09-10 04:55:06Z tcourt $
#

use strict;
use lib '..','../web', '../web/comp';

use Defs;
use Utils;

use Text::CSV_XS;
use Getopt::Long;

my $season;
my $realm;

GetOptions('season=i'=>\$season, 'realm=i'=>\$realm);

if (!$season or !$realm){ 
    &usage('Please provide the realm (ID) and season (ID) you wish to report on.');
    exit;
}

my $dbh = connectDB();
my ($season_name) = $dbh->selectrow_array(qq[SELECT strSeasonName FROM tblSeasons WHERE intSeasonID = $season]);

if ($season_name) {
    print "Reporting on $season_name\n";
}
else {
    print "Please check the season id you provided. It does not appear to be a valid ID.\n";
    print "Script terminating...\n";
    exit;
    
}
my $table_member_season = "tblMember_Seasons_$realm";

# We need break down of data at a National - int100ID, State - int30ID, Region - int20_ID and Zone int10_ID.
my $query = qq[SELECT DISTINCT 
                               tblMember.intMemberID,
                               strNationalNum,
                               strFirstname,
                               strSurname,
                               IF(intGender = 1, 'M', 'F') AS intGender,
                               dtDOB,
                               MONTHNAME(dtDOB) AS MonthOfBirth,
                               strPlaceOfBirth,
                               intPlayerAgeGroupID,
                               tblClub.strName AS ClubName,
                               tblAssoc.strName AS AssocName,
                               Zone.strName AS ZoneName,
                               Region.strName AS RegionName,
                               State.strName AS StateName,
                               National.strName AS NationalName 
               FROM tblMember 
               INNER JOIN $table_member_season ON (tblMember.intMemberID  = $table_member_season.intMemberID)
               INNER JOIN tblAssoc ON (tblAssoc.intAssocID = $table_member_season.intAssocID)
               LEFT JOIN tblClub ON (tblClub.intClubID = $table_member_season.intClubID)
               LEFT JOIN tblTempNodeStructure ON (tblTempNodeStructure.intAssocID  = $table_member_season.intAssocID)
               LEFT JOIN tblNode AS National ON (National.intNodeID = tblTempNodeStructure.int100_ID)
               LEFT JOIN tblNode AS State ON  (State.intNodeID = tblTempNodeStructure.int30_ID)              
               LEFT JOIN tblNode AS Region ON (Region.intNodeID = tblTempNodeStructure.int20_ID)
               LEFT JOIN tblNode AS Zone ON (Zone.intNodeID = tblTempNodeStructure.int10_ID)
               WHERE $table_member_season.intSeasonID = $season
               AND $table_member_season.intClubID != 0
               AND $table_member_season.intMSRecStatus != $Defs::RECSTATUS_DELETED
               AND tblMember.intPlayer = 1
               LIMIT 100
           ];

#

my $sth = $dbh->prepare($query); 
$sth->execute();

my $file_name = 'members_' . $season_name . '.csv';
my $csv = Text::CSV_XS->new ( { binary => 1, sep_char=>'|', eol => "\r\n"}  )  or die "Cannot use CSV: ".Text::CSV->error_diag ();
open my $fh, ">:encoding(utf8)", $file_name or die "$file_name: $!";

    
my @field_names =  (
                    'ARLID No',
                    'First Name', 
                    'Family Name', 
                    'Date of birth',
                    'Year of birth',
                    'Month of birth',
                    'Place of birth',
                    'Gender',
                    'Season Active ?',
                    'Player Active ?',
                    'Season',
                    'Club Name',
                    'League Name',
                    'Division Name',
                    'Zone Name',
                    'State governing body name',
                    );
    
$csv->print($fh, \@field_names);

while (my $href = $sth->fetchrow_hashref()) {
    my @data = ();
    my $index = 0;
    
    $data[$index++] = $href->{strFirstname};    
    $data[$index++] = $href->{strSurname};    
    
    # Checking example.
    if ($href->{intEthnicityID} == 433537) {
        $data[$index++] = 'TRUE';
    }
    else {
        $data[$index++] = '';
    }

    $csv->print($fh, \@data);
    
}

exit;

sub usage {
    my $error = shift;
    print "\nERROR:\n";
    print "\t$error\n";
    print "\tusage:./season_demographics.pl --realm realm_id --season season_id\n\n";
}
