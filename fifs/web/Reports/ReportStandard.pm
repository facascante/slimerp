#
# $Header: svn://svn/SWM/trunk/web/Reports/ReportStandard.pm 11336 2014-04-22 03:03:07Z apurcell $
#

package Reports::ReportStandard;

use strict;

use lib '.', '..', '../..';

use ReportBaseObj;
our @ISA =qw(ReportBaseObj);
use Safe;
use SearchLevels;
use TTTemplate;
use DateTime;

use Log;

use strict;

sub _getConfiguration {
	my $self = shift;
	return undef if !$self->{'DBData'}{'Report'}{'strFilename'};
	my $dir = '';
	$dir = 'standard' if $self->{'DBData'}{'Report'}{'intType'} == 1;
	$dir = 'custom' if $self->{'DBData'}{'Report'}{'intType'} == 2;
	return undef if !$dir;
	my $filename = "$Defs::fs_base/reports/$dir/$self->{'DBData'}{'Report'}{'strFilename'}";

	my $configData = new Safe;
	my $config = $configData->rdo($filename);
	return undef if !$config;
	$self->{'Config'} = $config;
}

sub makeSQL {
	my $self = shift;

	my $reportLevel = $self->{'Config'}{'ReportLevel'} || $self->{'EntityTypeID'} || 0;
	my $reportEntity = $self->{'Config'}{'ReportEntity'} || $Defs::LEVEL_PERSON;
	my $reportStats = $self->{'Config'}{'StatsReport'} || 0;
	my $reportNotMemberTeam = !($self->{'Config'}{'MemberTeam'} || 0);

	my %OptVals = (
		REPORT_LEVEL => $reportLevel,
		REPORT_ENTITY => $reportEntity,
		CLUBID => $self->{'ClientValues'}{'clubID'} || 0,
        REGIONID => $self->{'ClientValues'}{'regionID'} || 0,
		REALMID => $self->{'Data'}{'Realm'} || 0,
	);
	($OptVals{'FROM_LEVELS'}, $OptVals{'WHERE_LEVELS'}, $OptVals{'SELECT_LEVELS'}, $OptVals{'CURRENT_FROM'}, $OptVals{'CURRENT_WHERE'}) =
		getLevelQueryStuff($reportLevel,  $reportEntity, $self->{'Data'}, $reportStats, $reportNotMemberTeam);
	my $sql = $self->{'Config'}{'SQL'} || '';
	my @opts = keys %OptVals;
	for my $param (keys %{$self->{'Config'}{'Parameters'}})	{
		my $val = $self->{'FormParams'}{'opt_'.$param};
		next if !defined $val;
		if($self->{'Config'}{'Parameters'}{$param}{'Type'} eq 'date')	{
			if($val =~/\d{1,2}\/\d{1,2}\/\d{2,4}/)	{
				$val=~s/(\d{1,2})\/(\d{1,2})\/(\d{2,4})/$3-$2-$1/;
			}
		}
		push @opts, $param;
		$OptVals{$param} = $val;
	}
	for my $i (@opts)	{
		$sql =~s/###$i###/$OptVals{$i}/g;	
	}
	#attempt to fix some common sql syntax errors
	$sql =~s/FROM\s*INNER JOIN/FROM /is;
	$sql =~s/(JOIN|LEFT) JOIN\s*(INNER|LEFT) JOIN/$2 JOIN/is;
	return ($sql || '',1);
}

sub displayOptions {
	my $self = shift;

	return '' if !$self->{'DBData'}{'Report'}{'intParameters'};

	my $tablerows = '';
	my $options_map = $self->_get_display_options(); 

	my $params = $self->{'Config'}{'Parameters'};
	for my $k (sort {
		($params->{$a}{'Order'} || 50)
			<=>
		($params->{$b}{'Order'} || 50)
	} keys %{$params})	{

		my $option = '';
		
		if ($self->{'SystemConfig'}->{'use_new_report_style'}){
		    my $type = $params->{$k}{'Type'};

		    if ( defined $options_map->{$type} ){
		        my $sub_ref = $options_map->{$type};
		        $option = $self->$sub_ref($k);
		    }
		    else{
		        WARN "Unknown report parameter type $type";
		    }
		}
		else {
    		if($params->{$k}{'Type'} eq 'date')	{
    			my $default = $params->{$k}{'Default'} || '';
    			
    			# Check for a hashref
    			if (ref $default eq 'HASH'){
    			    my $dt = DateTime->today();
    			    $dt->add(%{$default});
                    $default = $dt->ymd('-');
    			}
    			
    			$default =~s/(\d\d\d\d)-(\d\d)-(\d\d)/$3\/$2\/$1/;
    			$option = qq[<input type="text" value ="$default" name="opt_$k" class="dateinput" size="10">];
    		}
    		if($params->{$k}{'Type'} eq 'text')	{
    			my $default = $params->{$k}{'Default'} || '';
    			$option = qq[<input type="text" value ="$default" name="opt_$k" size="10">];
    		}
		
		}
		$tablerows .= qq[
			<tr>
				<td class="repopt-label">$params->{$k}{'Name'}</td>
				<td class="repopt-value">$option</td>
			</tr>
		];
	}
	my $reportID = $self->ID();
	my $body = qq[ 
      <br>
      <br>
      <p>Choose your parameters and press the 'Run Report' button to proceed.</p>
      <br>
      <br>
      <script type="text/javascript">
      jQuery().ready(function() {
        jQuery(".dateinput").datepicker({ dateFormat: 'dd/mm/yy'});
      });
      </script>

			<form action ="main.cgi" method="POST" id="repparams_form" target="report">
			<table>
				$tablerows
			</table> 

			<input type="hidden" name="a" value="REP_REPORT">
			<input type="hidden" name="client" value="$self->{'Data'}{'unesc_client'}">
			<input type="hidden" name="rID" value="$reportID">
			<input type="hidden" name="rt" value="$self->{'DBData'}{'Report'}{'intType'}">

			</form>
	];

	return $body;
}

sub _get_display_options {
    my $self = shift;
    
    my %options = (
        'date' => $self->can('_option_date'),
        'text' => $self->can('_option_text'),
    );
    
    return \%options;
}

sub _option_text {
    my ($self, $field) = @_;
    
    my $parameter = $self->{'Config'}{'Parameters'}{$field};
    
    my $default = $parameter->{'Default'} || '';
    return qq[<input type="text" value ="$default" name="opt_$field" size="10">];
}

sub _option_date {
    my ($self, $field) = @_;
    
    my $parameter = $self->{'Config'}{'Parameters'}{$field};
    
    my $default = $parameter->{'Default'} || '';
    
    # Check for a hashref
    if (ref $default eq 'HASH'){
        my $dt = DateTime->today();
        $dt->add(%{$default});
        $default = $dt->ymd('-');
    }
    
    $default =~s/(\d\d\d\d)-(\d\d)-(\d\d)/$3\/$2\/$1/;
    return qq[<input type="text" value ="$default" name="opt_$field" class="dateinput" size="10">];
}

1;
