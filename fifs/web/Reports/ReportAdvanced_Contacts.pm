#
# $Header: svn://svn/SWM/trunk/web/Reports/ReportAdvanced_Contacts.pm 8251 2013-04-08 09:00:53Z rlee $
#

package Reports::ReportAdvanced_Contacts;

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
	my $CommonVals = getCommonValues(
		$Data,
		{
			SubRealms => 1,
      FieldLabels => 1,
      DefCodes => 1,
			ContactRoles => 1,
		},
	);

  my $txt_Clr = $Data->{'SystemConfig'}{'txtCLR'} || 'Clearance';

	my %config = (
		Name => 'Detailed Contacts Report',

		StatsReport => 0,
		MemberTeam => 0,
		ReportEntity => 5,
		ReportLevel => 0,
		Template => 'default_adv',
    TemplateEmail => 'default_adv_CSV',
		DistinctValues => 1,
    SQLBuilder => \&SQLBuilder,
    DefaultPermType => 'NONE',

		Fields => {

        intContactRoleID => ['Role',{displaytype=>'lookup', fieldtype=>'dropdown', dropdownoptions=>$CommonVals->{'ContactRoles'}{'Values'}, dropdownorder=>$CommonVals->{'ContactRoles'}{'Order'}, allowsort=>1,  size=>3, multiple=>1, dbfield=>'intContactRoleID', allowgrouping=>1}],
        ContactType => ['Contact Type',{displaytype=>'lookup', fieldtype=>'dropdown', dropdownoptions=>{0=>'All', $Defs::LEVEL_CLUB=>'Club', $Defs::LEVEL_ASSOC => 'Association'}, dropdownorder=>[0,$Defs::LEVEL_CLUB, $Defs::LEVEL_ASSOC], dbfield => "IF(tblContacts.intClubID = 0, $Defs::LEVEL_ASSOC, $Defs::LEVEL_CLUB)"}],

        strContactFirstname=> ['Firstname',{displaytype=>'text', fieldtype=>'text', active=>1, allowsort=>1, dbfield => 'strContactFirstname'}],
        strContactSurname=> ['Surname',{displaytype=>'text', fieldtype=>'text', active=>1, allowsort=>1, dbfield => 'strContactSurname'}],
				intContactGender => [ 'Gender', { displaytype=>'lookup', fieldtype=>'dropdown', dropdownoptions=>{ ''=>'&nbsp;', 1=>'Male', 2=>'Female'}, dropdownorder=>['', 1, 2], size=>2, multiple=>1, allowgrouping=>1 } ],
        strContactEmail => ['Email',{displaytype=>'text', fieldtype=>'text', active=>1, allowsort=>1, dbfield => 'strContactEmail'}],
        strContactMobile => ['Mobile',{displaytype=>'text', fieldtype=>'text', active=>1, allowsort=>1, dbfield => 'strContactMobile'}],
        intFnCompAdmin => ['Competition Admin',{displaytype=>'lookup', fieldtype=>'dropdown', dropdownoptions=>{0=>'No', 1=>'Yes'}, dropdownorder=>[0,1]}],
        intFnSocial => ['Social Activities',{displaytype=>'lookup', fieldtype=>'dropdown', dropdownoptions=>{0=>'No', 1=>'Yes'}, dropdownorder=>[0,1]}],
        intFnWebsite => ['Website and Publicity',{displaytype=>'lookup', fieldtype=>'dropdown', dropdownoptions=>{0=>'No', 1=>'Yes'}, dropdownorder=>[0,1]}],
        intFnClearances => ["$txt_Clr and Permits",{displaytype=>'lookup', fieldtype=>'dropdown', dropdownoptions=>{0=>'No', 1=>'Yes'}, dropdownorder=>[0,1]}],
        intFnSponsorship => ['Sponsors and Fundraising',{displaytype=>'lookup', fieldtype=>'dropdown', dropdownoptions=>{0=>'No', 1=>'Yes'}, dropdownorder=>[0,1]}],
        intFnSponsorship => ['Sponsors and Fundraising',{displaytype=>'lookup', fieldtype=>'dropdown', dropdownoptions=>{0=>'No', 1=>'Yes'}, dropdownorder=>[0,1]}],
        intFnPayments => ['Finance & Payments',{displaytype=>'lookup', fieldtype=>'dropdown', dropdownoptions=>{0=>'No', 1=>'Yes'}, dropdownorder=>[0,1]}],
        intFnLegal => ['Legal & Contracts',{displaytype=>'lookup', fieldtype=>'dropdown', dropdownoptions=>{0=>'No', 1=>'Yes'}, dropdownorder=>[0,1]}],
        intPrimaryContact => ['Primary Contact',{displaytype=>'lookup', fieldtype=>'dropdown', dropdownoptions=>{0=>'No', 1=>'Yes'}, dropdownorder=>[0,1]}],
       intShowInLocator => ['Show in Locator',{displaytype=>'lookup', fieldtype=>'dropdown', dropdownoptions=>{0=>'No', 1=>'Yes'}, dropdownorder=>[0,1]}],


			strClubName=> [
				"$Data->{'LevelNames'}{$Defs::LEVEL_CLUB} Name",
				{
					displaytype=>'text', 
					fieldtype=>'text', 
					allowsort=>1, 
					dbfield => 'tblClub.strName', 
				  optiongroup => 'affiliations',
				}
			],
			strAssocName => [
				$Data->{'LevelNames'}{$Defs::LEVEL_ASSOC}.' Name',
				{
					displaytype=>'text',
					fieldtype=>'text',
					allowsort=>1,
					active=>1,
				  optiongroup => 'affiliations',
					dbfield=>'tblAssoc.strName',
					enabled => $currentLevel > $Defs::LEVEL_ASSOC,
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
				  optiongroup => 'affiliations',
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
				  optiongroup => 'affiliations',
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
				  optiongroup => 'affiliations',
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
				  optiongroup => 'affiliations',
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
				  optiongroup => 'affiliations',
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
				  optiongroup => 'affiliations',
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
				  optiongroup => 'affiliations',
					enabled => $currentLevel > $Defs::LEVEL_INTREGION,
				}
			],
		},

		Order => [qw(

			intContactRoleID
			strContactFirstname
			strContactSurname
			intContactGender
			strContactEmail
			strContactMobile
			intFnCompAdmin
			intFnSocial
			intFnWebsite
			intFnClearances
			intFnSponsorship
			intFnPayments
			intFnLegal
			intPrimaryContact
			intShowInLocator
			strClubName
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
			affiliations=> ['Affiliations',{}],
		},

		Config => {
			FormFieldPrefix => 'c',
			FormName => 'clubform_',
			EmailExport => 1,
			limitView  => 5000,
			EmailSenderAddress => $Defs::admin_email,
			SecondarySort => 1,
			RunButtonLabel => 'Run Report',
			ReturnProcessData => [qw(tblContacts.strEmail tblContacts.strName)],
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
    $where_list .= qq[ AND (tblAssoc_Comp.intRecStatus IS NULL OR tblAssoc_Comp.intRecStatus IN (0,1))] if ($from_list =~ /tblAssoc_Comp/);


	if ($currentLevel == $Defs::LEVEL_INTREGION) { #INT ZON level
        $from_levels.=qq[ INNER JOIN tblNode AS tblIntRegion ];
    }
    if ($currentLevel == $Defs::LEVEL_INTZONE) { #INT ZON level
        $from_levels.=qq[ INNER JOIN tblNode AS tblIntZone ];
    }
    if ($currentLevel == $Defs::LEVEL_NATIONAL) { #INT ZON level
        $from_levels.=qq[ INNER JOIN tblNode AS tblNational ];
    }
    if ($currentLevel == $Defs::LEVEL_STATE) { #INT ZON level
        $from_levels.=qq[ INNER JOIN tblNode AS tblState ];
    }
    if ($currentLevel == $Defs::LEVEL_REGION) { #National level
        $from_levels.=qq[ INNER JOIN tblNode AS tblRegion ];
    }
    if ($currentLevel == $Defs::LEVEL_ZONE) { #Region Level and above
        $from_levels.=qq[ INNER JOIN tblNode AS tblZone ];
    }

    if($currentLevel <= $Defs::LEVEL_ASSOC)  {
        $from_levels = 'tblAssoc';
    }
    if($from_levels) {
	$from_levels  = "INNER JOIN ".$from_levels;
    }
    $where_levels ||= '1=1';
	$current_from = '';
    $sql = qq[
      SELECT ###SELECT###
      FROM tblContacts 
        $from_levels $current_from $from_list
      LEFT JOIN tblAssoc_Clubs ON tblAssoc_Clubs.intAssocID=tblAssoc.intAssocID
      LEFT JOIN tblClub ON (
       tblContacts.intClubID = tblClub.intClubID
      )
      WHERE  $where_levels $current_where $where_list
        AND tblContacts.intAssocID = tblAssoc.intAssocID
    ];
    return ($sql,'');
  }
}

1;
