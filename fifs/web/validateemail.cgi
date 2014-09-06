#!/usr/bin/perl -w

#
# $Header: svn://svn/SWM/trunk/web/validateemail.cgi 8249 2013-04-08 08:14:07Z rlee $
#

use strict;
use lib "..",".";
use Defs;
use Lang;
use Utils;
use Reg_common;
use PageMain;
use CGI qw(param);

main();

sub main  {
  # GET INFO FROM URL
  my $key= param('k') || '';
  my $email = param('e') || '';
  my $client= param('client') || '';

  my %Data=();
  my $lang= Lang->get_handle() || die "Can't get a language handle!";
  $Data{'lang'}=$lang;
  my $target='main.cgi';
  $Data{'target'}=$target;
  my %clientValues = getClient($client);
  $Data{'clientValues'} = \%clientValues;
  # AUTHENTICATE
  my $db = connectDB();
	my $body = '';
	my $pageHeading = 'Validate Email Address';
	if(!$key or !$email)	{
		$body = qq[
			<div class="warningmsg">Invalid Parameters</div>
			<p>The link you followed to get here seems to be invalid.  Please check the link again.</p>
		];
	}
	else {
		my $st = qq[
			SELECT 
				strKey,
				dtVerified
			FROM tblVerifiedEmail
			WHERE strEmail = ?
		];
		my $q = $db->prepare($st);
		$q->execute($email);
		my($DBkey, $DBdate) = $q->fetchrow_array();
		$DBkey ||= '';
		$DBdate ||= '';
		$q->finish();
		if($key eq $DBkey)	{
			my $st_u = qq[
				UPDATE tblVerifiedEmail
					SET dtVerified = NOW()
				WHERE strEmail = ?
			];
			my $qu = $db->prepare($st_u);
			$qu->execute($email);
			$qu->finish();

			$body = qq[
				<div class="OKmsg">Address Verified</div>
				<p>Your email address has been verified.</p>
			];
		}
		else	{
			$body = qq[
				<div class="warningmsg">Invalid Parameters</div>
				<p>The link you followed to get here seems to be invalid.  Please check the link again.</p>
			];
		}
	}


	my $resultHTML=qq[
		<div class="pageHeading">$pageHeading</div>
		$body
	];
	pageMain(
		$Defs::page_title, 
		'', 
		$resultHTML,
		\%clientValues, 
		$client,
		\%Data
	);
}

