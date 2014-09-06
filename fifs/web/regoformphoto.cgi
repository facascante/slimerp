#!/usr/bin/perl 

#
# $Header: svn://svn/SWM/trunk/web/regoformphoto.cgi 10128 2013-12-03 04:03:40Z tcourt $
#

use strict;
use warnings;
use CGI qw(param);
use lib "..",".";
use Defs;
use Reg_common;
use Utils;
use Lang;
use Photo;
use PageMain;
use SystemConfig;

main();	

sub main	{
	# GET INFO FROM URL
  my $client = param('client') || '';
  my $temp= param('t') || '';
  my $action = param('a') || '';
  my $tempfile_prefix= param('tfn') || '';
                                                                                                        
  my %Data=();
  my $target='regoformphoto.cgi';
  $Data{'target'}=$target;
  my %clientValues = getClient($client);
	if(
			!$clientValues{'memberID'}
			or $clientValues{'memberID'} == -1
	)	{
		$clientValues{'memberID'} = -1000;
	}
  $Data{'clientValues'} = \%clientValues;
  my $memberID = $clientValues{'memberID'};
	
	#$tempfile_prefix= 'tempfile';
	if(!$tempfile_prefix)	{
    srand();
    my $salt=(rand()*100000);
    my $salt2=(rand()*100000);
    $tempfile_prefix=crypt($salt2,$salt);
    #Clean out some rubbish in the key
    $tempfile_prefix=~s /['\/\.\%\&]//g;
    $tempfile_prefix=substr($tempfile_prefix,0,20);
	}


  # AUTHENTICATE
  my $db=connectDB();
	$Data{'db'} = $db;
  ($Data{'Realm'}, $Data{'RealmSubType'})=getRealm(\%Data);
  $Data{'SystemConfig'}=getSystemConfig(\%Data);
  my $lang   = Lang->get_handle('', $Data{'SystemConfig'}) || die "Can't get a language handle!";
  $Data{'lang'}=$lang;

	my $body = '';
	$action ||= 'M_PH_n';
		($body,undef, undef, undef) = handle_photo(
			$action,
			\%Data,
			$memberID,
			'',
			'',
			$tempfile_prefix,
			1, #From RegoForm
		);


	printBasePage(
		$body,
		$lang->txt('Photo'),
	);

}
