#
# $Header: svn://svn/SWM/trunk/web/Search.pm 11524 2014-05-09 05:01:35Z ppascoe $
#

package Search;

require Exporter;
@ISA =  qw(Exporter);
@EXPORT = qw(handleSearch);
@EXPORT_OK = qw(handleSearch);

use strict;
use lib '..';

use Defs;
use CGI qw(param unescape escape);
use Reg_common;
use Utils;
use SearchLevels;
use FormHelpers;
use DeQuote;
use HTMLForm qw(_date_selection_dropdown);
use FieldLabels;

sub handleSearch {
 my ($action, $Data, $client ) = @_;
	my $clientValues = $Data->{'clientValues'};
	my $db = $Data->{db};
	my $target = $Data->{'target'};
	$client ||= setClient($clientValues);
	my $resultHTML = '';
	my $pageTitle = '';
	if ($action eq 'SEARCH_F') {
		$resultHTML = displaySearchScreen($Data, $client);
		$pageTitle = $Data->{'lang'}->txt('Search');
	}
	elsif ($action eq 'SEARCH_R') {
		$resultHTML = doSearch($Data, $client);  
		$pageTitle = $Data->{'lang'}->txt('Search Results');
	}
  elsif ($action eq 'SEARCH_NA') {
		$resultHTML = doNationalAccredSearch($Data, $client) if($Data->{'SystemConfig'}{'NationalAccreditation'});  
		$resultHTML = doAccredSearch($Data, $client) if(!$Data->{'SystemConfig'}{'NationalAccreditation'});  
		$pageTitle = $Data->{'lang'}->txt('National Accreditation Search Results');
  }
	$pageTitle ||= $Data->{'lang'}->txt('Search Results');
	return ($resultHTML, $pageTitle);
}

sub doSearch {
  my($Data, $client) = @_;
	my $db=$Data->{'db'} || undef;
	my $target=$Data->{'target'};
	my $clientValues_ref=$Data->{'clientValues'};
	my $limit=200;	
  $client = unescape($client);
  my $found = 0;
  my $searchentity = param('searchentity') || $Defs::LEVEL_MEMBER;
	my $searchstart='CURRENT';
  my $searchvalues = param('searchvalues')  || '';
  my $searchlevel = ($searchstart eq 'CURRENT') ? $clientValues_ref->{currentLevel} : $clientValues_ref->{authLevel};
  if ($searchlevel > $clientValues_ref->{authLevel}) {
    errlog('Caught attempt to search higher level');
    $searchlevel = $clientValues_ref->{authLevel};
  }
  my $searchFoundText = $Data->{'lang'}->txt('Search found the following results');
  my $resultHTML = qq[<span>$searchFoundText:</span><BR><BR>\n];
  my %otheroptions = ($Data->{'SystemConfig'}{'ShowInactiveMembersInClubSearch'})
      ? (ShowInactiveMembersInClubSearch=>1) 
      : ();
	my ($from_levels, $where_levels, $select_levels, $current_from, $current_where)=getLevelQueryStuff($searchlevel, $searchentity, $Data, 0, 0, \%otheroptions);

  $where_levels=' AND '.$where_levels if $where_levels;
	$searchvalues=~s/\*/%/g;
	if($searchvalues!~/%/)	{
		$searchvalues='%'.$searchvalues.'%';
	}
	deQuote($db, \$searchvalues);
	my $statement='';
 		if ($searchentity == $Defs::LEVEL_INTERNATIONAL) {
      $statement = qq[
				SELECT DISTINCT tblInternational.intNodeID AS internationalID, tblInternational.strName AS internationalName $select_levels
				FROM $from_levels $current_from
				WHERE tblInternational.strName LIKE $searchvalues $where_levels $current_where
				ORDER BY tblInternational.strName
				LIMIT $limit
			];
	 		$resultHTML.=search_query($db,$statement, $clientValues_ref, $Defs::LEVEL_INTERNATIONAL, 'internationalName', 'internationalID', $target,\$found, $Data);
    } 		
		elsif ($searchentity == $Defs::LEVEL_INTREGION) {
      $statement=qq[
				SELECT DISTINCT tblIntRegion.intNodeID AS intregionID, tblIntRegion.strName AS intregionName $select_levels
				FROM $from_levels $current_from
				WHERE tblIntRegion.strName LIKE $searchvalues $where_levels $current_where
				ORDER BY tblIntRegion.strName
				LIMIT $limit
			];
	 		$resultHTML.=search_query($db,$statement, $clientValues_ref, $Defs::LEVEL_INTREGION, 'intregionName', 'intregionID', $target,\$found, $Data);
    } 
		elsif ($searchentity == $Defs::LEVEL_INTZONE) {
      $statement=qq[
				SELECT DISTINCT tblIntZone.intNodeID AS intzoneID, tblIntZone.strName AS intzoneName $select_levels
				FROM $from_levels $current_from
				WHERE tblIntZone.strName LIKE $searchvalues $where_levels $current_where
				ORDER BY tblIntZone.strName
				LIMIT $limit
			];
	 		$resultHTML.=search_query($db,$statement, $clientValues_ref, $Defs::LEVEL_INTZONE, 'intzoneName', 'intzoneID', $target,\$found, $Data);
    } 
 		elsif ($searchentity == $Defs::LEVEL_NATIONAL) {
      $statement=qq[
				SELECT DISTINCT tblNational.intNodeID AS nationalID, tblNational.strName AS nationalName $select_levels
				FROM $from_levels $current_from
				WHERE tblNational.strName LIKE $searchvalues $where_levels $current_where
				ORDER BY tblNational.strName
				LIMIT $limit
			];
	 		$resultHTML.=search_query($db,$statement, $clientValues_ref, $Defs::LEVEL_NATIONAL, 'nationalName', 'nationalID', $target,\$found, $Data);
    } 
   elsif ($searchentity == $Defs::LEVEL_STATE) {
      $statement=qq[
				SELECT DISTINCT tblState.intNodeID AS stateID, tblState.strName AS stateName $select_levels
				FROM $from_levels $current_from
				WHERE tblState.strName LIKE $searchvalues $where_levels $current_where
				ORDER BY tblState.strName
				LIMIT $limit
			];
	 		$resultHTML.=search_query($db,$statement, $clientValues_ref, $Defs::LEVEL_STATE, 'stateName', 'stateID', $target,\$found, $Data);
    }     
		elsif ($searchentity == $Defs::LEVEL_REGION) {
      $statement=qq[
				SELECT DISTINCT tblRegion.intNodeID AS regionID, tblRegion.strName AS regionName $select_levels
				FROM $from_levels $current_from
				WHERE tblRegion.strName LIKE $searchvalues $where_levels $current_where
				ORDER BY tblRegion.strName
				LIMIT $limit
			];
	 		$resultHTML.=search_query($db,$statement, $clientValues_ref, $Defs::LEVEL_REGION, 'regionName', 'regionID', $target,\$found, $Data);
    } 
    elsif ($searchentity == $Defs::LEVEL_ZONE) {
      $statement=qq[
				SELECT DISTINCT tblZone.intNodeID AS zoneID, tblZone.strName AS zoneName $select_levels
				FROM $from_levels $current_from
				WHERE tblZone.strName LIKE $searchvalues $where_levels $current_where
				ORDER BY tblZone.strName
				LIMIT $limit
			];
	 		$resultHTML.=search_query($db,$statement, $clientValues_ref, $Defs::LEVEL_ZONE, 'zoneName', 'zoneID', $target,\$found, $Data);
    } 
		elsif ($searchentity == $Defs::LEVEL_ASSOC) {
      $statement=qq[
				SELECT DISTINCT tblAssoc.intAssocID AS assocID, tblAssoc.strName AS assocName $select_levels
				FROM $from_levels $current_from
				WHERE tblAssoc.strName LIKE $searchvalues $where_levels $current_where
				ORDER BY tblAssoc.strName
				LIMIT $limit
			];
	 		$resultHTML.=search_query($db,$statement, $clientValues_ref, $Defs::LEVEL_ASSOC, 'assocName', 'assocID', $target,\$found, $Data);
    } 
		elsif ($searchentity == $Defs::LEVEL_CLUB) {
			$statement=qq[
				SELECT DISTINCT tblClub.intClubID AS clubID, tblClub.strName AS clubName $select_levels
				FROM $from_levels $current_from
				WHERE tblClub.strName LIKE $searchvalues $where_levels $current_where
				ORDER BY tblClub.strName
				LIMIT $limit
			];
	 		$resultHTML.=search_query($db,$statement, $clientValues_ref, $Defs::LEVEL_CLUB, 'clubName', 'clubID', $target,\$found, $Data);
    } 
		elsif ($searchentity == $Defs::LEVEL_MEMBER) {
			my $wherefields='';
			$searchvalues||='%';
			my $mnum = param('mnum') || '';
			my $idnum = param('idnum') || '';
			my $accredID= param('accredID') || '';
			my $natnum = param('natnum') || '';
			my $dob_mon= param('d_dob1_mon') || '';
			my $surname= param('surname') || '';
			my $firstname= param('firstname') || '';
			my $error='';
      if ($dob_mon) { 
				my $dob_day=param('d_dob1_day') || '';
				my $dob_year=param('d_dob1_year') || '';
				use Date::Calc qw(check_date);
				my $valid_date= check_date($dob_year,$dob_mon,$dob_day) || 0;;
				$error=$Data->{'lang'}->txt('You have entered an Invalid Date of birth') if !$valid_date;
				$wherefields.=" AND dtDOB='$dob_year-$dob_mon-$dob_day' ";
			}
      if ($mnum) { 
				deQuote($db, \$mnum);
				$wherefields.=" AND strMemberNo like $mnum";
			}
      if ($idnum) {
        deQuote($db, \$idnum);
        $wherefields.=" AND strIdentNum like $idnum";
      }
      if ($natnum) { 
				deQuote($db, \$natnum);
				$natnum = qq['$natnum'] if $natnum and $natnum !~ /^\'/;
				$wherefields.=" AND strNationalNum like $natnum";
			}
			my $accred_from='';
			my $accred_select='';
			my $club_from='';
			my $club_select='';
			my $club_where='';
			my $clubGroupBy = '';
			my $club_orderBy='';
			if($Data->{'SystemConfig'}{'ClubInSearch'})	{
				$club_from = qq[ LEFT JOIN tblAssoc_Clubs AS AC ON (AC.intAssocID = tblMember_Associations.intAssocID) ];
				$club_from .=qq[ LEFT JOIN tblMember_Clubs AS MC ON (tblMember_Associations.intMemberID=MC.intMemberID AND MC.intStatus <> $Defs::RECSTATUS_DELETED AND  AC.intClubID = MC.intClubID) LEFT JOIN tblClub AS C ON (MC.intClubID=C.intClubID ) ];
				$club_select=qq[ , C.strName as strClubName, MAX(MC.intStatus) as MCStatus,  IF(MSClub.intMemberSeasonID > 0, 1, 0) as SeasonClubStatus, SClub.strSeasonName as SeasonClubName ];
				$clubGroupBy= qq[ GROUP  BY tblMember.intMemberID, C.intClubID];
				$club_where=qq[  AND (AC.intAssocID=tblAssoc.intAssocID OR AC.intAssocID IS NULL) ] ;
				$club_orderBy = qq[, MCStatus DESC];
				my $MStablename = "tblMember_Seasons_$Data->{'Realm'}";
                		$club_from .= qq[
                        		LEFT JOIN $MStablename as MSClub ON (
						MSClub.intMemberID = tblMember.intMemberID
			        		AND MSClub.intSeasonID = intCurrentSeasonID
        					AND MSClub.intAssocID = tblMember_Associations.intAssocID
        					AND MSClub.intClubID = MC.intClubID
                                		AND MSClub.intMSRecStatus = 1
					)
					LEFT JOIN tblSeasons as SClub ON (SClub.intSeasonID = intCurrentSeasonID)
                		];
			}
      if ($accredID) { 
				deQuote($db, \$accredID);
				$wherefields.=" AND ES.intAccredCatID = $accredID "; 
			}
			my $namewhere='';
			if($surname)	{
				deQuote($db, \$surname);
				$namewhere.=' AND ' if $namewhere;
				$namewhere.=" strSurname = $surname ";
			}
			if($firstname)	{
				deQuote($db, \$firstname);
				$namewhere.=' AND ' if $namewhere;
				$namewhere.=" strFirstname = $firstname ";
			}
			$namewhere=qq[concat(strFirstname, " ", strSurname) LIKE $searchvalues ] if !$namewhere;

 		  my $MStablename = "tblMember_Seasons_$Data->{'Realm'}";
      my $season_JOIN = qq[
        LEFT JOIN $MStablename as MS ON (
				MS.intMemberID = tblMember.intMemberID
			        AND MS.intSeasonID = intCurrentSeasonID
        			AND MS.intAssocID = tblMember_Associations.intAssocID
        			AND MS.intClubID = 0
                                AND MS.intMSRecStatus = 1
			  )
			  LEFT JOIN tblSeasons as S ON (S.intSeasonID = intCurrentSeasonID)
      ];
      $statement=qq[
        SELECT 
          DISTINCT 
          strNationalNum, 
          IF(MS.intMemberSeasonID > 0, 1, 0) as SeasonStatus, 
          S.strSeasonName as SeasonName, 
          tblMember.intMemberID AS memberID, 
          concat(strFirstname, " ", strSurname) AS memberName,  
          DATE_FORMAT(dtDOB,'%d/%m/%Y') AS dtDOB, 
          tblMember_Associations.intRecStatus AS MemberStatus  
          $accred_select 
          $club_select 
          $select_levels
        FROM 
          $from_levels 
          $current_from
				  $accred_from 
          $club_from
		      $season_JOIN
        WHERE  
          $namewhere
					AND tblMember_Associations.intRecStatus<>$Defs::RECSTATUS_DELETED
					AND tblMember.intRealmID=$Data->{'Realm'}
					$wherefields
          $where_levels 
          $current_where 
          $club_where
				$clubGroupBy
				ORDER BY 
          strSurname, 
          strFirstname, 
          dtDOB DESC 
          $club_orderBy
				LIMIT $limit
      ];
	 		$resultHTML.=search_query($db,$statement, $clientValues_ref, $Defs::LEVEL_MEMBER, 'memberName', 'memberID', $target,\$found, $Data) if !$error;
			$resultHTML=$error if $error;
    }
 	$resultHTML.=qq[<br><br>]; 
    if (!$found) {
        $resultHTML = qq[<p style="height:10px;">].$Data->{'lang'}->txt('No entries match your Search criteria. Please try again').'</p>';
	    $resultHTML .= qq[<div class="pageHeading">].$Data->{'lang'}->txt('Search Again').'</div>';
	    $resultHTML .= displaySearchScreen($Data, escape($client));
    }
    elsif($found==$limit)	{
        $resultHTML .= '<p>'.$Data->{'lang'}->txt('The list is limited to the first [_1] entries.', $limit).'</p>';
    }
  
  return $resultHTML;
}


# DISPLAY SEARCH CRITERIA

sub displaySearchScreen {
  my($Data, $client) = @_;
  my $searchEntityText = $Data->{'lang'}->txt('Search Entity');
  my $dateOfBirthText = $Data->{'lang'}->txt('Date of Birth');
  $client = unescape($client);
	my $currentLevel=$Data->{'clientValues'}{'currentLevel'} || $Defs::LEVEL_NONE;
	my @SearchOptions=(
		$Defs::LEVEL_TOP,
		$Defs::LEVEL_INTERNATIONAL,
		$Defs::LEVEL_INTREGION,
		$Defs::LEVEL_INTZONE,
		$Defs::LEVEL_NATIONAL,
		$Defs::LEVEL_STATE,
		$Defs::LEVEL_REGION,
		$Defs::LEVEL_ZONE,
		$Defs::LEVEL_ASSOC,
		$Defs::LEVEL_CLUB,
		$Defs::LEVEL_MEMBER,
	);
	my $options='';
	my @options=();
	for my $l (sort reverse @SearchOptions)	{
		if($currentLevel > $l and $Data->{'LevelNames'}{$l})	{
			next if ($l==$Defs::LEVEL_CLUB and $Data->{'SystemConfig'}{'NoClubs'});
			push @options, $l;
		}
	}
	for my $l (@options)	{
			$options.=qq[<option value="$l">$Data->{'LevelNames'}{$l}</option>\n];
	}
	my $searchentity='';
	if(scalar(@options) > 1)	{
		$searchentity=qq[
		<tr>
			<td class="label">$searchEntityText</td>
			<td class="value"><select name="searchentity" size="1" onchange="displaysearchfields(this.value);">
				$options
			</select></td>
		</tr>
		];
	}
	else	{
		$searchentity=qq[<input type="hidden" name="searchentity" value="$options[0]">];
	}
  my $natnumname=$Data->{'SystemConfig'}{'NationalNumName'} || 'National Number';
	my $searchmembernum = (defined $Data->{'Permissions'}{'Member'}{'strMemberNo'} and $Data->{'Permissions'}{'Member'}{'strMemberNo'} ne 'Hidden') ? qq[
    <tr>
      <td class="label">Member Number</td>
      <td class="value"><input type="text" name="mnum"></td>
    </tr>
	] : '';
	#my $searchnatnum=(defined $Data->{'SystemConfig'}{'GenNumField'}) ? qq[
	my $searchnatnum=((defined $Data->{'Permissions'}{'Member'}{'strNationalNum'} and $Data->{'Permissions'}{'Member'}{'strNationalNum'} ne 'Hidden') or (defined $Data->{'SystemConfig'}{'GenNumField'} and $Data->{'clientValues'}{'currentLevel'} >= $Defs::LEVEL_ASSOC))?  qq[
		<tr>
			<td class="label">$natnumname</td>
			<td class="value"><input type="text" name="natnum"></td>
		</tr>
	]  : '';
	my $dob_box=_date_selection_dropdown('dob1','','','');

	my $search_dob=($Data->{'Permissions'}{'Member'}{'dtDOB'} ne 'Hidden')?  qq[
		<tr>
			<td class="label">$dateOfBirthText</td>
			<td class="value">$dob_box</td>
		</tr>
	] : '';
	my $accred_category='';

  my $identification_number = ($Data->{'SystemConfig'}{'SystemForIdentNo'}) ? qq[
    <tr>
      <td class="label">Identification Number</td>
      <td class="value"><input type="text" name="idnum"></td>
    </tr>
  ] : '';



    my $lang = $Data->{'lang'};
    my $searchUsing = $lang->txt('Search using the options below');
    my $searchingFrom = $lang->getSearchingFrom($Data->{'LevelNames'}{$currentLevel});
    my $searchLabel = $lang->txt('Search');
    my $nameOrPart = $lang->txt(qq[Name (or part of name)]);
    my $OR = $lang->txt('OR');
    my $familyNameText = $lang->txt('Family Name');
    my $firstNameText = $lang->txt('First Name');

  my $resultHTML = qq[
<form action="$Data->{'target'}" method="post">
 <script language="Javascript" type="text/javascript">

		function displaysearchfields (val)	{
			if(val == $Defs::LEVEL_MEMBER)	{
				jQuery('#searchonfield').show();
			}
			else	{
				jQuery('#searchonfield').hide();
			}
		}
 </script>

<table>
	<tbody>
		<tr>
			<td colspan="2">$searchUsing<br><br><i>$searchingFrom</i><br><br></td>
		</tr>
		$searchentity
		<tr>
			<td class="label">$nameOrPart</td>
			<td class="value"><input type="text" name="searchvalues"></td>
		</tr>
	</tbody>
	<tbody id="searchonfield" >
		<tr>
			<td class="label">$OR </td>
		</tr>
		<tr>
			<td class="label">$familyNameText</td>
			<td class="value"><input type="text" name="surname"></td>
			<td class="label">$firstNameText</td>
			<td class="value"><input type="text" name="firstname"></td>
		</tr>
		$search_dob
		$searchnatnum
		$searchmembernum
    $identification_number
		$accred_category
	</tbody>
	</table>
<br>
	<input type="submit" value="$searchLabel">
    <input type="hidden" name="a" value="SEARCH_R">
    <input type="hidden" name="client" value="$client">
</form>
	];
  $resultHTML = getNationalAccredSearchScreen($Data, $resultHTML) if ($Data->{'SystemConfig'}{'AccredExpose'}); 
	
  return $resultHTML;
}


# SEARCH QUERY

sub search_query	{
	my ($db,$statement, $clientValues_ref, $level, $nameField, $IDField, $target, $found_ref, $Data)=@_;
	my $reportdb = connectDB('reporting');
	$reportdb ||= $db;
	my $query = $reportdb->prepare($statement);
	$query->execute;
	my $resultHTML =  '';
	$resultHTML .= qq[<p>Current $Data->{'LevelNames'}{$Defs::LEVEL_ASSOC} Season in bold</p><br>] if ($Data->{'SystemConfig'}{'AllowSeasons'} and $Data->{'SystemConfig'}{'SearchUseSeasons'});
	$resultHTML .= qq[<table class="listTable">];
	my %origClientValues = %{$clientValues_ref};
	my %actions=(
		$Defs::LEVEL_MEMBER => 'M_HOME',
		$Defs::LEVEL_CLUB => 'C_HOME',
		$Defs::LEVEL_ASSOC => 'A_HOME',
		$Defs::LEVEL_ZONE => 'N_HOME',
		$Defs::LEVEL_REGION => 'N_HOME',
		$Defs::LEVEL_STATE => 'N_HOME',
		$Defs::LEVEL_NATIONAL => 'N_HOME',
		$Defs::LEVEL_INTZONE => 'N_HOME',
		$Defs::LEVEL_INTREGION => 'N_HOME',
		$Defs::LEVEL_INTERNATIONAL => 'N_HOME',
	);
	my %displayed=();
	while (my $dref= $query->fetchrow_hashref()) {
		$$found_ref++;
		my %tempClientValues = %origClientValues;
		next if (exists $displayed{$dref->{memberID}} and ! $dref->{strClubName} and $Data->{'SystemConfig'}{'ClubInSearch'});
		$displayed{$dref->{memberID}} = 1;
		$tempClientValues{clubID}=$dref->{intClubID} if $dref->{intClubID};
		$tempClientValues{assocID}=$dref->{intAssocID} if $dref->{intAssocID};
		$tempClientValues{zoneID}=$dref->{intZoneID} if $dref->{ZoneStatus};
		$tempClientValues{regionID}=$dref->{intRegionID} if $dref->{RegionStatus};
		$tempClientValues{stateID}=$dref->{intStateID} if $dref->{StateStatus};
		$tempClientValues{natID}=$dref->{intNationalID} if $dref->{NationalStatus};
		$tempClientValues{intzonID}=$dref->{intIntZoneID} if $dref->{IntZoneStatus};
		$tempClientValues{intregID}=$dref->{intIntRegionID} if $dref->{IntRegionStatus};
		$tempClientValues{interID}=$dref->{intInternationalID} if $dref->{InternationalStatus};
		$tempClientValues{$IDField} = $dref->{$IDField} if $dref->{$IDField};
		$tempClientValues{$nameField} = $dref->{$nameField} if $dref->{$nameField};
		$tempClientValues{currentLevel} = $level;
		my $tempClient = setClient(\%tempClientValues);
		my $otherdetails='';
		$otherdetails.=" $dref->{strAssocName} " if $dref->{strAssocName} and $level != $Defs::LEVEL_ASSOC;
		my $regions=($dref->{strZoneName} and  $level != $Defs::LEVEL_ZONE  and $dref->{'ZoneStatus'} != $Defs::NODE_HIDE )? $dref->{strZoneName} : '';
		$regions.=' - ' if $regions and $dref->{strRegionName};
		$regions.=$dref->{strRegionName} if($dref->{strRegionName} and $level != $Defs::LEVEL_REGION and $dref->{'RegionStatus'} != $Defs::NODE_HIDE);
		$otherdetails.=" ($regions) " if $regions;
		$otherdetails='&nbsp;'.$otherdetails || '';
		my $tdclass= $$found_ref %2 ==0 ? 'class="rowshade" ' : '';
		my $act=$actions{$level};
		$dref->{'accred'}||='';
		my $mcStatus = '';
		$mcStatus = $dref->{'MCStatus'} == 1 ? "Active in $Data->{'LevelNames'}{$Defs::LEVEL_CLUB}" : "Inactive in $Data->{'LevelNames'}{$Defs::LEVEL_CLUB}";
		my $club_status='';
		my $club_column='';
		my $club_seasonStatus='';
		if ($Data->{'SystemConfig'}{'ClubInSearch'})	{
			$club_status= qq[ <td $tdclass >$mcStatus</td>];
			$club_column= qq[ <td $tdclass >$dref->{'strClubName'}</td>];
			if ($Data->{'SystemConfig'}{'AllowSeasons'} and $Data->{'SystemConfig'}{'SearchUseSeasons'})	{
				$club_seasonStatus=$dref->{'SeasonClubStatus'} == $Defs::RECSTATUS_ACTIVE ? qq[Participating in <b>$dref->{'SeasonClubName'}</b>]: qq[Not-Participating in <b>$dref->{'SeasonClubName'}</b>];
				$club_seasonStatus = qq[<td $tdclass >$club_seasonStatus</td>];
		  }
		}
		my $natNum_column=qq[ <td $tdclass >$dref->{'strNationalNum'}</td>] if ($dref->{'strNationalNum'});
		my $dob_column= ((defined $Data->{'Permissions'}{'Member'}{'dtDOB'} and $Data->{'Permissions'}{'Member'}{'dtDOB'} ne 'Hidden') or !defined $Data->{'Permissions'}{'Member'}{'dtDOB'})?  qq[ <td $tdclass >$dref->{'dtDOB'}</td>] : '';
		my $actStatus='';
        if (exists $dref->{'MemberStatus'}) {
		    $actStatus=$dref->{'MemberStatus'} == $Defs::RECSTATUS_ACTIVE ? qq[Active in $Data->{'LevelNames'}{$Defs::LEVEL_ASSOC}] : qq[Inactive in $Data->{'LevelNames'}{$Defs::LEVEL_ASSOC}];
        }
		my $seasonStatus='';
		if ($Data->{'SystemConfig'}{'AllowSeasons'} and $Data->{'SystemConfig'}{'SearchUseSeasons'})	{
			$seasonStatus=$dref->{'SeasonStatus'} == $Defs::RECSTATUS_ACTIVE ? qq[Participating in <b>$dref->{'SeasonName'}</b>]: qq[Not-Participating in <b>$dref->{'SeasonName'}</b>];
			$seasonStatus = qq[<td $tdclass >$seasonStatus</td>];
		}
		$resultHTML .= qq[
		<tr>
			<td $tdclass ><a href="$target?client=$tempClient&amp;a=$act">$tempClientValues{$nameField}</a></td>
			<td $tdclass >$actStatus</td>
			$seasonStatus
			$natNum_column
			$dob_column
			$club_status
			$club_seasonStatus
			$club_column
			<td $tdclass >$otherdetails</td>
		</tr>
		];
	}
	$resultHTML .= qq[</table>];
	$query->finish;
	return $resultHTML;
}

sub getNationalAccredSearchScreen {
  my ($Data, $searchHTML) = @_;
  return $searchHTML unless($Data->{'SystemConfig'}{'AccredExpose'});
  my $resultHTML = '';
  my $taboptions = '';
  my $client = $Data->{'client'};
  my $currentLevel=$Data->{'clientValues'}{'currentLevel'} || $Defs::LEVEL_NONE;
  my $lang = $Data->{'lang'};
  my $searchUsing = $lang->txt('Search using the options below');
  my $searchLabel = $lang->txt('Search');
  my $nameOrPart = $lang->txt(qq[Name (or part of name)]);
  my $OR = $lang->txt('OR');
  my $familyNameText = $lang->txt('Family Name');
  my $firstNameText = $lang->txt('First Name');
  my $natnumname=$Data->{'SystemConfig'}{'NationalNumName'} || 'National Number';
  my $searchmembernum = '';
  if (defined $Data->{'Permissions'}{'Member'}{'strNationalNum'} and $Data->{'Permissions'}{'Member'}{'strNationalNum'} ne 'Hidden') {
     $searchmembernum = qq[
        <tbody id="searchonfield">
        <tr>
          <td class="label">$OR </td>
        </tr>
        <tr>
          <td class="label">$natnumname</td>
          <td class="value"><input type="text" name="natnum"></td>
        </tr>
        </tbody>
    ];
  }
  $resultHTML .= qq[
    <script type="text/javascript">
			jQuery(function()	{
				jQuery('#searchtabs').tabs();
			});
		</script>
    <div id="searchtabs" style="float:left;width:90%;">
			<ul>
				<li><a href="#search_dat">].$lang->txt('Search').qq[</a></li>
				<li><a href="#accred_dat">].$lang->txt('National Accreditation Search').qq[</a></li>
			</ul>
		<div id="search_dat">$searchHTML</div>
    <div id="accred_dat" style="padding:10px;">
    <form action="$Data->{'target'}" method="post">
      <table>
        <tbody>
        <tr>
          <td colspan="2">$searchUsing<br><br></td>
        </tr>
        <tr>
          <td class="label">$familyNameText</td>
          <td class="value"><input type="text" name="surname"></td>
          <td class="label">$firstNameText</td>
          <td class="value"><input type="text" name="firstname"></td>
        </tr>
        </tbody>
        <tbody id="searchonfield">
        <tr>
          <td class="label">$OR </td>
        </tr>
        <tr>
          <td class="label">$nameOrPart</td>
          <td class="value"><input type="text" name="searchvalues"></td>
        </tr>
        </tbody>
        $searchmembernum
      </table>
      <br>
      <input type="submit" value="Search">
      <input type="hidden" name="a" value="SEARCH_NA">
      <input type="hidden" name="client" value="$client">
    </form>
    </div>
	</div>
  ];
  return $resultHTML;
}

sub doAccredSearch {
  my ($Data, $client) = @_;
  my $partname = param('searchvalues') || '';
  my $firstname = param('firstname') || '';
  my $surname = param('surname') || '';
  my $natnum = param('natnum') || '';
  my @assocs = split /\|/, $Data->{'SystemConfig'}{'AccredExpose'};
  my $assoc_in = join(',',@assocs);
  unless ($partname or $firstname or $surname or $natnum) {
    return $Data->{'lang'}->txt('No values entered');
  }
  my $FieldLabels=getFieldLabels($Data, $Defs::LEVEL_MEMBER);
  my $partname_IN = $partname || '';
  $partname = '%' . $partname . '%' if $partname_IN;
  deQuote($Data->{'db'}, \$partname);
  my $where  = ($partname_IN) ? qq[AND concat(strFirstname, " ", strSurname) LIKE $partname ] : '';
  unless ($where) {
    if($surname)  {
      deQuote($Data->{'db'}, \$surname);
      $where .= " AND strSurname = $surname ";
    }
    if($firstname)  {
        deQuote($Data->{'db'}, \$firstname);
        $where.=" AND strFirstname = $firstname ";
    }
  }
  unless ($where) {
    if ($natnum) {
      deQuote($Data->{'db'}, \$natnum);
      $natnum = qq['$natnum'] if $natnum and $natnum !~ /^\'/;
      $where .= " AND strNationalNum like $natnum";
    }
  }
  my $st = qq[
    SELECT
      M.intMemberID,
      M.strFirstname,
      M.strSurname,
      M.dtDOB,
      M.strNationalNum,
      M.intDefaulter,
      MT.intTypeID,
      MT.intSubTypeID,
      MT.intActive,
      MT.intInt1,
      MT.intInt2,
      DC1.strName AS intInt1_name,
      DC2.strName AS intInt2_name,
      DC5.strName AS intInt5_name,
      DC6.strName AS intInt6_name,
      DATE_FORMAT(MT.dtDate1,'%d/%m/%Y') AS dtDate1,
      DATE_FORMAT(MT.dtDate2,'%d/%m/%Y') AS dtDate2,
      DATE_FORMAT(MT.dtDate3,'%d/%m/%Y') AS dtDate3,
      DATE_FORMAT(M.dtDOB,'%d/%m/%Y') AS dtDOB,
      intInt7
    FROM
      tblMember AS M
      INNER JOIN tblMember_Types AS MT ON (M.intMemberID = MT.intMemberID)
      LEFT JOIN tblDefCodes AS DC1 ON (DC1.intCodeID = MT.intInt1)
      LEFT JOIN tblDefCodes AS DC2 ON (DC2.intCodeID = MT.intInt2)
      LEFT JOIN tblDefCodes AS DC5 ON (DC5.intCodeID = MT.intInt5)
      LEFT JOIN tblDefCodes AS DC6 ON (DC6.intCodeID = MT.intInt6)
    WHERE
      M.intRealmID = $Data->{'Realm'}
      AND MT.intAssocID IN ($assoc_in)
      AND MT.intRecStatus <> -1
      $where
    ORDER BY
      MT.intTypeID,
      MT.intSubTypeID,
      M.strSurname,
      M.strFirstname
  ];
  my $q = $Data->{'db'}->prepare($st) or query_error($st);
  $q->execute();
  my $resultHTML = '';
  my %deactivated = ();
  my $hide_start_date = $Data->{'SystemConfig'}{'HIDE_start_date_on_accred_search'} || 0;
  while (my $href = $q->fetchrow_hashref()) {
    if ($Defs::MEMBER_TYPE_COACH == $href->{'intTypeID'} and $href->{'intSubTypeID'} == 0 and $href->{'intInt1'} == 1) {
      $deactivated{$href->{'intMemberID'}} = 1;
    }
    if ($Defs::MEMBER_TYPE_UMPIRE == $href->{'intTypeID'} and $href->{'intSubTypeID'} == 0 and $href->{'intInt2'} == 1) {
      $deactivated{$href->{'intMemberID'}} = 1;
    }
    next unless (($Defs::MEMBER_TYPE_COACH == $href->{'intTypeID'} or $Defs::MEMBER_TYPE_UMPIRE == $href->{'intTypeID'} or ($Data->{'Realm'} == 3 and $Defs::MEMBER_TYPE_OFFICIAL == $href->{'intTypeID'})) and $href->{'intSubTypeID'} == 1);
    my $accred_type = '';
    $accred_type=$Data->{'SystemConfig'}{'TYPE_NAME_'.$Defs::MEMBER_TYPE_COACH} || $Defs::memberTypeName{$Defs::MEMBER_TYPE_COACH} if ($Defs::MEMBER_TYPE_COACH==$href->{'intTypeID'});
    $accred_type=$Data->{'SystemConfig'}{'TYPE_NAME_'.$Defs::MEMBER_TYPE_UMPIRE} || $Defs::memberTypeName{$Defs::MEMBER_TYPE_UMPIRE} if ($Defs::MEMBER_TYPE_UMPIRE==$href->{'intTypeID'});
    $accred_type=$Data->{'SystemConfig'}{'TYPE_NAME_'.$Defs::MEMBER_TYPE_OFFICIAL} || $Defs::memberTypeName{$Defs::MEMBER_TYPE_OFFICIAL} if ($Defs::MEMBER_TYPE_OFFICIAL==$href->{'intTypeID'} and $Data->{'Realm'} == 3);
    my $re_accred = ($href->{'intInt7'} == 1) ? '*' : '';
    $deactivated{$href->{'intMemberID'}} ||= 0;
    my $deregsitered_css = ($deactivated{$href->{'intMemberID'}} == 1) ? qq[style='color:red;'] : '';

    $href->{'strNationalNum'} ||= '';
    $href->{'strFirstname'} ||= '';
    $href->{'strSurname'} ||= '';
    $href->{'intInt1_name'} ||= '';
    $href->{'intInt2_name'} ||= '';
    $href->{'intInt5_name'} ||= '';
    $href->{'intInt6_name'} ||= '';

    $resultHTML .= qq[
      <tr>
        <td>$re_accred</td>
        <td $deregsitered_css>$href->{'strNationalNum'}</td>
        <td $deregsitered_css>$accred_type</td>
        <td $deregsitered_css>$href->{'strFirstname'}</td>
        <td $deregsitered_css>$href->{'strSurname'}</td>
        <td $deregsitered_css>$href->{'intInt1_name'}</td>
        <td $deregsitered_css>$href->{'intInt2_name'}</td>
        <td $deregsitered_css>$href->{'intInt5_name'}</td>
        <td $deregsitered_css>$href->{'intInt6_name'}</td>
    ];
    $resultHTML .= qq[
        <td $deregsitered_css>$href->{'dtDate1'}</td>
    ] if ($hide_start_date != 1);
    $resultHTML .= qq[
        <td $deregsitered_css>$href->{'dtDate2'}</td>
        <td $deregsitered_css>$href->{'dtDate3'}</td>
      </tr>
    ];
  }
  my $national_num_head = $Data->{'SystemConfig'}{'NationalNumName'} || $Data->{'lang'}->txt('National Number');
  my $type_head = $FieldLabels->{'Accred.intInt1'} || $Data->{'lang'}->txt('Type');
  my $level_head = $FieldLabels->{'Accred.intInt2'} || $Data->{'lang'}->txt('Level');
  my $accred_prov_level = $FieldLabels->{'Accred.intInt5'} || $Data->{'lang'}->txt('Accred Provider');
  my $result_head = $FieldLabels->{'Accred.intInt6'} || $Data->{'lang'}->txt('Accreditation Result');
  my $start_date_head = $FieldLabels->{'Accred.dtDate1'} || $Data->{'lang'}->txt('Start Date');
  my $end_date_head = $FieldLabels->{'Accred.dtDate2'} || $Data->{'lang'}->txt('End Date');
  my $app_date_head = $Data->{'SystemConfig'}{'ACCRED_ApplicationDate'} || $FieldLabels->{'Accred.dtDate3'};
  if ($resultHTML) {
    my $start_date_header = ($hide_start_date) ? '' : qq[<th>$start_date_head</th>];
    my $accred_type_header = $Data->{'lang'}->txt('Accred Type');
    my $firstname_header = $Data->{'lang'}->txt('First Name');
    my $surname_header = $Data->{'lang'}->txt('Surname');
    $resultHTML = qq[
      <table width="100%" class="listTable">
        <tr>
          <th></th>
          <th>$national_num_head</th>
          <th>$accred_type_header</th>
          <th>$firstname_header</th>
          <th>$surname_header</th>
          <th>$type_head</th>
          <th>$level_head</th>
          <th>$accred_prov_level</th>
          <th>$result_head</th>
          $start_date_header
          <th>$end_date_head</th>
          <th>$app_date_head</th>
        </tr>
        $resultHTML
      </table>
    ];
  }
  $resultHTML ||= $Data->{'lang'}->txt('No results found.');
  return $resultHTML;
}

sub doNationalAccredSearch {
  my ($Data, $client) = @_;
  my $partname = param('searchvalues') || '';
  my $firstname = param('firstname') || '';
  my $surname = param('surname') || '';
  my $natnum = param('natnum') || '';
  my @assocs = split /\|/, $Data->{'SystemConfig'}{'AccredExpose'};
  my $assoc_in = join(',',@assocs);
  unless ($partname or $firstname or $surname or $natnum) {
    return $Data->{'lang'}->txt('No values entered');
  }
  my $FieldLabels=getFieldLabels($Data, $Defs::LEVEL_MEMBER);
  my $partname_IN = $partname || '';
  $partname = '%' . $partname . '%' if $partname_IN;
  deQuote($Data->{'db'}, \$partname);
  my $where  = ($partname_IN) ? qq[AND concat(strFirstname, " ", strSurname) LIKE $partname ] : '';
  unless ($where) {
    if($surname)  {
      deQuote($Data->{'db'}, \$surname);
      $where .= " AND strSurname = $surname ";
    }
    if($firstname)  {
        deQuote($Data->{'db'}, \$firstname);
        $where.=" AND strFirstname = $firstname ";
    }
  }
  unless ($where) {
    if ($natnum) {
      deQuote($Data->{'db'}, \$natnum);
      $natnum = qq['$natnum'] if $natnum and $natnum !~ /^\'/;
      $where .= " AND strNationalNum like $natnum";
    }
  }
  my $st = qq[
    SELECT
      M.intMemberID,
      M.strFirstname,
      M.strSurname,
      M.dtDOB,
      M.strNationalNum,
      M.intDefaulter,
      A.strCourseNumber,
	TYPE.strName as strType,
      Q.strName as strLevel,
      PROVIDER.strName as strProvider,
      STATUS.strName as strStatus,
      DATE_FORMAT(A.dtStart,'%d/%m/%Y') as dtStart,
      DATE_FORMAT(A.dtExpiry,'%d/%m/%Y') as dtExpiry,
      DATE_FORMAT(A.dtApplication,'%d/%m/%Y') as dtApplication,
      DATE_FORMAT(M.dtDOB,'%d/%m/%Y') AS dtDOB
    FROM
      tblMember AS M
      INNER JOIN tblAccreditation AS A ON (M.intMemberID = A.intMemberID)
      INNER JOIN tblQualification AS Q ON (Q.intQualificationID = A.intQualificationID)
      LEFT JOIN tblDefCodes AS PROVIDER ON (PROVIDER.intCodeID = A.intProvider)
      LEFT JOIN tblDefCodes AS STATUS ON (STATUS.intCodeID = A.intStatus)
      LEFT JOIN tblDefCodes AS TYPE ON (TYPE.intCodeID = Q.intType)
    WHERE
      M.intRealmID = $Data->{'Realm'}
	 AND A.intRecStatus <> $Defs::RECSTATUS_DELETED
	 AND M.intStatus <> $Defs::MEMBERSTATUS_DELETED
	$where
    ORDER BY
      M.strSurname,
      M.strFirstname
  ];
  my $q = $Data->{'db'}->prepare($st) or query_error($st);
  $q->execute();
  my $resultHTML = '';
  my %deactivated = ();
  my $hide_start_date = $Data->{'SystemConfig'}{'HIDE_start_date_on_accred_search'} || 0;
  while (my $href = $q->fetchrow_hashref()) {
    my $accred_type = '';
    my $re_accred = ($href->{'intInt7'} == 1) ? '*' : '';
    $deactivated{$href->{'intMemberID'}} ||= 0;
    my $deregsitered_css = ($deactivated{$href->{'intMemberID'}} == 1) ? qq[style='color:red;'] : '';

    $href->{'strNationalNum'} ||= '';
    $href->{'strFirstname'} ||= '';
    $href->{'strSurname'} ||= '';
    $href->{'intInt1_name'} ||= ''; #type
    $href->{'intInt2_name'} ||= '';#level
    $href->{'intInt5_name'} ||= '';#provider
    $href->{'intInt6_name'} ||= '';#result
    $href->{'dtApplication'} = '' if($href->{'dtApplication'} eq '00/00/0000');
    $resultHTML .= qq[
      <tr>
        <td>$re_accred</td>
        <td $deregsitered_css>$href->{'strNationalNum'}</td>
        <td $deregsitered_css>$href->{'strType'}</td>
        <td $deregsitered_css>$href->{'strFirstname'}</td>
        <td $deregsitered_css>$href->{'strSurname'}</td>
        <td $deregsitered_css>$href->{'strLevel'}</td>
        <td $deregsitered_css>$href->{'strProvider'}</td>
        <td $deregsitered_css>$href->{'strStatus'}</td>
    ];
    $resultHTML .= qq[
        <td $deregsitered_css>$href->{'dtStart'}</td>
    ] if ($hide_start_date != 1);
    $resultHTML .= qq[
        <td $deregsitered_css>$href->{'dtExpiry'}</td>
        <td $deregsitered_css>$href->{'dtApplication'}</td>
      </tr>
    ];
  }
  my $national_num_head = $Data->{'SystemConfig'}{'NationalNumName'} || $Data->{'lang'}->txt('National Number');
  my $type_head = $FieldLabels->{'Accred.intInt1'} || $Data->{'lang'}->txt('Type');
  my $level_head = $FieldLabels->{'Accred.intInt2'} || $Data->{'lang'}->txt('Level');
  my $accred_prov_level = $FieldLabels->{'Accred.intInt5'} || $Data->{'lang'}->txt('Accred Provider');
  my $result_head = $FieldLabels->{'Accred.intInt6'} || $Data->{'lang'}->txt('Accreditation Result');
  my $start_date_head = $FieldLabels->{'Accred.dtDate1'} || $Data->{'lang'}->txt('Start Date');
  my $end_date_head = $FieldLabels->{'Accred.dtDate2'} || $Data->{'lang'}->txt('End Date');
  my $app_date_head = $Data->{'SystemConfig'}{'ACCRED_ApplicationDate'} || $FieldLabels->{'Accred.dtDate3'};
  if ($resultHTML) {
    my $start_date_header = ($hide_start_date) ? '' : qq[<th>$start_date_head</th>];
    my $accred_type_header = $Data->{'lang'}->txt('Accred Type');
    my $firstname_header = $Data->{'lang'}->txt('First Name');
    my $surname_header = $Data->{'lang'}->txt('Surname');
    $resultHTML = qq[
      <table width="100%" class="listTable">
        <tr>
          <th></th>
          <th>$national_num_head</th>
          <th>$accred_type_header</th>
          <th>$firstname_header</th>
          <th>$surname_header</th>
          <th>$level_head</th>
          <th>$accred_prov_level</th>
          <th>$result_head</th>
          $start_date_header
          <th>$end_date_head</th>
          <th>$app_date_head</th>
        </tr>
        $resultHTML
      </table>
    ];
  }
  $resultHTML ||= $Data->{'lang'}->txt('No results found.');
  return $resultHTML;
}

1;
