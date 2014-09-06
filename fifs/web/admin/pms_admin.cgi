#!/usr/bin/perl -w

#
# $Header: svn://svn/SWM/trunk/web/admin/pms_admin.cgi 8815 2013-06-27 04:18:58Z fkhezri $
#

use lib "../..","..",".";
#use lib "/u/regonew_live","/u/regonew_live/web","/u/regonew_live/web/admin";
use DBI;
use CGI qw(param unescape escape);
use Defs;
use Utils;
use strict;
use AdminPageGen;
use AdminCommon;
use RealmAdmin;
use PMSAdmin;
use LoginAdmin;
use ClubAdmin;
use ClearDollar;
use FormHelpers;

main();

sub main	{

# Variables coming in

	my $header = "Content-type: text/html\n\n";
	my $body = "";
	my $title = "$Defs::sitename PMS Administration";
	my $output=new CGI;

	my $action = param('action') || 'SEARCH_FORM';
	my $sport= param('sport') || '';

  my $assocID=param('intAssocID') || param('entityID') || 0;
  my $assocName=param('AssocName') || '';
  my $escAssocName=escape($assocName);
	my $subBody='';
	my $menu='';
	my $activetab=0;
	my $target="pms_admin.cgi";
	my $error='';
	my $db=connectDB();
	if(!$db)	{
		$action='ERROR';
	}
	my @tabs=(
			["$target?action=SEARCH_FORM",'Search'],
			["$target?action=BANK",'Bank Accounts'],
		);
	if ($action eq "SEARCH_FORM") {
		$activetab=0;
		$subBody = display_find_fields($target,$db);
	}
	elsif($action=~/APP_/) {
		$activetab=2;
		@tabs=(
			["$target?action=SEARCH_FORM",'Search'],
			["$target?action=BANK",'Bank Accounts'],
			["$target?action=ASSOC_edit&amp;intAssocID=$assocID",'Details'],
		);
		$activetab=2 if($action eq 'ASSOC_loc');
		$activetab=3 if($action eq 'ASSOC_upl');
		$activetab=2 if($action eq 'ASSOC_lu');
		$activetab=4 if($action eq 'ASSOC_clubs');
		$activetab=5 if($action eq 'ASSOC_teams');
		$activetab=5 if($action eq 'ASSOC_clear_club');
		$activetab=6 if($action eq 'ASSOC_tstamp' or $action eq 'ASSOC_tstamp_reset' );
		if($assocID)	{
			push @tabs, ["$target?action=ASSOC_loc&intAssocID=$assocID&AssocName=$escAssocName",'Location'];
			push @tabs, ["$target?action=ASSOC_upl&intAssocID=$assocID&AssocName=$escAssocName",'Syncs'];
			push @tabs, ["$target?action=ASSOC_clubs&intAssocID=$assocID&AssocName=$escAssocName",'Clubs'];
			push @tabs, ["$target?action=ASSOC_teams&intAssocID=$assocID&AssocName=$escAssocName",'Teams'];
			push @tabs, ["$target?action=ASSOC_tstamp&intAssocID=$assocID&AssocName=$escAssocName",'Timestamps'];
		}
		($subBody,$menu)=handle_paymentapplication($db,$action,$target, $escAssocName);
	}
	elsif ($action =~/CLEAR/) {
	    ($subBody,$menu)=handle_clearDollar($db,$action,$target, $escAssocName);
	}
    elsif ($action =~/BANK/){
        $activetab = 1;
        $subBody = bankAccount_find_fields($target,$db);    
    }
    elsif($action =~/Bank_Detail/){
        $activetab=2;
        @tabs=(
            ["$target?action=SEARCH_FORM",'Search'],
            ["$target?action=BANK",'Bank Accounts'],
            ["$target?action=BANK_confirm&amp;intAssocID=$assocID",'Details'],
        );
       ($subBody,$menu)=handle_paymentapplication($db,$action,$target, $escAssocName); 
    }
	$subBody=create_tabs($subBody, undef, \@tabs, undef, $activetab, $assocName, $menu);
	$body=$subBody if $subBody;
	disconnectDB($db) if $db;
	print_adminpageGen($body, "", "");
}


sub display_find_fields {
	my($target, $db)=@_;
	my $st=qq[ SELECT intRealmID, strRealmName FROM tblRealms ORDER BY strRealmName];
	my $realms=getDBdrop_down('realmID',$db,$st,'','&nbsp;') || '';
	my $body = qq[
	<form action="$target" method="post">
	<input type="hidden" name="action" value="APP_list">
	<table style="margin-left:auto;margin-right:auto;">
	<tr>
    <td class="formbg fieldlabel">Application ID:&nbsp;<input type="text" name="paymentapp_id" size="30"></td>
  </tr>
	<tr>
		<td class="formbg fieldlabel">Application Type:&nbsp;
			<select name="paymentapp_type">
				<option value="13" SELECTED>NAB</option>
				<option value="11">PayPal</option>
			</select>
		</td>
	</tr>

	<tr>
		<td class="formbg fieldlabel">Application Status:&nbsp;<select name="paymentapp_status"><option value="" SELECTED></option>
	];
	
	foreach my $k (keys %Defs::applicationStatus)	{
		$body .= qq[<option value="$k">$Defs::applicationStatus{$k}</option>];
	}

	$body.=qq[
		</select></td>
	</tr> 

	<tr>
    <td class="formbg fieldlabel">NAB Merchant Username:&nbsp;<input type="text" name="merchant_username" size="30"></td>
  </tr>
	<tr>
    <td class="formbg fieldlabel">PayPal Email:&nbsp;<input type="text" name="pms_email" size="30"></td>
  </tr>
	<tr>
		<td class="formbg fieldlabel">Association Name:&nbsp;<input type="text" name="assoc_name" size="30"></td>
	</tr>
	<tr>
		<td class="formbg fieldlabel">Association ID:&nbsp;<input type="text" name="assoc_id" size="30"></td>
	</tr>
	<tr>
		<td class="formbg fieldlabel">Club Name:&nbsp;<input type="text" name="club_name" size="30"></td>
	</tr>
	<tr>
		<td class="formbg fieldlabel">Club ID:&nbsp;<input type="text" name="club_id" size="30"></td>
	</tr>
	<tr>
		<td class="formbg fieldlabel">Promo Code:&nbsp;<input type="text" name="promo_code" size="30"></td>
	</tr>

	<tr>
		<td class="formbg fieldlabel">Created Date (Start):&nbsp;<input type="text" name="start_date" size="30"></td>
		<td rowspan=2><i>Dates should be<br> formatted<br> YYYY-MM-DD</i></td></tr>
	<tr>
		<td class="formbg fieldlabel">Created Date (End):&nbsp;<input type="text" name="end_date" size="30"></td>
	</tr>
	<tr>
		<td class="formbg fieldlabel">Realm:&nbsp;$realms</td>
	</tr>
	<tr>
		<td class="formbg fieldlabel">Sub Realm ID:&nbsp;<input type="text" name="sub_realm_id" size="30"></td>
	</tr>
	<tr>
		<td class="formbg"><input type="submit" name="submit" value="S E A R C H"></td>
	</tr>
	</table>
	</form>
	];
}
sub bankAccount_find_fields {
    my($target, $db)=@_;
    my $st=qq[ SELECT intRealmID, strRealmName FROM tblRealms ORDER BY strRealmName];
    my $realms=getDBdrop_down('realmID',$db,$st,'','&nbsp;') || '';
    my $levels=qq[<select name ="entityTypeID">
                    <option value ="$Defs::LEVEL_CLUB">Club($Defs::LEVEL_CLUB)</option>
                    <option value="$Defs::LEVEL_ASSOC">Association($Defs::LEVEL_ASSOC)</option>
                    <option value="$Defs::LEVEL_ZONE">Zone($Defs::LEVEL_ZONE)</option>
                    <option value="$Defs::LEVEL_REGION">Region($Defs::LEVEL_REGION)</option>
                    <option value="$Defs::LEVEL_STATE">State($Defs::LEVEL_STATE)</option>
                    <option value="$Defs::LEVEL_NATIONAL">National($Defs::LEVEL_NATIONAL)</option>
                </select>];
    my $body = qq[
    <form action="$target" method="post">
    <input type="hidden" name="action" value="Bank_Detail_list">
    <table style="margin-left:auto;margin-right:auto;">
    <tr>
        <td class="formbg fieldlabel">Name:&nbsp;<input type="text" name="name_in" size="30"></td>
    </tr>
    <tr>
        <td class="formbg fieldlabel">ID:&nbsp;<input type="text" name="entityID" size="30"></td>
    </tr>
    <tr>
        <td class="formbg fieldlabel">Level:&nbsp;$levels</td>
    </tr>
    <tr>
        <td class="formbg fieldlabel">Realm:&nbsp;$realms</td>
    </tr>
    <tr>
        <td class="formbg"><input type="submit" name="submit" value="S E A R C H"></td>
    </tr>
</table>
    </form>
    ];

}


1;
