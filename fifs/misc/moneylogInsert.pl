#!/usr/bin/perl

#
# $Header: svn://svn/SWM/trunk/misc/moneylogInsert.pl 8250 2013-04-08 08:24:36Z rlee $
#

use strict;

use lib "..","../web","../web/comp";

use Defs;
use Utils;
use DBI;
use LWP::UserAgent;
use PaymentSplitExport;
use BankAccountObj;
use CGI qw(unescape);
use DeQuote;
use PaymentSplitMoneyLog;
use Payments;

main();

sub main	{

	my %Data = ();
	my $db = connectDB();
	$Data{'db'} = $db;

	my $logID = $ARGV[0] || 0;

	if (! $logID)	{
		print "EXITING - has no ID";
		exit;
	}
	my $st = qq[
		SELECT DISTINCT
			TL.intRealmID,
			TL.intPaymentConfigUsedID,
			T.intRealmSubTypeID,
			SC.strValue,
            TL.intPaymentType,
            TL.intPaymentConfigID
		FROM
		 	tblTransLog as TL
			INNER JOIN tblTransactions as T ON (T.intTransLogID = TL.intLogID)
			LEFT JOIN tblSystemConfig as SC ON (SC.intRealmID = TL.intRealmID and strOption='PaymentSplitRuleID' and SC.intSubTypeID IN (0,T.intRealmSubTypeID))
		WHERE 
			intLogID = $logID 
			AND intPaymentType IN (1,11,13)
		ORDER BY
			SC.intSubTypeID DESC
		LIMIT 1
	];
	my $q = $db->prepare($st);
	$q->execute();

	my $error=0;
	my ($realmID, $pcID, $realmSubTypeID, $ruleID, $payType, $payConfigID) = $q->fetchrow_array();
	$error =1 if ! $realmID;
	$Data{'SystemConfig'}{'PaymentConfigID'} = $pcID || 0;

	if ($error)	{
		print STDERR "LOG ERROR";
		return;
	}
	$Data{'Realm'} = $realmID;
	$Data{'RealmSubType'} = $realmSubTypeID;
	$Data{'SystemConfig'}{'PaymentSplitRuleID'} = $ruleID;
	my ($paymentSettings, undef) = getPaymentSettings(\%Data, $payType, $payConfigID);
	calcMoneyLog(\%Data, $paymentSettings, $logID);
print "DONE";
	exit;
}
