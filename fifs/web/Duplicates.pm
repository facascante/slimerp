#
# $Header: svn://svn/SWM/trunk/web/Duplicates.pm 11576 2014-05-15 08:00:42Z apurcell $
#

package Duplicates;
require Exporter;
@ISA =  qw(Exporter);
@EXPORT = qw(handleDuplicates isCheckDupl getDuplFields getDupTaskCount);
@EXPORT_OK = qw(handleDuplicates isCheckDupl getDuplFields getDupTaskCount);

use lib '.', '..', "comp", 'RegoForm', "dashboard", "RegoFormBuilder",'PaymentSplit', "user";

use strict;
use Reg_common;
use CGI qw(unescape param Vars);
use Utils;
use DeQuote;
#use AuditLog;
use Seasons;
use MovePhoto;
use Notifications;
use PersonRegistration;

sub getDupTaskCount {

    my ($Data, $entityID) = @_;

    my $st = qq[
        SELECT COUNT(tblPerson.intPersonID) as CountNum
        FROM 
            tblPerson
            INNER JOIN tblPersonRegistration_$Data->{'Realm'} as PR ON (tblPerson.intPersonID= PR.intPersonID)
        WHERE PR.intEntityID = $entityID
            AND tblPerson.intSystemStatus=$Defs::PERSONSTATUS_POSSIBLE_DUPLICATE
            AND tblPerson.intRealmID=$Data->{'Realm'}
    ];
    my $qry= $Data->{'db'}->prepare($st);
    $qry->execute or query_error($st);
    return $qry->fetchrow_array() || 0;
}

sub handleDuplicates {

	my ($action, $Data) = @_;

	my $body='';
	$action||='DUPL_L';
    my $entityID= getID($Data->{'clientValues'}, $Data->{'clientValues'}{'current_level'}) || 0;
	if($action eq 'DUPL_U')	{
		$body=updateDuplicateProblems($Data, $entityID) || '';	
		$action='DUPL_L';
	}
	if($action eq 'DUPL_L')	{
		$body.=displayDuplicateProblems($Data, $entityID) || '';	
	}
	my $title='Duplicate Resolution';

	return ($body,$title);
}

sub displayDuplicateProblems	{
	my ($Data, $entityID)=@_;
	my $db=$Data->{'db'};

	my $num_field=$Data->{'SystemConfig'}{'GenNumField'} || 'strNationalNum';

	my $realm=$Data->{'Realm'}||0;

	return 'Invalid Option - No Entity' if !$entityID;

	my $duplcheck=isCheckDupl($Data);
	my @FieldsToCheck=getDuplFields($Data);

	return ('Duplicate Checking is not configured') if(!$duplcheck or !@FieldsToCheck);

	my %SelectFields=(
        strLocalFirstname                => 1, 
        strLocalSurname                  => 1, 
        'tblPerson.strSuburb'       => 1, 
        'tblPerson.strState'        => 1, 
        'tblPerson.strISOCountry'      => 1, 
        'tblPerson.tTimeStamp'      => 1, 
        'tblPerson.strAddress1'     => 1, 
        'tblPerson.strAddress2'     => 1, 
        'tblPerson.strPostalCode'   => 1, 
        dtDOB                       => 1, 
        $num_field=>1
    );

	for my $k (@FieldsToCheck)	{ 
		$SelectFields{$k}=1; 
	}
	my $fieldlist=join(',',@FieldsToCheck);

	#<RE>
	my ($extraFrom, $extraWhere) = ('', '');
	#RE - added extraFrom, extraWhere to query
	my $selline=join(',',keys %SelectFields) || '';
	my $statement = qq[
		SELECT tblEntity.intEntityID, tblPerson.intPersonID, tblPerson.intPhoto, tblEntity.strLocalName AS strClubName, tblPerson.strStatus, COUNT(TXN.intTransactionID) as NumPaidTXN, $selline
		FROM tblPerson 
			INNER JOIN tblPersonRegistration_$realm as PR ON (tblPerson.intPersonID= PR.intPersonID)
			LEFT JOIN tblEntity ON (PR.intEntityID=tblEntity.intEntityID)
			LEFT JOIN tblTransactions as TXN ON (tblPerson.intPersonID = TXN.intID AND TXN.intTableType=$Defs::LEVEL_PERSON AND TXN.intStatus=1)
			$extraFrom
		WHERE PR.intEntityID = $entityID
			AND tblPerson.intSystemStatus=$Defs::PERSONSTATUS_POSSIBLE_DUPLICATE
            AND tblPerson.strStatus <> 'INPROGRESS'
            AND PR.strStatus <> 'INPROGRESS'
			AND tblPerson.intRealmID=$realm
			$extraWhere
		GROUP BY tblPerson.intPersonID
		ORDER BY strLocalSurname
	];
	my $wherestr='';

	my $query = $db->prepare($statement) or query_error($statement);
	$query->execute or query_error($statement);
	my $where='';
	my %ProbRecords=();
	while(my $dref = $query->fetchrow_hashref())  {
		my $key='';
		my $w='';
		for my $k (@FieldsToCheck)	{ 
			## FIX HERE $dref->{$k} =~ s/\s*$//;
			$dref->{$k} =~ s/\s*$// if ($k =~ /^str/);
			$key.=$dref->{$k}.'|'; 
			$w.=" AND  " if $w;
			$w.=" $k = ".$db->quote($dref->{$k});
		}
		$key=uc($key);
		$ProbRecords{$key}=$dref;
	  $where.= ' OR ' if $where;
		$where.="($w)";
	}
	$query->finish;
	my $body='';
	my $auto_resolved_Count=0;
	my $noduplicates = 0;
	if(scalar(keys %ProbRecords))	{
		$statement=qq[
			SELECT tblPerson.intPersonID AS intPersonID, tblEntity.intEntityID as ClubID, tblPerson.intPhoto, tblEntity.strLocalName AS strClubName, tblPerson.strStatus, $selline
			FROM tblPerson 
			    INNER JOIN tblPersonRegistration_$realm as PR ON (tblPerson.intPersonID= PR.intPersonID)
			    LEFT JOIN tblEntity ON (PR.intEntityID=tblEntity.intEntityID)
			WHERE tblPerson.intRealmID=$realm
				AND tblPerson.intSystemStatus <> $Defs::PERSONSTATUS_POSSIBLE_DUPLICATE
				AND tblPerson.intSystemStatus<>$Defs::PERSONSTATUS_DELETED
                AND tblPerson.strStatus <> 'INPROGRESS'
                AND PR.strStatus <> 'INPROGRESS'
				AND ( $where)
			ORDER BY strLocalSurname, strLocalFirstname, dtDOB
		];
		my $query = $db->prepare($statement) or query_error($statement);
		$query->execute or query_error($statement);
		my $i=0;
		my $cl  = setClient($Data->{'clientValues'});

		my $count=0;
		while(my $orig = $query->fetchrow_hashref())  {
			my $key='';
			for my $k (@FieldsToCheck)	{ 
				$orig->{$k} =~ s/\s*$// if ($k =~ /^str/);
				$key.=$orig->{$k}.'|'; 
			}
			$key=uc($key);
			next if exists $ProbRecords{$key}{'MATCH_FOUND'};
			my $bgcol= $i++%2==0 ? 'ffffff' : 'eeeeee';
			my $origdob=$orig->{'dtDOB'};
			my $dupldob=$ProbRecords{$key}{'dtDOB'};
			my $origtimeStamp=$orig->{'tTimeStamp'};
			my $dupltimeStamp=$ProbRecords{$key}{'tTimeStamp'};

			$ProbRecords{$key}{'MATCH_FOUND'} = 1;
			$orig->{$num_field}||='';
			$ProbRecords{$key}{$num_field}||='';
			$origdob=~s/(\d\d\d\d)-(\d\d)-(\d\d)/$3\/$2\/$1/;
			$dupldob=~s/(\d\d\d\d)-(\d\d)-(\d\d)/$3\/$2\/$1/;
			$origdob='' if $origdob eq '00/00/0000';
			$dupldob='' if $dupldob eq '00/00/0000';

			$origtimeStamp=~s/\s.*$// if $origtimeStamp;
			$dupltimeStamp=~s/\s.*$// if $dupltimeStamp;
			$origtimeStamp=~s/(\d\d\d\d)-(\d\d)-(\d\d)/$3\/$2\/$1/ if $origtimeStamp;
			$dupltimeStamp=~s/(\d\d\d\d)-(\d\d)-(\d\d)/$3\/$2\/$1/ if $dupltimeStamp;
			$origtimeStamp='' if $origtimeStamp eq '00/00/0000';
			$dupltimeStamp='' if $dupltimeStamp eq '00/00/0000';

			my $duplicate_member_id=$ProbRecords{$key}{intPersonID};
			my $origphoto='';
			my $probphoto='';
			if($orig->{intPhoto})	{
				my %cv=%{$Data->{'clientValues'}};
				$cv{'currentLevel'}=$Defs::LEVEL_PERSON;
				$cv{'personID'}=$orig->{intPersonID};
				my $c =setClient(\%cv);	
				$origphoto=qq[ <div><img width="200px;" src="getphoto.cgi?client=$c"></div> ];
			}
			if($ProbRecords{$key}{intPhoto})	{
				my %cv=%{$Data->{'clientValues'}};
				$cv{'currentLevel'}=$Defs::LEVEL_PERSON;
				$cv{'personID'}=$duplicate_member_id;
				my $c =setClient(\%cv);	
				$probphoto=qq[ <div><img width="200px;" src="getphoto.cgi?client=$c&amp"></div> ];
			}			
			$ProbRecords{$key}{'strClubName'} ||='';
			$orig->{strClubName}||='';
			my %statuses=($Defs::RECSTATUS_ACTIVE=> 'Active', $Defs::RECSTATUS_INACTIVE => 'Inactive');

			$count++;
			next if $count >=300;
			my $rows_count=13;
			## Build up row span depending on which fields will show below
			$rows_count ++ if ($ProbRecords{$key}{'strAddress1'} or $orig->{strAddress1});
			$rows_count ++ if ($ProbRecords{$key}{'strAddress2'} or $orig->{strAddress2});
			$rows_count ++ if ($ProbRecords{$key}{'strPostalCode'} or $orig->{strPostalCode});

			my %cv=%{$Data->{'clientValues'}};
			$cv{'currentLevel'}=$Defs::LEVEL_PERSON;
			$cv{'personID'}=$orig->{'intPersonID'};
			my $c =setClient(\%cv);	
			my $viewMoreLink = qq[viewdupl.cgi?client=$c&a=DUPL_more];
			my $viewMore = qq[<div><a href = "#" onclick = "dialogform('$viewMoreLink','View Duplicate Information');return false;">View more details...</a></div>];
			$body.=qq[
				<tr>
					<td style="padding:3px;background:#$bgcol;">&nbsp;</td>
					<td style="padding:3px;background:#$bgcol;border-bottom:solid 1px #000000"><b>Problem Record</b><br>(New Record)</td>
					<td style="padding:3px;background:#$bgcol;">&nbsp;</td>
					<td style="padding:3px;background:#$bgcol;border-bottom:solid 1px #000000"><b>Suggested Match</b><br>(Existing Online Data)$viewMore</td>
					<td style="padding:3px;background:#$bgcol;">&nbsp;</td>
				</tr>
				<tr>
					<td class="label" style="background:#$bgcol;">PersonID&nbsp;</td>
					<td class="value" style="background:#$bgcol;">$ProbRecords{$key}{'intPersonID'}</td>
					<td style="padding:3px;background:#$bgcol;">&nbsp;</td>
					<td class="value" style="background:#$bgcol;">$orig->{intPersonID}</td>
					<td style="padding:3px;background:#$bgcol;">&nbsp;</td>
				</tr>
				<tr>
					<td class="label" style="background:#$bgcol;">Firstname&nbsp;</td>
					<td class="value" style="background:#$bgcol;">$ProbRecords{$key}{'strLocalFirstname'}</td>
					<td style="padding:3px;background:#$bgcol;border-bottom:solid 1px #bbbbbb" rowspan="$rows_count"><span style="font-size:14px;padding:16px;">= ?</span></td>
					<td class="value" style="background:#$bgcol;">$orig->{strLocalFirstname}</td>
					<td style="padding:6px;padding-left:20px;background:#$bgcol;border-bottom:solid 1px #bbbbbb;vertical-align:top;" rowspan="$rows_count">
						<b>Choose option</b><br>
							<input type="hidden" name="matchNum$duplicate_member_id" value="$orig->{intPersonID}">
							<input type="radio" name="proboption$duplicate_member_id" value="matchusenew" onclick="return showwarning('matchusenew');" class="nb">This is the same person (Merge using new data as the base)<br>
							<input type="radio" name="proboption$duplicate_member_id" value="matchuseold" onclick="return showwarning('matchuseold');" class="nb">This is the same person (keep existing data)<br>
							<input type="radio" name="proboption$duplicate_member_id" value="new" onclick="return showwarning('new');" class="nb">This is a new person<br>
			];
			if ($ProbRecords{$key}{'NumPaidTXN'})	{
				$body .= qq[<br><i>Person has paid Transactions, cannot be deleted</i><br><br>];
			}
			else	{
				$body .= qq[
							<input type="radio" name="proboption$duplicate_member_id" value="del" onclick="return showwarning('del');" class="nb">Oops, delete this person<br>
				];
			}
			$body .= qq[
							<input type="radio" name="proboption$duplicate_member_id" checked value="ignore" onclick="return showwarning('ignore');" class="nb">Ignore this person for now<br>
							<br>
					</td>
				</tr>
				<tr>
					<td class="label" style="background:#$bgcol;">Surname&nbsp;</td>
					<td class="value" style="background:#$bgcol;">$ProbRecords{$key}{'strLocalSurname'}</td>
					<td class="value" style="background:#$bgcol;">$orig->{strLocalSurname}</td>
				</tr>
				<tr>
					<td class="label" style="background:#$bgcol;">Date of Birth&nbsp; </td>
					<td class="value" style="background:#$bgcol;">$dupldob </td>
					<td class="value" style="background:#$bgcol;">$origdob</td>
				</tr>
			];

			$body .= qq[
				<tr>
					<td class="label" style="background:#$bgcol;">Address 1&nbsp;</td>
					<td class="value" style="background:#$bgcol;">$ProbRecords{$key}{'strAddress1'}</td>
					<td class="value" style="background:#$bgcol;">$orig->{strAddress1}</td>
				</tr>
			] if ($ProbRecords{$key}{'strAddress1'} or $orig->{strAddress1});

			$body .= qq[
				<tr>
					<td class="label" style="background:#$bgcol;">Address 2&nbsp;</td>
					<td class="value" style="background:#$bgcol;">$ProbRecords{$key}{'strAddress2'}</td>
					<td class="value" style="background:#$bgcol;">$orig->{strAddress2}</td>
				</tr>
			] if ($ProbRecords{$key}{'strAddress2'} or $orig->{strAddress2});

			$body .= qq[
				<tr>
					<td class="label" style="background:#$bgcol;">Postal Code&nbsp;</td>
					<td class="value" style="background:#$bgcol;">$ProbRecords{$key}{'strPostalCode'}</td>
					<td class="value" style="background:#$bgcol;">$orig->{strPostalCode}</td>
				</tr>
			] if ($ProbRecords{$key}{'strPostalCode'} or $orig->{strPostalCode});

			$body .= qq[
				<tr>
					<td class="label" style="background:#$bgcol;">Suburb&nbsp;</td>
					<td class="value" style="background:#$bgcol;">$ProbRecords{$key}{'strSuburb'}</td>
					<td class="value" style="background:#$bgcol;">$orig->{strSuburb}</td>
				</tr>
				<tr>
					<td class="label" style="background:#$bgcol;">State&nbsp;</td>
					<td class="value" style="background:#$bgcol;">$ProbRecords{$key}{'strState'}</td>
					<td class="value" style="background:#$bgcol;">$orig->{strState}</td>
				</tr>
				<tr>
					<td class="label" style="background:#$bgcol;">Country&nbsp;</td>
					<td class="value" style="background:#$bgcol;">$ProbRecords{$key}{'strISOCountry'}</td>
					<td class="value" style="background:#$bgcol;">$orig->{strISOCountry}</td>
				</tr>
				<tr>
					<td class="label" style="background:#$bgcol;">$Data->{'LevelNames'}{$Defs::LEVEL_ASSOC}&nbsp;</td>
					<td class="value" style="background:#$bgcol;">&nbsp;</td>
					<td class="value" style="background:#$bgcol;">$orig->{strName}</td>
				</tr>
				<tr>
					<td class="label" style="background:#$bgcol;">Status&nbsp;</td>
					<td class="value" style="background:#$bgcol;">$statuses{$ProbRecords{$key}{'intRecStatus'}}</td>
					<td class="value" style="background:#$bgcol;">$statuses{$orig->{intRecStatus}}</td>
				</tr>
				<tr>
					<td class="label" style="background:#$bgcol;">$Data->{'LevelNames'}{$Defs::LEVEL_CLUB}&nbsp;</td>
					<td class="value" style="background:#$bgcol;">$ProbRecords{$key}{'strClubName'}</td>
					<td class="value" style="background:#$bgcol;">$orig->{strClubName}</td>
				</tr>
				<tr>
					<td class="label" style="background:#$bgcol;">Number&nbsp;</td> 
					<td class="value" style="background:#$bgcol;">$ProbRecords{$key}{$num_field}</td>
					<td class="value" style="background:#$bgcol;">$orig->{$num_field}</td>
				</tr>
				<tr>
					<td class="label" style="background:#$bgcol;border-bottom:solid 1px #bbbbbb;">&nbsp;</td> 
					<td class="value" style="background:#$bgcol;border-bottom:solid 1px #bbbbbb;">&nbsp;</td>
					<td class="value" style="background:#$bgcol;border-bottom:solid 1px #bbbbbb;">$origphoto</td>
				</tr>
			];
			#last if $count >=300;
		}
		my $resolved_Count = 0;
		foreach my $key (keys %ProbRecords)	{
			next if exists $ProbRecords{$key}{'MATCH_FOUND'} ;
			my $intPersonID_toResolve =$ProbRecords{$key}{intPersonID} || 0;
			$resolved_Count++;
			if ($intPersonID_toResolve)	{
				my $st = qq[
					UPDATE tblPerson
					SET intSystemStatus = $Defs::PERSONSTATUS_ACTIVE
					WHERE intSystemStatus = $Defs::PERSONSTATUS_POSSIBLE_DUPLICATE
						AND intPersonID = $intPersonID_toResolve
					LIMIT 1
				];
				my $qry_resolve = $db->prepare($st) or query_error($st);
				$qry_resolve->execute or query_error($st);
			}
		}
		my $Resolved_body = '';
		$Resolved_body .= qq[<p class="OKmsg"> $auto_resolved_Count member(s) were automatically resolved due to action based on the national identification scheme.</p>] if $auto_resolved_Count;
		$Resolved_body .= qq[<p class="OKmsg"> $resolved_Count member(s) were automatically resolved due to previously matching record being changed.</p>] if $resolved_Count;
		my $limit300 = ($count >= 299) ? qq[<p>This list has been limited to the first 300 duplicates.</p>] : '';

		$body=qq[
			$Resolved_body
			<p>The list below is of people that have been added that match another person within the database. </p>
			<p> To resolve the problem you must choose one of the options beside each person and then press the 'Update Duplicates' button.</p>
			$limit300

			<form action="$Data->{'target'}" method="post" name="duplform">
			<script language="JavaScript1.2" type="text/javascript">
				function showwarning (type)	{
					var msg = "";
					if(!document['duplform'].showwarnings.checked) {
						return true;
					}
					switch(type)	{
						case "del":
							msg="This option will delete all information about this person from the system.  You will not be able to get it back.";
							break;
						case "matchusenew":
							msg="This option will merge the new member with the existing.  It will use data from the new record, unless blank where it will check for existing data."; 
							break;
						case "matchuseold":
							msg="This option will discard the new details of the duplicate and use the details of the matching person already online.";
							break;
					}
					if(msg != "") {
						return confirm(msg);
					}
					return true;
				}				
			</script>

							<input type="checkbox" name="showwarnings" checked><b> Show warnings</b>
							
<br>
<br>
							<input type="submit" value="Update Duplicates" class="button proceed-button">
	<div style="clear:both;"></div>		
	<table border="0" cellpadding="0" cellspacing="0">
				$body
			</table>
							<input type="hidden" name="client" value="].unescape($cl).qq[">
							<input type="hidden" name="a" value="DUPL_U"><br><br>
							<input type="submit" value="Update Duplicates" class="button proceed-button">
			</form>
		] if $body;
		$query->finish;
		$noduplicates = 1 if !$body;
		$body=qq[$Resolved_body<br><p>There are no possible duplicates that need to be resolved.</p>] if !$body;
	}
	else	{
		$noduplicates = 1;
		$body=qq[<p>There are no possible duplicates that need to be resolved.</p>];
	}
	if($noduplicates)	{
		deleteNotification(
			$Data,
			$Defs::LEVEL_NODE,
			$entityID,
			0,
			'duplicates',
			0,
		);
	}

	return $body;
}

sub updateDuplicateProblems	{
	my ($Data, $entityID) = @_;
warn("UPDATE DUP PROBLEMS");
	my $num_field=$Data->{'SystemConfig'}{'GenNumField'} || 'strNationalNum';
	my %params=Vars();
	my $autoOption = $params{'autooption'} || 'ignore';
	for my $k (keys %params)	{
		if($k =~/^proboption/)	{
			my ($id_of_duplicate)=$k=~/proboption(\d+)/;
			my $option=$params{$k} || 'ignore';
			$option = $autoOption if ($option eq 'ignore' and $autoOption ne 'ignore'); #'

			#First we should check that this person is actually part of this associ
			my $inentity=checkEntity($Data->{'db'},$Data->{'Realm'}, $id_of_duplicate, $entityID) || 0;

			return '<div class="warning">Invalid attempt to modify a Member </div>' if !$inentity;
warn("##########################$option");
			my $id_of_existing=$params{"matchNum$id_of_duplicate"} || 0;
			if($option eq 'new')	{
				my $st=qq[UPDATE tblPerson SET intSystemStatus = $Defs::PERSONSTATUS_ACTIVE WHERE intPersonID=$id_of_duplicate];
				$Data->{'db'}->do($st);
			}
			elsif($option eq 'del')	{
				processMemberChange($Data,$entityID, $id_of_duplicate,0,'del');
			}
			elsif($option eq 'matchusenew')	{
				processMemberChange($Data,$entityID, $id_of_duplicate,$id_of_existing,'change_usenew') if $id_of_existing;
			}
			elsif($option eq 'matchuseold')	{
				processMemberChange($Data,$entityID, $id_of_duplicate,$id_of_existing,'change_useold') if $id_of_existing;
			}
		}
	}
	return '<div class="OKmsg">Records Updated</div>';
}



sub checkEntity {
	my ($db,$realmID, $personID, $entityID)=@_;
	$personID ||= 0;
	$entityID||= 0;
	my $st=qq[
		SELECT intPersonID 
		FROM tblPersonRegistration_$realmID
		WHERE intEntityID=$entityID AND intPersonID=$personID
	];
	my $q=$db->prepare($st);
	$q->execute();
	my ($id)=$q->fetchrow_array();
	$q->finish();
	return $id||0;
}


sub processMemberChange	{
	my ($Data,$entityID, $id_of_duplicate, $existingid, $option)=@_;

warn("PRCOESS MEMBER CHANGE");
	my $natnum = '';
	my $memberNo = '';
	my %USE_DATA=();
	$USE_DATA{'DataOrigin'} = 0;
	if ($option =~ /^change/)	{
		my $st = qq[
			SELECT 
				strNationalNum,
                strPersonNo,
                intDataOrigin
			FROM 
				tblPerson 
			WHERE 
				intPersonID IN ($id_of_duplicate, $existingid) 
			ORDER BY 
				intPersonID ASC 
		];	
		my $q=$Data->{'db'}->prepare($st);
		$q->execute();
		
		while (my $dref = $q->fetchrow_hashref())	{
			$natnum = $dref->{'strNationalNum'} if ! $natnum and $dref->{'strNationalNum'};
			$memberNo= $dref->{'strPersonNo'} if ! $memberNo and $dref->{'strPersonNo'};
			$USE_DATA{'DataOrigin'} = $dref->{intDataOrigin} if (
                $dref->{'intDataOrigin'} > $USE_DATA{'DataOrigin'} 
                and $USE_DATA{'DataOrigin'} !=  $Defs::CREATED_BY_REGOFORM
            );
		}
		$USE_DATA{'MemberNo'} = $memberNo || '';

		$st = qq[
			SELECT 
				intPersonID,
				strStatus
			FROM 
				tblPerson
			WHERE
				intPersonID IN ($id_of_duplicate, $existingid)
		];	
		$q=$Data->{'db'}->prepare($st);
		$q->execute();
		while (my $dref= $q->fetchrow_hashref())	{
			$USE_DATA{'strStatus'} = $dref->{'strStatus'} if ! $USE_DATA{'strStatus'};
		}
		
	}

	if($option eq 'change_usenew')	{
		#Get the Data rom the new record
		my $st=qq[SELECT * FROM tblPerson where intPersonID=$id_of_duplicate LIMIT 1];
		my $q=$Data->{'db'}->prepare($st);
		$q->execute();
		my $dref=$q->fetchrow_hashref();
		$q->finish();
		deQuote($Data->{'db'},$dref);
		my $update_str='';	
		$dref->{'intSystemStatus'}=$Defs::PERSONSTATUS_ACTIVE;
		for my $k (keys %{$dref})	{

			next if !defined $dref->{$k};

next if ! $dref->{$k};
next if $dref->{$k} eq '';
next if $dref->{$k} eq "''";
next if $dref->{$k} eq "'0000-00-00'";

			next if $k eq 'intPersonID';
			next if $k eq 'strNationalNum';
			next if $k eq 'intPhoto' and ! $dref->{'intPhoto'};
			next if $k eq 'strPersonNo' and ! $dref->{'strPersonNo'};
			next if $k eq 'intDataOrigin' and ! $dref->{'intDataOrigin'};
			
			next if $dref->{$k} eq 'NULL';
			$dref->{$k} ="''" if $dref->{$k} eq 'NULL';
			$update_str.=',' if $update_str;
			$update_str.= " $k = $dref->{$k} ";
		}
		
		#OK now set the Existing record with the new data from
		my $updst=qq[UPDATE tblPerson SET $update_str WHERE intPersonID=$existingid];
		$Data->{'db'}->do($updst);	
    }
		
	    my $memberNoUpdate = $USE_DATA{'MemberNo'} ? qq[ strPersonNo="$USE_DATA{'MemberNo'}", ] : '';
    my $createdFrom = $USE_DATA{'DataOrigin'} ? qq[ intDataOrigin =$USE_DATA{'DataOrigin'}, ] : '';
	if ($option =~ /^change/ and $natnum)	{
		my $updst=qq[UPDATE tblPerson SET $memberNoUpdate $createdFrom strNationalNum = '$natnum' WHERE intPersonID=$existingid];
		$Data->{'db'}->do($updst);	
	}
	elsif ($option =~ /^change/ and ($memberNoUpdate or $createdFrom))	{
		my $updst=qq[UPDATE tblPerson SET $memberNoUpdate $createdFrom  WHERE intPersonID=$existingid];
		$Data->{'db'}->do($updst);	
	}

		my $realmID = $Data->{'Realm'};
	if($option eq 'del')	{ 
        warn("HANDLE PERSON REGO HERE");
		$Data->{'db'}->do(qq[UPDATE tblPerson as M LEFT JOIN tblPersonRegistration_$realmID as MA ON (MA.intPersonID = M.intPersonID and MA.intEntityID<> $entityID ) SET M.intSystemStatus=$Defs::RECSTATUS_DELETED WHERE M.intPersonID=$id_of_duplicate and MA.intPersonID IS NULL]);
		$Data->{'db'}->do(qq[UPDATE tblPerson as M LEFT JOIN tblPersonRegistration_$realmID as MA ON (MA.intPersonID = M.intPersonID and MA.intEntityID<> $entityID) SET M.intSystemStatus=$Defs::RECSTATUS_ACTIVE WHERE M.intPersonID=$id_of_duplicate and MA.intPersonID IS NOT NULL]);
        $Data->{'db'}->do(qq[DELETE FROM tblWFTask WHERE intPersonID = $id_of_duplicate and strWFRuleFor IN ('PERSON', 'REGO')]);
	}
	elsif($option =~ /^change/)	{ 
        mergePersonRegistrations($Data, $id_of_duplicate, $existingid);
		$Data->{'db'}->do(qq[UPDATE tblTransactions SET intID = $existingid WHERE intID = $id_of_duplicate and intTableType=$Defs::LEVEL_PERSON AND intPersonRegistrationID=0]);
		$Data->{'db'}->do(qq[UPDATE tblDocuments SET intEntityID = $existingid WHERE intEntityID = $id_of_duplicate and intEntityLvel=$Defs::LEVEL_PERSON]);
		$Data->{'db'}->do(qq[UPDATE tblClearance SET intPersonID = $existingid WHERE intPersonID=$id_of_duplicate]);
		$Data->{'db'}->do(qq[UPDATE IGNORE tblAuth SET intID = $existingid WHERE intLevel=1 AND intID=$id_of_duplicate]);

		$Data->{'db'}->do(qq[UPDATE tblUploadedFiles SET intEntityID = $existingid WHERE intEntityID=$id_of_duplicate and intEntityTypeID=1]);

        checkPersonNotes($Data->{'db'}, $id_of_duplicate, $existingid);

		my $pr_st = qq[
			SELECT DISTINCT intEntityID
			FROM tblPersonRegistration_$realmID
			WHERE intPersonID = $id_of_duplicate
		];
		my $qry_pr=$Data->{'db'}->prepare($pr_st);
		$qry_pr->execute();
		while (my $aref=$qry_pr->fetchrow_hashref())	{
			$Data->{'db'}->do(qq[
          		      INSERT INTO tblDuplChanges (intEntityID, intNewID, intOldID)
                		VALUES ($entityID, $existingid, $id_of_duplicate)
        	]);

		}

		$Data->{'db'}->do(qq[DELETE M.* FROM tblPerson as M LEFT JOIN tblPersonRegistration_$realmID as PR ON (PR.intPersonID = M.intPersonID and PR.intEntityID <> $entityID) WHERE M.intPersonID=$id_of_duplicate and PR.intPersonID IS NULL]);
		if ($option eq 'del')	{
			$Data->{'db'}->do(qq[UPDATE tblPerson SET intSystemStatus=$Defs::RECSTATUS_ACTIVE WHERE intPersonID=$id_of_duplicate]);
		}
		$Data->{'db'}->do(qq[UPDATE tblPerson SET intSystemStatus=$Defs::RECSTATUS_ACTIVE WHERE intPersonID=$existingid ]);
		movePhoto($Data->{'db'}, $existingid, $id_of_duplicate);
	}
  #auditLog(0, $Data, 'Resolve', 'Duplicates');
}

sub checkPersonNotes    {

    my ($db, $id_of_duplicate, $existingid) = @_;

    my $st = qq[
        SELECT
            strNotes
        FROM
            tblPersonNotes
        WHERE
            intPersonID IN ($id_of_duplicate, $existingid)
    ];
    my $query = $db->prepare($st) or query_error($st);
    $query->execute or query_error($st);

    my %Notes=();

    while (my $dref = $query->fetchrow_hashref())   {
        $Notes{'strNotes'} .= qq[\n] if $Notes{'strNotes'};
        $Notes{'strNotes'} .= $dref->{strNotes} || '';
    }

    $Notes{'strNotes'} ||= '';

    $st = qq[
        DELETE
        FROM
            tblPersonNotes
        WHERE
            intPersonID = $id_of_duplicate
    ];
  $db->do($st);
  require Person;
  Person::updatePersonNotes($db, $existingid ,\%Notes);
}

sub isCheckDupl	{
	my($Data)=@_;
    return '' if ($Data->{'ReadOnlyLogin'} and !$Data->{'SystemConfig'}{'ShowDCWhenRO'});
	my $check_dupl='';

	#Duplicates should also be checked for unless specifically disabled
	if (exists $Data->{'SystemConfig'}{'DuplCheck'}) {
        return 'realm' if $Data->{'SystemConfig'}{'DuplCheck'} eq '1'; 
        return ''      if $Data->{'SystemConfig'}{'DuplCheck'} eq '-1'; #Don't check dup; 
	}
	if (exists $Data->{'Permissions'}{'OtherOptions'} and 
        exists $Data->{'Permissions'}{'OtherOptions'}{'DuplCheck'} and 
        $Data->{'Permissions'}{'OtherOptions'}{'DuplCheck'}[0] eq '-1')	{
		    return ''; #Explicitly turned off
	}
	return 'assoc';
}

sub getDuplFields	{
    my($Data)=@_;
    my $duplfields=$Data->{'SystemConfig'}{'DuplicateFields'} 
        || $Data->{'Permissions'}{'OtherOptions'}{'DuplFields'} 
        || 'strLocalSurname|strLocalFirstname|dtDOB';
    my @FieldsToCheck=split /\|/,$duplfields;
    return @FieldsToCheck;
}

1;
