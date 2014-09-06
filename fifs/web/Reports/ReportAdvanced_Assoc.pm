#
# $Header: svn://svn/SWM/trunk/web/Reports/ReportAdvanced_Assoc.pm 11220 2014-04-03 04:43:54Z dhanslow $
#

package Reports::ReportAdvanced_Assoc;

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
	my $txt_Clr = $SystemConfig->{'txtCLR'} || 'Clearance';

	my $clientValues = $Data->{'clientValues'};
	my $CommonVals = getCommonValues(
		$Data,
		{
			SubRealms => 1,
			ContactRoles => 1,
			EntityCategories => 1,
		},
	);

	my %config = (
		Name => 'Detailed Association Report',

		StatsReport => 1,
		MemberTeam => 0,
		ReportEntity => 5,
		ReportLevel => 0,
		Template => 'default_adv',
    TemplateEmail => 'default_adv_CSV',
		DistinctValues => 1,
    SQLBuilder => \&SQLBuilder,
		DefaultPermType => 'NONE',

		Fields => {
			intRecStatus=> [
				'Active',
				{
					displaytype=>'lookup', 
					fieldtype=>'dropdown', 
					dropdownoptions=> {0=>'No', 1=>'Yes'}, 
					dbfield=>'tblAssoc.intRecStatus', 
				}
			],
			strName=> [
				"$Data->{'LevelNames'}{$Defs::LEVEL_ASSOC} Name",
				{
					displaytype=>'text', 
					fieldtype=>'text', 
					active=>1, 
					allowsort=>1, 
					dbfield => 'tblAssoc.strName',
				}
			],
			 strIncNo=> [
                                'Incorporation Number',
                                {
                                        displaytype=>'text',
                                        fieldtype=>'text',
                                        allowsort=>1,
                                        dbfield => 'tblAssoc.strIncNo',
                                }
                        ],

			MaxUpload=> [
				'Date Last Successful Sync',
				{
					displaytype=>'text', 
					fieldtype=>'text', 
					allowsort=>1, 
					dbfield => "MAX(dtSync)"
				}
			],

			strContact=> [
				'Contact Person',
				{
					displaytype=>'text', 
					fieldtype=>'text', 
					active=>1, 
					allowsort=>1, 
					dbfield => 'tblAssoc.strContact',
				}
			],
			intLogins=> [
				'Number of Logins',
				{
					displaytype=>'text', 
					fieldtype=>'text', 
					allowsort=>1, 
					dbfrom=>"LEFT JOIN tblAuth ON (tblAssoc.intAssocID = tblAuth.intID and tblAuth.intLevel=5)",
					optiongroup => 'auth',		
				}
			],
			strAddress1=> [
				'Address Line 1',
				{
					displaytype=>'text', 
					fieldtype=>'text', 
					allowsort=>1, 
					dbfield => 'tblAssoc.strAddress1',
				}
			],
			strAddress2=> [
				'Address Line 2',
				{
					displaytype=>'text', 
					fieldtype=>'text', 
					allowsort=>1, 
					dbfield => 'tblAssoc.strAddress2',
				}
			],
			strAddress3=> [
				'Address Line 3',
				{
					displaytype=>'text', 
					fieldtype=>'text', 
					allowsort=>1, 
					dbfield => 'tblAssoc.strAddress3',
				}
			],
			strSuburb=> [
				'Suburb',
				{
					displaytype=>'text', 
					fieldtype=>'text', 
					allowsort=>1, 
					dbfield => 'tblAssoc.strSuburb',
				}
			],
			strState=> [
				'State',
				{
					displaytype=>'text', 
					fieldtype=>'text', 
					allowsort=>1, 
					dbfield => 'tblAssoc.strState',
					allowgrouping=>1,
				}
			],

			strPostalCode=> [
				'Postal Code',
				{
					displaytype=>'text', 
					fieldtype=>'text', 
					allowsort=>1, 
					dbfield => 'tblAssoc.strPostalCode',
				}
			],
			strPhone=> [
				'Phone',
				{
					displaytype=>'text', 
					fieldtype=>'text', 
					allowsort=>1, 
					dbfield => 'tblAssoc.strPhone',
				}
			],
			strFax=> [
				'Fax',
				{
					displaytype=>'text', 
					fieldtype=>'text', 
					allowsort=>1, 
					dbfield => 'tblAssoc.strFax',
				}
			],
			strEmail=> [
				'Email',
				{
					displaytype=>'text', 
					fieldtype=>'text', 
					allowsort=>1, 
					dbfield => 'tblAssoc.strEmail',
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
			intAssocCategoryID=> [
        scalar(keys %{$CommonVals->{'EntityCategories'}{$Defs::LEVEL_ASSOC}}) ? "$Data->{'LevelNames'}{$Defs::LEVEL_ASSOC} Category" : '',
        {
          displaytype=>'lookup',
          fieldtype=>'dropdown',
          dropdownoptions=> $CommonVals->{'EntityCategories'}{$Defs::LEVEL_ASSOC},
          dbfield=>'tblAssoc.intAssocCategoryID',
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

			AServ_intPublicShow=> [
				'Visible to Public ?',
				{
					displaytype=>'lookup', 
					fieldtype=>'dropdown', 
					dropdownoptions=>{0=>'No', 1=>'Yes'}, 
					dropdownorder=>[0,1], 
					optiongroup=>'assoc_services',
					dbfield => 'AServ.intPublicShow',
				}
			],
  AServ_dblLat=> [
                                'Venue Latitude',
                                {
                                        displaytype=>'double',
                                        fieldtype=>'double',
                                        allowsort=>1,
                                        optiongroup=>'assoc_services',
                                        dbfield => 'AServ.dblLat',
                                }
                        ],
                        AServ_dblLong=> [
                                'Venue Longitude',
                                {
                                        displaytype=>'double',
                                        fieldtype=>'double',
                                        allowsort=>1,
                                        optiongroup=>'assoc_services',
                                        dbfield => 'AServ.dblLong',
                                }
                        ],


      AServ_strContact1Name=> [
				'Contact 1 Person',
				{
					displaytype=>'text', 
					fieldtype=>'text', 
					allowsort=>1, 
					optiongroup=>'assoc_services',
					dbfield => 'AServ.strContact1Name'
				}
			],
			AServ_strContact1Title=> [
				'Contact 1 Title',
				{
					displaytype=>'text', 
					fieldtype=>'text', 
					allowsort=>1, 
					optiongroup=>'assoc_services',
					dbfield => 'AServ.strContact1Title'
				}
			],
			AServ_strContact1Phone=> [
				'Contact 1 Phone',
				{
					displaytype=>'text', 
					fieldtype=>'text', 
					allowsort=>1, 
					optiongroup=>'assoc_services',
					dbfield => 'AServ.strContact1Phone'
				}
			],
			AServ_strContact2Name=> [
				'Contact 2 Person',
				{
					displaytype=>'text', 
					fieldtype=>'text', 
					allowsort=>1, 
					optiongroup=>'assoc_services',
					dbfield => 'AServ.strContact2Name'
				}
			],
			AServ_strContact2Title=> [
				'Contact 2 Title',
				{
					displaytype=>'text', 
					fieldtype=>'text', 
					allowsort=>1, 
					optiongroup=>'assoc_services',
					dbfield => 'AServ.strContact2Title'
				}
			],
			AServ_strContact2Phone=> [
				'Contact 2 Phone',
				{
					displaytype=>'text', 
					fieldtype=>'text', 
					allowsort=>1, 
					optiongroup=>'assoc_services',
					dbfield => 'AServ.strContact2Phone'
				}
			],
			AServ_strURL=> [
                                'Website URL',
                                {
                                        displaytype=>'text',
                                        fieldtype=>'text',
                                        allowsort=>1,
                                        optiongroup=>'assoc_services',
                                        dbfield => 'AServ.strURL',
                                }
                        ],

			AServ_strVenueName=> [
				'Venue Name',
				{
					displaytype=>'text', 
					fieldtype=>'text', 
					allowsort=>1, 
					optiongroup=>'assoc_services',
					dbfield => 'AServ.strVenueName',
				}
			],
			AServ_strVenueAddress=> [
				'Venue Address',
				{
					displaytype=>'text', 
					fieldtype=>'text', 
					allowsort=>1, 
					optiongroup=>'assoc_services',
					dbfield => 'AServ.strVenueAddress',
				}
			],
			AServ_strVenueAddress2=> [
				'Venue Address 2',
				{
					displaytype=>'text', 
					fieldtype=>'text', 
					allowsort=>1, 
					optiongroup=>'assoc_services',
					dbfield => 'AServ.strVenueAddress2',
				}
			],
			AServ_strVenueSuburb=> [
				'Venue Suburb',
				{
					displaytype=>'text', 
					fieldtype=>'text', 
					allowsort=>1, 
					optiongroup=>'assoc_services',
					dbfield => 'AServ.strVenueSuburb',
				}
			],
			AServ_strVenueState=> [
				'Venue State',
				{
					displaytype=>'text', 
					fieldtype=>'text', 
					allowsort=>1, 
					optiongroup=>'assoc_services',
					dbfield => 'AServ.strVenueState',
				}
			],
			AServ_strVenueCountry=> [
				'Venue Country',
				{
					displaytype=>'text', 
					fieldtype=>'text', 
					allowsort=>1, 
					optiongroup=>'assoc_services',
					dbfield => 'AServ.strVenueCountry',
				}
			],
			AServ_strEmail=> [
				'Email',
				{
					displaytype=>'text', 
					fieldtype=>'text', 
					allowsort=>1, 
					optiongroup=>'assoc_services',
					dbfield => 'AServ.strEmail',
				}
			],
			AServ_strURL=> [
				'Website',
				{
					displaytype=>'text', 
					fieldtype=>'text', 
					allowsort=>1, 
					optiongroup=>'assoc_services',
					dbfield => 'AServ.strURL',
				}
			],
			AServ_intMon=> [
				'Monday',
				{
					displaytype=>'lookup', 
					fieldtype=>'dropdown', 
					dropdownoptions=>{0=>'No', 1=>'Yes'}, 
					dropdownorder=>[0,1], 
					optiongroup=>'assoc_services',
					dbfield => 'AServ.intMon',
				}
			],
			AServ_intTue=> [
				'Tuesday',
				{
					displaytype=>'lookup', 
					fieldtype=>'dropdown', 
					dropdownoptions=>{0=>'No', 1=>'Yes'}, 
					dropdownorder=>[0,1], 
					optiongroup=>'assoc_services',
					dbfield => 'AServ.intTue',
				}
			],
			AServ_intWed=> [
				'Wednesday',
				{
					displaytype=>'lookup', 
					fieldtype=>'dropdown', 
					dropdownoptions=>{0=>'No', 1=>'Yes'}, 
					dropdownorder=>[0,1], 
					optiongroup=>'assoc_services',
					dbfield => 'AServ.intWed',
				}
			],
			AServ_intThu=> [
				'Thursday',
				{
					displaytype=>'lookup', 
					fieldtype=>'dropdown', 
					dropdownoptions=>{0=>'No', 1=>'Yes'}, 
					dropdownorder=>[0,1], 
					optiongroup=>'assoc_services',
					dbfield => 'AServ.intThu',
				}
			],
			AServ_intFri=> [
				'Friday',
				{
					displaytype=>'lookup', 
					fieldtype=>'dropdown', 
					dropdownoptions=>{0=>'No', 1=>'Yes'}, 
					dropdownorder=>[0,1], 
					optiongroup=>'assoc_services',
					dbfield => 'AServ.intFri',
				}
			],
			AServ_intSat=> [
				'Saturday',
				{
					displaytype=>'lookup', 
					fieldtype=>'dropdown', 
					dropdownoptions=>{0=>'No', 1=>'Yes'}, 
					dropdownorder=>[0,1], 
					optiongroup=>'assoc_services',
					dbfield => 'AServ.intSat',
				}
			],
			AServ_intSun=> [
				'Sunday',
				{
					displaytype=>'lookup', 
					fieldtype=>'dropdown', 
					dropdownoptions=>{0=>'No', 1=>'Yes'}, 
					dropdownorder=>[0,1], 
					optiongroup=>'assoc_services',
					dbfield => 'AServ.intSun',
				}
			],
			AServ_strSessionDurations=> [
				'Duration',
				{
					displaytype=>'text', 
					fieldtype=>'text', 
					allowsort=>1, 
					optiongroup=>'assoc_services',
					dbfield => 'AServ.strSessionDurations',
				}
			],
			AServ_strTimes=> [
				'Times',
				{
					displaytype=>'text', 
					fieldtype=>'text', 
					allowsort=>1, 
					optiongroup=>'assoc_services',
					dbfield => 'AServ.strTimes',
				}
			],
			AServ_dtStart => [
				'Season Start Date',
				{
					displaytype=>'text', 
					fieldtype=>'date', 
					allowsort=>1, 
					optiongroup=>'assoc_services',
					dbfield => 'AServ.dtStart',
				}
			],
		 AServ_PostalCodes=> [
				'Postal Codes Serviced',
				{
					optiongroup=>'assoc_services', 
					displaytype=>'text', 
					fieldtype=>'text', 
					dbfrom => "LEFT JOIN tblAssocServicesPostalCode ON (tblAssocServicesPostalCode.intAssocID = tblAssoc.intAssocID and tblAssocServicesPostalCode.intAssocID = tblAssoc.intAssocID)", 
					dbfield=>'tblAssocServicesPostalCode.strPostalCode',
				}
			],

        intContactRoleID => ['Role',{displaytype=>'lookup', fieldtype=>'dropdown', dropdownoptions=>$CommonVals->{'ContactRoles'}{'Values'}, dropdownorder=>$CommonVals->{'ContactRoles'}{'Order'}, allowsort=>1,  size=>3, multiple=>1, dbfield=>'intContactRoleID', allowgrouping=>1, optiongroup=>'contacts',}],
        strContactFirstname=> ['Firstname',{displaytype=>'text', fieldtype=>'text', active=>1, allowsort=>1, dbfield => 'strContactFirstname', optiongroup=>'contacts',}],
        strContactSurname=> ['Surname',{displaytype=>'text', fieldtype=>'text', active=>1, allowsort=>1, dbfield => 'strContactSurname', optiongroup=>'contacts',}],
        strContactEmail => ['Email',{displaytype=>'text', fieldtype=>'text', active=>1, allowsort=>1, dbfield => 'strContactEmail', optiongroup=>'contacts',}],
        strContactMobile => ['Mobile',{displaytype=>'text', fieldtype=>'text', active=>1, allowsort=>1, dbfield => 'strContactMobile', optiongroup=>'contacts',}],
        intFnCompAdmin => ['Competition Admin',{displaytype=>'lookup', fieldtype=>'dropdown', dropdownoptions=>{0=>'No', 1=>'Yes'}, dropdownorder=>[0,1], optiongroup=>'contacts',}],
        intFnSocial => ['Social Activities',{displaytype=>'lookup', fieldtype=>'dropdown', dropdownoptions=>{0=>'No', 1=>'Yes'}, dropdownorder=>[0,1], optiongroup=>'contacts',}],
        intFnWebsite => ['Website and Publicity',{displaytype=>'lookup', fieldtype=>'dropdown', dropdownoptions=>{0=>'No', 1=>'Yes'}, dropdownorder=>[0,1], optiongroup=>'contacts',}],
        intFnClearances => ["$txt_Clr and Permits",{displaytype=>'lookup', fieldtype=>'dropdown', dropdownoptions=>{0=>'No', 1=>'Yes'}, dropdownorder=>[0,1], optiongroup=>'contacts',}],
        intFnSponsorship => ['Sponsors and Fundraising',{displaytype=>'lookup', fieldtype=>'dropdown', dropdownoptions=>{0=>'No', 1=>'Yes'}, dropdownorder=>[0,1], optiongroup=>'contacts',}],
        intFnSponsorship => ['Sponsors and Fundraising',{displaytype=>'lookup', fieldtype=>'dropdown', dropdownoptions=>{0=>'No', 1=>'Yes'}, dropdownorder=>[0,1], optiongroup=>'contacts',}],
        intFnPayments => ['Finance & Payments',{displaytype=>'lookup', fieldtype=>'dropdown', dropdownoptions=>{0=>'No', 1=>'Yes'}, dropdownorder=>[0,1], optiongroup=>'contacts',}],
        intFnLegal => ['Legal & Contracts',{displaytype=>'lookup', fieldtype=>'dropdown', dropdownoptions=>{0=>'No', 1=>'Yes'}, dropdownorder=>[0,1], optiongroup=>'contacts',}],
        intPrimaryContact => ['Primary Contact',{displaytype=>'lookup', fieldtype=>'dropdown', dropdownoptions=>{0=>'No', 1=>'Yes'}, dropdownorder=>[0,1], optiongroup=>'contacts',}],
       intShowInLocator => ['Show in Locator',{displaytype=>'lookup', fieldtype=>'dropdown', dropdownoptions=>{0=>'No', 1=>'Yes'}, dropdownorder=>[0,1], optiongroup=>'contacts',}],


		},

		Order => [qw(
			intRecStatus
			strName
			strIncNo
			MaxUpload
			strAddress1
			strAddress2
			strSuburb
			strState
			strPostalCode
			strPhone
			strFax
			strEmail
			intAssocTypeID
			intAssocCategoryID
			strZoneName
			strRegionName
			strStateName
			strNationalName
			strIntZoneName
			strIntRegionName
			AServ_strURL
			AServ_strVenueName
			AServ_strVenueAddress

			AServ_strVenueAddress2

			AServ_strVenueSuburb
			AServ_strVenueState
			AServ_strVenueCountry
			AServ_strEmail
			AServ_dblLat
			AServ_dblLong
			AServ_intMon
			AServ_intTue
			AServ_intWed
			AServ_intThu
			AServ_intFri
			AServ_intSat
			AServ_intSun
			AServ_strSessionDurations
			AServ_strTimes
			AServ_intPublicShow
			AServ_dtStart
			AServ_PostalCodes
      intContactRoleID
      strContactFirstname
      strContactSurname
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
            strUsername
            strPassword
			intLogins

		)],
		OptionGroups => {
			default => ['Details',{}],
			assoc_services=> ['Assoc Services',{
				from => "LEFT JOIN tblAssocServices as AServ ON (tblAssoc.intAssocID=AServ.intAssocID AND AServ.intClubID=0)",
				enabled => $Data->{'SystemConfig'}{'AssocAssocServices'},
			 }],
			contacts => ['Contacts ',{
				from => "LEFT JOIN tblContacts ON (tblContacts.intAssocID=tblAssoc.intAssocID AND tblContacts.intClubID = 0)",
			 }],
			auth => ['Authorisation',{
				from => "LEFT JOIN tblAuth ON (tblAssoc.intAssocID = tblAuth.intID and tblAuth.intLevel=5)",
			 }],
		},

		Config => {
			FormFieldPrefix => 'c',
			FormName => 'clubform_',
			EmailExport => 1,
			limitView  => 5000,
			EmailSenderAddress => $Defs::admin_email,
			SecondarySort => 1,
			RunButtonLabel => 'Run Report',
			ReturnProcessData => [qw(tblAssoc.strEmail tblAssoc.strName)],
		},
	);

        $config{'Fields'} = {
            %{$config{'Fields'}},
            strUsername => [
                'Username',
                {
                    displaytype=>'text', 
                    fieldtype=>'text', 
                    allowsort=>1, 
                    dbfield => "IF(tblAssoc.intDataAccess >= 10, tblAuth.strUsername, '')",
                    optiongroup => 'auth',
                }
            ],
        };
    if ($Data->{'SystemConfig'}{'AssocConfig'}{'ShowPassword'}) {
        $config{'Fields'} = {
            %{$config{'Fields'}},
            strPassword => [
                'Password',
                {
                    displaytype=>'text', 
                    fieldtype=>'text', 
                    allowsort=>1, 
                    dbfield => "IF(tblAssoc.intDataAccess >= 10, tblAuth.strPassword, '')",
                    dbfrom=>"LEFT JOIN tblAuth ON (tblAssoc.intAssocID = tblAuth.intID and tblAuth.intLevel=5)",
                    optiongroup => 'auth',
                }
            ],
        };
    }

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
	my $select_stuff = $OptVals->{'SELECT'};

	my $sync_from='';
	my $groupby = '';
	if ($select_stuff =~ /MaxUpload/)   {
			$groupby = qq[ GROUP BY tblAssoc.intAssocID];
			$sync_from = qq[
					LEFT JOIN tblSync as Sync ON (
							Sync.intAssocID=tblAssoc.intAssocID
							AND strStage='sync'
							AND intCompleted=1
							AND intReturnAcknowledged=1
					)
			];
	}

	$where_list=' AND '.$where_list if $where_list and ($where_levels or $current_where);

	my $sql = qq[
		SELECT ###SELECT###
		FROM $from_levels $current_from $from_list $sync_from
		WHERE  $where_levels $current_where $where_list 
		$groupby
	];
	return ($sql,'');
}

1;
