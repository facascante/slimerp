#!/usr/bin/perl -w

#
# $Header: svn://svn/SWM/trunk/misc/import_photos.pl 9484 2013-09-10 04:49:41Z tcourt $
#

use lib "..", "../web", "../web/comp", "../web/sportstats";

use Defs;
use Utils;
use DBI;
use strict;
use Member qw(getAutoMemberNum);
use SystemConfig;

#This program will assign national numbers to members in a realm
# that do not have one.

my $imagedir = '/tmp/photos';

my $realm=7; #Realm to check
my $assocID=7766;

my %Data=();
my $db=connectDB();
$Data{'db'}=$db;
$Data{'Realm'}=$realm;
$Data{'SystemConfig'}=getSystemConfig(\%Data);

my $st_u = qq[
	UPDATE tblMember
	SET intPhoto = 1
	WHERE intMemberID = ?
];
my $q_u=$db->prepare($st_u);

my $st=qq[
	SELECT M.intMemberID, M.strMemberNo
		FROM tblMember AS M
			INNER JOIN tblMember_Associations AS MA ON M.intMemberID=MA.intMemberID
		WHERE intAssocID=$assocID
	];
my $q=$db->prepare($st) or query_error($st);
$q->execute() or query_error($st);

while( my ($id, $memnum)=$q->fetchrow_array())	{
	next if !$id;
	next if !$memnum;
	my $oldimagefile = $imagedir .'/'.$memnum .'.jpg';
	my $path = getPath($id);
	my $newimagefile = "$Defs::fs_upload_dir/$path/$id".'.jpg';

	if(-f $oldimagefile)	{
		#$q_u->execute($id);
		#`cp $oldimagefile $newimagefile`;
		debug("cp $oldimagefile $newimagefile");
	}
}


sub getPath {
	my ($id) = @_;
	my $path='';
  {
    my $l=6 - length($id);
    my $pad_num=('0' x $l).$id;
    my (@nums)=$pad_num=~/(\d\d)/g;
    for my $i (0 .. $#nums-1) { 
      $path.="$nums[$i]/"; 
      if( !-d "$Defs::fs_upload_dir/$path") { mkdir "$Defs::fs_upload_dir/$path",0755; }
    }
  }
	return $path;
}



