package Navbar;

require Exporter;
@ISA =  qw(Exporter);
@EXPORT = qw(navBar );
@EXPORT_OK = qw(navBar );

use strict;
use DBI;
use lib '.';
use Reg_common;
use Defs;
use Utils;
use ConfigOptions;
use Duplicates;
use PaymentSplitUtils;
use MD5;
use InstanceOf;
use PageMain;
use ServicesContacts;
use TTTemplate;
use Log;
use Data::Dumper;

sub navBar {
    my(
        $Data, 
        $DataAccess_ref, 
        $SystemConfig
    ) = @_;

    my $clientValues_ref=$Data->{'clientValues'};
    my $currentLevel = $clientValues_ref->{INTERNAL_tempLevel} ||  $clientValues_ref->{currentLevel};
    my $currentID = getID($clientValues_ref);
    $clientValues_ref->{personID} = $Defs::INVALID_ID if $currentLevel > $Defs::LEVEL_PERSON;
    $clientValues_ref->{clubID} = $Defs::INVALID_ID  if $currentLevel > $Defs::LEVEL_CLUB;
    $clientValues_ref->{zoneID} = $Defs::INVALID_ID if $currentLevel >= $Defs::LEVEL_REGION;
    $clientValues_ref->{regionID} = $Defs::INVALID_ID if $currentLevel >= $Defs::LEVEL_NATIONAL;
    $clientValues_ref->{nationalID} = $Defs::INVALID_ID if $currentLevel >= $Defs::LEVEL_INTZONE;
    $clientValues_ref->{natID} = $Defs::INVALID_ID if $currentLevel >= $Defs::LEVEL_INTZONE;
    $clientValues_ref->{intzonID} = $Defs::INVALID_ID if $currentLevel >= $Defs::LEVEL_INTREGION;
    $clientValues_ref->{intregID} = $Defs::INVALID_ID if $currentLevel == $Defs::LEVEL_INTERNATIONAL;

    my ($navTree, $navObjects) = GenerateTree($Data, $clientValues_ref);

    my $client=setClient($clientValues_ref);

    my $menu_template = 'navbar/menu.templ';
    my $menu_data = undef;
    if(
        $currentLevel == $Defs::LEVEL_TOP
            or $currentLevel == $Defs::LEVEL_INTERNATIONAL
            or $currentLevel == $Defs::LEVEL_INTREGION
            or $currentLevel == $Defs::LEVEL_INTZONE
            or $currentLevel == $Defs::LEVEL_NATIONAL
            or $currentLevel == $Defs::LEVEL_STATE
            or $currentLevel == $Defs::LEVEL_REGION
            or $currentLevel == $Defs::LEVEL_ZONE 
    ) {
        $menu_data = getEntityMenuData(
            $Data,
            $currentLevel,
            $currentID,
            $client,
            $navObjects->{$currentLevel},
        );
    }
    elsif( $currentLevel == $Defs::LEVEL_CLUB) {
        $menu_data = getClubMenuData(
            $Data,
            $currentLevel,
            $currentID,
            $client,
            $navObjects->{$currentLevel},
        );
    }
    elsif( $currentLevel == $Defs::LEVEL_PERSON) {
        $menu_data = getPersonMenuData(
            $Data,
            $currentLevel,
            $currentID,
            $client,
            $navObjects->{$currentLevel},
        );
    }

    my $menu = '';
    if($menu_data and $menu_template) {
        $menu_data->{'client'} = $client;
        my %TemplateData= (
            MenuData => $menu_data,
        );
        $menu = runTemplate(
            $Data,
            \%TemplateData,
            $menu_template
        ) || '';
    }

    my $homeClient = getHomeClient($Data);

    my %HomeAction = (
        $Defs::LEVEL_INTERNATIONAL =>  'E_HOME',
        $Defs::LEVEL_INTREGION =>  'E_HOME',
        $Defs::LEVEL_INTZONE =>  'E_HOME',
        $Defs::LEVEL_NATIONAL =>  'E_HOME',
        $Defs::LEVEL_STATE =>  'E_HOME',
        $Defs::LEVEL_REGION =>  'E_HOME',
        $Defs::LEVEL_ZONE =>  'E_HOME',
        $Defs::LEVEL_CLUB =>  'C_HOME',
        $Defs::LEVEL_PERSON =>  'P_HOME',
    );

    my %TemplateData= (
        NavTree => $navTree,
        Menu => $menu,
        HomeURL => "$Data->{'target'}?client=$homeClient&amp;a=".$HomeAction{$Data->{'clientValues'}{'authLevel'}},
    );
    my $templateFile = 'navbar/navbar_main.templ';
    my $navbar = runTemplate(
        $Data,
        \%TemplateData,
        $templateFile
    );

    return $navbar;
}

sub getEntityMenuData {
    my (
        $Data,
        $currentLevel,
        $currentID,
        $client,
        $entityObj,
    ) = @_;


    my $target=$Data->{'target'} || '';
    my $lang = $Data->{'lang'} || '';
    my %cvals=getClient($client);
    $cvals{'currentLevel'}=$currentLevel ;
    $client=setClient(\%cvals);
    my $SystemConfig = $Data->{'SystemConfig'};
    my $txt_SeasonsNames= $SystemConfig->{'txtSeasons'} || 'Seasons';
    my $txt_AgeGroupsNames= $SystemConfig->{'txtAgeGroups'} || 'Age Groups';

    my $children = getEntityChildrenTypes($Data->{'db'}, $currentID, $Data->{'Realm'});

    my $hideClearances = $entityObj->getValue('intHideClearances');

    my $txt_Clr = $lang->txt('Transfer');
    my $txt_Clr_ListOnline = $lang->txt('List Online Transfers');

    my $paymentSplitSettings = getPaymentSplitSettings($Data);
    my $baseurl = "$target?client=$client&amp;";
    my %menuoptions = (
        advancedsearch => {
            name => $lang->txt('Advanced Search'),
            url => $baseurl."a=SEARCH_F",
        },
        reports => {
            name => $lang->txt('Reports'),
            url => $baseurl."a=REP_SETUP",
        },
        home => {
            name => $lang->txt('Dashboard'),
            url => $baseurl."a=E_HOME",
        },
    );
    if(exists $children->{$Defs::LEVEL_STATE})    {
        $menuoptions{'states'} = {
            name => $lang->txt($Data->{'LevelNames'}{$Defs::LEVEL_STATE.'_P'}),
            url => $baseurl."a=E_L&amp;l=$Defs::LEVEL_STATE",
        };
    }
    if(exists $children->{$Defs::LEVEL_REGION})    {
        $menuoptions{'regions'} = {
            name => $lang->txt($Data->{'LevelNames'}{$Defs::LEVEL_REGION.'_P'}),
            url => $baseurl."a=E_L&amp;l=$Defs::LEVEL_REGION",
        };
    }
    if(exists $children->{$Defs::LEVEL_ZONE})    {
        $menuoptions{'zones'} = {
            name => $lang->txt($Data->{'LevelNames'}{$Defs::LEVEL_ZONE.'_P'}),
            url => $baseurl."a=E_L&amp;l=$Defs::LEVEL_ZONE",
        };
    }
    #if(exists $children->{$Defs::LEVEL_CLUB})    {
        $menuoptions{'clubs'} = {
            name => $lang->txt($Data->{'LevelNames'}{$Defs::LEVEL_CLUB.'_P'}),
            url => $baseurl."a=C_L&amp;l=$Defs::LEVEL_CLUB",
        };
    #}
    #if(exists $children->{$Defs::LEVEL_VENUE})    {
        $menuoptions{'venues'} = {
            name => $lang->txt($Data->{'LevelNames'}{$Defs::LEVEL_VENUE.'_P'}),
            url => $baseurl."a=VENUE_L&amp;l=$Defs::LEVEL_VENUE",
        };
    #}
    #if(exists $children->{$Defs::LEVEL_PERSON})    {
        $menuoptions{'persons'} = {
            name => $lang->txt($Data->{'LevelNames'}{$Defs::LEVEL_PERSON.'_P'}),
            url => $baseurl."a=P_L&amp;l=$Defs::LEVEL_PERSON",
        };
    #}

    if($paymentSplitSettings->{'psBanks'}) {
        $menuoptions{'bankdetails'} = {
            name => $lang->txt('Payment Configuration'),
            url => $baseurl."a=BA_",
        };
    }


        $menuoptions{'approvals'} = {
            name => $lang->txt('Work Tasks'),
            url => $baseurl."a=WF_",
        };

        $menuoptions{'entityregistrationallowed'} = {
            name => $lang->txt('Reg. Allowed'),
            url => $baseurl."a=ERA_",
        };

    $menuoptions{'usermanagement'} = {
        name => $lang->txt('User Management'),
        url  => $baseurl."a=AM_",
    };

    if( scalar(keys $children)) {
        $menuoptions{'fieldconfig'} = {
            name => $lang->txt('Field Configuration'),
            url => $baseurl."a=FC_C_d",
        };

        if($SystemConfig->{'AllowClearances'} 
                and !$hideClearances
                and (!$Data->{'ReadOnlyLogin'} 
                    or  $SystemConfig->{'Overide_ROL_RequestClearance'})
        ) {
            $menuoptions{'clearances'} = {
                name => $lang->txt($txt_Clr_ListOnline),
                url => $baseurl."a=CL_list",
            };
            $menuoptions{'clearancesettings'} = {
                name => $lang->txt("$txt_Clr Settings"),
                url => $baseurl."a=CLRSET_",
            };
            if(
                $Data->{'clientValues'}{'authLevel'} >= $Defs::LEVEL_NATIONAL and 
                !$SystemConfig->{'clrHideSearchAll'}
            ) {
                $menuoptions{'clearancesAll'} = {
                    name => $lang->txt("Search ALL Online $txt_Clr"."s"),
                    url => $baseurl."a=CL_list&amp;showAll=1",
                };
            }
        }
        if ($SystemConfig->{'AllowCardPrinting'}) {
            $menuoptions{'cardprinting'} = {
                name => $lang->txt('Card Printing'),
                url => $baseurl."a=MEMCARD_BL",
            };
        }

        if ($SystemConfig->{'AllowPendingRegistration'}) {
            $menuoptions{'pendingregistration'} = {
                name => $lang->txt('Pending Registration'),
                url => $baseurl."a=P_PRS_L",
            };
        }

        #nationalrego. enable regoforms at entity level.
        if  ($SystemConfig->{'AllowOnlineRego_entity'}) {
            $menuoptions{'registrationforms'} = {
                name => $lang->txt('Registration Forms'),
                url => $baseurl."a=A_ORF_r",
            };
        }

        if($currentLevel == $Defs::LEVEL_NATIONAL) {
            #National Level Only
            if( $SystemConfig->{'AllowOldBankSplit'}) {
                $menuoptions{'bankfileexport'} = {
                    name => $lang->txt("Bank File Export"),
                    url => $baseurl."a=BANKSPLIT_",
                };
            }
            if($paymentSplitSettings->{'psRun'} 
                    and ! $SystemConfig->{'AllowOldBankSplit'}) {
                $menuoptions{'paymentsplitrun'} = {
                    name => $lang->txt("Payment Split Run"),
                    url => $baseurl."a=PSR_opt",
                };
            }

            if ($SystemConfig->{'AllowSeasons'}) {
                $menuoptions{'seasons'} = {
                    name => $lang->txt($txt_SeasonsNames),
                    url => $baseurl."a=SE_L",
                };
                $menuoptions{'agegroups'} = {
                    name => $lang->txt($txt_AgeGroupsNames),
                    url => $baseurl."a=AGEGRP_L",
                };
            }
            if(isCheckDupl($Data)) {
                $menuoptions{'duplicates'} = {
                    name => $lang->txt('Duplicate Resolution'),
                    url => $baseurl."a=DUPL_L",
                };
            }


        }
    }
                $menuoptions{'products'} = {
                    name => $lang->txt('Products'),
                    url => $baseurl."a=PR_",
                };

    # for Entity menu

    if(!$SystemConfig->{'NoAuditLog'}) {
        $menuoptions{'auditlog'} = {
            name => $lang->txt('Audit Log'),
            url => $baseurl."a=AL_",
        };
    }
    my $txt_RequestCLR = $SystemConfig->{'txtRequestCLR'} || 'Request a Clearance';
if($SystemConfig->{'AllowClearances'} and !$SystemConfig->{'TurnOffRequestClearance'}
    ) {
        if(!$Data->{'ReadOnlyLogin'}) {
            $menuoptions{'newclearance'} = {
                name => $lang->txt($txt_RequestCLR),
                url => $baseurl."a=CL_createnew",
            };
        }
        if (
            $Data->{'ReadOnlyLogin'} or $SystemConfig->{'Overide_ROL_RequestClearance'}) {
            $menuoptions{'newclearance'} = {
                name => $lang->txt($txt_RequestCLR),
                url => $baseurl."a=CL_createnew",
            };
        }
    }
    my @menu_structure = (
        [ $lang->txt('Dashboard'), 'home','home'],
        [ $lang->txt('States'), 'menu','states'],
        [ $lang->txt('Regions'), 'menu','regions'],
        [ $lang->txt('Zones'), 'menu','zones'],
        [ $lang->txt('Clubs'), 'menu','clubs'],
        [ $lang->txt('Venues'), 'menu','venues'],
        [ $lang->txt('People'), 'menu','persons'],
        [ $lang->txt('Work Tasks'), 'menu','approvals'],
        [ $lang->txt('Transfers'), 'menu', [
        'clearances',    
        'newclearance',    
        'clearancesAll',
        ]],
        [ $lang->txt('Registrations'), 'menu',[
        'bankdetails',
        'bankfileexport',
        'paymentsplitrun',
        'registrationforms', #nationalrego. enable regoforms at entity level.
        'entityregistrationallowed',
        ]],
        [ $lang->txt('Reports'), 'menu',[
        'reports',
        ]],
        [ $lang->txt('Search'), 'search',[
        'advancedsearch',
        'nataccredsearch',
        ]],
        [ $lang->txt('System'), 'system',[
        'usermanagement',
        'fieldconfig',
        'clearancesettings',
        'seasons',
        'agegroups',
        'mrt_admin',
        'auditlog',
        'optin',
        ]],
    );

    my $menudata = processmenudata(\%menuoptions, \@menu_structure);
    return $menudata;

}

sub getAssocMenuData {
    my (
        $Data,
        $currentLevel,
        $currentID,
        $client,
        $assocObj,
    ) = @_;

    my $target=$Data->{'target'} || '';
    my $lang = $Data->{'lang'} || '';
    my %cvals=getClient($client);
    $cvals{'currentLevel'}=$currentLevel ;
    $client=setClient(\%cvals);
    my $SystemConfig = $Data->{'SystemConfig'};
    my $txt_SeasonsNames= $SystemConfig->{'txtSeasons'} || 'Seasons';
    my $txt_AgeGroupsNames= $SystemConfig->{'txtAgeGroups'} || 'Age Groups';
    my $txt_Clr = $SystemConfig->{'txtCLR'} || 'Clearance';
    my $txt_Clr_ListOnline = $SystemConfig->{'txtCLRListOnline'} || "List Online $txt_Clr"."s";
    my $txt_Clr_ListOffline = "List Offline $txt_Clr"."s";

    my $swol_url = $Defs::SWOL_URL;
    $swol_url = $Defs::SWOL_URL_v6 if ($Data->{'SystemConfig'}{'AssocConfig'}{'olrv6'});
    my $DataAccess_ref = $Data->{'DataAccess'};

    my (
        $intAllowClearances, 
        $intSWOL,
        $hideAssocRollover,
        $hideClubRollover,
        $hideAllCheckbox,
        $intAllowRegoForm,
        $intAllowSeasons,
    ) = $assocObj->getValue([
        'intAllowClearances', 
        'intSWOL',
        'intHideRollover',
        'intClubRollover',
        'intHideAllRolloverCheckbox',
        'intAllowRegoForm',
        'intAllowSeasons',
        ]);
    $intSWOL = 0 if !$SystemConfig->{'AllowSWOL'};

    my $paymentSplitSettings = getPaymentSplitSettings($Data);

    my $baseurl = "$target?client=$client&amp;";
    my %menuoptions = (
        advancedsearch => {
            name => $lang->txt('Advanced Search'),
            url => $baseurl."a=SEARCH_F",
        },
        reports => {
            name => $lang->txt('Reports'),
            url => $baseurl."a=REP_SETUP",
        },
        home => {
            name => $lang->txt('Dashboard'),
            url => $baseurl."a=A_HOME",
        },
        persons => {
            name => $lang->txt('List '.$Data->{'LevelNames'}{$Defs::LEVEL_PERSON.'_P'}),
            url => $baseurl."a=P_L&amp;l=$Defs::LEVEL_PERSON",
        },
    );

    if (
        $Data->{'Permissions'}{'OtherOptions'}{ShowClubs} 
            or !$SystemConfig->{'NoClubs'}) {
        $menuoptions{'clubs'} = {
            name => $lang->txt('List '.$Data->{'LevelNames'}{$Defs::LEVEL_CLUB.'_P'}),
            url => $baseurl."a=C_L&amp;l=$Defs::LEVEL_CLUB",
        };
    }
    if ($SystemConfig->{'AssocServices'} and !$Data->{'ReadOnlyLogin'}) {
        $menuoptions{'services'} = {
            name => $lang->txt('Locator'),
            url => $baseurl."a=A_SV_DTE",
        };
    }

    #first can the person looking see any other options anyway
    my $data_access=$DataAccess_ref->{$Defs::LEVEL_ASSOC}{$currentID};
    #$data_access=$Defs::DATA_ACCESS_FULL;
    if (
        $data_access==$Defs::DATA_ACCESS_FULL 
            or $data_access==$Defs::DATA_ACCESS_READONLY
    ) {

        if($SystemConfig->{'AllowClearances'} 
                and $intAllowClearances
        ) {
            $menuoptions{'clearances'} = {
                name => $lang->txt($txt_Clr_ListOnline),
                url => $baseurl."a=CL_list",
            };
        }
        if($SystemConfig->{'DisplayOffLineClearances'}
                and $intAllowClearances
        )       {
            $menuoptions{'clearancesoff'} = {
                name => $lang->txt($txt_Clr_ListOffline),
                url => $baseurl."a=CL_offlist",
            };
        }


        if (
            $data_access==$Defs::DATA_ACCESS_FULL
                and !$Data->{'ReadOnlyLogin'}
                and allowedAction($Data,'a_e')
        ) {
            $menuoptions{'usermanagement'} = {
                name => $lang->txt('User Management'),
                url => $baseurl."a=AM_",
            };
            if(!$SystemConfig->{'NoConfig'}) {
                $menuoptions{'settings'} = {
                    name => $lang->txt('Settings'),
                    url => $baseurl."a=A_O_m",
                };
            }

            if(isCheckDupl($Data)) {
                $menuoptions{'duplicates'} = {
                    name => $lang->txt('Duplicate Resolution'),
                    url => $baseurl."a=DUPL_L",
                };
            }

            if (allowedAction($Data,'ba_e')) {
                if($paymentSplitSettings->{'psBanks'}) {
                    $menuoptions{'bankdetails'} = {
                        name => $lang->txt('Payment Configuration'),
                        url => $baseurl."a=BA_",
                    };
                }
            }
            if($paymentSplitSettings->{'psSplits'}) {
                $menuoptions{'paymentsplits'} = {
                    name => $lang->txt('Payment Splits'),
                    url => $baseurl."a=A_PS_showsplits",
                };
            }

            if ($SystemConfig->{'AllowCardPrinting'}) {
                $menuoptions{'cardprinting'} = {
                    name => $lang->txt('Card Printing'),
                    url => $baseurl."a=MEMCARD_BL",
                };
            }

            if ($SystemConfig->{'AllowPendingRegistration'}) {
                $menuoptions{'pendingregistration'} = {
                    name => $lang->txt('Pending Registration'),
                    url => $baseurl."a=P_PRS_L",
                };
            }

            if($SystemConfig->{'AllowTXNs'}) {
                $menuoptions{'products'} = {
                    name => $lang->txt('Products'),
                    url => $baseurl."a=PR_",
                };
            }   
            if (
                $intAllowRegoForm
                    and (
                    $Data->{'SystemConfig'}{'AllowOnlineRego'}
                        or $Data-> {'Permissions'}{'OtherOptions'}{'AllowOnlineRego'}
                )
            ) {
                $menuoptions{'registrationforms'} = {
                    name => $lang->txt('Registration Forms'),
                    url => $baseurl."a=A_ORF_r",
                };
            }

        }
    }

    if(
        $intAllowSeasons
            and ((!$Data->{'SystemConfig'}{'LockSeasons'}
                    and !$Data->{'SystemConfig'}{'Rollover_HideAll'}
                    and !$Data->{'SystemConfig'}{'Rollover_HideAssoc'}) or $Data->{'SystemConfig'}{'AssocConfig'}{'Rollover_AddRollover_Override'})
            and !$hideAssocRollover
            and allowedAction($Data, 'm_e')) {
        $menuoptions{'personrollover'} = {
            name => $lang->txt($Data->{'LevelNames'}{$Defs::LEVEL_PERSON}.' Rollover'),
            url => $baseurl."a=P_LSRO&amp;l=$Defs::LEVEL_PERSON",
        };
    }

    if (
        $Data->{'SystemConfig'}{'AllowPersonTransfers'}
            and allowedAction($Data, 'a_e')
    ) {
        $menuoptions{'transferperson'} = {
            url => $baseurl."a=P_TRANSFER&amp;l=$Defs::LEVEL_PERSON",
            name => $Data->{'SystemConfig'}{'transferPersonText'} || $lang->txt('Transfer Person'),
        };
    }


    # for assoc menu
    if(!$SystemConfig->{'NoAuditLog'}) {
        $menuoptions{'auditlog'} = {
            name => $lang->txt('Audit Log'),
            url => $baseurl."a=AL_",
        };
    }

    #if ($Data->{'SystemConfig'}{'DefaultListAction'} and $Data->{'SystemConfig'}{'DefaultListAction'} eq 'SUMM') {
    #push @assoc_options, [ $target, { client => $nc, a => 'A_SUMM' }, $textLabels{'Association Summary'}, ];
    #}

    my @menu_structure = (
        [ $lang->txt('Dashboard'), 'home','home'],
        [ $lang->txt($Data->{'LevelNames'}{$Defs::LEVEL_PERSON.'_P'}), 'menu', [
        'persons',
        'duplicates',
        'clearances',    
        'clearancesoff',    
        'personrollover',
        'transferperson',
        'cardprinting',
        'pendingregistration',
        ]],
        [ $lang->txt($Data->{'LevelNames'}{$Defs::LEVEL_CLUB.'_P'}), 'menu', [
        'clubs',
        'clubchampionships',
        ]],
        [ $lang->txt('Registrations'), 'menu',[
        'bankdetails',
        'registrationforms',
        'paymentsplits',
        'services',
        ]],
        [ $lang->txt('Reports'), 'menu',[
        'reports',
        ]],
        [ $lang->txt('Search'), 'search',[
        'advancedsearch',
        'nataccredsearch',
        ]],
        [ $lang->txt('System'), 'system',[
        'settings',
        'usermanagement',
        'seasons',
        'processlog',
        'mrt_admin',
        'auditlog',
        ]],
    );

    my $menudata = processmenudata(\%menuoptions, \@menu_structure);
    return $menudata;

}

sub getClubMenuData {
    my (
        $Data,
        $currentLevel,
        $currentID,
        $client,
        $clubObj,
        $assocObj,
    ) = @_;

    my $target=$Data->{'target'} || '';
    my $lang = $Data->{'lang'} || '';
    my %cvals=getClient($client);
    $cvals{'currentLevel'}=$currentLevel ;
    $client=setClient(\%cvals);
    my $SystemConfig = $Data->{'SystemConfig'};
    my $txt_SeasonsNames= $SystemConfig->{'txtSeasons'} || 'Seasons';
    my $txt_AgeGroupsNames= $SystemConfig->{'txtAgeGroups'} || 'Age Groups';
    my $txt_Clr = $SystemConfig->{'txtCLR'} || 'Clearance';
    my $txt_Clr_ListOnline = $SystemConfig->{'txtCLRListOnline'} || "List Online $txt_Clr"."s";
    my $DataAccess_ref = $Data->{'DataAccess'};

    my $paymentSplitSettings = getPaymentSplitSettings($Data);

    my $baseurl = "$target?client=$client&amp;";
    my %menuoptions = (
        advancedsearch => {
            name => $lang->txt('Advanced Search'),
            url => $baseurl."a=SEARCH_F",
        },
        reports => {
            name => $lang->txt('Reports'),
            url => $baseurl."a=REP_SETUP",
        },
        home => {
            name => $lang->txt('Dashboard'),
            url => $baseurl."a=C_HOME",
        },
        persons => {
            name => $lang->txt('List '.$Data->{'LevelNames'}{$Defs::LEVEL_PERSON.'_P'}),
            url => $baseurl."a=P_L&amp;l=$Defs::LEVEL_PERSON",
        },
        venues => {
            name => $lang->txt('List '.$Data->{'LevelNames'}{$Defs::LEVEL_VENUE.'_P'}),
            url => $baseurl."a=VENUE_L&amp;l=$Defs::LEVEL_VENUE",
        },
    );
    my $txt_RequestCLR = $SystemConfig->{'txtRequestCLR'} || 'Request a Clearance';

    if ($SystemConfig->{'AllowPendingRegistration'}) {
        $menuoptions{'pendingregistration'} = {
            name => $lang->txt('Pending Registration'),
            url => $baseurl."a=P_PRS_L",
        };
    }

    if($SystemConfig->{'AllowClearances'} and !$SystemConfig->{'TurnOffRequestClearance'} 
    ) {
        if(!$Data->{'ReadOnlyLogin'}) {
            $menuoptions{'newclearance'} = {
                name => $lang->txt($txt_RequestCLR),
                url => $baseurl."a=CL_createnew",
            };
        }
        if (
            $Data->{'ReadOnlyLogin'} or $SystemConfig->{'Overide_ROL_RequestClearance'}) {
            $menuoptions{'newclearance'} = {
                name => $lang->txt($txt_RequestCLR),
                url => $baseurl."a=CL_createnew",
            };
        }
    }
    #first can the person looking see any other options anyway
    my $data_access=$DataAccess_ref->{$Defs::LEVEL_CLUB}{$currentID};
    $data_access=$Defs::DATA_ACCESS_FULL;

    if (
        $data_access==$Defs::DATA_ACCESS_FULL 
            or $data_access==$Defs::DATA_ACCESS_READONLY
    ) {

        if($SystemConfig->{'AllowClearances'} 
                and (!$Data->{'ReadOnlyLogin'} or
                $SystemConfig->{'Overide_ROL_RequestClearance'}
            )
        ){
            $menuoptions{'clearances'} = {
                name => $lang->txt($txt_Clr_ListOnline),
                url => $baseurl."a=CL_list",
            };
            $menuoptions{'clearancesettings'} = {
                name => $lang->txt("$txt_Clr Settings"),
                url => $baseurl."a=CLRSET_",
            };
        }

        if (
            $data_access==$Defs::DATA_ACCESS_FULL
                and !$Data->{'ReadOnlyLogin'}
                and allowedAction($Data,'c_e')
        ) {

            $menuoptions{'usermanagement'} = {
                name => $lang->txt('User Management'),
                url => $baseurl."a=AM_",
            };
            if ( $Data->{'SystemConfig'}{'AllowPersonTransfers'}  and allowedAction($Data, 'c_e')) {
                $menuoptions{'transferperson'} = {
                    url => $baseurl."a=P_TRANSFER&amp;l=$Defs::LEVEL_PERSON",
                    name => $Data->{'SystemConfig'}{'transferPersonText'} || $lang->txt('Transfer Person'),
                };
            }

            if (allowedAction($Data,'c_e')) {
                if($paymentSplitSettings->{'psBanks'}) {
                    $menuoptions{'bankdetails'} = {
                        name => $lang->txt('Payment Configuration'),
                        url => $baseurl."a=BA_",
                    };
                }
            }
            if ($SystemConfig->{'AssocClubServices'}) {
                $menuoptions{'locator'} = {
                    name => $lang->txt('Locator'),
                    url => $baseurl."a=A_SV_DTE",
                };
            }
            if(isCheckDupl($Data)) {
                $menuoptions{'duplicates'} = {
                    name => $lang->txt('Duplicate Resolution'),
                    url => $baseurl."a=DUPL_L",
                };
            }
            if($SystemConfig->{'AllowTXNs'}
                    and $SystemConfig->{'AllowClubTXNs'}
            ) {
                $menuoptions{'products'} = {
                    name => $lang->txt('Products'),
                    url => $baseurl."a=PR_",
                };
            }   
        $menuoptions{'approvals'} = {
            name => $lang->txt('Work Tasks'),
            url => $baseurl."a=WF_",
        };
        $menuoptions{'entityregistrationallowed'} = {
            name => $lang->txt('Reg. Allowed'),
            url => $baseurl."a=ERA_",
        };


            if (
                $Data->{'SystemConfig'}{'AllowOnlineRego'}
                    or $Data-> {'Permissions'}{'OtherOptions'}{'AllowOnlineRego'}
                    and !$Data->{'ReadOnlyLogin'}
            ) {
                $menuoptions{'registrationforms'} = {
                    name => $lang->txt('Registration Forms'),
                    url => $baseurl."a=A_ORF_r",
                };
            }

        }
    }

    if(
            (!$Data->{'SystemConfig'}{'LockSeasons'}
                    and !$Data->{'SystemConfig'}{'LockSeasonsCRL'}
                    and !$Data->{'SystemConfig'}{'Club_PersonEditOnly'}
                    and !$Data->{'SystemConfig'}{'Rollover_HideAll'}
                    and !$Data->{'SystemConfig'}{'Rollover_HideClub'}
            )
            and allowedAction($Data, 'm_e')) {
        $menuoptions{'personrollover'} = {
            name => $lang->txt($Data->{'LevelNames'}{$Defs::LEVEL_PERSON}.' Rollover'),
            url => $baseurl."a=P_LSRO&amp;l=$Defs::LEVEL_PERSON",
        };
    }

    # for club menu

    if(!$SystemConfig->{'NoAuditLog'}) {
        $menuoptions{'auditlog'} = {
            name => $lang->txt('Audit Log'),
            url => $baseurl."a=AL_",
        };
    }
     if($SystemConfig->{'AllowTXNs'} and $SystemConfig->{'AllowClubTXNs'}) {
        $menuoptions{'transactions'} = {
            name => $lang->txt('Transactions'),
            url => $baseurl."a=C_TXNLog_list",
        };
     }
 
    my @menu_structure = (
        [ $lang->txt('Dashboard'), 'home','home'],
        [ $lang->txt($Data->{'LevelNames'}{$Defs::LEVEL_PERSON.'_P'}), 'menu', [
        'persons',
        'newclearance',    
        'clearances',    
        'personrollover',
        'transferperson',
        'duplicates',
        'pendingregistration',
        ]],
        [ $lang->txt($Data->{'LevelNames'}{$Defs::LEVEL_VENUE.'_P'}), 'menu','venues'],
        [ $lang->txt('Work Tasks'), 'menu','approvals'],
        [ $lang->txt('Registrations'), 'menu',[
        'registrationforms',
        'transactions',
        'locator',
        'entityregistrationallowed',
        ]],
        [ $lang->txt('Reports'), 'menu',[
        'reports',
        ]],
        [ $lang->txt('Search'), 'search',[
        'advancedsearch',
        'nataccredsearch',
        ]],
        [ $lang->txt('System'), 'system',[
        'usermanagement',
        'clearancesettings',
        'mrt_admin',
        'auditlog',
        ]],
    );

    my $menudata = processmenudata(\%menuoptions, \@menu_structure);
    return $menudata;

}

sub getEntityChildrenTypes  {
    my($db, $ID, $realmID) = @_;
    my %existingChildren = ();

    my $st = qq[
        SELECT 
            CE.intEntityLevel,
            COUNT(1) as cnt
        FROM
            tblEntityLinks AS EL
            INNER JOIN tblEntity AS CE
                ON EL.intChildEntityID = CE.intEntityID
        WHERE
            EL.intParentEntityID = ?
            AND CE.intDataAccess >= $Defs::DATA_ACCESS_STATS
        GROUP BY
            CE.intEntityLevel
        HAVING
            cnt > 0
    ];
    my $q = $db->prepare($st);
    $q->execute($ID);
    while(my($level, $cnt) = $q->fetchrow_array()) {
        $existingChildren{$level} = 1;
    }
    $st = qq[
        SELECT 
            1
        FROM
            tblPersonRegistration_$realmID
        WHERE
            intEntityID = ?
        LIMIT 1
    ];
    $q = $db->prepare($st);
    $q->execute($ID);
    my ($foundperson) = $q->fetchrow_array();
    $q->finish();
    if($foundperson)    {
        $existingChildren{$Defs::LEVEL_PERSON} = 1;
    }

    return \%existingChildren;
}

sub getNavIcons {
    my($Data,$icons)=@_;

    my $navicons='';
    for my $row (@{$icons}) {
        $navicons.=qq~<a href="$row->[0]"><img title="$row->[1]" alt="$row->[1]" src="images/$row->[2]" border="0"></a>~;
    }
    $navicons=qq[ <div class="navicons">$navicons</div> ] if $navicons;
    return $navicons;
}


sub GenerateTree {
    my ($Data, $clientValues_ref) = @_;

    my @tree = ();
    my %objects = ();
    my %instancetypes = (
        interID => ['entity', $Defs::LEVEL_INTERNATIONAL, 'E_HOME', ''],
        intregID => ['entity', $Defs::LEVEL_INTREGION, 'E_HOME', ''],
        intzonID => ['entity', $Defs::LEVEL_INTZONE, 'E_HOME', ''],
        natID => ['entity', $Defs::LEVEL_NATIONAL, 'E_HOME', ''],
        stateID => ['entity', $Defs::LEVEL_STATE, 'E_HOME', ''],
        regionID => ['entity', $Defs::LEVEL_REGION, 'E_HOME', ''],
        zoneID => ['entity', $Defs::LEVEL_ZONE, 'E_HOME', ''],
        clubID => ['club', $Defs::LEVEL_CLUB, 'C_HOME', ''],
        personID => ['person', $Defs::LEVEL_PERSON, 'P_HOME', ''],
    );
    for my $level (qw(
        interID
        intregID
        intzonID
        natID
        stateID
        regionID
        zoneID
        clubID
        personID
        )) {
        my $id = $clientValues_ref->{$level} || 0;
        if(
            $id 
                and $id != $Defs::INVALID_ID
        ) {
            my %tempClientRef = %{$clientValues_ref};
            my $instancetype = $instancetypes{$level}[0] || next;
            my $levelType = $instancetypes{$level}[1] || next;
            my $action = $instancetypes{$level}[2] || '';
            my $namefield = $instancetypes{$level}[3] || 'strName';
            my $obj = getInstanceOf($Data, $instancetype, $id) || next;
            $tempClientRef{'currentLevel'} = $levelType;
            my $client=setClient(\%tempClientRef);
            my $url = "$Data->{'target'}?client=$client&amp;a=$action";
            my $name = $obj->name();
            $objects{$levelType} = $obj;
            next if $levelType > $clientValues_ref->{'authLevel'};
            push @tree, {
                name => $name,
                type => $levelType,
                url => $url,
                levelname => $Data->{'LevelNames'}{$levelType},
            };
        }
    }

    return (
        \@tree,
        \%objects,
    );
}

sub processmenudata {
    my(
        $menuoptions, 
        $menu_structure
    ) = @_;

    my %menudata = ();
    for my $toplevel  (@{$menu_structure}) {
        my @menu = ();
        if(ref $toplevel->[2]) {
            for my $sub (@{$toplevel->[2]}) {
                push @menu, $menuoptions->{$sub} if $menuoptions->{$sub};
            }
        }
        else {
            push @menu, $menuoptions->{$toplevel->[2]} if $menuoptions->{$toplevel->[2]};
        }
        my $numitems = scalar(@menu);
        next if !$numitems;
        push @{$menudata{$toplevel->[1]}}, {
            name => $toplevel->[0],
            numitems => $numitems,
            items => \@menu,
        };

    }
    return \%menudata;
}


sub getPersonMenuData {
    my (
        $Data,
        $currentLevel,
        $currentID,
        $client,
        $personObj,
        $assocObj,
    ) = @_;

    my $target=$Data->{'target'} || '';
    my $lang = $Data->{'lang'} || '';
    my %cvals=getClient($client);
    $cvals{'currentLevel'}=$currentLevel ;
    $client=setClient(\%cvals);
    my $SystemConfig = $Data->{'SystemConfig'};
    my $txt_SeasonsNames= $SystemConfig->{'txtSeasons'} || 'Seasons';
    my $txt_Clrs = $Data->{'SystemConfig'}{'txtCLRs'} || 'Clearances';
    my $DataAccess_ref = $Data->{'DataAccess'};
    my $accreditation_title = exists $Data->{'SystemConfig'}{'ACCRED_Custom_Name'} ? $Data->{'SystemConfig'}{'ACCRED_Custom_Name'}.'s' : "Accreditations";

    my ($intOfficial) = $personObj->getValue('intOfficial');
    my $clubs = $Data->{'SystemConfig'}{'NoClubs'} ? 0 : 1;
    my $clr= $Data->{'SystemConfig'}{'AllowClearances'} || 0;

    my $baseurl = "$target?client=$client&amp;";
    my %menuoptions = (
        home => {
            name => $lang->txt('Dashboard'),
            url => $baseurl."a=P_HOME",
        },
    );
        if(!$SystemConfig->{'NoAuditLog'}) {
            $menuoptions{'auditlog'} = {
                name => $lang->txt('Audit Log'),
                url => $baseurl."a=AL_",
            };
        }
        if ($SystemConfig->{'NationalAccreditation'} or $SystemConfig->{'AssocConfig'}{'NationalAccreditation'}) {
            $menuoptions{'accreditation'} = {
                name => $lang->txt($accreditation_title),
                url => $baseurl."a=P_NACCRED_LIST",
            };
        }

     my $txns_link_name = $lang->txt('Transactions');
     if($SystemConfig->{'AllowTXNs'}) {
        $menuoptions{'transactions'} = {
            url => $baseurl."a=P_TXNLog_list",
        };
     }
        if($clubs) {
            $menuoptions{'clubs'} = {
                name => $lang->txt('Clubs'),
                url => $baseurl."a=P_CLUBS",
            };
        }
        if($clr) {
            $menuoptions{'clr'} = {
                name => $lang->txt($txt_Clrs),
                url => $baseurl."a=P_CLR",
            };
        }


    $Data->{'SystemConfig'}{'TYPE_NAME_3'} = '' if not exists $Data->{'SystemConfig'}{'TYPE_NAME_3'};
    my @menu_structure = (
        [ $lang->txt('Dashboard'), 'home','home'],
        [ $lang->txt($SystemConfig->{'txns_link_name'} || 'Transactions'), 'menu','transactions'],
        [ $lang->txt($txt_Clrs), 'menu','clr'],
        [ $lang->txt('Person History'), 'menu',[
        'clubs',
        'seasons',
        ]],
        [ $lang->txt('System'), 'system',[
        'auditlog',
        ]],
    );

    my $menudata = processmenudata(\%menuoptions, \@menu_structure );
    return $menudata;

}

# vim: set et sw=4 ts=4:
1;
