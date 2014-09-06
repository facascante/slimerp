#!/usr/bin/perl 

#
# $Header: svn://svn/SWM/trunk/web/lookupmanage.cgi 10133 2013-12-03 04:08:21Z tcourt $
#

use strict;
use warnings;
use CGI qw(param);
use lib "..",".","PaymentSplit","RegoFormBuilder";
use Defs;
use Reg_common;
use Utils;
use Lang;
use DefCodes;
use SystemConfig;
use ConfigOptions;
use PageMain;

main();	

sub main	{
	# GET INFO FROM URL
	my $client=param('client') || '';
  my $action = safe_param('a','action') || '';

  my %Data=();
  my $target='lookupmanage.cgi';
  $Data{'target'}=$target;
  my %clientValues = getClient($client);
  $Data{'clientValues'} = \%clientValues;
  my $db=allowedTo(\%Data);
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

	my ($resultHTML, $pageHeading) = handle_defcodes(
		\%Data,
		$action,
	);

  # BUILD PAGE
  $client=setClient(\%clientValues);
  $clientValues{INTERNAL_db} = $db;
	#my $pageHeading = '';
  $resultHTML ||= textMessage("An invalid Action Code has been passed to me.");
  $resultHTML=qq[
    <div class="pageHeading">$pageHeading</div>
    $resultHTML
  ] if $pageHeading;

  printBasePage($resultHTML, 'Sportzware Membership');

  disconnectDB($db);



}


