#!/usr/bin/perl -w

#
# $Header: svn://svn/SWM/trunk/web/locator/finder.cgi 10138 2013-12-03 20:24:41Z tcourt $
#

use strict;
use lib ".", "..", "../../","../comp", "../sportstats", "../SMS", "../dashboard";
use CGI qw(:standard escape);
use Utils;
use Defs;
use FinderDefs;
use Finder;
use SystemConfig;
use Reg_common;
use Lang;
use Finder;
use EOIDisplay;
use TTTemplate;

main();

sub main	{
  my $realmID     = safe_param('r','number')  || 0;
  my $subrealmID  = param('sr') || 0;
	my $iframe      = safe_param('if','number') || 0;
	my $action      = param('a')  || '';
  my $resultHTML = '';
  my $db = connectDB();
  my $FinderDefs = getFinderDefs($realmID);
  
  $subrealmID = 0 if ($subrealmID !~ /^([\d.,]+)$/);

  my %Data=(
    db => $db,
    Realm => $realmID,
    RealmSubType => $subrealmID,
    target => $FinderDefs->{'target'}
  );
  my $lang= Lang->get_handle() || die "Can't get a language handle!";
  $Data{'lang'} = $lang;
  my $SystemConfig = getSystemConfig(\%Data);
  $Data{'SystemConfig'} = $SystemConfig;
  getDBConfig(\%Data);
  if ($action eq 'EOI_DTA') {
    ($resultHTML, undef) = handleEOI('EOI_DTA', \%Data);
    $resultHTML = runTemplate(
      \%Data,
      {
        'Title'=>$FinderDefs->{'Brand'},
        'CSS'=>$FinderDefs->{'Style'},
        'Header'=>$FinderDefs->{'DefaultHeader'},
        'Copyright'=>$FinderDefs->{'DefaultCopyright'},
        'content'=>$resultHTML
      },
      $FinderDefs->{'directory'} . "/page.templ"
    );
  }
  else {
    $resultHTML = search_results(\%Data, $FinderDefs, $db);
  }  
  disconnectDB($db);
  $resultHTML = runTemplate(
    \%Data, 
    {
      'Title'=>$FinderDefs->{'Brand'}, 
      'CSS'=>$FinderDefs->{'Style'},
      'Header'=>$FinderDefs->{'DefaultHeader'},
      'Copyright'=>$FinderDefs->{'DefaultCopyright'}
    }, 
    $FinderDefs->{'directory'} . "/" . $FinderDefs->{'Error'}
  ) unless ($realmID);
  print qq[Content-type: text/html\n\n];
  print $resultHTML;
}
