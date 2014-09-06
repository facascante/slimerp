#!/usr/bin/perl 

#
# $Header: svn://svn/SWM/trunk/web/bank_file.cgi 10144 2013-12-03 21:36:47Z tcourt $
#

use strict;
use warnings;
use CGI qw(param);
use lib "..",".";
use Defs;
use Reg_common;
use Utils;
use Lang;

main();	

sub main	{
	# GET INFO FROM URL
  my $client = param('client') || '';
  my $intExportBSID= param('exportbsid') || '';
                                                                                                        
  my %Data=();
	my $db=connectDB();
        $Data{'db'}=$db;
  my $lang= Lang->get_handle() || die "Can't get a language handle!";
  $Data{'lang'}=$lang;
  my $target='main.cgi';
  $Data{'target'}=$target;
  my %clientValues = getClient($client);
  $Data{'clientValues'} = \%clientValues;
  my $memberID = $clientValues{'memberID'};
	
	($Data{'Realm'},$Data{'RealmSubType'})=getRealm(\%Data);
                                                                                                        
  # AUTHENTICATE
	if($db)	{
		my $statement=qq[
			SELECT strFilename
			FROM tblExportBankFile
			WHERE intExportBSID = $intExportBSID
				AND intRealmID = $Data{'Realm'}
		];
		my $query = $db->prepare($statement);
		$query->execute();
		my($filename)=$query->fetchrow_array();
		$query->finish();
		disconnectDB($db);
		if($filename)	{
			$filename="$Defs::bank_export_dir$filename";
			open (FILE, "<$filename") || die("Can't open file $filename\n");
			my $data='';
			while(<FILE>)  { $data.= $_; }
			close (FILE);
			print "Content-type: text/plain\n\n";
			print $data;
		}
		else	{ print "Content-type: text/html\n\n";}
	}
	else	{ print "Content-type: text/html\n\n";}
}
