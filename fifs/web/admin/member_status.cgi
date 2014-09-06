#!/usr/bin/perl -w

#
# $Header: svn://svn/SWM/trunk/web/admin/member_status.cgi 8249 2013-04-08 08:14:07Z rlee $
#

use lib "../..","..",".";
#use lib "/u/regonew_live","/u/regonew_live/web","/u/regonew_live/web/admin";
use DBI;
use CGI qw(param unescape escape);
use Defs;
use Utils;
use strict;
use AdminPageGen;
use AdminCommon;
use AssocAdmin;
use LoginAdmin;
use ClubAdmin;
use FormHelpers;

main();

sub main	{

# Variables coming in

	my $header = "Content-type: text/html\n\n";
	my $body = "";
	my $title = "$Defs::sitename Association Administration";
	my $output=new CGI;

	my $action = param('action') || '';
	my $natnum= param('natnum') || 0;
	my $mID= param('mID') || 0;

	my $target="member_status.cgi";

	my $error='';
	my $db=connectDB();
	
	if (! $natnum and ! $mID)	{
		$body = memForm($target);
	}
	elsif ($natnum and $action eq 'preview')	{
		$body = memPreview($db, $natnum, $target);
	}
	elsif ($natnum and $mID and $action eq 'updateMem')	{
		memUpdate($db, $mID,$natnum);
		$body = qq[Member Updated <br> <a href="member_status.cgi">Return to Start</a>];
	}
	else	{
		$body = clrForm($target);
	}

	disconnectDB($db) if $db;
	print_adminpageGen($body, "", "");
}

sub memForm	{

	my ($target) = @_;

	my $body = qq[
		<form action="$target" method="post">
		<b>UPDATE Member</b><br>
		<b>PLEASE FOOTYWEB NUMBER:</b> <input type="text" name="natnum" value="">
		<input type="hidden" name="action" value="preview">
		<input type="submit" value="U P D A T E">
		</form><br>
	];
	return $body;
}

sub memPreview {

	my ($db, $natnum, $target)=@_;

	my $st = qq[
		SELECT 
			intMemberID,
			strSurname,
			strFirstname,
			strNationalNum,
			intStatus
		FROM 
			tblMember
		WHERE 
			intRealmID=2
			AND strNationalNum=?
		LIMIT 1
	];

	my $q = $db->prepare($st);
  $q->execute($natnum);

	my $cref = $q->fetchrow_hashref();

	my $body = qq[
		<form action="$target" method="post">
		<table>
			<tr>
				<td>Firstname</td>
				<td>$cref->{strFirstname}</td>
			</tr>
			<tr>
				<td>Surname</td>
				<td>$cref->{strSurname}</td>
			</tr>
			<tr>
				<td>National Number</td>
				<td>$cref->{strNationalNum}</td>
			</tr>
			<tr>
				<td>Status</td>
				<td>$cref->{intStatus}</td>
			</tr>
	];
	if ($cref->{'intMemberID'})	{
		$body .= qq[
			<input type="hidden" name="natnum" value="$natnum">
			<input type="hidden" name="mID" value="$cref->{'intMemberID'}">
			<input type="hidden" name="action" value="updateMem">
			<input type="submit" value="U P D A T E">
		];
	}
	$body .= qq[
		</form>
	];
	return $body;
}


sub clrPreview {

	my ($db, $cID, $target)=@_;

	my $st = qq[
		SELECT 
			strSurname,
			strFirstname,
			C1.strName as FROMClubName,
			C2.strName as TOClubName
		FROM 
			tblClearance as C
			INNER JOIN tblClub as C1 ON (C1.intClubID=C.intSourceClubID)
			INNER JOIN tblClub as C2 ON (C2.intClubID=C.intDestinationClubID)
			INNER JOIN tblMember as M ON (M.intMemberID=C.intMemberID)
		WHERE 
			intClearanceID = ?
		LIMIT 1
	];

	my $q = $db->prepare($st);
  $q->execute($cID);

	my $cref = $q->fetchrow_hashref();

	my $body = qq[
		<form action="$target" method="post">
		<table>
			<tr>
				<td>Clearance ID</td>
				<td>$cID</td>
			</tr>
			<tr>
				<td>Firstname</td>
				<td>$cref->{strFirstname}</td>
			</tr>
			<tr>
				<td>Surname</td>
				<td>$cref->{strSurname}</td>
			</tr>
			<tr>
				<td>FROM Club</td>
				<td>$cref->{FROMClubName}</td>
			</tr>
			<tr>
				<td>TO Club</td>
				<td>$cref->{TOClubName}</td>
			</tr>
		<input type="hidden" name="cID" value="$cID">
		<input type="hidden" name="action" value="remove">
		<input type="submit" value="D E L E T E">
		</form>
	];
	return $body;
}
sub memUpdate	{

	my ($db, $mID, $natnum) = @_;

	my $st = qq[
		UPDATE tblMember SET intStatus=1 WHERE intStatus=0 AND intMemberID=? LIMIT 1
	];
	my $qry= $db->prepare($st);
  $qry->execute($mID);

}

1;
