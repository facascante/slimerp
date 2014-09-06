#!/usr/bin/perl -w

#
# $Header: svn://svn/SWM/trunk/web/payments_failure.cgi 8249 2013-04-08 08:14:07Z rlee $
#

use DBI;
use CGI qw(:cgi escape unescape);

use strict;

use lib "..",".",'PaymentSplit';

use Lang;
use Utils;
use Date::Calc qw(:all);
use DeQuote;
use MD5;
use Payments;

main();

sub main	{

	my $client = param('client') || 0;
	my $clientTransRefID= param('ci') || 0;
	print STDERR "START OF PAYMENT.cgi : CLIENT:$client: CTRef: $clientTransRefID: \n";

	### NEED TO CREATE $DATA !!!
	my $Data = 1;
	#my $db= $Data->{'db'};
	my $db=connectDB();

	my $body = '';
	## GENERAL VARIABLES

	processTransLogFailure($db, $clientTransRefID, '', '', '', '', '');

disconnectDB($db);
print qq[Content-type: text/html\n\n] if ! $body;

}
exit;
