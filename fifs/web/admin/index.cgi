#!/usr/bin/perl -w

#
# $Header: svn://svn/SWM/trunk/web/admin/index.cgi 11645 2014-05-22 03:47:31Z apurcell $
#

use lib "../..","..",".","../RegoForm/","../../..","../PaymentSplit",'../RegoFormBuilder',"../Facilities";
#use lib "/u/regonew_live","/u/regonew_live/web","/u/regonew_live/web/admin";
use DBI;
use CGI qw(param unescape escape);
use Defs;
use Utils;
use strict;
use warnings;
use AdminPageGen;
use AdminCommon;
use RealmAdmin;
use AssocAdmin;
use LoginAdmin;
use ClubAdmin;
use ClearDollar;
use FormHelpers;
use UtilsAdmin;
use MCache;
use ClearanceRemove;
use MemberCardAdmin;
use MRTConfig;
use SystemConfigAdmin;
use MemberAdmin;
use DataAdmin;
use RFTAdmin;
use StatsAdmin;
use BankAccount;
use TempRegos;
use CopyMemberWizard;
use PaymentAdmin;
use Data::Dumper;
use AdminTests;

main();

sub main	{

# Variables coming in
    my $header = "Content-type: text/html\n\n";
    my $body = "";
    my $title = "$Defs::sitename Administration";
    my $output=new CGI;
    my $action = param('action') || param('a') || 'SEARCH_FORM';
    my $sport= param('sport') || '';
    my $country= param('country') || '';
    my $url = param('decodeurl') || '';
    my $assoc_name_IN = param('assoc_name') || '';
    my $assoc_fsc_IN = param('assoc_fsc') || '';
    my $assoc_un_IN = param('assoc_un') || '';
    my $assoc_id_IN = param('assoc_id') || '';
    my $assoc_email_IN = param('assoc_email') || '';
    my $assoc_sportID_IN = param('sportID') || 0;

    my $assocID=param('intAssocID') || param('entityID') || param('aID') || param("swmid") || 0;
    my $assocName=param('AssocName') || '';
    my $escAssocName=escape($assocName);
    my $subBody='';
    my $menu='';
    my $activetab=0;
    my $activetop=0;
    my $target="index.cgi";

    my $error='';
    my $db=connectDB();
    if(!$db)	{
        $subBody=qq[You must select a country and sport<br>$error];
        $action='ERROR';
    }

    my @tabs=();
    my @topTabs=(

        ["$target?action=REALM_DETAILS",'Realms'],
        ["$target?action=LOGIN_SEARCH_FORM",'Nodes'],
        ["$target?action=SEARCH_FORM",'Associations'],
        ["$target?action=CLUB_SEARCH_FORM",'Clubs'],
        ["$target?action=MEMBER","Members"],
        ["$target?action=UTILS","Utils"],
        ["$target?action=DATA","Data"],	
        ["$target?action=TempReg","Temp Registration"],
        ["$target?action=COPY_MEMBERS",'Copy Member'],
        ["$target?action=TESTS",'Tests'],
    );

    #["$target?action=TEAM",'Team']
    if ($action =~/CLEAR/)	{
        ($subBody,$menu)=handle_clearDollar($db,$action,$target, $escAssocName, $sport, $country);
    }
    elsif($action=~/ASSOC_/ or  $action eq "SEARCH_FORM") {
        $activetop=2;
        my $hash_value = AdminCommon::create_hash_qs(0,0,$assocID,0,0);
        @tabs=(
            ["$target?action=SEARCH_FORM",'Search'],
            ["$target?action=ASSOC_new",'Add'],
            ["$target?action=ASSOC_edit&amp;intAssocID=$assocID&amp;hash=$hash_value",'Details'],
        );
        $activetab=1 if($action eq 'ASSOC_new');
        $activetab=2 if($action eq 'ASSOC_list');
        $activetab=2 if($action eq 'ASSOC_edit');
        $activetab=3 if($action eq 'ASSOC_passport');
        $activetab=4 if($action eq 'ASSOC_loc');
        $activetab=5 if($action eq 'ASSOC_upl');
        $activetab=2 if($action eq 'ASSOC_lu');
        $activetab=6 if($action eq 'ASSOC_clubs');
        $activetab=7 if($action =~ /ASSOC_comps/);
        $activetab=8 if($action eq 'ASSOC_clear_club');
        $activetab=8 if($action eq 'ASSOC_tstamp' or $action eq 'ASSOC_tstamp_reset' );
        $activetab=9 if($action =~ /ASSOC_config/);
        $activetab=10 if($action =~ /ASSOC_ASSOC_config/);
        $activetab=11 if($action =~ /ASSOC_agreements/);
        $activetab=12 if($action =~ /ASSOC_paymentsplits/);
        $activetab=13 if($action =~ /ASSOC_BankAccount/);
        $activetab=14 if($action =~ /ASSOC_memberhide/);
        if($assocID)	{
            push @tabs, ["$target?action=ASSOC_passport&intAssocID=$assocID&AssocName=$escAssocName&amp;hash=$hash_value",'Passport'];
            push @tabs, ["$target?action=ASSOC_loc&intAssocID=$assocID&AssocName=$escAssocName&amp;hash=$hash_value",'Location'];
            push @tabs, ["$target?action=ASSOC_upl&intAssocID=$assocID&AssocName=$escAssocName&amp;hash=$hash_value",'Syncs'];
            push @tabs, ["$target?action=ASSOC_clubs&intAssocID=$assocID&AssocName=$escAssocName&amp;hash=$hash_value",'Clubs'];
            push @tabs, ["$target?action=ASSOC_comps&intAssocID=$assocID&AssocName=$escAssocName&amp;hash=$hash_value",'Comps'];
            push @tabs, ["$target?action=ASSOC_tstamp&intAssocID=$assocID&AssocName=$escAssocName&amp;hash=$hash_value",'Timestamps'];
            push @tabs, ["$target?action=ASSOC_config&intAssocID=$assocID&amp;hash=$hash_value",'SWOL Configs'];
            push @tabs, ["$target?action=ASSOC_ASSOC_config&intAssocID=$assocID&amp;hash=$hash_value",'Assoc Config'];	
            push @tabs, ["$target?action=ASSOC_agreements&intAssocID=$assocID&amp;hash=$hash_value",'Interchange Agreements'];
            push @tabs, ["$target?action=ASSOC_paymentsplits&intAssocID=$assocID&amp;hash=$hash_value",'Payment Splits'];
            push @tabs, ["$target?action=ASSOC_BankAccount&intAssocID=$assocID&amp;hash=$hash_value",'Bank Account'];
            push @tabs, ["$target?action=ASSOC_memberhide&intAssocID=$assocID&amp;hash=$hash_value",'Member Hide'];
        }



        if($action eq "SEARCH_FORM") {
            $activetab=0;
            $subBody = display_find_fields($target,$db);
        }
        elsif($action =~ /ASSOC_agreements/ or $action=~/ASSOC_IA/) {
            print STDERR "INTERCHANGEAGREEMENTS";
            $subBody = handle_interchange_agreements($db,$action,$target,$assocID);
        }
        else {

            ($subBody,$menu)=handle_assoc($db,$action,$target, $escAssocName, $sport, $country);
        }
    }
    elsif ($action =~ /LOGIN_/) {
        $activetop=1;
        my $nodeID = param("nodeID"); 
        if($nodeID){
            my $level = param("level");
            my $hash_value = AdminCommon::create_hash_qs(0,$nodeID,0,0,0);
            @tabs=(
                ["$target?action=LOGIN_SEARCH_add_login&nodeID=$nodeID&level=$level&hash=$hash_value",'Add Login'],
                ["$target?action=LOGIN_NODE_BankAccount&nodeID=$nodeID&level=$level&hash=$hash_value",'Bank Account'],              
            );

        }
        my $level = param("level");
        $activetab=0 if($action =~ /LOGIN_SEARCH_add_login/);
        $activetab=1 if($action =~ /NODE_BankAccount/);
        if ($action eq "LOGIN_SEARCH_list") {
            $subBody = display_login_search_list($db, $action, $assocID, $target);
        }
        elsif ($action eq "LOGIN_SEARCH_add_login") {
            $subBody = edit_login_form($db, $target, 'add');
        }
        elsif ($action eq "LOGIN_SEARCH_update_login") {
            $subBody = edit_login_form($db, $target, 'edit');
        }
        elsif ($action eq "LOGIN_SEARCH_insert_login") {
            $subBody = modify_login_details($db, $target, 'insert');
        }
        elsif ($action eq "LOGIN_SEARCH_modify_login") {
            $subBody = modify_login_details($db, $target, 'modify');
        }
        elsif ($action eq "LOGIN_SEARCH_edit_node_name") {
            $subBody = edit_node_name($db, $target, 'update');
        }
        elsif ($action eq "LOGIN_SEARCH_update_node_name") {
            $subBody = modify_node_name($db, $target, 'modify');
        }
        elsif ($action =~ /LOGIN_NODE_BankAccount/) {
            $subBody = BankAccount($db, $target);
        }
        else {
            $subBody = display_login_search_form($target,$db);
        }
    }
    elsif ($action =~ /CLUB_/) {
        $activetop=3;
        my $clubID = param("clubID");
        my $hash_value = AdminCommon::create_hash_qs(0,0,0,$clubID,0);
        @tabs=(
            ["$target?action=CLUB_SEARCH_FORM&hash=$hash_value",'Club Search'],
            ["$target?action=CLUB_INFO&clubID=$clubID&hash=$hash_value",'Club Info'],

        );
        $activetab=1 if($action =~ /CLUB_INFO/ or $action =~ /CLUB_DELETE/ or $action eq "CLUB_SEARCH_edit");
        $activetab=2 if($action =~ /CLUB_BankAccount/);
        if($clubID){
            push @tabs, ["$target?action=CLUB_BankAccount&clubID=$clubID&hash=$hash_value",'Bank Account'];
        }
        if ($action eq "CLUB_SEARCH_list") {
            $subBody = display_club_search_list($db, $action, $assocID, $target);
        }
        elsif ($action =~  /CLUB_BankAccount/) {
            $subBody = BankAccount($db, $target);
        }
        elsif ($action eq "CLUB_SEARCH_edit") {
            $subBody = edit_club_form($db, $target, 'add');
        }
        elsif ($action eq "CLUB_SEARCH_update") {
            $subBody = modify_club_details($db, $target);
        }
        elsif ($action eq "CLUB_SEARCH_umpire") {
            $subBody = setup_umpire_allocation($db, $target);
        }
        elsif ($action eq "CLUB_SEARCH_delete_umpire") {
            $subBody = delete_umpire_allocation($db, $target);
        }
        elsif ($action eq "CLUB_SEARCH_delete_club") {
            $subBody = mark_club_as_deleted($db, $target);
        }
        elsif ($action eq "CLUB_SEARCH_restore_club") {
            $subBody = mark_club_as_undeleted($db, $target);
        }
        elsif($action eq "CLUB_DELETE")
        {
            my $memberID = item_set_delete($db);
            $subBody = team_club($db,$target, $memberID);
        }
        elsif ($action eq "CLUB_INFO") {
            my $memberID = param("clubID");
            $subBody = club_info($db,$target, $memberID);
        }
        else {
            $subBody = display_club_search_form($target,$db);
        }
    }
    elsif ($action =~ /REALM_/) {
        $activetop=0;
        $activetab=0;

        @tabs=(
            ["$target?action=REALM_DETAILS",'List of Realms'],
            ["$target?action=REALM_ADD",'Add Realm'],
            ["$target?action=REALM_SUBADD",'Add Subrealm'],
            ["$target?action=REALM_CONFIG",'Realm Config'],
            ["$target?action=REALM_DEFCODES",'Realm Defcodes'],
            ["$target?action=REALM_PAYMENT",'Realm Payments'],
        );


        if($action =~ /REALM_ADD/) {
            $activetab = 1;
            ($subBody, $menu) = handle_realm($db, $action, $target);
        }
        elsif($action =~ /REALM_SUBADD/) {
            $activetab = 2;
            ($subBody, $menu) = handle_realm($db, $action, $target);
        }

        elsif($action =~ /REALM_CONFIG/ or $action=~/REALM_SC/) {
            $activetab = 3;
            ($subBody, $menu) = handle_system_config($db, $action, $target);
        }
        elsif($action =~ /REALM_DEFCODES/ or $action=~/REALM_DC/) {
            $activetab = 4;
            ($subBody, $menu) = handle_defcodes_config($db, $action, $target);
        }
        elsif($action =~ /REALM_PAYMENT/) {
            $activetab = 5;

            if ($action eq "REALM_PAYMENT") {
                # Just display an empty screen
                ($subBody, $menu) = PaymentAdmin::payment_display_input_screen($db, $action, $target);
            }
            else {
                # Validate input from the screen and 
                ($subBody, $menu) = PaymentAdmin::payment_update_db($db, $action, $target);
            }
        }

        else {
            ($subBody, $menu) = handle_realm($db, $action, $target);
        }	
    }
    elsif ($action =~ /TEAM/) {
        $activetop=4;
        $activetab=0;
        $activetab=0 if($action eq "TEAM_SEARCH");
        $activetab=1 if($action =~ /TEAM_INFO/ or $action =~ /TEAM_DELETE/);
        $activetab=2 if($action =~ /TEAM_BankAccount/);
        @tabs=(
            ["$target?action=TEAM_SEARCH",'Search Team'] 
        );
        my $teamID = param("teamID");
        if($teamID){
            push @tabs, ["$target?action=TEAM_INFO&teamID=$teamID",'Team Info'];
            push @tabs, ["$target?action=TEAM_BankAccount&teamID=$teamID",'Bank Account'];

        }
        if ($action eq "TEAM_list") {
            $subBody = display_team_search_list($db, $action, $assocID, $target);
        }
        elsif($action eq "TEAM_DELETE")
        {
            my $memberID = item_set_delete($db);
            $subBody = team_info($db,$target, $memberID);
        }
        elsif ($action eq "TEAM_INFO") {
            my $memberID = param("teamID");
            $subBody = team_info($db,$target, $teamID);
        }
        elsif ($action =~ /TEAM_BankAccount/) {	
            $subBody = BankAccount($db, $target);
        }
        else {
            $subBody = display_team_form($target,$db);
        }




    }
    elsif ($action =~ /DATA/) {
        $activetop =6;
        my $type = param("type");
        my $useID = param("useID");
        if($action eq "DATA_DELETE")
        {
            ($useID, $type) = item_set_delete($db);
        }

        elsif($action eq "DATA_TS")
        {
            timestamp_now($db);
        }
        elsif($action eq "DATA_UPDATE")
        {
            item_set_update($db);
        }

        if($action eq "DATA_EDIT")
        {
            $subBody = item_set_edit($db);
        }
        elsif($action eq "DATA_FIELDCHECK")
        {
            $subBody =fieldPermCheck ($db);
        }
        elsif($action eq "DATA_PUBLISH")
        {
            $subBody = data_publish($db);
        }
        else
        {
            $subBody = data_info($db,$target, $type,$useID);
        }
    }
    elsif ($action =~ /STATS/) {
        $activetop =7;
        if($action eq "STATS_INFO") {
            $subBody = node_stats($db);
        } else {
            $subBody = node_selection($db);
        }
    }elsif($action =~ /COPY_MEMBERS/){
        $activetop = 8;
        $subBody = ShowWizard($db,$target); 
        print STDERR Dumper($output->{'param'});
        #if($action eq "COPY_MEMBER_finish"){
        #    $subBody = Copy_Members($db,$output->{'param'});
        #}
    }
    elsif ($action =~ /MEMBER/) {
        $activetop =4;
        if($action eq "MEMBER_INFO")
        {
            $subBody = display_member_search_list($db,$action,'',$target);		
        }
        else
        {
            $subBody = display_member_form($target,$db);
        }
    }
    elsif ($action =~ /UTILS/ or $action =~ /RFT/) {
        $activetop=5;
        @tabs=(
            ["$target?action=UTILS_decodeURL",'DecodeURL'],
            ["$target?action=UTILS_processlog",'Process Log'],
            ["$target?action=UTILS_CARDS",'Member Cards'],
            ["$target?action=UTILS_clearance",'Remove Clearance'],
            ["$target?action=UTILS_auskick",'Auskick Admin'],
            ["$target?action=UTILS_school",'School Admin'],
            ["$target?action=UTILS_teamsheets",'Team Sheets'],
            ["$target?action=UTILS_holidays",'Payment Exclusions'],
            ["$target?action=UTILS_categories",'Entity Categories'],
            ["$target?action=UTILS_SWOL_setup",'SWOL Setup'],
            ["$target?action=RFT",'RegoForm Templates'],
            ["$target?action=UTILS_compAuskick",'Auskick Comparison'],
            ["$target?action=ASSOC_memberhide&intAssocID=0",'Member Hide'],
            ["$target?action=UTILS_MRT",'MRT Config'],
        );

        if($action eq "UTILS" or $action eq "UTILS_decodeURL") {
            $activetab=0;
            my $cache = new MCache;
            $subBody = decodeForm($target, $url);
            $subBody .= decodeInfo($url, $db, $cache) if $url;

        }
        elsif($action =~ /UTILS_clearance/) {
            $activetab=3;
            $subBody = clearance_remove($db,$target);
        }
        elsif($action =~ /UTILS_processlog/) {
            $activetab=1;
            $subBody = _build_process_log_report();
        }
        elsif($action =~ /UTILS_CARDS/ or $action=~/UTILS_MC/) {
            $activetab = 2;
            ($subBody, $menu) = handle_member_card($db, $action, $target);
        }
        elsif($action =~ /UTILS_auskick/) {
            $activetab=4;
            $subBody = auskickAdmin($db,$target);
        }
        elsif($action =~ /UTILS_school/) {
            $activetab=5;
            $subBody = schoolAdmin($db,$target);
        }
        elsif($action =~ /UTILS_teamsheets/ or $action=~/UTILS_TS/) {
            $activetab=6;
            ($subBody,$menu) = handle_teamsheets($db,$action,$target);
        }
        elsif($action =~ /UTILS_holidays/ or $action=~/UTILS_H/) {
            $activetab=7;
            ($subBody,$menu) = handle_holidays($db,$action,$target);
        }
        elsif($action =~ /UTILS_categories/ or $action=~/UTILS_C/) {
            $activetab=8;
            ($subBody,$menu) = handle_categories($db,$action,$target);
        }
        elsif($action =~ /UTILS_SWOL_setup/) {
            $activetab=9; 
            my %Data = ();
            $Data{'action'} = param('a') || '';
            $Data{'swmid'} = param('swmid') || $assocID || '';
            $Data{'swmidcopy'} = param('swmidcopy') || '';
            $Data{'defaultcopyid'} = param('defaultcopyid') || '';
            $Data{'fsc'} = param('fsc') || '';
            $Data{'swwu'} = param('swwu') || '';
            $Data{'swwp'} = param('swwp') || '';
            $Data{'sport'} = param('sport') || '';

            if ($Data{'action'} eq "confirm") {
                $subBody = confirmData($db, \%Data,$assocID);
            }
            elsif ($Data{'action'} eq "setup") {
                $subBody = setupSWOL($db, \%Data, $assocID);
            }
            else {
                $subBody = displayMenu('', \%Data, $assocID);

            }
        }
        elsif($action =~ /RFT/) {
            $activetab=10    ;

            $subBody = qq[
            <br>
            <div style="margin-left:22px;padding-bottom:5px;"><a href="?a=RFT">Search</a> | <a href="$target?a=RFT_list">List All</a> | <a href="$target?a=RFT_add">Add New</a></div>
            ];


            my %Data   = ();
            $Data{'db'}     = $db;
            $Data{'target'} = $target;
            $subBody .= handle_template($action, \%Data);

        }
        elsif($action =~ /UTILS_compAuskick/) {
            $activetab=11;
            $subBody =auskickComp($db);
            #$subBody = getProcessLogReport($db);
        }
        elsif($action =~ /UTILS_MRT/) {
            $activetab = 13;
            ($subBody, $menu) = handle_mrt_config($db, $action, $target);
        }

    }
    elsif($action =~ /TempReg/) {
        $activetop=7;
        my $formID = param("formID");
        if($action eq "TempReg_Display")
        {
            $subBody = DisplayTempRegos($db,$formID);
        }

        else{
            $subBody = searchTempRegos($db);
        }

    }
    elsif($action =~ /TESTS/) {
        $activetop = 9;
        if ($action eq 'TESTS_RUN'){
            my @test_sets = param('test_set');
            my $verbosity = param('verbosity');
            my $results = run_tests(\@test_sets, $verbosity);
            $subBody = qq[<pre>$results->{'output'}</pre>] if $results->{'output'};
            $subBody .= qq[<pre class="redtext">$results->{'errors'}</pre>] if $results->{'errors'};
        }
        else {
            $subBody = show_tests();
        }
    }

    if(check_access($action)==0) {
        $subBody = '<p align="center">You do not have access for this page.If you feel this may be an error, please contact someone.</p>';
    }
    $subBody=create_tabs($subBody, \@topTabs,\@tabs, $activetop,$activetab, $assocName, $menu);
    $body=$subBody if $subBody;
    disconnectDB($db) if $db;
    print_adminpageGen($body, $title,'');
}

sub display_find_fields {

    my($target, $db)=@_;

    my $realmid = AdminCommon::get_realmid();

    my $st = "";
    my $st2 = "";
    my $realms = "";
    if (undef == $realmid) {
        $st=qq[ SELECT intRealmID, strRealmName FROM tblRealms ORDER BY strRealmName];
        $realms=getDBdrop_down('realmID',$db,$st,'','&nbsp;') || '';

        $st2=qq[
        select S.intSubTypeID, concat(R.strRealmName," - ",S.strSubTypeName) as strSubRealmName
        FROM tblRealmSubTypes S
        INNER JOIN tblRealms R ON R.intRealmID = S.intRealmID 
        ORDER BY R.strRealmName, S.strSubTypeName;
        ];
    } 
    else {
        $st=qq[ SELECT intRealmID, strRealmName FROM tblRealms WHERE intRealmID IN ($realmid) ORDER BY strRealmName];	
        $realms=getDBdrop_down('realmID',$db,$st,'','') || '';

        $st2=qq[
        select S.intSubTypeID, concat(R.strRealmName," - ",S.strSubTypeName) as strSubRealmName
        FROM tblRealmSubTypes S
        INNER JOIN tblRealms R ON R.intRealmID = S.intRealmID 
        WHERE R.intRealmID IN ($realmid)  
        ORDER BY R.strRealmName, S.strSubTypeName;
        ];
    }

    $realms =~ s/class = ""/class = "chzn-select"/g;
    my $subrealms=getDBdrop_down('subRealmID',$db,$st2,'','&nbsp;') || '';
    $subrealms =~ s/class = ""/class = "chzn-select"/g;

    my $body = qq[
    <form action="$target" method="post">
    <input type="hidden" name="action" value="ASSOC_list">
    <table style="margin-left:auto;margin-right:auto;">
    <tr>
    <td class="formbg fieldlabel">Name:&nbsp;<input type="text" name="assoc_name" size="50"></td>
    </tr>
    <tr>
    <td class="formbg fieldlabel">First Sync Code:&nbsp;<input type="text" name="assoc_fsc" size="50"></td>
    </tr>
    <tr>
    <td class="formbg fieldlabel">ID:&nbsp;<input type="text" name="assoc_id" size="50"></td>
    </tr>
    <tr>
    <td class="formbg fieldlabel">Association Username:&nbsp;<input type="text" name="assoc_un" size="50"></td>
    </tr>
    <tr>
    <td class="formbg fieldlabel">Email:&nbsp;<input type="text" name="assoc_email" size="50"></td>
    </tr>
    <tr>
    <td class="formbg fieldlabel">Realm:&nbsp;$realms</td>
    </tr>
    <tr>
    <td class="formbg fieldlabel">SubRealm:&nbsp;$subrealms</td>
    </tr>
    <tr>
    <td class="formbg fieldlabel">Uses SWOL:&nbsp;
    <select name="assoc_swol">
    <option value="">--Please Select--</option>
    <option value='No'>No</option>
    <option value='Yes'>Yes</option>
    </select>
    </td>
    </tr>

    <tr>
    <td class="formbg fieldlabel">Include deleted:&nbsp;
    <select name="inclDeleted">
    <option value="">--Please Select--</option>
    <option value='No' selected>No</option>
    <option value='Yes'>Yes</option>
    </select>
    </td>
    </tr>

    <tr>
    <td class="formbg"><input type="submit" name="submit" value="S E A R C H"></td>
    </tr>
    </table>
    </form>
    ];
}

sub display_login_search_form {

    my ($target, $db) = @_;

    my $realmid = AdminCommon::get_realmid();

    my $st = "";
    my $st2 = "";
    my $realms = "";
    if (undef == $realmid) {
        $st=qq[ SELECT intRealmID, strRealmName FROM tblRealms ORDER BY strRealmName];
        $realms=getDBdrop_down('realmID',$db,$st,'','&nbsp;') || '';

        $st2=qq[
        select S.intSubTypeID, concat(R.strRealmName," - ",S.strSubTypeName) as strSubRealmName
        FROM tblRealmSubTypes S
        INNER JOIN tblRealms R ON R.intRealmID = S.intRealmID 
        ORDER BY R.strRealmName, S.strSubTypeName;
        ];
    } 
    else {
        $st=qq[ SELECT intRealmID, strRealmName FROM tblRealms WHERE intRealmID IN ($realmid) ORDER BY strRealmName];	
        $realms=getDBdrop_down('realmID',$db,$st,'','') || '';

        $st2=qq[
        select S.intSubTypeID, concat(R.strRealmName," - ",S.strSubTypeName) as strSubRealmName
        FROM tblRealmSubTypes S
        INNER JOIN tblRealms R ON R.intRealmID = S.intRealmID 
        WHERE R.intRealmID IN ($realmid)  
        ORDER BY R.strRealmName, S.strSubTypeName;
        ];
    }

    $realms =~ s/class = ""/class = "chzn-select"/g;
    my $subrealms=getDBdrop_down('subRealmID',$db,$st2,'','&nbsp;') || '';
    $subrealms =~ s/class = ""/class = "chzn-select"/g;

    return qq[
    <form action="$target" method="post">
    <input type="hidden" name="action" value="LOGIN_SEARCH_list">
    <table style="margin-left:auto;margin-right:auto;">
    <tr>
    <tr>
    <td class="formbg fieldlabel">ID:&nbsp;<input type="text" name="assoc_id" size="50"></td>
    </tr>
    <td class="formbg fieldlabel">Name:&nbsp;<input type="text" name="assoc_name" size="50"></td>
    </tr>

    <tr>
    <td class="formbg fieldlabel">Username:&nbsp;<input type="text" name="assoc_un" size="50"></td>
    </tr>
    <tr>
    <td class="formbg fieldlabel">Realm:&nbsp;$realms</td>
    </tr>
    <tr>
    <tr>
    <td class="formbg fieldlabel">SubRealm:&nbsp;$subrealms</td>
    </tr>
    <td class="formbg fieldlabel">Level:&nbsp;<input type="text" name="level" size="22"></td>
    </tr>
    <tr>
    <td class="formbg"><input type="submit" name="submit" value="S E A R C H"></td>
    </tr>
    </table>
    </form>
    ];
}
sub display_club_search_form {

    my ($target, $db) = @_;

    my $realmid = AdminCommon::get_realmid();

    my $st = "";
    my $st2 = "";
    my $realms = "";
    if (undef == $realmid) {
        $st=qq[ SELECT intRealmID, strRealmName FROM tblRealms ORDER BY strRealmName];
        $realms=getDBdrop_down('realmID',$db,$st,'','&nbsp;') || '';

        $st2=qq[
        select S.intSubTypeID, concat(R.strRealmName," - ",S.strSubTypeName) as strSubRealmName
        FROM tblRealmSubTypes S
        INNER JOIN tblRealms R ON R.intRealmID = S.intRealmID 
        ORDER BY R.strRealmName, S.strSubTypeName;
        ];
    } 
    else {
        $st=qq[ SELECT intRealmID, strRealmName FROM tblRealms WHERE intRealmID IN ($realmid) ORDER BY strRealmName];	
        $realms=getDBdrop_down('realmID',$db,$st,'','') || '';

        $st2=qq[
        select S.intSubTypeID, concat(R.strRealmName," - ",S.strSubTypeName) as strSubRealmName
        FROM tblRealmSubTypes S
        INNER JOIN tblRealms R ON R.intRealmID = S.intRealmID 
        WHERE R.intRealmID IN ($realmid)  
        ORDER BY R.strRealmName, S.strSubTypeName;
        ];
    }

    $realms =~ s/class = ""/class = "chzn-select"/g;
    my $subrealms=getDBdrop_down('subRealmID',$db,$st2,'','&nbsp;') || '';
    $subrealms =~ s/class = ""/class = "chzn-select"/g;

    return qq[
    <form action="$target" method="post">
    <input type="hidden" name="action" value="CLUB_SEARCH_list">
    <table style="margin-left:auto;margin-right:auto;">
    <tr>
    <td class="formbg fieldlabel">Name:&nbsp;<input type="text" name="club_name" size="50"></td>
    </tr>
    <tr>
    <td class="formbg fieldlabel">Club Email:&nbsp;<input type="text" name="club_email" size="50"></td>
    </tr>
    <tr>
    <td class="formbg fieldlabel">Username:&nbsp;<b>3</b><input type="text" name="club_un" size="50"></td>
    </tr>

    <tr>
    <td class="formbg fieldlabel">Club ID:&nbsp;<input type="text" name="club_id" size="50"></td>
    </tr>
    <tr>
    <td class="formbg fieldlabel">Assoc ID:&nbsp;<input type="text" name="club_assoc_id" size="50"></td>
    </tr>
    <tr>
    <td class="formbg fieldlabel">Realm:&nbsp;$realms</td>
    </tr>
    <tr>
    <tr>
    <td class="formbg fieldlabel">SubRealm:&nbsp;$subrealms</td>
    </tr>
    <td class="formbg"><input type="submit" name="submit" value="S E A R C H"></td>
    </tr>
    </table>
    </form>
    ];
}
sub display_data_form {

    my ($target, $db) = @_;

    my $body = qq[  
    <table style="margin-left:auto;margin-right:auto;">
    <tr><td class="formbg"><h2>Member Info?</h2>

    <form action="$target" method="post">
    <b>MemberID</b>: <input type = "text" value = "" size =" 15" name = "memberID"><br>
    <input type="submit" name="submit" value="Get Info">
    <input type = "hidden" name="action" value="DATA_MEMBER_INFO">
    </div>
    </form><br>
    </td></tr></table>
    ];

}
sub display_member_form {

    my ($target, $db) = @_;

    my $realmid = AdminCommon::get_realmid();

    my $st = "";
    my $realms = "";
    if (undef == $realmid) {
        $st=qq[ SELECT intRealmID, strRealmName FROM tblRealms ORDER BY strRealmName];
        $realms=getDBdrop_down('realmID',$db,$st,'','&nbsp;') || '';
    } 
    else {
        $st=qq[ SELECT intRealmID, strRealmName FROM tblRealms WHERE intRealmID IN ($realmid) ORDER BY strRealmName];	
        $realms=getDBdrop_down('realmID',$db,$st,'','') || '';
    }

    $realms =~ s/class = ""/class = "chzn-select"/g;

    my $body = qq[
    <table style="margin-left:auto;margin-right:auto;">
    <tr><td class="formbg"><h2>Search Member?</h2>

    <form action="$target" method="post">

    <table style="margin-left:auto;margin-right:auto;">
    <tr>
    <td class="formbg fieldlabel">First Name:&nbsp;<input type="text" name="member_firstname" size="50"></td>
    </tr>
    <tr>
    <td class="formbg fieldlabel">Surname:&nbsp;<input type="text" name="member_surname" size="50"></td>
    </tr>
    <tr>
    <td class="formbg fieldlabel">National Number&nbsp;<input type="text" name="member_id" size="50"></td>
    </tr>
    <tr>
    <td class="formbg fieldlabel">Email&nbsp;<input type="text" name="member_email" size="50"></td>
    </tr>
    <tr>
    <td class="formbg fieldlabel">Realm:&nbsp;$realms</td>
    </tr>
    <tr>
    <td class="formbg"><input type="submit" name="submit" value="S E A R C H"></td>
    </tr>
    </table>
    <input type = "hidden" name="action" value="MEMBER_INFO">
    </form><br>
    </td></tr></table>
    ];

}

sub display_team_form {

    my ($target, $db) = @_;

    my $realmid = AdminCommon::get_realmid();

    my $st = "";
    my $realms = "";
    if (undef == $realmid) {
        $st=qq[ SELECT intRealmID, strRealmName FROM tblRealms ORDER BY strRealmName];
        $realms=getDBdrop_down('realmID',$db,$st,'','&nbsp;') || '';
    } 
    else {
        $st=qq[ SELECT intRealmID, strRealmName FROM tblRealms WHERE intRealmID IN ($realmid) ORDER BY strRealmName];	
        $realms=getDBdrop_down('realmID',$db,$st,'','') || '';
    }


    return qq[
    <form action="$target" method="post">
    <input type="hidden" name="action" value="TEAM_list">
    <table style="margin-left:auto;margin-right:auto;">
    <tr>
    <td class="formbg fieldlabel">Team Name:&nbsp;<input type="text" name="team_name" size="50"></td>
    </tr>
    <tr>
    <td class="formbg fieldlabel">Club ID&nbsp;<input type="text" name="club_id" size="50"></td>
    </tr>
    <tr>
    <td class="formbg fieldlabel">Assoc ID&nbsp;<input type="text" name="assoc_id" size="50"></td>
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

sub _build_process_log_report {
    return '<div id="processLogReportDivId"><iframe src="processlog.cgi" frameborder="0" style="width:100%; height:100%"></iframe></div><script type="text/javascript">document.getElementById("processLogReportDivId").style.height=window.innerHeight-200;</script>';
}
