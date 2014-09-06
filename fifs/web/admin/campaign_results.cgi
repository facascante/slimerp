#!/usr/bin/perl -w

#
# $Header: svn://svn/SWM/trunk/web/admin/campaign_results.cgi 8530 2013-05-22 05:57:47Z cgao $
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

use HTTP::Request::Common qw(POST);
use LWP::UserAgent;
use DeQuote;
use PaymentSplitMoneyLog;
use Payments;



main();

sub main    {
	my $db    = connectDB();

	my $a= param('a') || 'LIST';
	my $r= param('r') || '';
    my $campaign_id = '';
    
    if (param('cID') and param('cID') =~/^\d+$/) { 
        $campaign_id = param('cID');
    }

	my $body = listresults($db, $r, $campaign_id);
	disconnectDB($db) if $db;

    print_adminpageGen($body, "", "");
}

sub listresults	{

    my ($db, $r, $campaign_id) = @_ ;

    my $where = '';
    if ($campaign_id) {
        $where = qq[WHERE intCampaignID = $campaign_id];
    }
    
	my $st1 = qq[
                 SELECT 
                     intCampaignStatus, COUNT(*) as COUNTNUM 
                 FROM 
                     tblMember_Campaigns 
                 $where
                 GROUP BY intCampaignStatus
	];
        
	my $query = $db->prepare($st1);
	$query->execute;
	my $body .= qq[
		<p><b>OVERALL COUNTS:</b></p>
	];
	while (my $dref =$query->fetchrow_hashref())	{
		my $status = 'YES';
		$status = 'NO' if $dref->{intCampaignStatus} == 0;
		$body .= qq[<p>$status $dref->{COUNTNUM}</p>];
	}
	
	my $rWHERE = '';
	my $rFILTER='';

	if ($r eq 'N')	{
		$rWHERE = qq[ WHERE intCampaignStatus=0 ];
        $rFILTER = qq[<p><b>FILTERED BY RESPONSE = NO</b></p>];
	}
	elsif ($r eq 'Y')	{
		$rWHERE = qq[ WHERE intCampaignStatus=1 ];
		$rFILTER = qq[<p><b>FILTERED BY RESPONSE = YES</b></p>];
	}
    
    if ($campaign_id) {
        if ($r) {
            $rWHERE .= qq[ AND MC.intCampaignID = $campaign_id];
        }
        else {
            $rWHERE = qq[ WHERE MC.intCampaignID = $campaign_id];
        }
    } 

    
    my $st = qq[
	SELECT DISTINCT strSubTypeName, strRealmName, strName, intPermissionStatus, COUNT(MC.intMemberID) as COUNTNUM FROM tblMember_Campaigns as MC LEFT JOIN tblCampaignPermissions as CP USING (intAssocID) INNER JOIN tblAssoc as A ON (A.intAssocID=MC.intAssocID) INNER JOIN tblRealms as R ON (R.intRealmID=A.intRealmID) LEFT JOIN tblRealmSubTypes as RS ON (RS.intSubTypeID = intAssocTypeID) $rWHERE GROUP BY A.intAssocID ORDER BY strRealmName, A.strName
     ];
           
	$query = $db->prepare($st);
	$query->execute;

    my $count=0;
    $body .= qq[
	$rFILTER
        <table width="90%" class="listtable">
            <tr>
                <th>Realm</td>
                <th>Realm SubType</td>
                <th>Association</td>
                <th>Show Campaign</td>
                <th>Number Responses</td>
            </tr>
    ];
	while (my $dref =$query->fetchrow_hashref())	{
    	my $permission = ($dref->{'intPermissionStatus'}==1) ? 'Yes' : 'No';
    	$body .= qq[
            <tr>
                <td>$dref->{strRealmName}</td>
                <td>$dref->{strSubTypeName}</td>
                <td>$dref->{strName}</td>
                <td>$permission</td>
                <td>$dref->{COUNTNUM}</td>
            </tr>
        ];
        $count++;
    }

    $body .= qq[</table>];

    return $body;

}
1;
