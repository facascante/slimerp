#
# $Header: svn://svn/SWM/trunk/web/Reports/ReportAdvanced_ClearancesOffline.pm 8251 2013-04-08 09:00:53Z rlee $
#

package Reports::ReportAdvanced_ClearancesOffline;

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

	my %config = (
		Name => 'Offline Clearances Report',

		StatsReport => 0,
		MemberTeam => 0,
		ReportEntity => 3,
		ReportLevel => 0,
		Template => 'default_adv',
    TemplateEmail => 'default_adv_CSV',
		DistinctValues => 1,
    SQLBuilder => \&SQLBuilder,

		Fields => {

        intClearanceID=> ["$txt_Clr Ref No.",{displaytype=>'text', fieldtype=>'text', active=>1, allowsort=>1, dbfield => 'M.strFirstname'}],
        strNationalNum=> [$natnumname,{displaytype=>'text', fieldtype=>'text', allowsort=>1, dbfield=>'M.strNationalNum'}, active=>1],
        strFirstname=> ["First name",{displaytype=>'text', fieldtype=>'text', active=>1, allowsort=>1, dbfield => 'M.strFirstname'}],
        strSurname=> ["Family name",{displaytype=>'text', fieldtype=>'text', active=>1, allowsort=>1, dbfield => 'M.strSurname'}],
        dtDOB=> ['Date of Birth',{displaytype=>'date', fieldtype=>'date', dbfield=>'M.dtDOB', dbformat=>' DATE_FORMAT(M.dtDOB,"%d/%m/%Y")'}, active=>1],
        SourceAssocName=> ['Source Association',{displaytype=>'text', fieldtype=>'text', active=>1, allowsort=>1, dbfield => 'A2.strName'}],
        SourceClubName=> ['Source Club',{displaytype=>'text', fieldtype=>'text', active=>1, allowsort=>1, dbfield => 'C2.strName'}],
        DestinationAssocName=> ['Destination Association',{displaytype=>'text', fieldtype=>'text', active=>1, allowsort=>1, dbfield => 'A1.strName'}],
        DestinationClubName=> ['Destination Club',{displaytype=>'text', fieldtype=>'text', active=>1, allowsort=>1, dbfield => 'C1.strName'}],
        intClearanceYear=> ["$txt_Clr Year",{displaytype=>'text', fieldtype=>'text', active=>1, allowsort=>1, dbfield => 'C.intClearanceYear'}],
        intClearanceStatus=> ["Overall $txt_Clr Status" ,{displaytype=>'lookup', active=>1, fieldtype=>'dropdown', dropdownoptions => \%Defs::clearance_status, allowsort=>1, dbfield => 'C.intClearanceStatus'}],
        dtApplied=> ['Application Date',{displaytype=>'date', fieldtype=>'date', dbfield=>'C.dtApplied', dbformat=>' DATE_FORMAT(C.dtApplied,"%d/%m/%Y")'}],
		},

		Order => [qw(
			intClearanceID
			strNationalNum
			strFirstname
			strSurname
			dtDOB
			SourceAssocName
			SourceClubName
			DestinationAssocName
			DestinationClubName
			intClearanceYear
			intClearanceStatus
			dtApplied
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
        DATE_FORMAT(C.dtApplied, "%d/%m/%Y") AS dtApplied,
        M.strSurname,
        M.strFirstname,
        IF(C1.strName IS NOT NULL, C1.strName, strDestinationClubName) as DestinationClubName,
        IF(A1.strName IS NOT NULL, A1.strName, strDestinationAssocName) as DestinationAssocName,
        intSourceClubID,
        IF(C2.strName IS NOT NULL, C2.strName, strSourceClubName) as SourceClubName,
        IF(A2.strName IS NOT NULL, A2.strName, strSourceAssocName) as SourceAssocName,
        M.strNationalNum,
        DATE_FORMAT(M.dtDOB, "%d/%m/%Y") as dtDOB
      FROM tblClearance as C
        INNER JOIN tblMember as M ON (M.intMemberID = C.intMemberID)
		INNER JOIN tblMember_Associations as MA ON (MA.intMemberID = C.intMemberID)
        LEFT JOIN tblClub as C1 ON (C1.intClubID = intDestinationClubID)
        LEFT JOIN tblClub as C2 ON (C2.intClubID = intSourceClubID)
        LEFT JOIN tblAssoc as A1 ON (A1.intAssocID = intDestinationAssocID)
        LEFT JOIN tblAssoc as A2 ON (A2.intAssocID = intSourceAssocID)
      WHERE C.intRecStatus <> -1
        AND C.intCreatedFrom IN ($Defs::CLR_TYPE_SWC, $Defs::CLR_TYPE_MANUAL)
        AND C.intRealmID=$Data->{'Realm'}
		AND (
			(C.intSourceAssocID = $Data->{'clientValues'}{'assocID'} OR C.intDestinationAssocID = $Data->{'clientValues'}{'assocID'})
			OR
			(C.intSourceAssocID = 0 AND C.intDestinationAssocID = 0 AND MA.intAssocID = $Data->{'clientValues'}{'assocID'})
		)
        $where_list
    ];
    return ($sql,'');
  }
}

1;
