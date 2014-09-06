#!/usr/bin/perl -w

use lib "../..","..",".";
use DBI;
use MCache;
use CGI qw(param escape);
use Defs;
use Utils;
use strict;
use Data::Dumper;


main();


sub main	{
	my $header = "Content-type: text/html\n\n";
	my $body = "";
	my $title = "MemCache Stats";
	my $target = 'cachestats.cgi';
	my $action = param('a')	|| '';
	my $key = param('key')	|| '';
	my $value = param('value')	|| '';
	my $group = param('group')	|| '';
	my $type = param('type')	|| '';

	my $mcache = new MCache;
	my $returnkey = '';

	if($action eq 'set' and $key and $value)	{
		$mcache->set($type, $key, $value, $group);
	}
	elsif($action eq 'delete' and $key )	{
		$mcache->delete($type, $key);
	}
	elsif($action eq 'deletegroup' and $group)	{
		$mcache->delgroup($type, $group);
	}
	elsif($action eq 'get')	{
		$returnkey = $mcache->get($type,$key);
	}
	if($mcache)	{
		my $stats = $mcache->stats();
		if(ref $returnkey)	{
			my $rk = Dumper($returnkey);
			$returnkey = $rk;
		}
		$returnkey = "VALUE = <pre>$returnkey</pre>" if $returnkey;
		$body.=qq[
			<h1>SportingPulse Memcache Stats</h1>
			$returnkey
				<table>
					<tr>
						<td>Uptime</td>
						<td>].int($stats->{'uptime'}/60/60/24).qq[ Days </td>
					</tr>
					<tr>
						<td>Current Number of Items</td>
						<td>].commify($stats->{'curr_items'}).qq[</td>
					</tr>
					<tr>
						<td>Total Number of Items since restart</td>
						<td>].commify($stats->{'total_items'}).qq[</td>
					</tr>
					<tr>
						<td>MB cached</td>
						<td>].commify(int($stats->{bytes}/1024/1024)).qq[ (].int(100*($stats->{bytes}/$stats->{'limit_maxbytes'})).qq[%)</td>
					</tr>
					<tr>
						<td>Limit MB</td>
						<td>].commify($stats->{'limit_maxbytes'}/1024/1024).qq[</td>
					</tr>
					<tr>
						<td>Current Connections</td>
						<td>$stats->{'curr_connections'}</td>
					</tr>
					<tr>
						<td>Total Connections</td>
						<td>].commify($stats->{'total_connections'}).qq[</td>
					</tr>
					<tr>
						<td>Gets</td>
						<td>].commify($stats->{'cmd_get'}).qq[</td>
					</tr>
					<tr>
						<td>Sets</td>
						<td>].commify($stats->{'cmd_set'}).qq[</td>
					</tr>
					<tr>
						<td>Get Hits</td>
						<td>].commify($stats->{'get_hits'}).qq[ (].int($stats->{'get_hits'}/($stats->{'cmd_get'}||1) * 100).qq[%)</td>
					</tr>
					<tr>
						<td>Get Misses</td>
						<td>].commify($stats->{'get_misses'}).qq[ (].int($stats->{'get_misses'}/($stats->{'cmd_get'}||1) * 100).qq[%)</td>
					</tr>
					<tr>
						<td>MB Read by this server (Receiving data)</td>
						<td>].commify(int($stats->{'bytes_read'}/1024/1024)).qq[</td>
					</tr>
					<tr>
						<td>MB Written by this server (Sending data)</td>
						<td>].commify(int($stats->{'bytes_written'}/1024/1024)).qq[</td>
					</tr>
					<tr>
						<td>Threads</td>
						<td>$stats->{'threads'}</td>
					</tr>
					<tr>
						<td>Accepting Connections</td>
						<td>$stats->{'accepting_conns'}</td>
					</tr>
				</table>

			<h1>Cache Actions</h1>
				<form action = "$target">
					<b>Get Key</b> ====
					<select name="type" size="1">
						<option value=""></option>
						<option value="sww">SWW</option>
						<option value="swm">SWM</option>
						<option value="pp">Passport</option>
						<option value="mys">MySport</option>
						<option value="ls">LiveStats</option>
					</select>
					<b>key</b> :<input type="text" name="key" value="" size="20">

				<input type="hidden" name="a" value="get">
				<input type="submit" value="Get">

				</form>
				<form action = "$target">
					<b>Set Key</b> ====
					<select name="type" size="1">
						<option value=""></option>
						<option value="sww">SWW</option>
						<option value="swm">SWM</option>
						<option value="mys">MySport</option>
						<option value="ls">LiveStats</option>
						<option value="pp">Passport</option>
					</select>
					<b>group</b> :<input type="text" name="group" value="" size="20">
					<b>key</b> :<input type="text" name="key" value="" size="20">
					<b>value</b> :<input type="text" name="value" value="" size="20">

				<input type="hidden" name="a" value="set">
				<input type="submit" value="Set">

				</form>
				<form action = "$target">
					<b>Delete Key</b> ====
					<select name="type" size="1">
						<option value=""></option>
						<option value="sww">SWW</option>
						<option value="swm">SWM</option>
						<option value="mys">MySport</option>
						<option value="ls">LiveStats</option>
						<option value="pp">Passport</option>
					</select>
					<b>key</b> :<input type="text" name="key" value="" size="20">
				<input type="hidden" name="a" value="delete">

				<input type="submit" value="Delete">

				</form>		

				<form action = "$target">
					<b>Delete Group</b> ====
					<select name="type" size="1">
						<option value=""></option>
						<option value="sww">SWW</option>
						<option value="swm">SWM</option>
						<option value="mys">MySport</option>
						<option value="ls">LiveStats</option>
						<option value="pp">Passport</option>
					</select>
					<b>group</b> :<input type="text" name="group" value="" size="20">
				<input type="hidden" name="a" value="deletegroup">

				<input type="submit" value="Delete Group">

				</form>		


		];
	}
	else	{
		$body = qq[Cannot connect to memcached server];
	}

	printReport($body);
}

sub printReport	{
	my($body) = @_;

	my $title='Cache Stats';
    print qq[Content-type: text/html\n\n];
    print qq[
        <html>
            <head>
                <title>$title</title>
                <link rel="stylesheet" type="text/css" href="css/style.css">
            </head>
            <body class="report">
                $body
            </body>
        </html>
	];
}












