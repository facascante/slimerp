#! /usr/bin/perl -w

use strict;

use lib '..', '../..', '../web/';

use CGI qw(param);
use Utils;
use Data::Dumper;
use Log;
use Defs;
use SystemConfig;
use TTTemplate;
use Getopt::Std;

my $cgi = CGI->new();
my $dbh = connectDB();
my $content = '';
my ( $entity_type, $entity, $realm, $subrealm ) = ( 0, 0, 0, 0 );

my $interval_num  = 20;
my $interval_type = 'MINUTE';

getopts('a:');
our $opt_a;
if ($opt_a) {
    if ( $opt_a =~ /^gen(.*)url$/ ) {
        my $where = ( $1 eq 'all' )? qq[] : qq[WHERE tTimestamp > DATE_SUB( NOW(), INTERVAL $interval_num $interval_type )];

        my $st_select = qq(SELECT intOptinMemberID FROM tblOptinMember $where);
        my $st_update = qq(UPDATE tblOptinMember SET strUnsubscribeURL=? WHERE intOptinMemberID=?);

        my $q_select = $dbh->prepare($st_select);
        my $q_update = $dbh->prepare($st_update);

        $q_select->execute();
        while( my $entry_id = $q_select->fetchrow_array() ) {
            my $table_name = 'tblOptinMember';
            my $url = $Defs::base_url . '/3rdparty_unsubscribe.cgi?id=' . encode( "table_name=$table_name&entry_id=$entry_id" );
            $q_update->execute($url, $entry_id);
        }

        DEBUG "genurl for tblOptinMember strUnsubscribeURL done";
    }
    else {
        ERROR "Invalid action";
    }
    exit;
}
