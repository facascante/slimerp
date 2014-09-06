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
use MatrixManage;

main();

sub main  {

# Variables coming in

  my $body = "";
  my $action = param('a') || '';
  my $matrixID = param('m') || '';
  my $db = connectDB();
  my $cache = new MCache;
  if($action eq 'L')    {
    $body = list_matrix($db);
  }
  elsif($action eq 'E') {
    $body = display_matrix($db, $matrixID);
  }
  elsif($action eq 'A') {
    my $error = insert_matrix($db);
    $body = $error . list_matrix($db);
  }
  else  {



  }

  disconnectDB($db) if $db;
  print_adminpageGen($body, "", "");
}


