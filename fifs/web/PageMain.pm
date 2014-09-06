package PageMain;

require Exporter;
@ISA =  qw(Exporter);
@EXPORT = qw(pageMain printReport pageForm regoPageForm printBasePage ccPageForm getHomeClient getPageCustomization);
@EXPORT_OK = qw(pageMain printReport pageForm regoPageForm printBasePage ccPageForm getHomeClient getPageCustomization);

use strict;
use DBI;

use lib '.', '..';
use Reg_common;
use Defs;
use Utils;
use CGI;
use AddToPage;
use TTTemplate;
use Log;
use Data::Dumper;

sub ccPageForm  {
    my($title, $body, $clientValues_ref,$client, $Data) = @_;
    $title ||= '';
    $body ||= textMessage("Oops !<br> This shouldn't be happening!<br> Please contact <a href=\"mailto:info\@sportingpulse.com\">info\@sportingpulse.com</a>");

    if($Data->{'WriteCookies'}) {
        my $cookies_string = '';
        my @cookie_array = ();
        my $output = new CGI;
        for my $i (@{$Data->{'WriteCookies'}}) {
                push @cookie_array, $output->cookie(
                        -name=>$i->[0],
                        -value=>$i->[1],
                        -domain=>$Defs::cookie_domain,
                        -secure=>0,
                        -expires=> $i->[2] || '',
                        -path=>"/"
                );
                $cookies_string = join(',', @cookie_array);
        }

        print $output->header(-cookie=>[$cookies_string]); # -charset=>'UTF-8');
    } else {
        print "Content-type: text/html\n\n";
    }

    my ($html_head, $page_header, $page_navigator, $paypal, $powered) = getPageCustomization($Data);
                #Payments
    $paypal = qq[<div id="spfooter"> <img width="870" height="55" border="0" src="images/payment_footer.jpg"> </div>];

    my $meta = {};
    $meta->{'title'} = $title;
    $meta->{'head'} = qq[
        <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1">
        <meta http-equiv="Content-Type" content="text/html; charset=UTF-8" />
                $html_head
        <script type="text/javascript" src="//ajax.aspnetcdn.com/ajax/jquery.validate/1.8.1/jquery.validate.min.js"></script>
        
        <script type="text/javascript">
            jQuery().ready(function () {
                // validate the comment form when it is submitted
                jQuery("#cc-form").validate({
                    rules: {
                        EPS_CCV: "required",
                        EPS_CARDTYPE: "required",
                        EPS_EXPIRYMONTH: "required",
                        EPS_EXPIRYYEAR: "required",
                        EPS_CARDNUMBER: {
                            required: true,
                            creditcard: true
                        }
                    },
                    messages: {
                        EPS_CARDTYPE: {
                            required: "Card Type required"
                        },
                        EPS_CCV: {
                            required: "CCV required"
                        },
                        EPS_EXPIRYMONTH: {
                            required: ""
                        },
                        EPS_EXPIRYYEAR: {
                            required: "Expiry required"
                        },
                        EPS_CARDNUMBER: {
                            required: "Credit Card Number required",
                            minlength: "Your credit card number must be 16 digits",
                            maxlength: "Your credit card number must be 16 digits",
                            number: "Your credit card number must be digits only"
                        }
                    },
                    submitHandler: function (form) {
                        jQuery("#cc-form").hide();
                        jQuery(".spinner-wrap").show();
                        form.submit();
                    }
                });
            });
        </script>
    ];
    $meta->{'page_begin'} = qq[
    ];
    $meta->{'page_header'} = $page_header;
    $meta->{'page_content'} = $body;
    $meta->{'page_footer'} = qq [
        $powered
    ];

    print runTemplate($Data, $meta, 'main.templ');
}

sub pageMain {
    my(
        $title, 
        $navbar, 
        $body, 
        $clientValues_ref,
        $client, 
        $Data
    ) = @_;

    $title ||= '';
    $navbar||='';
    $body ||= textMessage($Data->{'lang'}->txt('NO_BODY'));


    $Data->{'AddToPage'} ||= new AddToPage;
    if($Data->{'SystemConfig'}{'HeaderBG'})    {
        $Data->{'AddToPage'}->add( 
            'css',
            'inline',
            $Data->{'SystemConfig'}{'HeaderBG'},
        );
    }
    $Data->{'TagManager'}=''; #getTagManager($Data);
    $Data->{'AddToPage'}->add(
    'js_bottom',
    'inline',
    $Data->{'TagManager'},
    );
    $Data->{'AddToPage'}->add(
        'js_bottom',
        'inline',
        'jQuery(".chzn-select").chosen({ disable_search_threshold: 5 });',
    );

    my $search_js = qq[
    jQuery.widget( "custom.catcomplete", jQuery.ui.autocomplete, {
        _renderMenu: function( ul, items ) {
            var self = this,
                currentCategory = "";
            var lastnumnotshown = 0;
            jQuery.each( items, function( index, item ) {
                if ( item.category != currentCategory ) {
                    if(lastnumnotshown)    {
                        ul.append( "<li class='ui-autocomplete-notshown'>" + lastnumnotshown + " items not shown</li>" );
                    }
                    ul.append( "<li class='ui-autocomplete-category'>" + item.category + "</li>" );
                    currentCategory = item.category;
                }
                lastnumnotshown = item.numnotshown;
                self._renderItem( ul, item );
            });
            if(lastnumnotshown)    {
                ul.append( "<li class='ui-autocomplete-notshown'>" + lastnumnotshown + " items not shown</li>" );
            }
        }
    });
        jQuery( "#search" ).catcomplete({
            delay: 0,
            source: 'ajax/aj_search.cgi?client=$client',
            position : {my : "right top", at : "right bottom"},
            select: function( event, ui ) {
                document.location = ui.item.link;
            }
        });

        jQuery("#fullscreen-btn").click(function() {
            SetCookie('SP_SWM_FULLSCREEN',].(!($Data->{'FullScreen'} || 0) || 0).qq[,30);
            document.location.reload();
        });
    ];
    $Data->{'AddToPage'}->add('js_bottom','file','js/jscookie.js');
    $Data->{'AddToPage'}->add(
        'js_bottom',
        'inline',
        $search_js,
    );

    
    my $helpURL=$Data->{'SystemConfig'}{'HELP'} 
        ? "$Data->{'target'}?client=$client&amp;a=HELP"
        : $Defs::helpurl;
    my $homeClient = getHomeClient($Data);
        
    my $statscounter = $Defs::NoStats ? '' : getStatsCounterCode();

  my $globalnav = runTemplate(
    $Data,
    {PassportLink => ''},
    'user/globalnav.templ',
  );

    $navbar = '' if $Data->{'ClearNavBar'};

    my %TemplateData = (
        HelpURL => $helpURL,
        NoSPLogo => $Data->{'SystemConfig'}{'NoSPLogo'} || 0,
        BlogURL => 'http://blog.sportingpulse.com',
        HomeURL => "$Data->{'target'}?client=$homeClient&amp;a=HOME",
        StatsCounter =>  $statscounter || '',
        Content => $body || '',
        Title => $title || '',
        MemListName => uc($Data->{'LevelNames'}{$Defs::LEVEL_PERSON.'_P'}) || $Data->{'lang'}->txt('PEOPLE'),
        ClubListName => uc($Data->{'LevelNames'}{$Defs::LEVEL_CLUB.'_P'}) || $Data->{'lang'}->txt('CLUBS'),
        GlobalNav => $globalnav || '',
        Header => $Data->{'SystemConfig'}{'Header'} || '',
        NavBar => $navbar || '',
        CSSFiles => $Data->{'AddToPage'}->get('css','file') || '',
        CSSInline => $Data->{'AddToPage'}->get('css','inline') || '',
        TopJSFiles => $Data->{'AddToPage'}->get('js_top','file') || '',
        TopJSInline => $Data->{'AddToPage'}->get('js_top','inline') || '',
        BottomJSFiles => $Data->{'AddToPage'}->get('js_bottom','file') || '',
        BottomJSInline => $Data->{'AddToPage'}->get('js_bottom','inline') || '',
        FullScreen => $Data->{'FullScreen'} || 0,
    );

    my $authLevel = $clientValues_ref->{'authLevel'} || 0;
    #if($authLevel == $Defs::LEVEL_ASSOC)    {
        #$TemplateData{'MemListURL'} = "$Data->{'target'}?client=$homeClient&amp;a=M_L&amp;l=1";
        #$TemplateData{'CompListURL'} = "$Data->{'target'}?client=$homeClient&amp;a=CO_L&amp;l=4" if(!$Data->{'SystemConfig'}{'NoComps'});
        #$TemplateData{'ClubListURL'} = "$Data->{'target'}?client=$homeClient&amp;a=C_L&amp;l=3" if($Data->{'Permissions'}{'OtherOptions'}{'ShowClubs'} or !$Data->{'SystemConfig'}{'NoClubs'});
        #$TemplateData{'TeamListURL'} = "$Data->{'target'}?client=$homeClient&amp;a=T_L&amp;l=2" if(!$Data->{'SystemConfig'}{'NoTeams'});
    #}
    if($authLevel == $Defs::LEVEL_CLUB)    {
        $TemplateData{'MemListURL'} = "$Data->{'target'}?client=$homeClient&amp;a=M_L&amp;l=1";
        $TemplateData{'TeamListURL'} = "$Data->{'target'}?client=$homeClient&amp;a=T_L&amp;l=2" if(!$Data->{'SystemConfig'}{'NoTeams'});
    }

    my $templateFile = 'page_wrapper/main_wrapper.templ';
    my $page = runTemplate(
        $Data, 
        \%TemplateData, 
        $templateFile
    );
    my $header = '';
    my $output = new CGI;
    if($Data->{'WriteCookies'})    {
warn("IN WRITE");
        my $cookies_string = '';
        my @cookie_array = ();
        for my $i (@{$Data->{'WriteCookies'}})    {
            push @cookie_array, $output->cookie(
                -name=>$i->[0], 
                -value=>$i->[1], 
                -domain=>$Defs::cookie_domain, 
                -secure=>0, 
                -expires=> $i->[2] || '',
                -path=>"/"
            );
            $cookies_string = join(',', @cookie_array);
        }
        my $p3p=q[policyref="/w3c/p3p.xml", CP="ALL DSP COR CURa ADMa DEVa TAIi PSAa PSDa IVAi IVDi CONi OTPi OUR BUS IND PHY ONL UNI COM NAV DEM STA"];

        if($Data->{'RedirectTo'})   {
            $header = $output->redirect (-uri => $Data->{'RedirectTo'},-cookie=>[$cookies_string], -P3P => $p3p);
        }
        else    {
            $header = $output->header(-cookie=>[$cookies_string], -P3P => $p3p, -charset=>'UTF-8');
        }
    }
    elsif($Data->{'RedirectTo'})    {
        $header = $output->redirect ($Data->{'RedirectTo'});
    }
    else    {
        $header = "Content-type: text/html\n\n";
    }
    print $header;
    print $page;
}

sub printReport    {

    my($body, $lang) = @_;

        my $title=$lang->txt('Reports');
    print qq[Content-type: text/html\n\n];
    print qq[
  <html>
    <head>
        <meta http-equiv="Content-Type" content="text/html; charset=UTF-8" />
      <title>$title</title>
            <link rel="stylesheet" type="text/css" href="$Defs::base_url/css/style.css">
    </head>
    <body class="report">
      $body
    </body>
  </html>
    ];
}

sub printBasePage {

    my($body, $title, $Data) = @_;

    print qq[Content-type: text/html\n\n];
    $Data->{'AddToPage'} ||= new AddToPage;
    my $CSSFiles = $Data->{'AddToPage'}->get('css','file') || '';
    my $CSSInline = $Data->{'AddToPage'}->get('css','inline') || '';
    my $TopJSFiles = $Data->{'AddToPage'}->get('js_top','file') || '';
    my $TopJSInline = $Data->{'AddToPage'}->get('js_top','inline') || '';
    my $BottomJSFiles = $Data->{'AddToPage'}->get('js_bottom','file') || '';
    my $BottomJSInline = $Data->{'AddToPage'}->get('js_bottom','inline') || '';
  print qq[
  <html>
    <head>
        <meta http-equiv="Content-Type" content="text/html; charset=UTF-8" />
      <title>$title</title>
            <script type="text/javascript" src="https://ajax.googleapis.com/ajax/libs/jquery/1.7.2/jquery.min.js"></script>
            <script type="text/javascript" src="https://ajax.googleapis.com/ajax/libs/jqueryui/1.8.21/jquery-ui.min.js"></script>
            <link rel="stylesheet" type="text/css" href="js/jquery-ui/css/theme/jquery-ui-1.8.22.custom.css">
            <script type="text/javascript" src="$Defs::base_url/js/jquery.ui.touch-punch.min.js"></script>
      <link rel="stylesheet" type="text/css" href="$Defs::base_url/css/style.css">
$CSSFiles
$CSSInline
$TopJSFiles
$TopJSInline
    </head>
    <body style = " background:none;">
      $body
$BottomJSFiles
$BottomJSInline
    </body>
  </html>
    ];
}


sub pageForm    {
    my($title, $body, $clientValues_ref,$client, $Data) = @_;
    $title ||= '';
    $body||= textMessage("Oops !<br> This shouldn't be happening!<br> Please contact <a href=\"mailto:info\@sportingpulse.com\">info\@sportingpulse.com</a>");

 $Data->{'TagManager'}='';#getTagManager($Data);
warn(" IN PF");

    my ($html_head, $page_header, $page_navigator, $paypal, $powered) = getPageCustomization($Data);
    my $meta = {};
    $meta->{'title'} = $title;
    $meta->{'head'} = $html_head;
    $meta->{'page_begin'} = qq[
        <div id="global-nav-wrap">
        $page_navigator
        </div>
    ];
    $meta->{'page_header'} = $page_header;
    $meta->{'page_content'} = $body;
    $meta->{'page_footer'} = qq [
        $paypal
        $powered
    ];
    $meta->{'page_end'} = qq [
        <script type="text/javascript">
        $Data->{'TagManager'}
        </script>
    ];

    my $output = new CGI;
    my $header = '';
    if($Data->{'WriteCookies'})    {
warn("### IN WRITE COOKIES#");
        my $cookies_string = '';
        my @cookie_array = ();
        for my $i (@{$Data->{'WriteCookies'}})    {
warn("EXPIRES $i->[2]");
            push @cookie_array, $output->cookie(
                -name=>$i->[0],
                -value=>$i->[1],
                -domain=>$Defs::cookie_domain,
                -secure=>0,
                -expires=> $i->[2] || '',
                -path=>"/"
            );
            $cookies_string = join(',', @cookie_array);
        }
        my $p3p=q[policyref="/w3c/p3p.xml", CP="ALL DSP COR CURa ADMa DEVa TAIi PSAa PSDa IVAi IVDi CONi OTPi OUR BUS IND PHY ONL UNI COM NAV DEM STA"];

        if($Data->{'RedirectTo'})   {
            $header = $output->redirect (-uri => $Data->{'RedirectTo'},-cookie=>[$cookies_string], -P3P => $p3p);
        }
        else    {
            $header = $output->header(-cookie=>[$cookies_string], -P3P => $p3p, -charset=>'UTF-8');
        }
    }
    elsif($Data->{'RedirectTo'})    {
        $header = $output->redirect ($Data->{'RedirectTo'});
    }
    else    {
        $header = "Content-type: text/html\n\n";
    }
    print $header;
    print runTemplate($Data, $meta, 'main.templ');
}

sub regoPageForm {
    my($title, $body, $clientValues_ref,$client, $Data) = @_;
    $title ||= '';
    $body||= textMessage("Oops !<br> This shouldn't be happening!<br> Please contact <a href=\"mailto:info\@sportingpulse.com\">info\@sportingpulse.com</a>");
    $Data->{'TagManager'}=''; #getTagManager($Data);

    if($Data->{'WriteCookies'}) {
        my $cookies_string = '';
        my @cookie_array = ();
        my $output = new CGI;
        for my $i (@{$Data->{'WriteCookies'}}) {
            push @cookie_array, $output->cookie(
                -name=>$i->[0], 
                -value=>$i->[1], 
                -domain=>$Defs::cookie_domain, 
                -secure=>0, 
                -expires=> $i->[2] || '',
                -path=>"/"
            );
            $cookies_string = join(',', @cookie_array);
        }

        print $output->header(-cookie=>[$cookies_string]); # -charset=>'UTF-8');
    } else {
        print "Content-type: text/html\n\n";
    }

    my ($html_head, $page_header, $page_navigator, $paypal, $powered) = getPageCustomization($Data);
    my $meta = {};
    $meta->{'title'} = $title;
    $meta->{'head'} = $html_head;
    $meta->{'page_begin'} = qq[
        <div id="global-nav-wrap">
        $page_navigator
        </div>
    ];
    $meta->{'page_header'} = qq[
        <div> 
        $page_header 
        </div>
    ];

    $meta->{'page_content'} = $body;
    $meta->{'page_footer'} = qq [
        <div id="footer-links">
            $powered
        </div>
    ];
    $meta->{'page_end'} = qq [
        <script type="text/javascript">
        $Data->{'TagManager'}
        </script>
    ];

    print runTemplate($Data, $meta, 'regoform/main.templ');
    #New regoform wrapper not ready for public consumption, Regs 16/4/14
    #print runTemplate($Data, $meta, 'regoform/main_2014.templ');
}

sub getPageCustomization{
    my ($Data) = @_;

    my $nav = runTemplate( $Data, {PassportLink => ''}, 'user/globalnav.templ');

    my $html_head = $Data->{'HTMLHead'} || '';
    my $html_head_style = '';
    $html_head_style .= $Data->{'SystemConfig'}{'OtherStyle'} if $Data->{'SystemConfig'}{'OtherStyle'};
    $html_head_style .= $Data->{'SystemConfig'}{'HeaderBG'} if $Data->{'SystemConfig'}{'HeaderBG'};
    $html_head_style = qq[<style type="text/css">$html_head_style</style>] if $html_head_style;

    $html_head = qq[
        $html_head
        $html_head_style
    ];

    my $page_header = qq[<img src="$Defs::base_url/images/sp_membership_web_lrg.png" ></img>];
    $page_header = $Data->{'SystemConfig'}{'Header'} if $Data->{'SystemConfig'}{'Header'};
    $page_header = $Data->{'SystemConfig'}{'AssocConfig'}{'Header'} if $Data->{'SystemConfig'}{'AssocConfig'}{'Header'};

    my $paypal = $Data->{'PAYPAL'} ? qq[<img src="images/PP-CC.jpg" alt="PayPal" border="0"></img>] : '';

    my $powered = qq[<span class="footerline">].$Data->{'lang'}->txt('COPYRIGHT').qq[</span>];

    return ($html_head, $page_header, $nav, $paypal, $powered);
}

sub getHomeClient {

    my ($Data) = @_;


    my %clientValues=%{$Data->{'clientValues'}};
    $clientValues{'currentLevel'} = $clientValues{'authLevel'};
    $clientValues{'currentLevel'} = $clientValues{'authLevel'};

    {
        $clientValues{interID} =0;
        $clientValues{intregID} =0;
        $clientValues{intzonID} =0;
        $clientValues{natID} =0;
        $clientValues{stateID} =0;
        $clientValues{regionID} =0;
        $clientValues{zoneID} =0;
        $clientValues{clubID} =0;
        $clientValues{memberID} =0;
        $clientValues{eventID} =0;
    }
    if ($clientValues{'currentLevel'} == $Defs::LEVEL_INTERNATIONAL)    {
        $clientValues{interID} = $Data->{'clientValues'}{'interID'} || 0;
    }
    if ($clientValues{'currentLevel'} == $Defs::LEVEL_INTREGION)    {
        $clientValues{intregID} = $Data->{'clientValues'}{'intregID'} || 0;
    }
    if ($clientValues{'currentLevel'} == $Defs::LEVEL_INTZONE)    {
        $clientValues{intzonID} = $Data->{'clientValues'}{'intzonID'} || 0;
    }
    if ($clientValues{'currentLevel'} == $Defs::LEVEL_NATIONAL)    {
        $clientValues{natID} = $Data->{'clientValues'}{'natID'} || 0;
    }
    if ($clientValues{'currentLevel'} == $Defs::LEVEL_STATE)    {
        $clientValues{stateID} = $Data->{'clientValues'}{'stateID'} || 0;
    }
    if ($clientValues{'currentLevel'} == $Defs::LEVEL_REGION)    {
        $clientValues{regionID} = $Data->{'clientValues'}{'regionID'} || 0;
    }
    if ($clientValues{'currentLevel'} == $Defs::LEVEL_ZONE)    {
        $clientValues{zoneID} = $Data->{'clientValues'}{'zoneID'} || 0;
    }
    if ($clientValues{'currentLevel'} == $Defs::LEVEL_CLUB)    {
        $clientValues{assocID} = $Data->{'clientValues'}{'assocID'} || 0;
        $clientValues{clubID} = $Data->{'clientValues'}{'clubID'} || 0;
    }
    my $client = setClient(\%clientValues);
    return $client; 
}

sub getStatsCounterCode {
    return q[
<!-- START Nielsen//NetRatings SiteCensus V5.1 -->
<!-- COPYRIGHT 2005 Nielsen//NetRatings -->
<script language="JavaScript" type="text/javascript">
<!--
        var _rsCI="sportingpulse";
        var _rsCG="sportzmembership";
        var _rsDT=0;
        var _rsDU=0;
        var _rsDO=1;
        var _rsX6=0;
        var _rsSI=escape(window.location);
        var _rsLP=location.protocol.indexOf('https')>-1?'https:':'http:';
        var _rsRP=escape(document.referrer);
        var _rsND=_rsLP+'//secure-au.imrworldwide.com/';

        if (parseInt(navigator.appVersion)>=4)
        {
                var _rsRD=(new Date()).getTime();
                var _rsSE=0;
                var _rsSV="";
                var _rsSM=0;
                _rsCL='<scr'+'ipt language="JavaScript" type="text/javascript" src="'+_rsND+'v51.js"></scr'+'ipt>';
        }
        else
        {
                _rsCL='<img src="'+_rsND+'cgi-bin/m?ci='+_rsCI+'&cg='+_rsCG+'&si='+_rsSI+'&rp='+_rsRP+'">';
        }
        document.write(_rsCL);
//-->
</script>
<noscript>
        <img src="//secure-au.imrworldwide.com/cgi-bin/m?ci=sportingpulse&amp;cg=0" alt="">
</noscript>
<!-- END Nielsen//NetRatings SiteCensus V5.1 -->
    ];    
}

1;
