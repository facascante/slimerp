#
# $Header: svn://svn/SWM/trunk/web/admin/MemberAdmin.pm 8593 2013-05-31 02:00:38Z cgao $
#

package MemberAdmin;

require Exporter;
@ISA =  qw(Exporter);
@EXPORT = qw(display_member_search_list);
@EXPORT_OK = qw(display_member_earch_list);

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
sub display_member_search_list {
  my ($db, $action, $intAssocID, $target) = @_;

  my $member_name_IN    = param('member_firstname') || '';
  my $realm_IN          = param('realmID') || '';
  my $member_surname_IN = param('member_surname') || '';
  my $member_id_IN      = param('member_id') || '';
  my $member_email_IN   = param('member_email') || '';

  my $strWhere='';
  if ($member_email_IN) {
    $strWhere .= qq/ AND strEmail LIKE '%$member_email_IN%' /;
  }
  if ($member_name_IN) {
    $strWhere .= qq/ AND strFirstname LIKE '%$member_name_IN%' /;
  }
  if ($member_surname_IN) {
    $strWhere .= qq/ AND strSurname LIKE '%$member_surname_IN%' /;
  }
  if ($member_id_IN) {
    $strWhere .= qq/ AND strNationalNum LIKE '%$member_id_IN%' /;
  }
  if ($realm_IN) {
    $strWhere .= qq/ AND intRealmID = '$realm_IN' /;
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
     	<td class="$classborder" align="center"><a href="?action=DATA&type=intMemberID&useID=$dref->{intMemberID}">?</a></td>
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



