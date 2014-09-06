#
# $Header: svn://svn/SWM/trunk/web/ReportOptions.pm 8361 2013-04-23 03:58:27Z cgao $
#

package ReportOptions;
require Exporter;
@ISA = qw(Exporter);
@EXPORT=qw(displayOptions process_submission displaybox_js showreport genSelect);
@EXPORT_OK=qw(displayOptions process_submission displaybox_js showreport genSelect);

use strict;
use FormHelpers;
use lib 'Reports';
use ReportEmail;
use Utils;

#Version : 1.53
#Last Modified : 21/04/2009

# This Module Requires FormHelpers.pm and ReportEmail.pm

# Fields Hash
	#fieldname => [Display Name, Type Display, Type Field];

			#Field Type text,  number date - The display in the filter areas
			#Display Type textbox, date - The displaay in the actual report
sub displayOptions	{

	my($FieldDefinitions, $prefix, $perms_ref, $formname, $langref)=@_;

	$prefix||='';
	$prefix.='_' if $prefix;
	$formname||='updateform';
	my $fields_ref=$FieldDefinitions->{'fields'};
	my $order_ref=$FieldDefinitions->{'order'};

	my $returnstr='';
	my @sort=();
	my @grouping=();
	my $lastoptiongroup='';
	for my $i (0 .. $#$order_ref)	{
		my $field_name=$order_ref->[$i] || '';
		my $linestr='';
		next if !$field_name;
		next if ($perms_ref and exists $perms_ref->{$field_name} and !$perms_ref->{$field_name});
		#if(!exists $fields_ref->{$field_name})	{print STDERR " ERROR: Cannot find $field_name\n";next;}
		if(!exists $fields_ref->{$field_name})	{next;}

		my ($displayname, $options)=@{$fields_ref->{$field_name}};
		next if !$displayname;
    $displayname = _langlookup($displayname, $langref);

		next if $options->{'disable'};
		my $def_val1=(defined $options->{'defaultvalue'} and $options->{'defaultvalue'} ne '') ?  $options->{'defaultvalue'} : '';
		my $def_val2=(defined $options->{'defaultvalue2'} and $options->{'defaultvalue2'} ne '') ?  $options->{'defaultvalue2'} : '';
		my $displ_1= $def_val1 ne ''? 'block' : 'none';
		my $displ_2= $def_val2 ne ''? 'block' : 'none';
		if($options->{'fieldtype'} eq 'text')	{
			$linestr.=qq[<div id="d1_$prefix$field_name" style="display:$displ_1;">].txt_field($field_name.'_1',$def_val1,$options->{'size'}||20,80)."</div>";
			$linestr.=qq[<div id="d2_$prefix$field_name" style="display:$displ_2;"> and ].txt_field($field_name.'_2',$def_val2,$options->{'size'}||20,80)."</div>";
		}
		if($options->{'fieldtype'} eq 'dropdown')	{
			$linestr.=qq[<div id="d1_$prefix$field_name" style="display:$displ_1;">].drop_down($field_name.'_1',$options->{'dropdownoptions'}, $options->{'dropdownorder'}, $def_val1, $options->{'size'} || 1, $options->{'multiple'}||0)."</div>";
			$linestr.=qq[<div id="d2_$prefix$field_name" style="display:$displ_2;"></div>];
		}
		if($options->{'fieldtype'} eq 'date' or $options->{'fieldtype'} eq 'datetime')	{
			my $fname=$field_name.'_1';
			$linestr.=qq[<div id="d1_$prefix$field_name" style="display:$displ_1;">].txt_field($fname,$def_val1,10,10).qq[<a href="#" onClick="cal.showCalendar('$fname','$formname'); return false;" NAME="$fname" ID="$fname"><img src="images/calendar.gif" border="0" alt="Choose Date"></a><i>(dd/mm/yyyy)</i></div>];
			$fname=$field_name.'_2';
			$linestr.=qq[<div id="d2_$prefix$field_name" style="display:$displ_2;"> and ].txt_field($fname,$def_val2,10,10).qq[<a href="#" onClick="cal.showCalendar('$fname','$formname'); return false;" NAME="$fname" ID="$fname"><img src="images/calendar.gif" border="0" alt="Choose Date"></a><i>(dd/mm/yyyy)</i></div>];
		}
		if($options->{'fieldtype'} eq 'none')	{
			$linestr='';	
		}
		my $comp_options='';
        if ($options->{'fieldtype'}) {
            $comp_options = compare_options(
                $field_name,
                $prefix,
                $options->{'fieldtype'},
                $options->{'defaultcomp'},
                $options->{'multiple'} || 0,
                $langref,
            );
        }
		
		my $active='';
		$active=' CHECKED ' if $options->{'active'};
		my $optiongroup=$options->{'optiongroup'} || '';
		if($lastoptiongroup ne $optiongroup)	{
				$returnstr.="</tbody>\n" if $lastoptiongroup ne '';
				next if $FieldDefinitions->{'optiongroups'}{$optiongroup}[1]{'disable'};
				$lastoptiongroup=$optiongroup;
				if($optiongroup ne '')	{
					my $activegrp=$FieldDefinitions->{'optiongroups'}{$optiongroup}[1]{'active'} ? ' style="display:table-row-group;" ' : '';
					my $linkopenclass= $activegrp ? ' folderopen ' : '';

					$returnstr .= <<"EOS";
<tr>
  <td colspan="3">
    <div class="ROoptgroupH">
      <a href="#" onclick="togglegroup('optg$prefix$optiongroup', this);return false;" class="$linkopenclass">
EOS
                    $returnstr .= _langlookup($FieldDefinitions->{'optiongroups'}{$optiongroup}[0], $langref);

					$returnstr .= <<"EOS";
... <span class="ROexpandtext"> (
EOS
                    $returnstr .= _langlookup('Click to Open/Close Group', $langref);

					$returnstr .= <<"EOS";
 )</span></a></div></td></tr>\n<tbody id="optg$prefix$optiongroup" class="ROoptgroup" $activegrp>
EOS
				}
		}
		my $test=$optiongroup ne '' ? ' style="display:none;" ' : '';

		my $nclass    = q{};
		my $fonlytext = q{};

		if (defined $options->{'filteronly'} and $options->{'filteronly'}) {
            $nclass = 'class="ROfonly"';

            $fonlytext
                = ' [<i>' . _langlookup('Filter Only', $langref) . '</i>] ';
        }

		$returnstr.=qq[
			<tr >
				<td><input type="checkbox" name="chk_$field_name" value="1" class="ROnb" $active></td>
				<td $nclass>$displayname$fonlytext</td>
				<td>$comp_options</td>
				<td>$linestr</td>
			</tr>
		];
		if(exists $options->{'allowsort'} and $options->{'allowsort'})	{
			push @sort, $field_name;
		}	
		if(exists $options->{'allowgrouping'} and $options->{'allowgrouping'})	{
			push @grouping, $field_name;
		}	
	}
	$returnstr.="</tbody>\n" if $lastoptiongroup ne '';
	$returnstr.=qq[</table>];

	if ($FieldDefinitions->{'config'}{'RunButtonLabel'}) {

        my $run_button_label = _langlookup(
            $FieldDefinitions->{'config'}{'RunButtonLabel'}, $langref
        );

        $returnstr.=qq[
			<div class="ROrunButton"><input type="submit" value="$run_button_label"></div>
        ];
    }
	if (
        not exists $FieldDefinitions->{'config'}{'ShowDistinct'}
        or (exists  $FieldDefinitions->{'config'}{'ShowDistinct'}
            and  $FieldDefinitions->{'config'}{'ShowDistinct'} == 1)
    ) {

        my @record_filter_options = (
            [ 'DISTINCT', 'Unique Records Only' ],

            (
                $FieldDefinitions->{'config'}{'NoSummaryData'}
                    ? ()
                    : ( [ 'SUMMARY', 'Summary Data' ] )
            ),

            [ 'ALL', 'All Records' ],
        );

        my $record_filter_options = join(
            q{},
            map {
                join(
                    q{},
                    "<option value='",
                    $_->[0],
                    "'>",
                    _langlookup($_->[1], $langref),
                    '</option>',
                )
            } @record_filter_options
        );

        my $options_header = _langlookup('Options', $langref);
        my $show_label     = _langlookup('Show', $langref);

        $returnstr.=qq[
            <fieldset class="RO_roptions">
                <legend>$options_header</legend>
            <table>
                <tr>
                    <td> <b>$show_label</b></td>
                    <td>
                    <select name="RO_RecordFilter" size="1">
                        $record_filter_options
                    </select>
                    </td>
                </tr>
        ];
    }
    
	if(@sort)	{

        my $sort_by_label           = _langlookup('Sort By', $langref);
        my $secondary_sort_by_label = _langlookup('Secondary Sort By', $langref);
        my $ascending_option        = _langlookup('Ascending', $langref);
        my $descending_option       = _langlookup('Descending', $langref);
        my $none_option             = _langlookup('None', $langref);

		my $sort=qq[
		<tr><td> <b>$sort_by_label</b></td>
				<td><select name="sortby" size="1">
		];
		for my $field (@sort)	{
            my $option = _langlookup($fields_ref->{$field}[0], $langref);
            $sort.=qq[<option value="$field">$option</option>];
		}
		$sort.=qq[
			</select>
			&nbsp;
			<select name="sortbydir" size="1">
				<option value="ASC">$ascending_option</option>
				<option value="DESC">$descending_option</option>
			</select>
				</td>
			</tr>
		];
		if(exists $FieldDefinitions->{'config'}{'SecondarySort'} and  $FieldDefinitions->{'config'}{'SecondarySort'} == 1)	{
			$sort.=qq[
			<tr><td><b>$secondary_sort_by_label</b></td>
				<td><select name="sortby2" size="1">
					<option value="">$none_option</option>
			];
			for my $field (@sort)	{
                my $option = _langlookup($fields_ref->{$field}[0], $langref);
                $sort.=qq[<option value="$field">$option</option>];
			}
			$sort.=qq[
				</select>
				&nbsp;
				<select name="sortbydir2" size="1">
					<option value="ASC">$ascending_option</option>
					<option value="DESC">$descending_option</option>
				</select>
				</td>
			 </tr>
			];
		}
		$returnstr.=$sort || '';
	}

    my $limit_header    = _langlookup('Limit', $langref);
    my $no_limit_option = _langlookup('No Limit', $langref);
    my $group_by_label = _langlookup('Group By', $langref);

    my $max_rows_message
        = _langlookup('Maximum no. of rows to display', $langref);

	$returnstr.=qq[
		<tr>
			<td><b>$limit_header</b></td>
			<td>
        <select name="limit" size="1">
          <option value="">$no_limit_option</option>
          <option value="50">50</option>
          <option value="100">100</option>
          <option value="500">500</option>
          <option value="1000">1000</option>
          <option value="2000">2000</option>
		</select> <i>($max_rows_message)</i>
			</td>
		</tr>
	];

	if(@grouping)	{
		$returnstr.=qq[
		<tr>
			<td><b>$group_by_label</b></td>
			<td><select name="groupby" size="1">
					<option value="">]._langlookup('No Grouping', $langref).qq[</option>
		];
		for my $field (@grouping)	{
			$returnstr.=qq[<option value="$field">]._langlookup($fields_ref->{$field}[0], $langref).qq[</option>];
		}
		$returnstr.=qq[
				</select>
			</td>
		</tr>	
		];
	}
	$returnstr.='</table></fieldset>';

	if($FieldDefinitions->{'config'}{'EmailExport'})	{

        my $report_output      = _langlookup('Report Output', $langref);
        my $choose_how_reports = _langlookup('CHOOSE_HOW_REPORTS',  $langref);
        my $display            = _langlookup('Display', $langref);
        my $display_report     = _langlookup('DISPLAY_REPORT', $langref);
        my $email_report       = _langlookup('EMAIL_REPORT', $langref);
        my $email              = _langlookup('Email', $langref);
        my $email_address      = _langlookup('Email Address', $langref);

		$returnstr.=qq[
			<fieldset class="ROReportFormat">
            <legend>$report_output</legend>
				<div style="margin-left:20px;">
                    $choose_how_reports

					<div style="padding:5px;">
                        <input
                          type="radio"
                          name="viewtype"
                          value="screen"
                          class="ROnb"
                          checked
                        >
                        <b>$display</b>
						<div style="margin-left:20px;">
                            <i>$display_report</i>
						</div>
					</div>
					<div style="padding:5px;">
                        <input
                          type="radio"
                          name="viewtype"
                          value="email"
                          class="ROnb"
                        >
                        <b>$email</b>
						<div style="margin-left:20px;">
                            <i>$email_report</i><br>
                            <b>$email_address</b>
                            <input type="text" size="45" name="exemail">
						</div>
					</div>
			</div>
		];
		if($FieldDefinitions->{'ExportFormats'})	{

            my $choose_export_format
                = _langlookup('CHOOSE_EXPORT_FORMAT', $langref);

            my $export_warning
                = _langlookup('EXPORT_WARNING', $langref);

            my $normal_tab_delimited
                = _langlookup('Normal (Tab Delimited)', $langref);

			my $ef=$FieldDefinitions->{'ExportFormats'};
			my $options='';
			for my $key (sort { $ef->{$a}{'Name'} cmp $ef->{$b}{'Name'}}  keys %{$ef})	{
				my $warning = $ef->{$key}{'Select'} ? 'W_' : '' ;

                my $export_format
                    = _langlookup($ef->{$key}{'Name'}, $langref);

                $options .=
                    qq[<option value="$warning$key">$export_format</option>];
			}
			$returnstr.=qq[
				<div style="margin-left:20px;">
                    <i>$choose_export_format</i><br>
		<script language="JavaScript" type="text/javascript">
		//<!-- HIDE
					
      function exportwarning(field)  {
          selectedoption= field.options[field.selectedIndex].value;
					if (selectedoption.substr(0,2) == 'W_')	{
                        alert('$export_warning');
					}
			}

		//-->
		</script>
					<select name="exformat" size="1" onchange="exportwarning(this);">
                        <option value="">$normal_tab_delimited</option>
						$options
					</select>
				</div>
			];
		}
		$returnstr.=qq[
			</fieldset>
		];
	}

    if ($FieldDefinitions->{'config'}{'RunButtonLabel'}) {

        my $run_button_label = _langlookup(
            $FieldDefinitions->{'config'}{'RunButtonLabel'},
            $langref,
        );

        $returnstr.=qq[
            <div class="ROrunButton">
              <input type="submit" value="$run_button_label">
            </div>
        ];
    }
  if($FieldDefinitions->{'SavedReports'}) 	{

        my $remembered_report  = _langlookup('Saved Report', $langref);
        my $remembered_reports = _langlookup('Saved Reports', $langref);
        my $remember_report_as = _langlookup('Save Report as', $langref);
		$returnstr.=qq[ 
			<fieldset class="ROsavedreports">
                    <legend>$remembered_reports</legend>
				<div>
		];
		if($FieldDefinitions->{'SavedReports'}{'sql_add'})  {
            $returnstr.=qq[
                <input
                  type="submit"
                  name="savereport"
                  value="$remember_report_as"
                  onclick="form.target='';"
                >
                <input type="text" size="30" name="RO_savedreportname">
                <br>
			];
		}
		if($FieldDefinitions->{'SavedReports'}{'ReportList'})  {
			my $saved_reports=drop_down('runreportlist',$FieldDefinitions->{'SavedReports'}{'ReportList'}, '',1, 0);
			$returnstr.=qq[
                <input type="submit" name="runsavereport" value="Run">
                <input
                  type="submit"
                  name="deletesavereport"
                  value="Forget"
                  onclick="form.target='';"
                >
                $remembered_report
                $saved_reports
			];
		}
		$returnstr.=qq[ </div></fieldset> ];
	}
	if($returnstr)	{

        my $show   = _langlookup('Show',   $langref);
        my $field  = _langlookup('Field',  $langref);
        my $filter = _langlookup('Filter', $langref);

		$returnstr=qq[
		<table class="ROtable">
			<tr>
                <th>$show</th>
                <th>$field</th>
                <th>$filter</th>
				<th>&nbsp;</th>
			</tr>
			$returnstr
		];
	}

	return $returnstr;

}


sub process_submission	{
	my($params, $FieldDefinitions, $db)=@_;

	my $fields_ref = $FieldDefinitions->{'fields'};
	my $order_ref = $FieldDefinitions->{'order'};

	my %activefields=();
	my $wherelist='';
	my $havinglist='';
	my %activeFromlist=();
	my @activeFromlist=();
	my %activeWherelist=();
	if($params->{'savereport'})	{
		SaveReport($params, $FieldDefinitions, $db, \%activefields);
	}
	if($params->{'runsavereport'} and $params->{'runreportlist'})	{
		LoadReport($params, $FieldDefinitions, $db);
	}
	if($params->{'deletesavereport'} and $params->{'runreportlist'})	{
		DeleteReport($params, $FieldDefinitions, $db, \%activefields);
	}
	for my $fieldname (@{$order_ref})	{
		next if !exists $fields_ref->{$fieldname};
       # next if $fieldname eq 'AwardPWD';
		my $usehaving = $fields_ref->{$fieldname}[1]{'usehaving'} || 0;
		if((exists $params->{'chk_'.$fieldname} and $params->{'chk_'.$fieldname})
			or $params->{'comp_'.$fieldname})	{
			if(exists $params->{'chk_'.$fieldname} and $params->{'chk_'.$fieldname})	{
				#Field is active
				$activefields{$fieldname}=1;
			}
			if(exists $fields_ref->{$fieldname}[1]{'filteronly'} and $fields_ref->{$fieldname}[1]{'filteronly'})	{
				delete $activefields{$fieldname};
			}
			my $DBfieldname=$fieldname;
			if(exists $fields_ref->{$fieldname}[1]{'dbfield'} and $fields_ref->{$fieldname}[1]{'dbfield'})	{
				$DBfieldname=$fields_ref->{$fieldname}[1]{'dbfield'} 
			}
			my $op=$params->{'comp_'.$fieldname} || '';
			my $val1=(defined $params->{$fieldname.'_1'} and $params->{$fieldname.'_1'} ne '') ?  $params->{$fieldname.'_1'} : '';
			my $val2=(defined $params->{$fieldname.'_2'} and $params->{$fieldname.'_2'} ne '') ?  $params->{$fieldname.'_2'} : '';

			if( $fields_ref->{$fieldname}[1]{'fieldtype'} eq 'date')	{
				$val1= fixDate($val1) if $val1;
				$val2= fixDate($val2) if $val2;
				#$val2=~ s/(\d{1,2})\/(\d{1,2})\/(\d{4})/$3-$2-$1/ if $val2;
			}
			if( $fields_ref->{$fieldname}[1]{'fieldtype'} eq 'datetime')    {
                                $val1= fixDate($val1) if $val1;
                                $val2= fixDate($val2) if $val2;
				if ($val2)	{
                                	$val2 = "$val2 23:59:59";
				}
				else	{
                                	$val2 = "$val1 23:59:59" if $val1;
				}
                                $val1 = "$val1 00:00:00" if $val1;
                                $op = 'between' if ($op eq 'equal');
                        }
			if($op eq 'between' and $val1 ne '' and $val2 ne '')	{
				if($usehaving)	{
					$havinglist.=qq[ AND ] if $havinglist;
				}
				else	{
					$wherelist.=qq[ AND ] if $wherelist;
				}
				$val1=deQuote($db,$val1);
				$val2=deQuote($db,$val2);
				if($usehaving)	{
					$havinglist.=qq[ $DBfieldname >= $val1  AND $DBfieldname <= $val2];	
				}
				else	{
					$wherelist.=qq[ $DBfieldname >= $val1  AND $DBfieldname <= $val2];	
				}
			}
			elsif($op) {
				my $opsym='';
				$opsym= '=' if $op eq 'equal';
				$opsym= '<>' if $op eq 'notequal';
				$opsym= '>' if $op eq 'morethan';
				$opsym= '<' if $op eq 'lessthan';
				$opsym= '=' if $op eq 'isblank';
				$opsym= '<>' if $op eq 'isnotblank';
				$opsym= ' like ' if $op eq 'like';
				if($op eq 'isblank'	 or $op eq 'isnotblank')	{ $val1=$val2='BLANK'; }
				if($op eq 'equal' and $val1=~/\((.*,.*)\)/)	{ $val1=join("\0",split /,/,$1); }
				if($op eq 'like')	{$val1=~s/\*/%/g;	}
				next if !$opsym;
				if($usehaving)	{
					$havinglist.=' AND ' if $havinglist;
				}
				else	{
					$wherelist.=' AND ' if $wherelist;
				}
				my @v=split("\0",$val1);
				my $vline='';
				for my $v (@v)	{
          $vline.=' OR ' if($vline and $op ne 'notequal');
          $vline.=' AND ' if($vline and $op eq 'notequal') ;
					$v=deQuote($db,$v);
					if($fields_ref->{$fieldname}[1]{'dbwherefieldalias'})	{
						$vline.="( $DBfieldname $opsym $v ";
						my $i=0;
						while($i < $#{$fields_ref->{$fieldname}[1]{'dbwherefieldalias'}})	{
							my $joiner=$fields_ref->{$fieldname}[1]{'dbwherefieldalias'}[$i];
							my $fnme=$fields_ref->{$fieldname}[1]{'dbwherefieldalias'}[$i+1];
							$vline.=" $joiner $fnme $opsym $v ";
							$i+=2;
						}
						$vline.=")";
					}
					else	{
						if($op eq 'isblank')	{ $vline.=" ($DBfieldname='' OR $DBfieldname IS NULL) "; }
						elsif($op eq 'isnotblank')	{ $vline.=" ($DBfieldname <>'' AND $DBfieldname IS NOT NULL) "; }
						else	{ $vline.=" $DBfieldname $opsym $v ";	}
					}
				}
				$vline="($vline)" if @v >1;
				if($usehaving)	{
					$havinglist.=$vline;
				}
				else	{
					$wherelist.=$vline;
				}
			}
			#Check to see if we have to add tables or join conditions
			if(exists $fields_ref->{$fieldname}[1]{'dbfrom'} and $fields_ref->{$fieldname}[1]{'dbfrom'})	{
				if(ref $fields_ref->{$fieldname}[1]{'dbfrom'})	{
					#Array of dbfroms
					for my $f (@{$fields_ref->{$fieldname}[1]{'dbfrom'}})	{ 
						push @activeFromlist, $f if !$activeFromlist{$f}; 
						$activeFromlist{$f}=1; 
					}
				}
				else	{ 
					push @activeFromlist, $fields_ref->{$fieldname}[1]{'dbfrom'} if !$activeFromlist{$fields_ref->{$fieldname}[1]{'dbfrom'}}; 
					$activeFromlist{$fields_ref->{$fieldname}[1]{'dbfrom'}}=1; 
				}
			}
			if(exists $fields_ref->{$fieldname}[1]{'dbwhere'} and $fields_ref->{$fieldname}[1]{'dbwhere'})	{
				$activeWherelist{$fields_ref->{$fieldname}[1]{'dbwhere'}}=1; 
			}
			if(exists $fields_ref->{$fieldname}[1]{'optiongroup'} and $fields_ref->{$fieldname}[1]{'optiongroup'})	{
				if(exists $FieldDefinitions->{'optiongroups'} and exists $FieldDefinitions->{'optiongroups'}{$fields_ref->{$fieldname}[1]{'optiongroup'}} and $FieldDefinitions->{'optiongroups'}{$fields_ref->{$fieldname}[1]{'optiongroup'}}[1] )	{
					my $group_options=$FieldDefinitions->{'optiongroups'}{$fields_ref->{$fieldname}[1]{'optiongroup'}}[1];
					if($group_options and exists $group_options->{'from'} and $group_options->{'from'})	{

						if(ref $group_options->{'from'})	{
							#Array of dbfroms
							for my $g (@{$group_options->{'from'}})	{ 
								push @activeFromlist, $g if !$activeFromlist{$g}; 
								$activeFromlist{$g}=1; 
							}
						}
						else	{ 	
							push @activeFromlist, $group_options->{'from'} if !$activeFromlist{$group_options->{'from'}}; 
							$activeFromlist{$group_options->{'from'}}=1; 
						}
					}
					if($group_options and exists $group_options->{'where'} and $group_options->{'where'})	{
						$activeWherelist{$group_options->{'where'}}=1; 
					}
				}
			}
		}
	}
	my $sortby_field=$params->{'sortby'} || '';
	my $sortby=$params->{'sortby'} || '';
	if(exists $fields_ref->{$sortby_field}[1]{'dbfield'} and $fields_ref->{$sortby_field}[1]{'dbfield'})	{
		$sortby=$fields_ref->{$sortby_field}[1]{'dbfield'};
	}
	if(exists $fields_ref->{$sortby_field}[1]{'sortfield'} and $fields_ref->{$sortby_field}[1]{'sortfield'} ne '')	{
		$sortby=$fields_ref->{$sortby_field}[1]{'sortfield'};
	}
	if(!$activefields{$sortby_field})	{
		if(exists $fields_ref->{$sortby_field}[1]{'dbfrom'} and $fields_ref->{$sortby_field}[1]{'dbfrom'})	{
			if(ref $fields_ref->{$sortby_field}[1]{'dbfrom'})	{
				#Array of dbfroms
				for my $f (@{$fields_ref->{$sortby_field}[1]{'dbfrom'}})	{ 
					push @activeFromlist, $f if !$activeFromlist{$f}; 
					$activeFromlist{$f}=1; 
				}
			}
			else	{ 
				push @activeFromlist,  $fields_ref->{$sortby_field}[1]{'dbfrom'} if !$activeFromlist{$fields_ref->{$sortby_field}[1]{'dbfrom'}}; 
				$activeFromlist{$fields_ref->{$sortby_field}[1]{'dbfrom'}}=1; 
			}
		}
		if(exists $fields_ref->{$sortby_field}[1]{'dbwhere'} and $fields_ref->{$sortby_field}[1]{'dbwhere'})	{
			$activeWherelist{$fields_ref->{$sortby_field}[1]{'dbwhere'}}=1; 
		}
	}
	$sortby.=' '.$params->{'sortbydir'} || 'ASC';
	if(exists $FieldDefinitions->{'config'}{'SecondarySort'} and  $FieldDefinitions->{'config'}{'SecondarySort'} == 1)	{
		my $sortby2_field=$params->{'sortby2'} || '';
		my $sortby2=$params->{'sortby2'} || '';
		if(exists $fields_ref->{$sortby2_field}[1]{'dbfield'} and $fields_ref->{$sortby2_field}[1]{'dbfield'})	{
			$sortby2=$fields_ref->{$sortby2_field}[1]{'dbfield'};
		}
		if(exists $fields_ref->{$sortby2_field}[1]{'sortfield'} and $fields_ref->{$sortby2_field}[1]{'sortfield'} ne '')	{
			$sortby2=$fields_ref->{$sortby2_field}[1]{'sortfield'};
		}
		$sortby.=", $sortby2 ".($params->{'sortbydir2'} || 'ASC') if $sortby2;
		if(!$activefields{$sortby2_field})	{
			if(exists $fields_ref->{$sortby2_field}[1]{'dbfrom'} and $fields_ref->{$sortby2_field}[1]{'dbfrom'})	{
				if(ref $fields_ref->{$sortby2_field}[1]{'dbfrom'})	{
					#Array of dbfroms
					for my $f (@{$fields_ref->{$sortby2_field}[1]{'dbfrom'}})	{ 
						push @activeFromlist, $f if !$activeFromlist{$f}; 
						$activeFromlist{$f}=1; 
					}
				}
				else	{
					push @activeFromlist, $fields_ref->{$sortby2_field}[1]{'dbfrom'} if !$activeFromlist{$fields_ref->{$sortby2_field}[1]{'dbfrom'}}; 
					$activeFromlist{$fields_ref->{$sortby2_field}[1]{'dbfrom'}}=1; 
				}
			}
			if(exists $fields_ref->{$sortby2_field}[1]{'dbwhere'} and $fields_ref->{$sortby2_field}[1]{'dbwhere'})	{
				$activeWherelist{$fields_ref->{$sortby2_field}[1]{'dbwhere'}}=1; 
			}
		}
	}

	$activefields{'RO_RecordFilter'}= $params->{'RO_RecordFilter'} || 'DISTINCT';
	$activefields{'RO_RecordFilter'}= 'DISTINCT' if $activefields{'DISTINCT'};
	$activefields{'DISTINCT'} = $activefields{'RO_RecordFilter'} eq 'DISTINCT' ? ' DISTINCT ' : '';;
	$activefields{'viewtype'}= $params->{'viewtype'} || '';
	$activefields{'exemail'}= $params->{'exemail'} || '';
	$activefields{'exformat'}= $params->{'exformat'} || '';
	$activefields{'limit'}= $params->{'limit'} || '';
	$activefields{'exformat'}=~s/^W_//;
	if($activefields{'exformat'} and $activefields{'viewtype'} eq 'email')	{
		my $f=$FieldDefinitions->{'ExportFormats'}{$activefields{'exformat'}}{'From'} || '';
		push @activeFromlist, $f if !$activeFromlist{$f};
		$activeFromlist{$f}=1;
	}
	$activefields{'groupby'}= $params->{'groupby'} || '';
	if($activefields{'groupby'})	{
		my $groupbysortcol =$fields_ref->{$activefields{'groupby'}}[1]{'sortfield'} 
			? $fields_ref->{$activefields{'groupby'}}[1]{'sortfield'} 
			: $activefields{'groupby'} ; 
		$sortby= " $groupbysortcol ASC, $sortby";

		if(!$activefields{$activefields{'groupby'}})	{
			$activefields{$activefields{'groupby'}}=1;
			my $f=$activefields{'groupby'};
			if(exists $fields_ref->{$f}[1]{'dbfrom'} and $fields_ref->{$f}[1]{'dbfrom'})	{
				if(ref $fields_ref->{$f}[1]{'dbfrom'})	{
					#Array of dbfroms
					for my $g (@{$fields_ref->{$f}[1]{'dbfrom'}})	{ 
						push @activeFromlist, $g if !$activeFromlist{$g}; 
						$activeFromlist{$g}=1; 
					}
				}
				else	{
					push @activeFromlist, $fields_ref->{$f}[1]{'dbfrom'} if !$activeFromlist{$fields_ref->{$f}[1]{'dbfrom'}}; 
					$activeFromlist{$fields_ref->{$f}[1]{'dbfrom'}}=1; 
				}
			}
			if(exists $fields_ref->{$f}[1]{'dbwhere'} and $fields_ref->{$f}[1]{'dbwhere'})	{
				$activeWherelist{$fields_ref->{$f}[1]{'dbwhere'}}=1; 
			}
		}	
	}
	my $fromlist=join(' ',@activeFromlist) || '';
	my $actWherelist=join(' ',keys %activeWherelist);
	$wherelist.=$actWherelist || '';
	# Check for other values to be passed through
	for my $k (keys %{$params})	{
		$activefields{$k} = $params->{$k} if $k=~/^_EXT/;
	}
	return (\%activefields, $wherelist, $sortby, $fromlist, $havinglist);
}


sub compare_options	{

    my($fieldname, $prefix, $fieldtype, $value, $multiple, $langref) = @_;

	$prefix||='';
	$value||='';

	my $subBody=qq[
	<select name="comp_$fieldname" size="1" onchange="displaybox(this, '$prefix$fieldname');">
		<option value="">&nbsp;</option>
	];
	my @options=();
	push @options,['isblank','Is Blank'];
	push @options,['isnotblank','Is Not Blank'];
	if($fieldtype ne 'none')	{
		push @options,['equal','Equals'];
		push @options,['notequal','Not Equals'];
	}
	if($fieldtype ne 'none' and $fieldtype ne 'dropdown')	{
		push @options,['like','Like'];
	}

	if (!$multiple and ($fieldtype eq 'text' or $fieldtype eq 'date' or $fieldtype eq 'datetime'))	{
		push @options,['lessthan','Less Than'];
		push @options,['morethan','More Than'];
		push @options,['between','Between'];
	}
	for my $i (@options)	{
		my $selected=$value eq $i->[0] ? ' SELECTED ' : '';
        my $label = _langlookup($i->[1], $langref);
        $subBody.=qq[<option $selected value="$i->[0]">$label</option>\n];
	}

	$subBody.=qq[
	</select>
	];
}


sub displaybox_js	{
	return qq~

		<script language="JavaScript" type="text/javascript" src="js/AnchorPosition.js"></script>
		<script language="JavaScript" type="text/javascript" src="js/PopupWindow.js"></script>
		<script language="JavaScript" type="text/javascript" src="js/CalendarPopup.js"></script>
		<script language="JavaScript" type="text/javascript">
		<!-- HIDE

			// Create CalendarPopup objects
			var cal = new CalendarPopup();
			cal.setReturnFunction("showDate");

			// Function to get input back from calendar popup
			function showDate(y,m,d, anchorname,formname) {
				document[formname][anchorname].value = d + "/" + m + "/" + y;
			}

			function displaybox(line, fieldname)	{
					selectedoption= line.options[line.selectedIndex].value;
					switch(selectedoption)	{
						case "": 
						case "isnotblank": 
						case "isblank": 
							document.getElementById("d1_"+fieldname).style.display="none";
							document.getElementById("d2_"+fieldname).style.display="none";
							break;
						case "between": 
							document.getElementById("d1_"+fieldname).style.display="inline";
							document.getElementById("d2_"+fieldname).style.display="inline";
							break;
						default:
							document.getElementById("d1_"+fieldname).style.display="inline";
							if(document.getElementById("d2_"+fieldname))	{
								document.getElementById("d2_"+fieldname).style.display="none";
							}
					}
      }
			function togglegroup(name, linkthis)	{
				//Allow for differences between IE/ Mozilla. Standards !!
				var displayStyle = document.defaultView ? "table-row-group" : "block"; 
				if (document.getElementById(name).style.display != displayStyle) {
						document.getElementById(name).style.display = displayStyle;
						linkthis.style.background = 'url(images/folder-open.gif) no-repeat';
				}
				else {
						document.getElementById(name).style.display = 'none';
						linkthis.style.background = 'url(images/folder.gif) no-repeat';
				}
			}
		// STOP HIDING -->
		</script>
	~;
}


sub genSelect	{
  my($FieldDefinitions, $activefields)=@_;

	my $select_vals='';
	my $groupby_vals='';
	my %selected_values=();
  my $emaildata= $activefields->{'viewtype'} eq 'email' ? 1 : 0;
  my $retprocessdata= ($activefields->{'viewtype'} eq 'returnprocessdata' and $FieldDefinitions->{'config'}{'ReturnProcessData'}) ? 1 : 0;
	if($emaildata and $activefields->{'exformat'} and $FieldDefinitions->{'ExportFormats'}{$activefields->{'exformat'}}{'Select'})	{
		return $FieldDefinitions->{'ExportFormats'}{$activefields->{'exformat'}}{'Select'};
	}
	for my $field (@{$FieldDefinitions->{order}})	{
		if($activefields->{$field})	{
			next if !exists $FieldDefinitions->{'fields'}{$field};
			next if(exists $FieldDefinitions->{'fields'}{$field}[1]{'dbfield'}  and !defined $FieldDefinitions->{'fields'}{$field}[1]{'dbfield'} );
			$select_vals.=', ' if $select_vals ne '';
			if($FieldDefinitions->{'fields'}{$field}[1]{'dbformat'} )	{
				$select_vals.=$FieldDefinitions->{'fields'}{$field}[1]{'dbformat'} . " AS $field";
			}
			elsif($FieldDefinitions->{'fields'}{$field}[1]{'dbfield'} )	{
				$select_vals.=$FieldDefinitions->{'fields'}{$field}[1]{'dbfield'}. " AS $field"; 
			}
			else	{ $select_vals.=$field; }
			$selected_values{$field}=1;
			if($activefields->{'RO_RecordFilter'} eq 'SUMMARY')	{ #Summarise Records
				$groupby_vals .= $groupby_vals ? ", $field " : $field;
			}
		}	
	}
	if($activefields->{'RO_RecordFilter'} eq 'SUMMARY')	{ #Summarise Records
		$select_vals.=', SUM(1) AS RO_SUM';
	}
	if($retprocessdata)	{
		#If we are supposed to return process data - make sure we have all the fields required. 
		#We are not writing the select line, as it may affect the grouping and distincts
		for my $i (@{$FieldDefinitions->{'config'}{'ReturnProcessData'}})	{
			if(!exists $selected_values{$i})	{
				$select_vals.=', ' if $select_vals ne '';
				$select_vals.=$i; 
				$selected_values{$i}=1;
			}
		}
	}
	# We have handle the normal values lets loop through and see if we need to generate links for any of the active fields.  If so, do we have all the fields we need.
	for my $key (keys %{$FieldDefinitions->{'links'}})	{
		if($activefields->{$key})	{
			for my $otherfield (@{$FieldDefinitions->{'links'}{$key}[1]})	{
				if(!exists $selected_values{$otherfield})	{
					$select_vals.=', ' if $select_vals ne '';
					if($FieldDefinitions->{'fields'}{$otherfield}[1]{'dbfield'} )	{
						$select_vals.=$FieldDefinitions->{'fields'}{$otherfield}[1]{'dbfield'}. " AS $otherfield"; 
					}
					else	{ $select_vals.=$otherfield; }
					$selected_values{$otherfield}=1;
				}
			}
		}
	}
	return ($select_vals, $groupby_vals) if wantarray;
	return $select_vals;
}

sub showreport  {
  my($db, $statement, $FieldDefinitions, $activefields)=@_;
  
	$statement.="\nLIMIT $activefields->{limit}" if $activefields->{limit};
  my $query = $db->prepare($statement) or ROquery_error($statement);
  $query->execute or ROquery_error($statement);
  my $report='';
  my $count=0;
	my %totals=();
	my @line=();
	my @report=();
	my $emaildata= $activefields->{'viewtype'} eq 'email' ? 1 : 0;
	my $retdata= $activefields->{'viewtype'} eq 'returnprocessdata' ? 1 : 0;
	my $lastgroupline='';
	my $lastfield='';
	my $numfieldsinuse=0;
	my @DataToProcess=();
	my %processfields=();
	if($retdata and $FieldDefinitions->{'config'}{'ReturnProcessData'})	{
		for my $i (@{$FieldDefinitions->{'config'}{'ReturnProcessData'}})	{
			my $j=$i;
			$j=~s/.*\.//g;
			$processfields{$j}=1;
			$activefields->{$j}=1;
		}
	}
	if(exists $activefields->{'SavedReports'})	{
		if($activefields->{'SavedReports'}==1)	{
			return 'Report Saved Successfully';
		}
		elsif($activefields->{'SavedReports'}==-1)	{
			return 'Report unable to be saved';
		}
	}
 	if(exists $activefields->{'DeletedReports'})	{
		if($activefields->{'DeletedReports'}==1)	{
			return 'Report Removed Successfully';
		}
		elsif($activefields->{'DeletedReports'}==-1)	{
			return 'Report unable to be removed';
		}
	}
		my $orderlink=$FieldDefinitions->{'order'};
		if($activefields->{'RO_RecordFilter'} eq 'SUMMARY')	{ #Summarise Records
			my @ord=@{$orderlink};
			push @ord, 'RO_SUM';
			$orderlink=\@ord;
			$activefields->{'RO_SUM'} = 1;
		}
		if($activefields->{'exformat'} and $FieldDefinitions->{'ExportFormats'}{$activefields->{'exformat'}}{'Order'})	{
			$orderlink=$FieldDefinitions->{'ExportFormats'}{$activefields->{'exformat'}}{'Order'};
		}
		elsif($retdata)	{ $orderlink=[keys %processfields]; }	
    for my $field (@{$orderlink}) {
      if(exists $activefields->{$field} and $activefields->{$field})  {
				$numfieldsinuse++;
			}
		}

		while (my $dataref = $query->fetchrow_hashref())     {
		my %DataToProcessLine=();
		$emaildata=1 if $retdata;
    $count++;
    my $class='rBG0';
    if($count%2==0) {$class='rBG1';}
		if($FieldDefinitions->{'config'}{'EmailExport'} and 
				$FieldDefinitions->{'config'}{'limitView'} and 
				!$emaildata and
				$count > $FieldDefinitions->{'config'}{'limitView'})	{

			$query->finish();
			return qq[
				<p class="warning">Too many results would be returned in this report.</p>
				<p class="warning">If you wish to get this data then you must use the send report to email function.</p>
			];
		}

		if($emaildata)	{ @line=(); }
		my $reportline='';
		#else	{ $report.=qq[ <tr>\n ] ;	}


    for my $field (@{$orderlink}) {
      if(exists $activefields->{$field} and $activefields->{$field})  {
				my $outvalue='';
				$lastfield=$field;
        if(!defined $dataref->{$field}) {$dataref->{$field}='&nbsp;';}
        my $displaytype = $FieldDefinitions->{'fields'}{$field}[1]{'displaytype'} || '';
        if($displaytype eq 'lookup') {
          $outvalue=$FieldDefinitions->{'fields'}{$field}[1]{'dropdownoptions'}{$dataref->{$field}} || '&nbsp;';
        }
        if($displaytype eq 'function') {
					# Field needs to be processed through a function first
					next if !$FieldDefinitions->{'fields'}{$field}[1]{'functionref'};
					my @fnparams=();
					if($FieldDefinitions->{'fields'}{$field}[1]{'fieldparams'})	{
						my @fieldparams=split /,\s*/,$FieldDefinitions->{'fields'}{$field}[1]{'fieldparams'};
						if(@fieldparams)	{
							for my $i (@fieldparams)	{
								push @fnparams, $dataref->{$i} || ''; 
							}	
						}
					}
					if($FieldDefinitions->{'fields'}{$field}[1]{'functionparams'})	{
						push(@fnparams, @{$FieldDefinitions->{'fields'}{$field}[1]{'functionparams'}});
					}
          $outvalue=&{$FieldDefinitions->{'fields'}{$field}[1]{'functionref'}}(@fnparams);
        }
				if($FieldDefinitions->{'fields'}{$field}[1]{'total'} or $field eq 'RO_SUM')	{
					$totals{'all'}{$field}+=$dataref->{$field};
					$totals{'grp'}{$field}+=$dataref->{$field};
				}
				$totals{'num'}{$field}++;
        if($dataref->{$field} =~/0+\/0+\/00+/)  {$dataref->{$field}='&nbsp;';}

				if(exists $FieldDefinitions->{'links'}{$field} and $FieldDefinitions->{'links'}{$field}[0] and !$emaildata)	{
					my $linkref= eval($FieldDefinitions->{'links'}{$field}[0]) || '';
					my $trgt=$FieldDefinitions->{'links'}{$field}[2] ? qq[ target="$FieldDefinitions->{'links'}{$field}[2]" ]: '';
					$outvalue = qq[<a href="$linkref" $trgt>$dataref->{$field}</a>];
				}
				if(!defined $outvalue or $outvalue eq '')	{ $outvalue=$dataref->{$field};	}
        if($displaytype eq 'currency' and $FieldDefinitions->{'config'}{'CurrencySymbol'})	{
					$outvalue= $FieldDefinitions->{'config'}{'CurrencySymbol'} . $outvalue;
				}

				$outvalue=~s/\&nbsp;/ /g if $emaildata;
				if($activefields->{'groupby'} and $field eq $activefields->{'groupby'} )	{
					if($outvalue ne $lastgroupline)	{
						my $numrecords=$totals{'num'}{$field} || 0;
						$report=~s/:GRP$lastgroupline:/$numrecords/;
						$lastgroupline = $outvalue;
						if($emaildata)	{ 
							my $tot=total_line(\%totals, 'grp', $activefields, $FieldDefinitions) if $activefields->{'groupby'}; 
							push @report, [@{$tot}] if $tot;
							my @temp=();
							push @temp, $outvalue;
							push @report, [@temp];
						}
						else	{
							$report.=total_line(\%totals, 'grp', $activefields, $FieldDefinitions) if $activefields->{'groupby'}; 
							$report.=qq[ <tr> <td colspan="].($numfieldsinuse-2).qq[" class="rGrpHead">$outvalue</td><td class="rGrpHead">:GRP$outvalue:</td></tr>\n];	
						}
						$totals{'grp'}=();
						$totals{'num'}=();
					}
					next;
				}
				$emaildata=0 if $retdata;
				if($emaildata)	{ 
					$outvalue=~s/\n/ /g;
					push @line, $outvalue; 
				}
				elsif($retdata)	{ $DataToProcessLine{$field}=$outvalue if $processfields{$field}; }
				else	{ 
					my $cellalign='';
					if($FieldDefinitions->{'fields'}{$field}[1]{'align'})	{
						$cellalign=qq[ style="text-align:$FieldDefinitions->{'fields'}{$field}[1]{'align'}" ];
					}
					$reportline.=qq[    <td class="$class" $cellalign>$outvalue</td> ];	
				}
      }
			elsif ($emaildata and $activefields->{'exformat'})	{
				#Not in Active fields, we'll try and be smart about it
				my $outvalue='';
				if(exists $dataref->{$field})	{ $outvalue=$dataref->{$field} || ''; }
				else	{ $outvalue=$field || ''; }
				$outvalue=~s/\n/ /g;
				push @line, $outvalue; 
			}
    }
		if($emaildata)	{ push @report, [@line]; }
		elsif($retdata)	{ 
			push @DataToProcess, \%DataToProcessLine; 
		}
		else	{ $report.=qq[ <tr> $reportline </tr>\n];	}
  }
	if($emaildata)	{
		my $tot=total_line(\%totals, 'grp', $activefields, $FieldDefinitions) if $activefields->{'groupby'};
		push @report, [@{$tot}] if $tot;
		$tot=total_line(\%totals, 'all', $activefields, $FieldDefinitions);
		push @report, [@{$tot}] if $tot;
	}
	else	{
		$report.=total_line(\%totals, 'grp', $activefields, $FieldDefinitions) if $activefields->{'groupby'}; 
		$report.=total_line(\%totals, 'all', $activefields, $FieldDefinitions) || '';
		my $numrecords=$totals{'num'}{$lastfield} || 0;
		$report=~s/:GRP$lastgroupline:/$numrecords/;
	}


  my $countline="<b> Your report returned $count records</b><br><br>";
  $countline='' if $count <= 1;
	my $headers='';
	my @headers=();
	for my $field (@{$FieldDefinitions->{'order'}}) {
		next if(!exists $activefields->{$field} or !$activefields->{$field});
		my $headval=(exists $FieldDefinitions->{'fields'}{$field}[1]{'headername'} and $FieldDefinitions->{'fields'}{$field}[1]{'headername'}) ?  $FieldDefinitions->{'fields'}{$field}[1]{'headername'} : $FieldDefinitions->{'fields'}{$field}[0];
		next if $field eq $activefields->{'groupby'};
		$headers.=qq[<td class="rHeading">$headval</td>];
		$headval=~s/\n/ /g;
		push @headers, $headval;
	}
	if($activefields->{'RO_RecordFilter'} eq 'SUMMARY')	{ #Summarise Records
		$headers.=qq[<td class="rHeading">Count</td>];
		push @headers, 'Count';
	}
	if($emaildata)	{
		my $wantheaders=1;
		my $filename=$FieldDefinitions->{'config'}{'EmailExportFileName'} || '';
		my $delimiter="\t";
		if($activefields->{'exformat'})	{
			$wantheaders=$FieldDefinitions->{'ExportFormats'}{$activefields->{'exformat'}}{'Headers'} || 0;
			$filename=$FieldDefinitions->{'ExportFormats'}{$activefields->{'exformat'}}{'ExportFileName'} || $filename;
			$delimiter=$FieldDefinitions->{'ExportFormats'}{$activefields->{'exformat'}}{'Delimiter'} || $delimiter;
		}
		unshift @report,\@headers if $wantheaders;
		my $retval=emailExport(\@report, $activefields->{'exemail'}, $FieldDefinitions->{'config'}{'EmailMessage'}, $FieldDefinitions->{'config'}{'EmailSubject'}, $filename, $FieldDefinitions->{'config'}{'EmailSenderAddress'}, $FieldDefinitions->{'config'}{'EmailLogFile'}, $delimiter);
		if($retval)	{
			$report =qq[ <p>There was an error sending the data you wanted.  Try again later</p> ];
		}
		else	{
			$report =qq[
				$countline
				<p>Your data has been emailed to $activefields->{'exemail'}</p>
			];	
		}
	}	
	elsif($retdata)	{
		$report =qq[ <p>Your data has been processed.</p> ];
	}
	else	{
		$report=qq[
				$countline
			<table>
				<tr>
					$headers
				</tr>
				$report
			</table>
		];
	}
	if(wantarray())	{return ($report,	\@DataToProcess); }
	else	{ return $report; }
	#return ($report,	\@DataToProcess); 
}

sub total_line	{
	my($totals, $type, $activefields, $FieldDefinitions)=@_;

	my $emaildata= $activefields->{'viewtype'}eq 'email' ? 1 : 0;
	my @line=();
	my $line='';
	if(scalar( keys %{$totals->{$type}}))	{
		if($emaildata)	{ @line=(); }
		else	{ $line.=qq[ <tr>\n ] ;	}
		my @ord=@{$FieldDefinitions->{'order'}};
		push @ord, 'RO_SUM' if $activefields->{'RO_SUM'};
    for my $field (@ord) {
			next if $field eq $activefields->{'groupby'};
			my $class='rBG0';
      if(exists $activefields->{$field} and $activefields->{$field})  {
				my $totalval='&nbsp;';
				if(exists $totals->{$type}{$field})	{
					$class='rTotal';
					$class=$type ne 'all' ? 'rSubTot' : 'rTotal';
					$totalval=$totals->{$type}{$field} || 0;
				}
        if($FieldDefinitions->{'fields'}{$field}[1]{'displaytype'} 
					and $FieldDefinitions->{'fields'}{$field}[1]{'displaytype'} eq 'currency' 
					and $FieldDefinitions->{'config'}{'CurrencySymbol'})	{
					$totalval= $FieldDefinitions->{'config'}{'CurrencySymbol'} . currency($totalval);
				}
				if($emaildata)	{ 
					$totalval=~s/&nbsp;/ /g;
					push @line, $totalval; 
				}
				else	{ 
					my $cellalign='';
					if($FieldDefinitions->{'fields'}{$field}[1]{'align'})	{
						$cellalign=qq[ style="text-align:$FieldDefinitions->{'fields'}{$field}[1]{'align'}" ];
					}
					$line.=qq[    <td class="$class" $cellalign>$totalval</td> ];	
				}
			}
		}
		if($emaildata)	{ return \@line; }
		else	{ return $line."</tr>\n";	}
	}
	return '';
}

sub currency  {
  $_[0]||=0;
  $_[0]=~s/,//g;
  my $text= sprintf "%.2f",$_[0];
  $text= reverse $text;
  $text=~s/(\d\d\d)(?=\d)(?!\d*\.)/$1,/g;
  return scalar reverse $text;
}
                                                                                                        
sub ROquery_error {
  my($error)=@_;
  my $currenttime=scalar localtime();
  if(!defined $error) {$error="";}
  # THIS ROUTINE SHOULD BE CALLED WHEN THERE IS A PROBLEM WITH ONE OF THE DATABASE COMMANDS.
  warn($DBI::errstr);
	print "Content-type: text/html\n\n";
  print "<h2>An Database error has Occurred.<br><br>Please contact us if the problem persists.<br>Sorry for the inconvenience.</h2><BR>\n";
  print "$error<BR>\n";
  warn("$currenttime $error");
	#print "$DBI::errstr";
  #$dbh->disconnect();
  exit(0);
}


sub fixDate  {
  my($date)=@_;
  return $date if $date!~/\//;
  my ($day, $month, $year)=split /\//,$date;
                                                                                                        
  if(defined $year and $year ne '' and defined $month and $month ne '' and defined $day and $day ne '') {
    $month='0'.$month if length($month) ==1;
    $day='0'.$day if length($day) ==1;
    if($year > 20 and $year < 100)  {$year+=1900;}
    elsif($year <=20) {$year+=2000;}
    $date="$year-$month-$day";
  }
  else  { $date='';}
  return $date;
}


sub deQuote	{
	my ($db, $val)=@_;
	return $db->quote($val) if $db;
	#No DB reference lets do our best
	if($val=~/^\d+$/)	{
		#just digits
		return $val; #nothing to do
	}
	$val=~s/'/''/; #escape quotes
	return "'$val'";
}

sub getSelectedValuesString {
	my($params, $FieldDefinitions, $db)=@_;

	my $fields_ref = $FieldDefinitions->{'fields'};
	my $order_ref = $FieldDefinitions->{'order'};

	my @vals=();
	for my $fieldname (@{$order_ref})	{
		next if !exists $fields_ref->{$fieldname};
		if(exists $params->{'chk_'.$fieldname} and $params->{'chk_'.$fieldname} )	{
			push @vals, 'chk_'.$fieldname.'|'.$params->{'chk_'.$fieldname};
		}
		if(exists $params->{'comp_'.$fieldname} and $params->{'comp_'.$fieldname} ne '')	{
			push @vals, 'comp_'.$fieldname.'|'.$params->{'comp_'.$fieldname};
			if(exists $params->{$fieldname.'_1'} and $params->{$fieldname.'_1'} ne '')	{
				push @vals, $fieldname.'_1|'.$params->{$fieldname.'_1'};
			}
			if(exists $params->{$fieldname.'_2'} and $params->{$fieldname.'_2'} ne '')	{
				push @vals, $fieldname.'_2|'.$params->{$fieldname.'_2'};
			}
		}
	}
	for my $i (qw(
		sortby sortbydir sortby2 sortby2dir DISTINCT viewtype exemail exformat limit groupby RO_RecordFilter
	))	{
		push @vals, $i.'|'.$params->{$i} if(exists $params->{$i} and $params->{$i} ne '');
	}

	my $rtn=join(';',@vals);
	return $rtn;
}

sub SaveReport	{
	my ($params, $FieldDefinitions, $db, $activefields)=@_;

	if($FieldDefinitions->{'SavedReports'} and $FieldDefinitions->{'SavedReports'}{'sql_add'})	{
		my $savestring=getSelectedValuesString($params, $FieldDefinitions, $db);
		my $reportname=$params->{'RO_savedreportname'} || 'Saved Report';
		$reportname=deQuote($db,$reportname);
		$savestring=deQuote($db,$savestring);
		my $sql= $FieldDefinitions->{'SavedReports'}{'sql_add'};
		$sql=~s/--REPORTNAME--/$reportname/;
		$sql=~s/--REPORTDATA--/$savestring/;
		$db->do($sql) if($sql and $db);
		if($DBI::err) { $activefields->{'SavedReports'}=-1; }
		else	{ $activefields->{'SavedReports'}=1; }
	}
}

sub LoadReport	{
	my($params, $FieldDefinitions,$db)=@_;
	if($FieldDefinitions->{'SavedReports'} and $FieldDefinitions->{'SavedReports'}{'sql_load'})	{
		my $reportID=$params->{'runreportlist'} || 0;
		return if !$reportID;
		my $sql= $FieldDefinitions->{'SavedReports'}{'sql_load'};
		$sql=~s/--ID--/$reportID/;
		{
			my $q= $db->prepare($sql);
			$q->execute;
			my $val=$q->fetchrow_array();
			$q->finish();
			$val||='';
			if($val)	{
				my @values=split /;/,$val;
				for my $v (@values)	{
					my($k, $option)=split /\|/,$v;
					if($k eq 'viewtype' and $option eq 'screen' and $params->{$k} eq 'email' and $params->{'exemail'})	{
						next;
					}
					$params->{$k}=$option;
				}
			}
		}
	}
}


sub DeleteReport	{
	my ($params, $FieldDefinitions, $db, $activefields)=@_;

	if($FieldDefinitions->{'SavedReports'} and $FieldDefinitions->{'SavedReports'}{'sql_del'})	{
		my $reportID=$params->{'runreportlist'} || 0;
		return if !$reportID;
		my $sql= $FieldDefinitions->{'SavedReports'}{'sql_del'};
		$sql=~s/--ID--/$reportID/;
		$db->do($sql) if($sql and $db);
		if($DBI::err) { $activefields->{'DeletedReports'}=-1; }
		else	{ $activefields->{'DeletedReports'}=1; }
	}
}

sub _langlookup  {
  my $key = shift;
  my $langref= shift;
  return '' if !$key;
	return $key if !$langref;
	return $langref->maketext($key,@_) || '';
}

=head1 NAME

ReportOptions - Provide and interface to display reports that allow filtering

=head1 SYNOPSYS

	use ReportOptions;
	$topjs = displaybox_js('formname');
	
  %FieldDefinitions=(
      fields => {
        strName=> ['Name',{displaytype=>'text', fieldtype=>'text', active=>1, allowsort=>1}],
        strStreetAddr=> ['Street Address 1',{displaytype=>'text', fieldtype=>'text', dbfield=>'strStreetAddr'}],
        strSuburb=> ['Suburb',{displaytype=>'text', fieldtype=>'text', dbfield=>'strSuburb', allowsort=>1}],
        intActive => ['Active ',{displaytype=>'lookup', fieldtype=>'dropdown', dbfield=>'tblCustomer.intActive', dropdownoptions=>{'YES'=>'Yes','NO'=>'No'}}],
			},
			order => [qw(strName strStreeAddr strSuburb intActive)],
			config => {
				limitView => 1000,
			}
	);

	q[<form action="yourscript.cgi" method="POST" name="formname">
		<table class="reportoptions">
		].	displayOptions(\%FieldDefinitions, 'prefix', \%perms, 'formname') .q[
		</table>
		<input type="submit" value="Run Report">
	</form>
	];

	($activefields, $wherelist, $sortby, $fromlist)=process_submission($params, $FieldDefinitions, $db);

  $select_stuff=genSelect($FieldDefinitions, $activefields);
                                                                                                        
  $wherelist="AND $wherelist" if $wherelist;
  $statement=qq[
      SELECT $activefields->{'DISTINCT'} $select_stuff
      FROM <Join Statement> $fromlist
      WHERE <Common Where Conditions>
      $wherelist
      ORDER BY $sortby
    ];
  return showreport($db, $statement, $FieldDefinitions, $activefields) || '';

=head1 DESCRIPTION

This module provides functions for generating a reporting system that allows the user to choose which fields to display and filter on particular fields.  The report can be displayed on-screen or emailed to a supplied email address.

The system makes use of a group of functions that must be called in a specific order.  Configuration is available by setting values in a data structure.

=head1 METHODs

=head2	display_js('formname')

This method includes the javscript needed for showing/hiding the selction boxes it should be included in the HTML of the page before the form containing the options.

=item formname

This is a string that is the name of the form element that these form elements are part of.  It is defined by the name <form action="yourscript.cgi" name="formname"> tag.

=head2 displayOptions(\%FieldDefinitions, 'prefix', '\%perms, 'formname',$languagereference)

This function returns the HTML code that contains the fields and selection boxes.  Each row is embedded in a HTML table <tr> tag.  This function should be wrapped by both a HTML Form and HTML table tag.

=item $FieldDefinitions

This is the main configuration data and allows selection of which fields are available and how to display them.  This should be the hash data structure as defined in the [Data Structure] section of this documentation.

=item $prefix

This is just a string to prepend to the generated HTML form elements.  This allows multiple forms to be used on the same page.  The value isn't important as long as it is unique to the page.

=item $perms

This datastructure allows you to dynamically hide particular fields without changing the configuration.  It is further defined in the [Data Structure] section.

=item $formname

This is a string that is the name of the form element that these form elements are part of.  It is defined by the name <form action="yourscript.cgi" name="formname"> tag.

=item $languagereference

This is a reference to a Locale::MakeText object for language conversion

=head2 ($activefields, $wherelist, $sortby, $fromlist)=process_submission($params, $FieldDefinitions, $db);

This function should be called after form submission.  It processes which fields are checked and any filters.

=item $params

This should be a reference to a hash containing name/value pairs of the values passed to this form.  Usually this is a result of the following code using the CGI module.
    my $q=new CGI;
    my %Params=$q->Vars();

=item $FieldDefinitions

This is the main configuration data and allows selection of which fields are available and how to display them.  This should be the hash data structure as defined in the [Data Structure] section of this documentation.

=item $activefields

This returned value is a reference to a hash whose keys contain the fieldnames of the active fields (the box was checked).  The value for the key is always 1.

=item $wherelist

This string is a portion of an SQL where statement that contains the conditions 
necessary to fulfill the requested filters.

=item $sortby

This string is a portion of an SQL SORT BY statement that contains the fields and 
order necessary to sort the SQL result set.

=item $fromlist

This string is a portion of an SQL from statement that contains the tabls and joins
necessary for the selected fields.


=head2 ($select_stuff, $groupbystuff)=genSelect($FieldDefinitions, $activefields);

This function produces a portion of an SQL select statement which contains the selected fields.
If called in array context is also returns a portion of SQL to be used as a GROUP BY.

=item $FieldDefinitions

As Above

=item $activefields

As Above.  This reference should be returned from a previous call to process_submission().


=head2 $report=showreport($db, $statement, $FieldDefinitions, $activefields);

This is the function that actually does the generation of the report.

=item $report

This string contains the text of the report in HTML format.  It also displays any 
errors if the report is exported to email.  The string does not contain any HTML 
page formatting commands eg. HTML,BODY,stylesheet.

=item $db

This is a reference to a connected DBI database object.

=item $statement

This is a valid SQL statement to generate the query necessary to return all the 
fields required for the report.  The statement should be of the form shown below.

  $statement=qq[
      SELECT $activefields->{'DISTINCT'} $select_stuff
      FROM <Join Statement>
      WHERE <Common Where Conditions>
      $wherelist
      ORDER BY $sortby
	];

	<Join Statement> is where you should list any required tables or joins 
		necessary to obtain the required data.
	<Common Where Conditions> is where any additional filter/constraints need to 
		be placed.  This may be extra filter or additional join conditions.  If 
		other where conditions are added it may be necessary to add the following 
		line before the statement declaration to obtain valid SQL.

  $wherelist="AND $wherelist" if $wherelist;


=item $FieldDefinitions

As Above

=item $activefields

As Above.  This reference should be returned from a previous call to process_submission().

=head1 Data Structures


=item perms


This permissions hash is optional and in most case isn't needed.
  %perms=(
    strName => 1,
    strSuburb => 0,
  )

If this value is supplied to the displayOptions function then any field not 
listed with a 1 in the value field will not be shown.

=item FieldDefinitions

This is the monster data structure that performs most of the configuration for this module

It is broken up into multiple sections with different hash keys.

The first (and probably largest) is 'fields'

 %FieldDefinitions=(
      fields => {
        strName=> ['Name',{displaytype=>'text', fieldtype=>'text', active=>1, allowsort=>1}],
        strStreetAddr=> ['Street Address 1',{displaytype=>'text', fieldtype=>'text', dbfield=>'strStreetAddr'}],
        intActive => ['Active ',{displaytype=>'lookup', fieldtype=>'dropdown', dbfield=>'tblCustomer.intActive', dropdownoptions=>{'YES'=>'Yes','NO'=>'No'}}],
      },

	...

	Each row is broken up into three parts as below
			FieldName => [Display field name, {options}],

	The FieldName should be the database field name as much as possible, but 
	is not essential.  The FieldName however must be unique in the fields list.
	The Display field name is how the field is described on the user form.
	The options section contains a hash of different parameters (listed below) 
	that relate to the particular field

			fieldtype
				This is how the the field is displayed in the user filter area.

				Possible options are 
						text      - provides a text box for the user to type into
						number    - as above, but known as a number only 
						date      - provides the user a data selection popup
						dropdown  - provides the user with a SELECT box contains possible values
						none 			- no filtering is possible

			displaytype
				This is how the field is displayed in the generated report.  This does 
				not need to be the same as fieldtype, but generally is.

				Possible options are
					text       - The field is displayed as is, no extra formatting
					lookup     - The field value is used as the key value for a lookup table 
											 and the result displayed.
					function   - For each value a function is called with a set of parameters.
					currency   - The field is displayed as is with a currency symbol prepended


			active
				If this parameter is set then the checkbox will appear 'checked' when loaded.

			align
        This string controls the text alignment of the column.  It can contain the options 
        left, center or right.
		
			allowgrouping
				If this parameter is set then it allows grouping on this column

			allowsort
				If this parameter is set then this field will appear in the list 
				of fields to be sorted by.
				
			dbfield
				This allows you to specify the exact database field name to use in a query. 
				eg. tblUser.strName.  
				This is necessary if the fieldname would result in an ambiguous table field.

			dbformat
				If the field needs to be reformatted in the SQL statement then 
				this option can be used.  eg. dbformat=>' DATE_FORMAT(dtDOB,"%d/%m/%y")'

			dbfrom
				This string can contain an SQL join string.  This string is added to the 
        SQL statement if this field is active.  This can also contain a reference to
				an array that contains SQL join strings.

			dbwhere
				This string can contain an SQL where condition string.  This string is added 
        to the SQL statement if this field is active.

      dbwherefieldalias
        This is a reference to an array containing alternating logic and field names.
        It is used if a particular filter specified for this field should also be 
        applied to another differently named field at the same time.
        eg. ['OR','tblMember2.strSurname','OR','tblMember3.strSurname']

      defaultcomp
        This sets the default comparison type. The available types are equal, notequal, 
        morethan, lessthan, isblank, isnotblank, like.

      defaultvalue
        This sets the default value to display for filter field 1.  This is a 
        normally a string value.  If multiple items need to be said (eg. for a 
        multi-select list box) then pass in a reference to an array containing the
        default values.

      disable
        Don't show this field

			dropdownoptions
				This option takes a reference to a hash containing the values for 
				the drop down list.  The hash key is the option returned and the 
				value is the displayed option.

			dropdownorder
				This option takes a reference to an array which has the order for the 
				drop down options to appear in.  The array should contain the hash 
				keys from the dropdownoptions hash.  If this option isn't included 
				then the dropdownoptions hash is sorted in alphabetical order.

			fieldparams
				This string should contain a comman separated list of the fieldnames 
				needed to passed to the function.

      filteronly
				If set to one then this field is only used in the where condition and doesn't appear 
        on the report output.

			functionparams
				This parameter should contain an array of the parameters to pass 
				to the function defined in functionref.  Any parameters defined in 
				fieldparams are prepended to this array.

			functionref
				If the display type is function then this parameter should contain 
				a reference to the function to be used.
			
			headername
				This string is what to call this column in the report header
		
      multiple
        This is only valid for a dropdown type of field.  It specifies that multiple selections
        are to be allowed (generally by holding down the CTRL key).  When a field is marked
        as multiple only equal/notequal (and blank testing) is possible for the field.

      size
        Gives the size of the filter field.  If used on a dropdown type field this converts
        it to a list box with this many rows.

			total
				If this parameter is set then totals will be generated for the field specified.

order

The second hash key 'order' is compulsory and defines the order in which the fields appear.

			order => [qw(strName strStreeAddr strSuburb intActive)],
The order key contains an array with a list of field names, in the order they need to appear.

links

The next hash key 'links' is not always used.  It provides the ability for a particular element of data to generate a HTML link (href).

      links =>  {
        strName => ['qq[showdetails.cgi?action=SHOW&intID=$dataref->{intOrgID}&Name=].main::escape($dataref->{strOrgName})',[qw(intOrgID strOrgName)],'main'],

			...
Each line is again broken into three parts
			
		FieldName => [evalString,fields];
				
				evalString - This string is evaled to produce the link, so you can include 
					other functions calls as long as scoping is take into account.  

				fields - This is an array of fields required for this link to work.  These do 
					not have to be part of the fields hash mentioned above.  To reference these 
					values in the evaled string user $dataref->{fieldname}.

        target - This is the HTML window name for this link to open in.


config

The next hash key is 'config'.  This key is not mandatory, and any keys not mentioned will have their default values. The contains misc configuration for the reporting system.  
The valid keys are listed below:

		RunButtonLabel - If supplied a 'run report' button is created with the label being
     the value of this parametet

		EmailExport (default 0), 1 active

		limitView -  Value is number of records.  If the number of records to be displayed 
			exceeds this amount, don't display the report but suggest usage of the email 
			export option.  Requires EmailExport=1.

		EmailSenderAddress - The address the export email will come from.   Requires EmailExport=1.

		EmailMessage - A message included in the export email.  Requires EmailExport=1.

		EmailSubject - The subject line of the default email.  Requires EmailExport=1.

		EmailExportFileName - The file name of the export file attached to the email.
		  Requires EmailExport=1.

		EmailLogFile - The full path name of a log file to record sending of email 
			exports to.  Requires EmailExport=1.

		CurrencySymbol - This is the symbol to be prepended to currency in the report. eg. $

    ShowDistinct - This parameter controls the displaying of the Distinct Values checkbox.
    If set to 0 this box won't display.  If not present or set to 1 then the box displays.

    SecondarySort- If set to 1 then the option will appear for a secondary sort field.

		NoSummaryData - Don't show the option to summarise the data.

    ReturnProcessData - If this parameter is set then the call to showreport will return two
      variables, the second one being a reference to an array of hashes.  The data in the hashes
      are the values for the fields specified in the the parameter.  The parameter is a reference 
      to an array of field names.

optiongroups

Another available hash key is 'optiongroups'. This allows you to bundle a set of fields 
together to form a group.  A non-active group appears only as the group title. Clicking
on the title causes the group to appear.  This saves space on what can be a complex form.

	optiongroups => {
		identifications => ['Identifications',{ }],
		contact => ['Contact Details',{
			from => "LEFT JOIN tblPerson_Contacts ON tblPerson.intPersonID=tblPerson_Contacts.intPersonID"
			where => "tblPerson_Contacts.intCOD=4",
		 }],

	Each row is broken up into three parts as below
			OptionName => [Display Option Name, {options}],

	OptionName is an identifier for the particular group.  It must be the same as that specified
	against 'optiongroup' option in FieldDefinitions.
	Display Option Name is what to call this option group on the screen.
	Options is a hash that can define other options:

	The available options are:

		disable
			Don't show this group

		from - This value should contain an SQL join string that is appended if any member of the 
			group is active. This can also contain a reference to an array that contains SQL join strings.

		where - This value should contain an SQL conditional string that is appended if any member of the 
			group is active.
		active - if set (1) then this group will display opened by default

ExportFormats

This section allows you to define custom export file formats.  These formats are only available for 
use when the report is emailed.  The option only displays when there are one or more formats defined (and email export is enabled).


     ExportFormats =>  {
        Format1 => {
          Name => 'Export Format 1',
          Select => 'strSurname, dtDOB';
          From => ' LEFT JOIN tblMemberDOB ON tblMember.intMemberID=tblMemberDOB.intMemberID ',
          Order => ['strSurname, 'dtDOB', 2, -1],
          Headers => 0,
          ExportFileName => 'export.txt',
          Delimiter => "\t",	
				}
		 }

The section contains a series of hashes, each one defining another export format.  Inside each hash the following keys are allowed.

      Name
        The name appears in the selection list for the user to chose

      Select
        This is a field list suitable to be passed to a SQL Select statement

      From
        A portion of an SQL FROM statement that may be necessary to join tables.  
        This field is optional.

      Order
        This array specifies the order of the fields in the Select statement.  A constant value
				can be specified and this will be included directly into the export.

      Headers
        If this is set to 0 then column headers aren't included in the output. (Optional)

      ExportFileNmae
        This value allows you to set the name of the file attachment sent in the email. (Optional)

      Delimiter
        This is the delimiter used between each value. This defaults to a Tab. (Optional)

SavedReports

By using this section a report can be memorised for later use.
	sql_add 
   This key should contain an SQL string which should write the data to a database.  The values --REPORTDATA-- and --REPORTNAME-- are replaced with the report selections and report name respectively.
	sql_load 
   This keys should contain an SQL string to load the saved report data when passed an ID.  The string --ID-- is replaced by the report ID.
	sql_del 
   This key should contain an SQL string which should delete the report from the database.
   The string --ID-- is replaced by the report ID.
	ReportList
	This key should a reference to a hash containing the ids (as hash key) and names (as hash value) of saved reports.

	
=head1 ChangeLog
=item 1.60 16/09/2010 Warren
Add in ability to pass in language reference

=item 1.53 21/04/2009 Warren
Add ability to pass through other form paramaters be prefixing with _EXT

=item 1.52 28/08/2008 Warren
Added usehaving flag to put filters into HAVING line

=item 1.51 18/08/2008 Warren
Fixed problem with saved reports - not saving filters when fields not checked

=item 1.50 16/01/2008 Warren
Changed layout of options etc - better grouping
Added folder icons
Removed distinct button - replaced with drop down and 
Added ability to produce summary data
Ability to filter on non shown fields

=item 1.49 11/01/2008 Warren
Fix issue where group by not sorting by sortfield

=item 1.48 12/11/2007 Warren
Put Secondary Sort on second line 
Between comparison now includes the values

=item 1.41 01/03/2006 Warren
Added alt tag on calendar image to make page validate

=item 1.47 16/04/2007 Warren
Added disable option for field and option group

=item 1.46 25/03/2007 Warren
Change OR to AND if not equal selected on multi field

=item 16/03/2007 Warren
If filter is not equal then boolean joiner should be AND not OR for multi selects

=item 1.45 05/02/2007 Warren
If report is saved as screen display and email export is selected before pressing the load saved report option then report is emailed instead of displayed.

=item 1.44 02/02/2007 Warren
Added prefix to optiongroup code to allow multiple forms with the same optiongrouop name

=item 1.43 19/07/2006 Warren
Added report save option

=item 1.42 11/07/2006 Warren
Change construction of from list to maintain the order it is executed in to fix problems with strange join problems.

=item 1.41 01/03/2006 Warren
Added alt tag on calendar image to make page validate

=item 1.40 20/12/2005 Warren
Added class around radio and check boxes to turn off border (if required), because of IE bug.

=item 1.39 20/10/2005 Warren
Fixed problem with undefined array value - when field name mispelled.

=item 1.38 20/10/2005 Warren
Fixed problem with using IN for multiple selections in text box

=item 1.38 07/09/2005 Warren
Cleaned up HTML warnings

=item 1.37 04/07/2005 Warren
Added Return Process Data option

=item 1.36 27/04/2005 Warren
Fixed problem with use of NOT BLANK - OR instead of AND
Added ability to define array of dbfroms

=item 1.35 14/09/2004 Warren
Fixed problem with where condition when using blank/not blank.
Blank/Not Blank now also check for nulls as well as ''.

=item 1.34 02/09/2004 Warren
Added ability to set HTML target on data links

=item 1.33 31/08/2004 Warren
Patch provided by Liam Wilks fixing problem with dbfrom

=item 1.32 19/08/2004 Warren Rodie
Added documentation for default* options.
Modified Form_helpers to allow for multiple default settings on combos

=item 1.31 18/08/2004 Warren Rodie

Added multiple and size functionality
Reordered Field Definition options in doco in alphabetical order
Added Limit functionality
Add DBNameAlias functionality
Fixed bug with grouping when table not included

=item 1.30 14/07/2004 Warren Rodie

Added filteronly flag
Added secondary sort option

=item 1.29 24/6/2004 Warren Rodie

Fix bug with drop down lists creating a Javascript error

=item 1.28 8/6/2004 Warren Rodie

Added ability for export formats.
Fixed date between problem where it doesn't convert between d/m/yyyy to dd/mm/yyyy.

=item 1.27 12/5/2004 Warren Rodie

Added ability to align columns and ShowDistinct config option.

=item 1.26 15/4/2004 Warren Rodie

Fixed bug that was allowing export of carriage return.  Replace with space so it didn't
break the import process.

=item 1.25 29/3/2004 Warren Rodie

Added function ROquery_error - it was calling it anyway on a database error.
Fixed problem with crashing when field in order not in 'fields'
Added fields dbfrom dbwhere
Added optiongroup ability

=item 1.24 23/12/2003

Added ability to group on a particular field. eg allowgrouping

=cut

;1

