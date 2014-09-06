package RegoFormConfigSQL;
                           
use lib '../..';

require Exporter;
@ISA       = qw(Exporter);
@EXPORT    = qw(getByRegoFormIdSQL getListOfTermsSetByParentBodySQL);
@EXPORT_OK = qw(getByRegoFormIdSQL getListOfTermsSetByParentBodySQL);

use strict;

sub getByRegoFormIdSQL {
    my (%params) = @_;

    my $fields  = $params{'fields'} || '*';

    my $sql = qq[SELECT $fields FROM tblRegoFormConfig WHERE intRegoFormID=?];

    return $sql;
}

sub getListOfTermsSetByParentBodySQL {
    my (%params) = @_;

    my $idOnly = $params{'idOnly'} || 0;
    my $fields = $params{'fields'} || '*';

    my $expr = ($idOnly) ? 'intRegoFormConfigID' : $fields;

    my $sql = qq[
        SELECT 
            $expr 
        FROM 
            tblRegoFormConfig
        WHERE 
            intRegoFormID=0 
            AND intRealmID=?
            AND (intSubRealmID=0 OR intSubRealmID=?)
            AND (intAssocID=0 OR intAssocID=?)
        ORDER BY 
            intSubRealmID ASC, 
            intAssocID ASC, 
            intRegoFormID ASC
    ];

    return $sql;
}

1;
