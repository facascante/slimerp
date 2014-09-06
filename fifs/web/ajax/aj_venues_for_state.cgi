#!/usr/bin/perl 

use strict;
use warnings;
use lib '..','../..','../gendropdown';
use CGI qw(param);
use Utils;
use JSON;
use GenDropDown;

main(); 

sub main {
    my $realmID    = param('realmID')    || 0;
    my $subrealmID = param('subrealmID') || 0;
    my $state      = param('state')      || '';

    if (!$realmID or !$subrealmID or !$state) {
        process_error('Realm, subrealm and state params must be provided.');
        return;
    }

    my %Data = ();

    $Data{'db'} = connectDB();

    my $dbh = $Data{'db'};

    my $json = genDropdownOptions(\%Data, {optType=>5, realmID=>$realmID, subrealmID=>$subrealmID, state=>$state, format=>'json'});

    disconnectDB($dbh);

    print "Content-type: text/html\n\n";
    print $json;
}

sub process_error {
    my ($message) = @_;

    my $json = to_json({Error=>$message});

    print "Content-type: text/html\n\n";
    print $json;
    return;
}
