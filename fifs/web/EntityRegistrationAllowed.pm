package RegistrationRule;
require Exporter;
@ISA = qw(Exporter);
@EXPORT = @EXPORT_OK = qw(
	validRegistrationRule
	getRegistrationRules
);

use strict;
use Utils;
use TTTemplate;
use Log;
use Data::Dumper;

sub validRegistrationRule {
     my(
        $Data,
        $Rego_ref,
    ) = @_;

	my $rc = 0;
   	my $st = '';
	my $q = '';
	my $db=$Data->{'db'};
	
    $st = qq[
		SELECT intStatus
		FROM tblRegistrationRule
		WHERE intEntityID = ?
			AND strPersonLevel = ?
			AND strPersonType = ?
			AND strRegistrationNature = ?
			AND strSport = ?
			AND strAgeLevel = ?		
    ];
	

	$db=$Data->{'db'};
	$q = $db->prepare($st) or query_error($st);
	$q->execute(
		$Rego_ref->{'entityID'},
		$Rego_ref->{'personLevel'},
		$Rego_ref->{'registrationType'},
		$Rego_ref->{'registrationNature'},
		$Rego_ref->{'sport'},
		$Rego_ref->{'ageLevel'},
	) or query_error($st);
	
	if (my $dref= $query->fetchrow_hashref()) {	
        $rc = $dref->{intStatus};		
	}

	return($rc);  	
}

sub getRegistrationRules {
     my(
        $Data, 
        $intEntityID,
    ) = @_;

	my $st = '';
	my $q = '';
	my $db=$Data->{'db'};
	
    $st = qq[
        SELECT *
			FROM tblRegistrationRule
			WHERE entityID = ?
    ];	
	
	$q = $db->prepare($st) or query_error($st);
	$q->execute($intEntityID) or query_error($st);
	
	my @List = ();
	  
	while(my $dref= $q->fetchrow_hashref()) {
	
		my %single_row = (
			EntityID => $dref->{intEntityID},
			PersonLevel => $dref->{strPersonLevel},			
			RegistrationType => $dref->{strRegistrationType},
			RegistrationNature => $dref->{intRegistrationNature},
			Sport => $dref->{strSport},
			AgeLevel => $dref->{strAgeLevel},	
			Status => $dref->{intStatus},				 	);
		push @List, \%single_row;
	}
		
	return(\%List); 

}

1;
