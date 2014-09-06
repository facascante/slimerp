#!/usr/bin/perl
use strict;
use lib '..', '../web';

use Data::Dumper;
use MemberRecordType;
use Singleton;
use ServerDefs;
use Log;

my @realm_list = (35,);
my $record_limit = 1000000;

my ($HOST, $USER, $PWD, $dbi, $mysql, $DB)=('192.168.200.240', $ServerDefs::DB_USER, $ServerDefs::DB_PASSWD, split(':', $ServerDefs::DB_DSN));
#my ($HOST, $USER, $PWD, $DB)=("192.168.200.240", "root", "qweasd", "prod_regoSWM_20131027");
#my ($HOST, $USER, $PWD, $DB)=("localhost", "root", "", "prod_regoSWM_20140223");
#my $dbh = DBI->connect("DBI:mysql:$DB:$HOST", $USER, $PWD) or die "Connect database failed";
my $dbh = get_dbh();

# global cache for record type
my $record_type_cache = {};

sub print_sql {
    print STDOUT @_, "\n";
}

sub get_record_type_id {
    my ($realm_id, $realm_sub_id, $name) = @_;
    my $key = sprintf("%s-%s-%s", $realm_id, $realm_sub_id, lc $name);
    if (not exists $record_type_cache->{$key}) {

        my $s;
        if (defined($realm_id) and defined($realm_sub_id)) {
            my $sql = qq{ 
                SELECT intMemberRecordTypeID FROM tblMemberRecordType
                WHERE strName = ? AND intRealmID = ? AND intSubRealmID = ?
            };
            $s = $dbh->prepare($sql);
            $s->execute($name, $realm_id, $realm_sub_id);
        } elsif (defined($realm_id)) {
            my $sql = qq{ 
                SELECT intMemberRecordTypeID FROM tblMemberRecordType
                WHERE strName = ? AND intRealmID = ? 
            };
            $s = $dbh->prepare($sql);
            $s->execute($name, $realm_id);
        } else {
            $record_type_cache->{$key} = -1;
            return -1;
        }

        my @row = $s->fetchrow_array();
        if (@row == 0) {
            ERROR "# record type id not found for name: $name, realm: $realm_id, sub_realm: $realm_sub_id)\n";
        }
        $record_type_cache->{$key} = @row>0 ? $row[0] : -1;
        $s->finish();
    }
    return $record_type_cache->{$key};
}


# prepare template table
print_sql("# PREPARE TABLE TEMPLATE"); 
print_sql(`cat ../db_setup/tblMemberRecords.sql`); 

# clear and prepare the taget table
for my $realm_id (@realm_list) {
    my $dst_table_name = "tblMemberRecords_$realm_id";
    print_sql("# PREPARE TABLE;"); 
    print_sql("DROP TABLE IF EXISTS $dst_table_name;"); 
    print_sql("CREATE TABLE $dst_table_name LIKE tblMemberRecords;"); 
    print_sql("ALTER TABLE $dst_table_name AUTO_INCREMENT = 1;");
    print_sql("");
    print_sql("# PREPARE DATA"); 

# get the realm id dataset
    my $sth = $dbh->prepare(qq{
        SELECT ms.*, s.strSeasonName, s.intRealmID, s.intRealmSubTypeID
        FROM tblMember_Seasons_$realm_id ms
        LEFT JOIN tblSeasons s ON ms.intSeasonID = s.intSeasonID
        LIMIT $record_limit
        });
#        WHERE ms.intAssocID = 12607
#        LEFT JOIN tblAssoc ass ON ms.intAssocID = ass.intAssocID
#        LEFT JOIN tblMember m ON ms.intMemberID = m.intMemberID

    $sth->execute() or die "SQL error";
    my $count = 0;
    my $total = $sth->rows;

    while (my $row = $sth->fetchrow_hashref()) {
        $count += 1;
        print STDERR "\rprocessing $count / $total";

        my $entity_type_id = ($row->{'intClubID'} != 0 ? 3 : 5);
        my $entity_id = $row->{'intClubID'} != 0 ? $row->{'intClubID'} : $row->{'intAssocID'};
        for my $type (qw/Player Coach Umpire Other1 Other2/) {
            if ($row->{"int${type}Status"} == 1) {
                my $record_type_id = get_record_type_id($row->{'intRealmID'}, $row->{'intSubRealmID'}, $type);
                my @values = (
                        $record_type_id,
                        $row->{'intMemberID'}, 
                        $entity_type_id, 
                        $entity_id,
                        $row->{'intSeasonID'}, 
                        $row->{'intPlayerAgeGroupID'},
                        $row->{"dtIn$type"},
                        $row->{"dtOut$type"},
                        $row->{"int${type}FinancialStatus"},
                        $row->{"int${type}Status"},
                        $row->{"intUsedRegoForm"},
                    );
                $values[6] = $values[6]? "'$values[6]'" : 'NULL';
                $values[7] = $values[7]? "'$values[7]'" : 'NULL';

                print_sql("INSERT INTO $dst_table_name (intMemberRecordTypeID, intMemberID, intEntityTypeID, intEntityID, intSeasonID, intAgeGroupID, dtIn, dtOut, intFinancialStatus, intStatus, intFromRegoForm)
    VALUES (", join(", ", @values), "); # $count");
            }
        }
    }

    $sth->finish();
}

$dbh->disconnect();

INFO "\nDone. Now you can import the batch data by the following command: \n";
INFO "    mysql -h$HOST -u$USER -p$PWD $DB < SQL_FILE\n\n";

# vim: set et sw=4 ts=4:
