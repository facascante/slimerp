#!/usr/bin/perl

#
# $Header: svn://svn/SWM/trunk/web/ajax/aj_search.cgi 9754 2013-10-15 22:31:41Z cgao $
#

use strict;
use warnings;
use lib "..",".","../..";
use CGI qw(param);
use Defs;
use Reg_common;
use Utils;
use Sphinx::Search;
use JSON;
use Data::Dumper;

main();	

sub main	{
	# GET INFO FROM URL
  my $client = param('client') || '';
  my $searchval = param('term') || '';
                                                                                                        
  my %Data=();
  my $target='main.cgi';
  $Data{'target'}=$target;
  my %clientValues = getClient($client);
  $Data{'clientValues'} = \%clientValues;
  my $db=allowedTo(\%Data);
	$Data{'db'} = $db;

	my $currentLevel = $Data{'clientValues'}{'currentLevel'} || 0;
  ($Data{'Realm'}, $Data{'RealmSubType'})=getRealm(\%Data);

  # AUTHENTICATE
	my $output = '';
	if($db)	{
		my %results = ();

		my $sphinx = Sphinx::Search->new;

		$sphinx->SetServer($Defs::Sphinx_Host, $Defs::Sphinx_Port);
		$sphinx->SetLimits(0,1000);

		my $intermediateNodes = {};
		my $assocs_from_node = [];
		if($currentLevel > $Defs::LEVEL_ASSOC)	{
			($intermediateNodes, $assocs_from_node) = getIntermediateNodes(\%Data);
		}
		my $filters = setupFilters(\%Data, $assocs_from_node);

		if($currentLevel > $Defs::LEVEL_MEMBER)	{
			$results{'members'} = search_members(
				\%Data,
				$sphinx,
				$searchval,
				$filters,
				$intermediateNodes,
			);
		}
		if($currentLevel > $Defs::LEVEL_CLUB)	{
			$results{'clubs'} = search_clubs(
				\%Data,
				$sphinx,
				$searchval,
				$filters,
				$intermediateNodes,
			);
		}
		if($currentLevel > $Defs::LEVEL_ASSOC)	{
			$results{'assocs'} = search_assocs(
				\%Data,
				$sphinx,
				$searchval,
				$filters,
				$intermediateNodes,
			);
		}

		my @r = ();
		for my $k (qw(assocs clubs members))	{
			if($results{$k} and scalar(@{$results{$k}}))	{
				for my $r (@{$results{$k}})	{
					push @r, $r;
				}
			}
		}
		$output = to_json(\@r);
	}
	print "Content-type: application/x-javascript\n\n";
	print $output;
}

sub search_members	{
	my (
		$Data,
		$sphinx,
		$searchval,
		$filters,
		$intermediateNodes,
	) = @_;
	$sphinx->ResetFilters();
	$sphinx->SetFilter('intrealmid',[$filters->{'realm'}]);
	$sphinx->SetFilter('intassocID',$filters->{'assoc'}) if $filters->{'assoc'};
	my $results = $sphinx->Query($searchval, 'SWM_Members');
	my @members = ();
	if($results and $results->{'total'})  {
		for my $r (@{$results->{'matches'}})  {
			push @members, $r->{'doc'};
		}
	}
	my @memarray = ();
	if(@members)	{
		my $member_list = join(',',@members);

        my $assoc_list = '';
        $assoc_list = join(',', @{$filters->{'assoc'}}) if($filters->{'assoc'});
		my $assocID = $Data->{'clientValues'}{'assocID'} || 0;
		my $clubID = $Data->{'clientValues'}{'clubID'} || 0;
		$clubID = 0 if $clubID == $Defs::INVALID_ID;
		my $st_from = '';
		elsif($clubID)	{
			$st_from = qq[
				INNER JOIN tblMember_Clubs AS MC
					ON (
						tblMember.intMemberID = MC.intMemberID
						AND MC.intClubID = $clubID
						AND MC.intStatus <> $Defs::RECSTATUS_DELETED
					)
			];	
		}
		$assocID = 0 if $assocID == $Defs::INVALID_ID;
		my $st = qq[
			SELECT 
				tblMember.intMemberID,
				tblMember.strFirstname,
				tblMember.strSurname,
				tblMember.strNationalNum
			FROM
				tblMember
				$st_from
			WHERE tblMember.intMemberID IN ($member_list)
			ORDER BY 
				tblMember.strSurname, 
				tblMember.strFirstname
			LIMIT 10
		];	
		if(!$assocID)	{
            my $assoc_sql ='';
            $assoc_sql = 'AND MA.intAssocID IN ('.$assoc_list.')' if($assoc_list);
			$st = qq[
				SELECT 
					tblMember.intMemberID,
					strFirstname,
					strSurname,
					strNationalNum,
					MA.intAssocID,
					A.strName AS AssocName
				FROM
					tblMember
					INNER JOIN tblMember_Associations AS MA ON (
						tblMember.intMemberID = MA.intMemberID
						AND MA.intRecStatus=1
                        $assoc_sql
					)
					INNER JOIN tblAssoc AS A ON (
						MA.intAssocID = A.intAssocID
					)
				WHERE tblMember.intMemberID IN ($member_list)
				ORDER BY 
					strSurname, 
					strFirstname
				LIMIT 10
			];
		}
		my $q = $Data->{'db'}->prepare($st);
		$q->execute();
		my %origClientValues = %{$Data->{'clientValues'}};

	my $numnotshown = ($results->{'total'} || 0) - 10;
	$numnotshown = 0 if $numnotshown < 0;
		while(my $dref = $q->fetchrow_hashref())	{
			my $link = getSearchLink(
				$Data,
				$Defs::LEVEL_MEMBER,
				'memberID'	,
				$dref->{'intMemberID'},
				$intermediateNodes,
				$assocID || $dref->{'intAssocID'} || 0,
			);						
			my $name = "$dref->{'strSurname'}, $dref->{'strFirstname'}" || '';
			$name .= " #$dref->{'strNationalNum'}" if $dref->{'strNationalNum'};
			$name .= "  ($dref->{'AssocName'})" if $dref->{'AssocName'};
			push @memarray, {
				id => $dref->{'intMemberID'} || next,
				label => $name,
				category => 'Members',
				link => $link,
				numnotshown => $numnotshown,
			};
		}
	}
	return \@memarray;
}
	
sub setupFilters	{
	my ($Data,$assocs_from_node) = @_;

	my $realm = $Data->{'Realm'} || 0;
	my $assocID = $Data->{'clientValues'}{'assocID'} || 0;
	$assocID = 0 if $assocID < 0;
	if($assocID)	{
		$assocID = [$assocID];
	}	
	else	{
		$assocID = $assocs_from_node;
	}
	my $clubID = $Data->{'clientValues'}{'clubID'} || 0;
	$clubID = 0 if $clubID < 0;

	my %filters = (
		realm => $realm,
		assoc => $assocID,
		club => $clubID,
	);

	return \%filters;
}


sub search_clubs	{
	my (
		$Data,
		$sphinx,
		$searchval,
		$filters,
		$intermediateNodes,
	) = @_;
	$sphinx->ResetFilters();
	$sphinx->SetFilter('intassocID',$filters->{'assoc'}) if $filters->{'assoc'};
	my $results = $sphinx->Query($searchval, 'SWM_Clubs');
	my @matchlist = ();
	if($results and $results->{'total'})  {
		for my $r (@{$results->{'matches'}})  {
			push @matchlist, $r->{'doc'};
		}
	}
	my @dataarray = ();
	if(@matchlist)	{
		my $id_list = join(',',@matchlist);
		my $st = qq[
			SELECT 
				intClubID,
				strName
			FROM
				tblClub
			WHERE intClubID IN ($id_list)
			ORDER BY 
				strName 
			LIMIT 10
		];
		my $assocID = $Data->{'clientValues'}{'assocID'} || 0;
		$assocID = 0 if $assocID == $Defs::INVALID_ID;
		if(!$assocID)	{
			$st = qq[
				SELECT 
					tblClub.intClubID,
					tblClub.strName,
					A.strName AS AssocName,
					A.intAssocID
				FROM
					tblClub
						INNER JOIN tblAssoc_Clubs AS AC ON 
							tblClub.intClubID = AC.intClubID
						INNER JOIN tblAssoc AS A  ON
							AC.intAssocID = A.intAssocID	
				WHERE tblClub.intClubID IN ($id_list)
				ORDER BY 
					tblClub.strName , A.strName
				LIMIT 10
			];
		}
		my $q = $Data->{'db'}->prepare($st);
		$q->execute();
		my $numnotshown = ($results->{'total'} || 0) - 10;
		$numnotshown = 0 if $numnotshown < 0;
		while(my $dref = $q->fetchrow_hashref())	{
			my $link = getSearchLink(
				$Data,
				$Defs::LEVEL_CLUB,
				'clubID'	,
				$dref->{'intClubID'},
				$intermediateNodes,
				$assocID || $dref->{'intAssocID'} || 0,
			);
			my $name = $dref->{'strName'} || '';
			$name .= "  ($dref->{'AssocName'})" if $dref->{'AssocName'};
			push @dataarray, {
				id => $dref->{'intClubID'} || next,
				label => $name,
				category => 'Clubs',
				link => $link,
				numnotshown => $numnotshown,
			};
		}
	}
	return \@dataarray;
}

sub search_assocs {
	my (
		$Data,
		$sphinx,
		$searchval,
		$filters,
		$intermediateNodes,
	) = @_;
	$sphinx->ResetFilters();
	$sphinx->SetFilter('intassocID',$filters->{'assoc'}) if $filters->{'assoc'};
	my $results = $sphinx->Query($searchval, 'SWM_Assocs');
	my @matchlist = ();
	if($results and $results->{'total'})  {
		for my $r (@{$results->{'matches'}})  {
			push @matchlist, $r->{'doc'};
		}
	}
	my @dataarray = ();
	my $numnotshown = ($results->{'total'} || 0) - 10;
	$numnotshown = 0 if $numnotshown < 0;
	if(@matchlist)	{
		my $id_list = join(',',@matchlist);
		my $st = qq[
			SELECT 
				intAssocID,
				strName
			FROM
				tblAssoc
			WHERE intAssocID IN ($id_list)
			ORDER BY 
				strName
			LIMIT 10
		];
		my $q = $Data->{'db'}->prepare($st);
		$q->execute();
		while(my $dref = $q->fetchrow_hashref())	{
			my $link = getSearchLink(
				$Data,
				$Defs::LEVEL_ASSOC,
				'assocID'	,
				$dref->{'intAssocID'},
				$intermediateNodes,
				$dref->{'intAssocID'},
			);
			push @dataarray, {
				id => $dref->{'intAssocID'} || next,
				label => $dref->{'strName'} || '',
				category => 'Associations',
				link => $link,
				numnotshown => $numnotshown,
			};
		}
	}
	return \@dataarray;
}


sub getSearchLink	{
	my (
		$Data,
		$level,
		$field,
		$value,
		$intermediateNodes,
		$assocID,
	) = @_;

  my %tempClientValues = %{$Data->{'clientValues'}};
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

	my $structlevel = $level || 0;
	my $structvalue = $value || 0;
	if($level <  $Defs::LEVEL_ASSOC)	{
		$structlevel = $Defs::LEVEL_ASSOC;
		$structvalue = $assocID || 0;
	}
	for my $k (keys %{$intermediateNodes->{$structlevel}{$structvalue}})	{
		if(
			!$tempClientValues{$k} 
			or ($tempClientValues{$k} and $tempClientValues{$k} == $Defs::INVALID_ID )
		)	{
			$tempClientValues{$k} = $intermediateNodes->{$structlevel}{$structvalue}{$k} || 0;
		}
	}
	$tempClientValues{$field} = $value;
	$tempClientValues{currentLevel} = $level;
	$tempClientValues{assocID} = $assocID || 0;
	my $tempClient = setClient(\%tempClientValues);

	my $act = $actions{$level};
	my $url = "$Data->{'target'}?client=$tempClient&amp;a=$act";

	return $url;
}

sub getIntermediateNodes {
	my(
		$Data, 
	) = @_;

	my $currentLevel = $Data->{'clientValues'}{'currentLevel'} || 0;
	my $currentID = getID($Data->{'clientValues'}) || 0;
	return undef if !$currentLevel;
	return undef if !$currentID;

	my $field = '';
	$field = 'int100_ID' if $currentLevel == $Defs::LEVEL_NATIONAL;
	$field = 'int30_ID' if $currentLevel == $Defs::LEVEL_STATE;
	$field = 'int20_ID' if $currentLevel == $Defs::LEVEL_REGION;
	$field = 'int10_ID' if $currentLevel == $Defs::LEVEL_ZONE;
	my $st = qq[
		SELECT 
			int100_ID,
			int30_ID,
			int20_ID,
			int10_ID,
			intAssocID
		FROM tblTempNodeStructure
		WHERE
			$field = ?
	];
	my $q = $Data->{'db'}->prepare($st);
	$q->execute(
		$currentID,
	);
	
	my %intermediateNodes = ();
	my @assocs = ();
	while(my $dref = $q->fetchrow_hashref())	{
		my $assocID = $dref->{'intAssocID'} || 0;
		my $zoneID = $dref->{'int10_ID'} || 0;
		my $regionID = $dref->{'int20_ID'} || 0;
		my $stateID = $dref->{'int30_ID'} || 0;
		my $nationalID = $dref->{'int100_ID'} || 0;
		if($currentLevel <= $Defs::LEVEL_NATIONAL)	{
			$nationalID = 0;
		}
		if($currentLevel <= $Defs::LEVEL_STATE)	{
			$stateID = 0;
		}
		if($currentLevel <= $Defs::LEVEL_REGION)	{
			$regionID = 0;
		}
		if($currentLevel <= $Defs::LEVEL_ZONE)	{
			$zoneID = 0;
		}
		$intermediateNodes{$Defs::LEVEL_STATE}{$stateID} = {
			natID => $nationalID || 0,	
		};
		$intermediateNodes{$Defs::LEVEL_REGION}{$regionID} = {
			natID => $nationalID || 0,	
			stateID => $stateID || 0,	
		};
		$intermediateNodes{$Defs::LEVEL_ZONE}{$zoneID} = {
			natID => $nationalID || 0,	
			stateID => $stateID || 0,	
			regionID => $regionID || 0,	
		};
		$intermediateNodes{$Defs::LEVEL_ASSOC}{$assocID} = {
			natID => $nationalID || 0,	
			stateID => $stateID || 0,	
			regionID => $regionID || 0,	
			zoneID => $zoneID || 0,	
		};
		push @assocs, $assocID;
	}
	return (\%intermediateNodes, \@assocs);
}
