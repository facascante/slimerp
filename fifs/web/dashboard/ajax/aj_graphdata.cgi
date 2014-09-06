#!/usr/bin/perl 

#
# $Header: svn://svn/SWM/trunk/web/dashboard/ajax/aj_graphdata.cgi 10383 2014-01-07 06:43:54Z sliu $
#

use strict;
use warnings;
use CGI qw(param);
use lib "..",".","../../",'../../comp','../../externallms',"../../..";
use Defs;
use Reg_common;
use Utils;
use Lang;
use JSON;
use DashboardGraphData;
use MCache;
use Log;
use Data::Dumper;


main();	

sub main	{
    # GET INFO FROM URL
    my $client = param('client') || '';
    my $graphtype = param('gt') || '';
    my %Data=();
    my $lang= Lang->get_handle() || die "Can't get a language handle!";
    $Data{'lang'}=$lang;
    my $target='aj_graphdata.cgi';
    $Data{'target'}=$target;
    $Data{'cache'} = new MCache;
    my %clientValues = getClient($client);
    $Data{'clientValues'} = \%clientValues;
    # AUTHENTICATE
    my $db = allowedTo(\%Data);
		($Data{'Realm'}, $Data{'RealmSubType'})=getRealm(\%Data);
    my $assocID=$clientValues{'assocID'} || 0;
    
    DEBUG "getGraphData: $graphtype";
		my $data = getGraphData(
			\%Data,
			$client,
			$graphtype,
		);

		$data ||= [];

    DEBUG "$graphtype AJAX Data:", Dumper($data);
    my $json=to_json({data => $data , results => scalar(@{$data})});
		print "Content-type: application/x-javascript\n\n";
		print $json;
}

