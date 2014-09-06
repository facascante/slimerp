package Options_Seasons;

use strict;
use warnings;

use Options_Base;

our @ISA = qw(Options_Base);

use lib "..", "../..", "../comp";
use InstanceOf;

sub getSQL {
    my $sql = qq[
        SELECT DISTINCT
            S.intSeasonID, 
            S.strSeasonName
        FROM 
            tblComp_Teams AS CT
            INNER JOIN tblAssoc_Comp AS AC ON CT.intCompID=AC.intCompID
            INNER JOIN tblSeasons    AS S  ON AC.intNewSeasonID=S.intSeasonID
        WHERE 
            CT.intTeamID=?
            AND S.intArchiveSeason<>1
        ORDER BY S.intSeasonOrder, S.strSeasonName DESC
    ];

    return $sql;
}

sub doQuery {
    my $self = shift;
    my ($params, $query) = @_;

    $query->execute($params->{'teamID'});

    return $query;
}

sub getOptionID {
    return 'intSeasonID';
}

sub getOptionDesc {
    my $self = shift;
    my ($dref) = @_;

    my $optionDesc = $dref->{'strSeasonName'};

    return $optionDesc;
}

sub getSelectName {
    return 'seasonID';
}

sub getSelectID {
    return 'd_seasonID';
}

sub getSelectDesc {
    return 'season';
}

sub getDefaultValue {
    my $self = shift;
    my ($Data, $params) = @_;

    my $assocObj = getInstanceOf($Data, 'assoc', $params->{'assocID'});

    my $defaultValue = 0;

    my $newRegoSeasonID = $assocObj->getValue('intNewRegoSeasonID') || 0;
     
    if ($newRegoSeasonID) {
        my $sql = qq[SELECT strSeasonName FROM tblSeasons WHERE intSeasonID=?];
        my $query = $Data->{'db'}->prepare($sql);
        $query->execute($newRegoSeasonID);
        ($defaultValue) = $query->fetchrow_array() || 0;
    }

    return $defaultValue;
}

1;
