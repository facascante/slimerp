package EntityTypeRoles;
require Exporter;
@ISA = qw(Exporter);

@EXPORT = @EXPORT_OK = qw(
    getEntityTypeRoles
);

use strict;
use Reg_common;
use Utils;
use AuditLog;
use CGI qw(unescape param);
use Log;


sub getEntityTypeRoles {
    my($Data, $sport, $personType) = @_;
                       
    my $st=qq[
        SELECT 
		    strEntityRoleKey,
            strEntityRoleName
        FROM tblEntityTypeRoles
        WHERE intRealmID IN (0, ?)
            AND intSubRealmID IN (0, ?)
            AND strSport IN ('', ?)
            AND strPersonType IN ('', ?)
        ORDER BY strEntityRoleName
    ];
    my $query = $Data->{'db'}->prepare($st);
    $query -> execute(
        $Data->{'Realm'},
        $Data->{'RealmSubType'},
        $sport,
        $personType
    );
    my %values=();
    while (my $dref = $query->fetchrow_hashref())   {
        $values{$dref->{'strEntityRoleKey'}} = $dref->{'strEntityRoleName'};
    }
    return \%values;
}
1;

