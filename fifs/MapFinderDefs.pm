#
# $Header: svn://svn/SWM/trunk/MapFinderDefs.pm 11597 2014-05-19 05:24:34Z akenez $
#

package MapFinderDefs;
require Exporter;

@ISA       = qw(Exporter);
@EXPORT    = qw(getMapFinderDefs);
@EXPORT_OK = qw(getMapFinderDefs);

$TARGET_FILE      = 'mapfinder.cgi';
$TEMPLATES_FOLDER = 'mapfinder';

#$REALM_DEFAULT      = 0;
$REALM_AFL          = 2;
$SUBREALM_AFL9s     = 7;
$REALM_RUGBY_LEAGUE = 3;
$REALM_FIBA = 13;
$SUBREALM_BA = 6;
$REALM_HOCKEY       = 5;
$REALM_SOCCER       = 7;
$REALM_PRIVATE      = 61;
$SUBREALM_ARU       = 120;

$SUBREALM_DEFUALT = 0;

#$REALM_TOUCH = 11;
#$REALM_MOTORCYCLING = 38;
#$REALM_AFL9s      = 20007;    #realm 2 * 10000 + subrealm 7
$REALM_WATER_POLO = 4;

#$REALM_ARU = 610120;

$TYPE_CLUB    = 1;
$TYPE_ASSOC   = 2;
$TYPE_PROGRAM = 3;
$CONFIG_TYPE_ASSOC_CLUB = 1;
$CONFIG_TYPE_PROGRAM    = 2;

%TYPE_MAP = (
    $TYPE_CLUB => $CONFIG_TYPE_ASSOC_CLUB,
    $TYPE_ASSOC => $CONFIG_TYPE_ASSOC_CLUB,
    $TYPE_PROGRAM => $CONFIG_TYPE_PROGRAM,
);

%Settings = (
    $CONFIG_TYPE_ASSOC_CLUB => {
        'default' => {
            Limit    => 10,
            Distance => 100,
            Brand    => "SportingPulse",
            Title    => 'Club Finder',
            Error    => 'error.templ',
            GlobalNav =>
'<script src="https://reg.sportingpulse.com/js/SPPassport.js" type="text/javascript"></script><script>jQuery(document).ready(function() {SPPassport({toolbar : 1});});</script>',
            Page                   => 'page.templ',
            NoResults              => 'noresults_default.templ',
            SearchResults          => 'searchresults_default.templ',
            AlternatePage          => '',
            AlternateSearchResults => '',
            DefaultHeader          => 'sp_membership_web_lrg.png',
            DefaultCopyright =>
'&copy;&nbsp; Copyright FOX SPORTS PULSE Pty Ltd & SportingPulse International Pty Ltd &nbsp;2014.&nbsp; All rights reserved.',
            AdvancedSearch              => 'advanced_search.templ',
            ClubCharacteristicsTemplate => '',
            ExtraStyle                  => '',
            Footer                      => '<div id="footer-links">
                    <div class="footer-nav">
                            <a class="footer-nav-item gd" title="GameDay.com.au" alt="GameDay.com.au" href="http://www.gameday.com.au/" target="_blank"></a>
                            <a class="footer-nav-item sp" title="SportingPulse.com" alt="SportingPulse.com" href="http://www.sportingpulse.com/" target="_blank"></a>
                            <a class="footer-nav-item au" title="About Us" alt="About Us" href="http://corp.sportingpulse.com/index.php?id=6" target="_blank"></a>
                            <a class="footer-nav-item ad" title="Advertise" alt="Advertise" href="http://corp.sportingpulse.com/index.php?id=55" target="_blank"></a>
                            <a class="footer-nav-item cu" title="Contact SP" alt="Contact SP" href="http://corp.sportingpulse.com/index.php?id=66" target="_blank"></a>
                            <a class="footer-nav-item s" title="Support" alt="Support" href="http://support.sportingpulse.com/" target="_blank"></a>
                            <a class="footer-nav-item pr" title="Privacy" alt="Privacy" href="http://corp.sportingpulse.com/index.php?id=75" target="_blank"></a>
                            <a class="footer-nav-item se" title="Search" alt="Search" href="http://sport.gameday.com.au/index.php?id=103" target="_blank"></a>
                    </div>
                    <div class="sp-logo">
                            <a class="ps" title="Powered by SportingPulse" alt="Powered by SportingPulse" href="http://www.sportingpulse.com/" target="_top"></a>
                    </div>
            </div>',
        },
        'realm' => {
            $REALM_RUGBY_LEAGUE => {
                 'subrealm' => {
                     $SUBREALM_DEFUALT => {
                        GlobalNav     => '&nbsp;',
                        Footer        => '&nbsp;',
                        Limit         => 15,
                        Brand         => "Play Rugby League",
                        Title         => 'Club Finder',
                        ExtraStyle    => 'playrugbyleague.css',
                        NoResults     => 'noresults_arld.templ',
                        #SearchResults => 'searchresults_rugby.templ',
                    },
                },
            },
            $REALM_AFL => {
                'subrealm' => {
                    $SUBREALM_DEFUALT => {
                        Limit         => 15,
                        Brand         => "FootyWeb",
                        Page          => 'page.templ',
                        DefaultHeader => 'sp_membership_web_lrg.png',
                        Title         => 'Club Finder',
                        NoResults     => 'noresults_afl.templ',
                    },
                    $SUBREALM_AFL9s => {
                        Limit         => 100,
                        Distance      => 1000,
                        Brand         => "AFL9s",
                        GlobalNav     => '<div></div>',
                        Page          => 'page.templ',
                        SearchResults => 'searchresults_afl9s.templ',
                        AlternatePage => 'page_alt.templ',
                        AlternateSearchResults =>'searchresults_afl9s_alt.templ',
                        DefaultCopyright => '<div></div>',
                        ExtraStyle       => 'afl9s.css',
                        Title            => 'Venue Finder',
                        NoResults        => 'noresults_afl9s.templ',
                        Footer           => '<div></div>',
                    },
                },
            },
            $REALM_FIBA => {
                'subrealm' => {
                    $SUBREALM_BA => {
                        Limit         => 15,
                        Brand         => "Basketball Australia",
                        GlobalNav     => '<div></div>',
                        DefaultCopyright => '<div></div>',
                        ExtraStyle       => 'ba.css',
                        Title            => 'Venue Finder',
                        Footer           => '<div></div>',
                    },
                },
            },

            $REALM_HOCKEY => {
                'subrealm' => {
                    $SUBREALM_DEFUALT => {
                        Limit         => 10,
                        Brand         => "Hockey",
                        DefaultHeader => 'sp_membership_web_lrg.png',
                        Title         => 'Hockey Club Finder',
                    },
                },
            },

            $REALM_SOCCER => {
                'subrealm' => {
                    $SUBREALM_DEFUALT => {
                        Brand => "MyFootballClub",
                        Limit => 15,
                        Title => 'Club Finder',
                        ClubCharacteristicsTemplate =>'clubcharacteristics_ffa.templ',
                        ExtraStyle    => 'myfootballclub.css',
                        GlobalNav     => '&nbsp;',
                        Footer        => '&nbsp;',
                        SearchResults => 'searchresults_soccer.templ',
                    },
                },
            },
            $REALM_WATER_POLO => {
                'subrealm' => {
                    $SUBREALM_DEFUALT => {
                        Brand         => "Water Polo",
                        Title         => "Water Polo Club Finder",
                        DefaultHeader => 'wpaheader.jpg',
                        NoResults     => 'noresults_polo.templ',
                    },
                },
            },
            $REALM_PRIVATE => {
                'subrealm' => {
                    $SUBREALM_ARU => {
                        Brand         => "Austrailian Rugby Union",
                        Title         => "Austrailian Rugby Union Club Finder",
                        DefaultHeader => 'aru-header.png',
                        SearchResults => 'searchresults_aru.templ',
                    },
                },
            },
        },
    },
    $CONFIG_TYPE_PROGRAM => {
        'default' => {
            Limit    => 15,
            Distance => 100,
            Brand    => 'Aussie Hoops Program Finder',
            Title    => 'Program Finder',
            Error    => 'error.templ',
            GlobalNav => '',
            Page                   => 'aussiehoops-page.templ',
            NoResults              => 'noresults_program_default.templ',
            SearchResults          => 'aussiehoops-searchresults.templ',
            AlternatePage          => '',
            AlternateSearchResults => '',
            DefaultHeader          => 'sp_membership_web_lrg.png',
            DefaultCopyright       => '&copy;&nbsp; Copyright FOX SPORTS PULSE Pty Ltd & SportingPulse International Pty Ltd &nbsp;2014.&nbsp; All rights reserved.',
            AdvancedSearch              => 'advanced_program_search.templ',
            ClubCharacteristicsTemplate => '',
            ExtraStyle    => 'aussiehoops.css',
            ShowDays                    => 1,
            Footer                      => '',
        },
        'realm' => {},
    },
);

sub getMapFinderDefs {
    my $params        = shift;
    my $MapFinderDefs = {};

    my ( $realmID, $subrealmID, $type ) = @{$params}{qw/ realmID subrealmID type/};

    $subrealmID ||= $SUBREALM_DEFUALT;
    $type       ||= $TYPE_CLUB;

    my $config_type = $TYPE_MAP{$type};

    # Work out what defs we really want
    if ( defined $Settings{$config_type}{'realm'}{$realmID} ) {
        # ok so we have the realm, but what about the subrealm?
        if ( defined $Settings{$config_type}{'realm'}{$realmID}{'subrealm'}{$subrealmID} ){
            $MapFinderDefs = $Settings{$config_type}{'realm'}{$realmID}{'subrealm'}{$subrealmID};
        }
        else {
            # ok just use the default then
            $MapFinderDefs = $Settings{$config_type}{'realm'}{$realmID}{'subrealm'}{$SUBREALM_DEFUALT};
        }
    }

    # fill in the defaults if not set
    foreach my $key ( %{ $Settings{$config_type}{'default'} } ) {
        $MapFinderDefs->{$key} ||= $Settings{$config_type}{'default'}{$key};
    }
    $MapFinderDefs->{'directory'} = $TEMPLATES_FOLDER;
    $MapFinderDefs->{'target'}    = $TARGET_FILE;

    return $MapFinderDefs;
}

1;
