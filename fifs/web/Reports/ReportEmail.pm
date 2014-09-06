#
# $Header: svn://svn/SWM/trunk/web/Reports/ReportEmail.pm 10123 2013-12-03 02:08:28Z tcourt $
#

package Reports::ReportEmail;

require Exporter;
@ISA =  qw(Exporter);
@EXPORT = qw(sendDataByEmail);
@EXPORT_OK = qw(sendDataByEmail);

use strict;
use lib '.', '..', '../..';
use Mail::Sendmail;
use MIME::Entity;
use Defs;


sub sendDataByEmail {
	my $self = shift;
	my (
		$data 
	) = @_;
	return 1 if !$data;
	my $email = $self->{'RunParams'}{'SendToEmail'} || return 1;

	my $message = $self->{'Config'}{'EmailMessage'} 
		|| 'The data you requested for export is included in the attached file';
	my $subject = $self->{'Config'}{'EmailSubject'} 
		|| 'Data Export';
	my $from_address= $self->{'Config'}{'EmailFromAddress'} 
		|| $Defs::admin_email;
	my $filename = $self->{'Config'}{'EmailAttachmentName'} 
		|| 'reportdata.txt';
	my $logfilename = $self->{'Config'}{'EmailLogFilename'} 
		|| $Defs::mail_log_file;

	my $boundary="====r53q6w8sgydixlgfxzdkgkh====";
	my $contenttype=qq[multipart/mixed; boundary="$boundary"];
	my $attachment=make_attachment(
		$data, 
		$boundary, 
		$filename, 
	);

	if(
		sendEmail(
			$email, 
			$attachment, 
			$boundary, 
			$contenttype, 
			$message, 
			$subject, 
			$from_address, 
			$logfilename,
		))	{
		#Error Sending Mail
		return -1;
	}
	return 0;
}

#---- Subroutines ----


sub sendEmail	{
	my (
		$email, 
		$attachment, 
		$boundary, 
		$contenttype, 
		$message_str, 
		$subject, 
		$from_address, 
		$logfile
	)=@_;
	$subject ||= "Data Export",
	my $message=qq[

This is a multi-part message in MIME format...

--].$boundary.qq[
Content-Type: text/plain
Content-Disposition: inline
Content-Transfer-Encoding: binary\n\n];
	
	$from_address||='';
	my %mail = ( 				
						To => "$email",
						From  => $from_address,
						Subject => $subject,
						Message => $message,
						'Content-Type' => $contenttype,
						'Content-Transfer-Encoding' => "binary"
	);
	$mail{Message}.="$message_str\n\n------------------------------------------\n\n" if $message_str;
	$mail{Message}.="\n\n<$from_address>" if $from_address;
	$mail{Message}.=$attachment if $attachment;

	my $error=1;
	if($mail{To}) {
		if($logfile)	{
			open MAILLOG, ">>$logfile" or print STDERR "Cannot open MailLog $logfile\n";
		}
		if (sendmail %mail) {
			print MAILLOG (scalar localtime()).":EXPORTREG:$mail{To}:Sent OK.\n" if $logfile;
			$error=0;
		}
		else {
			print MAILLOG (scalar localtime())." EXPORTREG:$mail{To}:Error sending mail: $Mail::Sendmail::error \n" if $logfile;
		}
		close MAILLOG if $logfile;
	}
	return $error;
}

sub make_attachment	{

	my(
		$data, 
		$boundary, 
		$filename, 
		$delimiter,
	) = @_;

	$filename ||= 'export.txt';
	$boundary= "====" . time() . "====" if !$boundary;
	# Build attachment contents;
	$data =~ s///g;
	my $top = MIME::Entity->build(Type     => "multipart/mixed", Boundary => $boundary);
	### Attach stuff to it:
	$top->attach(
			Data => $data,
			Filename => $filename,	
			Disposition => "attachment",
			Encoding    => "quoted-printable",
	);

	my $body=	$top->stringify_body;
	$body=~s/\s*This is a multi-part message in MIME format...//g;

	return $body;
}


1;
