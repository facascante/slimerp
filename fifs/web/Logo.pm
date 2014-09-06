#
# $Header: svn://svn/SWM/trunk/web/Logo.pm 10965 2014-03-13 02:18:07Z apurcell $
#

package Logo;
require Exporter;
@ISA =  qw(Exporter);
@EXPORT = qw(handle_logos showLogo);
@EXPORT_OK = qw(handle_logos showLogo);

use strict;
use lib "..",".";
use Defs;
use Utils;

use ImageUpload;
use FileUpload;
use CGI qw(:cgi param unescape escape);
use Reg_common;
use AuditLog;
use UploadFiles;
use FormHelpers;


sub showLogo	{
	my(
		$Data, 
		$entityTypeID,
		$entityID,
		$client,
		$editlink,
		$width,
		$height,
		$url_only,
	)=@_;

	return '' if !$entityTypeID;
	return '' if !$entityID;

	$width ||= 0;
	$height ||= 0;
	my $logo = getUploadedFiles(
		$Data,
		$entityTypeID,
		$entityID,
		$Defs::UPLOADFILETYPE_LOGO,
		$client,
	);

	my $body = '';
	my $url = '';
	if($logo and $logo->[0])	{
		$url = $logo->[0]{'URL'} || return '';
	}
	my $style = '';
	$style .= 'height: '.$height.'px;' if $height;
	$style .= 'width: '.$width.'px;' if $width;

	#Removing style on logo, seems unnecessarily restrictive. Regs - 13/08/2013

	if($editlink)	{
		$url ||= "$Defs::base_url/images/logo_default.jpg";
		my $linkurl = "$Defs::base_url/$Data->{'target'}?client=$client&amp;a=LOGO_E";
		my $logotxt = $Data->{'lang'}->txt('Edit Logo');
		$body = qq[
			<div class = "logo logoedit">
				<a href = "$linkurl" class="logo-link-image"><img src ="$url" alt = "Logo" title = "$logotxt"></a>
				<a href = "$linkurl" class="logo-link-text">$logotxt</a>
			</div>
		];
	}
	elsif ($url_only){
	    return $url || '';
	}
	else	{
		return '' if !$url;
		$body = qq[
			<div class = "logo">
				<img src ="$url" alt = "Logo">
			</div>
		];
	}

	return $body;
}

sub handle_logos {
	my (
		$action, 
		$Data, 
		$entityTypeID,
		$entityID,
		$client,
	) = @_;

  my $resultHTML='';
	
	return ('No entity specified','') if( !$entityTypeID or !$entityID);
	my $newaction='';

  my $type = '';

	$action ||= 'LOGO_E';

  if ($action eq 'LOGO_u') {
		my $retvalue = process_logo_upload( 
			$Data,
			$entityTypeID,
			$entityID,
			$client,
		);
		if($retvalue)	{
			$resultHTML .= qq[<div class="warningmsg">$retvalue</div>];
		}
		else	{
			$resultHTML .= qq[<div class="OKmsg">].$Data->{'lang'}->txt('Logo Updated').'</div>';
		}

		$type = 'Update Logo';
	}
	$resultHTML .= edit_logo_form(
		$Data,
		$entityTypeID,
		$entityID,
		$client,
	);

  if ($type) {
    auditLog($entityID, $Data, $type, 'Logo');
  }

	return ($resultHTML,$type);
}


sub edit_logo_form {
	my(
		$Data, 
		$entityTypeID,
		$entityID,
		$client,
	)=@_;

	my $l = $Data->{'lang'};
	my $target=$Data->{'target'} || '';
	my $logo = showLogo(
		$Data, 
		$entityTypeID,
		$entityID,
		$client,
		0,
	);

	my $title = $l->txt('Update Logo');
	my $existing = $l->txt('Existing Logo');
	my $body = '';
	if($logo)	{
		$body .=	qq[
		<div class="sectionheader">$existing</div>
		$logo
		];
	}
	$body .=	qq[
	<div class="sectionheader">$title</div>
		<div id="logoselect">
		<p>To add a logo click the browse button and find the logo you wish to upload from your computer.  When you have selected the file click the "Upload" button.</p>
		<form action="$target" method="POST" enctype="multipart/form-data">
				<td><input type="file" name="logo" class="browse-file"></td>
			<br>
			<input type="submit" name="submitb" value="Upload" onclick="logo.getElementById('logoselect').style.display='none';logo.getElementById('pleasewait').style.display='block'" class="button proceed-button">
			<input type="hidden" name="client" value="].unescape($client).qq[">
			<input type="hidden" name="a" value="LOGO_u">
		</form>
		</div>
	];
	return $body;
}


sub process_logo_upload	{
	my(
		$Data, 
		$entityTypeID,
		$entityID,
		$client,
	)=@_;

	deleteAllFiles(
		$Data, 
		$entityTypeID,
		$entityID,
    $Defs::UPLOADFILETYPE_LOGO,
	);
	my @files_to_process = ();

	push @files_to_process, ['Logo', 'logo', 1, {dimensions => '200x200'}];
	my $retvalue = processUploadFile(
		$Data, 
		\@files_to_process,
		$entityTypeID,
		$entityID,
    $Defs::UPLOADFILETYPE_LOGO,
	);
	return $retvalue;
}


1;
