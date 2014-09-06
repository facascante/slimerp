#
# $Header: svn://svn/SWM/trunk/web/AssocOptions.pm 11416 2014-04-29 01:29:08Z sliu $
#

package AssocOptions;

require Exporter;
@ISA = qw(Exporter);
@EXPORT = qw(handleAssocOptions getConfigurableFields);
@EXPORT_OK = qw(handleAssocOptions getConfigurableFields);

use strict;
use Reg_common;
use Utils;
use HTMLForm;
use CGI qw(unescape param);
use ConfigOptions;
use FieldLabels;
use CustomFields;
use FormHelpers;
use PaymentSplitUtils;
use AuditLog;

use List::Util qw(max sum);

use Member;

sub handleAssocOptions 	{
	my ($action, $Data, $assocID, $typeID)=@_;

  my $cgi = new CGI;

	my $client = setClient($Data->{'clientValues'});
    my $resultHTML  = q{};
    my $title       = q{};
    my $ret         = q{};

	if ($action =~/^A_O_u/) {
		 ($ret,$title)=update_permissions($action, $Data, $assocID, $client);
		 $action='A_O_p';
		 $resultHTML.=$ret;
	}

	$Data->{'Permissions'}=GetPermissions(
		$Data,
		$Data->{'clientValues'}{'currentLevel'},
		getID($Data->{'clientValues'}, $Data->{'clientValues'}{'currentLevel'}),
		$Data->{'Realm'},
		$Data->{'RealmSubType'},
		$Data->{'clientValues'}{'authLevel'},
		0,
	);

	if ($action =~/^A_O_p/) {
		 ($ret,$title)=assoc_permissions($action, $Data, $assocID, $client);
			$resultHTML.=$ret||'';
	}
	elsif ($action =~/^A_O_ML_l/) {
		($ret, $title)=showmemberlistfields($Data, $assocID, $client);
		$resultHTML.=$ret;
	}
	elsif ($action =~/^A_O_ML_s/) {
		$ret=update_memberlist_fields($Data, $assocID, $client);
		$resultHTML.=$ret;
		$Data->{'Permissions'}=GetPermissions(
			$Data,
			$Data->{'clientValues'}{'currentLevel'},
			getID($Data->{'clientValues'}, $Data->{'clientValues'}{'currentLevel'}),
			$Data->{'Realm'},
			$Data->{'RealmSubType'},
			$Data->{'clientValues'}{'authLevel'},
			0,
		);

		($ret, $title)=showmemberlistfields($Data, $assocID, $client);
		$resultHTML.=$ret;
	}
	elsif ($action =~/^A_OSYNC_l/) {
		 ($ret,$title)=viewSyncLogs($Data, $assocID);
			$resultHTML.=$ret;
	}
	else	{
		($resultHTML,$title)=assoc_optionsMenu($action, $Data, $assocID, $client);
	}
	
    return ($resultHTML, $title);
}

sub viewSyncLogs	{

	my ($Data, $assocID) = @_;

	my $st=qq[
        	SELECT DATE_FORMAT(dtSync,"%d/%m/%Y %H:%i") as DateSync, strStage, intReturnAcknowledged, strAppVer, intSyncNo, intCompleted
		FROM tblSync
		WHERE intAssocID = ?
		ORDER BY intSyncID DESC
	];
                
	my $query = $Data->{'db'}->prepare($st);
	$query->execute($assocID);

	my $body = qq[
		<table class="listTable">
		<tr>
			<th>Sync Date/Time</th>
			<th>Stage</th>
			<th>Sync Acknowledged</th>
			<th>Application Version</th>
			<th>Sync Number</th>
			<th>Completed ?</th>
		</tr>
	];
	my $count=0;

        while (my $dref = $query->fetchrow_hashref) {
		$count++;
		my $completed = '';
		my $acknowledged= '';
		if ($dref->{strStage} eq 'sync')	{
			$completed = $dref->{intCompleted} == 1 ? 'Yes' : 'No';
			$acknowledged= $dref->{intReturnAcknowledged} == 1 ? 'Yes' : 'No';
		}

		$body .= qq[
			<tr>
				<td>$dref->{DateSync}</td>
				<td>$dref->{strStage}</td>
				<td>$acknowledged</td>
				<td>$dref->{strAppVer}</td>
				<td>$dref->{intSyncNo}</td>
				<td>$completed</td>
			</tr>
		];

	}

	$body .= qq[</table>];

	$body = qq[<b>No Syncs have been performed</b>] if ! $count;

	return ($body, 'Sync Log');
}

sub assoc_optionsMenu	{
	my ($action, $Data, $assocID, $client)=@_;

	my $txt_Clr = $Data->{'SystemConfig'}{'txtCLR'} || 'Clearance';

	my $query = $Data->{'db'}->prepare(qq[
		SELECT 
      intAllowRegoForm, 
      intAllowSeasons, 
      intUploadType
		FROM 
      tblAssoc
		WHERE 
      intAssocID = ?
		LIMIT 1
	]);
	$query->execute($assocID);
	my($intAllowRegoForm, $intAllowSeasons, $intUploadType) = $query->fetchrow_array();
	$query->finish;

	my $l=$Data->{'lang'};

	my $mlistdisplay = $Data->{'SystemConfig'}{'HideMemberListDisplay'}
		? ''
		: qq[<li><a href="$Data->{'target'}?client=$client&amp;a=A_O_ML_l">].$l->txt('Member List Display').qq[</a></li>];

	my $clearancesettings = $Data->{'SystemConfig'}{'AllowClearances'} 
		? qq[<li><a href="$Data->{'target'}?client=$client&amp;a=CLRSET_">].$l->txt("$txt_Clr Settings").qq[</a></li>]
		: '';

	my $products = $Data->{'SystemConfig'}{'AllowTXNs'}
		? qq[ <li><a href="$Data->{'target'}?client=$client&amp;a=A_PR_">].$l->txt('Products').qq[</a></li>]
		: '';

	my $txt_SeasonsNames= $Data->{'SystemConfig'}{'txtSeasons'} || 'Seasons';

	my $seasons = ($Data->{'SystemConfig'}{'AllowSeasons'} and $intAllowSeasons)
		? qq[<li><a href="$Data->{'target'}?client=$client&amp;a=SN_L">].$l->txt($txt_SeasonsNames).qq[</a></li>]
		: '';

	my $txt_AgeGroupNames = $Data->{'SystemConfig'}{'txtAgeGroups'} || 'Age Groups';

	my $agegroups = ($Data->{'SystemConfig'}{'AllowSeasons'} and $intAllowSeasons)
		? qq[<li><a href="$Data->{'target'}?client=$client&amp;a=AGEGRP_L">].$l->txt($txt_AgeGroupNames).qq[</a></li>]
		: '';

	my $optins = (!$Data->{'SystemConfig'}{'NoOptIn'})
		? qq[<li><a href="$Data->{'target'}?client=$client&amp;a=OPTIN_L">Opt-Ins</a></li>]
		: '';
		
	my $txt1=$l->txt('These configuration options allow you to modify the data and behaviour of the system.');
	#<li><a href="$Data->{'target'}?client=$client&amp;a=A_O_f">].$l->txt('Field Options').qq[</a></li>

	my $body=qq[
		<p>$txt1</p><br>
		<div class="settings-group">
			<div class="settings-group-name">Manage Users and Security</div>
			<ul>
				<li><a href="$Data->{'target'}?client=$client&amp;a=A_O_p">].$l->txt('Permissions').qq[</a></li>
			</ul>
		</div>
		<div class="settings-group">
			<div class="settings-group-name">Configure Database Fields</div>
			<ul>
				<li><a href="$Data->{'target'}?client=$client&amp;a=A_CF_">].$l->txt('Custom Fields').qq[</a></li>
				<li><a href="$Data->{'target'}?client=$client&amp;a=FC_C_d">].$l->txt('Field Configuration').qq[</a></li>
				<li><a href="$Data->{'target'}?client=$client&amp;a=A_LK_">].$l->txt('Manage Lookup Information').qq[</a></li>
				<li><a href="$Data->{'target'}?client=$client&amp;a=A_MP_">].$l->txt('Member Packages').qq[</a></li>
			</ul>
		</div>
	];
	if($mlistdisplay)	{
		$body.=qq[
			<div class="settings-group">
				<div class="settings-group-name">Change how information displays</div>
				<ul>
					$mlistdisplay
				</ul>
			</div>
		];
	}
	$body.=qq[
		<div class="settings-group">
			<div class="settings-group-name">Setup Registrations</div>
			<ul>
				$agegroups
				$clearancesettings
				$seasons
				$optins
			</ul>
		</div>
		];

    $body = '' if ($Data->{'SystemConfig'}{'RestrictedConfigOptions'});    

			$body .= qq[
		<div class="settings-group">
			<div class="settings-group-name">Manage Competitions</div>
			<ul>
				<li><a href="$Data->{'target'}?client=$client&amp;a=VENUE_L">].$l->txt('Venues').qq[</a></li>
			</ul>
		</div>
		];


    if ($Data->{'SystemConfig'}{'RestrictedConfigOptions'}) {
      $body = qq[
        <p>$txt1</p><br>
        <div class="settings-group">
          <div class="settings-group-name">Manager Users and Security</div>
          <ul>
            <li><a href="$Data->{'target'}?client=$client&amp;a=A_O_p">].$l->txt('Permissions').qq[</a></li>
	</ul>
        </div>
        $body
      ];
    }

		return ($body,$Data->{'lang'}->txt('Configuration'));
}



sub assoc_permissions	{
	my ($action, $Data, $assocID, $client)=@_;

	my %valChecked=();
	my %locked=();
	for my $k (qw(t_m_ia c_m_a c_m_e c_m_d c_mt_a c_mt_e c_mt_d c_tag_e c_mu_a c_mu_e c_t_a c_t_e c_tu_a c_tu_e c_c_e c_cu_e t_m_a t_m_e t_m_d t_mt_a t_mt_e t_mt_d t_tag_e t_mu_a t_mu_e t_t_e t_tu_e m_m_e m_mt_a m_mt_e m_mt_d m_mu_e pba_full pba_ro pba_stat pba_none c_m_ne t_m_ne t_m_tran c_m_ia c_t_am c_ac_a ))	{ 
    $valChecked{$k}=$locked{$k}='';
    if ($Data->{'SystemConfig'}{'RestrictedConfigOptions'}) {
      $locked{$k}=' disabled ';
    }
  }
  if ($Data->{'SystemConfig'}{'RestrictedConfigOptions'}) {
      $locked{'c_t_am'} = '';
      $locked{'c_t_a'} = '';
      $locked{'c_t_e'} = '';
      $locked{'t_t_e'} = '';
      $locked{'c_mu_a'} = '';
      $locked{'c_mu_e'} = '';
      $locked{'c_tu_a'} = '';
      $locked{'c_tu_e'} = '';
      $locked{'c_c_e'} = '';
      $locked{'c_cu_e'} = '';
  }
	
	for my $k (keys %{$Data->{'Permissions'}{'PermOptions'}})	{ 
		$valChecked{$k}='CHECKED' if $Data->{'Permissions'}{'PermOptions'}{$k}[0]==1;
		if($Data->{'Permissions'}{'PermOptions'}{$k}[2]==0)	{
			$locked{$k}=' disabled ';
		}
	}
	my $parent=$Data->{'DataAccess'}{$Defs::LEVEL_ASSOC}{$assocID};
	if ($Data->{'clientValues'}{'authLevel'} == $Defs::LEVEL_ASSOC)	{
		my $st = qq[
			SELECT 
				intDataAccess
			FROM 
				tblAssoc
			WHERE intAssocID=?
		];
    	my $query = $Data->{'db'}->prepare($st);
    	$query->execute($assocID);
		my $dataAccess = $query->fetchrow_array();
		$parent = $dataAccess;
	}
	$parent = $Defs::DATA_ACCESS_FULL if !defined $parent;
	$valChecked{'pba_full'}='checked' if $parent == $Defs::DATA_ACCESS_FULL;
	$valChecked{'pba_ro'}='checked'   if $parent == $Defs::DATA_ACCESS_READONLY;
	$valChecked{'pba_stat'}='checked' if $parent == $Defs::DATA_ACCESS_STATS;
	$valChecked{'pba_none'}='checked' if $parent == $Defs::DATA_ACCESS_NONE;
	my $l=$Data->{'lang'};


	my $unescclient=unescape($client);
	my $intro=$l->txt('PERMISSIONS_intro');
	my $subBody=qq[
		<p>$intro</p>
		<form action="$Data->{'target'}" method="POST">
		<table class="permsTable">
	];
	my $txt_add=$l->txt('Add');
	my $txt_edit=$l->txt('Edit');
	my $txt_del=$l->txt('Delete');
	my $txt_full=$l->txt('Full Access');
	my $txt_ro=$l->txt('Restricted Access');
	my $txt_stat=$l->txt('Statistical Access');
	my $txt_none=$l->txt('No Access');
	my $txt_mtypes=$l->txt('Member Types');
	my $txt_mtags=$l->txt('Member Tags');
	my $txt_mpasswords=$l->txt('Member Passwords');
	my $txt_tmpasswords=$l->txt('Team Passwords');
	my $txt_tpasswords=$l->txt('Their Passwords');
	my $txt_tassigncomps=$l->txt('Assign to Competitions');
	my $txt_tdetails=$l->txt('Their Details');
	my $txt_name = $l->txt(qq[Make Name Read Only (below $Data->{'LevelNames'}{$Defs::LEVEL_ASSOC.'_P'} login)]);
  my $transactions = $Data->{'SystemConfig'}{'txns_link_name'} || $l->txt('Transactions');
	my $txt_name_transactions = $l->txt(qq[Hide $transactions menu ($Data->{'LevelNames'}{$Defs::LEVEL_TEAM} login)]);
	my $txt_clubInactive=$l->txt(qq[Activate inactive $Data->{'LevelNames'}{$Defs::LEVEL_CLUB} $Data->{'LevelNames'}{$Defs::LEVEL_MEMBER.'_P'}]);
	my $txt_teamInactive=$l->txt(qq[Activate inactive $Data->{'LevelNames'}{$Defs::LEVEL_TEAM} $Data->{'LevelNames'}{$Defs::LEVEL_MEMBER.'_P'}]);
    my $txt_clubAssign = $l->txt('Assign Members to Teams');
    my $txt_clubTeamPayments= $l->txt(qq[Record manual payments for $Data->{'LevelNames'}{$Defs::LEVEL_TEAM.'_P'}]);
    my $txt_clubMemberPayments= $l->txt(qq[Record manual payments for $Data->{'LevelNames'}{$Defs::LEVEL_MEMBER.'_P'}]);
    my $txt_teamMemberPayments= $l->txt(qq[Record manual payments for $Data->{'LevelNames'}{$Defs::LEVEL_MEMBER.'_P'}]);
	my $txt_tmt=$l->txt('Their Member Types');
    my $txt_enterMatchResults= $l->txt('Enter Match Results');
	$subBody.=qq[
			<tr>
				<td colspan="4" class="sectionheader">].$l->txt('Allow Parent Body').qq[:</td>
			</tr>
			<tr>
				<td class="label">&nbsp;</td>
				<td class="label" style="text-align:left;" colspan="3"><input type="radio" value="$Defs::DATA_ACCESS_FULL" name="ParentBody" $valChecked{'pba_full'} class="nb"> &nbsp;$txt_full</td>
			</tr>
			<tr>
				<td class="label">&nbsp;</td>
				<td class="label" style="text-align:left;" colspan="3"><input type="radio" value="$Defs::DATA_ACCESS_READONLY" name="ParentBody" $valChecked{'pba_ro'} class="nb"> &nbsp;$txt_ro</td>
			</tr>
			<tr>
				<td class="label">&nbsp;</td>
				<td class="label" style="text-align:left;" colspan="3"><input type="radio" value="$Defs::DATA_ACCESS_STATS" name="ParentBody" $valChecked{'pba_stat'} class="nb"> &nbsp;$txt_stat</td>
			</tr>
			<tr>
				<td class="label">&nbsp;</td>
				<td class="label" style="text-align:left;" colspan="3"><input type="radio" value="$Defs::DATA_ACCESS_NONE" name="ParentBody" $valChecked{'pba_none'} class="nb"> &nbsp;$txt_none</td>
			</tr>
	] if !exists $Data->{'SystemConfig'}{'ParentBodyAccess'};

	my $activateMembers = '';
	if ($Data->{'SystemConfig'}{'ShowInactiveClubMembers'})	{
		$activateMembers = qq[
			<tr>
				<td class="label">$txt_clubInactive</td>
				<th>&nbsp;</th>
				<td><input type="checkbox" value="1" name="c_m_ia" $valChecked{'c_m_ia'} $locked{'c_m_ia'} class="nb"></td>
				<th>&nbsp;</th>
			</tr>
		];
	}
	
    my $assignMembers = '';
	if ((!$Data->{'SystemConfig'}{'NoClubs'}) and (!$Data->{'SystemConfig'}{'NoTeams'} ) ) {
        $assignMembers = qq[
            <tr>
                <td class="label">$txt_clubAssign</td>
                <th>&nbsp;</th>
                <td><input type="checkbox" value="1" name="c_t_am" $valChecked{'c_t_am'} $locked{'c_t_am'} class="nb"></td>
                <th>&nbsp;</th>
            </tr>
        ];
    }
	my $teamPayments= '';
	if ($Data->{'SystemConfig'}{'AllowTXNs'} and (!$Data->{'SystemConfig'}{'NoClubs'}) and (!$Data->{'SystemConfig'}{'NoTeams'} ) ) {
        $teamPayments= qq[
            <tr>
                <td class="label">$txt_clubTeamPayments</td>
				<th>&nbsp;</th>
				<td><input type="checkbox" value="1" name="c_t_tp" $valChecked{'c_t_tp'} $locked{'c_t_tp'} class="nb"></td>
				<th>&nbsp;</th>
            </tr>
        ];
    }
	my $memberPayments= '';
	if ($Data->{'SystemConfig'}{'AllowTXNs'} and (!$Data->{'SystemConfig'}{'NoClubs'}))	{
        $memberPayments= qq[
            <tr>
                <td class="label">$txt_clubMemberPayments</td>
				<th>&nbsp;</th>
				<td><input type="checkbox" value="1" name="c_m_mp" $valChecked{'c_m_mp'} $locked{'c_m_mp'} class="nb"></td>
				<th>&nbsp;</th>
            </tr>
        ];
    }
    
	$subBody.=qq[
			<tr>
				<td colspan="4" class="sectionheader">].$l->txt("Allow $Data->{'LevelNames'}{$Defs::LEVEL_CLUB.'_P'} to").qq[:</td>
			</tr>
			$activateMembers
			$teamPayments
			$memberPayments
			<tr>
				<td class="label">$txt_name</td>
				<th>&nbsp;</th>
				<td><input type="checkbox" value="1" name="c_m_ne" $valChecked{'c_m_ne'} $locked{'c_m_ne'} class="nb"></td>
				<th>&nbsp;</th>
			</tr>
			<tr>
				<th>&nbsp;</th>
				<th>$txt_add</th>
				<th>$txt_edit</th>
				<th>$txt_del</th>
			</tr>
			<tr>
				<td class="label">$Data->{'LevelNames'}{$Defs::LEVEL_MEMBER.'_P'}</td>
				<td><input type="checkbox" value="1" name="c_m_a" $valChecked{'c_m_a'} $locked{'c_m_a'} class="nb"></td>
				<td><input type="checkbox" value="1" name="c_m_e" $valChecked{'c_m_e'} $locked{'c_m_e'} class="nb"></td>
				<td><input type="checkbox" value="1" name="c_m_d" $valChecked{'c_m_d'} $locked{'c_m_d'} class="nb"></td>
			</tr>
			<tr>
				<td class="label">$txt_mtypes</td>
				<td><input type="checkbox" value="1" name="c_mt_a" $valChecked{'c_mt_a'} $locked{'c_mt_a'} class="nb"></td>
				<td><input type="checkbox" value="1" name="c_mt_e" $valChecked{'c_mt_e'} $locked{'c_mt_e'} class="nb"></td>
				<td><input type="checkbox" value="1" name="c_mt_d" $valChecked{'c_mt_d'} $locked{'c_mt_d'} class="nb"></td>
			</tr>
			<tr>
				<td class="label">$txt_mtags</td>
				<td>&nbsp;</td>
				<td><input type="checkbox" value="1" name="c_tag_e" $valChecked{'c_tag_e'} $locked{'c_tag_e'} class="nb"></td>
				<td>&nbsp;</td>
			</tr>
			<tr>
				<td class="label">$txt_mpasswords</td>
				<td><input type="checkbox" value="1" name="c_mu_a" $valChecked{'c_mu_a'} $locked{'c_mu_a'} class="nb"></td>
				<td><input type="checkbox" value="1" name="c_mu_e" $valChecked{'c_mu_e'} $locked{'c_mu_e'} class="nb"></td>
				<td>&nbsp;</td>
			</tr>
			<tr>
				<td class="label">$Data->{'LevelNames'}{$Defs::LEVEL_TEAM.'_P'}</td>
				<td><input type="checkbox" value="1" name="c_t_a" $valChecked{'c_t_a'} $locked{'c_t_a'} class="nb"></td>
				<td><input type="checkbox" value="1" name="c_t_e" $valChecked{'c_t_e'} $locked{'c_t_e'} class="nb"></td>
				<td>&nbsp;</td>
			</tr>
			<tr>
				<td class="label">$txt_tmpasswords</td>
				<td><input type="checkbox" value="1" name="c_tu_a" $valChecked{'c_tu_a'} $locked{'c_tu_a'} class="nb"></td>
				<td><input type="checkbox" value="1" name="c_tu_e" $valChecked{'c_tu_e'} $locked{'c_tu_e'} class="nb"></td>
				<td>&nbsp;</td>
			</tr>
            $assignMembers
			<tr>
				<td class="label">$txt_tdetails</td>
				<td>&nbsp;</td>
				<td><input type="checkbox" value="1" name="c_c_e" $valChecked{'c_c_e'} $locked{'c_c_e'} class="nb"></td>
				<td>&nbsp;</td>
			</tr>
			<tr>
				<td class="label">$txt_tpasswords</td>
				<td>&nbsp;</td>
				<td><input type="checkbox" value="1" name="c_cu_e" $valChecked{'c_cu_e'} $locked{'c_cu_e'} class="nb"></td>
				<td>&nbsp;</td>
			</tr>
      <tr>
        <td class="label">$txt_tassigncomps</td>
        <td>&nbsp;</td>
        <td><input type="checkbox" value="1" name="c_ac_a" $valChecked{'c_ac_a'} $locked{'c_ac_a'} class="nb"></td>
        <td>&nbsp;</td>
      </tr>
			<tr> <td colspan="4">&nbsp;</td> </tr>
	] if !$Data->{'SystemConfig'}{'NoClubs'};

	$memberPayments= '';
  $activateMembers = '';
        if ($Data->{'SystemConfig'}{'ShowInactiveClubMembers'})
 {
                $activateMembers = qq[
                        <tr>
                                <td class="label">$txt_teamInactive</td>
                                <th>&nbsp;</th>
                                <td><input type="checkbox" value="1" name="t_m_ia" $valChecked{'t_m_ia'} $locked{'t_m_ia'} class="nb"></td>
                                <th>&nbsp;</th>
                        </tr>
                ];
        }




	if (1==2 and $Data->{'SystemConfig'}{'AllowTXNs'})	{
	### Teams can't do manual payments at this stage
    	$memberPayments= qq[
    		<tr>
		        <td class="label">$txt_teamMemberPayments</td>
				<th>&nbsp;</th>
				<td><input type="checkbox" value="1" name="t_m_mp" $valChecked{'t_m_mp'} $locked{'t_m_mp'} class="nb"></td>
				<th>&nbsp;</th>
    	    </tr>
    	];
	}

	$subBody.=qq[
			<tr>
				<td colspan="4" class="sectionheader">].$l->txt("Allow $Data->{'LevelNames'}{$Defs::LEVEL_TEAM.'_P'} to").qq[:</td>
			</tr>
			<tr>
				<td class="label">$txt_name</td>
				<th>&nbsp;</th>
				<td><input type="checkbox" value="1" name="t_m_ne" $valChecked{'t_m_ne'} $locked{'t_m_ne'} class="nb"></td>
				<th>&nbsp;</th>
			</tr>
      <tr>
        <td class="label">$txt_name_transactions</td>
        <th>&nbsp;</th>
        <td><input type="checkbox" value="1" name="t_m_tran" $valChecked{'t_m_tran'} $locked{'t_m_tran'} class="nb"></td>
        <th>&nbsp;</th>
      </tr>
      <tr>
        <td class="label">$txt_enterMatchResults</td>
        <th>&nbsp;</th>
        <td><input type="checkbox" value="1" name="t_e_r" $valChecked{'t_e_r'} $locked{'t_e_r'} class="nb"></td>
        <th>&nbsp;</th>
      </tr>
			$activateMembers
			$memberPayments	
			<tr>
				<th>&nbsp;</th>
				<th>$txt_add</th>
				<th>$txt_edit</th>
				<th>$txt_del</th>
			</tr>
			<tr>
				<td class="label">$Data->{'LevelNames'}{$Defs::LEVEL_MEMBER.'_P'}</td>
				<td><input type="checkbox" value="1" name="t_m_a" $valChecked{'t_m_a'} $locked{'t_m_a'} class="nb"></td>
				<td><input type="checkbox" value="1" name="t_m_e" $valChecked{'t_m_e'} $locked{'t_m_e'} class="nb"></td>
				<td><input type="checkbox" value="1" name="t_m_d" $valChecked{'t_m_d'} $locked{'t_m_d'} class="nb"></td>
			</tr>
			<tr>
				<td class="label">$txt_mtypes</td>
				<td><input type="checkbox" value="1" name="t_mt_a" $valChecked{'t_mt_a'} $locked{'t_mt_a'} class="nb"></td>
				<td><input type="checkbox" value="1" name="t_mt_e" $valChecked{'t_mt_e'} $locked{'t_mt_e'} class="nb"></td>
				<td><input type="checkbox" value="1" name="t_mt_d" $valChecked{'t_mt_d'} $locked{'t_mt_d'} class="nb"></td>
			</tr>
			<tr>
				<td class="label">$txt_mtags</td>
				<td>&nbsp;</td>
				<td><input type="checkbox" value="1" name="t_tag_e" $valChecked{'t_tag_e'} $locked{'t_tag_e'} class="nb"></td>
				<td>&nbsp;</td>
			</tr>
<!--
			<tr>
				<td class="label">$txt_mpasswords</td>
				<td><input type="checkbox" value="1" name="t_mu_a" $valChecked{'t_mu_a'} $locked{'t_mu_a'} class="nb"></td>
				<td><input type="checkbox" value="1" name="t_mu_e" $valChecked{'t_mu_e'} $locked{'t_mu_e'} class="nb"></td>
				<td>&nbsp;</td>
			</tr>
-->
			<tr>
				<td class="label">$txt_tdetails</td>
				<td>&nbsp;</td>
				<td><input type="checkbox" value="1" name="t_t_e" $valChecked{'t_t_e'} $locked{'t_t_e'} class="nb"></td>
				<td>&nbsp;</td>
			</tr>
<!--
			<tr>
				<td class="label">$txt_tpasswords</td>
				<td>&nbsp;</td>
				<td><input type="checkbox" value="1" name="t_tu_e" $valChecked{'t_tu_e'} $locked{'t_tu_e'} class="nb"></td>
				<td>&nbsp;</td>
			</tr>
-->
			<tr>
			<tr> <td colspan="4">&nbsp;</td> </tr>
	] if !exists $Data->{'SystemConfig'}{'NoTeams'};

# disable the follow content according to JIRA issue 11577
if (0) {
	$subBody.=qq[
			<tr>
				<td colspan="4" class="sectionheader">Allow Members to:</td>
			</tr>
			<tr>
				<th>&nbsp;</th>
				<th>$txt_add</th>
				<th>$txt_edit</th>
				<th>$txt_del</th>
			</tr>
			<tr>
				<td class="label">$txt_tdetails</td>
				<td>&nbsp;</td>
				<td><input type="checkbox" value="1" name="m_m_e" $valChecked{'m_m_e'} $locked{'m_m_e'} class="nb"></td>
				<td>&nbsp;</td>
			</tr>
	];

	if(!$Data->{'SystemConfig'}{'NoMemberTypes'})  {
		$subBody.=qq[
			<tr>
				<td class="label">$txt_tmt</td>
				<td><input type="checkbox" value="1" name="m_mt_a" $valChecked{'m_mt_a'} $locked{'m_mt_a'} class="nb"></td>
				<td><input type="checkbox" value="1" name="m_mt_e" $valChecked{'m_mt_e'} $locked{'m_mt_e'} class="nb"></td>
				<td><input type="checkbox" value="1" name="m_mt_d" $valChecked{'m_mt_d'} $locked{'m_mt_d'} class="nb"></td>
			</tr>
		];
	}
	$subBody.=qq[
			<tr>
				<td class="label">$txt_tpasswords</td>
				<td>&nbsp;</td>
				<td><input type="checkbox" value="1" name="m_mu_e" $valChecked{'m_mu_e'} $locked{'m_mu_e'} class="nb"></td>
				<td>&nbsp;</td>
			</tr>
	];
}

	$subBody.=qq[
		</table>

		<br> <br>
		<input type="submit" value="].$l->txt('Update Permissions').qq[" class = "button proceed-button">
		<input type="hidden" name="client" value="$unescclient">
		<input type="hidden" name="a" value="A_O_u">
		</form>
	];

	
	return ($subBody || '',$l->txt('Permissions'));

}

sub update_permissions {
	my ($action, $Data, $assocID, $client)=@_;

	my $realmID=$Data->{'Realm'} || 0;
	my $st_del=qq[
		DELETE FROM tblConfig 
		WHERE intLevelID=$Defs::LEVEL_ASSOC 
			AND intEntityID=$assocID
			AND intRealmID=$realmID
			AND strType ='PermOptions'
	];
	
	$Data->{'db'}->do($st_del);
	my $txt_prob=$Data->{'lang'}->txt('Problem updating Permissions');
	return qq[<div class="warningmsg">$txt_prob (1)</div>] if $DBI::err;
	my $st=qq[
		INSERT INTO tblConfig (intEntityID, intLevelID,strType , intRealmID, strPerm, strValue)
			VALUES ($assocID, $Defs::LEVEL_ASSOC, 'PermOptions', $realmID, ?,?)
	];
	my $q=$Data->{'db'}->prepare($st);
	for my $k (qw(c_m_a c_m_e c_m_d c_mt_a c_mt_e c_mt_d c_tag_e c_mu_a c_mu_e c_t_a c_t_e c_tu_a c_tu_e c_c_e c_cu_e t_m_a t_m_e t_m_d t_mt_a t_mt_e t_mt_d t_tag_e t_mu_a t_mu_e t_t_e t_tu_e m_m_e m_mt_a m_mt_e m_mt_d m_mu_e c_m_ne t_m_ne t_m_tran t_m_ia c_m_ia c_t_am c_t_tp c_m_mp t_m_mp c_ac_a t_e_r))	{ 
		$q->execute($k,1) if param($k);
		return qq[<div class="warningmsg">$txt_prob (2)</div>] if $DBI::err;
	}
	if(!exists $Data->{'SystemConfig'}{'ParentBodyAccess'})	{
		my $parent=param('ParentBody');
		$parent = $Defs::DATA_ACCESS_FULL if !defined $parent;
		$Data->{'db'}->do(qq[UPDATE tblAssoc SET intDataAccess=$parent WHERE intAssocID=$assocID]);
		if($Data->{'clientValues'}{'authLevel'} > $Defs::LEVEL_ASSOC)	{
			$Data->{'DataAccess'}{$Defs::LEVEL_ASSOC}{$assocID}=$parent;
		}
		else	{
			$Data->{'DataAccess'}{$Defs::LEVEL_ASSOC}{$assocID}=$Defs::DATA_ACCESS_FULL;
		}
	}
  auditLog($assocID, $Data, 'Update', 'Permissions');
	return '<div class="OKmsg">'.$Data->{'lang'}->txt('Permissions Updated').'</div>';
}

my @memberFields =(qw(
    strNationalNum
    strMemberNo
    intRecStatus
    strSalutation
    strFirstname
    strMiddlename
    strSurname
    strMaidenName
    strPreferredName
    dtDOB
    strPlaceofBirth
    intGender
    intDeceased
    strEyeColour
    strHairColour
    intEthnicityID
    strHeight
    strWeight
    strAddress1
    strAddress2
    strSuburb
    strCityOfResidence
    strState
    strCountry
    strPostalCode
    strPhoneHome
    strPhoneWork
    strPhoneMobile
    strPager
    strFax
    strEmail
    strEmail2
    strEmergContName
    strEmergContNo
    strEmergContNo2
    strEmergContRel
    intPlayer
    intCoach
    intUmpire
    intOfficial
    intMisc
    intVolunteer
    intPlayerPending
    strPreferredLang
    strPassportNationality
    strPassportNo
    strPassportIssueCountry
    dtPassportExpiry
    strBirthCertNo
    strHealthCareNo
    intIdentTypeID
    strIdentNum
    dtPoliceCheck
    dtPoliceCheckExp
    strPoliceCheckRef
    intP1Gender
    strP1Salutation
    strP1FName
    strP1SName
    strP1Phone
    strP1Phone2
    strP1PhoneMobile
    strP1Email
    strP1Email2
    intP1AssistAreaID
    intP2Gender
    strP2Salutation
    strP2FName
    strP2SName
    strP2Phone
    strP2Phone2
    strP2PhoneMobile
    strP2Email
    strP2Email2
    intP2AssistAreaID
    intFinancialActive
    intMemberPackageID
    curMemberFinBal
    intLifeMember
    intMedicalConditions
    intAllergies
    intAllowMedicalTreatment
    strMedicalNotes
    intOccupationID
    strLoyaltyNumber
    intMailingList
    strNatCustomStr1
    strNatCustomStr2
    strNatCustomStr3
    strNatCustomStr4
    strNatCustomStr5
    strNatCustomStr6
    strNatCustomStr7
    strNatCustomStr8
    strNatCustomStr9
    strNatCustomStr10
    strNatCustomStr11
    strNatCustomStr12
    strNatCustomStr13
    strNatCustomStr14
    strNatCustomStr15
    dblNatCustomDbl1
    dblNatCustomDbl2
    dblNatCustomDbl3
    dblNatCustomDbl4
    dblNatCustomDbl5
    dblNatCustomDbl6
    dblNatCustomDbl7
    dblNatCustomDbl8
    dblNatCustomDbl9
    dblNatCustomDbl10
    dtNatCustomDt1
    dtNatCustomDt2
    dtNatCustomDt3
    dtNatCustomDt4
    dtNatCustomDt5
    intNatCustomLU1
    intNatCustomLU2
    intNatCustomLU3
    intNatCustomLU4
    intNatCustomLU5
    intNatCustomLU6
    intNatCustomLU7
    intNatCustomLU8
    intNatCustomLU9
    intNatCustomLU10
    intNatCustomBool1
    intNatCustomBool2
    intNatCustomBool3
    intNatCustomBool4
    intNatCustomBool5
    strCustomStr1
    strCustomStr2
    strCustomStr3
    strCustomStr4
    strCustomStr5
    strCustomStr6
    strCustomStr7
    strCustomStr8
    strCustomStr9
    strCustomStr10
    strCustomStr11
    strCustomStr12
    strCustomStr13
    strCustomStr14
    strCustomStr15
    strCustomStr16
    strCustomStr17
    strCustomStr18
    strCustomStr19
    strCustomStr20
    strCustomStr21
    strCustomStr22
    strCustomStr23
    strCustomStr24
    strCustomStr25
    dblCustomDbl1
    dblCustomDbl2
    dblCustomDbl3
    dblCustomDbl4
    dblCustomDbl5
    dblCustomDbl6
    dblCustomDbl7
    dblCustomDbl8
    dblCustomDbl9
    dblCustomDbl10
    dblCustomDbl11
    dblCustomDbl12
    dblCustomDbl13
    dblCustomDbl14
    dblCustomDbl15
    dblCustomDbl16
    dblCustomDbl17
    dblCustomDbl18
    dblCustomDbl19
    dblCustomDbl20
    dtCustomDt1
    dtCustomDt2
    dtCustomDt3
    dtCustomDt4
    dtCustomDt5
    dtCustomDt6
    dtCustomDt7
    dtCustomDt8
    dtCustomDt9
    dtCustomDt10
    dtCustomDt11
    dtCustomDt12
    dtCustomDt13
    dtCustomDt14
    dtCustomDt15
    intCustomLU1
    intCustomLU2
    intCustomLU3
    intCustomLU4
    intCustomLU5
    intCustomLU6
    intCustomLU7
    intCustomLU8
    intCustomLU9
    intCustomLU10
    intCustomLU11
    intCustomLU12
    intCustomLU13
    intCustomLU14
    intCustomLU15
    intCustomLU16
    intCustomLU17
    intCustomLU18
    intCustomLU19
    intCustomLU20
    intCustomLU21
    intCustomLU22
    intCustomLU23
    intCustomLU24
    intCustomLU25
    intCustomBool1
    intCustomBool2
    intCustomBool3
    intCustomBool4
    intCustomBool5
    intCustomBool6
    intCustomBool7
    intFavStateTeamID
    intFavNationalTeamID
    intFavNationalTeamMember
    intAttendSportCount
    intWatchSportHowOftenID
    strNotes
    strMemberCustomNotes1
    strMemberCustomNotes2
    strMemberCustomNotes3
    strMemberCustomNotes4
    strMemberCustomNotes5
    dtFirstRegistered
    dtLastRegistered
    dtLastUpdate
    dtRegisteredUntil
    dtCreatedOnline
    intHowFoundOutID
    intConsentSignatureSighted
));

my @teamFields =(qw(
    intClubID
    TeamCode
    strName
    ClubName
    intCompID
    intRecStatus
    strNickname
    strContactTitle
    strContact
    strAddress1
    strAddress2
    strSuburb
    strState
    strCountry
    strPostalCode
    strPhone1
    strPhone2
    SP1
    strEmail
    strContactTitle2
    strContactName2
    strContactEmail2
    strContactPhone2
    strContactTitle3
    strContactName3
    strContactEmail3
    strContactPhone3
    strWebURL
    strUniformTopColour
    strUniformBottomColour
    strUniformNumber
    strAltUniformTopColour
    strAltUniformBottomColour
    strAltUniformNumber
    intExcludeClubChampionships
    strTeamNotes
    intCoachID
    intManagerID
    strTeamCustomStr1
    strTeamCustomStr2
    strTeamCustomStr3
    strTeamCustomStr4
    strTeamCustomStr5
    strTeamCustomStr6
    strTeamCustomStr7
    strTeamCustomStr8
    strTeamCustomStr9
    strTeamCustomStr10
    strTeamCustomStr11
    strTeamCustomStr12
    strTeamCustomStr13
    strTeamCustomStr14
    strTeamCustomStr15
    dblTeamCustomDbl1
    dblTeamCustomDbl2
    dblTeamCustomDbl3
    dblTeamCustomDbl4
    dblTeamCustomDbl5
    dblTeamCustomDbl6
    dblTeamCustomDbl7
    dblTeamCustomDbl8
    dblTeamCustomDbl9
    dblTeamCustomDbl10
    dtTeamCustomDt1
    dtTeamCustomDt2
    dtTeamCustomDt3
    dtTeamCustomDt4
    dtTeamCustomDt5
    intTeamCustomLU1
    intTeamCustomLU2
    intTeamCustomLU3
    intTeamCustomLU4
    intTeamCustomLU5
    intTeamCustomLU6
    intTeamCustomLU7
    intTeamCustomLU8
    intTeamCustomLU9
    intTeamCustomLU10
    intTeamCustomBool1
    intTeamCustomBool2
    intTeamCustomBool3
    intTeamCustomBool4
    intTeamCustomBool5
    intVenue1ID
    intVenue2ID
    intVenue3ID
));

my %readonlyfields =( #These fields can only be Read only or hidden
    dtLastUpdate => 1,
    dtRegisteredUntil=> 1,
    strNationalNum => 1,
    #strMemberNo => 1,
    dtCreatedOnline => 1,
);

my %NotSynced=(
    strEmergContNo2=>1,
    strEmergContRel=>1,
    strP1Salutation=> 1,
    strP2Salutation=> 1,
    intP1Gender=> 1,
    intP2Gender=> 1,
    strP1Phone => 1,
    strP1Phone2 => 1,
    strP1PhoneMobile => 1,
    strP1Email => 1,
    strP1Email2 => 1,
    strP2Phone => 1,
    strP2Phone2 => 1,
    strP2PhoneMobile => 1,
    strP2Email => 1,
    strP2Email2 => 1,
    intHowFoundOutID => 1,
    intMedicalConditions => 1,
    strMedicalNotes => 1,
    intP1AssistAreaID => 1,
    intP2AssistAreaID => 1,
    intAllowMedicalTreatment => 1,
    intAllergies => 1,
    intConsentSignatureSighted => 1,
    dtCreatedOnline => 1,
    intSchoolID=> 1,
    intGradeID=> 1,
    strMemberCustomNotes1=>1,
    strMemberCustomNotes2=>1,
    strMemberCustomNotes3=>1,
    strMemberCustomNotes4=>1,
    strMemberCustomNotes5=>1
);

	my @hiddenfields	= (qw(
		strSchoolName
		strSchoolSuburb
	));


sub getConfigurableFields	{
    my ($Data) = @_;

	my @newarray=();
	my %totalfields=();

    my $field_list =\@memberFields;
        #(GetFormType($Data) eq 'Team') ? \@teamFields : \@memberFields;

    for my $f (@$field_list) { $totalfields{$f}=1;};

	for my $f (@hiddenfields) { $totalfields{$f}=1;};
	for my $k (keys %NotSynced)	{ $totalfields{$k}=1;};
	for my $k (keys %totalfields)	{ push @newarray, $k;	}

	return \@newarray;
}

sub showmemberlistfields	{
	my ($Data, $assocID, $client)=@_;

	my $assocSeasons = Seasons::getDefaultAssocSeasons($Data);
  my $FieldLabels=getFieldLabels($Data, $Defs::LEVEL_MEMBER);
  my $CustomFieldNames=getCustomFieldNames($Data) || '';

	my %all_fields=();
	my $lang=$Data->{'lang'};
	my $configurablefields=getConfigurableFields($Data);
	my $allowed_fields=memberlist_allowed_fields($Data);
	for my $f (@{$allowed_fields})	{ 
		my ($pre,$field)=split /\./,$f;
		my $l=$FieldLabels->{$f};
		$l=$CustomFieldNames->{$f}[0] || '' if !$l;
		my $pretext=$pre;
		$pretext='MatchOfficial' if $pretext eq 'Umpire';
		if($field and $pre)	{ $l=uc($pretext).":$l"; }
		next if !$l;
		next if ($pre =~ /Seasons/ and ! $assocSeasons->{'allowSeasons'});
		next if ($l =~ /^SEASONS:$/ and $assocSeasons->{'allowSeasons'}); #Handling the Other1 & Other2 - if unnamed in SystemConfig
		next if ($pre =~ /AgeGroup/ and ! $assocSeasons->{'allowSeasons'});
		next if ($pre =~ /^intPlayer|^intCoach|^intUmpire|^intMisc|^intVolunteer/ and $assocSeasons->{'allowSeasons'});

		if (
			!$pre 
			and $Data->{'Permissions'}{'Member'} 
			and $Data->{'Permissions'}{'Member'}{$f} 
			and $Data->{'Permissions'}{'Member'}{$f} eq 'Hidden'
		)	{
			next;
		}
        $all_fields{$f}=$l;
	}

  ## IF NO FIELDS SELECTED ADD THE DEFAULT
  my $count_fields = 0;
  foreach my $key (%all_fields) { 
    $count_fields++ if exists $Data->{'Permissions'}{'MemberList'}{$key};
  }
  if ($count_fields == 0) {
    $Data->{'Permissions'}{'MemberList'}{'intRecStatus'} = [1,5,$assocID];
    $Data->{'Permissions'}{'MemberList'}{'strFirstname'} = [2,5,$assocID];
    $Data->{'Permissions'}{'MemberList'}{'strSurname'} = [3,5,$assocID];
    $Data->{'Permissions'}{'MemberList'}{'dtDOB'} = [4,5,$assocID];
    $Data->{'Permissions'}{'MemberList'}{'intGender'} = [5,5,$assocID];
  }
  #

	my $existingsort= $Data->{'Permissions'}{'MemberList'}{'SORT'}[0];
	my $sort_dropdown=drop_down('sortfield',\%all_fields,undef,$existingsort,,1,0);
	my @leftbox=();
	my @rightbox=();
  foreach my $key (sort {  uc($all_fields{$a}) cmp   uc($all_fields{$b})}  keys %all_fields) {
    next if exists $Data->{'Permissions'}{'MemberList'}{$key};
		push @leftbox, [$key, $all_fields{$key}];
  }
  foreach my $key (sort {
		$Data->{'Permissions'}{'MemberList'}{$a}[0] <=> $Data->{'Permissions'}{'MemberList'}{$b}[0] } keys %{$Data->{'Permissions'}{'MemberList'}})	{
		my $l=$FieldLabels->{$key};
		$l=$CustomFieldNames->{$key}[0]||'' if !$l;
		my ($pre,$field)=split /\./,$key;
		my $pretext=$pre;
		$pretext='MatchOfficial' if $pretext eq 'Umpire';
		if($field and $pre)	{ $l=uc($pretext).":$l"; }
		next if !$l;
    next if !$all_fields{$key};
		push @rightbox, [$key, $l];
  }
	use MoveCombos;
	my $boxes=getMoveSelectBoxes($Data, 'choosebox','Available Fields','Selected Fields',\@leftbox,\@rightbox, 289,400,'activeorder');

  my $body=qq[
  <p>Use this screen to choose which fields to display on your member list by dragging fields from the box on the left into the (box on the right).  When you have finished press the 'Update' button.</p>
	$boxes
			<div style="clear:both;"></div>
    <form action="$Data->{'target'}" method="post" name="comboForm">
			<br><br><span class="label">Sort by:</span><br> $sort_dropdown
				<div class="adminartbuttons"><br>
          <input type="submit" value="Update"  name="submitbutton" class = "button proceed-button">
        </div>

      <input type="hidden" name="activeorder" value="" id = "activeorder">
      <input type="hidden" name="a" value="A_O_ML_s">
      <input type="hidden" name="client" value="$client">
      </div>
      </form>
  ];
	return ($body,$lang->txt('Member List Fields'));
}

sub update_memberlist_fields {
	my ($Data, $assocID, $client)=@_;
	my $realmID=$Data->{'Realm'} || 0;
	my $st_del=qq[
		DELETE FROM tblConfig 
		WHERE intLevelID=$Defs::LEVEL_ASSOC 
			AND intEntityID=$assocID
			AND intRealmID=$realmID
			AND strType ='MemberList'
	];
	$Data->{'db'}->do($st_del);
	my $txt_prob=$Data->{'lang'}->txt('Problem updating Fields');
	return qq[<div class="warningmsg">$txt_prob (1)</div>] if $DBI::err;
	my $st=qq[
		INSERT INTO tblConfig (intEntityID, intLevelID, strType, intRealmID, strPerm, strValue)
			VALUES ($assocID, $Defs::LEVEL_ASSOC, 'MemberList', $realmID, ?,?)
	];
	my $q=$Data->{'db'}->prepare($st);
	my $neworder=param('activeorder') || '';
	$neworder=unescape($neworder);
	$neworder=~s/.*=//g;
	my @neworder=split /\|/, $neworder;
	my $cnt=1;
	for my $k (@neworder)	{
		$q->execute($k,$cnt) if $k;
		return qq[<div class="warningmsg">$txt_prob (2)</div>] if $DBI::err;
		$cnt++;
	}
	my $sort=param('sortfield') || '';
	$q->execute('SORT',$sort) if $sort;
  auditLog($assocID, $Data, 'Update', 'Member List Display');
	return '<div class="OKmsg">'.$Data->{'lang'}->txt('Fields Updated').'</div>';
}

sub memberlist_allowed_fields	{

	my @memberFields =(qw(
		tblSchoolGrades.strName
		strNationalNum
		strMemberNo
		intRecStatus
		strSalutation
		strFirstname
		strMiddlename
		strSurname
		strMaidenName
		strPreferredName
		dtDOB
		strPlaceofBirth
		intGender
		intDeceased
		strAddress1
		strAddress2
		strSuburb
		strCityOfResidence
		strState
		strCountry
		strPostalCode
		strPhoneHome
		strPhoneWork
		strPhoneMobile
		strPager
		strFax
		strEmail
		strEmail2
		strEmergContName
		strEmergContNo
		strEmergContNo2
		strEmergContRel
		intPlayer
		intCoach
		intUmpire
		intOfficial
		intMisc
		intVolunteer
		strPreferredLang
		strPassportNationality
		strPassportNo
		strPassportIssueCountry
		dtPassportExpiry
		strBirthCertNo
		strHealthCareNo
		dtPoliceCheck
		dtPoliceCheckExp
		strPoliceCheckRef
		intP1Gender
		strP1Salutation
		strP1FName
		strP1SName
		strP1Phone
		strP1Phone2
		strP1PhoneMobile
		strP1Email
		strP1Email2
		intP2Gender
		strP2Salutation
		strP2FName
		strP2SName
		strP2Phone
		strP2Phone2
		strP2PhoneMobile
		strP2Email
		strP2Email2
		intFinancialActive
		curMemberFinBal
		intLifeMember
		intMedicalConditions
		intAllergies
		intAllowMedicalTreatment
		strLoyaltyNumber
		intMailingList
		strNatCustomStr1
		strNatCustomStr2
		strNatCustomStr3
		strNatCustomStr4
		strNatCustomStr5
		strNatCustomStr6
		strNatCustomStr7
		strNatCustomStr8
		strNatCustomStr9
		strNatCustomStr10
		strNatCustomStr11
		strNatCustomStr12
		strNatCustomStr13
		strNatCustomStr14
		strNatCustomStr15
		dblNatCustomDbl1
		dblNatCustomDbl2
		dblNatCustomDbl3
		dblNatCustomDbl4
		dblNatCustomDbl5
		dblNatCustomDbl6
		dblNatCustomDbl7
		dblNatCustomDbl8
		dblNatCustomDbl9
		dblNatCustomDbl10
		dtNatCustomDt1
		dtNatCustomDt2
		dtNatCustomDt3
		dtNatCustomDt4
		dtNatCustomDt5
		intNatCustomBool1
		intNatCustomBool2
		intNatCustomBool3
		intNatCustomBool4
		intNatCustomBool5
		strCustomStr1
		strCustomStr2
		strCustomStr3
		strCustomStr4
		strCustomStr5
		strCustomStr6
		strCustomStr7
		strCustomStr8
		strCustomStr9
		strCustomStr10
		strCustomStr11
		strCustomStr12
		strCustomStr13
		strCustomStr14
		strCustomStr15
        strCustomStr16
        strCustomStr17
        strCustomStr18
        strCustomStr19
        strCustomStr20
        strCustomStr21
        strCustomStr22
        strCustomStr23
        strCustomStr24
        strCustomStr25
		dblCustomDbl1
		dblCustomDbl2
		dblCustomDbl3
		dblCustomDbl4
		dblCustomDbl5
		dblCustomDbl6
		dblCustomDbl7
		dblCustomDbl8
		dblCustomDbl9
		dblCustomDbl10
        dblCustomDbl11
        dblCustomDbl12
        dblCustomDbl13
        dblCustomDbl14
        dblCustomDbl15
        dblCustomDbl16
        dblCustomDbl17
        dblCustomDbl18
        dblCustomDbl19
        dblCustomDbl20
		dtCustomDt1
		dtCustomDt2
		dtCustomDt3
		dtCustomDt4
		dtCustomDt5
        dtCustomDt6
        dtCustomDt7
        dtCustomDt8
        dtCustomDt9
        dtCustomDt10
        dtCustomDt11
        dtCustomDt12
        dtCustomDt13
        dtCustomDt14
        dtCustomDt15
		intCustomBool1
		intCustomBool2
		intCustomBool3
		intCustomBool4
		intCustomBool5
		intCustomBool6
		intCustomBool7
		intFavNationalTeamMember
		dtRegisteredUntil
		dtFirstRegistered
		dtLastRegistered
		tTimeStamp
		dtCreatedOnline
		intConsentSignatureSighted

		strMemberCustomNotes1
		strMemberCustomNotes2
		strMemberCustomNotes3
		strMemberCustomNotes4
		strMemberCustomNotes5
		strPackageName
		Player.dtDate1
		Player.intInt1
		Player.intInt2
		Player.intInt3
		Player.intInt4

		Coach.intActive
		Coach.strString1
		Coach.strString2
		Coach.intInt1

		Umpire.intActive
		Umpire.strString1
		Umpire.strString2
		Umpire.intInt1
		Umpire.intInt2

		Seasons.intMSRecStatus
		Seasons.intPlayerStatus
		Seasons.intPlayerFinancialStatus
		Seasons.intCoachStatus
		Seasons.intCoachFinancialStatus
		Seasons.intUmpireStatus
		Seasons.intUmpireFinancialStatus
		Seasons.intMiscStatus
		Seasons.intMiscFinancialStatus
		Seasons.intVolunteerStatus
		Seasons.intVolunteerFinancialStatus
		Seasons.intOther1Status
		Seasons.intOther1FinancialStatus
		Seasons.intOther2Status
		Seasons.intOther2FinancialStatus
		
		PlayerNumberClub.strJumperNum
		PlayerNumberTeam.strJumperNum

	));
		#Player.intActive
	return \@memberFields;
}

1;


