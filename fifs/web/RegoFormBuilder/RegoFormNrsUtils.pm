package RegoFormNrsUtils;

require Exporter;
@ISA       = qw(Exporter);
@EXPORT    = qw(getNrsConfig getNrsOverrideFields checkHierarchicalPerms checkHierarchicalAdds);
@EXPORT_OK = qw(getNrsConfig getNrsOverrideFields checkHierarchicalPerms checkHierarchicalAdds);

use lib '.', '..';

use strict;
use Defs;
use Utils;
use Reg_common;

sub getNrsConfig {
    my ($Data) = @_;

    my $nrsEnabled   = $Data->{'SystemConfig'}{'AllowOnlineRego_node'} || 0;
    my $nrsPcEnabled = 0;
    my $nrsRaEnabled = 0;
    my $nrsMrEnabled = 0;
    my $nrsRoEnabled = 0;
    my $nrsOptCount  = 0;

    if ($nrsEnabled) {
        $nrsPcEnabled = !$Data->{'SystemConfig'}{'nrs_disablePaymentCompulsoryOverride'} || 0;
        $nrsRaEnabled = !$Data->{'SystemConfig'}{'nrs_disableRegisterAsOverride'}        || 0;
        $nrsMrEnabled = !$Data->{'SystemConfig'}{'nrs_disableMultipleRegoOverride'}      || 0;
        $nrsRoEnabled = !$Data->{'SystemConfig'}{'nrs_disableRegoOptionsOverride'}       || 0;
        $nrsOptCount  = $nrsPcEnabled + $nrsRaEnabled + $nrsMrEnabled + $nrsRoEnabled;
    }
   
   my %nrsConfig = (
       enabled   => $nrsEnabled,
       pcEnabled => $nrsPcEnabled,
       raEnabled => $nrsRaEnabled,
       mrEnabled => $nrsMrEnabled,
       roEnabled => $nrsRoEnabled,
       optCount  => $nrsOptCount,
   );

   return \%nrsConfig;
}

sub getNrsOverrideFields {

    #an alternative is to make a hash of arrays eg pc => ['intPaymentCompulsoryi'], ra => ['ynPlayer', 'ynCoach', etc]
    #but not as straightforward to work with...
    my %nrsOverrideFields = (
        paymentCompulsory => 'intPaymentCompulsory',
        player            => 'ynPlayer',
        coach             => 'ynCoach',
        official          => 'ynOfficial',
        matchOfficial     => 'ynMatchOfficial',
        misc              => 'ynMisc',
        volunteer         => 'ynVolunteer',
        multipleAdult     => 'intAllowMultipleAdult',
        multipleChild     => 'intAllowMultipleChild',
        newRegos          => 'intNewRegosAllowed',
        strAllowedMemberRecordTypes => 'strAllowedMemberRecordTypes',
    );

    return \%nrsOverrideFields;

};

sub checkHierarchicalPerms {
    my ($Data, $fieldName, $entityTypeID, $entityID, $upperLevel) = @_;

    my $entityStructure = getEntityStructure($Data, $entityTypeID, $entityID, $upperLevel, 0); #get bottomup

    my $perm = '';
    
   foreach my $entityArr (@$entityStructure) {
       my $checkPerm = checkPerms($Data, $fieldName, @$entityArr[0], @$entityArr[1]); #[0] is entityTypeID, [1] is entityID.
       $perm = $checkPerm if $checkPerm and (isHeavierPerm($checkPerm, $perm));
   }

    return $perm;
}

sub checkPerms {
    my ($Data, $fieldName, $entityTypeID, $entityID) = @_;

    my @fields = ('strPermission');
    my %where  = (
        intEntityTypeID => $entityTypeID, 
        intEntityID     => $entityID,
        strFieldName    => $fieldName,
        strFieldType    => 'MemberRegoForm',
        strPermission   => [ -and => {'!=', 'ChildDefine'}],
    );

    my ($sql, @bindVals) = getSelectSQL('tblFieldPermissions', \@fields, \%where, undef);

    my $q = $Data->{'db'}->prepare($sql);
    $q->execute(@bindVals);

    my ($perm) = $q->fetchrow_array() || '';

    return $perm;
}

sub checkHierarchicalAdds {
    my ($Data, $fieldName, $formID, $entityTypeID, $entityID, $upperLevel, $checkPerm) = @_;

    my $entityStructure = getEntityStructure($Data, $entityTypeID, $entityID, $upperLevel, 0); #get bottomup
    my $count = 0;

   foreach my $entityArr (@$entityStructure) {
       last if @$entityArr[0] >= $upperLevel; #[0] is entityTypeID, [1] is entityID. #upperLevel won't have any adds.
       $count += checkAdds($Data, $fieldName, $formID, @$entityArr[0], @$entityArr[1], $checkPerm);
       last if $count;
   }

    return $count;
}

sub checkAdds {
    my ($Data, $fieldName, $formID, $entityTypeID, $entityID, $checkPerm) = @_;

    my @fields = ('strPerm');
    my %where  = (intRegoFormID=>$formID, intEntityTypeID=>$entityTypeID, intEntityID=>$entityID, strFieldName=>$fieldName, intStatus=>1);

    my ($sql, @bindVals) = getSelectSQL('tblRegoFormFieldsAdded', \@fields, \%where);
    my $q = $Data->{'db'}->prepare($sql);
    $q->execute(@bindVals);

    my $count = 0;

    while (my ($thisPerm) = $q->fetchrow_array()) {
        if ($checkPerm) {
            $count++ if $Defs::FieldPermWeights{$thisPerm} >= $Defs::FieldPermWeights{$checkPerm};
        }
        else {
            $count++;
        }
    }

    return $count;
}

1;
