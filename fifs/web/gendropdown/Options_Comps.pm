package Options_Comps;

use strict;
use warnings;

use lib '..','../..';

use Options_Base;

our @ISA = qw(Options_Base);

use Defs;

sub getSQL {
    my $self = shift;
    my ($params) = @_;

    my $venueID = $params->{'venueID'} || 0;

    my $sql = '';
    
    if (!$venueID) {
        $sql = qq[
            SELECT
                AC.intCompID, 
                AC.strTitle
            FROM 
                tblComp_Teams AS CT
                INNER JOIN tblAssoc_Comp AS AC ON CT.intCompID=AC.intCompID
            WHERE 
                CT.intTeamID=?
                AND AC.intNewSeasonID=?
                AND CT.intRecStatus=$Defs::RECSTATUS_ACTIVE
                AND AC.intRecStatus=$Defs::RECSTATUS_ACTIVE
            ORDER BY
                AC.strTitle
        ];
    }
    else {
        $sql = qq[
            SELECT
                AC.intCompID, 
                AC.strTitle
            FROM 
                tblAssoc A
                INNER JOIN tblAssoc_Comp AS AC ON A.intAssocID=AC.intAssocID
            WHERE 
                A.intAssocID=?
                AND AC.intNewSeasonID=A.intCurrentSeasonID
                AND AC.intRecStatus=$Defs::RECSTATUS_ACTIVE
            ORDER BY
                AC.strTitle
        ];
    }

    return $sql;
}

sub doQuery {
    my $self = shift;
    my ($params, $query) = @_;

    my $venueID = $params->{'venueID'} || 0;

    if (!$venueID) {
        $query->execute($params->{'teamID'}, $params->{'seasonID'});
    }
    else {
        $query->execute($venueID);
    }

    return $query;
}

sub getOptionID {
    return 'intCompID';
}

sub getOptionDesc {
    my $self = shift;
    my ($dref) = @_;

    my $optionDesc = $dref->{'strTitle'};

    return $optionDesc;
}

sub getSelectName {
    return 'compID';
}

sub getSelectID {
    return 'd_compID';
}

sub getSelectDesc {
    return 'competition';
}

sub getDefaultValue {
    return 0;
}

1;
