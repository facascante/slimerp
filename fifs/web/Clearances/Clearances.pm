#
# $Header: svn://svn/SWM/trunk/web/Clearances.pm 10771 2014-02-21 00:20:57Z cgao $
#

package Clearances;
require Exporter;
@ISA = qw(Exporter);
@EXPORT = qw(checkAutoConfirms handleClearances clearanceHistory sendCLREmail finaliseClearance insertSelfTransfer getClrTaskCount);
@EXPORT_OK = qw(checkAutoConfirms handleClearances clearanceHistory sendCLREmail finaliseClearance insertSelfTransfer getClrTaskCount);
use lib '.', '..', '../..', "../comp", '../RegoForm', "../dashboard", "../RegoFormBuilder",'../PaymentSplit', "../user";

use strict;
use CGI qw(param unescape escape);
use Reg_common;
use Utils;
use HTMLForm;
use ClearancesList;
use FormHelpers;
use DeQuote;
use AuditLog;
use Mail::Sendmail;

use ServicesContacts;
use GridDisplay;
use Data::Dumper;
use ContactsObj;
use DefCodes;
use PersonRegistration;
use RuleMatrix;

sub getClrTaskCount {

    my ($Data, $entityID) = @_;

    my $st = qq[
        SELECT 
            COUNT(C.intClearanceID) as CountNum
        FROM 
            tblClearance as C
            INNER JOIN tblClearancePath as CP ON (CP.intClearanceID = C.intClearanceID)
        WHERE 
                C.intRealmID = $Data->{'Realm'}
                AND CP.intID = $entityID
                AND CP.intTypeID = $Data->{'clientValues'}{'currentLevel'}
                AND C.intCurrentPathID = CP.intClearancePathID 
                AND C.intClearanceStatus  = $Defs::CLR_STATUS_PENDING
    ];
    my $qry= $Data->{'db'}->prepare($st);
    $qry->execute or query_error($st);
    return $qry->fetchrow_array() || 0;
}
sub insertSelfTransfer  {

    my ($Data, $personID, $fromEntity, $toEntity, $clr_ref) = @_;
	my $intClearanceYear =$Data->{'SystemConfig'}{'clrClearanceYear'} || 0;

    my $st=qq[
        INSERT INTO tblClearance (
            intPersonID, 
            intDestinationEntityID, 
            intSourceEntityID, 
            intRealmID, 
            dtApplied, 
            intClearanceStatus, 
            intRecStatus, 
            intClearanceYear,
            intReasonForClearanceID,
            strPersonType,
            strPersonSubType,
            strPersonLevel,
            strPersonEntityRole,
            strSport,
            intOriginLevel,
            strAgeLevel
        )
        VALUES (
            ?, 
            ?,
            ?,
            ?,
            SYSDATE(), 
            ?,
            ?,
            ?, 
            ?, 
            ?,
            ?,
            ?,
            ?,
            ?,
            ?,
            ?
        )
    ];
    my $qry= $Data->{'db'}->prepare($st);
    $qry->execute(
            $personID, 
            $toEntity, 
            $fromEntity, 
            $Data->{'Realm'}, 
            $Defs::CLR_STATUS_PENDING, 
            $Defs::RECSTATUS_ACTIVE,  
            $intClearanceYear,
            $Data->{'SystemConfig'}{'clrReasonSelfInitiatedID'} || 0,
            $clr_ref->{'personType'} || '',
            $clr_ref->{'personSubType'} || '',
            $clr_ref->{'personLevel'} || '',
            $clr_ref->{'personEntityRole'} || '',
            $clr_ref->{'sport'} || '',
            $Defs::ORIGIN_SELF,
            $clr_ref->{'ageLevel'} || ''
    ) or query_error($st);
	my $clrID= $qry->{mysql_insertid} || 0;

   my %params = ();
   $params{'sourceEntityID'} = $fromEntity;
   $params{'destinationEntityID'} = $toEntity;
   my ($clrAddStatus, undef) = postClearanceAdd($clrID,\%params,'ADD',$Data,$Data->{'db'});
}

sub handleClearances	{
    ### PURPOSE: main function to handle clearances.

	my($action,$Data)=@_;
    my $lang = $Data->{'lang'};
	my $q=new CGI;
    my %params=$q->Vars();

	my $clearanceID = $params{'cID'} || 0;
	my $clearancePathID = $params{'cpID'} || 0;
	my $txt_RequestCLR = $lang->txt('Request a Transfer');

	return (createClearance($action, $Data), $txt_RequestCLR) if $action eq 'CL_createnew';
	return (clearancePathDetails($Data, $clearanceID, $clearancePathID), $lang->txt('Transfer Status Selection')) if $action eq 'CL_details';
	return (listClearances($Data), $txt_RequestCLR) if $action eq 'CL_list';
	return (listOfflineClearances($Data), $txt_RequestCLR) if $action eq 'CL_offlist';
	return (clearanceView($Data, $clearanceID), $lang->txt('Clearance Details')) if $action eq 'CL_view';
	return (clearanceCancel($Data, $clearanceID), $lang->txt('Cancel Transfer')) if $action eq 'CL_cancel';
	return (clearanceReopen($Data, $clearanceID), $lang->txt('Reopen Transfer')) if $action eq 'CL_reopen';
	return (clearanceAddManual($Data), $lang->txt("Add Manual Transfer")) if $action eq 'CL_addmanual';
	return (clearanceAddManual($Data), $lang->txt("Edit Manual Transfer")) if $action eq 'CL_editmanual';
}

sub clearanceCancel	{
### PURPOSE: To allow the Destination Club (club who requested the clearance), to cancel it. This function is called when the destination Club views the clearance (after clicking on the clearance in "List Clearances").
### The club can reopen it at any stage. See clearanceReopen(). 

	my ($Data, $clearanceID) = @_;
	my $db = $Data->{'db'};
    my $lang = $Data->{'lang'};
	$clearanceID ||= 0;
	my $clubID = getID($Data->{'clientValues'}); #{'clubID'} || 0;
	return $lang->txt("Transfer unable to be cancelled") if (! $clubID or ! $clearanceID);
  	my $client=setClient($Data->{'clientValues'}) || '';

	 my $st = qq[
                SELECT
                        intPersonID,
                        intDestinationEntityID,
                        intSourceEntityID
                FROM
                        tblClearance
                WHERE
                        intClearanceID = $clearanceID
        ]; 
        my $qry= $db->prepare($st);
        $qry->execute or query_error($st);
        my ($intPersonID, $intDestinationEntityID, $intSourceEntityID) = $qry->fetchrow_array();

	$st = qq[
		UPDATE tblClearance
		SET intClearanceStatus = $Defs::CLR_STATUS_CANCELLED
		WHERE intClearanceID = $clearanceID
			AND intDestinationEntityID = $clubID
	];
	$db->do($st);
	$st = qq[
		UPDATE tblClearancePath as CP 
            INNER JOIN tblClearance as C ON (C.intClearanceID = CP.intClearanceID)
		SET CP.intClearanceStatus = $Defs::CLR_STATUS_CANCELLED
		WHERE CP.intClearanceID = $clearanceID
			AND CP.intClearanceStatus = $Defs::CLR_STATUS_PENDING
			AND CP.intDestinationEntityID = $clubID
	];
	sendCLREmail($Data, $clearanceID, 'CANCELLED');
	my $txt_Clr = $Data->{'SystemConfig'}{'txtCLR'} || 'Clearance';
    auditLog($clearanceID, $Data, 'Cancelled','Clearance');
	return qq[<p>] . $lang->txt("Transfer Cancelled") . qq[</p><br> <a href="$Data->{'target'}?a=CL_list&amp;client=$client">] . $lang->txt('Return to Transfer Listing') . qq[</a>];
}

sub clearanceReopen	{

### PURPOSE: To allow the Destination Club (club who requested the clearance), to reopen it, if they cancelled it at any stage. This function is called when the destination Club views the clearance (after clicking on the clearance in "List Clearances").

### See the above function clearanceCancel() for how the destination club actually cancels it.
	my ($Data, $clearanceID) = @_;
	my $db = $Data->{'db'};
	$clearanceID ||= 0;
	my $clubID = getID($Data->{'clientValues'}); #{'clubID'} || 0;
    my $lang = $Data->{'lang'};
	return $lang->txt('Transfer unable to be Reopened') if (! $clubID or ! $clearanceID);
  	my $client=setClient($Data->{'clientValues'}) || '';

    my $st = qq[
      SELECT
        C.intClearanceID, 
				C1.strLocalName as DestinationEntityName, 
				C2.strLocalName as SourceEntityName, 
				C.intDestinationEntityID as DestinationEntityID,
                C.intSourceEntityID as SourceEntityID,
				DATE_FORMAT(C.dtApplied,'%d/%m/%Y') AS AppliedDate 
      FROM
				tblClearance as ThisClr
        INNER JOIN tblClearance as C ON (C.intPersonID=ThisClr.intPersonID and C.intClearanceID <> ThisClr.intClearanceID)
        LEFT JOIN tblEntity as C1 ON (C1.intEntityID = C.intDestinationEntityID)
        LEFT JOIN tblEntity as C2 ON (C2.intEntityID = C.intSourceEntityID)
    WHERE ThisClr.intClearanceID = $clearanceID
AND  C.intClearanceStatus = $Defs::CLR_STATUS_PENDING
      AND C.intCreatedFrom =0
  ];
  my $query = $db->prepare($st) or query_error($st);
  $query->execute or query_error($st);

	while (my $dref = $query->fetchrow_hashref()) {
		my $source_contact_name="";
		my $source_contact_email ="";
		my $destination_contact_name ="";
		my $destination_contact_email="";		
	
 if($dref->{SourceEntityID} >0){
                my $source_contactObj = ContactsObj->getList(dbh=>$db,clubid=>$dref->{SourceEntityID} , getclearances=>1)||[];
                my $source_contactObjP = ContactsObj->getList(dbh=>$db,clubid=>$dref->{SourceEntityID} , getprimary=>1)||[];
                if(scalar(@$source_contactObj)>0){
                        $source_contact_name =qq[@$source_contactObj[0]->{strContactFirstname} @$source_contactObj[0]->{strContactSurname}];
                        $source_contact_email = @$source_contactObj[0]->{strContactEmail};
                }
                elsif(scalar(@$source_contactObjP)>0){
                        $source_contact_name =qq[@$source_contactObjP[0]->{strContactFirstname} @$source_contactObjP[0]->{strContactSurname}];
                        $source_contact_email = @$source_contactObjP[0]->{strContactEmail};
                }
        }
        if($dref->{DestinationEntityID} >0){
                my  $destination_contactObj = ContactsObj->getList(dbh=>$db,clubid=>$dref->{DestinationEntityID} , getclearances=>1) ;
                my  $destination_contactObjP = ContactsObj->getList(dbh=>$db, clubid=>$dref->{DestinationEntityID} , getprimary=>1) ;
                if(scalar(@$destination_contactObj)>0){
                        $destination_contact_name =qq[@$destination_contactObj[0]->{strContactFirstname} @$destination_contactObj[0]->{strContactSurname}];
                        $destination_contact_email = @$destination_contactObj[0]->{strContactEmail};
                }
                elsif(scalar(@$destination_contactObjP)>0){
                        $destination_contact_name =qq[@$destination_contactObjP[0]->{strContactFirstname} @$destination_contactObjP[0]->{strContactSurname}];
                        $destination_contact_email = @$destination_contactObjP[0]->{strContactEmail};
                }
        }


		$dref->{SourceEmail} = $source_contact_email;
		$dref->{SourceContact} = $source_contact_name;

		$dref->{DestinationEmail} = $destination_contact_email;
		$dref->{DestinationContact} = $destination_contact_name;
		return qq[
			<div class="warningmsg">]. $lang->txt('The selected member is already involved in a pending clearance.  Unable to continue until the below transaction is finalised.') . qq[</div>
			<p>
					<b>] . $lang->txt('Date Requested') . qq[:</b> $dref->{AppliedDate}<br>
					<b>] . $lang->txt('Requested From') . qq[:</b> $dref->{SourceEntityName} ($source_contact_name)<br>
					] . $lang->txt('Contact') . qq[: $dref->{SourceContact}<br>
					] . $lang->txt('Phone') . qq[: $dref->{SourcePh}&nbsp;&nbsp;] . $lang->txt('Email') . qq[:  $dref->{SourceEmail}<br>
					<b>] . $lang->txt('Request To') . qq[:</b> $dref->{DestinationEntityName}<br>
					] . $lang->txt('Contact') . qq[: $dref->{DestinationContact}<br>
					] . $lang->txt('Phone') . qq[: $dref->{DestinationPh}&nbsp;&nbsp;] . $lang->txt('Email') . qq[: $dref->{DestinationEmail}<br>
				</p>
			];

	}

	$st = qq[
		UPDATE tblClearance
		SET intClearanceStatus = $Defs::CLR_STATUS_PENDING
		WHERE intClearanceID = $clearanceID
			AND intDestinationEntityID = $clubID
	];
	$db->do($st);
	$st = qq[
		UPDATE tblClearancePath as CP INNER JOIN tblClearance as C ON (C.intClearanceID = CP.intClearanceID)
		SET CP.intClearanceStatus = $Defs::CLR_STATUS_PENDING
		WHERE CP.intClearanceID = $clearanceID
			AND CP.intClearanceStatus = $Defs::CLR_STATUS_CANCELLED
			AND C.intDestinationEntityID = $clubID
	];
	$db->do($st);

	sendCLREmail($Data, $clearanceID, 'REOPEN');
    auditLog($clearanceID, $Data, $lang->txt('Reopen'). $lang->txt('Transfer'));
	return qq[<p>] . $lang->txt('Transfer Reopened') . qq[</p><br> <a href="$Data->{'target'}?a=CL_list&amp;client=$client">] . $lang->txt('Return to Transfer Listing') . qq[</a>];
}

sub clearanceHistory	{

### PURPOSE: This function displays, for given intPersonID, the clearance history that they have. This is called from within the view member screen.

### At the bottom of this function is the ability to add a manual clearance history record.  For example, if they came from overseas.  These manual records don't have approval paths, but rather, are for historical purposes.

	my ($Data, $intPersonID) = @_;
	$intPersonID ||= 0;
    my $lang = $Data->{'lang'};
	return '' if ! $intPersonID;

	my $db = $Data->{'db'};
	my $st = qq[
                SELECT 
                    C.*, 
                    SourceEntity.strLocalName as SourceEntityName, 
                    DestinationEntity.strLocalName as DestinationEntityName, 
                    DATE_FORMAT(dtApplied,'%d/%m/%Y') AS dtApplied, now() AS Today
                FROM tblClearance as C
			        LEFT JOIN tblClearancePath as CP ON (CP.intClearanceID = C.intClearanceID)
                    LEFT JOIN tblEntity as SourceEntity ON (SourceEntity.intEntityID= C.intSourceEntityID)
                    LEFT JOIN tblEntity as DestinationEntity ON (DestinationEntity.intEntityID = C.intDestinationEntityID)
                WHERE C.intPersonID = $intPersonID
			AND C.intRecStatus <> -1
		GROUP BY C.intClearanceID
		ORDER BY C.dtApplied DESC
        ];
    	my $query = $db->prepare($st) or query_error($st);
    	$query->execute or query_error($st);
	
	my @headerdata = (
    {
      type => 'Selector',
      field => 'SelectLink',
    },
    {
      name => $lang->txt('Transfer No.'),
      field => 'intClearanceID',
    },	
    {
      name => $lang->txt('Date'),
      field => 'dtApplied',
    },	
    {
      name => $lang->txt('From Club'),
      field => 'sourceDetails',
    },	
    {
      name => $lang->txt('To Club'),
      field => 'destinationDetails',
    },	
    {
      name => $lang->txt('Status'),
      field => 'status',
    },	
    {
      name => $lang->txt('Type'),
      field => 'type',
    },	
	);
	my $count=0;
  my $client=setClient($Data->{'clientValues'}) || '';
	my @rowdata=();
	while (my $dref=$query->fetchrow_hashref())	{
		$count++;
		my $status = $Defs::clearance_status{$dref->{intClearanceStatus}};
		my $priority= $Defs::clearance_priority{$dref->{intClearancePriority}};
    $dref->{SourceEntityName} ||= $dref->{strSourceEntityName} || '';
    $dref->{DestinationEntityName} ||= $dref->{strDestinationEntityName} || '';
		my $selectLink= "$Data->{'target'}?client=$client&amp;cID=$dref->{intClearanceID}&amp;a=CL_view";
		$selectLink= "$Data->{'target'}?client=$client&amp;clrID=$dref->{intClearanceID}&amp;a=CL_editmanual" if ($dref->{intCreatedFrom} == $Defs::CLR_TYPE_MANUAL and $Data->{'clientValues'}{'authLevel'} >= $Defs::LEVEL_ASSOC);

## TC ## HACKED IN COS TOO MANY BAFF CHANGES ON DEVEL | CHANGE IS CHECKED IN ON DEVEL
    my $clearance_type = '';
     $clearance_type = $Defs::ClearanceTypes{$dref->{intCreatedFrom}};

		$dref->{'sourceDetails'} = qq[$dref->{SourceEntityName}];
		$dref->{'destinationDetails'} = qq[$dref->{DestinationEntityName}];
		$dref->{'status'} = $status;
		$dref->{'type'} = $clearance_type;
		push @rowdata, {
      id => $dref->{'intClearanceID'},
			intClearanceID=>$dref->{'intClearanceID'},
      SelectLink=>$selectLink,
      dtApplied=> $dref->{'dtApplied'},
      sourceDetails=> $dref->{'sourceDetails'},
      destinationDetails=> $dref->{'destinationDetails'},
      status=> $dref->{'status'},
      type=> $dref->{'type'},
		};
	}
	
	my $body = showGrid(
      Data => $Data,
      columns => \@headerdata,
      rowdata => \@rowdata,
      gridid => 'grid',
      width => '99%',
      height => 700,
    );
	$body =qq[<div class="warningmsg">]. $lang->txt('No Transfer History found') . qq[</div>] if ! $count;

	my $addManual = qq[<a href="$Data->{'target'}?client=$client&amp;a=CL_addmanual">] . $lang->txt('Add manual Transfer History') . qq[</a>];
	$body = qq[$addManual$body];
	return $body;
}

sub clearanceView	{

### PURPOSE: This function is used to view a clearance record.  This is what is loaded once the clearance is clicked in "List Clearances" navbar option.
## The function works out if the level viewing it is the destination club (who requested the clearance) and if so allows the clearance notes field to be updated.

	my ($Data, $cID) = @_;

	my $db = $Data->{'db'};
    my $lang = $Data->{'lang'};
	my $body;

	my $st = qq[
                SELECT DISTINCT 
                    C.*, 
                    DATE_FORMAT(C.dtApplied,"%d/%m/%Y") AS dtApplied, 
                    CONCAT(M.strLocalSurname, " ", M.strLocalFirstname) as MemberName, 
                    SourceEntity.strLocalName as SourceEntityName, 
                    DestinationEntity.strLocalName as DestinationEntityName, 
                    M.strState, 
                    DATE_FORMAT(M.dtDOB,'%d/%m/%Y') AS dtDOB, 
                    strNationalNum  
                FROM tblClearance as C
                    INNER JOIN tblPerson as M ON (M.intPersonID = C.intPersonID)
			        LEFT JOIN tblClearancePath as CP ON (CP.intClearanceID = C.intClearanceID)
                    LEFT JOIN tblEntity as SourceEntity ON (SourceEntity.intEntityID = C.intSourceEntityID)
                    LEFT JOIN tblEntity as DestinationEntity ON (DestinationEntity.intEntityID = C.intDestinationEntityID)
                WHERE C.intClearanceID= $cID
		GROUP BY C.intClearanceID
        ];
    	my $query = $db->prepare($st) or query_error($st);
    	$query->execute or query_error($st);

	my $dref = $query->fetchrow_hashref() || undef;

	my $id=0;
	my $edit=0;
  	my $client=setClient($Data->{'clientValues'}) || '';
	my $target=$Data->{'target'} || '';
	my $option='display';

	if ($dref->{intCreatedFrom} == $Defs::CLR_TYPE_MANUAL or $dref->{intSourceEntityID} == getID($Data->{'clientValues'})) { #{'clubID'})	{
		$edit=1;
		$id=$cID;
		$option='edit';
	}

	my $clrupdate=qq[
                UPDATE tblClearance
                        SET --VAL--
                WHERE intClearanceID = $cID
        ];

  	my $resultHTML = '';
	my $toplist='';

	my %DataVals=();
	my $RecordData={};

    my ($DefCodes, $DefCodesOrder) = getDefCodes(
        dbh        => $Data->{'db'}, 
        realmID    => $Data->{'Realm'},
        subRealmID => $Data->{'RealmSubType'},
        onlyTypes  => '-37',
    );

	my $readonly = 1;
	$readonly=0 if (getID($Data->{'clientValues'}) == $dref->{intDestinationEntityID});	#clubID
	$dref->{SourceEntityName} ||= $dref->{strSourceEntityName} || '';
	$dref->{DestinationEntityName} ||= $dref->{strDestinationEntityName} || '';
	my $update_label = $Data->{'SystemConfig'}{'txtUpdateLabel_CLR'} || 'Update Clearance';
	my $intReasonForClearanceID = ($Data->{'SystemConfig'}{'clrHide_intReasonForClearanceID'}==1) ? '1' : '0';
	my $strReasonForClearance =($Data->{'SystemConfig'}{'clrHide_strReasonForClearance'}==1) ? '1' : '0';
	my $strFilingNumber = ($Data->{'SystemConfig'}{'clrHide_strFilingNumber'} == 1) ? '1' : '0';
	my $intClearancePriority= ($Data->{'SystemConfig'}{'clrHide_intClearancePriority'}==1) ? '1' : '0';
	my $strReason=($Data->{'SystemConfig'}{'clrHide_strReason'}==1) ? '1' : '0';
	
	$update_label = '' if $readonly;

	my %FieldDefs = (
		CLR => {
			fields => {
				NatNum=> {
					label => $Data->{'SystemConfig'}{'NationalNumName'},
					value => $dref->{'strNationalNum'},
                    type  => 'text',
					readonly => '1',
                },
				ClearanceID=> {
                    label => $lang->txt("Transfer No."),
					value => $dref->{'intClearanceID'},
                    type  => 'text',
					readonly => '1',
                },
				dtApplied=> {
					label => $lang->txt('Application Date'),
					value => $dref->{'dtApplied'},
                    type  => 'text',
					readonly => '1',
				},	
				MemberName=> {
					label => $lang->txt('Person being Transferred'),
					value => $dref->{'MemberName'},
                    type  => 'text',
					readonly => '1',
                },
				dtDOB => {
					label => $lang->txt('Date of Birth'),
					value => $dref->{'dtDOB'},
                    type  => 'text',
					readonly => '1',
				},	
				strState=> {
					label => $lang->txt('State'),
					value => $dref->{'strState'},
                    type  => 'text',
					readonly => '1',
                },
				SourceEntityName => {
					label => $lang->txt('From Club'),
					value => $dref->{'SourceEntityName'},
                    type  => 'text',
					readonly => '1',
				},
				DestinationEntityName => {
					label => $lang->txt('To Club'),
					value => $dref->{'DestinationEntityName'},
                    type  => 'text',
					readonly => '1',

				},
				ClearanceStatus => {
					label => $lang->txt('Overall Transfer Status'),
					value => qq[<b>$Defs::clearance_status{$dref->{intClearanceStatus}}</b>],
                    type  => 'text',
					readonly => '1',
				},
				ClearancePriority => {
					label => $lang->txt('Transfer Priority'),
					value => $Defs::clearance_priority{$dref->{intClearancePriority}},
                    type  => 'text',
					readonly => '1',
					nodisplay=>$intClearancePriority,
					noadd=>$intClearancePriority,
					noedit=>$intClearancePriority,
				},
				intReasonForClearanceID => {
					label => $lang->txt('Reason for Transfer'),
				    value => $dref->{intReasonForClearanceID},
				    type  => 'lookup',
        			options => $DefCodes->{-37},
        		    order => $DefCodesOrder->{-37},
					firstoption => ['',$lang->txt("Choose Reason")],
					readonly => '1',
					nodisplay=>$intReasonForClearanceID,
					noadd=>$intReasonForClearanceID,
					noedit=>$intReasonForClearanceID,
	      			},
				strReasonForClearance=> {
					label => $lang->txt('Additional Information'),
					type => 'textarea',
					value => $dref->{'strReasonForClearance'},
					rows => 5,
                	cols=> 45,
					readonly=>$readonly,
					nodisplay=>$strReasonForClearance,
					noadd=>$strReasonForClearance,
					noedit=>$strReasonForClearance,
				},
				strReason=>	{
					label => $lang->txt('Reason for Transfer'),
                    value => $dref->{'strReason'},
                    type  => 'text',
					readonly => '1',
					nodisplay=>$strReason,
					noadd=>$strReason,
					noedit=>$strReason,
				},
			},
		order => [qw(ClearanceID dtApplied NatNum MemberName dtDOB strState SourceEntityName DestinationEntityName ClearanceStatus ClearanceReason intReasonForClearanceID strReason strReasonForClearance)],
			options => {
				labelsuffix => ':',
				hideblank => 1,
				target => $Data->{'target'},
				formname => 'clr_form',
				submitlabel => $update_label,
				introtext => 'auto',
				buttonloc => 'bottom',
				updateSQL => $clrupdate,
				afterupdateFunction => \&postClearanceUpdate,
                afterupdateParams => [$option,$Data,$Data->{'db'}, $cID],
				stopAfterAction => 1,
				updateOKtext => qq[<div class="OKmsg">] . $lang->txt('Record updated successfully') . qq[</div> <br>                                        <a href="$Data->{'target'}?client=$client&amp;a=CL_view&amp;cID=$cID">] . $lang->txt('Return to Transfer') . qq[</a>],
			},
			sections => [ ['main',$lang->txt('Details')], ],
			carryfields =>  {
				client => $client,
				a=> 'CL_view',
				cID => $cID,
			},
		},
	);


	($resultHTML, undef )=handleHTMLForm($FieldDefs{'CLR'}, undef, $option, '',$db);


	if ($dref->{intCreatedFrom} == 0)	{
		$resultHTML .= qq[<a href="$Data->{'target'}?client=$client&amp;cID=$cID&amp;a=CL_cancel">] . $lang->txt('Cancel Transfer') . qq[</a>] if ($dref->{intDestinationEntityID} == getID($Data->{'clientValues'}) and $dref->{intClearanceStatus} != $Defs::CLR_STATUS_CANCELLED and $dref->{intClearanceStatus} != $Defs::CLR_STATUS_APPROVED);
		$resultHTML .= qq[<a href="$Data->{'target'}?client=$client&amp;cID=$cID&amp;a=CL_reopen">] . $lang->txt('Reopen Cancelled Transfer') . qq[</a>] if ($dref->{intDestinationEntityID} == getID($Data->{'clientValues'}) and $dref->{intClearanceStatus} == $Defs::CLR_STATUS_CANCELLED);
		$resultHTML .= showPathDetails($Data, $cID, $dref->{intClearanceStatus});
	}
	else	{
		$resultHTML .= qq[<br><div class="warningmsg">] . $lang->txt('No path details can be shown as this Transfer was created offline or it is a Manual Transfer History record') . qq[</div>];
	}

	if($option eq 'display')	{
		$resultHTML .=qq[<br><a href="$target?a=CL_list&amp;client=$client">] . $lang->txt('Return to Transfer Listing') . qq[</a> ] ;
	}

	$resultHTML=qq[
			<div class="alphaNav">$toplist</div>
			<div>
				$resultHTML
			</div>
	];
	my $heading=$lang->txt('Transfer Summary');
	return ($resultHTML,$heading);

}

sub postClearanceUpdate	{

    my($id,$params, $action,$Data,$db, $cID)=@_;
    $cID||=0;
    $id||=$cID;
    return (0,undef) if !$db;

	my $st = qq[
        SELECT
			intPersonID,
			intDestinationEntityID,
			intSourceEntityID
         FROM 
			tblClearance
         WHERE 
			intClearanceID = $id
    ];
    my $qry= $db->prepare($st);
    $qry->execute or query_error($st);
    my ($intPersonID, $intToClubID, $intFromClubID) = $qry->fetchrow_array();
	my $st_updateSource = qq[
        UPDATE
            tblMember_Clubs
        SET
            intStatus = $Defs::RECSTATUS_ACTIVE
        WHERE
            intPersonID = $intPersonID
            AND intClubID = $intFromClubID
            AND intStatus = $Defs::RECSTATUS_INACTIVE
        LIMIT 1
    ];
    $db->do($st_updateSource);
    my $st_clubsCleared = qq[
        DELETE
        FROM
            tblMember_ClubsClearedOut
        WHERE
            intPersonID = $intPersonID
            AND intClubID = $intFromClubID
    ];
    $db->do($st_clubsCleared);
}

sub showPathDetails	{

### PURPOSE: This function builds up the visible path information that is displayed at the bottom of the clearance record when viewing it.

### If the destination club (who requested clearance) have cancelled the clearance, this function has the "REOPEN" option set against the status column.

	my ($Data, $cID, $clearanceStatus) = @_;
    my $lang = $Data->{'lang'};

  	my $client=setClient($Data->{'clientValues'}) || '';
	$cID ||= 0;
	return if ! $cID;

	my $db = $Data->{'db'};

	my $st = qq[
		SELECT 
            CP.* , 
            DATE_FORMAT(CP.tTimeStamp,'%d/%m/%Y') AS TimeStamp, 
            C.intCurrentPathID
		FROM tblClearancePath as CP 
            INNER JOIN tblClearance as C ON (C.intClearanceID = CP.intClearanceID)
		WHERE CP.intClearanceID = $cID
		ORDER BY intOrder
	];
    my $query = $db->prepare($st) or query_error($st);
    $query->execute or query_error($st);

	my $body = '';

    my ($DefCodes, $DefCodesOrder) = getDefCodes(
        dbh        => $Data->{'db'}, 
        realmID    => $Data->{'Realm'},
        subRealmID => $Data->{'RealmSubType'},
        onlyTypes  => '-38',
    );
       
	$body .= qq[
        	<div class="sectionheader">] . $lang->txt('Transfer Approval Details') . qq[</div>
                <table class="listTable">
			<tr>
				<th>] . $lang->txt('Name') .qq[</th>
				<th>] . $lang->txt('Transfer Status') .qq[</th>
				<th>] . $lang->txt('Approved By') .qq[</th>
				<th>] . $lang->txt('Denial Reason') .qq[</th>
				<th>] . $lang->txt('Additional Information') .qq[</th>
				<th>] . $lang->txt('Time Updated') .qq[</th>
			</tr>
	];
	my $denied = 0;



#### 
        my $intID=0;         
        $intID = $Data->{'clientValues'}{'clubID'} if ($Data->{'clientValues'}{'currentLevel'} == $Defs::LEVEL_CLUB);
        $intID = $Data->{'clientValues'}{'zoneID'} if ($Data->{'clientValues'}{'currentLevel'} == $Defs::LEVEL_ZONE);
        $intID = $Data->{'clientValues'}{'regionID'} if ($Data->{'clientValues'}{'currentLevel'} == $Defs::LEVEL_REGION);
        $intID = $Data->{'clientValues'}{'stateID'} if ($Data->{'clientValues'}{'currentLevel'} == $Defs::LEVEL_STATE);         
        $intID = $Data->{'clientValues'}{'natID'} if ($Data->{'clientValues'}{'currentLevel'} == $Defs::LEVEL_NATIONAL);
        my $intTypeID = $Data->{'clientValues'}{'currentLevel'};

		my @rowdata=();
	while (my $dref = $query->fetchrow_hashref())	{
		my ($pathnode , undef, undef) = getNodeDetails($db, $dref->{intTableType}, $dref->{intTypeID}, $dref->{intID});
		next if ! $pathnode;
		my $status = ($denied == 1) ? '-' : $Defs::clearance_status{$dref->{intClearanceStatus}};
		$denied = 1 if $dref->{intClearanceStatus} == $Defs::CLR_STATUS_DENIED;
		$status = qq[<a href="$Data->{'target'}?client=$client&amp;a=CL_details&amp;cID=$dref->{intClearanceID}&amp;cpID=$dref->{intClearancePathID}">$status</a>] if ($status ne '-' and $dref->{intClearanceStatus} != $Defs::CLR_STATUS_PENDING and $dref->{intTypeID} == $intTypeID and $dref->{intID} == $intID and !$Data->{'ReadOnlyLogin'});

		$status = qq[<span style="font-weight:bold;color:green;">$status</style>] if $dref->{intClearanceStatus} == $Defs::CLR_STATUS_APPROVED;
		$status = qq[<span style="font-weight:bold;color:red;">$status</style>] if $dref->{intClearanceStatus} == $Defs::CLR_STATUS_DENIED;
		$status .= qq[&nbsp;&nbsp;<a href="$Data->{'target'}?client=$client&amp;a=CL_details&amp;cID=$dref->{intClearanceID}&amp;cpID=$dref->{intClearancePathID}">&nbsp;(--]. $lang->txt('Reopen Transfer') . qq[--)</a>] if ($dref->{intClearanceStatus} == $Defs::CLR_STATUS_DENIED and $dref->{intTypeID} == $intTypeID and $dref->{intID} == $intID);
		$status = $lang->txt('Cancelled') if ($clearanceStatus == $Defs::CLR_STATUS_CANCELLED and $dref->{intClearanceStatus} == $Defs::CLR_STATUS_PENDING);
		my $timestamp = $dref->{intClearanceStatus} ? $dref->{TimeStamp} : '';
		my $level = $Defs::LevelNames{$dref->{intTypeID}};
		$body .= qq[
			<tr>
				<td>$pathnode</td>
				<td>$status</td>
				<td>$dref->{strApprovedBy}</td>
				<td>$DefCodes->{-38}{$dref->{intDenialReasonID}}</td>
				<td>$dref->{strPathNotes}</td>
				<td>$timestamp</td>
			</tr>
		];
	}
	$body .= qq[</table><br>];

	return $body;

}

sub getNodeDetails	{

### PURPOSE: This function returns the Name, Email address for the passed values.  This is used by various functions such as emailing.

	my ($db, $intTableType, $intTypeID, $intID) = @_;

	$intTableType ||= 0;
	$intTypeID ||= 0;
	$intID ||= 0;

	return '' if ! $intTableType or ! $intTypeID or ! $intID;

	my $tablename = '';
	my $field = '';
	my $where = '';
	$tablename = 'tblEntity';
	$field = 'intEntityID';
#		$where = qq[ AND intStatusID =$Defs::NODE_SHOW ];

	my $st = qq[
		SELECT 
            strLocalName, 
            strEmail 
		FROM $tablename
		WHERE $field = $intID
			$where
	];
    my $query = $db->prepare($st) or query_error($st);
    $query->execute or query_error($st);
	my $name='';
	my $email='';
	my $id = '';

	if ($intTableType == $Defs::ASSOC_LEVEL_CLEARANCE)	{
		($name, $email, $id) = $query->fetchrow_array();
		$id ||= 0;
	}
	else	{
		($name, $email) = $query->fetchrow_array();
	}
	$name ||= '';
	$email ||= '';

	return ($name, $id,$email);

}

sub clearancePathDetails	{

### PURPOSE: This function creates a HTMLForm view of the clearance from a clearance Path view.  Ie: from the approval/denial record of a clearance.

### If the level at view the path details, they are given the option of editing the notes.

	my ($Data, $cID, $cpID) = @_;

    my $lang = $Data->{'lang'};
	my $db = $Data->{'db'};
	$cpID ||= 0;
	my $cpID_WHERE = $cpID ? qq[ AND CP.intClearancePathID = $cpID] : '';

	my $body;

	my $st = qq[
                SELECT DISTINCT 
                    C.*, 
                    CP.intClearanceStatus as PathStatus, 
                    CP.intClearancePathID, 
                    CONCAT(M.strLocalSurname, " ", M.strLocalFirstname) as MemberName, 
                    SourceEntity.strLocalName as SourceEntityName, 
                    DestinationEntity.strLocalName as DestinationEntityName, 
                    M.strState, 
                    DATE_FORMAT(M.dtDOB,'%d/%m/%Y') AS dtDOB, 
                    CP.intID, 
                    CP.intTypeID, 
                    CP.intDenialReasonID, 
                    CP.intTableType, 
                    CP.strPathNotes, 
                    CP.strPathFilingNumber, 
                    CP.strApprovedBy 
                FROM tblClearance as C
                        INNER JOIN tblClearancePath as CP ON (CP.intClearanceID = C.intClearanceID)
                        INNER JOIN tblPerson as M ON (M.intPersonID = C.intPersonID)
                        LEFT JOIN tblEntity as SourceEntity ON (SourceEntity.intEntityID = C.intSourceEntityID)
                        LEFT JOIN tblEntity as DestinationEntity ON (DestinationEntity.intEntityID = C.intDestinationEntityID)
                WHERE C.intClearanceID= $cID
			$cpID_WHERE
        ];
	#BAFF HERE
    	my $query = $db->prepare($st) or query_error($st);
    	$query->execute or query_error($st);

	my $dref = $query->fetchrow_hashref() || undef;

	 my $intID=0;
        $intID = $Data->{'clientValues'}{'clubID'} if ($Data->{'clientValues'}{'currentLevel'} == $Defs::LEVEL_CLUB);
        $intID = $Data->{'clientValues'}{'zoneID'} if ($Data->{'clientValues'}{'currentLevel'} == $Defs::LEVEL_ZONE);
        $intID = $Data->{'clientValues'}{'regionID'} if ($Data->{'clientValues'}{'currentLevel'} == $Defs::LEVEL_REGION);
        $intID = $Data->{'clientValues'}{'stateID'} if ($Data->{'clientValues'}{'currentLevel'} == $Defs::LEVEL_STATE);
        $intID = $Data->{'clientValues'}{'natID'} if ($Data->{'clientValues'}{'currentLevel'} == $Defs::LEVEL_NATIONAL);
        my $intTypeID = $Data->{'clientValues'}{'currentLevel'};

	my $readonly = 0;
	my $extrafields_readonly = 0;
	$extrafields_readonly = 1 if ($dref->{intTypeID} != $intTypeID or $dref->{intID} != $intID or $dref->{intCurrentPathID} < $cpID);
	$readonly = 1 if ($dref->{intCurrentPathID} != $cpID);
	$readonly = 1 if ($dref->{intClearanceStatus} == $Defs::CLR_STATUS_APPROVED); #BAFF
	my $update_label = $lang->txt('Update Transfer');
	my $id=0;
	my $edit=0;
  	my $client=setClient($Data->{'clientValues'}) || '';
	my $target=$Data->{'target'} || '';
	my $option=$edit ? ($id ? 'edit' : 'add')  :'display' ;
	$option='edit';

  	my $resultHTML = '';
	my $toplist='';

	my %DataVals=();
	my $RecordData={};
	$option = $dref->{intClearanceID} ? 'edit' : '';
	my $clrupdate=qq[
		UPDATE tblClearancePath 
			SET --VAL--
		WHERE intClearancePathID=$cpID
	];

	$option = 'display' if ($dref->{intClearanceStatus} == $Defs::CLR_STATUS_APPROVED and $Data->{'SystemConfig'}{'NoEditClearanceOnceApproved'}); 
	$option = 'display' if ($Data->{'ReadOnlyLogin'} and $Data->{'clientValues'}{'authLevel'}>=$Defs::LEVEL_ASSOC); ##BAFF
    my ($DefCodes, $DefCodesOrder) = getDefCodes(
        dbh        => $Data->{'db'}, 
        realmID    => $Data->{'Realm'},
        subRealmID => $Data->{'RealmSubType'},
        onlyTypes  => '-38',
    );
       
    $dref->{SourceEntityName} ||= $dref->{strSourceEntityName} || '';
    $dref->{DestinationEntityName} ||= $dref->{strDestinationEntityName} || '';
	my $intReasonForClearanceID = ($Data->{'SystemConfig'}{'clrHide_intReasonForClearanceID'}==1) ? '1' : '0';
	my $strReason=($Data->{'SystemConfig'}{'clrHide_strReason'}==1) ? '1' : '0';
	my $strReasonForClearance =($Data->{'SystemConfig'}{'clrHide_strReasonForClearance'}==1) ? '1' : '0';
	my $strFilingNumber = ($Data->{'SystemConfig'}{'clrHide_strFilingNumber'} == 1) ? '1' : '0';
	my $intClearancePriority= ($Data->{'SystemConfig'}{'clrHide_intClearancePriority'}==1) ? '1' : '0';
	
	#my $update_label = $Data->{'SystemConfig'}{'txtUpdateLabel_CLR'} || 'Update Clearance';
	my %FieldDefs = (
		CLR => {
			fields => {
					intClearanceID=> {
                        label => $lang->txt('Transfer No.'),
                        value => $dref->{'intClearanceID'},
                        type  => 'text',
					    readonly => '1',
                    },
				    MemberName=> {
                        label => $lang->txt('Person being Transferred'),
                        value => $dref->{'MemberName'},
                        type  => 'text',
					    readonly => '1',
                    },
                    dtDOB => {
                        label => $lang->txt('Date of Birth'),
                        value => $dref->{'dtDOB'},
                        type  => 'text',
					    readonly => '1',
                    },
                    strState=> {
                        label => $lang->txt('State'),
                        value => $dref->{'strState'},
                        type  => 'text',
					    readonly => '1',
                    },
                    SourceEntityName => {
                        label => $lang->txt('From Club'),
                        value => $dref->{'SourceEntityName'},
                        type  => 'text',
					    readonly => '1',
                    },
                    DestinationEntityName => {
                        label => $lang->txt('To Club'),
                        value => $dref->{'DestinationEntityName'},
                        type  => 'text',
					    readonly => '1',
                    },
                    Reason=> {
                        label => $lang->txt('Reason for Transfer'),
                        value => $dref->{'strReason'},
                        type  => 'text',
					    readonly => '1',
                    },
				    intClearanceStatus=> {
                        label => $lang->txt('Transfer Status'),
					    value => $dref->{'PathStatus'},
                        type  => 'lookup',
					options => \%Defs::clearance_status_approvals,
					compulsory => 1,
                        		firstoption => ['','Select Status'],
					readonly => $readonly,
                		},
				strPathNotes => {
					label => $lang->txt('Additional Information'),
					value => $dref->{'strPathNotes'},
					type => 'textarea',
					readonly => $extrafields_readonly,
				},
				strApprovedBy=> {
					label => $lang->txt('Approved By'),
					value => $dref->{'strApprovedBy'},
					type => 'text',
					readonly => $extrafields_readonly,
					compulsory => $Data->{'SystemConfig'}{'ClrApprovedBy_NotCompulsory'} ? 0 : 1,
				},
				strPathFilingNumber => {
					label => $lang->txt('Reference Number at this level'),
					value => $dref->{'strPathFilingNumber'},
					type => 'text',
					readonly => $extrafields_readonly,
					noadd=> $strFilingNumber,
					noedit=> $strFilingNumber,
				},
				 intDenialReasonID=> {
					label => $lang->txt('Reason for Denial'),
				    value => $dref->{intDenialReasonID},
				    type  => 'lookup',
        			options => $DefCodes->{-38},
        			order => $DefCodesOrder->{-38},
					firstoption => ['',$lang->txt("Choose Reason")],
	      		},
		},
		order => [qw(intClearanceID MemberName dtDOB strState SourceEntityName DestinationEntityName intClearanceStatus strApprovedBy intDenialReasonID strPathNotes)],
			options => {
				labelsuffix => ':',
				hideblank => 1,
				target => $Data->{'target'},
				formname => 'clr_form',
				submitlabel => $update_label,
				introtext => 'auto',
				buttonloc => 'bottom',
				updateSQL => $clrupdate,
				auditFunction=> \&auditLog,
        auditAddParams => [
          $Data,
          'Add',
          $lang->txt('Transfer Path')
        ],
        auditEditParams => [
          $cpID,
          $Data,
          'Update',
          $lang->txt('Transfer Path')
        ],

				afterupdateFunction => \&updateClearance,
				afterupdateParams=> [$option,$Data,$Data->{'db'}, $cID, $cpID],
				stopAfterAction => 1,
				updateOKtext => qq[<div class="OKmsg">] . $lang->txt('Record updated successfully') . qq[</div> <br>
					<a href="$Data->{'target'}?client=$client&amp;a=CL_view&amp;cID=$cID&amp;cpID=$cpID">] . $lang->txt('Return to Transfer Details') . qq[</a>
				],
				addOKtext => qq[
					<div class="OKmsg">] . $lang->txt('Record updated successfully') . qq[</div> <br>
					<a href="$Data->{'target'}?client=$client&amp;a=CL_details">] . $lang->txt('Return to Transfer Details') . qq[</a>
				],
			},
			sections => [ ['main',$lang->txt('Details')], ],
			carryfields =>  {
				client => $client,
				a=> 'CL_details',
				cpID => $cpID,
				cID => $cID,
			},
		},
	);
	$FieldDefs{'CLR'}{'fields'}{'intDenialReasonID'}{'compulsory'}=1 if ($Data->{'SystemConfig'}{'clrDenialReason_compulsory'} and param('d_intClearanceStatus') == $Defs::CLR_STATUS_DENIED);
	($resultHTML, undef )=handleHTMLForm($FieldDefs{'CLR'}, undef, $option, '',$db);
	$resultHTML = destinationEntityText($Data) . $resultHTML if ($dref->{intDestinationEntityID} == $dref->{intID});

	my $clrDenialBlob=  $Data->{'SystemConfig'}{'ClearancesDenialBlob'} || '';
	$resultHTML .= $clrDenialBlob;

	$resultHTML .= showPathDetails($Data, $cID, $dref->{intClearanceStatus});

	if($option eq 'display')	{
		$resultHTML .=qq[ <a href="$target?a=CL_details&amp;tID=$dref->{'intTransactionID'}&amp;client=$client">] . $lang->txt('Edit Details') . qq[</a> ] if !$Data->{'ReadOnlyLogin'};
	}

	$resultHTML .= memberLink($Data, $cID);


		$resultHTML=qq[<div>]. $lang->txt('This member does not have any Transaction information to display') . qq[</div>
		] if !ref $dref;

		$resultHTML=qq[
				<div class="alphaNav">$toplist</div>
				<div>
					$resultHTML
				</div>
		];
		my $heading=$lang->txt('Transfer');
		return ($resultHTML,$heading);
}

sub memberLink	{

	my ($Data, $cID) = @_;
    my $lang = $Data->{'lang'};

	my $destClubID = getID($Data->{'clientValues'}) || -1; #{'clubID'} || -1;
	$cID ||= 0;

	my $st = qq[
		SELECT *
		FROM tblClearance
		WHERE intClearanceID = $cID
			AND intDestinationEntityID = $destClubID
	];
	my $query = $Data->{'db'}->prepare($st) or query_error($st);
	$query->execute or query_error($st);
	my $dref=$query->fetchrow_hashref();

	if ($dref->{intClearanceID} and $dref->{intPersonID} and $dref->{intClearanceStatus} == $Defs::CLR_STATUS_APPROVED)	{
 		my %tempClientValues = %{$Data->{clientValues}};
        $tempClientValues{personID} = $dref->{intPersonID};
        $tempClientValues{personID} = $dref->{intPersonID};
        $tempClientValues{currentLevel} = $Defs::LEVEL_PERSON;
        my $tempClient = setClient(\%tempClientValues);
		return qq[ <div class="OKmsg">] . $lang->txt('The transfer has now been finalised') . qq[</div><br><a href="$Data->{'target'}?client=$tempClient&amp;a=P_HOME">] . $lang->txt('click here to display persons record') . qq[</a>];

	}
	return '';
}
sub destinationEntityText	{

### PURPOSE: This function returns text that is displayed at the top of the clearance approval record when its the destination clubs turn to decide whether they actually want to member.  At this stage, all other levels would have approved the clearance.

	my ($Data) = @_;
    my $lang = $Data->{'lang'};

	return '';
	my $body = $lang->txt('By approving this transfer, you will receive the person.<br>You also agree to pay any Fees incurred by the transferring of this player');
	return qq[<p class="heading1" style="font-size:16px;color:red;">$body</p>];

}

sub updateClearance	{

### PURPOSE: This function is called as an afterupdatefunction of clearancePathDetails.
### It updates the clearance record to what ever status, notes etc.. that the logged in level gave the path record.

### Once its done, it will try and do any Auto Confirms, then will send an email.

	my($id,$params,$action,$Data,$db, $cID, $cpID)=@_;


	if ($params->{d_intClearanceStatus} == $Defs::CLR_STATUS_DENIED)	{
		my $st = qq[
			UPDATE tblClearance
			SET intClearanceStatus = $Defs::CLR_STATUS_DENIED, dtFinalised = NOW()
			WHERE intClearanceID = $cID
		];
		my $query = $db->prepare($st) or query_error($st);
		$query->execute or query_error($st);
		sendCLREmail($Data, $cID, 'DENIED');
	}
	else	{
		if ($params->{d_intClearanceStatus} == $Defs::CLR_STATUS_APPROVED)	{
			## IF it was denied, then reopen if appropriate
			my $st = qq[
				UPDATE tblClearance
				SET intClearanceStatus = $Defs::CLR_STATUS_PENDING, dtFinalised = NULL
				WHERE intClearanceID = $cID
					AND intClearanceStatus =$Defs::CLR_STATUS_DENIED 
				AND intCurrentPathID <= $cpID
			];
			### BAFF ADDED ABOVE !!!!!
			my $query = $db->prepare($st) or query_error($st);
			$query->execute or query_error($st);
		}
		checkAutoConfirms($Data, $cID, $cpID);
	}

	my $st = qq[
		SELECT intClearancePathID, intClearanceStatus
		FROM tblClearancePath
		WHERE intClearanceID = $cID
		ORDER BY intOrder DESC
		LIMIT 1
	];
	my $query = $db->prepare($st) or query_error($st);
	$query->execute or query_error($st);
	my ($intFinalCPID, $intClearanceStatus) = $query->fetchrow_array();
	if ($intClearanceStatus == $Defs::CLR_STATUS_APPROVED)	{
		finaliseClearance($Data, $cID);
	}
	else	{
		sendCLREmail($Data, $cID, 'PATH_UPDATED');
	}
}

sub checkAutoConfirms	{

### PURPOSE: This function, when called from Clearance ADD or Path UPDATE, checks to see if any of the next path levels have Clearance Settings, and then applies these.
### Also, if the next path level is invisible (ie: an invisible zone level), then its auto confirmed.


	my($Data,$cID, $cpID)=@_;

	my $db = $Data->{'db'};
	$cpID ||= 0;
	my $cpWHERE = $cpID ? qq[ AND C.intCurrentPathID <= $cpID] : '';
	
	my $st = qq[
		SELECT 
            CP.intClearancePathID, 
            CP.intID, 
            CP.intTypeID, 
            M.dtDOB, 
            N.intStatusID, 
            N.intNodeID, 
            intDirection
		FROM tblClearance as C 
			INNER JOIN tblPerson as M ON (M.intPersonID = C.intPersonID)
			INNER JOIN tblClearancePath as CP ON (C.intClearanceID = CP.intClearanceID)
			LEFT JOIN tblNode as N ON (N.intNodeID = CP.intID AND CP.intTableType = $Defs::NODE_LEVEL_CLEARANCE)
		WHERE C.intClearanceID = $cID
			AND C.intClearanceStatus = 0
			AND CP.intClearanceStatus IN (0,2)
		ORDER BY CP.intOrder
	];
	my $query = $db->prepare($st) or query_error($st);
	$query->execute or query_error($st);

	my $st_path_update = qq[
		UPDATE tblClearancePath
		SET strApprovedBy = 'Auto Approved', intClearanceStatus = ?
		WHERE intClearancePathID = ?
			AND intClearanceID = $cID
	];
	my $qry_path_update = $db->prepare($st_path_update) or query_error($st_path_update);

	my %pathIDs=();
	my $clearanceStatus = 0;
	my $currentPathID = 0;
	while (my $dref = $query->fetchrow_hashref())	{
		## BECAUSE WE ARE PULLING BACK MULTI RECORDS FOR EACH PATH RECORD (ie: FOR ASSOCTYPEID = xx and 0) NEED TO ONLY PROCESS THE PATHID ONCE.
		next if exists $pathIDs{$dref->{intClearancePathID}};
		next if ($clearanceStatus == 2);
		
		$pathIDs{$dref->{intClearancePathID}} = 1;

		$currentPathID = $dref->{intClearancePathID};
		my $intAutoApproval = getClearanceSettings($Data, $dref->{intID}, $dref->{intTypeID}, $dref->{dtDOB}, $dref->{intDirection});
		if ($dref->{intNodeID} and $dref->{intStatusID} eq '0' and $intAutoApproval == 0)	{
			$intAutoApproval = $Defs::CLR_AUTO_APPROVE;
		}
		if ($intAutoApproval == $Defs::CLR_AUTO_APPROVE)	{
			my $clearancePathStatus = $intAutoApproval;
			$qry_path_update->execute($clearancePathStatus, $dref->{intClearancePathID}) or query_error($st_path_update);
			$currentPathID = $dref->{intClearancePathID};
		}
		 elsif ($intAutoApproval == $Defs::CLR_AUTO_DENY)	{
			my $clearancePathStatus = $intAutoApproval;
			$clearanceStatus = 2;
			$currentPathID = $dref->{intClearancePathID};
			$qry_path_update->execute($clearancePathStatus, 0, $dref->{intClearancePathID}) or query_error($st_path_update);
		}
		else	{
			last;
		}

	}
	if ($currentPathID or $clearanceStatus)	{
	
		my $st_clr_update = qq[
			UPDATE tblClearance
			SET intCurrentPathID= $currentPathID, intClearanceStatus= $clearanceStatus
			WHERE intClearanceID = $cID
		];
		my $qry_clr_update = $db->prepare($st_clr_update) or query_error($st_clr_update);
		$qry_clr_update->execute or query_error($st_clr_update);
	}

	$query->finish();
}

sub getClearanceSettings	{
	
### PURPOSE: This function returns the clearance settings for the level and members DOB

	my($Data, $intID, $intTypeID, $dtDOB, $ruleDirection)=@_;

	my $db = $Data->{'db'};
	$ruleDirection ||= $Defs::CLR_BOTH;
	
	my $st = qq[
		SELECT 
            intClearanceSettingID, 
            intAutoApproval , 
            intRuleDirection
		FROM tblClearanceSettings
		WHERE intID = $intID
			AND intTypeID = $intTypeID
			AND (dtDOBStart <= '$dtDOB' or dtDOBStart = '0000-00-00' or dtDOBStart IS NULL)
				AND (dtDOBEnd >= '$dtDOB' or dtDOBEnd = '0000-00-00' or dtDOBEnd IS NULL)
			AND intRuleDirection IN ($ruleDirection, $Defs::CLR_BOTH)
		ORDER BY intRuleDirection DESC, dtDOBStart
		LIMIT 1
	];
	my $query = $db->prepare($st) or query_error($st);
	$query->execute or query_error($st);

	my ($intClearanceSettingID, $intAutoApproval, $intRuleDirection) = $query->fetchrow_array();
	$intRuleDirection ||= $Defs::CLR_BOTH;
	$intClearanceSettingID ||= 0;
	$intAutoApproval ||= 0;
	if (! $intClearanceSettingID)	{
		$intAutoApproval = $Data->{'SystemConfig'}{'clrDefaultApprovalAction'} || 0;
	}

	return $intAutoApproval;
	
	
}

sub finaliseClearance	{

### PURPOSE: Once the clearance has been finalised, this function inserts the appropriate person_registration records.

### Once done, it notifies all the levels via email of the current clearance status (ie:Finalised).

	my ($Data, $cID) = @_;

	### If successful, move person and notify everyone.
	my $db = $Data->{'db'};

	my $st = qq[
		SELECT 
            C.intPersonID, 
            C.intDestinationEntityID, 
            C.intSourceEntityID, 
            M.intGender, 
            DATE_FORMAT(M.dtDOB, "%Y%m%d") as DOBAgeGroup,
            C.strPersonType,
            C.strPersonSubType,
            C.strPersonLevel,
            C.strSport,
            C.intOriginLevel,
            C.strAgeLevel,
            C.strPersonEntityRole,
            E.intEntityLevel as DestinationEntityLevel
		FROM tblClearance as C
			INNER JOIN tblPerson as M ON (M.intPersonID = C.intPersonID)
		WHERE intClearanceID = $cID
	];
	my $query = $db->prepare($st) or query_error($st);
	$query->execute or query_error($st);

	my ($intPersonID, $intClubID, $intSourceEntityID, $Gender, $DOBAgeGroup, $personType, $personSubType, $personLevel, $sport, $originLevel, $ageLevel, $entityRole, $destinationEntityLevel) = $query->fetchrow_array();
	$intPersonID ||= 0;
	$intClubID ||= 0;
	$intSourceEntityID ||= 0;
	$Gender ||= 0;
	$DOBAgeGroup ||= '';

	return if ! $intPersonID or ! $intClubID;

	my $genAgeGroup||=new GenAgeGroup ($Data->{'db'},$Data->{'Realm'}, $Data->{'RealmSubType'});
	my $ageGroupID =$genAgeGroup->getAgeGroup($Gender, $DOBAgeGroup) || 0;

	my $intMA_Status = $Defs::RECSTATUS_ACTIVE;

    my %reg =();
    $reg{'personID'} = $intPersonID;
    $reg{'entityID'} = $intClubID;
    $reg{'personType'} = $personType;
    $reg{'personEntityRole'} = $entityRole;
    $reg{'personLevel'} = $personLevel;
    $reg{'sport'} = $sport;
    $reg{'originLevel'} = $originLevel; 
    $reg{'ageLevel'} = $ageLevel; 
    $reg{'ageGroupID'} = $ageGroupID;
    $reg{'current'} = 1;
    $reg{'entityLevel'} = $destinationEntityLevel;
    $reg{'registrationNature'} = 'TRANSFER';

    my $matrix_ref = getRuleMatrix($Data, $Defs::ORIGIN_SELF, $destinationEntityLevel, $Defs::LEVEL_PERSON, $reg{'entityType'} || '','REGO', \%reg);
    $reg{'paymentRequired'} = $matrix_ref->{'intPaymentRequired'} || 0;
    
    PersonRegistration::addRegistration($Data, \%reg);
    

#		$st = qq[
#			UPDATE tblPerson
#			SET intPlayer = 1
#			WHERE intPersonID=$intPersonID
#		];
#		$db->do($st);
	

#	$st = qq[
#	UPDATE tblPerson
#        SET strStatus = $Defs::RECSTATUS_ACTIVE
#		WHERE intPersonID = $intPersonID
#		AND intStatus = $Defs::RECSTATUS_DELETED
#		LIMIT 1
#	];
#	$db->do($st);
	$st = qq[
		UPDATE tblClearance
		SET intClearanceStatus = $Defs::CLR_STATUS_APPROVED, dtFinalised=NOW()
		WHERE intClearanceID = $cID
	];
	$db->do($st);

	$st = qq[
		UPDATE tblPersonRegistration_1
        SET strStatus="TRANSFERRED"
		WHERE intEntityID= $intSourceEntityID
            AND intCurrent=1
			AND intPersonID = $intPersonID
	];
	$db->do($st);

	sendCLREmail($Data, $cID, 'FINALISED');

}

sub createClearance	{

### PURPOSE: This function is used to create the clearance.  It prepares all of the screens in the create clearance wizard and then passes control to clearanceForm() (a HTMLForm function) to actually display the clearance questions and insert the records into db.

	my ($action, $Data) = @_;

    my $lang = $Data->{'lang'};

	#my $db = $Data->{'db'};
	my $db = connectDB('reporting');
	my $q=new CGI;
    my %params=$q->Vars();
	my $txt_Clr = $Data->{'SystemConfig'}{'txtCLR'} || 'Clearance';

	
	my $destinationEntityID = getID($Data->{'clientValues'}) || 0; #{'clubID'} || 0;
	my $sourceEntityID = $params{'sourceEntityID'} || $params{'d_sourceEntityID'} || 0;

	my $personID = $params{'personID'} || $params{'d_personID'} || 0;
	$params{'member_surname'} ||= '';
	$params{'member_dob'} ||= '';
	$params{'member_natnum'} ||= '';
	$params{'member_loggedsurname'} ||= '';
	$params{'member_systemsurname'} ||= '';
	$params{'member_dob'}=  '' if ! check_valid_date($params{'member_dob'});
	$params{'member_dob'}= _fix_date($params{'member_dob'}) if (check_valid_date($params{'member_dob'}));
	$params{'member_systemdob'}=  '' if ! check_valid_date($params{'member_systemdob'});
	$params{'member_systemdob'}= _fix_date($params{'member_systemdob'}) if (check_valid_date($params{'member_systemdob'}));

	my $body = '';

	my $hidden='';
	for my $key (keys %params)	{
		next if ($key =~ /^member_/);
		next if (! $params{$key});
		$hidden .= qq[ <input type="hidden" value="$params{$key}" name="$key">];
	}
	if (! $destinationEntityID)	{
		$body .=qq[Club not found];
		return $body;
	}

	if	(! $personID and ! $params{'member_surname'} and ! $params{'member_dob'} and ! $params{'member_natnum'} and ! $params{'member_loggedsurname'} and ! $params{'member_systemsurname'} and ! $params{'member_systemdob'})	{
		$body .= qq[
			<form action="$Data->{'target'}" method="POST">
			<p>] . $lang->txt('Fill in the members National Number, or enter Surname and DOB') . qq[<br></p>
			<table>
			<tr><td><span class="label">] . $lang->txt('Search on a National Number') . qq[:</span></td><td><span class="formw"><input type="text" name="member_natnum" value=""></span></td></tr>
			<tr><td><span class="label">] . $lang->txt('Search on Surname') . qq[:</span></td><td><span class="formw"><input type="text" name="member_surname" value=""></span></td></tr>
			<tr><td><span class="label">] . $lang->txt('Search on Date of Birth (dd/mm/yyyy)') . qq[:</span></td><td><span class="formw"><input type="text" name="member_dob" value=""></span></td></tr>
			</table>
			<input type="submit" name="submit" value="] . $lang->txt('Select Person') . qq[">	
			$hidden
			</form>
		];
	}
	elsif	(! $personID and ($params{'member_surname'} or $params{'member_dob'} or $params{'member_natnum'} or $params{'member_loggedsurname'} or ($params{'member_systemsurname'} and $params{'member_systemdob'})))	{
		my $strWhere = '';
		my %tParams = %params;
		deQuote($db, \%tParams);	
		if ($params{'member_natnum'})	{
			my $nn=$tParams{'member_natnum'};
			$nn="'$nn'" if $nn!~/'/; #'
			$strWhere .= qq[ AND M.strNationalNum = $nn];
		}
		if ($params{'member_surname'})	{
			$strWhere .= qq[ AND M.strLocalSurname =$tParams{'member_surname'}];
		}
		if ($params{'member_loggedsurname'})	{
			$strWhere .= qq[ AND M.strLocalSurname =$tParams{'member_loggedsurname'}];
		}
		if ($params{'member_systemsurname'})	{
			$strWhere .= qq[ AND M.strLocalSurname =$tParams{'member_systemsurname'}];
		}
		if ($params{'member_systemdob'})	{
			$strWhere .= qq[ AND M.dtDOB =$tParams{'member_systemdob'}];
		}
		if ($params{'member_dob'})	{
			$strWhere .= qq[ AND M.dtDOB =$tParams{'member_dob'}];
		}
		if ($sourceEntityID)	{
			$strWhere .= qq[ AND PR.intEntityID = $sourceEntityID];
		}

		if ($params{'member_dob'})	{
			$strWhere .= qq[ AND M.dtDOB =$tParams{'member_dob'}];
		}
		if ($sourceEntityID)	{
			$strWhere .= qq[ AND PR.intEntityID = $sourceEntityID];
		}
        my $entityID = getID($Data->{'clientValues'}); # {'clubID'}

		my $st = qq[
			SELECT DISTINCT 
                M.intPersonID, 
                M.strLocalFirstname, 
                M.strLocalSurname, 
                M.strNationalNum, 
                DATE_FORMAT(M.dtDOB,'%d/%m/%Y') AS DOB, 
                M.dtDOB, 
                C.intEntityID as intSourceEntityID,
                C.strLocalName as ClubName, 
                DATE_FORMAT(MAX(CLR.dtFinalised),'%d/%m/%Y') AS CLR_DATE
			FROM tblPerson as M 
                INNER JOIN tblPersonRegistration_$Data->{'Realm'} as PR ON (PR.intPersonID=M.intPersonID)
				INNER JOIN tblEntity as C ON (C.intEntityID= PR.intEntityID)
				LEFT JOIN tblClearance as CLR ON (CLR.intPersonID = M.intPersonID AND CLR.intDestinationEntityID = C.intEntityID)
			WHERE 
                M.intRealmID = $Data->{'Realm'}
				AND C.intEntityID <> $entityID 
				AND PR.strStatus <> 'TRANSFERRED'
                AND M.strStatus <> 'INPROGRESS'
                AND PR.strStatus <> 'INPROGRESS'
                AND M.intSystemStatus = $Defs::PERSONSTATUS_ACTIVE
				$strWhere
			GROUP BY M.intPersonID, C.intEntityID
			ORDER BY MAX(CLR.dtFinalised) DESC, M.strLocalSurname, M.strLocalFirstname, M.dtDOB
		];
		
		my $userID=getID($Data->{'clientValues'}, $Data->{'clientValues'}{'authLevel'}) || 0;

		my $query = $db->prepare($st) or query_error($st);
	    $query->execute or query_error($st);

		my ($sourceEntity, undef, undef) = getNodeDetails($db, $Defs::CLUB_LEVEL_CLEARANCE, $Defs::LEVEL_CLUB, $sourceEntityID);
		my $txt_RequestCLR =  $lang->txt('Request a Transfer');
		$body .= qq[
			<p>] . $lang->txt('Select a person from the club') . qq[ <b>$sourceEntity</b> ] . $lang->txt('in which to Transfer') . qq[</p>
                	<table class="listTable">
				<tr>
					<th>&nbsp;</th>
					<th>] . $lang->txt('Surname') . qq[</th>
					<th>] . $lang->txt('Firstname') . qq[</th>
					<th>] . $lang->txt('Club') . qq[</th>
					<th>] . $lang->txt('Date Cleared to Club') . qq[</th>
					<th>] . $lang->txt('Date Last Registered') . qq[</th>
					<th>] . $lang->txt('Date of Birth') . qq[</th>
			        <th>$Data->{'SystemConfig'}{'NationalNumName'}</th>
			    </tr>
		];
		while (my $dref= $query->fetchrow_hashref())	{
			my $href = qq[client=$params{'client'}&amp;sourceEntityID=$dref->{'intSourceEntityID'}&amp;a=CL_createnew&amp;member_natnum=$params{'member_natnum'}];
			$href = qq[client=$params{'client'}&amp;sourceEntityID=$dref->{'intClubID'}&amp;a=CL_createnew&amp;member_natnum=$params{'member_natnum'}] if ($params{'member_loggedsurname'});
			$href = qq[client=$params{'client'}&amp;sourceEntityID=$dref->{'intClubID'}&amp;a=CL_createnew&amp;member_natnum=$params{'member_natnum'}] if ($params{'member_systemsurname'});
			$body .= qq[
				<tr>
			];
			if ($Data->{'SystemConfig'}{'Clearances_FilterClearedOut'} and $dref->{CLRD_ID})	{
				$body .= qq[<td><b>] . $lang->txt('TRANSFERRED') . qq[</b></td>];
			}
			else	{
				$body .= qq[<td><a href="$Data->{'target'}?$href&amp;personID=$dref->{intPersonID}">].$lang->txt('select').qq[</a></td>];
			}
			$body .= qq[
					<td>$dref->{strLocalSurname}</td>
					<td>$dref->{strLocalFirstname}</td>
					<td>$dref->{ClubName}</td>
					<td>$dref->{CLR_DATE} ($dref->{Club_STATUS})</td>
					<td>$dref->{LastRegistered}</td>
					<td>$dref->{DOB}</td>
					<td>$dref->{strNationalNum}</td>
				</tr>
			];
		}
		$body .= qq[</table>];
	}
	else	{
		my ($title, $cbody) = clearanceForm($Data, \%params,0,0,'add');
		$body .= $title . $cbody;
	}
	return $body;
}

sub clearanceForm	{

### PURPOSE: This function is called once the createClearance() function is ready to pass control to ask the destination club (who requested the clearance) the final clearance questions and then to write to DB.

### It has a postClearanceAdd() (afteraddfunction), which will create the clearance path.

  my($Data, $params, $personID, $id, $edit) = @_;
	$id ||= 0;	
    my $lang = $Data->{'lang'};

	my $db=$Data->{'db'} || undef;
	my $client=setClient($Data->{'clientValues'}) || '';
	my $target=$Data->{'target'} || '';
	my $option=$edit ? ($id ? 'edit' : 'add')  :'display' ;

	my $destinationEntityID = getID($Data->{'clientValues'}) || 0 ;#{'clubID'} || 0;

	my $member_natnum= $params->{'member_natnum'} || 0;
	my $sourceEntityID = $params->{'sourceEntityID'} || 0;
	my $realm = $params->{'realmID'} || $Data->{'Realm'} || 0;

	my ($sourceEntity, undef, undef) = getNodeDetails($db, $Defs::CLUB_LEVEL_CLEARANCE, $Defs::LEVEL_CLUB, $sourceEntityID);
	$personID = $personID || $params->{'personID'} || 0;
	my $statement = qq[
		SELECT 
            *,     
            DATE_FORMAT(dtDOB,'%d/%m/%Y') AS DOB
		FROM tblPerson 
		WHERE intPersonID = $personID
	];
	my $query = $db->prepare($statement);
	$query->execute;
	my $memref = $query->fetchrow_hashref();

	my $body = '';

  	my $resultHTML = '';

	$statement=qq[
		SELECT * 
		FROM tblClearance
		WHERE intClearanceID=$id
	];

	$query = $db->prepare($statement);
	my $RecordData={};
	$query->execute;
	my $dref=$query->fetchrow_hashref();
	my $clrupdate=qq[
		UPDATE tblClearance
			SET --VAL--
		WHERE intClearanceID=$id
	];
	my $intClearanceYear =$Data->{'SystemConfig'}{'clrClearanceYear'} || 0;

    my $clradd=qq[
        INSERT INTO tblClearance (intPersonID, intDestinationEntityID, intSourceEntityID, intRealmID, --FIELDS--, dtApplied, intClearanceStatus, intRecStatus, intClearanceYear )
            VALUES ($personID, $destinationEntityID, $sourceEntityID, $realm, --VAL--,  SYSDATE(), $Defs::CLR_STATUS_PENDING, $Defs::RECSTATUS_ACTIVE,  $intClearanceYear)
    ];

    my ($DefCodes, $DefCodesOrder) = getDefCodes(
        dbh        => $Data->{'db'}, 
        realmID    => $Data->{'Realm'},
        subRealmID => $Data->{'RealmSubType'},
        onlyTypes  => '-37',
    );
       
	my $intReasonForClearanceID = ($Data->{'SystemConfig'}{'clrHide_intReasonForClearanceID'}==1) ? '1' : '0';
	my $strReasonForClearance =($Data->{'SystemConfig'}{'clrHide_strReasonForClearance'}==1) ? '1' : '0';
	my $strReason=($Data->{'SystemConfig'}{'clrHide_strReason'}==1) ? '1' : '0';
	my $strFilingNumber = ($Data->{'SystemConfig'}{'clrHide_strFilingNumber'} == 1) ? '1' : '0';
	my $intClearancePriority= ($Data->{'SystemConfig'}{'clrHide_intClearancePriority'}==1) ? '1' : '0';

	my $update_label = $lang->txt('Update Transfer');
	my $update_labelClr = $lang->txt('Update Transfer');
	my %FieldDefs = (
		Clearance => {
			fields => {
				SourceEntity => {
					label => $lang->txt('Source Club'),
					value => $sourceEntity,
					type=> 'text',
					readonly => 1,
				},
				MemberName => {
					label => $lang->txt('Person'),
					value => qq[$memref->{strLocalFirstname} $memref->{strLocalSurname}],
					type=> 'text',
					readonly => 1,
				},
				NatNum=> {
					label => $Data->{'SystemConfig'}{'NationalNumName'},
					value => $memref->{'strNationalNum'},
                    type  => 'text',
					readonly => '1',
                },
				DOB => {
					label => $lang->txt('Date of Birth'),
					value => $memref->{'DOB'},
                    type  => 'text',
					readonly => '1',
				},	
				strState=> {
					label => $lang->txt('State'),
					value => $memref->{'strState'},
                    type  => 'text',
					readonly => '1',
                },
				 intReasonForClearanceID => {
					label => $lang->txt('Reason for Transfer'),
				    value => $dref->{intReasonForClearanceID},
				    type  => 'lookup',
        			options => $DefCodes->{-37},
        			order => $DefCodesOrder->{-37},
					firstoption => ['',$lang->txt("Choose Reason")],
					readonly => $intReasonForClearanceID,
	      		},
				strReason=> {
					label => $lang->txt('Reason for Transfer'),
					value => $dref->{'strReason'},
                    type  => 'text',
					readonly => $strReason,
				},	
				strReasonForClearance=> {
					label => $lang->txt('Additional Information'),
					type => 'textarea',
					value => $dref->{'strReasonForClearance'},
					rows => 5,
                	cols=> 45,
					readonly => $strReasonForClearance,
				},
				strFilingNumber => {
					label => $lang->txt('Reference Number'),
					value => $dref->{'strFilingNumber'},
                    type  => 'text',
					readonly => $strFilingNumber,
				},	
				intClearancePriority=> {
					label => $lang->txt('Transfer Priority'),
                    value => $dref->{'intClearancePriority'},
                    type  => 'lookup',
                    options => \%Defs::clearance_priority,
                    firstoption => ['','Select Priority'],
					readonly => $intClearancePriority,
                },
			},
			order => [qw(MemberName NatNum DOB strState SourceEntity intReasonForClearanceID strReasonForClearance )],
			options => {
				labelsuffix => ':',
				hideblank => 1,
				target => $Data->{'target'},
				formname => 'clearance_form',
				submitlabel => $update_label,
				introtext => 'auto',
				buttonloc => 'bottom',
				updateSQL => $clrupdate,
				addSQL => $clradd,
				beforeaddFunction => \&preClearanceAdd,
                beforeaddParams => [$Data,$client, $personID, getID($Data->{'clientValues'})],
				afteraddFunction => \&postClearanceAdd,
				afteraddParams=> [$option,$Data,$Data->{'db'}],
				auditFunction=> \&auditLog,
        auditAddParams => [
          $Data,
          'Add',
            $lang->txt('Transfer')
        ],
        auditEditParams => [
          $Data,
          'Update',
           $lang->txt('Transfer')
        ],
				stopAfterAction => 1,
				updateOKtext => qq[
					<div class="OKmsg">] . $lang->txt('Record updated successfully') . qq[</div> <br>
					<a href="$Data->{'target'}?client=$client&amp;a=CL_list">] . $lang->txt('Return to Transfer') . qq[</a>],
				addOKtext => qq[
					<div class="OKmsg">] . $lang->txt('Record updated successfully') . qq[</div> <br>
					<a href="$Data->{'target'}?client=$client&amp;a=CL_list">] . $lang->txt('Return to Transfer') . qq[</a>],
			},
			sections => [ ['main',$lang->txt('Details')], ],
			carryfields =>  {
				client => $client,
				a=> 'CL_createnew',
				clrID => $id,
				sourceEntityID => $sourceEntityID,
				destinationEntityID => $destinationEntityID,
				member_natnum => $member_natnum,
				personID => $personID,
				realmID => $Data->{'clientValues'}{'Realm'},
			},
		},
	);

	($resultHTML, undef )=handleHTMLForm($FieldDefs{'Clearance'}, undef, $option, '',$db);

  $resultHTML=qq[<div>] . $lang->txt('This person does not have any Transaction information to display') . qq[</div>] if !ref $dref;

  $resultHTML=qq[
				<div>
					$resultHTML
				</div>
		];
  my $heading=qq[];
  return ($resultHTML,$heading);

}

sub preClearanceAdd	{

    ### PURPOSE: Check whether the current member is in a pending clearance, or already in the club.
    
    my($params, $Data, $client, $personID, $destinationEntityID)=@_;
    my $db = $Data->{'db'};
    my $lang = $Data->{'lang'};
    
	if ($Data->{'SystemConfig'}{'clrNoMoreAdds'})	{
	    my $error = qq[ <div class="warningmsg">] . $lang->txt('Transfers are unable to be added') . qq[</div>];
        return (0,$error);
	}
    
	$personID ||= 0;
	my $st = qq[
			SELECT
				C.intClearanceID,
				C1.strLocalName as DestinationEntityName, 
				C2.strLocalName as SourceEntityName, 
				C1.intEntityID as DestinationEntityID,
                C2.intEntityID as SourceEntityID,
				DATE_FORMAT(dtApplied,'%d/%m/%Y') AS AppliedDate 
			FROM
				tblClearance as C
				LEFT JOIN tblEntity as C1 ON (C1.intEntityID = C.intDestinationEntityID)
				LEFT JOIN tblEntity as C2 ON (C2.intEntityID = C.intSourceEntityID)
		WHERE intPersonID = $personID
			AND  intClearanceStatus = $Defs::CLR_STATUS_PENDING
			AND intCreatedFrom =0
	];
	my $query = $db->prepare($st) or query_error($st);
        $query->execute or query_error($st);

	my $error_text = '';
	my $existingClearance=0;
     
     while (my $dref = $query->fetchrow_hashref())	{
         $existingClearance++;
         $error_text .= qq[
                	<div class="warningmsg">] . $lang->txt('The selected person is already involved in a pending transfer.  Unable to continue until the below transaction is finalised') . qq[</div>
				<p>
					<b>] . $lang->txt('Date Requested') . qq[:</b> $dref->{AppliedDate}<br>
					<b>] . $lang->txt('Requested From') . qq[:</b> $dref->{SourceEntityName}<br>
					<b>] . $lang->txt('Request To') . qq[:</b> $dref->{DestinationEntityName}<br>
				</p>
        	];
	}

        return (0,$error_text) if $existingClearance;
        return (1,'');

}

sub getEntityLevel {

    my ($db, $entityID) = @_;

    my $st = qq[
        SELECT 
            intEntityLevel
        FROM
            tblEntity
        WHERE intEntityID = ?
    ];
	my $query = $db->prepare($st) or query_error($st);
    $query->execute($entityID) or query_error($st);
    return $query->fetchrow_array() || 0;
}



sub postClearanceAdd	{

### PURPOSE: This function build's up the starting points between the two clubs then calls getMeetingPoint() to do the grunt work in finding the top node

	my($id,$params,$action,$Data,$db)=@_;
  	return undef if !$db or ! $id;
	my $resultHTML = '';

		my @sourceNodes = ();	
		my @destinationNodes = ();
		my $sourceNodeID=0;
		my $destinationNodeID=0;
		my $sourceTypeID = 0;
		my $destinationTypeID =0;
		my $destinationStatusID =0;
		my $sourceStatusID =0;
#$params->{'destinationEntityID'}=14;
	
		my $destinationEntityPathID = 0;
		
		my $found = getMeetingPoint($db, $params->{'sourceEntityID'}, $params->{'destinationEntityID'}, \@sourceNodes, \@destinationNodes);
        my %EntitiesUsed=();
	
		if ($found)	{
			my $insert_st = qq[
				INSERT INTO tblClearancePath
				(intClearanceID, intTypeID, intTableType, intID, intOrder, intDirection, intClearanceStatus)
				VALUES ($id, ?, ?, ?, ?, ?, $Defs::CLR_STATUS_PENDING)
			];
	    	my $qry_insert = $db->prepare($insert_st) or query_error($insert_st);
			my $count=1;
		

            my $srcLevel = getEntityLevel($db, $params->{'sourceEntityID'});
			$qry_insert->execute($srcLevel, $Defs::CLUB_LEVEL_CLEARANCE, $params->{'sourceEntityID'}, $count, $Defs::DIRECTION_FROM_SOURCE) if $params->{'sourceEntityID'};
            $EntitiesUsed{$params->{'sourceEntityID'}} = 1;
			my $firstPathID = $qry_insert->{mysql_insertid} || 0;
			
			$count++ if $params->{'sourceEntityID'};

			for my $node (reverse @sourceNodes)	{
                next if exists $EntitiesUsed{$node->[0]};
				$qry_insert->execute($node->[1], 3, $node->[0], $count, $Defs::DIRECTION_FROM_SOURCE);
                $EntitiesUsed{$node->[0]}  = 1;
				$count++;
			}
			my $skip_first = 0;
			for my $node (@destinationNodes)	{
				$skip_first++;
				next if $skip_first == 1; ## SKIP FIRST Destination NODE (ie: Its the top one).  IT WAS HANDLED IN SOURCE.
                next if exists $EntitiesUsed{$node->[0]};
				$qry_insert->execute($node->[1], 3, $node->[0], $count, $Defs::DIRECTION_TO_DESTINATION);
                $EntitiesUsed{$node->[0]}  = 1;
                $destinationEntityPathID = $qry_insert->{mysql_insertid} || 0;
				$count++;
			}
            my $destLevel = getEntityLevel($db, $params->{'destinationEntityID'});
            if (! exists $EntitiesUsed{$params->{'destinationEntityID'}})   {
    			$qry_insert->execute($destLevel, $Defs::CLUB_LEVEL_CLEARANCE, $params->{'destinationEntityID'}, $count, $Defs::DIRECTION_TO_DESTINATION) if $params->{'destinationEntityID'};
	    		$destinationEntityPathID = $qry_insert->{mysql_insertid} || 0;
            }

			my $st = qq[
				UPDATE tblClearance
				SET intCurrentPathID = 0
				WHERE intClearanceID = $id
			];
				#SET intCurrentPathID = $firstPathID
			$db->do($st);
			checkAutoConfirms($Data, $id,0);
			$st = qq[
		        SELECT 
				intClearancePathID, 
				intClearanceStatus
		        FROM 
				tblClearancePath
	    		WHERE 
				intClearanceID = $id
        		ORDER BY 
				intOrder DESC
        		LIMIT 1
    		];
    		my $query = $db->prepare($st) or query_error($st);
    		$query->execute or query_error($st);
    		my ($intFinalCPID, $intClearanceStatus) = $query->fetchrow_array();

    		if ($intClearanceStatus == $Defs::CLR_STATUS_APPROVED)  {
        		finaliseClearance($Data, $id);
			$resultHTML = memberLink($Data, $id);
    		}
		
		}
	
	sendCLREmail($Data, $id, 'ADDED');
	return (0, $resultHTML);
}

sub getMeetingPoint	{

	### PURPOSE: This function works out how far up structure tree to go till the meeting entities are found.

	my ($db, $sourceEntityID, $destinationEntityID, $sourceNodes, $destinationNodes) = @_;
	my $found=0;

warn("SOURCE$sourceEntityID DES:$destinationEntityID");
	my $st = qq[
		SELECT 
            intChildID, 
            intParentID, 
            intParentLevel
		FROM 
            tblTempEntityStructure
		WHERE 
            intChildID IN ($sourceEntityID, $destinationEntityID)
            AND intParentLevel > $Defs::LEVEL_CLUB
            AND intPrimary=1
        ORDER BY intParentLevel ASC
	];
            #AND intChildLevel = 3
    my $query = $db->prepare($st) or query_error($st);
    $query->execute or query_error($st);

    my %EntityStructure = ();
	while (my $dref = $query->fetchrow_hashref())	{
        $EntityStructure{$dref->{'intChildID'}}{$dref->{'intParentLevel'}} = $dref->{'intParentID'};
    }

    my @Levels = (10,20,30,100);
    foreach my $level (@Levels) {
        my $srcEntityID = $EntityStructure{$sourceEntityID}{$level} || 0;
        my $destEntityID = $EntityStructure{$destinationEntityID}{$level} || 0;
        $found =1 if ($srcEntityID and $destEntityID and $srcEntityID == $destEntityID);
        $found= 1 if ($srcEntityID and $srcEntityID == $destinationEntityID);
        $found=1 if ($destEntityID and $sourceEntityID == $destEntityID);
	    push @{$sourceNodes}, [$srcEntityID, $level] if ($srcEntityID);
	    push @{$destinationNodes}, [$destEntityID, $level] if ($destEntityID);
        last if $found;
    }

	return $found;
}
sub check_valid_date    {
        my($date)=@_;
        my($d,$m,$y)=split /\//,$date;
        use Date::Calc qw(check_date);
        return check_date($y,$m,$d);
}
sub _fix_date  {
  my($date)=@_;
  return '' if !$date;
  my($dd,$mm,$yyyy)=$date=~m:(\d+)/(\d+)/(\d+):;
  if(!$dd or !$mm or !$yyyy)  { return '';}
  if($yyyy <100)  {$yyyy+=2000;}
  return "$yyyy-$mm-$dd";
}

sub clearanceAddManual	{

### PURPOSE: This function is used by the view members screen to add manual clearance history.  This clearance history doesn't have path approvals and has text descriptions for the source/destination nodes.

  my($Data) = @_;
	my $edit=1;
	my $q=new CGI;
  my %params=$q->Vars(); 
	my $id = $params{'clrID'};
    my $lang = $Data->{'lang'};

	my $db=$Data->{'db'} || undef;
	my $personID = $Data->{'clientValues'}{'personID'} || -1;
	my $client=setClient($Data->{'clientValues'}) || '';
	my $target=$Data->{'target'} || '';
	my $option=$edit ? ($id ? 'edit' : 'add')  :'display' ;

	my $destinationEntityID = getID($Data->{'clientValues'}) || 0; #{'clubID'} || 0;

	my $realm = $params{'realmID'} || $Data->{'Realm'} || 0;

	$personID = $personID || $params{'personID'} || 0;
	my $statement = qq[
		SELECT 
            *, 
            DATE_FORMAT(dtDOB,'%d/%m/%Y') AS DOB
		FROM tblPerson 
		WHERE intPersonID = $personID
	];
	my $query = $db->prepare($statement);
	$query->execute;
	my $memref = $query->fetchrow_hashref();

	my $body = '';

  	my $resultHTML = '';

	$id ||= 0;
	$statement=qq[
		SELECT 
            *, 
            DATE_FORMAT(dtApplied,'%d/%m/%Y') AS dtApplied
		FROM tblClearance
		WHERE intClearanceID=$id
			AND intPersonID = $personID
			AND intCreatedFrom = $Defs::CLR_TYPE_MANUAL
	];

	$query = $db->prepare($statement);
	my $RecordData={};
	$query->execute;
	my $dref=$query->fetchrow_hashref();
	my $clrupdate=qq[
		UPDATE tblClearance
			SET --VAL--
		WHERE intClearanceID=$id
			AND intPersonID = $personID
			AND intCreatedFrom = $Defs::CLR_TYPE_MANUAL
	];
	my $intClearanceYear = $Data->{'SystemConfig'}{'clrClearanceYear'} || 0;
    my $clradd=qq[
        INSERT INTO tblClearance (intPersonID, intRealmID, --FIELDS--, dtApplied, intClearanceStatus, intCreatedFrom, intRecStatus, intClearanceYear)
        VALUES ($personID, $realm, --VAL--,  SYSDATE(), $Defs::CLR_STATUS_APPROVED, 2, $Defs::RECSTATUS_ACTIVE, $intClearanceYear)
    ];

    my ($DefCodes, $DefCodesOrder) = getDefCodes(
        dbh        => $Data->{'db'}, 
        realmID    => $Data->{'Realm'},
        subRealmID => $Data->{'RealmSubType'},
        onlyTypes  => '-37',
    );
       
	my $update_label = $lang->txt('Update Transfer');

	my %FieldDefs = (
		Clearance => {
			fields => {
				strSourceEntityName => {
					label => $lang->txt('From Club'),
					value => $dref->{strSourceEntityName},
					type=> 'text',
				},
				strDestinationEntityName => {
					label => $lang->txt('To Club'),
					value => $dref->{strDestinationEntityName},
					type=> 'text',
				},
				MemberName => {
					label => $lang->txt('Person'),
					value => qq[$memref->{strLocalFirstname} $memref->{strLocalSurname}],
					type=> 'text',
					readonly => 1,
				},
				dtApplied => {
					label => $lang->txt('Date'),
					value => $dref->{'dtApplied'},
                     type  => 'text',
					readonly => '1',
				},	
				DOB => {
					label => $lang->txt('Date of Birth'),
					value => $memref->{'DOB'},
                    type  => 'text',
					readonly => '1',
				},	
				strState=> {
					label => $lang->txt('State'),
					value => $memref->{'strState'},
                    type  => 'text',
					readonly => '1',
               	},
				 intReasonForClearanceID => {
					label => $lang->txt('Reason for Transfer'),
				    value => $dref->{intReasonForClearanceID},
				    type  => 'lookup',
        			options => $DefCodes->{-37},
        			order => $DefCodesOrder->{-37},
					firstoption => ['',$lang->txt("Choose Reason")],
	      		},
				strReasonForClearance=> {
					label => $lang->txt('Additional Information'),
					type => 'textarea',
					value => $dref->{'strReasonForClearance'},
					rows => 5,
                	cols=> 45,
				},
				strFilingNumber => {
					label => $lang->txt('Reference Number'),
					value => $dref->{'strFilingNumber'},
                    type  => 'text',
				},	
				intClearancePriority=> {
					label => $lang->txt('Transfer Priority'),
                    value => $dref->{'intClearancePriority'},
                    type  => 'lookup',
                    options => \%Defs::clearance_priority,
                    firstoption => ['',$lang->txt('Select Priority')],
                 },
				intClearAction=> {
                    label => $lang->txt('Transfer Action'),
                    type  => 'lookup',
                    options => \%Defs::clearance_clearAction,
                    firstoption => ['',$lang->txt('Select Action')],
					SkipAddProcessing => 1,
					compulsory => ($option eq 'add' and $Data->{'SystemConfig'}{'Clearances_ClearAction'}) ? 1 : 0,
                },
			
			},
			order => [qw(dtApplied MemberName DOB strState strSourceEntityName strDestinationEntityName intReasonForClearanceID strReasonForClearance intClearAction)],
			options => {
				labelsuffix => ':',
				hideblank => 1,
				target => $Data->{'target'},
				formname => 'clearance_form',
				submitlabel => $update_label,
				introtext => 'auto',
				buttonloc => 'bottom',
				updateSQL => $clrupdate,
				addSQL => $clradd,

				auditFunction=> \&auditLog,
        auditAddParams => [
          $Data,
          'Add',
          $lang->txt('Manual Transfer')
        ],
        auditEditParams => [
          $Data,
          'Update',
          $lang->txt('Manual Transfer')
        ],

				afteraddFunction => \&postManualClrAction,
 				afteraddParams => [$Data,$Data->{'db'}],
				stopAfterAction => 1,
				updateOKtext => qq[
					<div class="OKmsg">] . $lang->txt('Record updated successfully') . qq[</div> <br>
					<a href="$Data->{'target'}?client=$client&amp;a=CL_list">] . $lang->txt('Return to Transfer') . qq[</a> ],
				addOKtext => qq[
					<div class="OKmsg">] . $lang->txt('Record updated successfully') . qq[</div> <br>
					<a href="$Data->{'target'}?client=$client&amp;a=CL_list">] . $lang->txt('Return to Transfer') . qq[</a> ],
			},
			sections => [ ['main',$lang->txt('Details')], ],
			carryfields =>  {
				client => $client,
				a=> 'CL_addmanual',
				clrID => $id,
				destinationEntityID => $destinationEntityID,
				personID => $personID,
				realmID => $Data->{'clientValues'}{'Realm'},
			},
		},
	);
	($resultHTML, undef )=handleHTMLForm($FieldDefs{'Clearance'}, undef, $option, '',$db);

  $resultHTML=qq[<div>] . $lang->txt('This person does not have any Transaction information to display') . qq[</div>] if !ref $dref;

	$resultHTML=qq[
			<div>
				$resultHTML
			</div>
	];
	my $heading=qq[];
	return ($resultHTML,$heading);
}

sub sendCLREmail	{

### PURPOSE: This function handles the emailing to all the levels of the current status of the clearance.  It contains the text body and subject of the email.

	my ($Data, $cID, $action) = @_;
    my $lang = $Data->{'lang'};

	return if ($Data->{'SystemConfig'}{'clrNoEmails'});
	return if (($Data->{'SystemConfig'}{'clrEmails_addOnly'} and $action ne 'ADDED') and ($Data->{'SystemConfig'}{'clrEmails_Denial'} and $action ne 'DENIED') and ($Data->{'SystemConfig'}{'clrEmails_Reminder'} and $action !~ /REMINDER/));
	$cID ||= 0;
	my $db = $Data->{'db'};
	return if ! $cID;

	my $st = qq[
		SELECT 
            CONCAT(M.strLocalFirstname, ' ', M.strLocalSurname) as MemberName, 
            C.*, 
            IF(intDestinationEntityID > 0, C1.strLocalName, strDestinationEntityName) as DestinationEntityName, 
            IF(intSourceEntityID > 0 , C2.strLocalName, strSourceEntityName) as SourceEntityName, 
            CP.intTableType, 
            CP.intTypeID, 
            CP.intID, 
            DATE_FORMAT(M.dtDOB,'%d/%m/%Y') AS dtDOB,  
            DATE_FORMAT(C.dtApplied,'%d/%m/%Y') AS dtApplied, 
            DC.strName as DenialCode, 
            C.strReasonForClearance
		FROM tblClearance as C
			INNER JOIN tblClearancePath as CP ON (CP.intClearanceID = C.intClearanceID)
			INNER JOIN tblPerson as M ON (M.intPersonID = C.intPersonID)
			LEFT JOIN tblEntity as C1 ON (C1.intEntityID = C.intDestinationEntityID)
			LEFT JOIN tblEntity as C2 ON (C2.intEntityID = C.intSourceEntityID)
            LEFT JOIN tblDefCodes as DC ON (DC.intCodeID = CP.intDenialReasonID)
		WHERE C.intClearanceID = $cID
			AND CP.intClearancePathID = C.intCurrentPathID
		LIMIT 1
	];
    	my $query = $db->prepare($st) or query_error($st);
    	$query->execute or query_error($st);
	my $cref = $query->fetchrow_hashref();

	return if ($cref->{SourceSubType} and $cref->{DestSubType} and $cref->{SourceSubType} == $cref->{DestSubType} and $Data->{'SystemConfig'}{'clrNoEmails_sameSubType'});
	my $email_subject = '';
	###BUILD UP TEXT
	my $additionalInformation='';
        if ($Data->{'SystemConfig'}{'clrEmailAdditionalInfo'} and $cref->{'strReasonForClearance'})     {
                $additionalInformation = $lang->txt('Additional Information') . qq[: $cref->{'strReasonForClearance'}];
        }
	my $email_body = $lang->txt('Transfer No.') . qq[: $cref->{intClearanceID}
] . $lang->txt('Person') . qq[: $cref->{MemberName}
] . $lang->txt('To Club') . qq[: $cref->{DestinationEntityName}
] . $lang->txt('Source (From) Club') . qq[: $cref->{SourceEntityName}
$additionalInformation

];

	my ($whos_turn, undef, undef) = getNodeDetails($db, $cref->{intTableType}, $cref->{intTypeID}, $cref->{intID});
	my $emailOnlyCurrentLevel = 0;

	my $viewDetails = $lang->txt('To view details, please log into the system and click on the List Transfers option');
	$viewDetails = $Data->{'SystemConfig'}{'clrEmail_detailsLink'} if ($Data->{'SystemConfig'}{'clrEmail_detailsLink'});

	$emailOnlyCurrentLevel = 1 if ($Data->{'SystemConfig'}{'clr_EmailOnlyCurrentLevel'});
	if ($action eq 'CANCELLED')	{
		$email_body .= $lang->txt('This Transfer has now been cancelled') . $viewDetails;
		$email_subject = $lang->txt('Transfer cancelled- No.') . qq[:$cref->{intClearanceID}- $cref->{MemberName}];
	}
	if ($action eq 'DENIED')	{
	    $emailOnlyCurrentLevel = 0;
		$email_body .= $lang->txt('This Transfer has been denied at') . qq[ $whos_turn] . $lang->txt('level') . qq[.] . $lang->txt('The Transfer should NOT be requested again');
        $email_body .= $lang->txt('The reason given for the denial is') . qq[: $cref->{DenialCode}] if ($cref->{DenialCode});
		$email_subject = $lang->txt('Transfer DENIED- No.') . qq[:$cref->{intClearanceID}- $cref->{MemberName} - DOB - $cref->{dtDOB}];
	}
	if ($action eq 'REOPEN')	{
	    $emailOnlyCurrentLevel = 0;
		$email_body .= $lang->txt('The above Transfer has now been reopened.') . qq[

]. $lang->txt('Current Level for Approval') . qq[: $whos_turn

$viewDetails ];
		$email_subject = $lang->txt('Transfer reopened- No.') . qq[:$cref->{intClearanceID}- $cref->{MemberName} - DOB - $cref->{dtDOB}];
	}
	if ($action eq 'ADDED')	{
		$email_body .= $lang->txt('The above Transfer has been added') . qq[

] . $lang->txt('Current Level for Approval') . qq[: $whos_turn

$viewDetails ];
		$email_subject = $lang->txt('New request for Transfer- No.') . qq[:$cref->{intClearanceID}- $cref->{MemberName} - $cref->{dtDOB}];

		return if ($Data->{'SystemConfig'}{'clrEmail_turnOff_New'});
	}
	if ($action eq 'PATH_UPDATED')	{
		$email_body .= $lang->txt('The above Transfer has been updated') . qq[

] . $lang->txt('Current Level for Approval') . qq[: $whos_turn

$viewDetails
] . $lang->txt('Be sure to check the Transfer to see when its your turn to approve/deny it');
		$email_subject = $lang->txt('Transfer Updated- No.') . qq[:$cref->{intClearanceID}- $cref->{MemberName} - $cref->{dtDOB}];
	}
	if ($action eq 'FINALISED')	{
		$email_body .= $lang->txt('The above Transfer has been finalised') .  $viewDetails;
        $email_subject = $lang->txt('Transfer finalised- No.') . qq[:$cref->{intClearanceID}- $cref->{MemberName} - DOB - $cref->{dtDOB}];

	}

	my $st_path = qq[
		SELECT 
            intClearancePathID, 
            intTableType, 
            intTypeID, 
            intID
		FROM tblClearancePath
		WHERE intClearanceID = $cID
	];
    	my $qry_path = $db->prepare($st_path) or query_error($st_path);
    	$qry_path->execute or query_error($st_path);
	my $cc_list = '';
	while (my $dref = $qry_path->fetchrow_hashref())	{
		next if $emailOnlyCurrentLevel and $dref->{intClearancePathID} != $cref->{intCurrentPathID};
		my (undef, undef, $email) = getNodeDetails($db, $dref->{intTableType}, $dref->{intTypeID}, $dref->{intID});
        my $cs_emails = getServicesContactsEmail($Data, $dref->{intTypeID}, $dref->{intID}, $Defs::SC_CONTACTS_CLEARANCES);
        $email = $cs_emails if ($cs_emails);
		$email ||= '';
		if ($email)	{
			$cc_list .= qq[;] if ($cc_list);
			$cc_list .= $email;
		}
	}

    if ($Data->{'clrCCEmails'}) {
        $cc_list .= qq[;] if ($cc_list);
        $cc_list .= $Data->{'clrCCEmails'};
        $email_body = $email_body . $Data->{'clrCCmsg'};
    }
	
	sendEmail($cc_list, $email_body, $email_subject, $cID, $action);
}
sub sendEmail   {

### PURPOSE: Used to send the clearance email.

        my ($email, $message_str, $subject, $cID, $action)=@_;
	my $boundary="====SportingPulse-r53q6w8sgydixlgfxzdkgkh====";
    #    my $contenttype=qq[multipart/mixed; boundary="$boundary"];
	my $contenttype=qq[text/plain; charset="us-ascii"; boundary="$boundary"];

        my $message=qq[

This is a multi-part message in MIME format...

--].$boundary.qq[
Content-Type: text/plain
Content-Disposition: inline
Content-Transfer-Encoding: 8bit\n\n];
#Content-Transfer-Encoding: binary\n\n];

$message='';

        my %mail = (
		To => "$email",
		From  => "$Defs::donotreply_email_name <$Defs::donotreply_email>",
		Subject => $subject,
		Message => $message,
		'Content-Type' => $contenttype,
		'Content-Transfer-Encoding' => "binary"
        );
        $mail{Message}.="$message_str\n\n------------------------------------------\n\n" if $message_str;
        $mail{Message}.="\n\n$Defs::sitename <$Defs::donotreply_email>",

        my $error=1;
        if($mail{To}) {
                if($Defs::global_mail_debug)  { $mail{To}=$Defs::global_mail_debug;}
                open MAILLOG, ">>$Defs::mail_log_file" or print STDERR "Cannot open MailLog $Defs::mail_log_file\n";
                if (sendmail %mail) {
                        print MAILLOG (scalar localtime()).":CLR:$cID $action $mail{To}:Sent OK.\n" ;
                        $error=0;
                }
                else {
                        print MAILLOG (scalar localtime())." CLR:$cID $mail{To}:Error sending mail: $Mail::Sendmail::error \n" ;
                }
                close MAILLOG;
        }
}

sub postManualClrAction	{

	my($id,$params, $Data,$db)=@_;

	my $clrAction = $params->{'d_intClearAction'} || 0;
	my $clubID = getID($Data->{'clientValues'}) || 0; #{'clubID'} || 0;
	my $personID = $Data->{'clientValues'}{'personID'} || 0;

	$clubID = 0 if ($clubID == $Defs::INVALID_ID);
	$personID = 0 if ($personID == $Defs::INVALID_ID);

	if ($params->{'d_intClearAction'} == 1 and $clubID and $personID)	{
		## CLEAR MEMBER OUT !
		my $st = qq[
			INSERT INTO tblMember_ClubsClearedOut (
				intRealmID, 
				intClubID, 
				intPersonID, 
				intClearanceID 
			)
                	VALUES (
				$Data->{'Realm'}, 			
				$clubID,
				$personID,
				$id
			)
		];
		$db->do($st);
                $st= qq[
                        UPDATE
                                tblMember_Clubs
                        SET
                                intStatus = $Defs::RECSTATUS_INACTIVE
                        WHERE
                                intPersonID = $personID
                                AND intClubID = $clubID
                                AND intStatus = $Defs::RECSTATUS_ACTIVE
                ];
                $db->do($st);
	}
	if ($params->{'d_intClearAction'} == 2 and $clubID and $personID)	{
		## CLEAR MEMBER IN !
		my $st = qq[
			DELETE FROM 
				tblMember_ClubsClearedOut
                	WHERE 
				intRealmID = $Data->{'Realm'}
                        	AND intClubID = $clubID
                        	AND intPersonID = $personID
		];
		$db->do($st);

		$st= qq[
                        UPDATE
                                tblMember_Clubs
                        SET
                                intStatus = $Defs::RECSTATUS_ACTIVE
                        WHERE
                                intPersonID = $personID
                                AND intClubID = $clubID
                                AND intStatus = $Defs::RECSTATUS_INACTIVE
                        LIMIT 1
                ];
                $db->do($st);
	}

}

1;
