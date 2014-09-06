package RegistrationItem;
require Exporter;
@ISA = qw(Exporter);
@EXPORT = @EXPORT_OK = qw(
	getRegistrationItems 
);
use lib '.', '..'; #"comp", 'RegoForm', "dashboard", "RegoFormBuilder",'PaymentSplit', "user";

use strict;
use Utils;
use Log;
use Products;

sub getRegistrationItems    {
    my($Data, $ruleFor, $itemType, $originLevel, $regNature, $entityID, $entityLevel, $multiPersonType, $Rego_ref) = @_; 

    $itemType ||= '';
    $originLevel ||= 0; 
    $regNature ||= '';
    $ruleFor ||= '';
    $entityLevel ||= 0; # used for Products
    $multiPersonType ||= ''; ## For products, are multi regos used
    

    return 0 if (! $itemType);
	
    my $st = qq[
		SELECT 
            intID,
            intRequired,
            intUseExistingThisEntity,
            intUseExistingAnyEntity
        FROM
            tblRegistrationItem
        WHERE
            intRealmID = ?
            AND intSubRealmID IN (0, ?)
            AND strRuleFor = ?
            AND intOriginLevel = ?
			AND strRegistrationNature = ?
            AND strEntityType IN ('', ?)
            AND intEntityLevel = ?
			AND strPersonType = ?
			AND strPersonLevel = ?
            AND strPersonEntityRole IN ('', ?)
			AND strSport = ?
			AND strAgeLevel = ?		
            AND strItemType = ?
    ];
	
	my $q = $Data->{'db'}->prepare($st) or query_error($st);
	$q->execute(
        $Data->{'Realm'},
        $Data->{'RealmSubType'},
        $ruleFor,
        $originLevel,
		$regNature,
        $Rego_ref->{'strEntityType'} || $Rego_ref->{'entityType'} || '',
        $Rego_ref->{'strEntityLevel'} || $Rego_ref->{'entityLevel'} || 0,
		$Rego_ref->{'strPersonType'} || $Rego_ref->{'personType'} || '',
		$Rego_ref->{'strPersonLevel'} || $Rego_ref->{'personLevel'} || '',
		$Rego_ref->{'strPersonEntityRole'} || $Rego_ref->{'personEntityRole'} || '',
		$Rego_ref->{'strSport'} || $Rego_ref->{'sport'} || '',
		$Rego_ref->{'strAgeLevel'} || $Rego_ref->{'ageLevel'} || '',
        $itemType
	) or query_error($st);
	
    my @Items=();
warn($st);
    while (my $dref = $q->fetchrow_hashref())   {
warn("ITEM");
        my %Item=();
        $Item{'ID'} = $dref->{'intID'};
        $Item{'UseExistingThisEntity'} = $dref->{'intUseExistingThisEntity'} || 0;
        $Item{'UseExistingAnyEntity'} = $dref->{'intUseExistingAnyEntity'} || 0;
        $Item{'Required'} = $dref->{'intRequired'} || 0;
        if ($itemType eq 'PRODUCT') {
            $Item{'ProductPrice'} = getItemCost($Data, $entityID, $entityLevel, $multiPersonType, $dref->{'intID'}) || 0;
        }
        push @Items, \%Item;
    }
    return \@Items;

}

1;
