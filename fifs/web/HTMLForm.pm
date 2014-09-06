package HTMLForm;

require Exporter;

#use SelfLoader;
@ISA    = qw(Exporter);
@EXPORT = qw(handleHTMLForm apply_case_rule _date_selection_box generate_clientside_validation);
@EXPORT_OK =
  qw(handleHTMLForm _date_selection_picker _date_selection_dropdown _time_selection_box apply_case_rule _date_selection_box generate_clientside_validation);

use lib '.', '..';

use strict;
use CGI qw(params);
use lib 'comp';

use Date::Calc;
use List::Util qw /min/;
use Utils;
use DBUtils;
use Data::Dumper;
use Log;

sub genHTMLForm {
    my ( $fields_ref, $permissions, $action, $notabs, $oldaction,
        $override_config )
      = @_;
    my $returnstr   = '';
    my $sectionlist = $fields_ref->{'sections'};
    $sectionlist = [ [ 'main', '' ] ] if !$sectionlist;
    $action ||= 'display';

    my $subbutact = 1;
    if ( defined $override_config ) {
        if ( exists $override_config->{'subbutact'} ) {
            $subbutact = $override_config->{'subbutact'};
        }
    }
    my $tabs           = '';
    my %sections       = ();
    my %sectioncount   = ();
    my $txt_compulsory = langlookup( $fields_ref, 'Compulsory Field' );
    my $compulsory =
qq[<span class="compulsory"><img src="images/compulsory.gif" alt="$txt_compulsory" title="$txt_compulsory"/></span>];
    my @fieldorder =
      (       defined $override_config
          and exists $override_config->{'order'}
          and $override_config->{'order'} )
      ? @{ $override_config->{'order'} }
      : @{ $fields_ref->{'order'} };
    my %clientside_validation = ();

    #DEBUG "generating HTML form for $action fields in order (@fieldorder)";

    my $scripts = '';

  FIELD: for my $fieldname (@fieldorder) {
        next if !$fieldname;
        my $f = $fields_ref->{'fields'}{$fieldname};
        next if !$f;
        my $type = $f->{'type'} || 'text';

        my $sname =
          (       defined $override_config
              and exists $override_config->{'sectionname'}
              and $override_config->{'sectionname'}{$fieldname} )
          ? $override_config->{'sectionname'}{$fieldname} || ''
          : ( $f->{'sectionname'} || 'main' );
        my $label =
          langlookup( $fields_ref, $f->{'label'} ) || $f->{'label'} || '';
        my $val        = defined $f->{'value'} ? $f->{'value'} : '';
        my $field_html = '';
        my $row_class = '';
        my $edit       = $action eq 'edit' ? 1 : 0;
        my $add        = $action eq 'add' ? 1 : 0;
        my $visible_for_add =
          exists $f->{'visible_for_add'} ? $f->{'visible_for_add'} : 1;
        my $visible_for_edit =
          exists $f->{'visible_for_edit'} ? $f->{'visible_for_edit'} : 1;

        next if $f->{'noadd'} and $add;

        #next if $f->{'noedit'} and $edit;
        next if $f->{'nodisplay'} and $action eq 'display';
        $f->{'readonly'} = 1 if ( $f->{'noedit'} and $edit );
        next if !$label;

        my $field_has_permission = ((
                not defined $permissions
                    or not scalar keys %$permissions
            )
                or (  defined $permissions
                    and $permissions->{$fieldname} )
                or ( defined $type and $type eq 'textblock' ) ? 1 : 0 );

        #DEBUG "\n\n\n", "-" x 20, " $fieldname ", "-" x 20;
        #DEBUG "$fieldname :: config:", Dumper($f);

        # check for skip condition
        if (   ( $edit and not $visible_for_edit )
            or ( $add and not $visible_for_add )
            or not $field_has_permission )
        {
         #   DEBUG "$fieldname :: skip field";
         #   DEBUG "    Condition - edit: $edit, visible: $visible_for_edit";
         #   DEBUG "    Condition - add: $add, visible: $visible_for_add";
         #   DEBUG "    Condition - has_permission: $field_has_permission";
         #   DEBUG "        permissions:", ( $permissions ? 'True' : 'False' );
         #   DEBUG "        permission key:",
         #     ( ( exists $permissions->{$fieldname} ) ? 'True' : 'False' );
         #   DEBUG "        permission value: $permissions->{$fieldname}"
         #     if exists $permissions->{$fieldname};

            next;
        }

        my $is_editable_field =
          ( $type eq 'hidden' or not $f->{'readonly'} or ($f->{'readonly'} and  $f->{'Save_readonly'})) ? 1 : 0;

        if ( ( $edit or $add ) and $is_editable_field ) {
            #DEBUG "$fieldname :: editable field";

            #(not scalar keys %$permissions)

            my $disabled =
              $f->{'disabled'} ? 'readonly class="HTdisabled"' : '';

            my $onChange = '';


            $scripts .= qq [ /* script for $fieldname */ \n$f->{'script'} ] if ($f->{'script'});

            if ( $type eq 'textblock' ) {
                $sections{$sname} .=
                  qq[ <tr><td colspan="2">$fieldname</td></tr> ];
                next FIELD;
            }
            if ( $type eq 'textvalue' ) {
                $sections{$sname} .= qq[ <tr><td colspan="2">$val</td></tr> ];
                next FIELD;
            }
            if ( $type eq 'header' ) {
                $sections{$sname} .= qq[ <tr><th colspan="2">$label</th></tr> ];
                next FIELD;
            }
            if ( $type eq 'htmlrow' ) {
                $sections{$sname} .= $val || '';
                next FIELD;
            }
            if ( $type eq 'htmlblock' ) {
                if ( $f->{'nolabelsuffix'} ) {
                    $sections{$sname} .=
                      qq[<tr><td>&nbsp;</td><td colspan="2">$val</td></tr>];
                    next FIELD;
                }
                $field_html = $val;
            }
            elsif ( $type eq 'hidden' ) {
                $field_html =
                  qq[<input type="hidden" name="d_$fieldname" value="$val"/>\n];

                if ( ( $f->{addonly} and $f->{display} ) ) {
                    $field_html .= $f->{display};
                }
            }
            elsif ( $type eq 'textarea' ) {
                $row_class = 'form-textarea';
                my $rows = $f->{'rows'} ? qq[ rows = "$f->{'rows'}" ] : '';
                my $cols = $f->{'cols'} ? qq[ cols = "$f->{'cols'}" ] : '';
                $val =~ s/<br>/\n/ig;
                $field_html =
qq[<textarea name="d_$fieldname" id="l_$fieldname" $rows $cols $disabled $onChange>$val</textarea>\n];
            }
            elsif ( $type eq 'text' || $type eq 'jumper' ) {
                $row_class = 'form-input-text';
                my $sz = $f->{'size'} ? qq[ size="$f->{'size'}" ] : '';
                my $ms =
                  $f->{'maxsize'} ? qq[ maxlength="$f->{'maxsize'}" ] : '';
                my $txt_format =
                  $f->{'format_txt'}
                  ? qq[ <span class="HTdateformat">$f->{'format_txt'}</span>]
                  : '';
                my $ph =
                  ( defined $f->{'placeholder'} )
                  ? qq[ placeholder="$f->{'placeholder'}" ]
                  : '';
                my $isReadonly = '';
                if ($f->{'Save_readonly'}){
                    $isReadonly = qq[ readonly = "readonly" ];
                }
                $field_html =
qq[<input type="text" name="d_$fieldname" value="$val" $isReadonly id="l_$fieldname" $sz $ms $ph $disabled $onChange / >$txt_format\n];
            }
            elsif ( $type eq 'checkbox' ) {
                $row_class = 'form-checkbox';
                if ( $val eq '' and $f->{default} ) {
                    $val = $f->{default};
                }
                my $checked = ( $val and $val == 1 ) ? ' checked ' : '';
                $field_html =
qq[<input class="nb" type="checkbox" name="d_$fieldname" value="1" id="l_$fieldname" $checked $disabled $onChange / >\n];
            }
            elsif ( $type eq 'lookup' ) {
                $row_class = 'form-select';
                my $otheroptions = '';
                $otheroptions = qq[style="width:$f->{'width'}"]
                  if ( exists $f->{'width'} and $f->{'width'} );
                $field_html = drop_down(
                    "$fieldname",      $f->{'options'},
                    $f->{'order'},       $f->{'value'},
                    $f->{'size'},        $f->{'multiple'},
                    $f->{'firstoption'}, $otheroptions,
                    $onChange,           $f->{'class'},
                    $f->{'disable'},
                );
            }
            elsif ( $type eq 'date' ) {
                $row_class = 'form-select';
                $val = '' if $val eq '00/00/00';
                $val = '' if $val eq '00/00/0000';
                $val = '' if $val eq '0000-00-00';
                $val ||= '';
                my $datetype = $f->{'datetype'} || '';
                if ( $datetype eq 'dropdown' ) {
                    $field_html =
                      _date_selection_dropdown( $fieldname, $val, $f,
                        $disabled, $fields_ref, $onChange );
                }
                else {
                    $field_html =
                      _date_selection_picker( $fieldname, $val, $f, $disabled,
                        $fields_ref, $onChange );
                }
            }
            elsif ( $type eq 'time' ) {
                $row_class = 'form-select';
                $field_html =
                  _time_selection_box( $fieldname, $val, $f, $disabled, 0,
                    $onChange );
            }
            elsif ( $type eq '_SPACE_' ) {
                $row_class = 'form-space';
                $field_html = '&nbsp;';
            }
            $field_html .= $compulsory
            if $f->{'compulsory'} and $type ne 'hidden';
            if ( ( $f->{'compulsory'} or $f->{'validate'} )
                and $type ne 'hidden' )
            {
                $clientside_validation{$fieldname}{'compulsory'} =
                  $f->{'compulsory'};
                $clientside_validation{$fieldname}{'validate'} =
                  $f->{'validate'};
            }
            $label = qq[<label for="l_$fieldname">$label</label>] if $label;
        }
        else {
           # DEBUG "$fieldname :: readonly field";
           # DEBUG "    Condition - add: $add, edit: $edit";
           # DEBUG "    Condition - is_editable_field: $is_editable_field";
           # DEBUG "        type: $type, readonly:", $f->{'readonly'};
           # DEBUG "$fieldname ::     value: $val";

            if ( $type eq 'lookup' ) {
                $field_html = $f->{'options'}{$val} || "&nbsp;";
           #     DEBUG "$fieldname ::     options: ", Dumper( $f->{'options'} );
            }
            elsif ( $f->{'displaylookup'} ) {
                $field_html =
                  langlookup( $fields_ref, $f->{'displaylookup'}{$val} );
           #     DEBUG "$fieldname ::     displaylookup: ",
                  Dumper( $f->{'displaylookup'} );
            }
            else {
                $val =~ s/\n/<br>/g;
                $val = '' if $val eq '00/00/00';
                $val = '' if $val eq '00/00/0000';
                $val = '' if $val eq '00/00/0000 00:00';
                $val = '' if $val eq '0000-00-00';
                $val = '' if $val eq '0000-00-00 00:00';
                $field_html = $val;
           #     DEBUG "$fieldname ::     filtered value: $val";
            }
        }

        #DEBUG "$fieldname :: generated html: \n$field_html";

        if (    $fields_ref->{'options'}
            and $fields_ref->{'options'}{'labelsuffix'} )
        {
            $label .= $fields_ref->{'options'}{'labelsuffix'}
              if $f->{'label'} and !$f->{'nolabelsuffix'};
        }
        $label ||= '&nbsp;';
        if (    $fields_ref->{'options'}
            and $fields_ref->{'options'}{'hideblank'}
            and !$f->{'neverHideBlank'} )
        {
            next if !$field_html;
        }
        my $pretext  = $f->{'pretext'}  || '';
        my $posttext = $f->{'posttext'} || '';
        my $compulsory_replace =
            $f->{'compulsory'}
          ? $compulsory
          : '';
        $pretext =~ s /XXXCOMPULSORYICONXXX/$compulsory_replace/g;
        $posttext =~ s /XXXCOMPULSORYICONXXX/$compulsory_replace/g;

        if ($f->{'compulsory'}) {
            $row_class = join(' ', $row_class, 'required');
        }

        if (
            $fields_ref->{'options'}{'verticalform'}
            or (    $fields_ref->{'options'}{'verticalformedit'}
                and $action ne 'display' )
          )
        {
            $sections{$sname} .= qq[
            <tr class="$row_class"><td class="label HTvertform-l" colspan="2">$label</td></tr>
            <tr><td class="value HTvertform-v" colspan="3">$pretext$field_html$posttext</td> </tr>
            ];
        }
        else {
            $sectioncount{$sname}++;
            my $rowcount =
              ( $sectioncount{$sname} % 2 ) ? 'HTr_odd' : 'HTr_even';
            $sections{$sname} .= qq[
            <tr class="$rowcount $row_class">
            <td class="label">$label</td>
            <td class="value">$pretext$field_html$posttext</td>
            </tr>
            ];
        }
    }

    my %usedsections = ();
    for my $s ( @{$sectionlist} ) {

        my $sectionheader = langlookup( $fields_ref, $s->[1] );

        if ( $sections{ $s->[0] } ) {
            next if $s->[2] and not display_section( $s->[2], $fields_ref );
            $usedsections{ $s->[0] } = 1;
            if ($notabs) {
                $returnstr .= $sections{ $s->[0] };
            }
            else {
                #my $style=$s ? 'style="display:none;" ' : '';
                my $sh = q{};
                if ( $s->[1] ) {
                    $sh = <<"EOS";
<tr><th colspan="2" class="sectionheader">$sectionheader</th></tr>
EOS
                }
                $tabs .= qq[<li><a id="a_sec$s->[0]" class="tab_links" href="#sec$s->[0]">$sectionheader</a></li>];

                $returnstr .= qq~
                <tbody id="sec$s->[0]" class="new_tab">
                $sh
                $sections{$s->[0]}
                </tbody>
                ~;
            }
        }
    }
    my $tableinfo =
      $fields_ref->{'options'}{'tableinfo'} || ' class = "HTF_table" ';
    my $pre_button_bottom =
        $fields_ref->{'options'}{'pre_button_bottomtext'}
      ? $fields_ref->{'options'}{'pre_button_bottomtext'}
      : '';
    $returnstr = qq[ 
    <table cellpadding="2" cellspacing="0" border="0" $tableinfo>
    $returnstr
    <tr><td colspan="2">$pre_button_bottom</td></tr>
    </table>
    ];
    if ($returnstr) {
        my $buttons = '';
        if (    $fields_ref->{'options'}{'submitlabelnondisable'}
            and $action ne 'display' )
        {
            my $txt = langlookup( $fields_ref,
                $fields_ref->{'options'}{'submitlabelnondisable'} );
            $buttons .=
qq[ <input type="submit" name="subbut" value="$txt" class="HF_submit button proceed-button" did="HFsubbut"> ];
            $fields_ref->{'options'}{'submitlabel'} = '';
        }
        if (    $fields_ref->{'options'}{'submitlabel'}
            and $action ne 'display' )
        {
            my $txt = langlookup( $fields_ref,
                $fields_ref->{'options'}{'submitlabel'} );
            $buttons .=
qq[ <input type="submit" name="subbut" value="$txt" class="HF_submit button proceed-button" id="HFsubbut"> ];
        }
        if ( $fields_ref->{'options'}{'resetlabel'} and $action ne 'display' ) {
            my $txt =
              langlookup( $fields_ref, $fields_ref->{'options'}{'resetlabel'} );
            $buttons .=
qq[ <input type="reset" name="resbut" value="$txt" class="HF_reset button cancel-button"> ];
        }
        my $introtext = $fields_ref->{'options'}{'introtext'} || '';
        $fields_ref->{'options'}{'submitlabel'} =
          $fields_ref->{'options'}{'submitlabelnondisable'}
          if ( $fields_ref->{'options'}{'submitlabelnondisable'} );

        if ( $introtext eq 'auto' ) {
            my $auto = langlookup( $fields_ref, 'AUTO_INTROTEXT',
                $fields_ref->{'options'}{'submitlabel'}, $compulsory );
            $introtext = qq[ <p class="introtext">$auto</p> ];
        }

        $introtext = '' if $action eq 'display';
        my $carryfields = '';
        if ( $fields_ref->{'carryfields'} ) {
            for my $cf ( keys %{ $fields_ref->{'carryfields'} } ) {
                $carryfields .=
qq[<input type="hidden" name="$cf" value="$fields_ref->{'carryfields'}{$cf}">];
            }
        }
        my $button_str = qq[<div class="HTbuttons">$buttons</div>];
        my $button_str_top =
          qq[<div class="HTbuttons HTbuttons_top">$buttons</div>];
        my $button_bottom = '';
        my $button_top    = '';

        if ( $returnstr =~ s/\%BUTTONBLOCK\%/$button_str/g ) {
            ## This block intentionally left blank
        }
        elsif ( $fields_ref->{'options'}{'buttonloc'} ) {
            my $loc = $fields_ref->{'options'}{'buttonloc'} || '';
            $button_top = $button_str_top
              if ( $loc eq 'top' or $loc eq 'both' );
            $button_bottom = $button_str
              if ( $loc eq 'bottom' or $loc eq 'both' );
        }
        else {
            $button_bottom = $button_str;
        }

        my $bottomtext =
            $fields_ref->{'options'}{'bottomtext'}
          ? $fields_ref->{'options'}{'bottomtext'}
          : '';

        my $enctype =
          $fields_ref->{'options'}{'FormEncoding'}
          ? qq[ enctype="$fields_ref->{'options'}{'FormEncoding'}" ]
          : '';
        my $validation =
          generate_clientside_validation( \%clientside_validation,
            $fields_ref );

        $returnstr = qq[
        $validation
        <form action="$fields_ref->{'options'}{'target'}" name="$fields_ref->{'options'}{'formname'}" method="POST" $enctype id = "$fields_ref->{'options'}{'formname'}ID">
        $introtext
        $button_top
        $returnstr
        $button_bottom
        <input type="hidden" name="HF_oldact" value="$oldaction">
        <input type="hidden" name="HF_subbutact" value="$subbutact">
        $carryfields
        $bottomtext
        </form>

        <script type="text/javascript" src="js/ajax.js"></script>
        <script type="text/javascript">
        $scripts
        </script>
        ];
    }
    my $html_head_init = _date_selection_picker_init($fields_ref);
    return ( $returnstr, \%usedsections, $html_head_init, $tabs );
}

sub display_section {
    my ( $rule, $fields_ref ) = @_;

    foreach my $field ( keys %{ $fields_ref->{fields} } ) {
        $rule =~ s/$field/"$fields_ref->{fields}{$field}{value}"/g;
    }

    return eval($rule);
}

sub current_age {

    my ($dob) = @_;

    my ( $b_year, $b_month, $b_day ) = Date::Calc::Decode_Date_EU($dob);
    my ( $t_year, $t_month, $t_day ) = Date::Calc::Today();

    my $age = $t_year - $b_year;

    if (    ( $b_day == 29 )
        and ( $b_month == 2 )
        and not Date::Calc::leap_year($t_year) )
    {
        $b_day   = 1;
        $b_month = 3;
    }

    return $age - 1 if $t_month < $b_month;
    return $age     if $t_month > $b_month;
    return $age - 1 if $t_day < $b_day;
    return $age;
}

sub drop_down {
    my (
        $name , $options_ref, $order_ref,    $default,  $size,
        $multi, $pre,         $otheroptions, $onChange, $class,
        $disabled
    ) = @_;
    #DEBUG "genereate dropdown for $name";
    return '' if ( !$name or !$options_ref );
    if ( !defined $default ) { $default = ''; }
    $multi        ||= '';
    $size         ||= 1;
    $otheroptions ||= '';
    $onChange     ||= '';
    $class        ||= '';

    $disabled = $disabled ? 'disabled="disabled"': '';
    if ( !$order_ref ) {

        #Make sure the order array is set up if not already passed in
        my @order = ();
        for my $option (
            sort { $options_ref->{$a} cmp $options_ref->{$b} }
            keys %{$options_ref}
          )
        {
            push @order, $option;
        }
        $order_ref = \@order;
    }
    if ( $multi and $default =~ /\0/ ) {
        my @d = split /\0/, $default;
        $default = \@d;
    }

    my $subBody = '';
    for my $val ( @{$order_ref} ) {
        if($val =~/optgroup/){
            $subBody .=qq[ <$val>];
            next;
        }
        my $selected = '';
        if ( ref $default ) {
            for my $v ( @{$default} ) {
                $selected = 'SELECTED'
                  if $val eq $v;
            }
        }
        else { $selected = 'SELECTED' if $val eq $default; }
        $subBody .=
          qq[ <option $selected value="$val">$options_ref->{$val}</option>];
    }
    $multi = ' multiple ' if $multi;
    $size = min($size, scalar (keys %$options_ref) + 1);
    my $preoption =
      ( $pre and not $multi )
      ? qq{<option value="$pre->[0]">$pre->[1]</option>}
      : '';
    $subBody = qq[
    <select name="d_$name" id="l_$name" size="$size" class = "$class" $multi $otheroptions $onChange $disabled>
    $preoption
    $subBody
    </select>
    ];
    return $subBody;
}

sub CheckSubmittedValues {
    my ( $fields_ref, $params, $permissions, $override_config, $option ) = @_;

    my $compulsory = '';
    my $problems   = '';
    my @fieldorder =
      (       defined $override_config
          and exists $override_config->{'order'}
          and $override_config->{'order'} )
      ? @{ $override_config->{'order'} }
      : @{ $fields_ref->{'order'} };
    for my $fieldname (@fieldorder) {
        my $name = "d_$fieldname";
        my $fv   = $fields_ref->{'fields'}{$fieldname};
        $fv->{'old_value'} = $fv->{'value'};

        #Update the form display
        if ( exists $params->{$name}
            and $fv->{'type'} ne 'htmlblock' )
        {
            $fv->{'value'} = $params->{$name};
        }

     #Handle the checkboxes - Data doesn't get sent if checkboxes aren't checked
        if (
                $fv->{'type'} eq 'checkbox'
            and !exists $params->{$name}
            and
            ( !$permissions or ( $permissions and $permissions->{$fieldname} ) )
            and ( !exists $fv->{'readonly'} or !$fv->{'readonly'} )
          )
        {
            $fv->{'value'} = 0;
        }

        if (
            ( $fields_ref->{'fields'}{$fieldname}{'type'} eq 'date' )
            or (    $fields_ref->{'fields'}{$fieldname}{'type'} eq 'hidden'
                and $fields_ref->{'fields'}{$fieldname}{'validate'} eq 'DATE' )
          )
        {

            if (
                not $fields_ref->{'fields'}{$fieldname}{'datetype'}
                or (    $fields_ref->{'fields'}{$fieldname}{'datetype'}
                    and $fields_ref->{'fields'}{$fieldname}{'datetype'} ne
                    'box' )
              )
            {

                if (    defined $params->{ $name . '_day' }
                    and defined $params->{ $name . '_mon' }
                    and defined $params->{ $name . '_year' } )
                {

                    my $d = $params->{ $name . '_day' }  || q{};
                    my $m = $params->{ $name . '_mon' }  || q{};
                    my $y = $params->{ $name . '_year' } || q{};

                    $params->{$name} = '0000-00-00' unless ( $d or $m or $y );

                    if (   ( $params->{'a'} eq 'RELOAD' )
                        or ( $d and $m and $y ) )
                    {
                        $fv->{'value'} = $params->{$name} = "$d/$m/$y";
                    }
                }
            }
        }

        if ( $fields_ref->{'fields'}{$fieldname}{'type'} eq 'time' ) {
            my $h = $params->{ $name . '_h' } || '';
            my $m = $params->{ $name . '_m' } || '';
            my $s = $params->{ $name . '_s' } || '';
            $h = "0$h" if length $h < 2;
            $m = "0$m" if length $m < 2;
            $s = "0$s" if length $s < 2;
            if ( $h or $m ) {
                $params->{$name} = "$h:$m:$s";
                $fv->{'value'} = $params->{$name};
            }
        }

        if (
            $fv->{'compulsory'}
            and (  !exists $params->{$name}
                or !defined $params->{$name}
                or $params->{$name} eq ''
                or $params->{$name} =~ /^\s*$/
                or $params->{$name} eq '0000-00-00' )
          )
        {
            next if ( $fv->{'noedit'} and $option eq 'edit' );
            next if ( $fv->{'noadd'}  and $option eq 'add' );
            next if $fv->{'readonly'};
            next if ( $permissions    and !$permissions->{$fieldname} );
            $compulsory .= "<li>$fv->{'label'}</li>" if $fv->{'label'};
            next;
        }
        if (    $fv->{'validate'}
            and exists $params->{$name}
            and $params->{$name} ne '' )
        {
            my $errs =
              _validate( $fv->{'validate'}, $params->{$name}, $fields_ref );
            for my $err ( @{$errs} ) {
                $problems .= "<li>$fv->{'label'} $err</li>";
            }
        }
    }

    my $resultHTML = '';
    if ($compulsory) {
        $resultHTML .= q[
        <p>]
          . langlookup( $fields_ref,
            'The following fields are compulsory and need to be filled in' )
          . qq[:</p>
        <ul>
        $compulsory
        </ul>
        ];
    }
    if ($problems) {
        $resultHTML .= qq[
        <ul>
        $problems
        </ul>
        ];
    }
    return $resultHTML;
}

sub _validate {
    my ( $type, $val, $fields_ref ) = @_;

    my @errors = ();
    for my $t ( split /\s*,\s*/, $type ) {
        my ($param) = $t =~ /:(.*)/;
        $t =~ s/:.*//g;
        my ( $num1, $num2 ) = ( '', '' );
        if ($param) {
            ( $num1, $num2 ) = split /\-/, $param;
        }

        if ( $t eq 'NUMBER' ) {
            push @errors, langlookup( $fields_ref, 'is not a valid number' )
              if $val !~ /^\d+$/;
        }
        if ( $t eq 'FLOAT' ) {
            push @errors, langlookup( $fields_ref, 'is not a valid number' )
              if $val !~ /^[\d\.]+$/;
        }
        elsif ( $t eq 'NOSPACE' ) {
            push @errors, langlookup( $fields_ref, 'cannot have spaces' )
              if $val =~ /\s/;
        }
        elsif ( $t eq 'NOHTML' ) {
            push @errors, langlookup( $fields_ref, 'cannot contain HTML' )
              if $val =~ /[<>]/;
        }
        elsif ( $t eq 'DATE' ) {
            push @errors, langlookup( $fields_ref, 'is not a valid date' )
              if !check_valid_date($val);
        }
        elsif ( $t eq 'MORETHAN' ) {
            push @errors,
              langlookup( $fields_ref, "is not more than [_1]", $num1 )
              if $val <= $num1;
        }
        elsif ( $t eq 'MORETHANEQUAL' ) {
            push @errors,
              langlookup( $fields_ref, "is not more than or equal to [_1]",
                $num1 )
              if $val < $num1;
        }
        elsif ( $t eq 'LESSTHAN' ) {
            push @errors,
              langlookup( $fields_ref, "is not less than [_1]", $num1 )
              if $val >= $num1;
        }
        elsif ( $t eq 'LESSTHANEQUAL' ) {
            push @errors,
              langlookup( $fields_ref, "is not less than or equal to [_1]",
                $num1 )
              if $val > $num1;
        }
        elsif ( $t eq 'BETWEEN' ) {
            push @errors,
              langlookup( $fields_ref, "is not between [_1] and [_2]",
                $num1, $num2 )
              if ( $val < $num1 or $val > $num2 );
        }
        elsif ( $t eq 'LENGTH' ) {
            push @errors,
              langlookup( $fields_ref, "must be [_1] characters long", $num1 )
              if length($val) != $num1;
        }
        elsif ( $t eq 'EMAIL' ) {
            require Mail::RFC822::Address;
            my @emails = split /;/, $val;
            foreach (@emails) {
                push @errors,
                  langlookup( $fields_ref, 'is not a valid email address' )
                  if !Mail::RFC822::Address::valid($_);
            }
        }
    }

    return ( \@errors );
}

sub handleHTMLForm {
    my ( $fields_ref, $permissions, $option, $notabs, $db, $override_config,
        $tempAdd )
      = @_;
    my $q          = new CGI;
    my %params     = $q->Vars();
    my $resultHTML = '';
    my $usedsections;
    my $continue    = '';
    my $processed   = 0;
    my $processedOK = 0;

    my $result;

    if ( $params{'HF_subbutact'} ) {

        ($result) = CheckSubmittedValues( $fields_ref, \%params, $permissions,
            $override_config, $option, );
        if ( $result or ( $params{'a'} eq 'RELOAD' ) ) {
            $params{'HF_subbutact'} = '' if $result;
            if ( $params{'a'} ne 'RELOAD' ) {
                $resultHTML .= qq[
                <div class="warningmsg"><div class="msgtitle">]
                  . langlookup( $fields_ref, 'Problems' ) . qq[</div>
                $result
                </div>
                ];
            }
        }
    }
    my $html_head_init = q{};

    my $tabs = '';
    if ( $params{'HF_subbutact'} ) {
        if ( not $result and ( $params{'a'} ne 'RELOAD' ) ) {

#OK, the form has been submitted and the values are fine so we should do something about it
            my $oldaction = $params{'HF_oldact'} || '';
            if (    $oldaction eq 'add'
                and $fields_ref->{'options'}{'afteraddAction'} )
            {
                $option =
                  $fields_ref->{'options'}{'afteraddAction'} || 'display';
            }
            if (    $oldaction eq 'edit'
                and $fields_ref->{'options'}{'aftereditAction'} )
            {
                $option =
                  $fields_ref->{'options'}{'aftereditAction'} || 'display';
            }
            ( $continue, $result ) =
              _processsubmission( $fields_ref, \%params, $db, $option,
                $permissions, $override_config, $tempAdd );
            $processed   = 1;
            $processedOK = $continue;
            $continue    = 0 if $fields_ref->{'options'}{'stopAfterAction'};
            $params{'HF_subbutact'} = '' if ( $result and $continue );
            $resultHTML .= $result if $result;
        }
    }
    elsif ( !$params{'HF_subbutact'} ) {
        my $oldaction = $params{'HF_oldact'} || '';
        if ($processed) { $oldaction = $option; }
        $option = $fields_ref->{'options'}{'OptionAfterProcessed'}
          if (  $fields_ref->{'options'}{'OptionAfterProcessed'}
            and $processed );
        my $result = '';
        ( $result, $usedsections, $html_head_init, $tabs ) =
          genHTMLForm( $fields_ref, $permissions, $option, $notabs,
            $oldaction, $override_config );
        $resultHTML .= $result if $result;
    }

    return ( $resultHTML, $processedOK, $html_head_init, $tabs );
}

sub _processsubmission {
    my ( $fields_ref, $params, $db, $option, $permissions, $override_config,
        $tempAdd )
      = @_;
    my $continue   = 1;
    my $return_url = $fields_ref->{'options'}{'view_url'};
    my $return_html =
      $return_url ? "&nbsp;<br/><a href=\"$return_url\">Return</a>" : "";
    my $json_ready_array;
    my @fieldorder =
      (       defined $override_config
          and exists $override_config->{'order'}
          and $override_config->{'order'} )
      ? @{ $override_config->{'order'} }
      : @{ $fields_ref->{'order'} };

    if ( $option eq 'edit' ) {
        my ( @values, @fields, @values_placeholder ) = ();
        my %fields_changes;

        for my $fieldname (@fieldorder) {
            next if $fields_ref->{'fields'}{$fieldname}{'noedit'};
            next if !$fields_ref->{'fields'}{$fieldname}{'label'};

            my $elem_name = "d_$fieldname";
            my $elem_id   = "l_$fieldname";
            if (
                $fields_ref->{'fields'}{$fieldname}{'type'} eq 'checkbox'
                 and (!$permissions or ($permissions and $permissions->{$fieldname})) 
                and not $fields_ref->{'fields'}{$fieldname}{'readonly'}
              )
            {
                $params->{$elem_name} ||= 0;
            }

            if ( $fields_ref->{'fields'}{$fieldname}{'type'} eq 'date' ) {
                 if($params->{$elem_name}){
                        $params->{$elem_name} =
                         _fix_date( $params->{$elem_name} || '', $fields_ref );
                    }
                delete $params->{$elem_name} if !$params->{$elem_name};
            }
            next if not exists $params->{$elem_name};
            next if $fields_ref->{'fields'}{$fieldname}{'SkipProcessing'};
            if (
                exists $fields_ref->{'fieldtransform'}{'textcase'}{$fieldname} )
            {
                my $field_case =
                  $fields_ref->{'fieldtransform'}{'textcase'}{$fieldname} || '';
                $params->{$elem_name} =
                  apply_case_rule( $params->{$elem_name}, $field_case )
                  if $field_case;
            }
            $params->{$elem_name} =~ s/</&lt;/g
              if $fields_ref->{'options'}{'NoHTML'};
            $params->{$elem_name} =~ s/>/&gt;/g
              if $fields_ref->{'options'}{'NoHTML'};
            $params->{$elem_name} =~ s/"/&quot;/g
              if $fields_ref->{'options'}{'NoHTML'};
            my $db_f_name =
              $fields_ref->{'fields'}{$fieldname}{'tablename'}
              ? "$fields_ref->{'fields'}{$fieldname}{'tablename'}.$fieldname"
              : $fieldname;

            push @fields,             $db_f_name;
            push @values,             $params->{$elem_name};
            push @values_placeholder, "$db_f_name = ?";

            $json_ready_array->{$db_f_name} = $params->{$elem_name};

            if ( $fields_ref->{'fields'}{$fieldname}{'auditField'} ) {
                my $new_value = $params->{$elem_name};
                my $old_value =
                  $fields_ref->{'fields'}{$fieldname}{'old_value'};

                # Fix date formats if we even have them
                if (   $fields_ref->{'fields'}{$fieldname}{'type'} eq 'date'
                    && $old_value )
                {
                    $old_value = _fix_date( $old_value, $fields_ref );
                }

                $new_value = '' if ( !defined $new_value );
                $old_value = '' if ( !defined $old_value );

                if ( $old_value ne $new_value ) {
                    $fields_changes{$fieldname} = {
                        'old_value' => $old_value,
                        'new_value' => $new_value,
                    };
                }
            }
        }

        my $placeholders = join( ", ", @values_placeholder );
        my $statement = $fields_ref->{'options'}{'updateSQL'} || '';

        # in case of there is no editable field in the form (all readonly),
        # this $query has to not be undef or "False". Otherwise in later
        # run_function .. 'afterupdate', the first param push to the callback
        # function param list will not be the record id, code quote below
        # 
        # >> push @params, $query->{mysql_insertid} || 0 if $query;
        #
        # we can do more beyond this but that will cause many interface change
        # of callback functions
        my $query = {mysql_insertid => 0};

        if ( $statement and $placeholders ) {
            $statement =~ s/--VAL--/$placeholders/;
            my ( $cont, $fnret ) =
              run_function( $fields_ref, $params, 'beforeupdate' );
            return ( $cont, $fnret ) if $fnret;

            #Only happens if Temp add is requested
            if ($tempAdd) {
                $json_ready_array->{'afteraddParams'} = $params;
                my $j      = new JSON;
                my $string = JSON::to_json($json_ready_array);

                # warn "TO JASON:: $string\n\n\n\n";
                #$params->{'a'} ='RELOAD';
                $params->{'json'} = $string;
                return ( $cont, $fnret ) =
                  run_function( $fields_ref, $params, 'tempAdd' );
            }
            $query = exec_sql( $statement, @values );
            if ($DBI::err) {
                return ( 0,
                    $fields_ref->{'options'}{'updateBADtext'}
                      || '<div class="warningmsg">'
                      . langlookup( $fields_ref, 'Database Error in Update' )
                      . $return_html
                      . '</div>' );
            }
        }

        my ( $cont, $fnret ) = run_function( $fields_ref, $params, 'afterupdate', $query);
        return ( $cont, $fnret ) if $fnret;

        if ( $fields_ref->{'options'}{'auditFunction'} ) {
            my @params = ();
            push @params,
              @{ $fields_ref->{'options'}{'auditEditParams'} }
              if $fields_ref->{'options'}{'auditEditParams'};
            if (   $fields_ref->{'options'}{'auditEditParamsAddFields'}
                && %fields_changes )
            {
                push @params, \%fields_changes;
            }
            $fields_ref->{'options'}{'auditFunction'}->(@params);
        }
        return ( 1, $fields_ref->{'options'}{'updateOKtext'}
              || '<div class="OKmsg">'
              . langlookup( $fields_ref, 'Record updated successfully' )
              . $return_html
              . '</div>' );
    }
    elsif ( $option eq 'add' ) {

        my ( @values, @fields, @values_placeholder ) = ();

        for my $fieldname (@fieldorder) {
            next if $fields_ref->{'fields'}{$fieldname}{'noadd'};
            next if !$fields_ref->{'fields'}{$fieldname}{'label'};
            my $elem_name = 'd_' . $fieldname;
            next if !exists $params->{$elem_name};
            $params->{$elem_name} =
              _fix_date( $params->{$elem_name}, $fields_ref )
              if $fields_ref->{'fields'}{$fieldname}{'type'} eq 'date';
            $params->{$elem_name} =~ s/</&lt;/g
              if $fields_ref->{'options'}{'NoHTML'};
            $params->{$elem_name} =~ s/>/&gt;/g
              if $fields_ref->{'options'}{'NoHTML'};
            $params->{$elem_name} =~ s/"/&quot;/g;
            next if $fields_ref->{'fields'}{$fieldname}{'SkipProcessing'};
            next if $fields_ref->{'fields'}{$fieldname}{'SkipAddProcessing'};

            if (
                exists $fields_ref->{'fieldtransform'}{'textcase'}{$fieldname} )
            {
                my $field_case =
                  $fields_ref->{'fieldtransform'}{'textcase'}{$fieldname} || '';
                $params->{$elem_name} =
                  apply_case_rule( $params->{$elem_name}, $field_case )
                  if $field_case;
            }
            push @fields,             $fieldname;
            push @values,             $params->{$elem_name};
            push @values_placeholder, "?";
            $json_ready_array->{$fieldname} = $params->{$elem_name};
        }

        my $fieldlist    = join( ", ", @fields );
        my $placeholders = join( ", ", @values_placeholder );

        my $statement = $fields_ref->{'options'}{'addSQL'} || '';
        if ( $statement and $placeholders ) {
            $statement =~ s/--VAL--/$placeholders/;
            $statement =~ s/--FIELDS--/$fieldlist/;
            my ( $cont, $fnret ) =
              run_function( $fields_ref, $params, 'beforeadd' );
            return ( $cont, $fnret ) if $fnret;

            #only happes if Temp add is requested
            if ($tempAdd) {
                $json_ready_array->{'afteraddParams'} = $params;
                my $j      = new JSON;
                my $string = JSON::to_json($json_ready_array);

                #$params->{'a'} ='RELOAD';
                $params->{'json'} = $string;

                return ( $cont, $fnret ) =
                  run_function( $fields_ref, $params, 'tempAdd' );
            }

            my $query = exec_sql( $statement, @values );
            if ($DBI::err) {
                return $fields_ref->{'options'}{'addBADtext'}
                  || '<div class="warningmsg">'
                  . langlookup( $fields_ref, 'Database Error in Addition' )
                  . $query->errstr
                  . $return_html
                  . '</div>';
            }
            else {
                my ( $cont, $fnret ) =
                  run_function( $fields_ref, $params, 'afteradd', $query );
                if ( $fields_ref->{'options'}{'auditFunction'} ) {
                    my @params = ();
                    push @params, $query->{mysql_insertid} || 0;
                    push @params,
                      @{ $fields_ref->{'options'}{'auditAddParams'} }
                      if $fields_ref->{'options'}{'auditAddParams'};
                    $fields_ref->{'options'}{'auditFunction'}->(@params);
                }
                if ( $fields_ref->{'options'}{'addOKlink'} && $query->{mysql_insertid} ){
                    $fields_ref->{'options'}{'addOKlink'} =~ s/__ID__/$query->{mysql_insertid}/;
                }
                else{
                    $fields_ref->{'options'}{'addOKlink'} = '';
                }
                return ( $cont, $fnret ) if $fnret;
                return ( 1,
                    $fields_ref->{'options'}{'addOKtext'}
                      || '<div class="OKmsg">'
                      . langlookup( $fields_ref, 'Record added successfully' )
                      . $fields_ref->{'options'}{'addOKlink'}
                      . $return_html
                      . '</div>' );
            }
        }
    }
}

sub apply_case_rule {
    my ( $text, $case ) = @_;

    return $text if $case !~ /Lower|Upper|Title|Sentence/;

    my $new_text = '';
    if ( $case eq 'Lower' ) {
        $new_text = lc($text);
    }
    elsif ( $case eq 'Upper' ) {
        $new_text = uc($text);
    }
    elsif ( $case eq 'Title' ) {
        if ( $text eq uc($text) or $text eq lc($text) ) {
            $new_text = lc($text);
            $new_text = ucfirst($new_text);
            $new_text =~ s/(\w+)/\u$1/g;
            $new_text =~ s/([ \-'\(])/\u$1/g;
            $new_text =~ s/('S)/\L$1/g;
            $new_text =~ s/\s+$//;
        }
        else {
            $new_text = $text;
        }
    }
    else {
        $new_text = lc($text);
        $new_text = ucfirst($new_text);
    }

    return $new_text;

}

sub _fix_date {
    my ( $date, $fields_ref, %extra ) = @_;
    return '' if !$date;
    return '0000-00-00' if ( $date eq '0000-00-00' || $date eq '00/00/0000' );
    if ( exists $extra{NODAY} and $extra{NODAY} ) {
        my ( $mm, $yyyy ) = $date =~ m:(\d+)/(\d+):;
        if ( !$mm or !$yyyy ) {
            return ( langlookup( $fields_ref, "Invalid Date" ), '' );
        }
        if    ( $yyyy < 10 )  { $yyyy += 2000; }
        elsif ( $yyyy < 100 ) { $yyyy += 1900; }
        return "$yyyy-$mm-01";
    }
    my ( $dd, $mm, $yyyy ) = $date =~ m:(\d+)/(\d+)/(\d+):;
    if ( !$dd or !$mm or !$yyyy ) {
        return ( langlookup( $fields_ref, "Invalid Date" ), '' );
    }
    if    ( $yyyy < 10 )  { $yyyy += 2000; }
    elsif ( $yyyy < 100 ) { $yyyy += 1900; }
    return "$yyyy-$mm-$dd";
}

sub run_function {
    my ( $fields_ref, $params, $functiontype, $query ) = @_;
    if ( $fields_ref->{'options'}{ $functiontype . 'Function' } ) {
        my @params = ();
        push @params, $query->{mysql_insertid} || 0 if $query;
        push @params, $params;
        push @params, @{ $fields_ref->{'options'}{ $functiontype . 'Params' } }
          if $fields_ref->{'options'}{ $functiontype . 'Params' };
        $fields_ref->{'options'}{ $functiontype . 'Function' }->(@params);
    }
}

sub check_valid_date {
    my ($date) = @_;
    return 1 if $date eq '0000-00-00';
    return 1 if $date eq '00/00/0000';
    my ( $d, $m, $y ) = split /\//, $date;
    return Date::Calc::check_date( $y, $m, $d );
}

sub langlookup {
    my $fields_ref = shift;
    my $key        = shift;
    return '' if !$key;

    my %Lexicon = (
        'AUTO_INTROTEXT' =>
qq[To modify this information change the information in the boxes below and when you have finished press the <strong>'[_1]'</strong> button.<br><span class="intro-subtext"><strong>Note:</strong> All boxes marked with a [_2] are compulsory and must be filled in.</span>],
        'Compulsory Field'            => 'Compulsory Field',
        'Invalid Date'                => 'Invalid Date',
        'Record added successfully'   => 'Record added successfully',
        'Database Error in Addition'  => 'Database Error in Addition',
        'Record updated successfully' => 'Record updated successfully',
        'Database Error in Update'    => 'Database Error in Update',
        'Problems'                    => 'Problems',
        'The following fields are compulsory and need to be filled in' =>
          'The following fields are compulsory and need to be filled in',
        'is not a valid number' => 'is not a valid number',
        'cannot have spaces'    => 'cannot have spaces',
        'cannot contain HTML'   => 'cannot contain HTML',
        'is not a valid date'   => 'is not a valid date',
        "is not more than [_1]" => "is not more than [_1]",
        "is not more than or equal to [_1]" =>
          "is not more than or equal to [_1]",
        "is not less than [_1]" => "is not less than [_1]",
        "is not less than or equal to [_1]" =>
          "is not less than or equal to [_1]",
        "is not between [_1] and [_2]" => "is not between [_1] and [_2]",
        "must be [_1] characters long" => "must be [_1] characters long",
        'is not a valid email address' => 'is not a valid email address',
    );

    my $txt = q{};
    if ( exists $fields_ref->{'options'}{'LocaleMakeText'}
        and $fields_ref->{'options'}{'LocaleMakeText'} )
    {

        $txt = $fields_ref->{'options'}{'LocaleMakeText'}->txt(
            $key,
            (
                map {
                    $fields_ref->{'options'}{'LocaleMakeText'}->txt($_)
                      || $_
                } @_
            )
        );

        $txt ||= q{};

    }
    if ( !$txt and exists $Lexicon{$key} ) {
        $txt = $Lexicon{$key} || '';

        #Check for replacements
        my @matches = $txt =~ /\[[_\d]+\]/g;
        my $num     = scalar @matches;
        for my $n ( 1 .. $num ) {
            $txt =~ s/\[_$n\]/$_[$n-1]/;
        }
    }
    $txt = $key if !$txt;
    return $txt;
}

sub _time_selection_box {
    my ( $fieldname, $val, $f, $otherinfo, $showblank, $onChange ) = @_;
    $showblank ||= 0;
    $otherinfo ||= '';
    $val       ||= '';
    my ( $val_h, $val_m, $val_s ) = split /:/, $val;
    $val_h ||= '';
    $val_m ||= '';
    $val_s ||= '';
    my $hours = '';
    my $mins  = '';
    my $secs  = '';
    $val_h = '0' . $val_h if length($val_h) == 1;
    $val_m = '0' . $val_m if length($val_m) == 1;
    $val_s = '0' . $val_s if length($val_s) == 1;

    for my $j ( 0 .. 23 ) {
        $j = '0' . $j if $j < 10;
        my $selected = $j eq $val_h ? ' SELECTED ' : '';
        $hours .= qq[<option value="$j" $selected>$j</option>];
    }
    for my $j ( 0 .. 59 ) {
        $j = '0' . $j if $j < 10;
        my $selected = $j eq $val_m ? ' SELECTED ' : '';
        $mins .= qq[<option value="$j" $selected>$j</option>];
    }
    for my $j ( 0 .. 59 ) {
        $j = '0' . $j if $j < 10;
        my $selected = $j eq $val_s ? ' SELECTED ' : '';
        $secs .= qq[<option value="$j" $selected>$j</option>];
    }
    if ($showblank) {
        $mins  = qq[<option value=""> </option>] . $mins;
        $hours = qq[<option value=""> </option>] . $hours;
        $secs  = qq[<option value=""> </option>] . $secs;
    }
    my $field_html = qq[
    <select name="d_$fieldname]
      . qq[_h" style="vertical-align:middle" $otherinfo $onChange>$hours</select>:
    <select name="d_$fieldname]
      . qq[_m" style="vertical-align:middle" $otherinfo $onChange>$mins</select>
    <span class="HTdateformat">24 hour time</span>
    ];
    return $field_html;
}

sub _date_selection_dropdown {
    my ( $fieldname, $val, $f, $otherinfo, $fields_ref, $onChange ) = @_;
    my ( $onBlur, $onMouseOut );
    if ($onChange) {
        ( $onBlur = $onChange ) =~
s/onChange=(['"])(.*)\1/onBlur=$1 alert(changed_$fieldname); alert('Hola'); if (changed_$fieldname==1) { $2 } $1/i;
        ( $onMouseOut = $onChange ) =~
s/onChange=(['"])(.*)\1/onMouseOut=$1 if (changed_$fieldname==1) { $2 } $1/i;
    }
    $onBlur     ||= '';
    $onMouseOut ||= '';

    $otherinfo ||= '';

    my %days = map { $_ => $_ } ( 1 .. 31 );
    $days{0} = langlookup( $fields_ref, 'Day' );

    my %months = (
        0  => langlookup( $fields_ref, 'Month' ),
        1  => langlookup( $fields_ref, 'Jan' ),
        2  => langlookup( $fields_ref, 'Feb' ),
        3  => langlookup( $fields_ref, 'Mar' ),
        4  => langlookup( $fields_ref, 'Apr' ),
        5  => langlookup( $fields_ref, 'May' ),
        6  => langlookup( $fields_ref, 'Jun' ),
        7  => langlookup( $fields_ref, 'Jul' ),
        8  => langlookup( $fields_ref, 'Aug' ),
        9  => langlookup( $fields_ref, 'Sep' ),
        10 => langlookup( $fields_ref, 'Oct' ),
        11 => langlookup( $fields_ref, 'Nov' ),
        12 => langlookup( $fields_ref, 'Dec' ),
    );
    my $currentyear = (localtime)[5] + 1900 + 5;
    my %years = map { $_ => $_ } ( 1900 .. $currentyear );
    $years{0} = langlookup( $fields_ref, 'Year' );

    $val ||= '';
    my ( $val_y, $val_m, $val_d ) = split /\-/, $val;
    if ( !$val_d and $val =~ /\// ) {
        ( $val_d, $val_m, $val_y ) = split /\//, $val;
    }
    $val_d ||= '';
    $val_m ||= '';
    $val_y ||= '';
    $val_d =~ s/^0//;
    $val_m =~ s/^0//;

    my @order_d = ( 0 .. 31 );
    my @order_m = ( 0 .. 12 );
    my @order_y = reverse( 1900 .. $currentyear );
    unshift( @order_y, 0 );

    my $otherinfo_d =
      $otherinfo
      . qq[ id="l_d_$fieldname" onFocus="changed_temp_$fieldname=changed_$fieldname; changed_$fieldname=0;" onChange="changed_temp_$fieldname=1;" onBlur="changed_$fieldname=changed_temp_$fieldname; alert(changed_$fieldname);" ]
      if ($onChange);
    my $otherinfo_m =
      $otherinfo
      . qq[ id="l_m_$fieldname" onFocus="changed_temp_$fieldname=changed_$fieldname; changed_$fieldname=0;" onChange="changed_temp_$fieldname=1;" onBlur="changed_$fieldname=changed_temp_$fieldname; alert(changed_$fieldname);" ]
      if ($onChange);
    my $otherinfo_y =
      $otherinfo
      . qq[ id="l_y_$fieldname" onFocus="changed_temp_$fieldname=changed_$fieldname; changed_$fieldname=0;" onChange="changed_temp_$fieldname=1;" onBlur="changed_$fieldname=changed_temp_$fieldname; alert(changed_$fieldname);" ]
      if ($onChange);

    my $daysfield =
      drop_down( "${fieldname}_day", \%days, \@order_d, $val_d, 1, 0, '',
        $otherinfo_d );
    my $monthsfield =
      drop_down( "${fieldname}_mon", \%months, \@order_m, $val_m, 1, 0, '',
        $otherinfo_m );
    my $yearsfield =
      drop_down( "${fieldname}_year", \%years, \@order_y, $val_y, 1, 0, '',
        $otherinfo_y );

    my $field_html =
qq[ <span $onMouseOut> <script language="JavaScript1.2">var changed_$fieldname=0; var changed_temp_$fieldname=0</script> ];
    $field_html .= $daysfield;
    $field_html .= $monthsfield;
    $field_html .= $yearsfield;

    return $field_html;
}

=head1 NAME

_date_selection_picker

=head1 DESCRIPTION

Will return a string of html containing a script and a field.
The script applys a jquery datepicker to that field. 

=head1 EXAMPLE
For a field, you can specify what datepicker options you wish to apply

Field Configuration Example:
    dtMaxDOB => {
        label       => "Max DOB",
        value       => $dref->{'dtMaxDOB'},
        type        => 'date',
        size        => '20',
        sectionname => 'age',
        datepicker_options => {
            'link_min_field' => 'dtMinDOB',
            'min_date'       => $dref->{'dtMinDOB'},
        },
    },

=head1 OPTIONS

=over 14

=item link_min_field

Will link this field to minimum field. Selecting a date on the current field will 
update the max date on the linked field. This prevents the user from selecting a 
date on the minimum field that is after the current fiend.

=item link_max_field

Will link this field to maximum field. Selecting a date on the current field will 
update the min date on the linked field. This prevents the user from selecting a 
date on the maximum field that is before the current fiend.

=item min_date

Will set a minimum date. No dates before this date can be selected by the datepicker.
This can be in 'dd/mm/yy/' or 'yyyy-mm-dd' format, or could also be relative, for 
example '-1y' (one year before today) or '+3m' (3 months from today)

=item max_date

Will set a maximum date. No dates after this date can be selected by the datepicker.
This can be in 'dd/mm/yy/' or 'yyyy-mm-dd' format, or could also be relative, for 
example '-1y' (one year before today) or '+3m' (3 months from today)

=item no_min_date

Currently the default min_date is '-1y'. Setting this option to a true value will
prevent that default min_date from being applied.

=item prevent_user_input

This will set the field to readonly, so users can not edit it, but without it being
skipped when processing the submission. Will also not take effect if javascript is
disabled on the users end, so they can still enter their date.

=back 

=cut

sub _date_selection_picker {

    #my($name, $value) = @_;
    my ( $name, $value, $f, $otherinfo, $fieldsref, $onChange ) = @_;
    my ( $date, $time ) = split( ' ', $value );
    $value = join( '/', reverse( split( '-', $date ) ) ) if $date;
    my $readonly ='';
    
    my @datepicker_options = (
        qq[dateFormat: 'dd/mm/yy'],
        qq[showButtonPanel: true],
    );
    
    # Date to and from restrictions
    # used when we have two date fields and we want to link them together
    if ($f->{'datepicker_options'}->{'link_min_field'}){
        # enforce our maximum date restriction on the min field
        my $min = $f->{'datepicker_options'}->{'link_min_field'};
        push @datepicker_options, qq[ 
            onClose: function( selectedDate ) {
                \$( "#l_$min" ).datepicker( "option", "maxDate", selectedDate );
            }
        ];
    }
    elsif ($f->{'datepicker_options'}->{'link_max_field'}){
        # enforce our minimum date restriction on the max field
        my $max = $f->{'datepicker_options'}->{'link_max_field'};
        push @datepicker_options, qq[ 
            onClose: function( selectedDate ) {
                \$( "#l_$max" ).datepicker( "option", "minDate", selectedDate );
            }
        ];
    }
    
    # Max and min date values
    if ($f->{'datepicker_options'}->{'min_date'}){
        # enforce our maximum date restriction on the min field
        my $min = $f->{'datepicker_options'}->{'min_date'};
        if ( $min =~ /(\d{4})-(\d{1,2})-(\d{1,2})/ ){
            $min = "$3/$2/$1";
        }
        push @datepicker_options, qq[minDate: '$min'] unless ($min eq '00/00/0000');
    }
    
    if ($f->{'datepicker_options'}->{'max_date'}){
        # enforce our maximum date restriction on the min field
        my $max = $f->{'datepicker_options'}->{'max_date'};
        if ( $max =~ /(\d{4})-(\d{1,2})-(\d{1,2})/ ){
            $max = "$3/$2/$1";
        }
        push @datepicker_options, qq[maxDate: '$max'] unless ($max eq '00/00/0000');
    }
    
    # Prevent user input, as this might be outside our date range
    # done in javascript, as if they load without javascript, will not lock
    # them out of editing this field
    if ( $f->{'datepicker_options'}->{'prevent_user_input'}){
        $readonly = qq[\$('#l_$name').attr("readonly", true)];
    }

    my $datepicker_options_string = join(",\n", @datepicker_options) || '';

    my $js = qq[
    <script type="text/javascript">
    jQuery().ready(function() {
            jQuery("#l_$name").datepicker({
                    $datepicker_options_string
                });
            $readonly
        });
    </script>
    ];

    my $field_html = qq[
    $js
    <input type="text" name="d_$name" value="$value" id="l_$name" size="12" class="datepicker">
    ];

    return $field_html;
}

sub _date_selection_picker_init {
    my ($fields_ref) = @_;

    my $jsurl = $fields_ref->{'options'}{'jsURL'} || 'js/';

    my @picker_fields = ();
    for my $fieldname ( @{ $fields_ref->{'order'} } ) {
        next if !$fieldname;
        my $f = $fields_ref->{'fields'}{$fieldname};
        next if !$f;
        my $type = $f->{'type'} || '';
        if ( $type eq 'date' ) {
            push @picker_fields, $fieldname
              if ( exists $f->{'datetype'} and $f->{'datetype'} eq 'picker' );
        }
    }

    return '' if !@picker_fields;
}

sub generate_clientside_validation {
    my ( $validation, $fields_ref ) = @_;
    
    my $field_prefix = 'd_';
    my $form_suffix = 'ID';
    
    if (defined $fields_ref->{'options'}{'field_prefix'}){
        $field_prefix = $fields_ref->{'options'}{'field_prefix'};
    }
    if (defined $fields_ref->{'options'}{'form_suffix'}){
        $form_suffix = $fields_ref->{'options'}{'form_suffix'};
    }
    
    my $tab_div_id = $fields_ref->{'options'}{'tab_div_id'} ||'new_tabs_wrap';
    my $tab_class  = $fields_ref->{'options'}{'tab_class'}  || 'new_tab';
    my $tab_style  = $fields_ref->{'options'}{'tab_style'}  || 'none';
    
    my $body = '';

    my $messages = '';

    my %valinfo = ();
    for my $k ( keys %{$validation} ) {
        if ( $validation->{$k}{'compulsory'} ) {
            $valinfo{'rules'}{ $field_prefix . $k }{'required'} = 'true';
            $valinfo{'messages'}{ $field_prefix . $k }{'required'} =
              langlookup( $fields_ref, 'Field required' );
        }
        if ( $validation->{$k}{'validate'} ) {
            for my $t ( split /\s*,\s*/, $validation->{$k}{'validate'} ) {
                my ($param) = $t =~ /:(.*)/;
                $t =~ s/:.*//g;
                my ( $num1, $num2 ) = ( '', '' );
                if ($param) {
                    ( $num1, $num2 ) = split /\-/, $param;
                }
                if ( $t eq 'LENGTH' ) {
                    $valinfo{'rules'}{ $field_prefix . $k }{'minlength'} = $num1;
                    $valinfo{'messages'}{ $field_prefix . $k }{'minlength'} =
                      langlookup( $fields_ref,
                        "This must be [_1] characters long", $num1 );
                }
                elsif ( $t eq 'EMAIL' ) {
                    $valinfo{'rules'}{ $field_prefix . $k }{'email'} = 'true';
                    $valinfo{'messages'}{ $field_prefix . $k }{'email'} =
                      langlookup( $fields_ref,
                        "Please enter a valid email address" );
                }
                elsif ( $t eq 'BETWEEN' ) {
                    $valinfo{'rules'}{ $field_prefix . $k }{'range'} =
                      [ $num1, $num2 ];
                    $valinfo{'messages'}{ $field_prefix . $k }{'range'} =
                      langlookup( $fields_ref,
                        "Please enter a value between [_1] and [_2]",
                        $num1, $num2 );
                }
                elsif ( $t eq 'NUMBER' ) {
                    $valinfo{'rules'}{ $field_prefix . $k }{'digits'} = 'true';
                    $valinfo{'messages'}{ $field_prefix . $k }{'digits'} =
                      langlookup( $fields_ref, "Please enter only digits" );
                }
                elsif ( $t eq 'FLOAT' ) {
                    $valinfo{'rules'}{ $field_prefix . $k }{'number'} = 'true';
                    $valinfo{'messages'}{ $field_prefix . $k }{'number'} =
                      langlookup( $fields_ref, "Please enter a valid number",
                        $num1, $num2 );
                }
            }
        }
    }

    my $val_rules;
    eval {
        require JSON;
        $val_rules = JSON::to_json( \%valinfo );
    };
    if ( $val_rules and $val_rules ne '{}' ) {

        $val_rules =~ s/"true"/true/g;
        $val_rules =~ s/"false"/false/g;
        $val_rules =~ s/}$//;
        $val_rules .= qq~
            ,
            ignore: ".ignore",
            errorClass: "form_field_invalid",
            validClass: "form_field_valid",
            invalidHandler: function(e, validator){
                if(validator.errorList.length){
                    var tabname = jQuery(validator.errorList[0].element).closest(".$tab_class").attr('id');
                    
                    if ( '$tab_style' == 'ui-tabs' ){
                        // Using divs and jquery tabs
                        var tab = document.getElementById(tabname);
                        \$('#$tab_div_id').tabs('select', '#' + tabname);
                    }
                    else if ('$tab_style' == 'tables'){
                        // Using html forms tables and black magic
                        jQuery('.tab_links').removeClass('active');
                        jQuery('#a_' + tabname ).addClass('active');
                        jQuery('.$tab_class').hide();
                        jQuery('#' + tabname ).show(); 
                        
                    }
                    //alert("Got invalid input on tab " + tabname);
                }
            }
        }
        ~;
        return qq[
        <script src = "//ajax.aspnetcdn.com/ajax/jquery.validate/1.9/jquery.validate.min.js"></script>
        <script type="text/javascript">
        jQuery().ready(function() {
                // validate the comment form when it is submitted
                jQuery("#$fields_ref->{'options'}{'formname'}$form_suffix").validate($val_rules);
            });
        </script>
        ];
    }
    return '';
}

#Changes
# 17/01/12 Warren
# Make sure hidden fields aren't checked for compulsory nature

# 16/01/12 Warren
# Add in option to put compulsory icon in pre/post field text

#11/10/11 Warren
# Add in clientside validation

#02/08/2011 Warren
# Add htmlblock type

#15/9/2009 Warreb
#Some small cleanups and option to have vertical form (eg. labels on top of fields)

#27/06/2008 Warren
##Fixed problem with date not checking for compulsory
#
#25/02/2008 Warren
# Fixed problem with date not saving changes if missing compulsory field
#17/01/2008 Warren
# Added id to dropdown month field in date picker

#14/09/2007 Warren
# Fix bug with not being able to blank out dates

#27/02/2007 Warren
# Added showblank into timeselection box

#23/02/2007 Warren
# Fix bug with time selection box where hour < 10

#02/02/2007 Warren
#Fix bug with date component not showing properly if day < 10

#05/02/2007 Warren
# Fixed bug in action after processed
# Fixed bug with date handling if date set as readonly

#30/01/2007 Warren
# Fix bug with date component and dates not being saved

#11/01/2007 Warren
# Added ability to define ActionAfterProcessed to set a new option after record saved

#07/12/2006 Warren
# fix to not update column if label is blank

#01/12/06 Warren
#Added in tablename param for multi-table updates

#29/11/06 Warren
# add in format text for text field

#24/10/06 Warren

#Update add 1900 if date < 100 and > 10
#Update date picker so it will open on min date if range defined

#17/10/06 Warren
# Exported date_box function
# Fixed bug in regex

#11/10/06 Warren
# More work on date picker
# Allow date range restrictions

#26/09/06 Warren
#relocated pre_button_bottomtext to bottom of table

#19/09/06 Warren
#added bottomtext and pre_button_bottomtext

#04/08/06 Warren
#Fix bug with date not handling compulsory settings

#04/08/06 Warren
#Added date and time dropdown /selection types
#added in suppport for yahoo's yui calendar picker

#05/06/06 Warren
# Added onclick event to disable the submit button when pressed, in the hope of reducing some double click errors.

#06/03/06 Warren
# Make noedit, noadd not compulsory if not displayed.
# As with readonly not compulsory if not displayed.
#
#20/02/06 Warren
# Fixed problem with addonly option resetting values on edit
#

#31/01/06 Warren
#Added overridue option for order in process values
#to handle problem with resetting no displayed checkboxes

#21/12/05 Warren
# Added pretext/posttext options
# Added disabled option
# Don't display field in label = ''

# 04/03/14
#Save_readonly :: If added to the field hash then  read only file will be able to save, although it wont be editable by user
1;

# vim: set et sw=4 ts=4:
