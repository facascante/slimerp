#
# $Header: svn://svn/SWM/trunk/web/PaymentSplitExport.pm 10052 2013-12-01 22:37:17Z tcourt $
#

package PaymentSplitExport;

require Exporter;
@ISA       = qw(Exporter);
@EXPORT    = qw(doPaymentSplitExport doPaymentSplitTxnUpdate updatePostings updateLog getDefaultAccount getExportBankFileID getSubTypeID getBankAccount getLevelsUp);
@EXPORT_OK = qw(doPaymentSplitExport doPaymentSplitTxnUpdate updatePostings updateLog getDefaultAccount getExportBankFileID getSubTypeID getBankAccount getLevelsUp);

use strict;

use lib '.','..';
use Defs;
use Utils;
use Date::Calc qw(Today);
use Mail::Sendmail;
use MIME::Entity;
use FileHandle;

use PaymentSplitRuleObj;
use PaymentSplitObj;
use PaymentSplitFeesObj;
use PaymentSplitItemObj;
use PaymentSplitLogObj;
use BankAccountObj;
use DirectEntryExport;
 
sub getDefaultAccount   {
        my($db, $dref) = @_;

        #Find National body for this realm/subrealm

        my $realmID = $dref->{'intRealmID'} || $dref->{'Realm'} || return undef;
        my $subRealmID = $dref->{'intSubTypeID'} || $dref->{'RealmSubType'} || 0;

	my $assocID = $dref->{'intAssocID'} || 0;

        my $subrealmWHERE = $subRealmID
                ? qq[ AND N.intSubTypeID IN (0, $subRealmID) ]
                : '';
	my $assocJOIN = $assocID
		? qq[INNER JOIN tblTempNodeStructure as T ON (
			T.intAssocID = $assocID
			AND T.int100_ID = N.intNodeID
			AND T.intRealmID = $realmID
		)]
		: '';
	
	my $st = qq[
		SELECT 
			strValue
		FROM 			
			tblSystemConfig
		WHERE 
			intRealmID = $realmID
			AND intSubTypeID IN (0, $subRealmID)
			AND strOption ='PayPal_NationalNodeID'
		ORDER BY 
			intSubTypeID DESC
		LIMIT 1
	];
        my $q = $db->prepare($st);
        $q->execute();
	my $nodeID = $q->fetchrow_array() || 0;

	my $nodeIDWHERE = $nodeID 
			? qq[ AND N.intNodeID = $nodeID]
			: '';
	
        $st=qq[
                SELECT
                        N.intNodeID
                FROM
                        tblNode as N
			$assocJOIN
                WHERE
                        N.intRealmID = $realmID
                        AND N.intTypeID = $Defs::LEVEL_NATIONAL
                        $subrealmWHERE
			$nodeIDWHERE
        ];
        $q = $db->prepare($st);
        $q->execute();
        my $nationalID = 0;
        my $count = 0;
        while( my ($nID) = $q->fetchrow_array())        {
                $count++;
                $nationalID ||= $nID;
        }
        $q->finish();
        if($count > 1) {
                #OOPS Big Problems - multiple national bodies in this realm/filter
                notifyEmail(qq[
                        When attempting to get the default account for a masspay transfer for realm $realmID and subrealm $subRealmID, multiple national bodies ($count) were detected.  Skipping this one.
                ]);
                return undef;
        }
        return undef if !$nationalID;
        my $defaultAccount = BankAccountObj->load($Defs::LEVEL_NATIONAL, $nationalID, $db);
        return $defaultAccount;
}

sub doPaymentSplitExport {
    my ($Data, $ruleID, $defaultAccount, $paymentType, $email) = @_;
    # todo: ensure that $defaultAccount and $paymentType are set...

    my $dbh = $Data->{'db'};
    my $dbSysDate = getDBSysDate($dbh);

    my $rule = PaymentSplitRuleObj->load($ruleID, $dbh);
    my $realmID = $rule->getRealmID;                          
    my $isMassPay = ($rule->getFinInst eq 'PAYPAL_NAB') || 0;

    my $paymentSplits = PaymentSplitObj->getListByRule($ruleID, $dbh);

    # include a paymentsplit with splitID=0
    push @$paymentSplits, {
        'intSplitID'   => 0,
        'intRuleID'    => $ruleID,
        'strSplitName' => 'Dummy split for products without a splitID'
   };

    my $sql = qq[
        SELECT 
            t.intAssocID, tl.intClubPaymentID, tl.intAssocPaymentID, 
            SUM(t.curAmount) AS totAmount, 
            COUNT(1) AS numTrans

        FROM 
            tblTransactions t
            INNER JOIN tblTransLog tl ON t.intTransLogID=tl.intLogID
            INNER JOIN tblProducts p ON t.intProductID=p.intProductID
        WHERE
            p.intPaymentSplitID=?
            AND t.curAmount<>0
            AND tl.intPaymentType=$paymentType
            AND tl.dtSettlement<'$dbSysDate'
            AND tl.dtLog <= DATE_ADD(CURRENT_DATE(), INTERVAL -63 HOUR)
            AND t.intStatus IN (1, 2)
            AND tl.intStatus IN (1)
            AND t.intRealmID=$realmID                         
            AND t.intExportAssocBankFileID=0
        GROUP BY t.intAssocID, tl.intClubPaymentID, tl.intAssocPaymentID
    ];

    my $query = $dbh->prepare($sql); 
            
    my $tranCount    = 0;
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
    my $exportBankFileID = getExportBankFileID($realmID, $ruleID, $dbh);

    # process each split in turn
    for my $paymentSplit(@{$paymentSplits}) {
        my $splitID = $paymentSplit->{'intSplitID'};
	next if ! $splitID;
        my @items   = ();

        # dont pick up lines for splitID 0 (previously inserted; shouldn't be any, but just to be sure...)
        my $paymentSplitItems = ($splitID > 0)
            ? PaymentSplitItemObj->getList($splitID, $dbh)
            : []; # anonymous array constructor - reference to an empty array

        # set up the splitItems array with the items found for that splitID
        for my $paymentSplitItem(@{$paymentSplitItems}) {
            push @items, {
                'levelID'          => $paymentSplitItem->{'intLevelID'},
                'otherBankCode'    => $paymentSplitItem->{'strOtherBankCode'},
                'otherAccountNo'   => $paymentSplitItem->{'strOtherAccountNo'},
                'otherAccountName' => $paymentSplitItem->{'strOtherAccountName'},
                'factor'           => $paymentSplitItem->{'dblFactor'},
                'remainder'        => $paymentSplitItem->{'intRemainder'},
                'amount'        => $paymentSplitItem->{'curAmount'},
                'mpEmail'          => $paymentSplitItem->{'strMPEmail'}   
            };
        }

        # execute the query on the transaction file (to get trans for this split)
        $query->execute($splitID);
        
my $SPFee=0;
        while (my $tranRef = $query->fetchrow_hashref()) {

            next if $tranRef->{'numTrans'} == 0;

            $tranCount += $tranRef->{'numTrans'};

            my $remainingAmt = $tranRef->{'totAmount'} || next;
            my $clubID       = $tranRef->{'intClubPaymentID'};

            # Every trans will have an assoc (confirmed by BI)
            my $assocID      = ($tranRef->{'intAssocPaymentID'}) 
                ? $tranRef->{'intAssocPaymentID'} 
                : $tranRef->{'intAssocID'};

            # Get the subTypeID for the assoc.
            my $subTypeID = getSubTypeID($Data, $assocID);

            if ($subTypeID != $savSubTypeID) {
                $fees = PaymentSplitFeesObj->getList($realmID, $subTypeID, 1, $dbh);
                $savSubTypeID = $subTypeID;
            }

            for my $fee(@{$fees}) {
		#next if ! $fee->{'strMPEmail'}; ## Ignore Blank Fee -- This is the 1.1% PAYPAL + 0.30 (30cents)
                my $feeAmount  = $fee->{'curAmount'}; 
                my $feeFactor  = $fee->{'dblFactor'};
                my $feesValue  = $feeAmount * $tranRef->{'numTrans'};
                $feesValue    += $tranRef->{'totAmount'} * $feeFactor;
                $feesValue     = sprintf("%.2f", $feesValue); # round to 2 dp
                $feesValue     = $remainingAmt if $feesValue > $remainingAmt;
                $remainingAmt -= $feesValue;
                $exportAmt    += $feesValue;
                $bankCode      = $fee->{'strBankCode'};
                $accountNo     = $fee->{'strAccountNo'};
                $accountName   = $fee->{'strAccountName'};
                $mpEmail       = $fee->{'strMPEmail'};                                
		$SPFee += $feesValue;
		
		next if $paymentSplit->{'strSplitName'} =~ /PROCESSING FEE/; ## Lets ignore the fees on the low processing fee - ie: don't take 3.9%
		
                updatePostings($isMassPay, $mpEmail, $bankCode, $accountNo, $accountName, $feesValue, \%postingsAccs, \%postingsAmts);
                updateLog($exportBankFileID, 0, 0, $assocID, $clubID, $bankCode, $accountNo, $accountName, $mpEmail, $feesValue, $fee->{'intFeesType'}, $dbh);
            }
                $bankCode      = '';
                $accountNo     = '';
                $accountName   = '';
                $mpEmail       = ''; 
	

            for my $d(@items) {
                my $lineValue    = 0;
                my $entityTypeID = 0;
                my $entityID     = 0;

                if (!$d->{'remainder'}) {
                    if ($d->{'amount'} != 0.00) {
                        $lineValue = $d->{'amount'} * $tranRef->{'numTrans'};
                    }
                    else {
                        $lineValue = $tranRef->{'totAmount'} * $d->{'factor'};
                        $lineValue = sprintf("%.2f", $lineValue);
                    }
                    $lineValue     = $remainingAmt if $lineValue > $remainingAmt;
                    $remainingAmt -= $lineValue;
                }
                else {
                    $lineValue     = $remainingAmt;
                }
                $exportAmt += $lineValue;

                # now determine bank account details
                # both bank and masspay stuff will be returned but only one will have any content

                if ($d->{'levelID'} > 0) {
                    $bankAccount = getBankAccount($Data, $d->{'levelID'}, $clubID, $assocID, $defaultAccount);
			if (defined $bankAccount and $bankAccount) {
                    # will always come back with at least the default account
                    $bankCode     = $bankAccount->getBankCode;
                    $accountNo    = $bankAccount->getAccountNo;
                    $accountName  = $bankAccount->getAccountName;
                    $mpEmail      = $bankAccount->getMPEmail;
                    $entityTypeID = $bankAccount->getTypeID;
                    $entityID     = $bankAccount->getEntityID;
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

                updatePostings($isMassPay, $mpEmail, $bankCode, $accountNo, $accountName, $lineValue, \%postingsAccs, \%postingsAmts);
                # even if levelID=0, pass across the club and assoc ids (for reporting purposes)
                updateLog($exportBankFileID, $entityTypeID, $entityID, $assocID, $clubID, $bankCode, $accountNo, $accountName, $mpEmail, $lineValue, 0, $dbh);

            }
		
        }

    }

    # todo: ensure that the number of entries in the hashes is the same...

    if ($isMassPay) {
        my $in = '';

        for my $paymentSplit(@{$paymentSplits}) {
            $in .= $paymentSplit->{intSplitID} . ', ';
        }

        chop($in); # remove trailing space
        chop($in); # remove trailing comma
         
        my $tranList = getTranList($realmID, $in, $dbSysDate, $paymentType, $dbh);
        return ($ruleID, \%postingsAmts, $exportBankFileID, $exportAmt, $tranList)
    }

    # at this point, it must be  a DirectEntry rule

    my ($splitCount, $exportString) = doDirectEntryExport($ruleID, \%postingsAmts, \%postingsAccs, $exportBankFileID, $exportAmt, $dbh);

    # now mark the trans as having been processed
    for my $paymentSplit(@{$paymentSplits}) {
        # process each split in turn
        my $splitID = $paymentSplit->{'intSplitID'};
	next if ! $splitID;
        updateTXNs($exportBankFileID, $realmID, $splitID, $dbSysDate, $paymentType, $dbh);
    }
        
    my ($year,$month,$day) = Today();
    $month = sprintf("%02d", $month);
    $day = sprintf("%02d", $day);
    my $date1 = qq[$year$month$day];
    my $date2 = qq[$day-$month-$year];
    my $message = qq[
The attached file has been run on $date2, it contains the bank splits for transactions up to (but not including the $date2). 

The file contains $splitCount bank splits covering $tranCount unique credit card transaction(s).
];
    if ($splitCount) {
        my $dir        = $Defs::bank_export_dir.$ruleID || '';
        my $dir_web    = $ruleID || '';
        my $filename   = $exportBankFileID . '_' . $date2 . '_export.txt';
        $filename    ||= '';
        my $fname      = "$dir/$filename" || '';
        my $fnameWeb   = "$dir_web/$filename" || '';
        my $fileHandle = new FileHandle;
        my @errors     = ();
        open $fileHandle, ">>$fname" || push @errors, "Cannot open file $fname";
        my $fileOpen   = 0;
        $fileOpen      = 1 if !@errors;
        print $fileHandle qq[$exportString] if $fileOpen;
        close $fileHandle if $fileOpen;

        updateExportBankFile($fnameWeb, $exportBankFileID, $dbh);

        my $ruleName = $rule->getRuleName;

        emailExport($exportString, $email, 'info@sportingpulse.com', qq[$ruleName- $date1], $filename, $message) if $email;
    }

    return $splitCount;
}


sub doPaymentSplitTxnUpdate {
    my ($Data, $exportBankFileID, $tranList) = @_;

    return if !$exportBankFileID or !$tranList;

    my $sql = qq[
        UPDATE 
            tblTransactions
        SET 
            intExportAssocBankFileID=$exportBankFileID
        WHERE 
            intTransactionID=?
            AND intExportAssocBankFileID=0
    ];

    my $query = $Data->{'db'}->prepare($sql);

    foreach my $tran(@$tranList) {
        foreach my $tranID (@$tran) {
            $query->execute($tranID);
        }
    }

    return;
}


sub getTranList {
    my ($realmID, $in, $dbSysDate, $paymentType, $dbh) = @_;

    my $sql = qq[
        SELECT
            t.intTransactionID
        FROM
            tblTransactions t
            INNER JOIN tblTransLog tl ON tl.intLogID=t.intTransLogID
            INNER JOIN tblProducts p ON t.intProductID=p.intProductID
        WHERE 
            p.intPaymentSplitID IN ($in)
            AND tl.intPaymentType=$paymentType
            AND tl.dtSettlement<'$dbSysDate'
            AND t.intStatus IN (1, 2)
            AND tl.intStatus IN (1)
            AND t.intRealmID=$realmID
            AND t.intExportAssocBankFileID=0
    ];

    my $query = $dbh->prepare($sql);
    $query->execute;
    my $tranList = $dbh->selectall_arrayref($sql);

    return $tranList;
}
 

sub getSubTypeID {
    my ($Data, $assocID) = @_;

    my $sql = qq[
        SELECT 
            n.intSubTypeID
        FROM 
            tblAssoc_Node an
        LEFT JOIN 
            tblNode n ON n.intNodeID=an.intNodeID
        WHERE
            an.intAssocID=$assocID;
    ];

    my $query = $Data->{'db'}->prepare($sql);
    $query->execute();

    my ($subTypeID) = $query->fetchrow_array();
    $subTypeID ||= 0;

    return $subTypeID;
}


sub getLevelsUp {
    my ($Data, $clubID, $assocID) = @_;
    my $tblName;
    my $colName;
    my $entityID;

    if ($clubID) {
        $tblName  = 'tblAssoc_Clubs';
        $colName  = 'intClubID';
        $entityID = $clubID;
    }
    else {
        $tblName  = 'tblAssoc';
        $colName  = 'intAssocID';
        $entityID = $assocID;
    }
     
    my $sql = qq[
        SELECT 
            z.intNodeID AS zoneID,
            r.intParentNodeID AS regionID,
            s.intParentNodeID AS stateID,
            n.intParentNodeID AS natID
        FROM 
            $tblName a
        left join tblAssoc_Node z ON z.intAssocID=a.intAssocID
        left join tblNodeLinks r ON r.intChildNodeID=z.intNodeID
        left join tblNodeLinks s ON s.intChildNodeID=r.intParentNodeID
        left join tblNodeLinks n ON n.intChildNodeID=s.intParentNodeID
        WHERE
            a.$colName=$entityID;
    ];

    my $query = $Data->{'db'}->prepare($sql);
    $query->execute();
    my ($zoneID, $regionID, $stateID, $natID) = $query->fetchrow_array();
    return ($zoneID, $regionID, $stateID, $natID);
}


sub getBankAccount {
    my ($Data, $levelID, $clubID, $assocID, $defaultAccount) = @_;

    my ($zoneID, $regionID, $stateID, $natID) = getLevelsUp($Data, $clubID, $assocID);

    my $dbh = $Data->{'db'};
    my $zLevel = $levelID;
    my $bankAccount;

	### CheckNextLevel is turned on if the system should grab bank account from levels above.
	### Switched off on 29/10/09
    my $checkNextLevel=0;
	
     
    if ($zLevel == $Defs::LEVEL_CLUB) {
        $bankAccount = ($clubID) ? BankAccountObj->load($zLevel, $clubID, $dbh) : '';
        $zLevel = $Defs::LEVEL_ASSOC if !$bankAccount and $checkNextLevel;
    }
    if ($zLevel == $Defs::LEVEL_ASSOC) {
        $bankAccount = BankAccountObj->load($zLevel, $assocID, $dbh);
        $zLevel = $Defs::LEVEL_ZONE if !$bankAccount and $checkNextLevel;
    }
    if ($zLevel == $Defs::LEVEL_ZONE) {
        $bankAccount = BankAccountObj->load($zLevel, $zoneID, $dbh);
        $zLevel = $Defs::LEVEL_REGION if !$bankAccount and $checkNextLevel;
    }
    if ($zLevel == $Defs::LEVEL_REGION) {
        $bankAccount = BankAccountObj->load($zLevel, $regionID, $dbh);
        $zLevel = $Defs::LEVEL_STATE if !$bankAccount and $checkNextLevel;
    }
    if ($zLevel == $Defs::LEVEL_STATE) {
        $bankAccount = BankAccountObj->load($zLevel, $stateID, $dbh);
        $zLevel = $Defs::LEVEL_NATIONAL if !$bankAccount and $checkNextLevel;
    }
    if ($zLevel == $Defs::LEVEL_NATIONAL) {
        $bankAccount = $defaultAccount;
    }

    return $bankAccount;
}


# accum into postings arrays for export when all splits have been processed

sub updatePostings {
    my ($isMassPay, $mpEmail, $bankCode, $accountNo, $accountName, $amount, $postingsAccs, $postingsAmts) = @_;
    my $postingsKey = '';

    if ($isMassPay) {                                  
        $postingsKey = $mpEmail;
    }
    else {
        # insert @@ into key so as to know where to split it later
        $postingsKey = $bankCode . '@@' . $accountNo;
        $postingsAccs->{$postingsKey} = $accountName;
    }
    $postingsAmts->{$postingsKey} += $amount;

    return
}


# accum into postings arrays for export when all splits have been processed

sub updateLog {
    my ($exportBankFileID, $entityTypeID, $entityID, $assocID, $clubID, $bankCode, $accountNo, $accountName, $mpEmail, $amount, $feesType, $dbh) = @_;
    return if !$exportBankFileID;

    my $log = PaymentSplitLogObj->new(
        exportBankFileID => $exportBankFileID,
        entityTypeID     => $entityTypeID,
        entityID         => $entityID,
        assocID          => $assocID,
        clubID           => $clubID,
        bankCode         => $bankCode,
        accountNo        => $accountNo,
        accountName      => $accountName,
        mpEmail          => $mpEmail,
        amount           => $amount,
        feesType         => $feesType
    );

    $log->save($dbh);

    return
}


# create a tblExportBankFile record and return the id

sub getExportBankFileID {
    my ($realmID, $ruleID, $dbh, $exportType) = @_;

	$exportType ||= 0;
    my $sql = qq[
        INSERT INTO tblExportBankFile (
            intBankSplitID, intRealmID, dtRun, intExportType
        )
        VALUES (
            $ruleID, $realmID, NOW(), $exportType
        )
    ];
    my $query = $dbh->prepare($sql);
    $query->execute;
    my $exportBankFileID = $query->{mysql_insertid} || 0;
    return $exportBankFileID;
}

sub updateExportBankFile {
    my ($fnameWeb, $exportBankFileID, $dbh) = @_;
    my $sql = qq[
        UPDATE 
            tblExportBankFile
        SET 
            strFilename = "$fnameWeb"
        WHERE 
            intExportBSID = $exportBankFileID
    ];
    my $query = $dbh->prepare($sql);
    $query->execute;
    return
}


# assign the exportBankFileID to the transctions that have been processed

sub updateTXNs  {
    my ($exportBankFileID, $realmID, $splitID, $dbSysDate, $paymentType, $dbh) = @_;
    
    # although not processed, trans with a zero curamt need to be marked as processed
    my $sql = qq[
        UPDATE 
            tblTransactions t
            INNER JOIN tblTransLog tl ON tl.intLogID=t.intTransLogID
            INNER JOIN tblProducts p ON t.intProductID=p.intProductID
        SET 
            intExportAssocBankFileID=$exportBankFileID
        WHERE 
            p.intPaymentSplitID=$splitID
            AND tl.intPaymentType=$paymentType
            AND t.intStatus IN (1, 2)
	    AND tl.dtLog <= DATE_ADD(CURRENT_DATE(), INTERVAL -63 HOUR)
            AND tl.intStatus IN (1)
            AND t.intRealmID=$realmID
            AND t.intExportAssocBankFileID=0
    ];
            #AND tl.dtSettlement<'$dbSysDate'

    my $query = $dbh->prepare($sql);
    $query->execute;

    return;
}


# subs for the email creation and sending

sub emailExport {
    my ($contents, $emailAddress, $fromAddress, $subject, $filename, $message) = @_;

    if ($emailAddress) {
        my $boundary    = "====r53q6w8sgydixlgfxzdkgkh====";
        my $contentType = qq[multipart/mixed; boundary="$boundary"];
        if ($contents) {
            my $attachment = makeAttachment($contents, $boundary, $filename, '');
            sendEmail($emailAddress, $attachment, $boundary, $contentType, $message, $subject, $fromAddress, '');
        }
    }

    return;
}


sub sendEmail {
    my ($email, $attachment, $boundary, $contentType, $message_str, $subject, $fromAddress, $logFile) = @_;
    $subject ||= "Data Export";
    $fromAddress ||= '';
    
    my $message = qq[This is a multi-part message in MIME format...--];
    $message .= $boundary.qq[
        Content-Type: text/plain
        Content-Disposition: inline
        Content-Transfer-Encoding: binary\n\n
    ];

    my %mail = (
        To => "$email",
        From  => $fromAddress,
        Subject => $subject,
        Message => $message,
        'Content-Type' => $contentType,
        'Content-Transfer-Encoding' => "binary"
    );

    $mail{Message} .= "$message_str\n\n------------------------------------------\n\n" if $message_str;
    $mail{Message} .= "\n\n<$fromAddress>" if $fromAddress;
    $mail{Message} .= $attachment if $attachment;

    if ($mail{To}) {
        if ($logFile) {
            open MAILLOG, ">>$logFile" or print STDERR "Cannot open MailLog $logFile\n";
        }
        if (sendmail %mail) {
            print MAILLOG (scalar localtime()).":BANKSPLIT:$mail{To}:Sent OK.\n" if $logFile;
        }
        elsif ($logFile) {
            print MAILLOG (scalar localtime())." BANKSPLIT:$mail{To}:Error sending mail: $Mail::Sendmail::error \n" ;
        }
        close MAILLOG if $logFile;
    }
    return;
}


sub makeAttachment {
    my ($contents, $boundary, $filename, $delimiter) = @_;

    $delimiter ||= '\t';
    $filename  ||= 'exportbankfile.txt';
    $boundary = '====' . time() . '====' if !$boundary;
    my $top = MIME::Entity->build(Type => "multipart/mixed", Boundary => $boundary);
    $top->attach(
        Data        => $contents,
        Filename    => $filename,
        Disposition => "attachment",
        Encoding    => "quoted-printable",
    );

    my $body = $top->stringify_body;
    $body =~s/\s*This is a multi-part message in MIME format...//g;

    return $body;
}
