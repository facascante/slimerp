#
# $Header: svn://svn/SWM/trunk/web/SearchLevels.pm 8251 2013-04-08 09:00:53Z rlee $
#

package SearchLevels;

require Exporter;
@ISA =  qw(Exporter);
@EXPORT = qw(getLevelQueryStuff);
@EXPORT_OK = qw(getLevelQueryStuff);

use strict;
use lib '..';

use Defs;
use Utils;

sub getLevelQueryStuff	{

	my($searchlevel, $searchentity, $Data, $stats, $notmemberteam, $otheroptions)=@_;

	my $clientValues_ref=$Data->{'clientValues'};
	$stats||=0; #if stats is being reported or actual data
	$notmemberteam||=0; #if team/comp tables should be included in member join
	#Setup values for search levels
	my $from_levels='';
	my $where_levels='';
	my $select_levels='';

	if ($searchlevel > $Defs::LEVEL_INTERNATIONAL and $searchentity <= $Defs::LEVEL_INTERNATIONAL) { #INT ZON level
		$from_levels.=' INNER JOIN ' if $from_levels;
		$where_levels.=' AND ' if $where_levels;
		$select_levels.=',' if $select_levels;

		my $da =getAccessSQL('tblInternational', $stats, $Data) || '';
		$from_levels.=qq[ tblNode AS tblInternational INNER JOIN tblNodeLinks AS NL_I ON (NL_I.intChildNodeID=tblInternational.intNodeID AND tblInternational.intTypeID=$Defs::LEVEL_INTERNATIONAL $da)];
		$select_levels.=qq[ tblInternational.intNodeID AS intInternationalID, tblInternational.strName AS strInternationalName, tblInternational.intStatusID as InternationalStatus ];
	}
	if ($searchlevel > $Defs::LEVEL_INTREGION and $searchentity <= $Defs::LEVEL_INTREGION) { #INT ZON level
		$from_levels.=' INNER JOIN ' if $from_levels;
		$where_levels.=' AND ' if $where_levels;
		$select_levels.=',' if $select_levels;

		my $da =getAccessSQL('tblIntRegion', $stats, $Data) || '';
		$from_levels.=qq[ tblNode AS tblIntRegion INNER JOIN tblNodeLinks AS NL_IR ON (NL_IR.intChildNodeID=tblIntRegion.intNodeID AND tblIntRegion.intTypeID=$Defs::LEVEL_INTREGION $da)];
		$where_levels.=qq[ NL_IR.intParentNodeID=tblInternational.intNodeID ];
		$select_levels.=qq[ tblIntRegion.intNodeID AS intIntRegionID, tblIntRegion.strName AS strIntRegionName, tblIntRegion.intStatusID as IntRegionStatus];
	}
	if ($searchlevel > $Defs::LEVEL_INTZONE and $searchentity <= $Defs::LEVEL_INTZONE) { #INT ZON level
		$from_levels.=' INNER JOIN ' if $from_levels;
		$where_levels.=' AND ' if $where_levels;
		$select_levels.=',' if $select_levels;
		my $da =getAccessSQL('tblIntZone', $stats, $Data) || '';
		$from_levels.=qq[ tblNode AS tblIntZone INNER JOIN tblNodeLinks AS NL_IZ ON (NL_IZ.intChildNodeID=tblIntZone.intNodeID AND tblIntZone.intTypeID=$Defs::LEVEL_INTZONE $da)];
		$where_levels.=qq[ NL_IZ.intParentNodeID=tblIntRegion.intNodeID ];
		$select_levels.=qq[ tblIntZone.intNodeID AS intIntZoneID, tblIntZone.strName AS strIntZoneName , tblIntZone.intStatusID as IntZoneStatus];
	}
	if ($searchlevel > $Defs::LEVEL_NATIONAL and $searchentity <= $Defs::LEVEL_NATIONAL) { #INT ZON level
		$from_levels.=' INNER JOIN ' if $from_levels;
		$where_levels.=' AND ' if $where_levels;
		$select_levels.=',' if $select_levels;
		my $da =getAccessSQL('tblNational', $stats, $Data) || '';
		$from_levels.=qq[ tblNode AS tblNational INNER JOIN tblNodeLinks AS NL_N ON (NL_N.intChildNodeID=tblNational.intNodeID AND tblNational.intTypeID=$Defs::LEVEL_NATIONAL $da)];
		$where_levels.=qq[ NL_N.intParentNodeID=tblIntZone.intNodeID ];
		$select_levels.=qq[ tblNational.intNodeID AS intNationalID, tblNational.strName AS strNationalName , tblNational.intStatusID as NationalStatus];
	}
	if ($searchlevel > $Defs::LEVEL_STATE and $searchentity <= $Defs::LEVEL_STATE) { #National level
		$from_levels.=' INNER JOIN ' if $from_levels;
		$where_levels.=' AND ' if $where_levels;
		$select_levels.=',' if $select_levels;
		my $da =getAccessSQL('tblState', $stats, $Data) || '';
		$from_levels.=qq[ tblNode AS tblState INNER JOIN tblNodeLinks AS NL_S ON (NL_S.intChildNodeID=tblState.intNodeID AND tblState.intTypeID=$Defs::LEVEL_STATE $da)];
		$where_levels.=qq[ NL_S.intParentNodeID=tblNational.intNodeID ];

		$select_levels.=qq[ tblState.intNodeID AS intStateID, tblState.strName AS strStateName, tblState.intStatusID as StateStatus ];
	}
	if ($searchlevel > $Defs::LEVEL_REGION and $searchentity <= $Defs::LEVEL_REGION) { #National level
		$from_levels.=' INNER JOIN ' if $from_levels;
		$where_levels.=' AND ' if $where_levels;
		$select_levels.=',' if $select_levels;
		my $da =getAccessSQL('tblRegion', $stats, $Data) || '';
		$from_levels.=qq[ tblNode AS tblRegion INNER JOIN tblNodeLinks AS NL_R ON (NL_R.intChildNodeID=tblRegion.intNodeID AND tblRegion.intTypeID=$Defs::LEVEL_REGION $da)];
		$where_levels.=qq[ NL_R.intParentNodeID=tblState.intNodeID ];
		$select_levels.=qq[ tblRegion.intNodeID AS intRegionID, tblRegion.strName AS strRegionName, tblRegion.intStatusID as RegionStatus ];
	}

	if ($searchlevel > $Defs::LEVEL_ZONE and $searchentity <= $Defs::LEVEL_ZONE) { #Region Level and above
		$from_levels.=' INNER JOIN ' if $from_levels;
		$select_levels.=',' if $select_levels;
		$where_levels.=' AND ' if $where_levels;
		my $da =getAccessSQL('tblZone', $stats, $Data) || '';
		$from_levels.=qq[ tblNode AS tblZone INNER JOIN tblNodeLinks AS NL_Z ON (NL_Z.intChildNodeID=tblZone.intNodeID AND tblZone.intTypeID=$Defs::LEVEL_ZONE $da)];
		$select_levels.=qq[ tblZone.intNodeID AS intZoneID, tblZone.strName AS strZoneName, tblZone.intStatusID as ZoneStatus ];
		$where_levels.=qq[ NL_Z.intParentNodeID=tblRegion.intNodeID ];
	}
	if ($searchlevel > $Defs::LEVEL_ASSOC and $searchentity <=$Defs::LEVEL_ASSOC) { #Zone Level and above
		$from_levels.=' INNER JOIN ' if $from_levels;
		$select_levels.=',' if $select_levels;
		$where_levels.=' AND ' if $where_levels;
		my $da =getAccessSQL('tblAssoc', $stats, $Data) || '';
		$from_levels.=qq[ tblAssoc INNER JOIN tblAssoc_Node ON (tblAssoc_Node.intAssocID=tblAssoc.intAssocID $da)];
		$select_levels.=qq[ tblAssoc.intAssocID, tblAssoc.strName AS strAssocName ];
		$where_levels.=qq[ tblAssoc_Node.intNodeID = tblZone.intNodeID AND tblAssoc.intRecStatus <> $Defs::RECSTATUS_DELETED];
	}
	if ($searchlevel > $Defs::LEVEL_CLUB and $searchentity == $Defs::LEVEL_CLUB) { #Assoc Level and above
		$from_levels.=' INNER JOIN ' if $from_levels;
		$select_levels.=',' if $select_levels;
		$where_levels.=' AND ' if $where_levels;

		$from_levels.=qq[ tblClub INNER JOIN tblAssoc_Clubs ON (tblClub.intClubID=tblAssoc_Clubs.intClubID)];
		$select_levels.=qq[ tblClub.intClubID, tblClub.strName AS strClubName ];
		$where_levels.=qq[ tblAssoc.intAssocID=tblAssoc_Clubs.intAssocID AND tblClub.intRecStatus <> $Defs::RECSTATUS_DELETED];
	}

	if ($searchlevel > $Defs::LEVEL_MEMBER and $searchentity == $Defs::LEVEL_MEMBER) { #Assoc Level and above
		$from_levels.=' INNER JOIN ' if $from_levels;
		$where_levels.=' AND ' if $where_levels;
		my $team_JOIN=  ($clientValues_ref->{teamID} and  $clientValues_ref->{teamID} != $Defs::INVALID_ID ) ? 'INNER' : 'LEFT';
		if($notmemberteam)	{ $from_levels.=qq[ tblMember INNER JOIN tblMember_Associations ON (tblMember.intMemberID=tblMember_Associations.intMemberID AND tblMember_Associations.intRecStatus<> $Defs::RECSTATUS_DELETED) ] }
		else	{
			$from_levels.=qq[ tblMember INNER JOIN tblMember_Associations ON (tblMember.intMemberID=tblMember_Associations.intMemberID AND tblMember_Associations.intRecStatus <> $Defs::RECSTATUS_DELETED) $team_JOIN JOIN tblMember_Teams ON tblMember.intMemberID=tblMember_Teams.intMemberID $team_JOIN JOIN tblTeam ON (tblTeam.intTeamID=tblMember_Teams.intTeamID AND tblTeam.intAssocID=tblMember_Associations.intAssocID AND tblMember_Teams.intStatus <> $Defs::RECSTATUS_DELETED) LEFT JOIN tblComp_Teams ON tblComp_Teams.intTeamID=tblTeam.intTeamID LEFT JOIN tblAssoc_Comp ON (tblAssoc_Comp.intCompID=tblComp_Teams.intCompID AND tblAssoc_Comp.intAssocID=tblMember_Associations.intAssocID AND tblMember_Teams.intCompID=tblAssoc_Comp.intCompID)];
			$where_levels.=qq[  (tblMember_Teams.intCompID=tblAssoc_Comp.intCompID OR tblMember_Teams.intCompID =0 or tblMember_Teams.intCompID IS NULL OR tblAssoc_Comp.intCompID IS NULL)];
       	 	$where_levels.=' AND ' if $where_levels;
        	}
        	$where_levels.=qq[ tblAssoc.intAssocID=tblMember_Associations.intAssocID AND tblMember.intStatus <> $Defs::RECSTATUS_DELETED];
	}

	$select_levels=','.$select_levels if $select_levels;


	my $current_where='';
	my $current_from='';
  my $current_level=$clientValues_ref->{currentLevel};
	if($current_level== $Defs::LEVEL_ASSOC)	{
		$current_where=qq[tblAssoc.intAssocID= $clientValues_ref->{assocID} ];
		$from_levels = qq[ tblAssoc INNER JOIN $from_levels];
		#$current_from=qq[INNER JOIN tblAssoc];
	}
	elsif($current_level== $Defs::LEVEL_ZONE)	{
		$current_where=qq[tblZone.intNodeID= $clientValues_ref->{zoneID} ];
		$current_from=qq[ INNER JOIN tblNode AS tblZone];
	}
	elsif($current_level== $Defs::LEVEL_REGION)	{
		$current_where=qq[tblRegion.intNodeID= $clientValues_ref->{regionID} ];
		$current_from=qq[ INNER JOIN tblNode AS tblRegion];
	}
	elsif($current_level== $Defs::LEVEL_STATE)	{
		$current_where=qq[tblState.intNodeID= $clientValues_ref->{stateID} ];
		$current_from=qq[ INNER JOIN tblNode AS tblState];
	}
	elsif($current_level== $Defs::LEVEL_NATIONAL)	{
		$current_where=qq[tblNational.intNodeID= $clientValues_ref->{natID} ];
		$current_from=qq[ INNER JOIN tblNode AS tblNational];
	}
	elsif($current_level== $Defs::LEVEL_INTZONE)	{
		$current_where=qq[tblIntZone.intNodeID= $clientValues_ref->{intzonID} ];
		$current_from=qq[ INNER JOIN tblNode AS tblIntZone];
	}
	elsif($current_level== $Defs::LEVEL_INTREGION)	{
		$current_where=qq[tblIntRegion.intNodeID= $clientValues_ref->{intregID} ];
		$current_from=qq[ INNER JOIN tblNode AS tblIntRegion];
	}
	elsif($current_level== $Defs::LEVEL_INTERNATIONAL)	{
		$current_where=qq[tblInternational.intNodeID= $clientValues_ref->{interID} ];
		$current_from=qq[ INNER JOIN tblNode AS tblInternational];
	}
	elsif($current_level== $Defs::LEVEL_TOP)	{
		$current_where=qq[NL_I.intParentNodeID=0 ];
	}
	elsif($current_level== $Defs::LEVEL_CLUB)	{
		$current_where=qq[tblClub.intClubID = $clientValues_ref->{clubID} AND tblAssoc_Clubs.intAssocID=tblAssoc.intAssocID ];
		$current_from=qq[ INNER JOIN tblAssoc INNER JOIN tblClub INNER JOIN tblAssoc_Clubs ON (tblAssoc_Clubs.intClubID=tblClub.intClubID)];
		if($searchentity == $Defs::LEVEL_MEMBER) {

      if ($otheroptions->{'ShowInactiveMembersInClubSearch'}) {
			  $current_where.=qq[ AND tblMember_Clubs.intMemberID=tblMember.intMemberID AND tblMember_Clubs.intClubID=tblClub.intClubID AND tblMember_Clubs.intStatus<>$Defs::RECSTATUS_DELETED ];
      }
      else {
			  $current_where.=qq[ AND tblMember_Clubs.intMemberID=tblMember.intMemberID AND tblMember_Clubs.intClubID=tblClub.intClubID AND tblMember_Clubs.intStatus=$Defs::RECSTATUS_ACTIVE ];
      }
			$current_from.=qq[ INNER JOIN tblMember_Clubs];
		}
	}
	elsif($current_level== $Defs::LEVEL_MEMBER)	{
		$current_from=qq[tblMember];
		$current_where=qq[tblMember.intMemberID= $clientValues_ref->{memberID} ];
	}
	if($clientValues_ref->{assocID} and $clientValues_ref->{assocID} !=$Defs::INVALID_ID  and $from_levels=~/tblMember/) {
		$where_levels="AND $where_levels" if $where_levels;
		$where_levels=qq[tblMember_Associations.intAssocID= $clientValues_ref->{assocID} $where_levels];
	}
	$current_where='AND '.$current_where if $current_where;

	return ( $from_levels, $where_levels, $select_levels, $current_from, $current_where);

}


sub getAccessSQL	{
	my($accesstable, $stats, $Data)=@_;
	my $access_level= $stats ? $Defs::DATA_ACCESS_STATS : $Defs::DATA_ACCESS_READONLY;
	my $pb= exists $Data->{'SystemConfig'}{'ParentBodyAccess'} ? $Data->{'SystemConfig'}{'ParentBodyAccess'} : '';
	my $fname= $pb ne '' ? $pb : "$accesstable.intDataAccess";
	return qq[ AND $fname >= $access_level ];
}
