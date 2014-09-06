package Venues;
require Exporter;
@ISA = qw(Exporter);
@EXPORT=qw(handleVenues getVenues loadVenueDetails );
@EXPORT_OK=qw(handleVenues getVenues loadVenueDetails );

use strict;
use Reg_common;
use Utils;
use HTMLForm;
use AuditLog;
use CGI qw(unescape param);
use FormHelpers;
use GridDisplay;
use Log;
use EntityStructure;
use WorkFlow;

use RecordTypeFilter;
use RuleMatrix;

sub handleVenues    {
    my ($action, $Data)=@_;

    my $venueID= param('venueID') || 0;
    my $resultHTML='';
    my $title='';
    if ($action =~/^VENUE_DT/) {
        ($resultHTML,$title)=venue_details($action, $Data, $venueID);
    }
    elsif ($action =~/^VENUE_L/) {
        #List Venues
        my $tempResultHTML = '';
        ($tempResultHTML,$title)=listVenues($Data);
        $resultHTML .= $tempResultHTML;
    }
        
    return ($resultHTML,$title);
}

sub venue_details   {
    my ($action, $Data, $venueID)=@_;

    return '' if ($venueID and !venueAllowed($Data, $venueID));
    my $option='display';
    $option='edit' if $action eq 'VENUE_DTE';# and allowedAction($Data, 'venue_e');
    $option='add' if $action eq 'VENUE_DTA';# and allowedAction($Data, 'venue_a');
    $venueID=0 if $option eq 'add';
    my $field=loadVenueDetails($Data->{'db'}, $venueID) || ();
    
    my $intRealmID = $Data->{'Realm'} ? $Data->{'Realm'} : 0;
    my $client=setClient($Data->{'clientValues'}) || '';
    
    my $authID = getID($Data->{'clientValues'}, $Data->{'clientValues'}{'authLevel'});
    my $paymentRequired = 0;
    if ($option eq 'add')   {
        my %Reg=();
        $Reg{'registrationNature'}='NEW';
        my $matrix_ref = getRuleMatrix($Data, $Data->{'clientValues'}{'authLevel'}, getLastEntityLevel($Data->{'clientValues'}), $Defs::LEVEL_VENUE, '', 'ENTITY', \%Reg);
        $paymentRequired = $matrix_ref->{'intPaymentRequired'} || 0;
    }
    my %FieldDefinitions = (
    fields=>  {
      strFIFAID => {
        label => 'FIFA ID',
        value => $field->{strFIFAID},
        type  => 'text',
        size  => '40',
        maxsize => '150',
        readonly =>1,
        sectionname => 'details',
      },
      strLocalName => {
        label => 'Name',
        value => $field->{strLocalName},
        type  => 'text',
        size  => '40',
        maxsize => '150',
        sectionname => 'details',
        compulsory => 1,
      },
      strLocalShortName => {
        label => 'Short Name',
        value => $field->{strLocalShortName},
        type  => 'text',
        size  => '30',
        maxsize => '50',
        sectionname => 'details',
        compulsory => 1,
      },      
      strLatinName => {
        label => 'Name (Latin)',
        value => $field->{strLatinName},
        type  => 'text',
        size  => '40',
        maxsize => '150',
        sectionname => 'details',
      },
      strLatinShortName => {
        label => 'Short Name (Latin)',
        value => $field->{strLatinShortName},
        type  => 'text',
        size  => '30',
        maxsize => '50',
        sectionname => 'details',
      },
      
      strStatus => {
          label => 'Status',
    	  value => $field->{strStatus} || 'ACTIVE',
    	  type => 'lookup',  
    	  options => \%Defs::entityStatus,
    	  sectionname => 'details',
    	  readonly => $Data->{'clientValues'}{'authLevel'} >= $Defs::LEVEL_NATIONAL ? 0 : 1,
          noadd=>1,
      },
      
      strAddress => {
        label => 'Address',
        value => $field->{strAddress},
        type  => 'text',
        size  => '40',
        maxsize => '50',
        sectionname => 'details',
      },
      strTown => {
        label => 'Town',
        value => $field->{strTown},
        type  => 'text',
        size  => '30',
        maxsize => '50',
        sectionname => 'details',
      },
      strRegion => {
        label => 'Region',
        value => $field->{strRegion},
        type  => 'text',
        size  => '30',
        maxsize => '50',
        sectionname => 'details',
      },
      strISOCountry => {
        label => 'Country (ISO)',
        value => $field->{strISOCountry},
        type  => 'text',
        size  => '30',
        maxsize => '50',
        sectionname => 'details',
      },
      strPostalCode => {
        label => 'Postal Code',
        value => $field->{strPostalCode},
        type  => 'text',
        size  => '15',
        maxsize => '15',
        sectionname => 'details',
      },
      strPhone => {
        label => 'Phone',
        value => $field->{strPhone},
        type  => 'text',
        size  => '20',
        maxsize => '20',
        sectionname => 'details',
      },
      strFax => {
        label => 'Fax',
        value => $field->{strFax},
        type  => 'text',
        size  => '20',
        maxsize => '20',
        sectionname => 'details',
      },
      strEmail => {
        label => 'Email',
        value => $field->{strEmail},
        type  => 'text',
        size  => '35',
        maxsize => '250',
        validate => 'EMAIL',
        sectionname => 'details',
      },
      strWebURL => {
        label => 'Web',
        value => $field->{strWebURL},
        type  => 'text',
        size  => '35',
        maxsize => '250',
        sectionname => 'details',
      },
      strDescription => {
        label => 'Description',
        value => $field->{strDescription},
        type => 'textarea',
        rows => '10',
        cols => '40',
        sectionname => 'details',
      },
      SP1  => {
        type =>'_SPACE_',
        sectionname => 'details',
      },
      intCapacity => {
        label => 'Capacity',
        value => $field->{intCapacity},
        type  => 'text',
        size  => '10',
        maxsize => '10',
        validate => 'NUMBER',
        sectionname => 'details',
      },
      intCoveredSeats=> {
        label => 'Covered Seats',
        value => $field->{intCoveredSeats},
        type  => 'text',
        size  => '10',
        maxsize => '10',
        validate => 'NUMBER',
        sectionname => 'details',
      },
      intUncoveredSeats=> {
        label => 'Uncovered Seats',
        value => $field->{intUncoveredSeats},
        type  => 'text',
        size  => '10',
        maxsize => '10',
        sectionname => 'details',
        validate => 'NUMBER',
      },
      intCoveredStandingPlaces => {
        label => 'Covered Standing Places',
        value => $field->{intCoveredStandingPlaces},
        type  => 'text',
        size  => '10',
        maxsize => '10',
        validate => 'NUMBER',
        sectionname => 'details',
      },
      intUncoveredStandingPlaces => {
        label => 'Uncovered Standing Places',
        value => $field->{intUncoveredStandingPlaces},
        type  => 'text',
        size  => '10',
        maxsize => '10',
        validate => 'NUMBER',
        sectionname => 'details',
      },
      intLightCapacity=> {
        label => 'Light Capacity',
        value => $field->{intLightCapacity},
        type  => 'text',
        size  => '10',
        maxsize => '10',
        validate => 'NUMBER',
        sectionname => 'details',
      },
      strGroundNature => {
        label => 'Ground Nature',
        value => $field->{strGroundNature},
        type  => 'text',
        size  => '30',
        maxsize => '50',
        sectionname => 'details',
      },
      strDiscipline => {
        label => 'Discipline',
        value => $field->{strDiscipline},
        type  => 'text',
        size  => '30',
        maxsize => '50',
        sectionname => 'details',
      },
      strMapRef => {
        label       => "Map Reference (Printed Map)",
        value       => $field->{strMapRef},
        type        => 'text',
        size        => '10',
        sectionname => 'details',
      },
      intMapNumber => {
        label       => "Map Number (Printed Map)",
        value       => $field->{intMapNumber},
        type        => 'text',
        size        => '10',
        sectionname => 'details',
      },
      mapdesc => {
        label => 'map desc',
        type  => 'textvalue',
        value => '<p>Enter Latitude and Longtitude in the boxes below or drag the map marker to the correct location.</p>',
        sectionname    => 'mapping',
        SkipProcessing => 1,
      },
      mapblock => {
        label    => "Map",
        value    => '',
        posttext => ' <div id="map_canvas" style="width:450px;height:450px;border:1px solid #888;"></div>',
        type           => 'hidden',
        size           => '40',
        sectionname    => 'mapping',
        SkipProcessing => 1,
      },
      dblLat => {
        label       => "Latitude",
        value       => $field->{dblLat},
        type        => 'text',
        size        => '20',
        sectionname => 'mapping',
      },
      dblLong => {
        label       => "Longtitude",
        value       => $field->{dblLong},
        type        => 'text',
        size        => '20',
        sectionname => 'mapping',
      },
    },
    order => [qw(
        strFIFAID
        strLocalName
        strLocalShortName
        strLatinName
        strLatinShortName
        strStatus
        dtFrom
        dtTo
        strISOCountry
        strRegion
        strPostalCode
        strTown
        strAddress
        strWebURL
        strEmail
        strPhone
        strFax
        intCapacity
        intCoveredSeats
        intUncoveredSeats
        intCoveredStandingPlaces
        intUncoveredStandingPlaces
        intLightCapacity
        strGroundNature
        strDiscipline
        strMapRef
        intMapNumber
        mapdesc
        dblLat
        dblLong
        mapblock
        strDescription
    )],
    sections => [ 
        [ 'details', "Venue Details" ], 
        [ 'mapping', "Online Mapping" ], 
    ],
    options => {
      labelsuffix => ':',
      hideblank => 1,
      target => $Data->{'target'},
      formname => 'n_form',
      submitlabel => $Data->{'lang'}->txt('Update'),
      introtext => $Data->{'lang'}->txt('HTMLFORM_INTROTEXT'),
      NoHTML => 1, 
      updateSQL => qq[
          UPDATE tblEntity
            SET --VAL--
          WHERE intEntityID=$venueID
              AND intRealmID= $intRealmID
      ],
      addSQL => qq[
          INSERT INTO tblEntity (
              intRealmID, 
              intEntityLevel, 
              intCreatedByEntityID,
              intPaymentRequired,
              strStatus,
              intDataAccess,
              --FIELDS-- 
          )
          VALUES (
              $intRealmID, 
              $Defs::LEVEL_VENUE, 
              $authID,
              $paymentRequired,
              'PENDING',
              $Defs::DATA_ACCESS_FULL,
              --VAL-- 
          )
      ],
      auditFunction=> \&auditLog,
      auditAddParams => [
        $Data,
        'Add',
        'Venue'
      ],
      auditEditParams => [
        $venueID,
        $Data,
        'Update',
        'Venue'
      ],

      afteraddFunction => \&postVenueAdd,
      afteraddParams => [$option,$Data,$Data->{'db'}],
      afterupdateFunction => \&postVenueUpdate,
      afterupdateParams => [$option,$Data,$Data->{'db'}, $venueID],

      LocaleMakeText => $Data->{'lang'},
    },
    carryfields =>  {
      client => $client,
      a=> $action,
      venueID=> $venueID,
    },
  );
    my $resultHTML='';
    ($resultHTML, undef )=handleHTMLForm(\%FieldDefinitions, undef, $option, '',$Data->{'db'});
    my $title=qq[Venue- $field->{strLocalName}];

    my $chgoptions='';
    
    if($option eq 'display')  {
        # Edit Venue.
        $chgoptions.=qq[<span class = "button-small generic-button"><a href="$Data->{'target'}?client=$client&amp;a=VENUE_DTE&amp;venueID=$venueID">].$Data->{'lang'}->txt('Edit Venue').qq[</a></span> ] if allowedAction($Data, 'venue_e');
    }
    elsif ($option eq 'edit') {
        # Delete Venue.
        my $venueObj = new EntityObj('db'=>$Data->{db},ID=>$venueID,realmID=>$intRealmID);
        
        $chgoptions.=qq[<span class = "button-small generic-button"><a href="$Data->{'target'}?client=$client&amp;a=VENUE_DEL&amp;venueID=$venueID" onclick="return confirm('Are you sure you want to delete this venue');">Delete Venue</a> ] if $venueObj->canDelete();
    }
    
    $chgoptions=qq[<div class="changeoptions">$chgoptions</div>] if $chgoptions;
    $title=$chgoptions.$title;
    
    $title="Add New Venue" if $option eq 'add';

    if($option ne 'display') {
        my $original_lat = $field->{'dblLat'} || '-25.901820984476252';
        my $original_long = $field->{'dblLong'} || '134.00135040279997';

        my $zoomstr = $field->{'dblLat'} ? "zoom : 15," : '';
        $resultHTML .= qq[
<script src="https://maps.google.com/maps/api/js?sensor=true" type="text/javascript"></script>
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
         
                    jQuery('#n_formID input').change(updateMapFromAddress);

                    function updateMapFromAddress   () {
                        if( jQuery('#orig_dblLat').val().length > 1 || jQuery('#orig_dblLong').val().length > 1)    {
                            // coords already set
                            return false;
                        } 

                        var address = jQuery("#l_strAddress1").val() + ' ' + jQuery("#l_strAddress2").val() + ' ' + jQuery("#l_strSuburb").val() + ' ' + jQuery("#l_strState").val() + ' ' + jQuery("#l_strCountry").val();
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
    my $text = qq[<p style = "clear:both;"><a href="$Data->{'target'}?client=$client&amp;a=VENUE_L">Click here</a> to return to list of Venues</p>];
    $resultHTML = $text.$resultHTML.$text;

    return ($resultHTML,$title);
}

sub loadVenueDetails {
  my($db, $id) = @_;
                                                                                                        
  my $statement=qq[
    SELECT 
      intEntityID,
      intEntityLevel,
      intRealmID,
      strEntityType,
      strStatus,
      intRealmApproved,
      intCreatedByEntityID,
      strFIFAID,
      strLocalName,
      strLocalShortName,
      strLocalFacilityName,
      strLatinName,
      strLatinShortName,
      strLatinFacilityName,
      dtFrom,
      dtTo,
      strISOCountry,
      strRegion,
      strPostalCode,
      strTown,
      strAddress,
      strWebURL,
      strEmail,
      strPhone,
      strFax,
      strContactTitle,
      strContactEmail,
      strContactPhone,
      dtAdded,
      tTimeStamp,
      intCapacity,
      intCoveredSeats,
      intUncoveredSeats,
      intCoveredStandingPlaces,
      intUncoveredStandingPlaces,
      intLightCapacity,
      strGroundNature,
      strDiscipline,
      strMapRef,
      intMapNumber,
      dblLat,
      dblLong,
      strDescription
    FROM tblEntity
    WHERE intEntityID = ?
        AND intEntityLevel = $Defs::LEVEL_VENUE
  ];
  my $query = $db->prepare($statement);
  $query->execute($id);
  my $field=$query->fetchrow_hashref();
  $query->finish;
                                                                                                        
  foreach my $key (keys %{$field})  { if(!defined $field->{$key}) {$field->{$key}='';} }
  return $field;
}

sub listVenues  {
    my($Data) = @_;

    my $resultHTML = '';
    my $client = unescape($Data->{client});

    my %tempClientValues = getClient($client);

    my $entityID = getID($Data->{'clientValues'});

    my $statement =qq[
      SELECT 
        PN.intEntityID AS PNintEntityID, 
        CN.strLocalName, 
        CN.intEntityID AS CNintEntityID, 
        CN.intEntityLevel AS CNintEntityLevel, 
        PN.strLocalName AS PNName, 
        CN.strStatus
      FROM tblEntity AS PN 
        LEFT JOIN tblEntityLinks ON PN.intEntityID=tblEntityLinks.intParentEntityID 
        JOIN tblEntity as CN ON CN.intEntityID=tblEntityLinks.intChildEntityID
      WHERE PN.intEntityID = ?
        AND CN.strStatus <> 'DELETED'
        AND CN.intEntityLevel = ?
        AND CN.intDataAccess>$Defs::DATA_ACCESS_NONE
      ORDER BY CN.strLocalName
    ];
    my $query = $Data->{'db'}->prepare($statement);
    $query->execute($entityID, $Defs::LEVEL_VENUE);
    my $results=0;
    my @rowdata = ();
    while (my $dref = $query->fetchrow_hashref) {
      $results=1;
      #$tempClientValues{currentLevel} = $dref->{CNintEntityLevel};
      #setClientValue(\%tempClientValues, $dref->{CNintEntityLevel}, $dref->{CNintEntityID});
      #my $tempClient = setClient(\%tempClientValues);
      push @rowdata, {
        id => $dref->{'CNintEntityID'} || 0,
        strLocalName => $dref->{'strLocalName'} || '',
        strStatus => $dref->{'strStatus'} || '',
        strStatusText => $Data->{'lang'}->txt($Defs::entityStatus{$dref->{'strStatus'}} || ''),
        SelectLink => "$Data->{'target'}?client=$client&amp;a=VENUE_DTE&amp;venueID=$dref->{'CNintEntityID'}",
      };
    }
    $query->finish;

    my $addlink='';
    my $title=qq[Venues];
    {
        my $tempClient = setClient(\%tempClientValues);
        $addlink=qq[<span class = "button-small generic-button"><a href="$Data->{'target'}?client=$client&amp;a=VENUE_DTA">].$Data->{'lang'}->txt('Add').qq[</a></span>];

    }

    my $modoptions=qq[<div class="changeoptions">$addlink</div>];
    $title=$modoptions.$title;
    my $rectype_options=show_recordtypes(
        $Data, 
        $Data->{'lang'}->txt('Name'),
        '',
        \%Defs::entityStatus,
        { 'ALL' => $Data->{'lang'}->txt('All'), },
    ) || '';

    my @headers = (
        {
            type  => 'Selector',
            field => 'SelectLink',
        },
        {
            name  => $Data->{'lang'}->txt('Venue Name'),
            field => 'strLocalName',
        },
        {
            name   => $Data->{'lang'}->txt('Status'),
            field  => 'strStatusText',
            width  => 30,
        },
    );
    
    my $filterfields = [
        {
            field     => 'strLocalName',
            elementID => 'id_textfilterfield',
            type      => 'regex',
        },
        {
            field     => 'strStatus',
            elementID => 'dd_actstatus',
            allvalue  => 'ALL',
        },
    ];

    my $grid  = showGrid(
        Data    => $Data,
        columns => \@headers,
        rowdata => \@rowdata,
        gridid  => 'grid',
        width   => '99%',
        filters => $filterfields,
    );

    $resultHTML = qq[
        <div class="grid-filter-wrap">
            <div style="width:99%;">$rectype_options</div>
            $grid
        </div>
    ];

    return ($resultHTML,$title);
}

sub postVenueUpdate {
  my($id,$params,$action,$Data,$db, $entityID)=@_;
  return undef if !$db;
  $entityID ||= $id || 0;

  $Data->{'cache'}->delete('swm',"VenueObj-$entityID") if $Data->{'cache'};

}

sub postVenueAdd {
  my($id,$params,$action,$Data,$db)=@_;
  return undef if !$db;
  if($action eq 'add')  {
    if($id) {
      my $entityID = getID($Data->{'clientValues'});
      my $st=qq[
        INSERT INTO tblEntityLinks (intParentEntityID, intChildEntityID)
        VALUES (?,?)
      ];
      my $query = $db->prepare($st);
      $query->execute($entityID, $id);
      $query->finish();
      $Data->{'db'}=$db;
      createTempEntityStructure($Data); 
        #my $rc = addTasks($Data,$entityID, 0,0);
      addWorkFlowTasks($Data, 'ENTITY', 'NEW', $Data->{'clientValues'}{'authLevel'}, $id,0,0, 0);
    }
      ### A call TO createTempEntityStructure FROM EntityStructure   ###
      ### End call to createTempEntityStructure FROM EntityStructure###
    {
      my $cl=setClient($Data->{'clientValues'}) || '';
      my %cv=getClient($cl);
      my $clm=setClient(\%cv);
      return (0,qq[
        <div class="OKmsg"> $Data->{'LevelNames'}{$Defs::LEVEL_VENUE} Added Successfully</div><br>
        <a href="$Data->{'target'}?client=$cl&amp;venueID=$id&amp;a=VENUE_DT">Display Details for $params->{'d_strLocalName'}</a><br><br>
        <b>or</b><br><br>
        <a href="$Data->{'target'}?client=$cl&amp;a=VENUE_DTA&amp;l=$Defs::LEVEL_VENUE">Add another $Data->{'LevelNames'}{$Defs::LEVEL_VENUE}</a>

      ]);
    }
    
  } ## end if add
  
} ## end sub


sub venueAllowed    {
    #Check if this user is allowed access to this venue
    my ($Data, $venueID) = @_;

    #Get parent entity and check that the user has access to that

    my $st = qq[
        SELECT
            intParentEntityID
        FROM
            tblEntityLinks AS EL
                INNER JOIN tblEntity AS E
                    ON EL.intChildEntityID = E.intEntityID
        WHERE
            intChildEntityID = ?
            AND intEntityLevel = $Defs::LEVEL_VENUE
        LIMIT 1
    ];
    my $query = $Data->{'db'}->prepare($st);
    $query->execute($venueID);
    my $parentID = $query->fetchrow_array() || 0;
    $query->finish();
    return 0 if !$parentID;
    my $authID = getID($Data->{'clientValues'}, $Data->{'clientValues'}{'authLevel'});
    return 1 if($authID== $parentID);
    $st = qq[
        SELECT
            intRealmID
        FROM
            tblTempEntityStructure
        WHERE
            intParentID = ?
            AND intChildID = ?
            AND intDataAccess = $Defs::DATA_ACCESS_FULL
        LIMIT 1
    ];
    $query = $Data->{'db'}->prepare($st);
    $query->execute($authID, $parentID);
    my ($found) = $query->fetchrow_array();
    $query->finish();
    return $found ? 1 : 0;
}
1;


