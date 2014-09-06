#!/usr/bin/perl 

use strict;
use warnings;
use CGI qw(param);
use JSON;
use lib '..','../..';
use Reg_common;
use Utils;
use AuditLog;
use DefCodes;

main(); 

sub main {
    my $client = param('client') || '';

    my %Data = ();
    my %clientValues = getClient($client);
    $Data{'clientValues'} = \%clientValues;

    my $dbh = allowedTo(\%Data);

    my $dcType = param('type')  || ''; 
    my $dcKey  = param('key')   || '';
    my $optID  = param('optid') || '';

    #this is probably an overkill...
    my $dcKey2 = getRegoPassword(abs($dcType));

    doError('An invalid call has been attempted.') if $dcKey ne $dcKey2;
    doError('An option id must be provided.') if !$optID;

    my %DefCodeTypes = getDefCodesTypes();
    my %CustomFieldsToTypes = getCustomFieldsToTypes();

    my $assocID = getAssocID(\%clientValues) || 0;

    my $json = '';
    my $sql = '';
    my @bindvars = ();

#   $sql = qq[UPDATE tblMember_Associations SET $CustomFieldsToTypes{$dcType}='' WHERE intAssocID=?];
#   @bindvars = ($assocID);
#   doTableUpdate($dbh, $sql, \@bindvars);

    $sql = qq[UPDATE tblDefCodes SET intRecStatus=-1 WHERE intCodeID=?]; 
    @bindvars = ($optID);
    doTableUpdate($dbh, $sql, \@bindvars);

    AuditLog::auditLog($optID, \%Data, 'Delete', $DefCodeTypes{$dcType});

    disconnectDB($dbh);

    $json = to_json({result=>'Success'});

    printStuff($json);
    exit;
}

sub doTableUpdate {
    my ($dbh, $sql, $params) = @_;
    my $q = $dbh->prepare($sql);

    my $count = 0;
    foreach (@$params) {
        $count++;
        $q->bind_param($count, $_);
    }

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
