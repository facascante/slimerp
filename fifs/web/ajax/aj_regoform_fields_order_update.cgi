#!/usr/bin/perl 

#
# $Header: svn://svn/SWM/trunk/web/ajax/aj_regoform_fields_order_update.cgi 10863 2014-03-04 01:20:27Z mstarcevic $
#

use strict;
use warnings;

use lib '..','../../','../RegoFormBuilder','../PaymentSplit';

use CGI qw(param);
use JSON;
use Reg_common;
use Utils;
use RegoForm;
use RegoFormObj;
use RegoFormOrderObj;

main(); 

sub main {
    my $client = param('client') || '';

    my %Data = ();
    my %clientValues = getClient($client);
    $Data{'clientValues'} = \%clientValues;

    my $dbh = allowedTo(\%Data);

    my $formID  = param('fid')   || ''; 
    my $formKey = param('fky')   || '';
    my $order   = param('order') || '';

    #this is probably an overkill as allowedTo checks authenticity...
    my $formKey2 = getRegoPassword($formID);

    doError('An invalid call has been attempted.') if $formKey ne $formKey2;

    my @newOrder = split /\|/, $order;

    my $regoFormObj = RegoFormObj->load(db=>$dbh, ID=>$formID);
    my ($entityTypeID, $entityID) = getEntityValues($Data{'clientValues'});

    my $result = (($regoFormObj->isNodeForm() and !$regoFormObj->isOwnForm(entityID=>$entityID)) or $regoFormObj->isLinkedForm())
        ? updateLinked($dbh, $formID, \@newOrder, $regoFormObj, $entityTypeID, $entityID)
        : updateUnlinked($dbh, $formID, \@newOrder);

    disconnectDB($dbh);

    my $json = to_json({result=>'Success'});

    print "Content-type: text/html\n\n";
    print $json;

    exit;
}

sub updateLinked {
    my ($dbh, $formID, $newOrder, $regoFormObj, $entityTypeID, $entityID) = @_;

    my $count = 0;

    my %where = (intRegoFormID=>$formID, intEntityTypeID=>$entityTypeID, intEntityID=>$entityID);

    RegoFormOrderObj->deleteWhere(dbh=>$dbh, where=>\%where);

    foreach my $item (@$newOrder) {
        $count++;

        my $source  = substr($item, 0, 1);
        my $fieldID = unpack "xxA*", $item; #strip first two chars

#       #nationalrego> depending upon how things are 'cleaned up' when regoform fields are updated, it may be better to
#       #nationalrego> do a bulk delete before doing the update (to ensure no leftover fields). but for now, because the
#       #nationalrego> fields are coming from tblRegoFormOrder, an updateOnDup should suffice.

        my $regoFormOrderObj = RegoFormOrderObj->new(db=>$dbh);

        my $dbfields    = 'dbfields';

        $regoFormOrderObj->{$dbfields}    = ();
        $regoFormOrderObj->{$dbfields}{'intRegoFormID'}   = $formID;
        $regoFormOrderObj->{$dbfields}{'intEntityTypeID'} = $entityTypeID;
        $regoFormOrderObj->{$dbfields}{'intEntityID'}     = $entityID;
        $regoFormOrderObj->{$dbfields}{'intDisplayOrder'} = $count;
        $regoFormOrderObj->{$dbfields}{'intSource'}       = $source;
        $regoFormOrderObj->{$dbfields}{'intFieldID'}      = $fieldID;

        my $regoFormOrderID = $regoFormOrderObj->save();
    }

    return 1;
}

sub updateUnlinked {
    my ($dbh, $formID, $newOrder) = @_;

    my $sql = qq[UPDATE tblRegoFormFields SET intDisplayOrder=? WHERE intRegoFormFieldID=? AND intRegoFormID=?]; 

    my $count = 0;

    foreach my $item (@$newOrder) {
        $count++;
        my $fieldID = unpack "xxA*", $item; #strip first two chars
        $dbh->do($sql, undef, $count, $fieldID, $formID);
        doError('Error occurred during database update.') if $DBI::err;
    }

    return 1;
}

sub doError {
    my ($message) = @_;
    my $json = to_json({result=>'Error', message=>$message});
    print "Content-type: text/html\n\n";
    print $json;
    die "$message\n";
}
