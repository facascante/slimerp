#
# $Header: svn://svn/SWM/trunk/web/BankFileExport.pm 9492 2013-09-10 05:17:12Z tcourt $
#

package BankFileExport;

require Exporter;
@ISA       = qw(Exporter);
@EXPORT    = qw(handleBankFileExport);
@EXPORT_OK = qw(handleBankFileExport);

use strict;
use CGI qw(param unescape escape);

use lib '.';
use Reg_common;
use Defs;
use Utils;
use AuditLog;
use Date::Calc qw(Today);
use Mail::Sendmail;
use MIME::Entity;
use FileHandle;

use PaymentSplitRuleObj;
use PaymentSplitObj;
use PaymentSplitFeesObj;
use PaymentSplitItemObj;
use BankAccountObj;


sub handleBankFileExport {
    my ($action, $Data) = @_;

    my $client = setClient($Data->{'clientValues'}) || '';

    my $resultHTML = '';
    my $title      = '';

    if ($action =~ /^BFE_opt/) {
        ($resultHTML, $title) = get_options($Data, $client);
    }
    elsif ($action =~ /^BFE_run/) {
        ($resultHTML, $title) = do_export($Data, $client);
    }
    elsif ($action =~ /^BFE_prev/) {
        ($resultHTML, $title) = view_previous($Data);
    }

    return ($resultHTML,$title);
}


sub view_previous {
    my ($Data) = @_;

    my $sql = qq[
        SELECT 
            e.intExportBSID, 
            bs.strSplitName, 
            e.strFilename, 
            DATE_FORMAT(dtRun, "%d/%m/%Y") as dtRun_FORMATTED
        FROM 
            tblExportBankFile as e 
            INNER JOIN tblBankSplit as bs ON (e.intBankSplitID = bs.intSplitID)
        WHERE 
            bs.intRealmID = $Data->{'Realm'}
        ORDER BY 
            dtRun DESC;
    ];

    my $query = $Data->{'db'}->prepare($sql);
    $query->execute or query_error($sql);

    my $body = qq[
        <table class="listTable"><tr>
            <th>Name</th>
            <th>Date Run</th>
            <th>File</th>
        </tr>
    ];

    my $count = 0;
    while (my $dref = $query->fetchrow_hashref()) {
        $count++;
        $body .= qq[
            <tr>
                <td>$dref->{strSplitName}</td>
                <td>$dref->{dtRun_FORMATTED}</td>
        ];
        my $client = setClient($Data->{'clientValues'}) || '';
        if ($dref->{strFilename}) {
            $body .= qq[
                <td><a target="_blank" href="bank_file.cgi?client=$client&amp;exportbsid=$dref->{intExportBSID}">download file</a></td>];
        }
        else {
            $body .= qq[<td>--no data--</td>];
        }
    }
    
    $body .= qq[</table>];
    $body = qq[<p>No exports found</p>] if !$count;

    return ($body, "Previous Splits");
}


sub get_options {
    my ($Data, $client) = @_;

    my $header = 'Bank File Export';

    my %tempClientValues = getClient($client);
    my $viewText = 'View previous files';

    my $viewFiles = qq[
        <div class="changeoptions">
            <a href="$Data->{'target'}?client=$client&amp;a=BFE_prev&amp;l=$tempClientValues{currentLevel}">
                <img src="images/sml_view_icon.gif" border="0" alt="$viewText" title="$viewText">
            </a>
        </div>
    ];

    $header = $viewFiles.$header;

    my $rules = PaymentSplitRuleObj->getList($Data->{'Realm'}, $Data->{'db'});

    my $selections = '';
   
    for my $dref(@{$rules}) {
        $selections .= qq[
            <option value="$dref->{'intRuleID'}">$dref->{'strRuleName'}</option>
        ];
    }

    my $body = qq[
        <script type="text/javascript">
            function isBlank(s) {
                var c, i;
                if (s == null) return true;
                if (s == '')   return true;
                for (i = 0; i < s.length; i++) {
                    c = s.charAt(i);
                    if ((c != ' ') && (c != '\\n') && (c != '')) return false;
                }
                return true;
            }
            function checkFields() {
                var errMsg = '';
                if (document.getElementById('optRuleID').selectedIndex < 1)
                    errMsg += 'Payment Split Rule must be selected.\\n';
                if (isBlank(document.getElementById('txtEmail').value))
                    errMsg += 'Email address must be specified.\\n';
                if (errMsg) {
                    alert(errMsg);
                    return false;
                }
                return true;
            }
            function formSubmit() {
                if (checkFields()) {
                    if (confirm('Are you sure you want to continue?')) {
                        document.getElementById('btnContinue').disabled = true;
                        return true;
                    }
                }
                return false;
            }
        </script>

        <form action="$Data->{'target'}" method="POST" name="frmOptions" onsubmit="return formSubmit()">
            <p>Select the appropriate <b>rule</b> and adjust the recipient <b>email address</b> (if need be).</b></p><br>
            <p>Press the <b>Continue</b> button when ready to create the export file...</p><br>
            <label class="label": for "optRuleID">Payment Split Rule:</label>
            <select name="ruleID" id="optRuleID">
                <option value=""></option>
                $selections
            </select>
            <br><br>
            <label class="label": for "txtEmail">Email address:</label>
            <input type="text" name="email" id="txtEmail" value="$Data->{'SystemConfig'}{'BankSplit_email'}">
            <input type="hidden" name="a" value="BFE_run">
            <input type="hidden" name="client" value="$client">
            <br><br>
            <input type="submit" name="btnContinue" id="btnContinue" value="Continue">
        </form>
    ];

    return ($body, $header);
}


sub getSubTypeID {
    my ($Data, $assocID1, $assocID2) = @_;

    my $assocID = ($assocID1) ? $assocID1 : $assocID2;

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
    my ($Data, $clubID, $assocID1, $assocID2) = @_;

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
        $entityID = ($assocID1) ? $assocID1 : $assocID2;
    }
     
    my $sql = qq[
        SELECT 
            a.intAssocID AS assocID,
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

    my ($assocID, $zoneID, $regionID, $stateID, $natID) = $query->fetchrow_array();

    return ($assocID, $zoneID, $regionID, $stateID, $natID);
}
 

sub getBankAccount {
    my ($Data, $levelID, $clubID, $assocID1, $assocID2, $defaultAccount) = @_;

    my ($assocID, $zoneID, $regionID, $stateID, $natID) = getLevelsUp($Data, $clubID, $assocID1, $assocID2);

    my $dbh = $Data->{'db'};
    my $zlevel = $levelID;
    my $bankAccount;
     
    if ($zlevel == $Defs::LEVEL_CLUB) {
        $bankAccount = ($clubID) ? BankAccountObj->load($zlevel, $clubID, $dbh) : '';
        $zlevel = $Defs::LEVEL_ASSOC if !$bankAccount;
    }
    if ($zlevel == $Defs::LEVEL_ASSOC) {
        $bankAccount = BankAccountObj->load($zlevel, $assocID, $dbh);
        $zlevel = $Defs::LEVEL_ZONE if !$bankAccount;
    }
    if ($zlevel == $Defs::LEVEL_ZONE) {
        $bankAccount = BankAccountObj->load($zlevel, $zoneID, $dbh);
        $zlevel = $Defs::LEVEL_REGION if !$bankAccount;
    }
    if ($zlevel == $Defs::LEVEL_REGION) {
        $bankAccount = BankAccountObj->load($zlevel, $regionID, $dbh);
        $zlevel = $Defs::LEVEL_STATE if !$bankAccount;
    }
    if ($zlevel == $Defs::LEVEL_STATE) {
        $bankAccount = BankAccountObj->load($zlevel, $stateID, $dbh);
        $zlevel = $Defs::LEVEL_NATIONAL if !$bankAccount;
    }
    if ($zlevel == $Defs::LEVEL_NATIONAL) {
        $bankAccount = $defaultAccount;
    }

    return $bankAccount;
}


sub _getDBSysDate {
    my ($dbh) = @_;
    my $sql   = qq[SELECT SYSDATE()];
    my $query = $dbh->prepare($sql); 
    $query->execute();
    my ($dbSysDate) = $query->fetchrow_array();
    return $dbSysDate;
}


sub do_export {
    my ($Data, $client) = @_;

    my $ruleID = param("ruleID") || 0;
    my $email  = param("email")  || '';

    # untaint the ruleID
    $ruleID =~/(^\d+$)/; 
    $ruleID =$1;

    my $header = 'Bank File Export';
    my $dbh    = $Data->{'db'};

    my $dbSysDate = _getDBSysDate($dbh);

    # ensure default account has been set up
    my $defaultAccount = BankAccountObj->load($Defs::LEVEL_NATIONAL, $Data->{'clientValues'}{'natID'}, $dbh);
    
    if (!$defaultAccount) {
        my $errMsg = qq[
            <div class="warningmsg">
                <p>A default account has not been set up at the National level.</p><br>
                <p>Unable to run export.</p>
            </div>
        ];
        return ($errMsg, $header);
    }

    my $rule = PaymentSplitRuleObj->load($ruleID, $dbh);
    my $realmID = $rule->getRealmID;                          

    my $exportBankFileID = createExportBankFile($Data, $ruleID);
    my $export = exportHeader($rule->getFinInst, $rule->getUserName, $rule->getUserNo, $rule->getFileDesc) . qq[\n]; 

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
            p.intPaymentSplitID = ?
            AND t.curAmount<>0
            AND tl.intPaymentType = $Defs::PAYMENT_ONLINECREDITCARD
            AND tl.dtSettlement<'$dbSysDate'
            AND t.intStatus IN (1,2)
            AND tl.intStatus IN (1)
			AND t.intRealmID = $realmID                         
            AND t.intExportAssocBankFileID = 0
        GROUP BY t.intAssocID, tl.intClubPaymentID, tl.intAssocPaymentID
    ];

    my $query = $dbh->prepare($sql); 
            
    my $splitCount   = 0;
    my $tranCount    = 0;
    my $exportAmt    = 0;
    my $bankAccount  = '';
    my $bankCode     = '';
    my $accountNo    = '';
    my $accountName  = '';
    my %postingsAccs = ();
    my %postingsAmts = ();
    my $postingsKey  = '';
    my $fees         = '';
    my $savSubTypeID = -1;

    for my $paymentSplit(@{$paymentSplits}) {
        # process each split in turn
        my $splitID = $paymentSplit->{'intSplitID'};

        my @items = ();

        my $paymentSplitItems = PaymentSplitItemObj->getList($splitID, $dbh); # and this?

        # set up the splitItems array with the items found for that splitID
        for my $paymentSplitItem(@{$paymentSplitItems}) {
            push @items, {
                'levelID'          => $paymentSplitItem->{'intLevelID'},
                'otherBankCode'    => $paymentSplitItem->{'strOtherBankCode'},
                'otherAccountNo'   => $paymentSplitItem->{'strOtherAccountNo'},
                'otherAccountName' => $paymentSplitItem->{'strOtherAccountName'},
                'amount'           => $paymentSplitItem->{'curAmount'},
                'factor'           => $paymentSplitItem->{'dblFactor'},
                'remainder'        => $paymentSplitItem->{'intRemainder'}
            };
        }

        # execute the query on the transaction file (to get trans for this split)
        $query->execute($splitID);
        
        while (my $tranRef = $query->fetchrow_hashref()) {
            next if $tranRef->{'numTrans'} == 0;

            $tranCount += $tranRef->{'numTrans'};

            my $remainingAmt = $tranRef->{'totAmount'} || next;
            my $clubID       = $tranRef->{'intClubPaymentID'};
            my $assocID1     = $tranRef->{'intAssocPaymentID'};
            my $assocID2     = $tranRef->{'intAssocID'};

            # Get the subTypeID using one of the assocs. Every trans will have an assoc (confirmed by BI)
            my $subTypeID = getSubTypeID($Data, $assocID1, $assocID2);

            if ($subTypeID != $savSubTypeID) {
                $fees = PaymentSplitFeesObj->getList($Data->{'Realm'}, $subTypeID, 1, $dbh);
                $savSubTypeID = $subTypeID;
            }

            for my $fee(@{$fees}) {
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

                # accum into postings arrays for export when all splits have been processed
                # insert @@ into key so as to know where to split it later
                $postingsKey   = $bankCode . '@@' . $accountNo;

                if (!exists $postingsAccs{"$postingsKey"}) {
                    $postingsAccs{"$postingsKey"} = $accountName;
                }

                $postingsAmts{"$postingsKey"} += $feesValue;
            }

            for my $d(@items) {
            
                my $lineValue = 0;

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

               if ($d->{'levelID'} > 0) {
                   $bankAccount = getBankAccount($Data, $d->{'levelID'}, $clubID, $assocID1, $assocID2, $defaultAccount);
                   # will always come back with at least the default account
                   $bankCode    = $bankAccount->getBankCode;
                   $accountNo   = $bankAccount->getAccountNo;
                   $accountName = $bankAccount->getAccountName;
               }
               else {
                   $bankCode    = $d->{'otherBankCode'};
                   $accountNo   = $d->{'otherAccountNo'};
                   $accountName = $d->{'otherAccountName'};
               }

               # accum into postings arrays for export when all splits have been processed
               # insert @@ into key so as to know where to split it later
               $postingsKey = $bankCode . '@@' . $accountNo;

               if (!exists $postingsAccs{"$postingsKey"}) {
                   $postingsAccs{"$postingsKey"} = $accountName;
               }
               $postingsAmts{"$postingsKey"} += $lineValue;
            }
        }
    }

    # ensure that the number of entries in the hashes is the same?

    # now process the postings hashes
    foreach $postingsKey (keys %postingsAccs) {
        my @bcan = split(/@@/, $postingsKey);
        $bankCode     = $bcan[0];
        $accountNo    = $bcan[1];
        $accountName  = $postingsAccs{"$postingsKey"};

        # rounding could be done at this point here (instead of above)
        my $lineValue = $postingsAmts{"$postingsKey"} || next;
           
        my $myRef     = $rule->getRefPrefix . qq[E]. $exportBankFileID;
                
        $splitCount++;

        $export      .= exportLine($rule->getFinInst, $bankCode, $accountNo, $rule->getTransCode, $lineValue, $accountName, $myRef, $rule->getRemitter, $rule->getBSB, $rule->getAccountNo,) . qq[\n];

    }

    for my $paymentSplit(@{$paymentSplits}) {
        # process each split in turn
        my $splitID = $paymentSplit->{'intSplitID'};
        updateTXNs($Data, $exportBankFileID, $realmID, $splitID, $dbSysDate);
    }
        
    my $ref = $rule->getRefPrefix . "EFILE$exportBankFileID";
    $export .= exportFooter(
        $rule->getFinInst,
        $exportAmt, 
        $splitCount, 
        $rule->getBSB,
        $rule->getAccountNo,
        $rule->getUserName,
        $ref, 
        $rule->getRemitter
    );

    my $body = qq[<p class="OKmsg">The Bank split has been run, and emailed to $email</p><br>];

    my ($year,$month,$day) = Today();
    $month = sprintf("%02d", $month);
    $day = sprintf("%02d", $day);
    my $date = qq[$year$month$day];
    my $dateFORMATTED = qq[$day-$month-$year];
    my $message = qq[
The attached file has been run on $dateFORMATTED, it contains the bank splits for transactions up to (but not including the $dateFORMATTED). 

The file contains $splitCount bank splits covering $tranCount unique credit card transaction(s).
];
    if ($splitCount) {
        my $dir       = $Defs::bank_export_dir.$ruleID || '';
        my $dir_web   = $ruleID || '';
        my $filename  = $exportBankFileID . '_' . $dateFORMATTED . '_export.txt';
        $filename ||= '';
        my $fname     = "$dir/$filename" || '';
        my $fname_web = "$dir_web/$filename" || '';

        my $DATAFILE  = new FileHandle;
        my @errors    = ();
        open $DATAFILE, ">>$fname" || push @errors, "Cannot open file $fname";
        my $fileopen = 0;
        $fileopen    = 1 if !@errors;
        print $DATAFILE qq[$export] if $fileopen;
        close $DATAFILE if $fileopen;

        my $st = qq[
            UPDATE 
                tblExportBankFile
            SET 
                strFilename = "$fname_web"
            WHERE 
                intExportBSID = $exportBankFileID
        ];
        $dbh->do($st);
        my $ruleName = $rule->getRuleName;
        my $retval=emailExport($export, $email, 'info@sportingpulse.com', qq[$ruleName- $date], $filename, $message) if $email;
    }
    else {
        $body = qq[<p class="warningmsg">There are no records to be exported.</p><br>];
    }

    return ($body, $header);
}


sub createExportBankFile    {
    my ($Data, $splitID) = @_;

    my $st = qq[
        INSERT INTO tblExportBankFile (
            intBankSplitID, 
            intRealmID, 
            dtRun
        )
        VALUES (
            $splitID,
            $Data->{'Realm'}, 
            NOW()
        )
    ];
    my $query = $Data->{'db'}->prepare($st) or query_error($st);
    $query->execute or query_error($st);

    my $exportID = $query->{mysql_insertid} || 0;

    return $exportID;
}


###
# Once the transctions have been exported to a file and have been given an $exportBankFileID, lets assign it to the matching Transactions.
# Useful for future reporting.
###

sub updateTXNs  {
    my ($Data, $exportBankFileID, $realmID, $splitID, $dbSysDate) = @_;
    
    # don't check t.curamt for non-zero as the zero trans, although not processed, need to be marked as processed
    my $st = qq[
        UPDATE 
            tblTransactions t
            INNER JOIN tblTransLog tl ON tl.intLogID=t.intTransLogID
            INNER JOIN tblProducts p ON t.intProductID=p.intProductID
        SET 
            intExportAssocBankFileID=$exportBankFileID
        WHERE 
            p.intPaymentSplitID=$splitID
            AND tl.intPaymentType=$Defs::PAYMENT_ONLINECREDITCARD
            AND tl.dtSettlement<'$dbSysDate'
            AND t.intStatus IN (1,2)
            AND tl.intStatus IN (1)
			AND t.intRealmID = $realmID
            AND t.intExportAssocBankFileID=0
    ];
    my $query = $Data->{'db'}->prepare($st) or query_error($st);
        $query->execute or query_error($st);
}


###
# Build up the file Header.
# $fininst passed to sub incase we need to defer footers per institution.
###

sub exportHeader    {
    my ($fininst, $username, $usernum, $desc) = @_;

    my $blank1 = pack "A17", "";
    my $blank2 = pack "A7", "";
    my $blank3 = pack "A40", "";
    $username  = pack "A26", $username;
    $usernum   = sprintf("%06s", $usernum);
    $desc      = pack "A12", $desc;

    my ($year, $month, $day) = Today();

    $year      =~ s/20// if ($year =~ /^20\d\d/);
    $month     = sprintf("%02s", $month);
    $day       = sprintf("%02s", $day);
    my $date   = qq[$day$month$year];
        
    my $body   = qq[0] . $blank1 . qq[01] . $fininst . $blank2 . $username . $usernum . $desc . $date . $blank3;

    return $body;

}


###
# Build up the detail line.
# $fininst passed to sub in case we need to defer footers per institution.
###

sub exportLine  {
    my ($fininst, $bsb, $accnum, $transcode, $amount, $acctitle, $myref, $remitter, $frombsb, $fromaccnum) = @_;

    $accnum       =~ s/\-// if ($accnum !~ /^0/);
    $accnum       = sprintf("%9s", $accnum);
    $fromaccnum   =~ s/\-// if ($fromaccnum !~ /^0/);
    $fromaccnum   = sprintf("%9s", $fromaccnum);
    $transcode    = sprintf("%02s", $transcode);
    $acctitle = pack "A32", $acctitle;
    $amount       = $amount * 100;
    $amount       = sprintf("%010s", $amount);
    $myref        = pack "A18", $myref;
    $remitter     = pack "A16", $remitter;

    my $trace     = $frombsb . $fromaccnum;

    my $body      = qq[1] . $bsb . $accnum . qq[ ] . $transcode . $amount . $acctitle . $myref . $trace . $remitter . qq[00000000];

    return $body;
}


###
# Build up the footer row.
# $fininst passed to sub in case we need to defer footers per institution.
###

sub exportFooter    {
    my ($fininst, $amount, $splitCount, $bsb, $accnum, $username, $myref, $remitter) = @_;

    $accnum         =~ s/\-// if ($accnum !~ /^0/);
    $accnum         = sprintf("%9s", $accnum);
    my $blank1      = pack "A12", "";
    my $blank2      = pack "A24", "";
    my $blank3      = pack "A40", "";
    $splitCount++;
    $splitCount     = sprintf("%06d", $splitCount);
    $amount         = $amount * 100;
    $amount         = sprintf("%010s", $amount);
    my $debitamount = sprintf("%010s", 0);
    $remitter       = pack "A16", $remitter;
    $username       = pack "A32", $username;
    $myref          = pack "A18", $myref;

    my $balancing   = q[1] . $bsb . $accnum . qq[ ] . qq[13]. $amount . $username. $myref . $bsb . $accnum . $remitter . qq[00000000] . qq[\n];
    my $body        = qq[7999-999] . $blank1 . $debitamount. $amount . $amount . $blank2 . $splitCount . $blank3;
    return qq[$balancing$body];

}


###
# A generic filler sub for spacing
###

sub filler      {
    return sprintf("% $_[0]s",'');
}


###
# Below subs are only for the email creation and sending.
###

sub emailExport {
    my ($data, $email_address, $from_address, $subject, $filename, $message)=@_;

    return 1 if !$email_address;

    my $boundary    = "====r53q6w8sgydixlgfxzdkgkh====";
    my $contenttype = qq[multipart/mixed; boundary="$boundary"];

    if($data)       {
        #There is data in the export
        my $attachment=make_attachment($data, $boundary, $filename, '');
        if (sendEmail($email_address, $attachment, $boundary, $contenttype, $message, $subject, $from_address, '')) {
            #Error Sending Mail
            return -1;
        }
        return 0;
    }
    else    {
        #No Data to export
        return 1;
    }
}


sub sendEmail {
    my ($email, $attachment, $boundary, $contenttype, $message_str, $subject, $from_address, $logfile) = @_;
    $subject ||= "Data Export";
    my $message = qq[This is a multi-part message in MIME format...--];

    $message .= $boundary.qq[
        Content-Type: text/plain
        Content-Disposition: inline
        Content-Transfer-Encoding: binary\n\n
    ];

    $from_address ||= '';
    my %mail = (
        To => "$email",
        From  => $from_address,
        Subject => $subject,
        Message => $message,
        'Content-Type' => $contenttype,
        'Content-Transfer-Encoding' => "binary"
    );
    $mail{Message} .= "$message_str\n\n------------------------------------------\n\n" if $message_str;
    $mail{Message} .= "\n\n<$from_address>" if $from_address;
    $mail{Message} .= $attachment if $attachment;

    my $error = 1;
    if ($mail{To}) {
        if($logfile) {
            open MAILLOG, ">>$logfile" or print STDERR "Cannot open MailLog $logfile\n";
        }
        if (sendmail %mail) {
            print MAILLOG (scalar localtime()).":BANKSPLIT:$mail{To}:Sent OK.\n" if $logfile;
            $error=0;
        }
        else {
            print MAILLOG (scalar localtime())." BANKSPLIT:$mail{To}:Error sending mail: $Mail::Sendmail::error \n" if $logfile;
        }
        close MAILLOG if $logfile;
    }
    return $error;
}


sub make_attachment {
    my($data, $boundary, $filename, $delimiter)=@_;

    $delimiter ||= '\t';
    $filename  ||= 'exportbankfile.txt';
    $boundary = '====' . time() . '====' if !$boundary;
    # Build attachment contents;
    my $contents = $data;
    my $top      = MIME::Entity->build(Type => "multipart/mixed", Boundary => $boundary);
    ### Attach stuff to it:
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


