#
# $Header: svn://svn/SWM/trunk/web/AssocServices.pm 11257 2014-04-09 00:03:19Z fkhezri $
#

package AssocServices;
require Exporter;
@ISA = qw(Exporter);
@EXPORT=qw(handleAssocServices);
@EXPORT_OK=qw(handleAssocServices);

use strict;
use Reg_common;
use HTMLForm;
use ServicesContacts;
use Contacts;
use AuditLog;

sub handleAssocServices	{
	my ($action, $Data, $assocID)=@_;
	$assocID = $Data->{'clientValues'}{'assocID'} || 0;

	my $resultHTML='';
	my $title='';
	if ($action =~/^A_SV_DT/) {
		#AssocService  Details
		my $clubID = $Data->{'clientValues'}{'clubID'} if ($Data->{'clientValues'}{'clubID'} and $Data->{'clientValues'}{'clubID'} != $Defs::INVALID_ID);
		 ($resultHTML,$title)=assocservice_details($action, $Data, $assocID, $clubID);
	}

	return ($resultHTML,$title);
}



sub assocservice_details	{
	my ($action, $Data, $assocID, $clubID)=@_;
	$clubID ||= 0;

    my $lang = $Data->{'lang'};
	my $field=loadAssocServicesDetails($Data->{'db'}, $assocID, $clubID) || ();
	my $option='display';
	if($Data->{'clientValues'}{'authLevel'} >= $Defs::LEVEL_CLUB)	{
		$option=$field->{'intAssocID'} ? 'edit' : 'add';
	}
#	if(
#		$Data->{'DataAccess'}{$Data->{'clientValues'}{'currentLevel'}}{getID($Data->{'clientValues'})} < $Defs::DATA_ACCESS_FULL
#	)	{
#		$option = 'display';
#	}
  my $client=setClient($Data->{'clientValues'}) || '';
	my %registrationOptions=(
		0 => $lang->txt('Not Available'),
		1 => $lang->txt('Register to the Association'),
		2 => $lang->txt('Register to a Club'),
	);
	delete $registrationOptions{2} if $Data->{'SystemConfig'}{'NoClubs'};
	my $AllowRegistrations=0;
	{
		my $st=qq[ SELECT intAllowRegoForm FROM tblAssoc WHERE intAssocID=$assocID ];
		my $query = $Data->{'db'}->prepare($st);
		$query->execute;
		($AllowRegistrations)=$query->fetchrow_array();
		$query->finish;
		$AllowRegistrations||=0;
	}
	$AllowRegistrations = 0 if $clubID;
    my $regoform_club_id = -1;
    
# Hack for ARU demo, not sure why this isn't allowed for clubs   
    if ($Data->{RealmSubType} == 120){
        $AllowRegistrations = 1;
        $regoform_club_id = $clubID;
    }
    
      my %forms = (
		0 => $lang->txt('-- Not Available --'),
  );
  if ($AllowRegistrations) {
    my $st = qq[
      SELECT 
        intRegoFormID,
        strRegoFormName
      FROM 
        tblRegoForm 
      WHERE 
        intAssocID = ?
        AND intStatus = ? 
        AND intClubID = ?
    ];
    my $q = $Data->{'db'}->prepare($st);

    $q->execute($assocID, 1, $regoform_club_id);
    while (my $form_ref = $q->fetchrow_hashref) { 
      $forms{$form_ref->{'intRegoFormID'}} = $form_ref->{'strRegoFormName'};
    }
  }

	my %FieldDefinitions=(
		fields=>	{
			strContact1Name => {
				label => $clubID ? '' : "Other $Data->{'LevelNames'}{$Defs::LEVEL_ASSOC} Contact 1 - Name",
				value => $field->{strContact1Name},
				type  => 'text',
				size  => '50',
				maxsize => '100',
				sectionname => 'contact',
				noadd => 1,
			},
			strContact1Title=> {
				label => $clubID ? '' : "Other $Data->{'LevelNames'}{$Defs::LEVEL_ASSOC} Contact 1 - Title",
				value => $field->{strContact1Title},
				type  => 'text',
				size  => '30',
				maxsize => '50',
				sectionname => 'contact',
				noadd => 1,
			},
			strContact1Phone => {
				label => $clubID ? '' : "Other $Data->{'LevelNames'}{$Defs::LEVEL_ASSOC} Contact 1 - Phone",
				value => $field->{strContact1Phone},
				type  => 'text',
				size  => '20',
				maxsize => '50',
				sectionname => 'contact',
				noadd => 1,
			},
			strContact2Name => {
				label => $clubID ? '' : "Other $Data->{'LevelNames'}{$Defs::LEVEL_ASSOC} Contact 2 - Name",
				value => $field->{strContact2Name},
				type  => 'text',
				size  => '50',
				maxsize => '100',
				sectionname => 'contact',
				noadd => 1,
			},
			strContact2Title=> {
				label => $clubID ? '' : "Other $Data->{'LevelNames'}{$Defs::LEVEL_ASSOC} Contact 2 - Title",
				value => $field->{strContact2Title},
				type  => 'text',
				size  => '30',
				maxsize => '50',
				sectionname => 'contact',
				noadd => 1,
			},
			strContact2Phone => {
				label => $clubID ? '' : "Other $Data->{'LevelNames'}{$Defs::LEVEL_ASSOC} Contact 2 - Phone",
				value => $field->{strContact2Phone},
				type  => 'text',
				size  => '20',
				maxsize => '50',
				sectionname => 'contact',
				noadd => 1,
			},
			strPresidentName=> {
				label => $clubID ? "Other $Data->{'LevelNames'}{$Defs::LEVEL_CLUB} Contact 1 - Name" : '',
				value => $field->{strPresidentName},
				type  => 'text',
				size  => '20',
				maxsize => '50',
				sectionname => 'contact',
				noadd => 1,
			},
			strPresidentEmail=> {
				label => $clubID ? "Other $Data->{'LevelNames'}{$Defs::LEVEL_CLUB} Contact 1 - Email" : '',
				value => $field->{strPresidentEmail},
				type  => 'text',
				size  => '20',
				maxsize => '50',
				sectionname => 'contact',
				noadd => 1,
			},
			strPresidentPhone=> {
				label => $clubID ? "Other $Data->{'LevelNames'}{$Defs::LEVEL_CLUB} Contact 1 - Phone" : '',
				value => $field->{strPresidentPhone},
				type  => 'text',
				size  => '20',
				maxsize => '50',
				sectionname => 'contact',
				noadd => 1,
			},
      			intShowPresident => {
				label => $clubID ? "Show Other $Data->{'LevelNames'}{$Defs::LEVEL_CLUB} Contact 1" : '',
        			value => $field->{intShowPresident},
        			type  => 'checkbox',
        			sectionname => 'contact',
       		 		displaylookup => {1 => 'Yes', 0 => 'No'},
      			},
			strSecretaryName=> {
				label => $clubID ? "Other $Data->{'LevelNames'}{$Defs::LEVEL_CLUB} Contact 2 - Name" : '',
				value => $field->{strSecretaryName},
				type  => 'text',
				size  => '20',
				maxsize => '50',
				sectionname => 'contact',
				noadd => 1,
			},
			strSecretaryEmail=> {
				label => $clubID ? "Other $Data->{'LevelNames'}{$Defs::LEVEL_CLUB} Contact 2 - Email" : '',
				value => $field->{strSecretaryEmail},
				type  => 'text',
				size  => '20',
				maxsize => '50',
				sectionname => 'contact',
				noadd => 1,
			},
			strSecretaryPhone=> {
				label => $clubID ? "Other $Data->{'LevelNames'}{$Defs::LEVEL_CLUB} Contact 2 - Phone" : '',
				value => $field->{strSecretaryPhone},
				type  => 'text',
				size  => '20',
				maxsize => '50',
				sectionname => 'contact',
				noadd => 1,
			},
      			intShowSecretary=> {
				    label => $clubID ? "Show Other $Data->{'LevelNames'}{$Defs::LEVEL_CLUB} Contact 2" : '',
        			value => $field->{intShowSecretary},
        			type  => 'checkbox',
        			sectionname => 'contact',
       		 		displaylookup => {1 => 'Yes', 0 => 'No'},
				noadd => 1,
      			},
			strTreasurerName=> {
				label => $clubID ? "Other $Data->{'LevelNames'}{$Defs::LEVEL_CLUB} Contact 3 - Name" : '',
				value => $field->{strTreasurerName},
				type  => 'text',
				size  => '20',
				maxsize => '50',
				sectionname => 'contact',
				noadd => 1,
			},
			strTreasurerEmail=> {
				label => $clubID ? "Other $Data->{'LevelNames'}{$Defs::LEVEL_CLUB} Contact 3 - Email" : '',
				value => $field->{strTreasurerEmail},
				type  => 'text',
				size  => '20',
				maxsize => '50',
				sectionname => 'contact',
				noadd => 1,
			},
			strTreasurerPhone=> {
				label => $clubID ? "Other $Data->{'LevelNames'}{$Defs::LEVEL_CLUB} Contact 3 - Phone" : '',
				value => $field->{strTreasurerPhone},
				type  => 'text',
				size  => '20',
				maxsize => '50',
				sectionname => 'contact',
				noadd => 1,
			},
      			intShowTreasurer=> {
				label => $clubID ? "Show Other $Data->{'LevelNames'}{$Defs::LEVEL_CLUB} Contact 3" : '',
        			value => $field->{intShowTreasurer},
        			type  => 'checkbox',
        			sectionname => 'contact',
       		 		displaylookup => {1 => 'Yes', 0 => 'No'},
      			},
			strRegistrarName=> {
				label => $clubID ? "Other $Data->{'LevelNames'}{$Defs::LEVEL_CLUB} Contact 4 - Name" : '',
				value => $field->{strRegistrarName},
				type  => 'text',
				size  => '20',
				maxsize => '50',
				sectionname => 'contact',
				noadd => 1,
			},
			strRegistrarEmail=> {
				label => $clubID ? "Other $Data->{'LevelNames'}{$Defs::LEVEL_CLUB} Contact 4 - Email" : '',
				value => $field->{strRegistrarEmail},
				type  => 'text',
				size  => '20',
				maxsize => '50',
				sectionname => 'contact',
				noadd => 1,
			},
			strRegistrarPhone=> {
				label => $clubID ? "Other $Data->{'LevelNames'}{$Defs::LEVEL_CLUB} Contact 4 - Phone" : '',
				value => $field->{strRegistrarPhone},
				type  => 'text',
				size  => '20',
				maxsize => '50',
				sectionname => 'contact',
				noadd => 1,
			},
      		intShowRegistrar => {
				label => $clubID ? "Show Other $Data->{'LevelNames'}{$Defs::LEVEL_CLUB} Contact 4" : '',
        		value => $field->{intShowRegistrar},
        		type  => 'checkbox',
        		sectionname => 'contact',
       		 	displaylookup => {1 => 'Yes', 0 => 'No'},
      		},
			strVenueName => {
				label => 'Venue Name',
				value => $field->{strVenueName},
				type  => 'text',
				size  => '50',
				maxsize => '100',
				sectionname => 'location',
			},
			strVenueAddress => {
				label => 'Venue Address Line 1',
				value => $field->{strVenueAddress},
				type  => 'text',
				size  => '50',
				maxsize => '100',
				sectionname => 'location',
			},
			strVenueAddress2 => {
				label => 'Venue Address Line 2',
				value => $field->{strVenueAddress2},
				type  => 'text',
				size  => '50',
				maxsize => '100',
				sectionname => 'location',
			},			
			strVenueSuburb => {
				label => 'Venue Suburb',
				value => $field->{strVenueSuburb},
				type  => 'text',
				size  => '30',
				maxsize => '100',
				sectionname => 'location',
			},
			strVenueState => {
				label => 'Venue State',
				value => $field->{strVenueState},
				type  => 'text',
				size  => '30',
				maxsize => '50',
				sectionname => 'location',
			},
			strVenueCountry => {
				label => 'Venue Country',
				value => $field->{strVenueCountry},
				type  => 'text',
				size  => '30',
				maxsize => '50',
				sectionname => 'location',
			},
			strVenuePostalCode => {
				label => 'Venue Postal Code',
				value => $field->{strVenuePostalCode},
				type  => 'text',
				size  => '15',
				maxsize => '15',
				sectionname => 'location',
			},
			strFax => {
				label => 'Venue Phone',
				value => $field->{strFax},
				type  => 'text',
				size  => '20',
				maxsize => '20',
				sectionname => 'location',
			},
			strURL => {
				label => 'Website address',
				value => $field->{strURL},
				type  => 'text',
				size  => '20',
				maxsize => '250',
				sectionname => 'location',
				pretext => 'http://',
			},
			strEmail => {
				label => 'Venue Email',
				value => $field->{strEmail},
				type  => 'text',
				size  => '35',
				maxsize => '255',
				validate => 'EMAIL',
				sectionname => 'location',
			},
      intMon => {
        label => 'Monday',
        value => $field->{intMon},
        type  => 'checkbox',
        sectionname => 'availability',
        displaylookup => {1 => 'Yes', 0 => 'No'},
      },
      intTue => {
        label => 'Tuesday',
        value => $field->{intTue},
        type  => 'checkbox',
        sectionname => 'availability',
        displaylookup => {1 => 'Yes', 0 => 'No'},
      },
      intWed => {
        label => 'Wednesday',
        value => $field->{intWed},
        type  => 'checkbox',
        sectionname => 'availability',
        displaylookup => {1 => 'Yes', 0 => 'No'},
      },
      intThu => {
        label => 'Thursday',
        value => $field->{intThu},
        type  => 'checkbox',
        sectionname => 'availability',
        displaylookup => {1 => 'Yes', 0 => 'No'},
      },
      intFri => {
        label => 'Friday',
        value => $field->{intFri},
        type  => 'checkbox',
        sectionname => 'availability',
        displaylookup => {1 => 'Yes', 0 => 'No'},
      },
      intSat => {
        label => 'Saturday',
        value => $field->{intSat},
        type  => 'checkbox',
        sectionname => 'availability',
        displaylookup => {1 => 'Yes', 0 => 'No'},
      },
      intSun => {
        label => 'Sunday',
        value => $field->{intSun},
        type  => 'checkbox',
        sectionname => 'availability',
        displaylookup => {1 => 'Yes', 0 => 'No'},
      },
			strSessionDurations => {
				label => 'Session Durations',
				value => $field->{strSessionDurations},
				type  => 'text',
				size  => '20',
				maxsize => '100',
				sectionname => 'availability',
			},
			strTimes => {
				label => 'Session Times',
				value => $field->{strTimes},
				type  => 'text',
				size  => '20',
				maxsize => '100',
				sectionname => 'availability',
			},
      dtStart => {
        label => 'Season Start Date',
        value => $field->{dtStart},
        type  => 'date',
        posttext => '(00/00/0000 to remove date)',
        format => 'dd/mm/yyyy',
				sectionname => 'availability',
				validate => 'DATE',
      },
      dtFinish => {
        label => 'Season Finish Date',
        value => $field->{dtFinish},
        type  => 'date',
        posttext => '(00/00/0000 to remove date)',
        format => 'dd/mm/yyyy',
				sectionname => 'availability',
				validate => 'DATE',
      },
      PostalCodesServiced => {
        label => "Postal Codes Serviced<br>(You should limit the postcodes<br>entered here to perhaps 6-10<br>relevant and local codes.  <br>You can enter multiple codes by <br>using a comma between them.  EG:  3000, 3001, 3002)",
        value => $field->{PostalCodesServiced},
        type  => 'textarea',
        sectionname => 'availability',
        rows => 5,
        cols=> 45,
				SkipProcessing => 1,
      },
	intPublicShow=> {
        label => 'Show us in the Public Locator',
        value => $field->{intPublicShow},
        type  => 'checkbox',
        sectionname => 'availability',
        displaylookup => {1 => 'Yes', 0 => 'No'},
      },
#      intRegisterID => {
#				label => $AllowRegistrations ? 'Public Registrations':'',
#        value => $field->{intRegisterID},
#        type  => 'lookup',
#        options => \%registrationOptions,
#        sectionname => 'availability',
#      },
      intRegistrationFormID => {
        label => $AllowRegistrations ? 'Public Registrations':'',
        value => $field->{intRegistrationFormID},
        type  => 'lookup',
        options => \%forms,
        sectionname => 'availability',
      },
      strNotes=> {
        label => "General information to display on the locator<br>(Tip:  Use this section to tell people<br>about your organisation or provide<br>information not covered in the standard <br>fields here.   It's your opportunity to make a great impression.)",
        value => $field->{strNotes},
        type  => 'textarea',
        sectionname => 'availability',
        rows => 5,
        cols=> 45,
      },

##
      mapdesc => {
        label => 'map desc',
        type => 'textvalue',
        value => '<p>Enter Latitude and Longtitude in the boxes below or drag the map marker to the correct location.</p>',
        sectionname=>'mapping',
        SkipProcessing => 1,
      },
      mapblock => {
        label => "Map",
        value => '',
        posttext => ' <div id="map_canvas" style="width:450px;height:450px;border:1px solid #888;"></div>',
        type  => 'hidden',
        size  => '40',
        sectionname=>'mapping',
        SkipProcessing => 1,
      },
      dblLat=> {
        label => "Latitude",
        value => $field->{dblLat},
        type  => 'text',
        size  => '20',
        sectionname=>'mapping',
				compulsory => 1,
      },
      dblLong=> {
        label => "Longtitude",
        value => $field->{dblLong},
        type  => 'text',
        size  => '20',
        sectionname=>'mapping',
				compulsory => 1,
      },
##

		},
		OLDorder=> [qw(strContact1Name strContact1Title strContact1Phone strContact2Name strContact2Title strContact2Phone strPresidentName strPresidentEmail strPresidentPhone intShowPresident strSecretaryName strSecretaryEmail strSecretaryPhone intShowSecretary strTreasurerName strTreasurerEmail strTreasurerPhone intShowTreasurer strRegistrarName strRegistrarEmail strRegistrarPhone intShowRegistrar strVenueName strVenueAddress strVenueAddress2 strVenueSuburb strVenueState strVenueCountry strVenuePostalCode strEmail strURL strFax intMon intTue intWed intThu intFri intSat intSun strTimes strSessionDurations dtStart dtFinish intPublicShow intRegisterID PostalCodesServiced strNotes)],
		OLD2order => [qw(strVenueName strVenueAddress strVenueAddress2 strVenueSuburb strVenuePostalCode strVenueState strVenueCountry strEmail strURL strFax intMon intTue intWed intThu intFri intSat intSun strTimes strSessionDurations dtStart dtFinish intPublicShow intRegisterID PostalCodesServiced strNotes strContact1Name strContact1Title strContact1Phone strContact2Name strContact2Title strContact2Phone strPresidentName strPresidentEmail strPresidentPhone intShowPresident strSecretaryName strSecretaryEmail strSecretaryPhone intShowSecretary strTreasurerName strTreasurerEmail strTreasurerPhone intShowTreasurer strRegistrarName strRegistrarEmail strRegistrarPhone intShowRegistrar)],
		order => [qw(strVenueName strVenueAddress strVenueAddress2 strVenueSuburb strVenuePostalCode strVenueState strVenueCountry strEmail strURL strFax intMon intTue intWed intThu intFri intSat intSun strTimes strSessionDurations dtStart dtFinish strCompetitions strCompOrganizer strCompCosts intPublicShow intRegistrationFormID PostalCodesServiced strNotes mapdesc dblLat dblLong mapblock)],
 
    sections => [
      ['location','Playing Venue and General Details'],
      ['availability','Active Days and Times'],
      ['contact','Previous Contact Details'],
      ['comp','Competition Details'],
      ['mapping','Location Details'],

		],
		options => {
			labelsuffix => ':',
			hideblank => 1,
			target => $Data->{'target'},
			formname => 'n_form',
			submitlabel => 'Update Locator',
			introtext => '',
			addSQL => qq[
				INSERT INTO tblAssocServices (intAssocID,  intClubID, --FIELDS--)
				VALUES ($assocID, $clubID, --VAL--)
			],
      updateSQL => qq[
        UPDATE tblAssocServices
          SET --VAL--
        WHERE intAssocID=$assocID
		AND intClubID = $clubID
        ],
			NoHTML => 1,
			stopAfterAction => 1,
      auditFunction=> \&auditLog,
      auditAddParams => [
        $Data,
        'Add',
        'Locator'
      ],
      auditEditParams => [
        $assocID,
        $Data,
        'Update',
        'Locator'
      ],
      afterupdateFunction => \&postServicesUpdate,
      afterupdateParams => [$option,$Data,$Data->{'db'}, $assocID, $clubID],
      afteraddFunction => \&postServicesUpdate,
      afteraddParams => [$option,$Data,$Data->{'db'}, $assocID, $clubID],
			LocaleMakeText => $Data->{'lang'},
		},
    carryfields =>  {
      client => $client,
      a=> $action,
    },

	);

    if ($Data->{'SystemConfig'}{'AssocServicesCompDetails'}) {
        $FieldDefinitions{'fields'}{'strCompetitions'} = {
            label => 'Competitions',
            value => $field->{strCompetitions},
            type  => 'textarea',
            rows  => 5,
            cols  => 45,
            sectionname => 'comp',
        };
        $FieldDefinitions{'fields'}{'strCompOrganizer'} = {
            label => 'Competition Organizer',
            value => $field->{strCompOrganizer},
            type  => 'textarea',
            rows  => 5,
            cols  => 45,
            sectionname => 'comp',
        };
        $FieldDefinitions{'fields'}{'strCompCosts'} = {
            label => 'Competition Costs',
            value => $field->{strCompCosts},
            type  => 'textarea',
            rows  => 5,
            cols  => 45,
            sectionname => 'comp',
        };
    }

	my $resultHTML='';
  ($resultHTML, undef )=handleHTMLForm(\%FieldDefinitions, undef, $option, '',$Data->{'db'});
	my $title='Locator';
    my $entityTypeID = ($clubID>0) 
        ? $Defs::LEVEL_CLUB 
        : $Defs::LEVEL_ASSOC;
    my $entityID = ($entityTypeID == $Defs::LEVEL_CLUB) 
        ? $clubID
        : $assocID;
    my $scMenu = getServicesContactsMenu($Data, $entityTypeID, $entityID, $Defs::SC_MENU_SHORT, $Defs::SC_MENU_CURRENT_OPTION_SERVICES);

    $resultHTML = showContacts($Data,1) . qq[<br><br>] . $resultHTML;
  if($option eq 'display')  {
    my $chgoptions='';
		my $txt_edit=$Data->{'lang'}->txt('Edit');
		my $edit_option = $clubID ? 'c_e' : 'a_e';
    $chgoptions.=qq[<div class="changeoptions"><span class = "button-small generic-button"><a href="$Data->{'target'}?client=$client&amp;a=A_SV_DTE">$txt_edit</a></span></div> ] if($Data->{'clientValues'}{'authLevel'} >= $Defs::LEVEL_CLUB and allowedAction($Data, $edit_option));
    $title=$chgoptions.$title;
  }
	else	{
		$resultHTML = qq[
<p>This information is used to populate your sport's postcode locator.  It is used to help individuals locate a club or league they would like to join.</p>
<p>Please ensure the information you provide here is information you wish to be publically displayed.  </p>
<p><b>Tip:</b>  Ensure you consider carefully what information you provide here.</p>
<p>Where you leave a field blank then the details will not appear on the Locator. If there is any information you do not wish to show in the public locator then simply leave that field blank.</p>
	].$resultHTML; #'

    my $original_lat = $field->{'dblLat'} || '-25.901820984476252';
    my $original_long = $field->{'dblLong'} || '134.00135040279997';
    my $zoomstr = $field->{'dblLat'} ? "zoom : 15," : '';
    $resultHTML .= qq[
    <script src="//maps.google.com/maps/api/js?sensor=true" type="text/javascript"></script>
    <script src="js/jquery.ui.map.full.min.js" type="text/javascript"></script>
    <script type="text/javascript">
      jQuery(function() {
        var StartLatLng = new google.maps.LatLng($original_lat, $original_long);
        jQuery('#map_canvas').gmap({
          'center': StartLatLng,
          'streetViewControl': false,
          'panControl': false,
          $zoomstr
          zoomControlOptions :  {style: google.maps.ZoomControlStyle.SMALL}
        });
        jQuery('#map_canvas').gmap('addMarker', {'position': StartLatLng, 'draggable': true, 'bounds': false}).dragend( function(event) {
          jQuery('#l_dblLat').val(event.latLng.lat());
          jQuery('#l_dblLong').val(event.latLng.lng());
        })
        jQuery('#n_formID input:text').change(updateMapFromAddress);
        function updateMapFromAddress () {
          if( jQuery('#orig_dblLat').val().length > 1 || jQuery('#orig_dblLong').val().length > 1)  {
            // coords already set
            return false;
          }
          var address = jQuery("#l_strVenueAddress").val() + ' ' + jQuery("#l_strVenueAddress2").val() + ' ' + jQuery("#l_strVenueSuburb").val() + ' ' + jQuery("#l_strVenueState").val() + ' ' + jQuery("#l_strVenueCountry").val();
          jQuery('#map_canvas').gmap('search', {'address': address}, function(results, status) {
            if ( status === 'OK' ) {
              var newpos = results[0].geometry.location;
              //jQuery('#map_canvas').gmap('get','map').setCenter(newpos);
              jQuery('#map_canvas').gmap('get','map').fitBounds(results[0].geometry.viewport);
              var marker = jQuery('#map_canvas').gmap('get', 'markers')[0];
              marker.setPosition(newpos);
              jQuery('#l_dblLat').val(newpos.lat());
              jQuery('#l_dblLong').val(newpos.lng());
            }
            else {
              //alert("Geocode was not successful for the following reason: " + status);
            }
          });
        }
        updateMapFromAddress(); // Run first time on load
    });
    </script>
    <input type = "hidden" value = "$field->{'dblLat'}" name = "orig_dblLat" id = "orig_dblLat">
    <input type = "hidden" value = "$field->{'dblLong'}" name = "orig_dblLong" id = "orig_dblLong">
    ];
	}
	$resultHTML = $scMenu.$resultHTML;
	return ($resultHTML,$title);
}


sub loadAssocServicesDetails {
  my($db, $id, $clubID) = @_;
	$id ||= 0;
	$clubID ||= 0;
  my $statement=qq[
    SELECT *, DATE_FORMAT(dtStart,'%d/%m/%Y') AS dtStart, DATE_FORMAT(dtFinish,'%d/%m/%Y') AS dtFinish
    FROM tblAssocServices
    WHERE intAssocID=$id
	AND intClubID = $clubID
  ];
  my $query = $db->prepare($statement);
  $query->execute;
	my $field=$query->fetchrow_hashref();
  $query->finish;
  foreach my $key (keys %{$field})  { if(!defined $field->{$key}) {$field->{$key}='';} }

	#Get info re postcodes
  my $pcode_st=qq[
    SELECT strPostalCode
    FROM tblAssocServicesPostalCode
    WHERE intAssocID=$id
	AND intClubID = $clubID
  ];
  $query = $db->prepare($pcode_st);
  $query->execute;
	my @pcodes=();
	while(my ($pcode) = $query->fetchrow_array())	{
		next if !$pcode;
		push @pcodes, $pcode;
	}
	$field->{'PostalCodesServiced'}=join(',',@pcodes) || '';
  return $field;
}

sub postServicesUpdate  {
  my($id,$params, $action,$Data,$db,$assocID, $clubID)=@_;
	
	$clubID ||= 0;
	my $aID=$assocID;
  return (0,undef) if !$db;
  return (0,undef) if !$aID;
	#Handle PostalCodes
	#First delete existing ones.
	my $st_del=qq[DELETE FROM tblAssocServicesPostalCode WHERE intAssocID=$aID AND intClubID = $clubID];	
	$db->do($st_del);
	
	my $pcodes=$params->{'d_PostalCodesServiced'} || '';
	if($pcodes)	{
		my $s_add=qq[INSERT INTO tblAssocServicesPostalCode (intAssocID, intClubID, strPostalCode) VALUES ($aID,$clubID, ?)];
		my @pcodes=split /,/,$pcodes;
		my $q_add=$db->prepare($s_add);
		for my $i (@pcodes)	{ $q_add->execute($i); }
	}
	return (1,'');
}


1;
