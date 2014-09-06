#!/usr/bin/perl -w

#
# $Header: svn://svn/SWM/trunk/misc/import_bowls_clubs.pl 9483 2013-09-10 04:48:08Z tcourt $
#

use lib  "..", "../web", "../web/comp";
#use lib "..", ".", "/u/regonew_live/web/", "/u/regonew_live/";
#use lib "..", ".", "/u/rego_v6/web/", "/u/rego_v6/";
use strict;
use Defs;
use DBI;
use CGI qw(:standard escape);
use Utils;
use DeQuote;
use GenCode;
use Seasons;
                                                                                                    
main();
1;

sub main	{
my $db=connectDB();
#print STDERR "LIB, FILE NAME etc\n";
#exit;
#### SETTINGS #############
my $countOnly=0;
my $REALM_ID = 2;
my $infile='bowls_clubs_120320.csv';
###########################

my %Data=();
$Data{'Realm'} = $REALM_ID;
$Data{'db'}=$db;

open INFILE, "<$infile" or die "Can't open Input File";

my $count = 0;
                                                                                                        
seek(INFILE,0,0);
$count=0;
my $insCount=0;
my $NOTinsCount = 0;

while (<INFILE>)	{
	my %parts = ();
	$count ++;
	next if $count == 1;
	chomp;
	my $line=$_;
	$line=~s///g;
	#$line=~s/,/\-/g;
	$line=~s/"//g;
	my @fields=split /\t/,$line;
	$parts{'DISTRICT'} = $fields[0] || 0;
	$parts{'REGION'} = $fields[1] || 0;
	$parts{'CLUBID'} = $fields[2] || 0;
	$parts{'CLUBNAME'} = $fields[3] || "";
	$parts{'ADDRESS'} = $fields[4] || "";
	$parts{'CITY'} = $fields[5] || "";
	$parts{'STATE'} = $fields[6] || "";
	$parts{'ZIP'} = $fields[7] || '';
	$parts{'PHONE'} = $fields[8] || "";
	$parts{'GREENS'} = $fields[9] || "";
	$parts{'WEBSITE'} = $fields[10] || "";
	$parts{'PFN'} = $fields[11] || "";
	$parts{'PSN'} = $fields[12] || "";
	$parts{'SFN'} = $fields[13] || "";
	$parts{'SSN'} = $fields[14] || "";

	my $clubID= $parts{'CLUBID'} || 0;
	
	if (! $clubID)	{
		## LOG IN FILE
	}
	else	{
		if ($countOnly)	{
			$insCount++;
			next;
		}

		my $st = qq[
			UPDATE
				tblClub
			SET
				strAddress1 = ?,
				strSuburb = ?,
				strState = ?,
				strPostalCode = ?,
				strPhone = ?,
				strWebURL = ?,
				dblClubCustomDbl1=?
			WHERE
				intClubID = ?
			LIMIT 1
		];
	my $query = $db->prepare($st) or query_error($st);
 	$query->execute($parts{'ADDRESS'}, $parts{'CITY'}, $parts{'STATE'}, $parts{'ZIP'}, $parts{'PHONE'}, $parts{'WEBSITE'}, $parts{'GREENS'}, $clubID) or query_error($st);
	
	$st = qq[
		INSERT INTO tblContacts
		(intRealmID, intAssocID, intClubID, intContactRoleID, strContactFirstname, strContactSurname)
		VALUES (?,?,?,?,?,?)
	];
	$query = $db->prepare($st) or query_error($st);
 	$query->execute(23, 13954, $clubID,1, $parts{'PFN'}, $parts{'PSN'}) if ($parts{'PFN'});
 	$query->execute(23, 13954, $clubID,4, $parts{'SFN'}, $parts{'SSN'}) if ($parts{'SFN'});

        }
	$insCount++;
}
$count --;
print STDERR "COUNT CHECK ONLY !!!\n" if $countOnly;
print STDERR "$insCount RECORDS INSERTED\n";

close INFILE;

}
1;
