#!/usr/bin/perl

#
# $Header: svn://svn/SWM/trunk/automatic/masspay_split.pl 9462 2013-09-10 02:36:43Z tcourt $
#

use strict;

use lib "..","../web","../web/comp";

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

main();

sub main	{

	my %Data = ();
	my $db = connectDB();
	$db->{mysql_auto_reconnect} = 1;
	$db->{wait_timeout} = 3700;
	$db->{mysql_wait_timeout} = 3700;

	$Data{'db'} = $db;
	my $live=1;

	my $st = qq[
		SELECT 
			intRuleID,
			intRealmID,
			intSubTypeID,
			strCurrencyCode
		FROM
		 tblPaymentSplitRule 
		WHERE strFinInst = 'PAYPAL_NAB'
			AND intRealmID NOT IN (35)
		ORDER BY intSubTypeID DESC
	];
	my $q = $db->prepare($st);
	$q->execute();

	my $dbSysDate = getDBSysDate($db);

	my @ExportIDs=();

	while(my $dref = $q->fetchrow_hashref())	{
		my $ruleID = $dref->{'intRuleID'};
		my $currencyCode = $dref->{strCurrencyCode} || 'AUD';
        my $realmID = $dref->{intRealmID} || 0;
        next if $realmID==0;

		my $subRealmWHERE = '';
		$subRealmWHERE = qq[ AND ML.intRealmSubTypeID = $dref->{'intSubTypeID'}] if $dref->{'intSubTypeID'}; 
		my %values=();

        my $rerun=0;
        while (my $i==0) {
            $rerun++;
            $i=prepareMP($db, $live, $ruleID, $realmID, $subRealmWHERE, $currencyCode, \@ExportIDs);
            last if $i==0;
            last if $rerun==10;
        }
		my %Transactions=();
		my %MPEmails=();
		my %MLids = ();
		my %TXNids = ();
		my $exportBankFileID = getExportBankFileID($realmID, $ruleID, $db, $Defs::EXPORTFILE_PAYPAL);
		push @ExportIDs, $exportBankFileID;
		
		my $count = 0;
		
        ## Lets check for returns
		{	
            $MPEmails{''}=1;
            my $releaseHolds = releasePMSHold($db, $realmID);
            %values=();
			%MPEmails=();
            $count=0;
            my %Holds=();
            for my $r (keys %$releaseHolds) {
			    $values{'L_EMAIL'.$count} = $releaseHolds->{$r}{'email'};
			    $values{'L_AMT'.$count} += $releaseHolds->{$r}{'amountheld'};
			    $values{'L_UNIQUEID'.$count} = "$exportBankFileID-$count";
			    $values{'L_NOTE'.$count} = "SportingPulse Transfer";
                $Holds{$r}=1;
			    $MPEmails{$releaseHolds->{$r}{'email'}} = 1;
                $count++;
                if ($count >= 240)	{
                    $MPEmails{''}=1;
			        sendMassPay($db, $realmID, $live, $currencyCode, $exportBankFileID, \%values, \%MPEmails, \%MLids, \%Holds);
				    %values=();
				    %MPEmails=();
				    $count=0;
                    %Holds=();
                }
			}
		    if ($count)	{	
                $MPEmails{''}=1;
			    sendMassPay($db, $realmID, $live, $currencyCode, $exportBankFileID, \%values, \%MPEmails, \%MLids, \%Holds);
		    }   
		}

	}
	sendExportSummaryEmail($db, \@ExportIDs);

	exit;
}
sub prepareMP   {

    my ($db, $live, $ruleID, $realmID, $subRealmWHERE, $currencyCode, $ExportIDs) = @_;

    my %Exports=();

    my $ml_st = qq[
			SELECT 	
				ML.*, VE.strEmail as VerifiedEmail
			FROM 
				tblMoneyLog as ML
				INNER JOIN tblTransLog as TL ON (TL.intLogID = ML.intTransLogID)
				LEFT JOIN tblVerifiedEmail as VE ON (VE.strEmail = ML.strMPEmail
					AND VE.dtVerified IS NOT NULL)
			WHERE 
				ML.intRuleID = $ruleID
				AND ML.dtEntered<= DATE_ADD(CURRENT_DATE(), INTERVAL -2 DAY)
				AND ML.intRealmID = $realmID
				$subRealmWHERE
	            AND ML.intExportBankFileID = 0
        	    AND ML.intMYOBExportID = 0
				AND TL.intPaymentType IN ($Defs::PAYMENT_ONLINEPAYPAL)
				AND TL.intExportOK = 1
                AND ML.intLogType NOT IN ($Defs::ML_TYPE_SPORTTOTAL)
		];

		my $ml_qry = $db->prepare($ml_st);
		$ml_qry->execute();
		my %ML=();
		my %Transactions=();
		my %Summary=();
		my %MPEmails=();
		my %MLids = ();
		my %TXNids = ();
        my $rerun=0;
		while (my $mlref = $ml_qry->fetchrow_hashref())	{
			my $exportEmail = $mlref->{strMPEmail} || '';
            if (! $Exports{$exportEmail}{'amount'} or ($Exports{$exportEmail}{'amount'}+$mlref->{'curMoney'} <=11500))    {
			    $Transactions{$mlref->{intTransactionID}} = 1 if $mlref->{intTransactionID};
			
			    if ($mlref->{intLogType} == 6)	{
			    	next if ! $mlref->{'strMPEmail'};
			    	next if ! $mlref->{'VerifiedEmail'};
			    	$Exports{$exportEmail}{'amount'} += $mlref->{'curMoney'};
			    	$Summary{'totAmount'} += $mlref->{'curMoney'};
			    }   
			    $ML{$mlref->{'intMoneyLogID'}} = 1;
			    if ($mlref->{intLogType} == 4)	{
				    $Exports{$exportEmail}{'amount'} += $mlref->{'curMoney'};
				    $Summary{'totAmount'} += $mlref->{'curMoney'};
			    }
			    push @{$MLids{$exportEmail}}, $mlref->{intMoneyLogID};
            }
            else    {
                $rerun=1;
                last;
            }
		}
		my $exportBankFileID = getExportBankFileID($realmID, $ruleID, $db, $Defs::EXPORTFILE_PAYPAL);
		push @$ExportIDs, $exportBankFileID;
		
		my $count = 0;
        my %values=();
		
        my $holds_ref = checkForPMSHolds($db, $realmID); 
        ## CHECK FOR HOLD RE-RELEASE
        
		for my $k (keys %Exports)	{
			my $amount = $Exports{$k}{'amount'} || 0;
			$amount= sprintf("%.2f", $amount);
            if (exists $holds_ref->{$k} and $holds_ref->{$k} == 1)   {
                my $new_amount = createPMSMassPayHold($db, $realmID, $exportBankFileID, $k, $amount);
                $amount = $new_amount;
            }
			$MPEmails{$k} = 1;
            next if (! $amount or ! $k or $amount eq '0.00');
			$values{'L_EMAIL'.$count} = $k;
			$values{'L_AMT'.$count} += $amount;
			$values{'L_UNIQUEID'.$count} = "$exportBankFileID-$count";
			$values{'L_NOTE'.$count} = "SportingPulse Transfer";
			$MPEmails{$k} = 1;
			$count++;
			if ($count >= 240)	{
                $MPEmails{''}=1;
				sendMassPay($db, $realmID, $live, $currencyCode, $exportBankFileID, \%values, \%MPEmails, \%MLids, undef);
				%values=();
				#%values=%header;
				%MPEmails=();
				$count=0;
			}
			#### SPLIT AFTER 250 !!!!
		}
		if ($count)	{	
                $MPEmails{''}=1;
			sendMassPay($db, $realmID, $live, $currencyCode, $exportBankFileID, \%values, \%MPEmails, \%MLids, undef);
		}
        
        return $rerun;

}

sub sendExportSummaryEmail	{

	my ($db, $exportIDs_ref) = @_;

	my $ids = '';
	for my $i (@{$exportIDs_ref}) {
		$ids .= qq[, ] if $ids;
		$ids .= qq[$i];
        }
	my $body= '';
	if ($ids)	{
		my $st = qq[
			SELECT DISTINCT 
				ML.intExportBankFileID,
				R.strRealmName as RealmName, 
				IF(ML.intEntityType > 5, N.strName, A.strName) as MoneyToName, 
				C.strName as ClubName, 
				IF(intLogType=1, 'GATEWAY FEES', strMPEmail) as Email, 
				SUM(curMoney) as Money 
			FROM 
				tblMoneyLog as ML 
				INNER JOIN tblAssoc as A ON (A.intAssocID=ML.intAssocID) 
				INNER JOIN tblRealms as R ON (R.intRealmID=ML.intRealmID) 
				LEFT JOIN tblClub as C ON (ML.intClubID=C.intClubID)
				LEFT JOIN tblNode as N ON (N.intNodeID = ML.intEntityID)
			WHERE 
				intExportBankFileID IN ($ids) 
				AND intLogType IN (1,4,6) 
			GROUP BY 
				ML.intExportBankFileID,
				strMPEmail, 
				intLogType, 
				ML.intEntityType,
				ML.intEntityID,
				ML.intAssocID, 
				ML.intClubID 
			ORDER BY
				MoneyToName
		];

		my $q = $db->prepare($st);
		$q->execute();
		while(my $dref = $q->fetchrow_hashref())	{
			$body .= qq[$dref->{'intExportBankFileID'}\t$dref->{'RealmName'}\t$dref->{'MoneyToName'}\t$dref->{'ClubName'}\t$dref->{'Email'}\t$dref->{'Money'}\n];
		}
		if ($body)	{
			$body = qq[ExportID	REALM	MONEY TO	CLUB	EMAIL	AMOUNT\n] . $body;
		 	my $filename = 'MASSPAYsummary.txt';
    			my $message  = "The Masspay run Summary data is included in the attached file ($filename)" ;
    			my $retval   = emailExportData($db, '', 'j.tinkler@sportingpulse.com', $message, '', 'MassPay Summary', $filename, $body, '');
		}
	}

}
sub sendMassPay	{

	my ($db, $realmID, $live, $currencyCode, $exportBankFileID, $values_ref, $MPEmails_ref, $MLids_ref, $ReleaseHold) = @_; 

	my %output=();
	my $outputstr = '';

	my $APIusername= $live  == 1 ? $Defs::PAYPAL_LIVE_USERNAME : $Defs::PAYPAL_DEMO_USERNAME;
    my $APIpassword= $live == 1 ? $Defs::PAYPAL_LIVE_PASSWORD : $Defs::PAYPAL_DEMO_PASSWORD;
    my $APIsignature= $live == 1 ? $Defs::PAYPAL_LIVE_SIGNATURE : $Defs::PAYPAL_DEMO_SIGNATURE;
    my $APIurl= $live == 1 ? $Defs::PAYPAL_LIVE_URL_MASSPAY : $Defs::PAYPAL_DEMO_URL_MASSPAY;
    my %values=();
		my %header = (
			USER => $APIusername,
			PWD => $APIpassword,
			SIGNATURE => $APIsignature,
			VERSION => $Defs::PAYPAL_VERSION,

			METHOD => 'MassPay',
			EMAILSUBJECT => 'Payment Received',
			CURRENCYCODE => $currencyCode,
			RECEIVERTYPE => 'EmailAddress',
		);
		#%values=%header;
		foreach my $key (keys %$values_ref)  {
        	        $values{$key} = $values_ref->{$key};
        	}
		foreach my $key (keys %header)  {
        	        $values_ref->{$key} = $header{$key};
        	}
	my $var=  Dumper($values_ref);

	my $st_mr = qq[
			INSERT INTO tblPayment_MassPayReply	(
				intBankFileID,
				strResult,
				tmTimeStamp,
				strText,
				strMassPaySend
			)
			VALUES (
				?,
				?,
				NOW(),
				?,
				?
			)
	];
	my $q_mr = $db->prepare($st_mr);

	$st_mr = qq[
		UPDATE tblPayment_MassPayReply
		SET strResult=?, strText = ?
		WHERE intBankFileID = ?
		LIMIT 1
	];
	my $q_mrUpdate = $db->prepare($st_mr);

	$q_mr->execute($exportBankFileID, $output{'ACK'}, $outputstr , $var);
		
	%output=();
	my $ua = LWP::UserAgent->new();
  $APIurl= $live == 1 ? $Defs::PAYPAL_LIVE_URL_MASSPAY : $Defs::PAYPAL_DEMO_URL_MASSPAY;
	my $req = POST $APIurl, $values_ref;
	my $res= $ua->request($req);
	my $retval = $res->content() || '';
	$outputstr = '';
	for my $line (split /&/,$retval) {
		my ($k,$v)=split /=/,$line,2;
		$output{$k}=$v;
		$outputstr .= "$k => ".unescape($v)."\n";
	}

	#$output{'ACK'} = 'Success';
#print STDERR "BACK FROM MASSPAY\n";
	
	if($output{'ACK'} =~/^Success/)	{
		moneyLogUpdate($db, $exportBankFileID, $MPEmails_ref, $MLids_ref);
        updatePMSHolds($db,$realmID, $exportBankFileID, 1);
        if (ref $ReleaseHold)   {
            for my $holdID (keys %$ReleaseHold)  {
                finaliseRelease($db, $holdID, $realmID, $exportBankFileID);
            }
        }
	}
	else	{
        updatePMSHolds($db,$realmID, $exportBankFileID, -1);
		notifyEmail(qq[ Masspay run $exportBankFileID was not successful\n$outputstr ]);
	}
	$q_mrUpdate->execute( $output{'ACK'}, $outputstr , $exportBankFileID);
}

sub alterLog	{

	my ($db, $exportBankFileID, $email, $amount) = @_;

	deQuote($db, \$email);
	my $st = qq[
		UPDATE tblPaymentSplitLog
		SET curAmount = $amount
		WHERE 
			intExportBankFileID = $exportBankFileID
			AND strMPEmail = $email
	];
	
	$db->do($st);


}

sub notifyEmail	{
	my($message, $title) = @_;

	$title ||= 'WARNING: MassPay Issue';
  my %mail = (
            To => 'warren@sportingpulse.com, b.irvine@sportingpulse.com, c.churchill@sportingpulse.com',
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

