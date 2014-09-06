#!/usr/bin/perl 

#
# $Header: svn://svn/SWM/trunk/web/graph_full.cgi 10144 2013-12-03 21:36:47Z tcourt $
#

use strict;
use warnings;
use CGI qw(param);
use lib "..",".","dashboard","PaymentSplit",'RegoFormBuilder';
use Defs;
use Reg_common;
use Utils;
use Lang;
use SystemConfig;
use ConfigOptions;
use PageMain;
use DashboardGraphs;
use MCache;
use AddToPage;

main();	

sub main	{
	# GET INFO FROM URL
	my $client=param('client') || '';
  my $action = safe_param('a','action') || '';
	my $graph = safe_param('g','graph') || '';

  my %Data=();
  my $target='lookupmanage.cgi';
  $Data{'target'}=$target;
  my %clientValues = getClient($client);
  $Data{'clientValues'} = \%clientValues;
  my $db=allowedTo(\%Data);
  $Data{'cache'}=new MCache();
  $Data{'AddToPage'}=new AddToPage();
  ($Data{'Realm'},$Data{'RealmSubType'})=getRealm(\%Data);

  getDBConfig(\%Data);
  $Data{'SystemConfig'}=getSystemConfig(\%Data);
  my $lang   = Lang->get_handle('', $Data{'SystemConfig'}) || die "Can't get a language handle!";
  $Data{'lang'}=$lang;
  $Data{'LocalConfig'}=getLocalConfig(\%Data);
  my $assocID=getAssocID(\%clientValues) || '';
  $clientValues{'currentLevel'} = safe_param('cl','number') if (safe_param('cl','number') and safe_param('cl','number') <= $clientValues{'authLevel'});

  my $DataAccess_ref=getDataAccess(\%Data);
  $Data{'Permissions'}=GetPermissions(
    \%Data,
    $clientValues{'authLevel'},
    getID(\%clientValues, $clientValues{'authLevel'}),
    $Data{'Realm'},
    $Data{'RealmSubType'},
    $clientValues{'authLevel'},
    0,
  );

  $Data{'DataAccess'}=$DataAccess_ref;


	my $output = outputGraph(
		\%Data,
		$client,
		$graph,
		1,
	);

  # BUILD PAGE
  $client=setClient(\%clientValues);
  $clientValues{INTERNAL_db} = $db;
	#my $pageHeading = '';
	my $resultHTML = $output;
  $resultHTML ||= textMessage("An invalid Action Code has been passed to me.");

  printBasePage($resultHTML, 'Sportzware Membership', \%Data);

  disconnectDB($db);

}

