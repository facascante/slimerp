#
# $Header: svn://svn/SWM/trunk/web/EntitySettings.pm 11416 2014-04-29 01:29:08Z sliu $
#

package EntitySettings;

require Exporter;
@ISA = qw(Exporter);
@EXPORT = qw(handleEntitySettings );
@EXPORT_OK = qw(handleEntitySettings );

use strict;
use Reg_common;
use Utils;
use CGI qw(unescape param);


sub handleEntitySettings {
    my ($action, $Data)=@_;

    my $client = setClient($Data->{'clientValues'});
    my $resultHTML  = q{};
    my $title       = q{};
    my $ret         = q{};

    my $currentLevel = $Data->{'clientValues'}{'currentLevel'} || 0;
    $action ||= 'ESET_m';

    if ($action =~/^ESET_m/) {
        if($currentLevel == $Defs::LEVEL_CLUB) {
            ($ret,$title)=clubsettings_menu($action, $Data, $client);
        }
        elsif(
            $currentLevel == $Defs::LEVEL_ZONE
                or $currentLevel == $Defs::LEVEL_REGION
                or $currentLevel == $Defs::LEVEL_STATE
                or $currentLevel == $Defs::LEVEL_NATIONAL
        ) {
            ($ret,$title) = nodesettings_menu($action, $Data, $client);
        }
        $resultHTML .= $ret || '';
    }

    return ($resultHTML, $title);
}


sub clubsettings_menu {
    my ($action, $Data, $client)=@_;


    my $assocID = $Data->{'clientValues'}{'assocID'} || 0;
    my $st = qq[
    SELECT intAllowRegoForm, intAllowSeasons, intSWOL, intUploadType
    FROM tblAssoc
    WHERE intAssocID = ?
    LIMIT 1
    ];
    my $query = $Data->{'db'}->prepare($st);
    $query->execute($assocID);
    my($intAllowRegoForm, $intAllowSeasons, $intSWOL, $intUploadType)= $query->fetchrow_array();
    $query->finish;


    my $l=$Data->{'lang'};

    my $txt_Clr = $Data->{'SystemConfig'}{'txtCLR'} || 'Clearance';
    my $clearancesettings = $Data->{'SystemConfig'}{'AllowClearances'}
    ? qq[<li><a href="$Data->{'target'}?client=$client&amp;a=CLRSET_">].$l->txt("$txt_Clr Settings").qq[</a></li>]
    : '';

    my $products = $Data->{'SystemConfig'}{'AllowTXNs'}
    ? qq[ <li><a href="$Data->{'target'}?client=$client&amp;a=A_PR_">].$l->txt('Products').qq[</a></li>]
    : '';
    my $regoforms = '';
    if (
        $intAllowRegoForm
            and (
            $Data->{'SystemConfig'}{'AllowOnlineRego'}
                or $Data->
            {'Permissions'}
            {'OtherOptions'}
            {'AllowOnlineRego'}
        )
    ) {

        $regoforms = qq[
        <li><a href="$Data->{'target'}?client=$client&amp;a=A_ORF_r">].$l->txt('Registration Forms').qq[</a>
        </li>
        ];
    }

    my $txt1=$l->txt('These configuration options allow you to modify the data and behaviour of the system.');
    my $body=qq[
    <p>$txt1</p><br>
    <div class="settings-group">
    <div class="settings-group-name">Manage Users and Security</div>
    <ul>
    <li><a href="$Data->{'target'}?client=$client&amp;a=PW_">].$l->txt('Password Management').qq[</a></li>
    <li><a href="$Data->{'target'}?client=$client&amp;a=AM_">].$l->txt('User Management').qq[</a></li>
    </ul>
    </div>
    ];

    if (!$Data->{'SystemConfig'}{'RestrictedConfigOptions'}) {
        $body .= qq[
        <div class="settings-group">
        <div class="settings-group-name">Configure Database Fields</div>
        <ul>
        <li><a href="$Data->{'target'}?client=$client&amp;a=FC_C_d">].$l->txt('Field Configuration').qq[</a></li>
        </ul>
        </div>
        ];
        if($products or $regoforms or $clearancesettings) {
            $body .= qq[
            <div class="settings-group">
            <div class="settings-group-name">Setup Registrations and Payments</div>
            <ul>
            $products
            $regoforms
            $clearancesettings
            </ul>
            </div>
            ];
        }
    }

    return ($body,$Data->{'lang'}->txt('Configuration'));
}

sub nodesettings_menu {
    my ($action, $Data, $client)=@_;

    my $l=$Data->{'lang'};
    my $level = $Data->{'clientValues'}{'currentLevel'} || 0;

    my $SystemConfig = $Data->{'SystemConfig'};

    my $txt_Clr = $Data->{'SystemConfig'}{'txtCLR'} || 'Clearance';
    my $txt_SeasonsNames= $Data->{'SystemConfig'}{'txtSeasons'} || 'Seasons';
    my $txt_AgeGroupsNames= $Data->{'SystemConfig'}{'txtAgeGroups'} || 'Age Groups';
    my $target = $Data->{'target'};

    my $nodeID = getID($Data->{'clientValues'});
    my $hideclearances = 0;
    if($nodeID) {
        my $st = qq[
        SELECT intHideClearances
        FROM tblNode
        WHERE intNodeID = ?
        LIMIT 1
        ];
        my $query = $Data->{'db'}->prepare($st);
        $query->execute($nodeID);
        ($hideclearances) = $query->fetchrow_array();
    }

    my $clearancesettings = ($Data->{'SystemConfig'}{'AllowClearances'} and !$hideclearances)
    ? qq[<li><a href="$Data->{'target'}?client=$client&amp;a=CLRSET_">].$l->txt("$txt_Clr Settings").qq[</a></li>]
    : '';

    my $products = ($Data->{'SystemConfig'}{'AllowTXNs'} and $level == $Defs::LEVEL_NATIONAL)
    ? qq[ <li><a href="$Data->{'target'}?client=$client&amp;a=A_PR_">].$l->txt('Products').qq[</a></li>]
    : '';

    my $seasons = ($SystemConfig->{'AllowSeasons'} and $level == $Defs::LEVEL_NATIONAL)
    ? qq[<li><a href = "$target?client=$client&amp;a=SN_L">].$Data->{'lang'}->txt($txt_SeasonsNames).qq[</a>] 
    : ''; 

    my $agegroups = ($SystemConfig->{'AllowSeasons'} and $level == $Defs::LEVEL_NATIONAL)
    ? qq[<li><a href = "$target?client=$client&amp;a=AGEGRP_L">].$Data->{'lang'}->txt($txt_AgeGroupsNames).qq[</a>] 
    : ''; 

    my $txt1=$l->txt('These configuration options allow you to modify the data and behaviour of the system.');
    my $body=qq[
    <p>$txt1</p><br>
    <div class="settings-group">
    <div class="settings-group-name">Configure Database Fields</div>
    <ul>
    <li><a href="$Data->{'target'}?client=$client&amp;a=FC_C_d">].$l->txt('Field Configuration').qq[</a></li>
    </ul>
    </div>
    ];
    if($products or $clearancesettings or $seasons or $agegroups) {
        $body .= qq[
        <div class="settings-group">
        <div class="settings-group-name">Setup Registrations and Payments</div>
        <ul>
        $products
        $clearancesettings
        $seasons
        $agegroups
        </ul>
        </div>
        ];
    }
    $body .= qq[
    <div class="settings-group">
    <div class="settings-group-name">Manager Users and Security</div>
    <ul>
    <li><a href="$Data->{'target'}?client=$client&amp;a=AM_">].$l->txt('User Management').qq[</a></li>
    </ul>
    </div>
    ];

    $body = '' if ($Data->{'SystemConfig'}{'RestrictedConfigOptions'} and $level < $Data->{'SystemConfig'}{'RestrictedConfigOptions'});

    return ($body,$Data->{'lang'}->txt('Configuration'));
}

1;
# vim: set et sw=4 ts=4:
