#
# $Header: svn://svn/SWM/trunk/web/TransLog.pm 11428 2014-04-29 07:25:46Z dhanslow $
#

package TransLog;

require Exporter;
@ISA =  qw(Exporter);
@EXPORT = qw(handleTransLogs viewTransLog viewPayLaterTransLog);
@EXPORT_OK = qw(handleTransLogs viewTransLog viewPayLaterTransLog);

use strict;
use lib '.';
use DBI;
use Reg_common;
use Defs;
use Utils;
use ConfigOptions;
use HTMLForm;
use Switch;
use DeQuote;
use FormHelpers;
use AuditLog;
use GridDisplay;

require Products;
use Payments;
#require List;

my $entityName       = 'Transaction';
my $entityNameURL    = 'P_TXNLog';


sub handleTransLogs {
  my($action, $Data, $entityID, $personID) = @_;
	my $q=new CGI;
	$Data->{'params'} = $q->Vars();
  my $clientValues_ref = $Data->{'clientValues'};
  my ($body, $header, $db, $step1Success, $resultMessage)=('','', $Data->{'db'}, 0, '');

    my $gCount = $Data->{'params'}{'gatewayCount'} || 0;
    my $cc_submit = '';
    foreach my $i (1 .. $gCount)    {
        if ($Data->{'params'}{"cc_submit[$i]"}) {
            $cc_submit = $Data->{'params'}{"pt_submit[$i]"};
        }
        print STDERR "THE VALUE IS " . $cc_submit;
    }

  if ($action=~/step2/) {	
	  if ($cc_submit)	{
		  ($step1Success, $resultMessage) = (1,'');
	  }
	  else	{
		  ($step1Success, $resultMessage) = validateStep1($Data,$db,$clientValues_ref);
	  }
	  if ($step1Success) {
		  ($body, $header) = step2($Data, $db, $cc_submit, $clientValues_ref);
	  }
	  else {
	    $action = 'list'; 
	  }
  }
  if ($action=~/step3/) {	
	  ($resultMessage) = step3($Data, $db, $clientValues_ref);
	  $header = qq[Payment Confirmed];
  }
  if ($action=~/cancel/) {	
	  ($resultMessage) = cancelPayment($Data, $db, $clientValues_ref);
	  $action='list';
  }
  if ($action=~/list/) {
	  setupStandardList($Data);
	  ($body, $header) = listTransactions($Data, $db, $entityID, $personID, $clientValues_ref, $action, $resultMessage);
  }
  if ($action=~/payLIST/) {
	  ($body, $header) = listTransLog($Data, $entityID, $personID);
  }
	if ($action =~/payVIEW/)	{
		($body, $header) = viewTransLog($Data, $Data->{'params'}{'tlID'});
	}
  if ($action=~/(edit|display|add)/) {
	  ($body, $header)=entityDetails($action, $Data, $clientValues_ref, $db);
  }
  if ($action=~/(DEL)/) {
  	my $error = delTransLog($Data);
	  my $client=setClient($Data->{'clientValues'});
	  if ($error)	{
		  $body = qq[
			  <div class="warningmsg">$error</div>
	 		  <a href="$Data->{'target'}?client=$client&amp;a=P_TXNLog_payLIST">Return to Payment records</a>
		  ];	
	  }
	  else	{
		  $body = qq[
			  <div class="OKmsg">Record deleted successfully</div> <br>
			  Payment record has been deleted and transactions rolled back to Unpaid.<br><br>
	 		  <a href="$Data->{'target'}?client=$client&amp;a=P_TXNLog_payLIST">Return to Payment records</a>];	
	  }
	  $header = qq[Delete Payment record];
  }
  $body = $resultMessage . $body;
  return ($body, $header);
}


sub delTransLog	{
	my ($Data) = @_;
	my $intPersonID = $Data->{'clientValues'}{'personID'} || 0;
	my $intLogID = $Data->{'params'}{'tlID'} || 0;
	my $db = $Data->{'db'};
	my $st = qq[
		SELECT COUNT(intMoneyLogID) as ExportCount
		FROM
			tblMoneyLog
		WHERE intTransLogID = $intLogID
			AND intRealmID=$Data->{Realm}
			AND (
				intExportBankFileID >0
				OR  intMYOBExportID >0
			)
	];
	my $query = $db->prepare($st);
 	$query->execute;
	my $count = $query->fetchrow_array() || 0;
	return "Unable to delete Transaction.  Money has been exported" if $count;
	$st = qq[
		DELETE FROM tblTransLog
		WHERE intLogID = $intLogID
	];
	$db->do($st);
	$st = qq[
		DELETE FROM tblTXNLogs
		WHERE intTLogID = $intLogID
	];
	$db->do($st);
	$st = qq[
	  UPDATE tblTransactions
    SET 
      intStatus=$Defs::TXN_UNPAID, 
      intTransLogID=0, 
      dtPaid = NULL
    WHERE 
      intTransLogID=$intLogID 
		  AND intRealmID=$Data->{Realm}
	];
	$db->do($st);
	$st = qq[
		DELETE FROM tblMoneyLog
		WHERE intTransLogID = $intLogID
			AND intRealmID=$Data->{Realm}
			AND intExportBankFileID = 0
	];
	$db->do($st);
	return '';
}

	
sub cancelPayment {
	my ($Data, $db, $clientValues_ref) = @_;
	my $id=$Data->{'params'}{'id'} or return ('Invalid Payment');
	deQuote($db, \$id);
	my $extraWhereClause = ($clientValues_ref->{authLevel} == $Defs::LEVEL_EDU_DA) ? qq[ and m.intDeliveryAgentID=$clientValues_ref->{daID}] : '';
	my $statement=qq[
		UPDATE tblTransactions t, tblTransLog tl
		SET 
      t.intStatus = $Defs::TXN_UNPAID, 
      t.intTransLogID = 0, 
      tl.intStatus = $Defs::TXNLOG_CANCELLED
		WHERE 
      tl.intLogID = t.intTransLogID and
	    t.intTransLogID = $id and 
			t.intRealmID = $Data->{Realm} and 
			$extraWhereClause
	];
	$db->do($statement);
  auditLog($id, $Data, 'Cancel Payment', 'Transactions');
	return ('Payment Cancelled. Transactions have been flagged as unpaid.');
}


sub validateStep1 {
	my ($Data, $db, $clientValues_ref) = @_;

	my ($success, $body) = (0,'');
    my $lang = $Data->{'lang'};

	$body='<p>' . $lang->txt('To process an unpaid transaction select it by checking the box in the Pay column') . qq[</p>];

	#Check that there are actually some transactions
	foreach my $k (keys %{$Data->{params}}) {
                my $id=$k;
                $id=~s/.*_//;
                next  if $id=~/[^\d]/;
		$success=1;
		$body='';
        }

	#Validate Amount
	my $amount = $Data->{params}{intAmount};

	if ($amount !~/^[\-\d\.]+$/) {
		$body.="<br>" if $body;
		$body.= "'$amount' " . $lang->txt('is not a valid Amount');
		$success=0;
	}

	#Validate Date Paid
	my $dtLog = $Data->{params}{dtLog};
	
	my($d,$m,$y)=split /\//,$dtLog;
        use Date::Calc qw(check_date);
        if (!check_date($y,$m,$d)) {
		$body.="<br>" if $body;
		$body.= "'$dtLog' " . $lang->txt('is not valid for Date Paid');
		$success = 0;
	}

	return ($success, $body);
}

sub fixDate  {
  my($date)=@_;
  return $date if $date!~/\//;
  my ($day, $month, $year)=split /\//,$date;

  if(defined $year and $year ne '' and defined $month and $month ne '' and defined $day and $day ne '') {
    $month='0'.$month if length($month) ==1;
    $day='0'.$day if length($day) ==1;
    if($year > 20 and $year < 100)  {$year+=1900;}
    elsif($year <=20) {$year+=2000;}
    $date="$year-$month-$day";
  }
  else  { $date='';}
  return $date;
}

sub step2 {

#Handles the 'Payment Confirmation' Screen, tblTransactions records get intTempLogID set and new tblTransLog record gets added with intStatus=pending
	my ($Data, $db, $paymentTypeSubmitted, $clientValues_ref) = @_;

    my $lang = $Data->{'lang'};
	my ($body, $header) = ('', '');

	my ($currencyID, $intAmount, $dtLog, $paymentType, $strBSB, $strAccountName, $strAccountNum, $strResponseCode, $strResponseText, $strComments, $strBank, $strReceiptRef) = ($Data->{params}{currencyID}, $Data->{params}{intAmount}, $Data->{params}{dtLog}, $Data->{params}{paymentType}, $Data->{params}{strBSB}, $Data->{params}{strAccountName}, $Data->{params}{strAccountNum}, $Data->{params}{strResponseCode}, $Data->{params}{strResponseCode}, $Data->{params}{strComments}, $Data->{params}{strBank}, $Data->{params}{strReceiptRef});
    $paymentType ||= $paymentTypeSubmitted;

	#$dtLog=convertDateToYYYYMMDD($dtLog);
	$dtLog=fixDate($dtLog);
	deQuote($db, (\$currencyID, \$intAmount, \$dtLog, \$paymentType, \$strBSB, \$strAccountName, \$strAccountNum, \$strResponseCode, \$strResponseText, \$strComments, \$strBank, \$strReceiptRef));


#Load transactions, update them to point to this payment
	my @transactionIDs;
	foreach my $k (keys %{$Data->{params}}) {
                my $id=$k;
                $id=~s/.*_//;
                next  if $id=~/[^\d]/;
		push @transactionIDs, $id;
        }
		
	if ($paymentTypeSubmitted)	{
	#	if (! $Data->{'clientValues'}{'clubID'} or $Data->{'clientValues'}{'clubID'} == $Defs::INVALID_ID)	{
	#		my $whereClause = 'intTransactionID in ('.join(",", @transactionIDs).')';	
	#		my $st = qq[
	#			SELECT
	#				DISTINCT intProductID
	#			FROM
	#				tblTransactions
	#			WHERE intRealmID = $Data->{'Realm'}
	#			AND  $whereClause
	#		];
	#		my $query = $db->prepare($st);
  	#		$query->execute;
	#		while (my $productID=$query->fetchrow_array())	{
	#			if (Products::checkProductClubSplit($Data, $productID)>0)	{
	#				return ("One of these products has a club split that's attempting to send funds to a club, but the club is unknown. To sell a product with a club split applied, log in (or drill down) to club level and select the member from within the club.", "Transactions");
	#			}
	#		}
	#	}
		

			
		my $bb = Payments::checkoutConfirm($Data, $paymentType, \@transactionIDs,1);
		return ($bb, $lang->txt("Payments Checkout"));
	}

	my $whereClause = 'AND t.intTransactionID in ('.join(",", @transactionIDs).')';	
	setupStep2List($Data);
	my $displayonly = 1;

    my $authLevel = $Data->{'clientValues'}{'authLevel'}||=$Defs::INVALID_ID;
    #my $entityID = getID($Data->{'clientValues'}, $authLevel) || 0;

    my $entityID = getLastEntityID($Data->{'clientValues'});
#BAFF
    $entityID= 0 if ($entityID== $Defs::INVALID_ID);
	my $intPersonID= $Data->{'clientValues'}{'personID'}; 
	my ($transHTML, $transcount, $transCurrency_ref, $transAmount_ref)=getTransList($Data, $db, $entityID, $intPersonID, $whereClause, $clientValues_ref, 0, $displayonly);


#Make DB Changes
	my $statement = qq[
			INSERT INTO tblTransLog (intEntityPaymentID, dtLog, intAmount, strResponseCode, strResponseText, strComments, intPaymentType, strBSB, strBank, strAccountName, strAccountNum, intRealmID, intCurrencyID, strReceiptRef, intStatus) VALUES
	($entityID, $dtLog, $intAmount, $strResponseCode, $strResponseText, $strComments, $paymentType, $strBSB, $strBank, $strAccountName, $strAccountNum, $Data->{Realm}, $currencyID, $strReceiptRef, $Defs::TXNLOG_PENDING) 
	];
	my $query = $db->prepare($statement);
  	$query->execute;
	my $transLogID = $query->{'mysql_insertid'};	

	for my $i (@transactionIDs) { 
		my $st = qq[
			INSERT INTO tblTXNLogs
			(intTXNID, intTLogID)
			VALUES ($i, $transLogID)
		];
		$db->do($st);	
	}

#Try to identify any problems with amounts
	my ($transAmount, $prevCurrencyID, $multiCurrency, $warnings, $currencyUpto) = (0, 0, 0, '',0);
	foreach my $cID (@$transCurrency_ref) {
		if (!($multiCurrency) and $prevCurrencyID and ($prevCurrencyID != $cID)) {
			$warnings.='<br>' if $warnings;
			$warnings.=$lang->txt('This Payment includes transactions of multiple currencies (this makes it impossible to compare the payment amount to the total of the transactions).');
			$multiCurrency=1;
		}
		$transAmount+=$transAmount_ref->[$currencyUpto];
		$prevCurrencyID=$transCurrency_ref->[$currencyUpto];
		$currencyUpto++;
	}
	if ($transAmount != $Data->{params}{intAmount} and !$multiCurrency) {
		$warnings.='<br>' if $warnings;
		$warnings.=$lang->txt("The total of the transactions") ." ($transAmount) " . $lang->txt("amount does not equal the amount of the payment") . " ($Data->{params}{intAmount}).";
	}



#Get Currency Name
	#$statement = qq[SELECT strCurrencyName FROM tblCurrencies WHERE intCurrencyID=$currencyID and intRealmID=$Data->{Realm}];
	#$query = $db->prepare($statement);
  	#$query->execute;
	#my $currencyName='';
  	#if (my $row = $query->fetchrow_hashref()) {
	#	$currencyName=$row->{strCurrencyName};
	#}

	
			#<tr>
			#	<td class="label"><label for="l_intCurrencyID">Currency</label>:</td>
			#	<td class="value">$currencyName</td>
			#</tr>

	$header = $lang->txt('Confirm Payment');
	$body.= $lang->txt("Review the payment details below, then click Confirm Payment or Cancel Payment") . qq[
		<table cellpadding="2" cellspacing="0" border="0">
			
			<tbody id="secmain2" >	
			<tr>
				<td class="label"><label for="l_intAmount">].$lang->txt('Amount.').qq[</label>:</td>
				<td class="value">
				$Data->{params}{intAmount}
</td>
			</tr>

		
			<tr>
				<td class="label"><label for="l_dtLog">].$lang->txt('Date Paid').qq[</label>:</td>
				<td class="value">$Data->{params}{dtLog}</td>
			</tr>
	#	
		
			<tr>
				<td class="label"><label for="l_intPaymentType">].$lang->txt('Payment Type').qq[</label>:</td>
				<td class="value">$Defs::manualPaymentTypes{$Data->{params}{paymentType}}</td>
			</tr>
		
			<!--<tr>
				<td class="label"><label for="l_strBank">Bank</label>:</td>
				<td class="value">$Data->{params}{strBank}</td>
			</tr>

			<tr>

				<td class="label"><label for="l_strBSB">BSB</label>:</td>
				<td class="value">$Data->{params}{strBSB}</td>
			</tr>
		
			<tr>
				<td class="label"><label for="l_strAccountName">Account Name</label>:</td>
				<td class="value">$Data->{params}{strAccountName}</td>
			</tr>
		
			<tr>
				<td class="label"><label for="l_strAccountNum">Account Number</label>:</td>
				<td class="value">$Data->{params}{strAccountNum}</td>
			</tr>
		
			<tr>
				<td class="label"><label for="l_strResponseCode">Response Code</label>:</td>

				<td class="value">$Data->{params}{strResponseCode}</td>
			</tr>
		
			<tr>
				<td class="label"><label for="l_strResponseText">Response Text</label>:</td>
				<td class="value">$Data->{params}{strResponseText}</td>
			</tr>	

			<tr>
				<td class="label"><label for="l_strReceiptRef">Receipt Reference</label>:</td>
				<td class="value">$Data->{params}{strReceiptRef}</td>
			</tr>			-->

			<!--<tr>
				<td class="label"><label for="l_intPartialPayment">Partial Payment</label>:</td>
				<td class="value">].($Data->{params}{intPartialPayment} ? 'Yes' : 'No').qq[</td>
			</tr>	-->
			<tr>

				<td class="label"><label for="l_strComments">].$lang->txt('Comments').qq[</label>:</td>
				<td class="value">$Data->{params}{strComments}</td>
			</tr>
		    </tbody>	
		</table>
		<br>

	];	

	$body.=$transHTML;

	$body.=qq[
		<div style="clear:both;"></div>
		  <br><div class="pageHeading">].$lang->txt('Potential Problems').qq[</div>
		     <p class="error">$warnings</p>
		 ] if $warnings;

	my ($link, $mode, $personID, $paymentID, $client, $dtStart_paid, $dtEnd_paid) = generateTXNListLink('P_TXNLoglist', $Data, $clientValues_ref);


	$body.=qq[	<br>
			<form action="$Data->{'target'}" method="POST">
				<input type="hidden" name="a" value="P_TXNLogstep3">
				<input type="hidden" name="client" value="$client">
				<input type="hidden" name="mode" value="$mode"><input type="hidden" name="personID" value="$personID"><input type="hidden" name="client" value="$client"><input type="hidden" name="paymentID" value="$paymentID"><input type="hidden" name="transLogID" value="$transLogID">
				<input type="submit" name="subbut" value=" ]. $lang->txt('Confirm Payment') . qq[ " class="HF_submit button proceed-button">
			</form>
			<div style="clear:both;"></div>
			<form action="$Data->{'target'}" method="POST">
				<input type="hidden" name="a" value="P_TXNLoglist">
				<input type="hidden" name="client" value="$client">
				<input type="hidden" name="mode" value="$mode"><input type="hidden" name="personID" value="$personID"><input type="hidden" name="client" value="$client"><input type="hidden" name="paymentID" value="$paymentID"><input type="hidden" name="dt_start_paid" value="$dtStart_paid"><input type="hidden" name="dt_end_paid" value="$dtEnd_paid">
				<input type="submit" name="subbut" value=" ]. $lang->txt('Cancel Payment') . qq[ " class="HF_submit button cancel-button">
			</form>
		 ]; 

	return ($body, $header);
}

sub step3 {

	my ($Data, $db, $clientValues_ref) = @_;

    my $lang = $Data->{'lang'};
	my $transLogID=$Data->{'params'}{'transLogID'};
	return ($lang->txt('Invalid Transaction'),'') if !$transLogID;

	deQuote($db, \$transLogID);

    my $st = <<"EOS";
SELECT dtLog
FROM   tblTransLog
WHERE  intLogID = ?
AND    intRealmID = ?
AND    intStatus = ?
LIMIT 1
EOS
    my $query = $db->prepare($st);
    $query->execute($transLogID, $Data->{Realm}, $Defs::TXNLOG_PENDING);

    my($dtLog) = $query->fetchrow_array;

    if ($dtLog) {
        deQuote($db, \$dtLog);
    }
    else {
        $dtLog = 'NOW()'
    }

	$st=qq[
			UPDATE tblTransLog SET intStatus=$Defs::TXNLOG_SUCCESS WHERE intLogID=$transLogID and intRealmID=$Data->{Realm}
			AND intStatus = $Defs::TXNLOG_PENDING 
	];
	$db->do($st);

	$st = qq[UPDATE tblTransactions as T INNER JOIN tblTXNLogs as TXNLog ON (T.intTransactionID = TXNLog.intTXNID) SET T.dtPaid=$dtLog, T.intStatus=$Defs::TXN_PAID, T.intTransLogID=$transLogID WHERE intTLogID = $transLogID and T.intRealmID=$Data->{Realm} AND T.intStatus = $Defs::TXN_UNPAID];
	$db->do($st);

	Products::product_apply_transaction($Data,$transLogID);
	my $cl=setClient($Data->{'clientValues'}) || '';
	my $receiptLink = "printreceipt.cgi?client=$cl&ids=$transLogID";

  auditLog($transLogID, $Data, 'Confirmed Payment', 'Transactions');

	return (qq[
		<div class="OKmsg">].$lang->txt('Your payment has been Confirmed') .qq[</div>
		<br>
		<br><a href="$receiptLink" target="receipt">]. $lang->txt('Print Receipt') .qq[</a><br>
	<br><a href="$Data->{'target'}?client=$cl&amp;a=P_TXN_LIST">]. $lang->txt('Return to Transactions') .qq[</a><br>

	], '');		
}

sub getTransList {
	my ($Data, $db, $entityID, $personID, $whereClause, $tempClientValues_ref, $hide_list_payments_link, $displayonly) = @_;
	$displayonly ||= 0;
    my $hidePayment=1;
    $hidePayment=0 if ($personID and $Data->{'clientValues'}{'authLevel'} >= $Defs::LEVEL_CLUB);
    $hidePayment=0 if ($entityID and ! $personID and $Data->{'clientValues'}{'authLevel'} >= $Defs::LEVEL_CLUB);

    my $realmID = $Data->{'Realm'};
	my $orderBy = $Data->{'SystemConfig'}{'TransListOrderBy'} || '';
    my $entityWHERE = '';
    if ($entityID)   {
        $entityWHERE = qq[ 
            AND (
                tl.intLogID IS NULL 
                OR tl.intEntityPaymentID IN (0, $entityID)
            ) 
        ];
    }
	my $exposeNationalProducts = '';

	my $prodSellLevel = qq[ 
    AND ( 
      t.intStatus <> 0 
      OR (
        t.intStatus = 0 
        AND P.intMinSellLevel <= $Data->{'clientValues'}{'authLevel'} 
        OR P.intMinSellLevel=0
      )
    )
  ];

    $prodSellLevel = '' if $Data->{'SystemConfig'}{'IgnoreMinSellLevelForTransList'};

	my $statement = qq[
    SELECT 
      t.intTransactionID, 
      t.intStatus, 
      t.curAmount, 
      t.intTransLogID, 
      t.intID, 
      intQty, 
      t.dtStart AS dtStart_RAW, 
      DATE_FORMAT(t.dtStart, '%d/%m/%Y') AS dtStart, 
      t.dtEnd as dtEnd_RAW, 
      DATE_FORMAT( t.dtEnd, '%d/%m/%Y') AS dtEnd, 
      IF(strGroup <> '', 
      CONCAT(strGroup,'-',P.strName), P.strName) as strName, 
      t.strNotes
    FROM 
      tblTransactions as t
      INNER JOIN tblProducts as P ON (P.intProductID = t.intProductID)
      LEFT JOIN tblTransLog as tl ON (t.intTransLogID = tl.intLogID)
    WHERE
      t.intRealmID = $Data->{Realm}
			AND P.intProductType<>2
	    $prodSellLevel
      $whereClause
	  GROUP BY 
		  t.intTransactionID
		$orderBy
  ];
    $statement =~ s/AND  AND/AND/g;
    my $query = $db->prepare($statement);
    $query->execute or print STDERR $statement;
    my $client = setClient($Data->{clientValues});
    my @Columns = ();
    push (@Columns, {Name => '', Field => 'SelectLink', type => 'Selector', hide => $displayonly});
    push (@Columns, {Name => 'Invoice Number', Field => 'intTransactionID', width => 20});
    push (@Columns, {Name => 'Item Name', Field => 'strName'});
    push (@Columns, {Name => 'Quantity', Field => 'intQty', width => 15});
    push (@Columns, {Name => 'Amount', Field => 'curAmount', width =>20});
    push (@Columns, {Name => 'Start', Field => 'dtStart', width => 20});
    push (@Columns, {Name => 'Start_RAW', Field => 'dtStart_RAW', hide=>1});
    push (@Columns, {Name => 'End', Field => 'dtEnd', width => 20});
    push (@Columns, {Name => 'End_RAW', Field => 'dtEnd_RAW', hide=>1});
    push (@Columns, {Name => 'Status', Field => 'StatusTextLang', width => 20});
    push (@Columns, {Name => 'Status_raw', Field => 'intStatus', hide => 1});
    push (@Columns, {Name => '&nbsp;', Field => 'stuff', type => 'HTML', hide => $displayonly});
    push (@Columns, {Name => 'Pay', Field => 'manual_payment', type => 'HTML', width => 10, hide => $hidePayment});
    push (@Columns, {Name => 'Notes', Field => 'strNotes',  width => 50, hide => $displayonly});
    push (@Columns, {Name => 'View Receipt', Field => 'strReceipt', type=>"HTML", width => 50, hide => $displayonly});

    my @headers = ();
    foreach my $header (@Columns) {
        my $sorttype = ($header->{Field} =~ m/int/) ? 'number' : 'text';
        my $width = $header->{width} || "200";
        my %href = (
            name => $header->{Name},
            field => $header->{Field},
            sorttype => $sorttype,
            hide => $header->{hide},
            type => $header->{type},
            width => $width
        );
        push @headers, \%href;
    }
    my @rowdata = ();
    my @transCurrency = ();
    my @transAmount = ();
    $query->execute;
    my $i = 0;
    while (my $row = $query->fetchrow_hashref()) {
        push @transCurrency, $row->{intCurrencyID};
        push @transAmount, $row->{curAmount};
        my $row_data = {};
        $row_data->{id} = $i;
        foreach my $header (@Columns) {
            if ($header->{Field} eq 'StatusTextLang') {
        my $status = $row->{intStatus};
        $row->{StatusText} = 'Unpaid' if ($status == 0);
        $row->{StatusText} = 'Paid' if ($status == 1);
        $row->{StatusText} = 'Cancelled' if ($status == 2);

        $row->{StatusTextLang} = $Data->{'lang'}->txt('Unpaid') if ($status == 0);
        $row->{StatusTextLang} = $Data->{'lang'}->txt('Paid') if ($status == 1);
        $row->{StatusTextLang} = $Data->{'lang'}->txt('Cancelled') if ($status == 2);
      }
      $row_data->{$header->{Field}} = $row->{$header->{Field}};
    }
    $row_data->{SelectLink} = qq[main.cgi?client=$client&a=P_TXN_EDIT&personID=$row->{intID}&id=$row->{intTransLogID}&tID=$row->{intTransactionID}];
    if ($row->{StatusText} eq 'Paid') {
      $row_data->{stuff} = qq[<a href="main.cgi?a=P_TXNLog_payVIEW&client=$client&tlID=$row->{intTransLogID}">].$Data->{'lang'}->txt('View Payment Record').qq[</a>];
      $row_data->{strReceipt} = qq[<a href="printreceipt.cgi?client=$client&ids=$row->{intTransLogID}"  target="receipt">].$Data->{'lang'}->txt('View Receipt').qq[</a>];
      $row_data->{manual_payment} = '';
    }
    elsif ($row->{StatusText} eq 'Unpaid') {
      $row_data->{strReceipt} = qq[];

      my $allowUD = 1;
	  $allowUD = 0 if $Data->{'clientValues'}{'authLevel'} == $Defs::LEVEL_CLUB;
      $allowUD = 0 if $Data->{'SystemConfig'}{'DontAllowUnpaidDelete'}; 

      $row_data->{stuff} = ($allowUD) 
          ? qq[<a href="main.cgi?a=P_TXN_DEL&client=$client&tID=$row->{intTransactionID}">].$Data->{'lang'}->txt('Delete Transaction').qq[</a>]
          : '';
      $row_data->{manual_payment} = qq[<input type="checkbox" name="act_$row->{intTransactionID}" value="" class = "paytxn_chk">];
    }
    else {
      $row_data->{stuff} = '';
      $row_data->{manual_payment} = '';
    }
    push @rowdata, $row_data if $row_data;
    $i++;
  }
  my $filterfields = [
    {
      field => 'intStatus',
      elementID => 'dd_intStatus',
      allvalue => '3',
    },
  ];
  my $grid = showGrid(
    Data => $Data,
    columns => \@headers,
    rowdata => \@rowdata,
    gridid => 'grid',
    width => '99%',
    height => '',
    filters => $displayonly ? undef : $filterfields,
  );
	my $filterHTML = qq[
			<div class = "showrecoptions">
				Filter by:
				<select name="dd_intStatus" id="dd_intStatus">
					<option value="3">].$Data->{'lang'}->txt('All') .qq[</option>
					<option value="1">].$Data->{'lang'}->txt('Paid') .qq[</option>
					<option value="0">].$Data->{'lang'}->txt('Unpaid') .qq[</option>
					<option value="2">].$Data->{'lang'}->txt('Cancelled') .qq[</option>
				</select>
			</div>
	];
	$filterHTML = '' if $displayonly;
  $grid = qq[
		<div class = "grid-filter-wrap">
			$filterHTML
			$grid
		</div>
  ];
  my $cl=setClient($Data->{'clientValues'}) || '';
        my $payment_records_link=qq[<br><br><a href="$Data->{'target'}?client=$cl&amp;a=P_TXNLog_payLIST">].$Data->{'lang'}->txt('List All Payment Records')."</a>" ;
  $payment_records_link = '' if ($hide_list_payments_link);
  $grid = $grid ? qq[$grid $payment_records_link]  : qq[<p class="error">].$Data->{'lang'}->txt('No records were found with this filter').qq[</p>$payment_records_link]; 


  return ($grid, $i, \@transCurrency, \@transAmount);
}

sub setupStandardList {
  my ($Data) = @_;
	my $txnStatus = $Data->{'ViewTXNStatus'} || $Defs::TXN_UNPAID; 
  push @{$Data->{'listFields'}}, 'txnID';
  push @{$Data->{'listFields'}}, 'product_link';
  push @{$Data->{'listFields'}}, 'qty';
  push @{$Data->{'listFields'}}, 'AssocName';
  push @{$Data->{'listFields'}}, 'curAmount';
  push @{$Data->{'listFields'}}, 'curAmountDue';
  push @{$Data->{'listFields'}}, 'dtStart';
  push @{$Data->{'listFields'}}, 'dtEnd';
  push @{$Data->{'listFields'}}, 'checkbox' if $txnStatus == $Defs::TXN_UNPAID;
  push @{$Data->{'listFields'}}, 'delete_record' if $txnStatus == $Defs::TXN_UNPAID;
  push @{$Data->{'listFields'}}, 'edit_payment' if $txnStatus == $Defs::TXN_UNPAID;
  push @{$Data->{'listFields'}}, 'filter_by_payment' if $txnStatus == $Defs::TXN_PAID;
  push @{$Data->{'listFields'}}, 'strNotes';
  return $Data;
}

sub setupStep2List {
   
   my ($Data) = @_;
  
   push @{$Data->{'listFields'}}, 'txnID';
   push @{$Data->{'listFields'}}, 'product';
   push @{$Data->{'listFields'}}, 'qty';
   push @{$Data->{'listFields'}}, 'AssocName';
   push @{$Data->{'listFields'}}, 'curAmount';
   push @{$Data->{'listFields'}}, 'curAmountDue';

   return $Data;
}


sub generateTXNListLink {
	my ($action, $Data, $tempClientValues_ref) = @_;
	$action ||= '';
	my $client = setClient($tempClientValues_ref);
	my $dtStart_paid = $Data->{params}{dt_start_paid} || 0;
	my $dtEnd_paid = $Data->{params}{dt_end_paid} || 0;
	my $mode = $Data->{params}{mode} || 'u';
	my $tableID = 0;
	if ($Data->{'clientValues'}{'currentLevel'} == $Defs::LEVEL_PERSON)	{
		$tableID = $tempClientValues_ref->{personID} || $Data->{params}{personID} ||  0;
	}
	if ($Data->{'clientValues'}{'currentLevel'} == $Defs::LEVEL_CLUB)	{
		$tableID = $tempClientValues_ref->{clubID} || $Data->{params}{clubID} ||  0;
	}
	my $paymentID = $Data->{params}{paymentID} || 0;
	$tableID = 0 if $tableID == $Defs::INVALID_ID;
	my $link = "$Data->{target}?client=$client";
	$link .= "&amp;a=$action" if $action;
	$link .= "&amp;personID=$tableID" if $tableID and $Data->{'clientValues'}{'currentLevel'} == $Defs::LEVEL_PERSON;
	$link .= "&amp;clubID=$tableID" if $tableID and $Data->{'clientValues'}{'currentLevel'} == $Defs::LEVEL_CLUB;
	$link .= "&amp;dt_start_paid=$dtStart_paid" if $dtStart_paid;
	$link .= "&amp;dt_end_paid=$dtEnd_paid" if $dtEnd_paid;
	$link .= "&amp;paymentID=$paymentID" if $paymentID;
	return ($link, $mode, $tableID, $paymentID, $client, $dtStart_paid, $dtEnd_paid);
}

#sub listTransactions_where {
#    my ($whereClause, $txnStatus, $safeTableID, $safePaymentID, $paymentID, $Data, $db) = @_;
#
#    $whereClause .= qq[ AND t.intID=$safeTableID and t.intTableType=$Defs::LEVEL_PERSON] if $Data->{'clientValues'}{'currentLevel'} == $Defs::LEVEL_PERSON;
#    $whereClause .= qq[ AND t.intID=$safeTableID and t.intTableType=$Defs::LEVEL_CLUB]   if $Data->{'clientValues'}{'currentLevel'} == $Defs::LEVEL_CLUB;
#    $whereClause .= qq[ AND t1.intTLogID= $safePaymentID ] if $paymentID;
#
#    my $entityID = getLastEntityID($Data->{'clientValues'}) || 0; #
#
#    $whereClause .= qq[ AND intTXNEntityID IN (0, $entityID)] if $entityID;
#    $whereClause .= qq[ AND P.intProductType NOT IN ($Defs::PROD_TYPE_MINFEE) ] if $txnStatus != $Defs::TXN_PAID;
#
#    return $whereClause;
#}

sub listTransactions {
    my ($Data, $db, $entityID, $personID, $tempClientValues_ref, $action, $resultMessage) = @_;
warn("ENTITY: $entityID | $personID");
    my ($body, $paidLink, $unpaidLink, $cancelledLink, $query) = ('', '', '', '', '');
    my $lang = $Data->{'lang'};
    my $txnStatus = $Data->{'ViewTXNStatus'} || $Defs::TXN_UNPAID;
    my ($link, $mode, $TableID, $paymentID, $client, $dtStart_paid, $dtEnd_paid) = generateTXNListLink('', $Data, $tempClientValues_ref);
    my ($safeTableID, $safePaymentID) = ($TableID, $paymentID);

    deQuote($db, \$safeTableID);

    my $tempBody = '';
    my $transCount = 0;

    my $whereClause = '';
    $whereClause .= qq[ AND t.intID=$personID and t.intTableType=$Defs::LEVEL_PERSON] if ($personID and $Data->{'clientValues'}{'currentLevel'} == $Defs::LEVEL_PERSON);
warn("CL: " . $Data->{'clientValues'}{'currentLevel'});
    $whereClause .= qq[ AND t.intID=$entityID and t.intTableType=$Defs::LEVEL_CLUB] if $Data->{'clientValues'}{'currentLevel'} == $Defs::LEVEL_CLUB;
    $whereClause .= qq[ AND t1.intTLogID= $safePaymentID ] if $paymentID;

    $whereClause .= qq[ AND intTXNEntityID IN (0, $entityID)] if $entityID;
    $whereClause .= qq[ AND P.intProductType NOT IN ($Defs::PROD_TYPE_MINFEE) ] if $txnStatus != $Defs::TXN_PAID;


	($tempBody, $transCount) = getTransList($Data, $db, $entityID, $personID, $whereClause, $tempClientValues_ref);

	$body .= $tempBody;

    #GET FILTER TEXT
    my $filterCriterion = '';

    if ($paymentID) {
        my $statement=qq[
            SELECT 
                intAmount, 
                intPaymentType, 
                strCurrencyName, 
                DATE_FORMAT(dtLog,'%d/%m/%Y') as dtLog 
            FROM 
                tblTransLog t 
                INNER JOIN tblCurrencies c ON (t.intCurrencyID=c.intCurrencyID)
            WHERE 
                t.intRealmID=$Data->{Realm} 
                AND intLogID=$safePaymentID 
        ];
        $query = $db->prepare($statement);
        $query->execute;
        my $row = $query->fetchrow_hashref();
    }

    $filterCriterion = $filterCriterion ? substr($filterCriterion, 0, length($filterCriterion)-2) : '{show all}';

    my $checked_paid      = $txnStatus == $Defs::TXN_PAID      ? 'SELECTED' : '' ;
    my $checked_unpaid    = $txnStatus == $Defs::TXN_UNPAID    ? 'SELECTED' : '' ;
    my $checked_cancelled = $txnStatus == $Defs::TXN_CANCELLED ? 'SELECTED' : '' ;
    my $checked_showall   = $txnStatus == $Defs::TXN_SHOWALL   ? 'SELECTED' : '' ;

    my $line = '';
    my $addLink = qq[
        <div class="changeoptions"><span class="button-small generic-button"><a href="$Data->{'target'}?client=$client&amp;a=P_TXN_ADD">Add Transaction</a></span></div>
    ];
    $addLink = '' if $Data->{'ReadOnlyLogin'};
    $addLink = '' if ($Data->{'clientValues'}{'currentLevel'} == $Data->{'clientValues'}{'authLevel'});

    my $entityNamePlural = 'Transactions';
    $entityNamePlural= ($Data->{'SystemConfig'}{'txns_link_name'}) ? $Data->{'SystemConfig'}{'txns_link_name'} : $entityNamePlural;

	my $header=qq[$addLink$entityNamePlural];


    if ($transCount>0) {
	    my ($Second, $Minute, $Hour, $Day, $Month, $Year, $WeekDay, $DayOfYear, $IsDST) = localtime(time);
        $Year+=1900;
        $Month++;
        my $currentDate="$Day/$Month/$Year";
	    $currentDate = $Data->{params}{dtLog} if $Data->{params}{dtLog};
	    $resultMessage = qq[<p class="error">$resultMessage</p>] if $resultMessage;
	    my $paymentType = $Data->{params}{paymentType} || 0;
        my (undef, $paymentTypes) = getPaymentSettings($Data, $paymentType, 0, $tempClientValues_ref);
    
        my $CC_body = qq[<div id = "payment_cc" style= "display:none;"><br>];
        my $gatewayCount = 0;
        foreach my $gateway (@{$paymentTypes})  {
            $gatewayCount++;
            my $id = $gateway->{'intPaymentConfigID'};
            my $pType = $gateway->{'paymentType'};
            my $name = $gateway->{'gatewayName'};
            $CC_body .= qq[
				    <input type="submit" name="cc_submit[$gatewayCount]" value="]. $lang->txt("Pay via").qq[ $name" class = "button proceed-button"><br><br>
                    <input type="hidden" value="$pType" name="pt_submit[$gatewayCount]">
            ];
        }
        $CC_body .= qq[
                    <input type="hidden" value="$gatewayCount" name="gatewayCount">
				    <div style= "clear:both;"></div>
			    </div>
	    ];          
	  $CC_body = '' if ! $gatewayCount;
	  $CC_body = '' if ! $Data->{'SystemConfig'}{'AllowTXNs_CCs'};
	  for my $i (qw(intAmount strBank strBSB strAccountNum strAccountName strResponseCode strResponseText strReceiptRef strComments intPartialPayment))	{
		  $Data->{params}{$i}='' if !defined $Data->{params}{$i};
	  }
	  if ($Data->{'clientValues'}{'authLevel'} >= $Defs::LEVEL_CLUB) { 
		  my $allowManualPayments = 1;
		  $allowManualPayments = 0 if ($Data->{'clientValues'}{'authLevel'} == $Defs::LEVEL_CLUB and ! allowedAction($Data, 'm_mp'));
		  $allowManualPayments = 0 if ($Data->{'clientValues'}{'authLevel'} == $Defs::LEVEL_CLUB 
			  and $Data->{'clientValues'}{'currentLevel'}  == $Defs::LEVEL_PERSON 
			  and ! allowedAction($Data, 'm_mp')
		  );
		  $allowManualPayments = 0 if ($Data->{'clientValues'}{'authLevel'} == $Defs::LEVEL_CLUB 
			  and $Data->{'clientValues'}{'currentLevel'}  == $Defs::LEVEL_CLUB 
			  and ! allowedAction($Data, 't_tp')
		  );
      $allowManualPayments = 0 if $Data->{'ReadOnlyLogin'};

      my $allowMP = 1;
      $allowMP = 0 if !$allowManualPayments;
      $allowMP = 0 if !$personID and $entityID;
      $allowMP = 0 if $Data->{'SystemConfig'}{'DontAllowManualPayments'};
      $allowMP = 0 if $Data->{'SystemConfig'}{'AssocConfig'}{'DontAllowManualPayments'};
		  
		$body=qq[
			<form action="$Data->{target}" name="n_form" method="POST">
            <input type="hidden" name="a" value="P_TXNLogstep2">
            <input type="hidden" name="client" value="$client">
	
		$body
		  <br><br>
		  ];

		  $body .= qq[
			  $CC_body
		  ];
		 my $orstring = '';
		 $orstring = qq[&nbsp; <b>].$lang->txt('OR').qq[</b> &nbsp;] if $CC_body and $allowMP;
		 if($paymentType==0){ $paymentType='';}
        $body .= qq[
            <div id="payment_manual" style= "display:none;">
                $orstring
                <script type="text/javascript">
                    jQuery(function() {
                        jQuery(".paytxn_chk").live('change',function() {
                            jQuery('#payment_manual').show();
                            jQuery('#payment_cc').show();
                        });
                        jQuery("#btn-manualpay").click(function() {
                                if(jQuery('#paymentType').val() == '') {
                                    alert("You Must Provide A Payment Type");
                                    return false;
                                }
                        });
                    });
                </script>			  
        ];

        $body .= qq[
			  <div class="sectionheader">].$lang->txt('Manual Payment').qq[</div>
				  $resultMessage
					<table cellpadding="2" cellspacing="0" border="0">
					<tbody id="secmain2" >	
					<tr>
						<td class="label"><label for="l_intAmount">].$lang->txt('Amount (ddd.cc)').qq[</label>:</td>
						<td class="value">
						<input type="text" name="intAmount" value="$Data->{params}{intAmount}" id="l_intAmount" size="10"  /> </td>
					</tr>
					<tr>
						<td class="label"><label for="l_dtLog">].$lang->txt('Date Paid').qq[</label>:</td>
						<td class="value"><input type="text" name="dtLog" value="$currentDate" id="l_dtLog" size="10" maxlength="10" /> <span class="HTdateformat">dd/mm/yyyy</span> </td>
					</tr>
					<tr>
						<td class="label"><label for="l_intPaymentType">].$lang->txt('Payment Type').qq[</label>:</td>
						<td class="value">].drop_down('paymentType',\%Defs::manualPaymentTypes, undef, $paymentType, 1, 0,'','').qq[</td>
					</tr>
					<!--<tr>
						<td class="label"><label for="l_strBank">Bank</label>:</td>
						<td class="value"><input type="text" name="strBank" value="$Data->{params}{strBank}" id="l_strBank"   /></td>
					</tr>
					<tr>
						<td class="label"><label for="l_strBSB">BSB</label>:</td>
						<td class="value"><input type="text" name="strBSB" value="$Data->{params}{strBSB}" id="l_strBSB"   /></td>
					</tr>
					<tr>
						<td class="label"><label for="l_strAccountName">Account Name</label>:</td>
						<td class="value"><input type="text" name="strAccountName" value="$Data->{params}{strAccountName}" id="l_strAccountName"   /></td>
					</tr>
					<tr>
						<td class="label"><label for="l_strAccountNum">Account Number</label>:</td>
						<td class="value"><input type="text" name="strAccountNum" value="$Data->{params}{strAccountNum}" id="l_strAccountNum"   /> </td>
					</tr>
					<tr>
						<td class="label"><label for="l_strResponseCode">Response Code</label>:</td>
						<td class="value"><input type="text" name="strResponseCode" value="$Data->{params}{strResponseCode}" id="l_strResponseCode"   /> </td>
					</tr>
					<tr>
						<td class="label"><label for="l_strResponseText">Response Text</label>:</td>
						<td class="value"><input type="text" name="strResponseText" value="$Data->{params}{strResponseText}" id="l_strResponseText"   /> </td>
					</tr>
					<tr>
						<td class="label"><label for="l_strReceiptRef">Receipt Reference</label>:</td>
						<td class="value"><input type="text" name="strReceiptRef" value="$Data->{params}{strReceiptRef}" id="l_strReceiptRef"   /> </td>
					</tr>	-->
					<!-- <tr>
						<td class="label"><label for="l_intPartialPayment">Partial Payment</label>:</td>
						<td class="value"><input type="checkbox" name="intPartialPayment" value="1" id="l_intPartialPayment" ].($Data->{params}{intPartialPayment} ? 'checked' : '').qq[  /> </td>
					</tr>	-->
					<tr>

						<td class="label"><label for="l_strComments">].$lang->txt('Comments').qq[</label>:</td>
						<td class="value"><textarea name="strComments" id="l_strComments"  rows = "5"   cols = "45"  >$Data->{params}{strComments}</textarea> </td>
					</tr>
				    </tbody>	
				</table>
			
						<div class="HTbuttons"><input type="submit" name="subbut" value="Submit Manual Payment" class="HF_submit button generic-button" id = "btn-manualpay"></div>

						<input type="hidden" name="personID" value="$TableID"><input type="hidden" name="paymentID" value="$paymentID"><input type="hidden" name="dt_start_paid" value="$dtStart_paid"><input type="hidden" name="dt_end_paid" value="$dtEnd_paid">
					</form> 
				</div>
			] if $allowMP;
	  }
  	else	{
		  $body = qq[
			 <form action="$Data->{target}" name="n_form" method="POST">
        		 $body
			<input type="hidden" name="a" value="P_TXNLogstep2">
            		 <input type="hidden" name="client" value="$client">
			$CC_body
			</form>];

          if ($CC_body) {
              if ($Data->{'clientValues'}{'authLevel'} == $Defs::LEVEL_CLUB) { 
                  if ($Data->{'clientValues'}{'currentLevel'} == $Defs::LEVEL_CLUB) { 
                      $body .= qq[
                          <script type="text/javascript">
                              jQuery(".paytxn_chk").live('change',function() {
                                  jQuery('#payment_cc').show();
                              });
                          </script>			  
                      ];
                  }
              }
          }

      }
  } 
	$body = qq[<div style="width:99%;">$line</div>$body];
  return ($body, $header);
}


sub afterAdd {

   my ($id, undef, $Data, $tempClientValues_ref, $body_ref) = @_;

   my $tableType = $Defs::TABLE_TYPE_MEMBERMODULE;

   my $extraWhereClause = ($tempClientValues_ref->{authLevel} == $Defs::LEVEL_EDU_DA) ? qq[ AND m.intDeliveryAgentID= $tempClientValues_ref->{daID}] : '';

	my $st=qq[
                UPDATE tblTransactions t 
		INNER JOIN tblEDUMemberModule mm ON (mm.intMemberModuleID=t.intID)
		INNER JOIN tblEDUModule m ON (mm.intModuleID=m.intModuleID)

		SET intDelivered=1, intStatus=$Defs::TXN_PAID, dtPaid=now(), intPaymentType=$Data->{params}{d_intPaymentType}, intTransLogID=$id
                

		WHERE t.intTransactionID=?
		        AND t.intTableType = $tableType
			AND m.intEduID = $tempClientValues_ref->{eduID}
			$extraWhereClause
        ];
my $q=$Data->{'db'}->prepare($st);

  my $tempBody='';

  my $cgi=new CGI;
  my %params=$cgi->Vars();

        
        foreach my $k (keys %{$Data->{params}}) {
		my $id=$k;
                $id=~s/.*_//;
                next  if $id=~/[^\d]/;

		$tempBody = '<style type="text/css">'  if !$tempBody;
		
		$tempBody.=qq[ td#row$id {display:none} ];

                #my $oldval=$params{$k} || '';
                #$oldval='' if $oldval eq 'N';

                $q->execute($id);
	}
  $tempBody.='</style>' if $tempBody;
	
  return (1, $tempBody);
}





sub loadDetails {
  my($db, $id, $tempClientValues_ref) = @_;
  return {} if !$id;


  deQuote($db, \$id);

  my $extraWhereClause = ($tempClientValues_ref->{authLevel}==$Defs::LEVEL_EDU_DA) ? qq[AND m.intDeliveryAgentID=$tempClientValues_ref->{daID}] : '';

  my $statement=qq[
	SELECT tl.intLogID, DATE_FORMAT(tl.dtLog, '%d/%m/%Y') as dtLog, tl.intAmount, tl.strTXN, tl.strResponseCode, tl.strResponseText, tl.strComments, tl.intPaymentType, tl.strBSB, tl.strBank, tl.strAccountName, tl.strAccountNum, tl.intRealmID, tl.intCurrencyID, tl.strReceiptRef, tl.intPartialPayment 
	FROM tblTransLog tl	    
		LEFT JOIN tblTransactions t ON (t.intTransLogID=tl.intLogID)
		LEFT JOIN tblEDUMemberModule mm ON (mm.intMemberModuleID=t.intID and t.intTableType=$Defs::TABLE_TYPE_MEMBERMODULE)
		LEFT JOIN tblEDUModule m ON (m.intModuleID=mm.intModuleID)
	WHERE tl.intLogID=$id 
		$extraWhereClause
  ];
  my $query = $db->prepare($statement);
  $query->execute;
        my $field=$query->fetchrow_hashref();
  $query->finish;
  foreach my $key (keys %{$field})  { if(!defined $field->{$key}) {$field->{$key}='';} }
  return $field;
}


sub entityDetails        {
    my ($action, $Data, $tempClientValues_ref, $db)=@_;

	my $id=$Data->{'params'}{'id'};
	deQuote($db, \$id);

	my ($option, $header)=('display', 'Payment');
        ($option, $header)=('edit',"Edit Payment") if $action =~/edit/;
        #($option, $header)=('add',"Add Payment") if ($action =~/add/);
	

#Load currencies for dropdown list
my $currencySQL = qq[SELECT intCurrencyID, strCurrencyName from tblCurrencies WHERE intRealmID = $Data->{Realm}];

	my $query = $db->prepare($currencySQL);
	$query->execute;
	my %currencies;
	while (my $row = $query->fetchrow_hashref()) {$currencies{$row->{intCurrencyID}}=$row->{strCurrencyName}};


	
        my $field= ($option=~/add/) ? () : (loadDetails($db, $id, $tempClientValues_ref) || ());

	my (undef, $mode, $personID, $paymentID, $client, $dtStart_paid, $dtEnd_paid) = generateTXNListLink('P_TXNLoglist', $Data, $tempClientValues_ref);
	

my %FieldDefinitions=(
                fields=>        {
                        intPaymentID => {
                                label => 'Payment Number',
                                value => $field->{intLogID},
				readonly=>1,
                        },
			intAmount => {
                                label => 'Amount (ddd.cc)',
				type => 'text',
				validate => 'FLOAT',
                                value => $field->{intAmount},
				maxlength=>'19',
                        },
			dtLog => {
                                value => $field->{dtLog},
                                label => 'Date Paid',
                                type=>'date',
                                validate=>'DATE',
                                format=> 'dd/mm/yyyy',

                        },
			intCurrencyID => {
                                label => 'Currency',
                                value => $field->{intCurrencyID},
                                type  => 'lookup',
                                options => \%currencies,
				firstoption => ['','Select Currency'],
                        },
			intPaymentType => {
                                label => 'Payment Type',
                                value => $field->{intPaymentType} || $Defs::PAYMENT_NONE,
                                type  => 'lookup',
                                options => \%Defs::paymentTypes,
                        },
			strBank => {
                                label => 'Bank',
				type => 'text',
                                value => $field->{strBank},
				maxlength=>'100',
                        },
			strBSB => {
                                label => 'BSB',
				type => 'text',
                                value => $field->{strBSB},
				maxlength=>'50',
                        },
			strAccountName => {
                                label => 'Account Name',
				type => 'text',
                                value => $field->{strAccountName},
				maxlength=>'100',
                        },
			strAccountNum => {
                                label => 'Account Number',
				type => 'text',
                                value => $field->{strAccountNum} ,
				maxlength=>'100',
                        },
			strResponseCode => {
                                label => 'Response Code',
				type => 'text',
                                value => $field->{strResponseCode},
				maxlength=>'10',
                        },
			strResponseText => {
                                label => 'Response Text',
				type => 'text',
                                value => $field->{strResponseText},
				maxlength=>'100',
                        },
			strReceiptRef => {
                                label => 'Receipt Reference',
				type => 'text',
                                value => $field->{strReceiptRef},
				maxlength=>'100',
                        },
			intPartialPayment => {
                                label => 'Partial Payment',
				type => 'checkbox',
                                value => $field->{intPartialPayment},
                        },
			strComments => {
                                label => 'Comments',
				type => 'textarea',
                                value => $field->{strComments},
				cols => '45',
				rows => '5',
                        },	
		},
                order => [qw(intPaymentID intAmount dtLog intCurrencyID intPaymentType strBank strBSB strAccountName strAccountNum strResponseCode strResponseText strReceiptRef strComments)],
                options => {
                        labelsuffix => ':',
                        hideblank => 1,
                        target => $Data->{'target'},
                        formname => 'n_form',
			stopAfterAction=>1,
      			submitlabel => "Update",
      			introtext => 'auto',
                        NoHTML => 1,
      updateSQL => qq[
	UPDATE tblTransLog
	   SET --VAL--
	WHERE intLogID=$id
	],
      addSQL => qq[
        /*INSERT INTO tblTransLog
        (intRealmID, dtLog, --FIELDS--)
           VALUES ($Data->{'Realm'}, now(), --VAL-- )*/
        ],
	afteraddFunction => \&afterAdd,
        afteraddParams => [ $Data, $tempClientValues_ref],
        afterupdateFunction => \&afterUpdate,
        afterupdateParams => [$id, $Data, 'edit', $tempClientValues_ref],

      LocaleMakeText => $Data->{'lang'},
                }, 
      carryfields =>  {
	a => $action,
        client =>$client,
	id=>$id,
	dt_start_paid=>$dtStart_paid,
	dt_end_paid=>$dtEnd_paid,
        mode=>$mode,
	personID=>$personID,
	payment=>$paymentID,
      }, 
   );


  my ($body, undef)=handleHTMLForm(\%FieldDefinitions, undef, $option, '',$db);

  $body.=qq[
		<form action="$Data->{target}" method="POST">
			<input type="submit" style="margin-left:120px" name="subbutcancel" value=" *Cancel Payment* " class="HF_submit" onclick="return confirm('This will remove this payment and set all linked transactions to unpaid. Continue?')">
			<input type="hidden" name="a" value="P_TXNLogcancel">
			<input type="hidden" name="client" value="$client">
			<input type="hidden" name="id" value="$id">
			<input type="hidden" name="dt_start_paid" value="$dtStart_paid">
			<input type="hidden" name="dt_end_paid" value="$dtEnd_paid">
			<input type="hidden" name="mode" value="$mode">
			<input type="hidden" name="personID" value="$personID">
			<input type="hidden" name="payment" value="$paymentID">
		</form>
	    ] if $body=~/subbut/;

  return ($body, $header);
}


sub afterUpdate {

my (undef, undef, $id, $Data, $option, $tempClientValues_ref) = @_;

	my ($linklist, $mode, $personID, $paymentID, $client, $dtStart_paid, $dtEnd_paid) = generateTXNListLink('P_TXNLoglist', $Data, $tempClientValues_ref);
	my $linkedit='';
	($linkedit, $mode, $personID, $paymentID, $client, $dtStart_paid, $dtEnd_paid) = generateTXNListLink('P_TXNLogedit', $Data, $tempClientValues_ref);

	my $body=qq[
                               <div class="OKmsg">Payment edited successfully</div><br><br>
                                <a href='$linklist&amp;mode=$mode'>List Transactions</a><br><br>
                                <a href='$linkedit&amp;id=$id&amp;mode=$mode'>Edit the Payment you just edited</a><br>
                ];

        return(1,$body);
}

sub viewTransLog	{

	my ($Data, $intTransLogID)= @_;

    my $lang = $Data->{'lang'};
	$intTransLogID ||= 0;
	my $db = $Data->{'db'};
	my $dollarSymbol = $Data->{'LocalConfig'}{'DollarSymbol'} || "\$";

	my $st = qq[
		SELECT tblTransLog.*, IF(T.intTableType = $Defs::LEVEL_CLUB, Entity.strLocalName, CONCAT(strLocalFirstname,' ',strLocalSurname)) as Name, DATE_FORMAT(dtSettlement,'%d/%m/%Y') as dtSettlement
		FROM tblTransLog INNER JOIN tblTXNLogs as TXNLog ON (TXNLog.intTLogID = tblTransLog.intLogID)
			INNER JOIN tblTransactions as T ON (T.intTransactionID = TXNLog.intTXNID)
			LEFT JOIN tblPerson as M ON (M.intPersonID = T.intID and T.intTableType=$Defs::LEVEL_PERSON)
			LEFT JOIN tblEntity as Entity on (Entity.intEntityID = T.intID and T.intTableType=$Defs::LEVEL_CLUB)
		WHERE intLogID = $intTransLogID
		AND T.intRealmID = $Data->{'Realm'}
	];

	my $qry = $db->prepare($st);
  	$qry->execute;
	my $TLref = $qry->fetchrow_hashref();

	my $st_trans = qq[
		SELECT M.strLocalSurname, M.strLocalFirstName, E.*, P.strName, P.strGroup, E.strLocalName as EntityName
		FROM tblTransactions as T
			LEFT JOIN tblPerson as M ON (M.intPersonID = T.intID and T.intTableType=$Defs::LEVEL_PERSON)
			LEFT JOIN tblProducts as P ON (P.intProductID = T.intProductID)
			LEFT JOIN tblEntity as E ON (E.intEntityID = T.intID and T.intTableType=$Defs::LEVEL_CLUB)
		WHERE intTransLogID = $intTransLogID
		AND T.intRealmID = $Data->{'Realm'}
	];
	my $qry_trans = $db->prepare($st_trans);
  	$qry_trans->execute;
		
	my $orderAmount = $TLref->{'intAmount'};
	$TLref->{'intAmount'} = qq[$dollarSymbol $TLref->{'intAmount'}];
	my %FieldDefs = (
                TXNLOG => {
                        fields => {
				Name=>	{
					label => 'Payment By',
					value => $TLref->{'Name'},
                                        readonly => '1',
                                },
                                intLogID=> {
                                        label => 'Payment Reference Number',
                                        value => $TLref->{'intLogID'},
                                        readonly => '1',
                                },
                                intAmount=> {
                                        label => 'Amount Paid',
                                        value => $TLref->{'intAmount'},
                                        readonly => '1',
				},
				dtSettlement=> {
					label => 'Payment Settlement Date',
					value => $TLref->{'dtSettlement'},
					readonly => '1',
                                },
                                strTXN=> {
                                        label => 'Bank Reference Number',
                                        value => $TLref->{'strTXN'},
                                        readonly => '1',
                                },
                                strResponseCode=> {
                                        label => 'Bank response code',
                                        value => $TLref->{'strResponseCode'},
                                        readonly => '1',
                                },
                                strBSB=> {
                                        label => 'BSB (Manual Payments)',
                                        value => $TLref->{'strBSB'},
                                        readonly => '1',
                                },
                                strBank=> {
                                        label => 'Bank (Manual Payments)',
                                        value => $TLref->{'strBank'},
                                        readonly => '1',
                                },
                                strAccountName=> {
                                        label => 'Account Name (Manual Payments)',
                                        value => $TLref->{'strAccountName'},
                                        readonly => '1',
                                },
                                strAccountNum=> {
                                        label => 'Account Number (Manual Payments)',
                                        value => $TLref->{'strAccountNum'},
                                        readonly => '1',
                                },
                                Status=> {
                                        label => 'Payment Status',
                                        value => $Defs::TransLogStatus{$TLref->{'intStatus'}},
                                        readonly => '1',
                                },
                                PaymentType=> {
                                        label => 'Payment Type',
                                        value => $Defs::paymentTypes{$TLref->{'intPaymentType'}},
                                        readonly => '1',
                                },
				
			},
                order => [qw(intLogID Name intAmount Status PaymentType dtSettlement strTXN strResponseCode strResponseText strBSB strBank strAccountName strAccountNum PartialPayment)],
                        options => {
                                labelsuffix => ':',
                                hideblank => 1,
                                target => $Data->{'target'},
                                formname => 'txnlog_form',
                                introtext => 'auto',
                                buttonloc => 'bottom',
                                LocaleMakeText => $Data->{'lang'},
                                stopAfterAction => 1,
                        },
                        sections => [ ['main',''], ],
                },
        );
	
        my ($resultHTML, undef )=handleHTMLForm($FieldDefs{'TXNLOG'}, undef, 'display', '',$db);

	#my $dollarSymbol = $Data->{'LocalConfig'}{'DollarSymbol'} || "\$";
  my $previousAttemptsBody = qq[
    <div class="sectionheader">].$lang->txt('Previous Payment attempts') . qq[</div>
    <table class="listTable">
    <tr>
      <th>].$lang->txt('Payment Type') . qq[</th>
      <th>].$lang->txt('Date/Time') . qq[</th>
      <th>].$lang->txt('Gateway Text') . qq[</th>
      <th>].$lang->txt('Amount') . qq[</th>
    </tr>
  ];
  my $previousCount=0;

  my $st_previous = qq[
    SELECT
      *,
DATE_FORMAT(dtLog,'%d/%m/%Y %H:%i') as AttemptDateTime
    FROM
      tblTransLog_Retry
    WHERE
      intLogID = ?
    ORDER BY
      intRetryLogID
  ];
  my $qry_previous= $db->prepare($st_previous);
    $qry_previous->execute($intTransLogID);
  while (my $pref = $qry_previous->fetchrow_hashref())  {
    $previousCount++;
    $previousAttemptsBody .= qq[
      <tr>
        <td>$Defs::paymentTypes{$pref->{intPaymentType}}</td>
        <td>$pref->{AttemptDateTime}</td>
        <td>$pref->{strResponseText}</td>
        <td>$dollarSymbol $pref->{intAmount}</td>
      </tr>
    ];
  }

  $previousAttemptsBody .= qq[</table>];

  $previousAttemptsBody = '' if ! $previousCount;

	my $body = qq[
    $previousAttemptsBody
		<div class="sectionheader">].$lang->txt('Items making up this Payment').qq[</div>
		<table class="listTable">
		<tr>
			<th>].$lang->txt('Invoice Number').qq[</th>
			<th>].$lang->txt('Item').qq[</th>
			<th>].$lang->txt('Payment For').qq[</th>
			<th>].$lang->txt('Quantity').qq[</th>
			<th>].$lang->txt('Total Amount').qq[</th>
			<th>].$lang->txt('Status').qq[</th>
		</tr>
	];
	my $client=setClient($Data->{'clientValues'});
	my $count=0;
	my $thisassoc=0;
	$thisassoc=1 if ($TLref->{intEntityPaymentID} == $Data->{'clientValues'}{'assocID'});
	while (my $dref = $qry_trans->fetchrow_hashref())	{
		$count++;
        my $paymentFor = '';
        $paymentFor = qq[$dref->{strLocalSurname}, $dref->{strFirstName}] if ($dref->{intTableType} == $Defs::LEVEL_PERSON);
        $paymentFor = qq[$dref->{EntityName}] if ($dref->{intTableType} == $Defs::LEVEL_CLUB);
		my $productname = $dref->{strName};
		$productname = qq[$dref->{strGroup}-].$productname if ($dref->{strGroup});
		$body .= qq[
			<tr>
				<td>].Payments::TXNtoInvoiceNum($dref->{intTransactionID}).qq[</a></td>
				<td>$productname</a></td>
				<td>$paymentFor</a></td>
				<td>$dref->{intQty}</a></td>
				<td>$dollarSymbol $dref->{curAmount}</td>
				<td>$Defs::TransactionStatus{$dref->{intStatus}}</td>
			</tr>
		];
	}
  	$qry_trans->finish;

	$body .= qq[</table>];
	
	$body = $count ? qq[<div class="sectionheader">].$lang->txt('Payment Summary').qq[</div>] . $resultHTML.$body: $resultHTML;
	
	my $chgoptions='';
    
	$chgoptions.= qq[<a href="$Data->{target}?a=P_TXNLog_DEL&amp;client=$client&amp;tlID=$TLref->{intLogID}" onclick="return confirm(].$lang->txt('This will remove this payment and set all linked transactions to unpaid. Continue?').qq["><img src="images/delete.png" border="0" alt="Delete Payment Record" title="Delete Payment Record"></a>] if (
		$Data->{'clientValues'}{'authLevel'} >= $Defs::LEVEL_ASSOC 
		and $thisassoc 
		and (
			(
				($TLref->{intPaymentType} == $Defs::PAYMENT_ONLINEPAYPAL or $TLref->{intPaymentType} == $Defs::PAYMENT_ONLINECREDITCARD or $TLref->{intPaymentType} == $Defs::PAYMENT_ONLINENAB) 
				and $Data->{'SystemConfig'}{'AllowTXNs_CCs_delete'}
			) 
			or ($TLref->{intPaymentType} != $Defs::PAYMENT_ONLINECREDITCARD and $TLref->{intPaymentType} != $Defs::PAYMENT_ONLINEPAYPAL and $TLref->{intPaymentType} != $Defs::PAYMENT_ONLINENAB)
		)
		) 
		or  $orderAmount ==0;
  $chgoptions = '' if $Data->{'ReadOnlyLogin'};
  $chgoptions=qq[<div class="changeoptions">$chgoptions</div>] if $chgoptions;

	return ($body, $chgoptions.$lang->txt("Payment Record"));

}

sub viewPayLaterTransLog    {

	my ($Data, $intTransLogID)= @_;

	$intTransLogID ||= 0;
	my $db = $Data->{'db'};
	my $dollarSymbol = $Data->{'LocalConfig'}{'DollarSymbol'} || "\$";

	my $st = qq[
		SELECT tblTransLog.*, IF(T.intTableType = $Defs::LEVEL_CLUB, Entity.strLocalName, CONCAT(strLocalFirstname,' ',strLocalSurname)) as Name, DATE_FORMAT(dtSettlement,'%d/%m/%Y') as dtSettlement
		FROM tblTransLog INNER JOIN tblTXNLogs as TXNLog ON (TXNLog.intTLogID = tblTransLog.intLogID)
			INNER JOIN tblTransactions as T ON (T.intTransactionID = TXNLog.intTXNID)
			LEFT JOIN tblPerson as M ON (M.intPersonID = T.intID and T.intTableType=$Defs::LEVEL_PERSON)
			LEFT JOIN tblEntity as Entity on (Entity.intEntityID= T.intID and T.intTableType=$Defs::LEVEL_CLUB)
		WHERE intLogID = $intTransLogID
		AND T.intRealmID = $Data->{'Realm'}
	];

	my $qry = $db->prepare($st);
  	$qry->execute;
	my $TLref = $qry->fetchrow_hashref();

	my $st_trans = qq[
		SELECT M.strLocalSurname, M.strLocalFirstName, E.*, P.strName, P.strGroup
		FROM tblTransactions as T
            LEFT JOIN tblTXNLogs as TXNLog ON (TXNLog.intTXNID = T.intTransactionID)
			LEFT JOIN tblPerson as M ON (M.intPersonID = T.intID and T.intTableType=$Defs::LEVEL_PERSON)
			LEFT JOIN tblProducts as P ON (P.intProductID = T.intProductID)
			LEFT JOIN tblEntity as Entity on (Entity.intEntityID= T.intID and T.intTableType=$Defs::LEVEL_CLUB)
		WHERE TXNLog.intTLogID = $intTransLogID
		AND T.intRealmID = $Data->{'Realm'}
        AND P.intProductType<>2
	];
	my $qry_trans = $db->prepare($st_trans);
  	$qry_trans->execute;
		
	$TLref->{'intAmount'} = qq[$dollarSymbol $TLref->{'intAmount'}];
	my %FieldDefs = (
                TXNLOG => {
                    fields => {
				        Name=>	{
					        label => 'Payment To',
					        value => $TLref->{'Name'},
                            readonly => '1',
                         },
                         intAmount=> {
                            label => 'Amount Paid',
                            value => $TLref->{'intAmount'},
                            readonly => '1',
				         },
                         Status=> {
                            label => 'Payment Status',
                            value => 'Unpaid',
                            readonly => '1',
                         },
				
			        },
                order => [qw(Name Status)],
                        options => {
                                labelsuffix => ':',
                                hideblank => 1,
                                target => $Data->{'target'},
                                formname => 'txnlog_form',
                                introtext => 'auto',
                                buttonloc => 'bottom',
                                stopAfterAction => 1,
                        },
                        sections => [ ['main',''], ],
                },
        );
	
        my ($resultHTML, undef )=handleHTMLForm($FieldDefs{'TXNLOG'}, undef, 'display', '',$db);
	#<script language="JavaScript1.2" type="text/javascript" src="js/jscookie.js"></script>	
	#		<form action="$Data->{'target'}" method="POST">
	#	<input type="button" name="iFamily" Value="Clear Family Session" onclick="DeleteCookie('SWOMRFSID');alert('Cleared');">
	#	</form>
	my $headerText = '';
	$headerText = $Data->{'SystemConfig'}{'regoform_PayLaterText'} if ($Data->{'SystemConfig'}{'regoform_PayLaterText'});
	my $body = qq[
		$headerText
		<div class="sectionheader">Items making up this order</div>
		<table class="listTable">
		<tr>
			<th>Invoice Number</th>
			<th>Item</th>
			<th>Quantity</th>
			<th>Total Amount</th>
			<th>Status</th>
		</tr>
	];
	my $client=setClient($Data->{'clientValues'});
	my $count=0;
	my $thisassoc=0;
	while (my $dref = $qry_trans->fetchrow_hashref())	{
		$count++;
		my $productname = $dref->{strName};
		$productname = qq[$dref->{strGroup}-].$productname if ($dref->{strGroup});
		$body .= qq[
			<tr>
				<td>].Payments::TXNtoInvoiceNum($dref->{intTransactionID}).qq[</a></td>
				<td>$productname</a></td>
				<td>$dref->{intQty}</a></td>
				<td>$dollarSymbol $dref->{curAmount}</td>
				<td><b>$Defs::TransactionStatus{$Defs::TXN_UNPAID}</b></td>
			</tr>
		];
	}
  	$qry_trans->finish;

	$body .= qq[</table>];
	
	$body = $count ? $resultHTML.$body: $resultHTML;
	
	return ($body, "Pay later");

}

sub listTransLog	{
  my($Data, $entityID, $personID) = @_;
    $entityID ||= 0;
    $personID ||= 0;
	my $dollarSymbol = $Data->{'LocalConfig'}{'DollarSymbol'} || "\$";
	my $db=$Data->{'db'};
	my $resultHTML = '';
  my $lang = $Data->{'lang'};
  my %textLabels = (
    'amount' => $lang->txt('Amount'),
    'date' => $lang->txt('Date'),
    'listOfPaymentRecords' => $lang->txt('List of Payment Records'),
    'noPaymentRecordsFound' => $lang->txt('No Payment Records can be found in the database.'),
    'paymentType' => $lang->txt('Payment Type'),
    'refNo' => $lang->txt('Ref. No.'),
    'responseCode' => $lang->txt('Response Code'),
    'status' => $lang->txt('Status'),
    'viewReceipt' => $lang->txt('View Receipt'),
    'comments' => $lang->txt('Comments'),
  );
	my $WHERE = '';
		if ($personID and $Data->{'clientValues'}{'currentLevel'} == $Defs::LEVEL_PERSON)	{
		    $WHERE = qq[ AND T.intID = $personID];
		    $WHERE .= qq[ AND T.intTXNEntityID = $entityID] if ($entityID);
			$WHERE .= qq[ AND T.intTableType=$Defs::LEVEL_PERSON] 
		}
		elsif ($entityID and $Data->{'clientValues'}{'currentLevel'} == $Defs::LEVEL_CLUB)	{
		    $WHERE = qq[ AND T.intID = $entityID];
		    $WHERE .= qq[ AND T.intTXNEntityID = $entityID];
			$WHERE .= qq[ AND T.intTableType=$Defs::LEVEL_CLUB] 
		}
  my $entityWHERE = '';
  if (
		$entityID and $entityID != $Defs::INVALID_ID)  {
    $entityWHERE = qq[ AND TL.intEntityPaymentID IN (0, $entityID) ];
  }
	my $statement =qq[
		SELECT 
      DISTINCT TL.*, 
      DATE_FORMAT(TL.dtLog,"%d/%m/%Y %H:%i") AS dtLog,
      TL.dtLog AS dtLog_RAW
		FROM 
      tblTransLog as TL
			INNER JOIN tblTXNLogs as TXNLog ON (TXNLog.intTLogID= TL.intLogID)
			INNER JOIN tblTransactions as T ON (T.intTransactionID = TXNLog.intTXNID)
		WHERE 
      T.intRealmID= ?
      AND TL.intStatus<>0
		  $WHERE
		ORDER BY 
      TL.dtLog DESC, 
      TL.intLogID
	];
	my $query = $db->prepare($statement);
	$query->execute($Data->{'Realm'});
	my $found = 0;
	my $client=setClient($Data->{'clientValues'});
	my $currentname='';
  my $total = 0;
	my @rowdata = ();
	while (my $dref = $query->fetchrow_hashref) {
		$dref->{status} = $Defs::TransLogStatus{$dref->{intStatus}};
		$dref->{intAmount} ||= 0;
    $total += $dref->{intAmount};
		$dref->{paymentType} =$Defs::paymentTypes{$dref->{intPaymentType}};
		$dref->{intAmount} = qq[$dollarSymbol $dref->{intAmount}];
		my $action = 'P_TXNLog_payVIEW';
		$action = 'C_TXNLog_payVIEW' if $Data->{'clientValues'}{'currentLevel'} == $Defs::LEVEL_CLUB;
		push @rowdata, {
			id => $dref->{'intLogID'},
			intLogID => $dref->{'intLogID'},
			paymentType => $dref->{'paymentType'},
			intAmount => $dref->{'intAmount'},
			status => $dref->{'status'},
			strResponseCode => $dref->{'strResponseCode'},
			dtLog => $dref->{'dtLog'},
			dtLog_RAW => $dref->{'dtLog_RAW'},
			receipt => qq[<a href = "printreceipt.cgi?client=$client&ids=$dref->{intLogID}" target="receipt">].$textLabels{'viewReceipt'}."</a>",
			strComments => $dref->{'strComments'},
			SelectLink => "$Data->{'target'}?client=$client&amp;a=$action&amp;tlID=$dref->{intLogID}"
		}
	}
  $total = sprintf("%.2f", $total);
	$query->finish;

  my @headers = (
    {
      type => 'Selector',
      field => 'SelectLink',
    },
    {
      name =>   $Data->{'lang'}->txt('Ref. No.'),
      field =>  'intLogID',
    },
    {
      name =>   $Data->{'lang'}->txt('Payment Type'),
      field =>  'paymentType',
    },
    {
      name =>   $Data->{'lang'}->txt('Amount'),
      field =>  'intAmount',
    },
    {
      name =>   $Data->{'lang'}->txt('Status'),
      field =>  'status',
    },
    {
      name =>   $Data->{'lang'}->txt('Response Code'),
      field =>  'strResponseCode',
    },
    {
      name =>   $Data->{'lang'}->txt('Date'),
      field =>  'dtLog',
    },
    {
      name =>   $Data->{'lang'}->txt('Comments'),
      field =>  'strComments',
    },
    {
      name =>   $Data->{'lang'}->txt(' '),
      field =>  'receipt',
			type => 'HTML',
    },
  );

  my $grid  = showGrid(
    Data => $Data,
    columns => \@headers,
    rowdata => \@rowdata,
    gridid => 'grid',
    width => '99%',
    height => 700,
  );

	$resultHTML = qq[ 
		$grid
	];
	my $title=$textLabels{'listOfPaymentRecords'};
 	return ($resultHTML,$title);
}

1;
