#!/usr/bin/perl -w

#
# $Header: svn://svn/SWM/trunk/web/naburl_dummy.cgi 8249 2013-04-08 08:14:07Z rlee $
#

use DBI;
use CGI qw(:cgi escape unescape);

use strict;

use Lang;
use Utils;
use Payments;
use SystemConfig;
use ConfigOptions;
use Reg_common;
use Products;
use PageMain;
use CGI qw(param unescape escape);

use NABGateway;
use Gateway_Common;
use TTTemplate;

main();

sub main	{

	my $action = param('a') || 0;
	my $client = param('client') || 0;
	my $external= param('ext') || 0;
	my $logID= param('ci') || 0;
	my $encryptedID= param('ei') || 0;
	my $noheader= param('nh') || 0;
	my $chkv= param('chkv') || 0;
	my $formID= param('formID') || 0;
        my $session= param('session') || 0;
    warn "naburl sessiob:: $session";

    my $redirect_url = qq[$Defs::base_url/nabprocess_dummy.cgi?a=S&amp;ci=$logID&amp;client=$client&amp;chkv=$chkv&amp;formID=$formID&amp;session=$session];
    print redirect(-url=>$redirect_url);
   # print 
   # print "Content-type: text/html\n\n";
  #	print $body;
}

1;
