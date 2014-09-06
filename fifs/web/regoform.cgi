#! /usr/bin/perl -w

#
# $Header: svn://svn/SWM/trunk/web/regoform.cgi 11319 2014-04-16 04:08:12Z sliu $
#

use strict;
use CGI;

use lib '.','..','RegoForm','../sportstats',"PaymentSplit",'RegoFormBuilder';
use Lang;
use Reg_common;
use PageMain;
use Defs;
use Utils;
use RegoForm::RegoFormFactory;
use SystemConfig;
#use PassportLink;
use MCache;
use Data::Dumper;
use Gateway_Common;
use Payments;
use Logo;
use Log;
use Date::Calc qw(Today_and_Now Delta_DHMS);


main();

sub main	{

	my $db = connectDB();

	my $cgi             = new CGI;
	my $formID          = safe_param('fID','number') || safe_param('formID','number') || 0;
	my $reg_cookie      = $cgi->cookie($Defs::COOKIE_REGFORMSESSION) ||0;
	my $current_session = $cgi->cookie($Defs::COOKIE_REGFORMSESSION);
	my $sessionKey      = safe_param('session','word');
    #nationalrego
    my $clubID          = safe_param('cID','number') || safe_param('clubID','number')  || 0;
    my $memberID        = safe_param('ID','number')  || 0;
    my $pwdVal          = safe_param('pKey', 'word') || '';

    my $nfEntityTypeID  = safe_param('nfEntityTypeID','number') || 0;
    my $nfEntityID      = safe_param('nfEntityID','number')     || 0;

    if ($pwdVal) {
        if ($assocID or $clubID) {
            my $pwdVal2 = getRegoPassword($assocID + $clubID + $formID);
            if ($pwdVal2 eq $pwdVal) {
                $nfEntityTypeID = ($clubID) ? $Defs::LEVEL_CLUB : $Defs::LEVEL_ASSOC;
                $nfEntityID     = ($clubID) ? $clubID : $assocID;
            }
        }
    }

	my $noheader = safe_param('nh','number')  || 0;
	if ($cgi->param('ID') and $cgi->param('eID'))	{
        $cgi->param(-name => 'rfp', -value => 'vt');
	}
    # check if bulkID is valid
    my $bulkID = safe_param( 'bID', 'nubmer' ) || 0;
    my $st_BulkRenewals = qq[SELECT dtSent FROM tblBulkRenewals WHERE intBulkRenewalID=? AND intEntityID IN ( $assocID, $clubID)];
    my $q_BulkRenewals = $db->prepare($st_BulkRenewals);
    $q_BulkRenewals->execute($bulkID);
    my $dtSent = $q_BulkRenewals->fetchrow_array();
    my $has_expired = 0;
    if ($dtSent) {
        my ( $dtSent_date, $dtSent_time ) = split ' ', $dtSent;
        my ( $dtSent_year, $dtSent_month, $dtSent_day ) = split '-', $dtSent_date;
        my ( $dtSent_h, $dtSent_m, $dtSent_s ) = split ':', $dtSent_time;
        my ( $now_year, $now_month, $now_day, $now_h, $now_m, $now_s ) = Today_and_Now();
        my ( $Dd, $Dh, $Dm, $Ds ) = Delta_DHMS( $dtSent_year, $dtSent_month, $dtSent_day, $dtSent_h, $dtSent_m, $dtSent_s, $now_year, $now_month, $now_day, $now_h, $now_m, $now_s);
        if ( $Dd > 30 ) {
            $has_expired = 1;
        }
    }

    if(!$formID and $cgi->param('formID')=~ /\./) {
        $formID =~ s/^(\d+)\..*$/$1/;
	}

	my $lang = Lang->get_handle() || die "Can't get a language handle!";
	my $target = 'regoform.cgi';
	my %Data = (
		db       => $db,
		PageType => 'regoform',
		lang     => $lang,
		target   => $target,
		noheader => $noheader || 0,
		cache    => new MCache(),
	);

    #nationalrego
    $Data{'spClubID'}  = $clubID  || 0;
    $Data{'nfEntityTypeID'} = $nfEntityTypeID;
    $Data{'nfEntityID'}     = $nfEntityID;

	my %carryfields = (
		nh       => $noheader || 0,
		formID   => $formID   || 0,
	);

    #nationalrego
    $carryfields{'cID'}            = $clubID  if $clubID;
    $carryfields{'nfEntityTypeID'} = $nfEntityTypeID;
    $carryfields{'nfEntityID'}     = $nfEntityID;

    #tempformobj and setting up the Data variables can be removed when everyone use passport and so config is set for this feature
    my $tempformObj = getRegoFormObj($formID, \%Data, $db, $cgi, \%carryfields, undef, 1);
	if(!($tempformObj)) {
        regoPageForm('SportingPulse Registration', 'No Form Available', '', q{}, \%Data);
        disconnectDB($db);
        exit();
	}

    #For a linked form, $Data will have had correct entity details set up during the creation of the temp object.
    if (!$nfEntityTypeID) {
        if ($Data{'nfEntityTypeID'}) {
            $carryfields{'nfEntityTypeID'} = $Data{'nfEntityTypeID'};
            $carryfields{'nfEntityID'}     = $Data{'nfEntityID'};
        }
    }

	$Data{'Realm'} = $tempformObj->RealmID();
    $Data{'RealmSubType'} = $tempformObj->SubRealmID();
    $Data{'clientValues'}{'clubID'} = $tempformObj->ClubID();
    $Data{'spAssocID'} = $tempformObj->AssocID() if($tempformObj->AssocID()>0);
    $Data{'SystemConfig'}=getSystemConfig(\%Data);
    $lang   = Lang->get_handle('', $Data{'SystemConfig'}) || die "Can't get a language handle!";
    $Data{'lang'} = $lang;


    my $usePassportFeature =  $Data{'SystemConfig'}{'usePassportInRegos'};
    my $passport;

    if ($usePassportFeature){
	    my $passport_loggedin = $cgi->cookie($Defs::COOKIE_PASSPORT);
	    my $passport_failedlogin = $cgi->cookie('pp_swm_failedlogin');
	    if(!$passport_failedlogin and !$passport_loggedin)	{
            redirectPassportLogin(\%Data, {}, { allowautofail => 1, });
	    }
	    $passport = new Passport(db => $db, cache => $Data{'cache'});
	    $passport->loadSession();
	    my $passportID = $passport->id() || 0;
    }
	my $formObj = getRegoFormObj($formID, \%Data, $db, $cgi, \%carryfields, $passport || undef);

	my $body = '';
    if ( ( $has_expired and $bulkID ) and $memberID ) {
        my $new_url = "$Defs::base_url/regoform.cgi?$ENV{'QUERY_STRING'}";
        $new_url =~ s/&ID=\d+//g;
		$body = qq[
			<div class = "msg-error">Sorry, this link has expired. You will be redirected <a href="$new_url">here</a> after 5 seconds.<meta http-equiv="refresh" content="5;url=$new_url"></div>
		];
    }
	elsif($formObj)	{
		my $resultHTML = '';

		($resultHTML, $Data{'WriteCookies'}) = $formObj->display();
		my $formtitle = $formObj->Title();
		my $summary = $formObj->SessionSummary();
		my $logo = $formObj->Logo();
        my $style = $logo ? 'min-height:120px;line-height:100px;' : '';
		my $navigation = $formObj->Navigation();
		$body = qq[
            <div class="pageHeading">$logo<span class="form-title-wrap"><h1 class="form-title">$formtitle</h1></span></div>
            <div id="form-container">
                <div class="progress">$navigation</div>
                <div class="form-body">
                    $summary
                    $resultHTML
                </div>
			</div>
		];
	  $Data{'Realm'} = $formObj->RealmID();
	  $Data{'RealmSubType'} = $formObj->SubRealmID();
	}
	else	{
		$body = qq[
			<div class = "msg-error">I'm sorry but we are unable to find the registration form you are looking for</div>
		];

	}
#';
    my $compulsory = $tempformObj->getValue('intPaymentCompulsory');
    my $script = qq[<script>
    var payCheckInterval;
    var timeOut  = 70;
    jQuery(document).ready(function(){
            if( jQuery("#payment").length >0){
                jQuery("#payment").click(function(){
                        //console.log("We have to pay! Check heck Check!!");
                        payCheckInterval = window.setInterval(checkPaymentStatus, 5000);
                    });

            }
        });
    function checkPaymentStatus(){
        timeOut = timeOut - 1;
        if(timeOut < 0){
            clearInterval(payCheckInterval);
        }
        jQuery.post("$Defs::base_url/AjaxPay.cgi",
            {
                session : "$current_session",
                formID: "$formID",
                compulsory: "$compulsory",
                clajax : jQuery("#clajax").val(),
                invoiceList:jQuery("#invoiceList").val(),
            },
            function(data) {
                if(data == "-1"){
                    clearInterval(payCheckInterval);
                    //console.log("Some detail is missing!");
                }
                else if(data != "0"){
                    clearInterval(payCheckInterval);
                    jQuery("#payment").hide();
                    jQuery(".payment_note").hide();
                    jQuery("#final_msg").html("Thank you for your payment!");
                    jQuery("#trans_header").html("Transaction Summary");

                    if(data !='1'){
                        var logID = data;
                        // console.log ("display usernames and pasword::");
                        json = jQuery.parseJSON(data);
                        //console.log("Length::"+json.length);
                        for (var i = 0; i < json.length; ++i) {

                            var member = json[i];
                            //console.log("INSIDE"+member.logID);
                            tID = member.tID;
                            logID = member.logID;
                            //console.log("TID::"+tID);
                            jQuery("#n_"+tID).html(member.name);
                            jQuery("#u_"+tID).html(member.Username);
                            jQuery("#p_"+tID).html(member.Password);
                            jQuery("#e_"+tID).html(member.email);
                            jQuery(".userDetail").show();
                        }
                        jQuery("#final_msg").html("Thank you for your payment! Your payment Reference Number is "+logID +".");
                    }
                    else{

                        //jQuery("#final_msg").html("Thank you for your payment!");
                        //jQuery("#trans_header").html("Transaction Summary");
                        //console.log ("keep the page as is! happy time!");
                    }
                }

            });
        if(!jQuery("#payment").is(':visible')){
            clearInterval(payCheckInterval);
        }
    }

    </script>];

    if ($compulsory) {
        $script .= qq[
        <script type="text/javascript">
        jQuery(document).ready(function(){
            \$('#m_formID').submit( check_payment_product );
        });
        </script>]
    } 
	$body .= $script;
	my $header_css = $noheader ? ' #spheader {display:none;} ' : '';

    getDBConfig(\%Data);
    $Data{'SystemConfig'}=getSystemConfig(\%Data);
    $Data{'noheader'}=$noheader;
	$Data{'SystemConfig'}{'OtherStyle'} = "$header_css";
	$Data{'SystemConfig'}{'OtherStyle'} .= $Data{'SystemConfig'}{'RegoFormStyle'};

	regoPageForm('SportingPulse Registration', $body, $Data{'clientValues'}, q{}, \%Data);
	disconnectDB($db);
}

