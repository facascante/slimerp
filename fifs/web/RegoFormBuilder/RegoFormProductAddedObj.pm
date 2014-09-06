package RegoFormProductAddedObj;

use lib;
use BaseObject2;
our @ISA = qw(BaseObject2);

use strict;

use Utils;
use RegoFormProductAddedSQL;

sub _getTableName {
    return 'tblRegoFormProductsAdded';
}

sub _getKeyName {
    return 'intRegoFormProductAddedID';
}

sub getList {
    my $self = shift;

    my %params  = @_;
    my $dbh     = $params{'dbh'};
    my $formID  = $params{'formID'}  || 0;
    my $assocID = $params{'assocID'} || 0;
    my $orderBy = $params{'orderBy'} || '';

    return undef if !$dbh;

    #only logical to get a list for a form/assoc/club (club may be zero). 
    return undef if !$formID or !$assocID; 
    return undef if !exists $params{'clubID'};

    my $clubID  = $params{'clubID'};

    my $sql = getRegoFormProductAddedListSQL(orderBy=>$orderBy);
    my @bindVars = ($formID, $assocID, $clubID);

    my $q = getQueryPreparedAndBound($dbh, $sql, \@bindVars);
   
    $q->execute();

    my @regoFormProductAddedObjs = ();

    while (my $dref = $q->fetchrow_hashref()) {
        my $regoFormProductAddedObj = $self->load(db=>$dbh, ID=>$dref->{'intRegoFormProductAddedID'});
        push @regoFormProductAddedObjs, $regoFormProductAddedObj;
    }
    
    $q->finish();

    return \@regoFormProductAddedObjs;
}

sub bulkDelete {
    my $self = shift;

    my %params  = @_;
    my $dbh     = $params{'dbh'};
    my $formID  = $params{'formID'}  || 0;
    my $assocID = $params{'assocID'} || 0;

    return undef if !$dbh;

    #can only use method to delete by form/assoc/club (club may be zero). 
    return undef if !$formID or !$assocID; 
    return undef if !exists $params{'clubID'};

    my $clubID = $params{'clubID'};

    my $sql = getRegoFormProductAddedBulkDeleteSQL();

    my @bindVars = ($formID, $assocID, $clubID);

    my $q = getQueryPreparedAndBound($dbh, $sql, \@bindVars);
   
    $q->execute();
    $q->finish();

    return 1;
}

1;
