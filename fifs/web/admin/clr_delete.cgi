#!/usr/bin/perl -w

#
# $Header: svn://svn/SWM/trunk/web/admin/clr_delete.cgi 8486 2013-05-15 04:39:41Z dhanslow $
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
	my $cID= param('cID') || 0;
	my $mID= param('mID') || 0;
	my $clubID= param('clubID') || 0;

	my $target="clr_delete.cgi";

	my $error='';
	my $db=connectDB();
	
	if (! $cID and ! $mID and ! $clubID)	{
		$body = clrForm($target);
	}
	elsif ($cID and $action eq 'preview')	{
		$body = clrPreview($db, $cID, $target);
	}
	elsif ($mID and $clubID and $action eq 'previewCC')	{
		$body = clrOutPreview($db, $mID, $clubID, $target);
	}
	elsif ($cID and $action eq 'remove')	{
		clrRemove($db, $cID);
		$body = qq[Clearance Removed <br> <a href="clr_delete.cgi">Return to Start</a>];
	}
	elsif ($mID and $clubID and $action eq 'removeCC')	{
		clrOutRemove($db, $mID, $clubID);
		$body = qq[Cleared Out Removed <br> <a href="clr_delete.cgi">Return to Start</a>];
	}
	else	{
		$body = clrForm($target);
	}

	disconnectDB($db) if $db;
	print_adminpageGen($body, "", "");
}

sub clrForm	{

	my ($target) = @_;

	my $body = qq[
		<form action="$target" method="post">
		<b>Remove a Clearance</b><br>
		<b>PLEASE ENTER ID:</b> <input type="text" name="cID" value="">
		<input type="hidden" name="action" value="preview">
		<input type="submit" value="F I N D">
		</form><br>
		<b>OR</b><br><br>
		<b>Removed a Cleared out Status</b><br>
		<form action="$target" method="post">
		<b>PLEASE ENTER NATIONAL NUMBER (FOOTYWEB) ID: </b><input type="text" name="mID" value="">
		<b>PLEASE ENTER CLUB ID:  </b><input type="text" name="clubID" value="">
		<input type="hidden" name="action" value="previewCC">
		<input type="submit" value="F I N D">
		</form>
	];
	return $body;
}

sub clrOutPreview {

	my ($db, $mID, $clubID, $target)=@_;

	my $st = qq[
		SELECT 
			MCC.intMemberID,
			strSurname,
			strFirstname,
			C.strName as ClubName,
			A.strName as AssocName
		FROM 
			tblMember_ClubsClearedOut as MCC
			INNER JOIN tblClub as C ON (C.intClubID=MCC.intClubID)
			INNER JOIN tblAssoc as A ON (A.intAssocID=MCC.intAssocID)
			INNER JOIN tblMember as M ON (M.intMemberID=MCC.intMemberID)
		WHERE 
			M.strNationalNum=?
			AND MCC.intClubID=?
		LIMIT 1
	];
	my $q = $db->prepare($st);
  $q->execute($mID, $clubID);

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
				<td>Club</td>
				<td>$cref->{ClubName}</td>
			</tr>
			<tr>
				<td>Assoc</td>
				<td>$cref->{AssocName}</td>
			</tr>
	];
	if ($cref->{'intMemberID'})	{
		$body .= qq[
			<input type="hidden" name="clubID" value="$clubID">
			<input type="hidden" name="mID" value="$cref->{'intMemberID'}">
			<input type="hidden" name="action" value="removeCC">
			<input type="submit" value="D E L E T E">
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
			C2.strName as TOClubName,
			C.intPermitType,
			C.intMemberID
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
my $isPermit = $cref->{'intPermitType'};
	my $body = qq[
		<form action="$target" method="post">
		<table>
			<tr>
				<td>Clearance ID</td>
				<td>$cID</td>
			</tr>];
	if($isPermit){
$body .=qq[
<tr><td colspan="2" style='color:red'>This is a permit, we need to change the permit dates Perhaps?</td></tr>
];
		}
		$body .=qq[	<tr>
				<td>MemberID</td>
				<td>$cref->{intMemberID}</td>
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
sub clrOutRemove {

	my ($db, $mID, $clubID) = @_;

	my $st = qq[
		DELETE FROM tblMember_ClubsClearedOut WHERE intMemberID= ? AND intClubID=? LIMIT 1
	];
	my $q_del= $db->prepare($st);
  $q_del->execute($mID, $clubID);

}

sub clrRemove {

	my ($db, $cID) = @_;

	my $st = qq[
		DELETE FROM tblClearance WHERE intClearanceID = ? LIMIT 1
	];
	my $q_del= $db->prepare($st);
  $q_del->execute($cID);

	$st = qq[
		DELETE FROM tblClearancePath WHERE intClearanceID = ?
	];
	$q_del= $db->prepare($st);
  $q_del->execute($cID);

	$st = qq[
		DELETE FROM tblMember_ClubsClearedOut WHERE intClearanceID = ? LIMIT 1
	];
	$q_del= $db->prepare($st);
  $q_del->execute($cID);

}
1;
