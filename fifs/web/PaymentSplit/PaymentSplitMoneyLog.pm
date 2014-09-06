#
# $Header: svn://svn/SWM/trunk/web/PaymentSplitMoneyLog.pm 10870 2014-03-04 05:14:22Z fkhezri $
#

package PaymentSplitMoneyLog;

require Exporter;
@ISA       = qw(Exporter);
@EXPORT    = qw(calcMoneyLog moneyLogUpdate);
@EXPORT_OK = qw(calcMoneyLog moneyLogUpdate);

use strict;

use lib '.','..';
use Defs;
use Utils;
use Date::Calc qw(Today);
use Mail::Sendmail;
use MIME::Entity;
use FileHandle;

use PaymentSplitRuleObj;
use PaymentSplitFeesObj;
use PaymentSplitItemObj;
use DeQuote;
use PaymentSplitExport;
require Products;
 

sub upRounding  {

  my ($c)= @_;

	if ($c =~ /^.*\.\d\d5$/)  {
		$c = $c + 0.0001;
	}

	return $c;
}
sub calcMoneyLog	{

	my ($Data, $paymentSettings, $intLogID)= @_;

warn("ML NOT OWRKING");
return;
	$intLogID || return;
	
	my $mpFeesEmail = '';
	my $bsb= '';
	my $accNo= '';
	my $accName= '';
	my $PayPalFees=0;
	my $spMaxCut=0;
	my $lpf=0;
	my %MoneyLog=();
	my $hasParentTXN=0;
	$MoneyLog{'intTransLogID'} = $intLogID;
	$MoneyLog{'gatewayRuleID'} = $paymentSettings->{'gatewayRuleID'} || 0;
	$MoneyLog{'currency'} = $paymentSettings->{'currency'} || 'AUD';

	my %Transactions=();

	my $bankAccount  = '';
    	my $bankCode     = '';
    	my $accountNo    = '';
    	my $accountName  = '';

	my $st = qq[
		SELECT 
			COUNT(intMoneyLogID) as MoneyCount
		FROM 
			tblMoneyLog
		WHERE 
			intTransLogID = $intLogID
			AND (
				intExportBankFileID > 0 
				OR intMYOBExportID > 0
			)
			AND intRealmID = $Data->{'Realm'}
	];
    	my $query = $Data->{'db'}->prepare($st);
    	$query->execute;

	my $moneyCount = $query->fetchrow_array() || 0;

	return if $moneyCount;
	
	$st = qq[
		SELECT 
			TL.intLogID, 
			TL.intAmount, 
			TL.intRealmID,
			TL.intPaymentType,
			TL.intEntityPaymentID,
			IF(TL.intSWMPaymentAuthLevel = 3 OR RF.intClubID >0, 'CLUB', 'ASSOC') as CreatedBy
		FROM 
			tblTransLog as TL
			LEFT JOIN tblRegoForm as RF ON (RF.intRegoFormID = TL.intRegoFormID)
		WHERE 
			TL.intLogID = $intLogID
			AND TL.intRealmID =$Data->{'Realm'}
	];	
    	$query = $Data->{'db'}->prepare($st);
    	$query->execute;
	my $tref= $query->fetchrow_hashref();
	if ($tref->{'intClubPaymentID'} and $tref->{'CreatedBy'} eq 'CLUB')	{
		$Data->{'clientValues'}{'clubID'} = $tref->{'intClubPaymentID'};
		$Data->{'clientValues'}{'authLevel'} = $Defs::LEVEL_CLUB;
		$Data->{'RegoFormID'} ||= 0;
	}
	my $paymentType = $tref->{intPaymentType};
	return if (
		$paymentType != $Defs::PAYMENT_ONLINECREDITCARD 
		and $paymentType != $Defs::PAYMENT_ONLINENAB
		and $paymentType != $Defs::PAYMENT_ONLINEPAYPAL);

	### 2. Calc SP Max take per TXN
	
	my $clubLINK = qq[C.intClubID = RF.intClubID];
	if (! $Data->{'RegoFormID'} and $Data->{'clientValues'}{'authLevel'} == $Defs::LEVEL_CLUB and $Data->{'clientValues'}{'clubID'} and $Data->{'clientValues'}{'clubID'} > 0)	{
		$clubLINK = qq[C.intClubID = $Data->{'clientValues'}{'clubID'}];
	}
	$st = qq[
		SELECT 
			intTransactionID, 
			curAmount, 
			T.intRealmID, 
			T.intRealmSubTypeID ,
			TL.intPaymentType,
			P.intProductType,
			P.intPaymentSplitID,
			Split.intRuleID,
			T.intQty,
			TL.intAssocPaymentID,
			TL.intClubPaymentID,
			T.intAssocID,
			A.intAssocFeeAllocationType,
			C.intClubFeeAllocationType,
			T.intParentTXNID
		FROM 
			tblTransactions as T 
			INNER JOIN tblTransLog as TL ON (T.intTransLogID=TL.intLogID) 
			INNER JOIN tblProducts as P ON (P.intProductID = T.intProductID)
			INNER JOIN tblAssoc as A ON (A.intAssocID= TL.intAssocPaymentID)
			LEFT JOIN tblPaymentSplit as Split ON (Split.intSplitID = P.intPaymentSplitID)
            LEFT JOIN tblRegoForm as RF ON (RF.intRegoFormID = TL.intRegoFormID)
            LEFT JOIN tblClub as C ON ($clubLINK)
		WHERE 
			intLogID = $intLogID
			AND T.intRealmID =$Data->{'Realm'}
	];	
    	$query = $Data->{'db'}->prepare($st);
    	$query->execute;
        my $fees = PaymentSplitFeesObj->getList($Data->{'Realm'}, $Data->{'RealmSubType'}, 1, $Data->{'db'});
        for my $fee(@{$fees}) {
        	next if (! $fee->{'strMPEmail'} and $paymentType == $Defs::PAYMENT_ONLINEPAYPAL);
        	next if (! $fee->{'strBankCode'} and $paymentType == $Defs::PAYMENT_ONLINENAB);
		$mpFeesEmail = $fee->{'strMPEmail'};
		$bsb = $fee->{'strBankCode'};
		$accNo = $fee->{'strAccountNo'};
		$accName = $fee->{'strAccountName'};
		last;
	}
		

	my $del_st = qq[
		DELETE FROM tblMoneyLog
		WHERE 
			intTransLogID= $intLogID
			AND intRealmID = $Data->{'Realm'}
			AND intExportBankFileID=0
			AND intMYOBExportID = 0
	];
	$Data->{'db'}->do($del_st);

	$del_st = qq[
		DELETE FROM tblMoneyLog
		WHERE 
			intTransactionID = ?
			AND intExportBankFileID=0
			AND intMYOBExportID = 0
	];
    	my $del_qry = $Data->{'db'}->prepare($del_st);

	my $realmSubType=$Data->{'RealmSubType'} || 0;
	while (my $dref= $query->fetchrow_hashref())	{
		$del_qry->execute($dref->{intTransactionID});
		$MoneyLog{'intTransactionID'} = $dref->{intTransactionID} || next;
		$MoneyLog{'Realm'} = $dref->{intRealmID};
		$MoneyLog{'RealmSubType'} = $dref->{intRealmSubTypeID} || 0;
		$Transactions{$dref->{intTransactionID}}{'assocID'} = $dref->{intAssocPaymentID} || $dref->{intAssocID} || 0;
		$Transactions{$dref->{intTransactionID}}{'clubID'} = $dref->{intClubPaymentID} || 0; ### THIS NEEDS TO BE SET TO THE CLUB ID IF ITS A CLUB FORM
		$Transactions{$dref->{intTransactionID}}{'ClubJoinedID'} = $dref->{intClubPaymentID} || 0; ### SET AS THE CLUB JOINED
		$Transactions{$dref->{intTransactionID}}{'clubID'} = 0 if $tref->{'CreatedBy'} ne 'CLUB'; ## ClubJoinedID not touched if not assoc form
		$MoneyLog{'assocID'} = $Transactions{$dref->{intTransactionID}}{'assocID'} || 0;
		$MoneyLog{'clubID'} = $Transactions{$dref->{intTransactionID}}{'clubID'} || 0;
		$MoneyLog{'ClubJoinedID'} = $Transactions{$dref->{intTransactionID}}{'ClubJoinedID'} || 0;
		$realmSubType= $realmSubType || $Data->{'RealmSubType'} || $dref->{intRealmSubTypeID} || 0;

		$Transactions{$dref->{intTransactionID}}{'totAmount'} = $dref->{curAmount};
		$Transactions{$dref->{intTransactionID}}{'prodType'} = $dref->{intProductType};
		$Transactions{$dref->{intTransactionID}}{'SplitableAmount'} = $dref->{curAmount};
		$Transactions{$dref->{intTransactionID}}{'SplitID'} = $dref->{intPaymentSplitID} || 0;
		$Transactions{$dref->{intTransactionID}}{'RuleID'} = $dref->{intRuleID} || 0;
		$Transactions{$dref->{intTransactionID}}{'Qty'} = $dref->{intQty} || 1;
		$Transactions{$dref->{intTransactionID}}{'parentTXNID'} = $dref->{intParentTXNID} || 0;
		$hasParentTXN = 1 if ($dref->{intParentTXNID});
		next if (
			$dref->{intPaymentType} != $Defs::PAYMENT_ONLINEPAYPAL 
			and $dref->{intPaymentType} != $Defs::PAYMENT_ONLINENAB
		);

		if ($dref->{intProductType} == 2)	{
			$MoneyLog{'amount'} = $dref->{'curAmount'};
			moneyLog($Data, \%MoneyLog, $Defs::ML_TYPE_LPF, 'LPF');
			$lpf+=$MoneyLog{'amount'};
			$spMaxCut += $dref->{'curAmount'};
			next;
		}
		else	{
			## FOR non LPF make sure it has a ruleID (even if the parent)
			$Transactions{$dref->{intTransactionID}}{'RuleID'} = $dref->{intRuleID} || $Data->{'SystemConfig'}{'PaymentSplitRuleID'} || 0;
		}
		my $txnFee=0;
        	for my $fee(@{$fees}) {
                	next if (! $fee->{'strMPEmail'} and $paymentType == $Defs::PAYMENT_ONLINEPAYPAL);
        		next if (! $fee->{'strBankCode'} and $paymentType == $Defs::PAYMENT_ONLINENAB);
			next if (($fee->{intFeeAllocationType} == 2 and ! $dref->{intAssocFeeAllocationType} and ! $dref->{intClubFeeAllocationType} ) or ($dref->{intAssocFeeAllocationType} == 2 and ! $dref->{intClubFeeAllocationType}) or ($dref->{intClubFeeAllocationType} == 2));
                	my $feeAmount  = $fee->{'curAmount'};
                	my $feeFactor  = $fee->{'dblFactor'};
                	my $feesValue  = $feeAmount * 1;
                	$feesValue    += $dref->{curAmount} * $feeFactor;
                	$feesValue     = sprintf("%.2f", $feesValue); # round to 2 dp
			if ($fee->{curMaxFee} > 0 and $feesValue > $fee->{curMaxFee})	{
				$feesValue =  $fee->{curMaxFee};
			}
			$MoneyLog{'amount'} = $feesValue;
			$txnFee+=$feesValue;
			moneyLog($Data, \%MoneyLog, $Defs::ML_TYPE_SPMAX, 'SP MAX CUT');
			$spMaxCut += $feesValue;
			$bankCode      = $fee->{'strBankCode'};
	                $accountNo     = $fee->{'strAccountNo'};
        	        $accountName   = $fee->{'strAccountName'};
			last;
		}
		$Transactions{$dref->{intTransactionID}}{'SplitableAmount'} = $dref->{curAmount} - $txnFee;
	}
 
	### 2. Calc PAYPAL FEES
        $fees = PaymentSplitFeesObj->getList($Data->{'Realm'}, $Data->{'RealmSubType'}, 2, $Data->{'db'});
	
	my $gatewayFees =0;
	$MoneyLog{'intTransactionID'} = 0;
	$MoneyLog{'TotalOrderAmount'}= $tref->{intAmount};
	$MoneyLog{'paymentType'} = $paymentType;

	if ($paymentType == $Defs::PAYMENT_ONLINEPAYPAL)	{
		$MoneyLog{'RealmSubType'} = $Data->{'RealmSubType'} || $realmSubType || 0;
		$MoneyLog{'Realm'} = $Data->{'Realm'} || $tref->{intRealmID};
        	for my $fee(@{$fees}) {
                next if $fee->{'strMPEmail'};
                my $feeAmount  = $fee->{'curAmount'};
                my $feeFactor  = $fee->{'dblFactor'};
                my $feesValue  = $feeAmount * 1;
                $feesValue    += $tref->{intAmount} * $feeFactor;
								$feesValue = upRounding($feesValue);
                $feesValue     = sprintf("%.2f", $feesValue); # round to 2 dp
			    $MoneyLog{'amount'} = $feesValue;
                next if $tref->{intAmount} == 0;
				moneyLog($Data, \%MoneyLog, $Defs::ML_TYPE_GATEWAYFEES, 'GATEWAY FEES');
				$gatewayFees+=$feesValue;
				$bankCode      = $fee->{'strBankCode'};
	        	$accountNo     = $fee->{'strAccountNo'};
        		$accountName   = $fee->{'strAccountName'};
        	    my $mpEmail       = $fee->{'strMPEmail'};
				last;
			}
	}
	$MoneyLog{'amount'}= $spMaxCut - $gatewayFees;
	$MoneyLog{'mpEmail'} = $mpFeesEmail || '';
	$MoneyLog{'bankCode'} = $bsb || '';
	$MoneyLog{'accNo'} = $accNo || '';
	$MoneyLog{'accName'} = $accName || '';
	moneyLog($Data, \%MoneyLog, $Defs::ML_TYPE_SPFINAL, 'SP FINAL CUT') if $MoneyLog{'amount'} > 0;



	## MAX MONEY TO SPORT
	$MoneyLog{'amount'} = $MoneyLog{'TotalOrderAmount'} - $spMaxCut;# - $lpf;
	$MoneyLog{'mpEmail'} = '';
	$MoneyLog{'bankCode'} = '';
	$MoneyLog{'accNo'} = '';
	$MoneyLog{'accName'} = '';
	moneyLog($Data, \%MoneyLog, $Defs::ML_TYPE_SPORTTOTAL, 'MONEY TO SPORT');
 
	### 3. Calc splits

	foreach my $tran (keys %Transactions)	{
		$MoneyLog{'intTransactionID'} = $tran;
		$MoneyLog{'intAssocID'} = $Transactions{$tran}{'assocID'} || 0;
		$MoneyLog{'intClubID'} = $Transactions{$tran}{'clubID'} || 0;
		$MoneyLog{'ClubJoinedID'} = $Transactions{$tran}{'ClubJoinedID'} || 0;
		next if $Transactions{$tran}{'prodType'} == 2;
		next if ! $Transactions{$tran}{'RuleID'};
		calcMoneySplit($Data, $intLogID, \%{$Transactions{$tran}}, \%MoneyLog);
		checkParentPaid($Data, $Transactions{$tran}{'parentTXNID'}) if ($Transactions{$tran}{'parentTXNID'});
	}

	return;
}
sub checkParentPaid	{

	my ($Data, $parentTXNID) = @_;
	return if ! $parentTXNID;

	my $st = qq[
		SELECT
			T.intTransactionID,
			T.curAmount as OriginalAmount,
			SUM(TChildren.curAmount) as AmountAlreadyPaid,
			T.intRealmID,
			T.intAssocID,
			T.intTXNClubID,
			T.intID,
			T.intTableType
		FROM
			tblTransactions as T 
			LEFT JOIN tblTransactions as TChildren ON (
				TChildren.intParentTXNID = T.intTransactionID
				AND TChildren.intStatus=1
				AND TChildren.curAmount>0
			)
		WHERE
			T.intTransactionID = ?
			AND T.intStatus=0
	];
  my $query = $Data->{'db'}->prepare($st);
  $query->execute($parentTXNID);
	my $dref = $query->fetchrow_hashref();
	if ($dref->{'intTransactionID'} and $dref->{'AmountAlreadyPaid'} >= $dref->{'OriginalAmount'})	{
		my $st= qq[
			INSERT INTO tblTransLog (intAssocPaymentID, intClubPaymentID, dtLog, intAmount, strResponseCode, strResponseText, intPaymentType, intRealmID, intStatus) VALUES
			($dref->{'intAssocID'}, $dref->{'intTXNClubID'}, NOW(), $dref->{'OriginalAmount'}, 'OK', "Part Payments", $Defs::PAYMENT_MIXED, $dref->{'intRealmID'}, $Defs::TXNLOG_SUCCESS)
		];
		my $qry = $Data->{'db'}->prepare($st);
		$qry->execute;
		my $transLogID = $qry->{'mysql_insertid'};
		my $st_txnLogs = qq[
			INSERT INTO tblTXNLogs (intTXNID, intTLogID)
			VALUES (?,?)
		];
		my $qrytxnLogs = $Data->{'db'}->prepare($st_txnLogs);
		$qrytxnLogs->execute($dref->{'intTransactionID'}, $transLogID);

		$st = qq[
			UPDATE 
				tblTransactions
			SET 
				intTransLogID=?,
				intStatus = 1, 
				dtPaid = SYSDATE()
			WHERE
				intTransactionID=?
			LIMIT 1
		];
		$qry = $Data->{'db'}->prepare($st);
		$qry->execute($transLogID, $parentTXNID);
		Products::product_apply_transaction($Data,$transLogID);
	}
	else	{
	}
	return;

}

sub moneyLog	{

	my ($Data, $MoneyLog, $intLogType, $From) = @_;

	$intLogType ||= 0;
	$MoneyLog->{'Realm'} ||= 0;
	$MoneyLog->{'RealmSubType'} ||= 0;
	$MoneyLog->{'intTransactionID'} ||= 0;
	$MoneyLog->{'intTransLogID'} ||= 0;
	$MoneyLog->{'amount'} ||= 0;
	$MoneyLog->{'clubID'} ||= 0;
	$MoneyLog->{'assocID'} ||= 0;
	$MoneyLog->{'entityID'} ||= 0;
	$MoneyLog->{'entityTypeID'} ||= 0;
	$MoneyLog->{'ruleID'} = $MoneyLog->{'ruleID'} || $MoneyLog->{'gatewayRuleID'} || 0;
	$MoneyLog->{'ruleID'} = $Data->{'SystemConfig'}{'PaymentSplitRuleID'} if (! $MoneyLog->{'ruleID'} and $intLogType != $Defs::ML_TYPE_LPF);
	$MoneyLog->{'splitID'} ||= 0;
	$MoneyLog->{'splitItemID'} ||= 0;
	$MoneyLog->{'GSTRate'} ||= 0;
	$MoneyLog->{'currency'} ||= 'AUD';
	$MoneyLog->{'bankCode'} ||= '';
	$MoneyLog->{'accNo'} ||= '';
	$MoneyLog->{'accName'} ||= '';
	my $bankCode = $MoneyLog->{'bankCode'} || '';
	my $accNo = $MoneyLog->{'accNo'} || '';
	my $accName = $MoneyLog->{'accName'} || '';
	my $mpEmail = $MoneyLog->{'mpEmail'} || '';
	my $currencyCode = $MoneyLog->{'currency'} || 'AUD';
	$bankCode = '' if ($bankCode eq 'XX');
	$accNo= '' if ($accNo eq 'XX');
	
	$From ||= '';
	#deQuote($Data->{'db'}, \$mpEmail);
	#deQuote($Data->{'db'}, \$From);
	#deQuote($Data->{'db'}, \$currencyCode);
	#deQuote($Data->{'db'}, \$bankCode);
	#deQuote($Data->{'db'}, \$accNo);
	#deQuote($Data->{'db'}, \$accName);
	$MoneyLog->{'ruleID'} ||= 0;
	my $st = qq[
		INSERT IGNORE INTO tblMoneyLog
		(
			intTransactionID, 
			intTransLogID, 
			intRealmID, 
			intRealmSubTypeID, 
			intLogType,
			curMoney, 
			strFrom, 
			intAssocID, 
			intClubID, 
			intEntityID, 
			intEntityType,
			strMPEmail,
			intRuleID,
			intSplitID,
			intSplitItemID,
			strCurrencyCode,
			dblGSTRate,
			strBankCode,
			strAccountNo,
			strAccountName,
			dtEntered
		)
		VALUES (
			?,
			?,
			?,
			?,
			?,
			?,
			?,
			?,
			?,
			?,
			?,
			?,
			?,
			?,
			?,
			?,
			?,
			?,
			?,
			?,
			SYSDATE()
		)
	];
    my $query = $Data->{'db'}->prepare($st);
    $query->execute(
			$MoneyLog->{'intTransactionID'},
            $MoneyLog->{'intTransLogID'},
            $MoneyLog->{'Realm'},
            $MoneyLog->{'RealmSubType'},
            $intLogType,
            $MoneyLog->{'amount'},
            $From,
            $MoneyLog->{'assocID'},
            $MoneyLog->{'clubID'},
            $MoneyLog->{'entityID'},
            $MoneyLog->{'entityTypeID'},
            $mpEmail,
            $MoneyLog->{'ruleID'},
            $MoneyLog->{'splitID'},
            $MoneyLog->{'splitItemID'},
            $currencyCode,
            $MoneyLog->{'GSTRate'},
            $bankCode,
            $accNo,
            $accName
	);
}

sub getParentSplits	{

	my ($Data, $transID, $parentTXNID) = @_;

	return if (!$transID or !$parentTXNID);

	my $st = qq[
		SELECT 
			SUM(ML.curMoney) as TotalAmount,
			ML.intRuleID,
			ML.intSplitID,
			ML.intSplitItemID,
			ML.intEntityID,
			ML.intEntityType
		FROM
			tblMoneyLog as ML
			INNER JOIN tblTransactions as T ON (
				T.intTransactionID = ML.intTransactionID
			)
			INNER JOIN tblTransLog as TL ON (
				TL.intLogID=ML.intTransLogID
			)
		WHERE 
			intLogType=6
			AND intParentTXNID = ?
			AND T.intTransactionID != ?
			AND TL.intPaymentType IN ($Defs::PAYMENT_ONLINENAB, $Defs::PAYMENT_ONLINEPAYPAL)
			AND T.intStatus=1
		GROUP BY ML.intSplitItemID
	];

  my $query = $Data->{'db'}->prepare($st);
  $query->execute($parentTXNID, $transID);
	my %previousSplits=();

	while (my $dref= $query->fetchrow_hashref())	{
		my $key = $dref->{'intSplitItemID'} || next;
		$previousSplits{$key}{'amount'} = $dref->{'TotalAmount'};
	}
	return \%previousSplits;
}

sub calcMoneySplit	{

## LETS GET THE CURRENT AMOUNTS SPLIT PER PRODUCT/TRANSACTION
## NEED TO GET PRODUCT ID -- ie: Amount already split in tblMoneyLog !
## GET SPLITS FOR $transactionID from tblTransactions.intParentTXNID and link to tblMoneyLog
## Store per splitID |  ruleID ? | entityID | entityType | curAmountAlreadySent
## Only checks this if NOT a Remainder

    	my ($Data, $intLogID, $tranRef, $MoneyLog) = @_;
	my $paymentType = $MoneyLog->{'paymentType'};
    # todo: ensure that $defaultAccount and $paymentType are set...
	 my $defaultAccount = getDefaultAccount($Data->{'db'}, $MoneyLog);
	 my $prevSplits = getParentSplits($Data, $MoneyLog->{'intTransactionID'}, $tranRef->{'parentTXNID'});

    	my $dbh = $Data->{'db'};
    	#my $dbSysDate = getDBSysDate($dbh);

	my $ruleID=$tranRef->{'RuleID'};
    	my $rule = PaymentSplitRuleObj->load($ruleID, $dbh);
	
    	my $realmID = $MoneyLog->{'Realm'};
    	my $isMassPay = ($rule->getFinInst eq 'PAYPAL_NAB') || 0;

	my $query=();
    	my $paymentSplits = PaymentSplitObj->getListByRule($ruleID, $dbh);

    # include a paymentsplit with splitID=0
    	push @$paymentSplits, {
        	'intSplitID'   => 0,
        	'intRuleID'    => $ruleID,
        	'strSplitName' => 'Dummy split for products without a splitID'
   	};

    	my $exportAmt    = 0;
    	my $bankAccount  = '';
    	my $bankCode     = '';
    	my $accountNo    = '';
    	my $accountName  = '';
    	my $mpEmail      = '';                                                            
    	my %postingsAccs = ();
    	my %postingsAmts = ();
    	my $postingsKey  = '';
    	my $fees         = '';
    	my $savSubTypeID = -1;

    	# get the exportBankFileID here to pass to the log file
    	my $exportBankFileID = getExportBankFileID($realmID, $ruleID, $dbh) if (1==2);

    	# process each split in turn
    	my $splitID = $tranRef->{'SplitID'} || 0;
    	my @items   = ();

    	# dont pick up lines for splitID 0 (previously inserted; shouldn't be any, but just to be sure...)
    	my $paymentSplitItems = ($splitID > 0) ? PaymentSplitItemObj->getList($splitID, $dbh) : []; # anonymous array constructor - reference to an empty array

    	# set up the splitItems array with the items found for that splitID
    	for my $paymentSplitItem(@{$paymentSplitItems}) {
    		push @items, {
        	        'levelID'          => $paymentSplitItem->{'intLevelID'},
        	        'otherBankCode'    => $paymentSplitItem->{'strOtherBankCode'},
        	        'otherAccountNo'   => $paymentSplitItem->{'strOtherAccountNo'},
        	        'otherAccountName' => $paymentSplitItem->{'strOtherAccountName'},
        	        'factor'           => $paymentSplitItem->{'dblFactor'},
        	        'remainder'        => $paymentSplitItem->{'intRemainder'},
        	        'mpEmail'          => $paymentSplitItem->{'strMPEmail'},
        	        'amount'          => $paymentSplitItem->{'curAmount'},
        	        'itemID'          => $paymentSplitItem->{'intItemID'}   
        	};
    	}

	## if nothing in items then add self
	my $remainingAmt = $tranRef->{'SplitableAmount'} || next;
        my $clubID       = $tranRef->{'clubID'};
        my $assocID      = $tranRef->{'assocID'};
	
	if (!scalar(@items))	{
		## ONCE REGOFORM GOES LIVE, FIX THIS TO CHECK CLUB OR ASSOC
		#push @items, {
        	#	'levelID'          => 5,
        	#	'remainder'        => 1,
        	#};
		my $defaultLevel = ($clubID and $clubID > 0) ? $Defs::LEVEL_CLUB : $Defs::LEVEL_ASSOC;
			push @items, {
        	        	'levelID'          => $defaultLevel,
        	        	'remainder'        => 1,
        		};
	}

        # Get the subTypeID for the assoc.
        #my $subTypeID = getSubTypeID($Data, $assocID);

        for my $d(@items) {
		my $lineValue    = 0;
                my $entityTypeID = 0;
                my $entityID     = 0;
		$mpEmail='';

		foreach my $l (keys %{$d})	{
		}
										my $alreadySent=0;
                if (!$d->{'remainder'}) {
											if ($prevSplits->{$d->{'itemID'}}{'amount'} > 0)	{
												$alreadySent = $prevSplits->{$d->{'itemID'}}{'amount'} || 0;
											}
                    	if ($d->{'amount'} != 0.00 and $d->{'amount'} != 0 ) {
                    		$lineValue = $d->{'amount'} * $tranRef->{'Qty'};
                    	}
			if ($d->{'factor'})	{
				my $tempValue = 0;
                        	$tempValue = $tranRef->{'SplitableAmount'} * $d->{'factor'};
				$lineValue += $tempValue;
			}
                        $lineValue = sprintf("%.2f", $lineValue);
										my $totalWouldSend = $lineValue; ##Total Amount split will be
                    $lineValue     = $remainingAmt if $lineValue > $remainingAmt;
										my $leftToSend = 0;
										$leftToSend = $totalWouldSend -$alreadySent;  ##Lets subtract any alreadySnt (parentTXNID)
										$lineValue=$leftToSend if ($lineValue>$leftToSend);
                    $remainingAmt -= $lineValue;
                }
                else {
                    $lineValue     = $remainingAmt;
                }
                $exportAmt += $lineValue;

                # now determine bank account details
                # both bank and masspay stuff will be returned but only one will have any content

                if ($d->{'levelID'} > 0) {
			if ($d->{'levelID'} == 3 and ! $clubID and $MoneyLog->{'ClubJoinedID'})	{
				$clubID = $MoneyLog->{'ClubJoinedID'} || 0;
			}
                    	$bankAccount = getBankAccount($Data, $d->{'levelID'}, $clubID, $assocID, $defaultAccount);
			if (defined $bankAccount and $bankAccount)	{
                    		# will always come back with at least the default account
                    		$bankCode     = $d->{'otherBankCode'} || $bankAccount->getBankCode;
                    		$accountNo    = $d->{'otherAccountNo'} || $bankAccount->getAccountNo;
                    		$accountName  = $d->{'otherAccountName'} || $bankAccount->getAccountName;
				$mpEmail      = $d->{'mpEmail'} || $bankAccount->getMPEmail;
                    		$entityTypeID = $bankAccount->getTypeID;
                    		$entityID     = $bankAccount->getEntityID;
			}
			else	{
				## No bank Account so set as blank pointing to where its suppose to go and update tblMoneyLog
				## with MPEmail at a later stage
				 my ($zoneID, $regionID, $stateID, $natID) = getLevelsUp($Data, $clubID, $assocID);
				$entityTypeID = $d->{'levelID'};
				$entityID = $clubID if ($d->{'levelID'} == $Defs::LEVEL_CLUB);
				$entityID = $assocID if ($d->{'levelID'} == $Defs::LEVEL_ASSOC);
				$entityID = $zoneID if ($d->{'levelID'} == $Defs::LEVEL_ZONE);
				$entityID = $regionID if ($d->{'levelID'} == $Defs::LEVEL_REGION);
				$entityID = $stateID if ($d->{'levelID'} == $Defs::LEVEL_STATE);
				$entityID = $natID if ($d->{'levelID'} == $Defs::LEVEL_NATIONAL);
			}

                }
                else {
                    $bankCode     = $d->{'otherBankCode'};
                    $accountNo    = $d->{'otherAccountNo'};
                    $accountName  = $d->{'otherAccountName'};
                    $mpEmail      = $d->{'mpEmail'};
                    $entityTypeID = 0;
                    $entityID     = 0;
                }

		$MoneyLog->{'bankCode'} = $bankCode || '';
		$MoneyLog->{'accNo'} = $accountNo || '';
		$MoneyLog->{'accName'} = $accountName || '';
		$MoneyLog->{'amount'} = $lineValue;
		$MoneyLog->{'entityID'} =  $entityID || 0;
		$MoneyLog->{'entityTypeID'} =  $entityTypeID || 0;
		$MoneyLog->{'mpEmail'} = $mpEmail;
		$MoneyLog->{'ruleID'} = $ruleID;
		$MoneyLog->{'splitID'} = $splitID;
		$MoneyLog->{'splitItemID'} = $d->{itemID};
		moneyLog($Data, $MoneyLog, $Defs::ML_TYPE_SPLIT, "SPLIT");
            }

    return;
}

sub moneyLogUpdate{
    	my ($db, $exportBankFileID, $MLemails_ref, $MLids_ref) = @_;

    	return if !$exportBankFileID or !$MLids_ref or ! $MLemails_ref;

    	my $ml_st = qq[
        	UPDATE
			tblMoneyLog as ML
		SET
			ML.intExportBankFileID = $exportBankFileID
			
		WHERE 
			ML.intMoneyLogID=?
			AND ML.intExportBankFileID = 0
            AND ((ML.strBankCode <>'' and ML.strAccountNo <> '') or ML.strMPEmail <> '' OR ML.intLogType IN (1,2,3))
    	];
	
    	my $txn_st = qq[
        	UPDATE
			tblTransactions as T
			INNER JOIN tblMoneyLog as ML ON (ML.intTransactionID = T.intTransactionID)
		SET
			T.intExportAssocBankFileID = $exportBankFileID
			
		WHERE 
			ML.intMoneyLogID=?
			AND T.intExportAssocBankFileID=0
	];
    	my $ml_qry= $db->prepare($ml_st);
    	my $txn_qry= $db->prepare($txn_st);

        foreach my $email (keys %{$MLemails_ref})	{
		    for my $id (@{$MLids_ref->{$email}}) {
			    next if ! $id;
                $ml_qry->execute($id);
		        next if ! $email;
                $txn_qry->execute($id);
            }
	    }

    	return;
}

1;
