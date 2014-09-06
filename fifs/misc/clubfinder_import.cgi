#!/usr/bin/perl

#
# $Header: svn://svn/SWM/trunk/misc/clubfinder_import.cgi 8249 2013-04-08 08:14:07Z rlee $
#

use warnings;

use lib "..","../web";
use Defs;
use Utils;
use strict;

my $db=connectDB();
my $file = 'ClubFinder.txt';

my $st = qq[
INSERT INTO tblAssocServices (
  intAssocID, 
  intClubID, 
  strPresidentName, 
  strPresidentEmail, 
  strPresidentPhone, 
  intShowPresident, 
  strSecretaryName, 
  strSecretaryEmail, 
  strSecretaryPhone, 
  intShowSecretary, 
  strTreasurerName, 
  strTreasurerEmail, 
  strTreasurerPhone, 
  intShowTreasurer, 
  strRegistrarName, 
  strRegistrarEmail, 
  strRegistrarPhone, 
  intShowRegistrar, 
  strVenueAddress, 
  strVenueAddress2, 
  strVenueSuburb, 
  strVenueState, 
  strVenueCountry,
  strVenuePostalCode,
  strEmail,
  strURL,
  strFax,
  intMon,
  intTue,
  intWed,
  intThu,
  intFri,
  intSat,
  intSun,
  strTimes,
  strSessionDurations,
  dtStart,
  dtFinish,
  strNotes, 
  intPublicShow
) VALUES (
  ?,
  ?,
  ?,
  ?,
  ?,
  ?,
  ?,
  ?,
  ?,
  ?,
  ?,
  ?,
  ?,
  ?,
  ?,
  ?,
  ?,
  ?,
  ?,
  ?,
  ?,
  ?,
  ?,
  ?,
  ?,
  ?,
  ?,
  ?,
  ?,
  ?,
  ?,
  ?,
  ?,
  ?,
  ?,
  ?,
  ?,
  ?,
  ?,
  ?
)
];
my $query_service = $db->prepare($st);

my $statement = qq[
  INSERT INTO tblAssocServicesPostalCode (
    intAssocID,
    strPostalCode,
    intClubID
  )
  VALUES (
    ?,
    ?,
    ?
  )
];
my $query_postcode = $db->prepare($statement);

my $count = 0;
open INFILE, "<$file" or die "Can't open Input File $file";
seek(INFILE,0,0);
while (<INFILE>) {
  $count ++;
  next if $count == 1;
  chomp;
  my $line=$_;
  $line=~s/^M//g;
  $line=~s/\t/\-/g;
  $line=~s/[\n\r]//g;
  my @field=split /\|/,$line;
  next unless $field[1];
  $query_service->execute(
    $field[1],
    $field[3] || 0,
    $field[4],
    $field[5],
    $field[6],
    $field[7] || 0,
    $field[8],
    $field[9],
    $field[10],
    $field[11] || 0,
    $field[12],
    $field[13],
    $field[14],
    $field[15] || 0,
    $field[16],
    $field[17],
    $field[18],
    $field[19] || 0,
    $field[20],
    $field[21],
    $field[22],
    $field[23],
    $field[24],
    $field[25],
    $field[26],
    $field[27],
    $field[28],
    $field[29],
    $field[30],
    $field[31],
    $field[32],
    $field[33],
    $field[34],
    $field[35],
    $field[36],
    $field[37],
    $field[38],
    $field[39],
    $field[40],
    $field[41] || 0,
  );
  if ($field[42]) {
    my @postcodes = split /,/,$field[42];
    foreach (@postcodes) {
      $query_postcode->execute(
        $field[1],
        $_,
        $field[3] || 0,
      );
    }
  }  
}
