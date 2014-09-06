package Options_Forms;

use strict;
use warnings;

use Options_Base;

our @ISA = qw(Options_Base);

sub getSQL {
    my $self = shift;
    my ($params) = @_;

    my $sql = qq[
        SELECT 
            intRegoFormID, 
            strRegoFormName
        FROM   
            tblRegoForm
        WHERE  
            intAssocID=?
            AND intClubID=?
            AND intRegoType IN ($params->{'formType'})
            AND intStatus=1
            AND intTemplate=0
    ];

    return $sql;
}

sub doQuery {
    my $self = shift;
    my ($params, $query) = @_;

    $query->execute($params->{'assocID'}, $params->{'clubID'});

    return $query;
}

sub getOptionID {
    return 'intRegoFormID';
}

sub getOptionDesc {
    my $self = shift;
    my ($dref) = @_;

    my $optionDesc = qq[$dref->{'strRegoFormName'} (#$dref->{'intRegoFormID'})];

    return $optionDesc;
}

sub getSelectName {
    return 'formID';
}

sub getSelectID {
    return 'd_formID';
}

sub getSelectDesc {
    return 'registration form';
}

sub getDefaultValue {
    return 0;
}

1;
