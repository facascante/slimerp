#
# $Header: svn://svn/SWM/trunk/web/admin/ClubAdmin.pm 11308 2014-04-15 22:28:27Z ppascoe $
#

package ClubAdmin;

require Exporter;
@ISA =  qw(Exporter);
@EXPORT = qw(club_info display_club_search_list edit_club_form modify_club_details setup_umpire_allocation delete_umpire_allocation mark_club_as_deleted mark_club_as_undeleted);
@EXPORT_OK = qw(club_info display_club_search_list edit_club_form modify_club_details setup_umpire_allocation delete_umpire_allocation mark_club_as_deleted mark_club_as_undeleted);

use lib "..","../..","../sp_publisher";
use DBI;
use CGI qw(param unescape escape);
use strict;
use Defs;
use Utils;
use AdminCommon;
use DeQuote;
use FormHelpers;
use PassportLink;


sub display_club_search_list {
  my ($db, $action, $intAssocID, $target) = @_;

  my $club_name_IN  = param('club_name') || '';
  my $realm_IN      = param('realmID') || '';
  my $subRealm_IN   = param('subRealmID') || '';
  my $club_un_IN    = param('club_un') || '';
  my $club_id_IN    = param('club_id') || '';
  my $assocID_IN    = param('club_assoc_id') || $intAssocID || 0;
  my $club_email_IN = param('club_email') || '';

  my $strWhere='';
  if ($club_email_IN) {
    $strWhere .= qq/ AND C.strEmail LIKE '%$club_email_IN%' /;
  }
  if ($club_name_IN) {
    $strWhere .= qq/ AND C.strName LIKE '%$club_name_IN%' /;
  }
  if ($club_un_IN) {
    $strWhere .= qq/ AND A.strUsername = '$club_un_IN' /;
  }
  if ($club_id_IN) {
    $strWhere .= qq/ AND C.intClubID = '$club_id_IN' /;
  }
  if ($subRealm_IN) {
    $strWhere .= qq/ AND Assoc.intAssocTypeID = '$subRealm_IN' /;
  }
  if ($realm_IN) {
    $strWhere .= qq/ AND Assoc.intRealmID = '$realm_IN' /;
  }
  if ($assocID_IN) {
    $strWhere .= qq/ AND AC.intAssocID = $assocID_IN /;
  }

  my $statement=qq[
    SELECT DISTINCT
      C.intClubID,
      AC.intAssocID,
      C.strName,
      Assoc.strName as AssocName,
      R.strRealmName,
      SR.strSubTypeName,
      BA.strMerchantAccUsername as BAstrMerchantAccUsername,
      BA.strMPEmail as BAstrMPEmail,
      AC.intRecStatus AS intStatusID,
      C.intRecStatus AS intClubStatusID
    FROM
      tblClub as C
      LEFT JOIN tblAssoc_Clubs as AC ON (AC.intClubID = C.intClubID)
      LEFT JOIN tblAssoc as Assoc ON (Assoc.intAssocID=AC.intAssocID)
      LEFT JOIN tblAuth AS A ON (C.intClubID = A.intID AND A.intAssocID = AC.intAssocID AND A.intLevel = $Defs::LEVEL_CLUB)
      LEFT JOIN tblRealms AS R ON (Assoc.intRealmID = R.intRealmID)
      LEFT JOIN tblRealmSubTypes AS SR ON (Assoc.intAssocTypeID = SR.intSubTypeID)
      LEFT JOIN tblBankAccount as BA ON (BA.intEntityTypeID=3 AND BA.intEntityID = C.intClubID)
    WHERE
	  AC.intRecStatus<>-1
      $strWhere
	GROUP BY C.intClubID
    ORDER BY
      intStatusID desc,
      C.strName,
      R.intRealmID,
      SR.intSubTypeID
  ];
  if (param('showpay'))	{
  $statement=qq[
    SELECT distinct
      C.intClubID,
      AC.intAssocID,
      C.strName,
      Assoc.strName as AssocName,
      R.strRealmName,
      SR.strSubTypeName,
			BA.strMerchantAccUsername as BAstrMerchantAccUsername,
			BA.strMPEmail as BAstrMPEmail,
      AC.intRecStatus AS intStatusID,
      C.intRecStatus AS intClubStatusID,
			SUM(IF(TL.intLogID>0,intAmount,0)) as PayPalAmount
    FROM
      tblClub as C
      LEFT JOIN tblAssoc_Clubs as AC ON (AC.intClubID = C.intClubID)
      LEFT JOIN tblAssoc as Assoc ON (Assoc.intAssocID=AC.intAssocID)
      LEFT JOIN tblRealms AS R ON (Assoc.intRealmID = R.intRealmID)
      LEFT JOIN tblRealmSubTypes AS SR ON (Assoc.intAssocTypeID = SR.intSubTypeID)
			LEFT JOIN tblBankAccount as BA ON (BA.intEntityTypeID=3 AND BA.intEntityID = C.intClubID)
			LEFT JOIN tblMoneyLog as ML ON (
				ML.intEntityID=C.intClubID
				AND ML.intAssocID=AC.intAssocID
				AND ML.intEntityType=3
				AND ML.intLogType=6
			)
			LEFT JOIN tblTransLog as TL ON (
				TL.intLogID=ML.intTransLogID
				AND TL.intPaymentType=11
				AND TL.intStatus=1
			)
    WHERE
	    AC.intRecStatus<>-1
        $strWhere
		GROUP BY C.intClubID
    ORDER BY
      intStatusID desc,
      C.strName,
      R.intRealmID,
      SR.intSubTypeID
  ];
	}
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
    
    my $delete_link = '';
    $hash_value = AdminCommon::create_hash_qs(0,0,$dref->{intAssocID},$dref->{intClubID},0);	
    if ($dref->{'intClubStatusID'} == -1) {
      $delete_link = qq[<a href="$target?action=CLUB_SEARCH_restore_club&clubID=$dref->{intClubID}&assocID=$dref->{intAssocID}&hash=$hash_value">RESTORE</a>];
    }
    else {
      $delete_link = qq[<a href="$target?action=CLUB_SEARCH_delete_club&clubID=$dref->{intClubID}&assocID=$dref->{intAssocID}&hash=$hash_value">DELETE</a>];
    }

		my $loginurl= passportURL( {}, {}, '',
      "$Defs::base_url/authenticate.cgi?i=$dref->{intClubID}&amp;t=$Defs::LEVEL_CLUB",
    ) ;

    my $login_link = qq[<a target="new_window" href="$loginurl">LOGIN</a>];
    #$login_link = '' if (! $dref->{strUsername} or ! $dref->{strPassword});
    my $edit_link = $dref->{strName};
    $hash_value = AdminCommon::create_hash_qs(0,0,0,$dref->{intClubID},0);	
    $edit_link = qq[<a href="$target?action=CLUB_SEARCH_edit&clubID=$dref->{intClubID}&hash=$hash_value">$dref->{strName}</a>];
		my $payPalAmount='';
		$payPalAmount= qq[(\$].$dref->{PayPalAmount}.qq[)] if ($dref->{PayPalAmount});
    $hash_value = AdminCommon::create_hash(0,0,$dref->{intAssocID},0,0);	
    $body.=qq[
      <tr>
        <td class="$classborder">$edit_link [$delete_link]</td>
        <td class="$classborder">$dref->{intClubID}</td>
        <td class="$classborder"><a href="?action=ASSOC_edit&intAssocID=$dref->{intAssocID}&hash=$hash_value">$dref->{intAssocID}</a></td>
        <td class="$classborder">$dref->{AssocName}</td>
        <td class="$classborder">$dref->{strRealmName}</td>
        <td class="$classborder">$dref->{strSubTypeName}</td>
        <td class="$classborder">$dref->{BAstrMPEmail} $payPalAmount</td>
        <td class="$classborder">$dref->{BAstrMerchantAccUsername}</td>
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
        <th style="text-align:left;">Club ID</th>
        <th style="text-align:left;">Assoc ID</th>
        <th style="text-align:left;">Assoc Name</th>
        <th style="text-align:left;">Realm</th>
        <th style="text-align:left;">Sub Realm</th>
        <th style="text-align:left;">PayPal Email ( #forms)</th>
        <th style="text-align:left;">NAB Merchant</th>
        <th style="text-align:left;">&nbsp;</th>
      </tr>
      $body
    </table><br>
    ];
  }
  return ($body);
}

sub edit_club_form {
  my ($db, $target, $action, $clubID) = @_;
  my $clubID_IN = param('clubID') || $clubID || 0;

 	if (!AdminCommon::verify_hash()) {
		return("Error in Querystring hash");
	}  

  my $statement=qq[
    SELECT
        C.intClubID,
        C.strName,
        A.strName as AssocName,
        A.intApproveClubPayment,
        C.intClubFeeAllocationType,
        A.intAssocFeeAllocationType,
        C.intApprovePayment,
		    PA.strPaymentEmail,
        C.strExtKey
    FROM
      tblClub as C 
      INNER JOIN tblAssoc_Clubs as AC ON (AC.intClubID=C.intClubID)
		LEFT JOIN tblPaymentApplication as PA ON (PA.intEntityID = C.intClubID AND PA.intEntityTypeID=3)
      INNER JOIN tblAssoc as A ON (A.intAssocID = AC.intAssocID)
    WHERE
      C.intClubID = ?
		
  ];
  my $query = $db->prepare($statement) or query_error($statement);
  $query->execute($clubID_IN) or query_error($statement);
  my $club_name = '';
  my $club_payment= '';
  my $assoc_name = '';
  my $assoc_payment = '';
  my $club_feeAllocation='';
  my $assocFeeAllocation='';
  my $paymentEmail='';
  my $external_key='';
  while(my $dref= $query->fetchrow_hashref()) {
    $club_name = $dref->{strName};
    $external_key = $dref->{strExtKey};
    $assoc_name = $dref->{AssocName};
    $assoc_payment = $dref->{intApproveClubPayment} || 0;
    $club_payment = $dref->{intApprovePayment} || 0;
    $assoc_payment = ($assoc_payment == 1) ? 'YES - All approved' : 'No - individual club approval required';
    $club_feeAllocation=$dref->{intClubFeeAllocationType} || 0;
    $assocFeeAllocation = $dref->{intAssocFeeAllocationType} == 1 ? 'Inclusive': ($dref->{intAssocFeeAllocationType} == 2 ? 'user pays': '');
    $paymentEmail = $dref->{strPaymentEmail} || '';
    $external_key = $dref->{strExtKey} || '';
  }
  my $button_title = "UPDATE CLUB";
  my $form_action = "CLUB_SEARCH_update";

	my $clear = $paymentEmail ? qq[ <a href="$target?action=CLEAR_dollar&amp;intEntityID=$clubID_IN&amp;intEntityTypeID=3">Clear Address</a>] : '';


  my $st = qq[
    SELECT
      ULC.*,
      A.strName AS strAssocName,
      AC.strTitle AS strCompName
    FROM
      tblUmpireLevelConfig AS ULC
      INNER JOIN tblAssoc AS A ON (A.intAssocID = ULC.intComp_AssocID)
      LEFT JOIN tblAssoc_Comp AS AC ON (AC.intCompID = ULC.intComp_CompID)
    WHERE
      intUmpireLevel = 3
      AND intUmpireEntityID = ?
    ORDER BY
      A.strName
  ];
  my $q = $db->prepare($st);
  $q->execute($clubID_IN);
  my $umpire_config = '';
  while (my $dref = $q->fetchrow_hashref()) {
    $dref->{'strCompName'} ||= qq[All Competitions];
    $umpire_config .= qq[$dref->{'strAssocName'} ($dref->{'strCompName'}) [<a href="$target?action=CLUB_SEARCH_delete_umpire&clubID=$clubID_IN&assocID=$dref->{'intComp_AssocID'}">Delete</a>] <br>];  
  }
  $umpire_config ||= 'None';
	my $hash_value = AdminCommon::create_hash(0,0,0,$clubID_IN,0);

  return qq[
  
  <form action="$target" method="post">
  <input type="hidden" name="action" value="$form_action">
  <input type="hidden" name="clubID" value="$clubID_IN">
 <input type="hidden" name="hash" value="$hash_value">
  <table style="margin-left:auto;margin-right:auto;">
  <tr>
    <td class="formbg fieldlabel">Name:</td><td class="formbg">$club_name</td>
  </tr>
  <tr>
    <td class="formbg fieldlabel">External Key:</td><td class="formbg"><input type="text" name="club_extkey" value="$external_key" size="10"></td>
  </tr>
  <tr>
    <td class="formbg fieldlabel">Assoc Name:</td><td class="formbg">$assoc_name</td>
  </tr>
  <tr>
    <td class="formbg fieldlabel">Assoc Club Payments:</td><td class="formbg">$assoc_payment</td>
  </tr>
  <tr>
    <td class="formbg fieldlabel">Club payment Approval (0=No, 1=Yes):</td><td class="formbg"><input type="text" name="club_payment" value="$club_payment" size="10"></td>
  </tr>
  <tr>
    <td class="formbg fieldlabel">Club Fee Allocation(1=Inclusive, 2=User Pays):</td><td class="formbg"><input type="text" name="club_feeAllocation" value="$club_feeAllocation" size="10"></td>
  </tr>
  <tr>
    <td class="formbg fieldlabel">Assoc Fee Allocation:</td><td class="formbg">$assocFeeAllocation</td>
  </tr>
  <tr>
    <td class="formbg fieldlabel">Payment Email:</td><td class="formbg">$paymentEmail $clear</td>
  </tr>
  <tr>
    <td class="formbg" colspan="2" style="text-align:center;">
      <input type="submit" name="submit" value="$button_title">
    </td>
  </tr>
  </form>
  <tr>
    <td colspan="2" class="formbg"><br><hr style="color:white"></td>
  </tr>
  <tr>
    <td class="formbg fieldlabel">New Umpire Allocation:</td>
    <td class="formbg">
      <form action="$target" method="post">
        <input type="hidden" name="action" value="CLUB_SEARCH_umpire">
        <input type="hidden" name="clubID" value="$clubID_IN">
        <input type="text" name="assocID" value="" size="10"> (Assoc ID)
        <input type="submit" name="submit" value="Add">
      </form>
    </td>
  </tr>
  <tr>
    <td class="formbg fieldlabel" valign="top">Current Umpire Allocation:</td>
    <td class="formbg">$umpire_config</td>
  </tr>
  </table>
  ];
}

sub modify_club_details {
  my ($db, $target) = @_;
  my $clubID_IN = param('clubID') || 0;
  my $payment_IN = param('club_payment') || 0;
  my $feeAllocation_IN= param('club_feeAllocation') || 0;
  my $external_key_IN= param('club_extkey') || 0;
  $payment_IN = ($payment_IN == 1) ? 1 : 0;
  my $response_text = 'ERROR :: Invalid data passed in !';
  	
 	if (!AdminCommon::verify_hash()) {
		return("Error in Querystring hash");
	}  
  
  if ($clubID_IN)   {
    my $st = qq[
      UPDATE
        tblClub
      SET
        intApprovePayment = ?,
        intClubFeeAllocationType = ?,
        strExtKey = ?
      WHERE
        intClubID = ?
      LIMIT 1
    ];
    my $q = $db->prepare($st) or query_error($st);
    $q->execute(
        $payment_IN,
        $feeAllocation_IN,
        $external_key_IN,
        $clubID_IN
    ) or query_error($st);
    $response_text = "Club Updated OK";
  }
  return $response_text; 
}

sub setup_umpire_allocation {
  my ($db, $target) = @_;
  my $clubID_IN = param('clubID') || 0;
  my $assocID_IN = param('assocID') || 0;
  my $st_realm = qq[
    SELECT
      intRealmID
    FROM
      tblAssoc
    WHERE
      intAssocID = ?
  ];
  my $q_realm = $db->prepare($st_realm) or query_error($st_realm);
  $q_realm->execute($assocID_IN);
  my ($realmID) = $q_realm->fetchrow_array();
  my $st_club_assoc = qq[
    SELECT
      intAssocID
    FROM
     tblAssoc_Clubs
    WHERE
      intClubID = ?
  ];
  my $q_club_assoc = $db->prepare($st_club_assoc) or query_error($st_club_assoc);
  $q_club_assoc->execute($clubID_IN);
  my ($assocClubID) = $q_club_assoc->fetchrow_array();
  my $st_insert = qq[
    INSERT INTO tblUmpireLevelConfig (
      intUmpireEntityID,
      intUmpireLevel,
      intUmpireAssocID,
      intRealmID,
      intComp_AssocID,
      intComp_CompID,
      intSystemType,
      tTimeStamp
    )
    VALUES (
      ?,
      3,
      ?,
      ?,
      ?,
      0,
      1,
      now()
    )
  ];
  my $q_insert = $db->prepare($st_insert) or query_error($st_insert);
  $q_insert->execute($clubID_IN, $assocClubID, $realmID, $assocID_IN);
  edit_club_form($db, $target, 'CLUB_SEARCH_edit', $clubID_IN);
}

sub delete_umpire_allocation {
  my ($db, $target) = @_;
  my $clubID_IN = param('clubID') || 0;
  my $assocID_IN = param('assocID') || 0;
  	
 	if (!AdminCommon::verify_hash()) {
		return("Error in Querystring hash");
	} 

  my $st = qq[
    DELETE FROM 
      tblUmpireLevelConfig
    WHERE
      intUmpireEntityID = ?
      AND intComp_AssocID = ?
    LIMIT 1
  ];
  my $q = $db->prepare($st) or query_error($st);
  $q->execute($clubID_IN, $assocID_IN);
  edit_club_form($db, $target, 'CLUB_SEARCH_edit', $clubID_IN);
}

sub mark_club_as_deleted {
  my ($db, $target) = @_;
  my $clubID_IN = param('clubID') || 0;
  my $assocID_IN = param('assocID') || 0;
  
 	if (!AdminCommon::verify_hash()) {
		return("Error in Querystring hash");
	} 
	
  my $st = qq[
    UPDATE
      tblClub
    SET
      intRecStatus = $Defs::RECSTATUS_DELETED
    WHERE
      intClubID = ?
    LIMIT 1
  ];
  my $q = $db->prepare($st) or query_error($st);
  $q->execute($clubID_IN);
  display_club_search_list($db, '', $assocID_IN, $target);
}

sub mark_club_as_undeleted {
  my ($db, $target) = @_;
  my $clubID_IN = param('clubID') || 0;
  my $assocID_IN = param('assocID') || 0;
  	
 	if (!AdminCommon::verify_hash()) {
		return("Error in Querystring hash");
	} 
  
  my $st = qq[
    UPDATE
      tblClub
    SET
      intRecStatus = $Defs::RECSTATUS_ACTIVE
    WHERE
      intClubID = ?
    LIMIT 1
  ];
  my $q = $db->prepare($st) or query_error($st);
  $q->execute($clubID_IN);
  display_club_search_list($db, '', $assocID_IN, $target);
}

sub club_info
{
  my($db, $target, $memberID)=@_;
  	
 	if (!AdminCommon::verify_hash()) {
		return("Error in Querystring hash");
	} 
  
  my $body='';
  if($memberID){
 	 $body=edit_club_form($db, $target, 'add');
  }	
  else {
 	$body = "Need to select Club";	
  }
       return $body;
}

1;
