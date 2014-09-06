package EntityUtils;

require Exporter;
@ISA = qw(Exporter);

@EXPORT = @EXPORT_OK = qw(
    get_entity_list
);

use strict;
use warnings;
use lib '.', '..';

use Reg_common;
use Utils;
use DBUtils;
use Singleton;
use Log;

#
# return entity list in form { $id => $name, ... }
#
sub get_entity_list {
    my ($data, $entity_type_id) = @_;
    my $result = []; 

    if ($entity_type_id == $Defs::LEVEL_CLUB) {
        $result = query_data(qq [
            SELECT  
                c.intClubID AS k, c.strName AS v
            FROM
                tblClub c
            JOIN tblAssoc_Clubs ac 
                ON c.intClubID = ac.intClubID AND ac.intAssocID = ? 
            WHERE 
                c.intRecStatus >= 0 
            ORDER BY
                c.strName
            ], $data->{'clientValues'}{'assocID'});
    } 
    elsif ($entity_type_id == $Defs::LEVEL_ASSOC) {
        $result = query_data(qq [
            SELECT 
                a.intAssocID AS k, a.strName AS v
            FROM    
                tblAssoc a
            WHERE   
                a.intRecStatus >= 0 AND a.intRealmID = ? 
            ORDER BY
                a.strName
            ], $data->{'Realm'});
    }
    else {
        # TODO: get other entity list
    }

    return $result;
}

1;
# vim: set et sw=4 ts=4:
