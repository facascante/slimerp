package RegoFormFieldSQL;
                           
use lib '../..';

require Exporter;
@ISA       = qw(Exporter);
@EXPORT    = qw(getRegoFormFieldListSQL);
@EXPORT_OK = qw(getRegoFormFieldListSQL);

use strict;

sub getRegoFormFieldListSQL {
    my (%params) = @_;

    my $fields  = $params{'fields'}  || '*';
    my $orderBy = $params{'orderBy'} || '';

    my $type = (exists $params{'type'}) ? $params{'type'} : -1;

    my $sql = qq[SELECT $fields FROM tblRegoFormFields WHERE intRegoFormID=?];

    $sql .= qq[ AND intType=?] if $type != -1;
    $sql .= qq[ ORDER BY $orderBy] if $orderBy;

    return $sql;
}

1;
