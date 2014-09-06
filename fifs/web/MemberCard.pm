#
# $Header: svn://svn/SWM/trunk/web/MemberCard.pm 10771 2014-02-21 00:20:57Z cgao $
#

package MemberCard;

require Exporter;
@ISA =  qw(Exporter);
@EXPORT = qw(handleMemberCard);
@EXPORT_OK = qw(handleMemberCard);

use lib qw(. ..);
use DBI;
use strict;
use CGI qw(:standard escape unescape);
use Defs;
use Utils;
use DeQuote;
use FormHelpers;
use Reg_common;
use PrintForm;
use Countries qw(getCountriesNameToData);
use SearchLevels;
use Seasons;
use AuditLog;
use ReportManager;

sub handleMemberCard {
  my($action, $Data, $client, $eID, $typeID)=@_;

  $action=$action || param('lktask') || 'LK_list';
	$client||=setClient($Data->{'clientValues'});
	my $db = $Data->{'db'};
  my $title='';

  my $body='';

  if($action eq 'MEMCARD_SET') {
		my $ctype_IN=param('ctID') || 0;
		my $v_IN=param('v') || 0;
		toggleToPrintFlag($Data, $ctype_IN, $eID, $v_IN);

		$action = 'MEMCARD_MLIST';
	}
  elsif($action eq 'MEMCARD_BU') {
		$body=update_cardBulk($Data, $client); 
		$action = 'MEMCARD_BL';
  }
  if($action eq 'MEMCARD_MLIST') {
		return ('','') if $typeID != $Defs::LEVEL_MEMBER;
		$body.=member_card_details($db, $action, $client, $eID, $Data); 
  }
  elsif($action eq 'MEMCARD_BC') {
		$body .= checkBulkPrint($Data, $client); 
		$title = 'Bulk Print - Confirmation';
  }
  elsif($action eq 'MEMCARD_BL') {
		$body .=show_bulk_options($Data, $client); 
		$title = 'Bulk Print';
  }
  $title ||= 'Member Cards';

  return ($body, $title);
}

# *********************SUBROUTINES BELOW****************************



sub member_card_details	{
	my ($db, $action, $client, $memberID, $Data) = @_;

	my $realmID=$Data->{'Realm'}||0;
	my $subtypeID=$Data->{'RealmSubType'} || 0;
  my $assocID=$Data->{'clientValues'}{'assocID'} || 0;
	my $target = 'printcard.cgi';

	my $st=qq[
		SELECT
			MCC.intMemberCardConfigID,
			MCC.strName,
			MCC.intRealmID,
			MCC.intSubRealmID,
			MCC.intAssocID,
			CP.intMemberID AS ToBePrinted, 
			MCCP.intProductID,
			MCCP.intTXNStatus,
			MCCT.intTypeID,
			MCCT.intActive

		FROM tblMemberCardConfig AS MCC
			LEFT JOIN tblCardToBePrinted AS CP
				ON (
					CP.intMemberCardConfigID = MCC.intMemberCardConfigID
					AND CP.intMemberID = ?
				)
			LEFT JOIN tblMemberCardConfigProducts AS MCCP
				ON MCCP.intMemberCardConfigID = MCC.intMemberCardConfigID
			LEFT JOIN tblMemberCardConfigMemberTypes AS MCCT
				ON MCCT.intMemberCardConfigID = MCC.intMemberCardConfigID
		WHERE 
			intRealmID = ?
			AND (
				intAssocID = 0
				OR intAssocID = ?)
	];
	my $q = $db->prepare($st);
	$q->execute($memberID, $realmID, $assocID);
	my %possiblecards = ();
	while(my $dref=$q->fetchrow_hashref())	{
    next if($dref->{'intSubRealmID'} and $dref->{'intSubRealmID'} != $subtypeID);
		$possiblecards{$dref->{'intMemberCardConfigID'}}{'data'} = $dref;
		$possiblecards{$dref->{'intMemberCardConfigID'}}{'products'}{$dref->{'intProductID'}} = $dref->{'intTXNStatus'} if $dref->{'intProductID'};
		$possiblecards{$dref->{'intMemberCardConfigID'}}{'types'}{$dref->{'intTypeID'}} = $dref->{'intActive'} if $dref->{'intTypeID'};
	}
	#If card has product dependencies check them for this member
	#Products 	
	
	## TC - CHanged intMemberID to intID 22/01/2010
	my %memberproducts = ();
	{
		my $st = qq[
			SELECT intProductID, intStatus
			FROM tblTransactions AS T
			WHERE intID = ?
		];
		my $q = $db->prepare($st);
		$q->execute($memberID);
		while(my ($prodID, $status) = $q->fetchrow_array())	{
			$memberproducts{$prodID} = $status || 0;
		}
		$q->finish();
	}
	my %membertypes = ();
	{
		my $defaultseasons = getDefaultAssocSeasons($Data);
		my $st = qq[
			SELECT 
				intPlayerStatus,
				intCoachStatus,
				intUmpireStatus,
				intMiscStatus,
				intVolunteerStatus,
				intOther1Status,
				intOther2Status

			FROM tblMember_Seasons_$realmID
			WHERE intMemberID = ?
				AND intAssocID = ?
				AND intSeasonID = $defaultseasons->{'currentSeasonID'}
				
		];
		my $q = $db->prepare($st);
		$q->execute($memberID, $assocID);
		while(my (
			$player, 
			$coach, 
			$umpire, 
			$other1, 
			$other2
			) = $q->fetchrow_array())	{
			
			$membertypes{$Defs::MEMBER_TYPE_PLAYER} ||= $player;
			$membertypes{$Defs::MEMBER_TYPE_COACH} ||= $coach;
			$membertypes{$Defs::MEMBER_TYPE_UMPIRE} ||= $umpire;
		}
		$q->finish();
	}
	
	my @possiblecards = ();
	CARD: for my $c (
		sort { $possiblecards{$a}{'data'}{'strName'} cmp $possiblecards{$b}{'data'}{'strName'} }
		keys %possiblecards)	{

		for my $p (keys %{$possiblecards{$c}{'products'}})	{
			if(!exists $memberproducts{$p}
				or ( $possiblecards{$c}{'products'}{$p}
					and $memberproducts{$p} != $possiblecards{$c}{'products'}{$p}
				)
			)	{
				delete $possiblecards{$c};
				next CARD;
			}
		}
		for my $t (keys %{$possiblecards{$c}{'types'}})	{
			if(!exists $membertypes{$t}
				or ( $possiblecards{$c}{'types'}{$t}
					and $membertypes{$t} != $possiblecards{$c}{'types'}{$t}
				)
			)	{
				delete $possiblecards{$c};
				next CARD;
			}
		}
		push @possiblecards, $possiblecards{$c}{'data'};
	}
	
	my $cardlist = '';
	my $unesc_client = unescape($client);
	for my $c (@possiblecards)	{
		my $tobeprinted = $c->{'ToBePrinted'}
			? qq[ Card needs to be Printed - (<a href="$Data->{'target'}?client=$client&amp;mid=$memberID&amp;ctID=$c->{'intMemberCardConfigID'}&amp;a=MEMCARD_SET&amp;v=0">Clear</a>)]
			: qq[ Card doesn't need to be Printed - (<a href="$Data->{'target'}?client=$client&amp;mid=$memberID&amp;ctID=$c->{'intMemberCardConfigID'}&amp;a=MEMCARD_SET&amp;v=1">Set</a>)];#'
		$cardlist.=qq[ 
			<div class="sectionheader">$c->{'strName'} </div>
			<form action="$target" style="display:inline;" target="membercardcard">
				<input type="hidden" name="client" value="$unesc_client">
				<input type="hidden" name="a" value="MEMCARD_prev">
				<input type="hidden" name="ids" value="$memberID">
				<input type="hidden" name="ctID" value="$c->{'intMemberCardConfigID'}">
				<input type="submit" value="Preview Card" class = "button generic-button" style = "margin-right:10px;">
			</form>
			<form action="$target" style="display:inline;" target="membercardcard" name="membercardcardpr">
				<input type="hidden" name="ids" value="$memberID">
				<input type="hidden" name="ctID" value="$c->{'intMemberCardConfigID'}">
				<input type="hidden" name="client" value="$unesc_client">
				<input type="hidden" name="a" value="MEMCARD_print">
				<input type="submit" value="Print Card" onclick="window.open('$target?client=$client&amp;a=MEMCARD_print&amp;ids=$memberID&amp;ctID=$c->{'intMemberCardConfigID'}','membercardcard','toolbar=no,location=no,status=no,menubar=no,scrollbars=none,titlebar=no,width=200,height=200');return false;" class = "button generic-button">
			</form>
			<div style = "clear:both;">$tobeprinted</div>
		];
	}

	my $printlog = member_card_printlog($db, $action, $client, $memberID, $Data) 
		|| ' No Cards Printed';
	my $body =qq[
			$cardlist

		<div class="sectionheader">Print Log</div>
		$printlog

	];
	return $body;
}

sub member_card_printlog {
	my ($db, $action, $client, $memberID, $Data) = @_;

	my $st = qq[
		SELECT 
			CP.intMemberCardPrintedID,
			CP.intMemberCardConfigID,	
			DATE_FORMAT(CP.dtPrinted, "%d/%m/%Y %H:%i") AS dtPrinted_FMT,
			MCC.strName	
		FROM 
			tblMemberCardPrinted AS CP
			INNER JOIN tblMemberCardConfig AS MCC
				ON CP.intMemberCardConfigID = MCC.intMemberCardConfigID
		WHERE 
			CP.intMemberID = ?
	];
	my $q = $db->prepare($st);
	$q->execute($memberID);
	my $rows = '';
	while(my $dref=$q->fetchrow_hashref())	{
		$rows .= qq[ 
			<tr>
				<td>$dref->{'dtPrinted_FMT'}</td>
				<td>$dref->{'strName'}</td>
			</tr>
		];
	}

	return ' No Cards Printed' if !$rows;
	my $body =qq[
		<table>
			<tr>
				<th>Printed</th>
				<th>Name</th>
			</tr>
			$rows
		</table>

	];

	return $body;
}


sub show_bulk_options {
	my ($Data, $client) = @_;

	my $realmID=$Data->{'Realm'}||0;
	my $subtypeID=$Data->{'RealmSubType'} || 0;
  my $assocID=$Data->{'clientValues'}{'assocID'} || 0;
  my $currentLevel=$Data->{'clientValues'}{'currentLevel'} || 0;

	my $subrealmwhere = $subtypeID
		? " AND MCC.intSubRealmID = $subtypeID "
		: '';
	my $cardtypes = '';
	{
		my $st=qq[
			SELECT DISTINCT
				MCC.intMemberCardConfigID,
				MCC.strName
			FROM tblMemberCardConfig AS MCC

			WHERE 
				intRealmID = $realmID
				AND (
					intAssocID = 0
					OR intAssocID = $assocID
				)
				AND intBulkPrintFromLevelID >= $currentLevel
				$subrealmwhere
			ORDER BY strName
		];
		$cardtypes = getDBdrop_down(
			'ctID',
			$Data->{'db'},
			$st,
			0,
			' ',
			1,
			0,
			''
		);
	}
 
	my $db=$Data->{'db'};
	my $unesc_client=unescape($client);

  my ($reports, undef) = get_recipienttype_details(
    $Data,
    'reports',
    $assocID,
    $currentLevel,
  );
  my $reports_dropdown = qq[
    Select a Saved Report:
    <select name="reportID">
    <option></option>
  ];
  foreach my $report (keys %{$reports}) {
    $reports_dropdown .= qq[<option value="$report">$reports->{$report}</option>];
  }
  $reports_dropdown .= qq[</select>];
  my $agegroups_dropdown = _get_agegroup_dropdown($Data, $assocID);
	my $resultHTML=qq[
		<p>Choose what you want to bulk print from the options below.  All the filters are additive.</p>
		<form action="$Data->{'target'}" method="POST">
      <table border="0">
        <tr>
          <td>
            <b>1. Select Card Type:</b> $cardtypes
          </td>
        </tr>
        <tr>
          <td>
            <b>2. Filter By:</b>
            <p>$reports_dropdown</p>
            <i>OR</i>
            <p>$agegroups_dropdown</p>
            <i>OR</i> <br>
			      <input type="checkbox" value = "1" name = "needtobeprinted"> Card need to be printed <br>
			      <input type="checkbox" value = "1" name = "notprinted"> Not printed already <br><br>
          </td>
        </tr>
        <tr>
          <td>
			      <b>3. Limit:</b>
			      <select name="limit" size="1">
				      <option value="20">20</option>
				      <option value="50">50</option>
				      <option value="100">100</option>
				      <option value="200">200</option>
				      <option value="500">500</option>
				      <option value="1000">1000</option>
				      <option value="0">No Limit</option>
			      </select><br><br>
          <td>
        </tr>
        <tr>
          <td>
			      <input type="submit" value="Generate Bulk Print" class = "button proceed-button">
			      <input type="hidden" name="client" value="$unesc_client">
			      <input type="hidden" name="a" value="MEMCARD_BC">
            <br><br>
			      <p><i>(Press the <b>'Generate Bulk Print'</b> button to generate a list of cards to be printed.)</i></p>
          </td>
        </tr>
      </table>
		</form>

	];
	return $resultHTML;
}

sub checkBulkPrint {
  my ($Data, $client)=@_;

	my $db = $Data->{'db'};
	my $notprinted = param('notprinted') || 0;
	my $needsprinting = param('needtobeprinted') || 0;
  my $reportID = param('reportID') || 0;
  my $agegroupID = param('agegroupID') || 0;
	my $inseason = param('inseason') || 1;
	my $ctID = param('ctID') || return qq[<p class="warningmsg">You must select a card type</p>];
	my $limit = param('limit') || 0;
	my $currentLevel = $Data->{'clientValues'}{'currentLevel'} || 0;
	my @unprintedIDs = ();	
	my $printable = 0;
  my $hide_mark_as_printed = 0;
  if ($reportID) {
    $hide_mark_as_printed = 1;
    my $reportdata = getSavedReportData($Data, $reportID);
    for my $d (@{$reportdata}) {
      next unless ($d->{'intMemberID'});
      push @unprintedIDs, $d->{'intMemberID'} if ($printable < $limit or $limit == 0);
      $printable++;
    }
  }
  elsif ($agegroupID) {
    $hide_mark_as_printed = 1;
    my $agegroupdata = get_age_group_member_data($Data, $agegroupID);
    for my $d (@{$agegroupdata}) {
      next unless ($d->{'intMemberID'});
      push @unprintedIDs, $d->{'intMemberID'} if ($printable < $limit or $limit == 0);
      $printable++;
    }
  }
  else {
	  my ($from_levels, $where_levels, $select_levels, $current_from, $current_where)=getLevelQueryStuff($currentLevel,  $Defs::LEVEL_MEMBER, $Data,0,1);

	  my $clubID = (
			$Data->{'clientValues'}{'clubID'} 
			and $Data->{'clientValues'}{'clubID'} != $Defs::INVALID_ID
		) 
		? $Data->{'clientValues'}{'clubID'} 
		: 0;

	  my $MStablename = "tblMember_Seasons_$Data->{'Realm'}";
	  my $assocSeasonWHERE = ($from_levels =~ /tblClub/) ? qq[ AND $MStablename.intClubID>0] : qq[ AND $MStablename.intClubID=0];
	  $assocSeasonWHERE = qq[ AND $MStablename.intClubID = $clubID] if $clubID;

	  my $seasonfrom = qq[
		  INNER JOIN $MStablename ON (
			  $MStablename.intMemberID = tblMember_Associations.intMemberID 
			  AND $MStablename.intAssocID = tblMember_Associations.intAssocID 
			  AND $MStablename.intMSRecStatus=1 
			  AND IF(
			  tblAssoc.intAllowSeasons=1, 
				  $MStablename.intSeasonID > 0, 
				  $MStablename.intSeasonID = tblAssoc.intCurrentSeasonID
			  )
		  )
	  ];

	  if (!$inseason	)	{
		  $seasonfrom = '';
		  $assocSeasonWHERE= '';
	  }

	  my $needsprintingSQL = '';
	  if($needsprinting)	{
		  $needsprintingSQL = qq[
			  INNER JOIN tblCardToBePrinted AS CBP ON (
				  tblMember.intMemberID = CBP.intMemberID
				  AND CBP.intMemberCardConfigID = $ctID
			  )
		  ];
	  }

	  #Check card config - Member Type
	  my $typejoins = '';
	  {
		  my $st = qq[
			  SELECT intTypeID,
				  intActive
			  FROM 	tblMemberCardConfigMemberTypes
			  WHERE intMemberCardConfigID = ?
		  ];
		  my $q = $Data->{'db'}->prepare($st);
		  $q->execute($ctID);
		  my %fieldname = (
			  $Defs::MEMBER_TYPE_PLAYER => 'intPlayerStatus',
			  $Defs::MEMBER_TYPE_COACH => 'intCoachStatus',
			  $Defs::MEMBER_TYPE_UMPIRE => 'intUmpireStatus',
			  $Defs::MEMBER_TYPE_MISC => 'intMiscStatus',
			  $Defs::MEMBER_TYPE_VOLUNTEER => 'intVolunteerStatus',
		  );
		  while (my ($type, $active) = $q->fetchrow_array())	{
			  next if !$type;
			  next if !$fieldname{$type};
			  $typejoins .= " AND $MStablename.".$fieldname{$type}." = 1 ";
	  	}
	  }

	  #Check card config - Products
	  my $prodjoins = '';
	  {
		  my $st = qq[
			  SELECT intProductID,
				  intTXNStatus	
			  FROM 	tblMemberCardConfigProducts
			  WHERE intMemberCardConfigID = ?
		  ];
		  my $q = $Data->{'db'}->prepare($st);
		  $q->execute($ctID);
		  my $prodsubjoins = '';
		  while (my ($prodID, $status) = $q->fetchrow_array())	{
			  next if !$prodID;
			  my $statussql = $status
				? " AND T.intStatus = $status "
				: '';
			  $prodsubjoins .= ' OR ' if $prodsubjoins;
			  $prodsubjoins .= " (T.intProductID = $prodID $statussql ) ";
		  }
		  $prodjoins = qq[
			INNER JOIN tblTransactions AS T 
			  ON (
				  tblMember.intMemberID  = T.intID
				  AND T.intTableType = $Defs::LEVEL_MEMBER
				  AND tblAssoc.intAssocID = T.intAssocID
				  AND ($prodsubjoins)
			  )
		  ] if $prodsubjoins;
	  }
    $limit = ($limit and $limit > 0) ? qq[LIMIT $limit] : '';
	  my $st=qq[
		  SELECT tblMember.intMemberID, MAX(CP.dtPrinted)
		  FROM $from_levels $current_from
			  $seasonfrom
			  $needsprintingSQL
		  $prodjoins
		  LEFT JOIN tblMemberCardPrinted AS CP ON (
			  CP.intMemberID = tblMember.intMemberID
			  AND CP.intMemberCardConfigID = $ctID
		  )
		  WHERE  $where_levels $current_where $assocSeasonWHERE
			  $typejoins
		  GROUP BY tblMember.intMemberID
      $limit
	  ];

    my $query = $Data->{'db'}->prepare($st) or query_error($st);
    $query->execute() or query_error($st);
	  my $total=0;
    while(my($id,$printed)=$query->fetchrow_array())	{
		  next if !$id;
		  next if ($notprinted and $printed);
		  $total++;
		  push @unprintedIDs, $id;
		  $printable++;
		  #last if($limit and $printable>= $limit);
	  }
  }

	my $ids = join(',',@unprintedIDs);
	my $target=$Data->{'target'};
	my $unesc_client=unescape($client);
	my $cardtarget = 'printcard.cgi';
  my $limit_text = ($limit) ? $limit : "No limit";
	my $resultHTML = qq[
		<p>
		<span class="label">Cards to be printed: </span> $printable<br>
		<span class="label">Limited to: </span> $limit_text<br>
		<div class="sectionheader">Instructions</div>
		<ol>
			<li>Click the <b>'View Cards'</b> button to load the cards in a new window. This may take some time depending on the number of cards you are printing, please be patient.</li><br>
			<li>Print the cards using your browser's print options.  eg. 'File' menu, then 'Print'.</li><br>
  ]; #'#
	$resultHTML .= qq[
			<li>Press the <b>'Mark Cards as Printed'</b> button to register that the cards have been printed.  <b>You must perform this step or the system will not know that the passes have been printed</b>.</li><br>
  ] unless ($hide_mark_as_printed);
	$resultHTML .= qq[
		</ol>
    <form action="$cardtarget" style="display:inline;" target="bulkcard" method="POST">             				
      <input type="hidden" name="client" value="$unesc_client">
      <input type="hidden" name="a" value="MEMCARD_bulk">
      <input type="hidden" name="ids" value="$ids">
      <input type="hidden" name="ctID" value="$ctID">
      <input type="submit" value="View Cards" class = "button generic-button">
    </form>
  ];
	$resultHTML .= qq[
    <form action="$target" style="display:inline;" method="POST">             
      <input type="hidden" name="a" value="MEMCARD_BU">
      <input type="hidden" name="client" value="$unesc_client">
      <input type="hidden" name="ids" value="$ids">
      <input type="hidden" name="ctID" value="$ctID">
      <input type="submit" value="Mark Cards as Printed" class = "button generic-button">
    </form>

	] unless ($hide_mark_as_printed);
	$resultHTML = qq[ <div class="warningmsg">There are no cards able to be printed</div> ] if !$printable;
	return $resultHTML;
}


sub update_cardBulk	{
	my($Data, $client)=@_;
	my $ids=param('ids') || '';
	my $cardtypeID = param('ctID') || '';
	return '' if $ids=~/[^\d,]/;
	my @ids=split /,/,$ids;
  my $st = qq[
    INSERT INTO tblMemberCardPrinted (
      intMemberCardConfigID,
      intMemberID,
      dtPrinted,
      strUsername,
      intQty,
      intCount
    )
    VALUES (
      ?,
      ?,
      NOW(),
			?,
      1,
      1
    )
  ];
  my $q= $Data->{'db'}->prepare($st);
	for my $id (@ids)	{
		$q->execute(
			$cardtypeID,
			$id,
			$Data->{'UserName'},
		);
	}
	{
		my $st_del = qq[
			DELETE FROM tblCardToBePrinted
			WHERE intMemberCardConfigID = $cardtypeID
				AND intMemberID IN ($ids)
		];
		$Data->{'db'}->do($st_del);
	}
  auditLog($cardtypeID, $Data, 'Mark Bulk Print', 'Card Printing');
	my $resultHTML=qq[
		<p class="warningmsg" >Card printed status updated</p>
	];
	return $resultHTML;
}

sub toggleToPrintFlag	{
	my ($Data, $cardtypeID, $memberID, $add) = @_;

	$add ||= 0;

	my $st = '';
  my $type = '';
	if($add)	{
		$st = qq[ INSERT INTO tblCardToBePrinted (intMemberID, intMemberCardConfigID) VALUES (?,?)];
    $type = 'Set';
	}
	else	{
		$st = qq[ DELETE FROM tblCardToBePrinted WHERE intMemberID = ? AND intMemberCardConfigID = ?];
    $type = 'Clear';
	}
	my $q = $Data->{'db'}->prepare($st);
	$q->execute($memberID, $cardtypeID);
	$q->finish();

  unless ($Data->{'NoClearActionRequired'} == 1) {
    auditLog($cardtypeID, $Data, '$type', 'Card Printing');
  }

	return '';
}

sub _get_agegroup_dropdown {
  my ($Data, $assocID) = @_;
  my $season_data = getDefaultAssocSeasons($Data);
  my $body = '';
  my $st = qq[
    SELECT
      intAgeGroupID,
      strAgeGroupDesc,
      intAgeGroupGender
    FROM
      tblAgeGroups
    WHERE
      intRecStatus <> $Defs::RECSTATUS_DELETED
      AND intAssocID IN (0, $assocID)
      AND intRealmID = ?
    ORDER BY
      strAgeGroupDesc
  ];
  my $q = $Data->{'db'}->prepare($st);
  $q->execute($Data->{Realm});
  $body = qq[
    Select an agegroup:
    <select name="agegroupID">
      <option></option>
  ];
  while (my $href = $q->fetchrow_hashref()) {
    my $gender = ($href->{strAgeGroupGender}) ? qq[- $href->{strAgeGroupGender}] : '';
    $body .= qq[
      <option value="$href->{intAgeGroupID}">$href->{strAgeGroupDesc} $gender</option>
    ];
  }
  $body .= qq[
    </select>
  ];
  return $body;
}


sub get_age_group_member_data {
  my ($Data, $age_groupID) = @_;
  $age_groupID ||= 0;
  my $assocID = $Data->{'clientValues'}{'assocID'} || 0;
  my $season_data = getDefaultAssocSeasons($Data);
  my $seasonID = $season_data->{currentSeasonID} || 0;
  my $st = qq[
    SELECT
      intMemberID
    FROM
      tblMember_Seasons_$Data->{Realm}
    WHERE
      intSeasonID = ?
      AND intMSRecstatus <> $Defs::RECSTATUS_DELETED
      AND intAssocID = ?
      AND intClubID = 0
      AND intPlayerAgeGroupID = ?
  ];
  my $q = $Data->{db}->prepare($st);
  $q->execute($seasonID, $assocID, $age_groupID);
  my @members = ();
  while (my $href = $q->fetchrow_hashref()) {
    push @members, {intMemberID => $href->{'intMemberID'}};
  }
  return \@members;
}

1;
