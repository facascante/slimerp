#
# $Header: svn://svn/SWM/trunk/web/ClearancesList.pm 8530 2013-05-22 05:57:47Z cgao $
#

package ClearancesList;

## LAST EDITED -> 10/09/2007 ##

require Exporter;
@ISA =  qw(Exporter);
@EXPORT = qw(listClearances listClearanceSettings listOfflineClearances listClearanceHoldingBay );
@EXPORT_OK = qw(listClearances listClearanceSettings listOfflineClearances listClearanceHoldingBay );

use strict;
use CGI qw(param unescape escape);
use lib '.', '..', '../..', "../comp", '../RegoForm', "../dashboard", "../RegoFormBuilder",'../PaymentSplit', "../user";
use Defs;
use Reg_common;
use FieldLabels;
use Utils;
use Date::Calc qw(check_date Today);
use FormHelpers;
use CustomFields;
use GridDisplay;
use InstanceOf;

use Seasons;

sub listClearanceSettings	{

	my($Data, $intID, $intTypeID) = @_;
	$intID ||= 0;
	$intTypeID ||= 0;
    my $lang = $Data->{'lang'};
	my $txt_Clr = $Data->{'SystemConfig'}{'txtCLR'} || 'Clearance';
	my $db = $Data->{'db'};

	my %textLabels = (
		'addClearanceSettings' => $lang->txt("Add $txt_Clr Settings"),
		'autoApproval' => $lang->txt('Auto Approval'), 
		'clearance' => $lang->txt($txt_Clr),
		'defaultFee' => $lang->txt('Default Fee'), 
		'dobEnd' => $lang->txt('DOB End'),
		'dobStart' => $lang->txt('DOB Start'), 
		'listOfClearanceSettings' => $lang->txt("List of $txt_Clr Settings"),
		'noClearanceSettingsFound' => $lang->txt("No $txt_Clr Settings can be found using this filter."),
		'ruleAppliesTo' => $lang->txt('Rule Applies To'), 
		'clearanceType' => $lang->txt("Rule for $txt_Clr Type"), 
	);

	my $clearanceStatus = $Data->{'ViewClrStatus'} || $Defs::CLR_STATUS_PENDING || 0;
	my $st = qq[
		SELECT CS.*, DATE_FORMAT(dtDOBStart,'%d/%m/%Y') AS dtDOBStart, DATE_FORMAT(dtDOBEnd,'%d/%m/%Y') AS dtDOBEnd 
		FROM tblClearanceSettings as CS
		WHERE intID = ?
			AND intTypeID = ?
		ORDER BY dtDOBStart
	];

	my $query = $db->prepare($st);
	$query->execute(
		$intID,
		$intTypeID,
	);

	my $resultHTML = ''; 

	my $client=setClient($Data->{'clientValues'});

	my @rowdata = ();
  while (my $dref = $query->fetchrow_hashref) {
		$dref->{ruleDirection} = $Defs::ClearanceDirections{$dref->{intRuleDirection}} || '';
		$dref->{ruleDirection} .= qq[ (] . $lang->txt('for Type') . qq[: $Defs::ClearanceRuleTypes{$Data->{'Realm'}}{$dref->{intClearanceType}})] if ($dref->{intClearanceType});
		$dref->{delLink} = qq[<a href="$Data->{target}?a=CLRSET_DEL&amp;client=$client&amp;csID=$dref->{intClearanceSettingID}"><img border="0" src="images/sml_delete_icon.gif"></a>];

		$dref->{'dtDOBStart'} = '' if $dref->{'dtDOBStart'} eq '00/00/0000';
		$dref->{'dtDOBEnd'} = '' if $dref->{'dtDOBEnd'} eq '00/00/0000';

		push @rowdata, {
			approval => $Defs::ClearanceApprovals{$dref->{intAutoApproval}} || '',
			ruleDirection => $dref->{'ruleDirection'},
			delLink => $dref->{'delLink'} || '',
			dtDOBStart => $dref->{'dtDOBStart'},
			dtDOBEnd => $dref->{'dtDOBEnd'},
			curDefaultFee => $dref->{'curDefaultFee'},
			SelectLink => "$Data->{'target'}?client=$client&amp;a=CLRSET_EDIT&amp;csID=$dref->{intClearanceSettingID}",
			id => $dref->{'intClearanceSettingID'},
		};
  }
  $query->finish;
	my $addLink= qq[<div class="changeoptions"><span class = "button-small generic-button"><a href="$Data->{'target'}?client=$client&amp;a=CLRSET_ADD">] . $lang->txt('Add') . qq[</a></span></div>];

  my @headers = (
    {
      type => 'Selector',
      field => 'SelectLink',
    },
    {
      name =>   $Data->{'SystemConfig'}{'clrHide_curDevelFee'} ? '' : $lang->txt('Default Fee'),
      field =>  'curDefaultFee',
    },
    {
      name =>   $lang->txt('Auto Approval'),
      field =>  'approval',
    },
    {
      name =>   $lang->txt('Rule Applies To'),
      field =>  'ruleDirection',
    },
    {
      name =>   $lang->txt('DOB Start'),
      field =>  'dtDOBStart',
    },
    {
      name =>   $lang->txt('DOB End'),
      field =>  'dtDOBEnd',
    },
    {
      name =>   $lang->txt('Delete?'),
      field =>  'delLink',
			type => 'HTML',
    },
	);

  my $grid  = showGrid(
    Data => $Data,
    columns => \@headers,
    rowdata => \@rowdata,
    gridid => 'grid',
    width => '99%',
  );

	$resultHTML = qq[ 
		$grid
	];

	my $title=$addLink . $textLabels{'listOfClearanceSettings'};
  return ($resultHTML,$title);
}

sub listOfflineClearances {

	my($Data) = @_;

	my $intID = getID($Data->{'clientValues'}, $Data->{'clientValues'}{'currentLevel'});

	my $db = $Data->{'db'};

	my $lang = $Data->{'lang'};
	my %textLabels = (
			'all' => $lang->txt('All'),
			'applicationDate' => $lang->txt('Application Date'),
			'approved' => $lang->txt('Approved'),
			'cancelled' => $lang->txt('Cancelled'),
			'clearanceRefNo' => $lang->txt('Clearance Ref. No.'),
			'createdBy' => $lang->txt('Created by'),
			'denied' => $lang->txt('Denied'),
			'dob' => $lang->txt('Date of Birth'), 
			'fromClub' => $lang->txt('From Club'),
			'listClearances' => $lang->txt('List Offline/Manual Clearances'),
			'member' => $lang->txt('Member'),
			'memberName' => $lang->txt('Member Name'),
			'noClearanceFound' => $lang->txt('No Clearances can be found with this filter.'),
			'only100Shown'  => $lang->txt('NOTE: Only 100 Offline/Manual Clearances are shown.  You may need to apply more filters to view a specific record'),
			'overallStatus' => $lang->txt('Overall Status'), 
			'pending' => $lang->txt('Pending'),
			'records' => $lang->txt('records'),
			'showing' => $lang->txt('Showing'),
			'status' => $lang->txt('Status'),
			'toClub' => $lang->txt('To Club'),
			'transferWarning' => $lang->txt(q[Clearances for players transferring into clubs from other leagues will not appear below unless the clearance is approved and the player details are transferred to the new league/club]),
			'year' => $lang->txt('Year'),
	);

  my $intAllowClubClrAccess = 1;
#  my $assocObj = getInstanceOf($Data, 'assoc', $Data->{'clientValues'}{'assocID'});
#	if($assocObj)	{
#		( $intAllowClubClrAccess) = $assocObj->getValue([ 'intAllowClubClrAccess', ]);
#	}

#  $intAllowClubClrAccess ||= 0;
#  $intAllowClubClrAccess = 1 if ($Data->{'clientValues'}{'authLevel'}>=$Defs::LEVEL_ASSOC);

  my $intTypeID = $Data->{'clientValues'}{'currentLevel'};

	my $clearanceStatus = $Data->{'ViewClrStatus'} || $Defs::CLR_STATUS_PENDING || 0;
	$clearanceStatus = $Defs::CLR_STATUS_PENDING if $clearanceStatus == 100;
	my $membername= $Data->{'ViewClrMName'} || '';
	my $fromclub= $Data->{'ViewClrFromClub'} || '';
	my $toclub= $Data->{'ViewClrToClub'} || '';
	my $clryear= $Data->{'ViewClrYear'} || '';
	$clryear = '' if ($clryear !~ /^\d*$/);

	$intID = getID($Data->{'clientValues'}) || 0; #$Data->{'clientValues'}{'clubID'} if ($Data->{'clientValues'}{'currentLevel'} == $Defs::LEVEL_CLUB);

	my $st = qq[
		SELECT DISTINCT C.*, DATE_FORMAT(C.dtApplied,"%d/%m/%Y") AS dtApplied, CONCAT(M.strLocalSurname, ", ", M.strLocalFirstname) as MemberName, IF(SourceEntity.intClubID, SourceEntity.strName, strSourceEntityName) as SourceEntityName, IF (DestinationEntity.intClubID, DestinationEntity.strName, strDestinationEntityName) as DestinationEntityName, DATE_FORMAT(M.dtDOB,"%d/%m/%Y") AS DOB, YEAR(dtApplied) AS clrYear
		FROM tblClearance as C 
			INNER JOIN tblPerson as M ON (M.intPersonID = C.intPersonID) 
			LEFT JOIN tblClub as SourceEntity ON (SourceEntity.intClubID = C.intSourceEntityID)
			LEFT JOIN tblClub as DestinationEntity ON (DestinationEntity.intClubID = C.intDestinationEntityID)
                WHERE 
			C.intCreatedFrom IN ($Defs::CLR_TYPE_SWC, $Defs::CLR_TYPE_MANUAL)
			AND C.intRealmID = ?
	ORDER BY C.intClearanceID 
	];

	my $query = $db->prepare($st) or query_error($st);
	$query->execute(
		$Data->{'clientValues'}{'assocID'},
		$Data->{'Realm'},
	);

	my $resultHTML = qq[<span style="font-size:10px;"><i>$textLabels{'transferWarning'}</i></span><br><br>];  #'

	my $client=setClient($Data->{'clientValues'});

  my $cnt = 0;
	my @rowdata = ();
  while (my $dref = $query->fetchrow_hashref) {
		next if $dref->{intRecStatus} == -1;
    $dref->{'intClearanceStatus_RAW'} = $dref->{'intClearanceStatus'};
		$dref->{createdFrom} = $Defs::ClearanceTypes{$dref->{intCreatedFrom}};
		my %tempClientValues = getClient($client);
		$tempClientValues{memberID} = $dref->{intPersonID};
		$tempClientValues{currentLevel} = $Defs::LEVEL_MEMBER;
		my $tempClient = setClient(\%tempClientValues);
		my $action=($Data->{'SystemConfig'}{'DefaultListAction'} || 'DT') eq 'SUMM' ? 'M_SEL_l' : 'M_HOME';

		$dref->{overallstatus} = $Defs::clearance_status{$dref->{intClearanceStatus}} || 'P';
    $cnt++;

    my %row = ();
    for my $i (qw(MemberName DOB SourceEntityName DestinationEntityName updatestatus overallstatus dtApplied createdFrom intClearanceID clrYear intClearanceStatus_RAW ))  {
      $row{$i} = $dref->{$i};
    }
    $row{'id'} = $dref->{'intClearanceID'}.$cnt;
    $row{'SelectLink'} = "$Data->{'target'}?client=$tempClient&amp;a=$action";
    push @rowdata, \%row;
  }
  $query->finish;

	my $checked_approved = $clearanceStatus == $Defs::CLR_STATUS_APPROVED ? 'SELECTED' : '' ;
	my $checked_pending = $clearanceStatus == $Defs::CLR_STATUS_PENDING ? 'SELECTED' : '' ;
	my $checked_denied= $clearanceStatus == $Defs::CLR_STATUS_DENIED ? 'SELECTED' : '' ;
	my $checked_cancelled= $clearanceStatus == $Defs::CLR_STATUS_CANCELLED ? 'SELECTED' : '' ;
	my $checked_all= $clearanceStatus == 99 ? 'SELECTED' : '' ;
        my $line=qq[
        <div class="showrecoptions" style="float:right;">
        <script language="JavaScript1.2" type="text/javascript" src="js/jscookie.js"></script>
                <form action="#" onsubmit="return false;" name="recoptions">
    <span class="dinbold">$textLabels{'showing'}</span>&nbsp;$textLabels{'Name'}:&nbsp;<input type="text" name="membername" value="$membername" size="10" id = "id_surname">&nbsp;
    $textLabels{'fromClub'}:&nbsp;<input type="text" name="fromclub" value="$fromclub" size="10" id = "id_fromclub">&nbsp;
    $textLabels{'toClub'}:&nbsp;<input type="text" name="toclub" value="$toclub" size="10" id = "id_toclub">&nbsp;
  ];
  $line .= qq[$textLabels{'year'}:&nbsp;<input type="text" name="clryear" value="$clryear" size="5" id = "id_clryear">&nbsp;] if (exists $Data->{'SystemConfig'}{'clrClearanceYear'});
  $line .= qq[<input type="hidden" name="clryear" value="0">] if (! exists $Data->{'SystemConfig'}{'clrClearanceYear'});
	$line .= qq[
		$textLabels{'status'}:
				<select name="clearanceStatus" size="1" style="font-size:10px;" id = "dd_clearanceStatus">
					<option $checked_approved value="$Defs::CLR_STATUS_APPROVED">$textLabels{'approved'}</option>
					<option $checked_pending value="$Defs::CLR_STATUS_PENDING">$textLabels{'pending'}</option>
					<option $checked_denied value="$Defs::CLR_STATUS_DENIED">$textLabels{'denied'}</option>
					<option $checked_cancelled value="$Defs::CLR_STATUS_CANCELLED">$textLabels{'cancelled'}</option>
					<option $checked_all value="99">$textLabels{'all'}</option>
				</select> $textLabels{'records'}
                <input type="button" value="Filter" class="button-small generic-button" onclick="SetCookie('SWOMCLRREC',document.recoptions['clearanceStatus'].options[document.recoptions['clearanceStatus'].selectedIndex].value,30); SetCookie('SWOMCLRREC_mn',document.recoptions['membername'].value,30);SetCookie('SWOMCLRREC_year',document.recoptions['clryear'].value,30);SetCookie('SWOMCLRREC_toclub',document.recoptions['toclub'].value,30);SetCookie('SWOMCLRREC_fromclub',document.recoptions['fromclub'].value,30);document.location.reload();return true;">
                </form>
        </div><br><br>
	];

	my @headers = (
    {
      type => 'Selector',
      field => 'SelectLink',
    },
    {
      name =>   $lang->txt('Name'),
      field =>  'MemberName',
    },
    {
      name =>   $lang->txt('Date of Birth'),
      field =>  'DOB',
    },
    {
      name =>   $lang->txt('From Club'),
      field =>  'SourceEntityName',
    },
    {
      name =>   $lang->txt('To Club'),
      field =>  'DestinationEntityName',
    },
    {
      name =>   $lang->txt("Overall status"),
      field =>  'overallstatus',
    },
    {
      name =>   $lang->txt("Application Date"),
      field =>  'dtApplied',
    },
    {
      name =>   $lang->txt("Created By"),
      field =>  'createdFrom',
    },
    {
      name =>   $lang->txt("Ref. No."),
      field =>  'intClearanceID',
      width => 60,
    },
  );

  my $filterfields = [
    {
      field => 'MemberName',
      elementID => 'id_surname',
      type => 'regex',
    },
    {
      field => 'SourceEntityName',
      elementID => 'id_fromclub',
      type => 'regex',
    },
    {
      field => 'DestinationEntityName',
      elementID => 'id_toclub',
      type => 'regex',
    },
    {
      field => 'clrYear',
      elementID => 'id_clryear',
      type => 'regex',
    },
    {
      field => 'intClearanceStatus_RAW',
      elementID => 'dd_clearanceStatus',
      allvalue => '99',
    },
  ];

  my $grid  = showGrid(
    Data => $Data,
    columns => \@headers,
    rowdata => \@rowdata,
    gridid => 'grid',
    width => '99%',
    height => 700,
    filters => $filterfields,
  );



	$resultHTML .= qq[ 
		<div>$line</div>
		$grid
	];

	my $title=$textLabels{'listClearances'};
  return ($resultHTML,$title);
}


sub listClearances	{

	my($Data) = @_;
	my $txt_Clr = $Data->{'SystemConfig'}{'txtCLR'} || 'Clearance';
	my $showAll=param('showAll') || 0;

	my $intID = getID($Data->{'clientValues'}, $Data->{'clientValues'}{'currentLevel'});

	my $db = $Data->{'db'};

    my $lang = $Data->{'lang'};
    my %textLabels = (
			'ClearanceID' => $lang->txt('Clearance Ref'), 
			'all' => $lang->txt('All'),
			'applicationDate' => $lang->txt('Application Date'),
			'approved' => $lang->txt('Approved'),
			'awaitingApprovalFromLevel' => $lang->txt('Awaiting Approval from this level'),
			'awaitingYourApproval' => $lang->txt('AWAITING YOUR APPROVAL'),
			'cancelled' => $lang->txt('Cancelled'),
			'dateDue' => $lang->txt('Date Due'),
			'denied' => $lang->txt('Denied'),
			'dob' => $lang->txt('Date of Birth'), 
			'filter' => $lang->txt('Filter'),
			'listClearances' => $lang->txt("List Offline/Manual $txt_Clr".'s'),
			'listClrRequests' => $lang->txt("List $txt_Clr Requests"),
			'listOfClearances' => $lang->txt("List of $txt_Clr".'s'),
			'noClearancesFound' => $lang->txt("No $txt_Clr".'s can be found with this filter.'),
			'notYet' => $lang->txt('Not yet for your approval'),
			'pending' => $lang->txt('Pending'),
			'records' => $lang->txt('records'),
			'selected' => $lang->txt('SELECTED'),
			'showing' => $lang->txt('Showing'),
			'status' => $lang->txt('Status'),
			'surname' => $lang->txt('Surname'),
			'fromClub' => $lang->txt('From Club'),
      'toClub' => $lang->txt('To Club'),
      'year' => $lang->txt('Year'),
      'Name' => $lang->txt('Name'),
    );

  my ( $intAllowClubClrAccess) = 1;
#  my $assocObj = getInstanceOf($Data, 'assoc', $Data->{'clientValues'}{'assocID'});
#	if($assocObj)	{
#		( $intAllowClubClrAccess) = $assocObj->getValue([ 'intAllowClubClrAccess', ]);
#	}

#	$intAllowClubClrAccess ||= 0;
#	$intAllowClubClrAccess = 1 if ($Data->{'clientValues'}{'authLevel'}>=$Defs::LEVEL_ASSOC);

	my $intTypeID = $Data->{'clientValues'}{'currentLevel'};

	my $clearanceStatus = $Data->{'ViewClrStatus'} || $Defs::CLR_STATUS_PENDING || 0;
	my $membername= $Data->{'ViewClrMName'} || '';
	my $fromclub= $Data->{'ViewClrFromClub'} || '';
	my $toclub= $Data->{'ViewClrToClub'} || '';
	my $clryear= $Data->{'ViewClrYear'} || $Data->{'SystemConfig'}{'clrClearanceYear'} || '';
	$clryear = '' if ($clryear !~ /^\d*$/);

	my $pathWhere = $showAll ? '' : qq[
			AND CP.intTypeID = $intTypeID
			AND CP.intID = $intID
	];

	
	my $st = qq[
			SELECT C.*, DATE_FORMAT(C.dtApplied,"%d/%m/%Y") AS dtApplied, C.dtApplied as dtApplied_RAW, CP.intClearanceStatus as PathStatus, CP.intClearancePathID, CONCAT(M.strLocalSurname, ", ", M.strLocalFirstname) as MemberName, SourceEntity.strName as SourceEntityName, DestinationEntity.strName as DestinationEntityName,  DATE_FORMAT(M.dtDOB,"%d/%m/%Y") AS DOB, M.dtDOB AS DOB_RAW, CP.intTypeID, CP.intID, 
				IF(C.intCurrentPathID = CP.intClearancePathID AND C.intClearanceStatus  = $Defs::CLR_STATUS_PENDING,1,0) AS ThisLevel
			FROM tblClearance as C 
				INNER JOIN tblClearancePath as CP ON (CP.intClearanceID = C.intClearanceID) 
				INNER JOIN tblPerson as M ON (M.intPersonID = C.intPersonID) 
				LEFT JOIN tblClub as SourceEntity ON (SourceEntity.intClubID = C.intSourceEntityID)
				LEFT JOIN tblClub as DestinationEntity ON (DestinationEntity.intClubID = C.intDestinationEntityID)
			WHERE C.intRealmID = $Data->{'Realm'}
				$pathWhere
	];
  $st .= qq[
                        AND intClearanceYear = $clryear
	] if $clryear;
warn($st);

	if ($showAll)	{
		$st .= qq[ GROUP BY C.intClearanceID ORDER BY MemberName, dtApplied, C.intClearanceID ];
	}else {

		$st .= qq[ ORDER BY intClearanceID desc ];
	}
	my $query = $db->prepare($st) or query_error($st);
	$query->execute or query_error($st);

	my $resultHTML = ''; 

	my $client=setClient($Data->{'clientValues'});

	my @rowdata = ();
	my $hasDateDue=0;
	my $cnt = 0;
  while (my $dref = $query->fetchrow_hashref) {
		next if $dref->{intRecStatus} == -1;
		$dref->{'intClearanceStatus_RAW'} = $dref->{'intClearanceStatus'};
		$dref->{'intClearanceStatus_RAW'} = 100 if $dref->{'ThisLevel'};
		$dref->{'intClearanceStatus_RAW_filter'} = $dref->{'intClearanceStatus_RAW'};
		
		if($clearanceStatus==0) {
		$dref->{'intClearanceStatus_RAW_filter'} = 0 if($dref->{'intClearanceStatus_RAW_filter'} == 100);
		}
		$dref->{updatestatus} = $dref->{intCurrentPathID} == $dref->{intClearancePathID} 
            ? ($dref->{PathStatus} 
                ? $lang->txt($Defs::clearance_status{$dref->{PathStatus}}) 
                : qq[<a href="$Data->{'target'}?client=$client&amp;a=CL_details&amp;cID=$dref->{intClearanceID}&amp;cpID=$dref->{intClearancePathID}"><b>--$textLabels{'awaitingYourApproval'}--</b></a>]) 
            : '';
		$dref->{updatestatus} = $dref->{intCurrentPathID} > $dref->{intClearancePathID} 
            ? $lang->txt($Defs::clearance_status{$dref->{PathStatus}}) 
            : '' if ($dref->{updatestatus} eq '');
		$dref->{updatestatus} = $dref->{intCurrentPathID} < $dref->{intClearancePathID} 
            ? $textLabels{'notYet'} 
            : '' if ($dref->{updatestatus} eq '');
		$dref->{updatestatus} =  $lang->txt("$txt_Clr is $Defs::clearance_status{$dref->{intClearanceStatus}}") if $dref->{intClearanceStatus} > 1;
        $dref->{updatestatus} = '-' if ($dref->{intID} != $intID or $dref->{intTypeID} != $intTypeID);

		if ($dref->{intClearanceStatus} == $Defs::CLR_STATUS_CANCELLED) {
			$dref->{updatestatus} = $textLabels{'Cancelled'};
		}

		if (! $intAllowClubClrAccess and $dref->{intCurrentPathID} == $dref->{intClearancePathID})	{
			$dref->{updatestatus} = $lang->txt($Defs::clearance_status{$dref->{PathStatus}});
			$dref->{updatestatus} = $textLabels{'Cancelled'} if ($dref->{intClearanceStatus} == $Defs::CLR_STATUS_CANCELLED);
		}
		$dref->{updatestatus} ||= "&nbsp;";

		### HANDLE REOPENS ??

		$dref->{overallstatus} = $lang->txt($Defs::clearance_status{$dref->{intClearanceStatus}}) || 'P';
		$dref->{priority} = $lang->txt($Defs::clearance_priority{$dref->{intClearancePriority}});  
		$dref->{SourceEntityName} ||= $dref->{strSourceEntityName} || '';
		$dref->{DestinationEntityName} ||= $dref->{strDestinationEntityName} || '';
		$dref->{createdFrom} = $Defs::ClearanceTypes{$dref->{intCreatedFrom}};
		
		my %row = ();
		for my $i (qw(MemberName DOB DOB_RAW SourceEntityName DestinationEntityName updatestatus overallstatus dtApplied dtApplied_RAW createdFrom intClearanceID intClearanceYear intClearanceStatus_RAW intClearanceStatus_RAW_filter))	{
			$row{$i} = $dref->{$i};
		}
		$row{'id'} = $dref->{'intClearanceID'}.$cnt;
		$row{'SelectLink'} = "$Data->{'target'}?client=$client&amp;a=CL_view&amp;cID=$dref->{intClearanceID}&amp;cpID=$dref->{intClearancePathID}";
		push @rowdata, \%row;
		$cnt++;
  }
  $query->finish;

	my $checked_approved = $clearanceStatus == $Defs::CLR_STATUS_APPROVED ? $textLabels{'selected'} : '' ;
	my $checked_pending = $clearanceStatus == $Defs::CLR_STATUS_PENDING ? $textLabels{'selected'} : '' ;
	my $checked_denied= $clearanceStatus == $Defs::CLR_STATUS_DENIED ? $textLabels{'selected'} : '' ;
	my $checked_cancelled= $clearanceStatus == $Defs::CLR_STATUS_CANCELLED ? $textLabels{'selected'} : '' ;
	my $checked_awaitingApproval= $clearanceStatus == 100 ? $textLabels{'selected'} : '' ;
	my $checked_all= $clearanceStatus == 99 ? $textLabels{'selected'} : '' ;
        my $clearanceid = '';
	my $line=qq[
        <div class="showrecoptions" style="float:right;">
        <script language="JavaScript1.2" type="text/javascript" src="js/jscookie.js"></script>
                <form action="#" onsubmit="return false;" name="recoptions">
		<span class="dinbold">$textLabels{'ClearanceID'}</span>&nbsp;<input type="text" name="clearanceid" value="$clearanceid" size="10" id = "id_clearanceid">&nbsp;
		<span class="dinbold">$textLabels{'showing'}</span>&nbsp;$textLabels{'Name'}:&nbsp;<input type="text" name="membername" value="$membername" size="10" id = "id_surname">&nbsp;
		$textLabels{'fromClub'}:&nbsp;<input type="text" name="fromclub" value="$fromclub" size="10" id = "id_fromclub">&nbsp;
		$textLabels{'toClub'}:&nbsp;<input type="text" name="toclub" value="$toclub" size="10" id = "id_toclub">&nbsp;
	];

	$line .= qq[$textLabels{'year'}:&nbsp;<input type="text" name="clryear" value="$clryear" size="5" id = "id_clryear">&nbsp;] if (exists $Data->{'SystemConfig'}{'clrClearanceYear'});
	$line .= qq[<input type="hidden" name="clryear" value="0">] if (! exists $Data->{'SystemConfig'}{'clrClearanceYear'});
	$line .= qq[
		$textLabels{'status'}:
                <select name="clearanceStatus" size="1" style="font-size:10px;" id = "dd_clearanceStatus">
                        <option $checked_approved value="$Defs::CLR_STATUS_APPROVED">$textLabels{'approved'}</option>
                        <option $checked_pending value="$Defs::CLR_STATUS_PENDING">$textLabels{'pending'}</option>
                        <option $checked_denied value="$Defs::CLR_STATUS_DENIED">$textLabels{'denied'}</option>
                        <option $checked_cancelled value="$Defs::CLR_STATUS_CANCELLED">$textLabels{'cancelled'}</option>
			<option $checked_awaitingApproval value="100">--$textLabels{'awaitingApprovalFromLevel'}--</option>
		        <option $checked_all value="99">$textLabels{'all'}</option>
                </select> $textLabels{'records'}
                <input type="submit" value="Filter" class="button-small generic-button" onclick="SetCookie('SWOMCLRREC_cidm',document.recoptions['clearanceid'].value,30); SetCookie('SWOMCLRREC',document.recoptions['clearanceStatus'].options[document.recoptions['clearanceStatus'].selectedIndex].value,30); SetCookie('SWOMCLRREC_mn',document.recoptions['membername'].value,30);SetCookie('SWOMCLRREC_year',document.recoptions['clryear'].value,30);SetCookie('SWOMCLRREC_toclub',document.recoptions['toclub'].value,30);SetCookie('SWOMCLRREC_fromclub',document.recoptions['fromclub'].value,30);document.location.reload();return true;">
			<input type="hidden" name="showAll" value="$showAll">
                </form>
        </div><br><br>
        ];

        my $listOffline = ($Data->{'SystemConfig'}{'clrListOffline'} and ($Data->{'clientValues'}{'currentLevel'} == $Defs::LEVEL_CLUB or $Data->{'clientValues'}{'currentLevel'} == $Defs::LEVEL_ASSOC)) ? qq[<span class="button-small generic-button"><a href="$Data->{'target'}?client=$client&amp;a=CL_offlist">$textLabels{'listClearances'}</a></span>] : '';
        my $listRequests= ($Data->{'SystemConfig'}{'clrInternationalSpecial'} and $Data->{'clientValues'}{'currentLevel'} == $Data->{'SystemConfig'}{'clrInternationalSearchNodeLevel'}) ? qq[<span class="button-small generic-button"><a href="$Data->{'target'}?client=$client&amp;a=CL_LHB">$textLabels{'listClrRequests'}</a></span>] : '';
	
		my $applicationDateHeader = $textLabels{'applicationDate'};
		$applicationDateHeader .= qq[<br>($textLabels{'dateDue'})] if ($Data->{'SystemConfig'}{'Clearance_DateDue'} and $hasDateDue);


  my @headers = (
    {
      type => 'Selector',
      field => 'SelectLink',
    },
    {
      name =>   $lang->txt('Name'),
      field =>  'MemberName',
    },
    {
      name =>   $lang->txt('Date of Birth'),
      field =>  'DOB',
    },
    {
      name =>   $lang->txt('From Club'),
      field =>  'SourceEntityName',
    },
    {
      name =>   $lang->txt('To Club'),
      field =>  'DestinationEntityName',
    },
    {
      name =>   $lang->txt("This level's status"),
      field =>  'updatestatus',
			type=>'HTML',
    },
    {
      name =>   $lang->txt("Overall status"),
      field =>  'overallstatus',
    },
    {
      name =>   $lang->txt("Application Date"),
      field =>  'dtApplied',
    },
    {
      name =>   $lang->txt("Created By"),
      field =>  'createdFrom',
    },
    {
      name =>   $lang->txt("Ref. No."),
      field =>  'intClearanceID',
			width => 60,
    },
    {
      name =>   $lang->txt("Year"),
      field =>  'intClearanceYear',
			width => 40,
    },

	);

  my $filterfields = [
    {
      field => 'intClearanceID',
      elementID => 'id_clearanceid',
      type => 'regex',
    },
    {
      field => 'MemberName',
      elementID => 'id_surname',
      type => 'regex',
    },
    {
      field => 'SourceEntityName',
      elementID => 'id_fromclub',
      type => 'regex',
		},
    {
      field => 'DestinationEntityName',
      elementID => 'id_toclub',
      type => 'regex',
		},
    {
      field => 'intClearanceYear',
      elementID => 'id_clryear',
      type => 'regex',
		},
    {
      field => 'intClearanceStatus_RAW_filter',
      elementID => 'dd_clearanceStatus',
      allvalue => '99',
      js =>qq[SetCookie('SWOMCLRREC',document.recoptions['clearanceStatus'].options[document.recoptions['clearanceStatus'].selectedIndex].value,30); ],
      type => 'reload',
    },
	];

  my $grid  = showGrid(
    Data => $Data,
    columns => \@headers,
    rowdata => \@rowdata,
    gridid => 'grid',
    width => '99%',
		height => 700,
    filters => $filterfields,
  );


	$resultHTML = qq[
		<div class="changeoptions">
			$listOffline
			$listRequests 
		</div>
		<div class="grid-filter-wrap">
			<div style="width:100%;">$line</div>
			$grid
		</div>
	];

	my $title=$textLabels{'listOfClearances'};
  return ($resultHTML,$title);
}

1;

