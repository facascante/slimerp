#!/usr/bin/perl 

#
# $Header: svn://svn/SWM/trunk/web/ajax/aj_regoform_txthdr_get.cgi 10358 2013-12-23 06:07:46Z mstarcevic $
#

use strict;
use warnings;
use lib "..","../../","../RegoForm/",'../RegoFormBuilder','../PaymentSplit';
use CGI qw(param);
use JSON;
use Defs;
use Reg_common;
use Utils;
use RegoForm;
use RegoFormFieldObj;
use RegoFormFieldAddedObj;

main(); 

sub main    {
    my $client = param('client') || '';

    my %Data = ();
    my %clientValues = getClient($client);
    $Data{'clientValues'} = \%clientValues;

    my $dbh = allowedTo(\%Data);

    my $formID  = param('fid') || 0;
    my $formKey = param('fky') || '';

    #this is probably an overkill as allowedto checks authenticity...
    my $formKey2 = getRegoPassword($formID);

    doError('An invalid call has been attempted.') if $formKey ne $formKey2;

    # now into the specifics...
    my $fieldID = param('fldid') || 0;
    my $source  = substr($fieldID, 0, 1);
    $fieldID    = unpack "xxA*", $fieldID; #strip first two chars

    doError('An invalid field id parameter has been encountered.') if !$fieldID;

    my $useAdded = ($source >= 3);

    my $fieldObjName = ($useAdded) ? 'RegoFormFieldAddedObj' : 'RegoFormFieldObj';
    my $fieldObj = $fieldObjName->load(db=>$dbh, ID=>$fieldID);

    my $blabel   = $fieldObj->getValue('strFieldName');
    my $thtyp    = $fieldObj->getValue('intType'); 
    my $bcontent = $fieldObj->getValue('strText'); 

    my $remtext = ($thtyp == 1) ? 'RFHEADER' : 'RFTEXT';
    $remtext .= '\|regoform\|';
    $blabel =~ s/$remtext//;

    my $json = to_json({
        result    => 'Success',
        blabel    => $blabel,
        bcontent  => $bcontent
    });

    disconnectDB($dbh);

    print "Content-type: text/html\n\n";
    print $json;

    exit;
}

sub doError {
    my ($message) = @_;
    my $json = to_json({result=>'Error', message=>$message});
    print "Content-type: text/html\n\n";
    print $json;
    die"$message\n";
}
