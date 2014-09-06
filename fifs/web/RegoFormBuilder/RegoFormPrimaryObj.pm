package RegoFormPrimaryObj;

use lib;
use BaseObject2;
our @ISA = qw(BaseObject2);

use strict;

use Utils;
use RegoFormPrimarySQL;

sub _getTableName {
    return 'tblRegoFormPrimary';
}

sub _getKeyName {
    return 'intRegoFormPrimaryID';
}

sub getCurrentPrimaryFormID {
    my $self = shift;
    my (%params) = @_;

    my $dbh = $params{'dbh'};
    my $entityTypeID = $params{'entityTypeID'};
    my $entityID = $params{'entityID'};

    return undef if !$dbh or !$entityTypeID or !$entityID;

    my $sql  = getCurrentPrimaryFormIdSQL();

    my @bindVars = ($entityTypeID, $entityID);

    my $q = getQueryPreparedAndBound($dbh, $sql, \@bindVars);
   
    $q->execute();

    my ($primaryFormID) = $q->fetchrow_array();

    $primaryFormID ||= 0;
    
    $q->finish();

    return $primaryFormID;
}

sub delete {
    my $self = shift;

    my %params       = @_;
    my $dbh          = $params{'dbh'};
    my $entityTypeID = $params{'entityTypeID'} || 0;
    my $entityID     = $params{'entityID'}     || 0;
    my $formID       = $params{'formID'}       || 0;

    return undef if !$dbh or !$entityTypeID or !$entityID or !$formID;

    my $sql = getRegoFormPrimaryDeleteSQL();

    my @bindVars = ($entityTypeID, $entityID, $formID);

    my $q = getQueryPreparedAndBound($dbh, $sql, \@bindVars);
   
    $q->execute();
    $q->finish();

    return 1;
}

1;
