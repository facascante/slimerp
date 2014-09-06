#
# $Header: svn://svn/SWM/trunk/web/Mail/ExternalMailer_BulkMail.pm 9569 2013-09-20 05:51:06Z tcourt $
#

package Mail::ExternalMailer_BulkMail;

use strict;
use lib ".", "..", "../..";

our @ISA =qw(Mail::ExternalMailer_BaseObj);

use Mail::ExternalMailer_BaseObj;
use Mail::Bulkmail;
use Mail::Bulkmail::Server;

sub new {

  my $this = shift;
  my $class = ref($this) || $this;
	my %params=@_;
  my $self ={};
  ##bless selfhash to class
  bless $self, $class;

  return $self;
}

sub send {
	my $self = shift;
	my %params=@_;

	my @options = (qw(
		HTMLMessage
		TEXTMessage
		MessageID
		Subject
		FromName
		FromAddress
		ReplyToAddress
		BCCRecipients
		ToAddress
		ToName
	));
	for my $o (@options)	{
		$params{$o} ||= '';
	}
	my %compulsory = (
		MessageID => 1,
		Subject => 1,
		FromAddress => 1,
		BCCRecipients => 1,
		ToAddress => 1,
	);

	my $error = '';
	if (!$params{'HTMLMessage'}
		and !$params{'TextMessage'}
	)	{
		return (0,'Need Message');
	}
	for my $k (keys %compulsory)	{
		return (0,'Need '.$k) if !$params{$k};
	}

  my %Emails=();
 	for my $email (@{$params{'BCCRecipients'}})	{
    $email =~s/^'//g;
    $email =~s/'$//g;
    my $domain=$email;
    $domain=~s/.*\@//g or next;
    $Emails{$email}=$domain;
  }

  #Now sort by domain
  my @Emails;
  foreach my $key (sort {$Emails{$a} cmp $Emails{$b}} keys %Emails)       {
    push @Emails, $key;
  }
	my $server = Mail::Bulkmail::Server->new(
				 'Smtp' => "localhost",
				 'Port' => 25,
				 'Tries' => 5,
				 'Domain' => 'sportingpulse.com',
	) || die Mail::Bulkmail::Server->error();
	$server->Domain('sportingpulse.com');
	$server->Tries(5);
	my $message = getMessageContent($params{'HTMLMessage'},$params{'TextMessage'});

	my $bulk = Mail::Bulkmail->new(
		"LIST" => \@Emails,
		"From" => qq["$params{'FromName'}" <$params{'FromAddress'}>],
		"To" => qq["$params{'ToName'}" <$params{'ToAddress'}>],
		"Reply-To" => $params{'ReplyToAddress'},
		"Subject" => $params{'Subject'},
		"use_envelope" => '1',
		"envelope_limit" => '200',
		"Message" => $message,
		servers => [$server],
	) or Mail::Bulkmail->error();
	$bulk->header("Content-type", 'multipart/alternative; boundary="----=_NextPart_001_002D_01C21C53.27797610"');
	$bulk->bulkmail;
	return 1;
}

sub getMessageContent {
  my($html, $text)=@_;

  return '' if !$text;
	$text ||= '';
	$html ||= $text;
  my $message =qq[
------=_NextPart_001_002D_01C21C53.27797610
Content-Type: text/plain; charset="us-ascii"
Content-Transfer-Encoding: 8bit

This email has been sent as HTML.  
Your email client seems to be having problems with viewing it.

$text


------=_NextPart_001_002D_01C21C53.27797610
Content-Type: text/html; charset="us-ascii"
Content-Transfer-Encoding: 8bit

$html


------=_NextPart_001_002D_01C21C53.27797610--
  ];
  return $message;
}


1;
