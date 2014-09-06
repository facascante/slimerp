#
# $Header: svn://svn/SWM/trunk/web/ImageUpload.pm 8251 2013-04-08 09:00:53Z rlee $
#

package ImageUpload;

use FileUpload;
use strict;

sub new {

  my $this = shift;
  my $class = ref($this) || $this;
	my %params=@_;
  my $self ={};
  ##bless selfhash to class
  bless $self, $class;

	#Set Defaults
	$self->{error}='';
	$self->{size}=0;
	#Most of these should be passed directly to the FileUpload object;
	$params{type} ||= 'image'; # Type of object being uploaded
	$self->{existing}=$params{existing} || 0; # Don't upload file/use existing file
	$self->{fieldname}=$params{fieldname} or $self->LogError("No Fieldname specified"); # Fieldname on form to upload. 
																											#	If using existing this should be the filename of the existing file
	$self->{filename}=$params{filename} or $self->LogError("No Filename specified to save to"); # Filename of where to save file
	$self->{maxsize}=$params{maxsize} || 300000; # Maximum size of the upload post
	$self->{checkext}=$params{checkext} || 1; # Check the extension of file and reject certain types
	$self->{overwrite}=$params{overwrite} || 0; # Overwrite file if it already exists

	#Specific Image Handling options

	if(!$self->{exsiting})	{
		$self->{FileUpload}=new FileUpload(%params) or $self->LogError("Cannot create Upload object"); # FileUpload object
		if($self->{FileUpload}->Error()) {$self->LogError("Cannot create Upload object".$self->{FileUpload}->Error())	}; # FileUpload object
	}
	else	{$self->{FileUpload}='';}

  ##return the blessed hash
  return $self;
}

sub Error	{
  my $self = shift;
	return $self->{error};
}

sub LogError	{
  my $self = shift;
	my($error)=@_;
	$self->{error}.="$error\n";
}

sub Size	{
  my $self = shift;
	return $self->{size} || 0;
}
sub Width {
  my $self = shift;
	return $self->{Width} || 0;
}
sub Height {
  my $self = shift;
	return $self->{Height} || 0;
}

sub setProhibited	{
  my $self = shift;
	#pass in reference to array containing file extensions
	my ($array_ref)=@_;
	$self->{FileUpload}->setProhibited($array_ref) if !$self->{FileUpload};
}

sub Dimensions	{
  my $self = shift;
	return ($self->{Width},$self->{Height});
}

sub ImageManip	{
  my $self = shift;
	my %params=@_;

	if($params{filename})	{ $self->{filename}=$params{filename}; }
	if(!$self->{filename})	{$self->LogError("No Filename specified to save to"); }	# Filename of where to save file	
	$self->{NoModify}=$params{NoModify} || 0; # Do not perform any modifications on the image
	$self->{ChangeAspect}=$params{ChangeAspect} || 0; # Do not keep the aspect ratio of any image
	$self->{Resize}=$params{Resize} || 'iflarger'; # When to resize (always iflarger ifsmaller never)
	$self->{Dimensions}=$params{Dimensions} || ''; # The size to resize the image to 'widthxheight'
	$self->{DPI}=$params{DPI} || 0; # Change the Image DPI
	$self->{DPI}= 0 if $self->{'DPI'} =~/[^\d]/;
	if(!$self->{Dimensions})	{ $self->{Resize} = 'never';	}
	my($new_width, $new_height)=split /x/,$self->{Dimensions};
	if($self->{Dimensions} and (!$new_height or !$new_width or $new_height=~/[^\d]/ or $new_width=~/[^\d]/))	{
		$self->LogError("Invalid Dimensions $self->{Dimensions}");	
		return 1;	
	}

	my $inputfile='';
	if($self->{existing})	{
		#Generate image from an existing file
		$inputfile=$self->{fieldname} || '';
	}
	else	{
		#get file from uploader
		my $tempFilename='';
		for my $i (1 .. 10) {
			$tempFilename = "/tmp/temp_IMAGE".$$."_".time()."_$i";
			if (!-e $tempFilename) {last;}
			else	{$tempFilename='';}
		}
		if(!$tempFilename)	{
			$self->LogError("Cannot find a temporary filename");	
			return 1;	
		}
		my $ret=$self->{FileUpload}->get_upload(filename=>$tempFilename);
		if($ret)	{
			$self->LogError($self->{FileUpload}->Error());
			return $ret;	
		}
		$inputfile=$tempFilename;	
	}
	{
		#Here comes the Image Magic

		use Image::Magick;

		my $q = Image::Magick->new;
		{
			my $x= $q->Read($inputfile);
			if ($x) {
				#if(!$self->{existing})	{ unlink $inputfile;	}
				$self->LogError("Bad Image Type in Read :$x");
				return 1;
			}
		}
		if($self->{DPI})	{
			$q->Set("density"=>$self->{DPI});
			$q->Set("units"=>"PixelsPerInch");
		}
		if($self->{Resize} ne 'never')	{
			my $type='';
			if($self->{Resize} eq 'iflarger')	{	$type ='>';	}
			elsif($self->{Resize} eq 'ifsmaller')	{	$type ='<';	}
			my $absol='';
			if($self->{ChangeAspect})	{$absol='!';}
			my $geom = "'$new_width".'x'."$new_height$absol$type'";
			my $x = $q->Scale(geometry=>eval($geom));
			if ($x) {
				if(!$self->{existing})	{ unlink $inputfile;	}
				$self->LogError("Cannot Resize :$x");
				return 1;
			}
		}

		#Check if we can actually write the file to where we want to

		if(-e $self->{filename})  {
			#Does the file already exist
			if($self->{overwrite})  {
				if(!-w $self->{filename}) {
					$self->LogError("Cannot overwrite existing file: $self->{filename}");
					return 1;
				}
			}
			else  {
				$self->LogError("File already exists: $self->{filename}");
				return 1;
			}
		}
		else  {
			my $dir=$self->{filename};
			$dir=~ s/\/[^\/]*?$//g;
			if(!-d $dir or !-w $dir ) {
				$self->LogError("Invalid Directory or cannot write to directory: $self->{filename}");
				return 1;
			}
		}
		my $x = $q->Write($self->{filename});
		if ($x) {
			$self->LogError("Cannot Write file $self->{filename} :$x");
			return 1;
		}
		$x = $q->Read($self->{filename});
		if ($x) {
			unlink $self->{filename};
			$self->LogError("Cannot Read back file $self->{filename} :$x");
			return 1;
		}
		if(!$self->{existing})	{ unlink $inputfile;	}

		$self->{Width}= $q->Get('columns');
		$self->{Height}= $q->Get('rows');
		$self->{size} = (stat($self->{filename}))[7];

	}
	return 0;
}

1;
