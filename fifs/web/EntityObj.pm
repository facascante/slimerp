package EntityObj;

use strict;
use BaseObject;
our @ISA =qw(BaseObject);

sub load {
  my $self = shift;

  my $st=qq[
    SELECT * 
    FROM tblEntity
    WHERE intEntityID = ?
  ];

  my $q = $self->{'db'}->prepare($st);
  $q->execute($self->{'ID'});
  if($DBI::err)  {
    $self->LogError($DBI::err);
  }
  else  {
    $self->{'DBData'}=$q->fetchrow_hashref();  
  }
}

sub name {
  my $self = shift;
    my($db) = @_;
    return $self->{'DBData'}{'strLocalName'} 
        || $self->{'DBData'}{'strLatinName'} 
        || '';
}

sub delete {
  my $self = shift;

  if ($self->canDelete()) {
    my @errors = ();
    my $db = $self->{'db'};
    my $st = qq[
      UPDATE tblEntity
      SET strStatus = 'DELETED'
      WHERE 
          intEntityID = ?
      LIMIT 1
    ];
    my $q = $db->prepare($st);
    $q->execute($self->ID());
    $q->finish();
    if ($db->err()) {
        push @errors, $db->errstr();
    }
    if (scalar @errors) {
        return "ERROR:";
    }
    else {
        return 1;
    }
  }
  else {
      return 0;
  }
}

sub canDelete {
  my $self = shift;

  my $st = qq[
    SELECT COUNT(*)
    FROM 
        tblEntityLinks AS EL
        INNER JOIN tblEntity AS E 
            ON EL.intChildEntityID = E.intEntityID
    WHERE
        EL.intParentEntityID = ?
        AND E.strStatus <> 'DELETED'
  ];
  my $q = $self->{'db'}->prepare($st);
  $q->execute($self->{'ID'});
  my ($cnt) = $q->fetchrow_array();
  $q->finish();
  return !$cnt;
}

1;
