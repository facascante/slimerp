#!/usr/bin/perl 

use strict;
use warnings;
use CGI qw(param);
use JSON;
use lib '..','../..','../RegoFormBuilder','../PaymentSplit';
use Reg_common;
use Utils;
use RegoFormPrimaryObj;
use RegoFormOrderObj;

main(); 

sub main {
    my $client = param('client') || '';

    my %Data = ();
    my %clientValues = getClient($client);
    $Data{'clientValues'} = \%clientValues;

    my $dbh = allowedTo(\%Data);

    my $fID   = param('fid')   || 0; 
    my $pbfID = param('pbfid') || 0;

    doError('A formID must be provided.') if !$fID;

    my $sql = qq[UPDATE tblRegoForm SET intParentBodyFormID=? WHERE intRegoFormID=?]; 

    my @bindVars = ($pbfID, $fID);
    doTableUpdate($dbh, $sql, \@bindVars);

    if ($pbfID == 0) { #doing an unlink
        my $entityTypeID = param('etid') || 0; 
        my $entityID     = param('eid')  || 0;
        if ($entityTypeID and $entityID) {
            RegoFormPrimaryObj->delete(dbh=>$dbh, entityTypeID=>$entityTypeID, entityID=>$entityID, formID=>$fID);

            my %where = (intRegoFormID=>$fID, intEntityTypeID=>$entityTypeID, intEntityID=>$entityID);

            RegoFormOrderObj->deleteWhere(dbh=>$dbh, where=>\%where);

        }
    }

    disconnectDB($dbh);

    my $json = to_json({result=>'Success'});

    printStuff($json);
    exit;
}

sub doTableUpdate {
    my ($dbh, $sql, $bindVars) = @_;

    my $q = getQueryPreparedAndBound($dbh, $sql, $bindVars);

    $q->execute();

    doError("Error occurred during database update.") if $DBI::err;

    $q->finish();
    return;
}

sub doError {
    my ($message) = @_;

    my $json = to_json({result=>'Error', message=>$message});

    printStuff($json);
    die "$message\n";
}

sub printStuff {
    my ($stuff) = @_;
    print "Content-type: text/html\n\n";
    print $stuff;
    return
}
