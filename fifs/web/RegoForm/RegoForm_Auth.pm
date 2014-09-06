#
# $Header: svn://svn/SWM/trunk/web/RegoForm/RegoForm_Auth.pm 10122 2013-12-03 02:07:26Z tcourt $
#

package RegoForm_Auth;
require Exporter;
@ISA =  qw(Exporter);
@EXPORT = qw(generateLoginKey validateLoginKey);
@EXPORT_OK = qw(generateLoginKey validateLoginKey);

use strict;
use lib "..","../..";
use Reg_common;
use Defs;

sub	generateLoginKey	{
	my $self = shift;
	my (
		$username,
		$password,
		$passport_linkedEntityID,
		$passportID,
	) = @_;

	#Based on type of form work out whether team or Member
	#validate the un/pw and then create login key
	my $formtype = $self->FormEntityType();
	my $st = '';
	my $q;
	$passport_linkedEntityID ||= 0;
	$passportID ||= 0;
	if($username and $password)	{
		if($formtype eq 'Member')	{
			$username =~ s/^1//g;
			$st = qq[
				SELECT	
					MA.intMemberID
				FROM       
					tblAuth AS A
					INNER JOIN tblMember_Associations AS MA
						ON (	
							MA.intMemberID = A.intID 
							AND MA.intAssocID = ?
						)
						INNER JOIN tblMember AS M ON (M.intMemberID = MA.intMemberID)
				WHERE      
					A.intLevel = $Defs::LEVEL_MEMBER
					AND        A.strUsername = ?
					AND        A.strPassword = ?
					AND        M.intStatus <> -1
					AND        MA.intRecStatus <> -1
					AND        M.intDeRegister <> 1
				ORDER BY A.intAssocID DESC
				LIMIT      1
			];
	
			$q = $self->{'db'}->prepare($st);
			$q->execute(
				$self->AssocID() || 0,
				$username,
				$password
			);
		}
		elsif($formtype eq 'Team')	{
			$username =~ s/^2//g;
			$st = qq[
				SELECT   A.intID
				FROM     tblAuth as A
				WHERE    
					A.intLevel = $Defs::LEVEL_TEAM
					AND      A.intAssocID = ?
					AND      A.strUsername = ?
					AND      A.strPassword = ?
				LIMIT 1
			];
			$q = $self->{'db'}->prepare($st);
			$q->execute(
				$self->AssocID() || 0,
				$username,
				$password,
			);
		}
		else {
			return '';
		}
	}
	elsif(
		$passport_linkedEntityID
		and $passportID
	)	{
		if($formtype eq 'Member')	{
			$st = qq[
				SELECT	
					intMemberID
				FROM       
					tblPassportMember
				WHERE      
					intMemberID = ?
					AND intPassportID = ?
			];
			$q = $self->{'db'}->prepare($st);
			$q->execute(
				$passport_linkedEntityID,
				$passportID,
			);
		}
		elsif($formtype eq 'Team')	{
			$st = qq[
				SELECT   intEntityID
				FROM     tblPassportAuth
				WHERE    
					intEntityTypeID = $Defs::LEVEL_TEAM
					AND intEntityID = ?
					AND intPassportID = ?
				LIMIT 1
			];
			$q = $self->{'db'}->prepare($st);
			$q->execute(
				$passport_linkedEntityID,
				$passportID,
			);
		}
	}
	return '' if !$st;
	my($entityID) = $q->fetchrow_array();
	$entityID ||= 0;
	return '' if !$entityID;
	if(
		$passportID 
		and $entityID 
		and !$passport_linkedEntityID
		and $username
		and $password
	)	{
		#User logged in with UN/PW but has passport
		#assign the passport to the entity
		linkRegoAuthToPassport(
			$self->{'db'},
			$self->AssocID() || 0,
			$passportID,
			$entityID,	
			$formtype,
		);
	}
	my $key = $entityID .':'. getRegoPassword($entityID);
	return $key;
}

sub validateLoginKey	{
	my $self = shift;

	my $key = $self->{'RunParams'}{'ak'};
	if(
		!$key 
		and $self->{'RunParams'}{'eID'} 
		and $self->{'RunParams'}{'ID'} 
	)	{
		$key = $self->{'RunParams'}{'ID'} . ':' . $self->{'RunParams'}{'eID'};
	}
	$key ||= $self->{'AuthKey'} || '';

	my ($entity, $hash) = split /:/,$key,2;
	$hash ||= '';
	$entity ||= '';
	if(
		$entity
		and $hash
		and getRegoPassword($entity) eq $hash
	)	{
		$self->{'AuthKey'} = $key;
		$self->{'AuthorisedID'} = $entity;
		$self->addCarryField('ak', $key);
		$self->{'RunDetails'}{'ReRegister'} = 1;
		return $entity || 0;
	}
	return 0;
}

sub	linkRegoAuthToPassport	{
	my (
		$db,
		$assocID,
		$passportID,
		$entityID,	
		$formtype,
	) = @_;

	return '' if !$db;
	return '' if !$assocID;
	return '' if !$passportID;
	return '' if !$entityID;
	return '' if !$formtype;

	
	if($formtype eq 'Member')	{
    my $st = qq[
      INSERT IGNORE INTO tblPassportMember (
        intPassportID,
        intMemberID,
        tTimeStamp
      )
      VALUES (
        ?,
        ?,
        NOW()
      )
    ];
    my $q = $db->prepare($st);
    $q->execute(
      $passportID,
      $entityID,
    );
    $q->finish();
	}
	elsif($formtype eq 'Team')	{
    my $st = qq[
      INSERT INTO tblPassportAuth (
        intPassportID,
        intEntityTypeID,
        intEntityID,
        intAssocID,
        intReadOnly,
        intRoleID,
        dtCreated
      )
      VALUES (
        ?,
        ?,
        ?,
        ?,
        ?,
        ?,
        NOW()
      )
    ];
    my $q = $db->prepare($st);
    #$Defs::AUTH_TYPE_TEAM  or $Defs::TYPE_TEAM ???
    $q->execute(
      $passportID,
			$Defs::AUTH_TYPE_TEAM,
      $entityID,
			$assocID,
			0,
			0,
    );
    $q->finish();
	}
	return 1;
}

1;
