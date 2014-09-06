package InstanceOf;
require Exporter;
@ISA =  qw(Exporter);
@EXPORT = qw(getInstanceOf);
@EXPORT_OK = qw(getInstanceOf);

use lib "..",".";

use strict;
use Defs;

use PersonObj;
use EntityObj;

sub getInstanceOf	{
	my (
		$Data,
		$type,
		$idIN,
	) = @_;

	my $clientValues_ref=$Data->{'clientValues'};
	my $cache = $Data->{'cache'};
	my $obj = undef;
	$idIN ||= 0;
	my $db = $Data->{'db'};
	$type = number_to_level($type) if $type =~/^\d+$/;

	if($type eq 'club')	{
		my $id = $idIN || $clientValues_ref->{clubID} || $Defs::INVALID_ID;
		if($id != $Defs::INVALID_ID)	{
			$obj = $cache->get('swm',"ClubObj-$id") if $cache;
			if(!$obj)	{
                $obj = new EntityObj(
                    db => $db,
                    ID => $id,
				);
				return undef if !$obj;
				$obj->load();
				$obj->clearDB();
				$cache->set(
					'swm',
					"ClubObj-$id",
					$obj, 
					'',
					60*60*5, # 5hours
				) if $cache;
			}
		}
	}
	elsif($type eq 'person')	{
		my $id = $idIN || $clientValues_ref->{personID} || $Defs::INVALID_ID;
		if($id != $Defs::INVALID_ID)	{
			$obj = $cache->get('swm',"PersonObj-$id") if $cache;
			if(!$obj)	{
				$obj = new PersonObj(
					db => $db,
					ID => $id,
				);
				return undef if !$obj;
				$obj->load();
				$obj->clearDB();
				$cache->set(
					'swm',
					"PersonObj-$id",
					$obj, 
                    '',
					60*60*5, # 5hours
				) if $cache;
			}
		}
	}
	elsif($type eq 'entity')	{
		return undef if !$idIN;
		my $id = $idIN || $Defs::INVALID_ID;
		return undef if $id == $Defs::INVALID_ID;

		$obj = $cache->get('swm',"EntityObj-$id") if $cache;
			if(!$obj)	{
			$obj = new EntityObj(
				db => $db,
				ID => $id,
			);
			return undef if !$obj;
			$obj->load();
			$obj->clearDB();
			$cache->set(
				'swm',
				"EntityObj-$id",
				$obj, 
				'',
				60*60*5, # 5hours
			) if $cache;
		}
	}
	elsif(
		$type eq 'zone'
		or $type eq 'region'
		or $type eq 'state'
		or $type eq 'national'
		or $type eq 'intzone'
		or $type eq 'intregion'
		or $type eq 'international'
	)	{
		my $id = 0;
		$id = $clientValues_ref->{zoneID} if $type eq 'zone';
		$id = $clientValues_ref->{regionID} if $type eq 'region';
		$id = $clientValues_ref->{stateID} if $type eq 'state';
		$id = $clientValues_ref->{natID} if $type eq 'national';
		$id = $clientValues_ref->{intzonID} if $type eq 'intzone';
		$id = $clientValues_ref->{intregID} if $type eq 'intregion';
		$id = $clientValues_ref->{interID} if $type eq 'international';
		if(
			!$id
			#and $assocID
			and (
				$type eq 'zone'
				or $type eq 'region'
				or $type eq 'state'
				or $type eq 'national'
			)
		)	{
			#my $assoc_struct = $cache->get('swm',"AssocStructure-$assocID") if $cache;
			#if(!$assoc_struct)	{
				#my $st = qq[
					#SELECT
						#intRealmID,
						#int100_ID,
						#int30_ID,
						#int20_ID,
						#int10_ID,
						#intAssocID
					#FROM tblTempEntityStructure
					#WHERE intAssocID = ?
				#];
				#my $q = $db->prepare($st);
				#$q->execute($assocID);
				#my $dref = $q->fetchrow_hashref();
				#$q->finish();
#
				#$cache->set(
					#'swm',
					#"AssocStructure-$assocID",
					#$dref, 
					#'',
					#60*60*5, # 5hours
				#) if $cache;
				#$id = $dref->{'int10_ID'} if $type eq 'zone';
				#$id = $dref->{'int20_ID'} if $type eq 'region';
				#$id = $dref->{'int30_ID'} if $type eq 'state';
				#$id = $dref->{'int100_ID'} if $type eq 'national';
			#}
		} 

		return undef if !$id;
		return undef if $id == $Defs::INVALID_ID;

		$obj = $cache->get('swm',"EntityObj-$id") if $cache;
			if(!$obj)	{
			$obj = new EntityObj(
				db => $db,
				ID => $id,
			);
			return undef if !$obj;
			$obj->load();
			$obj->clearDB();
			$cache->set(
				'swm',
				"EntityObj-$id",
				$obj, 
				'',
				60*60*5, # 5hours
			) if $cache;
		}
	}

	$obj->setDB($db) if $obj;
	return $obj;
}

sub number_to_level	{
	my ($level) = @_;

	my %matrix = (
		$Defs::LEVEL_PERSON => 'person',
		$Defs::LEVEL_CLUB => 'club',
		$Defs::LEVEL_ZONE => 'zone',
		$Defs::LEVEL_REGION => 'region',
		$Defs::LEVEL_STATE => 'state',
		$Defs::LEVEL_NATIONAL => 'national',
		$Defs::LEVEL_INTZONE => 'intzone',
		$Defs::LEVEL_INTREGION => 'intregion',
		$Defs::LEVEL_INTERNATIONAL => 'international',
	);
	return $matrix{$level} || '';
}

1;

