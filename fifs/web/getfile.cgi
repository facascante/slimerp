#!/usr/bin/perl 

#
# $Header: svn://svn/SWM/trunk/web/getfile.cgi 10409 2014-01-10 06:01:24Z dhanslow $
#

use strict;
use warnings;
use CGI qw(param);
use lib "..",".";
use Defs;
use Reg_common;
use Utils;
use Lang;
use UploadFiles;

main();	

sub main	{
	# GET INFO FROM URL
  my $client = param('client') || '';
	my $fileID = param('f') || 0;
                                                                                                        
  my %Data=();
  my $lang= Lang->get_handle() || die "Can't get a language handle!";
  $Data{'lang'}=$lang;
  my $target='main.cgi';
  $Data{'target'}=$target;
  my %clientValues = getClient($client);
  $Data{'clientValues'} = \%clientValues;
  my $memberID = $clientValues{'memberID'};

	$fileID =~ /^(\d+)$/;
	$fileID = $1;	
                                                                                                        
  # AUTHENTICATE
	my $isadmin = 0;
	my $allowed = 0;
	my $db = connectDB();
	if($clientValues{'userName'} eq 'SYSADMIN')	{
		if($clientValues{'authLevel'} eq 'iu5hm039m45hf2937y5gtr')	{
			$isadmin = 1;
			$allowed = 1;
		}
	}
	$db ||= connectDB();

	my $statement=qq[
		SELECT *
		FROM tblUploadedFiles
		WHERE intFileID = ?
	];
	my $query = $db->prepare($statement);
	$query->execute($fileID);
	my $dref =$query->fetchrow_hashref();
	$query->finish();
	disconnectDB($db);
	if(
		$dref->{'intFileType'} == $Defs::UPLOADFILETYPE_LOGO
		or $dref->{'intFileType'} == $Defs::UPLOADFILETYPE_PRODIMAGE
	)	{
		$allowed = 1;
	}
	if(!$allowed)	{
  	$db=allowedTo(\%Data);
		$allowed = 1;
	}
	
	if($allowed)	{
		if($dref and (allowFileAccess(\%Data, $dref) or $isadmin))	{
			my $filename= "$Defs::fs_upload_dir/files/$dref->{'strPath'}$dref->{'strFilename'}.$dref->{'strExtension'}";
			open (FILE, "<$filename");
			my $file='';
			while(<FILE>)  { $file.= $_; }
			close (FILE);
			my $size = $dref->{'intBytes'} || 0;
			my $contenttype ='';
			my $ext = $dref->{'strExtension'} || '';
			my $origfilename = $dref->{'strOrigFilename'} || '';
			if($ext eq 'jpg') {
				$contenttype = 'image/jpeg';
			}
			elsif($ext eq 'txt')  {
				$contenttype = 'text/html';
			}
			else  {
				$contenttype = 'application/download';
			}
			$origfilename =~s/.*\///g;
			$origfilename =~s/.*\\//g;
			print "Content-type: $contenttype\n";
			print "Content-length: $size\n";
			print "Content-transfer-encoding: $size\n";
			print qq[Content-disposition: attachement; filename = "$origfilename"\n\n];
			print $file;
		}
		else	{ print "Content-type: text/html\n\n";}
	}
	else	{ print "Content-type: text/html\n\n";}
}
