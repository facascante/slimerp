#!/usr/bin/perl 

#
# $Header: svn://svn/SWM/trunk/web/getphoto.cgi 10409 2014-01-10 06:01:24Z dhanslow $
#

use strict;
use warnings;
use CGI qw(param);
use lib "..",".";
use Defs;
use Reg_common;
use Utils;
use Lang;

main();	

sub main	{
	# GET INFO FROM URL
  my $client = param('client') || '';
  my $temp= param('t') || '';
  my $tempfile_prefix = param('tf') || '';
  my $photo_auth = param('pa') || '';
                                                                                                        
  my %Data=();
  my $lang= Lang->get_handle() || die "Can't get a language handle!";
  $Data{'lang'}=$lang;
  my $target='main.cgi';
  $Data{'target'}=$target;
  my %clientValues = getClient($client);
  $Data{'clientValues'} = \%clientValues;
  my $memberID = $clientValues{'memberID'};
	
  # AUTHENTICATE
	$tempfile_prefix = ''  if ($tempfile_prefix and $tempfile_prefix =~ /[^0-9a-zA-Z]/);
	if($tempfile_prefix)	{
		
		my $filename="$Defs::fs_upload_dir/temp/$tempfile_prefix.jpg";
		$filename="$Defs::fs_upload_dir/temp/$tempfile_prefix"."_temp.jpg" if $temp;
		open (FILE, "< $filename") || die("Can't open file $filename\n");
		my $img='';
		while(<FILE>)  { $img.= $_; }
		close (FILE);
		print "Content-type: image/jpeg\n\n";
		print $img;

	}
	else	{
		my $db = '';
		if(!$photo_auth)	{
				$db=allowedTo(\%Data);
		}
		else	{
			$db = connectDB();
			my ($mID, $hash) = split /f/,$photo_auth,2;
			my $checkhash = authstring($mID);
			if($checkhash eq $hash)	{
				$memberID = $mID;
			}
			else	{
				$db = undef;
			}
		}
		if($db)	{
			my $statement=qq[
				SELECT intPhoto
				FROM tblMember
				WHERE intMemberID = ?
			];
			my $query = $db->prepare($statement);
			$query->execute($memberID);
			my($hasphoto)=$query->fetchrow_array();
			$query->finish();
			disconnectDB($db);
			if($hasphoto)	{
				my $path='';
				{
					my $l=6 - length($memberID);
					my $pad_num=('0' x $l).$memberID;
					my (@nums)=$pad_num=~/(\d\d)/g;
					for my $i (0 .. $#nums-1) { $path.="$nums[$i]/"; }
				}
				my $filename="$Defs::fs_upload_dir/$path$memberID.jpg";
				$filename="$Defs::fs_upload_dir/$path$memberID".'_temp.jpg' if $temp;
				open (FILE, "<$filename");
				my $img='';
				while(<FILE>)  { $img.= $_; }
				close (FILE);
                if ($img) {
                    print "Content-type: image/jpeg\n\n";
                    print $img;
                }
                else {
                    print "Content-type: text/html\n\n"; 
                }
			}
			else	{ print "Content-type: text/html\n\n";}
		}
		else	{ print "Content-type: text/html\n\n";}
	}
}
