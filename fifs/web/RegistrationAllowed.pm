package RegistrationAllowed;
require Exporter;
@ISA = qw(Exporter);
@EXPORT = @EXPORT_OK = qw(
	isRegoAllowedToSystem
);

use strict;
use Utils;
use Log;

sub isRegoAllowedToSystem {
    my($Rego_ref, $Data, $originLevel, $regNature, $entityLevel) = @_; 

    $originLevel ||= 0; 
    $regNature ||= '';

    #return 0 if (! $originLevel or ! $regNature);
	
    my $st = qq[
		SELECT 
            COUNT(intMatrixID) as CountRecords
        FROM
            tblMatrix
        WHERE
            intRealmID = ?
            AND intSubRealmID IN (0, ?)
			AND strPersonType = ?
			AND strPersonLevel = ?
			AND strSport = ?
			AND strAgeLevel = ?		
			AND intEntityLevel = ?		
    ];
    my @bind=();
    push @bind, $Data->{'Realm'};
    push @bind, $Data->{'RealmSubType'};
    push @bind, $Rego_ref->{'d_strPersonType'} || $Rego_ref->{'strPersonType'} || $Rego_ref->{'personType'} || '';
    push @bind, $Rego_ref->{'d_strPersonLevel'} || $Rego_ref->{'strPersonLevel'} || $Rego_ref->{'personLevel'} || '';
    push @bind, $Rego_ref->{'d_strSport'} || $Rego_ref->{'strSport'} || $Rego_ref->{'sport'} || '';
    push @bind, $Rego_ref->{'d_strAgeLevel'} || $Rego_ref->{'strAgeLevel'} || $Rego_ref->{'ageLevel'} || '';
        push @bind, $entityLevel;

    if ($originLevel)   {
        $st .= qq[AND intOriginLevel = ? ];
        push @bind, $originLevel;
    }
    if ($regNature)   {
		$st .= qq[AND strRegistrationNature = ? ];
        push @bind, $regNature;
    }
	
	my $q = $Data->{'db'}->prepare($st) or query_error($st);
    
	$q->execute(@bind) or query_error($st);
	
    my $count = $q->fetchrow_array() || 0;
    return (1, '') if $count;
    return (0, $Data->{'lang'}->txt('The system does not allow this combination')) if ! $count;

}

#sub isRegoAllowedToEntity {
#
#    my($Data, $entityID, $regNature, $Rego_ref) = @_; 
#
#    $entityID ||= 0;
#    $regNature ||= '';
#
#    return 0 if (! $entityID or ! $regNature);
#	
#    my $st = qq[
#		SELECT 
#            COUNT(intEntityRegistrationAllowedID) as CountRecords
#        FROM
#            tblEntityRegistrationAllowed
#        WHERE
#            intRealmID = ?
#            AND intSubRealmID IN (0, ?)
#		    AND intEntityID = ?
#			AND strRegistrationNature = ?
#			AND strPersonType = ?
#			AND strPersonLevel = ?
#			AND strSport = ?
#			AND strAgeLevel = ?		
#            AND intGender = ?
#    ];
#	
#
#	my $q = $Data->{'db'}->prepare($st) or query_error($st);
#	$q->execute(
#        $Data->{'Realm'},
#        $Data->{'RealmSubType'},
#		$entityID,
#		$regNature,
#		$Rego_ref->{'personType'} || '',
#		$Rego_ref->{'personLevel'} || '',
#		$Rego_ref->{'sport'} || '',
#		$Rego_ref->{'ageLevel'} || '',
#		$Rego_ref->{'gender'}
#	) or query_error($st);
#	
#    my $count = $q->fetchrow_array() || 0;
#    return 1 if $count;
#    return 0 if ! $count;
#}

1;
