#!/usr/bin/perl

#
# $Header: svn://svn/SWM/trunk/web/MapFinder/mapfinder_secure.cgi 10478 2014-01-19 23:29:04Z apurcell $
#

use strict;
use lib ".", "..", "../../","../comp","../sportstats","../SMS","../dashboard";
use CGI qw(param unescape escape);
use URI::Escape;

use Utils;
use Defs;
use MapFinderDefs;
use MapFinder;
use SystemConfig;
use Reg_common;
use Lang;
use EOIDisplay;
use TTTemplate;
use POSIX qw(strftime);
use Digest::MD5 qw(md5_base64);
use XML::Simple;
use JSON;

main();

sub main	{
    my $shared_secret = '75C6A1A8-8E2D-48CD-9FE8-8525D70E40FC';

    
    my $auth = uri_unescape(param('auth')) || 0;
    my $ts = param('ts');
 
    my $now = strftime '%Y%m%d%H%M', gmtime;
    
    if (($ts < ($now - 2)) || $ts > ($now + 2)) {
        #print "Content-type: text/html\n\n"; 
        #print "ERROR: Unable to process your request\n";
    }
    else {
        
        my $digest = md5_base64($shared_secret . $ts);
        #print "Content-type: text/html\n\n"; 
        #print $digest;
        #exit;
        if ($digest ne $auth) {
            #print "Content-type: text/html\n\n"; 
            #print "ERROR: Unable to authenicate your request\n";
        }
        else {
            my $realmID     = safe_param('r','number')  || 0;
            my $subrealmID  = param('sr') || 0;
            $subrealmID = 0 if ($subrealmID !~ /^([\d.,]+)$/);

            my $action = param('a')  || '';
            
            my $MapFinderDefs = getMapFinderDefs({
                'realmID' => $realmID,
            });
            my $lang= Lang->get_handle() || die "Can't get a language handle!";
            my $db = connectDB();
            my %Data=(
                      'db' => $db,
                      'Realm' => $realmID,
                      'RealmSubType' => $subrealmID,
                      'target' => $MapFinderDefs->{'target'},
                      'lang' => $lang,
                  );
            my $SystemConfig = getSystemConfig(\%Data);
            $Data{'SystemConfig'} = $SystemConfig;
            getDBConfig(\%Data);
            
            my $search_IN = param('search_value') || '';
            my $search_type = safe_param('type','number') || 2;
            my $search_term_type = param('stt') || 'pc';
            my $clubLevelAssoc = param('club_level_only_assoc') || -1;
            $clubLevelAssoc = '' if $clubLevelAssoc =~/[^\d,]/;
            
            my ($search_results, $json) = search_results(
                                                         \%Data, 
                                                         $MapFinderDefs, 
                                                         $db,
                                                         $search_IN,
                                                         $search_type, 
                                                         $clubLevelAssoc,
                                                         $search_term_type,
                                                         1 # data only
                                                    );
            my @clubs = ();
            foreach my $club (@{$search_results->{'results'}}) {
                push @clubs, $club->{Details};
            }

            my %data = (
                        'Clubs' => [{
                                     'Club' => \@clubs,
                                 }],
                    );
            
            my %output = (
                          Response => {
                                       Version =>1,
                                       Result => 'SUCCESS',
                                       Data => \%data,
                                   }
                      ); 

            my $xml = XMLout(\%output, NoAttr=> 1, KeyAttr=>[], KeepRoot=>1);
            print "Content-type: application/xml\n\n"; 
            print $xml;
		}
    }
}
exit;

