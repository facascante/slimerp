package Aj_ValidatePendingApproval;

use lib '..','../..','../comp';
use Aj_Base;
our @ISA = qw(Aj_Base);

use strict;

use InstanceOf;
use Utils;
use DuplicatePrevention;

sub genContent {
    my $self = shift;
    my ($Data) = @_;

    my $dbh    = $Data->{'db'};
    my $params = $Data->{'params'};

    my $assocID   = $params->{'associd'}   || 0;
    my $clubID    = $params->{'clubid'}    || 0;
    my $memberID  = $params->{'memberid'}  || 0;
    my $seasonID  = $params->{'seasonid'}  || 0;
    my $firstname = $params->{'firstname'} || '';
    my $surname   = $params->{'surname'}   || '';
    my $dob       = $params->{'dob'}       || ''; #format = dd/mm/yyyy
    my $dobraw    = $params->{'dobraw'}    || ''; #format = yyyy-mm-dd

    $clubID = 0 if $clubID < 0;

    my %result = ();

    return JsonifyResult($self, 'Success', 'Duplicate Prevention not enabled!') if !$Data->{'SystemConfig'}{'DuplicatePrevention'};
    return JsonifyResult($self, 'Failure', 'Invalid parameters received!')      if !$assocID or !$memberID or !$seasonID;

    my $memberObj = getInstanceOf($Data, 'member', $memberID);

    if ($firstname != $memberObj->getValue('strFirstname') or $surname != $memberObj->getValue('strSurname') or $dob != $memberObj->getValue('dtDOB')) {
        return JsonifyResult($self, 'Failure', 'Member details have changed!');
    }

    my $source = "tblMember_Seasons_".$Data->{'Realm'};
    my %where  = (intMemberID=>$memberID, intAssocID=>$assocID, intClubID=>$clubID, intSeasonID=>$seasonID);

    my ($sql, @bindValues) = getSelectSQL($source, undef, \%where, undef);

    my $q = $dbh->prepare($sql);

    $q->execute(@bindValues);

    my $href = $q->fetchrow_hashref(); #unique key on table, so will only ever be one record...
 
    return JsonifyResult($self, 'Failure', 'Member season record not found!') if !defined $href or !%{$href};
    return JsonifyResult($self, 'Failure', 'Member no longer pending!')       if !$href->{'intPlayerPending'};

    my $prefix = 'int';
    my $suffix = 'Status';

    my @memberTypes = qw(Player Coach Umpire Official  Misc Volunteer);

    my @registeringAs = ();

    foreach my $memberType (@memberTypes) {
        my $checkField = $prefix.$memberType.$suffix;
        push @registeringAs, $memberType if (exists $href->{$checkField} and $href->{$checkField});
    }

    return JsonifyResult($self, 'Failure', 'No member type is checked on season record!') if !@registeringAs;

    my %newMember = (firstname=>$firstname, surname=>$surname, dob=>$dobraw);

    my $resultHTML = duplicate_prevention($Data, \%newMember, \@registeringAs, $memberID);
  
    #the resultHTML will actually contain an error message which could be displayed (and is elsewhere eg Member.pm).
    #however, here it is just used as a test for a dup member.
    return JsonifyResult($self, 'Failure', 'A member with the same name and date of birth already exists!') if $resultHTML;
  
    return JsonifyResult($self, 'Success', 'pending approval validated');
}

sub JsonifyResult {
    my $self = shift;

    my ($resultType, $message) = @_;

    my %result = ();

    $result{'result'}  = $resultType;
    $result{'message'} = $message;

    return $self->_createJSON(\%result);
}

1;
