package RegoFormAddedObj;

use lib;
use BaseObject2;
our @ISA = qw(BaseObject2);

use strict;

sub _getTableName {
    return 'tblRegoFormAdded';
}

sub _getKeyName {
    return 'intRegoFormAddedID';
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

1;
