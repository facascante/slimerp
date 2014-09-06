#
# $Header: svn://svn/SWM/trunk/web/GenerateAttachment.pm 8251 2013-04-08 09:00:53Z rlee $
#

package GenerateAttachment;

require Exporter;
@ISA =  qw(Exporter);
@EXPORT = qw(generate_attachment);
@EXPORT_OK = qw(generate_attachment);

use MIME::Entity;
use strict;

sub generate_attachment	{

	my($data_array_ref, $boundary, $filename, $filtercontents, $delimiter)=@_;
	$filtercontents||=0;

	$delimiter||="\t";
	$filename ||= 'regupdates.txt';
	$boundary= "====" . time() . "====" if !$boundary;
	# Build attachment contents;
	my $contents="";
	for my $i(0 .. $#{$data_array_ref})	{
		for my $j(0 .. $#{$data_array_ref->[$i]})	{
			if($j !=0)	{$contents.=$delimiter;}
			if(defined $data_array_ref->[$i][$j])	{
				$data_array_ref->[$i][$j]=~s/\t//g if $filtercontents;
				$contents.= "$data_array_ref->[$i][$j]";
			}
		}
		$contents.= "\n";
	}
	my $top = MIME::Entity->build(Type     => "multipart/mixed", Boundary => $boundary);
	### Attach stuff to it:
	$top->attach(
			Data => $contents,
			Filename => $filename,	
			Disposition => "attachment",
			Encoding => "base64",
	);

	my $body=	$top->stringify_body;
	$body=~s/\s*This is a multi-part message in MIME format...//g;

	return $body;
}

