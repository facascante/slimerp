#!/usr/bin/perl -w

#
# $Header: svn://svn/SWM/trunk/web/.cgi 8249 2013-04-08 08:14:07Z rlee $
#
use CGI qw(:cgi escape unescape);

use strict;
use lib '.','..','RegoForm';
use Lang;
use Utils;
use Defs;
use Utils;
use Reg_common;
use SystemConfig;
use RegoForm::RegoFormFactory;
use Payments;
use Data::Dumper;

main();

sub main  {
    
    my $q = CGI->new;
    
    #my $sessionKey =safe_param('session','word') || '4c94d35fc3656ab5d33806be5aaf538f';
    #my $formID = safe_param('formID','number') || '22451';
    #my $client = param('clajax') || '	   MHwwfDB8MHwwfDB8MHw1NzY1fC0xfC0xfC0xfC0xfC0xfC0xfC0xfC0xfC0xfDB8MHwwfDB8MTM4MTM4MTg1MnxiYzMyMzI2YzFhOGE1YmE0MWJmM2NlNTg4NDMxYzM1ZA';
    #my $invoiceList = "139031652";
    #
    my $sessionKey =safe_param('session','word') || '';
    my $formID = safe_param('formID','number') || '0';
    my $compulsory = safe_param('compulsory','number') || '0';
    my $client = param('clajax') || '';
    my $invoiceList = param('invoiceList') || $q->{'invoiceList'} || $q->{param}{'invoiceList'} || ();
    
    my $msg ='da daaaa';
    
   
    if (!$sessionKey or !$client or !$formID or !$invoiceList) {
       
        print "Content-Type: text/html\n\n";
         print "-1";
        #print "<br />0 session: $sessionKey";
        #print "<br />0 invoices: $invoiceList";
        #
        #print "<br />0 client :$client";
        #print "<br />0 :formID: $formID";
        
    } else {
        
        my $db=connectDB();
        my %Data=();
        $Data{'db'}=$db;
        my %clientValues = getClient($client);
    
        $Data{'clientValues'} = \%clientValues;
        
        getDBConfig(\%Data);
        $Data{'SystemConfig'}=getSystemConfig(\%Data);
        my $lang   = Lang->get_handle('', $Data{'SystemConfig'}) || die "Can't get a language handle!";
        $Data{'lang'}=$lang;
  
        my $logID = isPaid($db,$invoiceList);
        if (!$logID ) {
            print "Content-Type: text/html\n\n";
            $msg = qq[0];

            
        } else{
            #my $formObj = getRegoFormObj($formID, \%Data, $db, $q, undef, undef,1);
            #$compulsory=  $formObj->getValue('intPaymentCompulsory');
            $msg = "$logID";
            
            my $cookie = $q->cookie(
                -name=>$Defs::COOKIE_REGFORMSESSION,
                -value=>'00',
                -domain=>$Defs::cookie_domain,
                -secure=>0,
                -expires=> '-1h',
                -path=>"/"
            );
            print $q->header(-cookie=>[$cookie]);
            
            
            if (!$compulsory) {
                $msg = $logID;
            } else { #look for credentials to display
                
                #usleep(3000);
                $msg = getUserDetails($db, $sessionKey); #members detail in a json string
            }
            
        }
        
        #my @invoices = split('',$invoiceList);
        disconnectDB($db);
        #print "Content-Type: text/html\n\n";
        print $msg;
    }
}


# there is only one intLogID for all the invoices of a transaction
# first find the log Id
# second check tblTransLog to see if it's been approved and payment hasbeen done
sub isPaid(){
    my ($db,$invoiceList)= @_;
    my $logID =0 ;
    my $status;
    my $strInvoices ='';
    my @invoices = split(',',$invoiceList);
    for my $i (@invoices){
        my $invoiceNum = Payments::invoiceNumToTXN($i);
        $strInvoices .= $strInvoices? qq[,$invoiceNum]:qq[$invoiceNum];
    }
    my $st = qq[ SELECT
			TL.strResponseCode,T.intStatus,TL.intLogID
		      FROM
			   tblTransactions T JOIN tblTransLog TL ON (T.intTransLogID = TL.intLogID) 

		      WHERE
                            T.intTransactionID IN (?)];
    my $qry = $db->prepare($st) or query_error($st);
    $qry->execute($strInvoices);
    while (my $dref = $qry->fetchrow_hashref()) {
        $status = $dref->{'intStatus'};
        
        if(!$status){
            return 0;
        }
        $logID =  $dref->{'intLogID'};
		
    }
    #if (!$status) {
    #    return 0;
    #}
    
    return $logID;
}

sub getUserDetails(){
    my ($db , $sessionKey )=@_;
    my $intID;
    my $tempID;
    my $level;
    my @member;
    
    my $strPassword;
    my $strUsername;
    
    my $json_string;
    my $json_from_DB;
    my $deserial;
    my $name;
    my $email;
    my $logID;
    #usleep(3000);
    my $st = qq[ SELECT
                    intTempMemberID,
                    intRealID,
                    intLevel,
                    intStatus,
                    strJson,
                    intTransLogID
		FROM    
                    tblTempMember
                WHERE
                    strSessionKey = ?];
    my $qry = $db->prepare($st) or query_error($st);
    $qry->execute($sessionKey);
    while (my $dref = $qry->fetchrow_hashref()) {
        if (!$dref->{'intStatus'}) {
            return 0;
        }
        
        $intID = $dref->{'intRealID'};
        
        next if(!$intID);
        
        $json_string = $dref->{'strJson'};
	$deserial = JSON::from_json($json_string); 
        $name = qq[$deserial->{'strName'}] || qq[$deserial->{'strFirstname'} $deserial->{'strSurname'}] ;
        $email = $deserial->{'strEmail'};
        $logID = $dref->{'intTransLogID'};
        
        $level =  $dref->{'intLevel'};
        $tempID = $dref->{'intTempMemberID'};
        $st = qq[ SELECT strPassword FROM tblAuth
                        WHERE strUsername = ?
                        AND intLevel = ?
                        AND intID = ? ];
        my $q  = $db->prepare($st);
        $q->execute($intID,
            $level,
            $intID);
        #    $level,
        #    $intID";
        $strPassword = $q->fetchrow_array();
        $strUsername =qq[$level$intID];
        push @member,{
                    Username => $strUsername,
                    Password =>$strPassword,
                    tID =>$tempID,
                    name=> $name,
                    email=> $email,
                    logID=> $logID,
                    };
		
    }
    my $j;
    $j = new JSON;
    my $string;
    $string = JSON::to_json(\@member);
    return $string;
}

# 1- get the session and form id
# 2- find out if the transaction has been finished and successful

    # there is only one intLogID for all the invoices of a transaction
    # first find the log Id
    # second check tblTransLog to see if it's been approved and payment hasbeen done

# 2-1 : if not return 0
# 2-2 : is yes then find out if form has compulsory payment or not
    # Do we need to run these functions here?? this should run in payment callback, here we just checkand retrieve data, AND clean cookie
        # 3 : compulsor :  run function ADDUPDATE
        # 4 : non compulsory:  run function UPDATEONLY

# function ADDUPDATE
# 1- rebuild the formOBJ using ID 
# 2- load the data from tbltemptable into session using sessionKey
# 3- run addRealMember and postUpdateRealMember functions to update the DB and related dependecies
# 4- build the json ro return back to regoform.cgi
# 5- remove cookies and clean up

# function UPDATEONLY
# 1- make sure the payment has been done succesfuly and there is no problem
# 2- build the json to return back to regoform.cgi
# 3- remove cookies and clean up
