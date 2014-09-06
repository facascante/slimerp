#!/usr/bin/perl

#
# $Header: svn://svn/SWM/trunk/web/admin/nab_manual_NON_ABA.cgi 8249 2013-04-08 08:14:07Z rlee $
#

use strict;

use lib "../..","..","../comp";

use Defs;
use Utils;
use DBI;
use HTTP::Request::Common qw(POST);
use LWP::UserAgent;
use PaymentSplitExport;
use BankAccountObj;
use Mail::Sendmail;
use CGI qw(unescape);
use DeQuote;
use ExportEmailData;
use PMSHold;
use Data::Dumper; 

main();

sub main	{

	my %Data = ();
	my $db = connectDB();
	$db->{mysql_auto_reconnect} = 1;
	$db->{wait_timeout} = 3700;
	$db->{mysql_wait_timeout} = 3700;

	$Data{'db'} = $db;
	my $exportBankFileID = getExportBankFileID(0, 0, $db, $Defs::EXPORTFILE_NAB_MANUAL);
		
    my $st = qq[
		UPDATE
			tblMoneyLog as ML
			INNER JOIN tblTransLog as TL ON (TL.intLogID = ML.intTransLogID)
			LEFT JOIN tblPaymentApplication as PA ON (PA.intEntityID=ML.intEntityID AND PA.intEntityTypeID=ML.intEntityType AND PA.intPaymentType=TL.intPaymentType)
		SET 
			intExportBankFileID = ?
		WHERE 
			ML.dtEntered<= DATE_ADD(CURRENT_DATE(), INTERVAL -1 HOUR)
			AND ML.intRealmID NOT IN (35)
	      	AND ML.intExportBankFileID = 0
        	AND ML.intMYOBExportID = 0
			AND TL.intPaymentType IN ($Defs::PAYMENT_ONLINENAB)
			AND TL.intExportOK = 1
        	AND ML.intLogType IN (6)
			AND ML.strCurrencyCode = 'AUD'
			AND strBankCode NOT LIKE '08%'
	];
	my $qry = $db->prepare($st);
	$qry->execute($exportBankFileID);
	
	createManualFile($db, $exportBankFileID);
        
}

sub createManualFile	{

	my ($db, $exportBankFileID) = @_;

	### Send to Dazz
	my $st = qq[
		SELECT
			SUM(curMoney) as ManualAmount,
			intApplicationID
		FROM 
			tblMoneyLog as ML
			INNER JOIN tblPaymentApplication as PA ON (
				ML.intEntityType = PA.intEntityTypeID
				AND ML.intEntityID = PA.intEntityID
				AND PA.intPaymentType= $Defs::PAYMENT_ONLINENAB
			)
		WHERE
			intExportBankFileID = ?
		GROUP BY
		 	PA.intApplicationID
	];
	my $qry = $db->prepare($st);
	$qry->execute($exportBankFileID);
	my $manualExport = '';

	while (my $dref=$qry->fetchrow_hashref())	{
		$manualExport .= qq[$dref->{intApplicationID}\t];
		$manualExport .= qq[$dref->{ManualAmount}\t];
		$manualExport .= qq[\n];
	}

	my $st_mr = qq[
			INSERT INTO tblPayment_MassPayReply	(
				intBankFileID,
				strResult,
				tmTimeStamp,
				strMassPaySend
			)
			VALUES (
				?,
				?,
				NOW(),
				?
			)
	];
	my $q_mr = $db->prepare($st_mr);
	$q_mr->execute($exportBankFileID, 'Success', $manualExport);
		
	#CREATE ON HOLDS

}

sub notifyEmail	{
	my($message, $title) = @_;

	$title ||= 'WARNING: NAB Direct File Issue';
  	my %mail = (
            To => 'warren@sportingpulse.com, b.irvine@sportingpulse.com, d.bell@sportingpulse.com',
            From  => $Defs::admin_email,
            Subject => $title,
            Message => $message,
  );
  if($mail{To}) {
		open MAILLOG, ">>$Defs::mail_log_file" or print STDERR "Cannot open MailLog $Defs::mail_log_file\n";
		$mail{To} = $Defs::global_mail_debug if $Defs::global_mail_debug;
    if (sendmail %mail) {
      print MAILLOG (scalar localtime()).":MPAY_WARNING:$mail{To}:Sent OK.\n";
    }
    else {
      print MAILLOG (scalar localtime())." MPAY_WARNING:$mail{To}:Error sending mail: $Mail::Sendmail::error \n";
    }
    close MAILLOG;
  }
  return '';
}

