#!/usr/bin/perl

#
# $Header: svn://svn/SWM/trunk/misc/export_role.pl 8250 2013-04-08 08:24:36Z rlee $
#

use strict;
use lib '..', '../web';

use Defs;
use Utils;

use Getopt::Long;
use Text::CSV_XS;

my $realm;
my $sub_realm;

GetOptions('realm=i'=>\$realm, 'subrealm:i'=>\$sub_realm);

if (!$realm){ 
    usage('Please provide the realm you wish to export');
    exit;
}

my $dbh = connectDB();

my $sub_realm_where = '';
if ($sub_realm) {
    $sub_realm_where = qq[AND intAssocTypeID = $sub_realm]
}
# get all the associations for this realm and sub realm.

my $query = qq[SELECT strName, intAssocID, intCurrentSeasonID
               FROM tblAssoc
               WHERE intRealmID = $realm
               $sub_realm_where        
               ORDER BY strName
               ];

my $sth = $dbh->prepare($query); 
$sth->execute();

my $active_members_query = qq[SELECT COUNT(DISTINCT tblMember.intMemberID) 
                              FROM tblMember_Seasons_$realm 
                              INNER JOIN tblMember USING (intMemberID)
                              WHERE intAssocID = ? AND intClubID = 0 AND intSeasonID = ? AND intMSRecStatus = 1
                              AND tblMember.intStatus IN (0, 1)
                              ];
my $active_members_query_sth = $dbh->prepare($active_members_query);

my $all_members_query = qq[SELECT COUNT(DISTINCT tblMember.intMemberID) 
                           FROM tblMember
                           INNER JOIN tblMember_Associations USING (intMemberID)
                           WHERE intAssocID = ? 
                           AND tblMember_Associations.intRecStatus IN (0,1)
                           AND tblMember.intStatus IN (0, 1)
                           ];
my $all_members_query_sth = $dbh->prepare($all_members_query);


my $file_name = 'members_by_associations_' . $realm;
if ($sub_realm) {
    $file_name .= '_' . $sub_realm;
}
$file_name .='.csv';

my $csv = Text::CSV_XS->new ( { binary => 1, sep_char=>',', eol => "\r\n"}  )  or die "Cannot use CSV: ".Text::CSV->error_diag ();
open my $fh, ">:encoding(utf8)", $file_name or die "$file_name: $!";

while (my $href = $sth->fetchrow_hashref()) {
    my $assoc_id = $href->{intAssocID};
    my $assoc_name = $href->{strName};
    my $current_season_id = $href->{intCurrentSeasonID};
    
    $active_members_query_sth->execute($assoc_id, $current_season_id);
    my($active_members) = $active_members_query_sth->fetchrow_array();

    $all_members_query_sth->execute($assoc_id);
    my($all_members) = $all_members_query_sth->fetchrow_array();
                                                    
    my @data = ($assoc_id, $assoc_name, $all_members, $active_members);
    $csv->print($fh, \@data);
}

close $fh;
exit;

sub usage {
    my $error = shift;
    print "\nERROR:\n";
    print "\t$error\n";
    print "\tusage:./member_by_assoc_count.pl --realm realm_id --sub-realm sub_realm_id\n\n";
}
