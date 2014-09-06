package WorkFlow;
require Exporter;
@ISA = qw(Exporter);
@EXPORT = @EXPORT_OK = qw(
	handleWorkflow
  	addWorkFlowTasks
  	approveTask
  	checkForOutstandingTasks
);

use strict;
use lib '.', '..', 'Clearances'; #"comp", 'RegoForm', "dashboard", "RegoFormBuilder",'PaymentSplit', "user";
use Utils;
use Reg_common;
use TTTemplate;
use Log;
use PersonUtils;
use Clearances;
use Duplicates;

sub handleWorkflow {
    my ( 
    	$action, 
    	$Data
    	 ) = @_;
 
	my $body = '';
	my $title = '';
	
	if ( $action eq 'WF_Approve' ) {
        approveTask($Data);
        ( $body, $title ) = listTasks( $Data );	
    }
    elsif ( $action eq 'WF_Reject' ) {
        rejectTask($Data);
        ( $body, $title ) = listTasks( $Data );	
    }
	else {
        ( $body, $title ) = listTasks( $Data );		
	};
   
    return ( $body, $title );
}

sub listTasks {
     my(
        $Data,
    ) = @_;

	my $body = '';
   	my $st = '';
	my $q = '';
	my $db=$Data->{'db'};
	
	my $entityID = getID($Data->{'clientValues'},$Data->{'clientValues'}{'currentLevel'});
	
    $st = qq[
		SELECT 
            t.intWFTaskID, 
            t.strTaskStatus, 
            t.strTaskType, 
            pr.strPersonLevel, 
            pr.strAgeLevel, 
            pr.strSport, 
			t.strRegistrationNature, 
            dt.strDocumentName,
			p.strLocalFirstname, 
            p.strLocalSurname, 
            p.intGender as PersonGender,
            e.strLocalName as EntityLocalName,
            p.intPersonID, 
            t.strTaskStatus, 
            t.strWFRuleFor,
            uar.entityID as UserEntityID, 
            uarRejected.entityID as UserRejectedEntityID
		FROM tblWFTask AS t
        LEFT JOIN tblEntity as e ON (e.intEntityID = t.intEntityID)
		LEFT JOIN tblPersonRegistration_$Data->{'Realm'} AS pr ON (t.intPersonRegistrationID = pr.intPersonRegistrationID)
		LEFT JOIN tblPerson AS p ON (t.intPersonID = p.intPersonID)
		LEFT JOIN tblUserAuthRole AS uar ON ( t.intApprovalEntityID = uar.entityID )
		LEFT OUTER JOIN tblDocumentType AS dt ON (t.intDocumentTypeID = dt.intDocumentTypeID)
		LEFT JOIN tblUserAuthRole AS uarRejected ON ( t.intProblemResolutionEntityID = uarRejected.entityID )
		WHERE 
            t.intRealmID = $Data->{'Realm'}
			AND (
                (intApprovalEntityID = ? AND t.strTaskStatus = 'ACTIVE')
                OR
                (intProblemResolutionEntityID= ? AND t.strTaskStatus = 'REJECTED')
            )
    ];

        #my $userID = $Data->{'clientValues'}{'userID'}
        ## if ($userID)
        ## $st .= qqp AND t.intCreatedByUserID <> $userID ];

            #uar.userID as UserID, 
            #uarRejected.userID as RejectedUserID, 
            #AND t.intApprovalRoleID = uar.roleId
			#AND t.intProblemResolutionRoleID = uarRejected.roleId
            #AND
            #(
            #    uar.userID = ? 
            #    OR uarRejected.userID = ?
            #)
		#$Data->{'clientValues'}{'userID'},
		#$Data->{'clientValues'}{'userID'},

	$db=$Data->{'db'};
	$q = $db->prepare($st) or query_error($st);
	$q->execute(
		$entityID,
		$entityID,
	) or query_error($st);
	
	my @TaskList = ();
	my $rowCount = 0;
	  
	while(my $dref= $q->fetchrow_hashref()) {
		$rowCount ++;
        my $name = '';
        $name = $dref->{'EntityLocalName'} if ($dref->{strWFRuleFor} eq 'ENTITY');
        $name = formatPersonName($Data, $dref->{'strLocalFirstname'}, $dref->{'strLocalSurname'}, $dref->{'PersonGender'}) if ($dref->{strWFRuleFor} eq 'REGO' or $dref->{strWFRuleFor} eq 'PERSON');
		my %single_row = (
			WFTaskID => $dref->{intWFTaskID},
			TaskType => $dref->{strTaskType},
			AgeLevel => $dref->{strAgeLevel},
			RuleFor=> $dref->{strWFRuleFor},
			RegistrationNature => $dref->{strRegistrationNature},
			DocumentName => $dref->{strDocumentName},
            Name=>$name,
			LocalEntityName=> $dref->{EntityLocalName},
			LocalFirstname => $dref->{strLocalFirstname},
			LocalSurname => $dref->{strLocalSurname},
			PersonID => $dref->{intPersonID},			
			TaskStatus => $dref->{strTaskStatus},
		);
		push @TaskList, \%single_row;
	}

    ## Calc Dupl Res and Pending Clr here
    my $clrCount = getClrTaskCount($Data, $entityID);
    my $dupCount = Duplicates::getDupTaskCount($Data, $entityID);
    if ($clrCount)   {
        my %row=(
            TaskType => 'TRANSFERS',
            Name => $Data->{'lang'}->txt('You have Transfers to view'),
        );
		push @TaskList, \%row;
    }
    if ($dupCount)   {
        my %row=(
            TaskType => 'DUPLICATES',
            Name => $Data->{'lang'}->txt('You have Duplicates to resolve'),
        );
		push @TaskList, \%row;
    }
		
	my $msg = ''; 
	if ($rowCount == 0) {
		$msg = $Data->{'lang'}->txt('No outstanding tasks');
	}
	else {
		$msg = $Data->{'lang'}->txt('The following are the outstanding tasks to be authorised');
	};
	
	my %TemplateData = (
			TaskList => \@TaskList,
			TaskMsg => $msg,
			TaskEntityID => $entityID,
			client => $Data->{client},
	);

	$body = runTemplate(
			$Data,
			\%TemplateData,
			'dashboards/worktasks.templ',
	);
	

	return($body,$Data->{'lang'}->txt('Registration Authorisation')); 	
}

sub getEntityParentID   {

    my ($Data, $fromEntityID, $getEntityLevel) = @_;

    my $st = qq[
        SELECT      
            intEntityLevel
        FROM
            tblEntity
        WHERE
            intEntityID = ?
    ];
	my $q = $Data->{'db'}->prepare($st);
  	$q->execute($fromEntityID);
    my $entityLevel = $q->fetchrow_array() || 0;
    return $fromEntityID if ($getEntityLevel == $entityLevel);

    $st = qq[
        SELECT 
            intParentID
		FROM 
            tblTempEntityStructure as T
		WHERE
            intChildID = ?
            AND intParentLevel = ?
        ORDER BY intPrimary DESC
        LIMIT 1            
    ];
            #AND intPrimary=1

	$q = $Data->{'db'}->prepare($st);
  	$q->execute($fromEntityID, $getEntityLevel);
        
    return  $q->fetchrow_array() || 0;
    
}
sub addWorkFlowTasks {
     my(
        $Data,
        $ruleFor,
        $regNature,
        $originLevel,
        $entityID,
        $personID,
        $personRegistrationID,
        $documentID
    ) = @_;
 
    $entityID ||= 0;
    $personID ||= 0;
    $originLevel ||= 0;
    $personRegistrationID ||= 0;
    $documentID ||= 0;

	my $q = '';
	my $db=$Data->{'db'};
	
	my $stINS = qq[
		INSERT IGNORE INTO tblWFTask (
			intWFRuleID,
			intRealmID,
			intSubRealmID, 
            intCreatedByUserID,
			intApprovalEntityID,
			strTaskType, 
            strWFRuleFor,
            strRegistrationNature,
			intDocumentTypeID, 
			strTaskStatus, 
			intProblemResolutionEntityID, 
            intEntityID,
			intPersonID, 
			intPersonRegistrationID,
            intDocumentID
		)
        VALUES (
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
            ?,
            ?,
            ?,
            ?,
            ?
        )
    ];
	my $qINS = $db->prepare($stINS);
            
    my $st = '';
    ## Build up SELECT based on what sort of record we are approving
    if ($ruleFor eq 'REGO' and $personRegistrationID)   {
        ## APPROVAL FOR PERSON REGO
        $st = qq[
		SELECT 
			r.intWFRuleID, 
			r.intRealmID,
			r.intSubRealmID,
			r.intApprovalEntityLevel,
			r.strTaskType, 
            r.strWFRuleFor,
			r.intDocumentTypeID, 
			r.strTaskStatus, 
			r.intProblemResolutionEntityLevel, 
			pr.intPersonID, 
			pr.intPersonRegistrationID,
            pr.intEntityID as RegoEntity,
            0 as DocumentID
		FROM tblPersonRegistration_$Data->{'Realm'} AS pr
        INNER JOIN tblEntity as e ON (e.intEntityID = pr.intEntityID)
		INNER JOIN tblWFRule AS r ON (
			pr.intRealmID = r.intRealmID
			AND pr.intSubRealmID = r.intSubRealmID
			AND pr.strPersonLevel = r.strPersonLevel
			AND pr.strAgeLevel = r.strAgeLevel
			AND pr.strSport = r.strSport
            AND pr.strPersonType = r.strPersonType
            AND r.intEntityLevel = e.intEntityLevel
        )
		WHERE 
            pr.intPersonRegistrationID = ?
            AND r.strWFRuleFor = 'REGO'
            AND r.intRealmID = ?
            AND r.intSubRealmID IN (0, ?)
            AND r.intOriginLevel = ?
            AND r.strEntityType IN ('', e.strEntityType)
			AND r.strRegistrationNature = ?
            AND r.strPersonEntityRole IN ('', pr.strPersonEntityRole)
		];
warn($st);
	    $q = $db->prepare($st);
  	    $q->execute($personRegistrationID, $Data->{'Realm'}, $Data->{'RealmSubType'}, $originLevel, $regNature);
    }
    if ($ruleFor eq 'ENTITY' and $entityID)  {
        ## APPROVAL FOR ENTITY
        $st = qq[
		SELECT 
			r.intWFRuleID, 
			r.intRealmID,
			r.intSubRealmID,
			r.intApprovalEntityLevel,
			r.strTaskType, 
            r.strWFRuleFor,
			r.intDocumentTypeID, 
			r.strTaskStatus, 
			r.intProblemResolutionEntityLevel, 
            0 as intPersonID,
            0 as intPersonRegistrationID,
            e.intEntityID as RegoEntity,
            0 as DocumentID
		FROM tblEntity as e
		INNER JOIN tblWFRule AS r ON (
			e.intRealmID = r.intRealmID
			AND e.intSubRealmID = r.intSubRealmID
            AND r.strPersonType = ''
			AND e.intEntityLevel = e.intEntityLevel
            AND e.strEntityType = r.strEntityType
        )
		WHERE e.intEntityID= ?
            AND r.strWFRuleFor = 'ENTITY'
            AND r.intRealmID = ?
            AND r.intSubRealmID IN (0, ?)
            AND r.intOriginLevel = ?
			AND r.strRegistrationNature = ?
		];
warn($st);
	    $q = $db->prepare($st);
  	    $q->execute($entityID, $Data->{'Realm'}, $Data->{'RealmSubType'}, $originLevel, $regNature);
    }
    if ($ruleFor eq 'DOCUMENT' and $documentID)    {
        ## APPROVAL FOR DOCUMENT
        $st = qq[
		SELECT 
			r.intWFRuleID, 
			r.intRealmID,
			r.intSubRealmID,
			r.intApprovalEntityLevel,
			r.strTaskType, 
            r.strWFRuleFor,
			r.intDocumentTypeID, 
			r.strTaskStatus, 
			r.intProblemResolutionEntityLevel, 
            0 as intPersonID,
            0 as intPersonRegistrationID,
            e.intEntityID as RegoEntity,
            d.intDocumentID as DocumentID
		FROM tblDocuments as d 
		INNER JOIN tblWFRule AS r ON (
            d.intDocumentTypeID = r.intDocumentTypeID
            AND d.intEntityLevel = r.intEntityLevel
        )
		WHERE d.intDocumentID = ?
            AND r.strWFRuleFor = 'DOCUMENT'
            AND r.intRealmID = ?
            AND r.intSubRealmID IN (0, ?)
            AND r.intOriginLevel = ?
			AND r.strRegistrationNature = ?
		];
	    $q = $db->prepare($st);
  	    $q->execute($documentID, $Data->{'Realm'}, $Data->{'RealmSubType'}, $originLevel, $regNature);
    }



    while (my $dref= $q->fetchrow_hashref())    {
warn("RULE FOUND");
        my $approvalEntityID = getEntityParentID($Data, $dref->{RegoEntity}, $dref->{'intApprovalEntityLevel'}) || 0;
        my $problemEntityID = getEntityParentID($Data, $dref->{RegoEntity}, $dref->{'intProblemResolutionEntityLevel'});
warn("DDDD" . $approvalEntityID . "|" . $problemEntityID);
        next if (! $approvalEntityID and ! $problemEntityID);
  	    $qINS->execute(
            $dref->{'intWFRuleID'},
            $dref->{'intRealmID'},
            $dref->{'intSubRealmID'},
            $Data->{'clientValues'}{'userID'} || 0,
            $approvalEntityID,
            $dref->{'strTaskType'},
            $ruleFor,
            $regNature,
            $dref->{'intDocumentTypeID'},
            $dref->{'strTaskStatus'},
            $problemEntityID,
            $entityID,
            $dref->{'intPersonID'},
            $dref->{'intPersonRegistrationID'},
            $dref->{'DocumentID'}
        );

    }
	
	if ($q->errstr) {
		return $q->errstr . '<br>' . $st
	}			
	$st = qq[
		INSERT IGNORE INTO tblWFTaskPreReq (
			intWFTaskID, 
			intWFRuleID, 
			intPreReqWFRuleID
		)
		SELECT 
			t.intWFTaskID, 	
			t.intWFRuleID, 
			rpr.intPreReqWFRuleID 
		FROM tblWFTask AS t
		INNER JOIN tblWFRulePreReq AS rpr 
			ON t.intWFRuleID = rpr.intWFRuleID
		WHERE t.intPersonRegistrationID = ?
		];

  	$q = $db->prepare($st);
  	$q->execute($personRegistrationID);
	
	if ($q->errstr) {
		return $q->errstr . '<br>' . $st;
	}

	my $rc = checkForOutstandingTasks($Data,$ruleFor, $entityID, $personID, $personRegistrationID, $documentID);

	return($rc); 
}

sub approveTask {
    my(
        $Data,
    ) = @_;
	
	my $st = '';
	my $q = '';
	my $db=$Data->{'db'};

	#Get values from the QS
    my $WFTaskID = safe_param('TID','number') || '';
	
	#Update this task to COMPLETE
	$st = qq[
	  	UPDATE tblWFTask SET 
	  		strTaskStatus = 'COMPLETE',
	  		intApprovalUserID = ?,
	  		dtApprovalDate = NOW()
	  	WHERE intWFTaskID = ?; 
		];
		
  	$q = $db->prepare($st);
  	$q->execute(
	  	$Data->{'clientValues'}{'userID'},
  		$WFTaskID,
  		);
  		
	if ($q->errstr) {
		return $q->errstr . '<br>' . $st
	}
	
    $st = qq[
        SELECT 
            intPersonID,
            intPersonRegistrationID,
            intEntityID,
            intDocumentID,
            strWFRuleFor
        FROM tblWFTask
        WHERE intWFTaskID = ?
    ];
        
    $q = $db->prepare($st);
    $q->execute($WFTaskID);
            
    my $dref= $q->fetchrow_hashref();
    my $personID = $dref->{intPersonID} || 0;
    my $personRegistrationID = $dref->{intPersonRegistrationID} || 0;
    my $entityID= $dref->{intEntityID} || 0;
    my $documentID= $dref->{intDocumentID} || 0;
    my $ruleFor = $dref->{strWFRuleFor} || '';
    
   	my $rc = checkForOutstandingTasks($Data,$ruleFor, $entityID, $personID, $personRegistrationID, $documentID);
    
    return($rc);
    
}

sub checkForOutstandingTasks {
    my(
        $Data,
        $ruleFor,
        $entityID,
        $personID,
        $personRegistrationID,
        $documentID
    ) = @_;

	my $st = '';
	my $q = '';
	my $db=$Data->{'db'};
		
	#As a result of an update, check to see if there are any Tasks that now have all their pre-reqs completed
	# or if all tasks have been completed
	$st = qq[	
		SELECT DISTINCT 
			pt.intWFTaskID, ct.strTaskStatus 
		FROM tblWFTask pt
		INNER JOIN tblWFTaskPreReq ptpr ON pt.intWFTaskID = ptpr.intWFTaskID
		INNER JOIN tblWFTask ct on ptpr.intPreReqWFRuleID = ct.intWFRuleID 
        WHERE
			pt.strTaskStatus = ?
		    AND (pt.intPersonRegistrationID = ? AND pt.intEntityID = ? AND pt.intPersonID = ? and pt.intDocumentID = ?)
			AND (ct.intPersonRegistrationID = ? AND ct.intEntityID = ? AND ct.intPersonID = ? and ct.intDocumentID = ?)
			AND ct.strTaskStatus IN (?,?)
            AND pt.strWFRuleFor = ?
            AND ct.strWFRuleFor = ?
		ORDER by pt.intWFTaskID;
	];
warn("CHECKING FOR OUTSANDING FOR PERSON $personID PR $personRegistrationID");	
	$q = $db->prepare($st);
  	$q->execute(
  		'PENDING',
  		$personRegistrationID,
        $entityID,
        $personID,
        $documentID,
  		$personRegistrationID,
        $entityID,
        $personID,
        $documentID,
  		'ACTIVE',
  		'COMPLETE',
        $ruleFor,
        $ruleFor,
  		);
  		
	if ($q->errstr) {
		return $q->errstr . '<br>' . $st
	}
warn("$ruleFor STILL CHECKING");

	my $prev_WFTaskID = 0;
   	my $updateThisTask = '';
   	my $pfx = '';
   	my $list_WFTaskID = '';
   	my $update_count = 0;
   	my $count = 0;
   		
   	#Should be a cleverer way to do this, but check all the Pending Tasks and see if all of their
   	# pre-reqs have been completed. If so, update their status from Pending to Active.
	while(my $dref= $q->fetchrow_hashref()) {
warn("INCHECKING");
		$count ++;
	
   		if ($dref->{intWFTaskID} != $prev_WFTaskID) {
   			if ($prev_WFTaskID != 0) {
   				if ($updateThisTask eq 'YES') {
   					$list_WFTaskID .= $pfx . $prev_WFTaskID;
   					$pfx = ",";
					$update_count ++;
			   			}
   			}
   			$updateThisTask = 'YES';
   			$prev_WFTaskID = $dref->{intWFTaskID};
   		}
   		
   		if ($dref->{strTaskStatus} eq 'ACTIVE') {
   			$updateThisTask = "nope";
   		}
    }
    
   	if ($prev_WFTaskID != 0) {
   		if ($updateThisTask eq 'YES') {
   			$list_WFTaskID .= $pfx . $prev_WFTaskID;
			$update_count ++;
		}
   	}
	
warn("CHECKING $update_count");
	my $rc = 0;
	 
	if ($update_count > 0) {
		#Update the Tasks to Active as their pre-reqs have been completed
		$st = qq[
		  	UPDATE tblWFTask SET 
		  		strTaskStatus = 'ACTIVE',
		  		dtActivateDate = NOW()
		  	WHERE intWFTaskID IN ($list_WFTaskID); 
			];
		  		#intActiveUserID = 1
			
	  	$q = $db->prepare($st);
	  	$q->execute();
	  		
		if ($q->errstr) {
			return $q->errstr . '<br>' . $st
		}
		    
	} 
	else {	
		# Nothing to update. Do a check to see if all tasks have been completed
		$st = qq[
            SELECT 
                COUNT(*) as NumRows
            FROM 
                tblWFTask
            WHERE 
                intPersonID = ?
                AND intPersonRegistrationID = ?
                AND intEntityID= ?
                AND intDocumentID = ?
                AND strWFRUleFor = ?
			    AND strTaskStatus IN ('PENDING','ACTIVE')
        ];
        
        $q = $db->prepare($st);
        $q->execute(
            $personID,
       		$personRegistrationID,
            $entityID,
            $documentID,
            $ruleFor
	  	);
  
        
        if ($ruleFor eq 'ENTITY' and $entityID and !$q->fetchrow_array())   {
            $st = qq[
                    UPDATE tblEntity
                    SET
                        strStatus = 'ACTIVE',
                        dtFrom = NOW()
                    WHERE
                        intEntityID= ?
                ];

                $q = $db->prepare($st);
                $q->execute(
                    $entityID
                    );
                $rc = 1;
        }
        if ($ruleFor eq 'DOCUMENT' and $documentID and !$q->fetchrow_array())   {
            $st = qq[
                    UPDATE tblDocuments
                    SET
                        strApprovalStatus = 'ACTIVE',
                        dtFrom = NOW()
                    WHERE
                        intDocumentID= ?
                ];

                $q = $db->prepare($st);
                $q->execute(
                    $documentID
                );
                $rc = 1;
        }
 
        if ($ruleFor eq 'REGO' and $personRegistrationID and !$q->fetchrow_array()) {
        	#Now check to see if there is a payment outstanding
        	#$st = qq[
			#        SELECT intPaymentRequired
			#        FROM tblPersonRegistration_$Data->{'Realm'} 
			#        WHERE intPersonRegistrationID = ?
			#];
			#        
			#$q = $db->prepare($st);
			#$q->execute($personRegistrationID);
			#            
			#my $dref= $q->fetchrow_hashref();
			#my $intPaymentRequired = 0; #$dref->{intPaymentRequired};
			  	
        	#if (!$intPaymentRequired) {
        		#Nothing outstanding, so mark this registration as complete
	            $st = qq[
	            	UPDATE tblPersonRegistration_$Data->{'Realm'} 
                    SET
	            	    strStatus = 'ACTIVE',
	            	    dtFrom = NOW()
	    	        WHERE 
                        intPersonRegistrationID = ?
	        	];
	    
		        $q = $db->prepare($st);
		        $q->execute(
		       		$personRegistrationID
		  			);         
	        	$rc = 1;	# All registration tasks have been completed        		
        }
        if ($personID)  {
                $st = qq[
	            	UPDATE tblPerson
                    SET
	            	    strStatus = 'ACTIVE'
	    	        WHERE 
                        intPersonID= ?
                        AND strStatus='PENDING'
	        	];
	    
		        $q = $db->prepare($st);
		        $q->execute( $personID); 
	        	$rc = 1;	# All registration tasks have been completed        		
        	#}
        }
	}      

return ($rc) # 1 = Registration is complete, 0 = There are still outstanding Tasks to be completed
       	
}

sub rejectTask {
    my(
        $Data,
    ) = @_;
	
	my $st = '';
	my $q = '';
	my $db=$Data->{'db'};

	#Get values from the QS
    my $WFTaskID = safe_param('TID','number') || '';
	
	#Update this task to REJECTED
	$st = qq[
	  	UPDATE tblWFTask 
        SET 
	  		strTaskStatus = 'REJECTED',
	  		intRejectedUserID = ?,
	  		dtRejectedDate = NOW()
	  	WHERE 
            intWFTaskID = ?; 
    ];
		
  	$q = $db->prepare($st);
  	$q->execute(
	  	$Data->{'clientValues'}{'userID'},
  		$WFTaskID,
  		);
  		
	if ($q->errstr) {
		return $q->errstr . '<br>' . $st
	}
	
    return(0);
    
}
1;
