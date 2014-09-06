#
# $Header: svn://svn/SWM/trunk/web/dashboard/DashboardGraphData.pm 10383 2014-01-07 06:43:54Z sliu $
#

package DashboardGraphData;

require Exporter;
@ISA =  qw(Exporter);
@EXPORT = qw(getGraphData);
@EXPORT_OK = qw(getGraphData);

use strict;
use CGI qw(param);

use lib '.', "..", "../..";
use Reg_common;
use Defs;
use Utils;
use MCache;
use AgeGroups;

sub getGraphData {
	my ( 
		$Data,
		$client,	
		$graphtype,
	) = @_;

	my $graphdata = undef;
	my $seriesnames = undef;

	my $entityTypeID = $Data->{'clientValues'}{'currentLevel'};
	my $entityID = getID($Data->{'clientValues'});

	my $db = connectDB('reporting');
	if(
		$graphtype eq 'member_historical'
		or $graphtype eq 'player_historical'
		or $graphtype eq 'coach_historical'
		or $graphtype eq 'umpire_historical'
		or $graphtype eq 'other1_historical'
		or $graphtype eq 'other2_historical'
		or $graphtype eq 'newmembers_historical'
		or $graphtype eq 'regoformembers_historical'
		or $graphtype eq 'permitmembers_historical'
		or $graphtype eq 'playergender_historical'
		or $graphtype eq 'playeragegroups_historical'
	)	{
		($graphdata, $seriesnames) = getMemberHistorical(
			$db,
			$Data,
			$client,
			$graphtype,
			$entityTypeID,
			$entityID,
		);
		#$graphdata = [$graphdata];		
	}
	elsif(
		$graphtype eq 'comps_historical'
		or $graphtype eq 'clubs_historical'
		or $graphtype eq 'teams_historical'
		or $graphtype eq 'clrin_historical'
		or $graphtype eq 'clrout_historical'
		or $graphtype eq 'permin_historical'
		or $graphtype eq 'permout_historical'
		or $graphtype eq 'txns_historical'
		or $graphtype eq 'txnval_historical'
		or $graphtype eq 'trib_historical'
	)	{
		($graphdata, $seriesnames) = getEntityHistorical(
			$db,
			$Data,
			$client,
			$graphtype,
			$entityTypeID,
			$entityID,
		);
		$graphdata = [$graphdata];		
	}
	elsif(
		$graphtype eq 'playergenders'
		or $graphtype eq 'playerages'
	)	{
		($graphdata, $seriesnames) = getMemberCurrent(
			$db,
			$Data,
			$client,
			$graphtype,
			$entityTypeID,
			$entityID,
		);
		$graphdata = [$graphdata];		
	}
    elsif(
        $graphtype eq 'payment_historical'
    )   {
		($graphdata, $seriesnames) = getPaymentHistorical(
			$db,
			$Data,
			$client,
			$graphtype,
			$entityTypeID,
			$entityID,
        );
		$graphdata = [$graphdata];		
    }

	return ($graphdata, $seriesnames);
}

sub getMemberHistorical {
	my ( 
		$db,
		$Data,
		$client,	
		$graphtype,
		$entityTypeID,
		$entityID,
	) = @_;


	my @series = ();
	my %lookuplabels = ();
	if($graphtype eq 'member_historical')	{
		push @series, ['cntMembers'];
	}
	elsif($graphtype eq 'player_historical')	{
		push @series, ['cntPlayer'];
	}
	elsif($graphtype eq 'coach_historical')	{
		push @series, ['cntCoach'];
	}
	elsif($graphtype eq 'umpire_historical')	{
		push @series, ['cntUmpire'];
	}
	elsif($graphtype eq 'other1_historical')	{
		push @series, ['cntOther1'];
	}
	elsif($graphtype eq 'other2_historical')	{
		push @series, ['cntOther2'];
	}
	elsif($graphtype eq 'newmembers_historical')	{
		push @series, ['cntNewMembers'];
	}
	elsif($graphtype eq 'regoformembers_historical')	{
		push @series, ['cntRegoFormMembers'];
	}
	elsif($graphtype eq 'playeragegroups_historical')	{
		push @series, ['cntPlayer',['intAgeGroupID']];
		my ($ages, undef) = getAgeGroups($Data);
		%lookuplabels = %{$ages};
		$lookuplabels{'XXXXXGROUPKEYXXXXX'} = 'Unknown';
	}
	elsif($graphtype eq 'playergender_historical')	{
		push @series, ['cntPlayer',['intGender']];
		%lookuplabels = (
			1 => 'Male',
			2 => 'Female',
			'XXXXXGROUPKEYXXXXX' => 'Unknown',
		);
	}
	#if($graphtype =~/gender/ or $graphtype =~ /agegroup/)	{
		#$groupby .= '';
	#}
	my @series_out = ();
	for my $s (@series)	{
		my ($ret, $series_names) = getMemberHistoricalData(
			$db,
			$Data,
			$s->[0], #keyfield,
			$s->[1] || undef, #groupbys
			$s->[2] || undef, #filters
			$entityTypeID,
			$entityID,
			\%lookuplabels,
		);
		return ($ret, $series_names);
	}
	return \@series_out;
}

sub getMemberHistoricalData {
	my ( 
		$db,
		$Data,
		$keyfield, 		
		$groupbys, #array ref
		$filters, #array ref
		$entityTypeID,
		$entityID,
		$lookuplabels,
	) = @_;

	my $realmID = $Data->{'Realm'} || return undef;
	my $groupby_extra = '';
	if($groupbys)	{
		$groupby_extra = join(',',@{$groupbys});
	}
	$lookuplabels ||= {};

	$groupby_extra = ','.$groupby_extra if $groupby_extra;

	my $cachekey = "GRAPHINGDATA_MEMHISTORICAL_$entityTypeID:$entityID:$groupby_extra";

	my $cache = $Data->{'cache'};
  my $dbdata = undef;
	if($cache)	{
		$dbdata = $cache->get('swm',$cachekey);
	}

	if(!$dbdata)	{
		my $st = qq[
			SELECT
				intEntityTypeID,
				intEntityID,
				intYear,
				intMonth,
				intSeasonID,
				intGender,
				intAgeGroupID,
				SUM(intMembers) AS cntMembers,
				SUM(intNewMembers) AS cntNewMembers,
				SUM(intRegoFormMembers) AS cntRegoFormMembers,
				SUM(intPermitMembers) AS cntPermitMembers,
				SUM(intPlayer) AS cntPlayer,
				SUM(intCoach) AS cntCoach,
				SUM(intUmpire) AS cntUmpire,
				SUM(intOther1) AS cntOther1,
				SUM(intOther2) AS cntOther2
			FROM
				tblSnapShotMemberCounts_$realmID
			WHERE
				intEntityTypeID = ?
				AND intEntityID = ?
			GROUP BY 
				intEntityTypeID,
				intEntityID,
				intYear,
				intMonth
				$groupby_extra
		];
		my $q = $db->prepare($st);
		$q->execute(
			$entityTypeID,
			$entityID,
		);
		while(my $dref = $q->fetchrow_hashref())	{
			push @{$dbdata}, $dref;
		}
	}
	my %output_data = ();
	my $groupfield = 'XXXXXGROUPFIELDXXXXX';
	$groupfield = $groupbys->[0] if $groupbys;
	
	for my $dref (@{$dbdata})	{
		if($filters and scalar(@{$filters}))	{
			my $passfilter = 1;
			for my $f (@{$filters})	{
				my $filterfield = $f->[0];
				my $filterval = $f->[1];
				$passfilter = 0 if $dref->{$filterfield} != $filterval;
			}
			next if !$passfilter;
		}
		my $val = int($dref->{$keyfield} || 0);
		my $month = $dref->{'intMonth'} || 0;
		$month = '0'.$month if $month < 10;
		my $year = $dref->{'intYear'} || 0;
		my $date = "$year-$month-01";
		my $groupkey = $dref->{$groupfield} || 'XXXXXGROUPKEYXXXXX';
		push @{$output_data{$groupkey}}, [$date, $val];
	}
	my @output_data = ();
	my @series = ();
	for my $k (keys %output_data)	{
		push @output_data, $output_data{$k};
		my $series_label = $lookuplabels->{$k} || $k;
		push @series, $series_label;
	}
	if($cache)	{
		$cache->set('swm',$cachekey, $dbdata, undef,60*60*3); #3 hours
	}
	
	@series = () if scalar(@series) < 2;
	return (\@output_data, \@series);
}

sub getEntityHistorical {
	my ( 
		$db,
		$Data,
		$client,	
		$graphtype,
		$entityTypeID,
		$entityID,
	) = @_;
	my $realmID = $Data->{'Realm'} || return undef;
	my $keyfield = '';
	my $groupby_extra = '';

	if($graphtype eq 'comps_historical')	{
		$keyfield = 'intComps';
	}
	elsif($graphtype eq 'clubs_historical')	{
		$keyfield = 'intClubs';
	}
	elsif($graphtype eq 'teams_historical')	{
		$keyfield = 'intTotalTeams';
	}
	elsif($graphtype eq 'clrin_historical')	{
		$keyfield = 'intClrIn';
	}
	elsif($graphtype eq 'clrout_historical')	{
		$keyfield = 'intClrOut';
	}
	elsif($graphtype eq 'permin_historical')	{
		$keyfield = 'intClrPermitIn';
	}
	elsif($graphtype eq 'permout_historical')	{
		$keyfield = 'intClrPermitOut';
	}
	elsif($graphtype eq 'txns_historical')	{
		$keyfield = 'intTxns';
	}
	elsif($graphtype eq 'txnval_historical')	{
		$keyfield = 'curTxnValue';
	}
	elsif($graphtype eq 'trib_historical')	{
		$keyfield = 'intNewTribunal';
	}
	my $cachekey = "GRAPHINGDATA_ENTHISTORICAL_$entityTypeID:$entityID";
	my $cache = $Data->{'cache'};
	my $dbdata = undef;
	if($cache)	{
		$dbdata = $cache->get('swm',$cachekey);
	}

	if(!$dbdata)	{
		my $st = qq[
			SELECT
				intEntityTypeID,
				intEntityID,
				intYear,
				intMonth,
				intSeasonID,
				intClubs,
				intComps,
				intCompTeams,
				intTotalTeams,
				intClrIn,
				intClrOut,
				intClrPermitIn,
				intClrPermitOut,
				intTxns,
				curTxnValue,
				intNewTribunal
			FROM
				tblSnapShotEntityCounts_$realmID
			WHERE
				intEntityTypeID = ?
				AND intEntityID = ?
		];
		my $q = $db->prepare($st);
		$q->execute(
			$entityTypeID,
			$entityID,
		);
		
		while(my $dref = $q->fetchrow_hashref())	{
			push @{$dbdata}, $dref;
		}
	}
	if($cache)	{
		$cache->set('swm',$cachekey, $dbdata, undef, 60*60*3); #3 hours
	}
	my @output_data = ();
	$dbdata ||= [];
	for my $dref (@{$dbdata})	{
		my $val = int($dref->{$keyfield} || 0);
		my $month = $dref->{'intMonth'} || 0;
		$month = '0'.$month if $month < 10;
		my $year = $dref->{'intYear'} || 0;
		my $date = "$year-$month-01";
		push @output_data, [$date, $val];
	}
	
	return (\@output_data, undef);
}

sub getMemberCurrent {
	my ( 
		$db,
		$Data,
		$client,	
		$graphtype,
		$entityTypeID,
		$entityID,
	) = @_;


	my @series = ();
	my %lookuplabels = ();
	if($graphtype eq 'playergenders')	{
		push @series, ['cntPlayer',['intGender']];
		%lookuplabels = (
			1 => 'Male',
			2 => 'Female',
			'XXXXXGROUPKEYXXXXX' => 'Unknown',
		);
	}
	if($graphtype eq 'playerages')	{
		push @series, ['cntPlayer',['intAgeGroupID']];
		my ($ages, undef) = getAgeGroups($Data);
		%lookuplabels = %{$ages};
		$lookuplabels{'XXXXXGROUPKEYXXXXX'} = 'Unknown';
	}
	my @series_out = ();
	for my $s (@series)	{
		my ($ret, undef) = getMemberCurrentData(
			$db,
			$Data,
			$s->[0], #keyfield,
			$s->[1] || undef, #groupbys
			$s->[2] || undef, #filters
			$entityTypeID,
			$entityID,
			\%lookuplabels,
		);
		return ($ret, undef);
	}
	return (\@series_out, undef);
}

sub getMemberCurrentData {
	my ( 
		$db,
		$Data,
		$keyfield, 		
		$groupbys, #array ref
		$filters, #array ref
		$entityTypeID,
		$entityID,
		$lookuplabels,
	) = @_;

	my $realmID = $Data->{'Realm'} || return undef;
	my $groupby_extra = '';
	if($groupbys)	{
		$groupby_extra = join(',',@{$groupbys});
	}

	$groupby_extra = ','.$groupby_extra if $groupby_extra;
	$lookuplabels ||= {};

	my $cachekey = "GRAPHINGDATA_MEMCURRENT_$entityTypeID:$entityID:$groupby_extra";
	my $cache = $Data->{'cache'};
	my $dbdata = undef;
	if($cache)	{
		$dbdata = $cache->get('swm',$cachekey);
	}

	if(!$dbdata)	{

		my $st_dates = qq[
			SELECT 
				intYear, 
				intMonth 
			FROM tblSnapShotMemberCounts_$realmID
			WHERE 
				intEntityTypeID = ?
				AND intEntityID = ?
			ORDER BY 
				intYear DESC, 
				intMonth DESC 
			LIMIT 1
		];
		my $q_dates = $db->prepare($st_dates);
		$q_dates->execute(
			$entityTypeID,
			$entityID,
		);
		my($year, $month) = $q_dates->fetchrow_array();
		return undef if !$year;	
		return undef if !$month;	

		my $st = qq[
			SELECT
				intEntityTypeID,
				intEntityID,
				intYear,
				intMonth,
				intSeasonID,
				intGender,
				intAgeGroupID,
				SUM(intMembers) AS cntMembers,
				SUM(intNewMembers) AS cntNewMembers,
				SUM(intRegoFormMembers) AS cntRegoFormMembers,
				SUM(intPermitMembers) AS cntPermitMembers,
				SUM(intPlayer) AS cntPlayer,
				SUM(intCoach) AS cntCoach,
				SUM(intUmpire) AS cntUmpire,
				SUM(intOther1) AS cntOther1,
				SUM(intOther2) AS cntOther2
			FROM
				tblSnapShotMemberCounts_$realmID
			WHERE
				intEntityTypeID = ?
				AND intEntityID = ?
				AND intYear = ?
				AND intMonth = ?
			GROUP BY 
				intEntityTypeID,
				intEntityID,
				intYear,
				intMonth
				$groupby_extra
		];
		my $q = $db->prepare($st);
		$q->execute(
			$entityTypeID,
			$entityID,
			$year,
			$month,
		);
		
		while(my $dref = $q->fetchrow_hashref())	{
			push @{$dbdata}, $dref;
		}
	}
	my %output_data = ();
	my $groupfield = 'XXXXXGROUPFIELDXXXXX';
	$groupfield = $groupbys->[0] if $groupbys;
	
	my @output_data = ();
	for my $dref (@{$dbdata})	{
		if($filters and scalar(@{$filters}))	{
			my $passfilter = 1;
			for my $f (@{$filters})	{
				my $filterfield = $f->[0];
				my $filterval = $f->[1];
				$passfilter = 0 if $dref->{$filterfield} != $filterval;
			}
			next if !$passfilter;
		}
		my $val = int($dref->{$keyfield} || 0);
		my $month = $dref->{'intMonth'} || 0;
		$month = '0'.$month if $month < 10;
		my $year = $dref->{'intYear'} || 0;
		my $date = "$year-$month-01";
		my $groupkey = $dref->{$groupfield} || 'XXXXXGROUPKEYXXXXX';
		#push @{$output_data{$groupkey}}, [$groupkey, $val];
		my $label = $lookuplabels->{$groupkey} || $groupkey;
		push @output_data, [$label, $val];
	}
	#for my $k (keys %output_data)	{
		#push @output_data, $output_data{$k};
	#}
	if($cache)	{
		$cache->set('swm',$cachekey, $dbdata, undef, 60*60*3); #3 hours
	}
	
	return (\@output_data, undef);
}


sub getPaymentHistorical {
	my ( 
		$db,
		$Data,
		$client,
		$graphtype,
		$entityTypeID,
		$entityID,
	) = @_;
	my $realmID = $Data->{'Realm'} || return undef;

	my @output_data = ();
     # TODO: get the data from Database
    push @output_data, ['Paid Online', 10];
    push @output_data, ['Paid Offline', 20];
    return (\@output_data, undef);
}

1;



#-- Line or Bar graphs
#Members - historical
#Players - historical
#Coaches - historical
#Umpires - historical
#Other1 - historical
#Other2 - historical
#
#Comps - historical
#Teams - historical
#Age Groups - historical
#Gender - historical
#Clearances In and Out - historical
#Permit In and Out - historical
#Num Transactions - historical
#Transaction Value - historical
#new Regos - historical
#
#Pie
#
#Gender - current Month
#Age Groups - current Month
#New or Rereg
#


