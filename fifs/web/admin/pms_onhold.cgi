#!/usr/bin/perl -w

#
# $Header: svn://svn/SWM/trunk/web/admin/pms_onhold.cgi 10127 2013-12-03 03:59:01Z tcourt $
#

use strict;
use lib "../..","..",".";
use DBI;
use CGI qw(param unescape escape);
use Defs;
use Utils;
use Defs;
use Date::Calc qw(Today);
use ExportEmailData;
use AdminPageGen;

main();

sub main    {
	my $db    = connectDB();

	my $a= param('a') || 'LIST';
	my $holdID= param('holdID') || 0;
	my $body = qq[<div><a href="pms_onhold.cgi?a=LIST">List Holds</a>&nbsp;|&nbsp;<a href="pms_onhold.cgi?a=ADD">Add Hold</a></div><br>];
	if ($a eq 'DELETE')    {
	    PMS_deleteHold($db, $holdID);
        $a = 'LIST';
    }
	$body .= PMS_listOnHold($db) if ($a eq 'LIST');
	if ($a eq 'UPDATE_HOLD')    {
     	$body .= PMS_updateHold($db, $holdID) if ($a eq 'UPDATE_HOLD');
        $a = 'SHOWHELDS';
    }
	if ($a eq 'SUBMIT_ADD') {
	   $holdID = PMS_addHold($db);
        $a = 'SHOWHELDS';
        if (! $holdID)  {
            $body = qq[ERROR IN ADD - Possible duplicate Hold];
            $a='';
        }
    }

	$body .= PMS_showHelds($db, $holdID) if ($a eq 'SHOWHELDS');
	$body .= PMS_addHoldForm($db, 0) if ($a eq 'ADD');
	$body .= PMS_addHoldForm($db, 1) if ($a eq 'PREVIEW_HOLD');
	disconnectDB($db) if $db;

    	print_adminpageGen($body, "", "");
}

sub PMS_updateHold  {


    my ($db, $holdID) = @_;

    my $status = param('intHoldStatus') || 0;

    my $st = qq[
        UPDATE
            tblPMSHold
        SET 
            intHoldStatus=$status
        WHERE
            intPMSHoldingBayID=$holdID
     ];
     $db->do($st);

     return qq[<p>Record updated</p>];

}

sub PMS_deleteHold  {

    my ($db, $holdID) = @_;

    my $st = qq[
        DELETE
        FROM
            tblPMSHold
        WHERE
            intPMSHoldingBayID=$holdID
            AND curBalanceToHold=curAmountToHold
            AND intMassPayReturnedOnID=0
    ];
    $db->do($st);
}

sub PMS_listOnHold  {

    my ($db) = @_ ;

    my $st = qq[
        SELECT
            PH.*,
            COUNT(MPH.intHoldID) as CountHelds,
            DATE_FORMAT(PH.dtHeld,'%d/%m/%Y') AS DateHeld
        FROM
            tblPMSHold as PH
            LEFT JOIN tblPMS_MassPayHolds as MPH ON (
                MPH.intPMSHoldingBayID = PH.intPMSHoldingBayID
                AND MPH.intHoldStatus=1
            )
        GROUP BY
            PH.intPMSHoldingBayID
        ORDER BY 
            PH.dtHeld
     ];

           
	my $query = $db->prepare($st);
	$query->execute;

    my $count=0;
    my $body = qq[
        <table width="90%" class="listtable">
            <tr>
                <th>&nbsp;</td>
                <th>HOLD ID</td>
                <th>Payment LogID</td>
                <th>Email Account being Held</td>
                <th>Date Hold Applied</td>
                <th>Total Amount to Hold</td>
                <th>Balance to still Hold</td>
                <th>Hold reversed ?</td>
                <th>&nbsp;</td>
            </tr>
    ];
	while (my $dref =$query->fetchrow_hashref())	{
        my $returned = $dref->{'intMassPayReturnedOnID'} ? qq[<span style="color:red;">REVERSED</span>] : 'No';
        my $delete = $dref->{CountHelds} ? '' : qq[<a onclick="return confirm('Are you sure you wish to delet this Hold request?')" href="pms_onhold.cgi?a=DELETE&amp;holdID=$dref->{'intPMSHoldingBayID'}">delete</a>];
        my $countHelds = $delete ? '' : qq[Holds: $dref->{CountHelds}];
        my $balance= ($dref->{curBalanceToHold} > 0) ? qq[\$ $dref->{curBalanceToHold}] : qq[ <span style="color:red;"><b>TOTAL BALANCE HELD</b></span>];
        $body .= qq[
            <tr>
                <td><a href="pms_onhold.cgi?a=SHOWHELDS&amp;holdID=$dref->{'intPMSHoldingBayID'}">details</a></td>
                <td>$dref->{intPMSHoldingBayID}</td>
                <td><a href="pms_search.cgi?d_tlogID=$dref->{intTransLogOnHoldID}&amp;a=RUN">$dref->{intTransLogOnHoldID}</a></td>
                <td>$dref->{strMassPayEmail}</td>
                <td>$dref->{DateHeld}</td>
                <td>\$ $dref->{curAmountToHold}</td>
                <td>$balance</td>
                <td>$returned</td>
                <td>$delete$countHelds</td>
            </tr>
        ];
        $count++;
    }

    $body .= qq[</table>];

    $body = qq[Nothing on Hold] if ! $count;

    return $body;

}

sub PMS_addHoldForm {

    my ($db, $preview) = @_;

    my $email=param('email') || '';
    my $bsb=param('bsb') || '';
    my $accNum=param('accNum') || '';
    my $accName=param('accName') || '';
    my $transLogID = param('tlID') || 0;
    my $amount = param('amount') || 0;
    my $comments = param('comments') || '';

    my $action = 'PREVIEW_HOLD';
    $action = 'SUBMIT_ADD' if $preview;
    my $previewTEXT = $preview ? qq[ PLEASE REVIEW THEN SUBMIT] : '';

    if ($preview and ((! $email and (! $bsb and ! $accNum))or ! $transLogID or ! $amount))   {
        $previewTEXT = qq[YOU MUST FILL IN FIELDS];
        $action = 'PREVIEW_HOLD';
    }
    my $disabled = ''; #$preview ? 'disabled' : '';
    my $submit = $preview ? 'Submit' : 'Preview';

    my $tlBody='';
    if ($transLogID)    {
				my $query='';
				if ($email)	{
        my $st = qq[
            SELECT 
                DISTINCT
                TL.*,
                A.strName as AssocName,
                strRealmName
            FROM
                tblTransLog as TL
                INNER JOIN tblAssoc as A ON (
                    A.intAssocID = intAssocPaymentID
                )
                INNER JOIN tblRealms as R ON (
                    TL.intRealmID=R.intRealmID
                )
                INNER JOIN tblMoneyLog as ML ON (
                    ML.intTransLogID=TL.intLogID
                    AND ML.strMPEmail=?
                )
            WHERE
                TL.intPaymentType=$Defs::PAYMENT_ONLINEPAYPAL
                AND TL.intLogID=?
        ];
	    $query = $db->prepare($st);
	    $query->execute($email, $transLogID);
			}

			if ($bsb and $accNum)	{
			my $st = qq[
            SELECT 
                DISTINCT
                TL.*,
                A.strName as AssocName,
                strRealmName
            FROM
                tblTransLog as TL
                INNER JOIN tblAssoc as A ON (
                    A.intAssocID = intAssocPaymentID
                )
                INNER JOIN tblRealms as R ON (
                    TL.intRealmID=R.intRealmID
                )
                INNER JOIN tblMoneyLog as ML ON (
                    ML.intTransLogID=TL.intLogID
                    AND ML.strBankCode=?
                    AND ML.strAccountNo=?
                )
            WHERE
                TL.intPaymentType=$Defs::PAYMENT_ONLINENAB
                AND TL.intLogID=?
        ];
	    	$query = $db->prepare($st);
	    	$query->execute($bsb, $accNum, $transLogID);
			}




        my $dref=$query->fetchrow_hashref();
        return qq[<div style="font-size:18px;"><b>CANNOT FIND PAYMENT LOG ID - Check ID is valid and that the Email entered is associated with that Payment</b></div> ] if (! $dref->{'intLogID'});
        return qq[<div style="color:red;font-size:18px;"><b>Original purchase price is \$ $dref->{intAmount}<br><br>You cannot place a hold on an amount greater than this</b></div> ] if ($amount > $dref->{'intAmount'});
        if ($dref->{'intLogID'})    {
            $tlBody .= qq[
                <tr>
                    <td>Original Payment to Association:</td>
                    <td>$dref->{'AssocName'}
                </tr>
                <tr>
                    <td>Original Payment Amount:</td>
                    <td>\$ $dref->{'intAmount'}</td>
                </tr>
                <tr>
                    <td>Sport/Realm:</td>
                    <td>$dref->{'strRealmName'}
                </tr>
            ];
        }
        $action = 'PREVIEW_HOLD';
    }


    my $body = '';
    
    if ($preview)   {
    $body = qq[
        <div style="font-size:18px;"><b>$previewTEXT</b></div><br>
		<form name="pms_onhold" action="pms_onhold.cgi" method="post">	
            <table>
                <tr>
                    <td>Email:</td>
                    <td>$email<input type="hidden" name="email" value="$email"></td>
                </tr>
                <tr>
                    <td>BSB:</td>
                    <td>$bsb<input type="hidden" name="bsb" value="$bsb"></td>
                </tr>
                <tr>
                    <td>AccNum:</td>
                    <td>$accNum<input type="hidden" name="accNum" value="$accNum"></td>
                </tr>
                <tr>
                    <td>AccName:</td>
                    <td>$accName<input type="hidden" name="accName" value="$accName"></td>
                </tr>
                <tr>
                    <td>Payment LogID:</td>
                    <td><a href="pms_search.cgi?d_tlogID=$transLogID&amp;a=RUN">$transLogID</a> <input type="hidden" name="tlID" value="$transLogID"></td>
                </tr>
                $tlBody
                <tr>
                    <td>Amount To Hold:</td>
                    <td>\$ $amount<input type="hidden" name="amount" value="$amount"></td>
                </tr>
                <tr>
                    <td>Comments</td>
                    <td>$comments<input type="hidden" name="comments" value="$comments"></td>
                </tr>
            </table>
			<input type="hidden" name="a" value="$action"><br>
			<input type="submit" name="submit" value="$submit">
        </form>
    ];
    }
    else    {
        $body = qq[
        <div style="font-size:18px;">Add Hold</div><br>
		<form name="pms_onhold" action="pms_onhold.cgi" method="post">	
            <table>
                <tr>
                    <td>Email:</td>
                    <td><input type="text" size="50" name="email" value="$email"><img src="../images/compulsory.gif" alt="Compulsory Field" title="Compulsory Field"/></td>
                </tr>
                <tr>
                    <td>BSB:</td>
                    <td><input type="text" size="50" name="bsb" value="$bsb"><img src="../images/compulsory.gif" alt="Compulsory Field" title="Compulsory Field"/></td>
                </tr>
                <tr>
                    <td>AccNum:</td>
                    <td><input type="text" size="50" name="accNum" value="$accNum"><img src="../images/compulsory.gif" alt="Compulsory Field" title="Compulsory Field"/></td>
                </tr>
                <tr>
                    <td>AccName:</td>
                    <td><input type="text" size="50" name="accName" value="$accName"><img src="../images/compulsory.gif" alt="Compulsory Field" title="Compulsory Field"/></td>
                </tr>
                <tr>
                    <td>Payment LogID:</td>
                    <td><input size="10" type="text" name="tlID" value="$transLogID"><img src="../images/compulsory.gif" alt="Compulsory Field" title="Compulsory Field"/></td>
                </tr>
                <tr>
                    <td>Amount To Hold: \$</td>
                    <td><input size="10" type="text" name="amount" value="$amount"><img src="../images/compulsory.gif" alt="Compulsory Field" title="Compulsory Field"/></td
                </tr>
                <tr>
                    <td>Comments</td>
                    <td><textarea rows="4" cols="40" name="comments">$comments</textarea></td>
                </tr>
            </table>

			<input type="hidden" name="a" value="$action"><br>
			<input type="submit" name="submit" value="$submit">
        </form>
    ];
    

    }

    return $body;

}

sub PMS_addHold {


    my ($db) = @_;

    my $email=param('email') || '';
    my $bsb=param('bsb') || '';
    my $accNum=param('accNum') || '';
    my $accName=param('accName') || '';
    my $transLogID = param('tlID') || 0;
    my $amount = param('amount') || 0;
    my $comments = param('comments') || 0;

    my $st = qq[
        INSERT INTO tblPMSHold (
            strMassPayEmail,
            strBSB,
            strAccNum,
            strAccname,
            intRealmID,
            intTransLogOnHoldID,
            curAmountToHold,
            curBalanceToHold,
            dtHeld,
            strHeldComments
        )
        SELECT
            ?,
            ?,
            ?,
            ?,
            intRealmID,
            intLogID,
            ?,
            ?,
            NOW(),
            ?
        FROM tblTransLog 
        WHERE intLogID = ?
    ];

	my $query = $db->prepare($st);
	$query->execute($email, $bsb, $accNum, $accName, $amount, $amount, $comments, $transLogID);
    my $holdID = $query->{mysql_insertid};
    return $holdID;
            

}

sub PMS_showHelds    {
    
    my ($db, $holdID) = @_;

    my $st = qq[
        SELECT
            H.*,
            DATE_FORMAT(dtHeld,'%d/%m/%Y') AS DateHeld,
            strRealmName,
            A.strName as AssocName
        FROM
            tblPMSHold as H
            INNER JOIN tblRealms as R ON (
                R.intRealmID=H.intRealmID
            )
            INNER JOIN tblTransLog as TL ON (
                TL.intLogID=intTransLogOnHoldID
            )
            INNER JOIN tblAssoc as A ON (
                A.intAssocID = intAssocPaymentID
            )
        WHERE
            intPMSHoldingBayID=$holdID
    ];
	my $qry = $db->prepare($st);
	$qry->execute;
	my $hold_ref =$qry->fetchrow_hashref();
     
    $st = qq[
        SELECT
            *,
            DATE_FORMAT(dtHeld,'%d/%m/%Y') AS DateHeld
        FROM
            tblPMS_MassPayHolds
        WHERE
            intPMSHoldingBayID=$holdID
            AND intHoldStatus>=0
    ];
	my $query = $db->prepare($st);
	$query->execute;
    
    my $status = qq[
        <select name="intHoldStatus">
    ];
    my $selected = ($hold_ref->{'intHoldStatus'} == 0) ? 'SELECTED' : '';
    $status .= qq[<option $selected value="0">On Hold</option>];

    $selected = ($hold_ref->{'intHoldStatus'} == 2) ? 'SELECTED' : '';
    $status .= qq[<option $selected value="2">Held Reversed (Return Money)</option>];
    $status .= qq[</select>];

    $status = qq[Money returned <input type="hidden" name="intHoldStatus" value="2">] if ($hold_ref->{'intHoldStatus'} == 2);
	my $submit = ($hold_ref->{'intHoldStatus'} == 2) ? '' : qq[<input type="submit" name="submit" value="Submit Status">];

    my $intMassPayReturnedOnID = ($hold_ref->{'intMassPayReturnedOnID'} > 0) ? "Yes (MassPay: $hold_ref->{'intMassPayReturnedOnID'})" : 'No';
    my $body = qq[
		<form name="pms_onhold" action="pms_onhold.cgi" method="post">	
        <table>
            <tr>
                <td>Hold ID</td>
                <td>$hold_ref->{intPMSHoldingBayID}</td>
            </tr>
            <tr>
                <td>Payment Log ID</td>
                <td><a href="pms_search.cgi?d_tlogID=$hold_ref->{intTransLogOnHoldID}&amp;a=RUN">$hold_ref->{intTransLogOnHoldID}</a></td>
            </tr>
            <tr>
                <td>Sport/Realm</td>
                <td>$hold_ref->{strRealmName}</td>
            </tr>
            <tr>
                <td>Association Original Payment for</td>
                <td>$hold_ref->{AssocName}</td>
            </tr>
            <tr>
                <td>BSB | AccNumber</td>
                <td>$hold_ref->{strBSB} $hold_ref->{strAccNum}</td>
            </tr>
            <tr>
                <td>Email Address</td>
                <td>$hold_ref->{strMassPayEmail}</td>
            </tr>
            <tr>
                <td>Total Money To Hold</td>
                <td>\$ $hold_ref->{curAmountToHold}</td>
            </tr>
            <tr>
                <td>Balance to Hold</td>
                <td>\$ $hold_ref->{curBalanceToHold}</td>
            </tr>
            <tr>
                <td>Date placed on Hold</td>
                <td>$hold_ref->{DateHeld}</td>
            </tr>
            <tr>
                <td>Status</td>
                <td>$status</td>
            </tr>
            <tr>
                <td>Money Returned ?</td>
                <td>$intMassPayReturnedOnID</td>
            </tr>
        </table>
			<input type="hidden" name="a" value="UPDATE_HOLD">
			<input type="hidden" name="holdID" value="$holdID">
            $submit
        </form>
        <br>
        <div style="font-size:18px;color:red;">Held Records</div>
        <table width="80%">
            <tr>
                <td><b>Date Held</b></td>
                <td><b>Amount Held</b></td>
                <td><b>MassPay ID</b></td>
            </tr>
    ];
    my $count=0;
	while (my $dref =$query->fetchrow_hashref())	{
        $body .= qq[
            <tr>
                <td>$dref->{DateHeld}</td>
                <td>\$ $dref->{curHold}</td>
                <td>$dref->{intMassPayHeldOnID}</td>
            </tr>
        ];
        $count++;
    }
    $body .= qq[</table>];


    return $body;

}

1;
