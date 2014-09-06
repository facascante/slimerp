#!/usr/bin/perl -w

#
# $Header: svn://svn/SWM/trunk/web/admin/supportyoursport_members.cgi 10208 2013-12-10 00:34:50Z tcourt $
#

use strict;
use lib "../..","..",".";
use DBI;
use CGI qw(param unescape escape);
use Defs;
use Utils;
use AdminPageGen;

main();

sub main {
    my $dbh = connectDB();

    my ($campaign_id, $date_from, $date_from2, $date_to, $date_to2) = validate_params();

    my $body = ($campaign_id)
        ? show_results($dbh, $campaign_id, $date_from, $date_from2, $date_to, $date_to2)
        : show_param_instructions();

    disconnectDB($dbh) if $dbh;

    print_adminpageGen($body, "", "");
}

sub validate_params {
    my $campaign_id = param('cid') || 0;
    if ($campaign_id) {
        $campaign_id = 0 if ($campaign_id != $Defs::CAMPAIGN_SYS_REBEL and $campaign_id != $Defs::CAMPAIGN_SYS_AMART)
    }

    my $date_from  = param('datefrom') || '';
    my $date_to    = param('dateto')   || '';
    my $date_from2 = '';
    my $date_to2   = '';
    my $success    = 0;

    if ($date_from) {
        ($success, $date_from2) = check_date($date_from);
        $campaign_id = 0 if !$success;
    }

    if ($date_to) {
        ($success, $date_to2) = check_date($date_to);
        $campaign_id = 0 if !$success;
    }
    return ($campaign_id, $date_from, $date_from2, $date_to, $date_to2)
}

sub check_date {
    my ($date_in) = @_;

    $date_in =~ /^(3[01]|[12][0-9]|0?[1-9])\/(1[0-2]|0?[1-9])\/(?:[0-9]{4})?([0-9]{4})$/;
    my $dd = $1;
    my $mm = $2;
    my $yy = $3;
    my $date_out = "$yy-$mm-$dd";
    my $success  = (length($date_out) == 10) ? 1 : 0;

    return ($success, $date_out);
}

sub show_param_instructions {
    my $param_instructions = qq[
        <p>Parameters to be supplied as follows:</p>
        <p><b>cid=</b>n where n is the campaign id number for either Rebel ($Defs::CAMPAIGN_SYS_REBEL) or Amart ($Defs::CAMPAIGN_SYS_AMART)</p>
        <p><b>datefrom=</b>dd/mm/yyyy</p> 
        <p><b>dateto=</b>dd/mm/yyyy</p> 
        <p>Example: cid=$Defs::CAMPAIGN_SYS_REBEL&amp;datefrom=16/11/2011&amp;dateto=17/11/2011</p> 
        <p>cid is mandatory, datefrom and dateto are optional</p>
    ];
    return $param_instructions;
}

sub show_results {
    my ($dbh, $campaign_id, $date_from, $date_from2, $date_to, $date_to2) = @_;

    my $where = '';
    $where .= " AND (DATE_FORMAT(mc.dtAdded, '%Y-%m-%d')>='$date_from2')" if $date_from2;
    $where .= " AND (DATE_FORMAT(mc.dtAdded, '%Y-%m-%d')<='$date_to2')" if $date_to2;

    my $st = qq[
        SELECT COUNT(1) as COUNTNUM 
        FROM tblMember_Campaigns mc
        WHERE (mc.intCampaignID=$campaign_id) $where
    ];

    my $query = $dbh->prepare($st);
    $query->execute;

	my $dref = $query->fetchrow_hashref();
    my $body = '';
    $body .= qq[<p><b>Date from:</b> $date_from, <b>Date to:</b> $date_to</p>] if $date_from or $date_to;
    $body .= qq[<p><b>Count:</b> $dref->{COUNTNUM}</p>];

    $st = qq[
        SELECT
            strRealmName, 
            a.strName as strAssocName, 
            c.strName as strClubName,
            CONCAT(m.strSurname, ', ', m.strFirstname) as strMemberName,
            m.strEmail,
            DATE_FORMAT(mc.dtAdded, '%d/%m/%Y') as dtJoined
        FROM tblMember_Campaigns mc 
            INNER JOIN tblAssoc a ON a.intAssocID=mc.intAssocID 
            INNER JOIN tblClub c ON c.intClubID=mc.intClubID 
            INNER JOIN tblMember m ON m.intMemberID=mc.intMemberID 
            INNER JOIN tblRealms r ON r.intRealmID=a.intRealmID 
        WHERE (mc.intCampaignID=$campaign_id) $where
        ORDER BY strRealmName, strAssocName, strClubName, strMemberName
     ];

    $query = $dbh->prepare($st);
    $query->execute;

    $body .= qq[
        <table width="90%" class="listtable">
            <tr>
                <th>Realm</td>
                <th>Association</td>
                <th>Club</td>
                <th>Member</td>
                <th>Email</td>
                <th>Date Joined</td>
            </tr>
    ];
    while ($dref = $query->fetchrow_hashref()) {
        $body .= qq[
            <tr>
                <td>$dref->{strRealmName}</td>
                <td>$dref->{strAssocName}</td>
                <td>$dref->{strClubName}</td>
                <td>$dref->{strMemberName}</td>
                <td>$dref->{strEmail}</td>
                <td>$dref->{dtJoined}</td>
            </tr>
        ];
    }

    $body .= qq[</table>];

    return $body;
}
