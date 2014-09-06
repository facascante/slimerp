#
# $Header: svn://svn/SWM/trunk/web/Reports/ReportAdvanced_Duplicates.pm 8251 2013-04-08 09:00:53Z rlee $
#

package Reports::ReportAdvanced_Duplicates;

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
	my $clientValues = $Data->{'clientValues'};
	my $CommonVals = getCommonValues(
		$Data,
		{
			SubRealms => 1,
		},
	);

	my %config = (
		Name => 'Duplicates Report',

		StatsReport => 1,
		MemberTeam => 0,
		ReportEntity => 1,
		ReportLevel => 0,
		Template => 'default_adv',
    TemplateEmail => 'default_adv_CSV',
		DistinctValues => 1,
    SQLBuilder => \&SQLBuilder,

		Fields => {
			strAssocName => [
				$Data->{'LevelNames'}{$Defs::LEVEL_ASSOC}.' Name',
				{
					displaytype=>'text',
					fieldtype=>'text',
					allowsort=>1,
					active=>1,
					dbfield=>'tblAssoc.strName',
					enabled => $clientValues->{assocID}==-1,
					allowgrouping=>1,
				}
			],

			intAssocTypeID=> [
				$Data->{'LevelNames'}{$Defs::LEVEL_ASSOC}.' Type',
				{
					displaytype=>'lookup',
					fieldtype=>'dropdown',
					dropdownoptions=> $CommonVals->{'SubRealms'},
					allowsort=>1,
					enabled => (scalar(keys %{$CommonVals->{'SubRealms'}}) and  $currentLevel > $Defs::LEVEL_ASSOC),
					allowgrouping=>1,
				}
			],

			strZoneName=> [
				$Data->{'LevelNames'}{$Defs::LEVEL_ZONE}.' Name',
				{
					displaytype=>'text',
					fieldtype=>'text',
					allowsort=>1,
					dbfield => "IF(tblZone.intStatusID = $Defs::NODE_SHOW, tblZone.strName, '')",
					allowgrouping=>1,
					active=>1,
					enabled => $currentLevel > $Defs::LEVEL_ZONE,
				}
			],

			strRegionName=> [
				$Data->{'LevelNames'}{$Defs::LEVEL_REGION}.' Name',
				{
					displaytype=>'text',
					fieldtype=>'text',
					allowsort=>1,
					dbfield => "IF(tblRegion.intStatusID = $Defs::NODE_SHOW, tblRegion.strName, '')",
					allowgrouping=>1,
					active=>1,
					enabled => $currentLevel > $Defs::LEVEL_REGION,
				}
			],

			strStateName=> [
				$Data->{'LevelNames'}{$Defs::LEVEL_STATE}.' Name',
				{
					displaytype=>'text',
					fieldtype=>'text',
					allowsort=>1,
					dbfield => "IF(tblState.intStatusID = $Defs::NODE_SHOW, tblState.strName, '')",
					allowgrouping=>1,
					active=>1,
					enabled => $currentLevel > $Defs::LEVEL_STATE,
				}
			],

			strNationalName=> [
				$Data->{'LevelNames'}{$Defs::LEVEL_NATIONAL}.' Name',
				{
					displaytype=>'text',
					fieldtype=>'text',
					allowsort=>1,
					dbfield => "IF(tblNational.intStatusID = $Defs::NODE_SHOW, tblNational.strName, '')",
					allowgrouping=>1,
					active=>1,
					enabled => $currentLevel > $Defs::LEVEL_NATIONAL,
				}
			],

			strIntZoneName=> [
				$Data->{'LevelNames'}{$Defs::LEVEL_INTZONE}.' Name',
				{
					displaytype=>'text',
					fieldtype=>'text',
					allowsort=>1,
					dbfield => "IF(tblIntZone.intStatusID = $Defs::NODE_SHOW, tblIntZone.strName, '')" ,
					allowgrouping=>1,
					active=>1,
					enabled => $currentLevel > $Defs::LEVEL_INTZONE,
				}
			],

			strIntRegionName=> [
				$Data->{'LevelNames'}{$Defs::LEVEL_INTREGION}.' Name',
				{
					displaytype=>'text',
					fieldtype=>'text',
					allowsort=>1,
					dbfield => " IF(tblIntRegion.intStatusID = $Defs::NODE_SHOW, tblIntRegion.strName, '') ",
					allowgrouping=>1,
					active=>1,
					enabled => $currentLevel > $Defs::LEVEL_INTREGION,
				}
			],
			numMembers=> ["Number of Duplicates to be Resolved",{displaytype=>'none', fieldtype=>'text', active=>1, dbfield => 'COUNT(tblMember.intMemberID)', total=>1, allowsort=>1}],
		},

		Order => [qw(
			numMembers
			strAssocName
			intAssocTypeID
			strZoneName
			strRegionName
			strStateName
			strNationalName
			strIntZoneName
			strIntRegionName
		)],
		OptionGroups => {
			default => ['Details',{}],
		},

		Config => {
			FormFieldPrefix => 'c',
			FormName => 'duplform_',
			EmailExport => 1,
			limitView  => 5000,
			EmailSenderAddress => $Defs::admin_email,
			SecondarySort => 1,
			RunButtonLabel => 'Run Report',
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

    $where_list=' AND '.$where_list if $where_list and ($where_levels or $current_where);
		my $groupfields = '';
		my @grouping = ();
    push @grouping, 'tblIntRegion.strName' if ($currentLevel > $Defs::LEVEL_INTREGION and $ActiveFields->{'strIntRegionName'});
    push @grouping, 'tblIntZone.strName' if ($currentLevel > $Defs::LEVEL_INTZONE and $ActiveFields->{'strIntZoneName'});
    push @grouping, 'tblNational.strName' if ($currentLevel > $Defs::LEVEL_NATIONAL and $ActiveFields->{'strNationalName'});
    push @grouping, 'tblState.strName' if ($currentLevel > $Defs::LEVEL_REGION and $ActiveFields->{'strStateName'});
    push @grouping, 'tblRegion.strName' if ($currentLevel > $Defs::LEVEL_ZONE and $ActiveFields->{'strRegionName'});
    push @grouping, 'tblZone.strName' if ($currentLevel > $Defs::LEVEL_ASSOC and $ActiveFields->{'strZoneName'});
    push @grouping, 'tblAssoc.strName' if ($currentLevel > $Defs::LEVEL_ASSOC and $ActiveFields->{'strAssocName'});

    my $grp_line=join(',',@grouping) || '';
    $grp_line="GROUP BY $grp_line" if $grp_line;

    $sql = qq[
      SELECT ###SELECT###
      FROM $from_levels $current_from $from_list 
      WHERE  $where_levels $current_where $where_list 
       AND tblMember.intStatus=$Defs::MEMBERSTATUS_POSSIBLE_DUPLICATE
			$grp_line
    ];
    return ($sql,'');
  }
}

1;
