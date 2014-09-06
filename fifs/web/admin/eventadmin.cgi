#!/usr/bin/perl -w

#
# $Header: svn://svn/SWM/trunk/web/admin/eventadmin.cgi 10070 2013-12-01 22:53:59Z tcourt $
#

use lib "../..","..",".";
use DBI;
use CGI qw(param unescape escape);
use Defs;
use Utils;
use strict;
use AdminPageGen;
use AdminCommon;
use EventAdmin;
use FormHelpers;
use HTMLForm;

main();

sub main	{
# Variables coming in
	my $header = "Content-type: text/html\n\n";
	my $body = "";
	my $title = "$Defs::sitename Association Administration";
	my $action = param('action') || '';
	my $event_name_IN = param('event_name') || '';
  my $eventID=param('eID') || 0;
	my $subBody='';
	my $menu='';
	my $activetab=0;
	my $target="eventadmin.cgi";
	my $error='';
	my $db=connectDB();
  if ($action eq "add") {
    ($subBody,$menu) = display_add_event_form($db);
  }	
	elsif($action eq "addevent")	{
		($subBody,$menu)=add_new_event($db);
	}
	elsif($action eq "edit" or $action eq "list")	{
		($subBody,$menu)=handle_event($db,$action,$target);
	}
  elsif ($action eq "approve") {
		($subBody,$menu)=confirm_approval($db,$action,$target,$eventID);
  }
  elsif ($action eq "approve_all") {
		($subBody,$menu)=approve_all($db,$action,$target,$eventID);
  }
	else	{
		$subBody=display_find_fields($target, $db);
	}
	$body=qq[$subBody <br> <div align="center"><a href="$target">Search</a> | <a href="$target?action=add">Add New Event</a></div>] if $subBody;
	disconnectDB($db) if $db;
	print_adminpageGen($body, "", "");
}


sub display_find_fields {
	my($target, $db)=@_;
  my$realms = getRealms($db);
	my $body = qq[
  <br>
	<form action="$target" method="post">
	<input type="hidden" name="action" value="list">
	<table style="margin-left:auto;margin-right:auto;">
	<tr>
		<td class="formbg fieldlabel">Name:&nbsp;<input type="text" name="event_name" size="50"></td>
	</tr>
	<tr>
		<td class="formbg fieldlabel">Realm:&nbsp;$realms</td>
	</tr>
	<tr>
		<td class="formbg"><input type="submit" name="submit" value="S E A R C H"></td>
	</tr>
	</table>
	</form>
	];
  return $body;
}

sub getRealms {
  my ($db) = @_;
  my $st= qq[ 
    SELECT intRealmID, strRealmName 
    FROM tblRealms 
    ORDER BY strRealmName
  ];
  return getDBdrop_down('realmID',$db,$st,'','&nbsp;') || '';
}

sub display_add_event_form {
  my ($db,$error) = @_;
  my $realms = getRealms($db);
  my $body = qq[
    <div class="pageHeading">Add Event</div>
    $error
    <form action="eventadmin.cgi" name="e_form" method="POST" onsubmit="document.getElementById('HFsubbut').disabled=true;return true;">    
    <p class="introtext">
      <b>Note:</b> All boxes marked with a 
      <img src="images/compulsory.gif" alt="Compulsory Field" title="Compulsory Field"/> are compulsory and must be filled in
    </p>
    <table cellpadding="2" cellspacing="0" border="0" >
      <tbody id="secmain" >              
      <tr>
        <td class="label"><label for="l_strEventName">Event Name</label>:</td>
        <td class="value">
          <input type="text" name="d_strEventName" value="" id="l_strEventName" size="40" maxlength="60">
          <img src="images/compulsory.gif" alt="Compulsory Field" title="Compulsory Field">
        </td>
      </tr>
      <tr>
        <td class="label"><label for="l_intAccredCard">Realm</label>:</td>
        <td class="value">
          $realms
          <img src="images/compulsory.gif" alt="Compulsory Field" title="Compulsory Field">
        </td>
      </tr>
      <tr>
        <td class="label"><label for="l_strUsername">Username</label>:</td>
        <td class="value">
          <input type="text" name="d_strUsername" value="" id="l_strUsername" size="40" maxlength="10">
          <img src="images/compulsory.gif" alt="Compulsory Field" title="Compulsory Field">
        </td>
      </tr>
    </table>
    <div class="HTbuttons">
      <input type="submit" name="subbut" value="Add Event" class="HF_submit" id="HFsubbut">
      <input type="hidden" name="action" value="addevent">
    </div>
    </form>
  ];
  return $body;
}

sub add_new_event {
  my ($db,$target) = @_;
  my $eventName = param('d_strEventName') || '';
  my $username = param('d_strUsername') || '';
  my $realmID = param('realmID') || '';
  return display_add_event_form($db,"ERROR: Missing Data") if (!$eventName or !$realmID);
  my $st = qq[
    INSERT INTO tblEvent
    (strEventName, intRealmID, tTimeStamp)
    VALUES (?,?,now())
  ];
  my $q = $db->prepare($st);
  $q->execute($eventName,$realmID);
  my $eventID = $q->{mysql_insertid};
  my $password = getpass();
  print STDERR qq[$username, $password, $eventID];
  my $statement = qq[
    INSERT INTO tblAuth (
      strUsername, 
      strPassword, 
      intLevel, 
      intAssocID, 
      intID, 
      intLogins, 
      dtLastLogin, 
      dtCreated, 
      tTimeStamp, 
      intReadOnly
    )
    VALUES (
      ?,
      ?,
      -50,
      0,
      ?,
      0,
      0,
      now(),
      now(),
      0
    )
  ];
  my $query = $db->prepare($statement);
  $query->execute($username, $password, $eventID);
  return handle_event($db,'edit',$target,$eventID);
}

sub getpass {
  srand();
  #srand(time() ^ ($$ + ($$ << 15)) );
  my $salt=(rand()*100000);
  my $salt2=(rand()*100000);
  my $k=crypt($salt2,$salt);
  #Clean out some rubbish in the key
  $k=~s /['\/\.\%\&]//g;
  $k=substr($k,0,8);
  $k=lc $k;
  return $k;
}

sub confirm_approval {
  my ($db, $action, $target, $eventID) = @_;
  my $st = qq[
    SELECT
      COUNT(ES.intEventApprovalID),
      E.strEventName
    FROM
      tblEventSelections AS ES
      INNER JOIN tblEvent AS E ON (E.intEventID = ES.intEventID) 
    WHERE 
      intEventApprovalID <> 1 
      AND ES.intEventID = ?
  ];
  my $q = $db->prepare($st);
  $q->execute($eventID);
  my ($count, $event_name) = $q->fetchrow_array();
  return qq[
    <div style="padding-left:5px;">
    <h1>CONFIRM Approve All</h1>
    <p>Click on the below button to confirm that you wish to approve <b>$count</b> participants for:<b>$event_name</b>.</p>
    <p>If you do not wish to proceed <a href="$target">click here</a> to return to front screen</p>
    <form action="$target" method="post">
      <input type="hidden" name="action" value="approve_all">
      <input type="hidden" name="eID" value="$eventID">
      <input type="submit" value="Approve $count Participants">
    </form>
    </div>
  ];
}

sub approve_all {
  my ($db, $action, $target, $eventID) = @_;
  my $st = qq[
    UPDATE 
      tblEventSelections 
    SET 
      intEventApprovalID = 1 
    WHERE 
      intEventID = ? 
  ];
  my $q = $db->prepare($st);
  $q->execute($eventID);
  return qq[
    <div style="padding-left:5px;">
    <h1>CONFIRM Approve All</h1>
    <p>SUCCESS</p>
    <p><a href="$target">click here</a> to return to front screen</p>
    </div>
  ];
}
