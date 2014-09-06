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
        select distinct m.intMemberID, m.strEmail
        from tblPassportMember pm
        inner join tblMember m on m.intMemberID = pm.intMemberID;
    ];

    my $q = $db->prepare($st);
    $q->execute();

    my $counter = 0;
    while ( my $record = $q->fetchrow_hashref() ) {
        $counter++;
        my $memberID = $record->{intMemberID};

        my $email = $record->{strEmail};

        $passport->addModule( 'SPMEMBERSHIPADMIN', $email );
    }
    INFO "Fixed $counter umpires";

    $q->finish();

    disconnectDB();
}

