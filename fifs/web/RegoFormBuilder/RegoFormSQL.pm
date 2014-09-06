#
# $Header: svn://svn/SWM/trunk/web/RegoFormSQL.pm 10810 2014-02-26 01:02:00Z mstarcevic $
#

package RegoFormSQL;
                           
use lib '../..';

require Exporter;
@ISA       = qw(Exporter);
@EXPORT    = qw(getListOfParentBodyFormsSQL);
@EXPORT_OK = qw(getListOfParentBodyFormsSQL);

use strict;
use lib '.', '..';
use Defs;

sub getListOfParentBodyFormsSQL {
    my (%params) = @_;

    my $realmID   = $params{'realmID'}   || 0;
    my $assocID   = $params{'assocID'}   || 0;

    return undef if !$realmID or !$assocID;
    
    my $fields    = $params{'fields'}    || 'R.*';
    my $formTypes = $params{'formTypes'} || '';

    #get forms created by nodes.
    my $sql = qq[
        SELECT
            $fields
        FROM   
            tblRegoForm R
        INNER JOIN tblTempNodeStructure TNS ON (
            (TNS.int100_ID = R.intCreatedID AND R.intCreatedLevel = $Defs::LEVEL_NATIONAL) OR
            (TNS.int30_ID =  R.intCreatedID AND R.intCreatedLevel = $Defs::LEVEL_STATE)    OR
            (TNS.int20_ID =  R.intCreatedID AND R.intCreatedLevel = $Defs::LEVEL_REGION)   OR
            (TNS.int10_ID =  R.intCreatedID AND R.intCreatedLevel = $Defs::LEVEL_ZONE)
        )
        WHERE  
            TNS.intAssocID = $assocID
            AND R.intAssocID=-1 
            AND R.intClubID=-1
            AND R.intRealmID=?
            AND R.intStatus<>-1
    ];

    $sql .= qq[ AND intRegoType IN ($formTypes)] if $formTypes;

    return $sql;
}

1;
