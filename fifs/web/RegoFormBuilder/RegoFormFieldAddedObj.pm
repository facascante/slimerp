package RegoFormFieldAddedObj;

use lib;
use BaseObject2;
our @ISA = qw(BaseObject2);

use strict;

use Utils;

sub _getTableName {
    return 'tblRegoFormFieldsAdded';
}

sub _getKeyName {
    return 'intRegoFormFieldAddedID';
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
    my %where  = (intRegoFormID=>$formID, intEntityTypeID=>$entityTypeID, intEntityID=>$entityID, intStatus=>1);

    my ($sql, @bindVals) = getSelectSQL($self->_getTableName(), \@fields, \%where);

    my $q = $dbh->prepare($sql);
    $q->execute(@bindVals);

    my ($maxDisplayOrder) = $q->fetchrow_array() || 0;

    return $maxDisplayOrder;
}

1;
