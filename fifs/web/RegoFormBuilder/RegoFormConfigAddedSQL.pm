package RegoFormConfigAddedSQL;
                           
use lib '../..';

require Exporter;
@ISA       = qw(Exporter);
@EXPORT    = qw(getRegoFormConfigAddedByFETESQL getRegoFormConfigAddedListSQL getRegoFormConfigAddedDeleteSQL);
@EXPORT_OK = qw(getRegoFormConfigAddedByFETESQL getRegoFormConfigAddedListSQL getRegoFormConfigAddedDeleteSQL);

use strict;

sub getRegoFormConfigAddedByFETESQL {
    my $sql = qq[SELECT * FROM tblRegoFormConfigAdded WHERE intRegoFormID=? AND intEntityTypeID=? AND intEntityID=?];
}

#to be removed at some stage
sub getRegoFormConfigAddedListSQL {
    my $sql = qq[SELECT * FROM tblRegoFormConfigAdded WHERE intRegoFormID=? AND intEntityTypeID=? AND intEntityID=?];
    return $sql;
}

sub getRegoFormConfigAddedDeleteSQL {
    my $sql = q[DELETE FROM tblRegoFormConfigAdded WHERE intRegoFormID=? AND intEntityTypeID=? AND intEntityID=?];
    return $sql;
}

1;
