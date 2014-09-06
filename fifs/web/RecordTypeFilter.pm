package RecordTypeFilter;

## LAST EDITED -> 10/09/2007 ##

require Exporter;
@ISA =  qw(Exporter);
@EXPORT = qw(show_recordtypes);
@EXPORT_OK = qw(show_recordtypes);

use strict;
use CGI qw(param unescape escape);

use lib '.', "..";
use Defs;
use Reg_common;
require FieldLabels;
use Utils;
use FormHelpers;

use Data::Dumper;
use Log;

sub show_recordtypes	{
    my(
        $Data, 
        $textfilter_name,
        $statusname,
        $statusFilterValues,
        $allStatusValue,
    )=@_;

    my $lang = $Data->{'lang'};
    $statusname ||= '';
    $statusFilterValues ||= undef;
    $allStatusValue ||= undef;
    my $statusfilter='';
    if ($statusFilterValues) {
        my $cgi = new CGI;
        my @values = ();
        my %labels = ();
        for my $k (keys %{$statusFilterValues}) {
            push @values, $k;
            $labels{$k} = $lang->txt($statusFilterValues->{$k});
        }
        if($allStatusValue) {
            for my $k (keys %{$allStatusValue}) {
                push @values, $k;
                $labels{$k} = $lang->txt($allStatusValue->{$k});
            }
        }
        $statusfilter =  $statusname . $cgi->popup_menu(
            -name    => "actstatus",
            -id      => "dd_actstatus",
            -size    => 1,
            -style   => "font-size:10px;",
            -values  => \@values,
            -default => $Data->{'ViewActStatus'},
            -labels  => \%labels,
        );

        my $statuscookie=qq[
        jQuery("#dd_actstatus").change(function() {
                SetCookie('$Defs::COOKIE_ACTSTATUS',jQuery('#dd_actstatus').val(),30);
            });
        ];
        $Data->{'AddToPage'}->add('js_bottom','inline',$statuscookie);
    }
    my $record_type_filter = '';

    my $textfilter = '';
    if($textfilter_name)	{
        my $including = $lang->txt('including');
        $textfilter = qq[
        $textfilter_name  $including <input type = "text" value = "" name = "textfilterfield" id = "id_textfilterfield" size = "10">
        ];
    }

    my $Filter  = $lang->txt('Filter');

    my $form_text = join(
        ' ',
        $lang->txt('Showing'),
        ' - ',
        $textfilter,
        $statusfilter,
    );

    my $line=qq[
    <div class="showrecoptions">
    <form action="#" onsubmit="return false;" name="recoptions">
    $form_text
    </form>
    </div>
    ];
    $line = '' if (! $statusfilter and ! $textfilter );
    $Data->{'AddToPage'}->add('js_bottom','file','js/jscookie.js');

    DEBUG "show_recordtypes: $line";
    return $line;
}

1;
