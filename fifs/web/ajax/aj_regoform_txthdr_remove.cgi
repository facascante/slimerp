#!/usr/bin/perl 

#
# $Header: svn://svn/SWM/trunk/web/ajax/aj_regoform_txthdr_remove.cgi 10863 2014-03-04 01:20:27Z mstarcevic $
#

use strict;
use warnings;
use CGI qw(param);
use JSON;
use lib "..","../../",'../RegoFormBuilder','../PaymentSplit';
use Defs;
use Reg_common;
use Utils;
use RegoForm;
use RegoFormObj;
use RegoFormRuleObj;
use RegoFormFieldObj;
use RegoFormRuleAddedObj;
use RegoFormFieldAddedObj;
use RegoFormOrderObj;

main(); 

sub main    {
    my $client = param('client') || '';

    my %Data = ();
    my %clientValues = getClient($client);
    $Data{'clientValues'} = \%clientValues;

    my $dbh = allowedTo(\%Data);

    my $formID  = param('fid') || 0;
    my $formKey = param('fky') || '';

    #this is probably an overkill as allowedTo checks authenticity...
    my $formKey2 = getRegoPassword($formID);

    doError('An invalid call has been attempted.') if $formKey ne $formKey2;

    # now into the specifics...
    my $fieldID = param('fldid') || 0;
    my $source  = substr($fieldID, 0, 1);
    $fieldID    = unpack "xxA*", $fieldID; #strip first two chars

    doError('An invalid field id parameter has been encountered.') if !$fieldID;

    my $useAdded = ($source >= 3);

    my $ruleObj     = ($useAdded) ? 'RegoFormRuleAddedObj'    : 'RegoFormRuleObj';
    my $fieldIdName = ($useAdded) ? 'intRegoFormFieldAddedID' : 'intRegoFormFieldID';
    my %where       = (intRegoFormID=>$formID, $fieldIdName=>$fieldID); 

    $ruleObj->deleteWhere(dbh=>$dbh, where=>\%where);

    my $fieldObj = ($useAdded) ? 'RegoFormFieldAddedObj' : 'RegoFormFieldObj';
    %where = (intRegoFormID=>$formID, $fieldObj->getKeyName()=>$fieldID);

    $fieldObj->deleteWhere(dbh=>$dbh, where=>\%where);

    my $regoFormObj = RegoFormObj->load(db=>$dbh, ID=>$formID);
    my ($entityTypeID, $entityID) = getEntityValues($Data{'clientValues'});

    if (($regoFormObj->isNodeForm() and !$regoFormObj->isOwnForm(entityID=>$entityID)) or $regoFormObj->isLinkedForm()) {
        %where = (intRegoFormID=>$formID, intEntityTypeID=>$entityTypeID, intEntityID=>$entityID, intSource=>$source, intFieldID=>$fieldID);
        RegoFormOrderObj->deleteWhere(dbh=>$dbh, where=>\%where); #doesn't matter if doesn't exist.
    }

    disconnectDB($dbh);

    my $json = to_json({result=>'Success'});

    print "Content-type: application/json\n\n";
    print $json;
     
    exit;
}

sub doError {
    my ($message) = @_;
    my $json = to_json({result=>'Error', message=>$message});
    print "Content-type: application/json\n\n";
    print $json;
    die"$message\n";
}
