#!/usr/bin/perl -w

#
# $Header: svn://svn/SWM/trunk/web/admin/jde_export.cgi 10071 2013-12-01 22:56:16Z tcourt $
#

use strict;
use lib "../comp","../..","..",".";
use DBI;
use CGI qw(param unescape escape);
use Defs;
use Utils;
use HTMLForm qw(_date_selection_picker);
use Lang;
use Defs;
use Date::Calc qw(Today);
use ExportEmailData;
use AdminPageGen;
use PaymentSplitMyobExportObj;

main();

##### TO DO:
## 2010-09-29-  In getJDEExprotID need to store if a JDE or a Myob... have a type ?


sub main    {
    my $body   = "";
    my $action = param('action') || '';
    my $target = "jde_export.cgi";
    my $dbh    = connectDB();

    if ($action eq 'buildDoc') {
        $body = buildDoc($target, $dbh);
    }
    elsif ($action eq 'doExport' ) {
        $body = doExport($dbh);
    }
    else {
        $body = getOptions($target, $dbh);
    }

    disconnectDB($dbh) if $dbh;

    print_adminpageGen($body, "", "");
}

## If events changes needed for Renee, then look at adding a flag to possibly tblAssoc.
## This can then be used as the trigger as intRealmID/SubType might not be needed.


sub getOptions {
    my ($target, $dbh) = @_;
    my $emailAddress = $Defs::admin_email;
    my $includeToDate = _date_selection_picker('includeToDate','');

    my $body = qq[
        <form action="$target" method="post">
            <p>Select the appropriate <b>payment type</b> and adjust the recipient <b>email address</b> (if need be).</b></p>
            <p>Press the <b>Continue</b> button when ready...</p><br><br>
            <br><br>
            <p><span class="label">Include To Date:</span> $includeToDate<span class="HTdateformat">(dd/mm/yyyy)</span></p>
            <br><br>
            <label class="label": for "txtEmailAddress">Email Address:</label>
            <input type="text" name="emailAddress" id="txtEmailAddress" value="$emailAddress">
            <input type="hidden" name="action" value="buildDoc">
            <br><br>
            <label class="label": for "txtRunName">JDE Run Name:</label>
            <input type="text" name="runName" id="txtRunName" value=""> (eg: <b>MAY-2010</b>)
            <br><br><br><br>
            <input type="submit" name="btnContinue" id="btnContinue" value="Continue">
        </form>
    ];

  return $body;
}


sub buildDoc {
    my ($target, $dbh) = @_;

    my $paymentType = $Defs::GATEWAY_PAYPAL;

    my $emailAddress       = param("emailAddress")         || $Defs::admin_email;
    my $runName            = param("runName")              || '';
    my $includeToDateDay   = param("d_includeToDate_day")  || '31';
    $includeToDateDay      = sprintf("%02d", $includeToDateDay);
    my $includeToDateMonth = param("d_includeToDate_mon")  || '12';
    $includeToDateMonth    = sprintf("%02d", $includeToDateMonth);
    my $includeToDateYear  = param("d_includeToDate_year") || '2009';
    my $includeToDate      = qq[$includeToDateYear-$includeToDateMonth-$includeToDateDay 23:59:59];
    my $fileDate = qq[$includeToDateDay/$includeToDateMonth/$includeToDateYear];
    my $dateUpTo= qq[$includeToDateDay$includeToDateMonth$includeToDateYear];

	my $sql = qq[
        	SELECT 
        		IF(l.intClubID>0, 
                    IF((cPay.strOrgName <> '' and cPay.strOrgName IS NOT NULL), cPay.strOrgName, c.strName)
                    , IF((aPay.strOrgName <> '' and aPay.strOrgName IS NOT NULL) , aPay.strOrgName, a.strName) 
                ) AS strName, 
            	IF(l.intClubID>0, cPay.strMailingAddress, aPay.strMailingAddress) AS strAddress1, 
            	IF(l.intClubID>0, cPay.strSuburb, aPay.strSuburb) AS strSuburb, 
            	IF(l.intClubID>0, cPay.strState, aPay.strState) AS strState, 
            	IF(l.intClubID>0, cPay.strPostalCode, aPay.strPostalCode) AS strPostalCode, 
            	IF(l.intClubID>0, cPay.strOrgPhone, aPay.strOrgPhone) AS strPhone, 
            	IF(l.intClubID>0, 
			        IF((cPay.strPaymentEmail <> '' and cPay.strPaymentEmail IS NOT NULL), cPay.strPaymentEmail, ClubBankAcc.strMPEmail), 
				    IF((aPay.strPaymentEmail <> '' and aPay.strPaymentEmail IS NOT NULL), aPay.strPaymentEmail, AssocBankAcc.strMPEmail)
			    ) AS MPEmail ,
			    l.intClubID,
			    l.intAssocID,
			    l.intLogType,
			    l.strCurrencyCode,
                l.intRealmID,
            	SUM(l.curMoney) AS curAmount,
			    strMYOBJobCode
        	FROM 
                tblMoneyLog AS l
            	INNER JOIN tblExportBankFile AS e ON l.intExportBankFileID=e.intExportBSID
            	INNER JOIN tblAssoc AS a ON l.intAssocID=a.intAssocID
            	LEFT  JOIN tblClub  AS c ON l.intClubID=c.intClubID
            	LEFT  JOIN tblPaymentApplication as cPay ON (
                    l.intClubID=cPay.intEntityID
                    AND cPay.intEntityTypeID = $Defs::LEVEL_CLUB
                )
            	LEFT  JOIN tblPaymentApplication as aPay ON (
                    l.intAssocID=aPay.intEntityID
                    AND aPay.intEntityTypeID = $Defs::LEVEL_ASSOC
                )
            	INNER JOIN tblPaymentSplitRule AS r ON (l.intRuleID = r.intRuleID)
	    		INNER JOIN tblTransLog as TL ON (l.intTransLogID = TL.intLogID)
			    LEFT JOIN tblBankAccount as ClubBankAcc ON (
				    ClubBankAcc.intEntityTypeID = $Defs::LEVEL_CLUB
				    AND ClubBankAcc.intEntityID = l.intClubID
			    )
			    LEFT JOIN tblBankAccount as AssocBankAcc ON (
				    AssocBankAcc.intEntityTypeID = $Defs::LEVEL_ASSOC
				    AND AssocBankAcc.intEntityID = l.intAssocID
			    )
        	WHERE
	    		TL.intPaymentType = $Defs::PAYMENT_ONLINEPAYPAL
            	AND e.dtRun<='$includeToDate'
			    AND l.intExportBankFileID >0
            	AND l.intMyobExportID=0
	    		AND l.intLogType IN ($Defs::ML_TYPE_SPMAX, $Defs::ML_TYPE_LPF, $Defs::ML_TYPE_GATEWAYFEES)
            	AND l.curMoney <>0
			    AND l.intRealmID NOT IN (35)
        	GROUP BY 
			    l.intAssocID, 
			    l.intClubID, 
			    l.intLogType
        	ORDER BY 
			    strName,
			    l.intAssocID,
			    l.intClubID
    ];
    my $query = $dbh->prepare($sql);

    $query->execute();

    my $doc      = '';
    my $custList = '';
    my $payPalList = '';

    my $myobExportID = getJDEExportID($includeToDate, $dbh, $runName);
    my $itemNo   = 0;
    my %AssocClub=();
    my $invCount = 0;
    my $totalAmt = 0;

    my ($year, $month, $day) = Today();
    $month   = sprintf("%02d", $month);
    $day     = sprintf("%02d", $day);
    my $date = $fileDate || qq[$day/$month/$year];

    return qq[<p class="warningmsg">There are no records to be exported.</p><br>] if !$query->rows;

    # now that we know there will be invs exported, get the (next) export id

	my %ItemAmount=();
	my $currentKey='';
	my $paypalTotal=0;
    my %PayPalTotal=();
    while (my $dref = $query->fetchrow_hashref()) {
        my $currency    = $dref->{strCurrencyCode} || 'AUD';
	    my $job = $dref->{strMYOBJobCode} || '';
	    next if $currency ne 'AUD';
	    my $country = 'AUSTRALIA';
        my $countryCode = 'AU';
        my $taxRateArea= 'OUTPUT';
        my $taxExplCode1= 'V';
        my $paymentTerms = 'NET';
	    next if ! $job;
	    ### AUD only at the moment.
	    ### If NZD is used, then need to look at GST Rate and Exchange column
        my %Customer=();

        ## NEED TO RUN CLEAN COMMAS

		my $uniqueID = 0;
		$uniqueID = "A$dref->{intAssocID}";
		$uniqueID .= "C$dref->{intClubID}" if $dref->{intClubID};
        $Customer{'name'} = $dref->{'strName'} || '';
        $Customer{'cardID'} = $uniqueID;
        $Customer{'address1'} = $dref->{'strAddress1'} || '';
        $Customer{'suburb'} = $dref->{'strAddress1'} || '';
        $Customer{'pcode'} = $dref->{'strPostalCode'} || '';
        $Customer{'stateCode'} = cleanStateCode($dref->{'strState'}) || '';
        $Customer{'phone'} = $dref->{'strPhone'} || '';
        $Customer{'email'} = $dref->{'MPEmail'} || '';

        my $invAmt      = $dref->{'curAmount'};
	    my $gstRate     = 11;
	    $gstRate        = 9 if $currency eq 'NZD';
        my $gstAmt      = sprintf("%.3f", $invAmt / $gstRate);
        my $exGstAmt    = $invAmt - $gstAmt;

        my @custLine = ();
	    my $key = qq[$dref->{intAssocID}_$dref->{intClubID}] || '';
	
	    if (not exists $AssocClub{$key})	{
	        $itemNo++;
		    $AssocClub{$key} = $itemNo;
		
		    @custLine = (
                '',                     ## A- Address Number (blank)      
                $Customer{'cardID'},    ## B- CardID                       
                '',                     ## C- Tax ID (blank)
                $Customer{'name'},      ## D- Customer name
                28800,                  ## E- Business Unit
                '',                     ## F- Industry Class. Code (blank)
                'C',                    ## G- Search Type
                '',                     ## H- Credit Message (blank)
                '',                     ## I- Person/Corp Code (blank)
                '',                     ## J- AR/AP netting (blank)
                '',                     ## L- Address Type - 4 (blank)
                '',                     ## M- Address Type - 5 (blank)
                '',                     ## N- Address Type - Payables (blank)
                '',                     ## O- Address Type - Code Purchaser (blank)
                '',                     ## P- Address Book - Misc Code (blank)
                '',                     ## Q- Address Type - Employee (blank)
                '',                     ## R- Address Number - 1 (blank)
                '',                     ## S- Address Number - 2 (blank)
                '',                     ## T- Address Number - 3 (blank)
                '',                     ## U- Address Number - 4 (blank)
                '',                     ## V- Address Number - 5 (blank)
                '',                     ## W- Factor/Special Payee (blank)
                '',                     ## X- Customer Type (blank)
                'SP',                   ## Y- Category Code (Address Book 02)
                'E',                    ## Z- Category Code (Address Book 03)
                $countryCode,           ## AA-Category Code (Address Book 04)
                '',                     ## AB-Category Code (Address Book 05) (blank)
                '',                     ## AC-Category Code (Address Book 06) (blank)
                '',                     ## AD-Category Code (Address Book 07) (blank)
                '',                     ## AE-Category Code (Address Book 08) (blank)
                '',                     ## AF-Category Code (Address Book 09) (blank)
                '',                     ## AG-Category Code (Address Book 10) (blank)
                '',                     ## AH-Sales Region (blank)
                '',                     ## AI-G/L Bank Account (blank)
                '',                     ## AJ-Name - Remark (blank)
                '',                     ## AK-Certificate Tax Exemption (blank)
                '',                     ## AL-Tax ID (blank)
                '',                     ## AM-Secondary Alpha Name (blank)
                $Customer{'name'},      ## AN-Name (same as D)
                '',                     ## AO-Secondary Mailing Name (blank)
                $Customer{'address1'},  ## AP-Address Line 1
                '',                     ## AQ-Address Line 2
                '',                     ## AR-Address Line 3
                '',                     ## AS-Address Line 4
                $Customer{'pcode'},     ## AT-Postal Code
                $Customer{'suburb'},    ## AU-City (Suburb)
                $countryCode,           ## AV-County Code
                $Customer{'stateCode'}, ## AW-State Code
                '',                     ## AX-County (blank)
                '',                     ## AY-Phone Prefix (blank)
                $Customer{'phone'},     ## AZ-Phone
                '',                     ## BA-Phone Number Type 1 (blank)
                '',                     ## BB-Phone Prefix 2 (blank)
                '',                     ## BC-Phone Number 2 (blank)
                '',                     ## BD-Phone Number Type 2 (blank)
                '',                     ## BE-Transaction Originator (blank)
                '',                     ## BF-User ID (blank)
                '',                     ## BG-Address Number - Parent (blank)
                '',                     ## BH-Company (blank)
                'TRAD',                 ## BI-G/L Offest
                '',                     ## BJ-Business Unit - A/R Default (blank)
                '',                     ## BK-Object - Accounts Receivable Default (blank)
                '',                     ## BL-Subsidiary - Accounts Receivable Default (blank)
                '',                     ## BM-Document Company (A/R Model Document) (blank)
                '',                     ## BN-Document - A/R Default for Model JE (blank)
                '',                     ## BO-Document Type - A/R Default for Model JE (blank)
                $currency,              ## BP-Currency Code From
                $taxRateArea,           ## BQ-Tax Rate/Area
                $taxExplCode1,          ## BR-Tax Empl Code 1
                '',                     ## BS-Amount - Credit Limit (blank)
                '',                     ## BT-Hold Invoices (blank)
                $paymentTerms,          ## BU-Payment Terms - A/R
                '',                     ## BV-(blank)
                '',                     ## BW-Payment Instrument (blank)
                '',                     ## BX-Print Statement Y/N (blank)
                '',                     ## BY-Alernate Payor (blank)
                '',                     ## BZ-Auto Receipt Y/N (blank)
                '',                     ## CA-Send Invoice to C/P (blank)
                '',                     ## CB-Ledger Inquiry Sequence (blank)
                '',                     ## CC-Auto Receipt Algorithm Method (blank)
                '',                     ## CD-Statement Cycle (blank)
                '',                     ## CE-Blance Forward- Open Item (blank)
                '',                     ## CF-Temporary Credit Message (blank)
                '',                     ## CG-Credit Check Handling Code (blank)
                '',                     ## CH-Date - Last Credit Review (blank)
                '',                     ## CI-Delinquency Notice Y/N (blank)
                '',                     ## CJ-Days Sales Outstanding (blank)
                '',                     ## CK-Credit Manager (blank)
                '',                     ## CL-Collection Manager (blank)
                '',                     ## CM-Collection Report Y/N (blank)
                '',                     ## CN-Apply Finance Charges Y/N (blank)
                '',                     ## CO-Currency Code - A/B Amounts (blank)
                '',                     ## CP-Related - Address Number (blank)
                '',                     ## CQ-Customer Price Group (blank)
                '',                     ## CR-Credit Hold Exempt (blank)
                '',                     ## CS-Credit Check Level (blank)
                '',                     ## CT-Invoice Copies (blank)
                '',                     ## CU-Invoice Consolidation (blank)
                '',                     ## CV-Billing Frequency (blank)
                '',                     ## CW-Commission Code 1 (blank)
                '',                     ## CX-Rate - Commission 1 (blank)
                '',                     ## CY-Commission Code 2 (blank)
                '',                     ## CZ-Rate - Commission 2 (blank)
                '',                     ## DA-Customer Type Identifier (blank)
                '',                     ## DB-Policy Number (Internal) (blank)
                '',                     ## DC-Deduction Manager (blank)
                '',                     ## DD-Auto Receipts Execution List (blank)
                '',                     ## DE-Administration Credit Limit (blank)
                '',                     ## DF-Industry Group (blank)
                $Customer{'email'},     ## DG-Email address (blank)
        	);
	    }
	    $ItemAmount{$itemNo} += $invAmt if ($dref->{intLogType} != $Defs::ML_TYPE_GATEWAYFEES);
	    my $amountHolder = qq[X] . $itemNo . qq[X];
        my $invNo = $myobExportID * 10000 + $itemNo,
        $invCount++;
        $totalAmt += $invAmt;

        # got all the fields, now build the line
        my @invLine = ();

	    if ($dref->{intLogType} == $Defs::ML_TYPE_LPF or $dref->{intLogType} == $Defs::ML_TYPE_SPMAX)	{
            my $itemDescription = 'SportingPulse Low Processing Fee';
            $itemDescription = 'SportingPulse subscription costs' if ($dref->{intLogType} == $Defs::ML_TYPE_SPMAX);
        	@invLine = (
                    $Customer{'cardID'},    ## A- CardID                       
                    $dateUpTo,              ## B- Date for G/L
                    $dateUpTo,              ## C- Date Invoice
                    $invNo,                 ## D- Supplier Invoice Number
        	    	$invAmt,                ## E- Amount - Taxable
                    '',                     ## F- Amount - Non Taxable
                    '',                     ## G- Subledger
                    'S',                    ## H- Subledger Type
                    '',                     ## I- Reference (blank)
                    $itemDescription,       ## J- Name - Remark
                    '',                     ## K- Batch File Discount Handling Code (blank)
                    '',                     ## L- Transaction Number (blank)
                    '',                     ## M- Line Number (blank)
                    '',                     ## N- Line Number (blank)
                    '',                     ## O- Mode-Foreign or Domestic
                    '',                     ## P- Currency Code - From (blank)
                    '',                     ## Q- Amount - Foreign Taxable (blank)
                    '',                     ## R- Amount - Foreign Non Taxable (blank)
                    '',                     ## S- Document / Invoice Number (blank)
                    '',                     ## T- Document Type (blank)
                    '',                     ## U- Document Company (blank)
                    '',                     ## V- Document Pay Item (blank)
                    '',                     ## W- Batch Type (blank)
                    '',                     ## X- Fiscal Year (blank)
                    '',                     ## Y- Century (blank)
                    '',                     ## Z- Period Number- General Ledger (blank)
                    '',                     ## AA-Company (blank)
                    '',                     ## AB-G/L Offset (blank)
                    '',                     ## AC-Account ID (blank)
                    '',                     ## AD-Address Number - Parent (blank)
                    '',                     ## AE-Address Number - Alternate Payee (blank)
                    '',                     ## AF-Payor Address Number (blank)
                    '',                     ## AG-Balanced - Journal Entries (blank)
                    '',                     ## AH-Pay Status Code (blank)
                    $invAmt,                ## AI-Amount - Gross (blank)
                    '',                     ## AJ-Discount Available (blank)
                    '',                     ## AK-Discount Taken (blank)
                    '',                     ## AL-Amount - Tax (blank)
                    '',                     ## AM-Currency Conversion Rate (blank)
                    '',                     ## AN-Domestic Entry w/Mult Currency Distr (blank)
                    '',                     ## AO-Amount - Currency (blank)
                    '',                     ## AP-Amount - Foreign Open (blank)
                    '',                     ## AQ-Amount - Foreign Discount Available (blank)
                    '',                     ## AR-Amount - Foreign Discount Taken (blank)
                    '',                     ## AS-Amount - Foreign Tax (blank)
                    '',                     ## AT-Tax Rate/Area (blank)
                    '',                     ## AU-Tax Expl Code (blank)
                    '',                     ## AV-Date - Service/Tax (blank)
                    '',                     ## AW-G/L Bank Account (blank)
                    '',                     ## AX-Account Mode - G/L (blank)
                    '',                     ## AY-Account ID (blank)
                    '',                     ## AZ-Account Mode - G/L (blank)
                    '',                     ## BA-Business Unit (blank)
                    '',                     ## BB-Object (blank)
                    '',                     ## BC-Subsidiary (blank)
                    '',                     ## BD-Payment Terms Code (blank)
                    '',                     ## BE-Date - Net Due (blank)
                    '',                     ## BF-Date - Discount Due (blank)
                    '',                     ## BG-Document - Original (blank)
                    '',                     ## BH-Document Type - Original (blank)
                    '',                     ## BI-Document Company (Original Order) (blank)
                    '',                     ## BJ-Document Pay Item - Original (blank)
                    '',                     ## BK-Booking Number (blank)
                    '',                     ## BL-Order Type (blank)
                    '',                     ## BM-Sales Document Number (blank)
                    '',                     ## BN-Sales Document Type (blank)
                    '',                     ## BO-Document Company (Sales Order) (blank)
                    '',                     ## BP-Order Suffix(blank)
                    '',                     ## BQ-Commission Code 1 (blank)
                    '',                     ## BR-Page Code (blank)
                    '',                     ## BS-Unit (blank)
                    '',                     ## BT-Business Unit 2 (blank)
                    '',                     ## BU-Name - Alpha (blank)
                    '',                     ## BV-Frequency - Recurring (blank)
                    '',                     ## BW-Recurring Frequency # of Payments (blank)
                    '',                     ## BX-Control / Statement Field (blank)
                    '',                     ## BY-Item Number - Short (blank)
                    '',                     ## BZ-Units (blank)
                    '',                     ## CA-Unit of Measure (blank)
                    '',                     ## CB-Payment Instrument (blank)
                    '',                     ## CC-A/R Reporting Code 1 (blank)
                    '',                     ## CD-A/R Reporting Code 2 (blank)
                    '',                     ## CE-A/R Reporting Code 3 (blank)
                    '',                     ## CF-A/R Reporting Code 4 (blank)
                    '',                     ## CG-A/R Reporting Code 5 (blank)
                    '',                     ## CH-A/R Reporting Code 6 (blank)
                    '',                     ## CI-A/R Reporting Code 7 (blank)
                    '',                     ## CJ-A/R Reporting Code 8 (blank)
                    '',                     ## CK-A/R Reporting Code 9 (blank)
                    '',                     ## CL-A/R Reporting Code 10 (blank)
                    '',                     ## CM-Page Number (blank)
                    '',                     ## CN-Customer Reference (blank)
                    '',                     ## CO-Originating System (blank)
                    '',                     ## CP-Collection Manager (blank)
                    '',                     ## CQ-Credit Manager (blank)
                    '',                     ## CR-Amount - To Distribute (blank)
                    '',                     ## CS-Amount - Currency to Distribute (blank)
                    '',                     ## CT-Non-Recoverable Tax Amount (blank)
                    '',                     ## CU-Sales Rep (blank)
                    '',                     ## CV-Sales Rep Number (blank)
        	);
	    }
	    if ($dref->{intLogType} == $Defs::ML_TYPE_GATEWAYFEES)	{
            $PayPalTotal{$dref->{'intRealmID'}} += $invAmt;
		    $paypalTotal += $invAmt;
	    }

        $doc .= "\r\n" if ($key ne $currentKey and $key);
	    $doc .= join("\t", @invLine);
        $doc .= "\n" if (scalar @invLine);

	    if (scalar @custLine)	{
		    $custList .= "\n";
        	$custList .= join("\t", @custLine);
	        $custList .= "\r\n";
	    }

	    $currentKey=$key;
    }
	foreach my $k (keys %PayPalTotal)	{
        my $subLedgerType = getSubLedgerType($k);
        my @payPalLine = (
            'Paypal Bank Account',  ## A- Account No.
            $PayPalTotal{$k},       ## B- Amount
            'S',                    ## C- Subledger (blank) 
            $subLedgerType,         ## D- Subledger Type (blank) 
            '',                     ## E- Remark (blank) 
            'Output',               ## F- Tax Code (blank) 
            'V',                     ## G- (blank) 
        );
	    $payPalList .= join("\t", @payPalLine);
    }
	my @payPalLine = (
        'Paypal Bank Account',  ## A- Account No.
        -$paypalTotal,          ## B- Amount
        '',                     ## C- Subledger (blank) 
        '',                     ## D- Subledger Type (blank) 
        '',                     ## E- Remark (blank) 
        '',                     ## F- Tax Code (blank) 
        '',                     ## G- (blank) 
    );
	$payPalList .= join("\t", @payPalLine);

	foreach my $k (keys %ItemAmount)	{
		my $tmp = qq[X] . $k . qq[X];
		$doc =~ s/$tmp/$ItemAmount{$k}/g;
	}
    $doc.= "\n";

    my $body = qq[
        <div><b>$invCount invoices totalling $totalAmt have been generated.</b></div><br/>
        <div>Press Continue to export the invoices.</div>
        <form action ="$target" method="POST">
            <input type="hidden" name="includeToDate" value="$includeToDate">
            <input type="hidden" name="emailAddress" value="$emailAddress">
            <input type="hidden" name="runName" value="$runName">
            <input type="hidden" name="myobExportID" value="$myobExportID">
            <input type="hidden" name="invCount" value="$invCount">
            <input type="hidden" name="totalAmt" value="$totalAmt">
            <input type="hidden" name="doc" value="$doc">
            <input type="hidden" name="custList" value="$custList">
            <input type="hidden" name="payPalList" value="$payPalList">
            <input type="submit" name="btnContinue" value="Continue">
            <input type="hidden" name="action" value="doExport">
        </form>
    ];

    return ($body);
}


sub getJDEExportID {
    my ($includeToDate, $dbh, $runName) = @_;

    # use the gateway number to indicate payment type
    my $myobExport = PaymentSplitMyobExportObj->new(
        paymentType  => $Defs::GATEWAY_PAYPAL,
        includeTo    => qq["$includeToDate"],
        totalInvs    => 0,
        totalAmount  => 0,
        currencyRun  => 'AUD',
        runName      => $runName
    );

    my $myobExportID = $myobExport->save($dbh);

    return $myobExportID;
}


sub doExport {
    my ($dbh) = @_;

    my $includeToDate = param("includeToDate") || '';
    my $emailAddress  = param("emailAddress")  || '';
    my $myobExportID  = param("myobExportID")  || '';
    return getErrorMessage() if !$includeToDate or !$emailAddress or !$myobExportID;

    my $invCount = param("invCount") || 0;
    my $totalAmt = param("totalAmt") || 0;
    my $doc      = param("doc")      || '';
    my $custList = param("custList") || '';
    my $payPalList = param("payPalList") || '';

    my $filename = 'pms_jde'.$myobExportID.'.txt';

    my $message  = "The data you requested for export is included in the attached file ($filename)" ;
    my $subject  = "SportingPulse PMS Data Export - Payment Split Fees";
    my $retval   = emailExportData($dbh, '', $emailAddress, $message, '', $subject, $filename, $doc, '');
    my $body     = '';
    
    if ($retval == 0) {
        $body = qq[<p class="OKmsg">The Payment Split Export File for JDE has been emailed to $emailAddress.</p><br>];
        updateLogEntries($includeToDate, $myobExportID, $dbh);

        {
            my $filename = 'pms_jde'.$myobExportID.'custs.txt';
            my $message  = "The customer list for export ID $myobExportID is included in the attached file ($filename)" ;
            my $subject  = "SportingPulse PMS Data Export - Customer List";
            my $retval   = emailExportData($dbh, '', $emailAddress, $message, '', $subject, $filename, $custList, ',');
    
            $body .= ($retval == 0)
                ? qq[<p class="OKmsg">The corresponding Customer List has been emailed to $emailAddress.</p><br>]
                : getErrorMessage();
        }
	    {
            my $filename = 'pms_jde'.$myobExportID.'fees.txt';
            my $message  = "The customer list for export ID $myobExportID is included in the attached file ($filename)" ;
            my $subject  = "SportingPulse PMS Data Export - PayPal Fees";
            my $retval   = emailExportData($dbh, '', $emailAddress, $message, '', $subject, $filename, $payPalList, ',');
    
            $body .= ($retval == 0)
                ? qq[<p class="OKmsg">The corresponding Pay Pal Fees List has been emailed to $emailAddress.</p><br>]
                : getErrorMessage();
        }
    }
    else {
        $body = getErrorMessage();
    }

    return ($body);
}


sub updateLogEntries {
    my ($includeToDate, $myobExportID, $dbh) = @_;

    my $sql = qq[
        UPDATE 
            tblMoneyLog AS l
            INNER JOIN tblExportBankFile   AS e ON l.intExportBankFileID=e.intExportBSID
            INNER JOIN tblPaymentSplitRule AS r ON l.intRuleID =r.intRuleID
		INNER JOIN tblTransLog as TL ON (l.intTransLogID = TL.intLogID)
        SET
            intMyobExportID=$myobExportID
        WHERE
		    TL.intPaymentType = $Defs::PAYMENT_ONLINEPAYPAL
            AND e.dtRun<='$includeToDate'
            AND l.intMyobExportID=0 
            AND l.curMoney <>0
			AND l.strCurrencyCode='AUD'
    ];
	    	#AND l.intLogType IN ($Defs::ML_TYPE_SPMAX, $Defs::ML_TYPE_LPF)

    my $query = $dbh->prepare($sql);
    $query->execute;

    return;
}

sub getErrorMessage {
    return qq[<p class="warningmsg">There was an error during the export process.</p><br>];
}

sub cleanStateCode    {

}

sub cleanAssocName  {

}

sub cleanCommas {

}

sub getSubLedgerType    {

}
