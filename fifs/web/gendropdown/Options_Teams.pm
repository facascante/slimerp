package Options_Teams;

use strict;
use warnings;

use Options_Base;

our @ISA = qw(Options_Base);

use lib "../..";

use Defs;

sub getSQL {
    my $sql = qq[
        SELECT
            CT.intTeamID, 
            T.strName
        FROM 
            tblComp_Teams AS CT
            INNER JOIN tblTeam AS T ON CT.intTeamID=T.intTeamID
        WHERE 
            CT.intCompID=?
			AND CT.intRecStatus=$Defs::RECSTATUS_ACTIVE
			AND T.intRecStatus=$Defs::RECSTATUS_ACTIVE
        ORDER BY
            T.strName
    ];

    return $sql;
}

sub doQuery {
    my $self = shift;
    my ($params, $query) = @_;

    my $compID = $params->{'compID'} || -1;

    $query->execute($compID);

    return $query;
}

sub getOptionID {
    return 'intTeamID';
}

sub getOptionDesc {
    my $self = shift;
    my ($dref) = @_;

    my $optionDesc = $dref->{'strName'};

    return $optionDesc;
}

sub getSelectName {
    return 'teamID';
}

sub getSelectID {
    return 'd_teamID';
}

sub getSelectDesc {
    return 'team';
}

sub getDefaultValue {
    return 0;
}

1;
