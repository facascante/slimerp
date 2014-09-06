#
# $Header: svn://svn/SWM/trunk/web/admin/TeamAdmin.pm 8251 2013-04-08 09:00:53Z rlee $
#

package TeamAdmin;

require Exporter;
@ISA =  qw(Exporter);
@EXPORT = qw(team_info);
@EXPORT_OK = qw(team_info);

use lib "..","../..","../sp_publisher";
use DBI;
use CGI qw(param unescape escape);
use strict;
use Defs;
use Utils;
use AdminCommon;
use DeQuote;
use FormHelpers;
use AdminPageGen;
sub team_info
{

  my($db, $target, $memberID)=@_;
  my $body='';
  my $menu='';

         $body = qq[
<table style="margin-left:auto;margin-right:auto;">
<tr><td class="formbg"><h2>Team Info?</h2>

  <form action="$target" method="post">
                <b>TeamID</b>: <input type = "text" value = "$memberID" size =" 15" name = "teamID"><br>
    <input type="submit" name="submit" value="Get Info">
    <input type = "hidden" name="action" value="TEAM_INFO">
    </div>
  </form><br>
</td></tr></table>
        ];


if($memberID) {

my $st = qq[
           SELECT intTeamID, intClubID, intAssocID, strName from tblTeam WHERE intTeamID=$memberID
        ];

my $stMT = qq[
        SELECT MT.intMemberTeamID, MT.intTeamID, MT.intMemberID, M.strFirstname, M.strSurname, MT.intCompID, AC.strTitle, AC.intSeasonID, MT.tTimeStamp, MT.intStatus FROM tblMember_Teams MT
INNER JOIN tblMember M ON (M.intMemberID = MT.intMemberID)
LEFT JOIN tblAssoc_Comp AC ON (MT.intCompID = AC.intCompID)
WHERE MT.intTeamID=$memberID
];
my $stCT = qq[SELECT CT.intCompNO, CT.intTeamID, CT.intCompID, AC.strTitle, CT.tTimeStamp, CT.intRecStatus, CT.intHideOnLadder FROM tblComp_Teams CT
LEFT JOIN tblAssoc_Comp AC ON (CT.intCompID = AC.intCompID)
WHERE CT.intTeamID =$memberID
];
my $stL = qq[select intLadderID, intCompID,intRoundID, intRoundNumber,intTeamID, strName, intResultStatus,intStatTotal1 'Played',intStatTotal2 'Won',intStatTotal3 'Lost',intStatTotal4 'Drawn' ,intStatTotal14 'Byes' ,intStatTotal5 'For' ,intStatTotal6 'Against' ,intStatTotal11 'Points',dblStatTotal1 'Percentage',strStatTotal1 'Last 5' ,dblStatTotal20 'Bonus Points' ,intStat24 'Penalty Points' from tblLadder WHERE intTeamID=$memberID
];
my $stMatch = qq[Select intMatchID, intRoundID, intCompID, intAssocID, intMatchNum, strMatchName, dtMatchTime, intVenueID, intHomeTeamID, intAwayTeamID, intRecStatus, intMatchStatus 'Played', intHomeTeamResultStatus 'Home Status', intAwayTeamResultStatus 'Away Status', intWinningTeamID 'Winning ID', intTeam1FinalScore 'Home Final', intTeam2FinalScore 'Away Final'
FROM tblCompMatches
WHERE (intHomeTeamID=$memberID OR intAwayTeamID=$memberID) Order by dtMatchTime asc
];
$body .= dump_table('','',$memberID, $db, $st, 'tblTeam','');
$body .= dump_table('TEAM_DELETE','intTeamID',$memberID, $db, $stMT,' tblMember_Teams', 'intStatus');
$body .= dump_table('TEAM_DELETE','intTeamID',$memberID, $db, $stCT,' tblComp_Teams', 'intRecStatus');
$body .= dump_table('','',$memberID, $db, $stMatch,' tblCompMatches', '');
$body .= dump_table('','',$memberID, $db, $stL,' tblLadder', '');

}
       return $body;
}

