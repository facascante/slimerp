#!/usr/bin/perl -w

#
# $Header: svn://svn/SWM/trunk/misc/loyalty.pl 8250 2013-04-08 08:24:36Z rlee $
#

use strict;
use Date::Calc qw(Week_of_Year Monday_of_Week);
use Memoize;


my %month_to_num=("Jan",'01',"Feb",'02',"Mar",'03',"Apr",'04',"May",'05',"Jun",'06',"Jul",'07',"Aug",'08',"Sep",'09',"Oct",10,"Nov",11,"Dec",12);

memoize('isRobot');

my %stats=();
my %users=();
while (<>)	{
	chomp;
	s/\s+/ /go;
	my ($clientAddress,    $rfc1413,      $username, 
		$localTime,         $httpRequest,  $statusCode, 
		$bytesSentToClient, $referer,      $clientSoftware) =
		/^(\S+) (\S+) (\S+) \[(.+)\] \"(.+)\" (\S+) (\S+) \"(.*)\" \"(.*)\"/o;
		#
	#get date structure
	$localTime=~s/\[//g;
	my ($logdate,undef)=split /:/,$localTime;
	my ($day,$month,$year)=split /\//,$logdate;
	next if(!$year or !$month or !$day);
	if($day <10 and $day!~/^0/)	{	$day='0'.$day;	}
	$month=$month_to_num{$month};
	my $date="$year$month$day";
	if($httpRequest!~/\.cgi/)	{
		next unless $httpRequest=~/ \/ /;
	}
	my $robot=isRobot($clientSoftware);
	next if $robot;
	my $week=0;
	my $wyear=0;
	eval {
		($week, $wyear)= Week_of_Year($year,$month,$day);
	};
	if(!$week)	{
		print "INVALID DATE $year:$month:$day\n";
		next;
	}
	my $unique=$clientAddress.$clientSoftware;
	$stats{$week}{$unique}++;
	$users{$unique}++;
}

my @weeks=sort keys %stats;
my $totallastweek=0;
my $totallast2week=0;
for my $i (0 .. $#weeks)	{
	my $uniqnum=scalar(keys %{$stats{$weeks[$i]}});
	my $inlastweek=0;
	my $notinlastweek=0;
	my $inlast2week=0;
	my $notinlast2week=0;
	if($i > 0)	{
		for my $u (keys %{$stats{$weeks[$i]}})	{
			if(exists $stats{$weeks[$i-1]}{$u})	{
print STDERR "IN $u\n";
				$inlastweek++;
			}
			else	{
				$notinlastweek++;
print STDERR "NOT IN $u\n";
			}
		}
	}
	if($i > 1)	{
		for my $u (keys %{$stats{$weeks[$i]}})	{
			if(exists $stats{$weeks[$i-2]}{$u})	{
				$inlast2week++;
			}
			else	{
				$notinlast2week++;
			}
		}
	}
	my $lost=$totallastweek-$inlastweek;
	my ($wyear,$wmonth,$wday)=Monday_of_Week($weeks[$i],'2008');
	print "Week $weeks[$i] ($wday/$wmonth/$wyear) -  Number uniq: $uniqnum  New: $notinlastweek : Return: $inlastweek Lost: $lost New2: $notinlast2week Return2: $inlast2week\n";
	$totallast2week=$totallastweek;
	$totallastweek=$uniqnum;
}






sub isRobot	{
	my($ua)=@_;
	my @matches=(qw(
		robot
		slurp
		spider
		crawl
		bot
	));
	for my $m (@matches)	{
		return 1 if $ua =~/$m/;
	}
}


# Database
# dtDate
# Rec Type 1= day
# Type ID 
# ID
# Count
#
