package PersonRegistration;
require Exporter;
@ISA = qw(Exporter);
@EXPORT = @EXPORT_OK = qw(
    getRegistrationData
    addRegistration
    deletePersonRegistered
    isPersonRegistered
    mergePersonRegistrations
    submitPersonRegistration
    updatePersonRegistration
    checkRenewalOK
);

use strict;
use WorkFlow;
#use Log;
use RuleMatrix;
use NationalReportingPeriod;
use GenAgeGroup;
use Data::Dumper;

sub checkRenewalOK  {

    my ($Data, $personID, $rego_ref) = @_;
    my %Reg = (
        sport=> $rego_ref->{'sport'} || '',
        personType=> $rego_ref->{'personType'} || '',
        personEntityRole=> $rego_ref->{'personEntityRole'} || '',
        personLevel=> $rego_ref->{'personLevel'} || '',
        ageLevel=> $rego_ref->{'ageLevel'} || '',
        status=> 'ACTIVE',
    );
    my ($count, $regs) = getRegistrationData(
        $Data,
        $personID,
        \%Reg
    );

    return $count;
}


sub deletePersonRegistered  {
	my ($Data, $personID, $personRegistrationID) = @_;

    my $st = qq[
        UPDATE tblPersonRegistration_$Data->{'Realm'}
        SET strStatus = 'DELETED'
        WHERE
            intPersonID = ?
            AND intPersonRegistrationID = ?
        LIMIT 1
    ];
  	my $q= $Data->{'db'}->prepare($st);
    $q->execute($personID, $personRegistrationID) or query_error($st);
}

sub isPersonRegistered {

	my ( $Data, $personID, $regFilters_ref)=@_;

## Are there any "current" registration records for the member in the system
    $regFilters_ref->{'current'} = 1;
    my ($count, $p1_refs) = getRegistrationData($Data, $personID, $regFilters_ref);

    return 1 if $count;
    return 0;
}

sub mergePersonRegistrations    {

    my ($Data, $pFromId, $pToId) = @_;

    my ($pFromCount, $pFrom_refs) = getRegistrationData($Data, $pFromId, undef);
    my ($pToCount, $pTo_refs) = getRegistrationData($Data, $pToId, undef);

    my $stMove = qq[
        UPDATE tblPersonRegistration_$Data->{'Realm'}
        SET
            intPersonID = ?
        WHERE
            intPersonID = ?
            AND intPersonRegistrationID = ?
        LIMIT 1
    ];
  	my $qMove = $Data->{'db'}->prepare($stMove);

    my $stMerge = qq[
        UPDATE tblPersonRegistration_$Data->{'Realm'}
        SET
            intPersonID = ?,
            strStatus=?,
            dtFrom = ?,
            dtTo = ?,
            intCurrent = ?,
            intIsPaid = ?,
            intPaymentRequired = ?,
            dtAdded= ?,
            dtLastUpdated = ?
        WHERE
            intPersonID = ?
            AND intPersonRegistrationID = ?
        LIMIT 1
    ];
  	my $qMerge = $Data->{'db'}->prepare($stMerge);
        
    my $stTXNs = qq[
        UPDATE tblTransactions
        SET intPersonRegistrationID = ?
        WHERE 
            intPersonRegistrationID >0 
            AND intPersonRegistrationID = ?
    ];
  	my $qTXNs= $Data->{'db'}->prepare($stTXNs);

    my $stTASKs = qq[
        UPDATE tblWFTask
        SET
            intPersonID = ?,
            intPersonRegistrationID = ?
        WHERE
            intPersonID = ?
            AND intPersonRegistrationID = ?
    ];
  	my $qTasks= $Data->{'db'}->prepare($stTASKs);

    my $stDELTasks= qq[
        DELETE FROM tblWFTask
        WHERE
            intPersonID = ?
            AND strWFRuleFor = 'REGO'
            AND intPersonRegistrationID = ?
    ];
  	my $qDELTasks= $Data->{'db'}->prepare($stDELTasks);


    
    for my $From_ref (@{$pFrom_refs}) {
        my $keyFrom = $From_ref->{'intEntityID'} . "|" . $From_ref->{'strPersonType'} . "|" . $From_ref->{'strPersonSubType'} . "|" . $From_ref->{'strPersonLevel'} . "|" . $From_ref->{'strPersonEntityRole'} . "|" . $From_ref->{'strSport'} . "|" . $From_ref->{'strAgeLevel'};
        my $personRegoIDFrom = $From_ref->{'intPersonRegistrationID'};
        my $found_To_ref='';
        my $personRegoIDTo = 0;
        for my $To_ref (@{$pTo_refs}) {
            #lets see if there is a match
            my $keyTo = $To_ref->{'intEntityID'} . "|" . $To_ref->{'strPersonType'} . "|" . $To_ref->{'strPersonSubType'} . "|" . $To_ref->{'strPersonLevel'} . "|" . $To_ref->{'strPersonEntityRole'} . "|" . $To_ref->{'strSport'} . "|" . $To_ref->{'strAgeLevel'};

            if ($keyTo eq $keyFrom) {
                ##Match found
                $personRegoIDTo= $To_ref->{'intPersonRegistrationID'};
                $found_To_ref = $To_ref;
                last;
            }
        }
        if ($personRegoIDFrom and ! $personRegoIDTo )   {
  	        $qMove->execute($pToId, $pFromId, $personRegoIDFrom);
            $qTasks->execute($pToId, $personRegoIDFrom, $pFromId, $personRegoIDFrom);
            $qTasks->execute($pToId, 0, $pFromId, 0);
        }
        my $tasks = 'USE_TO';
        if ($personRegoIDTo) {
            my $newStatus = $From_ref->{'strStatus'} eq 'ACTIVE' ? $From_ref->{'strStatus'} : $found_To_ref->{'strStatus'};
            if ($From_ref->{'strStatus'} eq 'ACTIVE' and $found_To_ref->{'strStatus'} ne 'ACTIVE')  {
                $tasks = 'USE_FROM';
            }
            
            my $new_dtFrom = $From_ref->{'dtFrom_'} < $found_To_ref->{'dtFrom_'} ? $From_ref->{'dtFrom'} : $found_To_ref->{'dtFrom'};
            my $new_dtTo= $From_ref->{'dtTo_'} > $found_To_ref->{'dtTo_'} ? $From_ref->{'dtTo'} : $found_To_ref->{'dtTo'};
            my $new_dtAdded= $From_ref->{'dtAdded_'} < $found_To_ref->{'dtAdded_'} ? $From_ref->{'dtAdded'} : $found_To_ref->{'dtAdded'};
            my $new_dtLastUpdated= $From_ref->{'dtLastUpdated_'} > $found_To_ref->{'dtLastUpdated_'} ? $From_ref->{'dtLastUpdated'} : $found_To_ref->{'dtLastUpdated'};

            my $new_intCurrent= $From_ref->{'intCurrent'} ? 1 : $found_To_ref->{'intCurrent'};
            my $new_intIsPaid= $From_ref->{'intIsPaid'} ? 1 : $found_To_ref->{'intIsPaid'};
            my $new_intPaymentRequired= $From_ref->{'intPaymentRequired'} ? 1 : $found_To_ref->{'intPaymentRequired'};

  	        $qMerge->execute($pToId, $newStatus, $new_dtFrom, $new_dtTo, $new_intCurrent, $new_intIsPaid, $new_intPaymentRequired, $new_dtAdded, $new_dtLastUpdated, $pToId, $personRegoIDTo);

            $qTXNs->execute($personRegoIDTo, $personRegoIDFrom);
            if ($tasks eq 'USE_TO') {
                $qDELTasks->execute($pFromId, $personRegoIDFrom);
            }
            if ($tasks eq 'USE_FROM')   {
                $qDELTasks->execute($pToId, $personRegoIDTo);
                $qTasks->execute($pToId, $$personRegoIDTo, $pFromId, $personRegoIDFrom);
            }
        }
    }
}

sub updatePersonRegistration    {

    my ($Data, $personID, $personRegistrationID, $Reg_ref) = @_;

    if ($Reg_ref->{'personEntityRole'} eq '-')  {
        $Reg_ref->{'personEntityRole'}= '';
    }
    if ($Reg_ref->{'strPersonEntityRole'} eq '-')  {
        $Reg_ref->{'strPersonEntityRole'}= '';
    }
        
	my $st = qq[
   		UPDATE tblPersonRegistration_$Data->{'Realm'} 
        SET
            strPersonType = ?,
            strPersonSubType = ?,
            strPersonLevel = ?,
            strPersonEntityRole = ?,
            strStatus = ?,
            strSport = ?,
            intCurrent = ?,
            dtFrom = ?,
            dtTo = ?,
            dtLastUpdated = ?,
            strAgeLevel = ?,
            strRegistrationNature = ?,
            intIsPaid = ?,
            intPaymentRequired = ?
        WHERE
            intPersonID = ?
            AND intPersonRegistrationID = ?
        LIMIT 1
    ];

  	my $q = $Data->{'db'}->prepare($st);
  	$q->execute(
        $Reg_ref->{'personType'} || $Reg_ref->{'strPersonType'},
        $Reg_ref->{'personSubType'} || $Reg_ref->{'strPersonSubType'},
        $Reg_ref->{'personLevel'} || $Reg_ref->{'strPersonLevel'},
        $Reg_ref->{'personEntityRole'} || $Reg_ref->{'strPersonEntityRole'},
        $Reg_ref->{'status'} || $Reg_ref->{'strStatus'},
        $Reg_ref->{'sport'} || $Reg_ref->{'strSport'},
        $Reg_ref->{'current'} || $Reg_ref->{'intCurrent'},
        $Reg_ref->{'dateFrom'} || $Reg_ref->{'dtFrom'},
        $Reg_ref->{'dateTo'} || $Reg_ref->{'dtTo'},
        $Reg_ref->{'dateLastUpdated'} || $Reg_ref->{'dtLastUpdated'},
        $Reg_ref->{'ageLevel'} || $Reg_ref->{'strAgeLevel'},
        $Reg_ref->{'registrationNature'} || $Reg_ref->{'strRegistrationNature'},
        $Reg_ref->{'isPaid'} || $Reg_ref->{'intIsPaid'},
        $Reg_ref->{'paymentRequired'} || $Reg_ref->{'intPaymentRequired'},
        $personID,
        $personRegistrationID
  	);
	
	if ($q->errstr) {
		return 0;
	}
    return 1;
}

sub getRegistrationData	{
	my ( $Data, $personID, $regFilters_ref)=@_;
	
    my @values = (
        $personID,
    );
    my $where = '';

    if ($regFilters_ref->{'personEntityRole'} eq '-')  {
        $regFilters_ref->{'personEntityRole'}= '';
    }
    if ($regFilters_ref->{'strPersonEntityRole'} eq '-')  {
        $regFilters_ref->{'strPersonEntityRole'}= '';
    }
    if($regFilters_ref->{'personRegistrationID'})  {
        push @values, $regFilters_ref->{'personRegistrationID'};
        $where .= " AND pr.intPersonRegistrationID= ? ";
    }
    if($regFilters_ref->{'personType'})  {
        push @values, $regFilters_ref->{'personType'};
        $where .= " AND pr.strPersonType = ? ";
    }
    if($regFilters_ref->{'personSubType'})  {
        push @values, $regFilters_ref->{'personSubType'};
        $where .= " AND pr.strPersonSubType = ? ";
    }
    if($regFilters_ref->{'personLevel'})  {
        push @values, $regFilters_ref->{'personLevel'};
        $where .= " AND pr.strPersonLevel= ? ";
    }
    if($regFilters_ref->{'personEntityRole'})  {
        push @values, $regFilters_ref->{'personEntityRole'};
        $where .= " AND pr.strPersonEntityRole= ? ";
    }
    if($regFilters_ref->{'status'})  {
        push @values, $regFilters_ref->{'status'};
        $where .= " AND pr.strStatus= ? ";
    }
    if($regFilters_ref->{'sport'})  {
        push @values, $regFilters_ref->{'sport'};
        $where .= " AND pr.strSport= ? ";
    }
    if(exists $regFilters_ref->{'current'})  {
        push @values, $regFilters_ref->{'current'};
        $where .= " AND pr.intCurrent = ? ";
    }
    if($regFilters_ref->{'registrationNature'})  {
        push @values, $regFilters_ref->{'registrationNature'};
        $where .= " AND pr.strRegistrationNature= ? ";
    }
    if(exists $regFilters_ref->{'nationalPeriodID'})  {
        push @values, $regFilters_ref->{'nationalPeriodID'};
        $where .= " AND pr.intNationalPeriodID= ? ";
    }
    if(exists $regFilters_ref->{'paymentRequired'})  {
        push @values, $regFilters_ref->{'paymentRequired'};
        $where .= " AND pr.intPaymentRequired = ? ";
    }

    my $st= qq[
        SELECT 
            pr.*, 
            p.dtDOB,
            DATE_FORMAT(p.dtDOB, "%d/%m/%Y") as DOB,
            p.intGender,
            p.intGender as Gender,
            DATE_FORMAT(pr.dtFrom, "%Y%m%d") as dtFrom_,
            DATE_FORMAT(pr.dtTo, "%Y%m%d") as dtTo_,
            DATE_FORMAT(pr.dtAdded, "%Y%m%d%H%i") as dtAdded_,
            DATE_FORMAT(pr.dtLastUpdated, "%Y%m%d%H%i") as dtLastUpdated_,
            e.strLocalName 
        FROM
            tblPersonRegistration_$Data->{'Realm'} AS pr
            INNER JOIN tblEntity e ON (
                pr.intEntityID = e.intEntityID 
            )
            INNER JOIN tblPerson as p ON (
                p.intPersonID = pr.intPersonID
            )
        WHERE     
            p.intPersonID = ?
            $where
        ORDER BY
          pr.dtAdded DESC
    ];	
    my $db=$Data->{'db'};
    my $query = $db->prepare($st) or query_error($st);
    $query->execute(@values) or query_error($st);
    my $count=0;

    my @Registrations = ();
      
    while(my $dref= $query->fetchrow_hashref()) {
        $count++;
        push @Registrations, $dref;
    }
    return ($count, \@Registrations);
}

sub addRegistration {
    my($Data, $Reg_ref) = @_;

    if ($Reg_ref->{'personEntityRole'} eq '-')  {
        $Reg_ref->{'personEntityRole'}= '';
    }
    my $status = $Reg_ref->{'status'} || 'PENDING';

    if (! exists $Reg_ref->{'paymentRequired'})    {
        my $matrix_ref = getRuleMatrix($Data, $Reg_ref->{'originLevel'}, $Reg_ref->{'entityLevel'}, $Defs::LEVEL_PERSON, $Reg_ref->{'entityType'} || '', 'REGO', $Reg_ref);
        $Reg_ref->{'paymentRequired'} = $matrix_ref->{'intPaymentRequired'} || 0;
    }
    my $nationalPeriodID = getNationalReportingPeriod($Data->{db}, $Data->{'Realm'}, $Data->{'RealmSubType'}, $Reg_ref->{'sport'});
    my $genAgeGroup ||=new GenAgeGroup ($Data->{'db'},$Data->{'Realm'}, $Data->{'RealmSubType'});
    my $ageGroupID = 0;

    if ($Reg_ref->{'personID'})  {
        my $st= qq[
            SELECT 
                DATE_FORMAT(dtDOB, "%Y%m%d") as DOBAgeGroup, 
                intGender
            FROM 
                tblPerson
            WHERE 
                intPersonID= ?
        ];
        my $qry=$Data->{'db'}->prepare($st);
        $qry->execute($Reg_ref->{'personID'});
        my ($DOBAgeGroup, $Gender)=$qry->fetchrow_array();
        $ageGroupID=$genAgeGroup->getAgeGroup($Gender, $DOBAgeGroup) || 0;
    }

	my $st = qq[
   		INSERT INTO tblPersonRegistration_$Data->{'Realm'} (
            intPersonID,
            intEntityID,
            strPersonType,
            strPersonSubType,
            strPersonLevel,
            strPersonEntityRole,
            strStatus,
            strSport,
            intCurrent,
            intOriginLevel,
            intOriginID,
            intCreatedByUserID,
            dtFrom,
            dtTo,
            intRealmID,
            intSubRealmID,
            dtAdded,
            dtLastUpdated,
            intNationalPeriodID,
            intAgeGroupID,
            strAgeLevel,
            strRegistrationNature,
            intPaymentRequired
		)
		VALUES
		(
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
            ?,
            ?,
            NOW(),
            NOW(),
            ?,
            ?,
            ?,
            ?,
            ?
        )
    ];

  	my $q = $Data->{'db'}->prepare($st);
  	$q->execute(
  		$Reg_ref->{'personID'},
  		$Reg_ref->{'entityID'},
  		$Reg_ref->{'personType'} || '',  		
  		$Reg_ref->{'personSubType'} || '',  		
  		$Reg_ref->{'personLevel'} || '',  		
  		$Reg_ref->{'personEntityRole'} || '',  		
  		$status || '',  		
  		$Reg_ref->{'sport'},  		
  		$Reg_ref->{'current'} || 0,  		
  		$Reg_ref->{'originLevel'} || 0,  		
  		$Reg_ref->{'originID'} || 0,  		
        $Data->{'clientValues'}{'userID'} || 0,
  		$Reg_ref->{'dateFrom'},  		
  		$Reg_ref->{'dateTo'},  		
  		$Data->{'Realm'},
  		$Data->{'RealmSubType'} || 0,
  		$nationalPeriodID || 0,
  		$ageGroupID || 0,
  		$Reg_ref->{'ageLevel'} || '',
  		$Reg_ref->{'registrationNature'} || '',
  		$Reg_ref->{'paymentRequired'} || 0
  	);
	
	if ($q->errstr) {
		return (0, 0);
	}
  	my $personRegistrationID = $q->{mysql_insertid};
  	
    my $rc=0;
    if ($status eq 'PENDING')   {
  	    $rc = addWorkFlowTasks(
            $Data,
            'REGO', 
            $Reg_ref->{'registrationNature'}, 
            $Reg_ref->{'originLevel'} || 0, 
            $Reg_ref->{'entityID'} || 0,
            $Reg_ref->{'personID'},
            $personRegistrationID, 
            0
        );
        personInProgressToPending($Data, $Reg_ref->{'personID'});
    }
  	
 	return ($personRegistrationID, $rc) ;
}

sub submitPersonRegistration    {

    my ($Data, $personID, $personRegistrationID) = @_;

    my %Reg=();
    $Reg{'personRegistrationID'} = $personRegistrationID;
    my ($count, $regs) = getRegistrationData($Data, $personID, \%Reg);

    if ($count) {
        my $pr_ref = $regs->[0];
        $pr_ref->{'strStatus'} = 'PENDING';

        updatePersonRegistration($Data, $personID, $personRegistrationID, $pr_ref);

  	    my $rc = addWorkFlowTasks(
            $Data,
            'REGO', 
            $pr_ref->{'registrationNature'} || $pr_ref->{'strRegistrationNature'} || '', 
            $pr_ref->{'originLevel'} || $pr_ref->{'intOriginLevel'} || 0, 
            $pr_ref->{'entityID'} || $pr_ref->{'intEntityID'} || 0,
            $personID,
            $personRegistrationID, 
            0
        );
        personInProgressToPending($Data, $personID);
    }
}

sub personInProgressToPending {

    my ($Data, $personID) = @_;

    return if (! $personID);
    my $st = qq[
        UPDATE tblPerson
        SET strStatus='PENDING'
        WHERE 
            intPersonID=?
            AND intRealmID=?
            AND strStatus='INPROGRESS'
        LIMIT 1
    ];
    my $qry=$Data->{'db'}->prepare($st);
    $qry->execute($personID, $Data->{'Realm'});
}

1;
