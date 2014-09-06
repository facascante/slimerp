#
# $Header: svn://svn/SWM/trunk/web/Reports/ReportAdvanced_Clearances.pm 8849 2013-07-04 02:14:36Z dhanslow $
#

package Reports::ReportAdvanced_Clearances;

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

  my $txt_Clr = $SystemConfig->{'txtCLR'} || 'Clearance';
	my $showAgentFields = ($SystemConfig->{'clrHide_AgentFields'} == 1) ? '0' : '1';
  my $natnumname=$SystemConfig->{'NationalNumName'} || 'National Number';

  my $CommonVals = getCommonValues(
    $Data,
    {
      DefCodes => 1,
    },
  );

	my %config = (
		Name => "$txt_Clr Report",

		StatsReport => 0,
		MemberTeam => 0,
		ReportEntity => 3,
		ReportLevel => 0,
		Template => 'default_adv',
		TemplateEmail => 'default_adv_CSV',
		DistinctValues => 1,
    SQLBuilder => \&SQLBuilder,

		Fields => {

        intClearanceID=> ["$txt_Clr Ref No.",{displaytype=>'text', fieldtype=>'text', active=>1, allowsort=>1, dbfield => 'M.strLocalFirstname'}],
        strNationalNum=> [$natnumname,{displaytype=>'text', fieldtype=>'text', allowsort=>1, dbfield=>'M.strNationalNum'}, active=>1],
        strLocalFirstname=> ["First name",{displaytype=>'text', fieldtype=>'text', active=>1, allowsort=>1, dbfield => 'M.strLocalFirstname'}],
        strLocalSurname=> ["Family name",{displaytype=>'text', fieldtype=>'text', active=>1, allowsort=>1, dbfield => 'M.strLocalSurname'}],
        dtDOB=> ['Date of Birth',{displaytype=>'date', fieldtype=>'date', dbfield=>'M.dtDOB', dbformat=>' DATE_FORMAT(M.dtDOB,"%d/%m/%Y")'}, active=>1],
        dtYOB=> ['Year of Birth',{displaytype=>'date', fieldtype=>'text', allowgrouping=>1, allowsort=>1, dbfield=>'YEAR(M.dtDOB)', dbformat=>' YEAR(M.dtDOB)'}],
        SourceClubName=> ['Source Club',{displaytype=>'text', fieldtype=>'text', active=>1, allowsort=>1, dbfield => 'SourceClub.strLocalName', allowgrouping=>1}],
        DestinationClubName=> ['Destination Club',{displaytype=>'text', fieldtype=>'text', active=>1, allowsort=>1, dbfield => 'DestinationClub.strLocalName', allowgrouping=>1}],
        intClearanceYear=> ["$txt_Clr Year",{displaytype=>'text', fieldtype=>'text', active=>1, allowsort=>1, dbfield => 'C.intClearanceYear'}],
        intReasonForClearanceID => [
					"Reason for $txt_Clr" ,
					{
						displaytype=>'lookup', 
						active=>0, 
						fieldtype=>'dropdown', 
						dropdownoptions => $CommonVals->{'DefCodes'}{-37},
						allowsort=>1, 
						allowgrouping=>1,
						enabled => !$Data->{'SystemConfig'}{'clrHide_intReasonForClearanceID'},
					}
				],
        strReasonForClearance => [
					"Additional Information" ,
					{
						displaytype=>'text', 
						active=>1, 
						fieldtype=>'text', 
						allowsort=>1, 
						allowgrouping=>1,
						enabled => !$Data->{'SystemConfig'}{'clrHide_strReasonForClearanceID'},
					}
				],
        intDenialReasonID=> [
					"Reason for Denial",
					{
						fieldtype=>'dropdown', 
						displaytype=>'lookup', 
						dropdownoptions => $CommonVals->{'DefCodes'}{-38},
						allowsort=>1, 
						allowgrouping=>1,
						enabled => !$Data->{'SystemConfig'}{'clrHide_intDenialReasonID'},
					}
				],



        intClearanceStatus=> ["Overall $txt_Clr Status" ,{displaytype=>'lookup', active=>1, fieldtype=>'dropdown', dropdownoptions => \%Defs::clearance_status, allowsort=>1, dbfield => 'C.intClearanceStatus', allowgrouping=>1}],
        PathStatus=> ["This level's Status" ,{displaytype=>'lookup', active=>1, fieldtype=>'dropdown', dropdownoptions => \%Defs::clearance_status, allowsort=>1, dbfield=> 'CP.intClearanceStatus', allowgrouping=>1}],
        ThisLevel=> ["Waiting At This Level?" ,{displaytype=>'lookup', active=>1, fieldtype=>'dropdown', dropdownoptions => {0=>'No', 1=>'Yes'}, allowsort=>1, dbfield=> 'IF(C.intCurrentPathID = CP.intClearancePathID AND C.intClearanceStatus  = 0,1,0)', allowgrouping=>1}],
        dtApplied=> ['Application Date',{displaytype=>'date', fieldtype=>'date', dbfield=>'C.dtApplied', dbformat=>' DATE_FORMAT(C.dtApplied,"%d/%m/%Y")'}],
        dtFinalised=> ['Finalised Date',{displaytype=>'date', fieldtype=>'date', dbfield=>'C.dtFinalised', dbformat=>' DATE_FORMAT(C.dtFinalised,"%d/%m/%Y")'}],
                intHasAgent=> ["Has Agent ?",{displaytype=>'lookup', fieldtype=>'dropdown', dropdownoptions=>{0=>'No', 1=>'Yes'}, dropdownorder=>[0,1], enabled => $showAgentFields}],
        strAgentFirstname=> ["Agent First name", {displaytype=>'text', fieldtype=>'text', allowsort=>1, enabled => $showAgentFields}],
        strAgentSurname=> ["Agent Surname",{displaytype=>'text', fieldtype=>'text', allowsort=>1, enabled => $showAgentFields}],
        strAgentNationality=> ["Agent Nationality",{displaytype=>'text', fieldtype=>'text', allowsort=>1, enabled => $showAgentFields}],
        strAgentLicenseNum=> ["Agent License Number",{displaytype=>'text', fieldtype=>'text', allowsort=>1, enabled => $showAgentFields}],
        strAgencyName=> ["Agency Name" ,{displaytype=>'text', fieldtype=>'text', allowsort=>1, enabled => $showAgentFields}],
        strAgencyEmail=> ["Agency Email" ,{displaytype=>'text', fieldtype=>'text', allowsort=>1, enabled => $showAgentFields}],
		},

		Order => [qw(
			intClearanceID
			strNationalNum
			strLocalFirstname
			strLocalSurname
			dtDOB
			dtYOB
			SourceClubName
			DestinationClubName
			intClearanceYear
			PathStatus
			ThisLevel
			intReasonForClearanceID
			strReasonForClearance
			intDenialReasonID
			intClearanceStatus
			dtApplied
			dtFinalised
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

    $sql = qq[
      SELECT 
				C.*,
				IF(C.intCurrentPathID = CP.intClearancePathID AND C.intClearanceStatus  = $Defs::CLR_STATUS_PENDING,1,0) AS ThisLevel,	
				DATE_FORMAT(C.dtApplied, "%d/%m/%Y") AS dtApplied,
				CP.intClearanceStatus as PathStatus,
				CP.intClearancePathID,
				M.strLocalSurname,
				M.strLocalFirstname,
				SourceClub.strLocalName as SourceClubName,
				DestinationClub.strLocalName as DestinationClubName,
				M.strNationalNum,
				DATE_FORMAT(M.dtDOB, "%d/%m/%Y") as dtDOB,
				DATE_FORMAT(M.dtDOB, "%Y") as dtYOB
				FROM tblClearance as C
					INNER JOIN tblClearancePath as CP ON (CP.intClearanceID = C.intClearanceID)
					INNER JOIN tblPerson as M ON (M.intPersonID = C.intPersonID)
					LEFT JOIN tblEntity as SourceClub ON (SourceClub.intEntityID = C.intSourceClubID)
					LEFT JOIN tblEntity as DestinationClub ON (DestinationClub.intEntityID = C.intDestinationClubID)
				WHERE CP.intTypeID = $currentLevel
					AND CP.intID = $self->{'EntityID'}
					AND C.intRecStatus <> -1
					AND C.intCreatedFrom = 0
					$where_list
    ];
    return ($sql,'');
  }
}

1;
