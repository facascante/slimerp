#
# $Header: svn://svn/SWM/trunk/web/PMSHold.pm 8251 2013-04-08 09:00:53Z rlee $
#

package PMSHold;
require Exporter;
@ISA = qw(Exporter);
@EXPORT=qw(checkForPMSHolds createPMSMassPayHold updatePMSHolds releasePMSHold finaliseRelease);
@EXPORT_OK=qw(checkForPMSHolds createPMSMassPayHold updatePMSHolds releasePMSHold finaliseRelease);

use strict;
use Reg_common;
use Utils;
use DeQuote;
use CGI qw(param);

use CGI qw(param unescape escape);

sub checkForPMSHolds {

    my ($db, $realmID, $paymentType) = @_;

	$paymentType ||= $Defs::PAYMENT_ONLINEPAYPAL;
    my %Holds=();

    my $st = qq[
        SELECT
            DISTINCT 
							PH.strMassPayEmail, 
							PH.strBSB, 
							PH.strAccNum, 
							PH.strAccName
        FROM
            tblPMSHold as PH
			INNER JOIN tblTransLog as TL ON (		
				TL.intLogID= PH.intTransLogOnHoldID
			)
        WHERE
            PH.intHoldStatus=0
            AND PH.intRealmID=?
			AND TL.intPaymentType=$paymentType
            AND PH.curBalanceToHold>0
    ];

    my $qry= $db->prepare($st) or query_error($st);
    $qry->execute($realmID) or query_error($st);
    my $count=0;
    while (my $dref=$qry->fetchrow_hashref())       {
			my $key = $dref->{strMassPayEmail};
			if ($dref->{strBSB} and $dref->{strAccNum})	{
				$key = $dref->{strBSB} . qq[|] . $dref->{strAccNum} . qq[|] . $dref->{strAccName};
			}
        $Holds{$key}=0 if ! ($Holds{$dref->{strMassPayEmail}} and $paymentType == $Defs::PAYMENT_ONLINEPAYPAL);
        $Holds{$key}=0 if ! ($Holds{$dref->{strBSB}} and $paymentType == $Defs::PAYMENT_ONLINEPAYNAB);
        $Holds{$key}++;
    }

    return \%Holds;
}

sub createPMSMassPayHold    {

    my ($db, $realmID, $exportBankFileID, $email, $totalSending, $paymentType) = @_;

	$paymentType ||= $Defs::PAYMENT_ONLINEPAYPAL;

    my $totalAmount = $totalSending;

	my $qry ='';
	if ($paymentType == $Defs::PAYMENT_ONLINENAB)	{
		my ($bsb, $accNum, $accountName) = split /\|/,$email;
    my $st = qq[
        SELECT
            intPMSHoldingBayID,
            curBalanceToHold,
            curAmountToHold
        FROM
            tblPMSHold
        WHERE
            intRealmID=?
            AND strBSB=?
            AND strAccNum=?
            AND intHoldStatus=0
            AND curBalanceToHold>0
        ORDER BY
            dtHeld
    ];
    $qry= $db->prepare($st) or query_error($st);
    $qry->execute($realmID, $bsb, $accNum) or query_error($st);
	}
	else	{
		my $st = qq[
        SELECT
            intPMSHoldingBayID,
            curBalanceToHold,
            curAmountToHold
        FROM
            tblPMSHold
        WHERE
            intRealmID=?
            AND strMassPayEmail=?
            AND intHoldStatus=0
            AND curBalanceToHold>0
        ORDER BY
            dtHeld
    	];
    	$qry= $db->prepare($st) or query_error($st);
    	$qry->execute($realmID, $email) or query_error($st);
	}
    my $st_ins = qq[
        INSERT INTO tblPMS_MassPayHolds (
            intPMSHoldingBayID,
            curHold,
            intMassPayHeldOnID,
            intRealmID,
            dtHeld
        )
        VALUES (
            ?,
            ?,
            $exportBankFileID,
            $realmID,
            NOW()
        )
    ];
    my $qry_ins= $db->prepare($st_ins) or query_error($st_ins);

    my $totalBeingHeld=0;
    while (my $dref=$qry->fetchrow_hashref())       {
        last if ! $totalAmount;
            my $balanceToHold = 0;
        if ($dref->{'curBalanceToHold'} <= $totalAmount)   {
            $balanceToHold = $dref->{'curBalanceToHold'} || $dref->{'curAmountToHold'} || 0;
        }
        else    {
            $balanceToHold = $totalAmount;
        }
        $totalBeingHeld=$totalBeingHeld+$balanceToHold;
        $totalAmount=$totalAmount-$balanceToHold;
        next if ! $balanceToHold;
        $qry_ins->execute($dref->{'intPMSHoldingBayID'}, $balanceToHold) or query_error($st_ins);
    }

    $totalSending-=$totalBeingHeld;

    return $totalSending;

}

sub updatePMSHolds  {

    my ($db, $realmID, $exportBankFileID, $status) = @_;

    my $st = qq[
        UPDATE 
            tblPMS_MassPayHolds     
        SET
            intHoldStatus=$status
        WHERE
            intMassPayHeldOnID =$exportBankFileID
    ];
    $db->do($st);

    if ($status == 1)   {
        ## Lets update Balance remaining
        my $st = qq[
            SELECT
                DISTINCT intPMSHoldingBayID
            FROM
                tblPMS_MassPayHolds
            WHERE
                intMassPayHeldOnID = ?
                AND intHoldStatus = 1
        ];
        my $qry= $db->prepare($st) or query_error($st);
        $qry->execute($exportBankFileID) or query_error($st);
        while (my $dref=$qry->fetchrow_hashref())       {
            recalculatePMSHold($db, $dref->{'intPMSHoldingBayID'});
        }
}

sub recalculatePMSHold  {

    my ($db, $holdID) = @_;

    my $st = qq[
        SELECT
            SUM(curHold) as HeldAmount
        FROM
            tblPMS_MassPayHolds
        WHERE
            intPMSHoldingBayID= ?
            AND intHoldStatus = 1
    ];
    my $qry= $db->prepare($st) or query_error($st);
    $qry->execute($holdID) or query_error($st);
    my $amountHeld = $qry->fetchrow_array() || 0;

    $st = qq[
        UPDATE
            tblPMSHold
        SET
            curBalanceToHold = curAmountToHold-$amountHeld
        WHERE
            intPMSHoldingBayID = $holdID
        LIMIT 1
    ];
    $db->do($st); 
}
sub releasePMSHold  {
    
    my ($db, $realmID, $paymentType) = @_;

	$paymentType ||= $Defs::PAYMENT_ONLINEPAYPAL;

	my $bsbWHERE = ($paymentType == $Defs::PAYMENT_ONLINENAB) ? qq[ AND PH.strBSB LIKE '08%'] : '';
        
    my $st = qq[
        SELECT 
            PH.intPMSHoldingBayID,
            strMassPayEmail,
						PH.strBSB,
						PH.strAccNum,
						PH.strAccName,
            SUM(curHold) as AmountHeld
        FROM
            tblPMSHold as PH
            INNER JOIN tblPMS_MassPayHolds as MPH ON (
                MPH.intPMSHoldingBayID= PH.intPMSHoldingBayID
				AND MPH.intHoldStatus>0
            )
			INNER JOIN tblTransLog as TL ON (		
				TL.intLogID= PH.intTransLogOnHoldID
			)
        WHERE
            PH.intRealmID=$realmID
            AND PH.intMassPayReturnedOnID = 0
            AND PH.intHoldStatus=2
			AND TL.intPaymentType = $paymentType
			$bsbWHERE
				GROUP BY
					 PH.intPMSHoldingBayID	
        HAVING
            AmountHeld>0
     ];
    my $qry= $db->prepare($st) or query_error($st);
    $qry->execute() or query_error($st);
    my %ReleaseHolds=();
    while (my $dref=$qry->fetchrow_hashref())       {
        $ReleaseHolds{$dref->{'intPMSHoldingBayID'}}{'amountheld'} = $dref->{'AmountHeld'};
        $ReleaseHolds{$dref->{'intPMSHoldingBayID'}}{'email'} = $dref->{'strMassPayEmail'};
        $ReleaseHolds{$dref->{'intPMSHoldingBayID'}}{'bsb'} = $dref->{'strBSB'};
        $ReleaseHolds{$dref->{'intPMSHoldingBayID'}}{'accNum'} = $dref->{'strAccNum'};
        $ReleaseHolds{$dref->{'intPMSHoldingBayID'}}{'accName'} = $dref->{'strAccName'};
    }

    return \%ReleaseHolds;
}

sub finaliseRelease {

    my ($db, $holdID, $realmID, $exportBankFileID) = @_;

    $holdID ||= 0;
    $exportBankFileID ||= 0;
    return if (!$holdID or  !$exportBankFileID);

    my $st = qq[
        UPDATE
            tblPMSHold
        SET
            intMassPayReturnedOnID =$exportBankFileID
        WHERE
            intPMSHoldingBayID=$holdID
            AND intHoldStatus=2
            AND intMassPayReturnedOnID=0
    ];
    $db->do($st);

}





}
