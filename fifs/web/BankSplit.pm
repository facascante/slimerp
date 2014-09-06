#
# $Header: svn://svn/SWM/trunk/web/BankSplit.pm 8251 2013-04-08 09:00:53Z rlee $
#

package BankSplit;

require Exporter;
@ISA =  qw(Exporter);
@EXPORT = qw(handleBankSplit);
@EXPORT_OK = qw(handleBankSplit);

use strict;
use CGI qw(param unescape escape);

use lib '.';
use Reg_common;
use Defs;
use Utils;
use Date::Calc qw(Today);
use Mail::Sendmail;
use MIME::Entity;
use FileHandle;

sub handleBankSplit	{
	my($action, $Data)=@_;

	my $splitID=param("splitID") || 0;
	$splitID =~/(\d+)/;
	$splitID=$1;
	my $email=param("email") || 0;

  	my $resultHTML='';
	my $heading='';

  	if ($action =~ /_$|_list/) {
		($resultHTML,$heading) = displayBankSplits($Data);
  	}
  	elsif ($action =~ /_run/) {
		($resultHTML,$heading) = runSplitFile($Data, $splitID, $email);
  	}
  	elsif ($action =~ /_showlist/) {
		($resultHTML,$heading) = showRunSplits($Data);
  	}
  	return ($resultHTML,$heading);

}


sub displayBankSplits	{

###
# Bank Split Menu
###

	my ($Data) = @_;

	my $client=setClient($Data->{'clientValues'}) || '';

	my $st = qq[
		SELECT 
			intSplitID, 
			strSplitName
		FROM 
			tblBankSplit
		WHERE 
			intRealmID = $Data->{Realm}
		ORDER BY 
			strSplitName
	];
	my $query = $Data->{'db'}->prepare($st) or query_error($st);
    	$query->execute or query_error($st);

	my $body = qq[
		<form action="$Data->{'target'}" method="POST" tyle="float:left;" onsubmit="document.getElementById('btnsubmit').disabled=true;return true;">
		<p><b>Please select a Bank Export and fill in the email address.</b></p>
		<table>
		<tr><td>Bank Split</td><td><select name="splitID"><option value="">--Select Bank Export--</option>
	];
	while (my $dref = $query->fetchrow_hashref())	{
		$body .= qq[
			<option value="$dref->{intSplitID}">$dref->{strSplitName}</option>
		];
	}
	$body .= qq[
		</select></td></tr>
		<tr><td>Email address for Export file:</td><td><input type="text" name="email" value="$Data->{'SystemConfig'}{'BankSplit_email'}" size="50"></td></tr>
		</table>
		<input type="hidden" name="a" value="BANKSPLIT_run">
                <input type="hidden" name="client" value="$client">
		<input type="submit" name="submit" id="btnsubmit" value="Run export">
		</form>
		<br><br>
		<form action="$Data->{'target'}" method="POST" tyle="float:left;" onsubmit="document.getElementById('btnlistsubmit').disabled=true;return true;">
		<input type="hidden" name="a" value="BANKSPLIT_showlist">
                <input type="hidden" name="client" value="$client">
		<input type="submit" id="btnlistsubmit" name="submit" value="View previous files">
		</form>
	];
	return ($body, "Bank Export");
}

sub showRunSplits	{

###
# When the "View previous files' button is run
###
	my ($Data) = @_;


	my $st = qq[
		SELECT 
			E.intExportBSID, 
			BS.strSplitName, 
			E.strFilename, 
			DATE_FORMAT(dtRun, "%d/%m/%Y") as dtRun_FORMATTED
		FROM 
			tblExportBankFile as E 
			INNER JOIN tblBankSplit as BS ON (E.intBankSplitID = BS.intSplitID)
		WHERE 
			BS.intRealmID = $Data->{'Realm'}
		ORDER BY 
			dtRun DESC
	];

	my $query = $Data->{'db'}->prepare($st) or query_error($st);
    	$query->execute or query_error($st);

	my $body = qq[
		<table class="listTable"><tr>
			<th>Name</th>
			<th>Date Run</th>
			<th>File</th>
		</tr>
	];

	my $count=0;
	while (my $dref= $query->fetchrow_hashref())	{
		$count++;
		$body .= qq[
			<tr>
				<td>$dref->{strSplitName}</td>
				<td>$dref->{dtRun_FORMATTED}</td>
		];
	my $client=setClient($Data->{'clientValues'}) || '';
		if ($dref->{strFilename})	{
			$body .= qq[
				<td><a target="_blank" href="bank_file.cgi?client=$client&amp;exportbsid=$dref->{intExportBSID}">download file</a></td>];
		}
		else	{
			$body .= qq[<td>--no data--</td>];
		}
	}
	
	$body .= qq[
		</table>
	];

	$body = qq[<p>No exports found</p>] if ! $count;


	return ($body, "Previous Splits");

}


sub runSplitFile	{

###
# Run the split.
###
	my ($Data, $splitID, $email) = @_;

	$splitID ||= 0;
	$email ||= '';

	return (qq[<p class="warningmsg">Please select a Bank Export and type in an email address</p>], "Bank Export") if (! $splitID or ! $email);

	my $export='';

###
# Lets get the details for the selected Split
###
	my $bank_st = qq[
		SELECT 
			*
		FROM 
			tblBankSplit
		WHERE 
			intSplitID =$splitID
	];
	my $query = $Data->{'db'}->prepare($bank_st) or query_error($bank_st);
    	$query->execute or query_error($bank_st);

	my $bref=$query->fetchrow_hashref();

	
	return ("Error with Split selected", "Bank Split") if ! ref $bref;

###
# Get the line rules to run for the split.  Order by intClubID first to do club splits (if configured)
###
	my $st = qq[
		SELECT 
			*
		FROM 
			tblAssocBankSplit
		WHERE 
			intSplitID = $splitID
		ORDER BY 
			intClubID DESC, 
			intAssocID
	];
	$query = $Data->{'db'}->prepare($st) or query_error($st);
    	$query->execute or query_error($st);

###
# Lets get the Transactions that match the intClubID/intAssocID/intProductID from the line rules.
###
	my $trans_st = qq[
		SELECT 
			SUM(curAmount) as SumAmount, 
			COUNT(intTransactionID) as CountOfID
		FROM 
			tblTransactions as T
			INNER JOIN tblTransLog as TL ON (TL.intLogID = T.intTransLogID)
		WHERE 
			T.intAssocID = ?
			AND T.intProductID = ?
			AND TL.intClubPaymentID IN (?)
			AND TL.intPaymentType = $Defs::PAYMENT_ONLINECREDITCARD
			AND TL.dtSettlement < SYSDATE()
			AND T.intStatus IN (1,2)
			AND TL.intStatus IN (1)
			AND T.intRealmID = $Data->{'Realm'}
			AND T.curAmount >= ?
			AND T.intExportAssocBankFileID = 0
	];
	my $trans_qry= $Data->{'db'}->prepare($trans_st) or query_error($trans_st);

	my $count=0;
	my $count_txns=0;
	my %ExportData = ();
	
	my $export_amount = 0;

###
# Log ExportBankFile and generate a header
###
	my $intExportBankFileID = createExportBankFile($Data, $splitID);
	$export .= exportHeader($bref->{strFILE_Header_FinInst}, $bref->{strFILE_Header_UserName}, $bref->{strFILE_Header_UserNumber}, $bref->{strFILE_Header_Desc}) . qq[\n];

###
# Loop the line rules
###
	while (my $ABS_ref=$query->fetchrow_hashref())	{
    		$trans_qry->execute($ABS_ref->{intAssocID}, $ABS_ref->{intProductID}, $ABS_ref->{intClubID}, $ABS_ref->{curMinAmountCheck}) or query_error($trans_st);
	
	###
	# Get the Transactions that match the line rules and do the splits
	# NOTE: Probably doesn't need to be a loop below.
	###
		while (my $tref = $trans_qry->fetchrow_hashref())	{
			next if $tref->{CountOfID} == 0;
			$count_txns += $tref->{CountOfID}; ##++ if $i ==1;
			my $intExportABFID= createExportAssocBankFile($Data, $ABS_ref, $intExportBankFileID);
			my $txn_amount_left= $tref->{SumAmount} || next;
			for my $i (1 .. 6)	{
				next if ($ABS_ref->{"strBSB_$i"} eq '');
				$count++;
			
				my $line_amount = $ABS_ref->{"curAmount_$i"} * $tref->{CountOfID};
				if ($ABS_ref->{"dblMultiFactor_$i"} == 1)	{
					$txn_amount_left -= ($ABS_ref->{"curAmount_$i"} * $tref->{CountOfID}) if ($ABS_ref->{"curAmount_$i"} > 0);
					$line_amount = $txn_amount_left if ($ABS_ref->{"intUseRemainder_$i"});
				}

				### BELOW ARE THE NEW LINES FOR % SPLIT !
				if ($ABS_ref->{"dblMultiFactor_$i"} and $ABS_ref->{"dblMultiFactor_$i"} < 1)	{
					$line_amount = $tref->{'SumAmount'} * $ABS_ref->{"dblMultiFactor_$i"};
					if ($ABS_ref->{"intMultiApplyOn_$i"} == 2)	{ ##APPLY ON REMAINDER !
						$line_amount = $txn_amount_left * $ABS_ref->{"dblMultiFactor_$i"};
					}
					$line_amount = sprintf("%.2f", $line_amount);
					$txn_amount_left -= $line_amount;
				}
				### END % SPLIT - 24/12/2008

				$export_amount += $line_amount;

				 my $myRef = $ABS_ref->{"strFILE_RefPrefix_$i"} . qq[E]. $intExportABFID;
				$export .= exportLine($bref->{strFILE_Header_FinInst}, $ABS_ref->{"strBSB_$i"}, $ABS_ref->{"strAccountNum_$i"}, $ABS_ref->{"strFILE_TransCode_$i"}, $line_amount, $ABS_ref->{"strFILE_AccountTitle_$i"}, $myRef, $ABS_ref->{"strFILE_RemitterName_$i"}, $ABS_ref->{"strFromBSB_$i"}, $ABS_ref->{"strFromAccountNum_$i"}) . qq[\n];
			}
			updateTXNs($Data, $intExportABFID, $ABS_ref);
		}
	}

	my $ref = "$bref->{strFILE_Footer_RefPrefix}EFILE$intExportBankFileID";
	$export .= exportFooter($bref->{strFILE_Header_FinInst}, $export_amount, $count, $bref->{strFILE_Footer_BSB},$bref->{strFILE_Footer_AccountNum}, $bref->{strFILE_Header_UserName}, $ref, $bref->{strFILE_Footer_Remitter} );

	
	my $body = qq[<p class="OKmsg">The Bank split has been run, and emailed to $email</p><br>];
	my ($year,$month,$day) = Today();
        $month = sprintf("%02d", $month);
        $day = sprintf("%02d", $day);
	my $date = qq[$year$month$day];
	my $dateFORMATTED = qq[$day-$month-$year];
	my $message = qq[
The attached file has been run on $dateFORMATTED, it contains the bank splits for transactions up to (but not including the $dateFORMATTED). 

The file contains $count bank splits covering $count_txns unique credit card transaction(s).
];
	if ($count)	{
		### WRITE FILE TO DIRECTORY
		my $dir=$Defs::bank_export_dir.$splitID || '';
		my $dir_web=$splitID || '';
		$dir ||= '';
		my $filename = $intExportBankFileID."_" . $dateFORMATTED . "_export.txt";
		$filename ||= '';
		my $fname="$dir/$filename" || '';
		my $fname_web="$dir_web/$filename" || '';

		my $DATAFILE = new FileHandle;
		my @errors=();
                open $DATAFILE, ">>$fname" || push @errors, "Cannot open file $fname";
		my $fileopen=0;
                $fileopen=1 if !@errors;
		print $DATAFILE qq[$export] if $fileopen;
		close $DATAFILE if $fileopen;

		my $st = qq[
			UPDATE 
				tblExportBankFile
			SET 
				strFilename = "$fname_web"
			WHERE 
				intExportBSID = $intExportBankFileID
		];
		$Data->{'db'}->do($st);
		my $retval=emailExport($export, $email, 'info@sportingpulse.com', qq[$bref->{strSplitName}- $date], $filename, $message) if $email;
	}
	else	{
		$body = qq[<p class="warningmsg">There are no records to be exported.</p><br>];
	}
	return ($body, "Bank Split");
}

sub createExportBankFile	{

###
# Lets log the fact we are doing a run
###
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

sub createExportAssocBankFile	{

###
# Create an entry in the tblExportAssocBankFile, one per Assoc/Club/Product key
###
	my ($Data, $ABS_ref, $exportBankFileID) = @_;

	
	my $st = qq[
		INSERT INTO tblExportAssocBankFile (
			intSplitID, 
			intExportBankFileID, 
			intRealmID, 
			intAssocID, 
			intProductID, 
			intClubID, 
			dtRun
		)
		VALUES (
			$ABS_ref->{intSplitID}, 
			$exportBankFileID, 
			$Data->{'Realm'}, 
			$ABS_ref->{intAssocID}, 
			$ABS_ref->{intProductID}, 
			$ABS_ref->{intClubID}, 
			NOW()
		)
	];
	my $query = $Data->{'db'}->prepare($st) or query_error($st);
    	$query->execute or query_error($st);
	my $exportID = $query->{mysql_insertid} || 0;

	return $exportID;
}

sub updateTXNs	{

###
# Once the transctions have been exported to a file and have been given an $intExportAssocBankFileID, lets assign it to the matching Transactions.
# Useful for future reporting.
###
	my ($Data, $intExportAssocBankFileID, $ABS_ref) = @_;
	
	my $st = qq[
		UPDATE 
			tblTransactions as T
			INNER JOIN tblTransLog as TL ON (TL.intLogID = T.intTransLogID)
		SET 
			intExportAssocBankFileID = $intExportAssocBankFileID
		WHERE 
			intProductID = $ABS_ref->{intProductID}
			AND intAssocID = $ABS_ref->{intAssocID}
			AND TL.intClubPaymentID IN ($ABS_ref->{intClubID})
			AND T.intStatus IN (1,2)
			AND TL.intStatus IN (1)
			AND T.curAmount >= $ABS_ref->{curMinAmountCheck}
			AND TL.intPaymentType = $Defs::PAYMENT_ONLINECREDITCARD
			AND TL.dtSettlement < SYSDATE()
			AND T.intRealmID = $Data->{'Realm'}
			AND T.intExportAssocBankFileID = 0
	];
	my $query = $Data->{'db'}->prepare($st) or query_error($st);
    	$query->execute or query_error($st);
}

sub exportHeader	{

###
# Build up the file Header.
# $fininst passed to sub incase we need to defer footers per institution.
###
	my ($fininst, $username, $usernum, $desc) = @_;

	#my $blank1 = filler(17); 
	#my $blank2 = filler(7); 
	#my $blank3 = filler(40); 
	my $blank1 = pack "A17", "";
	my $blank2 = pack "A7", "";
	my $blank3 = pack "A40", "";
	$username= pack "A26", $username;
	#$usernum= sprintf("%06d", $usernum);
	$usernum= sprintf("%06s", $usernum);
	$desc= pack "A12", $desc;

	my ($year,$month,$day) = Today();
	$year =~ s/20// if ($year =~ /^20\d\d/);
       	#$month = sprintf("%02d", $month);
       	#$day = sprintf("%02d", $day);
       	$month = sprintf("%02s", $month);
       	$day = sprintf("%02s", $day);
	my $date = qq[$day$month$year];
		
	my $body = qq[0] . $blank1 . qq[01] . $fininst . $blank2 . $username . $usernum . $desc . $date . $blank3;

	return $body;

}

sub exportLine	{

###
# Build up the detail line.
# $fininst passed to sub incase we need to defer footers per institution.
###
	my ($fininst, $bsb, $accnum, $transcode, $amount, $accounttitle, $myref, $remitter, $frombsb, $fromaccnum) = @_;

	$accnum =~ s/\-// if ($accnum !~ /^0/);
	$accnum= sprintf("%9s", $accnum);
	$fromaccnum =~ s/\-// if ($fromaccnum !~ /^0/);
	$fromaccnum= sprintf("%9s", $fromaccnum);
	#$transcode= sprintf("%02d", $transcode);
	$transcode= sprintf("%02s", $transcode);
	$accounttitle = pack "A32", $accounttitle;
	$amount = $amount * 100;
#### BELOW WAS: %010d !!!!
	$amount = sprintf("%010s", $amount);
	$myref= pack "A18", $myref;
	$remitter= pack "A16", $remitter;

	my $trace= $frombsb . $fromaccnum;

	my $body = qq[1] . $bsb . $accnum . qq[ ] . $transcode . $amount . $accounttitle . $myref . $trace . $remitter . qq[00000000];

	return $body;
}

sub exportFooter	{

###
# Build up the footer row.
# $fininst passed to sub incase we need to defer footers per institution.
###
	my ($fininst, $amount, $count, $bsb, $accnum, $username, $myref, $remitter) = @_;

	$accnum =~ s/\-// if ($accnum !~ /^0/);
	$accnum= sprintf("%9s", $accnum);
	my $blank1 = pack "A12", "";
	my $blank2 = pack "A24", "";
	my $blank3 = pack "A40", "";
	#my $blank1 = filler(12); 
	#my $blank2 = filler(24); 
	#my $blank3 = filler(40); 
	$count++;
	$count = sprintf("%06d", $count);
	$amount = $amount * 100;
	#$amount = sprintf("%010d", $amount);
	#my $debitamount = sprintf("%010d", 0);
	$amount = sprintf("%010s", $amount);
	my $debitamount = sprintf("%010s", 0);
	$remitter= pack "A16", $remitter;
	$username= pack "A32", $username;
	$myref= pack "A18", $myref;

	my $balancing = q[1] . $bsb . $accnum . qq[ ] . qq[13]. $amount . $username. $myref . $bsb . $accnum . $remitter . qq[00000000] . qq[\n];
	my $body = qq[7999-999] . $blank1 . $debitamount. $amount . $amount . $blank2 . $count . $blank3;
	return qq[$balancing$body];

}


sub filler      {
###
# A generic filler sub for spacing
###

        return sprintf("% $_[0]s",'');
}

###
# Below subs are only for the email creation and sending.
###

sub emailExport {
        my ($data, $email_address, $from_address, $subject, $filename, $message)=@_;

        return 1 if !$email_address;

        my $boundary="====r53q6w8sgydixlgfxzdkgkh====";
        my $contenttype=qq[multipart/mixed; boundary="$boundary"];

        if($data)       {
                #There is data in the export
                my $attachment=make_attachment($data, $boundary, $filename, '');
                if(sendEmail($email_address, $attachment, $boundary, $contenttype, $message, $subject, $from_address, ''))      {
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

#---- Subroutines ----

sub sendEmail   {
        my ($email, $attachment, $boundary, $contenttype, $message_str, $subject, $from_address, $logfile)=@_;
        $subject||="Data Export",
        my $message=qq[

This is a multi-part message in MIME format...

--].$boundary.qq[
Content-Type: text/plain
Content-Disposition: inline
Content-Transfer-Encoding: binary\n\n];

        $from_address||='';
        my %mail = (
                                                To => "$email",
                                                From  => $from_address,
                                                Subject => $subject,
                                                Message => $message,
                                                'Content-Type' => $contenttype,
                                                'Content-Transfer-Encoding' => "binary"
        );
        $mail{Message}.="$message_str\n\n------------------------------------------\n\n" if $message_str;
        $mail{Message}.="\n\n<$from_address>" if $from_address;
        $mail{Message}.=$attachment if $attachment;

        my $error=1;
        if($mail{To}) {
                if($logfile)    {
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


sub make_attachment     {

        my($data, $boundary, $filename, $delimiter)=@_;

        $delimiter||="\t";
        $filename ||= 'exportbankfile.txt';
        $boundary= "====" . time() . "====" if !$boundary;
        # Build attachment contents;
        my $contents=$data;
        my $top = MIME::Entity->build(Type     => "multipart/mixed", Boundary => $boundary);
        ### Attach stuff to it:
        $top->attach(
                        Data => $contents,
                        Filename => $filename,
                        Disposition => "attachment",
                        Encoding    => "quoted-printable",
        );

        my $body=       $top->stringify_body;
        $body=~s/\s*This is a multi-part message in MIME format...//g;

        return $body;
}


