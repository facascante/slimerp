#!/usr/bin/perl -w

#
# $Header: svn://svn/SWM/trunk/misc/migrate_onoc_photos.pl 8250 2013-04-08 08:24:36Z rlee $
#

use lib "../web","..";
use Defs;
use Utils;
use DBI;
use strict;

#This program will assign national numbers to members in a realm
# that do not have one.

my $realm=8; #Realm to check
my $olddir='/u/registration/uploaded/OCAL';


my %Data=();
my $db=connectDB();
$Data{'db'}=$db;
$Data{'Realm'}=$realm;

my $st=qq[
	SELECT M.intMemberID, M.strExtKey AS oldID, A.intAlternateID AS oldAssocID
	FROM tblMember AS M 
		INNER JOIN tblMember_Associations AS MA ON M.intMemberID=MA.intMemberID
		INNER JOIN tblAssoc AS A ON MA.intAssocID=A.intAssocID
	WHERE M.intRealmID=$realm
];
my $q=$db->prepare($st) or query_error($st);
$q->execute() or query_error($st);

my $count=0;
while( my ($memberID, $oldID, $oldassocID)=$q->fetchrow_array())	{
	$count++;
	next if !$memberID;
debug("$memberID:$oldID:$oldassocID");
	my $oldfname="$olddir/$oldassocID/$oldID.jpg";
	next if !-e $oldfname;
  my $path='';
  {
    my $l=6 - length($memberID);
    my $pad_num=('0' x $l).$memberID;
    my (@nums)=$pad_num=~/(\d\d)/g;
    for my $i (0 .. $#nums-1) {
      $path.="$nums[$i]/";
      if( !-d "$Defs::fs_upload_dir/$path") { mkdir "$Defs::fs_upload_dir/$path",0755; }
    }
  }

  my $new_file="$Defs::fs_upload_dir/$path$memberID.jpg";
	print STDERR "$oldfname => $new_file\n";
	`mv $oldfname $new_file`;
}
print "count $count\n";
