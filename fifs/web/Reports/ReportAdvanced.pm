#
# $Header: svn://svn/SWM/trunk/web/Reports/ReportAdvanced.pm 9178 2013-08-08 01:13:12Z dhanslow $
#

package Reports::ReportAdvanced;

use strict;

use lib ".", "../", "../..";

use ReportBaseObj;
our @ISA =qw(ReportBaseObj);
use Safe;
use SearchLevels;
use TTTemplate;
use FormHelpers;
use JSON;

use strict;

sub _getConfiguration {
	my $self = shift;
	return undef;
}

sub makeSQL {
	my $self = shift;


	my %OptVals = ();
	my $activefields = undef;
	my $sortvals = undef;
	my $continue = 1;
	my $msg = '';
  (
		$activefields, 
		$OptVals{'WHERE_LIST'}, 
		$sortvals, 
		$OptVals{'FROM_LIST'}, 
		$OptVals{'HAVING_LIST'},
		$continue,
		$msg,
		) = $self->processSubmission();
	$continue ||=0;
	if(!$continue)	{
		#Something has come up, we should return early
		return ('', $continue, $msg || '');
	}
	$self->{'RunParams'}{'ActiveFields'} = $activefields;
	$self->afterSubmission();
	my $reportLevel = $self->{'Config'}{'ReportLevel'} || $self->{'EntityTypeID'} || 0;
	my $reportEntity = $self->{'Config'}{'ReportEntity'} || $Defs::LEVEL_PERSON;
	my $reportStats = $self->{'Config'}{'StatsReport'} || 0;
	my %otheroptions = ($self->{'SystemConfig'}{'ShowInactiveMembersInClubSearch'})
      ? (ShowInactiveMembersInClubSearch => 1)
      : ();
  my $reportNotMemberTeam = !($self->{'Config'}{'MemberTeam'} || 0);
	my $otheroptions = '';
	(
		$OptVals{'FROM_LEVELS'}, 
		$OptVals{'WHERE_LEVELS'}, 
		$OptVals{'SELECT_LEVELS'}, 
		$OptVals{'CURRENT_FROM'}, 
		$OptVals{'CURRENT_WHERE'}
		) = getLevelQueryStuff(
			$reportLevel,  
			$reportEntity, 
			$self->{'Data'}, 
			$reportStats, 
			$reportNotMemberTeam,
			\%otheroptions
		);
	$OptVals{'SELECT'} = $self->genSelect($activefields);


	my $w_join1 = '';
	if($OptVals{'WHERE_LEVELS'} and $OptVals{'CURRENT_WHERE'} and $OptVals{'CURRENT_WHERE'}!~/^\s*(and|or)/i)	{
		$w_join1 = ' AND ';
	}
	my $w_join2 = '';
	if($OptVals{'WHERE_LIST'} and ($OptVals{'WHERE_LEVELS'} or $OptVals{'CURRENT_WHERE'}) and $OptVals{'WHERE_LIST'}!~/^\s*(and|or)/i)	{
		$w_join2 = ' AND ';
	}
	$self->{'Config'}{'Sort'} = $sortvals;
	my $sql = '';
	my $error = '';
	if($self->{'Config'}{'SQLBuilder'})	{
		($sql, $error) = $self->{'Config'}{'SQLBuilder'}->($self,\%OptVals, $self->{'RunParams'}{'ActiveFields'});
		return ('', 0, qq[<div class="warningmsg">$error</div>]) if $error;
	}
	$sql ||= $self->{'Config'}{'SQL'} || qq[
		SELECT $OptVals{'SELECT'}
		FROM $OptVals{'FROM_LEVELS'} $OptVals{'CURRENT_FROM'} $OptVals{'FROM_LIST'}
		WHERE  $OptVals{'WHERE_LEVELS'} $w_join1 $OptVals{'CURRENT_WHERE'} $w_join2 $OptVals{'WHERE_LIST'}
	];
	my @opts = (qw(
		FROM_LEVELS 
		WHERE_LEVELS 
		SELECT_LEVELS 
		CURRENT_FROM 
		CURRENT_WHERE
		FROM_LIST
		WHERE_LIST
		SELECT
	));
	for my $i (@opts)	{
		$sql =~s/###$i###/$OptVals{$i}/g;	
	}
	return ($sql || '', $continue, '');
}

sub displayOptions {
	my $self = shift;

  my $prefix = $self->{'Config'}{'FormFieldPrefix'} || '';
  my $formname = $self->{'Config'}{'FormName'} || 'updateform';
  $prefix.='_' if $prefix;
  $formname||='updateform';
  my $fields_ref=$self->{'Config'}->{'Fields'};
  my $order_ref=$self->{'Config'}->{'Order'};
	my $perms_ref = $self->{'Permissions'};

  my @sort=();
  my @grouping=();
  my $lastoptiongroup='';
	my $lang = $self->{'Lang'};
	my @groupingorder = ();
	my %seengrouping = ();
	my %groupdata = ();
  for my $i (0 .. $#$order_ref) {
    my $field_name=$order_ref->[$i] || '';
    my $linestr='';
    next if !$field_name;
    if(!exists $fields_ref->{$field_name})  {next;}
		my ($displayname, $options)=@{$fields_ref->{$field_name}};
    next if !$displayname;
		my $perms_type = $self->{'Config'}->{'DefaultPermType'} 
			|| $options->{'permissionType'}
			|| 'Member';
		if (
			$perms_ref 
			and exists $perms_ref->{$perms_type} 
			and exists $perms_ref->{$perms_type}{$field_name} 
			and !$perms_ref->{$perms_type}{$field_name}
		)	{
			next;
		}
    #if(!exists $fields_ref->{$field_name}) {print STDERR " ERROR: Cannot find $field_name\n";next;}

    $displayname = $lang->txt($displayname);

    next if $options->{'disable'};
    next if (exists $options->{'enabled'} and !$options->{'enabled'});
    my $def_val1=(
				defined $options->{'defaultvalue'} 
					and $options->{'defaultvalue'} ne ''
			) 
			?  $options->{'defaultvalue'} 
			: '';
    my $def_val2=(
				defined $options->{'defaultvalue2'} 
					and $options->{'defaultvalue2'} ne ''
			) 
			?  $options->{'defaultvalue2'} 
			: '';
    my $displ_1= $def_val1 ne '' ? 'block' : 'none';
    my $displ_2= $def_val2 ne '' ? 'block' : 'none';
    if($options->{'fieldtype'} eq 'text') {
			my $f1 = txt_field(
				'f_'.$field_name.'_1',
				$def_val1,
				$options->{'size'} || 20,
				80,
			);
			my $f2 = txt_field(
				'f_'.$field_name.'_2',
				$def_val2,
				$options->{'size'} || 20,
				80,
			);
			$linestr.=qq[<div id="d1_$prefix$field_name" style="display:$displ_1;">$f1</div>];
			$linestr.=qq[<div id="d2_$prefix$field_name" style="display:$displ_2;"> and $f2</div>];
    }
    if($options->{'fieldtype'} eq 'dropdown') {
			my $f1 = drop_down(
				'f_'.$field_name.'_1',$options->{'dropdownoptions'}, 
				$options->{'dropdownorder'}, 
				$def_val1, 
				$options->{'size'} || 1, 
				$options->{'multiple'} || 0,
				'',
			);
      $linestr.=qq[<div id="d1_$prefix$field_name" style="display:$displ_1;">$f1</div>];
      $linestr.=qq[<div id="d2_$prefix$field_name" style="display:$displ_2;"></div>];
    }
    if($options->{'fieldtype'} eq 'date' or $options->{'fieldtype'} eq 'datetime')  {
			my $f1 = txt_field(
				'f_'.$field_name.'_1',
				$def_val1,
				10,
				10,
				'dateinput',
			);
 			my $f2 = txt_field(
				'f_'.$field_name.'_2',
				$def_val2,
				10,
				10,
				'dateinput',
			);
			$linestr.=qq[<div id="d1_$prefix$field_name" style="display:$displ_1;">$f1<i>(dd/mm/yyyy)</i></div>];
			$linestr.=qq[<div id="d2_$prefix$field_name" style="display:$displ_2;"> and $f2<i>(dd/mm/yyyy)</i></div>];
    }
    if($options->{'fieldtype'} eq 'datetimefull')  {
			my $f1 = txt_field(
				'f_'.$field_name.'_1',
				$def_val1,
				20,
				10,
				'datetimeinput',
			);
 			my $f2 = txt_field(
				'f_'.$field_name.'_2',
				$def_val2,
				20,
				10,
				'datetimeinput',
			);
			$linestr.=qq[<div id="d1_$prefix$field_name" style="display:$displ_1;">$f1</div>];
			$linestr.=qq[<div id="d2_$prefix$field_name" style="display:$displ_2;"> and $f2</div>];
    }
    if($options->{'fieldtype'} eq 'none') {
      $linestr='';
    }
    my $comp_options='';
    $comp_options=compare_options(
			$field_name, 
			$prefix, 
			$options->{'fieldtype'}, 
			$options->{'defaultcomp'}, 
			$options->{'multiple'} || 0,
            $lang,
		) if $options->{'fieldtype'};

    my $active='';
    $active=' CHECKED ' if $options->{'active'};
    my $optiongroup=$options->{'optiongroup'} || 'default';
		next if $self->{'Config'}->{'OptionGroups'}{$optiongroup}[1]{'disable'};
		next if(exists  $self->{'Config'}->{'OptionGroups'}{$optiongroup}[1]{'enable'}
			and !$self->{'Config'}->{'OptionGroups'}{$optiongroup}[1]{'disable'});
		push @groupingorder, $optiongroup if !$seengrouping{$optiongroup};
		$seengrouping{$optiongroup} = 1;

    my $nclass    = '';
    my $fonlytext = '';

    if (defined $options->{'filteronly'} and $options->{'filteronly'}) {
			$nclass = 'ROfonly';
			$fonlytext = ' [<i>' . $lang->txt('Filter Only') . '</i>] ';
		}
		my $displaylabel = $lang->txt('Display');
		my $filterlabel = $lang->txt('Filter');
		my $removetxt = $lang->txt('Remove');
		$comp_options = qq[<label for ="f_chk_$field_name">$filterlabel :</label> $comp_options] if $comp_options;
   	my $fieldblock =qq[
      <div class="RO_fieldblock" id="fld_$field_name">
				<div class="RO_remove">
					<a href="" onclick="removefield('fld_$field_name'); return false;"><img src="images/report_field_remove.png" alt="$removetxt"></a>
					<a href="" onclick="removefield('fld_$field_name'); return false;">$removetxt</a> 
				</div>
					<div class="RO_fielddisplay"><input type="checkbox" name="f_chk_$field_name" value="1" class="ROnb" id="f_chk_$field_name" checked title="$displaylabel"></div>
				<div class="RO_fieldname $nclass">$displayname$fonlytext</div>
				<div class="RO_fielddata">
					<div class="RO_compoption">$comp_options</div>
					<div class="RO_valfields">$linestr<br></div>
				</div>
				<div class="RO_fieldblockbottom"></div>
      </div>
    ];
		push @{$groupdata{$optiongroup}}, [$field_name, $fieldblock];
    if(exists $options->{'allowsort'} and $options->{'allowsort'})  {
      push @sort, $field_name;
    }
    if(exists $options->{'allowgrouping'} and $options->{'allowgrouping'})  {
      push @grouping, $field_name;
    }
  }

  my $allfields ='';
	for my $group (@groupingorder)	{
		my $grpdata = '';
		for my $i (@{$groupdata{$group}})	{
			$grpdata .= qq[<li class="fieldblock-li">$i->[1]</li>] || '';
		}
		my $groupname = $lang->txt($self->{'Config'}->{'OptionGroups'}{$group}[0]);
		if($grpdata)	{
			$allfields .= qq[
				<h3><a href="#">$groupname</a></h3>
				<div>
					<ul class="connectedSortable" id="fieldgrouping_$group">
						$grpdata
					</ul>
				</div>	
			];
		}
	}
  my $returnstr='';
  if ($self->{'Config'}->{'Config'}{'RunButtonLabel'}) {

		my $run_button_label = $lang->txt(
				$self->{'Config'}->{'Config'}{'RunButtonLabel'}
		);
		$returnstr.=qq[
			<div class="ROrunButton"><input type="submit" value="$run_button_label" class="button proceed-button ROButRun"></div>
		];
	}
  if (
		not exists $self->{'Config'}->{'Config'}{'ShowDistinct'}
		or (exists  $self->{'Config'}->{'Config'}{'ShowDistinct'}
				and  $self->{'Config'}->{'Config'}{'ShowDistinct'} == 1)
	) {

		my @record_filter_options = (
				[ 'DISTINCT', $lang->txt('Unique Records Only') ],
				(
						$self->{'Config'}->{'Config'}{'NoSummaryData'}
								? ()
								: ( [ 'SUMMARY', $lang->txt('Summary Data') ] )
				),
				[ 'ALL', $lang->txt('All Records') ],
		);

		my $record_filter_options = '';
		for my $i (@record_filter_options)	{
			my $selected = $i->[0] eq 'DISTINCT' ? ' CHECKED ' : '';
			$record_filter_options .= qq[<input type="radio" name="RO_RecordFilter" value="$i->[0]" id="RO_RF_$i->[0]" $selected><label for="RO_RF_$i->[0]">$i->[1]</label>];
		}

		my $options_header = $lang->txt('Options');
		my $show_label     = $lang->txt('Show');

		$returnstr.=qq[
			<div class="ROoptionblock">
				<div class="ROoptionblock-header">$options_header</div>
				<table>
						<tr>
								<td>$show_label</td>
								<td>
										$record_filter_options
								</td>
						</tr>
		];
	}

  if(@sort) {

		my $sort_by_label           = $lang->txt('Sort by');
		my $secondary_sort_by_label = $lang->txt('Secondary sort by');
		my $ascending_option        = $lang->txt('Ascending');
		my $descending_option       = $lang->txt('Descending');
		my $none_option             = $lang->txt('None');

    my $sort1list = '';
		for my $field (@sort) {
			$sort1list .=qq[<option value="$field">$fields_ref->{$field}[0]</option>];
		}
    my $sort=qq[
			<tr>
				<td>$sort_by_label</td>
        <td><select name="RO_SortBy1" size="1" class = "chzn-select">$sort1list</select>
      &nbsp;
      <select name="RO_SortByDir1" size="1">
        <option value="ASC">$ascending_option</option>
        <option value="DESC">$descending_option</option>
      </select>
        </td>
      </tr>
    ];
    if(exists $self->{'Config'}->{'Config'}{'SecondarySort'} and  $self->{'Config'}->{'Config'}{'SecondarySort'} == 1)  {
			my $sort2list = '';
			for my $field (@sort) {
				$sort2list .=qq[<option value="$field">$fields_ref->{$field}[0]</option>];
			}
      $sort.=qq[
      <tr>
				<td>$secondary_sort_by_label</td>
        <td>
					<select name="RO_SortBy2" size="1" class = "chzn-select">
          <option value="">$none_option</option>
					$sort2list
				 </select>
        &nbsp;
        <select name="RO_SortByDir2" size="1">
          <option value="ASC">$ascending_option</option>
          <option value="DESC">$descending_option</option>
        </select>
        </td>
       </tr>
      ];
    }
    $returnstr.=$sort || '';
  }

	my $group_by_label = $lang->txt('Group By');

  if(@grouping) {
		my $grouplist = '';
    for my $field (@grouping) {
      $grouplist .=qq[<option value="$field">].$lang->txt($fields_ref->{$field}[0]).qq[</option>];
    }
    $returnstr.=qq[
    <tr>
      <td>$group_by_label</td>
      <td><select name="RO_GroupBy" size="1" class = "chzn-select">
          <option value="">].$lang->txt('No Grouping').qq[</option>
					$grouplist
        </select>
      </td>
    </tr>
    ];
  }
  $returnstr.='</table></div>';

  if($self->{'Config'}->{'Config'}{'EmailExport'})  {
    $returnstr.=qq[
      <div class="ROoptionblock">
          <div class="ROoptionblock-header">Report Output</div>
        <div style="">
          Choose how you want to receive the data from this report.

          <div style="padding:5px;">
            <input type="radio" name="RO_OutputType" value="screen" class="ROnb" checked id="RO_Output_display"><label for="RO_Output_display"> <b>Display</b></label>
           <div style="margin-left:20px;">
              <i>Open the report for viewing on the screen.</i>
            </div>
          </div>
          <div style="padding:5px;">
            <input type="radio" name="RO_OutputType" value="email" class="ROnb" id="RO_Output_email"><label for="RO_Output_email"> <b>Email</b></label>
            <div style="margin-left:20px;">
              <i>Email the report in a format suitable to be imported into another product.</i><br>
              <b>Email Address</b> <input type="text" size="45" name="RO_OutputEmail">
            </div>
          </div>
      </div>
      </div>
    ];
  }
  $returnstr.=qq[
      <div class="ROrunButton"><input type="submit" value="$self->{'Config'}->{'Config'}{'RunButtonLabel'}" class="button proceed-button ROButRun"></div>
  ] if $self->{'Config'}->{'Config'}{'RunButtonLabel'};
  if($returnstr)  {
		my $carryfields = '';
		if($self->{'CarryFields'})	{
			for my $k (keys %{$self->{'CarryFields'}})	{
				$carryfields .= qq[<input type="hidden" name="$k" value="$self->{'CarryFields'}{$k}">];
			}
		}
	my $preblock = $self->{'Config'}{'PreBlock'} 
		? qq[<div id= "ROPreBlock">$self->{'Config'}{'PreBlock'}</div>]
		: '';
	my $preblock_beforeform = $self->{'Config'}{'PreBlockBeforeForm'} 
		? qq[<div id= "ROPreBlock">$self->{'Config'}{'PreBlockBeforeForm'}</div>]
		: '';
	my $postblock = $self->{'Config'}{'PostBlock'} 
		? qq[<div id= "ROPostBlock">$self->{'Config'}{'PostBlock'}</div>]
		: '';
	my $savedreports = $self->SavedReportBlock();
	my $intro = $lang->txt('ADV_REPORT_INTRO');
	my $returl = $self->{'ReturnURL'}
		? qq[ <a href="$self->{'ReturnURL'}">&lt; Return to Report Manager</a>]
		: '';
    $returnstr=qq[
			$returl
  <script type="text/javascript" src = "js/advancedreports.js"></script>
  <script type="text/javascript" src = "js/timepicker.js"></script>
<style type="text/css">
/* css for timepicker */
.ui-timepicker-div .ui-widget-header { margin-bottom: 8px; }
.ui-timepicker-div dl { text-align: left; }
.ui-timepicker-div dl dt { height: 25px; margin-bottom: -25px; }
.ui-timepicker-div dl dd { margin: 0 10px 10px 65px; }
.ui-timepicker-div td { font-size: 90%; }
.ui-tpicker-grid-label { background: none; border: none; margin: 0; padding: 0; }

.ui-timepicker-rtl{ direction: rtl; }
.ui-timepicker-rtl dl { text-align: right; }
.ui-timepicker-rtl dl dd { margin: 0 65px 10px 10px; }
</style>
		<div class="RO_adv_intro">$intro</div>
		<div id = "ROallfields-wrapper">
			<div id = "ROallfields">
			$allfields
			</div>
		</div>
		<div id = "ROreportselect-wrapper">
				$preblock_beforeform
			<form action = "$self->{'Data'}{'target'}" method="POST" id="reportform">
				$preblock
				<div id = "ROselectedfields-wrapper">
					<h3>Selected Fields</h3><br>
					<div id = "ROselectedfields">
						<ul class="connectedSortable" id="ROselectedfields-list"> </ul>
					</div>
				</div>
					$returnstr
					<input type="hidden" name="d_ROselectedfieldlist" id="ROselectedfieldlist">
					$carryfields
					$savedreports
					$postblock
				</form>
			</div>
    ];
  }

  return $returnstr;
}

sub processSubmission {
	my $self = shift;
	my $db = $self->{'db'};

  my $fields_ref = $self->{'Config'}{'Fields'};
  my $order_ref = $self->{'Config'}{'Order'};
  $self->{'RunParams'} = (); #Clear out any old parameters;

  my %activefields=();
  my $wherelist='';
  my $havinglist='';
  my %activeFromlist=();
  my @activeFromlist=();
  my %activeWherelist=();

	my $params = $self->{'FormParams'};
	if(
		$params->{'RO_SR_run'}
		or $params->{'RO_SR_load'}
		or $params->{'RO_SR_save'}
		or $params->{'RO_SR_del'}
	)	{
		my $response = '';
		if($params->{'RO_SR_run'} and $params->{'repID'})	{
			$self->processSavedReportData($params->{'repID'});
		}
		elsif($params->{'RO_SR_save'})	{
			my $newID = 0;
			($response, $newID) = $self->saveReportData($params);
			$params->{'RO_SR_load'} = 1;
			$params->{'repID'} = $newID;
			#return ('','','','','',0,$response);
		}
		elsif($params->{'RO_SR_del'} and $params->{'repID'})	{
			$response = $self->deleteSavedReportData($params->{'repID'});
			return ('','','','','',0,$response);
		}
		if($params->{'RO_SR_load'} and $params->{'repID'})	{
			my ($reportname, $reportdata) = $self->loadSavedReportData($params->{'repID'});
			$reportname =~s/"/&quot;/g;
			$reportdata =~s/"/&quot;/g;
			my $returnstr = qq[
				<input type="hidden" name="savedreportname" id = "SavedReportName" value="$reportname">
				<input type="hidden" name="savedreportdata" id = "SavedReportData" value="$reportdata">
			]. $response;
			return ('','','','','',0,$returnstr);
		}
	}
	if($params->{'d_ROselectedfieldlist'})	{
		my @o = split(/\s*,\s*/,$params->{'d_ROselectedfieldlist'});
		for my $o (@o)	{
			$o=~s/^fld_//g;
		}
		$self->{'RunParams'}{'Order'} = \@o || $self->{'Config'}{'Order'};
	}
	$order_ref = $self->{'RunParams'}{'Order'};
	my @OutputOrder = ();
  for my $fieldname (@{$order_ref}) {
    next if !exists $fields_ref->{$fieldname};
    my $usehaving = $fields_ref->{$fieldname}[1]{'usehaving'} || 0;
    if((exists $params->{'f_chk_'.$fieldname} and $params->{'f_chk_'.$fieldname})
      or $params->{'f_comp_'.$fieldname}) {
      if(exists $params->{'f_chk_'.$fieldname} and $params->{'f_chk_'.$fieldname})  {
        #Field is active
        $activefields{$fieldname}=1;
      }
      if(exists $fields_ref->{$fieldname}[1]{'filteronly'} and $fields_ref->{$fieldname}[1]{'filteronly'})  {
        delete $activefields{$fieldname};
      }
			push @OutputOrder, $fieldname if $activefields{$fieldname};
      my $DBfieldname=$fieldname;
      if(exists $fields_ref->{$fieldname}[1]{'dbfield'} and $fields_ref->{$fieldname}[1]{'dbfield'})  {
        $DBfieldname=$fields_ref->{$fieldname}[1]{'dbfield'}
      }
      my $op=$params->{'f_comp_'.$fieldname} || '';
			$activefields{'RAW_f_comp'.$fieldname} = $op;
      my $val1=(defined $params->{'f_'.$fieldname.'_1'} and $params->{'f_'.$fieldname.'_1'} ne '') 
				? $params->{'f_'.$fieldname.'_1'} 
				: '';
			$activefields{'RAW_f_'.$fieldname.'_1'} = $val1;
      if($val1 =~/\0/)	{
				my @v = split /\0/,$val1;
				$activefields{'RAW_f_'.$fieldname.'_1'} = \@v;
			}
      my $val2=(defined $params->{'f_'.$fieldname.'_2'} and $params->{'f_'.$fieldname.'_2'} ne '') 
				? $params->{'f_'.$fieldname.'_2'} 
				: '';
			$activefields{'RAW_f_'.$fieldname.'_2'} = $val2;

      if( $fields_ref->{$fieldname}[1]{'fieldtype'} eq 'datetimefull')  {
	$val1= _fixDateTime($val1) if $val1;
        $val2= _fixDateTime($val2) if $val2;
      }
      if( $fields_ref->{$fieldname}[1]{'fieldtype'} eq 'date')  {
	$val1= _fixDate($val1) if $val1;
        $val2= _fixDate($val2) if $val2;
      }
      if( $fields_ref->{$fieldname}[1]{'fieldtype'} eq 'datetime')    {
				$val1= _fixDate($val1) if $val1;
				$val2= _fixDate($val2) if $val2;
	if ($val2)  {
					$val2 = "$val2 23:59:59";
        }
        else  {
					$val2 = "$val1 23:59:59" if $val1;
        }
				$val1 = "$val1 00:00:00" if $val1;
				$op = 'between' if ($op eq 'equal');
			}
      if($op eq 'between' and $val1 ne '' and $val2 ne '')  {
        if($usehaving)  {
          $havinglist.=qq[ AND ] if $havinglist;
        }
        else  {
          $wherelist.=qq[ AND ] if $wherelist;
        }
        $val1=_deQuote($db,$val1);
        $val2=_deQuote($db,$val2);
        if($usehaving)  {
          $havinglist.=qq[ $DBfieldname >= $val1  AND $DBfieldname <= $val2];
        }
        else  {
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
        if($op eq 'isblank'  or $op eq 'isnotblank')  { $val1=$val2='BLANK'; }
        if($op eq 'equal' and $val1=~/\((.*,.*)\)/) { $val1=join("\0",split /,/,$1); }
        if($op eq 'like') {$val1=~s/\*/%/g; }
        next if !$opsym;
        if($usehaving)  {
          $havinglist.=' AND ' if $havinglist;
        }
        else  {
          $wherelist.=' AND ' if $wherelist;
        }
        my @v=split("\0",$val1);
        my $vline='';
        for my $v (@v)  {
          $vline.=' OR ' if($vline and $op ne 'notequal');
          $vline.=' AND ' if($vline and $op eq 'notequal') ;
          $v=_deQuote($db,$v);
          if($fields_ref->{$fieldname}[1]{'dbwherefieldalias'}) {
            $vline.="( $DBfieldname $opsym $v ";
            my $i=0;
            while($i < $#{$fields_ref->{$fieldname}[1]{'dbwherefieldalias'}}) {
              my $joiner=$fields_ref->{$fieldname}[1]{'dbwherefieldalias'}[$i];
              my $fnme=$fields_ref->{$fieldname}[1]{'dbwherefieldalias'}[$i+1];
              $vline.=" $joiner $fnme $opsym $v ";
              $i+=2;
            }
            $vline.=")";
          }
          else  {
            if($op eq 'isblank')  { $vline.=" ($DBfieldname='' OR $DBfieldname IS NULL) "; }
            elsif($op eq 'isnotblank')  { $vline.=" ($DBfieldname <>'' AND $DBfieldname IS NOT NULL) "; }
            else  { $vline.=" $DBfieldname $opsym $v "; }
          }
        }
        $vline="($vline)" if @v >1;
        if($usehaving)  {
          $havinglist.=$vline;
        }
        else  {
          $wherelist.=$vline;
        }
      }
      #Check to see if we have to add tables or join conditions
      if(
				exists $fields_ref->{$fieldname}[1]{'dbfrom'} 
			 	and $fields_ref->{$fieldname}[1]{'dbfrom'})  {

        if(ref $fields_ref->{$fieldname}[1]{'dbfrom'})  {
          #Array of dbfroms
          for my $f (@{$fields_ref->{$fieldname}[1]{'dbfrom'}}) {
            push @activeFromlist, $f if !$activeFromlist{$f};
            $activeFromlist{$f}=1;
          }
        }
        else  {
          push @activeFromlist, $fields_ref->{$fieldname}[1]{'dbfrom'} if !$activeFromlist{$fields_ref->{$fieldname}[1]{'dbfrom'}};
          $activeFromlist{$fields_ref->{$fieldname}[1]{'dbfrom'}}=1;
        }
      }
      if(exists $fields_ref->{$fieldname}[1]{'dbwhere'} 
				and $fields_ref->{$fieldname}[1]{'dbwhere'})  {
        $activeWherelist{$fields_ref->{$fieldname}[1]{'dbwhere'}}=1;
      }
      if(exists $fields_ref->{$fieldname}[1]{'optiongroup'} 
				and $fields_ref->{$fieldname}[1]{'optiongroup'})  {
        if(exists $self->{'Config'}->{'OptionGroups'} 
					and exists $self->{'Config'}->{'OptionGroups'}{$fields_ref->{$fieldname}[1]{'optiongroup'}} 
					and $self->{'Config'}->{'OptionGroups'}{$fields_ref->{$fieldname}[1]{'optiongroup'}}[1] ) {

          my $group_options=$self->{'Config'}->{'OptionGroups'}{$fields_ref->{$fieldname}[1]{'optiongroup'}}[1];
          if($group_options and exists $group_options->{'from'} and $group_options->{'from'}) {

            if(ref $group_options->{'from'})  {
              #Array of dbfroms
              for my $g (@{$group_options->{'from'}}) {
                push @activeFromlist, $g if !$activeFromlist{$g};
                $activeFromlist{$g}=1;
              }
            }
            else  {
              push @activeFromlist, $group_options->{'from'} if !$activeFromlist{$group_options->{'from'}};
              $activeFromlist{$group_options->{'from'}}=1;
            }
          }
          if($group_options 
						and exists $group_options->{'where'} 
						and $group_options->{'where'}) {
            $activeWherelist{$group_options->{'where'}}=1;
          }
        }
      }
    }
  }
	my @sort_data = ();
	my $sortby=$self->untaint($params->{'RO_SortBy1'},'string') || '';
  my $sortby_field=$sortby;
  #if(exists $fields_ref->{$sortby_field}[1]{'dbfield'} 
		#and $fields_ref->{$sortby_field}[1]{'dbfield'})  {
    #$sortby=$fields_ref->{$sortby_field}[1]{'dbfield'};
  #}
  #if(exists $fields_ref->{$sortby_field}[1]{'sortfield'} 
		#and $fields_ref->{$sortby_field}[1]{'sortfield'} ne '')  {
    #$sortby=$fields_ref->{$sortby_field}[1]{'sortfield'};
  #}
  if(!$activefields{$sortby_field}) {
    if(exists $fields_ref->{$sortby_field}[1]{'dbfrom'} 
			and $fields_ref->{$sortby_field}[1]{'dbfrom'})  {
      if(ref $fields_ref->{$sortby_field}[1]{'dbfrom'}) {
        #Array of dbfroms
        for my $f (@{$fields_ref->{$sortby_field}[1]{'dbfrom'}})  {
          push @activeFromlist, $f if !$activeFromlist{$f};
          $activeFromlist{$f}=1;
        }
      }
      else  {
        push @activeFromlist,  $fields_ref->{$sortby_field}[1]{'dbfrom'} if !$activeFromlist{$fields_ref->{$sortby_field}[1]{'dbfrom'}};
        $activeFromlist{$fields_ref->{$sortby_field}[1]{'dbfrom'}}=1;
      }
    }
    if(exists $fields_ref->{$sortby_field}[1]{'dbwhere'} 
			and $fields_ref->{$sortby_field}[1]{'dbwhere'})  {
      $activeWherelist{$fields_ref->{$sortby_field}[1]{'dbwhere'}}=1;
    }
  }
  my $RO_SortByDir =$params->{'RO_SortByDir1'} || 'ASC';
	push @sort_data, [ $sortby, $RO_SortByDir, $fields_ref->{$sortby_field}[1]{'sorttype'} || 'string'];

  if(exists $self->{'Config'}{'Config'}{'SecondarySort'} 
		and  $self->{'Config'}{'Config'}{'SecondarySort'} == 1)  {

    my $sortby2=$self->untaint($params->{'RO_SortBy2'},'string') || '';
    my $sortby2_field=$sortby2;
    #if(exists $fields_ref->{$sortby2_field}[1]{'dbfield'} and $fields_ref->{$sortby2_field}[1]{'dbfield'})  {
      #$sortby2=$fields_ref->{$sortby2_field}[1]{'dbfield'};
    #}
    #if(exists $fields_ref->{$sortby2_field}[1]{'sortfield'} and $fields_ref->{$sortby2_field}[1]{'sortfield'} ne '')  {
      #$sortby2=$fields_ref->{$sortby2_field}[1]{'sortfield'};
    #}
	  if($sortby2)	{
			my $RO_SortByDir2 = $params->{'RO_SortByDir2'} || 'ASC';
			push @sort_data, [ $sortby2, $RO_SortByDir2, $fields_ref->{$sortby2_field}[1]{'sorttype'} || 'string'];
		}
    if(!$activefields{$sortby2_field})  {
      if(exists $fields_ref->{$sortby2_field}[1]{'dbfrom'} 
				and $fields_ref->{$sortby2_field}[1]{'dbfrom'})  {
        if(ref $fields_ref->{$sortby2_field}[1]{'dbfrom'})  {
          #Array of dbfroms
          for my $f (@{$fields_ref->{$sortby2_field}[1]{'dbfrom'}}) {
            push @activeFromlist, $f if !$activeFromlist{$f};
            $activeFromlist{$f}=1;
          }
        }
        else  {
          push @activeFromlist, $fields_ref->{$sortby2_field}[1]{'dbfrom'} if !$activeFromlist{$fields_ref->{$sortby2_field}[1]{'dbfrom'}};
          $activeFromlist{$fields_ref->{$sortby2_field}[1]{'dbfrom'}}=1;
        }
      }
      if(exists $fields_ref->{$sortby2_field}[1]{'dbwhere'} 
				and $fields_ref->{$sortby2_field}[1]{'dbwhere'})  {
        $activeWherelist{$fields_ref->{$sortby2_field}[1]{'dbwhere'}}=1;
      }
    }
  }

  $activefields{'RO_RecordFilter'}= $params->{'RO_RecordFilter'} || 'DISTINCT';
  $activefields{'RO_RecordFilter'}= 'DISTINCT' if $activefields{'DISTINCT'};
	$self->{'RunParams'}{'Distinct'} = 1 if $activefields{'RO_RecordFilter'} eq 'DISTINCT';
	$self->{'RunParams'}{'Summarise'} = 1 if $activefields{'RO_RecordFilter'} eq 'SUMMARY';
	$self->{'RunParams'}{'Limit'} = $params->{'limit'} || '';
	$self->{'RunParams'}{'ViewType'} = $params->{'RO_OutputType'} || '';
	$self->{'RunParams'}{'SendToEmail'} = $params->{'RO_OutputEmail'} || '';
	$self->{'FormParams'}{'ReturnData'} = 1 if $params->{'retprocess'};

  $activefields{'exformat'}= $params->{'exformat'} || '';
  $activefields{'exformat'}=~s/^W_//;
  if($activefields{'exformat'} and $activefields{'RO_OutputType'} eq 'email')  {
    my $f=$self->{'Config'}{'Config'}->{'ExportFormats'}{$activefields{'exformat'}}{'From'} || '';
    push @activeFromlist, $f if !$activeFromlist{$f};
    $activeFromlist{$f}=1;
  }
	$self->{'RunParams'}{'GroupBy'} = $self->untaint($params->{'RO_GroupBy'},'string') || '';
  if($self->{'RunParams'}{'GroupBy'})  {
    if(!$activefields{$self->{'RunParams'}{'GroupBy'}})  {
      $activefields{$self->{'RunParams'}{'GroupBy'}}=1;
      my $f=$self->{'RunParams'}{'GroupBy'};
      if(exists $fields_ref->{$f}[1]{'dbformat'} 
				and $fields_ref->{$f}[1]{'dbformat'})  {
        if(ref $fields_ref->{$f}[1]{'dbformat'})  {
          #Array of dbfroms
          for my $g (@{$fields_ref->{$f}[1]{'dbformat'}}) {
            push @activeFromlist, $g if !$activeFromlist{$g};
            $activeFromlist{$g}=1;
          }
        }
        else  {
          push @activeFromlist, $fields_ref->{$f}[1]{'dbfrom'} if !$activeFromlist{$fields_ref->{$f}[1]{'dbfrom'}};
          $activeFromlist{$fields_ref->{$f}[1]{'dbfrom'}}=1;
        }
      }
      if(exists $fields_ref->{$f}[1]{'dbwhere'} 
				and $fields_ref->{$f}[1]{'dbwhere'})  {
        $activeWherelist{$fields_ref->{$f}[1]{'dbwhere'}}=1;
      }
    }
  }
  my $fromlist=join(' ',@activeFromlist) || '';
  my $actWherelist=join(' ',keys %activeWherelist);
  $wherelist.=$actWherelist || '';
  # Check for other values to be passed through
  for my $k (keys %{$params}) {
    $activefields{$k} = $params->{$k} if $k=~/^_EXT/;
  }
	
	$self->{'RunParams'}{'Order'} = \@OutputOrder;
	#Generate Labels
	if($self->{'RunParams'}{'GroupBy'})	{
		#Change the order to make group by column first
		@{$self->{'RunParams'}{'Order'}} = grep { $_ ne $self->{'RunParams'}{'GroupBy'}} @{$self->{'RunParams'}{'Order'}};
		unshift @{$self->{'RunParams'}{'Order'}}, $self->{'RunParams'}{'GroupBy'};
	}
	for my $i (@{$self->{'RunParams'}{'Order'}})	{
		next if !$activefields{$i};
		next if $self->{'Config'}{'Fields'}{$i}[1]{'filteronly'};
		push @{$self->{'Config'}{'Labels'}}, [ $i, $self->{'Config'}{'Fields'}{$i}[0]];
	}
  return (\%activefields, $wherelist, \@sort_data, $fromlist, $havinglist, 1, '');
}

sub genSelect {
	my $self = shift;
  my($activefields)=@_;

  my $groupby_vals='';
  my %selected_values=();
  my %selected_fields=();
  my $fields_ref=$self->{'Config'}{'Fields'};
  my $emaildata= $activefields->{'RO_OutputType'} eq 'email' ? 1 : 0;
  my $retprocessdata= (
		$self->{'FormParams'}{'ReturnData'}
			and $self->{'Config'}->{'Config'}{'ReturnProcessData'}
	) ? 1 : 0;
  for my $field (@{$self->{'RunParams'}{'Order'}})	{
    if($activefields->{$field}) {
      next if !exists $fields_ref->{$field};
      next if(
				exists $fields_ref->{$field}[1]{'dbfield'}  
				and !defined $fields_ref->{$field}[1]{'dbfield'} 
			);
      if($fields_ref->{$field}[1]{'dbformat'} ) {
        $selected_fields{$fields_ref->{$field}[1]{'dbformat'} . " AS $field"} = 1;
      	if($fields_ref->{$field}[1]{'dbfield'} ) {
					$selected_fields{"$fields_ref->{$field}[1]{'dbfield'} AS $field".'_RAW'} = 1;
				}
      }
      elsif($fields_ref->{$field}[1]{'dbfield'} ) {
        $selected_fields{$fields_ref->{$field}[1]{'dbfield'}. " AS $field"} = 1;
      }
      else  { 
				$selected_fields{$field} = 1;
			}
      $selected_values{$field}=1;
    }
  }
  if($retprocessdata) {
    #If we are supposed to return process data - make sure we have all the fields required. 
    #We are not writing the select line, as it may affect the grouping and distincts
    for my $i (@{$self->{'Config'}->{'Config'}{'ReturnProcessData'}}) {
      if(!exists $selected_values{$i})  {
				$selected_fields{$i} = 1;
        $selected_values{$i}=1;
      }
    }
  }
  # We have handle the normal values lets loop through and see if we need to generate links for any of the active fields.  If so, do we have all the fields we need.
  for my $key (keys %{$self->{'Config'}->{'links'}})  {
    if($activefields->{$key}) {
      for my $otherfield (@{$self->{'Config'}->{'links'}{$key}[1]}) {
        if(!exists $selected_values{$otherfield}) {
          if($self->{'Config'}{'Fields'}{$otherfield}[1]{'dbfield'} ) {
            $selected_fields{$self->{'Config'}{'Fields'}{$otherfield}[1]{'dbfield'}. " AS $otherfield"} = 1;
          }
          else  { $selected_fields{$otherfield} = 1; }
          $selected_values{$otherfield}=1;
        }
      }
    }
  }
	my $select_vals = join(', ',keys %selected_fields);
  return $select_vals;
}

sub _fixDateTime  {
  my($date)=@_;
	return $date if $date!~/\//;
  my ($day, $month, $year, $hms)=split /\/| /,$date;

  if(defined $year and $year ne '' and defined $month and $month ne '' and defined $day and $day ne '') {
    $month='0'.$month if length($month) ==1;
    $day='0'.$day if length($day) ==1;
    if($year > 20 and $year < 100)  {$year+=1900;}
    elsif($year <=20) {$year+=2000;}
    $date="$year-$month-$day $hms:00";
  }
  else  { $date='';}
  return $date;
}

sub _fixDate  {
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


sub _deQuote {
  my ($db, $val)=@_;
  return $db->quote($val) if $db;
  #No DB reference lets do our best
  if($val=~/^\d+$/) {
    #just digits
    return $val; #nothing to do
  }
  $val=~s/'/''/; #escape quotes
  return "'$val'";
}

sub compare_options {
  my($fieldname, $prefix, $fieldtype, $value, $multiple, $lang)=@_;
  $prefix||='';
  $value||='';

  my @options=();
  push @options,['isblank','Is Blank'];
  push @options,['isnotblank','Is Not Blank'];
  if($fieldtype ne 'none')  {
    push @options,['equal','Equals'];
    push @options,['notequal','Not Equals'];
  }
  if($fieldtype ne 'none' and $fieldtype ne 'dropdown') {
    push @options,['like','Like'];
  }

  if (!$multiple and ($fieldtype eq 'text' or $fieldtype eq 'date' or $fieldtype eq 'datetime' or $fieldtype eq 'datetimefull'))  {
    push @options,['lessthan','Less Than'];
    push @options,['morethan','More Than'];
    push @options,['between','Between'];
  }
	my $options = '';
  for my $i (@options)  {
    my $selected=$value eq $i->[0] ? ' SELECTED ' : '';
    $options .=
        qq[<option $selected value="$i->[0]">] .
        $lang->txt($i->[1]) .
        q[</option>];
  }

  my $subBody=qq[
  <select id="fid_comp_$fieldname" name="f_comp_$fieldname" size="1" onchange="displaybox('$prefix$fieldname');">
    <option value="">&nbsp;</option>
		$options
  </select>
  ];
}

sub _getSavedReportList	{
	my $self = shift;
	my $db = $self->{'db'};
	my $id = $self->{'ID'} || 0;
	my ($defval) = @_;
	$defval = '' if !defined $defval;

	my $st = qq[
		SELECT 
			intSavedReportID,
			strReportName
		FROM tblSavedReports
		WHERE 
			intLevelID = ?
			AND intID = ?
			AND intReportID = ?
		ORDER BY strReportName
	];
	my $q = $db->prepare($st);
	$q->execute(
		$self->{'EntityTypeID'},
		$self->{'EntityID'},
		$id,
	);
	my $options = '';
	while(my($id, $value) = $q->fetchrow_array())	{
		my $selected = $defval == $id ? ' SELECTED ' : '';
		$options .=qq[<option value="$id" $selected >$value</option>];
	}
	return '' if !$options;
	my $list = qq[
		<select name="repID" size="1" class = "chzn-select">
			<option value=""></option>
			$options
		</select>
	];
	return $list || '';
}

sub SavedReportBlock	{
	my $self = shift;
	my $db = $self->{'db'};
	my $id = $self->{'ID'} || 0;

	my $options = $self->_getSavedReportList();
	my $editbutton = q[<input type="submit" name="RO_SR_load" value="Edit" class="button-small generic-button">];
	my $runbutton = q[<input type="submit" name="RO_SR_run" value="Run" class="button-small proceed-button ROButRun">];
	my $delbutton = q[<input type="submit" name="RO_SR_del" value="Delete" class="button-small cancel-button" onclick="return confirm('Are you sure you want to delete this report?');">];
	if(!$options)	{
		$editbutton = $runbutton = $delbutton = '';
	}
	my $body = q[
    <script type="text/javascript">
			jQuery(function()	{
				jQuery('#ROSaveButton').click(function() {

					var d = jQuery('#ROsavedialog').dialog({
            modal: true,
            autoOpen: false,
            close: function(ev, ui) { jQuery(this).dialog('destroy'); },
            height: 200,
            width: 400,
            resizable: false,
            title: 'Enter Report Name',
            buttons: {
              "Cancel": function() { jQuery(this).dialog("close"); },
              "Save": function() {
                jQuery('#ROSaveButtonVal').val('1');
                var newname = jQuery('#ROsavedname').val();
                jQuery('#RO_NewReportNameID').val(newname);
                jQuery('#reportform').submit();
                jQuery(this).dialog("close");
              }
            }
					});
					d.dialog('open');
					return false;
				});
			});
    </script>
		].qq[
		<div class="ROoptionblock">
			<div class="ROoptionblock-header">Saved Reports</div>
			$options
			$runbutton
			$editbutton
			<input type="submit" name="RO_SR_savebut" value="Save" id="ROSaveButton" class="button-small generic-button">
			<input type="hidden" name="RO_SR_save" value="0" id="ROSaveButtonVal">
			<input type="hidden" name="RO_NewReportName" value="" id="RO_NewReportNameID">
			$delbutton
		</div>
		<div id="ROsavedialog" style="display:none;">
		<br><br>
			<input id="ROsavedname" type="text" name="RO_reportname" class="text ui-widget-content ui-corner-all" size = "45">
		</div>
	];
	return $body;
}

sub loadSavedReportData	{
	my $self = shift;
	my $db = $self->{'db'};
	my ($reportID) = @_;
	my $st = qq[
		SELECT 
			strReportName,
			strReportData
		FROM tblSavedReports
		WHERE 
			intSavedReportID = ?
	];
	my $q = $db->prepare($st);
	$q->execute(
		$reportID,
	);
	my ($name, $data) = $q->fetchrow_array();
	$q->finish();
	return ($name || '', $data || '');
}

sub processSavedReportData	{
	my $self = shift;
	my $db = $self->{'db'};
	my ($reportID) = @_;
	$self->loadSaved($reportID);
	my ($reportname, $reportdata) = $self->loadSavedReportData($reportID);
	return undef if !$reportdata;
	my $json = from_json($reportdata || '');
	for my $k (keys %{$json->{'options'}})	{
		if($k =~ /^_EXT/)	{
			$self->{'FormParams'}{$k} = $json->{'options'}{$k};
		}
		else	{
			$self->{'FormParams'}{'RO_'.$k} = $json->{'options'}{$k};
		}
	}
	my %seenfields = ();
	for my $r (@{$json->{'fields'}})	{
		my $fieldname = $r->{'name'} || next;
		next if $seenfields{$fieldname};	
		$seenfields{$fieldname} = 1;
		$self->{'FormParams'}{'d_ROselectedfieldlist'} .= 'fld_'.$fieldname.',';
		$self->{'FormParams'}{'f_comp_'.$fieldname} = $r->{'comp'};
		$self->{'FormParams'}{'f_chk_'.$fieldname} = $r->{'display'};
		$self->{'FormParams'}{'f_'.$fieldname.'_1'} = $r->{'v1'};
		$self->{'FormParams'}{'f_'.$fieldname.'_2'} = $r->{'v2'};
	}
}

sub saveReportData	{
	my $self = shift;
	my $db = $self->{'db'};

	my $params = $self->{'FormParams'};

	my %options = ();
	my @fields = ();
	my @optarray = (qw(
		RO_RecordFilter 
		RO_SortBy1 
		RO_SortByDir1 
		RO_SortBy2 
		RO_SortByDir2 
		RO_GroupBy 
		RO_OutputType 
		RO_OutputEmail
	));
	for my $o (@optarray)	{
		my $okey = $o;
		$okey =~ s/^RO_//;
		$options{$okey} = $params->{$o};
	}
	for my $k (keys %{$params})	{
		if($k =~ /^_EXT/)	{
			$options{$k} = $params->{$k};
		}
	}

	if($params->{'d_ROselectedfieldlist'})	{
		my @order = split(/\s*,\s*/,$params->{'d_ROselectedfieldlist'});
		for my $o (@order)	{
			$o=~s/^fld_//g;
			push @fields, {
				name => $o,
				comp => $params->{'f_comp_'.$o},
				display => $params->{'f_chk_'.$o},
				v1 => $params->{'f_'.$o.'_1'},
				v2 => $params->{'f_'.$o.'_2'},
			};
		}
	}
	my %reportdatahash = (
		fields => \@fields,
		options => \%options
	);
	my $json = to_json(\%reportdatahash);
	return ('',0) if !$json;
	my $name = $params->{'RO_NewReportName'} || 'Saved Report';

	#Check existing
	{
		my %existing_names = ();
		my $max_num  = 0;
		my $st = qq[
			SELECT strReportName
			FROM tblSavedReports
			WHERE
				intLevelID = ?	
				AND intID = ?
				AND intReportID = ?	
		];
		my $q=$self->{'db'}->prepare($st);
		$q->execute(
			$self->{'EntityTypeID'},
			$self->{'EntityID'},
			$self->{'ID'},
		);
		my $existing_count = 0;
		while(my ($existing_name) = $q->fetchrow_array())	{
			$existing_count++ if $existing_name eq $name;	
			if($existing_name =~/^$name Copy \d+/)	{
				$existing_count++;
				my ($num) = $existing_name =~/Copy (\d+)/;
				$max_num = $num if $num> $max_num;
			}
		}
		if($existing_count)	{
			$name = $name." Copy ".++$max_num if $existing_count;
		}
	}

	my $st = qq[
		INSERT INTO tblSavedReports(
			intReportID,
			strReportName,
			intLevelID,
			intID,
			strReportData
		)
		VALUES (
			?,
			?,
			?,
			?,
			?
		)
	];
	my $q=$self->{'db'}->prepare($st);
	$q->execute(
		$self->{'ID'},
		$name,
		$self->{'EntityTypeID'},
		$self->{'EntityID'},
		$json,
	);
	my $newID = $q->{mysql_insertid} || 0;
	my $response = '<div class="OKmsg">Report Saved</div>';
	return ($response, $newID);
}


sub deleteSavedReportData	{
	my $self = shift;
	my $db = $self->{'db'};
	my ($reportID) = @_;
	my $st = qq[
		DELETE
		FROM tblSavedReports
		WHERE 
			intLevelID = ?
			AND intID = ?
			AND intSavedReportID = ?
	];
	my $q = $db->prepare($st);
	$q->execute(
		$self->{'EntityTypeID'},
		$self->{'EntityID'},
		$reportID,
	);
	$q->finish();
	return '<div class="OKmsg">Saved Report has been deleted</div>';
}

sub afterSubmission {
	my $self = shift;
	return undef;
}

1;
