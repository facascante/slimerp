#
# $Header: svn://svn/SWM/trunk/web/FileUpload.pm 8251 2013-04-08 09:00:53Z rlee $
#

package FileUpload;

use CGI qw(standard);
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
	$self->{type}=$params{type} || 'file'; # Type of object being uploaded
	$self->{CGI}=$params{CGI} || new CGI or $self->LogError("Cannot create CGI object"); # CGI object
	$self->{fieldname}=$params{fieldname} or $self->LogError("No Fieldname specified"); # Fieldname on form to upload
	$self->{filename}=$params{filename} or $self->LogError("No Filename specified to save to"); # Filename of where to save file
	$self->{maxsize}=$params{maxsize} || 300000; # Maximum size of the upload post
	$self->{checkext}=$params{checkext} || 1; # Check the extension of file and reject certain types
	$self->{overwrite}=$params{overwrite} || 0; # Overwrite file if it already exists
	$self->{useextension}=$params{useextension} || 0; # Append existing extension to new file name
	$self->{ProhibitedExtensions}=[qw(bat exe scr com vbs)];

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

sub Ext	{
  my $self = shift;
	return $self->{ext} || '';
}

sub setProhibited	{
  my $self = shift;
	#pass in reference to array containing file extensions
	my ($array_ref)=@_;
	$self->{ProhibitedExtensions}=$array_ref;
}

sub get_upload	{
	#Returns 1 on failure
	#Call Error to get type of error
  
my $self = shift;
	my %params=@_;
	if(exists $params{filename} and $params{filename})	{
		$self->{filename}=$params{filename};
	}


	my $cgi=$self->{CGI};
	$self->{DATA_orginalfilename}=$cgi->param($self->{fieldname}) || '';
	my @parts=split /\./,$self->{DATA_orginalfilename};
	$self->{ext}=$parts[$#parts];
	$self->{'ext'} =~/([\dA-Za-z]+)/; #Untaint
	$self->{'ext'} = $1;
	if($self->{useextension})	{	$self->{filename}.=".$self->{ext}";	}
	if($self->{checkext})	{
		for my $badext (@{$self->{ProhibitedExtensions}})	{
			if($self->{ext} eq $badext)	{ $self->LogError("$self->{ext} Not allowed");	return 1;	}
		}
	}
	
	#OK we have tested the file extension, now let's check to see if we can put it somewhere

	if(-e $self->{filename})	{
		#Does the file already exist
		if($self->{overwrite})	{
			if(!-w $self->{filename})	{ 
				$self->LogError("Cannot overwrite existing file: $self->{filename}");	
				return 1;	
			} 
		}
		else	{
			$self->LogError("File already exists: $self->{filename}");	
			return 1;	
		}
	}
	else	{
		my $dir=$self->{filename};
		$dir=~ s/\/[^\/]*?$//g;
		if(!-d $dir or !-w $dir )	{ 
			$self->LogError("Invalid Directory or cannot write to directory: $self->{filename}");	
			return 1;	
		} 
	}

	#If we are here then we can write to the file.

	my $file = $cgi->upload($self->{fieldname});
	if (!$file or $cgi->cgi_error) {
		$self->LogError("Problems with uploading the file".$cgi->cgi_error." also remember to check encoding type.");	
		return 1;	
	}

	#OK we've now done some checking lets start writing the file and see what happens
	my $size=0;
	if (open(FILEOUT,">$self->{filename}")) {
		binmode FILEOUT;
		while(<$file>)  {
			if($size > $self->{maxsize})	{
				close(FILEOUT);
				$self->LogError("File too large. The file should be less than ".($self->{maxsize}/1000)."Kb");	
				unlink $self->{filename};
				return (-1);
			}
			print FILEOUT;
			$size += length;
		}
		$self->{size}=$size;
		close FILEOUT;
		return $self->LogError("No File Selected") if !$size;	
	}
	else	{
		$self->LogError("Cannot open file for writing");	
		return 1;	
	}

	return 0;
}

1;
