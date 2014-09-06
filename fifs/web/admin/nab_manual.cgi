#!/usr/bin/perl

#
# $Header: svn://svn/SWM/trunk/web/admin/nab_manual.cgi 10127 2013-12-03 03:59:01Z tcourt $
#

use strict;
use lib "..","../..","../comp";
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
use PaymentSplitMoneyLog;
use ExportEmailData;
use PMSHold;
use Data::Dumper; 
use DirectEntryExport;
use MIME::Entity;
use FileHandle;

main();

sub main	{

	my $db = connectDB();
	$db->{mysql_auto_reconnect} = 1;
	$db->{wait_timeout} = 3700;
	$db->{mysql_wait_timeout} = 3700;

	my $st = qq[
		SELECT 
			intRuleID,
			intRealmID,
			intSubTypeID
		FROM
		 	tblPaymentSplitRule 
		WHERE 
			strFinInst = 'PAYPAL_NAB'
			AND intRealmID NOT IN (35)
			AND strCurrencyCode = 'AUD'
		ORDER BY intSubTypeID DESC
	];
	my $q = $db->prepare($st);
	$q->execute();

	my @ExportIDs=();
	my %postingsAccs=();
	my %postingsAmts=();
	my $exportTotalAmount=0;
	my %MLids = ();
	my %MPEmails=();
    my %Holds=();

	my $exportBankFileID = getExportBankFileID(0, 3, $db, $Defs::EXPORTFILE_NAB_ABA);
	push @ExportIDs, $exportBankFileID;

	while(my $dref = $q->fetchrow_hashref())	{
		my $ruleID = $dref->{'intRuleID'};
    	my $realmID = $dref->{intRealmID} || next ;
		my $subRealmWHERE = ($dref->{'intSubTypeID'}) ? qq[ AND ML.intRealmSubTypeID = $dref->{'intSubTypeID'}] : '';

      	my $totalAmount =prepareExport($db, $ruleID, $realmID, $subRealmWHERE, $exportBankFileID, \%MLids, \%MPEmails, \%postingsAmts, \%postingsAccs) || 0;
		$exportTotalAmount+=$totalAmount;
		
      	my $releaseHolds = releasePMSHold($db, $realmID, $Defs::PAYMENT_ONLINENAB);
      	for my $r (keys %$releaseHolds) {
				my $bsb = $releaseHolds->{$r}{'bsb'};
				my $accNum = $releaseHolds->{$r}{'accNum'};
				my $accountName = $releaseHolds->{$r}{'accName'} || '';
				my $amount = $releaseHolds->{$r}{'amountheld'};
				my $bankKey = $bsb."|".$accNum."|".$accountName;
				updatePostings(0, '', $bsb, $accNum, $accountName, $amount, \%postingsAccs, \%postingsAmts);
      			$Holds{$r}=1;
				$MPEmails{$bankKey}=1;
				$exportTotalAmount+=$amount;
			}
	}
	my ($splitCount, $nabExport) = doDirectEntryExport(-99, \%postingsAmts, \%postingsAccs, $exportBankFileID, $exportTotalAmount, $db);
	sendBankFile($db, $exportBankFileID, $nabExport, \%MPEmails, \%MLids, \%Holds) if ($splitCount);
	exit;
}

sub prepareExport   {

    my ($db, $ruleID, $realmID, $subRealmWHERE, $exportBankFileID, $MLids_ref, $MPEmails_ref, $postingsAmts_ref, $postingsAccs_ref) = @_;

	my $exportTotalAmount=0;
    my %Exports=();

    my $ml_st = qq[
			SELECT 	
				DISTINCT
				ML.*
			FROM 
				tblMoneyLog as ML
				INNER JOIN tblTransLog as TL ON (TL.intLogID = ML.intTransLogID)
				LEFT JOIN tblBankAccount as BA ON (
					BA.intEntityID=ML.intEntityID
					AND BA.intEntityTypeID = ML.intEntityType
				)
			WHERE 
				ML.intRuleID = $ruleID
				AND ML.intRealmID = $realmID
				$subRealmWHERE
	      		AND ML.intExportBankFileID = 0
        		AND ML.intMYOBExportID = 0
				AND TL.intPaymentType IN ($Defs::PAYMENT_ONLINENAB)
				AND TL.intExportOK = 1
        		AND ML.intLogType NOT IN ($Defs::ML_TYPE_SPORTTOTAL)
				AND (BA.intStopNABExport IS NULL or BA.intStopNABExport = 0)
				AND ML.dtEntered<= DATE_ADD(CURRENT_DATE(), INTERVAL -2 DAY)
	];
	my $ml_qry = $db->prepare($ml_st);
	$ml_qry->execute();
	my %ML=();
	while (my $mlref = $ml_qry->fetchrow_hashref())	{
		my $bsb = $mlref->{strBankCode} || '';
		my $accNum = $mlref->{strAccountNo} || '';
		my $accName = $mlref->{strAccountName} || '';
		next if ((! $bsb or ! $accNum or ! $accName or $bsb =~ /^08/));
		#next if ($mlref->{'intLogType'} !~ /2|3/ and (! $bsb or ! $accNum or ! $accName or $bsb =~ /^08/));
		my $bankKey = $bsb."|".$accNum."|".$accName;
		if ($mlref->{intLogType} == 6)	{
			next if ! $bankKey;
			$Exports{$bankKey}{'amount'} += $mlref->{'curMoney'};
		}   
		$ML{$mlref->{'intMoneyLogID'}} = 1;
		if ($mlref->{intLogType} == 4)	{
			$Exports{$bankKey}{'amount'} += $mlref->{'curMoney'};
		}
		push @{$MLids_ref->{$bankKey}}, $mlref->{intMoneyLogID};
	}
    my $holds_ref = checkForPMSHolds($db, $realmID, $Defs::PAYMENT_ONLINENAB);

$MPEmails_ref->{'||'} = 1;
	for my $k (keys %Exports)	{
		my $amount = $Exports{$k}{'amount'} || 0;
		$amount= sprintf("%.2f", $amount);
      	if (exists $holds_ref->{$k} and $holds_ref->{$k} == 1)   {
      		my $new_amount = createPMSMassPayHold($db, $realmID, $exportBankFileID, $k, $amount, $Defs::PAYMENT_ONLINENAB);
        	$amount = $new_amount;
      	}
		$MPEmails_ref->{$k} = 1;
      	next if (! $amount or ! $k or $amount eq '0.00');
		my ($bsb, $accNum, $accountName) = split /\|/,$k;
		
		updatePostings(0, '', $bsb, $accNum, $accountName, $amount, $postingsAccs_ref, $postingsAmts_ref);
		$exportTotalAmount+=$amount;
	}
    return $exportTotalAmount;
}

sub sendBankFile	{

	my ($db, $exportBankFileID, $nabExport, $MPEmails_ref, $MLids_ref, $ReleaseHold) = @_; 

	my %output=();
	my $outputstr = '';

	### Write to file and send to NAB
 	my $dir       = $Defs::bank_export_dir || '';
    my $filename  = $exportBankFileID . '_manualaba.txt';
        $filename ||= '';
        my $fname     = "$dir/$filename" || '';

	my $message = qq[NAB Manual File attached];
	my $subject = qq[NAB Manual File];
my $retval   = emailExportData($db, '', $Defs::accounts_email, $message, '', $subject, $filename, $nabExport, '');

	my $st_mr = qq[
			INSERT INTO tblPayment_MassPayReply	( intBankFileID, strResult, tmTimeStamp, strText, strMassPaySend)
			VALUES ( ?, ?, NOW(), ?, ?)
	];
	my $q_mr = $db->prepare($st_mr);

	$st_mr = qq[
		UPDATE tblPayment_MassPayReply
		SET strResult=?, strText = ?
		WHERE intBankFileID = ?
		LIMIT 1
	];
	my $q_mrUpdate = $db->prepare($st_mr);

	$q_mr->execute($exportBankFileID, $output{'ACK'}, $outputstr , $nabExport);
		
	%output=();
	$output{'ACK'} = 'Success';

	if($output{'ACK'} =~/^Success/)	{
		moneyLogUpdate($db, $exportBankFileID, $MPEmails_ref, $MLids_ref);
        updatePMSHolds($db,0, $exportBankFileID, 1);
        if (ref $ReleaseHold)   {
            for my $holdID (keys %$ReleaseHold)  {
                finaliseRelease($db, $holdID, 0, $exportBankFileID);
            }
        }
	}
	else	{
    	updatePMSHolds($db,0, $exportBankFileID, -1);
	}
	$q_mrUpdate->execute( $output{'ACK'}, $outputstr , $exportBankFileID);
}
1;
