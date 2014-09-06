#!/usr/bin/perl

use strict;
use lib "../","../web";
use Utils;

my $db = connectDB();

my @entityLevels= qw(20 3);
my @origin = (20);

my $st = qq[
    INSERT INTO tblWFRule (
        intRealmID,
        intOriginLevel,
        intEntityLevel,
        strWFRuleFor,
        strRegistrationNature,
        strPersonType,
        strPersonLevel,
        strSport,
        strAgeLevel,
        strTaskType
    )
    VALUES (
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

my $q = $db->prepare($st);
my $realm = 1;
foreach my $entityLevel (@entityLevels)    {
    foreach my $origin (@origin)    {
        foreach my $sport (keys %Defs::sportType)   {
            foreach my $nature (keys %Defs::registrationNature)   {
                foreach my $personType (keys %Defs::personType)   {
                    foreach my $personLevel (keys %Defs::personLevel)   {
                        foreach my $ageLevel (keys %Defs::ageLevel)   {
                            $q->execute(
                                $realm,
                                $origin,
                                $entityLevel,
                                'REGO',
                                $nature,
                                $personType,
                                $personLevel,
                                $sport,
                                $ageLevel,
                                'APPROVAL',
                            );
                        }
                    }
                }
            }
        }
    }
}



