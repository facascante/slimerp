package EntityStructure;

require Exporter;
@ISA       = qw(Exporter);
@EXPORT    = qw(createTempEntityStructure);
@EXPORT_OK = qw(createTempEntityStructure);

use strict;

use lib '.', '..';
use Defs;
use Utils;

sub createTempEntityStructure  {

  my ($Data, $realmID_IN) = @_;
  my $db = $Data->{'db'};

  $realmID_IN ||= 0;
  my @realms = ();
  if($realmID_IN) {
    push @realms, $realmID_IN;
  }
  else  {
    my $st = qq[
      SELECT 
        intRealmID
      FROM 
        tblRealms
    ];
    my $qry = $db->prepare($st);
    $qry->execute();
    while (my($intRealmID) = $qry->fetchrow_array) {
        push @realms, $intRealmID;
    }
  }

  my $ins_st = qq[
    INSERT IGNORE INTO tblTempEntityStructure (
        intRealmID, 
        intParentID,
        intParentLevel,
        intChildID,
        intChildLevel,
        intDirect,
        intDataAccess,
        intPrimary
    )
    VALUES (
        ?,
        ?,
        ?,
        ?,
        ?,
        ?,
        ?,
        ?
    )
  ];
  my $ins_qry= $db->prepare($ins_st);

  my $del_st = qq[
    DELETE FROM 
        tblTempEntityStructure
    WHERE 
      intRealmID = ?
  ];

  my $del_qry= $db->prepare($del_st);

  my $st_e = qq[
    SELECT
      intEntityID,
      intEntityLevel,
      intDataAccess
    FROM
      tblEntity
    WHERE
      intRealmID = ?
      AND strStatus <> 'DELETED'
  ];
  my $q_e = $db->prepare($st_e);


  foreach my $realmID (@realms) {
    $del_qry->execute($realmID);
    $del_qry->finish();

    my %entities = ();
    $q_e->execute($realmID);
    while (my($id, $level, $dataaccess) = $q_e->fetchrow_array()) {
      $entities{$id} = {
          level => $level,
          dataaccess => $dataaccess,
      };
    }

    my $entity_list = join(',',keys %entities);
    my %entityLinks = ();
    if($entity_list)  {
      my $st_el = qq[
        SELECT
          intParentEntityID,
          intChildEntityID,
          intPrimary
        FROM
          tblEntityLinks
        WHERE
            intParentEntityID IN ($entity_list)
      ];
      my $q_el = $db->prepare($st_el);
      $q_el->execute();
      while (my($parent, $child, $primary) = $q_el->fetchrow_array()) {
        if(
            $parent 
            and $child 
            and exists($entities{$parent})
            and exists($entities{$child})
        )    {
          push @{$entityLinks{$parent}}, $child; 
          #Insert the direct relationships
          $ins_qry->execute(
              $realmID,
              $parent,
              $entities{$parent}{'level'},
              $child,
              $entities{$child}{'level'},
              1,
              $entities{$child}{'dataaccess'},
              $primary
          );
        }
      }
    }

    #Now to generate and insert the indirect relationships
    foreach my $entityID (keys %entities)    {
      insertRelationships(
          $entityID,
          \%entities,
          \%entityLinks,
          $ins_qry, 
          $realmID,
      );
    }
  }
}

sub insertRelationships {
    my  (
        $entityID,
        $entities,
        $entityLinks,
        $qry,
        $realmID,
    ) = @_;

    my @children = ();
    my $myDataAccess = $entities->{$entityID}{'dataaccess'};
    if(exists($entityLinks->{$entityID})) {
      foreach my $childID (@{$entityLinks->{$entityID}}) {
          push @children, {
            id => $childID,
            dataaccess => $entities->{$childID}{'dataaccess'},
          };
          my $ret = insertRelationships(
            $childID,
            $entities,
            $entityLinks,
            $qry,
            $realmID,
          );
          push @children, @{$ret} if $ret;
      }
      foreach my $child (@children) {
          $qry->execute(
              $realmID,
              $entityID,
              $entities->{$entityID}{'level'},
              $child->{'id'},
              $entities->{$child->{'id'}}{'level'},
              0,
              $child->{'dataaccess'},
              $child->{'primary'},
          );
          if($myDataAccess < $child->{'dataaccess'})  {
            $child->{'dataaccess'} = $myDataAccess;
          }
      }

    }
    return \@children;
}

