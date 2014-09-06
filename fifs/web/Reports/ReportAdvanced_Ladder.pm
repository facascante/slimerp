#
# $Header: svn://svn/SWM/trunk/web/Reports/ReportAdvanced_Fixture.pm 8251 2013-04-08 09:00:53Z rlee $
#

package Reports::ReportAdvanced_Ladder;

use strict;
use lib ".";
use ReportAdvanced_Common;
use Reports::ReportAdvanced;
our @ISA =qw(Reports::ReportAdvanced);


use strict;

sub _getConfiguration {
	my $self = shift;

	my $currentLevel = $self->{'EntityTypeID'} || 0;
	my $Data = $self->{'Data'};
	my $SystemConfig = $self->{'SystemConfig'};
	my $clientValues = $Data->{'clientValues'};

  my $txt_SeasonName= $Data->{'SystemConfig'}{'txtSeason'} || 'Season';
  my $txt_SeasonNames= $Data->{'SystemConfig'}{'txtSeasons'} || 'Seasons';
  my $txt_AgeGroupName= $Data->{'SystemConfig'}{'txtAgeGroup'} || 'Age Group';
  my $txt_AgeGroupNames= $Data->{'SystemConfig'}{'txtAgeGroups'} || 'Age Groups';

  my $CommonVals = getCommonValues(
    $Data,
    {
      DefCodes => 1,
      AgeGroups => 1,
			Seasons => 1,
			Grades => 1,
    },
  );
  my $hideSeasons = $CommonVals->{'Seasons'}{'Hide'} || 0;
  my %NRO=();
  $NRO{'Accreditation'}= (
    ($clientValues->{assocID} >0
      or $clientValues->{clubID} > 0)
    ? 1
    :0
    )
    || $SystemConfig->{'RepAccred'} || 0; #National Report Options 
  $NRO{'RepCompLevel'}= (
      ($clientValues->{assocID} >0
        or $clientValues->{clubID} > 0) ? 1 :0)
      || $SystemConfig->{'RepCompLevel'} || 0; #National Report Options


	my %config = (
	 SQL => "No SQL",
  ReportEntity => 0,
  Template => 'ladder',
	Name => 'Ladder Report',
		StatsReport => 0,
		MemberTeam => 0,
		ReportLevel => 0,
		DistinctValues => 1,
			 SQLBuilder => \&SQLBuilder,
			DataFromFunction => 'ReportData_CustomLadder::ladder_report',
		Fields => {
        intNewSeasonID => ["$txt_SeasonName",{filteronly=> 1,displaytype=>'lookup', fieldtype=>'dropdown', dropdownoptions => $CommonVals->{'Seasons'}{'Options'},  dropdownorder=>$CommonVals->{'Seasons'}{'Order'},  active=>0, multiple=>1, size=>3, dbfield=>"intNewSeasonID", disable=>$hideSeasons, defaultcomp=>'equal', defaultvalue=>$CommonVals->{'Seasons'}{'Current'} }],
        strTitle => ["Competition Name",{filteronly=>1,displaytype=>'text', fieldtype=>'text', active=>1 }],

		},
		Order => [qw(
			intNewSeasonID 
			strTitle 
		)],
    OptionGroups => {
      default => ['Details',{}],
			competition => ['Competition Details',{}],
    },

		Config => {
			FormFieldPrefix => 'c',
			FormName => 'clearform_',
			limitView  => 5000,
			EmailSenderAddress => $Defs::admin_email,
			RunButtonLabel => 'Run Report',
			ReturnProcessData => [qw(tblTeam.strEmail tblTeam.strName)],
		},
	);
	$self->{'Config'} = \%config;
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

	if ($currentLevel == $Defs::LEVEL_TEAM) {
      $sql= qq[
        SELECT DISTINCT
                                        Comp.intDisplayLadder,
                                        Comp.strTitle,
                                        Comp.intCompID,
                                        CP.intCompPoolID as poolID,
                CP.intStageID as stageID
        FROM
          tblAssoc_Comp AS Comp
                LEFT JOIN tblComp_Pools as CP ON (CP.intCompID=Comp.intCompID AND CP.intRecStatus<>-1)
                                        INNER JOIN tblComp_Teams AS CT
                                                ON Comp.intCompID = CT.intCompID
        WHERE
					$where_list
                                        AND Comp.intAssocID = $Data->{'clientValues'}{'assocID'}
                                        AND Comp.intStatus <> -1
                                        AND CT.intRecStatus = 1
                                        AND CT.intTeamID = $Data->{'clientValues'}{'teamID'}
                                ORDER BY
                                        Comp.intOrder ASC, Comp.strTitle
      ];
    }
    elsif ($currentLevel == $Defs::LEVEL_CLUB) {
      $sql= qq[
        SELECT DISTINCT
                                        Comp.intDisplayLadder,
                                        Comp.strTitle,
                                        Comp.intCompID,
                                        CP.intCompPoolID as poolID,
                CP.intStageID as stageID
        FROM
          tblAssoc_Comp AS Comp
                LEFT JOIN tblComp_Pools as CP ON (CP.intCompID=Comp.intCompID AND CP.intRecStatus<>-1)
                                        INNER JOIN tblComp_Teams AS CT
                                                ON Comp.intCompID = CT.intCompID
                                        INNER JOIN tblTeam AS T
                                                ON CT.intTeamID = T.intTeamID
        WHERE
					$where_list
                                        AND Comp.intAssocID = $Data->{'clientValues'}{'assocID'}
                                        AND Comp.intStatus <> -1
                                        AND CT.intRecStatus = 1
                                        AND T.intClubID = $Data->{'clientValues'}{'clubID'}
                                ORDER BY
                                        Comp.intOrder ASC, Comp.strTitle
      ];
    }
    elsif ($currentLevel == $Defs::LEVEL_ASSOC) {
      $sql= qq[
        SELECT DISTINCT
                                        Comp.intDisplayLadder,
                                        Comp.strTitle,
                                        Comp.intCompID,
                                        CP.intCompPoolID as poolID,
                CP.intStageID as stageID
        FROM
          tblAssoc_Comp AS Comp
                LEFT JOIN tblComp_Pools as CP ON (CP.intCompID=Comp.intCompID AND CP.intRecStatus<>-1)
        WHERE
					$where_list
                                        AND Comp.intAssocID = $Data->{'clientValues'}{'assocID'}
                                        AND Comp.intStatus <> -1
                                ORDER BY
                                        Comp.intOrder ASC, Comp.strTitle
      ];
    }
    elsif ($currentLevel == $Defs::LEVEL_COMP) {
      $sql= qq[
        SELECT DISTINCT
                                        Comp.intDisplayLadder,
                                        Comp.strTitle,
                                        Comp.intCompID,
                                        CP.intCompPoolID as poolID,
                CP.intStageID as stageID
        FROM
          tblAssoc_Comp AS Comp
                LEFT JOIN tblComp_Pools as CP ON (CP.intCompID=Comp.intCompID AND CP.intRecStatus<>-1)
        WHERE
					$where_list
                                        AND Comp.intCompID = $Data->{'clientValues'}{'compID'}
                                ORDER BY
                                        Comp.intOrder ASC, Comp.strTitle
      ];
    }
    else {
        return '';
    }

	$self->{'Data'}{'sql'} = $sql;
    return ($sql,'');
  }
}

