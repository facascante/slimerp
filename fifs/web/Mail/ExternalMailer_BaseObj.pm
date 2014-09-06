#
# $Header: svn://svn/SWM/trunk/web/Mail/ExternalMailer_BaseObj.pm 9568 2013-09-20 05:49:06Z tcourt $
#

package Mail::ExternalMailer_BaseObj;

use strict;
use lib "..","../..";
use TTTemplate;
use CGI;


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


	return 1;
}


1;
