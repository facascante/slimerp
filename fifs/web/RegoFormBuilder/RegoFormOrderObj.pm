#
# $Header: svn://svn/SWM/trunk/web/RegoFormObj.pm 9981 2013-11-28 03:57:26Z mstarcevic $
#

package RegoFormOrderObj;

use lib '..';
use BaseObject2;
our @ISA = qw(BaseObject2);

use strict;

use Utils;

sub _getTableName {
    return 'tblRegoFormOrder';
}

sub _getKeyName {
    return 'intRegoFormOrderID';
}

sub entriesExist {
    my $self = shift;

    my (%params)     = @_;
    my $dbh          = $params{'dbh'};
    my $formID       = $params{'formID'};
    my $entityTypeID = $params{'entityTypeID'};
    my $entityID     = $params{'entityID'};

    return undef if !$dbh or !$formID or !$entityTypeID or !$entityID;

    my @fields = ('COUNT(1)');
    my %where  = (intRegoFormID=>$formID, intEntityTypeID=>$entityTypeID, intEntityID=>$entityID);

    my ($sql, @bindVals) = getSelectSQL($self->_getTableName(), \@fields, \%where, undef);

    my $q = $dbh->prepare($sql);
    $q->execute(@bindVals);

    my ($entriesExist) = $q->fetchrow_array() || 0;

    $entriesExist = 0 if $entriesExist eq 'NULL';

    return $entriesExist;
}

sub getMaxDisplayOrder {
    my $self = shift;

    my %params       = @_;
    my $dbh          = $params{'dbh'};
    my $formID       = $params{'formID'}       || 0;
    my $entityTypeID = $params{'entityTypeID'} || 0;
    my $entityID     = $params{'entityID'}     || 0;

    return undef if !$dbh or !$formID or !$entityTypeID or !$entityID;

    my @fields = ('MAX(intDisplayOrder)');
    my %where  = (intRegoFormID=>$formID, intEntityTypeID=>$entityTypeID, intEntityID=>$entityID);

    my ($sql, @bindVals) = getSelectSQL($self->_getTableName(), \@fields, \%where, undef);

    my $q = $dbh->prepare($sql);
    $q->execute(@bindVals);

    my ($maxDisplayOrder) = $q->fetchrow_array() || 0;

    $maxDisplayOrder = 0 if $maxDisplayOrder eq 'NULL';

    return $maxDisplayOrder;
}

1;
