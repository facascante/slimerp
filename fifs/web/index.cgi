#!C:/Perl64/bin/perl.exe -w
#
# $Header: svn://svn/SWM/trunk/web/index.cgi 10277 2013-12-15 21:15:06Z tcourt $
#

use strict;
use lib ".", "..";
use CGI qw(param unescape escape cookie);
use Defs;
use Lang;
use TTTemplate;

	my $lang= Lang->get_handle() || die "Can't get a language handle!";
	
	my $pheading=$lang->txt('Sign in to <span class="sporange">Membership</span>');
	my $txtexpl=$lang->txt('Here you can sign in to your SportingPulse Membership database.');
	my $title=$lang->txt('APPNAME') || 'SportingPulse Membership';

	my $page=qq[
			<span></span>
		].loginform($lang, '').qq[
	];
	my %Data = (
		lang => $lang,
	);
  my $globalnav = runTemplate(
    \%Data,
    {},
    'user/globalnav.templ',
  );

  print "Content-type: text/html\n\n";
  print qq[<!DOCTYPE html><html lang="en" xmlns="http://www.w3.org/1999/xhtml">
  <head>
    <title>$title</title>
		<script src = "https://ajax.googleapis.com/ajax/libs/jquery/1.7.1/jquery.min.js"></script>
		<link rel="stylesheet" type="text/css" href="css/spfont.css">
    <link rel="stylesheet" type="text/css" href="css/style.css">
  <!--[if lt IE 8]>
  <style>
.membership-login .auth-row input.fields {
	line-height: 40px;
}
</style>
    <![endif]-->
  <!--[if IE]>
    <link rel="stylesheet" type="text/css" href="css/passport_ie.css" />
  <![endif]-->

  <!--[if lt IE 9]>
    <link rel="stylesheet" type="text/css" href="css/passport_ie_old.css" />
  <![endif]-->
  </head>
  <body onload="document.loginform.username.focus();" class="membership-login">
		$globalnav
    <div id="spheader">
			<div id="spheader-int">
				<img src="images/sp_membership.png" alt="" title="">
			</div>
		</div>
    <div id="pageholder">
      <div id="content">$page</div> <!-- End Content -->
      <div id="footer">
	<div id="footer-topline"></div>
		<div id="footer-content">
				<a href="http://www.sportingpulse.com"><img src="images/SP_powered_rev.png" title="SportingPulse" alt="SportingPulse"></a>
				<div class="footerline">].$lang->txt('COPYRIGHT').q[</div>
		</div>
      </div>
    </div> <!-- End Page Holder -->
</div> <!-- End wrapper -->
<!-- START Nielsen Online SiteCensus V5.3 -->
<!-- COPYRIGHT 2009 Nielsen Online -->
<script type="text/javascript">
        var _rsCI="sportingpulse";
        var _rsCG="sportzmembership";
        var _rsDN="//secure-au.imrworldwide.com/";
        var _rsCL=1;
        var _rsUT="1";
        var _rsC0="";
        var _rsC1="advertising,ads";

</script>
<noscript>
  <div><img src="//secure-au.imrworldwide.com/cgi-bin/m?ci=sportingpulse&amp;cg=sportzmembership&amp;cc=1&amp;_rsUT=1&amp;_rsC1=advertising,ads" alt=""></div>
</noscript>
<!-- END Nielsen Online SiteCensus V5.3 -->

<!-- START Tealium -->
<script type="text/javascript">
  utag_data = window.utag_data || {};
  utag_data.net_site = 'sportingpulse';
utag_data.net_section = 'sportzmembership';
utag_data.ss_sp_ga_account = 'UA-144085-2';
utag_data.ss_sp_pagename = 'SP Membership Login';
utag_data.ss_sp_ads = '0';
utag_data.ss_sp_sportname = 'nosport';
utag_data.ss_sp_pagetype = 'membership';
utag_data.ss_sp_ads_string = 'advertising,noads';

  
 (function(a,b,c,d){
  a='//tags.tiqcdn.com/utag/newsltd/sportingpulse/prod/utag.js';
  b=document;c='script';d=b.createElement(c);d.src=a;d.type='text/java'+c;d.async=true;
  a=b.getElementsByTagName(c)[0];a.parentNode.insertBefore(d,a);
  })();
</script>
<!-- END Tealium -->
  </body>
</html>
  ];

sub loginform	{
	my ($lang)=@_;
	my $logindesc=$lang->txt('ENTER_USER_PASSWORD', $lang->txt('Sign In'));
	my $un=$lang->txt('Username/Code');
	my $pw=$lang->txt('Password');
	my $login=$lang->txt('Sign in');
	my $reset=$lang->txt('Reset');
	my $txt_loginpassport =$lang->txt('Sign in with Passport');

	return qq[
		<div id="swm-login-wrap">
			<div class="spm-left">
				<div class="pp-signin">
					<p class="intro">].$lang->txt("We are making it easier to access your SP products with a single email and password, your").qq[ <span class="sp-passport">].$lang->txt("SP Passport").qq[</span>.</p>
					<p>].$lang->txt("This gives you:").qq[</p>
					<ul>
						<li><span>].$lang->txt("A single login for all SP products, especially handy if you juggle multiple username / passwords in").qq[ <span class="sp-membership">].$lang->txt("SP Membership").qq[</span></span></li>
						<li><span>].$lang->txt("Better auditing of database updates").qq[</span></li>
						<li><span>].$lang->txt("Better communications from SP on product updates").qq[</span></li>
						<li><span>].$lang->txt("Access SP Membership at any time with a single click from the global navigation").qq[</span></li>
					</ul>
      		<p><a href="https://sportingpulse.zendesk.com/entries/22501701-sp-passport-passport-update-december-5th" target="_blank">Click here for more information</a></p>
      	</div>
			</div>
			<div class="or-sep-vert"><img src="images/rule-vert.png"></div>
			<div class="spm-right">
				<div class="membership-login-wrap passport-sign-box">
					<p class="pageHeading"><span class="spp_loggedout">Register/</span>].$lang->txt("Sign in with").qq[ <span class="sp-passport">].$lang->txt("SP Passport").qq[</span></p>				
					<span class="spp_loggedout"><p class="instruct">].$lang->txt("Don't have a").qq[ <span class="sp-passport">].$lang->txt("SP Passport").qq[</span>?</p>
					<p class="instruct">].$lang->txt("No problems, just click Register to create one and gain access to your").qq[
					 <span class="sp-membership">].$lang->txt("SP Membership").qq[</span> ].$lang->txt("database").qq[.
</span>
					</p>
<p>
<form method = "POST" action = "user/login.cgi">
                       UN <input type = "text" name = "email"><br>
                       PW <input type = "password" name = "pw"><br>
                        <span class="button generic-button"><input type = "submit" value = "].$lang->txt('Sign in').qq["> </span>
</p>
</form>
					<span class="spp_loggedin">
						<p class="instruct">We see you already have <span class="sp-passport">SP Passport</span>. Sign in below to access your <span class="sp-membership">SP Membership</span> database.</p>
					</span>
					<span class="spp_loggedout"><span class="button special-button"><a href="user/signup.cgi">Register</a></span></span>
					<span><p style="padding-top:70px; font-size:16px; margin:8px 0; letter-spacing: -0.5px;"><a href="forgotten_password.cgi">I forgot my password.</a></p></span>
				</div>
			</div>
		</div>
	];
}
