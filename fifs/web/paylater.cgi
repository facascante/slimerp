#! /usr/bin/perl -w

#
# $Header: svn://svn/SWM/trunk/web/paylater.cgi 8249 2013-04-08 08:14:07Z rlee $
#

use strict;
use CGI qw(param);

use lib '.','..','RegoForm','PaymentSplit';
use Lang;
use Reg_common;
use PageMain;
use Defs;
use Utils;
use SystemConfig;
use Payments;

main();

sub main	{

	my $db = connectDB();

	my $action = param('a');
	my $intLogID = param('ci') || 0;
	my $target = 'paylater.cgi';

	my %Data = (
		db => $db,
		target => $target,
	);

	my $st= qq[
		SELECT TL.*, A.intAssocTypeID
		FROM tblTransLog as TL
			LEFT JOIN tblAssoc as A ON (A.intAssocID = TL.intAssocPaymentID)
		WHERE TL.intLogID = ?
	];
	my $q = $db->prepare($st);
	$q->execute($intLogID);
	my $transref = $q->fetchrow_hashref();
	$q->finish();
  $Data{'RegoFormID'} = $transref->{'intRegoFormID'} || 0;
  $Data{'RealmSubType'} ||= $transref->{'intAssocTypeID'} || 0;
  $Data{'Realm'} ||= $transref->{'intRealmID'} || 0;
  $Data{'clientValues'}{'assocID'} ||= $transref->{intAssocPaymentID} || 0;
  getDBConfig(\%Data);
  $Data{'SystemConfig'}=getSystemConfig(\%Data);
  my $lang   = Lang->get_handle('', $Data{'SystemConfig'}) || die "Can't get a language handle!";
  $Data{'lang'}=$lang;

  $Data{'LocalConfig'}=getLocalConfig(\%Data);

	my $body = '';
	my ($resultHTML, $title)  = handlePayments(
		$action,
		\%Data,
		1,
	);
	$body .= $resultHTML;

	pageForm(
	    'Sportzware Membership',
	    $body,
	    $Data{'clientValues'},
	    q{},
	    \%Data
	);
	disconnectDB($db);
}

