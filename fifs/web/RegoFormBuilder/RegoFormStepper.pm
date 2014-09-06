#
# $Header: svn://svn/SWM/trunk/web/RegoFormStepper.pm 8251 2013-04-08 09:00:53Z rlee $
#

package RegoFormStepper;

require Exporter;
@ISA = qw(Exporter);
@EXPORT = qw(regoform_navigation);
@EXPORT_OK = qw(regoform_navigation);

use strict;

use Reg_common;
use Defs;

sub regoform_navigation {
    my ($Data, $step_code, $form_id, $form_type, $editing) = @_;

    return if !$step_code;
    return if !defined $form_id;
    return if !$form_type;

    $editing ||= 0;
    my $adding = ($editing) ? 0 : 1;
    my $stepper_mode = ($editing) ? 'edit' : 'add';
    my $prod_actn = ($form_type == $Defs::REGOFORM_TYPE_TEAM_ASSOC) ? 'A_ORF_tp' : 'A_ORF_p';

    my %step_hoh = ();

    update_hash(\%step_hoh, 'sett', 1, 'Settings', 'A_ORF_re');
    update_hash(\%step_hoh, 'flds', 2, 'Fields', 'A_ORF_f');
    update_hash(\%step_hoh, 'lout', 3, 'Layout', 'A_ORF_o');
    update_hash(\%step_hoh, 'prod', 4, 'Products', $prod_actn);
    update_hash(\%step_hoh, 'mess', 5, 'Messages', 'A_ORF_t');
    update_hash(\%step_hoh, 'comp', 6, 'Competitions', 'A_ORF_tc') if ($form_type == $Defs::REGOFORM_TYPE_TEAM_ASSOC) and (allowedAction($Data, 'c_ca_a'));
    update_hash(\%step_hoh, 'noti', 7, 'Notifications', 'A_ORF_noti');

    return if !exists $step_hoh{$step_code};

    my @unsorted = keys %step_hoh;

    my @sorted = sort { $step_hoh{$a}{'stepno'} <=> $step_hoh{$b}{'stepno'} } @unsorted;

    my $step_js = '';

    if ($editing) {
        $step_js = qq[
            <script type="text/javascript">
                jQuery().ready(function() {
                    jQuery('.steps').mouseenter(function(){
                        if (!jQuery(this).hasClass('nav-currentstep'))
                            jQuery(this).removeClass('nav-completedstep').addClass('nav-mouseenter');
                    });
                    jQuery('.steps').mouseleave(function(){
                        if (!jQuery(this).hasClass('nav-currentstep'))
                            jQuery(this).removeClass('nav-mouseenter').addClass('nav-completedstep');
                    });
                });
            </script>
        ];
    }

    my $result_html = qq[
        <link rel="stylesheet" type="text/css" href="css/regoform_be.css">
        $step_js
        <ul class="form-nav">
    ];

    my $current_step_no = $step_hoh{$step_code}->{'stepno'};
	my $client = setClient($Data->{'clientValues'});
    for my $step(@sorted) {
        my $step_no = $step_hoh{$step}->{'stepno'};
        my $step_desc = $step_hoh{$step}->{'stepdesc'};
        my $step_actn = $step_hoh{$step}->{'stepactn'};
        my $step_class = 'nav-completedstep';
        $step_class = 'nav-currentstep' if $step_no == $current_step_no;
        $step_class = 'nav-futurestep' if ($adding) and ($step_no > $current_step_no);
        if ($adding or $step_no == $current_step_no) {
            $result_html .= qq[
               <li class="$step_class steps">
                   <span class="stepDesc">$step_desc</span>
               </li>
            ];
        }
        else {
            $result_html .= qq[
                <li class="$step_class steps">
                    <a href="$Data->{'target'}?client=$client&fID=$form_id&a=$step_actn&stepper=$stepper_mode"><span class="stepDesc">$step_desc</span></a>
                </li>
            ];
        }
    }

    $result_html .= qq[
        </ul>
        <div style="clear:both"></div>
    ];

    return $result_html;
}


sub update_hash {
    my ($step_hoh, $step_key, $step_no, $step_desc, $step_actn) = @_;
    $step_hoh->{$step_key} = {
       'stepno'   => $step_no,
       'stepdesc' => $step_desc,
       'stepactn' => $step_actn
    };
    return 1;
}


1;

