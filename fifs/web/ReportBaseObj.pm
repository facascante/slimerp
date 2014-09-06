#
# $Header: svn://svn/SWM/trunk/web/ReportBaseObj.pm 11573 2014-05-15 02:25:10Z sliu $
#

package ReportBaseObj;

use strict;
use Sort::Maker;
use TTTemplate;
use Utils;
use Time::HiRes qw(gettimeofday tv_interval);
use Reports::ReportEmail;

sub new {

  my $this = shift;
  my $class = ref($this) || $this;
	my %params=@_;
  my $self ={};
  ##bless selfhash to class
  bless $self, $class;

	#Set Defaults
	$self->{'db'}=$params{'db'};
	$self->{'dbRun'}=$params{'dbRun'} || $params{'db'};
	$self->{'lang'}=$params{'lang'};

	$self->{'ID'}=$params{'ID'};
	$self->{'EntityID'}=$params{'EntityID'};
	$self->{'EntityTypeID'}=$params{'EntityTypeID'};
	$self->{'Data'}=$params{'Data'};
	$self->{'FormParams'}=$params{'FormParams'} || undef;
	$self->{'RunParams'}= ();
	$self->{'CarryFields'}= ();
	$self->{'ClientValues'} = $params{'ClientValues'};
	$self->{'Permissions'}=$params{'Permissions'};
	$self->{'Lang'}=$params{'Lang'};
	$self->{'ReturnURL'}=$params{'ReturnURL'};
	$self->{'SystemConfig'}=$params{'SystemConfig'};
	$self->{'OtherOptions'}=$params{'OtherOptions'};
	$self->{'DEBUG'} ||= 0;

	return undef if !$self->{'db'};
	return undef if !$self->{'ID'};
	return undef if $self->{'ID'} !~ /^\d+$/;
	$self->_loadReport();
	$self->_getConfiguration();
  return $self;
}

sub _loadReport	{
	my $self = shift;

	my $st = qq[
		SELECT *
		FROM tblReports
		WHERE intReportID = ?
	];
	my $q = $self->{'db'}->prepare($st);
	$q->execute($self->ID());
	$self->{'DBData'}{'Report'} = $q->fetchrow_hashref();
	$q->finish();
}

sub loadSaved {
	my $self = shift;
	my ($savedReportID) = @_;
	return undef if !$savedReportID;
	return undef if $savedReportID !~ /^\d+$/;

	my $st = qq[
		SELECT *
		FROM tblSavedReports
		WHERE intSavedReportID = ?
	];
	my $q = $self->{'db'}->prepare($st);
	$q->execute($savedReportID);
	$self->{'DBData'}{'Saved'} = $q->fetchrow_hashref();
	$q->finish();
	return 1;
}

sub ID {
  my $self = shift;
  return $self->{'ID'} || 0;
}

sub getValue  {
  my $self = shift;
  my($field)=@_;
  return $self->{'DBData'}{$field};
}

sub Name	{
  my $self = shift;
  return $self->{'DBData'}{'Saved'}{'strReportName'} 
		|| $self->{'DBData'}{'Report'}{'strName'} 
		|| '';
}

# --- Placeholder functions - to be overridden
sub displayOptions {
	my $self = shift;
	return '';
}

sub runReport {
  my $self = shift;
  my ($sql, $continue, $msg) = $self->makeSQL();
	warn $sql;
	return ($msg , $continue) if !$continue;
	return ('',1) if !$sql;
	my $output_array = undef;
	if($self->{'Config'}{'DataFromFunction'})	{
		my ($module, $fnname)  = $self->{'Config'}{'DataFromFunction'} =~/(.*)::(.*)/;
		if($module)	{
			eval "require $module";
		}
		$output_array = $module->$fnname($self->{'Data'}, $self->{'FormParams'});
	}
	else	{
		my $data_array = $self->runQuery($sql);
		#print STDERR $sql;
		$output_array = $self->processData($data_array);
	}
	if($self->{'Config'}{'ProcessReturnDataFunction'})	{

		my $retdata = $self->_runFunction(
			$self->{'Config'}{'ProcessReturnDataFunction'} || undef,
			$self->{'Config'}{'ProcessReturnDataFunctionParams'} || undef,
			$output_array,
		);
		return ($retdata, 1);
	}
	return $output_array if $self->{'FormParams'}{'ReturnData'};
  my $formatted = $self->formatOutput($output_array );
#use PDF::FromHTML;
 #my $pdf = PDF::FromHTML->new( encoding => 'utf-8' );
#$pdf->load_file(\$formatted);
    #$pdf->convert(
        ## With PDF::API2, font names such as 'traditional' also works
        #LineHeight  => 10,
    #);

    # Write to a file:
    #$pdf->write_file('/tmp/target.pdf');
  my $output = $self->deliverReport($formatted);
	return ($output, 1);
}

sub saveReport {
	my $self = shift;
}

sub deleteSavedReport {
	my $self = shift;
}

sub deliverReport {
	my $self = shift;
  my ($reportoutput) = @_;

	my $output = '';
	if($self->{'RunParams'}{'ViewType'} 
		and $self->{'RunParams'}{'ViewType'} eq 'email'
		and $self->{'RunParams'}{'SendToEmail'}
	)	{
		#Deliver by email

		my $sendoutput = $self->sendDataByEmail($reportoutput);
		$output = runTemplate(
			$self->{'Data'},
			{
				Name => $self->Name(),
				DateRun => scalar(localtime()),
				RunOrder => $self->{'RunParams'}{'FieldOrder'} || $self->{'RunParams'}{'Order'},
				RecordCount => $self->{'RunParams'}{'RecordCount'},
				Totals => $self->{'RunParams'}{'Totals'},
				GroupField => $self->{'RunParams'}{'GroupBy'},
				Email => $self->{'RunParams'}{'SendToEmail'},
			},
			"reports/email_confirmation.templ",
		);

	}
	else	{
		#just return report
		$output = $reportoutput;
	}
	return $output;
}

sub formatOutput {
  my $self = shift;
  my ($data_array) = @_;

  my $output = '';
  #If using Template toolkit

  my $templatename = $self->{'Config'}{'Template'} || 'default';	
	if($self->{'RunParams'}{'ViewType'} 
		and $self->{'RunParams'}{'ViewType'} eq 'email'
		and $self->{'RunParams'}{'SendToEmail'}
	)	{
		$templatename = $self->{'Config'}{'TemplateEmail'} if $self->{'Config'}{'TemplateEmail'};
	}
	my $debugtime = [gettimeofday];
	warn("REPORT DEBUG: ".localtime()." Format Start ") if $self->{'DEBUG'};
  $output = runTemplate(
    $self->{'Data'},    
    {
			Name => $self->Name(),
      Labels => $self->{'Config'}{'Labels'},
      ReportData => $data_array, 
			DateRun => scalar(localtime()),
			RunOrder => $self->{'RunParams'}{'FieldOrder'} || $self->{'RunParams'}{'Order'},
			RecordCount => $self->{'RunParams'}{'RecordCount'},
			Totals => $self->{'RunParams'}{'Totals'},
			GroupField => $self->{'RunParams'}{'GroupBy'},	
			SummaryCount => $self->{'RunParams'}{'SummaryCount'},
			Summarise => $self->{'RunParams'}{'Summarise'} || 0,
			Options => $self->{'OtherOptions'},
    },
    "reports/$templatename.templ",
  );
	warn("REPORT DEBUG: ".tv_interval($debugtime)." Format End ") if $self->{'DEBUG'};
  return $output;
}

sub processData {
  my $self = shift;
  my($data_array) = @_;
	my $output_array = undef;

  #First do sort
	my @sortparams = ();
	my $sort = $self->{'Sort'} || $self->{'Config'}{'Sort'};
	my $groupfield = $self->{'RunParams'}{'GroupBy'} || '';
	my $debugtime = [gettimeofday];
	warn("REPORT DEBUG: ".localtime()." Sort Start") if $self->{'DEBUG'};
	if($groupfield)	{
		unshift @{$sort}, [$groupfield,'ASC','string'];
	}
	if($sort)	{
		my @sortparams = ('ST', 'ref_in', 'ref_out','no_case');
		for my $s (@{$sort})	{
			next if !$s->[0];
			my $type = $s->[2];
			$type = 'string' if($type ne 'number');
			my $direction = $s->[1] eq 'DESC' ? 'descending' : 'ascending';
			push @sortparams, $type;
			my $field = $s->[0];
			if(exists $data_array->[0]->{$field.'_RAW'})	{
				$field .='_RAW';
			}
			push @sortparams, {
				code => '$_->{'.$field.'}',
				"$direction" => 1,
				varying => 1,
			};
		}
		my $sort_fn = make_sorter( @sortparams);
		if($sort_fn)	{
			$output_array = $sort_fn->($data_array)
		}
		else 	{
			$output_array = $data_array;
			print STDERR $@;
		}
	}
	else	{
		$output_array = $data_array;
	}
	warn("REPORT DEBUG: ".tv_interval($debugtime)." Sort End ") if $self->{'DEBUG'};
	my $lastrowdatahash= '';
	my $rowcount = 0;
	$debugtime = [gettimeofday];
	warn("REPORT DEBUG: ".localtime()." Process Start") if $self->{'DEBUG'};
	my %existingrows = ();
	if($self->{'Config'}{'Fields'}
		or $self->{'RunParams'}{'Summarise'}
		or $self->{'RunParams'}{'Distinct'})	{

		my $index = 0;
		my $numrows = $#$output_array;
		while($index <= $numrows)	{
			my $row = $output_array->[$index];
			if($self->{'RunParams'}{'Distinct'} or $self->{'RunParams'}{'Summarise'})	{
				my $rowdatahash = join("\0",(map {defined $_ ? $_ : ''} values %{$row})); #key for row
				$self->{'RunParams'}{'SummaryCount'}{'Rows'}{$rowdatahash}++;
				$self->{'RunParams'}{'SummaryCount'}{'All'}++;
				my $gv = $row->{$groupfield};
				$gv = '' if !defined $gv;
				if($groupfield)	{
					$self->{'RunParams'}{'SummaryCount'}{'GroupTotal'}{$gv}++;
				}
				if(
					(
						$self->{'RunParams'}{'Distinct'} 
						or $self->{'RunParams'}{'Summarise'}
					)
					and $self->{'RunParams'}{'SummaryCount'}{'Rows'}{$rowdatahash} >1 
					)	{
						splice @{$output_array}, $index, 1;
						$numrows--;
						next 
				}

				if($groupfield)	{
					$self->{'RunParams'}{'SummaryCount'}{'NumRows'}{$gv}++;
				}
				$row->{'RowHash'} = $rowdatahash || '';
			}

			if($self->{'Config'}{'Fields'})	{ #Has detailed field configuration
				$self->_processrow($row, $groupfield);
			}
			$index++;
		}
	}
	warn("REPORT DEBUG: ".tv_interval($debugtime)." Process End ") if $self->{'DEBUG'};

	$self->{'RunParams'}{'RecordCount'} = scalar(@{$output_array});
  return $output_array || undef;
}

sub _processrow	{
  my $self = shift;
	my ($dataref, $groupfield) = @_;
	my $activefields = $self->{'RunParams'}{'ActiveFields'};
	for my $field (@{$self->{'RunParams'}{'Order'}}) {
		if(
			exists $activefields->{$field} 
			and $activefields->{$field}
		)	{
			$dataref->{$field.'_RAW'} ||= $dataref->{$field};
			my $fieldopts = $self->{'Config'}{'Fields'}{$field}[1] || next;

			my $outvalue='';
			if(!defined $dataref->{$field}) {$dataref->{$field}='';}
			my $displaytype = $fieldopts->{'displaytype'} || '';
			if($displaytype eq 'lookup') {
				$outvalue=$fieldopts->{'dropdownoptions'}{$dataref->{$field}} || '';
			}
			if($displaytype eq 'function') {
				# Field needs to be processed through a function first
				next if !$fieldopts->{'functionref'};
				my @fnparams=();
				if($fieldopts->{'fieldparams'}) {
					my @fieldparams=split /,\s*/,$fieldopts->{'fieldparams'};
					if(@fieldparams)  {
						for my $i (@fieldparams)  {
							push @fnparams, $dataref->{$i} || '';
						}
					}
				}
				if($fieldopts->{'functionparams'})  {
					push(@fnparams, @{$fieldopts->{'functionparams'}});
				}
				$outvalue=&{$fieldopts->{'functionref'}}(@fnparams);
			}
			if($fieldopts->{'total'} or $field eq 'RO_SUM') {
				$self->{'RunParams'}{'Totals'}{'all'}{$field}+=$dataref->{$field};
				$self->{'RunParams'}{'Totals'}{'grp'}{$dataref->{$groupfield}}{$field}+=$dataref->{$field} if $groupfield;
			}
			if($dataref->{$field} =~/0+\/0+\/00+/)  {$dataref->{$field}='&nbsp;';}

			if(exists $self->{'Config'}{'links'}{$field} and $self->{'Config'}->{'links'}{$field}[0]) {
				my $linkref= eval($self->{'Config'}{'links'}{$field}[0]) || '';
				my $trgt=$self->{'Config'}{'links'}{$field}[2] ? qq~ target="$self->{'Config'}{'links'}{$field}[2]" ~: '';
				$outvalue = qq[<a href="$linkref" $trgt>$dataref->{$field}</a>];
			}
			if(
				!defined $outvalue 
				or $outvalue eq ''
				and !($displaytype eq 'lookup' and $outvalue eq '')
			) { $outvalue=$dataref->{$field}; }
			if($displaytype eq 'currency' and $self->{'Config'}->{'Config'}{'CurrencySymbol'})  {
				$outvalue= $self->{'Config'}{'Config'}{'CurrencySymbol'} . $outvalue;
			}
			$dataref->{$field} = $outvalue;

			#Handle grouping
		}
	}
}

sub _getConfiguration {
  my $self = shift;
  return undef;
}

sub runQuery {
  my $self = shift;
  my($sql) = @_;


  #attempt to fix some common sql syntax errors
  $sql =~s/FROM\s*INNER JOIN/FROM /is;
  $sql =~s/(JOIN|LEFT) JOIN\s*(INNER|LEFT) JOIN/$2 JOIN/is;
  $sql =~s/WHERE\s*AND/WHERE /is;
  my $debugtime = [gettimeofday];
  #warn("REPORT DEBUG: ".localtime()." DB Run Start") if $self->{'DEBUG'};
  my $q = $self->{'dbRun'}->prepare($sql);
  $q->execute();

  my @data_array = ();
  while(my $dref = $q->fetchrow_hashref())	{
		#for my $k (keys %{$dref})	{
			#$dref->{$k} = '' if !defined $dref->{$k};
		#}
  	push @data_array, $dref;
	}
  $q->finish();
	warn("REPORT DEBUG: ".tv_interval($debugtime)." DB Run End ") if $self->{'DEBUG'};
  return \@data_array || undef;
}

sub setCarryFields {
  my $self = shift;
	my($fields) = @_;
	$self->{'CarryFields'} = $fields;
}

sub untaint {
  my $self = shift;
	my ($value, $type) = @_;
	return undef if !defined $value;
	my $outvalue = '';
	if($type eq 'string')	{
		$value =~ /^([0-9a-zA-Z_]*)$/;
		$outvalue = $1;
	}
	elsif($type eq 'number')	{
		$value =~ /^([\d]*)$/;
		$outvalue = $1;
	}
	return $outvalue;
}

sub _runFunction	{
  my $self = shift;
	my (
		$function,
		$params,
		$output_array,
	) = @_;
	
	my @params=(
		$self->{'Data'},
		$self->{'db'},
		$output_array,
	);
	push @params, @{$params};
	my $ret = $function->(@params);
	return $ret;
}


1;
