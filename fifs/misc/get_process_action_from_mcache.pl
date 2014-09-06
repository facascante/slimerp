#!/usr/bin/perl

#
# $Header: svn://svn/SWM/trunk/misc/get_process_action_from_mcache.pl 8250 2013-04-08 08:24:36Z rlee $
#

use strict;
use lib '../','../web/';

use MCache;
use Defs;
use Utils;
use Data::Dumper;

my $ip_address = '203.21.3.198';

my $file = $ARGV[0];
if (!$file) {
    print "Please provide the name of the file containing process ids you wish to check. (One process id per line.)\n\n";
    exit;
}

open(FH, $file) || die "Couldn't open file $file:$!\n";
my $mcache = new MCache;
my $type = 'swm';

while (my $line = <FH>) {
    chomp $line;

    my $process_id = $line;
    my $key = 'MEMACTION_'. $ip_address  . '_' . $process_id;
	my $result = $mcache->get($type, $key);
    if(ref $result)	{
    # 'client' => 'MHwwfDB8MHwwfDB8MHw3NTEzfC0xfC0xfC0xfDM3MTg2Nzd8MXw1fC0xfC0xfC0xfDB8MHwwfDE2NjE0NHwxMzYzNjYyMDk0fDBlOTAxYTVkZjU3M2RlYmMwOGQ5ZjU1NDRmN2JhMGRl',
         # 'processID' => '27251',
         # 'querystring' => 'client=MHwwfDB8MHwwfDB8MHw3NTEzfC0xfC0xfC0xfDM3MTg2Nzd8MXw1fC0xfC0xfC0xfDB8MHwwfDE2NjE0NHwxMzYzNjYyMDk0fDBlOTAxYTVkZjU3M2RlYmMwOGQ5ZjU1NDRmN2JhMGRl&a=M_SEASONS',
         # 'url' => '/v6/main.cgi?client=MHwwfDB8MHwwfDB8MHw3NTEzfC0xfC0xfC0xfDM3MTg2Nzd8MXw1fC0xfC0xfC0xfDB8MHwwfDE2NjE0NHwxMzYzNjYyMDk0fDBlOTAxYTVkZjU3M2RlYmMwOGQ5ZjU1NDRmN2JhMGRl&a=M_SEASONS',
         # 'action' => 'M_SEASONS',
        #  'server' => '203.21.3.198',
       #   'host' => 'reg.sportingpulse.com'
        print "$process_id:", $result->{assocID}, ":", $result->{action}, ":", $result->{'querystring'}, "\n";
    }
}


close FH;

