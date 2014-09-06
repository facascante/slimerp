package Options_Venues;

use strict;
use warnings;

use lib '..','../..';

use Options_Base;

our @ISA = qw(Options_Base);

use Defs;

sub getSQL {

    my $sql = qq[
        SELECT
            A.intAssocID AS intVenueID, 
            A.strName
        FROM 
            tblAssoc AS A
            INNER JOIN tblAssocServices AS S ON A.intAssocID=S.intAssocID
        WHERE 
            A.intRealmID=?
            AND A.intAssocTypeID=?
			AND A.intRecStatus=$Defs::RECSTATUS_ACTIVE
            AND S.intPublicShow=1
            AND S.strVenueState=?
    ];

    return $sql;
}

sub doQuery {
    my $self = shift;
    my ($params, $query) = @_;

    my $realmID    = $params->{'realmID'}    || -1;
    my $subrealmID = $params->{'subrealmID'} || -1;
    my $state      = $params->{'state'}      || '';

    $query->execute($realmID, $subrealmID, $state);

    return $query;
}

sub getOptionID {
    return 'intVenueID';
}

sub getOptionDesc {
    my $self = shift;
    my ($dref) = @_;

    my $optionDesc = $dref->{'strName'};

    return $optionDesc;
}

sub getSelectName {
    return 'venueID';
}

sub getSelectID {
    return 'd_venueID';
}

sub getSelectDesc {
    return 'venue';
}

sub getDefaultValue {
    return 0;
}

1;
