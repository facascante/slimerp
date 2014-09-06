#! /usr/bin/perl -w

#
# $Header: svn://svn/SWM/trunk/web/invoice_pay.cgi 8249 2013-04-08 08:14:07Z rlee $
#

use strict;
use CGI;

use lib '.','..','RegoForm', '../templates','PaymentSplit';
use Lang;
use Reg_common;
use PageMain;
use Defs;
use Utils;
use SystemConfig;
use TTTemplate;
use Payments;
use InvoicePay;

main();

sub main	{

	my $db = connectDB();

	my $cgi = new CGI;
	my $action= safe_param('a','words') || '';
	my $txnPPID= safe_param('t','number') || '';
	#my $txns= safe_param('txns','words') || '';
	#my $clubID = safe_param('clubID','number') || '';
	my $assocID = safe_param('aID','number') || '';

	my ($txns, $clubID) = getTXNPPTxnIDs($db, $txnPPID, $assocID);
	my @TXNs =split /\|/, $txns;
	# ie: &txn=12345|12346

	my $target = 'invoice_pay.cgi';
	my $noheader=0;
	my %Data = (
		db => $db,
		target => $target,
		noheader => $noheader || 0,
	);
	my $body = '';

	my ($trans_ref, $txn_ref) = getInvoiceTransactionsDetails($db, \@TXNs);
	$trans_ref->{'TXNs'} = $txn_ref;
	$trans_ref->{'txns'} = $txns;
	$trans_ref->{'txnPPID'} = $txnPPID;

	## If the Club ID passed doesn't equal clubID against TXN then 0
	$clubID = 0 if (
		$clubID 
		and $trans_ref->{'clubID'} > 0 
		and $clubID != $trans_ref->{'clubID'}
	);
	$trans_ref->{'clubID'} = $clubID if ($clubID>0);

	
	$Data{'Realm'} = $trans_ref->{'Realm'} || 0;
	$Data{'RealmSubType'} = $trans_ref->{'RealmSubType'} || 0;
	$Data{'clientValues'}{'assocID'} = $trans_ref->{'assocID'} || 0;

	my $error = (! $trans_ref->{'Realm'} or ! $trans_ref->{'assocID'}) ? 1: 0;

	my $header_css = $noheader ? ' #spheader {display:none;} ' : '';
  getDBConfig(\%Data);
  $Data{'SystemConfig'}=getSystemConfig(\%Data);
  my $lang   = Lang->get_handle('', $Data{'SystemConfig'}) || die "Can't get a language handle!";
  $Data{'lang'}=$lang;

  $Data{'noheader'}=$noheader;
	$Data{'SystemConfig'}{'OtherStyle'} = "$header_css";
	my $header=qq[<img src="images/sp_membership.jpg" alt="" title="">];
	$header=$Data{'SystemConfig'}{'Header'} if $Data{'SystemConfig'}{'Header'};
	my $otherstyle='';
	$otherstyle.=$Data{'SystemConfig'}{'OtherStyle'} if $Data{'SystemConfig'}{'OtherStyle'};
	$otherstyle.=$Data{'SystemConfig'}{'HeaderBG'} if $Data{'SystemConfig'}{'HeaderBG'};
	$otherstyle=qq[<style type="text/css">$otherstyle</style>] if $otherstyle;
	$trans_ref->{'Style'}= $otherstyle;
	$trans_ref->{'header'}= $header;

print STDERR "HANDLE: ERROR value\n";
	if ($trans_ref->{'ok'} and $action eq 'submit')	{
		my @newTXNs=();
		for my $txn (@TXNs)	{
		# For each of the TXNs being passed, lets get their hash record from txn_ref to pass to createPartPayment
			my %params=();
			my $thisTXN = undef;
			for my $t (@{$txn_ref}) {
				if ($t->{'intTransactionID'} == $txn)	{
					$thisTXN = $t;
				}
			}
			next if ! $thisTXN;
			$params{'amount_paying'} = safe_param($txn."_amount_paying", 'number') || 0;
			print STDERR "PAY: $params{'amount_paying'}\n";
			$params{'payee'} = safe_param("payee", 'words') || '';
			$params{'payee_notes'} = safe_param("payee_notes", 'words') || '';
			next if ! $params{'amount_paying'};
			next if $params{'amount_paying'} > $thisTXN->{'AmountOwing'};
			push @newTXNs, createPartPayment($db, $trans_ref, $thisTXN, \%params);
		}
		$Data{'clientValues'}{'clubID'} = $clubID;
		my $checkOut = Payments::checkoutConfirm(\%Data, $paymentType, \@newTXNs,1) || q{};
		$trans_ref->{'checkout'} = $checkOut;
	}
	else	{
	}
	my $result = runTemplate(
  	undef,
  	$trans_ref,
  	'payment/invoice_pay.templ'
  );
  $body = $result if($result);


	disconnectDB($db);
	print "Content-type: text/html\n\n";
	print $body;
}


