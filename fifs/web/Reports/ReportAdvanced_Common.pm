#
# $Header: svn://svn/SWM/trunk/web/Reports/ReportAdvanced_Common.pm 11607 2014-05-20 01:12:36Z cgao $
#

package ReportAdvanced_Common;
require Exporter;
@ISA =  qw(Exporter);
@EXPORT = qw(getCommonValues showMultiEntitlements);
@EXPORT_OK = qw(getCommonValues showMultiEntitlements);

use strict;

use lib '.', 'comp',"..","../..";
use Reg_common;
use Defs;
use Utils;
use ConfigOptions;
use CustomFields;
use Countries;
use FieldLabels;
use FormHelpers;
use ClubCharacteristics;
use Log;


sub getCommonValues {
	my($Data, $options)=@_;

	return undef if !keys %{$options};

	my $clientValues_ref=$Data->{'clientValues'};

	my %optvalues = ();
	my $db=$Data->{'db'};
	if($options->{'CustomFields'})	{
		$optvalues{'CustomFields'}=getCustomFieldNames($Data) || undef;
	}

	if($options->{'DefCodes'})	{
		my $aID=getAssocID($clientValues_ref) || 0;
		my %Codes=();

		$aID=0 if $aID==-1;
		my $statement=qq[
			SELECT *
			FROM tblDefCodes
      			WHERE intRealmID=$Data->{'Realm'}
        			AND (intAssocID = $aID OR intAssocID = 0)
				AND intRecStatus<>$Defs::RECSTATUS_DELETED
		];
		my $query = $db->prepare($statement) or query_error($statement);
		$query->execute or query_error($statement);
		while (my $dref = $query->fetchrow_hashref() ) {
			$Codes{$dref->{'intType'}}{$dref->{'intCodeID'}}=$dref->{strName};
		}
		$optvalues{'DefCodes'} = \%Codes;
	}

	if($options->{'SubRealms'})	{
		my %AssocTypes=();
		my $statement=qq[
			SELECT intSubTypeID, strSubTypeName
			FROM tblRealmSubTypes
			WHERE intRealmID = ?
		];
		my $query = $db->prepare($statement);
		$query->execute($Data->{'Realm'});
		while (my $dref = $query->fetchrow_hashref() ) {
			$AssocTypes{$dref->{'intSubTypeID'}}=$dref->{strSubTypeName};
		}
		$optvalues{'SubRealms'} = \%AssocTypes;
	}

  if ($options->{'Assocs'}) {
    my %Assocs = ();
    my $statement = qq[
      SELECT intAssocID, strName
      FROM tblAssoc
      WHERE intRealmID = ? AND intRecStatus != -1
    ];
    my $query = $db->prepare($statement);
    $query->execute($Data->{'Realm'});
    while (my $dref = $query->fetchrow_hashref() ) {
      $Assocs{$dref->{'intAssocID'}} = $dref->{strName};
    }
    $optvalues{'Assocs'} = \%Assocs;
  }

	if ($options->{'RegoForms'}) {
		my $aID=getAssocID($clientValues_ref) || 0;
        my $currLevel = $clientValues_ref->{'currentLevel'} || 0;
        my $clubID = $clientValues_ref->{'clubID'} || 0;
        
        my ($entityTypeID, $entityID) = getEntityValues($Data->{'clientValues'});
        my $nodeIds = '0';
        my $entityStructure = getEntityStructure($Data, $db, $entityTypeID, $entityID, $Defs::LEVEL_NATIONAL);
        foreach my $entityArr (@$entityStructure) {
            next if @$entityArr[0] <= $Defs::LEVEL_ASSOC;
            $nodeIds .= ',' if $nodeIds;
            $nodeIds .= @$entityArr[1];
        }
		$aID=0 if $aID==-1;
		my %RegoForms = ();
		my @RegoFormsOrder = ();
        #National Forms
        my $statement = qq[
        SELECT
            RF.intRegoFormID,RF.strRegoFormName
        FROM
            tblRegoForm RF
        WHERE
            (RF.intAssocID IN (0, $aID) OR (RF.intAssocID=-1 AND RF.intCreatedLevel>$Defs::LEVEL_ASSOC AND $currLevel<=RF.intCreatedLevel AND RF.intCreatedID IN (0, $nodeIds)))
            AND RF.intRealmID = $Data->{'Realm'}
        ];
        #forms created by nodes will have a clubID of -1. clubs can only see member-to-club forms created by nodes.
        if ($clubID) {
            $statement .= qq[
                AND (RF.intClubID = $clubID OR (RF.intClubID=-1 AND RF.intCreatedLevel>$Defs::LEVEL_ASSOC AND RF.intRegoType=$Defs::REGOFORM_TYPE_MEMBER_CLUB AND RF.intCreatedID IN (0,$nodeIds)))
            ];
        }
        else {
            $statement .= " AND RF.intClubID = -1";
        }
        #not National Forms
        my $sql = qq[SELECT intRegoFormID, strRegoformName FROM tblRegoForm WHERE intAssocID IN (0, $aID) AND intRealmID = $Data->{'Realm'} ];

        if ($clubID and $clubID != -1) {
            $sql .= " AND intClubID = $clubID ";
        }
        else {
            $sql .= " AND intClubID = -1";
        }

        $statement = qq[$statement UNION $sql];
		my $query = $db->prepare($statement);
		$query->execute();
		while (my $dref = $query->fetchrow_hashref() ) {
			$RegoForms{$dref->{'intRegoFormID'}}=$dref->{strRegoFormName};
			push @RegoFormsOrder, $dref->{intRegoFormID};
		}
		my %RegoFormData = (
			Options => \%RegoForms,
			Order => \@RegoFormsOrder,
		);
		$optvalues{'RegoForms'} = \%RegoFormData;
	}

	if($options->{'Seasons'})	{
		my $AssocSeasons=Seasons::getDefaultAssocSeasons($Data);
		my $hideSeasons=0;
		$hideSeasons = 1 if(!$Data->{'SystemConfig'}{'AllowSeasons'} and !$AssocSeasons->{'allowSeasons'});
		my $currentSeason = $AssocSeasons->{'currentSeasonID'} || 0;
		my %Seasons=();
		my @SeasonsOrder=();
		if ($Data->{'SystemConfig'}{'AllowSeasons'})	{
			my $aID=getAssocID($clientValues_ref) || 0;
			$aID=0 if $aID==-1;
			my $statement=qq[
				SELECT intSeasonID, strSeasonName
				FROM tblSeasons
							WHERE intRealmID=$Data->{'Realm'}
							AND (intAssocID = $aID OR intAssocID = 0)
				 AND (intRealmSubTypeID = $Data->{'RealmSubType'} OR intRealmSubTypeID= 0)
				ORDER BY intSeasonOrder, strSeasonName DESC
			];
			my $query = $db->prepare($statement) or query_error($statement);
			$query->execute or query_error($statement);
			while (my $dref = $query->fetchrow_hashref() ) {
				$Seasons{$dref->{'intSeasonID'}}=$dref->{strSeasonName};
				push @SeasonsOrder, $dref->{intSeasonID};
			}
		}
		my %SeasonData = (
			Options => \%Seasons,
			Order => \@SeasonsOrder,
			Hide => $hideSeasons,
			Current => $currentSeason,
		);
		$optvalues{'Seasons'} = \%SeasonData;
	}

	if($options->{'AgeGroups'})	{

		my %AgeGroups=();
		my @AgeGroupsOrder=();
		if ($Data->{'SystemConfig'}{'AllowSeasons'})	{
			my $aID=getAssocID($clientValues_ref) || 0;
			$aID=0 if $aID==-1;
			my $statement=qq[
				SELECT intAgeGroupID, strAgeGroupDesc, intAgeGroupGender
				FROM tblAgeGroups
							WHERE intRealmID=$Data->{'Realm'}
							AND (intAssocID = $aID OR intAssocID = 0)
				 AND (intRealmSubTypeID = $Data->{'RealmSubType'} OR intRealmSubTypeID= 0)
				AND intRecStatus=1
				ORDER BY strAgeGroupDesc
			];
			my $query = $db->prepare($statement) or query_error($statement);
			$query->execute or query_error($statement);
			while (my $dref = $query->fetchrow_hashref() ) {
				my $gender = $dref->{intAgeGroupGender} ? qq[- ($Defs::genderInfo{$dref->{intAgeGroupGender}})] : '';
				$AgeGroups{$dref->{'intAgeGroupID'}}=qq[$dref->{strAgeGroupDesc}$gender] || '';
				push @AgeGroupsOrder, $dref->{intAgeGroupID};
			}
		}
		$optvalues{'AgeGroups'} = {
			Order => \@AgeGroupsOrder,
			Options => \%AgeGroups,
		};
	}

	if($options->{'Products'})	{
		if($Data->{'SystemConfig'}{'AllowTXNrpts'})	{
			my %Products=();
			my @ProductsOrder=();
			my $aID=getAssocID($clientValues_ref) || 0;
			$aID=0 if $aID==-1;
			my $WHEREClub = '';
			if ($Data->{'clientValues'}{'clubID'} and $Data->{'clientValues'}{'clubID'} != $Defs::INVALID_ID) {
				$WHEREClub = qq[
					AND (
						(intCreatedLevel = 0 OR intCreatedLevel > 3) 
						OR (
							intCreatedLevel = $Defs::LEVEL_CLUB 
							AND intCreatedID = $Data->{'clientValues'}{'clubID'}
						)
					)
				];
			}

			my $levelWHERE = qq[AND (P.intAssocID = $aID OR P.intAssocID = 0) ];
			my $currentLevel = $Data->{'clientValues'}{'currentLevel'};
			my $productName = qq[ P.strName as ProductName,];
			if ($currentLevel > $Defs::LEVEL_ASSOC)	{
				$levelWHERE = qq[ AND (P.intAssocID=0 OR ];
				$levelWHERE .= qq[TNS.int100_ID > 0 ] if ($currentLevel > 100);
				$levelWHERE .= qq[TNS.int100_ID = $Data->{'clientValues'}{'natID'}] if ($currentLevel == 100);
				$levelWHERE .= qq[TNS.int30_ID = $Data->{'clientValues'}{'stateID'}] if ($currentLevel == 30);
				$levelWHERE .= qq[TNS.int20_ID = $Data->{'clientValues'}{'regionID'}] if ($currentLevel == 20);
				$levelWHERE .= qq[TNS.int10_ID = $Data->{'clientValues'}{'zoneID'}] if ($currentLevel == 10);
				$levelWHERE .= qq[ )];
				#$productName = qq[ CONCAT('(', A.strName, ')- ', P.strName) as ProductName,];
				$productName = qq[IF(A.intAssocID, CONCAT('(', A.strName, ')- ', P.strName), P.strName) as ProductName,];
			}
			my $statement=qq[
				SELECT DISTINCT
					P.intProductID,
					$productName
					strGroup, 
					intInactive
				FROM tblProducts as P 
					LEFT JOIN tblTempNodeStructure as TNS ON (
						TNS.intAssocID=P.intAssocID
					)
					LEFT JOIN tblAssoc as A ON (
						A.intAssocID=P.intAssocID
					)
				WHERE P.intRealmID=$Data->{'Realm'}
					$levelWHERE
					AND intProductSubRealmID IN (0, $Data->{'RealmSubType'})
					$WHEREClub
				ORDER BY intInactive, strGroup,ProductName 
			];
			my $query = $db->prepare($statement) or query_error($statement);
			$query->execute or query_error($statement);
			while (my $dref = $query->fetchrow_hashref() ) {
				my $inactive = $dref->{intInactive} ? qq[(ARCHIVED)-] : '';
				my $group = $dref->{strGroup} ? qq[$dref->{strGroup}-] : '';
				$Products{$dref->{'intProductID'}}=qq[$inactive$group$dref->{ProductName}];
				push @ProductsOrder, $dref->{intProductID};
			}
			$optvalues{'Products'} = {
				Order => \@ProductsOrder,
				Options => \%Products,
			};
		}
	}

	if($options->{'Countries'})	{
  	my @countries=getCountriesArray($Data);
  	my %countriesonly=();
  	for my $c (@countries)  { $countriesonly{$c}=$c;  }
		$optvalues{'Countries'} = \%countriesonly;
	}

	if($options->{'ContactRoles'})	{
		my %ContactRoles=();
		my @ContactRolesOrder=();
		{
			my $statement = qq[
				SELECT intRoleID, strRoleName
				FROM tblContactRoles
				WHERE intRealmID IN ($Data->{'Realm'},0)
				ORDER BY intRoleOrder ASC
			];
			my $query = $Data->{'db'}->prepare($statement);
			$query->execute;
			while (my($id, $strName) = $query->fetchrow_array) {
				$ContactRoles{$id}=$strName || '';
				push @ContactRolesOrder, $id;
			}
		}
		$optvalues{'ContactRoles'} = {
			Order => \@ContactRolesOrder,
			Values => \%ContactRoles,
		};
	}


	if($options->{'FieldLabels'})	{
		$optvalues{'FieldLabels'} = getFieldLabels($Data, $Defs::LEVEL_PERSON);
	}

	if($options->{'ClubCharacteristics'})	{
		my %cchar_values = ();
		my @cchar_order = ();
		my $cchars = getAvailableCharacteristics($Data);

		for my $c (@{$cchars})	{
			my $id  = $c->{'intCharacteristicID'} || next;
			$cchar_values{$id} = $c->{'strName'} || next;
			push @cchar_order, $id;
		}
		$optvalues{'ClubCharacteristics'} = {
			Order => \@cchar_order,
			Values => \%cchar_values,
		};
	}
	if($options->{'EntityCategories'})	{
		my $aID=getAssocID($clientValues_ref) || 0;
		my %EntityCategories=();

		$aID=0 if $aID==-1;
		my $subRealmWHERE = '';
		my $currentLevel = $Data->{'clientValues'}{'currentLevel'};
		if ($currentLevel > $Defs::LEVEL_ASSOC)	{
			$subRealmWHERE = '';
		}
		my $statement=qq[
			SELECT 
				intEntityCategoryID,
				strCategoryName,
				intEntityType
			FROM 
				tblEntityCategories
     	WHERE 
				intRealmID=$Data->{'Realm'}
        AND (intAssocID = $aID OR intAssocID = 0)
				$subRealmWHERE
		];
		my $query = $db->prepare($statement) or query_error($statement);
		$query->execute or query_error($statement);
		while (my $dref = $query->fetchrow_hashref() ) {
			$EntityCategories{$dref->{'intEntityType'}}{$dref->{'intEntityCategoryID'}}=$dref->{strCategoryName};
		}
		$optvalues{'EntityCategories'} = \%EntityCategories;
	}

	return \%optvalues;
}

sub showMultiEntitlements {
  my($val, $lookup)=@_;

  my @a=split /\|/,$val;
  my $out='';
  for my $i (@a)  {
    next if !$i;
    $out.=', ' if $out;
    my $v=$i;
    $v=$lookup->{$i} if ($lookup and $lookup->{$i});
    $out.=$v;
  }
  return $out;

}

1;

