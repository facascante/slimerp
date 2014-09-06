#!/usr/bin/perl

#
# $Header: svn://svn/SWM/trunk/misc/export_role.pl 8250 2013-04-08 08:24:36Z rlee $
#

use strict;
use lib '..','../web', '../web/comp';

use Defs;
use Utils;

use Getopt::Long;
use Text::CSV_XS;

my $realm;
my $sub_realm;
my $role;

GetOptions('realm=i'=>\$realm, 'subrealm:i'=>\$sub_realm, 'role:s'=>\$role);

if (!$role){ 
    usage('Please provide the role you wish to export');
    exit;
}

my $dbh = connectDB();

my $role_name = '';
my ($role_count) = $dbh->selectrow_array(qq[SELECT COUNT(*) FROM tblContactRoles WHERE strRoleName = "$role"]);

if ($role_count) {
    print "Reporting on $role\n";
}
else {
    print "Please check the role name you provided. It does not appear to be a valid.\n";
    print "Script terminating...\n";
    exit;
}

my $realm_where = '';
my $sub_realm_where = '';

my $query = qq[SELECT 
               strRealmName AS RealmName,
               tblAssoc.strName AS AssocName,
               tblClub.strName  AS ClubName,
               strContactFirstname,
               strContactSurname, 
               strContactEmail, 
               strContactMobile,
               tblClub.strAddress1, tblClub.strAddress2, tblClub.strSuburb, tblClub.strState, tblClub.strPostalCode
               FROM tblContacts
               INNER JOIN tblContactRoles ON (tblContacts.intContactRoleID = tblContactRoles.intRoleID)
               LEFT JOIN tblRealms ON (tblContacts.intRealmID = tblRealms.intRealmID)
               LEFT JOIN tblAssoc ON (tblContacts.intAssocID =  tblAssoc.intAssocID)
               LEFT JOIN tblClub ON (tblContacts.intClubID = tblClub.intClubID)
               WHERE strRoleName = "$role" 
               $realm_where
               $sub_realm_where        
               ORDER BY RealmName, AssocName, ClubName, strContactSurname, strContactFirstname
               ];

my $sth = $dbh->prepare($query); 
$sth->execute();

my $file_name = $role . '.csv';
my $csv = Text::CSV_XS->new ( { binary => 1, sep_char=>',', eol => "\r\n"}  )  or die "Cannot use CSV: ".Text::CSV->error_diag ();
open my $fh, ">:encoding(utf8)", $file_name or die "$file_name: $!";

while (my $href = $sth->fetchrow_hashref()) {
    my $address = join(' ', $href->{strAddress1}, $href->{strAddress2}, $href->{strSuburb}, $href->{strState}, $href->{strPostalCode});
    $address =~s/\s+/ /g;
    $address =~s/^\s+$//;

    my @data = ($href->{'RealmName'}, $href->{'AssocName'}, $href->{'ClubName'}, $href->{'strContactFirstname'}, $href->{'strContactSurname'}, $href->{'strContactEmail'}, $href->{'strContactMobile'}, $address);      
    $csv->print($fh, \@data);
}

close $fh;
exit;

sub usage {
    my $error = shift;
    print "\nERROR:\n";
    print "\t$error\n";
    print "\tusage:./export_role.pl --realm realm_id --sub-realm sub_realm_id --role role_name\n\n";
}
