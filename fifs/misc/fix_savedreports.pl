#!/usr/bin/perl -w

#
# $Header: svn://svn/SWM/trunk/misc/fix_savedreports.pl 8250 2013-04-08 08:24:36Z rlee $
#

use lib "../web","..";
use Defs;
use Utils;
use DBI;
use JSON;
use strict;

my %Data=();
my $db=connectDB();

	my $st_u = qq[
		UPDATE tblSavedReports
		SET	
			strReportData = ?
		WHERE intSavedReportID = ?
	];
	my $q_u = $db->prepare($st_u);

	my $st =qq[
		SELECT 
			intSavedReportID,
			strReportData
		FROM tblSavedReports
	];

	my $q = $db->prepare($st);
	$q->execute();
	while(my($id, $data) = $q->fetchrow_array()) {

		if($data =~/optins/)	{
			$data =~s/optins/options/g;
warn($data);
			$q_u->execute($data, $id);
		}
	}
