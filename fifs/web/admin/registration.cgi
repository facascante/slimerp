#!/usr/bin/perl

#
# $Header: svn://svn/SWM/trunk/web/admin/decodeURL.cgi 10127 2013-12-03 03:59:01Z tcourt $
#

use strict;
use lib ".","..","../..","../comp";

use Defs;
use Utils;
use Reg_common;
use DBI;
use CGI qw(param unescape escape);
use AdminPageGen;
use TTTemplate;
use Registration;

main();

sub main  {

# Variables coming in

  my $body = "";
  my $action = param('action') || 'D';
  my $target="registration.cgi";

  my $db = connectDB();
  my $cache = new MCache;
  if($action eq 'A')    {
    $body = add_registration($db,$action,$target);
  }
  else  {
    $body = display_screen($db,$action,$target);
  }

  disconnectDB($db) if $db;
  print_adminpageGen($body, "", "");
}


