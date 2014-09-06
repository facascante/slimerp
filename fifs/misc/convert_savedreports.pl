#!/usr/bin/perl -w

#
# $Header: svn://svn/SWM/trunk/misc/convert_savedreports.pl 8250 2013-04-08 08:24:36Z rlee $
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
			intReportID = ?,
			strReportData = ?
		WHERE intSavedReportID = ?
	];
	my $q_u = $db->prepare($st_u);

	my $st =qq[
		SELECT 
			intSavedReportID,
			strReportData,
			strReportType
		FROM tblSavedReports
			WHERE strReportType IS NOT NULL
				AND intReportID =0
	];

	my $q = $db->prepare($st);
	$q->execute();
	my %reportMatrix = (
		event_member => 29,
		event_membersport => 29,
		event_statuses => 31,
		event_printed => 30,
		fitnesstest => 8,
		member => 3,
		club => 2,
		team => 4,
		playerseason => 19,
		roundsplayed => 20,
		awardrndbyrnd => 21,
		transactions => 10,
		txnsold => 11,
		fundsreceived => 12,
		tribunal => 15,
		assoc => 14,
		clearances => 6,
		summary => 18,
		duplicates => 13,
		memberdemog => 18,
		retention => 9,
		fixture => 8,
		contacts => 5,
	);
	while(my($id, $olddata, $type) = $q->fetchrow_array()) {
		my $reportID = $reportMatrix{$type} || next;
		my %newData = ();
		my @options = split /;/,$olddata;
		my @fieldorder = ();
		for my $i (@options)	{
			my($o, $v) = split /\|/, $i;
			my $field = $o;
			if($field =~/.*_\d$/)	{
				$field =~s/_\d$//g;
			}
			elsif($field =~/^[^\_]*_/)	{
				$field =~s/^[^\_]*_//g;
#warn("UU $field");
			}
			if($o eq "chk_$field")	{
				$newData{'fields'}{$field}{'display'} = $v || 0;
			}
			elsif($o eq "comp_$field")	{
				$newData{'fields'}{$field}{'comp'} = $v || '';
			}
			elsif($o eq $field."_1")	{
				$newData{'fields'}{$field}{'v1'} = $v || '';
			}
			elsif($o eq $field."_2")	{
				$newData{'fields'}{$field}{'v2'} = $v || '';
			}
			elsif($o eq "viewtype")	{
				$newData{'Options'}{'OutputType'} = $v || '';
			}
			elsif($o eq "sortby")	{
				$newData{'Options'}{'SortBy1'} = $v || '';
			}
			elsif($o eq "sortby2")	{
				$newData{'Options'}{'SortBy2'} = $v || '';
			}
			elsif($o eq "sortbydir")	{
				$newData{'Options'}{'SortByDir1'} = $v || '';
			}
			elsif($o eq "sortbydir2")	{
				$newData{'Options'}{'SortByDir2'} = $v || '';
			}
			elsif($o eq "groupby")	{
				$newData{'Options'}{'GroupBy'} = $v || '';
			}
			elsif($o eq "exemail")	{
				$newData{'Options'}{'OutputEmail'} = $v || '';
			}
			elsif($o eq "RO_RecordFilter")	{
				$newData{'Options'}{'RecordFilter'} = $v || '';
			}
			elsif($o eq "DISTINCT")	{
				$newData{'Options'}{'RecordFilter'} = 'DISTINCT' || '';
			}
			elsif($o eq "exformat")	{
				next;
			}
			elsif($o eq "limit")	{
				next;
			}
			else	{
				warn("unknown $o:$v:$field");
			}
			push @fieldorder, $field;
		}
		my @fields = ();
		
		for my $field (@fieldorder)	{
			push @fields, {
				name => $field,
				display => $newData{'fields'}{$field}{'display'} || 0,
				v1 => $newData{'fields'}{$field}{'v1'} || '',
				v2 => $newData{'fields'}{$field}{'v2'} || '',
				comp => $newData{'fields'}{$field}{'comp'} || '',
			};
		}

		my %newhash  = (
			fields => \@fields,
			options => $newData{'Options'},
		);
		my $newdata = to_json(\%newhash);
		#warn($newdata);
		$q_u->execute(
			$reportID,
			$newdata,
			$id,
		);
	}
