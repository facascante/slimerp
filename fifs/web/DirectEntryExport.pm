#
# $Header: svn://svn/SWM/trunk/web/DirectEntryExport.pm 8251 2013-04-08 09:00:53Z rlee $
#

package DirectEntryExport;

require Exporter;
@ISA       = qw(Exporter);
@EXPORT    = qw(doDirectEntryExport);
@EXPORT_OK = qw(doDirectEntryExport);

use strict;

use lib '.';
use Utils;
use Date::Calc qw(Today);

use PaymentSplitRuleObj;

sub doDirectEntryExport {
    my ($ruleID, $postingsAmts, $postingsAccs, $exportBankFileID, $exportAmt, $dbh) = @_;
    my $rule = PaymentSplitRuleObj->load($ruleID, $dbh);
    my $export = exportHeader($rule->getFinInst, $rule->getUserName, $rule->getUserNo, $rule->getFileDesc);
    my $expRef1 = $rule->getRefPrefix . qq[E]. $exportBankFileID;
    my $expRef2 = $rule->getRefPrefix . "EFILE$exportBankFileID";

    # now process the postings hashes

    my @bcan         = ();
    my $bankCode     = '';
    my $accountNo    = '';
    my $accountName  = '';
    my $postingsKey  = '';
    my $splitCount   = 0;

    foreach $postingsKey (keys %$postingsAmts) {
        my $lineValue = $postingsAmts->{$postingsKey} || 0;

        if ($lineValue) {
            @bcan        = split(/@@/, $postingsKey);
            $bankCode    = $bcan[0];
            $accountNo   = $bcan[1];
            $accountName = $postingsAccs->{$postingsKey};
						$lineValue =  sprintf("%.2f", $lineValue);
            $export     .= exportLine($rule->getFinInst, $bankCode, $accountNo, $rule->getTransCode, $lineValue, $accountName, $expRef1, $rule->getRemitter, $rule->getBSB, $rule->getAccountNo);
            $splitCount++;
        }
    }

    $export .= exportFooter($rule->getFinInst, $exportAmt, $splitCount, $rule->getBSB, $rule->getAccountNo, $rule->getUserName, $expRef2, $rule->getRemitter);

    return ($splitCount, $export);
}

sub exportHeader {
    my ($finInst, $userName, $userNo, $desc) = @_;
    my $blank1 = pack "A17", "";
    my $blank2 = pack "A7", "";
    my $blank3 = pack "A40", "";

    $userName  = pack "A26", $userName;
    $userNo    = sprintf("%06s", $userNo);
    $desc      = pack "A12", $desc;

    my ($year, $month, $day) = Today();
    $year      =~ s/20// if ($year =~ /^20\d\d/);
    $month     = sprintf("%02s", $month);
    $day       = sprintf("%02s", $day);
    my $body   = qq[0] . $blank1 . qq[01] . $finInst . $blank2 . $userName . $userNo . $desc . qq[$day$month$year] . $blank3 . qq[\r\n];

    return $body;
}


sub exportLine {
    my ($finInst, $bsb, $accountNo, $transCode, $amount, $accountName, $expRef, $remitter, $fromBSB, $fromAccountNo) = @_;

    $accountNo     =~ s/\-// if ($accountNo !~ /^0/);
    $accountNo     = sprintf("%9s", $accountNo);
    $fromAccountNo =~ s/\-// if ($fromAccountNo !~ /^0/);
    $fromAccountNo = sprintf("%9s", $fromAccountNo);
    $transCode     = sprintf("%02s", $transCode);
    $accountName   = pack "A32", $accountName;
    $amount        = $amount * 100;
    $amount        = sprintf("%010s", $amount);
    $expRef        = pack "A18", $expRef;
    $remitter      = pack "A16", $remitter;
$bsb=~ s/(\d{3})/$1\-/ if ($bsb !~ /\-/);

    my $body       = qq[1] . $bsb . $accountNo . qq[ ] . $transCode . $amount . $accountName . $expRef . $fromBSB . $fromAccountNo . $remitter . qq[00000000] . qq[\r\n];

    return $body;
}


sub exportFooter    {
    my ($finInst, $amount, $splitCount, $bsb, $accountNo, $userName, $expRef, $remitter) = @_;

    $accountNo         =~ s/\-// if ($accountNo !~ /^0/);
    $accountNo         = sprintf("%9s", $accountNo);
    my $blank1      = pack "A12", "";
    my $blank2      = pack "A24", "";
    my $blank3      = pack "A40", "";
    $splitCount++;
    $splitCount     = sprintf("%06d", $splitCount);
    $amount         = $amount * 100;
    $amount         = sprintf("%010s", $amount);
    my $debitAmount = sprintf("%010s", 0);
    $remitter       = pack "A16", $remitter;
    $userName       = pack "A32", $userName;
    $expRef          = pack "A18", $expRef;

    my $balancing   = q[1] . $bsb . $accountNo . qq[ ] . qq[13]. $amount . $userName. $expRef . $bsb . $accountNo . $remitter . qq[00000000] . qq[\r\n];
    my $body        = qq[7999-999] . $blank1 . $debitAmount. $amount . $amount . $blank2 . $splitCount . $blank3;
    return qq[$balancing$body];
}


1;
