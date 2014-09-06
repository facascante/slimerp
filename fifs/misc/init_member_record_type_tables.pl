#!/usr/bin/perl
# vim: set et sw=4 ts=4:
use strict;
use lib '..', '../web';

use Data::Dumper;
use Singleton;
use DBUtils;
use Log;

my $SQL = `cat ../db_setup/tblMemberRecords.sql`;

my $realms = query_data(qq{ SELECT intRealmID FROM tblRealms });
for my $realm (@$realms) {
    my $realm_id = $realm->{'intRealmID'};
    my $sql = $SQL;
    $sql =~ s/tblMemberRecords/tblMemberRecords_$realm_id/g;
    print "$sql\n";
}

# initialize MemberRecordType table
$SQL =`cat ../db_setup/tblMemberRecordType.sql`; 
print $SQL;

# initialize MemberRecordTypeConfig table
$SQL =`cat ../db_setup/tblMemberRecordTypeConfig.sql`; 
print $SQL;
