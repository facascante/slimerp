#!/usr/bin/perl -w

use lib "../web","..";
use Defs;
use Utils;
use DBI;
use strict;

use EntityStructure;

{
my $db=connectDB();

	
	my %Data=();
	$Data{'db'}=$db;

	createTempEntityStructure(\%Data);
}
1;

