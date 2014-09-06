#!/usr/bin/perl -w

#
# $Header: svn://svn/SWM/trunk/misc/umberto_report.pl 8250 2013-04-08 08:24:36Z rlee $
#

use lib "../web","..";
use Defs;
use Utils;
use DBI;
use Date::Calc qw(Today Add_Delta_YM);
use strict;

my %Data=();
my $db=connectDB();

  my @agebands=(
    ['0-4',0,4],
    ['4-11',4,11],
    ['12-14',12,14],
    ['15-17',15,17],
    ['18-24',18,24],
    ['25-34',25,34],
    ['35-44',35,44],
    ['45-54',45,54],
    ['55-64',55,64],
    ['65 and over',65,200],
    ['Unknown',0,0],
  );
	my %states=();
  {
    my ($today_year,$today_month,$today_day)= Today();

    my %upperage=();
    my $sql='';
    my $cnt=0;
    for my $ageband (@agebands) {
      next if !$ageband->[2];
      my($y, $m, $d)=Add_Delta_YM($today_year, $today_month, $today_day, $ageband->[2]*-1,0);
      $upperage{$ageband->[0]}="$y-$m-$d";
      $sql.=qq[ IF(dtDOB > '$upperage{$ageband->[0]}', '$ageband->[0]', ];
      $cnt++;
    }
    $sql.=qq[ 'Unknown' ]. (')' x $cnt);

    my $statement=qq[
SELECT RL.strRealmName, S.strName AS strState, intGender, $sql as agerange, COUNT(M.intMemberID) AS numMembers

FROM
tblNode AS S
        INNER JOIN tblNodeLinks AS NLS ON S.intNodeID=NLS.intParentNodeID
        INNER JOIN tblNode AS R  ON R.intNodeID=NLS.intChildNodeID
        INNER JOIN tblNodeLinks AS NLR ON R.intNodeID=NLR.intParentNodeID
        INNER JOIN tblNode AS Z  ON Z.intNodeID=NLR.intChildNodeID
        INNER JOIN tblAssoc_Node AS AN ON Z.intNodeID=AN.intNodeID
        INNER JOIN tblAssoc AS A ON AN.intAssocID=A.intAssocID
        INNER JOIN tblMember_Associations AS MA ON A.intAssocID=MA.intAssocID
        INNER JOIN tblMember AS M ON  MA.intMemberID=M.intMemberID
        INNER JOIN tblRealms AS RL ON RL.intRealmID=M.intRealmID
WHERE
        M.intStatus=1
        AND MA.intRecStatus <> -1
GROUP BY strRealmName, strState, intGender, agerange
    ];
#AND (A.intAssocTypeID= 6 or S.intNodeID IN (1283,1286,1287,1288,1289,1290,1291) )
        #AND MA.intRecStatus<>-1

    my $query = $db->prepare($statement) or query_error($statement);
    $query->execute or query_error($statement);
    while(my($realm, $state, $gender, $age, $count) = $query -> fetchrow_array()) {
			$count||=0;
			$state||='';
			$realm||='';
			$gender||='';
      $age||='Unknown';
			$Data{$realm}{$state}{$age}{$gender}+=$count;
			$Data{$realm}{$state}{$age}{'total'}+=$count;
			$Data{$realm}{$state}{'total'}{$gender}+=$count;
			$Data{$realm}{$state}{'total'}{'total'}+=$count;
			$Data{$realm}{'total'}{$age}{$gender}+=$count;
			$Data{$realm}{'total'}{$age}{'total'}+=$count;
			$Data{$realm}{'total'}{'total'}{$gender}+=$count;
			$Data{$realm}{'total'}{'total'}{'total'}+=$count;
			$states{$realm}{$state}=1;
    }
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

push @agebands, ['total'];
my $body='';

for my $realm (keys %Data)	{
	my @state_order=();
	push @state_order, 'total';
	for my $state (sort keys %{$states{$realm}})	{ push @state_order, $state; }
	$body=qq[
		<h1>$realm</h1>
	<table>
		<tr><th>&nbsp;</th> ];
	for my $state (@state_order)	{ $body.=qq[<th colspan="3">$state</th>];	}
	$body.=qq[</tr>
		<tr> <th>Age</th>
	];
	for my $state (@state_order)	{
		$body.=qq[<th>Total</th><th>Male</th><th>Female</th>];
	}
	$body.=qq[ </tr> ];
	for my $agerange (@agebands)	{
		my $age=$agerange->[0] || '';
		$body.=qq[<tr><td>$age</td>];
		for my $state (@state_order)	{
			$body.=qq[
				<td>].commify($Data{$realm}{$state}{$age}{'total'}||0).qq[</td>
				<td>].commify($Data{$realm}{$state}{$age}{$Defs::GENDER_MALE}||0).qq[</td>
				<td>].commify($Data{$realm}{$state}{$age}{$Defs::GENDER_FEMALE}||0).qq[</td>
			];
		}
		$body.=qq[ </tr>];
	}

	$body.=qq[</table>];
print $body;
}

