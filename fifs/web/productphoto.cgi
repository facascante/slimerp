#!/usr/bin/perl 

#
# $Header: svn://svn/SWM/trunk/web/regoformphoto.cgi 8249 2013-04-08 08:14:07Z rlee $
#

use strict;
use warnings;
use CGI qw(param);
use lib "..",".";
use Defs;
#use Reg_common;
use Utils;
use Lang;
use ProductPhoto;
use PageMain;
use SystemConfig;
main();	

sub main	{
	# GET INFO FROM URL
  my $client = param('client') || '';
  my $temp= param('t') || '';
  my $action = param('a') || '';
  my $tempfile_prefix= param('tfn') || '';
  my $pID = param("pID") ||0;                                                                                                       
  my %Data=();
  my $lang= Lang->get_handle() || die "Can't get a language handle!";
  $Data{'lang'}=$lang;
  my $target='productphoto.cgi';
  $Data{'target'}=$target;
	
 #$tempfile_prefix= 'tempfile';
  if(!$tempfile_prefix)   {
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
	my $body = '';
	$action ||= 'P_PH_n';
		($body,undef, undef, undef) = handle_ProductPhoto(
			$action,
			\%Data,
			$pID,
			'',
			'',
			$tempfile_prefix,
		          1,#Product Photo #From RegoForm
		);

	printBasePage(
		$body,
		$lang->txt('Photo'),
	);

}
