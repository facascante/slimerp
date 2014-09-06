#!/usr/bin/perl

#
# $Header: 
#

use strict;

use lib '.', '..','../web', '../web/comp';

use Defs;
use Utils;

use Text::CSV_XS;
use Getopt::Long;

my $current_season_id;
my $previous_season_id;


GetOptions('current-season=i'=>\$current_season_id, 'previous-season=i'=>\$previous_season_id);

if (!$current_season_id || !$previous_season_id){ 
    &usage('Please provide the previous season (ID) and current_season id you wish to report on.');
    exit;
}

my $dbh = connectDB();
my ($previous_season_name) = $dbh->selectrow_array(qq[SELECT strSeasonName FROM tblSeasons WHERE intSeasonID = $previous_season_id]);
my ($current_season_name) =  $dbh->selectrow_array(qq[SELECT strSeasonName FROM tblSeasons WHERE intSeasonID = $current_season_id]);

if ($current_season_name && $previous_season_name) {
    print "Reporting on $previous_season_name and $current_season_name\n";
    sleep 5;
}
else {
    print "Please check the season ids youprovided. One or more may not be a valid.\n";
    print "Script terminating...\n";
    exit;
    
}

my $file = create_data_file($dbh);
    
print "Finished\n";

exit;


sub create_data_file {
    my $dbh = shift;

    my $assoc_previous_season = 'Assoc' . $previous_season_name;
    my $assoc_current_season  = 'Assoc' . $current_season_name;
    
    my $assoc_count_previous_season = 'AssocCount' . $previous_season_name;
    my $assoc_count_current_season  = 'AssocCount' . $current_season_name;
 
    my $ms_previous_season = 'PreviousSeason' . $previous_season_name;
    my $ms_current_season =  'CurrentSeason' . $current_season_name;
    
    my $assoc_realm_subtype_current = 'Assoc' . $current_season_name . 'RealmSubType';
    
    
    my $st = qq[
                SELECT
                Region.strName AS Region,
                State.strName AS State,
                $assoc_previous_season.intAssocID AS PreviousSeasonAssocID,
                $assoc_previous_season.strName AS PreviousSeasonAssocName,
                COUNT(DISTINCT $ms_previous_season.intMemberID) as $assoc_count_previous_season,
                $assoc_current_season.intAssocID AS CurrentSeasonAssocID,
                $assoc_current_season.strName AS CurrentSeasonAssocName,
                COUNT(DISTINCT $ms_current_season.intMemberID) as $assoc_count_current_season
                FROM
                tblAssoc as $assoc_previous_season
                INNER JOIN tblMember_Seasons_2 AS $ms_previous_season ON 
                (
                 $ms_previous_season.intAssocID=$assoc_previous_season.intAssocID
                 AND $ms_previous_season.intMSRecStatus=1
                 AND $ms_previous_season.intSeasonID=$previous_season_id
                )
                INNER JOIN tblMember as M ON (M.intMemberID=$ms_previous_season.intMemberID AND M.intRealmID=2)
                INNER JOIN tblTempNodeStructure as T ON (T.intAssocID=$assoc_previous_season.intAssocID)
                LEFT JOIN tblMember_Seasons_2 as $ms_current_season ON 
                (
                 $ms_current_season.intMemberID = $ms_previous_season.intMemberID
                 AND $ms_current_season.intSeasonID=$current_season_id
                )  
                LEFT JOIN tblAssoc as $assoc_current_season ON ($assoc_current_season.intAssocID = $ms_current_season.intAssocID)
                LEFT JOIN tblNode as State ON (State.intNodeID = T.int20_ID)
                LEFT JOIN tblNode as Region ON (Region.intNodeID = T.int10_ID)
                WHERE 
                  $assoc_previous_season.intRealmID=2 AND $assoc_previous_season.intAssocTypeID = 2
                GROUP BY
                $assoc_previous_season.intAssocID,
                $assoc_current_season.intAssocID
                ORDER BY Region, State, PreviousSeasonAssocName
           ];

    my $q = $dbh->prepare($st);
    $q->execute();

    my $file_name = 'auskick_retention.csv';
    my $csv = Text::CSV_XS->new ( { binary => 1, sep_char=>'|', eol => "\r\n"}  )  or die "Cannot use CSV: ".Text::CSV->error_diag ();
    open my $fh, ">:encoding(utf8)", $file_name or die "$file_name: $!";
    
    my @field_names = (
                        'Region',
                        'State', 
                        'Association ID Previous Season',
                        'Association Name Previous Season',
                        'Count',
                        'Association ID Current Season',
                        'Association Name Current Season',
                        'Count',
                        );
    
    $csv->print($fh, \@field_names);
    
    while(my $href = $q->fetchrow_hashref()){
        
        my @data = ();
        my $index = 0;
        
        $data[$index++] = $href->{Region};
        $data[$index++] = $href->{State};
        $data[$index++] = $href->{PreviousSeasonAssocID};
        $data[$index++] = $href->{PreviousSeasonAssocName};
        $data[$index++] = $href->{$assoc_count_previous_season};
        $data[$index++] = $href->{CurrentSeasionAssocID};
        $data[$index++] = $href->{CurrentSeasonAssocName};
        $data[$index++] = $href->{$assoc_count_current_season};

        $csv->print($fh, \@data);
        
    }
    
    close $fh;
    
    return $file_name;
}


sub usage {
    my $error = shift;
    print "\nERROR:\n";
    print "\t$error\n";
    print "\tusage:./auskick_retention_report --previous-season seasonID --current-season seasonID.\n\n";
}
