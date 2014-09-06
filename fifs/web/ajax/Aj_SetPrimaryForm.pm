package Aj_SetPrimaryForm;

use lib '..','../..','../comp';
use Aj_Base;
our @ISA = qw(Aj_Base);

use strict;

use RegoFormPrimaryObj;

sub genContent {
    my $self = shift;
    my ($Data) = @_;

    my $dbh    = $Data->{'db'};
    my $params = $Data->{'params'};

    my $entityTypeID = $params->{'entityTypeID'} || 0;
    my $entityID     = $params->{'entityID'}     || 0;
    my $formID       = $params->{'formID'}       || 0;
    my $action       = $params->{'action'}       || '';

    return undef if !$entityTypeID or !$entityID or !$formID or !$action; #some extra error handling needed here!

    my %result = ();

    if ($action eq 'add') {
        my $currentPrimaryFormID = RegoFormPrimaryObj->getCurrentPrimaryFormID(dbh=>$dbh, entityTypeID=>$entityTypeID, entityID=>$entityID);

        $result{'old'} = $currentPrimaryFormID;

        my $dbfields    = 'dbfields';
        my $ondupfields = 'ondupfields';

        my $regoFormPrimaryObj = RegoFormPrimaryObj->new(db=>$dbh);
        $regoFormPrimaryObj->{$dbfields}    = ();
        $regoFormPrimaryObj->{$ondupfields} = ();

        $regoFormPrimaryObj->{$dbfields}{'intEntityTypeID'} = $entityTypeID;
        $regoFormPrimaryObj->{$dbfields}{'intEntityID'}     = $entityID;
        $regoFormPrimaryObj->{$dbfields}{'intRegoFormID'}   = $formID;

        $regoFormPrimaryObj->{$ondupfields} = ['intRegoFormID'];

        $regoFormPrimaryObj->save();
        $result{'new'} = $formID;
    }
    elsif ($action eq 'delete') {
        RegoFormPrimaryObj->delete(dbh=>$dbh, entityTypeID=>$entityTypeID, entityID=>$entityID, formID=>$formID);
        $result{'old'} = $formID;
        $result{'new'} = 0;
    }
    else {
    }

    my $content = $self->_createJSON(\%result);
    
    return $content;
}

1;
