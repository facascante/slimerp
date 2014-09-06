#!/usr/bin/perl -w

#
# $Header: svn://svn/SWM/trunk/web/admin/rftadmin.cgi 10127 2013-12-03 03:59:01Z tcourt $
#

use lib "../..","..",".";
use DBI;
use CGI qw(param unescape escape);
use Utils;
use strict;
use AdminPageGen;
use RFTAdmin;

main();

sub main {
    my $action = param('a') || '';
    my $db     = connectDB();
    my $target = "rftadmin.cgi";
    my %Data   = ();

    $Data{'db'}     = $db;
    $Data{'target'} = $target;

    my $subBody = handle_template($action, \%Data);
    my $body = qq[
        $subBody 
        <br>
        <div style="margin-left:22px"><a href="$target">Search</a> | <a href="$target?a=RFT_list">List All</a> | <a href="$target?a=RFT_add">Add New</a></div>
    ] if $subBody;

    disconnectDB($db) if $db;
    print_adminpageGen($body, "", "");
}
