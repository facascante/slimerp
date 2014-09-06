#
# $Header: svn://svn/SWM/trunk/web/EditMemberClubs.pm 10939 2014-03-12 00:49:39Z dhanslow $
#

package EditMemberClubs;
require Exporter;
@ISA = qw(Exporter);
@EXPORT=qw(handleMemberClub);
@EXPORT_OK=qw(handleMemberClub);

use strict;
use Reg_common;
use Utils;
use CGI qw(unescape param);
use HTMLForm qw(_date_selection_dropdown);
use Date::Calc qw(Today);
use AuditLog;
use Seasons;
use GenAgeGroup;

sub handleMemberClub{
	my ($action, $Data,$memberID)=@_;
	my $resultHTML='';
	my $title='';
	my $ret='';
	if ($action =~/^M_CLB_u/) {
		 ($ret,$title)=update_clubs($action, $Data, $memberID);
		 $action='M_CLB_l';
		 $resultHTML.=$ret;
	}
	else	{
		#Assoc Details
		 ($ret,$title)=edit_clubs($action, $Data, $memberID);
			$resultHTML.=$ret;
	}
	$title||=$Data->{'lang'}->txt($Data->{'LevelNames'}{$Defs::LEVEL_CLUB."_P"});
	
	return ($resultHTML,$title);
}

sub edit_clubs	{
	my ($action, $Data, $memberID)=@_;

	my $l=$Data->{'lang'};
	my $intro=$l->txt('FIELDS_intro');

	my $assocID=$Data->{'clientValues'}{'assocID'} || 0;
	my $realmID=$Data->{'Realm'} || 0;
	my $subBody=qq[
		<form action="$Data->{'target'}" method="POST">
		<input type="submit" value="].$l->txt("Save " . $Data->{'LevelNames'}{$Defs::LEVEL_CLUB."_P"}).qq[">
		<table class="permsTable">
	];
	my $unescclient=unescape(setClient($Data->{'clientValues'}));

	my $assocSeasons = Seasons::getDefaultAssocSeasons($Data);
	my $CurrentMemberClub = getCurrentMemberClub($Data->{'db'}, $Data->{'Realm'}, $assocID, $memberID, $assocSeasons->{'newRegoSeasonID'});
	my $txt_SeasonNames= $Data->{'SystemConfig'}{'txtSeasons'} || 'Seasons';
	my $txt_SeasonName= $Data->{'SystemConfig'}{'txtSeason'} || 'Season';

	## GET PRIMARY CLUB
	my $PrimaryClub = ($Data->{'SystemConfig'}{'AllowPrimaryClub'}) ? getPrimaryClub($Data->{'db'},$memberID) : '';
	$PrimaryClub = (!$PrimaryClub) ? -1 : $PrimaryClub; ## MAKE SURE THAT PRIMARY CLUB IS NOT NULL
	my $st=qq[
		SELECT tblClub.intClubID, tblClub.strName 
		FROM tblClub INNER JOIN tblAssoc_Clubs ON tblClub.intClubID=tblAssoc_Clubs.intClubID
		WHERE tblAssoc_Clubs.intAssocID=$assocID
			AND tblClub.intRecStatus<>$Defs::RECSTATUS_DELETED
      AND tblAssoc_Clubs.intRecStatus<>$Defs::RECSTATUS_DELETED
		ORDER BY tblClub.strName
	];
	my $q=$Data->{'db'}->prepare($st);
	$q->execute();

	## HEADER INFORMATION
	my $gradeTitle = ($Data->{'SystemConfig'}{'AllowClubGrades'}) ? qq[<th>Grade</th>] : '' ;
	my $pclubTitle = '';
  if ($Data->{'SystemConfig'}{'AllowPrimaryClub'}) {
    my $title = ($Data->{'SystemConfig'}{'PrimaryClubTitle'}) ? $Data->{'SystemConfig'}{'PrimaryClubTitle'} : 'Primary';
    $pclubTitle = qq[<th> $title $Data->{'LevelNames'}{$Defs::LEVEL_CLUB}</th>];
  }
	my $contractTitle = ($Data->{'SystemConfig'}{'AllowContractDetails'}) ? qq[<th>Contract Number</th><th>Contract Expiry Year</th><th>Contract Entered</th>] : '' ;
	$subBody .= qq[
		<tr>	
			<th colspan="5"><b>Includes the member types for <i>$assocSeasons->{'newRegoSeasonName'}</i></b><br><br>For member to Participate in $assocSeasons->{'newRegoSeasonName'} $txt_SeasonName, you must tick <b>Participates in $assocSeasons->{'newRegoSeasonName'} $txt_SeasonName</b>.</th>
		</tr>
	] if ($assocSeasons->{'allowSeasons'} and ! $Data->{'SystemConfig'}{'Seasons_NotOnMCInactive'});
	$subBody .= qq[
		<tr>
			<th>$Data->{'LevelNames'}{$Defs::LEVEL_CLUB} Name</th>
			<th>Active</th>
			<th>Inactive</th>
			<th>Delete from $Data->{'LevelNames'}{$Defs::LEVEL_CLUB}</th>
			$gradeTitle
			$pclubTitle
			$contractTitle
	];
	$subBody .= qq[
			<th><b>Participates in<br>$assocSeasons->{'newRegoSeasonName'} $txt_SeasonName?</b></th>
			<th>Player in<br>$Data->{'LevelNames'}{$Defs::LEVEL_CLUB}<br>for $assocSeasons->{'newRegoSeasonName'}?</th>
			<th>Coach in<br>$Data->{'LevelNames'}{$Defs::LEVEL_CLUB}<br>for $assocSeasons->{'newRegoSeasonName'}?</th>
			<th>Misc in<br>$Data->{'LevelNames'}{$Defs::LEVEL_CLUB}<br>for $assocSeasons->{'newRegoSeasonName'}?</th>
			<th>Volunteer in<br>$Data->{'LevelNames'}{$Defs::LEVEL_CLUB}<br>for $assocSeasons->{'newRegoSeasonName'}?</th>
			<th>$Data->{'SystemConfig'}{'TYPE_NAME_3'} in<br>$Data->{'LevelNames'}{$Defs::LEVEL_CLUB}<br>for $assocSeasons->{'newRegoSeasonName'}?</th>
	] if ($assocSeasons->{'allowSeasons'} and ! $Data->{'SystemConfig'}{'Seasons_NotOnMCInactive'});
	$subBody .= qq[<th>$Data->{'SystemConfig'}{'Seasons_Other1'} in<br>$Data->{'LevelNames'}{$Defs::LEVEL_CLUB}<br>for $assocSeasons->{'newRegoSeasonName'}?</th>] if ($Data->{'SystemConfig'}{'Seasons_Other1'} and $assocSeasons->{'allowSeasons'} and ! $Data->{'SystemConfig'}{'Seasons_NotOnMCInactive'});
	$subBody .= qq[<th>$Data->{'SystemConfig'}{'Seasons_Other2'} in<br>$Data->{'LevelNames'}{$Defs::LEVEL_CLUB}<br>for $assocSeasons->{'newRegoSeasonName'}?</th>] if ($Data->{'SystemConfig'}{'Seasons_Other2'} and $assocSeasons->{'allowSeasons'} and ! $Data->{'SystemConfig'}{'Seasons_NotOnMCInactive'});
	$subBody .= qq[
		</tr>
	];
			#<th>Official ?</th>
			#<th>Misc ?</th>

	my $found=0;
	while(my $dref=$q->fetchrow_hashref())	{
		next if !$dref->{'strName'};
		$found=1;
		
		my $act_checked=(exists $CurrentMemberClub->{$dref->{'intClubID'}}{'Status'} and $CurrentMemberClub->{$dref->{'intClubID'}}{'Status'}==$Defs::RECSTATUS_ACTIVE) ? 'checked' : '';
		my $inact_checked=(exists $CurrentMemberClub->{$dref->{'intClubID'}}{'Status'} and $CurrentMemberClub->{$dref->{'intClubID'}}{'Status'}==$Defs::RECSTATUS_INACTIVE) ? 'checked' : '';

		my $del_checked=(exists $CurrentMemberClub->{$dref->{'intClubID'}}{'Status'} and $CurrentMemberClub->{$dref->{'intClubID'}}{'Status'}==$Defs::RECSTATUS_DELETED) ? 'checked' : '';

		my $noOfMemberClubs = getNumberOfMemberClubs($Data->{'db'},$memberID) if $Data->{'SystemConfig'}{'AllowPrimaryClub'};

		my $selected= ($Data->{'SystemConfig'}{'AllowPrimaryClub'} and $dref->{'intClubID'}==$PrimaryClub or ($noOfMemberClubs==1 and exists $CurrentMemberClub->{$dref->{'intClubID'}}{'Status'} and $CurrentMemberClub->{$dref->{'intClubID'}}{'Status'}==$Defs::RECSTATUS_ACTIVE)) ? ' CHECKED ' : '';


		## DISPLAY GRADE DROP DOWN LIST	
		my $gradeDDL='';
		$gradeDDL = qq[<td>].getGradeDDL($Data->{'db'},$memberID,$dref->{'intClubID'},$realmID).qq[</td>] if $Data->{'SystemConfig'}{'AllowClubGrades'};

		## DISPLAY CONTRACT NO AND YEAR
		my $contractDetails='';
		$contractDetails = getContractDetails($Data->{'db'},$memberID,$dref->{'intClubID'},$realmID) if $Data->{'SystemConfig'}{'AllowContractDetails'};
	
		## DISPLAY PRIMARY MEMBER RADION BUTTONS
		my $primaryClub='';
		$primaryClub = qq[<td align="center"><input type="radio" name="PCLB" value="$dref->{'intClubID'}" $selected></td>] if $Data->{'SystemConfig'}{'AllowPrimaryClub'};

		my $player = $CurrentMemberClub->{$dref->{'intClubID'}}{'PlayerStatus'} ? 'CHECKED' : '';
		my $coach = $CurrentMemberClub->{$dref->{'intClubID'}}{'CoachStatus'} ? 'CHECKED' : '';
		my $umpire= $CurrentMemberClub->{$dref->{'intClubID'}}{'UmpireStatus'} ? 'CHECKED' : '';
		my $misc  = $CurrentMemberClub->{$dref->{'intClubID'}}{'MiscStatus'} ? 'CHECKED' : '';
		my $volunteer = $CurrentMemberClub->{$dref->{'intClubID'}}{'VolunteerStatus'} ? 'CHECKED' : '';
		my $other1= $CurrentMemberClub->{$dref->{'intClubID'}}{'Other1Status'} ? 'CHECKED' : '';
		my $other2= $CurrentMemberClub->{$dref->{'intClubID'}}{'Other2Status'} ? 'CHECKED' : '';
		my $season= $CurrentMemberClub->{$dref->{'intClubID'}}{'InNewRegoSeason'} ? 'CHECKED' : '';
		$subBody.=qq[
			<tr>
				<td class="label">$dref->{'strName'}</td>
				<td align="center"><input type="radio" name="CLB_$dref->{'intClubID'}" value="ACTIVE" $act_checked></td>
				<td align="center"><input type="radio" name="CLB_$dref->{'intClubID'}" value="INACTIVE" $inact_checked></td>
				<td align="center"><input type="radio" name="CLB_$dref->{'intClubID'}" value="DELETE" $del_checked></td>
				$gradeDDL
				$primaryClub
				$contractDetails
		];
		if ($assocSeasons->{'allowSeasons'} and ! $Data->{'SystemConfig'}{'Seasons_NotOnMCInactive'})	{
#			if (exists $CurrentMemberClub->{$dref->{'intClubID'}}{'Status'} and $CurrentMemberClub->{$dref->{'intClubID'}}{'NumSeasons'} > 1)	{
#				my $colCount = 3;
#				$colCount ++ if ($Data->{'SystemConfig'}{'Seasons_Other1'});
#				$colCount ++ if ($Data->{'SystemConfig'}{'Seasons_Other2'});
#				$subBody .= qq[
#						<td align="center"><input type="checkbox" name="CLBA_$dref->{'intClubID'}" value="1" $season></td>
#						<td colspan="$colCount">Cannot Update Member Types as a member of $Data->{'LevelNames'}{$Defs::LEVEL_CLUB} over multiple $txt_SeasonNames</td>
#					</tr>
#				];
#			}
#			else	{
				### FOR NEW CLUB RELATIONSHIPS (New Rego Season)
				my $PutInSeason = $season ? qq[<input type="hidden" name="CLBA_$dref->{'intClubID'}" value="1" $season>Yes] : qq[<input type="checkbox" name="CLBA_$dref->{'intClubID'}" value="1" $season>];
				$subBody .= qq[
						<td align="center">$PutInSeason</td>
						<td align="center"><input type="checkbox" name="CLBP_$dref->{'intClubID'}" value="1" $player></td>
						<td align="center"><input type="checkbox" name="CLBC_$dref->{'intClubID'}" value="1" $coach></td>
						<td align="center"><input type="checkbox" name="CLBM_$dref->{'intClubID'}" value="1" $misc></td>
						<td align="center"><input type="checkbox" name="CLBV_$dref->{'intClubID'}" value="1" $volunteer></td>
                        <td align="center"><input type="checkbox" name="CLBU_$dref->{'intClubID'}" value="1" $umpire></td>
				];
			
				$subBody .= qq[<td align="center"><input type="checkbox" name="CLBO1_$dref->{'intClubID'}" value="1" $other1></td>] if $Data->{'SystemConfig'}{'Seasons_Other1'};
				$subBody .= qq[<td align="center"><input type="checkbox" name="CLBO2_$dref->{'intClubID'}" value="1" $other2></td>] if $Data->{'SystemConfig'}{'Seasons_Other2'};

				$subBody .= qq[
					</tr>
				];
#			}
		}
  	}

	## IF PRIMARY CLUB ENABLED GET CLUBS FROM OTHER LEAGUES
	if ($Data->{'SystemConfig'}{'AllowPrimaryClub'}) {
		## GET LIST OF CLUBS THAT THE MEMBER BELONGS TO IN OTHER ASSOCIATIONS
	   	my $statement = qq[
			SELECT tblClub.strName AS strClubName, tblClub.intClubID, tblAssoc_Clubs.intAssocID, tblAssoc.strName AS strAssocName
			FROM tblClub
				INNER JOIN tblAssoc_Clubs ON tblClub.intClubID=tblAssoc_Clubs.intClubID
				INNER JOIN tblAssoc ON tblAssoc_Clubs.intAssocID=tblAssoc.intAssocID
			WHERE tblAssoc_Clubs.intAssocID IN (SELECT intAssocID FROM tblMember_Associations WHERE intMemberID=$memberID AND intAssocID <> $assocID);
		];
		my $query=$Data->{'db'}->prepare($statement);
		$query->execute();
		while (my $dref=$query->fetchrow_hashref()) {
			## DISPLAY PRIMARY MEMBER RADIO BUTTONS
			my $primaryClub='';
			$primaryClub = qq[<td align="center"><input type="radio" name="PCLB" value="$dref->{'intClubID'}"></td>];
			## BUILD HTML
			$subBody.=qq[
				<tr>
					<td class="label">$dref->{'strAssocName'} : $dref->{'strClubName'}</td>
					<td></td>
					<td></td>
					<td></td>
					$primaryClub
				</tr>
			];
		}
	}

	$subBody.=qq[
		</table>
		<input type="submit" value="].$l->txt('Save '. $Data->{'LevelNames'}{$Defs::LEVEL_CLUB."_P"}).qq[">
			<input type="hidden" name="a" value="M_CLB_u">
			<input type="hidden" name="client" value="$unescclient">
		</form>
	];
	if($found)	{ $subBody=qq[ <p>$intro</p>$subBody]; }
	else	{ $subBody=qq[<div class="warningmsg">There are no available $Data->{'LevelNames'}{$Defs::LEVEL_CLUB."_P"} to assign</div>]; }

	return ($subBody,$l->txt('Edit '. $Data->{'LevelNames'}{$Defs::LEVEL_CLUB."_P"}));

}

sub update_clubs {
	my ($action, $Data, $memberID)=@_;
	my $realmID=$Data->{'Realm'} || 0;
	my $assocID=$Data->{'clientValues'}{'assocID'} || 0;


	my %AvailableClubs=();
	{
		#Get Total List of MemberClub
		my $st=qq[
			SELECT 
        tblClub.intClubID, 
        tblClub.strName 
			FROM 
        tblClub 
				INNER JOIN tblAssoc_Clubs ON tblClub.intClubID=tblAssoc_Clubs.intClubID
			WHERE 
        tblAssoc_Clubs.intAssocID = $assocID
				AND tblClub.intRecStatus <> $Defs::RECSTATUS_DELETED
		];
		my $q=$Data->{'db'}->prepare($st);
		$q->execute();
		while(my $dref = $q->fetchrow_hashref())  {
			$AvailableClubs{$dref->{'intClubID'}} = $dref->{'strName'}||'';
		}
	}

	my $CurrentMemberClub = getCurrentMemberClub($Data->{'db'}, $Data->{'Realm'}, $assocID, $memberID, 1);

	my $txt_prob=$Data->{'lang'}->txt('Problem updating Fields');

	return qq[<div class="warningmsg">$txt_prob (1)</div>] if $DBI::err;

	my $add_contract1 = ($Data->{'SystemConfig'}{'AllowContractDetails'}) ? qq[,strContractNo, strContractYear,dtContractEntered] : '';
	my $add_contract2 = ($Data->{'SystemConfig'}{'AllowContractDetails'}) ? qq[,?,?,?] : '';
	my $up_contract = ($Data->{'SystemConfig'}{'AllowContractDetails'}) ? qq[, tblMember_Clubs.strContractNo=?, tblMember_Clubs.strContractYear=?, tblMember_Clubs.dtContractEntered=?] : '';

	my $st_add=qq[
		INSERT INTO tblMember_Clubs (
      intClubID, 
      intMemberID, 
      intStatus, 
      intGradeID 
      $add_contract1
    )
	  VALUES (
      ?, 
      $memberID, 
      ?,
      ? 
      $add_contract2
    )
	];
	my $st_upd=qq[
		UPDATE 
      tblMember_Clubs  
      INNER JOIN tblAssoc_Clubs ON tblMember_Clubs.intClubID=tblAssoc_Clubs.intClubID 
    SET 
      tblMember_Clubs.intStatus=?, 
      tblMember_Clubs.intGradeID=? 
      $up_contract
    WHERE intAssocID=$assocID 
		  AND intMemberID= $memberID
			AND tblMember_Clubs.intClubID = ? 
      AND (
        tblMember_Clubs.dtPermitEnd >= NOW() 
			  OR tblMember_Clubs.dtPermitEnd IS NULL
			  OR tblMember_Clubs.dtPermitEnd ='0000-00-00'
		  )
	];

	my $st_upd_2=qq[
		UPDATE 
      tblMember_Clubs  
      INNER JOIN tblAssoc_Clubs ON tblMember_Clubs.intClubID=tblAssoc_Clubs.intClubID 
    SET 
      tblMember_Clubs.intStatus=?, 
      tblMember_Clubs.intGradeID=? 
	  WHERE 
      intAssocID=$assocID 
			AND intMemberID= $memberID
			AND tblMember_Clubs.intClubID = ? 
      AND (
        tblMember_Clubs.dtPermitEnd >= NOW() 
			  OR tblMember_Clubs.dtPermitEnd IS NULL
			  OR tblMember_Clubs.dtPermitEnd ='0000-00-00'
		  )
	];

	my $st_permits = qq[
		UPDATE 
			tblMember_Clubs
		SET
			intStatus=0
		WHERE
			intPermit=1
			AND intMemberID=$memberID
			AND intClubID=?
			AND intStatus=1 
			AND tblMember_Clubs.dtPermitEnd < NOW()
	];

	my $q_permits=$Data->{'db'}->prepare($st_permits);
	my $q_add=$Data->{'db'}->prepare($st_add);
	my $q_upd=$Data->{'db'}->prepare($st_upd);
	my $q_upd_2=$Data->{'db'}->prepare($st_upd_2);
	
	my $PC=param("PCLB") || '';
	my $assocSeasons = Seasons::getDefaultAssocSeasons($Data);
	my $genAgeGroup ||=new GenAgeGroup ($Data->{'db'},$Data->{'Realm'}, $Data->{'RealmSubType'}, $assocID);
	my $st_member = qq[
    SELECT 
      DATE_FORMAT(dtDOB, "%Y%m%d") as DOBAgeGroup, 
      intGender
    FROM 
      tblMember
      WHERE intMemberID = $memberID
  ];
  my $qry_member=$Data->{'db'}->prepare($st_member);
  $qry_member->execute();
  my ($DOBAgeGroup, $Gender)=$qry_member->fetchrow_array();
  my $ageGroupID =$genAgeGroup->getAgeGroup($Gender, $DOBAgeGroup) || 0;
	for my $k (keys %AvailableClubs)	{
		next if !param("CLB_$k");
		$q_permits->execute($k);
		my $mcStatus = param("CLB_$k");
		
		my %types = ();
		#if ( ! exists $CurrentMemberClub->{$k})	or $CurrentMemberClub->{$k}{'NumSeasons'} <= 1)	{
		my $PutInSeason = param("CLBA_$k") || 0;
		if ($PutInSeason)	{
	    $types{'intPlayerStatus'} = param("CLBP_$k") || 0;
	    $types{'intCoachStatus'} = param("CLBC_$k") || 0;
	    $types{'intUmpireStatus'} = param("CLBU_$k") || 0;
	    $types{'intMiscStatus'} = param("CLBM_$k") || 0;
	    $types{'intVolunteerStatus'} = param("CLBV_$k") || 0;
	    $types{'intOther1Status'} = param("CLBO1_$k") || 0;
	    $types{'intOther2Status'} = param("CLBO2_$k") || 0;
		}

		if ($mcStatus eq 'DELETE')	{
			my $gradeID = param("CLBG_$k") || 0;
			$q_upd_2->execute($Defs::RECSTATUS_DELETED, $gradeID, $k,);
			updatePrimaryClub($Data->{'db'},$memberID,$k,0);
			delete $CurrentMemberClub->{$k};	
		}
		elsif ($mcStatus eq 'ACTIVE' or $mcStatus eq 'INACTIVE')	{
			my $status = $mcStatus eq 'ACTIVE' ? 1 : 0;
			my $gradeID = param("CLBG_$k") || 0;
			my ($contractNo, $contractYear, $dtDay, $dtMonth, $dtYear) = ('', '', '', '', ''); 
			if ($Data->{'SystemConfig'}{'AllowContractDetails'})	{
				$contractNo = param("contNo_$k") || '';
				$contractYear = param("contYear_$k") || '';
				$dtDay = param("d_".$k."_day") || '';
				$dtMonth = param("d_".$k."_mon") || '';
				$dtYear = param("d_".$k."_year") || '';
			}
			my $dtContractEntered = $dtYear."-".$dtMonth."-".$dtDay;
      ## IF SEASON NOT TURNED ON STILL CREATE DEFAULT CLUB SEASON RECORD
      $PutInSeason = 1 if (!$Data->{'SystemConfig'}{'AllowSeasons'});
			if(exists $CurrentMemberClub->{$k})	{
				if($CurrentMemberClub->{$k}{'Status'} != $Defs::RECSTATUS_DELETED)	{
				 	if ($PutInSeason and ! ($status == $Defs::RECSTATUS_INACTIVE and $Data->{'SystemConfig'}{'Seasons_NotOnMCInactive'}))	{
						$types{'intMSRecStatus'} = 1;
					 	Seasons::insertMemberSeasonRecord($Data, $memberID, $assocSeasons->{'newRegoSeasonID'}, $Data->{'clientValues'}{'assocID'}, $k, $ageGroupID, \%types);
						my %assocTypes=();
						$assocTypes{'intMSRecStatus'} = 1;
						Seasons::insertMemberSeasonRecord($Data, $memberID, $assocSeasons->{'newRegoSeasonID'}, $Data->{'clientValues'}{'assocID'}, 0, $ageGroupID, \%assocTypes);
					}
					if ($Data->{'SystemConfig'}{'AllowContractDetails'}) {
						$q_upd->execute($status,$gradeID,$contractNo,$contractYear,$dtContractEntered,$k);
					} else {
						$q_upd->execute($status,$gradeID,$k);
					}
					my $a = ($k == $PC) ? 1 : 0 ;
					updatePrimaryClub($Data->{'db'},$memberID,$k,$a);
				}
				delete $CurrentMemberClub->{$k};
			}
			else	{ 
				if ($PutInSeason)	{
					$types{'intMSRecStatus'} = 1;
					Seasons::insertMemberSeasonRecord($Data, $memberID, $assocSeasons->{'newRegoSeasonID'}, $Data->{'clientValues'}{'assocID'}, $k, $ageGroupID, \%types);
					my %assocTypes=();
					$assocTypes{'intMSRecStatus'} = 1;
					Seasons::insertMemberSeasonRecord($Data, $memberID, $assocSeasons->{'newRegoSeasonID'}, $Data->{'clientValues'}{'assocID'}, 0, $ageGroupID, \%assocTypes);
				}
				if ($Data->{'SystemConfig'}{'AllowContractDetails'}) {
					$q_add->execute($k,$status, $gradeID,$contractNo,$contractYear,$dtContractEntered); 
				} else {
					$q_add->execute($k,$status, $gradeID); 
				}
				if ($k == $PC) { updatePrimaryClub($Data->{'db'},$memberID,$k,1); }
			} 
		}
		return qq[<div class="warningmsg">$txt_prob (2)</div>] if $DBI::err;
	}
	#Now delete the non-active ones
	for my $k (keys %{$CurrentMemberClub})	{ 
		my $PutInSeason = param("CLBA_$k") || 0;
		my $gradeID = param("CLBG_$k");
		my %types = ();
		if ($CurrentMemberClub->{$k} and $CurrentMemberClub->{$k}{'NumSeasons'} <= 1)	{
	    $types{'intPlayerStatus'} = param("CLBP_$k") || 0;
	    $types{'intCoachStatus'} = param("CLBC_$k") || 0;
	    $types{'intUmpireStatus'} = param("CLBU_$k") || 0;
	    $types{'intMiscStatus'} = param("CLBM_$k") || 0;
	    $types{'intVolunteerStatus'} = param("CLBV_$k") || 0;
	    $types{'intOther1Status'} = param("CLBO1_$k") || 0;
	    $types{'intOther2Status'} = param("CLBO2_$k") || 0;
		}
		if ($PutInSeason and ! $Data->{'SystemConfig'}{'Seasons_NotOnMCInactive'})	{
			$types{'intMSRecStatus'} = 1;
			my %assocTypes=();
			$assocTypes{'intMSRecStatus'} = 1;
			Seasons::insertMemberSeasonRecord($Data, $memberID, $assocSeasons->{'newRegoSeasonID'}, $Data->{'clientValues'}{'assocID'}, $k, $ageGroupID, \%types);
			Seasons::insertMemberSeasonRecord($Data, $memberID, $assocSeasons->{'newRegoSeasonID'}, $Data->{'clientValues'}{'assocID'}, 0, $ageGroupID, \%assocTypes);
		}
		$q_upd_2->execute($Defs::RECSTATUS_INACTIVE, $gradeID, $k,);
		updatePrimaryClub($Data->{'db'},$memberID,$k,0);
	}
  auditLog($memberID, $Data, 'Update Clubs', 'Member');
	return '<div class="OKmsg">'.$Data->{'lang'}->txt('Clubs Updated').'</div>';
}

sub getCurrentMemberClub	{
	my($db, $realmID, $assocID, $memberID, $seasonID)=@_;
	my %CurrentMemberClub=();
	return undef if !$db;
	$assocID||=0;
	$memberID||=0;
	$seasonID ||=0;
	$realmID ||= 0;
	my $MStablename = "tblMember_Seasons_$realmID";
	#Get Current List of Active MemberClub
	my $st=qq[
		SELECT MC.intClubID, MC.intStatus, MS.intPlayerStatus, MS.intCoachStatus, MS.intUmpireStatus, MS.intMiscStatus, MS.intVolunteerStatus, MS.intOther1Status, MS.intOther2Status, COUNT(MS_Count.intMemberSeasonID) as CountClubSeasons, MS.intMemberSeasonID
		FROM tblMember_Clubs AS MC INNER JOIN tblAssoc_Clubs AS AC ON MC.intClubID=AC.intClubID
			LEFT JOIN $MStablename as MS ON (MS.intClubID = MC.intClubID 
				AND MS.intMemberID = MC.intMemberID 
				AND MS.intSeasonID=$seasonID
				AND MS.intMSRecStatus = 1)
			LEFT JOIN $MStablename as MS_Count ON (MS_Count.intClubID = MC.intClubID 
				AND MS_Count.intMemberID = MC.intMemberID 
			)
		WHERE AC.intAssocID=$assocID
			AND MC.intMemberID=$memberID
			AND MC.intStatus<>$Defs::RECSTATUS_DELETED
            AND (MC.dtPermitEnd >= NOW() OR MC.dtPermitEnd IS NULL OR MC.dtPermitEnd ='0000-00-00')
		GROUP BY MC.intMemberID, MC.intClubID, MC.intMemberClubID
		ORDER BY MC.intStatus 
	];
	my $q=$db->prepare($st);
	$q->execute();
	while(my $dref=$q->fetchrow_hashref())  {
		$CurrentMemberClub{$dref->{'intClubID'}}{'ClubID'}=$dref->{'intClubID'};
		$CurrentMemberClub{$dref->{'intClubID'}}{'Status'}=$dref->{'intStatus'};
		$CurrentMemberClub{$dref->{'intClubID'}}{'PlayerStatus'}=$dref->{'intPlayerStatus'} || 0;
		$CurrentMemberClub{$dref->{'intClubID'}}{'CoachStatus'}=$dref->{'intCoachStatus'} || 0;
		$CurrentMemberClub{$dref->{'intClubID'}}{'UmpireStatus'}=$dref->{'intUmpireStatus'} || 0;
		$CurrentMemberClub{$dref->{'intClubID'}}{'MiscStatus'}=$dref->{'intMiscStatus'} || 0;
		$CurrentMemberClub{$dref->{'intClubID'}}{'VolunteerStatus'}=$dref->{'intVolunteerStatus'} || 0;
		$CurrentMemberClub{$dref->{'intClubID'}}{'Other1Status'}=$dref->{'intOther1Status'} || 0;
		$CurrentMemberClub{$dref->{'intClubID'}}{'Other2Status'}=$dref->{'intOther2Status'} || 0;
		$CurrentMemberClub{$dref->{'intClubID'}}{'NumSeasons'}=$dref->{'CountClubSeasons'} || 0;
		$CurrentMemberClub{$dref->{'intClubID'}}{'InNewRegoSeason'}= $dref->{'intMemberSeasonID'} ? 1 : 0;
	}
	return \%CurrentMemberClub;
}


sub getGradeDDL {
	my ($db,$memberID,$clubID,$realmID)=@_;
	my $gradeDDLHTML='';


	#	## GET THE CURRENT GRADE OF THE MEMEBER
	#	my $st=qq[
	#		SELECT intGradeID
	#		FROM tblMember_Clubs
	#		WHERE intClubID=$clubID
	#		AND intMemberID=$memberID
	#		AND intStatus <> $Defs::RECSTATUS_DELETED
	#	];
	#	my $q=$db->prepare($st);
	#	$q->execute();
	#	my ($intGradeID) = $q->fetchrow_array();

## -- START -------------- 

		my ($year,$month,$day) = Today();
       	## GET THE AGE OF THE PLAYER AS OF THE 31/12 OF THE CURRENT YEAR
        my $age_date = qq[$year-12-31];
        my $statement = qq[
        	SELECT DATE_FORMAT(FROM_DAYS(TO_DAYS("$age_date")-TO_DAYS(dtDOB)),'%Y')+0 AS AGE
            FROM tblMember
            	WHERE intMemberID=$memberID;
        ];
        my $query=$db->prepare($statement);
        $query->execute();
        my $age = $query->fetchrow_array();
        ## GET A LIST OF GRADES LESS THAN THE PLAYERS AGE AT THE 31/12 THEN SORT DESC AND LIMIT TO ONE
        ## IN ORDER TO GET THE GRADE THEY BELONG TO
        $statement = qq[
        	SELECT intGradeID
            FROM tblClubGrades
            WHERE intAge <= $age
            ORDER BY intAge DESC
            LIMIT 1
        ];
        $query=$db->prepare($statement);
        $query->execute();
        my ($intGradeID) = $query->fetchrow_array();

## -- END ----------------

	$intGradeID = (!$intGradeID) ? -1 : $intGradeID;
	## BUILD DROP DOWN LIST
	$gradeDDLHTML = qq[<select name="CLBG_$clubID"><option value="0"></option>];
	my $st=qq[
		SELECT intGradeID, strGradeName
		FROM tblClubGrades
		WHERE intRealmID=$realmID
	];
	my $q=$db->prepare($st);
	$q->execute();
	while (my ($gradeID, $gradeName) = $q->fetchrow_array()) {
		my $selected = ($gradeID == $intGradeID) ? "SELECTED" : ""; ## TEST TO SEE IF GRADE EQUALS MEMBER GRADE
		$gradeDDLHTML .= qq[<option value="$gradeID" $selected>$gradeName</option>];
	}
	$gradeDDLHTML .= qq[</select>];
	return $gradeDDLHTML;
}

sub getContractDetails {
	## CHANGES
	## 10/01/2007 - ADD IN TEST TO SEE IF CLUB LINK IS ACTIVE PUT IN CURRENT YEAR BY DEFAULT

    my ($db,$memberID,$clubID,$realmID)=@_;
	my ($year,$month,$day) = Today();
    my $contractDetailsHTML='';

	## CHECK IF PRIMARY CLUB EXISTS
	my $primaryClubExists = getPrimaryClub($db,$memberID);
	## GET NUMBER OF CLUBS THE MEMBER BELONGS TOO
	my $noOfMemberClubs=0;
	## IF NO PRIMARY CLUB GET NUMBER OF CLUBS WICH ARE ACTIVE
	#if (!$primaryClubExists) { $noOfMemberClubs = getNumberOfMemberClubs($db,$memberID); }
	$noOfMemberClubs = getNumberOfMemberClubs($db,$memberID);

        ## GET THE CURRENT GRADE OF THE MEMEBER
        my $st=qq[
                SELECT strContractYear, strContractNo, dtContractEntered, intStatus
                FROM tblMember_Clubs
                WHERE intClubID=$clubID
                AND intMemberID=$memberID
                AND intStatus <> $Defs::RECSTATUS_DELETED
								ORDER BY dtContractEntered DESC
								LIMIT 1 
        ];
        my $q=$db->prepare($st);
        $q->execute();
        my ($strContractYear, $strContractNo, $dtContractEntered, $intStatus) = $q->fetchrow_array();
        $dtContractEntered = (!$dtContractEntered) ? ''  : $dtContractEntered;
        $strContractYear = (!$strContractYear) ? 0  : $strContractYear;
        $intStatus = (!$intStatus) ? 0  : $intStatus;
		
		## IF CONTRACT YEAR IS LESS THAN WHAT IS IN THE DATABASE DISPLAY THE CURRENT YEAR AND CURRENT DATE
		## THIS WILL ONLY WORK IF THERE IS ONLY ONE CLUB WITH AN ACTIVE STATUS
		if ($strContractYear < $year && $intStatus == 1 && $noOfMemberClubs==1) {
			$strContractYear = ($year == 0) ? '' : $year; 
			$dtContractEntered = "$year-$month-$day";
		}
        $strContractNo = (!$strContractNo) ? ''  : $strContractNo;
		$strContractYear = ($strContractYear == 0) ? '' : $strContractYear; 
		my $dtExpiry = _date_selection_dropdown($clubID,$dtContractEntered);
        $dtExpiry = qq[<td>].$dtExpiry.qq[</td>];
        $contractDetailsHTML = qq[<td><input type="text" name="contNo_$clubID" value="$strContractNo" size="5"></td><td><input type="text" name="contYear_$clubID" value="$strContractYear" size="5"></td>$dtExpiry];
        return $contractDetailsHTML;
}

sub getNumberOfMemberClubs {
	my ($db,$memberID)=@_;

	my $st = qq[
		SELECT COUNT(intClubID)
        FROM tblMember_Clubs
        WHERE intMemberID=$memberID
			AND intStatus = 1
    ];
    my $query=$db->prepare($st);
    $query->execute();
	my ($noOfMemberClubs)=$query->fetchrow_array();

	return ($noOfMemberClubs);
}

sub getPrimaryClub {
	my ($db,$memberID)=@_;
	my $st=qq[
		SELECT intClubID 
		FROM tblMember_Clubs
		WHERE intMemberID=$memberID
			AND intPrimaryClub=1
		LIMIT 1
	];
	my $query=$db->prepare($st);
	$query->execute();
	my ($intClubID)=$query->fetchrow_array();
	return $intClubID;
}

sub updatePrimaryClub {
	my ($db, $memberID, $PC, $a)=@_;
	my $st_upd_pc = qq[
		UPDATE 
      tblMember_Clubs
		SET 
      intPrimaryClub = ?
		WHERE 
      intMemberID = $memberID
			AND intClubID = ?
	];
	my $q_up_pc=$db->prepare($st_upd_pc);
  my $st_reset_pc = qq[
    UPDATE
      tblMember_Clubs
    SET
      intPrimaryClub = 0
    WHERE
      intMemberID = $memberID
  ];
	if ($a == 1) {
	  my $q_reset_pc=$db->prepare($st_reset_pc);
		$q_reset_pc->execute();
		$q_up_pc->execute(1,$PC);
	} else {
		$q_up_pc->execute(0,$PC);
	}
	return 1;
}

1;
