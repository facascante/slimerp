#
# $Header: svn://svn/SWM/trunk/web/locator/FinderCustom.pm 10138 2013-12-03 20:24:41Z tcourt $
#

package FinderCustom;

require Exporter;
@ISA =  qw(Exporter);
@EXPORT = qw(get_custom_sql);
@EXPORT_OK = qw(get_custom_sql);

use strict;
use lib ".", "..", "../..";
use DBI;
use CGI qw(:standard escape param);
use DeQuote;
use FormHelpers;
use Contacts;
use FinderDefs;

sub get_custom_sql {
  my ($realmID, $subRealmID, $club_WHERE, $sub_realm_WHERE, $dob_WHERE) = @_;
  if ($realmID == $FinderDefs::REALM_AFL) {
    return _afl_sql($realmID, $subRealmID, $club_WHERE, $sub_realm_WHERE, $dob_WHERE);
  }
  return ($subRealmID, $club_WHERE, $sub_realm_WHERE, $dob_WHERE);
}

sub _afl_sql {
  my ($realmID, $subRealmID, $club_WHERE, $sub_realm_WHERE, $dob_WHERE) = @_;
	my $yob_IN = param('yob') || '';
  if ($yob_IN)  {
    if($yob_IN < 100)  {
      $yob_IN+=2000;
    }
    my $year = (localtime)[5];
    $year += 1900;
    if ($yob_IN >= ($year - 7)) { ## If 8 or under show only Auskick, need to work out how to do this for all codes.
      $subRealmID = 2;
      $dob_WHERE = qq[ AND A.intAssocTypeID = 2]; ## If 8 years or under show only Auskick
      $club_WHERE = qq[ AND S.intClubID=0];
      $sub_realm_WHERE = '';
    }
    elsif ($yob_IN >= ($year - 12)) {
      $subRealmID = 0;
      $sub_realm_WHERE = '';
      $dob_WHERE = '' ;
      $club_WHERE = qq[AND (S.intClubID > 0  OR A.intAssocTypeID = 2) AND ASPC.intClubID = S.intClubID];
    }
    else  {
      if ($subRealmID !~ /8|9/) {
        $subRealmID = 0;
        $sub_realm_WHERE = '';
      }
      $club_WHERE = qq[ AND S.intClubID > 0 AND A.intAssocTypeID <> 2 AND ASPC.intClubID = S.intClubID];
    }
  }
  return ($subRealmID, $club_WHERE, $sub_realm_WHERE, $dob_WHERE);
}

1;
