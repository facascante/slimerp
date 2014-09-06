package RegoFormProductAddedSQL;
                           
#use lib '../..';

require Exporter;
@ISA       = qw(Exporter);
@EXPORT    = qw(getRegoFormProductAddedListSQL getRegoFormProductAddedBulkDeleteSQL);
@EXPORT_OK = qw(getRegoFormProductAddedListSQL getRegoFormProductAddedBulkDeleteSQL);

use strict;

sub getRegoFormProductAddedListSQL {
    my (%params) = @_;

    my $fields  = $params{'fields'}  || '*';
    my $orderBy = $params{'orderBy'} || '';

    my $sql = qq[SELECT $fields FROM tblRegoFormProductsAdded WHERE intRegoFormID=? AND intAssocID=? AND intClubID=?];

    $sql .= qq[ ORDER BY $orderBy] if $orderBy;

    return $sql;
}

sub getRegoFormProductAddedBulkDeleteSQL {
    my (%params) = @_;

    my $sql = q[DELETE FROM tblRegoFormProductsAdded WHERE intRegoFormID=? AND intAssocID=? AND intClubID=?];

    return $sql;
}

1;
