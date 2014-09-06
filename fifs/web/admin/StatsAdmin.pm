#
# $Header: svn://svn/SWM/trunk/web/admin/StatsAdmin.pm 10067 2013-12-01 22:52:15Z tcourt $
#

package StatsAdmin;

require Exporter;
@ISA =  qw(Exporter);
@EXPORT = qw(node_selection node_stats);
@EXPORT_OK = qw(node_selection node_stats);

use lib "..","../..","../sp_publisher","../comp";
use DBI;
use CGI qw(param unescape escape);
use strict;
use Defs;
use Utils;
use AdminCommon;
use DeQuote;
use FormHelpers;
use AdminPageGen;
use CompSWWUpload;

sub node_selection {
  my ($db) = @_;
  my $statement=qq[
    SELECT
      *
    FROM
      tblRealms
    WHERE
      intRealmID <> '' AND intRealmID IS NOT NULL
    ORDER BY
      strRealmName
  ];
 my $body = ''; 
  my $query = $db->prepare($statement) or query_error($statement);
  $query->execute() or query_error($statement);
  while(my $dref= $query->fetchrow_hashref()) {
    foreach my $key (keys %{$dref}) { if(!defined $dref->{$key})  {$dref->{$key}='0';} }
    $body.=qq[
<table border=1 width='80%' style='border:5px solid #1376B0;margin:10px;margin-left:auto;margin-right:auto;'>
      <tr>
        <td style="background-color:#1376B0;color:white;font-size:16"><b>Realm</b>: $dref->{strRealmName}</td>
	</tr><tr>
        <td>];

  my $nodes=qq[
    SELECT
      *
    FROM
      tblNode
    WHERE
     intRealmID = $dref->{intRealmID} AND
     intTypeID= 100
    ORDER BY
      intTypeID desc, strName
  ];

  my $queryNode = $db->prepare($nodes) or query_error($nodes);
  $queryNode->execute() or query_error($nodes);
while(my $drefN= $queryNode->fetchrow_hashref()) {
    		foreach my $keyN (keys %{$drefN}) { if(!defined $drefN->{$keyN})  {$drefN->{$keyN}='';} }
		$body.=qq[<a href="?action=STATS_INFO&intEntityID=$drefN->{'intNodeID'}&intEntityType=$drefN->{'intTypeID'}" style="line-height:30px;margin:5px;padding:5px; color:white;background-color:#5F6062;">$drefN->{strName}</a> ];
	}



      $body .=qq[&nbsp;</td>
	</tr>
	</table>
    ];
}
  $body=qq[
<h1>Select A Governing Body to Report For</h1>
      $body
];
return $body;
}


sub node_stats {
  my ($db) = @_;

my $intEntityID = param('intEntityID') || 0;
my $intEntityType = param('intEntityType') || 0;
my $strEntityName = DataAdmin::dlookup($db,"strName","tblNode","intNodeID=$intEntityID");
my $intRealmID = DataAdmin::dlookup($db,"intRealmID","tblNode","intNodeID=$intEntityID");
my $strRealmName = DataAdmin::dlookup($db,"strRealmName","tblRealms","intRealmID=$intRealmID");
my $intClubs = 0;
my $intComps = 0;	
my $intCompTeams = 0;	
my $intTotalTeams = 0;
my $members = 0;
my $month = 0;
my $year = 0;
my $intMembers = 0;
my $intPlayers = 0;
my $intCoaches = 0;
my $intUmpires = 0;
 my $counts=qq[
    SELECT
      *
    FROM
    tblSnapShotEntityCounts_$intRealmID
    WHERE
     intEntityTypeID = $intEntityType
    AND intEntityID = $intEntityID
    ORDER BY
    intYear desc, intMonth desc limit 1;
  ];

  my $queryCount = $db->prepare($counts) or query_error($counts);
  $queryCount->execute() or query_error($counts);
while(my $dref= $queryCount->fetchrow_hashref()) {
                foreach my $key (keys %{$dref}) { if(!defined $dref->{$key})  {$dref->{$key}='';} }

$intClubs = $dref->{'intClubs'};
$intComps = $dref->{'intComps'};
$intCompTeams = $dref->{'intCompTeams'};
$intTotalTeams = $dref->{'intTotalTeams'};
$month = $dref->{'intMonth'};
$year = $dref->{'intYear'};

}

$members = qq[
SELECT SUM(intMembers) as 'Total Members', Sum(intPlayer) Players, Sum(intCoach) Coaches, Sum(intUmpire) Umpires
FROM tblSnapShotMemberCounts_$intRealmID M
WHERE intYear = $year AND intMonth = $month AND intEntityID=$intEntityID and intEntityTypeID=$intEntityType
ORDER BY intYear desc, intMonth desc];

  $queryCount = $db->prepare($members) or query_error($members);
  $queryCount->execute() or query_error($members);
while(my $dref= $queryCount->fetchrow_hashref()) {
                foreach my $key (keys %{$dref}) { if(!defined $dref->{$key})  {$dref->{$key}='';} }

$intMembers = $dref->{'Total Members'};
$intPlayers = $dref->{'Coaches'};
$intCoaches = $dref->{'Players'};
$intUmpires = $dref->{'Umpires'};

}

 my $body=qq[
<div style="height:250px">
<h1>Quick Info</h1>
<table border=1 cellspacing=4 cellpadding=4 style='padding:5px;border:5px solid #1376B0;margin:10px;margin-left:auto;margin-right:auto;float:left;'>
      <tr>
        <td  colspan=2 style="background-color:#1376B0;color:white;font-size:24" align="center"><b>Info</b></td>
        </tr>
      <tr>
        <td style="background-color:#1376B0;color:white;font-size:16"><b>Realm</b>: $strRealmName ($intRealmID)</td>
        </tr>
      <tr>
        <td style="background-color:#1376B0;color:white;font-size:16"><b>Node ($intEntityType)</b>: $strEntityName ($intEntityID)</td>
        </tr>
      <tr>
        <td style="background-color:#1376B0;color:white;font-size:16"><b>As Of</b>: $month/$year</td>
        </tr>
</table>

<table border=1 cellpadding=4 cellspacing=4 style='padding:5px;border:5px solid #1376B0;margin:10px;margin-left:auto;margin-right:auto;'>
      <tr>
        <td  colspan=9 style="background-color:#1376B0;color:white;font-size:24" align="center"><b>Counts</b></td>
        </tr><tr>
	<td style="background-color:#1376B0;color:white;font-size:16">Sport</td>
        <td style="background-color:#1376B0;color:white;font-size:16">Clubs</td>
        <td style="background-color:#1376B0;color:white;font-size:16">Competitions</td>
        <td style="background-color:#1376B0;color:white;font-size:16">Teams in Comps</td>
        <td style="background-color:#1376B0;color:white;font-size:16">Total Members</td>
        </tr>
	<tr>
	<td>$strRealmName</td>
	<td>$intClubs</td>
	<td>$intComps</td>
	<td>$intCompTeams</td>
	<td>$intMembers</td>
	</tr>
</table> </div>           ];

$body.= '<h2>More Info:</h2>';
$body .=DataAdmin::dump_table('',$intEntityID,$db,qq[select 
intSeasonID,	intClubs,	intComps,	intCompTeams,	intTotalTeams,	intClrIn,	intClrOut,	intClrPermitIn,	intClrPermitOut,	intTxns,	curTxnValue,	intNewTribunal
 from tblSnapShotEntityCounts_$intRealmID
 WHERE intEntityID=$intEntityID and intEntityTypeID=$intEntityType
 AND intYear = $year AND intMonth=$month
 order by intYear desc, intMonth desc],qq[tblSnapShotEntityCounts_$intRealmID]);
$body .=DataAdmin::dump_table('',$intEntityID,$db,qq[
select 
intSeasonID,	intMembers,	intNewMembers,	intRegoFormMembers,	intPermitMembers,	intPlayer,	intCoach,	intUmpire,	intOther1,	intOther2,
A.strAgeGroupDesc, case when intGender=1 then 'Male' when intGender=2 then 'Female' else 'Unknown' end as strGender 
 from tblSnapShotMemberCounts_$intRealmID M
 LEFT JOIN tblAgeGroups A ON (A.intAgeGroupID=M.intAgeGroupID)
 WHERE intEntityID=$intEntityID and intEntityTypeID=$intEntityType
 AND intYear = $year AND intMonth=$month
 order by intYear desc, intMonth desc],qq[tblSnapShotMemberCounts_$intRealmID]);

return $body;
}
