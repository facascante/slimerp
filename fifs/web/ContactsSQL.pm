#
# $Header: svn://svn/SWM/trunk/web/ContactsSQL.pm 8352 2013-04-22 21:23:50Z tcourt $
#

package ContactsSQL;
                           
require Exporter;
@ISA       = qw(Exporter);
@EXPORT    = qw(getContactsSQL);
@EXPORT_OK = qw(getContactsSQL);

use strict;
use lib "..","../..";

sub getContactsSQL {
    my (%params) = @_;

    my $assoc_id         = $params{'associd'}          || 0;
    my $club_id          = $params{'clubid'}           || 0;
    my $getregistrations = $params{'getregistrations'} || 0;
    my $getpayments      = $params{'getpayments'}      || 0;
    my $getprimary       = $params{'getprimary'}       || 0;
    my $getClearances 	 = $params{'getclearances'}       || 0;
    my $sql = '';

    #if getting a list of any sort, an assoc should always be provided.
    if ($assoc_id or $club_id or $getregistrations or $getpayments or $getprimary) {
        $sql .= q[SELECT * FROM tblContacts WHERE 1=1];
        $sql .= q[ AND intAssocID=?]         if $assoc_id > 0; 
        $sql .= q[ AND intClubID=?]; #clubid needed even if 0.
        $sql .= q[ AND intFnPayments=?]      if $getpayments;
        $sql .= q[ AND intFnRegistrations=?] if $getregistrations;
        $sql .= q[ AND intPrimaryContact=?]  if $getprimary;
       	$sql .= q[ AND intFnClearances=?]  if $getClearances;
	 $sql .= q[ ORDER BY intContactID];
    }
    else {
        $sql .= qq[SELECT * FROM tblContacts WHERE intContactID=? LIMIT 1];
    }
    return $sql;
}

1;
