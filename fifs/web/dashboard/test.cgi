#!/usr/bin/perl -w

#
# $Header: svn://svn/SWM/trunk/web/authlist.cgi 10456 2014-01-16 03:51:34Z eobrien $
#

use strict;
use warnings;

use DBI;
use CGI qw(:cgi escape unescape);
use Crypt::CBC;

use lib ".", "..", "../..", "../passport";

use Defs;
use Utils;
use DashboardUtils qw(:constants);
use Digest::MD5 qw(md5_base64);

use Data::Dumper;
use Log;

main();

sub main {
    my $db = connectDB();

    my $cipher = Crypt::CBC->new( -key    => DASHBOARD_ENCRYPTION_KEY,
                                  -cipher => "Crypt::Blowfish" );

    my $base_url = DASHBOARD_BASE_URL;

    my $st = qq[
        SELECT pm.intPassportID, m.intMemberID, m.intRealmID, dm.intDashboardID, m.strFirstName, m.strSurname
        FROM tblPassportMember pm
        INNER JOIN tblMember m on m.intMemberID = pm.intMemberID
        INNER JOIN tblDashboardMember dm on m.intMemberID = dm.intMemberID;
    ];

    my $q = $db->prepare($st);
    $q->execute();
    my $member_login_list = '<u>';
    while ( my ( $passport_id, $member_id, $realm_id, $dashboard_id, $firstname, $surname ) = $q->fetchrow_array() ) {
        my $member_md5 = escape( md5_base64( $dashboard_id . '.' . $realm_id . '.' . DASHBOARD_MEMBER_SECRET ) );
        my $member_enc = $cipher->encrypt_hex($dashboard_id);
        $member_login_list .= qq[<li><a href="$base_url?m=$member_enc.$member_md5;r=$realm_id">$firstname $surname</a></li>];
    }
    $member_login_list .= '</ul>';
    $q->finish();
    disconnectDB($db);

    print "Content-type: text/html", "\n\n";
    print $member_login_list;
}
