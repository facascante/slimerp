#!/usr/bin/perl -w

#
# $Header: svn://svn/SWM/trunk/web/admin/pms_stats.cgi 8530 2013-05-22 05:57:47Z cgao $
#

use strict;
use lib "../..","..",".";
use DBI;
use CGI qw(param unescape escape);
use Defs;
use Utils;
use Defs;
use Date::Calc qw(Today);
use ExportEmailData;
use AdminPageGen;
use GridDisplayAdmin;
use FormHelpers;
main();

sub main    {
	my $db    = connectDB();

	my $realm= param('realm') || 0;
	my $sr= param('sr') || 0;
	my $type= param('type') || 0;
	my $pt= param('pt') || 0;
	my $dtFrom= param('dtFrom') || '';
	my $dtTo= param('dtTo') || '';
	my $tFrom= param('tFrom') || '';
	my $tTo= param('tTo') || '';
	my $gby= param('groupby') || '';
	my $body = runPMSReport($db, $type, $realm, $dtFrom, $dtTo, $tFrom, $tTo, $sr,$pt, $gby);
	disconnectDB($db) if $db;

    	print_adminpageGen($body, "", "");
}


sub runPMSReport	{

	my ($db, $type, $realm, $dtFrom, $dtTo, $tFrom, $tTo, $sr, $pt, $gby) = @_;

	$realm ||= 0;
	$pt||=0;

$sr||=0;
$tTo = qq[23:59:59] if ($dtFrom eq $dtTo and ! $tTo);
	my $typeWHERE = ($type) 
		? qq[ AND MS.intClubID =0]
		: qq[ AND MS.intClubID >0];
	my $subrealmWHERE = ($sr) 
		? qq[ AND A.intAssocTypeID= $sr]
		: '';
	$tFrom = qq[ $tFrom] if ($tFrom);
	my $dtFromWHERE = ($dtFrom) 
		? qq[ AND MS.dtLastUsedRegoForm >= "$dtFrom$tFrom"]
		: '';
		#? qq[ AND ML.dtEntered >= "$dtFrom$tFrom"]

	$tTo = qq[ $tTo] if ($tTo);
	my $dtToWHERE = ($dtTo) 
		? qq[ AND MS.dtLastUsedRegoForm <= "$dtTo$tTo"]
		: '';
my @headers =(
        {
            name  => 'Realm',
            field => 'realm',
        },
        {
            name  => 'SubRealm',
            field => 'subrealm',
        },
        {
            name => "AssocID",
            field => "associd",
        },
        {
            name => "Association",
            field => "assoc",
        },
        {
            name => "Assoc State",
            field => "astate",
        },
        {
            name => "ClubID",
            field => "clubid",
        },
        {
            name => "Club",
            field => "club",
        },
        {
            name => "RegoForm",
            field => "regoform",
        },
        {
            name => "Season",
            field => "season",
        },
        {
            name => "Registered",
            field => "count",
            sorttype=>"number",
	},
        {
            name => "Paid",
            field => "pay",
            sorttype=>"number",
	},
        {
            name => "%",
            field => "percent",
            sorttype=>"number",
	},
	);
my $groupby = "R.intRegoFormID, MS.intAssocID, MS.intClubID, S.intSeasonID";
if($gby eq 'club'){
$groupby = "MS.intClubID, MS.intAssocID";
delete $headers[4];
delete $headers[5];
}elsif($gby eq 'all') {
$groupby = "R.intRegoFormID, MS.intAssocID, MS.intClubID, S.intSeasonID";
}elsif($gby eq 'regoform') {
$groupby = "R.intRegoFormID, MS.intAssocID, MS.intClubID";
delete $headers[5];
}elsif($gby eq 'season') {
$groupby = "MS.intAssocID, MS.intClubID, S.intSeasonID";
delete $headers[4];
}
	my $st = qq[
			
select SR.strSubTypeName, Re.strRealmName, A.strState AState, A.intAssocID, A.strName AssocName, C.intClubID, C.strName ClubName, count(DISTINCT Mcheck.intMemberID) countMem, count(DISTINCT M.intMemberID) countPay, R.intRegoFormID, R.strRegoFormName, S.intSeasonID, S.strSeasonName
FROM tblMember_Seasons_$realm MS
LEFT JOIN tblAssoc A ON MS.intAssocID=A.intAssocID
INNER JOIN tblMember Mcheck ON Mcheck.intMemberID = MS.intMemberID AND Mcheck.intStatus IN (1,0)
LEFT JOIN tblRealms Re ON Re.intRealmID=A.intRealmID
LEFT JOIN tblRealmSubTypes SR ON SR.intSubTypeID=A.intAssocTypeID
LEFT JOIN tblClub C ON MS.intClubID = C.intClubID
INNER JOIN tblRegoForm R ON MS.intUsedRegoFormID = R.intRegoFormID 
LEFT JOIN tblRegoFormProducts RP ON RP.intRegoFormID = R.intRegoFormID 
LEFT JOIN tblTransactions T ON RP.intProductID = T.intProductID and MS.intMemberID=T.intID and T.intTableType=1 AND dtPaid>'2000-01-01'
LEFT JOIN tblTransLog TL ON TL.intLogID = T.intTransLogID AND TL.intPaymentType=13
LEFT JOIN tblTransactions T2 ON TL.intLogID = T2.intTransLogID
LEFT JOIN tblMember M ON M.intMemberID = T2.intID and T2.intTableType=1  AND M.intStatus IN (1,0) 
INNER JOIN tblSeasons S ON S.intSeasonID = MS.intSeasonID
WHERE MS.intUsedRegoForm>0
			$dtFromWHERE
			$typeWHERE
			$dtToWHERE
			$subrealmWHERE
GROUP BY $groupby

	];
#LEFT JOIN tblTransLog TL ON TL.intLogID = T.intTransLogID AND TL.intPaymentType=13
#LEFT JOIN tblMoneyLog ML ON TL.intLogID = ML.intTransLogID and ML.intClubID = C.intClubID
#LEFT JOIN tblTransactions T2 ON ML.intTransLogID = T2.intTransLogID
 my $stR=qq[ SELECT intRealmID, strRealmName FROM tblRealms ORDER BY strRealmName];
        my $realms=getDBdrop_down('realm',$db,$stR,$realm,'&nbsp;') || '';
my $selected_assoc = '';
$selected_assoc = ' selected ' if($type);

	my $body = qq[<form name="" action="" method="get">

<p>Realm: $realms</p>
<p>Date From: <input type="text" value="$dtFrom" name="dtFrom"></p>
<p>Date To: <input type="text" value="$dtTo" name="dtTo"></p>
<p>Group By: <select name="groupby">
<option value="$gby">$gby (Current)</option>
<option value="club">Assoc, Club</option>
<option value="regoform">Assoc, Club, RegoForm</option>
<option value="season">Assoc, Club, Season</option>
<option value="all">Assoc, Club, RegoForm, Season</option>

</select></p>
<p>Type: <select name="type">
<option value="">Club</option>
<option value="assoc" $selected_assoc >Assoc</option>
</select></p>
<input type="submit" value="Resubmit">
</form>
	];
	my $query = $db->prepare($st);
	$query->execute;


	my $countMem=0;
	my $countMemP=0;
	my $count=0;
 my @rowdata =();

	while (my $dref =$query->fetchrow_hashref())	{
  push @rowdata ,{
            id => $count,
            realm => $dref->{'strRealmName'},
            subrealm => $dref->{'strSubTypeName'},
            associd => $dref->{'intAssocID'},
            astate => $dref->{'AState'},
            assoc => $dref->{'AssocName'},
            season => $dref->{'strSeasonName'},
            clubid => $dref->{'intClubID'},
            club => $dref->{'ClubName'},
            regoform => $dref->{'strRegoFormName'},
            count => $dref->{'countMem'},
            pay => $dref->{'countPay'},
            percent => sprintf("%.4f",$dref->{'countPay'}/$dref->{'countMem'})*100,
        };
		$countMem += $dref->{'countMem'};
		$countMemP += $dref->{'countPay'};
		$count++;
	}


 my $filterfields = [];
my $Data ={};
	$body .= qq[<p>Number of Members Registered: $countMem</p>];
	$body .= qq[<p>Number of Members Paid: $countMemP</p>];
	$body .= qq[<p>Percent Paid ].sprintf("%.2f",$countMemP/$countMem*100).qq[%</p>];






my $grid .= showGrid (
        Data =>$Data,
        columns => \@headers,
        rowdata=> \@rowdata,
        gridid=>'grid',
        width => 1400,
        height => 1100,
        simple=>1,
        filters => $filterfields,
        font_size => "1.2em",
    );
    $body .= qq[
        <div class="_grid-filter-wrap">
            $grid
        </div>
    ];




	return $body;


}
1;
