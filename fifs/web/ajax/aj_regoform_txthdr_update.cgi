#!/usr/bin/perl 

#
# $Header: svn://svn/SWM/trunk/web/ajax/aj_regoform_txthdr_update.cgi 10358 2013-12-23 06:07:46Z mstarcevic $
#

use strict;
use warnings;
use lib "..","../../","../RegoForm/","../RegoFormBuilder",'../PaymentSplit';
use CGI qw(param);
use JSON;
use Defs;
use Reg_common;
use Utils;
use RegoForm;
use RegoFormFieldObj;
use RegoFormFieldAddedObj;

main(); 

sub main {
    my $client = param('client') || '';

    my %Data = ();
    my %clientValues = getClient($client);
    $Data{'clientValues'} = \%clientValues;

    my $dbh = allowedTo(\%Data);

    my $formID  = param('fid')   || '';
    my $formKey = param('fky')   || '';

    #this is probably an overkill as allowedto checks authenticity...
    my $formKey2 = getRegoPassword($formID);

    doError('An invalid call has been attempted.') if $formKey ne $formKey2;

    # now into the specifics...
    my $typ = param('typ') || 0;

    doError('An invalid type parameter has been encountered.') if $typ !~ /^1|2/;

	my $bl = param('bl')  || '';
    my $bc = param('bc')  || '';

    my $fieldName = ($typ == 1) ? 'RFHEADER' : 'RFTEXT';

    $fieldName .= "|regoform|$bl";

    my $fieldID = param('fldid') || 0;
    my $source  = substr($fieldID, 0, 1);
    $fieldID    = unpack "xxA*", $fieldID; #strip first two chars

    doError('An invalid field id parameter has been encountered.') if !$fieldID;

    my $useAdded     = ($source >= 3);
    my $fieldObjName = ($useAdded) ? 'RegoFormFieldAddedObj' : 'RegoFormFieldObj';
    my $fieldObj     = $fieldObjName->load(db=>$dbh, ID=>$fieldID);
        
    my $dbfields = 'dbfields';

    $fieldObj->{$dbfields} = ();
    $fieldObj->{$dbfields}{'strFieldName'} = $fieldName;
    $fieldObj->{$dbfields}{'strText'}      = $bc;

    my $retID = $fieldObj->save();

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
        flabel => $flabel,
        source => $source,
    });

    disconnectDB($dbh);

    print "Content-type: text/html\n\n";
    print $json;

}

sub doError {
    my ($message) = @_;
    my $json = to_json({result=>'Error', message=>$message});
    print "Content-type: text/html\n\n";
    print $json;
    die "$message\n";
}
