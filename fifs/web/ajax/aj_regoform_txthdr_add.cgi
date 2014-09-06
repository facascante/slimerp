#!/usr/bin/perl 

#
# $Header: svn://svn/SWM/trunk/web/ajax/aj_regoform_txthdr_add.cgi 10615 2014-02-06 23:01:49Z dhanslow $
#

use strict;
use warnings;
use lib "..","../../",'../RegoFormBuilder','../PaymentSplit';
use CGI qw(param);
use JSON;
use Reg_common;
use Utils;
use RegoForm;
use RegoFormObj;
use RegoFormFieldObj;
use RegoFormOrderObj;
use RegoFormFieldAddedObj;

main(); 

sub main {
    my $client = param('client') || '';

    my %Data = ();
    my %clientValues = getClient($client);
    $Data{'clientValues'} = \%clientValues;

    my $dbh = allowedTo(\%Data);
    $Data{'db'} = $dbh;

    my $formID  = param('fid') || '';
    my $formKey = param('fky') || '';

    #this is probably an overkill as allowedTo checks authenticity...
    my $formKey2 = getRegoPassword($formID);

    doError('An invalid call has been attempted.') if $formKey ne $formKey2;

    # now into the specifics...
    my $typ = param('typ') || 0;

    doError('An invalid type parameter has been encountered.') if $typ !~ /^1|2/;

    my $bl = param('bl') || '';
    my $bc = param('bc') || '';

    my $fieldName = ($typ == 1) ? 'RFHEADER' : 'RFTEXT';

    $fieldName .= "|regoform|$bl";
    my $regoFormObj = RegoFormObj->load(db=>$dbh, ID=>$formID);
    my ($entityTypeID, $entityID) = getEntityValues($Data{'clientValues'});

    #determine the displayOrder to assign to the new field...
    my $displayOrder = RegoFormFieldObj->getMaxDisplayOrder(dbh=>$dbh, formID=>$formID);

    #use added fields (node form being edited by a node other than the creating node or a linked form)?
    my $useAdded = (($regoFormObj->isNodeForm() and !$regoFormObj->isOwnForm(entityID=>$entityID)));
    if ($useAdded) {
        #if entries exist on tblRegoFormOrder...
        #otherwise get from tblRegoFormFields, tblRegoFormFieldsAdded
	if (RegoFormOrderObj->entriesExist(dbh=>$dbh, formID=>$formID, entityTypeID=>$entityTypeID, entityID=>$entityID)) {
            $displayOrder = RegoFormOrderObj->getMaxDisplayOrder(dbh=>$dbh, formID=>$formID, entityTypeID=>$entityTypeID, entityID=>$entityID);
        }
        else {
            my $displayOrderAdded = 0;
            my $upperLevel = $regoFormObj->getValue('intCreatedLevel');
            my $entityStructure = getEntityStructure(\%Data, $entityTypeID, $entityID, $upperLevel, 1); #get topdown.
		    foreach my $entityArr (@$entityStructure) {
                my $tempOrderAdded = RegoFormFieldAddedObj->getMaxDisplayOrder(dbh=>$dbh, formID=>$formID, entityTypeID=>@$entityArr[0], entityID=>@$entityArr[1]);
                $displayOrderAdded = $tempOrderAdded if $tempOrderAdded > $displayOrderAdded;
            }
            $displayOrder = $displayOrderAdded if $displayOrderAdded > $displayOrder;
        }
    }
    $displayOrder++;

    my $perm   = 'Editable';
    my $source = 1;

    my $fieldObjName = ($useAdded) ? 'RegoFormFieldAddedObj' : 'RegoFormFieldObj';
    my $fieldObj     = $fieldObjName->new(db=>$dbh);

    my $dbfields = 'dbfields'; 
    $fieldObj->{$dbfields}{'intRegoFormID'}   = $formID;
    $fieldObj->{$dbfields}{'strFieldName'}    = $fieldName;
    $fieldObj->{$dbfields}{'intType'}         = $typ;
    $fieldObj->{$dbfields}{'intDisplayOrder'} = $displayOrder;
    $fieldObj->{$dbfields}{'strText'}         = $bc;
    $fieldObj->{$dbfields}{'strPerm'}         = $perm;

    if ($useAdded) {
        $source  = 3;
        $fieldObj->{$dbfields}{'intEntityTypeID'} = $entityTypeID;
        $fieldObj->{$dbfields}{'intEntityID'}     = $entityID;
    }

    my $fieldID = $fieldObj->save();

    if ($useAdded) {
        if (RegoFormOrderObj->entriesExist(dbh=>$dbh, formID=>$formID, entityTypeID=>$entityTypeID, entityID=>$entityID)) {

            my $regoFormOrderObj = RegoFormOrderObj->new(db=>$dbh);

            my $dbfields    = 'dbfields';
            my $ondupfields = 'ondupfields';

            $regoFormOrderObj->{$dbfields}    = ();
            $regoFormOrderObj->{$ondupfields} = ();
            $regoFormOrderObj->{$dbfields}{'intRegoFormID'}   = $formID;
            $regoFormOrderObj->{$dbfields}{'intEntityTypeID'} = $entityTypeID;
            $regoFormOrderObj->{$dbfields}{'intEntityID'}     = $entityID;
            $regoFormOrderObj->{$dbfields}{'intDisplayOrder'} = $displayOrder;
            $regoFormOrderObj->{$dbfields}{'intSource'}       = $source;
            $regoFormOrderObj->{$dbfields}{'intFieldID'}      = $fieldID;

            $regoFormOrderObj->{$ondupfields} = ['intDisplayOrder'];

            my $regoFormOrderID = $regoFormOrderObj->save();
        }
    }

    my $desc = $bl;
    $desc ||= $bc;
    $desc =~ s/\s+$//;

    my $desc2 = $desc;
    $desc = substr($desc, 0, 30);

    if (length($desc2) gt length($desc)) {
        $desc =~ s/\s+$//;
        $desc .= '...';
    }

    my $flabel = ($typ == 1) ? 'H' : 'T';
    $flabel .= "-Block => $desc";

    my $json = to_json({
        result => 'Success',
        fid    => $fieldID,
        fname  => $fieldName,
        typ    => $typ,
        flabel => $flabel,
        dorder => $displayOrder,
        source => $source,
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
    die "message\n";
}
