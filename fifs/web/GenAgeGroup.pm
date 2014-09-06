#
# $Header: svn://svn/SWM/trunk/web/GenAgeGroup.pm 8251 2013-04-08 09:00:53Z rlee $
#

package GenAgeGroup;

use lib "../web";
use strict;
use Utils;
use SystemConfig;

#This code generates the grade that a member should be in
# NB This code requires that only one instance is running at one time or concurrency issues may occur.

sub new {

  my $this = shift;
  my $class = ref($this) || $this;
  my ($db, $realm, $realmSubTypeID, $overide_interval) = @_;
  my %fields=();
  $fields{db}=$db || '';
  $fields{availablenums}=();
  $fields{'realm'}=$realm || '';
  $fields{'realmSubTypeID'}=$realmSubTypeID || 0;

  my $realmSubType_SQL = '';
  if ($realmSubTypeID and $realmSubTypeID > 0) {
    $realmSubType_SQL = qq[ AND intRealmSubTypeID IN (0, $realmSubTypeID) ];
  }

  my %Data=();
  $Data{'db'} = $db;
  $Data{'Realm'} = $fields{'realm'} || 0;
  $Data{'RealmSubType'} = $fields{'realmSubTypeID'} || 0;
  $Data{'SystemConfig'} = getSystemConfig(\%Data);
	
	my $orderBy = qq[  ORDER BY DOBEnd ASC, DOBStart ASC, intRealmSubTypeID, intAgeGroupGender, intAgeGroupID ];
	if ($Data{'SystemConfig'}{'AgeGroup_OrderOverride'})	{
		$orderBy = qq[  ORDER BY intRealmSubTypeID DESC, DOBEnd ASC, DOBStart ASC, intAgeGroupGender, intAgeGroupID ];
	}

	#Setup Values
	my $statement=qq[
		SELECT intAgeGroupID, DATE_FORMAT(dtDOBStart, "%Y%m%d") as DOBStart, DATE_FORMAT(dtDOBEnd, "%Y%m%d") as DOBEnd, intAgeGroupGender
		FROM tblAgeGroups
		WHERE intRealmID = $realm
			AND intRecStatus = 1
      $realmSubType_SQL
		$orderBy
	];

  if ($overide_interval) {
	  $statement = qq[
      SELECT 
        intAgeGroupID, 
        DATE_FORMAT(DATE_SUB(dtDOBStart, INTERVAL $overide_interval YEAR), "%Y%m%d") as DOBStart, 
        DATE_FORMAT(DATE_SUB(dtDOBEnd, INTERVAL $overide_interval YEAR), "%Y%m%d") as DOBEnd, 
        intAgeGroupGender
      FROM 
        tblAgeGroups
      WHERE 
        intRealmID = $realm
        AND intRecStatus = 1
        $realmSubType_SQL
      $orderBy
    ];
  }

	my $query=$db->prepare($statement) or query_error($statement);
	$query->execute or query_error($statement);
	while (my $dref = $query->fetchrow_hashref())	{
		push @{$fields{'AgeGroups'}}, [$dref->{intAgeGroupID}, $dref->{intAgeGroupGender}, $dref->{DOBStart}, $dref->{DOBEnd}];
	}
	$query->finish();

	my $self={%fields};
  bless $self, $class;
  ##bless selfhash to GenCode;
  ##return the blessed hash
  return $self;
}


sub getAgeGroup	{
	#return a members grade

	my $self = shift;
	my($gender, $dob) = @_;

	$gender ||= 0;
	$dob ||= 0;

	for my $ageGroup (@{$self->{'AgeGroups'}})	{
		if ((! $gender or ! $ageGroup->[1] or $gender == $ageGroup->[1] or $ageGroup->[1] == $Defs::GENDER_MIXED) and $dob >= $ageGroup->[2] and $dob <= $ageGroup->[3])	{
			return $ageGroup->[0];
		}
	}
	return 0;
	
}
1;
