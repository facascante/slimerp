#
# $Header: svn://svn/SWM/trunk/web/admin/LoginAdmin.pm 11311 2014-04-15 22:29:11Z ppascoe $
#

package LoginAdmin;

require Exporter;
@ISA =  qw(Exporter);
@EXPORT = qw(display_login_search_list edit_login_form modify_login_details edit_node_name modify_node_name);
@EXPORT_OK = qw(display_login_search_list edit_login_form modify_login_details edit_node_name modify_node_name);

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
use PassportLink;

sub display_login_search_list {
  my ($db, $action, $intAssocID, $target) = @_;

  my $assoc_id_IN   = param('assoc_id') || '';
  my $assoc_name_IN = param('assoc_name') || '';
  my $realm_IN      = param('realmID') || '';
  my $subRealm_IN   = param('subRealmID') || '';
  my $assoc_un_IN   = param('assoc_un') || '';
  my $level_IN      = param('level') || '';

  my $strWhere='';
  if ($assoc_id_IN) {
    $strWhere .= qq/ AND N.intNodeID = '$assoc_id_IN' /;
  }
  if ($assoc_name_IN) {
    $strWhere .= qq/ AND N.strName LIKE '%$assoc_name_IN%' /;
  }
  if ($assoc_un_IN) {
    $strWhere .= qq/ AND A.strUsername = '$assoc_un_IN' /;
  }
  if ($subRealm_IN) {
    $strWhere .= qq/ AND N.intSubTypeID = '$subRealm_IN' /;
  }
  if ($realm_IN) {
    $strWhere .= qq/ AND N.intRealmID = '$realm_IN' /;
  }
  if ($level_IN) {
    $strWhere .= qq/ AND N.intTypeID = '$level_IN' /;
  }
  $strWhere =~ s/^ AND //g if $strWhere;
  $strWhere = "WHERE $strWhere" if $strWhere;

  my $statement=qq[
    SELECT DISTINCT
      N.intNodeID,
      N.strName,
      N.intTypeID,
      N.intStatusID,
      N.intRealmID,
      R.strRealmName,
      SR.strSubTypeName
    FROM
      tblNode AS N
     LEFT JOIN tblAuth AS A ON (N.intNodeID = A.intID AND A.intAssocID = 0 AND A.intLevel > $Defs::LEVEL_ASSOC)
     LEFT JOIN tblRealms AS R ON (N.intRealmID = R.intRealmID)
     LEFT JOIN tblRealmSubTypes AS SR ON (N.intSubTypeID = SR.intSubTypeID)
    $strWhere
    ORDER BY
      N.intTypeID DESC,
      R.intRealmID,
      SR.intSubTypeID
  ];
  my $query = $db->prepare($statement) or query_error($statement);
  $query->execute() or query_error($statement);
  my $count=0;
  my $body='';
  my $hash_value = '';
  while(my $dref= $query->fetchrow_hashref()) {
    foreach my $key (keys %{$dref}) { if(!defined $dref->{$key})  {$dref->{$key}='';} }
    $dref->{strName} = $dref->{strName} || '&nbsp;';
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
    my $login_link = '';
  { 
			my $loginurl = passportURL( {}, {}, '',
      "$Defs::base_url/authenticate.cgi?i=$dref->{intNodeID}&amp;t=$dref->{'intTypeID'}",
			) ;

			$login_link = qq[<a target="new_window" href="$loginurl">LOGIN</a>];
    }
    my $edit_link = $dref->{strName};
    if ($dref->{intStatusID} == 1) {
      $hash_value = AdminCommon::create_hash_qs(0,$dref->{'intNodeID'},0,0,0);	
      my $edit = ($dref->{intAuthID}) ? "update_login" : "add_login";
      $edit_link = qq[<a href="$target?action=LOGIN_SEARCH_$edit&nodeID=$dref->{intNodeID}&authID=$dref->{'intAuthID'}&level=$dref->{intTypeID}&hash=$hash_value">$dref->{strName}</a>];
    }
    $body.=qq[
      <tr>
        <td class="$classborder">$edit_link</td>
        <td class="$classborder">$dref->{intTypeID}</td>
        <td class="$classborder">$dref->{intNodeID}</td>
        <td class="$classborder">$dref->{strRealmName}</td>
        <td class="$classborder">$dref->{strSubTypeName}</td>
        <td class="$classborder">$login_link</td>
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
        <th style="text-align:left;">Name</th>
        <th style="text-align:left;">Type</th>
        <th style="text-align:left;">ID</th>
        <th style="text-align:left;">Realm</th>
        <th style="text-align:left;">Sub Realm</th>
        <th style="text-align:left;">&nbsp;</th>
      </tr>
      $body
    </table><br>
    ];
  }
  return ($body);
}

sub edit_login_form {
  my ($db, $target, $action) = @_;
  my $authID_IN = param('authID') || 0;
  my $nodeID_IN = param('nodeID') || 0;

print "Content-type: text/html\n\n";
use Data::Dumper;
print "<pre>";
print Dumper('02'); 
print "</pre>";
  
  if (!AdminCommon::verify_hash()) {
		return("Error in Querystring hash");
  } 
    
  my $edit_node_option = '';
  if (check_access('NODE_EDIT_USER')) {
    $edit_node_option = qq[[<span style="font-weight:normal;"><a href="$target?action=LOGIN_SEARCH_edit_node_name&nodeID=$nodeID_IN">Edit</a></span>]];
  }
  my $statement=qq[
    SELECT DISTINCT     
	N.intNodeID,
      N.strName,
      N.intTypeID,
      N.intStatusID,
      N.intRealmID,
      A.intAuthID,
      A.strUsername,
      A.strPassword,
      A.intReadOnly
    FROM
      tblNode AS N
      LEFT JOIN tblAuth AS A ON (N.intNodeID = A.intID AND A.intAssocID = 0 AND A.intLevel > $Defs::LEVEL_ASSOC)
    WHERE
      intNodeID = ?
  ];
  my $query = $db->prepare($statement) or query_error($statement);
  $query->execute($nodeID_IN) or query_error($statement);
  my $username = '';
  my $password = '';
  my $node_name = '';
  my $level = '';
  my $selected = '';
  while(my $dref= $query->fetchrow_hashref()) {
    $username = $dref->{strUsername} if ($dref->{intAuthID} == $authID_IN);
    $password = $dref->{strPassword} if ($dref->{intAuthID} == $authID_IN);
    $selected = "SELECTED" if ($dref->{intAuthID} == $authID_IN and $dref->{intReadOnly} == 1);
    $node_name = $dref->{strName};
    $level = $dref->{intTypeID};
  }
  my $button_title = ($action eq "edit") ? "UPDATE LOGIN" : "ADD LOGIN";
  my $form_action = ($action eq "edit") ? "LOGIN_SEARCH_modify_login" : "LOGIN_SEARCH_insert_login";
  my $additional_login = ($authID_IN) ? qq[ <a href="$target?action=LOGIN_SEARCH_add_login&nodeID=$nodeID_IN">[Create Additional Login]</a>] : '';
  my $hash_value = AdminCommon::create_hash_qs(0,$nodeID_IN,0,0,0);
  	
  return qq[
  <form action="$target" method="post">
  <input type="hidden" name="action" value="$form_action">
  <input type="hidden" name="nodeID" value="$nodeID_IN">
  <input type="hidden" name="authID" value="$authID_IN">
  <input type="hidden" name="level" value="$level">
  <input type="hidden" name="hash" value="$hash_value">
  
  <table style="margin-left:auto;margin-right:auto;">
  <tr>
    <td class="formbg fieldlabel">Name:&nbsp; <input type="text" name="assoc_name" value="$node_name" size="50" readonly="true"> $edit_node_option</td>
  </tr>
  <tr>
    <td class="formbg fieldlabel">Username:&nbsp;<input type="text" name="assoc_un" value="$username" size="50"></td>
  </tr>
  <tr>
    <td class="formbg fieldlabel">Password:&nbsp;<input type="text" name="assoc_pw" value="$password" size="50"></td>
  </tr>
  <tr>
    <td class="formbg fieldlabel">Read Only:&nbsp;<select name="ro"><option value="0">No</option><option value="1" $selected>Yes</option></select></td>
  </tr>
  <tr>
    <td class="formbg fieldlabel">Level:&nbsp;$level</td>
  </tr> 
 <tr>
    <td class="formbg"><input type="submit" name="submit" value="$button_title"> $additional_login</td>
  </tr>
  </table>
  </form>
  ];
}

sub modify_login_details {
  my ($db, $target, $action) = @_;
  my $authID_IN = param('authID') || 0;
  my $nodeID_IN = param('nodeID') || 0;
  my $level_IN = param('level') || 0;
  my $readonly_IN = param('ro') || 0;
  my $username_IN = param('assoc_un') || 0;
  my $password_IN = param('assoc_pw') || 0;
  return "ERROR :: No Node ID passed in !" unless $nodeID_IN;
  return "ERROR :: No Level passed in !" unless $level_IN;
  return "ERROR :: Password is blank !" unless $password_IN;
  return "ERROR :: Password is too short (min 6 chracters) !" unless (length($password_IN) > 5);
  return "ERROR :: Username is too short (min 6 chracters) !" unless (length($username_IN) > 5);
  return "ERROR :: Username is blank !" unless $username_IN;

print "Content-type: text/html\n\n";
use Data::Dumper;
print "<pre>";
print Dumper('03'); 
print "</pre>";

 	if (!AdminCommon::verify_hash()) {
		  return "ERROR :: Error in Querystring";	
	} 

  my $statement = qq[SELECT intAuthID FROM tblAuth WHERE strUsername = ? AND intAuthID <> ?];
  my $query = $db->prepare($statement) or query_error($statement);
  $query->execute($username_IN, $authID_IN) or query_error($statement);
  return "ERROR :: Username already exists !" if $query->fetchrow_array();
  my $response_text = 'ERROR :: Invalid data passed in !';
  if ($authID_IN and $action eq "modify") {
    my $st = qq[
      UPDATE
        tblAuth
      SET
        strUsername = ?,
        strPassword = ?,
        intReadOnly = ?
      WHERE
        intAuthID = ?
        AND intID = ?
      LIMIT 1
    ];
    my $q = $db->prepare($st) or query_error($st);
    $q->execute(
      $username_IN,
      $password_IN,
      $readonly_IN,
      $authID_IN,
      $nodeID_IN
    ) or query_error($st);
    $response_text = "Login Updated OK";
  }
  elsif ($action eq "insert" and !$authID_IN) {
    my $st = qq[
      INSERT INTO
        tblAuth (
          strUsername,
          strPassword,
          intID,
          intAssocID,
          intLevel,
          intLogins,
          dtCreated,
          intReadOnly
        )
      VALUES (
        ?,
        ?,
        ?,
        0,
        ?,
        0,
        now(),
        ?
      )
    ];
    my $q = $db->prepare($st) or query_error($st);
    $q->execute(
        $username_IN,
        $password_IN,
        $nodeID_IN,
        $level_IN,
        $readonly_IN
    ) or query_error($st);
    $response_text = "Login Inserted OK";
  }
  return $response_text; 
}

sub edit_node_name {
  my ($db, $target, $action) = @_;
  my $nodeID_IN = param('nodeID') || 0;

print "Content-type: text/html\n\n";
use Data::Dumper;
print "<pre>";
print Dumper('04'); 
print "</pre>";

  my $statement=qq[
    SELECT
      N.intNodeID,
      N.strName,
      N.intTypeID,
      N.intStatusID,
      N.intRealmID
    FROM
      tblNode AS N
    WHERE
      intNodeID = ?
  ];
  my $query = $db->prepare($statement) or query_error($statement);
  $query->execute($nodeID_IN) or query_error($statement);
  my $node_ref = $query->fetchrow_hashref();
  return qq[<p><b>ERROR:</b> Something is very wrong here !</p>] unless ($node_ref->{'strName'} and $node_ref->{'intNodeID'});
  return qq[
  <form action="$target" method="post">
  <input type="hidden" name="action" value="LOGIN_SEARCH_update_node_name">
  <input type="hidden" name="nodeID" value="$nodeID_IN">
  <table style="margin-left:auto;margin-right:auto;">
  <tr>
    <td class="formbg fieldlabel">Name:&nbsp; <input type="text" name="nodeName" value="$node_ref->{'strName'}" size="50"></td>
  </tr>
  <tr>
    <td class="formbg"><input type="submit" name="submit" value="UPDATE"></td>
  </tr>
  </table>
  </form>
  ];
}

sub modify_node_name {
  my ($db, $target, $action) = @_;
  my $nodeID_IN = param('nodeID') || 0;
  my $nodeName_IN = param('nodeName') || 0;
  return "ERROR :: No Node ID passed in !" unless $nodeID_IN;
  return "ERROR :: No Node Name passed in !" unless $nodeName_IN;
  
  print "Content-type: text/html\n\n";
use Data::Dumper;
print "<pre>";
print Dumper('05'); 
print "</pre>";
  
  my $st = qq[
    UPDATE
      tblNode
      SET
        strName = ?
      WHERE
        intNodeID = ?
      LIMIT 1
  ];
  my $q = $db->prepare($st) or query_error($st);
  $q->execute(
      $nodeName_IN,
      $nodeID_IN
  ) or query_error($st);
  return "Node Name Updated OK";
}

1;
