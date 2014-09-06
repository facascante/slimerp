package RegoFormPrimarySQL;
                           
require Exporter;
@ISA       = qw(Exporter);
@EXPORT    = qw(getCurrentPrimaryFormIdSQL getRegoFormPrimaryDeleteSQL);
@EXPORT_OK = qw(getCurrentPrimaryFormIdSQL getRegoFormPrimaryDeleteSQL);

use strict;

sub getCurrentPrimaryFormIdSQL {
    my $sql = q[SELECT intRegoFormID FROM tblRegoFormPrimary WHERE intEntityTypeID=? AND intEntityID=?];
    return $sql;
}

sub getRegoFormPrimaryDeleteSQL {
    my $sql = q[DELETE FROM tblRegoFormPrimary WHERE intEntityTypeID=? AND intEntityID=? AND intRegoFormID=?];
    return $sql;
}

1;
