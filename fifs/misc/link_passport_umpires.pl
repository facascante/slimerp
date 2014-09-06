#!/usr/bin/perl

use strict;
use warnings;

use lib "..", "../web";

use Defs;
use DBI;
use Utils;
use Passport;
use MCache;
use Lang;
use Log;

main();

sub main {
    my $db       = connectDB();
    my $lang     = Lang->get_handle() || die "Can't get a language handle!";
    my $passport = new Passport( db => $db );
    my %Data = (
                 db    => $db,
                 lang  => $lang,
                 cache => new MCache(),
                 Realm => undef,
    );

    my $st = qq[
        select distinct m.intMemberID, m.strEmail, m.strFirstname, m.strSurname, m.strCountry, m.strState
        from tblUmpireAllocations ua
        inner join tblMember m on m.intMemberID = ua.intMemberID
        inner join tblAssocConfig ac on ac.intAssocID = ua.intAssocID
        left outer join tblPassportMember pm on pm.intMemberID = m.intMemberID
        where ac.strOption = 'AllowRefereeLogin'
        and ac.strValue = '1'
        and pm.intMemberID IS NULL;
 
    ];

    my $q = $db->prepare($st);
    $q->execute();

    my $counter = 0;
    while ( my $record = $q->fetchrow_hashref() ) {
        $counter++;
        my $memberID = $record->{intMemberID};

        my $email = $record->{strEmail};

        my %params = (

            'Email'      => $email,
            'Firstname'  => $record->{strFirstname} || 'Unknown',
            'Familyname' => $record->{strSurname} || $record->{strFirstname} || 'Name',
            'Country' => $record->{strCountry} || 'Australia',
            'State'   => $record->{strState}   || '',

        );
        my ( $passportID, $errors ) = $passport->create_passport( \%params );
        if ( !$passportID ) {
            if ( @{$errors} ) {
                WARN "Could not create passport for memberID:$memberID";
                for my $error ( @{$errors} ) {
                    WARN "Error:$error";
                }
            }
        }
        else {
            link_passport_to_member( $db, $memberID, $passportID );
            $passport->addModule( 'SPMEMBERSHIPADMIN', $email );

            INFO "PassportID:$passportID,MemberID:$memberID";
        }
    }
    INFO "Linked $counter umpires to passports";

    $q->finish();

    disconnectDB();
}

sub link_passport_to_member {
    my ( $db, $memberID, $passportID ) = @_;

    my $st = qq[
                INSERT INTO tblPassportMember (
                    intPassportID,
                    intMemberID,
                    tTimeStamp
                )
                VALUES (
                    ?,
                    ?,
                    NOW()
                )
            ];
    my $q = $db->prepare($st);
    $q->execute(
                 $passportID,
                 $memberID,
    );
    $q->finish();
}
