#!/usr/bin/perl -w

#
# $Header: svn://svn/SWM/trunk/misc/traceFieldPermission.pl 11205 2014-04-01 23:57:33Z apurcell $
#

use lib "../web","..", "../web/comp/";
use Defs;
use Utils;
use DBI;
use ConfigOptions;
use Reg_common;
use strict;

#This program will assign national numbers to members in a realm
# that do not have one.

my $login_authLevel = 100;

my $viewEntityTypeID = 4;
my $viewEntityID = 452711;
my $assocID = 89; #set to zero if above

my $fieldname = 'strName';
my $fieldtype = 'Team'; # Member, Club, Team
my $regoform = 0; #Check for regoform?



# ============
my $db = connectDB();

my %Data = (
	clientValues => {
		assocID => $assocID,
		authLevel => $login_authLevel,
		currentLevel => $viewEntityTypeID,
	},
	db => $db,
);
setClientValue($Data{'clientValues'},$viewEntityTypeID, $viewEntityID);
($Data{'Realm'}, $Data{'RealmSubType'})=getRealm(\%Data);

my $perms_raw = GetPermissions(
    \%Data,
    $viewEntityTypeID,
    $viewEntityID,
    $Data{'Realm'},
    $Data{'RealmSubType'},
    $login_authLevel,
    1,
);

my @levels_to_check = (
	'REALM',
	$Defs::LEVEL_NATIONAL,
	$Defs::LEVEL_STATE,
	$Defs::LEVEL_REGION,
	$Defs::LEVEL_ZONE,
	$Defs::LEVEL_ASSOC,
	$Defs::LEVEL_CLUB,
);

print "Best Guess --------\n";
my $above = 0;
my %perms = ();
for my $level (@levels_to_check)	{
	my $type = $fieldtype;
	$above = 0 if $level eq $login_authLevel;
	$type .= 'Child' if($above and !$regoform);

	my $val_at_level = $perms_raw->{$type}{$level}{$fieldname} || '';
	if(
		$val_at_level
		and (
			(!$perms{$type}{$fieldname} or $perms{$type}{$fieldname} eq 'ChildDefine')
			or ($above and AllowPermissionUpgrade($perms{$type}{$fieldname},$val_at_level))
		)
	) {
		print "$level => $val_at_level : replaced $perms{$type}{$fieldname}\n";
		$perms{$type}{$fieldname} = $val_at_level;
	}
	else	{
		print "$level => $val_at_level\n";
	}
}
print "Best Guess Result ==== $perms{$fieldtype}{$fieldname} \n";

print "-------- All Types --------\n";
for my $type (( $fieldtype, $fieldtype.'Child', $fieldtype.'RegoForm'))	{
print "$type -- \n";
	for my $level (@levels_to_check)	{
		my $val_at_level = $perms_raw->{$type}{$level}{$fieldname} || '';
		print "   $level => $val_at_level\n";
	}
}

