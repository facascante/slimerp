#
# $Header: svn://svn/SWM/trunk/web/dashboard/Dashboard.pm 8251 2013-04-08 09:00:53Z rlee $
#

package Dashboard;

require Exporter;
@ISA =  qw(Exporter);
@EXPORT = qw(showDashboard);
@EXPORT_OK = qw(showDashboard getItems);

use strict;
use CGI qw(param);

use lib '.','..','../..';
use Reg_common;
use Defs;
use Utils;
use DashboardGraphs;


sub showDashboard {
	my ( 
		$Data,
		$client,	
		$entityTypeID,
		$entityID,
	) = @_;

	my @includes = ();


	my $output = '';
	my $items = getItems(
		$Data,
    $client,
    $entityTypeID,
    $entityID,
  );
	for my $row (@{$items})	{

		my $type = $row->[0] || next;
		my $item = $row->[1] || next;
		if($type eq 'graph')	{
			$output .= outputGraph(
				$Data,
				$client,
				$item,
				'',
			);
		}
	}
		
	my $includes = '';
	my %includes = ();

	for my $i (@includes)	{
		next if $includes{$i};
		$includes{$i} = 1;
		$includes .= $i;
	}
	$output = $includes.$output;
	return (
		($output || ''),
		'Dashboard',
	);
}

sub getItems	{
	my ( 
		$Data,
		$client,	
		$entityTypeID,
		$entityID,
	) = @_;

	my $st = qq[
		SELECT 
			strDashboardItemType,
			strDashboardItem
		FROM tblDashboardConfig
		WHERE
			intEntityTypeID  = ?
			AND intEntityID  = ?
		ORDER BY intOrder
	];
	my $q = $Data->{'db'}->prepare($st);
	$q->execute(
		$entityTypeID,
		$entityID,
	);
	my @items = ();
	while(my ($type, $item) = $q->fetchrow_array())	{
		next if !$type;
		next if !$item;
		push @items, [$type, $item];
	}
	if(!scalar(@items))	{
		@items = @{getDefaultItems($Data, $entityTypeID)};
	}
	return \@items;
}

sub getDefaultItems	{
	my ( 
		$Data,
		$entityTypeID,
	) = @_;

	my @defaultitems = (
		['graph', 'member_historical'],
		['graph', 'playergenders'],
		['graph', 'playergender_historical'],
		['graph', 'player_historical'],
		['graph', 'coach_historical'],
		['graph', 'umpire_historical'],
		['graph', 'newmembers_historical'],
		['graph', 'regoformembers_historical'],
		['graph', 'clrout_historical'],
		#['graph', 'txns_historical'],
		['graph', 'txnval_historical'],
	);
	if($entityTypeID == $Defs::LEVEL_ASSOC)	{
	}
	
	return \@defaultitems;
}

1;
