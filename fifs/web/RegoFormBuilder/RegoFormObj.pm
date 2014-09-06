#
# $Header: svn://svn/SWM/trunk/web/RegoFormObj.pm 11494 2014-05-06 05:56:45Z sliu $
#

package RegoFormObj;

use lib '..';
use BaseObject2;
our @ISA = qw(BaseObject2);

use strict;

use Defs;
use Utils;

use RegoFormSQL;

sub _getTableName {
    return 'tblRegoForm';
}

sub _getKeyName {
    return 'intRegoFormID';
}

sub isNodeForm {
    my $self = shift;
    my $isNodeForm = (($self->getValue('intAssocID') == -1) and ($self->getValue('intCreatedLevel') > $Defs::LEVEL_ASSOC)) ? 1 : 0;
    return $isNodeForm;
}

sub isLinkedForm {
    my $self = shift;
    my $isLinkedForm = ($self->getValue('intParentBodyFormID')) ? 1 : 0;
    return $isLinkedForm;
}

sub isOwnForm {
    my $self = shift;
    my (%params) = @_;
    my $entityID = $params{'entityID'};
    return undef if !$entityID;
    my $isOwnForm = ($entityID == $self->getValue('intCreatedID')) ? 1 : 0;
    return $isOwnForm;
}

sub isParentBodyForm { 
    my $self = shift;
    my (%params) = @_;
    my $level = $params{'level'};
    return undef if !$level;
    my $isParentBodyForm = ($level < $self->getValue('intCreatedLevel')) ? 1 : 0;
    return $isParentBodyForm;
}

sub allowPlayer {
    my $self = shift;
    my $allowPlayer = $self->getValue('ynPlayer') eq 'Y';
    return $allowPlayer;
}

sub allowCoach {
    my $self = shift;
    my $allowCoach = $self->getValue('ynCoach') eq 'Y';
    return $allowCoach;
}

sub allowOfficial {
    my $self = shift;
    my $allowOfficial = $self->getValue('ynOfficial') eq 'Y';
    return $allowOfficial;
}

sub allowMisc {
    my $self = shift;
    my $allowMisc = $self->getValue('ynMisc') eq 'Y';
    return $allowMisc;
}

sub allowUmpire {
    my $self = shift;
    my $allowUmpire = $self->getValue('ynMatchOfficial') eq 'Y';
    return $allowUmpire;
}

sub allowVolunteer {
    my $self = shift;
    my $allowVolunteer = $self->getValue('ynVolunteer') eq 'Y';
    return $allowVolunteer;
}

sub allowTypes {
    my $self = shift;
    my $allow_types = $self->getValue('strAllowedMemberRecordTypes') || '';
    my @allow_types = split(',', $allow_types);
    return @allow_types;
}

sub getListOfParentBodyForms {
    my $self = shift;

    my (%params) = @_;
    my $dbh       = $params{'dbh'};
    my $realmID   = $params{'realmID'}   || 0;
    my $assocID   = $params{'assocID'}   || 0;
    my $formTypes = $params{'formTypes'} || '';

    return undef if !$dbh;
    return undef if !$realmID or !$assocID;

    my $sql = getListOfParentBodyFormsSQL(realmID=>$realmID, formTypes=>$formTypes, assocID=>$assocID);

    my @bindVars = ($realmID);

    my $q = getQueryPreparedAndBound($dbh, $sql, \@bindVars);
   
    $q->execute();

    my @regoFormObjs = ();

    while (my $dref = $q->fetchrow_hashref()) {
        my $RegoFormObj = $self->load(db=>$dbh, ID=>$dref->{'intRegoFormID'});
        push @regoFormObjs, $RegoFormObj;
    }
    
    $q->finish();

    return \@regoFormObjs;
}

sub getFormEntityType {
    my $self = shift;

    my $formType = $self->getValue('intRegoType');

    my $formEntityType = '';

    if ($formType == $Defs::REGOFORM_TYPE_MEMBER_ASSOC or $formType == $Defs::REGOFORM_TYPE_MEMBER_TEAM or $formType == $Defs::REGOFORM_TYPE_MEMBER_CLUB or $formType == $Defs::REGOFORM_TYPE_MEMBER_PROGRAM) {
        $formEntityType = 'Member';
    }
    elsif ($formType == $Defs::REGOFORM_TYPE_TEAM_ASSOC) {
        $formEntityType = 'Team';
    }

    return $formEntityType;
}

sub is_form_type {
    my $self = shift;
    my $type = shift || 0;

    my $formType = $self->getValue('intRegoType');

    return ($formType == $type) ? 1 : 0;
}

1;
