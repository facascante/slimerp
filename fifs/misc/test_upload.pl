#!/usr/bin/perl -w

#
# $Header: svn://svn/SWM/trunk/misc/test_upload.pl 8250 2013-04-08 08:24:36Z rlee $
#
use lib "../web","..","../web/comp","../web/sportstats";
use Defs;
use Utils;
use DBI;
use CompSWWUpload_sync;
use strict;

my %Data=();
my $db=connectDB();

SWWUploadGo_sync({db => $db}, $db, 12607);


