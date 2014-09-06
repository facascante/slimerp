#
# $Header: svn://svn/SWM/trunk/web/AssocTime.pm 8251 2013-04-08 09:00:53Z rlee $
#

package AssocTime;
require Exporter;
@ISA =  qw(Exporter);
@EXPORT = qw(timeatAssoc);
@EXPORT_OK = qw(timeatAssoc);

use strict;
use DateTime;

sub timeatAssoc	{
	my($timezone, $datestring)	=@_;
	my @values;
	my($y,$m,$d,$h,$min,$s)=(0,0,0,0,0,0);
	if($datestring)	{
		($y,$m,$d,$h,$min,$s)=$datestring=~/(\d\d\d\d)-(\d{1,2})-(\d{1,2})\s(\d{1,2}):(\d{1,2}):(\d{1,2})/;
		$y ||= 0;
		$m ||= 0;
		$d ||= 0;
		$h ||= 0;
		$min ||= 0;
		$s ||= 0;
	}
	if($timezone)	{
		my $dt='';
		if($y and $m and $d)	{
			$dt = DateTime->new( year   => $y, month=>$m, day=>$d, hour=>$h, minute=>$min, second => $s, time_zone => 'local',);
			$dt->set_time_zone($timezone);
		}
		else	{
			$dt = DateTime->new( year   => 2000, time_zone => 'local',);
			$dt = DateTime->now->set_time_zone($timezone);
		}
		@values=($dt->second(),$dt->minute(),$dt->hour(),$dt->mday(),$dt->month(),$dt->year());
		$values[4]--;
		$values[5]-=1900;
	}
	else	{ 
		if($datestring)	{
			@values=($s,$min,$h,$d,$m-1,$y-1900);
		}
		else	{
			@values=(localtime())[0..5]; 
		}
	}
	my $stringdate=sprintf("%02d-%02d-%02d %02d:%02d:%02d", ($values[5]+1900),($values[4]+1), $values[3],$values[2],$values[1],$values[0]);
	return wantarray ? @values : $stringdate;
}
