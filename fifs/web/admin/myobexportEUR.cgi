#!/usr/bin/perl -w

#
# $Header: svn://svn/SWM/trunk/web/admin/myobexportEUR.cgi 10073 2013-12-01 22:57:50Z tcourt $
#

use strict;
use lib "../comp","../..","..",".";
use DBI;
use CGI qw(param unescape escape);
use Defs;
use Utils;
use Lang;
use HTMLForm qw(_date_selection_dropdown);
use Defs;
use Date::Calc qw(Today);
use ExportEmailData;
use AdminPageGen;
use PaymentSplitMyobExportObj;

main();

sub main    {
    my $body   = "";
    my $action = param('action') || '';
    my $target = "myobexportEUR.cgi";
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


sub getOptions {
    my ($target, $dbh) = @_;
    my $emailAddress = $Defs::accounts_email;
    my $includeToDate = _date_selection_dropdown('includeToDate','');

    my $body = qq[
        <form action="$target" method="post">
            <p>THIS IS THE EURO Export</p>
            <div style="color:red;"><b>GET EXCHANGE RATE FROM ACCOUNTS</b></div>
            <p>Select the appropriate <b>payment type</b> and adjust the recipient <b>email address</b> (if need be).</b></p>
            <p>Press the <b>Continue</b> button when ready...</p><br><br>
            <label class="label": for "rbPaymentTypes">Payment Type:</label>
            <input type="radio" name="paymentType" id="rbPaypal" value="PAYPAL" class="ROnb" checked><label for="rbPaypal"> Paypal</label>
            <!--<input type="radio" name="paymentType" id="rbCreditCard" value="Credit Card" class="ROnb"><label for="rbCreditCard"> Other</label>-->
            <br><br><br>
            <p><span class="label">Include To Date:</span> $includeToDate<span class="HTdateformat">(dd/mm/yyyy)</span></p>
            <br><br>
            <label class="label": for "txtEmailAddress">Email Address:</label>
            <input type="text" name="emailAddress" id="txtEmailAddress" value="$emailAddress">
<br>
            <label class="label": for "txtEURORate">EURO Rate:</label><input type="text" name="eurorate" id="txtEURORate" value="0.6">
            <input type="hidden" name="action" value="buildDoc">
            <br><br>
            <label class="label": for "txtRunName">MYOB Run Name:</label>
            <input type="text" name="runName" id="txtRunName" value=""> (eg: <b>MAY-2010</b>)
            <br><br><br><br>
            <input type="submit" name="btnContinue" id="btnContinue" value="Continue">
        </form>
    ];

  return $body;
}


sub buildDoc {
    my ($target, $dbh) = @_;

    my $paymentType  = param("paymentType") || '';
    return getErrorMessage() if !$paymentType;

    $paymentType = ($paymentType eq 'PAYPAL') # maybe make this a constant or even a Defs entry
        ? $Defs::GATEWAY_PAYPAL
        : $Defs::GATEWAY_CC;

    my $emailAddress       = param("emailAddress")         || $Defs::accounts_email;
    my $EURORate= param("eurorate")         || 0;

    return getErrorMessage() if !$EURORate;
    my $runName            = param("runName")              || '';
    my $includeToDateDay   = param("d_includeToDate_day")  || '31';
    $includeToDateDay      = sprintf("%02d", $includeToDateDay);
    my $includeToDateMonth = param("d_includeToDate_mon")  || '12';
    $includeToDateMonth    = sprintf("%02d", $includeToDateMonth);
    my $includeToDateYear  = param("d_includeToDate_year") || '2009';
    my $includeToDate      = qq[$includeToDateYear-$includeToDateMonth-$includeToDateDay 23:59:59];
    my $fileDate = qq[$includeToDateDay/$includeToDateMonth/$includeToDateYear];

    my $wherePP = qq[r.strFinInst];
    $wherePP   .= ($paymentType eq 'PAYPAL') ? qq[=] : qq[<>];
    $wherePP .= qq['PAYPAL_NAB'];

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
            		SUM(l.curMoney) AS curAmount,
			strMYOBJobCode
        	FROM 
            		tblMoneyLog AS l
	    					INNER JOIN tblTransLog as TL ON (l.intTransLogID = TL.intLogID)
            		INNER JOIN tblExportBankFile AS e ON l.intExportBankFileID=e.intExportBSID
            		INNER JOIN tblAssoc AS a ON l.intAssocID=a.intAssocID
            		LEFT  JOIN tblClub  AS c ON l.intClubID=c.intClubID
            		LEFT  JOIN tblPaymentApplication as cPay ON (
                        l.intClubID=cPay.intEntityID
                        AND cPay.intEntityTypeID = $Defs::LEVEL_CLUB
												AND cPay.intPaymentType=TL.intPaymentType
                    )
            		LEFT  JOIN tblPaymentApplication as aPay ON (
                        l.intAssocID=aPay.intEntityID
                        AND aPay.intEntityTypeID = $Defs::LEVEL_ASSOC
												AND aPay.intPaymentType=TL.intPaymentType
                    )
            		INNER JOIN tblPaymentSplitRule AS r ON (l.intRuleID = r.intRuleID)
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

    my @headings = (
        'Co./Last Name',
        'First Name',
        'Addr 1 - Line 1',
        '           - Line 2',
        '           - Line 3',
        '           - Line 4',
        'Inclusive',
        'Invoice #',
        'Date',
        'Customer PO',
        'Ship Via',
        'Delivery Status',
        'Item Number',
        'Quantity',
        'Description',
        'Price',
        'Inc-Tax Price',
        'Discount',
        'Total',
        'Inc-Tax Total',
        'Job',
        'Comment',
        'Journal Memo',
        'Salesperson Last Name',
        'Salesperson First Name',
        'Shipping Date',
        'Referral Source',
        'Tax Code',
        'Non-GST Amount',
        'GST Amount',
        'LCT Amount',
        'Freight Amount',
        'Inc-Tax Freight Amount',
        'Freight Tax Code',
        'Freight Non-GST Amount',
        'Freight GST Amount',
        'Freight LCT Amount',
        'Sale Status',
        'Currency Code',
        'Exchange Rate',
        'Terms - Payment is Due',
        '           - Discount Days',
        '           - Balance Due Days',
        '           - % Discount',
        '           - % Monthly Charge',
        'Amount Paid',
        'Payment Method',
        'Payment Notes',
        'Name on Card',
        'Card Number',
        'Expiry Date',
        'Authorisation Code',
        'BSB',
        'Account Number',
        'Drawer/Account Name',
        'Cheque Number',
        'Category',
        'Location ID',
        'Card ID',
        'Record ID'
    );

    $doc  = join("\t", @headings);
  #  $doc .= "\r\n";

    my $myobExportID = getMyobExportID($paymentType, $includeToDate, $dbh, $runName);
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
	my $exchangeRate = $EURORate; #0.6; ## CHANGE FOR EURO
	my $paypalTotal=0;
    while (my $dref = $query->fetchrow_hashref()) {
        my $currency    = $dref->{strCurrencyCode} || 'AUD';
	my $job = $dref->{strMYOBJobCode} || '';
	next if $currency ne 'EUR';
	my $country = 'Ireland';
	next if ! $job;
	### If EUR is used, then need to look at GST Rate and Exchange column

        my $name        = $dref->{'strName'};
        my $address1    = $dref->{'strAddress1'}; 
        my $suburb      = $dref->{'strSuburb'}; 
        my $phone1      = $dref->{'strPhone'}; 
        my $state       = $dref->{'strState'}; 
        my $postcode    = $dref->{'strPostalCode'}; 
        my $invAmt      = $dref->{'curAmount'};
	my $email 	= $dref->{'MPEmail'};
	my $gstRate = 11;
	$gstRate = 9 if $currency eq 'EUR';
        my $gstAmt      = 0; #sprintf("%.3f", $invAmt / $gstRate);
        my $exGstAmt    = $invAmt; # - $gstAmt;
        my $journalMemo = 'Sale; ' . $name;

        my @custLine = ();
	my $key = qq[$dref->{intAssocID}_$dref->{intClubID}] || '';
	
		my $uniqueID = 0;
		$uniqueID = "A$dref->{intAssocID}";
		$uniqueID .= "C$dref->{intClubID}" if $dref->{intClubID};
	if (not exists $AssocClub{$key})	{
	        $itemNo++;
		$AssocClub{$key} = $itemNo;
		
		@custLine = (
        	    	$name,      # Co./Last Name
			'',
			$uniqueID,
			'N',
			$currency,
			$address1,
			'', 	
			'',
			'',
        	    	$suburb,    # Suburb
        	    	$state,     # State
        	    	$postcode,  # Postcode
			$country,
			$phone1,
			'',
			'',
			'',
			$email,
			'',
			'',
			'',
			'', ## ADDRESS 2
			'',
			'',
			'',
			'',
			'',
			'',
			'',
			'',
			'',
			'',
			'',
			'',
			'',
			'',
			'',
			'', ## ADDRESS 3
			'',
			'',
			'',
			'',
			'',
			'',
			'',
			'',
			'',
			'',
			'',
			'',
			'',
			'',
			'',
			'', ## ADDRESS 4
			'',
			'',
			'',
			'',
			'',
			'',
			'',
			'',
			'',
			'',
			'',
			'',
			'',
			'',
			'',
			'', ## ADDRESS 5
			'',
			'',
			'',
			'',
			'',
			'',
			'',
			'',
			'',
			'',
			'',
			'',
			'',
			'',
			'',
			'', #PIC
			'', #NOTES
			'', 
			'SPORTS CUSTOMER',
			$country,
			'', ## LIST FROM DAZZ
			'', ##Field1
			'', ##Field2
			'', ##Field3
			'', #Billing Rate
			'2',
			'0',
			'14',
			'0',
			'0',
			'EXP', #WAS GST
			'',
			'',
			'',
			'',
			'',
			'',
			'',
			'', ## NAME ON CARD
			'',
			'',
			'',
			'',
			'',
			'',
			'',
			'',
			'',
			'',
			'',
			'',
			'1SPulseANZ-PMS Item',
			'EXP', #AS S BUT BEFORE THAT IT #WAS GST
			'N',
			'',
			'P',
			''
        	);
	}
	$ItemAmount{$itemNo} += $invAmt if ($dref->{intLogType} != $Defs::ML_TYPE_GATEWAYFEES);
	my $amountHolder = qq[X] . $itemNo . qq[X];
        my $invNo = $myobExportID * 10000 + $itemNo,
        $invCount++;
        $totalAmt += $invAmt;

        # got all the fields, now build the line
        my @invLine = ();
        my @payPalLine = ();

	if ($dref->{intLogType} == $Defs::ML_TYPE_LPF)	{
        	@invLine = (
        	    	$name,
        	    	'', #FIRSTNAME
        	    	'', #ADD 1
        	    	'', #ADD 2
        	    	'', #ADD 3
        	    	'', #ADD 4
        	    	'X',
        	    	$invNo,
        	    	$date,
			'',
			'',
        	    	'E',
        	    	'SPOMPS0020',
        	    	'1',
        	    	'SportingPulse Processing Fee',
        	    	$exGstAmt,
        	    	$invAmt,
        	    	'0',
        	    	$invAmt,# $exGstAmt,
        	    	$invAmt,
        	    	$job,
			'',
        	    	$journalMemo,
			'', ##HOOD
			'', ##Craig
			'',
			'',
        	    	'EXP', #WAS GST
       		    	'0.00',
            		$gstAmt,
            		'0.00',
			'',
			'',
            		'EXP', #WAS GST
            		'0.00',
            		'0.00',
            		'0.00',
            		'I',
            		$currency,
            		$exchangeRate,
            		'2',
            		'0',
            		'0',
            		'0',
            		'0',
            		$amountHolder,
            		'PayPal',
            		'',
            		'',
            		'',
            		'',
            		'',
            		'',
            		'',
            		'',
            		'',
            		'',
            		'',
            		$uniqueID, #'*None',
            		'',
        	);
	}
	if ($dref->{intLogType} == $Defs::ML_TYPE_SPMAX)	{
        	@invLine = (
        	    	$name,
        	    	'', #FIRSTNAME
        	    	'', #ADD 1
        	    	'', #ADD 2
        	    	'', #ADD 3
        	    	'', #ADD 4
        	    	'X',
        	    	$invNo,
        	    	$date,
			'',
			'',
        	    	'E',
        	    	'SPOMPS0020',
        	    	'1',
        	    	'SportingPulse subscription costs',
        	    	$exGstAmt,
        	    	$invAmt,
        	    	'0',
        	    	$exGstAmt,
        	    	$invAmt,
        	    	$job,
			'',
        	    	$journalMemo,
			'',
			'',
			'',
			'',
        	    	'EXP', #WAS GST
       		    	'0.00',
            		$gstAmt,
			'0.00',
            		'',
            		'',
            		'EXP', #WAS GST
            		'0.00',
            		'0.00',
            		'0.00',
            		'I',
            		$currency,
            		$exchangeRate,
            		'2',
            		'0',
            		'0',
            		'0',
            		'0',
            		$amountHolder,
            		'PayPal',
			'',
            		'',
            		'',
            		'',
            		'',
            		'',
            		'',
            		'',
            		'',
            		'',
            		'',
            		$uniqueID, #'*None',
            		'',

        	);
	}
	if ($dref->{intLogType} == $Defs::ML_TYPE_GATEWAYFEES)	{
		$paypalTotal += $invAmt;
		@payPalLine = (
			'', ##CHEQUE ACCOUNT 
			"PP$myobExportID", #CHEQ NUM
        	    	$date,
			'X',
			'', ##CO/LASTNAME
			'', ## FIRSTNAME
        	    	'Paypal', #$address1,
        	    	'', #$address2,
			'',
			'',
			'Paypal fees',
			'53050', # ALLOCATION ACC NUM
        	    	$invAmt,
        	    	$invAmt,
			$job, #'', #JOB NUM
			'N-T', #TAX CODE
			'',# Non GST AMT
			'', #TAX AMT
			'', #IMPORT DUTY
			'', ## PRINTED
			$currency,
			$exchangeRate,
			'', ##STATEMENT TEXT
			'', ## ALLOCATION MEMO
			'', ##CATEGORY
			'',#$uniqueID, #CardID
			'', #RECORDID
			'' #DELIVERY STATUS	
        	);
	}

        $doc .= "\r\n" if ($key ne $currentKey and $key);
	$doc .= join("\t", @invLine);
        $doc .= "\n" if (scalar @invLine);

	if (scalar @custLine)	{
		$custList .= "\n";
        	$custList .= join("\t", @custLine);
	        $custList .= "\r\n";
	}

	if (scalar @payPalLine)	{
	        #$payPalList .= "\n"; #if ($key ne $currentKey);
	        $payPalList .= join("\t", @payPalLine);
	        $payPalList .= "\r\n";
	}
	$currentKey=$key;

    }
	my @payPalLine = (
            		'11185', ##CHEQUE ACCOUNT
            		"PP$myobExportID", #CHEQ NUM
                    	$date,
            		'X',
            		'Paypal', ##CO/LASTNAME
            		'', ## FIRSTNAME
			'Paypal', # $address1,
			'', # $address2,
            		'',
            		'',
            		'Paypal fees',
            		'', # ALLOCATION ACC NUM
                    	$paypalTotal,
                    	$paypalTotal,
	            	'', #JOB NUM
            		'', #TAX CODE
            		'',# Non GST AMT
            		'', #TAX AMT
            		'', #IMPORT DUTY
            		'X', ## PRINTED
            		'EUR',
            		$exchangeRate,
            		'', ##STATEMENT TEXT
            		'', ## ALLOCATION MEMO
            		'', ##CATEGORY
            		'PP001', #CardID
            		'', #RECORDID
            		'A' #DELIVERY STATUS    
            );
		my $tempPayPalFirstLine = join("\t", @payPalLine);
		$payPalList = $tempPayPalFirstLine . "\n" . $payPalList;

	foreach my $k (keys %ItemAmount)	{
		my $tmp = qq[X] . $k . qq[X];
		$doc =~ s/$tmp/$ItemAmount{$k}/g;
	}
#$custList =~ s/\\r\\n$//;
#$doc =~ s/\\r\\n$//;
#$payPalList =~ s/\\r\\n$//;
$doc.= "\n";

    my $body = qq[
        <div><b>$invCount invoices totalling $totalAmt have been generated.</b></div><br/>
        <div>Press Continue to export the invoices.</div>
        <form action ="$target" method="POST">
            <input type="hidden" name="includeToDate" value="$includeToDate">
            <input type="hidden" name="eurorate" value="$EURORate">
            <input type="hidden" name="emailAddress" value="$emailAddress">
            <input type="hidden" name="runName" value="$runName">
            <input type="hidden" name="wherePP" value="$wherePP">
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


sub getMyobExportID {
    my ($paymentType, $includeToDate, $dbh, $runName) = @_;

    my $gatewayNo = ($paymentType eq 'PAYPAL' or $paymentType == 2)
        ? $Defs::GATEWAY_PAYPAL
        : $Defs::GATEWAY_CC;

    # use the gateway number to indicate payment type
    my $myobExport = PaymentSplitMyobExportObj->new(
        paymentType  => $gatewayNo, 
        includeTo    => qq["$includeToDate"],
        totalInvs    => 0,
        totalAmount  => 0,
	    currencyRun  => 'EUR',
        runName      => $runName
    );

    my $myobExportID = $myobExport->save($dbh);

    return $myobExportID;
}


sub doExport {
    my ($dbh) = @_;

    my $includeToDate = param("includeToDate") || '';
    my $emailAddress  = param("emailAddress")  || '';
    my $wherePP       = param("wherePP")       || '';
    my $myobExportID  = param("myobExportID")  || '';
    return getErrorMessage() if !$includeToDate or !$emailAddress or !$wherePP or !$myobExportID;

    my $invCount = param("invCount") || 0;
    my $totalAmt = param("totalAmt") || 0;
    my $doc      = param("doc")      || '';
    my $custList = param("custList") || '';
    my $payPalList = param("payPalList") || '';

	my $custheadings = qq[Co./Last Name	 First Name	 Card ID	 Card Status	 Currency Code	 Addr 1 - Line 1	            - Line 2	            - Line 3	            - Line 4	            - City	            - State	            - Postcode	            - Country	            - Phone # 1	            - Phone # 2	            - Phone # 3	            - Fax #	            - Email	            - WWW	            - Contact Name	            - Salutation	 Addr 2 - Line 1	            - Line 2	            - Line 3	            - Line 4	            - City	            - State	            - Postcode	            - Country	            - Phone # 1	            - Phone # 2	            - Phone # 3	            - Fax #	            - Email	            - WWW	            - Contact Name	            - Salutation	 Addr 3 - Line 1	            - Line 2	            - Line 3	            - Line 4	            - City	            - State	            - Postcode	            - Country	            - Phone # 1	            - Phone # 2	            - Phone # 3	            - Fax #	            - Email	            - WWW	            - Contact Name	            - Salutation	 Addr 4 - Line 1	            - Line 2	            - Line 3	            - Line 4	            - City	            - State	            - Postcode	            - Country	            - Phone # 1	            - Phone # 2	            - Phone # 3	            - Fax #	            - Email	            - WWW	            - Contact Name	            - Salutation	 Addr 5 - Line 1	            - Line 2	            - Line 3	            - Line 4	            - City	            - State	            - Postcode	            - Country	            - Phone # 1	            - Phone # 2	            - Phone # 3	            - Fax #	            - Email	            - WWW	            - Contact Name	            - Salutation	 Picture	 Notes	 Identifiers	 Custom List 1	 Custom List 2	 Custom List 3	 Custom Field 1	 Custom Field 2	 Custom Field 3	 Billing Rate	 Terms - Payment is Due	            - Discount Days	            - Balance Due Days	            - % Discount	            - % Monthly Charge	 Tax Code	 Credit Limit	 Tax ID No.	 Volume Discount %	 Sales/Purchase Layout	 Price Level	 Payment Method	 Payment Notes	 Name on Card	 Card Number	 Expiry Date	 BSB	 Account Number	 Account Name	 A.B.N. 	 A.B.N. Branch	 Account	 Salesperson	 Salesperson Card ID	 Comment	 Shipping Method	 Printed Form	 Freight Tax Code	 Use Customer's Tax Code	 Receipt Memo	 Invoice/Purchase Order Delivery	 Record ID];

    $custList  = $custheadings . "\n" . $custList . "\n\n";

	my $feeheadings = qq[Cheque Account	Cheque #	Date	Inclusive	Co./Last Name	First Name	Addr 1 - Line 1	           - Line 2	           - Line 3	           - Line 4	Memo	Allocation Account #	Ex-Tax Amount	Inc-Tax Amount	Job #	Tax Code	Non GST/LCT Amount	Tax Amount	Import Duty Amount	Printed	Currency Code	Exchange Rate	Statement Text	Allocation Memo	Category	Card ID	Record ID	Delivery Status];
    $payPalList  = $feeheadings . "\n" . $payPalList . "\n\n";


    my $filename = 'ps4myob'.$myobExportID.'.txt';

    my $message  = "The EURO data you requested for export is included in the attached file ($filename)" ;
    my $subject  = "EUR Data Export - Payment Split Fees";
    my $retval   = emailExportData($dbh, '', $emailAddress, $message, '', $subject, $filename, $doc, '');
    my $body     = '';
    
    if ($retval == 0) {
        $body = qq[<p class="OKmsg">The Payment Split Export File for MYOB has been emailed to $emailAddress.</p><br>];
        updateLogEntries($includeToDate, $wherePP, $myobExportID, $dbh);

        {
            my $filename = 'ps4myob'.$myobExportID.'custs.txt';
            my $message  = "The customer list for export ID $myobExportID is included in the attached file ($filename)" ;
            my $subject  = "EUR Data Export - Customer List";
            my $retval   = emailExportData($dbh, '', $emailAddress, $message, '', $subject, $filename, $custList, ',');
    
            $body .= ($retval == 0)
                ? qq[<p class="OKmsg">The corresponding Customer List has been emailed to $emailAddress.</p><br>]
                : getErrorMessage();
        }
	{
            my $filename = 'ps4myob'.$myobExportID.'fees.txt';
            my $message  = "The customer list for export ID $myobExportID is included in the attached file ($filename)" ;
            my $subject  = "EUR Data Export - PayPal Fees";
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
    my ($includeToDate, $wherePP, $myobExportID, $dbh) = @_;

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
		AND l.strCurrencyCode='EUR'
    ];
	    	#AND l.intLogType IN ($Defs::ML_TYPE_SPMAX, $Defs::ML_TYPE_LPF)

    my $query = $dbh->prepare($sql);
    $query->execute;

    return;
}


sub getErrorMessage {
    return qq[<p class="warningmsg">There was an error during the export process.</p><br>];
}
