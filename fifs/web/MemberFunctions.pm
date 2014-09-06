#
# $Header: svn://svn/SWM/trunk/web/MemberFunctions.pm 8251 2013-04-08 09:00:53Z rlee $
#

package MemberFunctions;

require Exporter;
@ISA       = qw(Exporter);
@EXPORT    = qw(getAgeGroupID);
@EXPORT_OK = qw(getAgeGroupID);

use strict;

use GenAgeGroup;

sub getAgeGroupID {
    my($Data, $db, $assocID, $id) = @_;

    my $genAgeGroup = new GenAgeGroup(
        $Data->{'db'},
        $Data->{'Realm'},
        $Data->{'RealmSubType'},
        $assocID
    );

    my $st = qq[
        SELECT DATE_FORMAT(dtDOB, "%Y%m%d"), intGender
        FROM   tblMember
        WHERE  intMemberID = ?
    ];

    my $qry = $db->prepare($st);
    $qry->execute($id);

    my ($DOBAgeGroup, $Gender) = $qry->fetchrow_array();

    $DOBAgeGroup ||= q{};
    $Gender      ||= 0;

    return $genAgeGroup->getAgeGroup($Gender, $DOBAgeGroup) || 0;
}

1;
