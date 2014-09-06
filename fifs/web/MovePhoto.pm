#
# $Header: svn://svn/SWM/trunk/web/MovePhoto.pm 8251 2013-04-08 09:00:53Z rlee $
#

package MovePhoto;
require Exporter;
@ISA =  qw(Exporter);
@EXPORT = qw(movePhoto);
@EXPORT_OK = qw(movePhoto);

use strict;
use lib "..",".";
use Defs;
use Utils;

use ImageUpload;
use FileUpload;
use CGI qw(:cgi param unescape escape);
use Reg_common;
use AuditLog;
use File::Copy;

sub movePhoto	{

	my ($db, $newID, $existingID) =@_;

	my $new_file = '';
	my $existing_file = '';
	{
		my $path = '';
		my $l=6 - length($existingID);
		my $pad_num=('0' x $l).$existingID;
		my (@nums)=$pad_num=~/(\d\d)/g;
		for my $i (0 .. $#nums-1) {
			$path.="$nums[$i]/";
			if( !-d "$Defs::fs_upload_dir/$path") { mkdir "$Defs::fs_upload_dir/$path",0755; }
		}
		$existing_file ="$Defs::fs_upload_dir/$path$existingID.jpg";
	}

	{
		my $path = '';
		my $l=6 - length($newID);
		my $pad_num=('0' x $l).$newID;
		my (@nums)=$pad_num=~/(\d\d)/g;
		for my $i (0 .. $#nums-1) {
			$path.="$nums[$i]/";
			if( !-d "$Defs::fs_upload_dir/$path") { mkdir "$Defs::fs_upload_dir/$path",0755; }
		}
		$new_file="$Defs::fs_upload_dir/$path$newID.jpg";
	}
	
	if(!-e $new_file and -e $existing_file)      { 
        copy($existing_file, $new_file); 
				my $st = qq[
					UPDATE tblMember SET intPhoto =1 WHERE intMemberID=$newID LIMIT 1
				];
				$db->do($st);
		} 

}
