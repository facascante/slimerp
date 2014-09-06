#
# $Header: svn://svn/SWM/trunk/web/Email.pm 8251 2013-04-08 09:00:53Z rlee $
#

package Email;

require Exporter;
@ISA =  qw(Exporter);
@EXPORT = qw(sendEmail);
@EXPORT_OK = qw(sendEmail);
use lib "..";
use strict;
use Mail::Sendmail;
#use Utils;
use DeQuote;


sub sendEmail {
#Sends an email with both html and text parts

my ($to, $from, $subject, $header, $htmlMsg, $textMsg, $maillog_text, $BCC) = @_;

$from ||= $Defs::donotreply_email;
$from = $Defs::donotreply_email if ($from eq ";");
$htmlMsg= qq[
	<html>
		<head>
			<META http-equiv=Content-Type content="text/html; charset=us-ascii">
		</head>
		<body style="font-family:Arial, Sans-Serif">
		 	<h1>$header</h1>
			$htmlMsg	
		</body>
	</html>
];

my $headerLength= length($header);
my $headerLine= '';
for (my $i=0;  $i<$headerLength; $i++) {
	$headerLine.='-';
}

$textMsg= qq[
				$textMsg\n\n

				$headerLine\n
			];

	my $message=qq[
This is a multi-part message in MIME format.

------=_NextPart_000_003D_01C216C5.D0AA8640
Content-Type: multipart/alternative; boundary="----=_NextPart_001_003E_01C216C5.D0B3AE00"


------=_NextPart_001_003E_01C216C5.D0B3AE00
Content-Type: text/plain; charset="us-ascii"
Content-Transfer-Encoding: 8bit

$textMsg

------=_NextPart_001_003E_01C216C5.D0B3AE00
Content-Type: text/html; charset="us-ascii"
Content-Transfer-Encoding: 8bit

	$htmlMsg


------=_NextPart_001_003E_01C216C5.D0B3AE00--

	];


	my %mail = (
		To      => "$to",
		From    => "$from",
		Subject => "$subject",
	  Message => $message,
	  'MIME-Version' => '1.0',
	  'Content-Type' => 'multipart/related; boundary="----=_NextPart_000_003D_01C216C5.D0AA8640"',
	);
	open MAILLOG, ">>$Defs::mail_log_file" or print STDERR "Cannot open MailLog $Defs::mail_log_file\n";
	if($mail{To} ne "") {
		if (sendmail(%mail)) {
			print MAILLOG (scalar localtime()).":$maillog_text :$mail{To}: FROM $from Sent OK\n";
			print scalar localtime().":$maillog_text :$mail{To}: FROM $from Sent OK\n";
	#close MAILLOG;
			return 1;
		}
		else {
			print MAILLOG (scalar localtime()).":$maillog_text:$mail{To}:Error sending mail: $Mail::Sendmail::error\n"; 
			print scalar localtime().":$maillog_text:$mail{To}:Error sending mail: $Mail::Sendmail::error\n";
	#close MAILLOG;
			return 0;
		}
	}
}

1;

