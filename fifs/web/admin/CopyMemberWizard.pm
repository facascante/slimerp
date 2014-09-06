#
# $Header: svn://svn/SWM/trunk/web/admin/RealmAdmin.pm 9336 2013-08-26 02:04:46Z dhanslow $
#

package CopyMemberWizard;

require Exporter;
@ISA =  qw(Exporter);
@EXPORT = qw(ShowWizard Copy_Members cal_MembeNumber);
@EXPORT_OK = qw(ShowWizard Copy_Members cal_MembeNumber);

use lib "..","../..","../comp";
use DBI;
use CGI qw(param unescape escape);
use strict;

use Defs;
use Utils;
use TechAdminCommon;
use DeQuote;
use FormHelpers;
use ClubObj;

sub ShowWizard{
    my ($db ,$target)=@_;
    my $content=  qq[ 
        <link href="wizard/css/jquery.wizard.css" rel="stylesheet" type="text/css">
        <script type="text/javascript" src="https://ajax.googleapis.com/ajax/libs/jquery/1.7.1/jquery.min.js"></script>
        <script type="text/javascript" src="wizard/smartWizard.js"></script>
	<style>
	    .warning
		{color:red}
	</style>
        <script type="text/javascript" src="wizard/copyMember.js"></script>
<table align="center" border="0" cellpadding="0" cellspacing="0">
<tr><td> 
            <div id="wizard" class="swMain">
                <ul>
                <li><a href="#step-1">
                <span class="stepNumber">1</span>
                <span class="stepDesc">
                   Step 1<br />
                   <small>Club Selection</small>
                </span>
            </a></li>
                <li><a href="#step-2">
                <span class="stepNumber">2</span>
                <span class="stepDesc">
                   Step 2<br />
                   <small>Options</small>
                </span>
            </a></li>
                <li><a href="#step-3">
                <span class="stepNumber">3</span>
                <span class="stepDesc">
                   Step 3<br />
                   <small>Review</small>
                </span>                   
             </a></li>
                
            </ul>
        <div id="step-1">
            <h2 class="StepTitle">Realm</h2>
		<table cellspacing="2" cellpadding="2" align="center">
		<tr>
		    <td colspan="2"></td>
		</tr>
		<tr align="left">
		    <td><label for="realmID">Realm:</label></td>
		    <td><select id="realmID" name ="realmID"></select>&nbsp;<span class="warning" id="msg_realm"></span>&nbsp;</td>
		</tr>
		<tr>
		    <td colspan="2"></td>
		</tr>
		</table>
	    <h2 class="StepTitle">From:</h2>
		<table cellspacing="2" cellpadding="2" align="center">
		<tr>
		    <td colspan="2"></td>
		</tr>
		
		<tr align="left">
		    <td><label for="fromAssoc">Association:</label></td>
		    <td><select id="fromAssoc" name="fromAssoc"></select>&nbsp;<span class="warning" id="msg_fromAssoc"></span>&nbsp;</td>
		</tr>
		<tr align="left">
		    <td><label for="fromClub">Club:</label></td>
		    <td><select id="fromClub" name="fromClub"></select>&nbsp;<span class="warning" id="msg_fromClub"></span>&nbsp;</td>
		</tr>
		<tr>
		    <td colspan="2"></td>
		</tr>
		</table>
	    <h2 class="StepTitle">To:</h2>
		<table cellspacing="2" cellpadding="2" align="center">
		<tr>
		    <td colspan="2"></td>
		</tr>
		<tr>
		
		    <td><label for="toAssoc">Association:</label></td>
		    <td><select id="toAssoc" name="toAssoc"></select>&nbsp;<span class="warning" id="msg_toAssoc"></span>&nbsp;</td>
		</tr>
		<tr>
		    <td><label for="toClub">Club:</label></td>
		    <td><select id="toClub" name="toClub" ></select>&nbsp;<span class="warning" id="msg_toClub"></span>&nbsp;</td>
		</tr>
		<tr>
		    <td colspan="2"></td>
		</tr>
		</table>
	    
        </div>
        <div id="step-2">
            <h2 class="StepTitle">Configuration Options:</h2>
	    <table cellspacing="2" cellpadding="2" align="center">
		<tr>
		    <td colspan="2"></td>
		</tr>
	        <tr>
		    <td><lable>From Season</label></td>
		    <td><select  name="FromseasonID" id = "FromseasonID" ></select>&nbsp;<span class="warning" id="msg_FromseasonID"></span>&nbsp;</td>
		</tr>
		<tr>
		    <td><lable>To Season</label></td>
		    <td><select  name="ToseasonID" id = "ToseasonID" ></select>&nbsp;<span class="warning" id="msg_ToseasonID"></span>&nbsp;</td>
		</tr>
		<tr>
		    <td><input type="checkbox" name="clearOut" id = "clearOut" /></td>
		    <td><lable>Clear out members</label></td>
		</tr>
		<tr>
		    <td><input type="checkbox" name="activeOldAssoc" id = "activeOldAssoc" /></td>
		    <td><lable>Keep member active in old association</label></td>
		</tr>
		<tr>
		    <td><input type="checkbox" name="activeNewAssoc" id = "activeNewAssoc" /></td>
		    <td><lable>Member are active in new association</label></td>
		</tr>
	    </table>
        </div>
        <div id="step-3">
            <h2 class="StepTitle" id="finalTitle">Review</h2>
	    <div id ="review"></div>
        </div>
       
      </div>
      <input type="hidden" name ="action" id ="action" value ="COPY_MEMBERS_finish" />
    </td></tr>
    </table> 
    ];
    return $content;
}
sub cal_MembeNumber {
    my($dbh,$fromAssocID,$fromClub,$season) =@_;
    my $clubObj = new ClubObj(('db'=>$dbh, 'assocID'=>$fromAssocID, 'ID'=>$fromClub));

    my $allPlayers = $clubObj->AllClubPlayers($season);
    my $Players = $clubObj->playersNotClearedOut($season);
    my $NonPlayers = $clubObj->activeNonPlayers($season);
    my $res = qq[<table align ="center"  cellpadding="10"><tbody>];
    $res .=qq[<tr><td><b>Total All Members: </b></td><td>]. scalar keys %{$allPlayers};$res .= qq[</td></tr>];
    $res .= qq[<tr><td><b>Total Players to Transfer:</b></td><td>]. scalar keys %{$Players};$res .= qq[</td></tr>];
   # $res .=qq[<tr><td><b>Total Non Players to transfer:</b> </td><td> ]. scalar keys %{$NonPlayers};$res .= qq[</td></tr>];
    
    my $Members = $Players;

    my $seasonPlayerCount = 0;
    my $ClearedOutPlayer = 0;
    my $otherSeasonPlayerCount = 0;
    foreach my $player(keys %{$Players}) {
	my $SeasonRecord = $clubObj->seasonClubRecord($player,$season);
	if ($SeasonRecord) {
	    $seasonPlayerCount++;
	}
	else {
	    $otherSeasonPlayerCount++;
	}
    }
    foreach my $allplayer (keys %{$allPlayers}) {
	
	# Cleared out and non clearedout
	if (!exists($Members->{$allplayer})) {
	    if ($ClearedOutPlayer == 0) {
		$res.=qq[<tr colspan=2  align ="center"><td><b>ClearedOut Players</b></td></tr>];
	    }
	    my $name = $allPlayers->{$allplayer}->{firstname} . ' ' .  $allPlayers->{$allplayer}->{surname};
	    $res.=qq[<tr colspan=2><td>Member:<b>$name($allplayer)</b> has been clearedout.</td></tr>];
	    $ClearedOutPlayer++;
	}
	else {
	}
    }
    $res .=qq[<tr><td><b>Total ClearedOuts:</b></td><td> $ClearedOutPlayer</td></tr>];
    my $officialAndPlayer = 0;
    my $NonePlayer = 0;
    my $resNonPlayer ='';
    foreach my $nonplayer (keys %{$NonPlayers}) {
	
	#player and non players
	if (exists($Members->{$nonplayer})) {
	    if ($officialAndPlayer == 0) {
		$res.=qq[<tr colspan=2  align ="center"><td><b>Official and Players</b></td></tr>];
	    }
	    my $name = $Members->{$nonplayer}->{firstname} . ' ' .  $Members->{$nonplayer}->{surname};
	    $Members->{$nonplayer}->{playerofficial} = 1;
	    $res.=qq[<tr colspan=2><td><b>Member:<b>$name($nonplayer)</b> is a player and a nonplayer</td></tr>];
	    $officialAndPlayer++;
	}
	else {
	    my $name = $NonPlayers->{$nonplayer}->{firstname} . ' ' .  $NonPlayers->{$nonplayer}->{surname};
	    if ($NonePlayer == 0) {
		$resNonPlayer.=qq[<tr colspan=2  align ="center"><td><b>Official</b></td></tr>];
	    }
	    $resNonPlayer.=qq[<tr colspan=2><td><b>Member:<b>$name($nonplayer)</b> is not a player</td></tr>];
	    $NonePlayer++;
	    #$Members->{$nonplayer} = $NonPlayers->{$nonplayer};
	}
    }
    
    $res .=qq[<tr><td><b>Total PlayerOfficials:</b></td><td>$officialAndPlayer</td></tr>];
    $res .= $resNonPlayer;
    $res .=qq[</tbody></table>];
    #	$res .=qq[<b>Count of All Members(Non Clearedout): </b>]. scalar keys %{$Members};


    
    return ($res, $Members,$clubObj);
    
}
sub Copy_Members{
    my($db,$fromAssocID,$fromClub, $toAssoc,$toClub,$Fromseason,$Toseason,$param) =@_;
    my ($review, $Members,$clubObj)= cal_MembeNumber($db, $fromAssocID,$fromClub,$Fromseason);
    
    my $count = 0;

    foreach my $memberID (keys %{$Members}) {
	my $name = $Members->{$memberID}->{firstname} . ' ' .  $Members->{$memberID}->{surname};
	$clubObj->copyMemberToNewClub($memberID, $Members->{$memberID}, $toClub, $toAssoc, $Fromseason,$Toseason,$param);
	$review .=qq[<br/>Moving member: $memberID - $name ];
	$count++;
    }
    
    $review .= qq[<br/><br/><b>Moved $count members</b>];
    return $review;
}

1;
