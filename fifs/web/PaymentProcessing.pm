#
# $Header: svn://svn/SWM/trunk/web/PaymentProcessing.pm 10148 2013-12-03 23:01:55Z tcourt $
#

package PaymentProcessing;
require Exporter;
@ISA = qw(Exporter);
@EXPORT=qw(EmailPaymentConfirmation UpdateCart processTransLog);
@EXPORT_OK=qw(EmailPaymentConfirmation UpdateCart processTransLog);

use strict;
use Utils;
use MD5;
use DeQuote;
use CGI qw(param);
use Email;
use ServicesContacts;
require Payments;

sub EmailPaymentConfirmation	{

	my ($Data, $paymentSettings, $intLogID, $client) = @_;

	my $st = qq[
		SELECT * , DATE_FORMAT(dtLog,'%d/%m/%Y') AS dateLog
		FROM tblTransLog
		WHERE intLogID = $intLogID
			AND intStatus = 1
	];
    	my $qry = $Data->{db}->prepare($st) or query_error($st);
    	$qry->execute or query_error($st);
	my $tref = $qry->fetchrow_hashref();
	return if ! ref $tref;

	my $body_header_txt = qq[
$Data->{'SystemConfig'}{'paymentReceiptHeaderTEXT'}
You have successfully made a payment of \$$tref->{intAmount}.\n

Bank Reference Number:$tref->{strTXN} 
Payment ID:$tref->{intLogID} 
Date Purchased:$tref->{dateLog} 
];
	my $body_header_html = qq[ $Data->{'SystemConfig'}{'paymentReceiptHeaderHTML'}
<p>You have successfully made a payment of \$$tref->{intAmount}.<br>
<b>Bank Reference Number:</b>$tref->{strTXN}<br>
<b>Payment ID:</b>$tref->{intLogID}<br>
<b>Date Purchased:</b>$tref->{dateLog}</p>
];

	my $body_html='';
	my $body_txt='';

	my $st_trans = qq[
		SELECT intTXNID
		FROM tblTXNLogs
		WHERE intTLogID = $intLogID
	];
    	my $qry_trans = $Data->{db}->prepare($st_trans) or query_error($st_trans);
    	$qry_trans->execute or query_error($st_trans);
	my $email_address='';
	my $count=0;
	while (my $trans_ref = $qry_trans->fetchrow_hashref())	{
		$count++;
		my $txnRef = Payments::getTXNDetails($Data, $trans_ref->{intTXNID}, 0);
		my $abn = $txnRef->{strBusinessNo} ? qq[ABN: $txnRef->{strBusinessNo}] : '';
		$email_address .= qq[$txnRef->{Email};];	
		$email_address .= qq[$txnRef->{P1Email};] if ($txnRef->{P1Email});
		$body_txt .= qq[
---------------------------------------------------------------------\n
A payment of \$$txnRef->{curAmount} $txnRef->{strGSTText} for $txnRef->{Name} at $txnRef->{strName} $Data->{'SystemConfig'}{'paymentAssocType'}\n
Invoice Number:$txnRef->{InvoiceNum}
Product:(Qty $txnRef->{intQty}) $txnRef->{ProductName}
$abn
];
$body_txt .=qq[Description:$txnRef->{strProductNotes}\n] if ($txnRef->{strProductNotes});
$body_txt .=qq[Amount:\$$txnRef->{curAmount} $txnRef->{strGSTText}\n
$txnRef->{strPaymentReceiptBodyTEXT}
$Data->{'SystemConfig'}{'paymentReceiptFooterTEXT'}
];
		$txnRef->{strProductNotes}=~s/\n/<br>/g;
		$abn = $txnRef->{strBusinessNo} ? qq[<b>ABN:</b> $txnRef->{strBusinessNo}<br>] : '';
		
		$body_html .= qq[
---------------------------------------------------------------------<br>
<p>A payment of \$$txnRef->{curAmount} $txnRef->{strGSTText} for $txnRef->{Name} at $txnRef->{strName} $Data->{'SystemConfig'}{'paymentAssocType'}<br>
<b>Invoice Number:</b>$txnRef->{InvoiceNum}<br>
<b>Product:</b>(Qty $txnRef->{intQty})- $txnRef->{ProductName}<br>
$abn
];
$body_html .= qq[
<b>Description:</b>$txnRef->{strProductNotes}<br>
] if ($txnRef->{strProductNotes});
$body_html .= qq[
<b>Amount:</b>\$$txnRef->{curAmount} $txnRef->{strGSTText}</p>
$txnRef->{strPaymentReceiptBodyHTML}
$Data->{'SystemConfig'}{'paymentReceiptFooterHTML'}
	];
		
	}
	
	$body_html = $body_header_html. qq[<p><b>The following $count invoice/s make up this payment</b></p><br>] . $body_html;
	$body_txt = $body_header_txt . qq[\nThe following $count invoice/s make up this payment\n\n] . $body_txt;

    if ($Data->{'SystemConfig'}{'paymentReceiptCC_Assoc'})  {
	    my $st = qq[
	        SELECT DISTINCT 
                T.intAssocID,
                A.strEmail as AssocEmail,
                intTXNClubID as ClubID,
                C.strEmail as ClubEmail

			FROM 
                tblTransactions as T
                LEFT JOIN tblClub as C ON (
                    C.intClubID = intTXNClubID
                )
                LEFT JOIN tblAssoc as A ON (
                    A.intAssocID = T.intAssocID
                )
			WHERE T.intTransLogID = $intLogID
		];
    	my $qry_assoc= $Data->{db}->prepare($st) or query_error($st);
    	$qry_assoc->execute or query_error($st);
		while (my $dref = $qry_assoc->fetchrow_hashref())	{
            my $assocEmail = '';
            my $clubEmail = '';
            ## Lets see if the Clubs have Contacts & Services people with Payments emails
            if ($dref->{'ClubID'})   {
                $clubEmail = getServicesContactsEmail($Data, $Defs::LEVEL_CLUB, $dref->{ClubID}, $Defs::SC_CONTACTS_PAYMENTS) || $dref->{'ClubEmail'};
            }
            $assocEmail = getServicesContactsEmail($Data, $Defs::LEVEL_ASSOC, $dref->{'intAssocID'}, $Defs::SC_CONTACTS_PAYMENTS) || $dref->{'AssocEmail'} ||  $Defs::admin_email;
            $assocEmail .= qq[;] if ($assocEmail);
            $assocEmail .= $clubEmail;
            $email_address .= qq[$assocEmail;];
	    }
    }
	
	sendEmail($email_address, $paymentSettings->{notification_address}, 'Payment Received','', $body_html, $body_txt,'Payment Confirmation - $intLogID');

}
sub UpdateCart	{

    my ($db, $paymentSettings, $client, $txn, $code, $intLogID) = @_;

    deQuote($db, \$txn);

	my $st= qq[
        UPDATE tblTransactions INNER JOIN tblTXNLogs as TXNLog ON (tblTransactions.intTransactionID= TXNLog.intTXNID)
        SET intStatus = 1, dtPaid = SYSDATE(), intTransLogID = $intLogID
		WHERE TXNLog.intTLogID= $intLogID
            AND intStatus = 0
    ];
    my $qry = $db->prepare($st) or query_error($st);
    $qry->execute or query_error($st);
print STDERR $st;
	
}

sub processTransLog    {

    my ($db, $txn, $responsecode, $responsetext, $intLogID, $paymentSettings, $passedChkValue, $settlement_date) = @_;

    my %fields=();
    $intLogID ||= 0;
    $fields{txn} = $txn || '';
    $fields{responsecode} = $responsecode || '';
    $fields{responsetext} = $responsetext || '';
    $fields{settlement_date} = $settlement_date || '';
	my $intStatus = $Defs::TXNLOG_FAILED;
	$intStatus = $Defs::TXNLOG_SUCCESS if ($responsecode eq "00" or $responsecode eq "08" or $responsecode eq "OK" or $responsecode eq "1" or $responsecode eq 'Success');

	my $statement = qq[
		SELECT intAmount , intPaymentType
		FROM tblTransLog
		WHERE intLogID = $intLogID
			AND strResponseCode IS NULL
	];
    my $query = $db->prepare($statement) or query_error($statement);
    $query->execute or query_error($statement);

	my ($amount, $paymentType)=$query->fetchrow_array();
	$amount ||= 0;
	$paymentType ||= 0;
	$amount= sprintf("%.2f", $amount);
	my $chkvalue = $amount . $intLogID . $responsecode;
    my $m;
    $m = new MD5;
    $m->reset();

    $m->add($paymentSettings->{'gateway_string'}, $chkvalue);
    $chkvalue = $m->hexdigest();

    deQuote($db, \%fields);
	if (! $responsecode)	{
		Payments::processTransLogFailure($db, $intLogID);
	}
	else	{
    		$statement = qq[
        		UPDATE tblTransLog
        		SET dtLog=SYSDATE(), strTXN = $fields{txn}, strResponseCode = $fields{responsecode}, strResponseText = $fields{responsetext}, intStatus = $intStatus, dtSettlement=$fields{settlement_date}
        		WHERE intLogID = $intLogID
			AND strResponseCode IS NULL
    		];
    		$query = $db->prepare($statement) or query_error($statement);
    		$query->execute or query_error($statement);
		print STDERR "PT$paymentType | $intStatus\n";
		if (($paymentType == $Defs::PAYMENT_ONLINENAB or $paymentType == $Defs::PAYMENT_ONLINEPAYPAL) 
			and $intStatus == $Defs::TXNLOG_SUCCESS)	{
			calcPayPalFees($db, undef, 0, $intLogID);
		}
	}

	$intLogID=0 if ($chkvalue ne $passedChkValue);

	
	return $intLogID || 0;
}
1;
