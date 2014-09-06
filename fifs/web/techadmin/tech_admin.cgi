#!/usr/bin/perl -w

#
# $Header: svn://svn/SWM/trunk/web/techadmin/tech_admin.cgi 10107 2013-12-03 01:30:08Z tcourt $
#

use lib "../..","..",".";
#use lib "/u/regonew_live","/u/regonew_live/web","/u/regonew_live/web/admin";

use strict;
use DBI;
use CGI qw(param unescape escape);
use Defs;
use Utils;

use FormHelpers;
use TechAdminPageGen;
use TechAdminCommon;
use MemberCardAdmin;
use RealmAdmin;
use SystemConfigAdmin;

main();

sub main	{
	my $action = param('action') || 'MC_';
	my $output = new CGI;
	my $header = "Content-type: text/html\n\n";
	my $body = "";
	my $subBody = "";
  my $menu = "";
	my $error = "";
	my $title = "$Defs::sitename Association Administration";
	my $activetab = 0;
	my $target = "tech_admin.cgi";
	my $db = connectDB();
	if(!$db)	{
		$subBody=qq[Cannot connect to the database.];
	}
	my @tabs = (
			["$target?action=MC_LIST", 'Member Cards'],
			["$target?action=R_LIST", 'Realm Setup'],
			["$target?action=SC_LIST", 'System Config'],
  );

	if($action =~ /MC_/) {
		$activetab = 0;
		($subBody, $menu) = handle_member_card($db, $action, $target);
	}
	elsif($action =~ /R_/) {
		$activetab = 1;
		($subBody, $menu) = handle_realm($db, $action, $target);
	}
	elsif($action =~ /SC_/) {
		$activetab = 2;
		($subBody, $menu) = handle_system_config($db, $action, $target);
	}
	$subBody = create_tabs($subBody, \@tabs, $activetab, '', $menu);
	$body = $subBody if $subBody;
  $body = $error if $error;
	disconnectDB($db) if $db;
	print_adminpageGen($body, "", "");
}

