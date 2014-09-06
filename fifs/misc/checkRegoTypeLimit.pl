#!/usr/bin/perl

#
# $Header: svn://svn/SWM/trunk/misc/moneylogInsert.pl 8250 2013-04-08 08:24:36Z rlee $
#

use strict;

use lib "..","../web","../web/comp", "../web/user", '../web/RegoForm', "../web/dashboard", "../web/RegoFormBuilder",'../web/PaymentSplit', "../web/Clearances";

use Defs;
use Utils;
use DBI;
use WorkFlow;
use UserObj;
use CGI qw(unescape);
use RegistrationAllowed;
use PersonRegistration;
use RegoTypeLimits;
use Data::Dumper;

main();

sub main	{


	my %Data = ();
	my $db = connectDB();
    my $personID= 10640665;
    my $pRID= 1266;
	$Data{'db'} = $db;
	$Data{'Realm'} = 1;
	$Data{'RealmSubType'} = 0;

   my $ok = checkRegoTypeLimits(\%Data, $personID, $pRID, 'FOOTBALL', 'PLAYER', '', 'AMATEUR', 'JUNIOR');
warn("try1-FAILED") if (!$ok);
warn("try1-OK to insert") if ($ok);

   my $ok = checkRegoTypeLimits(\%Data, $personID, $pRID, 'FOOTBALL', 'PLAYER', '', 'AMATEUR', 'SENIOR');
warn("try2-FAILED") if (!$ok);
warn("try2-OK to insert") if ($ok);

   my $ok = checkRegoTypeLimits(\%Data, $personID, $pRID, 'FOOTBALL', 'TECHOFFICIAL', 'DOCTOR', 'AMATEUR', 'SENIOR');
warn("try3-FAILED") if (!$ok);
warn("try3-OK to insert") if ($ok);
}
