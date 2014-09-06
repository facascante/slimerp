#
# $Header: svn://svn/SWM/trunk/web/Reg_common.pm 11399 2014-04-28 16:14:39Z sliu $
#

package Reg_common;

require Exporter;
@ISA = qw(Exporter);
@EXPORT = @EXPORT_OK = qw(
kickThemOff allowedTo setClient getClient stripSpaces moneyFormat entryExists getDataAccess textMessage getAssocID getDBConfig create_selectbox getLevelName txtField getID setClientValue getClientValue allowedAction getRealm currency createButtonForm getRegoPassword getEntityValues getEntityID getEntityStructure isHeavierPerm get_page_url getLastEntityID getLastEntityLevel
);

use strict;
use CGI qw(escape unescape);
use Otp;

use lib "..";
use Defs;
use Utils;
use DeQuote;
use ConfigOptions;
use Digest::MD5;
use MIME::Base64 qw(encode_base64url decode_base64url);
use UserSession;
use GlobalAuth;

#use Data::Dumper;

$Reg_common::keystr =
q[dos no mundo. O MySQL uma implementao clienteservidor queconsiste de um servidor chamado mysqld e diversosprogramasbibliotecas clientes. Os principais objetivos do MySQL svelocidade, robustez e facilidade de uso.  O MySQL foi originalmentedesenvolvido porque ns na Tcx precisvamos de um servidor SQL quepudesse lidar com grandes bases de dados e com uma velocidade muitomaior do que a que qualquer vendedor podia nos oferecer.];

# USER HAS ENTERED AN AREA THEY HAVE NO ACCESS TO

sub kickThemOff {

    my ( $message, $url ) = @_;

    $url = "$Defs::base_url/index.cgi" if ( !defined $url );

    ## POPULATE ERROR MESSAGE IF NO MESSAGE IS PASSED IN
    if ( !defined $message ) {
        $message =
"Your login has expired or you are not authorised to view the page you have selected";
    }

    ## THIS USER IS EVIL, BOOT THEM !
    print qq[Content-type: text/html\n\n];
    print qq[
<html>

<head>
	<title></title>
	<link rel="stylesheet" type="text/css" href="$Defs::base_url/css/style.css">
	<meta http-equiv="refresh" content="5;url=$url">
</head>

<body bgcolor="#ffffff">

<p><br></p>
<p><br></p>
<p><br></p>
<p><br></p>
<p><br></p>
<p><br></p>

<p align="center" class="error"><b>$message</b></p>
<p align="center"><b>You are now being returned to the login screen.</b></p>

</body>

</html>
  ];

    ## SOD OFF !
    exit;
}

# CHECK IF A USER IS ONE OF A LIST OF USER TYPES

# INPUT  : $params - A REFERENCE TO A HASH OF CLIENT VALUES
# OUTPUT : $db Database reference$clientValues_ref->{currentLevel};

sub allowedTo {

    my ( $Data, $entityID, $entityTypeID ) = @_;
    ## CHECK COOKIE
    my $output        = new CGI;
    my $member_cookie = $output->cookie("$Defs::COOKIE_MEMBER") || '';
    my $rs            = $output->cookie("$Defs::COOKIE_ACTSTATUS");
    $rs = '' if !defined $rs;
    $Data->{'ViewActStatus'} = 1;
    $Data->{'ViewActStatus'} = $rs
      if ( $rs eq '2' or $rs eq '1' or $rs eq '0' );
    my $txn_rs = $output->cookie("$Defs::COOKIE_TXN_ACTSTATUS");
    $txn_rs = '' if !defined $txn_rs;
    $Data->{'ViewTXNStatus'} = 1;
    $Data->{'ViewTXNStatus'} = $txn_rs
      if ( $txn_rs eq '2'
        or $txn_rs eq '1'
        or $txn_rs eq '0'
        or $txn_rs eq '-1'
        or $txn_rs eq '99' );
    my $clr_rs = $output->cookie("$Defs::COOKIE_CLR_ACTSTATUS");
    $clr_rs = '' if !defined $clr_rs;
    $Data->{'ViewClrStatus'} = 1;
    $Data->{'ViewClrStatus'} = $clr_rs
      if ( $clr_rs eq '2'
        or $clr_rs eq '1'
        or $clr_rs eq '0'
        or $clr_rs eq '-1'
        or $clr_rs eq '99'
        or $clr_rs eq '100' );

    my $mc_rs = $output->cookie("$Defs::COOKIE_MCSTATUS");
    $mc_rs = '' if !defined $mc_rs;
    $Data->{'ViewMCStatus'} = 1;
    $Data->{'ViewMCStatus'} = $mc_rs
      if ( $mc_rs eq '2' or $mc_rs eq '1' or $mc_rs eq '0' );

    $Data->{'ViewSeason'}   = $output->cookie("$Defs::COOKIE_SEASONFILTER");
    $Data->{'ViewAgeGroup'} = $output->cookie("$Defs::COOKIE_AGEGROUPFILTER");

    my $clr_mname    = $output->cookie("$Defs::COOKIE_CLR_MEMNAME");
    my $clr_fromclub = $output->cookie("$Defs::COOKIE_CLR_FROMCLUB");
    my $clr_toclub   = $output->cookie("$Defs::COOKIE_CLR_TOCLUB");
    my $clr_year     = $output->cookie("$Defs::COOKIE_CLR_YEAR");
    $Data->{'ViewClrMName'}    = '';
    $Data->{'ViewClrMName'}    = $clr_mname if $clr_mname;
    $Data->{'ViewClrToClub'}   = '';
    $Data->{'ViewClrToClub'}   = $clr_toclub if $clr_toclub;
    $Data->{'ViewClrFromClub'} = '';
    $Data->{'ViewClrFromClub'} = $clr_fromclub if $clr_fromclub;
    $Data->{'ViewClrYear'}     = '';
    $Data->{'ViewClrYear'}     = $clr_year if $clr_year;
    my $mtfilter_cookie = $output->cookie("$Defs::COOKIE_MTYPEFILTER") || '';
    $Data->{'CookieMemberTypeFilter'} = '';

    $Data->{'FullScreen'} = $output->cookie('SP_SWM_FULLSCREEN') || 0;

    for my $i (
        qw(intPlayer intCoach intUmpire intOfficial intMisc intVolunteer intPlayerStatus intCoachStatus intUmpireStatus intMiscStatus intVolunteerStatus Seasons.intPlayerStatus Seasons.intCoachStatus Seasons.intUmpireStatus Seasons.intMiscStatus Seasons.intVolunteerStatus )
      )
    {
        $Data->{'CookieMemberTypeFilter'} = $mtfilter_cookie
          if $i eq $mtfilter_cookie;
    }

    $Data->{'CookieRecordTypeFilter'} = $output->cookie('SWOMRTF');

    my $prod_rs = $output->cookie("$Defs::COOKIE_PRODSTATUS");
    $prod_rs = '' if !defined $prod_rs;
    $Data->{'ViewProductStatus'} = 0;
    $Data->{'ViewProductStatus'} = $prod_rs
      if ( $prod_rs eq '2' or $prod_rs eq '1' or $prod_rs eq '0' );
    ## FIND DATABASE
    my ( $db, $message ) = connectDB();
    if ( !$db ) {
        kickThemOff($message);
    } # NO DATABASE POINTER RECEIVED, SO KICK USER OFF AND DISPLAY ERROR MESSAGE
    $Data->{'db'} = $db;
    getDBConfig($Data);

    my $clientValues_ref = $Data->{clientValues};

    my $level        = 0;
    my $intID        = 0;
    my $readOnly     = 0;
    my $roleID       = 0;
    my $UserName = 0;
    #User login
    my $user = new UserSession(
        db    => $db,
        cache => $Data->{'cache'},
    );
    $user->load();
    my $userID = $user->id() || 0;
    kickThemOff() if $userID != $clientValues_ref->{'userID'};

    my $st = qq[
      SELECT
        entityTypeID,
        entityID,
        readOnly
      FROM tblUserAuth
      WHERE
        userID = ?
        AND entityTypeID = ?
        AND entityID = ?
    ];
    my $q = $db->prepare($st);
    $q->execute(
        $userID,
        $clientValues_ref->{authLevel},
        getID( $clientValues_ref, $clientValues_ref->{authLevel} ),
    );

    ( $level, $intID, $readOnly, $roleID ) = $q->fetchrow_array();
    $q->finish();
    if ( !$level and !$intID ) {
        my $valid = validateGlobalAuth(
            $Data, $userID,
            $clientValues_ref->{authLevel},
            getID( $clientValues_ref, $clientValues_ref->{authLevel} ),
        );
        if ($valid) {
            $level = $clientValues_ref->{authLevel};
            $intID =
              getID( $clientValues_ref, $clientValues_ref->{authLevel} );
            $roleID   = 0;
            $readOnly = 0;
        }
    }
    $UserName = $user->fullname();

    ## ENSURE THE USER IS VALID FOR THE CURRENT LEVEL

    $clientValues_ref->{currentLevel} ||= kickThemOff();
    kickThemOff() if $clientValues_ref->{authLevel} != $level;

    #$clientValues_ref->{assocID} = $assocID;

    if (    $clientValues_ref->{currentLevel} > $level) {
        kickThemOff();    # THIS USER IS EVIL: BOOT THEM
    }

    if ( $entityID and $entityTypeID ) {
        if ( $level != $entityTypeID or $intID != $entityID ) {
            kickThemOff();    # THIS USER IS EVIL: BOOT THEM
        }
    }

    ## RE - Copy Auth Details into client variables
    $clientValues_ref->{'_intID'} = $intID;
    $Data->{'ReadOnlyLogin'}      = $readOnly || 0;
    $Data->{'AuthRoleID'}         = $roleID || 0;
    $Data->{'UserName'}       = $UserName || 0;

    ## RETURN DATABASE POINTER
    return ($db);

}

# ENCODE CLIENT VALUES IN FORMAT SUITABLE FOR PASSING IN A URL

sub setClient {

    my ($clientValues_ref) = @_;

    $clientValues_ref->{interID}      ||= 0;
    $clientValues_ref->{intregID}     ||= 0;
    $clientValues_ref->{intzonID}     ||= 0;
    $clientValues_ref->{natID}        ||= 0;
    $clientValues_ref->{stateID}      ||= 0;
    $clientValues_ref->{regionID}     ||= 0;
    $clientValues_ref->{zoneID}       ||= 0;
    $clientValues_ref->{assocID}      ||= $Defs::INVALID_ID;
    $clientValues_ref->{clubID}       ||= $Defs::INVALID_ID;
    $clientValues_ref->{personID}     ||= $Defs::INVALID_ID;
    $clientValues_ref->{currentLevel} ||= -1;
    $clientValues_ref->{authLevel}    ||= -1;
    $clientValues_ref->{'userID'} ||= 0;

    my $client =
        $clientValues_ref->{interID} . '|'
      . $clientValues_ref->{intregID} . '|'
      . $clientValues_ref->{intzonID} . '|'
      . $clientValues_ref->{natID} . '|'
      . $clientValues_ref->{stateID} . '|'
      . $clientValues_ref->{regionID} . '|'
      . $clientValues_ref->{zoneID} . '|'
      . $clientValues_ref->{clubID} . '|'
      . $clientValues_ref->{personID} . '|'
      . $clientValues_ref->{currentLevel} . '|'
      . $clientValues_ref->{authLevel} . '|'
      . $clientValues_ref->{'userID'} . '|';

    # SET EXPIRY DATE
    $client .= time;

    # ENCRYPT HERE
    my $digest = Digest::MD5::md5_hex( $client, $Reg_common::keystr );
    my $d = $client . '|' . $digest;
    $client = encode_base64url( $d, '' );

    return $client;
}

# DECODE CLIENT INFORMATION

sub getClient {

    my ($client) = @_;
    my %clientValues = ();

    # DECRYPT HERE
    my $dec = decode_base64url($client);
    my ( $client_dec, $digest_dec ) = $dec =~ /(.*)\|([^\|]+)/;
    $client_dec ||= '';
    $digest_dec ||= '';
    my $digest = Digest::MD5::md5_hex( $client_dec, $Reg_common::keystr ) || '';
    $client_dec = '' if $digest ne $digest_dec;

    my $lastAccess;
    (
        $clientValues{interID},      
        $clientValues{intregID},
        $clientValues{intzonID},     
        $clientValues{natID},
        $clientValues{stateID},      
        $clientValues{regionID},
        $clientValues{zoneID},       
        $clientValues{clubID},
        $clientValues{personID},
        $clientValues{currentLevel}, 
        $clientValues{authLevel},
        $clientValues{'userID'}, 
        $lastAccess
    ) = split( /\|/, $client_dec );

    $clientValues{interID}      ||= 0;
    $clientValues{intregID}     ||= 0;
    $clientValues{intzonID}     ||= 0;
    $clientValues{natID}        ||= 0;
    $clientValues{stateID}      ||= 0;
    $clientValues{regionID}     ||= 0;
    $clientValues{zoneID}       ||= 0;
    $clientValues{clubID}       ||= $Defs::INVALID_ID;
    $clientValues{personID}     ||= $Defs::INVALID_ID;
    $clientValues{currentLevel} ||= -1;
    $clientValues{authLevel}    ||= -1;
    $clientValues{userID}   ||= 0;

    if ( $clientValues{currentLevel} > $Defs::LEVEL_PERSON ) {
        $clientValues{personID} = $Defs::INVALID_ID;
    }
    if ( $clientValues{currentLevel} > $Defs::LEVEL_CLUB ) {
        $clientValues{personID} = $Defs::INVALID_ID;
    }
    if ( $clientValues{currentLevel} > $Defs::LEVEL_CLUB ) {
        $clientValues{clubID} = $Defs::INVALID_ID;
    }
    if ( $clientValues{currentLevel} >= $Defs::LEVEL_REGION ) {
        $clientValues{zoneID} = $Defs::INVALID_ID;
    }
    if ( $clientValues{currentLevel} >= $Defs::LEVEL_STATE ) {
        $clientValues{regionID} = $Defs::INVALID_ID;
    }
    if ( $clientValues{currentLevel} >= $Defs::LEVEL_NATIONAL ) {
        $clientValues{stateID} = $Defs::INVALID_ID;
    }
    if ( $clientValues{currentLevel} >= $Defs::LEVEL_INTZONE ) {
        $clientValues{natID} = 0;
    }
    if ( $clientValues{currentLevel} >= $Defs::LEVEL_INTREGION ) {
        $clientValues{intzonID} = 0;
    }
    if ( $clientValues{currentLevel} >= $Defs::LEVEL_INTERNATIONAL ) {
        $clientValues{intregID} = 0;
    }
    if ( $clientValues{currentLevel} == $Defs::LEVEL_TOP ) {
        $clientValues{interID} = 0;
    }

    # HAS THIS LINK EXPIRED?
    if ( $lastAccess and ( ( time() - $lastAccess ) > $Defs::expiryseconds ) ) {
        $clientValues{authLevel}    = -1;
        $clientValues{currentLevel} = -1;
    }

    return (%clientValues);
}

# CHECKS FOR THE EXISTANCE OF A RECORD IN A TABLE

sub entryExists {

    my ( $db, $id, $tablename, $keyfield ) = @_;
    my $query = $db->prepare(
        "SELECT $keyfield FROM $tablename WHERE $keyfield= ? LIMIT 1");
    $query->execute($id);
    my $found = ( $query->rows > 0 ) ? 1 : 0;
    $query->finish;

    return $found;

}

# ERROR MESSAGE + CONFIRMATION MESSAGE

sub textMessage {

    my ($message) = @_;

    return qq[<p class="note">$message</p>];

}

# THIS FUNCTION REMOVES EXTRA SPACES FROM THE END OF A STRING, AND ESCAPES ALL QUOTES & APOSTROPHIES

sub stripSpaces {

    my ($strToStrip) = @_;

    if ( defined $strToStrip ) {
        $strToStrip =~ s/\A(\s*)//m;    # Strip spaces from ends
        $strToStrip =~ s/(\s*)\Z//m;
        $strToStrip =~ s/\'/&#039;/g;
        $strToStrip =~ s/\"/&quot;/g;
    }
    else {
        $strToStrip = '';
    }

    return $strToStrip;

}

# DISPLAY NUMBERS IN A MONETARY FORMAT, WITH COMMAS AND OPTIONAL LIMITING OF DECIMALS

sub moneyFormat {

    my ( $value, $decsrequest ) = @_;
    my ( $decimals, $integerpart, $decimalpart );

    if ( !$value ) { $value = 0; }
    else {
        if ( $value =~ /\./ ) {
            ( $integerpart, $decimalpart ) = $value =~ /(.*?)\.(.*)/;
        }
        else {
            $integerpart = $value;
            $decimalpart = '';
        }
        $decimalpart = ( defined $decimalpart ) ? $decimalpart : '';
        $integerpart = ( defined $integerpart ) ? $integerpart : '';
        $decimals =
          ( defined $decimalpart )
          ? length($decimalpart)
          : 0;    # Get actual number of decimals available
        $decsrequest =
          ( defined $decsrequest && $decsrequest < $decimals )
          ? $decsrequest
          : $decimals;

        if ( $decsrequest < $decimals )
        {         # Chop extra decimals, NO ROUNDING IS DONE
            $decimalpart = substr( $decimalpart, 0, $decsrequest );
        }
        if ( $decimalpart ne '' ) {
            $value = "$integerpart.$decimalpart";
        }
        else {
            $value = '' . $integerpart;
        }
        if ( substr( $value, 0, 1 ) eq '-' ) {
            $value = substr( $value, 1 );
            $value = '-$' . commify($value);
        }
        else {
            $value = '$' . commify($value);
        }
    }
    return $value;
}

# GET DATA ACCESS

sub getDataAccess {
    my ($Data) = @_;
    my %AccessData = ();

    my $where_statement = '';
    my @values = ();

    #First getEntitys

    for my $level (
        $Defs::LEVEL_TOP,       
        $Defs::LEVEL_INTERNATIONAL,
        $Defs::LEVEL_INTREGION, 
        $Defs::LEVEL_INTZONE,
        $Defs::LEVEL_NATIONAL,  
        $Defs::LEVEL_STATE,
        $Defs::LEVEL_REGION,    
        $Defs::LEVEL_ZONE,
        $Defs::LEVEL_CLUB,
      )
    {
        my $id = getClientValue( $Data->{'clientValues'}, $level );
        if($id and $id > 0) {
            if ($where_statement) { $where_statement .= " OR "; }
            $where_statement .= qq[(intEntityID = ? AND intEntityLevel = ? ) ];
            push @values, $id;
            push @values, $level;
        }
    }

    if ($where_statement) {
        my $statement = qq[
			SELECT intEntityID, intEntityLevel, intDataAccess
			FROM tblEntity
			WHERE $where_statement
		];
        my $query = $Data->{'db'}->prepare($statement);
        $query->execute(@values);
        while ( my ( $DB_intEntityID, $DB_intEntityLevel, $DB_intDataAccess ) =
            $query->fetchrow_array() )
        {
            $DB_intDataAccess = $Defs::DATA_ACCESS_FULL if !defined $DB_intDataAccess;
            $AccessData{$DB_intEntityLevel}{$DB_intEntityID} = $DB_intDataAccess;
        }
    }

    return \%AccessData;
}

sub getAssocID {

    my ($clientValues_ref) = @_;
    my $assocID = $Defs::INVALID_ID;
    if ( $clientValues_ref->{assocID} == $Defs::INVALID_ID ) {
        $assocID = $clientValues_ref->{clubAssocID};
    }
    else { $assocID = $clientValues_ref->{assocID}; }

    return ($assocID);

}

sub getDBConfig {
    my ($Data) = @_;
    my $db      = $Data->{'db'}    || '';
    my $realmID = $Data->{'Realm'} || 0;
    if ($db) {
        my @names = (
            [ 'National Body',   100, 0, 'NBody'],
            [ 'National Bodies', 100, 1, 'NBodies'],
            [ 'State',           30,  0, 'State'],
            [ 'States',          30,  1, 'States'],
            [ 'Region',          20,  0, 'Region'],
            [ 'Regions',         20,  1, 'Regions'],
            [ 'Zones',           10,  1, "Zone"],
            [ 'Zone',            10,  0, 'Zone'],
            [ 'Association',     5,   0, 'Assoc'],
            [ 'Associations',    5,   1, 'Assocs'],
            [ 'Clubs',           3,   1, 'Clubs'],
            [ 'Club',            3,   0, 'Club'],
            [ 'Person',          1,   0, 'Person'],
            [ 'People',         1,   1, 'People'],
            [ 'Venues',        -47,   1, 'Venues'],
            [ 'Venue',         -47,   0, 'Venue'],
        );
        for my $name (@names) {
            if ( $name->[2] ) {
                $Data->{'LevelNames'}{ $name->[1] . '_PA' } = $name->[3];
                $Data->{'LevelNames'}{ $name->[1] . '_P' } = $name->[0];
            }    #was $Data->{'lang'}->txt($name->[0])
            else {
                $Data->{'LevelNames'}{ $name->[1] } = $name->[0];
                $Data->{'LevelNames'}{ $name->[1] . '_A' } = $name->[3];
            }    #was $Data->{'lang'}->txt($name->[0])
        }
        my $st = $Data->{'RealmSubType'} || 0;
        my $statement = qq[
			SELECT  intLevelID, intPlural, strAbbrev, strName
			FROM tblDBLevelConfig
			WHERE intDBConfigGroupID = ?
				 AND intSubTypeID IN (?,0)
			ORDER BY intSubTypeID ASC
		];
		my $query=$db->prepare($statement);
		$query->execute($realmID, $st);
		while(my $dref=$query->fetchrow_hashref())	{
			if($dref->{'intPlural'})	{ 
				$Data->{'LevelNames'}{$dref->{'intLevelID'}.'_PA'}=$dref->{'strAbbrev'}; 
				$Data->{'LevelNames'}{$dref->{'intLevelID'}.'_P'}=$dref->{'strName'}; 
			} #was $Data->{'lang'}->txt($dref->{'strName'})
			else	{ 
				$Data->{'LevelNames'}{$dref->{'intLevelID'}}=$dref->{'strName'}; 
				$Data->{'LevelNames'}{$dref->{'intLevelID'}.'_A'}=$dref->{'strAbbrev'}; 
			} #was $Data->{'lang'}->txt($dref->{'strName'})
		}
	}
}

sub create_selectbox {

    #Create HTML Select Box from Hash Ref passed in
    my ( $data_ref, $current_data, $name, $preoptions, $action, $type ) = @_;
    if ( !$name )       { return ''; }
    if ( !$preoptions ) { $preoptions = ''; }
    if ( !$action )     { $action = ''; }
    my $subBody  = '';
    my $selected = '';
    if ( $type and $type == 2 ) {
        foreach my $i (
            sort { $data_ref->{$a}[1] <=> $data_ref->{$b}[1] }
            keys %{$data_ref}
          )
        {
            if ( $current_data and $current_data == $i ) {
                $selected = " SELECTED ";
            }
            else { $selected = ""; }
            $subBody .=
              qq[ <option $selected value="$i">$data_ref->{$i}[0]</option>\n ];
        }
    }
    else {
        foreach my $i (
            sort { $data_ref->{$a} cmp $data_ref->{$b} }
            keys %{$data_ref}
          )
        {
            if ( $current_data and $current_data eq $i ) {
                $selected = " SELECTED ";
            }
            else { $selected = ""; }
            $subBody .=
              qq[ <option $selected value="$i">$data_ref->{$i}</option>\n ];
        }
    }
    $subBody = qq[
    <select name="$name" size="1" $action>
      $preoptions
      $subBody
    </select>
  ];
    return $subBody;
}

sub getLevelName {
    my ( $levelID, $clientValues_ref, $plural ) = @_;
    $levelID ||= 0;
    $plural  ||= 0;
    return '' if !$clientValues_ref;

    return $clientValues_ref->{Level_MemberName}
      if $levelID == $Defs::LEVEL_PERSON and !$plural;
    return $clientValues_ref->{Level_MemberNamePlural}
      if $levelID == $Defs::LEVEL_PERSON and $plural;

    return $clientValues_ref->{Level_ClubName}
      if $levelID == $Defs::LEVEL_CLUB and !$plural;
    return $clientValues_ref->{Level_ClubNamePlural}
      if $levelID == $Defs::LEVEL_CLUB and $plural;

    return $clientValues_ref->{Level_ZoneName}
      if $levelID == $Defs::LEVEL_ZONE and !$plural;
    return $clientValues_ref->{Level_ZoneNamePlural}
      if $levelID == $Defs::LEVEL_ZONE and $plural;

    return $clientValues_ref->{Level_RegionName}
      if $levelID == $Defs::LEVEL_REGION and !$plural;
    return $clientValues_ref->{Level_RegionNamePlural}
      if $levelID == $Defs::LEVEL_REGION and $plural;

    return $clientValues_ref->{Level_NationalName}
      if $levelID == $Defs::LEVEL_NATIONAL and !$plural;
    return $clientValues_ref->{Level_NationalNamePlural}
      if $levelID == $Defs::LEVEL_NATIONAL and $plural;

    return '';
}

sub txtField {
    my ( $name, $value, $length, $maxlength ) = @_;
    $length ||= 50;
    $value  ||= '';
    return
qq[ <input type="text" name="$name" value="$value" maxlength="$maxlength" size="$length">];

}

sub getLastEntityID {
    my ( $clientValues) = @_;

    return 0 if !$clientValues;
    for my $k (qw(
        clubID
        zoneID
        regionID
        stateID
        natID
        intzonID
        intregID
        interID
    ))  {
        if($clientValues->{$k} > 0)   {
            return $clientValues->{$k};
        }
    }
    return 0;
}

sub getLastEntityLevel {
    # Returns the level of the last entity
    my ( $clientValues) = @_;

    return 0 if !$clientValues;
    return $Defs::LEVEL_CLUB if ($clientValues->{clubID} and $clientValues->{'clubId'} != $Defs::INVALID_ID);
    return $Defs::LEVEL_ZONE if ($clientValues->{zoneID} and $clientValues->{'zoneId'} != $Defs::INVALID_ID);
    return $Defs::LEVEL_REGION if ($clientValues->{regionID} and $clientValues->{'regionId'} != $Defs::INVALID_ID);
    return $Defs::LEVEL_STATE if ($clientValues->{stateID} and $clientValues->{'stateId'} != $Defs::INVALID_ID);
    return $Defs::LEVEL_NATIONAL if ($clientValues->{natID} and $clientValues->{'natId'} != $Defs::INVALID_ID);
    return $Defs::LEVEL_INTZONE if ($clientValues->{intzonID} and $clientValues->{'intzonId'} != $Defs::INVALID_ID);
    return $Defs::LEVEL_INTREGION if ($clientValues->{intregID} and $clientValues->{'intregId'} != $Defs::INVALID_ID);

    return 0;
}


sub getID {

    my ( $clientValues, $level ) = @_;

    return 0 if !$clientValues;
    my $cl = $level || $clientValues->{currentLevel} || 0;
    return $clientValues->{personID}  || 0 if $cl == $Defs::LEVEL_PERSON;
    return $clientValues->{clubID}    || 0 if $cl == $Defs::LEVEL_CLUB;
    return $clientValues->{zoneID}    || 0 if $cl == $Defs::LEVEL_ZONE;
    return $clientValues->{regionID}  || 0 if $cl == $Defs::LEVEL_REGION;
    return $clientValues->{stateID}   || 0 if $cl == $Defs::LEVEL_STATE;
    return $clientValues->{natID}     || 0 if $cl == $Defs::LEVEL_NATIONAL;
    return $clientValues->{intzonID}  || 0 if $cl == $Defs::LEVEL_INTZONE;
    return $clientValues->{intregID}  || 0 if $cl == $Defs::LEVEL_INTREGION;
    return $clientValues->{interID}   || 0 if $cl == $Defs::LEVEL_INTERNATIONAL;
    return $clientValues->{venueID}   || 0 if $cl == $Defs::LEVEL_VENUE;
	
    return 0;
}

sub setClientValue {
    my ( $clientValues_ref, $typeID, $val ) = @_;
    $clientValues_ref->{interID} = $val
      if $typeID == $Defs::LEVEL_INTERNATIONAL;
    $clientValues_ref->{intregID}  = $val if $typeID == $Defs::LEVEL_INTREGION;
    $clientValues_ref->{intzonID}  = $val if $typeID == $Defs::LEVEL_INTZONE;
    $clientValues_ref->{natID}     = $val if $typeID == $Defs::LEVEL_NATIONAL;
    $clientValues_ref->{stateID}   = $val if $typeID == $Defs::LEVEL_STATE;
    $clientValues_ref->{regionID}  = $val if $typeID == $Defs::LEVEL_REGION;
    $clientValues_ref->{zoneID}    = $val if $typeID == $Defs::LEVEL_ZONE;
    $clientValues_ref->{clubID}    = $val if $typeID == $Defs::LEVEL_CLUB;
    $clientValues_ref->{personID}  = $val if $typeID == $Defs::LEVEL_PERSON;
    $clientValues_ref->{venueID}   = $val if $typeID == $Defs::LEVEL_VENUE;
}

sub getClientValue {
    my ( $clientValues_ref, $typeID ) = @_;
    return $clientValues_ref->{interID}
      if $typeID == $Defs::LEVEL_INTERNATIONAL;
    return $clientValues_ref->{intregID}  if $typeID == $Defs::LEVEL_INTREGION;
    return $clientValues_ref->{intzonID}  if $typeID == $Defs::LEVEL_INTZONE;
    return $clientValues_ref->{natID}     if $typeID == $Defs::LEVEL_NATIONAL;
    return $clientValues_ref->{stateID}   if $typeID == $Defs::LEVEL_STATE;
    return $clientValues_ref->{regionID}  if $typeID == $Defs::LEVEL_REGION;
    return $clientValues_ref->{zoneID}    if $typeID == $Defs::LEVEL_ZONE;
    return $clientValues_ref->{clubID}    if $typeID == $Defs::LEVEL_CLUB;
    return $clientValues_ref->{personID}  if $typeID == $Defs::LEVEL_PERSON;

    return 0;
}

sub allowedAction {
    my ( $Data, $action ) = @_;
    my $orig_action = $action;
    $action = 'm_e' if $action eq 'm_ep';
    return 0 if !$Data->{'db'};
    return 0
      if ( $Data->{'MemberOnPermit'}
        and !$Data->{'SystemConfig'}{'allowPermitEdits'} );
    if ( $Data->{'ReadOnlyLogin'} ) {
        return 0 if $action =~ /_a$/;
        return 0 if $action =~ /_e$/;
        return 0 if $action =~ /_d$/;
    }
    my $level   = $Data->{'clientValues'}{'authLevel'}  || $Defs::LEVEL_NONE;
    if ( !$Data->{'Permissions'} ) {
    }
    my $currentID = getID( $Data->{'clientValues'} ) || 0;
    my $currentlevel = $Data->{'clientValues'}{'currentLevel'} || $Defs::LEVEL_NONE;
    my $parentaccess = $Data->{'DataAccess'}{$currentlevel}{$currentID} || 0;
    $parentaccess = $Defs::DATA_ACCESS_FULL if !defined $parentaccess;
    if ( exists $Data->{'SystemConfig'}{'ParentBodyAccess'} ) {
        $parentaccess = $Data->{'SystemConfig'}{'ParentBodyAccess'};
    }

    return 1 if $parentaccess == $Defs::DATA_ACCESS_FULL;
    return 1;
    #return 0;
}

sub getRealm {
    my ($Data) = @_;
    my $cl  = $Data->{'clientValues'}{'currentLevel'} || 0;
    my $st  = '';
    my $val = 0;
    my $id = getLastEntityID( $Data->{'clientValues'} ) || 0;
    $st =
      qq[SELECT intRealmID, intSubRealmID FROM tblEntity WHERE intEntityID= ? ];
    $val = $id;
    if ($st) {
        my $q = $Data->{'db'}->prepare($st);
        $q->execute($val);
        my ( $realmID, $subtype ) = $q->fetchrow_array();
        $q->finish();
        return ( $realmID || 0, $subtype || 0 );
    }
    return ( 0, 0 );
}

sub currency {
    my $a = $_[0];
    $a ||= 0;
    $a =~ s/,//g;
    my $text = sprintf "%.2f", $a;
    $text = reverse $text;
    $text =~ s/(\d\d\d)(?=\d)(?!\d*\.)/$1,/g;
    return scalar reverse $text;
}

sub createButtonForm {

#Generates a form with some hidden fields and a button (as an alternative to a link)

    my ( $fields_ref, $submit_text ) = @_;
    my $form = '';
    foreach my $key ( keys %$fields_ref ) {
        $form .=
          qq[<input type='hidden' name='$key' value='$fields_ref->{$key}' />];
    }

    $form = qq[<form method="post">
		$form
		<input type="submit" value="$submit_text" />
	   </form
          ];

    return $form;
}

sub getRegoPassword {
    my ($value) = @_;
    return '' if ( !defined $value or $value eq '' );
    my $m = new MD5;
    $m->reset();
    $m->add( $Defs::REGO_FORM_SALT, $value );
    return $m->hexdigest() || '';
}

sub getEntityValues {
    my ($clientValues) = @_;

    my $entityTypeID = $clientValues->{'currentLevel'};
    my $entityID     = getEntityID($clientValues);

    return ($entityTypeID, $entityID);
}

sub getEntityID {
    my ($clientValues) = @_;
    my $level = $clientValues->{'currentLevel'};
    my $entityID = 0;

    if($level == 100){#National
        $entityID = $clientValues->{'natID'};    
    } 
    elsif ($level == 30){#State
        $entityID = $clientValues->{'stateID'};       
    }
    elsif($level == 20){#Region
        $entityID = $clientValues->{'regionID'};
    }
    elsif($level == 10){#Zone
        $entityID = $clientValues->{'zoneID'};
    }
    elsif ($level == 3){#club
        $entityID = $clientValues->{'clubID'};
    }
    return $entityID;
}

sub getEntityStructure {
    my ($Data, $entityTypeID, $entityID, $upperLevel, $topDown) = @_;

    $entityTypeID ||= 0;
    $entityID     ||= 0;
    $upperLevel   ||= $Defs::LEVEL_NATIONAL;
    $topDown      ||= 0;

    return undef if !$entityTypeID or !$entityID;

    my $cacheKey = "ES_".$entityTypeID."_".$entityID."_".$upperLevel."_".$topDown;
    my $cache = $Data->{'cache'} || '';

    if ($cache) {
    	my $entityStructure = $cache->get('swm', $cacheKey) || '';
        return $entityStructure if $entityStructure;
    }

    my $dbh = $Data->{'db'};

    my @entityStructure = ();
    my @tempStructure   = ();

    if ($entityTypeID <= $Defs::LEVEL_ASSOC) {
        my $assocID = ($entityTypeID == $Defs::LEVEL_ASSOC) ? $entityID : $Data->{'clientValues'}{'assocID'};
        my $tempEntityStructureObj = TempEntityStructureObj->load(db=>$dbh, ID=>$assocID);
        my @levels = (100, 30, 20, 10);
        foreach my $level(@levels) {
            next if $upperLevel and $level > $upperLevel;
            push @tempStructure, [$level, $tempEntityStructureObj->getValue('int'.$level.'_ID')];
        }
        push @tempStructure, [$Defs::LEVEL_ASSOC, $assocID] if $entityTypeID < $Defs::LEVEL_ASSOC;
        push @tempStructure, [$entityTypeID, $entityID];
        @entityStructure = ($topDown) ? @tempStructure : reverse @tempStructure;
    }
    else {
        my $nodeID = $entityID;
        my @levels = (10, 20, 30, 100);
        foreach my $level(@levels) {
            last if $upperLevel and $level > $upperLevel;
            next if $level < $entityTypeID;
            push @tempStructure, [$level, $nodeID];
            my $parentEntityID = EntityLinksObj->getParentEntityID(dbh=>$dbh, nodeID=>$nodeID);
            $nodeID = $parentEntityID;
        }
        @entityStructure = ($topDown) ? reverse @tempStructure : @tempStructure;
    }
  
    my $group = "ES_".$entityTypeID."_".$entityID;

    $cache->set('swm', $cacheKey, \@entityStructure, $group, 60*60*8) if $cache;

    return \@entityStructure;
}

#a simple sub to determine if the weighting of perm1 is greater than that of perm2.
sub isHeavierPerm {
    my ($perm1, $perm2) = @_;
    return ($Defs::FieldPermWeights{$perm1} > $Defs::FieldPermWeights{$perm2}) ? 1 : 0;
}

sub get_page_url {
    my ($data, $keys) = @_;
    my $target = $data->{'target'} || '';
    my $client = setClient($data->{'clientValues'});

    my $link = '';
    for my $k (keys %$keys) {
        $link .= "&$k=$keys->{$k}";
    }

    $link = "$target?client=$client$link";

    return $link;
}


1;
