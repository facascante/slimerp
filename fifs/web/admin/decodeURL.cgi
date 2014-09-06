#!/usr/bin/perl

#
# $Header: svn://svn/SWM/trunk/web/admin/decodeURL.cgi 10127 2013-12-03 03:59:01Z tcourt $
#

use strict;
use lib ".","..","../..","../comp";

use Defs;
use Utils;
use Reg_common;
use InstanceOf;
use MCache;
use DBI;
use CGI qw(param unescape escape);
use AdminPageGen;

main();

sub main  {

# Variables coming in

  my $body = "";
  my $title = "$Defs::sitename URL Decoder";
  my $url = param('decodeurl') || '';
  
  my $target="decodeURL.cgi";
    
  my $error='';
  my $db=connectDB();
	my $cache = new MCache;

	$body = decodeForm($target, $url);
	$body .= decodeInfo($url, $db, $cache) if $url;

  disconnectDB($db) if $db;
  print_adminpageGen($body, "", "");
}


sub decodeForm {
  my($target, $url)=@_;
  my $body='';
  my $menu='';

	$body = qq[
<h2>Decode URL</h2>

  <form action="$target" method="post">
		<b>URL to decode</b>: <input type = "text" value = "$url" size =" 100" name = "decodeurl"><br>
    <input type="submit" name="submit" value="Decode URL">
    <input type = "hidden" name="action" value="SUP_url">
    </div>
  </form><br>

	];
	return $body;
}

sub decodeInfo {
  my($url, $db, $cache)=@_;

	#get clientstring	
	my ($client) = $url =~ /.*client=(.*?)&/; 
	return '' if !$client;
	my %clientValues = getClient($client) if $client;
	my @outdata = ();
use Data::Dumper;
print STDERR Dumper(\%clientValues);

	my %Data = (
		clientValues => \%clientValues,
		cache => $cache,
		db => $db, 
	);

	if($clientValues{'interID'} and $clientValues{'interID'} > 0)	{
		my $obj = getInstanceOf(
			\%Data,
			'international',
			$clientValues{'interID'},
		);
		if($obj)	{
			my $name = $obj->getValue('strName') || '';
			push @outdata, ['InternationalID', $clientValues{'interID'}, $name];
		}
	}
	if($clientValues{'intregID'} and $clientValues{'intregID'} > 0)	{
		my $obj = getInstanceOf(
			\%Data,
			'intregion',
			$clientValues{'intregID'},
		);
		if($obj)	{
			my $name = $obj->getValue('strName') || '';
			push @outdata, ['InternationalRegionID', $clientValues{'intregID'}, $name];
		}
	}
	if($clientValues{'intzonID'} and $clientValues{'intzonID'} > 0 )	{
		my $obj = getInstanceOf(
			\%Data,
			'intzone',
			$clientValues{'intzonID'},
		);
		if($obj)	{
			my $name = $obj->getValue('strName') || '';
			push @outdata, ['InternationalZoneID', $clientValues{'intzonID'}, $name];
		}
	}
	if($clientValues{'natID'} and $clientValues{'natID'} > 0)	{
		my $obj = getInstanceOf(
			\%Data,
			'national',
			$clientValues{'natID'},
		);
		if($obj)	{
			my $name = $obj->getValue('strName') || '';
			push @outdata, ['NationalID', $clientValues{'natID'}, $name];
		}
	}
	if($clientValues{'stateID'} and $clientValues{'stateID'} > 0)	{
		my $obj = getInstanceOf(
			\%Data,
			'state',
			$clientValues{'stateID'},
		);
		if($obj)	{
			my $name = $obj->getValue('strName') || '';
			push @outdata, ['StateID', $clientValues{'stateID'}, $name];
		}
	}
	if($clientValues{'regionID'} and $clientValues{'regionID'} > 0)	{
		my $obj = getInstanceOf(
			\%Data,
			'region',
			$clientValues{'regionID'},
		);
		if($obj)	{
			my $name = $obj->getValue('strName') || '';
			push @outdata, ['RegionID', $clientValues{'regionID'}, $name];
		}
	}
	if($clientValues{'zoneID'} and $clientValues{'zoneID'} > 0 )	{
		my $obj = getInstanceOf(
			\%Data,
			'zone',
			$clientValues{'zoneID'},
		);
		if($obj)	{
			my $name = $obj->getValue('strName') || '';
			push @outdata, ['ZoneID', $clientValues{'zoneID'}, $name];
		}
	}
	if($clientValues{'assocID'} and $clientValues{'assocID'} > 0)	{
		my $obj = getInstanceOf(
			\%Data,
			'assoc',
			$clientValues{'assocID'},
		);
		if($obj)	{
			my $name = $obj->getValue('strName') || '';
			push @outdata, ['AssocID', $clientValues{'assocID'}, $name];
		}
	}
	if($clientValues{'compID'} and $clientValues{'compID'})	{
		my $obj = getInstanceOf(
			\%Data,
			'comp',
			$clientValues{'compID'},
		);
		if($obj)	{
			my $name = $obj->getValue('strTitle') || '';
			push @outdata, ['CompID', $clientValues{'compID'}, $name];
		}
	}
	if($clientValues{'clubID'} and $clientValues{'clubID'} > 0)	{
		my $obj = getInstanceOf(
			\%Data,
			'club',
			$clientValues{'clubID'},
		);
		if($obj)	{
			my $name = $obj->getValue('strName') || '';
			push @outdata, ['ClubID', $clientValues{'clubID'}, $name];
		}
	}
	if($clientValues{'teamID'} and $clientValues{'teamID'} > 0)	{
		my $obj = getInstanceOf(
			\%Data,
			'team',
			$clientValues{'teamID'},
		);
		if($obj)	{
			my $name = $obj->getValue('strName') || '';
			push @outdata, ['TeamID', $clientValues{'teamID'}, $name];
		}
	}
	if($clientValues{'memberID'} and $clientValues{'memberID'} > 0)	{
		my $obj = getInstanceOf(
			\%Data,
			'member',
			$clientValues{'memberID'},
		);
		if($obj)	{
			my $name = $obj->name() || '';
			push @outdata, ['MemberID', $clientValues{'memberID'}, $name];
		}
	}

	push @outdata, ['Current Level', $clientValues{'currentLevel'}, $Defs::LevelNames{$clientValues{'currentLevel'}}];
	push @outdata, ['Auth Level', $clientValues{'authLevel'}, $Defs::LevelNames{$clientValues{'authLevel'}}];
	push @outdata, ['Username', $clientValues{'userName'}, ''];


	my $body = '';
	for my $row (@outdata)	{
		$body .= qq{
			<tr>
				<td>$row->[0]</td>
				<td>$row->[1]</td>
				<td>$row->[2]</td>
			</tr>
		};
	}
	$body = qq[
		<table>
			$body
		</table>
	];
	return $body;

}




