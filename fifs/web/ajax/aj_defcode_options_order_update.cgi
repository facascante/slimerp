#!/usr/bin/perl

use strict;
use warnings;
use CGI qw(param);
use JSON;
use lib '..','../..';
use Reg_common;
use Utils;

main(); 

sub main {
    my $client = param('client') || '';

    my %Data = ();
    my %clientValues = getClient($client);
    $Data{'clientValues'} = \%clientValues;

    my $dbh = allowedTo(\%Data);

    my $dcType = param('type')  || ''; 
    my $dcKey  = param('key')   || '';
    my $order  = param('order') || '';

    #this is probably an overkill...
    my $dcKey2 = getRegoPassword(abs($dcType));

    my $json = '';

    if ($dcKey ne $dcKey2) {
        process_error('An invalid call has been attempted.');
        return;
    }

    my $sql = qq[UPDATE tblDefCodes SET intDisplayOrder=? WHERE intCodeID=?]; 

    my @newOrder = split /\|/, $order;

    my $count = 0;
    foreach my $i (@newOrder) {
        $count++;
        $dbh->do($sql, undef, $count, $i);
        if ($DBI::err) {
            process_error('Error occurred during database update.');
            return;
        }
    }

    disconnectDB($dbh);

    $json = to_json({result=>'Success'});

    print "Content-type: text/html\n\n";
    print $json;

}

sub process_error {
    my ($message) = @_;

    my $json = to_json({
        result  => 'Error',
        message => $message
    });

    print "Content-type: text/html\n\n";
    print $json;
    return;
}
