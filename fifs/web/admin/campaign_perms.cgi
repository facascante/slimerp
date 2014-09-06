#!/usr/bin/perl -w

#
# $Header: svn://svn/SWM/trunk/web/admin/campaign_perms.cgi 8530 2013-05-22 05:57:47Z cgao $
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
	my $intID= param('id') || 0;
	my $body = qq[<div><a href="campaign_perms.cgi?a=FORM">Add Permission</a>&nbsp;|&nbsp;];
	$body .= qq[<a href="campaign_perms.cgi?a=LIST">List Permissions</a></div><br>];
	CP_delete($db, $intID) if ($a eq 'DELETE');
	$body .= CP_list($db) if ($a eq 'LIST');
    $body .= CP_addForm($db) if ($a eq 'FORM');
    $body .= CP_add($db) if ($a eq 'ADD');
	disconnectDB($db) if $db;

    	print_adminpageGen($body, "", "");
}

sub CP_delete	{

	my ($db, $intID) = @_;

	$intID ||= 0;

	return if ! $intID;

	my $st = qq[
		DELETE
		FROM
			tblCampaignPermissions
		WHERE
			intID = $intID
		LIMIT 1
	];
	my $query = $db->prepare($st);
	$query->execute;

}

sub CP_add	{

	my ($db)=@_;

	my $intRealmID = param('intRealmID') || 0;
	my $intAssocID = param('intAssocID') || 0;
	my $intClubID = param('intClubID') || 0;
	my $intCampaignID = param('intCampaignID') || 0;
	my $intPermissionStatus= param('intPermissionStatus') || 0;

	return 'Campaign must be selected' if ! $intCampaignID;
	return 'Realm must be selected' if ! $intRealmID;
	return 'Permission must be selected' if ! $intRealmID;

	if ($intClubID or $intAssocID)	{	
		my $st = qq[
			SELECT 
				A.intAssocID,
				AC.intClubID
			FROM
				tblAssoc as A 
				LEFT JOIN tblAssoc_Clubs as AC ON (
					AC.intAssocID=A.intAssocID
					AND AC.intClubID=$intClubID
				)
			WHERE
				A.intAssocID=?
				AND A.intRealmID=?
		];
		print STDERR $st;
		my $query = $db->prepare($st);
		$query->execute($intAssocID, $intRealmID);
		my $dref=$query->fetchrow_hashref();

		return 'Club not found for that Association or Sport' if ($intClubID and ! $dref->{'intClubID'});
		return 'Association not found for that Sport' if ($intAssocID and ! $dref->{'intAssocID'});
	}

	my $st = qq[
		INSERT IGNORE INTO tblCampaignPermissions
		(intCampaignID, intRealmID, intAssocID, intClubID, intPermissionStatus, dtAdded)
		VALUES (?,?,?,?,?,NOW())
	];
	my $query = $db->prepare($st);
	$query->execute($intCampaignID, $intRealmID, $intAssocID, $intClubID, $intPermissionStatus);

	return qq[<span style="color:green;">Permission Added</span>];
}

sub CP_addForm	{

	my ($db) = @_;

	my $st =qq[
		SELECT 
			intRealmID,
			strRealmName
		FROM
			tblRealms
		ORDER BY
			strRealmName
	];
	my $query = $db->prepare($st);
	$query->execute;
	my $realms = qq[
		<select name="intRealmID"><option value="">--Select Realm</option>
	];
	while (my $dref=$query->fetchrow_hashref())	{
		$realms .= qq[<option value="$dref->{'intRealmID'}">$dref->{'strRealmName'}</option>];
	}
	$realms .= qq[</select>];

	my $campaigns = qq[
		<select name="intCampaignID">
		<option value="1">Rebel</option>
        <option value="3">Support Your Sport (Rebel/Amart)</option>
		</select>
	];

	my $status= qq[
		<select name="intPermissionStatus">
		<option value="0">--Select Status--</option>
		<option value="1">Allow Campaign</option>
		<option value="-1">Hide Campaign</option>
		</select>
	];
	my $body = qq[
		<form name="form" action="campaign_perms.cgi" post="post">
			<table>
				<tr>
					<td>Campaign:</td>
					<td>$campaigns</td>
				</tr>
				<tr>
					<td>Realm/Sport:</td>
					<td>$realms</td>
				</tr>
				<tr>
					<td>Association ID:</td>
					<td><input type="text" name="intAssocID" value=""></td>
				</tr>
				<tr>
					<td>Club ID:</td>
					<td><input type="text" name="intClubID" value=""></td>
				</tr>
				<tr>
					<td>Permission Status</td>
					<td>$status</td>
				</tr>
				</table>
			<input type="hidden" name="a" value="ADD">
			<input type="submit" name="Submit" value="Submit">
		</form>
	];
}

sub CP_list  {

    my ($db) = @_ ;
    
    my $where = '';
    if (param('cID')){
        my $campaign_id = param('cID');
        if ($campaign_id =~/^\d+$/) {
            $where = qq[WHERE intCampaignID = $campaign_id];
        }
    }
    
    my $st = qq[
        SELECT 
			intID,
			intCampaignID,
			strRealmName,
			A.strName as AssocName,
			C.strName as ClubName,
			intPermissionStatus
		FROM
			tblCampaignPermissions as CP
			LEFT JOIN tblClub as C ON (
				C.intClubID=CP.intClubID
			)
			LEFT JOIN tblAssoc as A ON (
				A.intAssocID=CP.intAssocID
			)
			INNER JOIN tblRealms as R ON (
				R.intRealmID=CP.intRealmID
			)
        $where
	    ORDER BY 
			strRealmName,
			A.strName,
			C.strName
     ];

           
	my $query = $db->prepare($st);
	$query->execute;

    my $count=0;
    my $body = qq[
        <table width="90%" class="listtable">
            <tr>
                <th>CAMPAIGN</td>
                <th>Realm</td>
                <th>Association Name</td>
                <th>Club Name</td>
                <th>Status</td>
                <th>&nbsp;</td>
            </tr>
    ];
	while (my $dref =$query->fetchrow_hashref())	{
        my $returned = $dref->{'intMassPayReturnedOnID'} ? qq[<span style="color:red;">REVERSED</span>] : 'No';
		
        my $campaign = '';
		if ($dref->{'intCampaignID'} == 1) {
            $campaign = 'Rebel';
        }
        elsif ($dref->{'intCampaignID'} == 3) {
            $campaign = 'Support Your Support (Rebel/Amart)';
        }

		my $status = 'No Status';
		$status = '<span style="color:green;"><b>Allow</b></span>' if ($dref->{'intPermissionStatus'} ==1);
		$status = 'HIDE' if ($dref->{'intPermissionStatus'} ==-1);
        $body .= qq[
            <tr>
                <td>$campaign</td>
                <td>$dref->{strRealmName}</td>
                <td>$dref->{AssocName}</td>
                <td>$dref->{ClubName}</td>
                <td>$status</td>
                <td><a href="campaign_perms.cgi?a=DELETE&amp;id=$dref->{'intID'}"  onclick="return confirm('Are you sure you want to delete this Permission?');">delete</a></td>
            </tr>
        ];
        $count++;
    }

    $body .= qq[</table>];

    $body = qq[No Permissions] if ! $count;

    return $body;

}

1;
