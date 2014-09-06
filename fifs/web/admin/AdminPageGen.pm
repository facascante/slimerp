#
# $Header: svn://svn/SWM/trunk/web/admin/AdminPageGen.pm 11643 2014-05-22 03:42:14Z apurcell $
#

package AdminPageGen;

require Exporter;
@ISA =  qw(Exporter);
@EXPORT = qw(get_user_level print_adminpageGen create_tabs check_access);
@EXPORT_OK = qw(get_user_level print_adminpageGen create_tabs check_access);

use strict;
use lib "..", "../..";
use Defs;

sub print_adminpageGen {
	my($body,$page_title,$page_heading, $extra_ref)=@_;

	my $otherevents=$extra_ref->{onload} || '';
	print "Content-Type: text/html\n\n";
	print qq[
	<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN">
	<html>
	<head>
	<link rel="stylesheet" type="text/css" href="../css/style.css">
	<link rel="stylesheet" type="text/css" href="adminstyle.css">

<script type="text/javascript" src="https://ajax.googleapis.com/ajax/libs/jquery/1.7.1/jquery.min.js"></script>
			<script type="text/javascript" src="../js/chosen/chosen.jquery.min.js"></script>
			<link rel="stylesheet" type="text/css" href="../js/chosen/chosen.css">
 <!--<script type="text/javascript" src="../js/ext-2.2/adapter/jquery/ext-jquery-adapter.js"></script>
    <script type="text/javascript" src="../js/ext-2.2/ext-all.js"></script>-->
 <script type="text/javascript" src="table2csv.js"></script>

			<script type="text/javascript">
Ext.onReady(function(){

                        jQuery(".chzn-select").chosen({ disable_search_threshold: 5 });
    });
</script>
	<title>$page_title</title>
	</head>
	<body>
	$body
	</body>
</html>
	];
    #<div id="spheader"><img src="../images/membership_1.jpg" alt="" title=""><img src="../images/membership_2.jpg" alt="" title=""><img src="../images/membership_3.jpg" alt="" title=""><img src="../images/membership_4.jpg" alt="" title=""></div>
}

sub create_tabs	{
	my($subBody, $tabs_ref, $sub_tabs_ref, $activetop,$activetab, $name, $menu)=@_;
	$name||='';
	$menu||='';

	my $body=qq[\n
	<table cellpadding="0" cellspacing="0" border="0" width="100%" align="">
		<tr>
<td align='left'>

<img align="middle" src="images/header.png" alt="Sporting Pulse Membership Administration" title="Sporting Pulse Membership Administration" style="height:70px;">
	<h3 style="display:inline;color:#5F6062;">Membership</h3>
</td>

			<td align='right'><table cellpadding=0 cellspacing=4 border=0 width="100%">		<tr>
	];
	for my $i (0 .. $#$tabs_ref)	{
		my $bgclass='inactiveformbg';
		
		if(check_access($tabs_ref->[$i][0])==1){
		if($i!=0)	{$body.=qq[<td  align="center" width="1"></td>\n];}
		if($i==$activetop)	{
			$bgclass='menuformbg';
		}
		$body.=qq[	<td class="$bgclass tab" align="center" colspan="].(($#$sub_tabs_ref+1)*2).qq[" valign="middle"><a href="$tabs_ref->[$i][0]" class="tabheading $bgclass">$tabs_ref->[$i][1]</a></td>\n];
		}
	}
$body.=qq[
					</tr></table></td></tr>
</table>
        <table cellpadding="0" cellspacing="0" border="0" width="90%" align="center" style="border:2px solid black;top:-50px">
					<tr>
	];
	my $sub_tabs_counter=0;
        for my $i (0 .. $#$sub_tabs_ref)    {
                my $bgclass='inactiveformbg';
		 if(check_access($sub_tabs_ref->[$i][0])==1){

                if($i!=0)       {$body.=qq[<td class="blackbg" align="center" width="1"></td>\n];}
                if($i==$activetab)      {
                        $bgclass='formbg';
                }
		
		$sub_tabs_counter++;
                $body.=qq[      <td class="$bgclass tab" align="center"  valign="middle"><a href="$sub_tabs_ref->[$i][0]" class="tabheading $bgclass">$sub_tabs_ref->[$i][1]</a></td>\n];
		}
        }
$body.=qq[
                                        </tr>
                                        <tr>
        ];

	for my $i (0 .. $#$sub_tabs_ref)	{
		my $bgclass='blackbg';
		if($i==$activetab)	{$bgclass='formbg';}
		 if(check_access($sub_tabs_ref->[$i][0])==1){
		if($i!=0)	{$body.=qq[		<td  class="blackbg" align="center" width="1"></td>\n];}
		
		$body.=qq[		<td class="$bgclass" align="center"></td>\n];
		}
	}
	$body.=qq[
					</tr>
					<tr>
						<td colspan="].(($sub_tabs_counter)*2).qq[" class="formbg">
							<table cellpadding="3" cellspacing="0" border="0" width="100%" align="center">
							<tr>
								<td class="name" align="left">&nbsp; $name</td>
								<td class="name" align="right">$menu &nbsp;</td>
							</tr>
							<tr>
								<td class="formbg" colspan="2">$subBody</td>
							</tr>
						</table>
					</tr>

				</table>
		];
	return $body;

#  <tr><td align='right' colspan="].(($#$tabs_ref+1)).qq[" ><img src="images/header.png" style="width:150px;"></td></tr>
}

sub check_access {
	my($action,$checktype)=@_;
	 
	$checktype ||= '';
	if($action=~/=/) {
		my @action_split = split('&',$action);
		@action_split = split('=',$action_split[0]);
		$action = $action_split[1];
	}
	
	my $user_level = get_user_level();
	
	if($checktype eq 'levelonly') {
		return $user_level;
	}
		
	my $screen_level = get_screen_level($action);
		
	if($user_level >= $screen_level) { 
		return 1;
	}
	else {
		return 0;
	}
}

sub get_user_level {
	
#90+ - tech
#80+ - web
#50+ - support
#40+ - rest support 
#20+ - account
#10+ - rest account
#10  - Sport Admin user
#0+  - base
	my %accesslevels = (

		#techs
		dhanslow => 99,
		sregmi => 99,
		fkhezri => 99,	
		warren => 99,
		tim => 99,
		bruce => 99,
		mstarcevic => 99,
		cchurchill => 99,
		wrodie=>99,
		birvine=>99,
		tcourt=>99,
		cgao=>99,	
		apurcell=>99,	
		sliu=>99,	
	    gyeong=>99,
    	
		#web
		cregnier => 99,
		akenez => 99,
		dweaver => 80,
		rtsai =>80,
		pfink=>80,
		cgarcia => 80,		
		srodan => 80,		
        tclark=>90,	
		#support
		mmaden => 99,
		sfewster => 91,
		rodonnell => 90,
		jcaines=>90,
		pstewart=>99,
		skettler=>90,
		#account managers
		gtripp=>91,
		bturner=>20,
		kbell=>99,
        csparsi => 99,
		mpocklington => 91,
		mpititto => 91,
		dmaakaroun => 91,
		chood => 20,
		acollins => 20,
		kpicking => 20,
		jling => 20,
		psuon=>20,
		tcorr=>20,
        mfenwick=>20,
        jbartholomew=>20,
		#IT
		smelnikov => 99,
        nsplitter =>20,	
        jdeleon=>90,
		mlalor=>20,
        dbell=>20,    
    #Sport Admin users
		tcostanzo => 10,	
		mallan => 10,	
		
		#deleted employees
		dsmith=>-1,	

		#to be assigned
		trialacc=>-1,
		devel=>99
		);

	my $user_level = -1;
	my $user_name = '';
	
	$user_name = AdminCommon::get_username();

	if(exists $accesslevels{$user_name}) {
		$user_level = $accesslevels{$user_name} || 0;
	} 

	return $user_level;
}

sub get_business_unit_type {
	
#1 - SPANZ
#2 - SPIL
#3 - GameDay

	my %but_id = (
		mallan => 2,	
		);

	my $but_id = 1; #Set default to SPANZ
	my $user_name = '';
	
	$user_name = AdminCommon::get_username();

	if(exists $but_id{$user_name}) {
		$but_id = $but_id{$user_name} || 0;
	} 

	return $but_id ;
}


sub get_screen_level {
 my($action)=@_;
 
 	my $level = 0;

	#NOTE: This isn't all of the pages. If a page isn't listed here it is assumed to have a level of 0
	my %lockdownpages = (
		REALM_DETAILS =>10, #list realms
		REALM_CONFIG=>80,
		REALM_ADD=>80,
        ASSOC_memberhide=>20,
		REALM_SUBADD=>90,
		REALM_DEFCODES=>90,
		REALM_PAYMENT=>90,
		UTILS_holidays=>90,
		LOGIN_SEARCH_FORM=>0, #Node Search
		NODE_EDIT_USER=>90,
		SEARCH_FORM=>10, #assoc search
		ASSOC_config=>20, #swol config
		UTILS_SWOL_setup=>90,
		ASSOC_ASSOC_config=>90,
		ASSOC_passport=>90,
		ASSOC_edit=>10,
		ASSOC_loc=>10, #assoc locations
		ASSOC_tstamp=>90, #reset assoc timestamps
		ASSOC_new=>10, #add assoc
		CLUB_SEARCH_FORM=>10,
		TEAM=>90, #team search. please match below.
		TEAM_SEARCH=>90,
		TEAM_INFO=>90,
		DATA=>90,
		DATA_EDIT=>90,
		DATA_UPDATE=>90,
		MEMBER=>90, #member search. please match below.
		MEMBER_SEARCH=>90,
		MEMBER_INFO=>90,
		UTILS=>10, #utils main & decode URL. Please Match the one below.
		UTILS_decode_URL=>10,
		UTILS_CARDS=>80,
		UTILS_clearance=>20,
		UTILS_auskick=>50,
		UTILS_school=>20,
		UTILS_processlog=>20,
		UTILS_teamsheets=>20,
		UTILS_compAuskick=>20,
		RFT=>20,
		COPY_MEMBERS =>90,
		TempReg_Display => 20, 
		UTILS_categories=>90,
		TESTS => 50,
		TESTS_RUN => 50,
	);
	if(exists $lockdownpages{$action}) {
		$level =  $lockdownpages{$action} || 0;
	}
	
	return $level;
	 
}
