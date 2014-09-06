#
# $Header: svn://svn/SWM/trunk/web/MapFinder/MapFinder.pm 11335 2014-04-22 02:58:17Z apurcell $
#

package MapFinder;

require Exporter;
@ISA       = qw(Exporter);
@EXPORT    = qw(search_results getAdvancedSearchBox);
@EXPORT_OK = qw(search_results getAdvancedSearchBox);

use strict;
use lib ".", "..", "../..", "../RegoForm";
use DBI;
use CGI qw(:standard escape param);
use DeQuote;
use FormHelpers;
use Contacts;
use TTTemplate;
use MapFinderDefs;
use Log;
use Data::Dumper;
use FacilitiesUtils;

#use FinderCustom;
use Utils;
use ClubCharacteristics;

sub search_results {
    my (
        $Data,            
        $MapFinderDefs,    
        $db,
        $search_IN,       
        $search_type,      
        $clubLevelAssoc,
        $assocLevelAssoc, 
        $assocID,
        $search_term_type, 
        $search_days,
        $data_only,
        $alternate
    ) = @_;
    my $realmID    = $Data->{'Realm'};
    my $subRealmID = $Data->{'RealmSubType'};
    my $error      = '';
    my $result     = '';
    my @values     = ();
    my $lat        = 0;
    my $long       = 0;
    my $file       = '';
    if ( !$realmID or !$search_type ){
        $error = 1;
        $file  = $MapFinderDefs->{'Error'};
    }

    my $searchState = '';

    if ( $search_IN =~ /^\d{3,4}$/ ) {
        $search_IN =~ s/^0//;
        ( $lat, $long ) = _getPostCodeLatLong( $db, $search_IN );
        $searchState = getSearchState($search_IN) if ( $search_term_type eq 'state' );
    }
    else {
        ( $lat, $long ) = _getSuburbLatLong( $db, $search_IN );
    }
    
    my $having        = '';
    my $distance_calc = '';
    my $distance      = $MapFinderDefs->{'Distance'};
    my $statedistance = $MapFinderDefs->{'StateDistance'} || $MapFinderDefs->{'Distance'};

    #hack to make state searches show everything
    if ( $search_term_type eq 'state' ) { $distance = $statedistance; }
    
    my %SearchResults = (
        'json_file'  => '[]',
        'realmID'    => $realmID,
        'subRealmID' => $subRealmID,
        'type'       => $search_type,
        'directory'  => $MapFinderDefs->{'directory'},
    );
    
    my $json_file = '[]';
    $search_type ||= 2;
    
    if ( $search_type == $MapFinderDefs::TYPE_PROGRAM ){
        
        # get facilities with long/lat search
        my $facilities = get_facilities_by_lat_long{
            'dbh'         => $db,
            'realm_id'    => $realmID, 
            'subrealm_id' => $subRealmID,
            'latitude'    => $lat,
            'longitude'   => $long,
            'distance'    => $distance,
            'state'       => $searchState,
        };
        
        my $rowCount      = 0;
        my @json_data     = ();
        my @alphabet = qw(A B C D E F G H I J K L M N O P Q R S T U V W X Y Z);
        
        my @display_list;
        
        # loop through facilities
        FACILITY: foreach my $facility_obj (@$facilities){
            
            # find programs
            my $params = {};
            if ( scalar @{$search_days} > 0 ) {
                $params->{'search_days'} = $search_days;
            }
            if ( $assocID != -1 ) {
                $params->{'assoc_id'} = $assocID;
            }
            my $programs = $facility_obj->get_programs($params);
            
            next FACILITY if (scalar @$programs == 0);
            
            # Add facility to data
            push @json_data, {
                'name'   => $facility_obj->{'DBData'}->{'strName'},
                'lat'    => $facility_obj->{'DBData'}->{'dblLat'},
                'lng'    => $facility_obj->{'DBData'}->{'dblLong'},
                'rank'   => $rowCount,
                'letter' => $alphabet[$rowCount],
            };
            
            
            my $facility_data = $facility_obj->{'DBData'};
             
            $facility_data->{'search_value'} = $search_IN;
            $facility_data->{'letter'}       = $alphabet[$rowCount];
            $facility_data->{'rank'}         = $rowCount;
            $facility_data->{'programs'}     = $programs;
            
            my @programs_run;
            
            foreach my $program_template_obj (@{$facility_obj->get_program_templates()}){
                push @programs_run, $program_template_obj->name();
            }
            
            $facility_data->{'programs_run'} = \@programs_run;

            $rowCount++;
             
            push @display_list, {
                'Details'  => $facility_data,
                'Programs' => $programs,
            };
            
            if ($MapFinderDefs->{'Limit'} && ($rowCount >= $MapFinderDefs->{'Limit'})) {
                last FACILITY;
            }
        }
        
        require JSON;
        $json_file = JSON::to_json( \@json_data );

        #$json_file ||= '{[]}';
        $SearchResults{'json_file'} = $json_file;
        $SearchResults{'results'}   = \@display_list;
        $file =
          ( !$alternate )
          ? $MapFinderDefs->{'SearchResults'}
          : $MapFinderDefs->{'AlternateSearchResults'}
          || $MapFinderDefs->{'SearchResults'};
        $file = $MapFinderDefs->{'NoResults'} unless (scalar @display_list);
        $SearchResults{'search_value'} = $search_IN;
        $SearchResults{'AllowEOI'} = !( $Data->{'SystemConfig'}{'NoEOI'} || 0 );
        
    }
    else {

        my $order = '';
        if ( $search_term_type eq 'name' ) {
            $order = " ClubName, strName ";
        }
        else {
            push @values, $lat;
            push @values, $long;
            push @values, $lat;
            if ( !$lat or !$long ) {
                $search_IN = '';
            }
            $having =
              ( !$searchState )
              ? " HAVING strDistance < '$distance' "
              : " HAVING strVenueState=? ";
            $distance_calc = "
            (
              6371
              * acos(
                cos( radians(?) )
                * cos( radians( dblLat ) )
                * cos( radians( dblLong )
                - radians(?) )
                + sin( radians(?) )
                * sin( radians( dblLat ) )
              )
            ) AS strDistance,
            ";
            $order = " strDistance ";
        }
        
        
        if ($search_IN) {
            my $club_WHERE = '';
            my $namecol    = '';
            if ( $search_type == 1 ) {
                $club_WHERE = qq[ AND S.intClubID > 0  AND C.intClubID>0];
                $namecol    = 'C.strName';
            }
            elsif ( $search_type == 2 ) {
                $club_WHERE = qq[ AND S.intClubID = 0];
                $namecol    = 'A.strName';
            }
            my $extra_JOIN      = '';
            my $extra_WHERE     = '';
            my $sub_realm_WHERE = '';
            if ( $search_term_type eq 'name' ) {
                my $sv = '%' . $search_IN . '%';
                $extra_WHERE .= " AND $namecol LIKE ?";
                push @values, $sv;
            }
            $sub_realm_WHERE = qq[ AND A.intAssocTypeID IN ($subRealmID)]
              if $subRealmID;
    
            #    (
            #      $subRealmID,
            #      $club_WHERE,
            #      $sub_realm_WHERE
            #    ) = get_custom_sql(
            #      $realmID,
            #      $subRealmID,
            #      $club_WHERE,
            #      $sub_realm_WHERE
            #    );
            $extra_WHERE .= qq[AND A.intAssocID IN ($clubLevelAssoc)]
              if ( $clubLevelAssoc and $search_type == 1 );
            $extra_WHERE .= qq[AND A.intAssocID=$assocLevelAssoc]
              if ( $assocLevelAssoc and $search_type == 2 );
    
            #Get the advanced filtering
    
            my $characs = getAvailableCharacteristics( $Data, 1 );
            my $characs_filtering = '';
            if ($characs) {
                for my $c ( @{$characs} ) {
                    my $id = $c->{'intCharacteristicID'} || next;
                    if ( param( 'as_char_' . $id ) ) {
                        $characs_filtering .= qq[
                             INNER JOIN tblClubCharacteristics AS CC_$id 
                                ON (
                                    CC_$id.intClubID = C.intClubID
                                    AND CC_$id.intCharacteristicID = $id
                                )
                        ];
                    }
                }
            }
    
            my $statement = qq[
                SELECT 
                    DISTINCT 
                    S.dblLat,
                    S.dblLong,
                    $distance_calc
                    A.intAssocID, 
                    A.intSWWAssocID,
                    S.intClubID, 
                    S.strContact1Name, 
                    $namecol AS NameCol,
                    CONCAT (IF(A.intAssocID, A.intAssocID,0) ,'_',IF(C.intClubID, C.intClubID, 0)) AS IDCol,
                    A.strName, 
                    S.strContact1Name, 
                    S.strContact1Title, 
                    S.strContact1Phone, 
                    S.strContact2Name, 
                    S.strContact2Title, 
                    S.strContact2Phone, 
                    S.strVenueName, 
                    S.strVenueAddress, 
                    S.strVenueAddress2, 
                    S.strVenueSuburb, 
                    S.strVenueCountry,
                    S.strVenueState,
                    S.strVenuePostalCode, 
                    S.intMon, 
                    S.intTue, 
                    S.intWed, 
                    S.intThu, 
                    S.intFri, 
                    S.intSat, 
                    S.intSun, 
                    S.strSessionDurations, 
                    S.strTimes, 
                    DATE_FORMAT(S.dtStart,'%d/%m/%y') as niceStartDate, 
                    DATE_FORMAT(S.dtFinish,'%d/%m/%y') as niceFinishDate, 
                    S.strNotes, 
                    S.strURL, 
                    S.strEmail, 
                    S.intRegisterID,
                    S.strCompetitions,
                    S.strCompOrganizer,
                    S.strCompCosts,
                    S.intRegistrationFormID, 
                    A.intAllowRegoForm, 
                    C.strName as ClubName, 
                    S.strPresidentName, 
                    S.strPresidentEmail, 
                    S.strPresidentPhone,  
                    S.strSecretaryName, 
                    S.strSecretaryEmail, 
                    S.strSecretaryPhone,  
                    S.strTreasurerName, 
                    S.strTreasurerEmail, 
                    S.strTreasurerPhone,  
                    S.strRegistrarName, 
                    S.strRegistrarEmail, 
                    S.strRegistrarPhone, 
                    S.intShowPresident, 
                    S.intShowSecretary, 
                    S.intShowTreasurer, 
                    S.intShowRegistrar, 
                    S.intClubClassification,
                    SR.strSubTypeName, 
                    A.intAssocTypeID,
                    C.intGoodSport
                FROM tblAssoc AS A 
                    INNER JOIN tblAssocServices AS S ON A.intAssocID=S.intAssocID  
                    LEFT JOIN tblClub as C ON (C.intClubID = S.intClubID AND C.intRecStatus >-1)
                    LEFT JOIN tblRealmSubTypes as SR ON (SR.intSubTypeID = A.intAssocTypeID)
                    $extra_JOIN
                    $characs_filtering
                WHERE 
                    S.intPublicShow = 1
                    $club_WHERE
                    $sub_realm_WHERE
                    $extra_WHERE
                AND A.intRealmID = ?
                    $having
                ORDER BY $order
                LIMIT 0 , $MapFinderDefs->{'Limit'}
            ];
            push @values, $realmID;
            push @values, $searchState if $searchState;
            my $query = $db->prepare($statement);
            $query->execute(@values);
    
            #    my %SearchResults = ();
            my @organisations = ();
            my $rowCount      = 0;
            my @json_data     = ();
            my @alphabet = qw(A B C D E F G H I J K L M N O P Q R S T U V W X Y Z);
            my %clubIDs  = ();
            while ( my $row = $query->fetchrow_hashref() ) {
                next if ( !( $row->{'dblLat'} or $row->{'dblLong'} ) );
                $clubIDs{ $row->{'intClubID'} } = 1;
                $row->{'strVenueName'} ||= 'Unknown';
                my $letter = $alphabet[$rowCount];
                push @json_data,
                  {
                    name     => $row->{'NameCol'},
                    lat      => $row->{'dblLat'},
                    lng      => $row->{'dblLong'},
                    'rank'   => $rowCount,
                    'letter' => $letter
                  };
                $rowCount++;
                $row->{'IDCol'}    ||= '';
                $row->{'strName'}  ||= '';
                $row->{'ClubName'} ||= '';
                $row->{'strNotes'} ||= '';
                $row->{'strNotes'}         =~ s/\r*\n/<br>/g;
                $row->{'strCompetitions'}  =~ s/\r*\n/<br>/g;
                $row->{'strCompetitions'}  =~ s/&lt;b&gt;/<b>/g;
                $row->{'strCompetitions'}  =~ s/&lt;\/b&gt;/<\/b>/g;
                $row->{'strCompOrganizer'} =~ s/\r*\n/<br>/g;
                $row->{'strCompOrganizer'} =~ s/&lt;b&gt;/<b>/g;
                $row->{'strCompOrganizer'} =~ s/&lt;\/b&gt;/<\/b>/g;
                $row->{'strCompCosts'}     =~ s/\r*\n/<br>/g;
                $row->{'strCompCosts'}     =~ s/&lt;b&gt;/<b>/g;
                $row->{'strCompCosts'}     =~ s/&lt;\/b&gt;/<\/b>/g;
                $row->{'SubRealmName'} ||= '';
                $row->{'intGoodSport'} ||= '';
                $row->{'search_value'} = $search_IN;
                $row->{'days'}         = _format_days($row);
                $row->{'register_btn'} = _generate_register_btn( $row, $rowCount, $db );
                $row->{'realmID'} = $realmID;
                $row->{'letter'}  = $letter;
                $row->{'rank'}    = $rowCount - 1;
                $row->{'ClubLevelImageName'} = 'FFA_NCAS_'. $row->{'intClubClassification'} . 'STAR_FC_RGB_POS.png' if ( $row->{'intClubClassification'} >= 1 );
                
    
                $Data->{'clientValues'}{'assocID'} = $row->{'intAssocID'};
                $Data->{'clientValues'}{'clubID'}  = $row->{'intClubID'};
                my %OrgData = (
                    'Details'  => $row,
                    'Contacts' => getLocatorContacts($Data)
                );
                push @organisations, \%OrgData;
            }
            require JSON;
            $json_file = JSON::to_json( \@json_data );
    
            #$json_file ||= '{[]}';
            $SearchResults{'json_file'} = $json_file;
            $SearchResults{'results'}   = \@organisations;
            $file =
              ( !$alternate )
              ? $MapFinderDefs->{'SearchResults'}
              : $MapFinderDefs->{'AlternateSearchResults'}
              || $MapFinderDefs->{'SearchResults'};
            $file = $MapFinderDefs->{'NoResults'} unless ($rowCount);
            $SearchResults{'search_value'} = $search_IN;
            $SearchResults{'AllowEOI'} = !( $Data->{'SystemConfig'}{'NoEOI'} || 0 );
    
            my %clubCharHTML = ();
            if ( $MapFinderDefs->{'ClubCharacteristicsTemplate'} ) {
                my @clubids = keys %clubIDs;
                my $cchars = getCurrentCharacteristics( $Data, \@clubids );
                for my $cID ( keys %{$cchars} ) {
                    $clubCharHTML{$cID} = runTemplate(
                        $Data,
                        {
                            ClubID          => $cID,
                            Characteristics => $cchars->{$cID},
                        },
                        $MapFinderDefs->{'directory'} . '/'
                          . $MapFinderDefs->{'ClubCharacteristicsTemplate'},
                    );
                }
            }
            $SearchResults{'ClubCharacteristics'} = \%clubCharHTML;
        }
    }
    
    $file ||= $MapFinderDefs->{'NoResults'};
    
    if ($data_only) {
        return ( \%SearchResults, $json_file );
    }
    else {
        $result =
          runTemplate( $Data, \%SearchResults,
            $MapFinderDefs->{'directory'} . "/$file" );
        return ( $result, $json_file );
    }
}

sub _format_days {
    my ($row) = @_;
    my $days = '';
    foreach my $day (
        [ 'intMon', 'Monday' ],
        [ 'intTue', 'Tuesday' ],
        [ 'intWed', 'Wednesday' ],
        [ 'intThu', 'Thursday' ],
        [ 'intFri', 'Friday' ],
        [ 'intSat', 'Saturday' ],
        [ 'intSun', 'Sunday' ],
      )
    {
        $days .= ', ' if ( $days and $row->{ $day->[0] } );
        $days .= ( $row->{ $day->[0] } ) ? $day->[1] : '';
    }
    return $days;
}

sub _generate_register_btn {
    my ( $row, $count, $db ) = @_;
    return '' unless ( $row->{'intAllowRegoForm'} and !$row->{'intClubID'} );
    my $register_btn     = '';
    my $club             = '';
    my $onsubmit         = '';
    my $regoType         = 1;
    my $formname         = "regof$count";
    my $showButton       = 1;
    my $selectButtonText = 'Register';
    if ( $row->{'intRegisterID'} == 2 ) {
        my $clublist = _getClubs( $db, $row->{'intAssocID'} );
        $clublist->{0} = ' -- Select a Club --';
        $club             = '<BR>' . drop_down( 'cID', $clublist, 0, '', 1, 0 );
        $selectButtonText = 'Register to Club';
        $onsubmit         = qq[ onsubmit="return checkclub('$formname');" ];
        $regoType         = 4;
    }
    $showButton = 0 if !$row->{'intRegistrationFormID'};
    $register_btn = $showButton
      ? qq[
    <form method="post" action="../regoform.cgi" name="$formname" $onsubmit>
      <input type="hidden" name="aID" value="$row->{intAssocID}">
      <input type="hidden" name="fID" value="$row->{intRegistrationFormID}">
      <input type="hidden" name="nh" value="1">
      <input type="submit" name="selectbut" value="$selectButtonText">
      $club
    </form>
  ]
      : '';
    return $register_btn;
}

sub _getClubs {
    my ( $db, $assocID ) = @_;
    my $st = qq[
    SELECT
      C.intClubID,
      C.strName
    FROM
      tblClub AS C
      INNER JOIN tblAssoc_Clubs AS AC ON C.intClubID=AC.intClubID
    WHERE
      AC.intAssocID = ?
      AND AC.intRecStatus = $Defs::RECSTATUS_ACTIVE
      AND C.intRecStatus = $Defs::RECSTATUS_ACTIVE
  ];
    my $q = $db->prepare($st);
    $q->execute($assocID);
    my %clubs = ();
    while ( my ( $id, $name ) = $q->fetchrow_array() ) {
        next if !$id;
        next if !$name;
        $clubs{$id} = $name;
    }
    return \%clubs;
}

sub _getPostCodeLatLong {
    my ( $db, $postcode ) = @_;
    my $st = qq[
    SELECT
      strLat,
      strLong
    FROM
      tblPostCodes_LatLong
    WHERE
      strPostalCode = ?
  ];
    my $q = $db->prepare($st);
    $q->execute($postcode);
    my ( $lat, $long ) = $q->fetchrow_array();
    return ( $lat, $long );
}

sub _getSuburbLatLong {
    my ( $db, $suburb ) = @_;
    my $st = qq[
    SELECT
      strLat,
      strLong
    FROM
      tblPostCodes_LatLong
    WHERE
      strSuburb = ?
  ];
    my $q = $db->prepare($st);
    $q->execute( uc($suburb) );
    my ( $lat, $long ) = $q->fetchrow_array();
    return ( $lat, $long );
}

sub getAdvancedSearchBox {
    my ( $Data, $MapFinderDefs, ) = @_;

    my $characs = getAvailableCharacteristics( $Data, 1 );

    if ( !$characs or !@{$characs} ) {
        return '';
    }
    my $body = '';
    $body = runTemplate(
        $Data,
        { Characteristics => $characs, },
        $MapFinderDefs->{'directory'} . '/'
          . $MapFinderDefs->{'AdvancedSearch'},
    );
    return $body;
}

sub getSearchState {
    my ($postcode) = @_;

    my %States = (
        800  => 'NT',
        2000 => 'NSW',
        2600 => 'ACT',
        3000 => 'VIC',
        4000 => 'QLD',
        5000 => 'SA',
        6000 => 'WA',
        7000 => 'TAS',
    );

    my $searchState = $States{$postcode} || '';

    return $searchState;
}

1;
