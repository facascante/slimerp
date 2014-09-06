package RegoFormFieldObj;

use lib;
use BaseObject2;
our @ISA = qw(BaseObject2);

use strict;

use Utils;

sub _getTableName {
    return 'tblRegoFormFields';
}

sub _getKeyName {
    return 'intRegoFormFieldID';
}

sub getMaxDisplayOrder {
    my $self = shift;

    my %params = @_;
    my $dbh    = $params{'dbh'};
    my $formID = $params{'formID'} || 0;

    return undef if !$dbh or !$formID;

    my @fields = ('MAX(intDisplayOrder)');

    my %where = (
       intRegoFormID => $formID,
       strPerm       => [ -and => {'!=', 'Hidden'}, {'!=', 'ChildDefine'}],
    );

    my ($sql, @bindVals) = getSelectSQL($self->_getTableName(), \@fields, \%where, undef);

    my $q = $dbh->prepare($sql);
    $q->execute(@bindVals);

    my ($maxDisplayOrder) = $q->fetchrow_array() || 0;

    $maxDisplayOrder = 0 if $maxDisplayOrder eq 'NULL';
    
    return $maxDisplayOrder;
}

1;
