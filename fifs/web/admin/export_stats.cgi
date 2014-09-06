#!/usr/bin/perl -w

use DBI;
use CGI qw(:cgi escape unescape);
use strict;

use lib '../../web', '../..';
use Utils;

main();

sub main {
	my $action = param('a') || '';
	my $brandID	= param('brandID') || 2;
	my $interestID = param('interestID') || 6;
	my $url = "export_stats.cgi";
	my $db = connectDB();
  my $page = '';
	if ($action eq "export_clubs") {
		$page .= get_clubs($db);
		export_file($page);
	}
	else {
    $page = qq[
      <ul>
        <li><a href="$url?a=export_clubs">Get Clubs - Bruce Pritchard</a></li>
				<br>
        <li><a href="$url?a=export_rr_vouchers">Get Red Rooster Vouchers - Sue Chandler</a></li>
				<br>
        <li><a href="$url?a=export_rr_sites">Get Red Rooster Sites - Sue Chandler</a></li>
      </ul>
    ];
		print_page($page);
	}
}

sub get_clubs {
	my ($db) = @_;
	my $st = qq[
	SELECT
R.strRealmName as 'Realm', 
SR.strSubTypeName as 'SubRealm', 
A.intAssocID as 'AssocID', A.strName as 'Association', 
C.intClubID as 'ClubID', 
C.strName as 'Club Name', 
IF(A.strPostalCode,A.strPostalCode,'') as 'Assoc Postcode', 
IF(C.strPostalCode,C.strPostalCode,'') as 'Club Postcode', 
IF(CAS.strVenuePostalCode,CAS.strVenuePostalCode,'') as 'Club Venue Postcode', 
IF(AAS.strVenuePostalCode,AAS.strVenuePostalCode,'') as 'Assoc Venue Postcode'
FROM tblClub C
INNER JOIN tblAssoc_Clubs AC ON (C.intClubID = AC.intClubID)
INNER JOIN tblAssoc A ON (A.intAssocID = AC.intAssocID)
INNER JOIN tblRealms R ON (A.intRealmID = R.intRealmID)
LEFT JOIN tblRealmSubTypes SR ON (A.intAssocTypeID = SR.intSubTypeID)
LEFT JOIN tblAssocServices CAS ON (CAS.intClubID = C.intClubID)
LEFT JOIN tblAssocServices AAS ON (AAS.intClubID = 0 and AAS.intAssocID=A.intAssocID)
WHERE C.intRecStatus>-1
AND A.intRecStatus>-1
AND AC.intRecStatus>-1
	];
	my $q = $db->prepare($st);
	$q->execute();
	my $file_data = '';
  $file_data = join (',','Realm','SubRealm','AssocID','Association','ClubID','Club','Assoc Postcode','Club Postcode','Club Venue Postcode','Assoc Venue Postcode');
	$file_data .= "\n";
  while (my $href = $q->fetchrow_hashref()) {
		$file_data .= join (
			',',
			"$href->{'Realm'}",
			"$href->{'SubRealm'}",
			"$href->{'AssocID'}",
			"$href->{'Association'}",
			"$href->{'ClubID'}",
			"$href->{'Club Name'}",
			"$href->{'Assoc Postcode'}",
			"$href->{'Club Postcode'}",
			"$href->{'Assoc Venue Postcode'}",
			"$href->{'Club Venue Postcode'}",
		);
		$file_data .= "\n";
	}
	return $file_data;
}

sub print_page {
	my ($body) = @_;
	print "Content-type: text/html\n\n";
	print qq[
<html>
<head>
	<title>Stats Reporting</title>
</head>
<body style="margin:0px;padding:0px;text-align:center;font-family:arial;">
	<div style="width:1024px;margin:0px auto 0px auto; padding:0px auto 0px auto;">
	<div align="center"><h1>Stats Reporting</h1></div>
	<div style="font-family:arial;font-size:12px;">
		$body
	</div>
	<div align="center">&copy Copyright SportingPulse (ANZ) Pty Ltd 2011. All Rights Reserved.</div>
</body>
</html>
	];
}

sub export_file {
	my ($data) = @_;
	use Time::Local;
	my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst)=localtime(time);
	print "Content-type: application/vnd.ms-excel\n";
	print "Content-Disposition: attachment;filename=export" . $mday . $mon . $year . ".csv\n\n";
	print $data;
}
