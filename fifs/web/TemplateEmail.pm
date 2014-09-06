#
# $Header: svn://svn/SWM/trunk/web/TemplateEmail.pm 9392 2013-08-30 01:56:45Z dhanslow $
#

package TemplateEmail;
require Exporter;
@ISA =	qw(Exporter);
@EXPORT = qw(sendTemplateEmail);
@EXPORT_OK = qw(sendTemplateEmail);

use strict;
use lib "..";
use Defs;
use Utils;
use Mail::Sendmail;
use TTTemplate;

$ENV{'PATH'} = '/bin';

sub sendTemplateEmail	{
	#Returns 1 on success 0 on failure
	my(
		$Data,
		$templatefile,
		$templatedata,
		$toaddress,
		$subject,
		$fromaddress,
		$ccaddress,
		$bccaddress,
	) = @_;

	my $templateblob = runTemplate(
		$Data,
		$templatedata,
		"emails/$templatefile",
	);

	return wantarray ? (0,'') : 0 if !$templateblob;
	return wantarray ? (0,'') : 0 if (!$toaddress and !$ccaddress and !$bccaddress);
	return wantarray ? (0,'') : 0 if !$subject;
	$fromaddress ||= "$Defs::admin_email_name <$Defs::admin_email>";
	if ($fromaddress eq ';')        {
		$fromaddress = "$Defs::admin_email_name <$Defs::admin_email>";
	}

	my $message=qq[
This is a multi-part message in MIME format.

------=_NextPart_000_003D_01C216C5.D0AA8640
Content-Type: multipart/alternative; boundary="----=_NextPart_001_003E_01C216C5.D0B3AE00"


------=_NextPart_001_003E_01C216C5.D0B3AE00
Content-Type: text/plain; charset="us-ascii"
Content-Transfer-Encoding: 8bit

This email has been sent as HTML.  

If you see only this message then you need to configure
your email client to be able to view HTML messages.

------=_NextPart_000_003D_01C216C5.D0AA8640
Content-Type: text/html; charset="us-ascii"
Content-Transfer-Encoding: 8bit

$templateblob

------=_NextPart_000_003D_01C216C5.D0AA8640--
	];

	#fix email addresses if no toaddress, but we have cc address or bcc address
	if($toaddress eq '' and $ccaddress) {
		$toaddress = $ccaddress;
		$ccaddress = '';
	} elsif ($toaddress eq '' and $bccaddress)
	{
		$toaddress = $bccaddress;
		$bccaddress = '';
	}
	
	my %mail = (
		To      => $toaddress,
		From    => $fromaddress,
		Subject => $subject,
	  Message => $message,
	  'MIME-Version' => '1.0',
	  'Content-Type' => 'multipart/related; boundary="----=_NextPart_000_003D_01C216C5.D0AA8640"',
	  'Content-Transfer-Encoding' => "quoted-printable"
	);
	$mail{'Cc'} = $ccaddress if $ccaddress;
	$mail{'Bcc'} = $bccaddress if $bccaddress;
	open MAILLOG, ">>$Defs::mail_log_file" or warn("Cannot open MailLog\n");
	if($mail{To}) {
		if($Defs::global_mail_debug)	{
			$mail{To}=$Defs::global_mail_debug;
			delete $mail{'Cc'};
			delete $mail{'Bcc'};
		}
		if (sendmail(%mail)) {
			print MAILLOG (scalar localtime()).":Template:$subject:$mail{To}:Sent OK\n";
			#Sucess sending email
			return wantarray ? (1,$message) : 1;
		}
		else {
			print MAILLOG (scalar localtime()).":Template:$subject:$mail{To}:Error sending mail: $Mail::Sendmail::error \n";
			warn("no send  $Mail::Sendmail::error");
			return wantarray ? (0,$message) : 0;
		}
	}
}

1;

