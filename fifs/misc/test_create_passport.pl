#!/usr/bin/perl

use strict;
use lib "..", "../web";
use Defs;
use DBI;
use Utils;
use Passport;
use MCache;
use Log;
use Data::Dumper;

main();

sub main {
    my $db = connectDB();
    my $passport = new Passport( db => $db );
    my %params = (
                   'Email'      => 'eugenejobrien+04@gmail.com',
                   'Firstname'  => 'Eugene',
                   'Familyname' => 'O\'Brien',
                   'Country'    => 'Australia',
                   'State'      => 'Victoria',
    );
    INFO 'Attempting to create passport';
    INFO Dumper(\%params);
    my ( $passportID, $errors ) = $passport->create_passport( \%params );
    if ( !$passportID ) {
        if ( @{$errors} ) {
            ERROR 'Errors returned';
        }
        for my $error ( @{$errors} ) {
            ERROR "Error:$error";
        }
    }
    else {
        INFO "PassportID:$passportID";
    }
    disconnectDB();
}
