#!/usr/bin/perl -w

#
# $Header: svn://svn/SWM/trunk/automatic/coaches_maintenance.pl 8250 2013-04-08 08:24:36Z rlee $
#

use lib "../web","..";
use Defs;
use Utils;
use DBI;
use strict;
use SystemConfig;

my $realm = 2; 

my %Data = ();
my $db = connectDB();
$Data{'db'} = $db;
$Data{'Realm'} = $realm;
$Data{'SystemConfig'} = getSystemConfig(\%Data);

if ($Data{'SystemConfig'}{'AddCoachExpiryInterval'} and $Data{'SystemConfig'}{'AddCoachExpiryAssoc'}) {
  my $st_update_expiry = qq[
    UPDATE 
      tblMember_Types 
    SET 
      dtDate2 = dtDate1 $Data{'SystemConfig'}{'AddCoachExpiry'} 
    WHERE 
      intAssocID IN (?) 
      AND intSubTypeID = 1 
      AND dtDate1 IS NOT NULL
      AND dtDate2 IS NULL
  ];
  my $q_update_expiry = $db->prepare($st_update_expiry);
  $q_update_expiry->execute($Data{'SystemConfig'}{'AddCoachExpiryAssoc'});
}

if ($Data{'SystemConfig'}{'MakeCoachesInactive'} and $Data{'SystemConfig'}{'MakeCoachesInactiveAssoc'}) {
  my $st_update_inactive = qq[
    UPDATE
      tblMember_Types
    SET
      intActive = 0
    WHERE
      intAssocID IN (?)
      AND intSubTypeID = 1
      AND intActive = 1
      AND dtDate2 < now()
  ];
  my $q_update_inactive = $db->prepare($st_update_inactive);
  $q_update_inactive->execute($Data{'SystemConfig'}{'MakeCoachesInactiveAssoc'});
}
