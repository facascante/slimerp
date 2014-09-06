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
use Approval;

main();

sub main  {

# Variables coming in

  my $body = "";
  my $action = param('a') || '';
  my $roleID = param('RID') || '';
  my $WFTaskID = param('TID') || '';
  
  my $db = connectDB();
  my $cache = new MCache;

  $body = list_tasks($db,$roleID,$WFTaskID);

  disconnectDB($db) if $db;
  print_adminpageGen($body, "", "");
}


