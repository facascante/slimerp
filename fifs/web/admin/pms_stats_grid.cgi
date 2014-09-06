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

main();

sub main    {
	my $db    = connectDB();

	my $realm= param('realm') || 0;
	my $sr= param('sr') || 0;
	my $pt= param('pt') || 0;
	my $dtFrom= param('dtFrom') || '';
	my $dtTo= param('dtTo') || '';
	my $tFrom= param('tFrom') || '';
	my $tTo= param('tTo') || '';
	my $body = runPMSReport($db, $realm, $dtFrom, $dtTo, $tFrom, $tTo, $sr,$pt);
	disconnectDB($db) if $db;

    	print_adminpageGen($body, "", "");
}


sub runPMSReport	{

	my ($db, $realm, $dtFrom, $dtTo, $tFrom, $tTo, $sr, $pt) = @_;

	$realm ||= 0;
	$pt||=0;

$sr||=0;
$tTo = qq[23:59:59] if ($dtFrom eq $dtTo and ! $tTo);
	my $subrealmWHERE = ($sr) 
		? qq[ AND ML.intRealmSubTypeID= $sr]
		: '';
	my $realmWHERE = ($realm) 
		? qq[ AND ML.intRealmID = $realm]
		: '';


	$tFrom = qq[ $tFrom] if ($tFrom);
	my $dtFromWHERE = ($dtFrom) 
		? qq[ AND TL.dtLog >= "$dtFrom$tFrom"]
		: '';
		#? qq[ AND ML.dtEntered >= "$dtFrom$tFrom"]

	$tTo = qq[ $tTo] if ($tTo);
	my $dtToWHERE = ($dtTo) 
		? qq[ AND TL.dtLog <= "$dtTo$tTo"]
		: '';

	my $ptWHERE = ($pt) 
		? qq[ AND TL.intPaymentType=$pt]
		: '';

	my $st = qq[
		SELECT 
			strRealmName, 
			strSubTypeName, 
			A.strName as AssocName, 
			C.strName as ClubName, 
			ML.strCurrencyCode as CurrencyCode,
			COUNT(DISTINCT intTransLogID) as countTrans, 
			SUM(curMoney) as sumMoney
		FROM 
			tblMoneyLog as ML 
			INNER JOIN tblTransLog as TL ON (
				TL.intLogID=ML.intTransLogID
			) 
			INNER JOIN tblAssoc as A ON (
				A.intAssocID=ML.intAssocID
			) 
			INNER JOIN tblRealms as R ON (
				R.intRealmID=ML.intRealmID
			) 
			LEFT JOIN tblRealmSubTypes as RS ON (
				RS.intSubTypeID=ML.intRealmSubTypeID
			) 
			LEFT JOIN tblClub as C ON (
				C.intClubID=ML.intClubID
			) 
		WHERE 
			ML.intLogType IN (1,4,6) 
			AND TL.intAmount>0
			AND TL.intStatus=1
			$realmWHERE
			$subrealmWHERE
			$dtFromWHERE
			$dtToWHERE
			$ptWHERE
		GROUP BY 
			ML.intRealmID, 
			ML.intRealmSubTypeID, 
			ML.intAssocID, 
			ML.intClubID,
			ML.strCurrencyCode

	];

	my $body = qq[
	];

	my $query = $db->prepare($st);
	$query->execute;


	my $countTrans=0;
	my $sumMoney=0;
	my $count=0;
 my @rowdata =();

	while (my $dref =$query->fetchrow_hashref())	{
  push @rowdata ,{
            id => $count,
            realm => $dref->{'strRealmName'},
            subrealm => $dref->{'strSubTypeName'},
            assoc => $dref->{'AssocName'},
            club => $dref->{'ClubName'},
            count => $dref->{'countTrans'},
            amount => $dref->{'sumMoney'},
            currency => $dref->{'CurrencyCode'},
        };
		$countTrans += $dref->{'countTrans'};
		$sumMoney += $dref->{'sumMoney'};
		$count++;
	}

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
            name => "Association",
            field => "assoc",
        },
        {
            name => "Club",
            field => "club",
        },
        {
            name => "Count",
            field => "count",
            sorttype=>"number",
        },
        {
            name => "Amount",
            field => "amount",
            sorttype=>"number",
	},
        {
            name => "Currency",
            field => "currency",
        },
	);
 my $filterfields = [];
my $Data ={};
	$body .= qq[<p>Number of Entities: $count</p>];
	$body .= qq[<p>Total Number: $countTrans</p>];
	$body .= qq[<p>Total Money: \$$sumMoney</p>];
my $grid .= showGrid (
        Data =>$Data,
        columns => \@headers,
        rowdata=> \@rowdata,
        gridid=>'grid',
        width => 1400,
        height => 1100,
        simple=>0,
        filters => $filterfields,
        font_size => "1.2em"
    );
    $body .= qq[
        <div class="_grid-filter-wrap">
            $grid
        </div>
    ];




	return $body;


}
1;
