#
# $Header: svn://svn/SWM/trunk/web/UploadFiles.pm 8251 2013-04-08 09:00:53Z rlee $
#

package UploadFiles;
require Exporter;
@ISA =  qw(Exporter);
@EXPORT = qw(getUploadedFiles processUploadFile allowFileAccess deleteFile deleteAllFiles);
@EXPORT_OK = qw(getUploadedFiles processUploadFile allowFileAccess deleteFile deleteAllFiles);

use strict;
use lib "..",".";
use Defs;
use Utils;

use ImageUpload;
use FileUpload;
use CGI qw(:cgi param unescape escape);
use Reg_common;


my $File_MaxSize = 4*1024*1024; #4Mb;

sub getUploadedFiles	{
	my (
    $Data,
    $entityTypeID,
    $entityID,
		$fileType,
		$client,
  ) = @_;

	my $st = qq[
		SELECT 
			*,
			DATE_FORMAT(dtUploaded,"%d/%m/%Y %H:%i") AS DateAdded_FMT
		FROM tblUploadedFiles AS UF
		WHERE
			intEntityTypeID = ?
			AND intEntityID = ?
			AND intFileType = ?
	];
	my $q = $Data->{'db'}->prepare($st);
	$q->execute(
		$entityTypeID,
		$entityID,
		$fileType,
	);
	my @rows = ();
	while(my $dref = $q->fetchrow_hashref())	{
		my $url = "$Defs::base_url/getfile.cgi?client=$client&amp;f=$dref->{'intFileID'}";
		push @rows, {
			ID => $dref->{'intFileID'} || 0,
			Title => $dref->{'strTitle'} || '',
			URL => $url,
			Ext => $dref->{'strExtension'} || '',
			Size => sprintf("%0.2f",($dref->{'intBytes'} /1024/1024)),
			DateAdded => $dref->{'DateAdded_FMT'},
			DB => $dref,
		};
	}
	$q->finish();

	return \@rows;
}


sub processUploadFile	{
	my (
    $Data,
    $files_to_process,
    $EntityTypeID,
    $EntityID,
    $fileType,
  ) = @_;

	my $ret = '';

	for my $files (@{$files_to_process})	{
		my $err = _processUploadFile_single(
			$Data,
			$files->[0],
			$files->[1],
			$EntityTypeID,
			$EntityID,
			$fileType,
			$files->[2],
			$files->[3] || undef,
		);
		if($err)	{
			$ret .= "'$files->[0]' : $err<br>";
		}
	}

  return $ret;
}

sub _processUploadFile_single	{
	my (
		$Data,
		$title,
		$file_field,
		$EntityTypeID,
		$EntityID,
		$fileType,
		$permissions,
		$options,
	) = @_;

	$options ||= {};
  my $origfilename=param($file_field) || '';
	$origfilename =~s/.*\///g;
	$origfilename =~s/.*\\//g;
  return ('Invalid filename',0) if !$origfilename;
  my $extension='';
  {
    my @parts=split /\./,$origfilename;
    $extension=$parts[$#parts];
  }
  my @imageextensions =(qw(jpg gif jpeg bmp png ));
	my $isimage = 0;
  for my $i (@imageextensions)  {
    $isimage = 1 if $i eq lc $extension;
  }

	my $st_u = qq[
		UPDATE tblUploadedFiles
			SET 
				strFilename = ?,
				strPath = ?,
				intBytes = ?,
				strExtension = ?
			WHERE intFileID = ?
	];
	my $q_u = $Data->{'db'}->prepare($st_u);

	my $st_a = qq[
		INSERT INTO tblUploadedFiles
		(
			intFileType,
			intEntityTypeID,
			intEntityID,
			intAddedByTypeID,
			intAddedByID,
			strTitle,
			strOrigFilename,
			intPermissions,
			dtUploaded
		)
		VALUES (
			?,
			?,
			?,
			?,
			?,
			?,
			?,
			?,
			NOW()
		)

	];
	my $q_a = $Data->{'db'}->prepare($st_a);
	$q_a->execute(
		$fileType,
		$EntityTypeID,
		$EntityID,
		$Data->{'clientValues'}{'authLevel'},
		$Data->{'clientValues'}{'_intID'},
		$title,
		$origfilename,
		$permissions,
	);
	my $fileID = $q_a->{mysql_insertid} || 0;
	$q_a->finish();
	return ('Invalid ID',0) if !$fileID;

	my $path='';
	{
		my $l=6 - length($fileID);
		my $pad_num=('0' x $l).$fileID;
		my (@nums)=$pad_num=~/(\d\d)/g;
		for my $i (0 .. $#nums-1) { 
			$path.="$nums[$i]/"; 
			if( !-d "$Defs::fs_upload_dir/files/$path") { mkdir "$Defs::fs_upload_dir/files/$path",0755; }
		}
	}
	
	my $error = '';
  if($isimage )  { #Image
    my $filename= "$Defs::fs_upload_dir/files/"."$path$fileID.jpg";
    my %field=();
    {
      my $dimensions=$options->{'dimensions'} || '800x600';
      my $img=new ImageUpload(
        fieldname=> $file_field,
        filename=>$filename,
        maxsize=>$File_MaxSize,
        overwrite=>1,
      );
      my ($h, $w)=(0,0);
      if($img->Error()) {$error="Cannot create Upload object".$img->Error();}
      else  {
        my $ret=$img->ImageManip(Dimensions=>$dimensions);
        if($ret)  { $error=$img->Error(); }
        ($w, $h) =$img->Dimensions();
      }
			$q_u->execute(
				$fileID,
				$path,
				$img->Size(),
				'jpg',
				$fileID,
			);
    }

  }
  else { #File
    my $filename= "$Defs::fs_upload_dir/files/$path$fileID";
    my %field=();
    my $file=new FileUpload(
        fieldname => $file_field,
        filename => $filename,
        overwrite=>1,
        useextension=>1,
        maxsize=>$File_MaxSize,
    );
    my $ret=$file->get_upload();
    if($ret)  { $error=$file->Error(); }
    if(!$error) {
 			$q_u->execute(
				$fileID,
				$path,
				$file->Size(),
        $file->Ext(),
				$fileID,
			);
    }
  }
	if($error)	{
		#Remove file
		deleteFile( $Data, $fileID);
	}
	return $error || '';
}

sub deleteAllFiles	{
	my(
		$Data,
		$entityTypeID,
		$entityID,
		$fileType,
	) = @_;

	my $st = qq[
		SELECT intFileID
		FROM tblUploadedFiles AS UF
		WHERE
			intEntityTypeID = ?
			AND intEntityID = ?
			AND intFileType = ?
	];
	my $q = $Data->{'db'}->prepare($st);
	$q->execute(
		$entityTypeID,
		$entityID,
		$fileType,
	);
	while(my $dref = $q->fetchrow_hashref())	{
		deleteFile($Data , $dref->{'intFileID'});
	}
}

sub deleteFile	{
	my(
		$Data,
		$fileID,
	) = @_;

	my $st = qq[
		SELECT * 
		FROM tblUploadedFiles
		WHERE intFileID = ?
	];
	my $q = $Data->{'db'}->prepare($st);
	$q->execute(
		$fileID,
	);
	my $dref = $q->fetchrow_hashref();
	$q->finish();

	my $allowedaccess = allowFileAccess($Data, $dref);
	if($allowedaccess)	{

		my @tobedeleted=();
    my $filename= "$Defs::fs_upload_dir/files/$dref->{'strPath'}$dref->{'strFilename'}.$dref->{'strExtension'}";
		push @tobedeleted, $filename;
		unlink @tobedeleted;
	
		my $st_d = qq[
			DELETE FROM tblUploadedFiles
			WHERE intFileID = ?
		];
		my $q_d = $Data->{'db'}->prepare($st_d);
		$q_d->execute(
			$fileID,
		);
		$q_d->finish();
		return 1;
	}
	return 0;
}


sub allowFileAccess {
	my (
		$Data,
		$FileData,
	) = @_;

	my $LoginEntityTypeID = $Data->{'clientValues'}{'authLevel'};
	my $LoginEntityID = $Data->{'clientValues'}{'_intID'};
	my $permission = $FileData->{'intPermissions'} || 0;
	my $filetype = $FileData->{'intFileType'} || 0;
	if(
		$filetype == $Defs::UPLOADFILETYPE_PRODIMAGE
		or $filetype == $Defs::UPLOADFILETYPE_LOGO)	{
		return 1; #Not protected
	}
	#Permission options
		#1 = Available to Everyone
    #2 = Available to only the person adding it
    #3 = Available to all bodies at add level and above to which the entity is lnked
	return 1 if $permission == 1;
	if($permission == 2)	{
		return 1 if(
			$FileData->{'intAddedByTypeID'} == $LoginEntityTypeID	
			and $FileData->{'intAddedByID'} == $LoginEntityID	
		);	
		return 0;
	}
	if($permission == 3)	{
		return 1 if $LoginEntityTypeID >= $FileData->{'intAddedByTypeID'};
		return 0;
	}

	return 0;
}


1;
