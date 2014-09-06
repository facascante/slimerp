#!/usr/bin/perl -w

#
# $Header: svn://svn/SWM/trunk/misc/mem_numbers.pl 8250 2013-04-08 08:24:36Z rlee $
#

use lib "../web","..";
use Defs;
use Utils;
use DBI;
use strict;

my %Data=();
my $db = connectDB();
        $db->{mysql_auto_reconnect} = 1;
        $db->{wait_timeout} = 3700;
        $db->{mysql_wait_timeout} = 3700;



	my $statement=qq[
SELECT RL.strRealmName, 
COUNT(DISTINCT M.intMemberID) AS numMembers
FROM tblAssoc AS A
        INNER JOIN tblMember_Associations AS MA ON A.intAssocID=MA.intAssocID
        INNER JOIN tblMember AS M ON  MA.intMemberID=M.intMemberID
        INNER JOIN tblRealms AS RL ON RL.intRealmID=M.intRealmID
WHERE
        M.intStatus <> -1
        AND MA.intRecStatus <> -1
				AND A.intRecStatus <> -1
GROUP BY 
	strRealmName
	];

	my $query = $db->prepare($statement) or query_error($statement);
	$query->execute or query_error($statement);
	while(my($realm, $count) = $query -> fetchrow_array()) {
		$count||=0;
		$realm||='';
		$Data{$realm}{'ALL'}+=$count;
	}

	$statement=qq[
SELECT RL.strRealmName, 
SR.strSubTypeName,
COUNT(DISTINCT M.intMemberID) AS numMembers
FROM tblAssoc AS A
        INNER JOIN tblMember_Associations AS MA ON A.intAssocID=MA.intAssocID
        INNER JOIN tblMember AS M ON  MA.intMemberID=M.intMemberID
        INNER JOIN tblRealms AS RL ON RL.intRealmID=M.intRealmID
        INNER JOIN tblRealmSubTypes AS SR ON (
					A.intAssocTypeID=SR.intSubTypeID
					AND SR.intRealmID = RL.intRealmID
				)
WHERE
        M.intStatus <> -1
        AND MA.intRecStatus <> -1
GROUP BY 
	strRealmName, 
	strSubTypeName
	];

	$query = $db->prepare($statement) or query_error($statement);
	$query->execute or query_error($statement);
	while(my($realm, $subrealm, $count) = $query -> fetchrow_array()) {
		$count||=0;
		$realm||='';
		$subrealm||='';
		$Data{$realm}{$subrealm}+=$count;
	}

print qq[
	<style type="text/css">
		html  {
			font-family: verdana, arial, helvetica, sans-serif;
			margin:0px;
			font-size:12px;
		}
		td,th	{
			font-size:12px;
			padding:3px;
		}
	 	table, td {
			border:1px solid black;
			border-collapse:collapse;
		}

		</style>


];

my $time = scalar(localtime());
my $body=qq[
	<h1>Record Counts in SWM</h1>
	<h3>As of $time</h3>
	<table>
		<tr>
			<th colspan="2">&nbsp;</th>
			<th>Number or Unique Member Records</th>
		</tr>
];

for my $realm (sort keys %Data)	{
	$body.=qq[
		<tr>
			<th colspan="2">$realm</th>
			<td>].commify($Data{$realm}{'ALL'}).qq[</td>
		</tr>
	];
	for my $subrealm (sort keys %{$Data{$realm}})	{
		next if $subrealm eq 'ALL';
		$body.=qq[
			<tr>
				<td>&nbsp;</td>
				<td>$subrealm</td>
				<td>].commify($Data{$realm}{$subrealm}).qq[</td>
			</tr>
		];
	}
}
	$body.=qq[</table>];
print $body;

