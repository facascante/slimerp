#
# $Header: svn://svn/SWM/trunk/web/Reports/ReportAdvanced_Tribunal.pm 8863 2013-07-05 03:42:35Z dhanslow $
#

package Reports::ReportAdvanced_Tribunal;

use strict;
use lib ".";
use ReportAdvanced_Common;
use Reports::ReportAdvanced;
use Reg_common;
our @ISA =qw(Reports::ReportAdvanced);


use strict;

sub _getConfiguration {
	my $self = shift;

	my $currentLevel = $self->{'EntityTypeID'} || 0;
	my $Data = $self->{'Data'};
	my $SystemConfig = $self->{'SystemConfig'};
	my $clientValues = $Data->{'clientValues'};

  my $txt_Tribunal= $SystemConfig->{'txtTribunal'} || 'Tribunal';
  my $natnumname=$SystemConfig->{'NationalNumName'} || 'National Number';

  my $CommonVals = getCommonValues(
    $Data,
    {
      DefCodes => 1,
      AgeGroups => 1,
    },
  );

	my %config = (
		Name => 'Tribunal Report',

		StatsReport => 0,
		MemberTeam => 0,
		ReportEntity => 3,
		ReportLevel => 0,
		Template => 'default_adv',
    TemplateEmail => 'default_adv_CSV',
		DistinctValues => 1,
    SQLBuilder => \&SQLBuilder,

		Fields => {
			 TribunalID => ["$txt_Tribunal ID",{displaytype=>'text', fieldtype=>'text', dbfield=>'tblTribunal.intTribunalID', active=>1}],

      strNationalNum=> [$natnumname,{displaytype=>'text', fieldtype=>'text', allowsort=>1, dbfield=>'tblMember.strNationalNum', allowgrouping=>1,active=>1}],

      strFirstname=> ["First name",{displaytype=>'text', fieldtype=>'text', active=>1, allowsort=>1, dbfield => 'tblMember.strFirstname'}],
      strSurname=> ["Family name",{displaytype=>'text', fieldtype=>'text', active=>1, allowsort=>1, dbfield => 'tblMember.strSurname'}],
      dtDOB=> ['Date of Birth',{displaytype=>'date', fieldtype=>'date', dbfield=>'tblMember.dtDOB', dbformat=>' DATE_FORMAT(tblMember.dtDOB,"%d/%m/%Y")'}, active=>1],

			AssocName=> ["$Data->{'LevelNames'}{$Defs::LEVEL_ASSOC} Name",{displaytype=>'text', allowgrouping=>1, fieldtype=>'text', active=>1, allowsort=>1, dbfield => 'tblAssoc.strName', active=>1}],
			TeamName=> ["$Data->{'LevelNames'}{$Defs::LEVEL_TEAM} Name",{displaytype=>'text', allowgrouping=>1, fieldtype=>'text', active=>1, allowsort=>1, dbfield => 'tblTeam.strName', active=>1}],
			ClubName=> ["$Data->{'LevelNames'}{$Defs::LEVEL_CLUB} Name",{displaytype=>'text', allowgrouping=>1, fieldtype=>'text', active=>1, allowsort=>1, dbfield => 'tblClub.strName',active=>1}],
			CompName=> ["$Data->{'LevelNames'}{$Defs::LEVEL_COMP} Name",{displaytype=>'text',  allowgrouping=>1, fieldtype=>'text', allowsort=>1, dbfield=>'tblAssoc_Comp.strTitle'}],

			DateCharged => ['Date Charged',{displaytype=>'date',  allowgrouping=>1, fieldtype=>'date', allowsort=>1,dbfield=>'tblTribunal.dtCharged', dbformat=>' DATE_FORMAT(tblTribunal.dtCharged, "%d/%m/%Y")',active=>1}],
			VenueName=> ["Venue Name",{displaytype=>'text',  allowgrouping=>1, fieldtype=>'text', allowsort=>1, dbfield=>'tblDefVenue.strName'}],

			DateHearing  => ['Date Hearing',{displaytype=>'date', fieldtype=>'date', allowsort=>1,dbfield=>'tblTribunal.dtHearing',  dbformat=>' DATE_FORMAT(tblTribunal.dtHearing, "%d/%m/%Y")',active=>1}],

			intTribunalAgeGroupID=> ['Grade' ,{displaytype=>'lookup', fieldtype=>'dropdown', dropdownoptions=>$CommonVals->{'AgeGroups'}{'Options'},  dropdownorder=>$CommonVals->{'AgeGroups'}{'Order'}, active=>1}],
			intChargeID=>['Offence',{displaytype=>'lookup',  allowgrouping=>1, fieldtype=>'dropdown', dropdownoptions=>$CommonVals->{'DefCodes'}{-13}, active=>1, multiple=>1}],
			intCharge2ID=>['Offence 2',{displaytype=>'lookup', fieldtype=>'dropdown', dropdownoptions=>$CommonVals->{'DefCodes'}{-13}, multiple=>1}],
			intCharge3ID=>['Offence 3',{displaytype=>'lookup', fieldtype=>'dropdown', dropdownoptions=>$CommonVals->{'DefCodes'}{-13}, multiple=>1}],
			strOffence => ['Offence (Other/SWC)', {displaytype=>'text', allowgrouping=>1, fieldtype=>'text', allowsort=>1, dbfield=>'tblTribunal.strOffence'}],
			ChargeGrading=>['Charge Grading',{displaytype=>'text', fieldtype=>'text', allowsort=>1,dbfield=>'tblTribunal.strChargeGrading'}],
			Outcome=>['Outcome',{displaytype=>'text', fieldtype=>'text', allowsort=>1,dbfield=>'tblTribunal.strOutcome', active=>1}],
			PenaltyType=>['Penalty (Type)',{displaytype=>'lookup', fieldtype=>'dropdown', dropdownoptions=>\%Defs::TribunalTypes, allowsort=>1,dbfield=>'tblTribunal.strPenaltyType', active=>1}],

			PenaltyUnit=>['Penalty (Units)',{displaytype=>'text', fieldtype=>'text', allowsort=>1,dbfield=>'tblTribunal.intPenalty', active=>1, total=>1}],
			SuspendedFrom=>['Penalty Start Date',{displaytype=>'date', fieldtype=>'date', allowsort=>1,dbfield=>'tblTribunal.dtPenaltyStartDate', dbformat=>' DATE_FORMAT(tblTribunal.dtPenaltyStartDate, "%d/%m/%Y")',active=>1}],
			PenaltyExpDate=>['Penalty Exp Date',{displaytype=>'date', fieldtype=>'date', allowsort=>1,dbfield=>'tblTribunal.dtPenaltyExp', dbformat=>' DATE_FORMAT(tblTribunal.dtPenaltyExp, "%d/%m/%Y")',active=>1}],
			SuspendedPenaltyType=>['Suspended Penalty (Type)',{displaytype=>'lookup', fieldtype=>'dropdown', dropdownoptions=>\%Defs::TribunalTypes, allowsort=>1,dbfield=>'tblTribunal.strSuspendedPenaltyType', active=>1}],
			SuspendedPenaltyUnit=>['Suspended Penalty (Units)',{displaytype=>'text', fieldtype=>'text', allowsort=>1,dbfield=>'tblTribunal.intSuspendedPenalty', active=>1, total=>1}],
			Reporter=>['Reporter',{displaytype=>'text', fieldtype=>'text', allowsort=>1,dbfield=>'tblTribunal.strReporter'}],
			Witness=>['Witness',{displaytype=>'text', fieldtype=>'text', allowsort=>1,dbfield=>'tblTribunal.strWitness'}],
			Notes=>['Notes',{displaytype=>'text', fieldtype=>'text', allowsort=>1,dbfield=>'tblTribunal.strNotes'}],
		},
		Order => [qw(
			TribunalID
			strNationalNum
			dtDOB
			strSurname
			strFirstname
			AssocName
			ClubName
			CompName
			TeamName
			VenueName
			intTribunalAgeGroupID
			Reporter
			Witness
			DateCharged
			DateHearing
			intChargeID
			intCharge2ID
			intCharge3ID
			strOffence
			ChargeGrading
			Outcome
			PenaltyType
			PenaltyUnit
			PenaltyExpDate
			SuspendedFrom
			SuspendedTo
			SuspendedPenaltyType
			SuspendedPenaltyUnit
			Notes
		)],
    OptionGroups => {
      default => ['Details',{}],
    },

		Config => {
			FormFieldPrefix => 'c',
			FormName => 'clearform_',
			EmailExport => 1,
			limitView  => 5000,
			EmailSenderAddress => $Defs::admin_email,
			SecondarySort => 1,
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

    $where_list=' AND '.$where_list if $where_list and ($where_levels or $current_where);

    my $where = qq[ $where_levels $current_where $where_list ];
		my $from = '';

		my $whereand = '';
		my $extraWHERE = '';

		if ($where_list) {
			$whereand = 'WHERE ';
		}

		if ($currentLevel == $Defs::LEVEL_TEAM) {
			$from .= qq[
				INNER JOIN tblMember ON (
                                        tblMember.intMemberID = tblTribunal.intMemberID)
				INNER JOIN tblMember_Teams ON (tblMember_Teams.intMemberID = tblTribunal.intMemberID
								AND tblMember_Teams.intTeamID = $clientValues->{'teamID'}
                                                                                AND tblMember_Teams.intStatus = $Defs::RECSTATUS_ACTIVE)
			];
=c
			$from .= qq [ 
				INNER JOIN tblMember ON (
					tblMember.intMemberID = tblTribunal.intMemberID
						AND (
							(
								tblTribunal.intMemberID IN (
									SELECT intMemberID 
									FROM tblMember_Teams
									WHERE tblMember_Teams.intTeamID = $clientValues->{'teamID'}
										AND tblMember_Teams.intStatus = $Defs::RECSTATUS_ACTIVE
																								
								)
							)
							OR (
								tblTribunal.intTeamID = $clientValues->{'teamID'}
							)
					)
				)
			];
=cut
		}
		elsif ($currentLevel == $Defs::LEVEL_CLUB) {
			$from .= qq [ 
                                INNER JOIN tblMember ON (
                                        tblMember.intMemberID = tblTribunal.intMemberID)
				INNER JOIN tblMember_Clubs ON (tblMember_Clubs.intMemberID = tblTribunal.intMemberID
								AND tblMember_Clubs.intClubID = $clientValues->{'clubID'}
                                                                                AND tblMember_Clubs.intStatus = $Defs::RECSTATUS_ACTIVE)
			];	 
=ut			$from .= qq [ 
				INNER JOIN tblMember ON (
					tblMember.intMemberID = tblTribunal.intMemberID
						AND (
							(
								tblTribunal.intMemberID IN (
									SELECT intMemberID 
									FROM tblMember_Clubs
									WHERE tblMember_Clubs.intClubID = $clientValues->{'clubID'}
										AND tblMember_Clubs.intStatus = $Defs::RECSTATUS_ACTIVE
								)
							)
							OR (
								tblTribunal.intClubID = $clientValues->{'clubID'}
							)
					)
				)
			];
=cut
		}
		elsif ($currentLevel == $Defs::LEVEL_ASSOC) {
			$from .= qq[
				INNER JOIN tblMember ON (tblMember.intMemberID = tblTribunal.intMemberID)
				INNER JOIN tblMember_Associations ON(tblMember_Associations.intMemberID = tblTribunal.intMemberID
									AND tblMember_Associations.intAssocID = $clientValues->{'assocID'}
                                                                        AND tblMember_Associations.intRecStatus = $Defs::RECSTATUS_ACTIVE
				)
			];
=comment
			$from .= qq [ 
				INNER JOIN tblMember ON (
					tblMember.intMemberID = tblTribunal.intMemberID
						AND (
							(
								tblTribunal.intMemberID IN (
									SELECT intMemberID 	
									FROM tblMember_Associations
									WHERE tblMember_Associations.intAssocID = $clientValues->{'assocID'}
										AND tblMember_Associations.intRecStatus = $Defs::RECSTATUS_ACTIVE
							)
						)
						OR (tblTribunal.intAssocID = $Data->{'clientValues'}{'assocID'})
					)
				)
			];
=cut	
	}
		elsif ($currentLevel > $Defs::LEVEL_ASSOC && $currentLevel =~/(10|20|30|100)/) {
			my $tblTempNodeStructureField = 'int' .  $currentLevel . '_ID';
			my $currentLevelID = getID($clientValues);
			$from = qq[
				INNER JOIN tblMember ON (tblMember.intMemberID = tblTribunal.intMemberID)
				INNER JOIN tblMember_Associations ON (
					tblTribunal.intMemberID = tblMember_Associations.intMemberID
					AND tblTribunal.intAssocID = tblMember_Associations.intAssocID
				)
				INNER JOIN tblTempNodeStructure ON (
					tblTempNodeStructure.intAssocID = tblMember_Associations.intAssocID
					AND $tblTempNodeStructureField = $currentLevelID
				)
			];
			$extraWHERE = qq[AND tblMember_Associations.intRecStatus = $Defs::RECSTATUS_ACTIVE];
		}
		else {
			return ('','Report does not support current user level');
		}


    $sql = qq[
      SELECT ###SELECT###
			FROM tblTribunal $from
				INNER JOIN tblAssoc ON (tblAssoc.intAssocID = tblTribunal.intAssocID)
				LEFT JOIN tblClub ON (tblClub.intClubID = tblTribunal.intClubID)
				LEFT JOIN tblTeam ON (tblTeam.intTeamID = tblTribunal.intTeamID)
				LEFT JOIN tblAssoc_Comp ON (tblAssoc_Comp.intCompID=tblTribunal.intCompID)
				LEFT JOIN tblCompMatches ON (tblCompMatches.intMatchID=tblTribunal.intMatchID)
				LEFT JOIN tblDefVenue ON (tblCompMatches.intVenueID=tblDefVenue.intDefVenueID)
				$whereand $where_list $extraWHERE
    ];
    return ($sql,'');
  }
}

1;
