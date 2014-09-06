#
# $Header: svn://svn/SWM/trunk/web/Reports/ReportAdvanced_ClearancesAllBelow.pm 8251 2013-04-08 09:00:53Z rlee $
#

package Reports::ReportAdvanced_ClearancesAllBelow;

use strict;
use lib ".";
use ReportAdvanced_Common;
use Reports::ReportAdvanced;
use Reports::ReportAdvanced_Clearances;
our @ISA =qw(Reports::ReportAdvanced_Clearances);


use strict;

sub _getConfiguration {
  my $self = shift;

  $self->SUPER::_getConfiguration();
  $self->{'Config'}{'SQLBuilder'} = \&SQLBuilder;
}

sub SQLBuilder  {
  my($self, $OptVals, $ActiveFields) =@_ ;
  my $currentLevel = $self->{'EntityTypeID'} || 0;
  my $Data = $self->{'Data'};
  my $clientValues = $Data->{'clientValues'};
  my $SystemConfig = $Data->{'SystemConfig'};

  my $from_levels = $OptVals->{'FROM_LEVELS'};
  my $from_list = $OptVals->{'FROM_LIST'};
  my $where_levels = $OptVals->{'WHERE_LEVELS'};
  my $where_list = $OptVals->{'WHERE_LIST'};
  my $current_from = $OptVals->{'CURRENT_FROM'};
  my $current_where = $OptVals->{'CURRENT_WHERE'};
  my $select_levels = $OptVals->{'SELECT_LEVELS'};

  my $sql = '';
  { #Work out SQL

    $where_list=' AND '.$where_list if $where_list and ($where_levels or $current_where);

	my $tempWHERE = '';
	$tempWHERE = qq[ (Temp1.int10_ID = $self->{'EntityID'} or Temp2.int10_ID = $self->{'EntityID'}) ] if ($currentLevel == 10);
	$tempWHERE = qq[ (Temp1.int20_ID = $self->{'EntityID'} or Temp2.int20_ID = $self->{'EntityID'}) ] if ($currentLevel == 20);
	$tempWHERE = qq[ (Temp1.int30_ID = $self->{'EntityID'} or Temp2.int30_ID = $self->{'EntityID'}) ] if ($currentLevel == 30);
	$tempWHERE = qq[ (Temp1.int100_ID = $self->{'EntityID'} or Temp2.int100_ID = $self->{'EntityID'}) ] if ($currentLevel == 100);

    $sql = qq[
      SELECT 
				C.*,
				DATE_FORMAT(C.dtApplied, "%d/%m/%Y") AS dtApplied,
				CP.intClearanceStatus as PathStatus,
				CP.intClearancePathID,
				M.strSurname,
				M.strFirstname,
				SourceClub.strName as SourceClubName,
				DestinationClub.strName as DestinationClubName,
				SourceAssoc.strName as SourceAssocName,
				DestinationAssoc.strName as DestinationAssocName,
				DATE_FORMAT(CP.dtAlert, "%d/%m/%Y") AS dtAlert,
				IF(dtAlert <> '00/00/0000', 1, 0) as AlertType,
				IF(dtAlert <= NOW(), 1, 0) as AlertNow,
				M.strNationalNum,
				DATE_FORMAT(M.dtDOB, "%d/%m/%Y") as dtDOB,
				DATE_FORMAT(M.dtDOB, "%Y") as dtYOB
				FROM tblClearance as C
					LEFT JOIN tblClearancePath as CP ON (
						CP.intClearanceID = C.intClearanceID AND 
						CP.intClearancePathID = C.intCurrentPathID)
					INNER JOIN tblMember as M ON (M.intMemberID = C.intMemberID)
					INNER JOIN tblAssoc as SourceAssoc ON (SourceAssoc.intAssocID = C.intSourceAssocID)
					INNER JOIN tblAssoc as DestinationAssoc ON (DestinationAssoc.intAssocID = C.intDestinationAssocID)
					LEFT JOIN tblClub as SourceClub ON (SourceClub.intClubID = C.intSourceClubID)
					LEFT JOIN tblClub as DestinationClub ON (DestinationClub.intClubID = C.intDestinationClubID)
					INNER JOIN tblTempNodeStructure as Temp1 ON (Temp1.intAssocID = C.intSourceAssocID)
					INNER JOIN tblTempNodeStructure as Temp2 ON (Temp2.intAssocID = C.intDestinationAssocID)
				WHERE 
					$tempWHERE
					AND C.intRecStatus <> -1
					AND C.intCreatedFrom = 0
					$where_list
    ];
	print STDERR $sql;
    return ($sql,'');
  }
}

1;
