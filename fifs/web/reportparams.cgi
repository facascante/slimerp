#!/usr/bin/perl 

#
# $Header: svn://svn/SWM/trunk/web/reportparams.cgi 11339 2014-04-22 08:19:58Z apurcell $
#

use strict;
use warnings;
use CGI qw(param unescape escape);
use lib "..",".","PaymentSplit",'RegoFormBuilder';
use Defs;
use Reg_common;
use SystemConfig;
use Utils;
use Lang;
use ReportManager;
use Reports::ReportStandard;


main();	

sub main	{
	# GET INFO FROM URL
    my $client = param('client') || '';
    my $reportID = param('rID') || '';
                                                                                                            
    my %Data=();
    my $target='main.cgi';
    $Data{'target'}=$target;
    $Data{'client'}=$client;
    $Data{'unesc_client'}=unescape($client);
    my %clientValues = getClient($client);
    $Data{'clientValues'} = \%clientValues;

    my $memberID = $clientValues{'memberID'};
    	
    # AUTHENTICATE
    my $db=allowedTo(\%Data);
    ( $Data{'Realm'}, $Data{'RealmSubType'} ) = getRealm( \%Data );
    $Data{'db'}=$db;
    $Data{'SystemConfig'} = getSystemConfig( \%Data );
    my $lang   = Lang->get_handle('', $Data{'SystemConfig'}) || die "Can't get a language handle!";
    $Data{'lang'}=$lang;

	my $body = '';
	if($db and $reportID)	{
	    
        if ($Data{'SystemConfig'}{'use_new_report_style'}){
            my $reportObj = getReportObj({
                'db'            => $db,                               
                'data'          => \%Data, 
                'client_values' => $Data{'clientValues'},
                'report_id'     => $reportID,
            });
            
            $body .= $reportObj->displayOptions();
        }
        else{
            my $currentLevel = $Data{'clientValues'}{'currentLevel'} || 0;
            my $entityID = getID($Data{'clientValues'}, $Data{'clientValues'}{'currentLevel'});
            my $r = new Reports::ReportStandard (
                Data => \%Data,
                db => $db,
                ID => $reportID,
                EntityTypeID => $currentLevel,
                EntityID => $entityID,
            );
            $body .= $r->displayOptions();
        }

		
	}
	print "Content-type: text/html\n\n";
	print $body;
}
