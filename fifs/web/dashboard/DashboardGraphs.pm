#
# $Header: svn://svn/SWM/trunk/web/dashboard/DashboardGraphs.pm 10399 2014-01-09 07:00:02Z sliu $
#

package DashboardGraphs;

require Exporter;
@ISA       = qw(Exporter);
@EXPORT    = qw(outputGraph);
@EXPORT_OK = qw(outputGraph);

use strict;
use CGI qw(param);

use lib '.', "..", "../..";
use Reg_common;
use Defs;
use Utils;
use DashboardGraphData;
use JSON;
use Date::Calc qw(Delta_Days);
use Date::Simple();
use Log;
use Data::Dumper;

sub _getGraphConfig {
    my ( $Data, $client, $graph, ) = @_;

    my $historical_line_graph_config_ajax = q[
        dataRenderer: ajaxDataRenderer,
        highlighter: {
          show: true
        },
        cursor: {
          show: false
        },
                grid: {
                    backgroundColor: '#ECECEC'
                },
        axes:{
          xaxis:{
            renderer:jQuery.jqplot.DateAxisRenderer,
                        XXX-TICKINT-XXX
                        XXX-MINVAL-XXX
                        XXX-MAXVAL-XXX
            tickOptions:{
              formatString:'%b&nbsp;%y'
            }
          }
        }
    ];
    my $historical_line_graph_config = q[
        highlighter: {
          show: true
        },
        cursor: {
          show: false
        },
        grid: {
            backgroundColor: '#ECECEC'
                },
        axes:{
          xaxis:{
            renderer:jQuery.jqplot.DateAxisRenderer,
                        XXX-TICKINT-XXX
                        XXX-MINVAL-XXX
                        XXX-MAXVAL-XXX
            tickOptions:{
              formatString:'%b&nbsp;%y'
            }
          }
        },
                legend : { 
                    show: XXXSHOWLEGENDXXX,
                    location: 'e',
                    placement:'outside'
                }
    ];
    my $pie_graph_config = q~
            highlighter: {
        show:true,
        sizeAdjust: 10,
        tooltipLocation: 'n',
        tooltipAxes: 'pieref',
        tooltipAxisX: 60,
        tooltipAxisY: 90,
                tooltipFormatString : '%s',
        useAxesFormatters: false
            },
            grid: {
        backgroundColor: '#FFFFFF',
                drawBorder: false,
          shadow: false
            },
            seriesDefaults: {
        // Make this a pie chart.
        renderer: jQuery.jqplot.PieRenderer,
        rendererOptions: {
                    padding: 4,
          // Put data labels on the pie slices.
          // By default, labels show the percentage of the slice.
          showDataLabels: true
        }
      },
            legend : { 
                show: XXXSHOWLEGENDXXX,
                location: 'e',
                placement:'outside'
            }
    ~;

    my %graphs = (
        member_historical => {
            name => $Data->{'LevelNames'}{ $Defs::LEVEL_PERSON . "_P" },
        },
        player_historical => {
            name => 'Players',
        },
        coach_historical => {
            name => 'Coaches',
        },
        umpire_historical => {
            name => 'Umpires',
        },
        other1_historical => {
            name => 'Other 1',
        },
        other2_historical => {
            name => 'Other 2',
        },
        newmembers_historical => {
            name => 'New '
              . $Data->{'LevelNames'}{ $Defs::LEVEL_PERSON . "_P" },
        },
        regoformembers_historical => {
            name => $Data->{'LevelNames'}{ $Defs::LEVEL_PERSON . "_P" }
              . ' registered via forms',
        },
        permitmembers_historical => {
            name => $Data->{'LevelNames'}{ $Defs::LEVEL_PERSON . "_P" }
              . ' on Permit',
        },
        clrin_historical => {
            name => 'Clearances In',
        },
        clrout_historical => {
            name => 'Clearances Out',
        },
        permin_historical => {
            name => 'Permitted In',
        },
        permout_historical => {
            name => 'Permitted Out',
        },
        txns_historical => {
            name => 'Number of Transactions',
        },
        txnval_historical => {
            name => 'Transaction Value',
        },
        trib_historical => {
            name => 'Tribunal',
        },
        playeragegroups_historical => {
            name => 'Players by Age Group',
        },
        playergender_historical => {
            name => 'Players by Gender',
        },
        playergenders => {
            name        => 'Players by Gender',
            graphconfig => $pie_graph_config,
        },
        playerages => {
            name        => 'Players by Ages',
            graphconfig => $pie_graph_config,
        },
        payment_historical => {
            name        => 'Online Payment',
            graphconfig => $pie_graph_config,
        },
    );
    my %base_graph_data = (
        dataurl     => "dashboard/ajax/aj_graphdata.cgi?client=$client",
        graphconfig => $historical_line_graph_config,
        includes    => [
            'js/jqplot/excanvas.js',
            'js/jqplot/jquery.jqplot.min.js',
            'js/jqplot/plugins/jqplot.dateAxisRenderer.min.js',
            'js/jqplot/plugins/jqplot.pieRenderer.min.js',
            'js/jqplot/plugins/jqplot.highlighter.js',
            'js/jqplot/plugins/jqplot.cursor.min.js',
            'js/jqplot/plugins/jqplot.enhancedLegendRenderer.min.js',
            'js/jqplot/jquery.jqplot.min.css',
            _jqplot_ajax_renderer(),
        ],
    );

    for my $g ( keys %graphs ) {
        for my $bg ( keys %base_graph_data ) {
            if ( !exists $graphs{$g}{$bg} ) {
                $graphs{$g}{$bg} = $base_graph_data{$bg};
            }
        }
    }

    return $graphs{$graph} if $graph;
    return \%graphs;
}

sub _jqplot_ajax_renderer {
    return q~
  var ajaxDataRenderer = function(url, plot, options) {
    var ret = null;
    jQuery.ajax({
      // have to use synchronous here, else the function
      // will return before the data is fetched
      async: false,
      url: url,
      dataType:"json",
            data: options,
      success: function(data) {
                if(!data.results)    {
                    ret = [[null]];
                }
                else    {
                    ret = data.data;
                }
      }
    });
        plot.axes.xaxis.min = ret[0][0][0];
        plot.axes.xaxis.max = ret[0][ret[0].length -1 ][0];
    return ret;
  };
    ~;
}

sub outputGraph {
    my ( $Data, $client, $graphtype, $fullscreen, ) = @_;

    my $graphconfig = _getGraphConfig( $Data, $client, $graphtype, );
    $fullscreen ||= '';
    DEBUG "$graphtype GraphConfig:", Dumper($graphconfig);

    if ( $graphconfig->{'includes'} ) {
        for my $i ( @{ $graphconfig->{'includes'} } ) {
            if ( $i =~ /\.js/ ) {
                $Data->{'AddToPage'}->add( 'js_bottom', 'file', $i );
            }
            elsif ( $i =~ /\.css/ ) {
                $Data->{'AddToPage'}->add( 'css', 'file', $i );
            }
            else {
                $Data->{'AddToPage'}->add( 'js_bottom', 'inline', $i );
            }
        }
    }
    my $title = $graphconfig->{'title'} || '';
    $title =~ s/'/\\'/g;
    my $gconfig = $graphconfig->{'graphconfig'} || '';
    my $url     = $graphconfig->{'dataurl'}     || '';
    $url .= "&amp;gt=$graphtype";
    my $graphdata = '';
    if ( $graphconfig->{'ajax'} ) {
        $graphdata = "'$url'";
    }
    else {
        my ( $gd, $series_names ) =
          getGraphData( $Data, $client, $graphtype, $fullscreen, );
        DEBUG "$graphtype Data: ", Dumper($gd);
        $gd = [[]] and ERROR "graphic data of $graphtype is NULL" if not defined $gd;
        $graphdata = to_json($gd);
        DEBUG "$graphtype JSON Data: ", Dumper($graphdata);

		#set some values so the page doesnt crash if we have no graph values yet.
        	$graphdata = qq~[[["2012-05-01",0]]]~
        	  if ( $graphdata eq qq~[[]]~ or $graphdata eq qq~[]~ or $graphdata eq qq~[null]~);
		$gd->[0][0][0] = "2012-05-01" if(!$gd->[0][0][0]); 
		$gd->[0][0][0] = "2012-11-01" if(!$gd->[0][$#{$gd->[0]}][0]); 

        $gconfig =~ s/XXX-MINVAL-XXX/min: '$gd->[0][0][0]',/;  #|| '2012-05-01';
        $gconfig =~ s/XXX-MAXVAL-XXX/max: '$gd->[0][$#{$gd->[0]}][0]',/
          ;    # || '2012-05-01';
        if (    $graphconfig->{'graphconfig'} =~ /XXX-TICKINT-XXX/
            and $gd->[0][0][0]
            and $gd->[0][ $#{ $gd->[0] } ][0] )
        {
            my @datefrom = split( '-', $gd->[0][0][0] );
            my @dateto   = split( '-', $gd->[0][ $#{ $gd->[0] } ][0] );
            $dateto[0]   += 1900;
            $datefrom[0] += 1900;
            if (    Date::Simple->new( join( '-', @datefrom ) )
                and Date::Simple->new( join( '-', @dateto ) ) )
            {
                my $days = Delta_Days( @datefrom, @dateto );
                $days = sprintf( "%.0f", $days / 30.5 / 3 ) || 1;
                $gconfig =~ s/XXX-TICKINT-XXX/tickInterval: '$days months',/;
            }
        }

        my $series = '';
        for my $sn ( @{$series_names} ) {
            $series .= ',' if $series;
            $series .= "{label: '$sn'}";
        }
        if ( $fullscreen and ( $series or $gconfig =~ /PieRenderer/ ) ) {
            $gconfig .= qq~
                ,series: [ $series ]
            ~;
            $gconfig =~ s/XXXSHOWLEGENDXXX/true/g;
        }
        else {
            $gconfig =~ s/XXXSHOWLEGENDXXX/false/g;
        }
    }
    $gconfig =~ s/XXX.*?XXX//g;
    my $fullscreen_class = $fullscreen ? '_full' : '';
    my $fullscreen_link = '';
    if ( !$fullscreen ) {
        $fullscreen_link =
"dialogform('graph_full.cgi?client=$client&amp;g=$graphtype','$graphconfig->{'name'}', 1000, 600);";
    }
    my $output = qq[
        <div id = "graph_wrap_$graphtype$fullscreen_class" class = "dash_graph_widget$fullscreen_class" style = "float:left;">
    ];
    if ( !$fullscreen ) {
        $output .= qq[
                <div class="graph-heading">$graphconfig->{'name'}</div>
        ];
    }
    my $newfullscreen_class = $fullscreen ? '_full' : 'widget';
    my $graphstr = '';
    $graphstr = qq[
                <div id = "graph_$graphtype$newfullscreen_class" class = "dash_graph_canvas$fullscreen_class"></div>
    ];
    if ( !$fullscreen ) {
        $graphstr =
qq[ <a href = "#" onclick = "$fullscreen_link;return false;">$graphstr </a> ];
    }
    $output .= qq[
        $graphstr
        </div>
    ];
    my $graphjs = qq[
                        graph_$graphtype = jQuery.jqplot('graph_$graphtype$newfullscreen_class', $graphdata, {
                        $gconfig
                    });
    ];
    $Data->{'AddToPage'}->add( 'js_bottom', 'inline', $graphjs );

    return $output;

}

#Done ----

#-- Line or Bar graphs
#Members - historical
#Players - historical
#Coaches - historical
#Umpires - historical
#Other1 - historical
#Other2 - historical
#new Regos - historical

#
#Comps - historical
#Teams - historical
#Age Groups - historical
#Gender - historical
#Clearances In and Out - historical
#Permit In and Out - historical
#Num Transactions - historical
#Transaction Value - historical
#
#Pie
#
#Gender - current Month
#Age Groups - current Month
#New or Rereg
#

sub getRolling12Months {
    my ($previousyears) = @_;
    $previousyears ||= 0;

    my @values       = ( localtime() )[ 0 .. 5 ];
    my $current_year = $values[5] + 1900;
    $current_year -= $previousyears if $previousyears;
    my $current_month = $values[4] + 1;

    my @months = ();
    my $m      = $current_month;
    my $y      = $current_year;
    for my $i ( 1 .. 12 ) {
        push @months, [ $m, $y ];
        $m--;
        $y--;
        if ( $m < 1 ) {
            $m = 12;
            $y--;
        }
    }
    return \@months;
}

1;
