package PersonObj;

use strict;
use BaseObject;
our @ISA =qw(BaseObject);


sub load {
  my $self = shift;

	my $st=qq[
  SELECT
    tblPerson.*,
    DATE_FORMAT(dtPassportExpiry,'%d/%m/%Y') AS dtPassportExpiry,
    DATE_FORMAT(dtDOB,'%d/%m/%Y') AS dtDOB,
    tblPerson.dtDOB AS dtDOB_RAW,
    DATE_FORMAT(tblPerson.tTimeStamp,'%d/%m/%Y') AS tTimeStamp,
    DATE_FORMAT(dtNatCustomDt1,'%d/%m/%Y') AS dtNatCustomDt1,
    DATE_FORMAT(dtNatCustomDt2,'%d/%m/%Y') AS dtNatCustomDt2,
    DATE_FORMAT(dtNatCustomDt3,'%d/%m/%Y') AS dtNatCustomDt3,
    DATE_FORMAT(dtNatCustomDt4,'%d/%m/%Y') AS dtNatCustomDt4,
    DATE_FORMAT(dtNatCustomDt5,'%d/%m/%Y') AS dtNatCustomDt5,
    MN.strNotes
      FROM
    tblPerson
    LEFT JOIN tblPersonNotes as MN ON (
      MN.intPersonID = tblPerson.intPersonID
    )
      WHERE
    tblPerson.intPersonID = ?
	];
	my $q = $self->{'db'}->prepare($st);
	$q->execute(
		$self->{'ID'},
	);
	if($DBI::err)	{
		$self->LogError($DBI::err);
	}
	else	{
		$self->{'DBData'}=$q->fetchrow_hashref();	
	}
}

sub name {
    my $self = shift;

    my $surname   = $self->getValue('strLocalSurname');
    my $firstname = $self->getValue('strLocalFirstname');

    return "$firstname $surname";
}


# Across realm check to see there is an existing member with this firstname/surname/dob and with primary club set.
# Static method.
sub already_exists {
    my $class = shift;

    my ($Data, $new_member, $sub_realm_id) = @_;

    my $realm_id = $Data->{'Realm'};

    $sub_realm_id ||= $Data->{'RealmSubType'};

    my $st = qq[
        SELECT
            M.intPersonID,
            M.strLocalFirstname,
            M.strLocalSurname,
            M.strEmail,
            M.dtDOB,
            M.strNationalNum
        FROM tblPerson as M 
        WHERE
            M.intRealmID=?
            AND M.strLocalFirstname=?
            AND M.strLocalSurname=?
            AND M.dtDOB=?
            AND M.intStatus=1
     ];

    my $q = $Data->{'db'}->prepare($st);
    $q->execute(
        $realm_id,
        $sub_realm_id,
        $new_member->{'firstname'},
        $new_member->{'surname'},
        $new_member->{'dob'},
    );

    my @matched_members = ();
    while (my $dref = $q->fetchrow_hashref()) {
        push @matched_members, $dref;
 }
    return \@matched_members;
}

1;
