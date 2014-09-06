#
# $Header: svn://svn/SWM/trunk/web/admin/DataAdmin.pm 11327 2014-04-17 02:06:36Z dhanslow $
#

package DataAdmin;

require Exporter;
@ISA =  qw(Exporter);
@EXPORT = qw(data_publish timestamp_now fieldPermCheck item_set_update item_set_edit item_set_delete data_info);
@EXPORT_OK = qw(data_publish timestamp_now fieldPermCheck item_set_update item_set_edit data_info item_set_delete);

use lib "..","../..","../sp_publisher",".","../comp";
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
use HTML::Entities;
sub display_member_search_list {
  my ($db, $action, $intAssocID, $target) = @_;
  my $member_name_IN = param('member_firstname') || '';
  my $realm_IN = param('realmID') || '';
  my $member_surname_IN = param('member_surname') || '';
  my $member_id_IN = param('member_id') || '';
  my $member_email_IN = param('member_email') || '';
my $strWhere='';
  if ($member_email_IN) {
    $strWhere .= "AND strEmail LIKE '%".$member_email_IN."%'";
  }
  if ($member_name_IN) {
    $strWhere .= "AND strFirstname LIKE '%".$member_name_IN."%'";
  }
  if ($member_surname_IN) {
    $strWhere .= "AND strSurname LIKE  '%".$member_surname_IN."%'";
  }
  if ($member_id_IN) {
    $strWhere .= "AND strNationalNum LIKE '%". $member_id_IN."%'";
  }
  if ($realm_IN) {
    $strWhere .= "AND intRealmID = $realm_IN ";
  }
  my $statement=qq[
    SELECT
      *
    FROM
      tblMember m
    WHERE
	    intMemberID>0
      $strWhere
    ORDER BY
      strSurname,
      strFirstname
  ];
  
  my $query = $db->prepare($statement) or query_error($statement);
  $query->execute() or query_error($statement);
  my $count=0;
  my $body='';
  while(my $dref= $query->fetchrow_hashref()) {
    foreach my $key (keys %{$dref}) { if(!defined $dref->{$key})  {$dref->{$key}='';} }
    $dref->{strName} = $dref->{strName} || '&nbsp;';
    $dref->{strUsername} = $dref->{strUsername} || '';
    $dref->{strUsername} = qq[3] . $dref->{strUsername} if ($dref->{strUsername});
    $dref->{strPassword} = $dref->{strPassword} || '';
    $dref->{strRealmName} ||= '&nbsp;';
    my $class='';
    my $classborder='commentborder';
    if($count++%2==1) {
      $class=q[ class="commentshaded" ];
      $classborder="commentbordershaded";
    }
    my $extralink='';
    if($dref->{intStatusID} < 1) {
      $classborder.=" greytext";
      $extralink=qq[ class="greytext"];
    }
   my $hiddenMember = '';
   if($dref->{intMemberToHideID}!='') { 
    $hiddenMember = 'Yes';
   }
    $body.=qq[
      <tr>
        <td class="$classborder">$dref->{intMemberID}</td>
        <td class="$classborder">$dref->{strFirstname}</td>
        <td class="$classborder">$dref->{strSurname}</td>
        <td class="$classborder">$dref->{strNationalNum}</td>
        <td class="$classborder">$dref->{strEmail}</td>
     	<td class="$classborder" align="center"><a href="?action=MEMBER_INFO&memberID=$dref->{intMemberID}">?</a></td>
	</tr>
    ];
  }
  if(!$body)  {
    $body.=qq[
    <table cellpadding="1" cellspacing="0" border="0" width="90%" align="center">
      <tr>
        <td colspan="3" align="center"><b><br> No Search Results were found<br><br></b></td>
      </tr>
    </table>
    <br>
    ];
  }
  else  {
    $body=qq[
     <table cellpadding="1" cellspacing="0" border="0" width="95%" align="center">
      <tr>
	<th style="text-align:left;">Member ID</th>
        <th style="text-align:left;">First Name</th>
        <th style="text-align:left;">Surname</th>
        <th style="text-align:left;">National Number</th>
        <th style="text-align:left;">Email</th>
 	<th style="text-align:center;">Counts / Delete</th>
	</tr>
      $body
    </table><br>
    ];
  }
}
sub data_info
{

  my($db, $target, $type,$useID)=@_;
  my $body='';
  my $menu='';
my @options = ('','LIKE', 'IN','=','>','<','>=','<=','!=','IS NOT NULL','IS NULL');
my $header = '';
my $tables = '';
my %types = ('intTableID',"Tables",
'intTableData','TableData For',
'intRealmID', 'Realm',
'intNodeID', 'Node',
'intMemberID', 'Member',
'intTeamID', 'Team',
'intClubID', 'Club',
'intAssocID', 'Assoc',
'intCompID', 'Comp',
'intMatchID','Match',
'intTransLogID','TransLog',
'intProductID','Product',
'intRegoFormID', 'RegoForm');
       my  $mainBody = qq[
<table style="margin-left:auto;margin-right:auto;">
<tr><td class="formbg"><h2> $types{$type} Info</h2>
  <form action="$target" method="get">
                <b><select name="type">];
foreach my $key (sort keys %types){
		my $value = $types{$key};
    my $selected = ($key eq $type) ? qq[ SELECTED ] : '';
 $mainBody .= "<option value='$key' $selected>".$value."</option>";
}
$mainBody .= qq[
</select>
ID</b>: <input type = "text" value = "$useID" size =" 15" name = "useID"><br>
		 
   <input type="submit" name="submit" value="Get Info">
    <input type = "hidden" name="action" value="DATA">
    </div>
  </form><br>
</td></tr></table>
        ];
my $intEntityType = 0;
my $intRealmID = '';
if($type eq 'intTableData') {

my $st = qq[
SHOW FIELDS FROM $useID;
        
];

my @primary_keys = get_primary_keys($db,$useID);

my $query = $db->prepare($st);
$query->execute();

my $table = qq[<form name="actionform" action="" method="post">
<input type="hidden" name="action" value="DATA">
<input type="hidden" name="type" value="$type">
<input type="hidden" name="useID" value="$useID">
<table border=1 width='80%' style='border:5px solid #1376B0;margin:10px;margin-left:auto;margin-right:auto;'>
<tr>
<td style="background-color:#1376B0;color:white;">Select</td>
<td style="background-color:#1376B0;color:white;">Field</td>
<td style="background-color:#1376B0;color:white;">Action</td>
<td style="background-color:#1376B0;color:white;">Value</td>
</tr>\n];
my $rows=0;
my $fieldcheck = '';
my $fieldoption = '';
my $fieldwhere = '';
my $sqlWhere = '';
my @displayfields = ();
my @allfields = ();
while (my(@row) = $query->fetchrow_array)
{
push(@allfields,$row[0]);
my $fieldcheck = param("dbcheck_$row[0]");
my $fieldoption = param("dboptions_$row[0]");
my $fieldoptionwrap = '';
my $fieldoptiontrail = '';
my $fieldwhere = param("dbwhere_$row[0]");
 $rows++;
my $value = "x";
$table .= "  <tr>\n";
if(grep /$row[0]/, @primary_keys) { 
push(@displayfields,$row[0]);
$table .= qq[
<td>&#10003; <input type="hidden" name="dbcheck_$row[0]" value=1></td>
];
} else {
if($fieldcheck == 1) {push(@displayfields,$row[0]);}
my $selected  = ($fieldcheck == 1)? ' CHECKED ' : '';
$table .= qq[
<td><input type="checkbox" name="dbcheck_$row[0]" value=1 $selected></td>
];
}
$table .=qq[
<td><b>$row[0]</b></td>
<td><select name="dboptions_$row[0]">
];

foreach my $value (@options){
	my $selected = ($value eq $fieldoption) ? qq[ SELECTED ] : '';
 $table .= "<option value='$value' $selected>".$value."</option>";
}


$table .=qq[</select></td>
<td><input type="text" name="dbwhere_$row[0]" value="$fieldwhere"></td>
</tr>
];
if(($fieldoption ne '' and $fieldwhere ne '') or ($fieldoption eq 'IS NULL' or $fieldoption eq 'IS NOT NULL'))
{
if($fieldoption eq 'IN'){$fieldoption = 'IN (';
$fieldoptiontrail = ')';
}
elsif($fieldoption eq 'LIKE') { $fieldoptionwrap = "\"";}
elsif($fieldoption eq 'IS NOT NULL' or $fieldoption eq 'IS NULL') { $fieldwhere = '';}
$sqlWhere .= qq[`$row[0]` $fieldoption $fieldoptionwrap$fieldwhere$fieldoptionwrap $fieldoptiontrail AND ];

}
}
$body .=$table.qq[
<tr><td colspan=3 align="right">Order By <select name="db_order">];
my $actualSortOrder = '';
my$db_order = param("db_order");
foreach my $value (@allfields){
	if($value eq $db_order) { $actualSortOrder = "ORDER BY $db_order ASC";}
        my $selected = ($value eq $db_order) ? qq[ SELECTED ] : '';
 $body .= "<option value='$value' $selected>".$value."</option>";
}



$body .=qq[</select></td><td><input type="submit" value="submit"></td></tr>
</table></form>];
my $fields = join(", ",@displayfields);

if($sqlWhere ne ''){
$body .= dump_table('',$useID, $db,qq[SELECT $fields FROM $useID WHERE $sqlWhere 1=1 $actualSortOrder],$useID,'');
}
$body .= dump_table('',$useID, $db, $st,$useID.' Fields', '');


} elsif($type eq 'intTableID') {
my $st = qq[
           Show tables like "\%$useID\%"
        ];
$body .= dump_table('',$useID, $db, $st,'tables', '');


}elsif($type eq 'intRealmID') {
my $st = qq[
           SELECT intRealmID, strRealmName from tblRealms WHERE intRealmID=$useID
        ];

my $stS = qq[
           SELECT intSubTypeID, intSubTypeID, strSubTypeName from tblRealmSubTypes WHERE intRealmID=$useID
        ];
my $stN = qq[
           SELECT intNodeID, strName, tTimeStamp from tblNode WHERE intTypeID=100 AND intRealmID=$useID
        ];

$body .= dump_table('',$useID, $db, $st,'tblRealms', '');
$body .= dump_table('',$useID, $db, $stS,'tblRealmSubTypes', '');
$body .= dump_table('',$useID, $db, $stN,'tblNode (100)', '');
}
elsif($type eq 'intNodeID') {

my %levels =('100','30','30','20','20','10','10','Assoc');

my $st = qq[
           SELECT intRealmID,intTypeID from tblNode WHERE intNodeID=$useID
        ];
        my $query = $db->prepare($st);
        $query->execute();

        ($intRealmID,$intEntityType) = $query->fetchrow_array();

$st = qq[
           SELECT intNodeID, intStatusID, strName, tTimeStamp, intSubTypeID FROM tblNode WHERE intNodeID=$useID
        ];
my $stnl = qq[
select N.intNodeID, N.strName from tblNodeLinks NL, tblNode N WHERE N.intNodeID=NL.intParentNodeID AND intChildNodeID=$useID];; 

my $stN='';
if($levels{$intEntityType} eq 'Assoc')
{
$stN = "SELECT distinct A.intAssocID, A.strName, A.tTimeStamp from tblAssoc A LEFT JOIN tblTempNodeStructure TNS ON (A.intAssocID = TNS.intAssocID) WHERE TNS.int10_ID=$useID"; 
}else{
$stN = "SELECT distinct N.intNodeID, N.strName, N.tTimeStamp from tblNode N LEFT JOIN tblTempNodeStructure TNS ON (N.intNodeID = TNS.int".$levels{$intEntityType}."_ID) WHERE intTypeID=".$levels{$intEntityType}." AND TNS.int".$intEntityType."_ID=$useID"; 
}
my $nodeLevel = dlookup($db,'intTypeID','tblNode',qq[intNodeID=$useID]);
my $stBank = qq[SELECT * from tblBankAccount WHERE intEntityID=$useID AND intEntityTypeID=$nodeLevel;];
my $stPayment = qq[SELECT intApplicationID, strOrgName, strACN, strABN, strSoftDescriptor, dtCreated, intPaymentType FROM tblPaymentApplication WHERE intEntityTypeID=$nodeLevel AND intEntityID=$useID];
$body .= dump_table('',$useID, $db, $st,'tblNode', '');
$body .= dump_table('',$useID, $db, $stnl,'tblParentNode', '');
$body .= dump_table('',$useID, $db, $stN,qq[tblNode ($levels{$intEntityType})], '');
$body .= dump_table('',$useID, $db, $stBank,'tblBankAccount', '');
$body .= dump_table('',$useID, $db, $stPayment,'tblPaymentApplication', '');

}

elsif($type eq 'intAssocID') {
my $st = qq[
           SELECT intRealmID from tblAssoc WHERE intAssocID=$useID
        ];
        my $query = $db->prepare($st);
        $query->execute();
	
        $intRealmID = $query->fetchrow_array();
	$intEntityType = 5;
$st = qq[
           SELECT intAssocID, strName, intRealmID, intAssocTypeID, intCurrentSeasonID 'SeasonID', intNewRegoSeasonID 'RegoSeasonID', dtRegistered, tTimeStamp, intRecStatus from tblAssoc WHERE intAssocID=$useID
        ];
my $stN = qq[
		select TNS.intRealmID,N100.intNodeID, N100.strName, N30.intNodeID, N30.strName, N20.intNodeID, N20.strName, N10.intNodeID, N10.strName, TNS.tTimeStamp 
from tblTempNodeStructure TNS
LEFT JOIN tblNode N100 ON (TNS.int100_ID = N100.intNodeID)
LEFT JOIN tblNode N30 ON (TNS.int30_ID = N30.intNodeID)
LEFT JOIN tblNode N20 ON (TNS.int20_ID = N20.intNodeID)
LEFT JOIN tblNode N10 ON (TNS.int10_ID = N10.intNodeID)



WHERE intAssocID=$useID;
];
my $stAC = qq[
           SELECT intCompID, intAssocID, strTitle, intNewSeasonID, tTimeStamp, intStatus from tblAssoc_Comp WHERE intAssocID=$useID
        ];

my $stACl = qq[
           SELECT intAssocClubID, intAssocID, C.intClubID, C.strName, AC.tTimeStamp, AC.intRecStatus from tblAssoc_Clubs AC LEFT JOIN tblClub C ON (C.intClubID=AC.intClubID) WHERE intAssocID=$useID
        ];
my $stRego = qq[
		SELECT intRegoFormID, intAssocID, intClubID, intRealmID, strRegoFormName,intStatus FROM tblRegoForm WHERE intAssocID=$useID
];
my $stBank = qq[SELECT * from tblBankAccount WHERE intEntityID=$useID AND intEntityTypeID=5;];

my $stPayment = qq[SELECT intApplicationID, strOrgName, strACN, strABN, strSoftDescriptor, dtCreated, intPaymentType FROM tblPaymentApplication WHERE intEntityTypeID=5 AND intEntityID=$useID];
my $allowSWOL = dlookup($db, "intSWOL","tblAssoc","intAssocID=$useID")|| 0;;
if($allowSWOL==1){
$body .= qq[<p align="right" style="padding-right:10%" width="80%"><a href="?action=DATA_PUBLISH&intAssocID=$useID" style="background-color:red;color:white;padding:5px;border:1px solid black;">PUBLISH TO WEB</a></p>];
}
$body .= dump_table('intAssocID',$useID, $db, $st,'tblAssoc', 'intRecStatus');
$body .= dump_table('',$useID, $db, $stN,'tblTempNodeStructure', '');
$body .= dump_table('intAssocID',$useID, $db, $stAC,'tblAssoc_Comp', 'intStatus');
$body .= dump_table('intAssocID',$useID, $db, $stACl,'tblAssoc_Clubs', 'intRecStatus');
$body .= dump_table('intAssocID',$useID, $db, $stRego,'tblRegoForm', 'intStatus');
$body .= dump_table('intAssocID',$useID, $db, $stBank,'tblBankAccount', '');
$body .= dump_table('',$useID, $db, $stPayment,'tblPaymentApplication', '');

}
elsif($type eq 'intMatchID') {

my $st = qq[
           SELECT intAssocID from tblCompMatches WHERE intMatchID=$useID
        ];
        my $query = $db->prepare($st);
        $query->execute();

        my $intAssocID = $query->fetchrow_array();



my $stMatch = qq[Select intMatchID, intRoundID, intCompID, intAssocID, intMatchNum, strMatchName, dtMatchTime, intVenueID, intHomeTeamID, intAwayTeamID, intRecStatus, intMatchStatus 'Played', intHomeTeamResultStatus 'Home Status', intAwayTeamResultStatus 'Away Status', intWinningTeamID 'Winning ID', intTeam1FinalScore 'Home Final', intTeam2FinalScore 'Away Final'
FROM tblCompMatches
WHERE (intMatchID=$useID) Order by intMatchID, dtMatchTime asc
];
my $stCMP = qq[
        SELECT intSPID, intMatchID, intTeamID, intMemberID,intOrder,tTimeStamp,intOnPermit FROM tblCompMatchSelectedPlayers WHERE  intMatchID=$useID
];
my $stCMPS = qq[
        SELECT intMatchStatID,intMemberID

,intStat1       	"	is1	",
 intStat2       	"	is2	",
 intStat3       	"	is3	",
 intStat4       	"	is4	",
 intStat5       	"	is5	",
 intStat6       	"	is6	",
 intStat7       	"	is7	",
 intStat8       	"	is8	",
 intStat9       	"	is9	",
 intStat10      	"	is10	",
 intStat11      	"	is11	",
 intStat12      	"	is12	",
 intStat13      	"	is13	",
 intStat14      	"	is14	",
 intStat15      	"	is15	",
 intStat16      	"	is16	",
 intStat17      	"	is17	",
 intStat18      	"	is18	",
 intStat19      	"	is19	",
 intStat20      	"	is20	",
 intStat21      	"	is21	",
 intStat22      	"	is22	",
 intStat23      	"	is23	",
 intStat24      	"	is24	",
 intStat25      	"	is25	",
 dblStat1       	"	ds1	",
 dblStat2       	"	ds2	",
 dblStat3       	"	ds3	",
 dblStat4       	"	ds4	",
 dblStat5       	"	ds5	",
 dblStat6       	"	ds6	",
 dblStat7       	"	ds7	",
 dblStat8       	"	ds8	",
 dblStat9       	"	ds9	",
 dblStat10      	"	ds10	",
 dblStat11      	"	ds11	",
 dblStat12      	"	ds12	",
 dblStat13      	"	ds13	",
 dblStat14      	"	ds14	",
 dblStat15      	"	ds15	",
 dblStat16      	"	ds16	",
 dblStat17      	"	ds17	",
 dblStat18      	"	ds18	",
 dblStat19      	"	ds19	",
 dblStat20      	"	ds20	",
 strStat1       	"	ss1	",
 strStat2       	"	ss2	",
 strStat3       	"	ss3	",
 strStat4       	"	ss4	",
 strStat5       	"	ss5	",
 strStat6       	"	ss6	",
 strStat7       	"	ss7	",
 strStat8       	"	ss8	",
 strStat9       	"	ss9	",
 strStat10      	"	ss10	",
 strStat11      	"	ss11	",
 strStat12      	"	ss12	",
 strStat13      	"	ss13	",
 strStat14      	"	ss14	",
 strStat15      	"	ss15	",
 strStat16      	"	ss16	",
 strStat17      	"	ss17	",
 strStat18      	"	ss18	",
 strStat19      	"	ss19	",
 strStat20      	"	ss20	",
 tTimeStamp     	"tTime"

 FROM tblCompMatchPlayerStats WHERE intMatchID=$useID
];

my $stCSMD = qq[
           SELECT * from tblCourtsideOnlineMatchData WHERE intMatchID=$useID        ];

$body .= dump_table('',$useID, $db, $stMatch,'tblCompMatches', '');
$body .= dump_table('',$useID,$db, $stCMP, 'tblCompMatchSelectedPlayers');
$body .= dump_table('',$useID, $db, $stCMPS, 'tblCompMatchPlayerStats');
$body .= dump_table('',$useID, $db, $stCSMD, 'tblCourtsideOnlineMatchData');

$body .= qq[<p align="right" style="padding-right:10%" width="80%"><a href="?action=DATA_PUBLISH&intAssocID=$intAssocID&intMatchID=$useID" style="background-color:red;color:white;padding:5px;border:1px solid black;">PUBLISH TO WEB - Stadium Scoring</a></p>];
$body .= qq[<p align="right" style="padding-right:10%" width="80%"><a href="?action=DATA_PUBLISH&intAssocID=$intAssocID&intMatchID=$useID&type=51" style="background-color:red;color:white;padding:5px;border:1px solid black;">PUBLISH TO WEB - LiveStats</a></p>];
}

elsif($type eq 'intCompID') {

my $stAC = qq[
           SELECT AC.intCompID, AC.strTitle,AC.intAssocID, A.strName, AC.intNewSeasonID, AC.tTimeStamp, AC.intStatus from tblAssoc_Comp AC LEFT JOIN tblAssoc A ON (A.intAssocID=AC.intAssocID) WHERE intCompID=$useID
        ];
my $stMT = qq[
        SELECT MT.intMemberTeamID, MT.intTeamID, MT.intMemberID, M.strFirstname, M.strSurname, MT.intCompID, AC.strTitle, AC.intNewSeasonID, MT.tTimeStamp, MT.intStatus FROM tblMember_Teams MT
INNER JOIN tblMember M ON (M.intMemberID = MT.intMemberID)
LEFT JOIN tblAssoc_Comp AC ON (MT.intCompID = AC.intCompID)
WHERE MT.intCompID=$useID
];
my $stCT = qq[SELECT CT.intCompNO, CT.intTeamID, CT.intTeamNum, T.strName, CT.intCompID, CT.tTimeStamp, CT.intRecStatus, CT.intHideOnLadder FROM tblComp_Teams CT
LEFT JOIN tblTeam T ON (CT.intTeamID = T.intTeamID)
WHERE CT.intCompID =$useID
order by CT.intRecStatus DESC, CT.intTeamNum ASC
];
my $stL = qq[select intLadderID, intCompID,intRoundID, intRoundNumber,intTeamID, strName, intResultStatus,intStatTotal1 'Played',intStatTotal2 'Won',intStatTotal3 'Lost',intStatTotal4 'Drawn' ,intStatTotal14 'Byes' ,intStatTotal5 'For' ,intStatTotal6 'Against' ,intStatTotal11 'Points',dblStatTotal1 'Percentage',strStatTotal1 'Last 5' ,dblStatTotal20 'Bonus Points' ,intStat24 'Penalty Points' from tblLadder L
INNER JOIN (Select max(intRoundID) max FROM tblLadder WHERE intCompID=$useID) LL ON (LL.max=L.intRoundID)
WHERE intCompID=$useID 
ORDER BY intRoundID desc, Points desc, Percentage desc];
my $stMatch = qq[Select intMatchID, intRoundID, intCompID, intAssocID, intMatchNum, strMatchName, dtMatchTime, intVenueID, intHomeTeamID, intAwayTeamID, intRecStatus, intMatchStatus 'Played', intHomeTeamResultStatus 'Home Status', intAwayTeamResultStatus 'Away Status', intWinningTeamID 'Winning ID', intTeam1FinalScore 'Home Final', intTeam2FinalScore 'Away Final'
FROM tblCompMatches
WHERE (intCompID=$useID) Order by intMatchID, dtMatchTime asc
];
my $stH = qq[SELECT * from tblCompHideRounds WHERE intCompID=$useID];

my $stR = qq[Select intRoundID, intAssocID, intCompID, intRoundNumber, strRoundName, intRoundTypeID, intPoolID, tTimeStamp, intRecStatus
 FROM tblCompRounds WHERE intCompID=$useID order by intRoundTypeID, intRoundNumber asc];
$body .= dump_table('intCompID',$useID, $db, $stAC,'tblAssoc_Comp', 'intStatus');
$body .= dump_table('intCompID',$useID, $db, $stMT,'tblMember_Teams');
$body .= dump_table('intCompID',$useID, $db, $stCT,'tblComp_Teams', 'intRecStatus');
$body .= dump_table('intCompID',$useID, $db, $stR,'tblCompRounds', 'intRecStatus');
$body .= dump_table('intCompID',$useID, $db, $stH,'tblCompHideRounds', '');
$body .= dump_table('intCompID',$useID, $db, $stMatch,'tblCompMatches', 'intRecStatus');
$body .= dump_table('',$useID, $db, $stL,'tblLadder', '');

} 
elsif($type eq 'intClubID') {
my $st = qq[
           SELECT intRealmID from tblAssoc A, tblAssoc_Clubs AC WHERE A.intAssocID = AC.intAssocID AND intClubID=$useID
        ];
        my $query = $db->prepare($st);
        $query->execute();
        ($intRealmID) = $query->fetchrow_array();
        $intEntityType = 3;

$st = qq[
           SELECT intClubID, strName, tTimeStamp, intRecStatus from tblClub WHERE intClubID=$useID
        ];
my $stACl = qq[
           SELECT intAssocClubID, AC.intClubID, A.intAssocID, A.strName, AC.tTimeStamp, AC.intRecStatus from tblAssoc_Clubs AC LEFT JOIN tblAssoc A ON (A.intAssocID=AC.intAssocID) WHERE intClubID=$useID
        ];
my $stT = qq[
           SELECT intTeamID, intClubID, intAssocID, strName, intRecStatus from tblTeam WHERE intClubID=$useID
        ];
my $stRego = qq[
		SELECT intRegoFormID, intAssocID, intClubID, intRealmID, strRegoFormName,intStatus FROM tblRegoForm WHERE intClubID=$useID
];
my $stBank = qq[SELECT * from tblBankAccount WHERE intEntityID=$useID AND intEntityTypeID=3;];

my $stPayment = qq[SELECT intApplicationID, strOrgName, strACN, strABN, strSoftDescriptor, dtCreated, intPaymentType FROM tblPaymentApplication WHERE intEntityTypeID=3 AND intEntityID=$useID];

$body .= dump_table('intClubID',$useID, $db, $st,'tblClub', 'intRecStatus');
$body .= dump_table('intClubID',$useID, $db, $stACl,'tblAssoc_Clubs', 'intRecStatus');
$body .= dump_table('intClubID',$useID, $db, $stT,'tblTeam','intRecStatus');
$body .= dump_table('',$useID, $db, $stRego,'tblRegoForm', 'intStatus');
$body .= dump_table('intAssocID',$useID, $db, $stBank,'tblBankAccount', '');
$body .= dump_table('',$useID, $db, $stPayment,'tblPaymentApplication', '');

}
elsif($type eq 'intTeamID') {

my $st = qq[
           SELECT intTeamID, intClubID, intAssocID, strName, tTimeStamp,intRecStatus from tblTeam WHERE intTeamID=$useID
        ];

my $stMT = qq[
        SELECT MT.intMemberTeamID, MT.intTeamID, MT.intMemberID, M.strFirstname, M.strSurname, MT.intCompID, AC.strTitle, AC.intNewSeasonID, MT.tTimeStamp, MT.intStatus FROM tblMember_Teams MT
INNER JOIN tblMember M ON (M.intMemberID = MT.intMemberID)
LEFT JOIN tblAssoc_Comp AC ON (MT.intCompID = AC.intCompID)
WHERE MT.intTeamID=$useID
];
my $stCT = qq[SELECT CT.intCompNO, CT.intTeamID, CT.intCompID, AC.strTitle, CT.tTimeStamp, CT.intRecStatus, CT.intHideOnLadder FROM tblComp_Teams CT
LEFT JOIN tblAssoc_Comp AC ON (CT.intCompID = AC.intCompID)
WHERE CT.intTeamID =$useID
];
my $stL = qq[select intLadderID, intCompID,intRoundID, intRoundNumber,intTeamID, strName, intResultStatus,intStatTotal1 'Played',intStatTotal2 'Won',intStatTotal3 'Lost',intStatTotal4 'Drawn' ,intStatTotal14 'Byes' ,intStatTotal5 'For' ,intStatTotal6 'Against' ,intStatTotal11 'Points',dblStatTotal1 'Percentage',strStatTotal1 'Last 5' ,dblStatTotal20 'Bonus Points' ,intStat24 'Penalty Points' from tblLadder WHERE intTeamID=$useID
];
my $stMatch = qq[Select intMatchID, intRoundID, intCompID, intAssocID, intMatchNum, strMatchName, dtMatchTime, intVenueID, intHomeTeamID, intAwayTeamID, intRecStatus, intMatchStatus 'Played', intHomeTeamResultStatus 'Home Status', intAwayTeamResultStatus 'Away Status', intWinningTeamID 'Winning ID', intTeam1FinalScore 'Home Final', intTeam2FinalScore 'Away Final'
FROM tblCompMatches
WHERE (intHomeTeamID=$useID OR intAwayTeamID=$useID) Order by dtMatchTime asc
];
$body .= dump_table('intTeamID',$useID, $db, $st, 'tblTeam','intRecStatus');
$body .= dump_table('intTeamID',$useID, $db, $stMT,' tblMember_Teams', 'intStatus');
$body .= dump_table('intTeamID',$useID, $db, $stCT,'tblComp_Teams', 'intRecStatus');
$body .= dump_table('',$useID, $db, $stMatch,'tblCompMatches', '');
$body .= dump_table('',$useID, $db, $stL,'tblLadder', '');

} 
elsif($type eq 'intTransLogID') {
my $stTrans = qq[
        SELECT TL.intLogID as intLogID, TL.strTXN, TL.strResponseCode, TL.strResponseText, TL.intAmount FROM tblTransLog TL
WHERE TL.intLogID=$useID
];

my $stMoney = qq[
        SELECT * FROM tblMoneyLog WHERE intTransLogID=$useID
];
my $stTransL = qq[
        SELECT T.intTransactionID, T.intStatus, T.intID, T.intProductID, P.strName, T.intQty, T.curPerItem, T.curAmount, T.dtTransaction, T.dtPaid, T.strNotes  FROM tblTransactions T
LEFT JOIN tblProducts P ON (P.intProductID=T.intProductID)
WHERE T.intTransLogID=$useID
];


my $stTLC = qq[
        SELECT * FROM tblTransLog_Counts WHERE intTLogID=$useID
];

my $stTXN = qq[
        SELECT * FROM tblTXNLogs WHERE intTLogID=$useID
];

$body .= dump_table('',$useID, $db, $stTrans, 'tblTransLog');
$body .= dump_table('',$useID, $db, $stTransL, 'tblTransactions');
$body .= dump_table('',$useID, $db, $stTLC, 'tblTransLog_Counts');
$body .= dump_table('',$useID, $db, $stTXN, 'tblTXNLogs');
$body .= dump_table('',$useID, $db, $stMoney, 'tblMoneyLog');

} elsif($type eq 'intRegoFormID') {

my $stRego = qq[SELECT intRegoFormID, intAssocID, intClubID, intRealmID, strRegoFormName,intStatus FROM tblRegoForm WHERE intRegoFormID=$useID];

my $stRFC = qq[SELECT * FROM tblRegoFormComps WHERE intRegoFormID=$useID];
my $stRFCo = qq[SELECT * FROM tblRegoFormConfig WHERE intRegoFormID=$useID];
my $stRFF = qq[SELECT * FROM tblRegoFormFields WHERE intRegoFormID=$useID order by intDisplayOrder];
my $stRFO = qq[SELECT * FROM tblRegoFormOrder WHERE intRegoFormID=$useID];
my $stRFP = qq[SELECT R.*, P.strName FROM tblRegoFormProducts R LEFT JOIN tblProducts P ON (P.intProductID=R.intProductID) WHERE intRegoFormID=$useID];
my $stRFR = qq[SELECT * FROM tblRegoFormRules  WHERE intRegoFormID=$useID];

my $stCustom = qq[SELECT C.* FROM tblRegoForm R INNER JOIN tblCustomFields C ON (C.intAssocID=R.intAssocID or ((C.intSubTypeID=0 or R.intSubRealmID=C.intSubTypeID) AND R.intRealmID=C.intRealmID and C.intAssocID=0)) WHERE intRegoFormID=$useID ORDER BY C.strDBFName];
$body .= dump_table('intRegoFormID',$useID, $db, $stRego, 'tblRegoForm','intStatus');
$body .= dump_table('intRegoFormID',$useID, $db, $stRFC, 'tblRegoFormComps');
$body .= dump_table('intRegoFormID',$useID, $db, $stRFCo, 'tblRegoFormConfig');
$body .= dump_table('intRegoFormID',$useID, $db, $stRFF, 'tblRegoFormFields');
$body .= dump_table('intRegoFormID',$useID, $db, $stRFP, 'tblRegoFormProducts');
$body .= dump_table('intRegoFormRuleID',$useID, $db, $stRFR, 'tblRegoFormRules','intStatus');
$body .= dump_table('',$useID, $db, $stCustom, 'tblCustomFields');

} elsif($type eq 'intProductID') {

my $stProd = qq[SELECT intProductID, strName, curDefaultAmount, dtProductExpiry, dtMemberExpiry,dtDateAvailableFrom,dtDateAvailableTo FROM tblProducts WHERE intProductID=$useID];

my $stRFP = qq[SELECT RF.intRegoFormID, RF.strRegoFormName FROM tblRegoFormProducts R INNER JOIN tblRegoForm RF ON (RF.intRegoFormID=R.intRegoFormID) WHERE R.intProductID=$useID];
my $stO = qq[SELECT intTransactionID, intTransLogID, curAmount, intQty,dtTransaction, dtPaid, tTimeStamp, intAssocID  FROM tblTransactions WHERE intProductID=$useID ORDER BY dtTransaction desc LIMIT 250];

$body .= dump_table('',$useID, $db, $stProd, 'tblProducts');
$body .= dump_table('intRegoFormID',$useID, $db, $stRFP, 'tblRegoForm');
$body .= dump_table('intTransactions',$useID, $db, $stO, 'tblTransactions (Last 250)', 1);

 
} elsif($type eq 'intMemberID') {

my $st = qq[
           SELECT intRealmID from tblMember WHERE intMemberID=$useID
        ];
        my $query = $db->prepare($st);
        $query->execute();
        my ($intRealmID) = $query->fetchrow_array();
if($intRealmID){
my $st = qq[
           SELECT intMemberID, strNationalNum, strFirstname, strSurname, dtDob, intStatus from tblMember WHERE intMemberID=$useID
        ];
my $stDupl = qq[
           SELECT * from tblDuplChanges WHERE intNewID=$useID
        ];
my $stMA = qq[
           SELECT MA.intMemberAssociationID, MA.intMemberID, MA.intAssocID, A.strName, MA.tTimeStamp, MA.intRecStatus from tblMember_Associations MA, tblAssoc A WHERE MA.intAssocID=A.intAssocID AND intMemberID=$useID
        ];
my $stMC = qq[
	SELECT intMemberClubID, intMemberID, MC.intClubID, C.strName,  MC.intPermit, MC.dtPermitStart, MC.dtPermitEnd, MC.tTimeStamp, MC.intStatus from tblMember_Clubs MC, tblClub C WHERE C.intClubID = MC.intClubID AND intMemberID=$useID        
	];
my $stMT = qq[
	SELECT MT.intMemberTeamID, MT.intMemberID, MT.intTeamID, T.strName, MT.intCompID, AC.strTitle, AC.intNewSeasonID, MT.tTimeStamp, MT.intStatus FROM tblMember_Teams MT
INNER JOIN tblTeam T ON (T.intTeamID = MT.intTeamID)
LEFT JOIN tblAssoc_Comp AC ON (MT.intCompID = AC.intCompID)
WHERE intMemberID=$useID
];
my $stMS = qq[
SELECT MS.intMemberSeasonID, MS.intMemberID, MS.intAssocID, A.strName 'Association', MS.intClubID, C.strName 'Club', MS.intSeasonID, S.strSeasonName,MS.tTimeStamp, MS.intMSRecStatus
FROM tblMember_Seasons_$intRealmID MS
LEFT JOIN tblSeasons S on (S.intSeasonID = MS.intSeasonID)
LEFT JOIN tblAssoc A on (A.intAssocID = MS.intAssocID)
LEFT JOIN tblClub C on (C.intClubID = MS.intClubID) WHERE intMemberID=$useID
        ];
my $stCMP = qq[
        SELECT count(intSPID) 'Matches Played'  FROM tblCompMatchSelectedPlayers WHERE  intMemberID=$useID
];
my $stCMPS = qq[
        SELECT count(intMatchStatID) 'Matches with Stats' FROM tblCompMatchPlayerStats WHERE intMemberID=$useID
];
my $stCL = qq[
        SELECT intClearanceID, intMemberID, intSourceAssocID,  intSourceClubID,  intDestinationAssocID, intDestinationClubID, dtApplied, dtFinalised FROM tblClearance WHERE intMemberID=$useID
];

my $stTrans = qq[
        SELECT T.intTransactionID, T.intStatus, T.intID, T.intProductID, P.strName, T.intQty, T.curPerItem, T.curAmount, T.dtTransaction, T.dtPaid, T.strNotes, T.intTransLogID as 
'intTransLogID', TL.strTXN, TL.strResponseCode, TL.strResponseText, TL.intAmount FROM tblTransactions T
LEFT JOIN tblProducts P ON (P.intProductID=T.intProductID)
LEFT JOIN tblTransLog TL ON (T.intTransLogID = TL.intLogID)
WHERE T.intTableType=1 AND T.intID=$useID
];
my $stCCO = qq[
        SELECT CCO.intMemberID, CCO.intRealmID, CCO.intAssocID, A.strName 'Assoc name', CCO.intClubID, C.strName 'Club name', CCO.intClearanceID, CCO.intCurrentSeasonID, S.strSeasonName 
FROM tblMember_ClubsClearedOut CCO
LEFT JOIN tblAssoc A ON (CCO.intAssocID = A.intAssocID)
LEFT JOIN tblClub C ON (CCO.intClubID = C.intClubID)
LEFT JOIN tblSeasons S ON (S.intSeasonID = CCO.intCurrentSeasonID)
WHERE intMemberID=$useID
];
$body .= dump_table('intMemberID',$useID, $db, $st, 'tblMember','intStatus');
$body .= dump_table('intMemberID',$useID, $db, $stMA,'tblMember_Associations','intRecStatus');
$body .= dump_table('intMemberID',$useID, $db, $stMC, 'tblMember_Clubs','intStatus');
$body .= dump_table('intMemberID',$useID, $db, $stMT,'tblMember_Teams', 'intStatus');
$body .= dump_table('intMemberID',$useID, $db, $stMS, 'tblMember_Seasons_'.$intRealmID,'intMSRecStatus');
$body .= dump_table('',$useID,$db, $stCMP, 'tblCompMatchSelectedPlayers');
$body .= dump_table('',$useID, $db, $stCMPS, 'tblCompMatchPlayerStats');
$body .= dump_table('',$useID, $db, $stCL, 'tblClearance');
$body .= dump_table('',$useID, $db, $stTrans, 'tblTransactions');
$body .= dump_table('',$useID, $db, $stDupl, 'tblDuplChanges');
$body .= dump_table('',$useID, $db, $stCCO, 'tblMember_ClubsClearedOut');
}
}
if($intRealmID and $intEntityType>2)
{
$body .=dump_table('',$useID,$db,qq[select * from tblSnapShotEntityCounts_$intRealmID WHERE intEntityID=$useID and intEntityTypeID=$intEntityType order by intYear desc, intMonth desc],qq[tblSnapShotEntityCounts_$intRealmID]);
$body .=dump_table('',$useID,$db,qq[select M.*,A.strAgeGroupDesc, case when intGender=1 then 'Male' when intGender=2 then 'Female' else 'Unknown' end as strGender  from tblSnapShotMemberCounts_$intRealmID M LEFT JOIN tblAgeGroups A ON (A.intAgeGroupID=M.intAgeGroupID) WHERE intEntityID=$useID and intEntityTypeID=$intEntityType order by intYear desc, intMonth desc],qq[tblSnapShotMemberCounts_$intRealmID]);
}
$body .= qq[
<script type="text/javascript">
<!--
function updateTS(string) {
	var answer = confirm("Update Timestamp to Now?")
	if (answer){
	window.location = "?action=DATA_TS&"+string;	
	}
}
//-->
</script>]; 

my $box='';
#	$body = $mainBody.'<div style="float:right;padding:5px;border:1px solid #5F6062;background-color:silver;">'.$box."</div>".$body;
	$body = $mainBody.$body;
       return $body;
}

sub item_set_delete
{
	my($db)=@_;
	my $intDeleteID = param("deleteID") || '';
	my $table = param("table") || '';
	my $key = param("key") || '';
	my $keyfield = param("keyfield") || '';
	my $field = param("field") || '';
	my $value = param("value") || '';
	my $matchingfield = param("matchField") || '';
	if($value ne '' and $field ne '' and $key ne '' and $table ne '' and $keyfield ne '' and $intDeleteID ne '')
	{
		my $st = qq[
           		UPDATE $table SET $field = $value WHERE $matchingfield = $intDeleteID AND $keyfield = $key LIMIT 1;
        		];
  		my $query = $db->prepare($st);
        	$query->execute();
	}
	return ($intDeleteID, $matchingfield);
}
sub fieldPermCheck
{
  my($db)=@_;
        my $body ='';
        my $intAssocID = param("intAssocID") || '';
        my $strFieldName = param("strFieldName") || '';
        my $intRegoFormID = param("intRegoForm") || '';
	my $intRealmID = dlookup($db,'intRealmID','tblAssoc',qq[intAssocID=$intAssocID]);
	$body = qq[<table style="margin-left:auto;margin-right:auto;">
<tr><td class="formbg"><h2> Field Permissions Check $strFieldName in $intAssocID</h2>
<p align=right>Return to <a href="?action=DATA&type=intRegoFormID&useID=$intRegoFormID">Rego Form</a></p>];
 my $stFPerm = qq[
SELECT
			tblFieldPermissions.intRealmID,
                             intSubRealmID,
                             intEntityTypeID,
                             intEntityID,
                             strFieldType,

                             strFieldName,

                             strPermission,
                             intRoleID
                     FROM
                             tblFieldPermissions

LEFT JOIN tblTempNodeStructure TNS on (TNS.intAssocID=$intAssocID)

                     WHERE
                             tblFieldPermissions.intRealmID = $intRealmID
                             AND (
                                     (
                                             intEntityTypeID = 0
                                             AND intEntityID = 0
                                     )
                                     OR
                                     (

                                             intEntityTypeID = 5

                                             AND intEntityID = $intAssocID
                                     )

                                     OR
                                     (
                                             intEntityTypeID = 100
                                             AND intEntityID = TNS.int100_ID
                                     )

                                     OR
                                     (
                                             intEntityTypeID = 30
                                             AND intEntityID = TNS.int30_ID
                                     )

                                     OR
                                     (
                                             intEntityTypeID = 20 AND intEntityID = TNS.int20_ID
                                     )

                                     OR
                                     (
                                             intEntityTypeID = 10
                                             AND intEntityID = TNS.int10_ID
                                    )

                            )
				AND strFieldName='$strFieldName'
                            AND intRoleID IN (0,0)
                    ORDER BY strFieldType, strFieldName, intEntityTypeID desc, intRoleID DESC
];
$body .= dump_table('',$intRegoFormID,$db,$stFPerm,'tblFieldPermissions','');
$body .= qq[</td></tr></table>];
}
sub item_set_edit
{
	my($db)=@_;
        my $body ='';
	my $table = param("table") || '';
	my $type = param("type") || '';
        my $useID = param("useID") || '';

	my @primary_keys = get_primary_keys($db,$table);
	my $keyCount =scalar grep { defined $_ } @primary_keys;
	my $where = '';
	my $whereCount=0;
	foreach my $name (@primary_keys)
	{
	if($whereCount>0){ $where .= qq[ AND ];}
	my 	$val = param($name);
			if($val ne '')
			{
				$where .= qq[ `$name` = "$val" ];
				$whereCount++;
			}
	}
	


	
	my $query = $db->prepare(qq[SELECT * from $table WHERE $where LIMIT 1;]);
        if($whereCount!=$keyCount) { return $body = qq[SELECT * from $table WHERE $where LIMIT 1;<br />Sorry, invalid SQL]}
	$query->execute();
	while (my(@row) = $query->fetchrow_array)
        {
	$body .=qq[<table border=1 width='60%' style='border:5px solid #1376B0;margin:10px;margin-left:auto;margin-right:auto;'>
	<tr><td colspan=2 align='center' style="background-color:#1376B0"><h1 style="display:inline;">Table: $table ($where)</td></tr>
<form name="" action="" enctype="multipart/form-data" method="post">];
	my $count=0;
	 foreach my $val (@row) {
         my $showval = $val;
	my $fieldname = $query->{NAME}[$count];
	if((grep /$fieldname/, @primary_keys or $fieldname eq 'intRealmID') and 1==2) {
	 $body .=qq[\n<tr><td><b>$query->{NAME}[$count]</b></td><td>$showval<input type="hidden" value="$showval" name="f_$fieldname"></td></tr>];
	 }elsif(grep /$fieldname/, @primary_keys or $fieldname eq 'intRealmID') {
	$body .=qq[\n<tr><td style='background-color:red;color:white;'><b>$query->{NAME}[$count]</b></td><td style='background-color:red;color:white;'><input type="text" value="$showval" style='background-color:red;color:white' name="f_$fieldname"></td></tr>];
	$body .=qq[\n<input type="hidden" value="$showval" name="f_pk_$fieldname">];
	} elsif(length($showval)>25){
	 $body .=qq[\n<tr><td><b>$query->{NAME}[$count]</b></td><td><textarea name="f_$fieldname" rows=5 cols=30>$showval</textarea></td></tr>];
	} else {
	$body .=qq[\n<tr><td><b>$query->{NAME}[$count]</b></td><td><input type="text" value="$showval" name="f_$fieldname"></td></tr>];
	}

$count++;	}
	$body .= qq[<tr><td colspan=2 align='center'>
<input type="submit" name="submit" value="Update">
<input type="submit" name="submit2" value="COPY TO NEW RECORD">
<input type="hidden" name="type" value="$type">
<input type="hidden" name="useID" value="$useID">
<input type="hidden" name="action" value="DATA_UPDATE">
<input type="hidden" name="table" value="$table">
</form></td></tr></table>];
}
return $body;
}

sub item_set_update
{
	my($db)=@_;
        my $body ='';
        my $table = param("table") || '';
	my $useID = param("useID") || '';
        my $type = param("type") || '';
	my $submit = param("submit2") || '';

	my $st = qq[UPDATE $table SET ];
	if($submit eq 'COPY TO NEW RECORD') {
		$st = qq[INSERT INTO $table SET];
	}
	my $where=qq[];
	my	$count=0;
	my $whereCount=0;
  	my $query = $db->prepare(qq[SELECT * from $table LIMIT 1;]);
	$query->execute();
	my @primary_keys = get_primary_keys($db,$table);
	my @whereBind = ();
	my @bind = ();
	foreach my $field (@{$query->{NAME}}) 
	{
		my $value = param("f_$field");
		my $valuePK = param("f_pk_$field");
		if(grep /$field/, @primary_keys) {
			if($whereCount>0) { $where .= qq[ AND ];}
			$where .=qq[`$field` = ?];
			$whereCount++;
			push @whereBind, $valuePK;
		}

			if($count>0) { $st .= qq[, ];}
			$st .=qq[`$field` = ?];
			push @bind, $value;
			$count++;
	}
	if($count>0 and $whereCount>0)
	{
		if($submit eq '') {
			$st .= qq[ WHERE $where LIMIT 1;];
		my $query2 = $db->prepare($st);
        	$query2->execute(@bind,@whereBind);
		}else {
		my $query2 = $db->prepare($st);
        	$query2->execute(@bind);
		}
	}
	return ($useID,$type);
}
		
sub dump_table
{
  	my($matchingfield,$memberID, $db, $sql,$sqltable,$field,$hidelimit)=@_;
        $field ||='';
    $sql = $sql." LIMIT 10000" if($hidelimit!=1);
	my $query = $db->prepare($sql);
	$query->execute();
	my $type = param("type") || '';
	my $useID = param("useID") || '';
	my $table = "<table id='$sqltable' border=1 width='80%' style='border:5px solid #1376B0;margin:10px;margin-left:auto;margin-right:auto;'>\n";
	$table .='<tr><td style="background-color:#1376B0;color:white;font-size:16" colspan=99><a name="$sqltable">&nbsp;</a><a href="?action=DATA&type=intTableData&useID='.$sqltable.'" style="color:white;">'.$sqltable."</a></td></tr><tr>";
	my @primary_keys = get_primary_keys($db,$sqltable);
	my $intAssocID=0;
	if($sqltable eq 'tblRegoFormFields'){$intAssocID = dlookup($db,'intAssocID','tblRegoForm',qq[intRegoFormID=$memberID]); }
	my $count = 0;
	my $keyfield = '';
	my $checkfield = 0;
	my @fieldnames;
		foreach my $value (@{$query->{NAME}}) {
			$value ||='';
			push(@fieldnames, $value);
			if($count==0){$keyfield = $value;}
			$table .= '<td style="background-color:#1376B0;color:white;">'.$value."</td>";
			if($field eq $value){$checkfield = $count;}
			$count++;
		}
	$table .="</td><td style='background-color:#1376B0;color:white;'>Edit?</td>";
	$table .= "<td style='background-color:#1376B0;color:white;'>Delete?</td>\n" if($field ne '' and check_access('','levelonly')>=95);
	my $rows=0;
	$table .="</tr>";
	while (my(@row) = $query->fetchrow_array)
	{
		$rows++;
	my $edit_string = '';
	my $edit_string_js = '';
	my $primary_count=0;   $table .= "  <tr>\n";
		my $switchvalue =-1;
		my $colstyle='style="background-color:white"';
		if($row[$checkfield]<0){$switchvalue=1;$colstyle = 'style="color:white;background-color:red"';}
		elsif($row[$checkfield]<=0){$switchvalue=1;$colstyle = 'style="color:white;background-color:yellow;color:black;"';}
	        my $count=0;
		foreach my $val (@row) {
		$val = defined($val) ? $val : '';
		my $showval = defined($val) ? $val : '';
		my $currentField = $fieldnames[$count];
			if($currentField eq 'strSetup' or $currentField eq 'strResults') { 

			#	my $tc = '';
			#	use XML::Simple();
				#my $data = XML::Simple($showval);
				$showval = "<pre>".encode_entities($showval)."</pre>";
				#use Data::Dumper;
				#$showval = Dumper($data);
				#$showval = qq[<pre>$showval</pre>];
			 }		
		my $keyCount =scalar grep { defined $_ } @primary_keys;
		if(grep /$currentField/, @primary_keys) {$primary_count++;$edit_string .=qq[&$currentField=$val];}
		if($val ne 0 and $val ne -1) {
		if($sqltable eq 'tables') {
			$showval = qq[<a href="?action=DATA&type=intTableData&useID=$val">$val</a>]; 
		}
		if($sqltable eq 'tblRegoFormFields' and $currentField eq 'strFieldName') {
			$showval = qq[<a href="?action=DATA_FIELDCHECK&strFieldName=$val&intRegoForm=$memberID&intAssocID=$intAssocID">$val</a>]; 
		}


		if($primary_count==$keyCount and $keyCount>0 and $fieldnames[$count] eq "tTimeStamp") {
			$showval = qq[<a href='#' onclick="updateTS('type=$type&useID=$useID&table=$sqltable$edit_string')">$val</a>]; 
		}
		if($fieldnames[$count] eq "intProductID") {
			$showval = qq[<a href="?action=DATA&type=intProductID&useID=$val">$val</a>]; 
		}
		if($fieldnames[$count] eq "intRegoFormID") {
			$showval = qq[<a href="?action=DATA&type=intRegoFormID&useID=$val">$val</a>]; 
		}
		if($fieldnames[$count] eq "intNodeID") {
			$showval = qq[<a href="?action=DATA&type=intNodeID&useID=$val">$val</a>]; 
		}
		if($fieldnames[$count] eq "intRealmID") {
			$showval = qq[<a href="?action=DATA&type=intRealmID&useID=$val">$val</a>]; 
		}
		if($fieldnames[$count] eq "intMatchID") {
			$showval = qq[<a href="?action=DATA&type=intMatchID&useID=$val">$val</a>]; 
		}
		if($fieldnames[$count] eq "intAssocID") {
			$showval = qq[<a href="?action=DATA&type=intAssocID&useID=$val">$val</a>]; 
		}
		 if($fieldnames[$count] eq "intMemberID") {
                        $showval = qq[<a href="?action=DATA&type=intMemberID&useID=$val">$val</a>];
                }
		 if($fieldnames[$count] eq "intTeamID" or $fieldnames[$count] eq 'intHomeTeamID' or $fieldnames[$count] eq 'intAwayTeamID' or $fieldnames[$count] eq 'Winning ID') {
                        $showval = qq[<a href="?action=DATA&type=intTeamID&useID=$val">$val</a>];
                }
		 if($fieldnames[$count] eq "intCompID") {
                        $showval = qq[<a href="?action=DATA&type=intCompID&useID=$val">$val</a>];
                }
		 if($fieldnames[$count] eq "intTransLogID") {
                        $showval = qq[<a href="?action=DATA&type=intTransLogID&useID=$val">$val</a>];
                }
		 if($fieldnames[$count] eq "intClubID") {
                        $showval = qq[<a href="?action=DATA&type=intClubID&useID=$val">$val</a>];
                }
		}

	   $table .= qq[<td $colstyle valign='top'>$showval</td>\n];
	
	    $count++;     }
  if((check_access('','levelonly')>=95)) {
		my $keyCount =scalar grep { defined $_ } @primary_keys;
if($primary_count==$keyCount and $keyCount>0){ $table .= qq[<td width='100px' $colstyle><a href="?action=DATA_EDIT&type=$type&useID=$useID&$edit_string&table=$sqltable">[EDIT]</a></td>];}else{$table .="<td> &nbsp; </td>";}
if($matchingfield ne '' and $field ne ''){ $table .= qq[<td width='100px' $colstyle><a href="?action=DATA_DELETE&matchField=$matchingfield&deleteID=$memberID&value=$switchvalue&table=$sqltable&key=$row[0]&keyfield=$keyfield&field=$field">[DELETE]</a></td> </tr>\n];
        }}}
         $table .= "<tr><td colspan=".($count+2)." style='background-color:#1376B0;color:white;' align='right'><i>$rows rows returned</i></td></tr></table>\n";
	
	$table .= qq[<p align="right" style="padding-right:10%" width="80%"><input value='Export Above CSV' type='button' onclick="\$('#$sqltable').table2CSV()"></p>];
#	$box .= "<li style='float:right;'><a href='#sqltable'>$sqltable</a></li>";

return ($table);
}

sub timestamp_now
{
        my($db)=@_;
        my $body ='';
        my $table = param("table") || '';

        my $st = qq[UPDATE $table SET tTimeStamp=NOW() ];
        my $where=qq[];
        my $whereCount=0;
        my @primary_keys = get_primary_keys($db,$table);
	my $keyCount =scalar grep { defined $_ } @primary_keys;        
	foreach my $field (@primary_keys)
        {
                my $value = param("$field");
                if(grep /$field/, @primary_keys) {
                        if($whereCount>0) { $where .= qq[ AND ];}
                        $where .=qq[`$field` = "$value"];
                        $whereCount++;
                }
        }
	if($whereCount!=$keyCount) { return $body = qq[Sorry, ALL PRIMARY KEYS WERE NOT ACCOUNTED FOR];}        
	if( $whereCount>0)
        {
                $st .= qq[ WHERE $where LIMIT 1;];
                my $query2 = $db->prepare($st);
                $query2->execute();
        }
}
sub get_primary_keys
{
  	my($db,$table)=@_;
	my $st= qq[SHOW KEYS FROM $table WHERE Key_name='PRIMARY'];
	my $query = $db->prepare($st);
        my @primary = ();
	$query->execute();
	while(my $dref= $query->fetchrow_hashref()) {
    		foreach my $key (keys %{$dref}) { if(!defined $dref->{$key})  {$dref->{$key}='';} }
		push(@primary, $dref->{Column_name});
	}
	return @primary;
}
sub dlookup
{
	my($db,$field,$table,$where)=@_;
	my $st = qq[SELECT $field from $table WHERE $where];
        my $query = $db->prepare($st);
        $query->execute();
        return $query->fetchrow_array() || '';
}
sub data_publish
{
	my($db)=@_;
	my %Data = ();
	$Data{'db'} = $db;
        my $assocID = param("intAssocID");
        my $matchID = param("intMatchID");
        my $type = param("type") || 50;
	my $body = '';
	if($matchID) {
 		my $st =qq[
		    INSERT IGNORE INTO tblCompProcessLog (
		      intAssocID,
		      intTypeID,
		      intID,
		      dtAdded,
		      intStatus,
		      strProcessName
		    )
		    VALUES (
		      ?,
		      ?,
		      ?,
		      NOW(),
		      1,
		      "Courtside Match Update"
    			)
		];
		my $query = $db->prepare($st);
                $query->execute($assocID, $type, $matchID);


	        $body =  (qq[<div class="OKmsg"><b>Match $matchID</b> has been added to the <b>Process Log</b>. 
		<a href="?action=DATA&type=intMatchID&useID=$matchID">Return to Match Info Page</a></div>]);
	} else {
		my %args = ('DB'=>$Data{'db'});
        	my $pl = new ProcessLog(%args);
        	$pl->write($Defs::PROCESSLOG_SWW_UPLOAD,$assocID);
	        $body =  (qq[<div class="OKmsg"><b>Publish to web</b> has been added to the <b>Process Log</b>. 
		<a href="?action=DATA&type=intAssocID&useID=$assocID">Return to Assoc Info Page</a></div>]);
	}
	return $body;
}

sub str_replace {
    my ($search, $replace, $subject) = @_;
    my $pos = index($subject, $search);
    while($pos > -1) {
        substr($subject, $pos, length($search), $replace);
        $pos = index($subject, $search, $pos + length($replace));
    }
    return $subject;
}
