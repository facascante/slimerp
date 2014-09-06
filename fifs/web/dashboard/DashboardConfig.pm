#
# $Header: svn://svn/SWM/trunk/web/dashboard/DashboardConfig.pm 10383 2014-01-07 06:43:54Z sliu $
#

package DashboardConfig;
require Exporter;

@ISA =  qw(Exporter);
@EXPORT = qw(handle_DashboardConfig);
@EXPORT_OK = qw(handle_DashboardConfig);

use strict;
use lib "..","../..";
use CGI qw(param unescape);
use Dashboard qw(showDashboard getItems);
use Reg_common;
use FormHelpers;

sub handle_DashboardConfig {
  my(
		$action,
		$Data, 
		$entityID,
		$entityTypeID,
		$client,
	)=@_;

  my $body='';
  if($action eq 'DASHCFG_U')  {
    $body=update_DashboardConfig(
			$Data,
			$client,
			$entityTypeID,
			$entityID,
		);
  }
  else  {
    $body.= displayDashboardConfig(
			$Data,
			$client,
			$entityTypeID,
			$entityID,
		);
  }
  my $title=$Data->{'lang'}->txt('Configure Dashboard');
  return ($body,$title);
}


sub displayDashboardConfig {
	my(
		$Data,
    $client,
    $entityTypeID,
    $entityID,
	)=@_;

	my $realmID=$Data->{'Realm'} || 0;
  my $target=$Data->{'target'};
  my $cl  = setClient($Data->{'clientValues'});
  my $unesc_cl=unescape($cl);
	my $assocID=$Data->{'clientValues'}{'assocID'} || $Defs::INVALID_ID;
	my $items = getItems(
		$Data,
    $client,
    $entityTypeID,
    $entityID,
	);

	my $possibleitems = getPossibleDashboardItems();
	my %positems = ();
	for my $i (@{$possibleitems})	{
		$positems{"$i->[0]:$i->[1]"} = $i->[2] || next;
	}
	$positems{''} = '';

	my $numitems = 10;
	my $selectitems = '';
	my $allitems = {};

	for my $i (1 .. $numitems)	{
		my $val = '';
		if(($i-1) <= $#{$items})	{
			$val = $items->[$i-1][0].':'.$items->[$i-1][1];
		}
		my $selecitems_dd .= drop_down(
			"dbitem_$i",
			\%positems,
			undef,
			$val,
		);
		$selectitems .= qq[$selecitems_dd <br>];
	}

	my $uwm = $Data->{'lang'}->txt('Update');

	my $body = '';
	$body=$Data->{'lang'}->txt('TO_UPD_DASHBOARD', $uwm).qq[
	<form action="$target" method="POST">
		<input type="hidden" name="a" value="DASHCFG_U">
		<input type="hidden" name="client" value="$client">
		$selectitems
		<p>
			<input type="submit" value="$uwm"><br>
		</p>
	</form>
	];

	return $body;

}

sub update_DashboardConfig {
	my(
		$Data,
    $client,
    $entityTypeID,
    $entityID,
	)=@_;

	{
		my $st_del=qq[
			DELETE FROM tblDashboardConfig 
			WHERE 
				intEntityTypeID= ? 
				AND intEntityID= ? 
		];
		my $query = $Data->{'db'}->prepare($st_del);
		$query->execute(
			$entityTypeID,
			$entityID,
		);
	}
	my $st_insert=qq[
		INSERT INTO tblDashboardConfig (
			intEntityTypeID,
			intEntityID,
			strDashboardItemType,
			strDashboardItem,
			intOrder
		)
		VALUES (
			?,
			?,
			?,
			?,
			?
		)
	];
  my $q= $Data->{'db'}->prepare($st_insert);
	my $numitems = 10;
	for my $cnt (0 .. $numitems)	{
		my $val = param('dbitem_'.$cnt) || next;
		my ($v1,$v2) = split /:/, $val;
		$q->execute(
			$entityTypeID,
			$entityID,
			$v1,
			$v2,
			$cnt,
		);
	}
	my $subBody='';
	if($DBI::err)	{
		$subBody=qq[<div class="warningmsg">].$Data->{'lang'}->txt('There was a problem updating your Dashboard').'</div>';
	}
	else	{ 
    $subBody.=qq[<div class="OKmsg">].$Data->{'lang'}->txt('Dashboard Updated').'</div>';
  }
	return $subBody;
}

sub getPossibleDashboardItems	{

	my @items = (
		['graph','member_historical','Graph: Members'],
		['graph','playergender_historical','Graph: Players by Gender  - Historical'],
		['graph','playeragegroups_historical','Graph: Players by Age Group  - Historical'],
		['graph','playergenders','Graph: Players by Gender  - Current'],
		['graph','playerages','Graph: Players by Age Group - Current'],
		['graph','player_historical','Graph: Players'],
		['graph','coach_historical','Graph: Coaches'],
		['graph','umpire_historical','Graph: Match Officials'],
		['graph','other1_historical','Graph: Other 1'],
		['graph','other2_historical','Graph: Other 2'],
		['graph','newmembers_historical','Graph: New Members'],
		['graph','regoformembers_historical','Graph: Registration Form Members'],
		['graph','comps_historical','Graph: Competitions'],
		['graph','clubs_historical','Graph: Clubs'],
		['graph','teams_historical','Graph: Teams'],
		['graph','clrin_historical','Graph: Clearances In'],
		['graph','clrout_historical','Graph: Clearances Out'],
		['graph','permin_historical','Graph: Permits In'],
		['graph','permout_historical','Graph: Permits Out'],
		['graph','txns_historical','Graph: Transactions'],
		['graph','txnval_historical','Graph: Transaction Value'],
		['graph','trib_historical','Graph: Tribunals'],
		['graph','payment_historical','Graph: Paid Online Registration'],
	);
	return \@items;
}

1;
