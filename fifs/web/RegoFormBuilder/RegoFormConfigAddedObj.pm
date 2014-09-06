package RegoFormConfigAddedObj;

use lib;
use BaseObject2;
our @ISA = qw(BaseObject2);

use strict;

use Utils;
use RegoFormConfigAddedSQL;

sub _getTableName {
    return 'tblRegoFormConfigAdded';
}

sub _getKeyName {
    return 'intRegoFormConfigAddedID';
}

sub loadByFormEntityTypeEntityID {
    my $this = shift;
    my (%params) = @_;

    my $dbh          = $params{'dbh'};
    my $formID       = $params{'formID'}       || 0;
    my $entityID     = $params{'entityID'}     || 0;
    my $entityTypeID = $params{'entityTypeID'} || '';

    return undef if !$dbh or !$formID or !$entityTypeID or !$entityID; 

    my $self = new $this(db=>$dbh);
    my $sql  = getRegoFormConfigAddedByFETESQL();
    my @args = ($formID, $entityTypeID, $entityID);

    $self->_doQuery($sql, \@args);
    $self->{'ID'} = $self->getValue('intRegoFormConfigAddedID');

    return $self;
}

#this may be able to get deleted eventually, as a list doesn't make sense.
sub getList {
    my $self   = shift;
    my %params = @_;

    my $dbh          = $params{'dbh'};
    my $formID       = $params{'formID'}  || 0;
    my $entityID     = $params{'entityID'} || 0;
    my $entityTypeID = $params{'entityTypeID'} || '';

    return undef if !$dbh;

    #only logical to get a list for a form/entityTypeID/entityID
    return undef if !$formID or !$entityID; 

    my $sql = getRegoFormConfigAddedListSQL();
    my @bindVars = ($formID, $entityTypeID, $entityID);

    my $q = getQueryPreparedAndBound($dbh, $sql, \@bindVars);
   
    $q->execute();

    my @regoFormConfigAddedObjs = ();
    my $dref = $q->fetchrow_hashref();
    #while (my $dref = $q->fetchrow_hashref()) {
    #    my $regoFormConfigAddedObj = $self->load(db=>$dbh, ID=>$dref->{'intRegoFormConfigdAddedID'});
    #    push @regoFormConfigAddedObjs, $regoFormConfigAddedObj;
    #}
    
    $q->finish();

    return $dref;
}

sub delete {
    my $self = shift;

    my %params  = @_;
    my $dbh     = $params{'dbh'};
    my $formID  = $params{'formID'}  || 0;
    my $entityID  = $params{'entityID'}  || 0;
    my $entityTypeID = $params{'entityTypeID'} || 0;

    return undef if !$dbh;

    #can only use method to delete by form/assoc/club/type (club may be zero, type not set). 
    return undef if !$entityID or !$entityTypeID; 

    my $sql = getRegoFormConfigAddedDeleteSQL();

    my @bindVars = ($formID, $entityTypeID, $entityID);

    my $q = getQueryPreparedAndBound($dbh, $sql, \@bindVars);
   
    $q->execute();
    $q->finish();

    return 1;
}

1;
