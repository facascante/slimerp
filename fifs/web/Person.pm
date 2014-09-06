package Person;
require Exporter;
@ISA    = qw(Exporter);
@EXPORT = @EXPORT_OK = qw(
  handlePerson
  getAutoPersonNum
  person_details
  updatePersonNotes
  prePersonAdd
  check_valid_date
  postPersonUpdate
  loadPersonDetails
);

use strict;
use lib '.', '..', 'Clearances';
use Defs;

use Reg_common;
use Utils;
use HTMLForm;
use Countries;
use Postcodes;
use CustomFields;
use FieldLabels;
use ConfigOptions qw(ProcessPermissions);
use GenCode;
use AuditLog;
use DeQuote;
use Duplicates;
#use ProdTransactions;
#use EditPersonClubs;
use CGI qw(cookie unescape);
use Payments;
use TransLog;
use Transactions;
use ConfigOptions;
use ListPersons;

use Clearances;
use GenAgeGroup;
use GridDisplay;
use InstanceOf;

use FieldCaseRule;
use HomePerson;
use InstanceOf;
use Photo;
use AccreditationDisplay;
use DefCodes;

use Log;
use Data::Dumper;

use PrimaryClub;
use DuplicatePrevention;

sub handlePerson {
    my ( $action, $Data, $personID ) = @_;

    my $resultHTML = '';
    my $personName = my $title = '';

    my $clrd_out = 0;
    if ( $Data->{'SystemConfig'}{'Clearances_FilterClearedOut'} ) {
        my $club = $Data->{'clientValues'}{'clubID'};
        my $st   = qq[ 
			SELECT 
				intPersonID, 
				MCC.intClubID,
				strName as ClubName 
			FROM 
				tblPerson_ClubsClearedOut as MCC 
					INNER JOIN tblClub as C ON (C.intClubID = MCC.intClubID) 
			WHERE 
				intPersonID=$personID 
				AND intAssocID = $Data->{'clientValues'}{'assocID'}
		];
        my $query = $Data->{'db'}->prepare($st);
        $query->execute;
        my $clubs = '';
        while ( my $dref = $query->fetchrow_hashref() ) {
            $clrd_out = 1 if ( $dref->{'intClubID'} == $club );
            $clubs .= qq[, ] if $clubs;
            $clubs .= $dref->{'ClubName'};
        }
        $Data->{'PersonClrdOut'} = $clubs ? qq[<b>Cleared Out of: $clubs</b>] : '';
        $Data->{'PersonClrdOut_ofClub'}        = $clrd_out if ( $Data->{'clientValues'}{'authLevel'} <= $Defs::LEVEL_CLUB );
        $Data->{'PersonClrdOut_ofCurrentClub'} = $clrd_out if ( $Data->{'clientValues'}{'authLevel'} <= $Defs::LEVEL_ASSOC );
    }

    if ( $action =~ /P_PH_/ ) {
        my $newaction = '';
        ( $resultHTML, $title, $newaction ) = handle_photo( $action, $Data, $personID );
        $action = $newaction if $newaction;
    }
    if ( $action =~ /^P_DT/ ) {
        #Person Details
        ( $resultHTML, $title ) = person_details( $action, $Data, $personID );
    }
    elsif ( $action =~ /^P_A/ ) {
	    #Person Details
        ( $resultHTML, $title ) = person_details( $action, $Data, $personID );
	}
    elsif ( $action =~ /^P_LSROup/ ) {
        ( $resultHTML, $title ) = bulkPersonRolloverUpdate( $Data, $action );
    }
    elsif ( $action =~ /^P_LSRO/ ) {
        ( $resultHTML, $title ) = bulkPersonRollover( $Data, $action );
    }
    elsif ( $action =~ /^P_L/ ) {
        ( $resultHTML, $title ) = listPersons( $Data, getID($Data->{'clientValues'}), $action );
    }
    elsif ( $action =~ /^P_PRS_L/ ) {
        ( $resultHTML, $title ) = listPersons( $Data, getID($Data->{'clientValues'}), $action );
    }
    elsif ( $action =~ /P_CLB_/ ) {
        ( $resultHTML, $title ) = handlePersonClub( $action, $Data, $personID );
    }
    #elsif ( $action =~ /P_PRODTXN_/ ) {
    #    ( $resultHTML, $title ) = handleProdTransactions( $action, $Data, $personID );
    #}
    elsif ( $action =~ /P_TXN_/ ) {
        ( $resultHTML, $title ) = Transactions::handleTransactions( $action, $Data, $personID );
    }
    elsif ( $action =~ /P_TXNLog/ ) {
        my $entityID = getLastEntityID($Data->{'clientValues'});
        ( $resultHTML, $title ) = TransLog::handleTransLogs( $action, $Data, $entityID, $personID );
    }
    elsif ( $action =~ /P_PAY_/ ) {
        ( $resultHTML, $title ) = handlePayments( $action, $Data, 0 );
    }
    elsif ( $action =~ /^P_DUP_/ ) {
        ( $resultHTML, $title ) = PersonDupl( $action, $Data, $personID );
    }
    elsif ( $action =~ /^P_DEL/ ) {

        #($resultHTML,$title)=delete_person($Data, $personID);
    }
    elsif ( $action =~ /^P_TRANSFER/ ) {
        ( $resultHTML, $title ) = PersonTransfer($Data);
    }
    elsif ( $action =~ /P_CLUBS/ ) {
        my ( $clubStatus, $clubs, undef) = showClubTeams( $Data, $personID );
        $clubs      = qq[<div class="warningmsg">No $Data->{'LevelNames'}{$Defs::LEVEL_CLUB} History found</div>] if !$clubs;
        $resultHTML = $clubs;
        $title      = "$Data->{'LevelNames'}{$Defs::LEVEL_CLUB} History";
    }
    elsif ( $action =~ /P_SEASONS/ ) {
        ( $resultHTML, $title ) = showSeasonSummary( $Data, $personID );
    }
    elsif ( $action =~ /P_CLR/ ) {
        $resultHTML = clearanceHistory( $Data, $personID ) || '';
        my $txt_Clr = $Data->{'SystemConfig'}{'txtCLR'} || 'Clearance';
        $title = $txt_Clr . " History";
    }
    elsif ( $action =~ /^P_HOME/ ) {
        my ( $FieldDefinitions, $memperms ) = person_details( '', $Data, $personID, {}, 1 );
        ( $resultHTML, $title ) = showPersonHome( $Data, $personID, $FieldDefinitions, $memperms );
    }
    elsif ( $action =~ /^P_NACCRED/ ) {
        ( $resultHTML, $title ) = handleAccreditationDisplay( $action, $Data, $personID );
    }
    else {
        print STDERR "Unknown action $action\n";
    }
    return ( $resultHTML, $title );
}

sub updatePersonNotes {

    my ( $db, $personID, $notes_ref ) = @_;
    $personID ||= 0;

    my @noteFields  = (qw(strNotes));
    my %Notes       = ();
    my %notes_ref_l = %{$notes_ref};

    #deQuote($db, \%notes_ref_l);
    my ( $insert_cols, $insert_vals, $update_vals ) = ( "", "", "" );
    my @value_list;

    for my $f (@noteFields) {
        next if ( !exists $notes_ref_l{ 'd_' . $f } and !exists $notes_ref_l{$f} );

        $Notes{$f} = $notes_ref_l{ 'd_' . $f } || $notes_ref_l{$f} || '';
        my $fieldname = $f;
        $insert_cols .= qq[, $fieldname];

        $insert_vals .= qq[, ?];
        $update_vals .= qq[, $fieldname = ? ];
        push @value_list, $Notes{$f};
    }

    my $st = qq[
        INSERT INTO tblPersonNotes
            (intPersonID $insert_cols)
        VALUES 
            ($personID $insert_vals)
        ON DUPLICATE KEY UPDATE tTimeStamp=NOW() $update_vals
    ];

    my $query = $db->prepare($st);
    $query->execute( @value_list, @value_list );
}

sub PersonTransfer {

    my ($Data) = @_;

    my $client           = setClient( $Data->{'clientValues'} ) || '';
    my $body             = '';
    my $cgi              = new CGI;
    my %params           = $cgi->Vars();
    my $db               = $Data->{'db'};
    my $transfer_natnum  = $params{'transfer_natnum'} || '';
    my $transfer_surname = $params{'transfer_surname'} || '';
    my $transfer_dob     = $params{'transfer_dob'} || '';
    my $personID         = $params{'personID'} || 0;
    $transfer_dob = '' if !check_valid_date($transfer_dob);
    $transfer_dob = _fix_date($transfer_dob) if ( check_valid_date($transfer_dob) );
    deQuote( $db, \$transfer_natnum );
    deQuote( $db, \$transfer_surname );
    deQuote( $db, \$transfer_dob );
    my $confirmed = $params{'transfer_confirm'} || 0;
    my $assocTypeIDWHERE = exists $Data->{'SystemConfig'}{'PersonTransfer_AssocType'} ? qq[ AND A.intAssocTypeID = $Data->{'SystemConfig'}{'PersonTransfer_AssocType'} ] : '';
    my $st = qq[
		SELECT 
            M.intPersonID, 
            A.strName, 
            A.intAssocID, 
            MA.strStatus, 
            CONCAT(M.strLocalFirstname, ' ', M.strLocalSurname) as PersonName, 
            DATE_FORMAT(dtDOB,'%d/%m/%Y') AS dtDOB, 
            DATE_FORMAT(dtDOB, "%Y%m%d") as DOBAgeGroup, 
            M.intGender
		FROM tblPerson as M
			INNER JOIN tblPerson_Associations as MA ON (MA.intPersonID = M.intPersonID)
			INNER JOIN tblAssoc as A ON (A.intAssocID = MA.intAssocID)
		WHERE M.intRealmID = $Data->{'Realm'}
			$assocTypeIDWHERE
			AND M.strLocalSurname = $transfer_surname
			AND (M.strNationalNum = $transfer_natnum OR M.dtDOB= $transfer_dob)
			AND M.intSystemStatus = $Defs::PERSONSTATUS_ACTIVE
	];
    $st .= qq[ AND M.intPersonID = $personID] if $personID;

    if ( !$params{'transfer_surname'} and ( !$params{'transfer_dob'} or !$params{'transfer_surname'} ) ) {
        my $assocType = '';
        my $assocTypeIDWHERE = exists $Data->{'SystemConfig'}{'PersonTransfer_AssocType'} ? qq[ AND intSubTypeID = $Data->{'SystemConfig'}{'PersonTransfer_AssocType'} ] : '';
        if ($assocTypeIDWHERE) {
            my $st = qq[
				SELECT strSubTypeName
				FROM tblRealmSubTypes
				WHERE intRealmID = $Data->{'Realm'}
		                        $assocTypeIDWHERE
			];
            my $query = $db->prepare($st);
            $query->execute;
            my $dref = $query->fetchrow_hashref() || undef;
            $assocType = qq[ <b>(from $dref->{strSubTypeName} only)</b>];
        }
        $body .= qq[
			<form action="$Data->{'target'}" method="POST" style="float:left;" onsubmit="document.getElementById('btnsubmit').disabled=true;return true;">
                                <p>If you wish to Transfer a person to this Association $assocType, please fill in the Surname and $Data->{'SystemConfig'}{'NationalNumName'} or Date of Birth below and click <b>Transfer Person</b>.</p>

                        <table>
				<tr><td><span class="label">Person's Surname:</td><td><span class="formw"><input type="text" name="transfer_surname" value=""></td></tr>
				<tr><td><b>AND</b></td></tr>
				<tr><td>&nbsp;</td></tr>
				<tr><td><span class="label">$Data->{'SystemConfig'}{'NationalNumName'}:</td><td><span class="formw"><input type="text" name="transfer_natnum" value=""></td></tr>
				<tr><td><b>OR</b></td></tr>
				<tr><td><span class="label">Person's Date of Birth:</td><td><span class="formw"><input type="text" name="transfer_dob" value="">&nbsp;<i>dd/mm/yyyy</li></td></tr>
			</table>
                                <input type="hidden" name="a" value="P_TRANSFER">
                                <input type="hidden" name="client" value="$client">
                                <input type="submit" value="Transfer Person" id="btnsubmit" name="btnsubmit"  class="button proceed-button">
                        </form>
		];
    }
    elsif ( !$confirmed and !$personID ) {
        my $query = $db->prepare($st);
        $query->execute;
        $body .= qq[
                                <p>Please select a person to be transferred and click the <b>select</b> link.</p>
                        <p>
                        	<table>
                               	<tr><td>&nbsp;</td>		
								<td><span class="label">$Data->{'SystemConfig'}{'NationalNumName'}:</td>
                               	<td><span class="label">Person's Name:</td>
                               	<td><span class="label">Person's Date Of Birth:</td>
                               	<td><span class="label">Linked To:</td>
							</tr>
		];
        my $count = 0;
        while ( my $dref = $query->fetchrow_hashref() ) {
            $count++;
            my $href = qq[client=$client&amp;a=P_TRANSFER&amp;transfer_surname=$params{'transfer_surname'}&amp;transfer_dob=$params{'transfer_dob'}&amp;transfer_natnum=$params{'transfer_natnum'}];
            $body .= qq[<tr><td><a href="$Data->{'target'}?$href&amp;personID=$dref->{intPersonID}">select</a></td>
							<td>$dref->{strNationalNum}</td>
							<td>$dref->{PersonName}</td>
							<td>$dref->{dtDOB}</td>
							<td>$dref->{strName}</td></tr>];
        }
        $body .= qq[</table>];
        if ( !$count ) {
            $body = qq[<p class="warningmsg">No Persons found</p>];
        }

    }
    elsif ( !$confirmed and $personID ) {
        my $query = $db->prepare($st);
        $query->execute;
        $body .= qq[
                        <form action="$Data->{'target'}" method="POST" style="float:left;" onsubmit="document.getElementById('btnsubmit').disabled=true;return true;">
                                <p>Please review the person to be transferred and click the <b>Confirm Transfer</b> button below.</p>

                        <p>
                                <table>
                                <tr><td><span class="label">$Data->{'SystemConfig'}{'NationalNumName'}:</td><td><span class="formw">:$params{'transfer_natnum'}</td></tr>
                                <tr><td><span class="label">Person's Surname:</td><td><span class="formw">:$params{'transfer_surname'}</td></tr>
                                <tr><td><span class="label">Person's DOB:</td><td><span class="formw">:$params{'transfer_dob'}</td></tr>
                                <tr><td><span class="label">Linked to:</td><td>&nbsp;</td></tr>
                ];
        my $count     = 0;
        my $thisassoc = 0;
        while ( my $dref = $query->fetchrow_hashref() ) {
            $thisassoc = 1 if ( $dref->{intAssocID} == $Data->{'clientValues'}{'assocID'} );
            $count++;
            $body .= qq[<tr><td colspan="2">$dref->{strName}</td></tr>];
        }
        $body .= qq[
                                </table><br>
                                <input type="hidden" name="a" value="P_TRANSFER">
                                <input type="hidden" name="transfer_confirm" value="1">
                                <input type="hidden" name="transfer_natnum" value="$params{'transfer_natnum'}">
                                <input type="hidden" name="transfer_surname" value="$params{'transfer_surname'}">
                                <input type="hidden" name="transfer_dob" value="$params{'transfer_dob'}">
                                <input type="hidden" name="personID" value="$personID">
                                <input type="hidden" name="client" value="$client">
                                <input type="submit" value="Confirm transfer" id="btnsubmit" name="btnsubmit"  class="button proceed-button">
                        </form>
                ];
        $body = qq[<p class="warningmsg">Person already exists in this Association</p>] if ($thisassoc);
        if ( !$count ) {
            $body = qq[<p class="warningmsg">Person not found</p>];
        }
    }
    elsif ($confirmed) {
        $st .= qq[ LIMIT 1];
        my $query = $db->prepare($st);
        $query->execute;
        my ( $personID, undef, $oldAssocID, $recstatus, undef, undef, $DOBAgeGroup, $Gender ) = $query->fetchrow_array();
        $DOBAgeGroup ||= '';
        $Gender      ||= 0;
        $personID    ||= 0;
        my $assocID      = $Data->{clientValues}{'assocID'} || 0;
        my $assocSeasons = Seasons::getDefaultAssocSeasons($Data);
        my %types        = ();

        $types{'intMSRecStatus'} = 1;
        if ( $personID and $assocID ) {
            my $genAgeGroup ||= new GenAgeGroup( $Data->{'db'}, $Data->{'Realm'}, $Data->{'RealmSubType'}, $assocID );
            my $ageGroupID = $genAgeGroup->getAgeGroup( $Gender, $DOBAgeGroup ) || 0;
            warn("INSERT personRego & any products");
            my $mem_st = qq[
				UPDATE tblPerson
				SET intPlayer = 1
				WHERE intPersonID = $personID
				LIMIT 1
			];
            $db->do($mem_st);
            my %tempClientValues = %{ $Data->{clientValues} };
            $tempClientValues{personID}     = $personID;
            $tempClientValues{currentLevel} = $Defs::LEVEL_PERSON;
            my $tempClient = setClient( \%tempClientValues );
            $body = qq[ <div class="OKmsg">The person has been transferred</div><br><a href="$Data->{'target'}?client=$tempClient&amp;a=P_HOME">click here to display persons record</a>];

        }
    }
    else {
        return ( "Invalid Option", "Transfer Person" );
    }
    return ( $body, "Person Transfer" );

}

sub person_details {
    my ( $action, $Data, $personID, $prefillData, $returndata ) = @_;
    $returndata ||= 0;
    my $option = 'display';
    $option = 'edit' if $action eq 'P_DTE' and allowedAction( $Data, 'm_e' );
    $option = 'add'  if $action eq 'P_A'   and allowedAction( $Data, 'm_a' );
    $option = 'add' if ( $Data->{'RegoForm'} and !$personID );
    $personID = 0 if $option eq 'add';
    my $hideWebCamTab = $Data->{SystemConfig}{hide_webcam_tab} ? qq[&hwct=1] : '';
    my $field = loadPersonDetails( $Data->{'db'}, $personID ) || ();
    

    if ( $prefillData and ref $prefillData ) {
        if ($personID) {
            for my $k ( keys %{$prefillData} ) { $field->{$k} ||= $prefillData->{$k} if $prefillData->{$k}; }
        }
        else {
            $field = $prefillData;
        }
    }
    my $natnumname = $Data->{'SystemConfig'}{'NationalNumName'} || 'National Number';
    my $FieldLabels   = FieldLabels::getFieldLabels( $Data, $Defs::LEVEL_PERSON );
    my @countries     = getCountriesArray($Data);
    my %countriesonly = ();
    for my $c (@countries) {
        $countriesonly{$c} = $c;
    }
    my $countries = getCountriesHash($Data);

    my ($DefCodes, $DefCodesOrder) = getDefCodes(
        dbh        => $Data->{'db'}, 
        realmID    => $Data->{'Realm'},
        subRealmID => $Data->{'RealmSubType'} || $field->{'intAssocTypeID'},
        assocID    => $Data->{'clientValues'}{'assocID'},
        hideCodes  => $Data->{'SystemConfig'}{'AssocConfig'}{'hideDefCodes'},
    );

    my $CustomFieldNames = CustomFields::getCustomFieldNames( $Data, $field->{'intAssocTypeID'} ) || '';
    my $fieldsdefined = 1;
    my %genderoptions = ();
    for my $k ( keys %Defs::PersonGenderInfo ) {
        next if !$k;
        next if ( $Data->{'SystemConfig'}{'NoUnspecifiedGender'} and $k eq $Defs::GENDER_NONE );
        $genderoptions{$k} = $Defs::PersonGenderInfo{$k} || '';
    }

    my $client = setClient( $Data->{'clientValues'} ) || '';

    my $photolink = '';
    if ($field->{'intPersonID'}) {
        my $hash = authstring($field->{'intPersonID'});
        $photolink = qq[<img src = "getphoto.cgi?pa=$field->{'intPersonID'}f$hash" onerror="this.style.display='none'" height='200px'>];
    }
    my $field_case_rules = get_field_case_rules({dbh=>$Data->{'db'}, client=>$client, type=>'Person'});
	my @reverseYNOrder = ('',1,0);

    my $mrt_config = '';
       #readonly      => $Data->{'clientValues'}{'authLevel'} >= $Defs::LEVEL_NATIONAL ? 0 : 1,
               

    my %FieldDefinitions = (
        fields => {
            strFIFAID => {
                label       => $FieldLabels->{'strFIFAID'},
                value       => $field->{strFIFAID},
                type        => 'text',
                size        => '14',
                readonly    => 1,
                sectionname => 'details',
            },
            strNationalNum => {
                label       => $FieldLabels->{'strNationalNum'},
                value       => $field->{strNationalNum},
                type        => 'text',
                size        => '14',
                readonly    => 1,
                sectionname => 'details',
            },
            strPersonNo => {
                label       => $FieldLabels->{'strPersonNo'},
                value       => $field->{strPersonNo},
                type        => 'text',
                size        => '15',
                maxsize     => '15',
                sectionname => 'details',
            },
            strStatus => {
                label         => $FieldLabels->{'strStatus'},
                value         => $field->{strStatus},
                type          => 'lookup',
                sectionname   => 'details',
                options       => \%Defs::personStatus, 
                readonly      => $Data->{'clientValues'}{'authLevel'} >= $Defs::LEVEL_NATIONAL ? 0 : 1,
                noadd         => 1,
            },
            strTitle => {
                label       => $FieldLabels->{'strTitle'},
                value       => $field->{strTitle},
                type        => 'text',
                size        => '20',
                maxsize     => '30',
                sectionname => 'details',
            },

            strLocalFirstname => {
                label       => $FieldLabels->{'strLocalFirstname'},
                value       => $field->{strLocalFirstname},
                type        => 'text',
                size        => '40',
                maxsize     => '50',
                sectionname => 'details',
                first_page  => 1,
            },
            strLocalMiddlename => {
                label       => $FieldLabels->{'strLocalMiddlename'},
                value       => $field->{strLocalMiddlename},
                type        => 'text',
                size        => '40',
                maxsize     => '50',
                sectionname => 'details',
            },
            strLocalSurname => {
                label       => $Data->{'SystemConfig'}{'strLocalSurname_Text'} ? $Data->{'SystemConfig'}{'strLocalSurname_Text'} : $FieldLabels->{'strLocalSurname'},
                value       => $field->{strLocalSurname},
                type        => 'text',
                size        => '40',
                maxsize     => '50',
                sectionname => 'details',
                first_page  => 1,
            },


            strLatinFirstname => {
                label       => $FieldLabels->{'strLatinFirstname'},
                value       => $field->{strLatinFirstname},
                type        => 'text',
                size        => '40',
                maxsize     => '50',
                sectionname => 'details',
                first_page  => 1,
            },
            strLatinMiddlename => {
                label       => $FieldLabels->{'strLatinMiddlename'},
                value       => $field->{strLatinMiddlename},
                type        => 'text',
                size        => '40',
                maxsize     => '50',
                sectionname => 'details',
            },
            strLatinSurname => {
                label       => $Data->{'SystemConfig'}{'strLocalSurname_Text'} ? $Data->{'SystemConfig'}{'strLocalSurname_Text'} : $FieldLabels->{'strLatinSurname'},
                value       => $field->{strLatinSurname},
                type        => 'text',
                size        => '40',
                maxsize     => '50',
                sectionname => 'details',
                first_page  => 1,
            },


            strMaidenName => {
                label       => $FieldLabels->{'strMaidenName'},
                value       => $field->{strMaidenName},
                type        => 'text',
                size        => '40',
                maxsize     => '50',
                sectionname => 'details',
            },
            strPreferredName => {
                label       => $FieldLabels->{'strPreferredName'},
                value       => $field->{strPreferredName},
                type        => 'text',
                size        => '40',
                maxsize     => '50',
                sectionname => 'details',
            },
            dtDOB => {
                label       => $FieldLabels->{'dtDOB'},
                value       => $field->{dtDOB},
                type        => 'date',
                datetype    => 'dropdown',
                format      => 'dd/mm/yyyy',
                sectionname => 'details',
                validate    => 'DATE',
                first_page  => 1,

                #onChange   => 1,
            },
            strPlaceofBirth => {
                label       => $FieldLabels->{'strPlaceofBirth'},
                value       => $field->{strPlaceofBirth},
                type        => 'text',
                size        => '30',
                maxsize     => '45',
                sectionname => 'details',
            },
            strISOCountryOfBirth => {
                label       => $FieldLabels->{'strISOCountryOfBirth'},
                value       => $field->{strISOCountryOfBirth},
                type        => 'lookup',
                options     => \%countriesonly,
                sectionname => 'other',
                firstoption => [ '', 'Select Country' ],
            },
            strISOMotherCountry => {
                label       => $FieldLabels->{'strISOMotherCountry'},
                value       => $field->{strMotherISOCountry},
                type        => 'lookup',
                options     => \%countriesonly,
                sectionname => 'details',
                firstoption => [ '', 'Select Country' ],
            },
            strISOFatherCountry => {
                label       => $FieldLabels->{'strISOFatherCountry'},
                value       => $field->{strISOFatherCountry},
                type        => 'lookup',
                options     => \%countriesonly,
                sectionname => 'details',
                firstoption => [ '', 'Select Country' ],
            },
            intGender => {
                label       => $FieldLabels->{'intGender'},
                value       => $field->{intGender},
                type        => 'lookup',
                options     => \%genderoptions,
                sectionname => 'details',
                firstoption => [ '', " " ],
                first_page  => 1,
            },

            strAddress1 => {
                label       => $FieldLabels->{'strAddress1'},
                value       => $field->{strAddress1},
                type        => 'text',
                size        => '50',
                maxsize     => '100',
                sectionname => 'contact',
            },
            strAddress2 => {
                label       => $FieldLabels->{'strAddress2'},
                value       => $field->{strAddress2},
                type        => 'text',
                size        => '50',
                maxsize     => '100',
                sectionname => 'contact',
            },
            strSuburb => {
                label       => $FieldLabels->{'strSuburb'},
                value       => $field->{strSuburb},
                type        => 'text',
                size        => '30',
                maxsize     => '100',
                sectionname => 'contact',
            },
            strState => {
                label       => $FieldLabels->{'strState'},
                value       => $field->{strState},
                type        => 'text',
                size        => '50',
                maxsize     => '100',
                sectionname => 'contact',
            },
            strISOCountry => {
                label       => $FieldLabels->{'strISOCountry'},
                value       => $field->{strISOCountry}, 
                type        => 'lookup',
                options     => \%countriesonly,
                sectionname => 'contact',
                firstoption => [ '', 'Select Country' ],
            },
            strPostalCode => {
                label       => $FieldLabels->{'strPostalCode'},
                value       => $field->{strPostalCode},
                type        => 'text',
                size        => '15',
                maxsize     => '15',
                sectionname => 'contact',
            },
            strPhoneHome => {
                label       => $FieldLabels->{'strPhoneHome'},
                value       => $field->{strPhoneHome},
                type        => 'text',
                size        => '20',
                maxsize     => '30',
                sectionname => 'contact',
            },
            strPhoneWork => {
                label       => $FieldLabels->{'strPhoneWork'},
                value       => $field->{strPhoneWork},
                type        => 'text',
                size        => '20',
                maxsize     => '30',
                sectionname => 'contact',
            },
            strPhoneMobile => {
                label       => $FieldLabels->{'strPhoneMobile'},
                value       => $field->{strPhoneMobile},
                type        => 'text',
                size        => '20',
                maxsize     => '30',
                sectionname => 'contact',
            },
            strPager => {
                label       => $FieldLabels->{'strPager'},
                value       => $field->{strPager},
                type        => 'text',
                size        => '20',
                maxsize     => '30',
                sectionname => 'contact',
            },
            strFax => {
                label       => $FieldLabels->{'strFax'},
                value       => $field->{strFax},
                type        => 'text',
                size        => '20',
                maxsize     => '30',
                sectionname => 'contact',
            },
            strEmail => {
                label       => $FieldLabels->{'strEmail'},
                value       => $field->{strEmail},
                type        => 'text',
                size        => '50',
                maxsize     => '200',
                sectionname => 'contact',
                validate    => 'EMAIL',
            },
            intEthnicityID => {
                label       => $FieldLabels->{'intEthnicityID'},
                value       => $field->{intEthnicityID},
                type        => 'lookup',
                options     => $DefCodes->{-8},
                order       => $DefCodesOrder->{-8},
                sectionname => 'details',
                firstoption => [ '', " " ],
            },
            strPreferredLang => {
                label       => $FieldLabels->{'strPreferredLang'},
                value       => $field->{strPreferredLang},
                type        => 'text',
                size        => '20',
                maxsize     => '50',
                sectionname => 'identification',
            },
            strPassportIssueCountry => {
                label       => $FieldLabels->{'strPassportIssueCountry'},
                value       => uc( $field->{strPassportIssueCountry} ),
                type        => 'lookup',
                options     => \%countriesonly,
                sectionname => 'identification',
                firstoption => [ '', " " ],
            },
            strPassportNationality => {
                label       => $FieldLabels->{'strPassportNationality'},
                value       => uc( $field->{strPassportNationality} ),
                type        => 'lookup',
                options     => \%countriesonly,
                sectionname => 'identification',
                firstoption => [ '', " " ],
            },
            strPassportNo => {
                label       => $FieldLabels->{'strPassportNo'},
                value       => $field->{strPassportNo},
                type        => 'text',
                size        => '20',
                maxsize     => '50',
                sectionname => 'identification',
            },
            dtPassportExpiry => {
                label       => $FieldLabels->{'dtPassportExpiry'},
                value       => $field->{dtPassportExpiry},
                type        => 'date',
                format      => 'dd/mm/yyyy',
                sectionname => 'identification',
                validate    => 'DATE',
            },
            dtPoliceCheck => {
                label => $Data->{'SystemConfig'}{'dtPoliceCheck_Text'} ? $Data->{'SystemConfig'}{'dtPoliceCheck_Text'} : $FieldLabels->{'dtPoliceCheck'},
                value => $field->{dtPoliceCheck},
                type  => 'date',
                format      => 'dd/mm/yyyy',
                sectionname => 'identification',
                validate    => 'DATE',
            },
            dtPoliceCheckExp => {
                label => $Data->{'SystemConfig'}{'dtPoliceCheckExp_Text'} ? $Data->{'SystemConfig'}{'dtPoliceCheckExp_Text'} : $FieldLabels->{'dtPoliceCheckExp'},
                value => $field->{dtPoliceCheckExp},
                type  => 'date',
                format      => 'dd/mm/yyyy',
                sectionname => 'identification',
                validate    => 'DATE',
            },
            strPoliceCheckRef => {
                label       => $FieldLabels->{'strPoliceCheckRef'},
                value       => $field->{strPoliceCheckRef},
                type        => 'text',
                size        => '20',
                maxsize     => '30',
                sectionname => 'identification',
            },
            strEmergContName => {
                label       => $FieldLabels->{'strEmergContName'},
                value       => $field->{strEmergContName},
                type        => 'text',
                size        => '30',
                maxsize     => '100',
                sectionname => 'contact',
            },
            strEmergContNo => {
                label       => $FieldLabels->{'strEmergContNo'},
                value       => $field->{strEmergContNo},
                type        => 'text',
                size        => '30',
                maxsize     => '100',
                sectionname => 'contact',
            },
            strEmergContRel => {
                label       => $FieldLabels->{'strEmergContRel'},
                value       => $field->{strEmergContRel},
                type        => 'text',
                size        => '30',
                maxsize     => '100',
                sectionname => 'contact',
            },
            strP1Salutation => {
                label       => $FieldLabels->{'strP1Salutation'},
                value       => $field->{strP1Salutation},
                type        => 'text',
                size        => '20',
                maxsize     => '30',
                sectionname => 'parent',
            },
            strP2Salutation => {
                label       => $FieldLabels->{'strP2Salutation'},
                value       => $field->{strP2Salutation},
                type        => 'text',
                size        => '20',
                maxsize     => '30',
                sectionname => 'parent',
            },
            intP1Gender => {
                label       => $FieldLabels->{'intP1Gender'},
                value       => $field->{intP1Gender},
                type        => 'lookup',
                options     => \%genderoptions,
                sectionname => 'details',
                firstoption => [ '', " " ],
                sectionname => 'parent',
            },
            intP2Gender => {
                label       => $FieldLabels->{'intP2Gender'},
                value       => $field->{intP2Gender},
                type        => 'lookup',
                options     => \%genderoptions,
                sectionname => 'details',
                firstoption => [ '', " " ],
                sectionname => 'parent',
            },
            strP1FName => {
                label       => $FieldLabels->{'strP1FName'},
                value       => $field->{strP1FName},
                type        => 'text',
                size        => '30',
                maxsize     => '50',
                sectionname => 'parent',
            },
            strP1SName => {
                label       => $FieldLabels->{'strP1SName'},
                value       => $field->{strP1SName},
                type        => 'text',
                size        => '30',
                maxsize     => '50',
                sectionname => 'parent',
            },
            strP2FName => {
                label       => $FieldLabels->{'strP2FName'},
                value       => $field->{strP2FName},
                type        => 'text',
                size        => '30',
                maxsize     => '50',
                sectionname => 'parent',
            },
            strP2SName => {
                label       => $FieldLabels->{'strP2SName'},
                value       => $field->{strP2SName},
                type        => 'text',
                size        => '30',
                maxsize     => '50',
                sectionname => 'parent',
            },
            strP1Phone => {
                label       => $FieldLabels->{'strP1Phone'},
                value       => $field->{strP1Phone},
                type        => 'text',
                size        => '20',
                maxsize     => '30',
                sectionname => 'parent',
            },
            strP2Phone => {
                label       => $FieldLabels->{'strP2Phone'},
                value       => $field->{strP2Phone},
                type        => 'text',
                size        => '20',
                maxsize     => '30',
                sectionname => 'parent',
            },
            strP1Phone2 => {
                label       => $FieldLabels->{'strP1Phone2'},
                value       => $field->{strP1Phone2},
                type        => 'text',
                size        => '20',
                maxsize     => '30',
                sectionname => 'parent',
            },
            strP2Phone2 => {
                label       => $FieldLabels->{'strP2Phone2'},
                value       => $field->{strP2Phone2},
                type        => 'text',
                size        => '20',
                maxsize     => '30',
                sectionname => 'parent',
            },
            strP1PhoneMobile => {
                label       => $FieldLabels->{'strP1PhoneMobile'},
                value       => $field->{strP1PhoneMobile},
                type        => 'text',
                size        => '20',
                maxsize     => '30',
                sectionname => 'parent',
            },
            strP2PhoneMobile => {
                label       => $FieldLabels->{'strP2PhoneMobile'},
                value       => $field->{strP2PhoneMobile},
                type        => 'text',
                size        => '20',
                maxsize     => '30',
                sectionname => 'parent',
            },
            strP1Email => {
                label       => $FieldLabels->{'strP1Email'},
                value       => $field->{strP1Email},
                type        => 'text',
                size        => '50',
                maxsize     => '200',
                sectionname => 'parent',
                validate    => 'EMAIL',
            },
            strP2Email => {
                label       => $FieldLabels->{'strP2Email'},
                value       => $field->{strP2Email},
                type        => 'text',
                size        => '50',
                maxsize     => '200',
                sectionname => 'parent',
                validate    => 'EMAIL',
            },
            strP1Email2 => {
                label       => $FieldLabels->{'strP1Email2'},
                value       => $field->{strP1Email2},
                type        => 'text',
                size        => '50',
                maxsize     => '200',
                sectionname => 'parent',
                validate    => 'EMAIL',
            },
            strP2Email2 => {
                label       => $FieldLabels->{'strP2Email2'},
                value       => $field->{strP2Email2},
                type        => 'text',
                size        => '50',
                maxsize     => '200',
                sectionname => 'parent',
                validate    => 'EMAIL',
            },
            strEyeColour => {
                label       => $FieldLabels->{'strEyeColour'},
                value       => $field->{strEyeColour},
                type        => 'lookup',
                options     => $DefCodes->{-11},
                order       => $DefCodesOrder->{-11},
                sectionname => 'other',
                firstoption => [ '', " " ],
                sectionname => 'details',
            },
            strHairColour => {
                label       => $FieldLabels->{'strHairColour'},
                value       => $field->{strHairColour},
                type        => 'lookup',
                options     => $DefCodes->{-10},
                order       => $DefCodesOrder->{-10},
                sectionname => 'other',
                firstoption => [ '', " " ],
                sectionname => 'details',
            },
            strHeight => {
                label       => $FieldLabels->{'strHeight'},
                value       => $field->{strHeight},
                type        => 'text',
                size        => '5',
                maxsize     => '20',
                sectionname => 'details',
                format_txt  => 'cm',
            },
            strWeight => {
                label       => $FieldLabels->{'strWeight'},
                value       => $field->{strWeight},
                type        => 'text',
                size        => '5',
                maxsize     => '20',
                sectionname => 'details',
                format_txt  => 'kg',
            },

            dtLastUpdate => {
                label       => 'Last Updated',
                value       => $field->{tTimeStamp},
                type        => 'date',
                format      => 'dd/mm/yyyy',
                sectionname => 'other',
                readonly    => 1,
            },
            strNotes => {
                label             => $FieldLabels->{'strNotes'},
                value             => $field->{strPersonNotes},
                type              => 'textarea',
                sectionname       => 'other',
                rows              => 5,
                cols              => 45,
                SkipAddProcessing => 1,
                SkipProcessing    => 1,
            },
            PhotoUpload => {
                label => 'Photo',
                type  => 'htmlblock',
                value => q[
                <div id="photoupload_result">] . $photolink . q[</div>
                <div id="photoupload_form"></div>
                <input type="button" value = " Upload Photo " id = "photoupload" class="button generic-button">
                <input type="hidden" name = "d_PhotoUpload" value = "] . ( $photolink ? 'valid' : '' ) . q[">
                <script>
                jQuery('#photoupload').click(function() {
                        jQuery('#photoupload_form').html('<iframe src="regoformphoto.cgi?client=] . $client . $hideWebCamTab . q[" style="width:750px;height:650px;border:0px;"></iframe>');
                        jQuery('#photoupload_form').dialog({
                                width: 800,
                                height: 700,
                                modal: true,
                                title: 'Upload Photo'
                            });
                    });
                </script>
                ],
                SkipAddProcessing => 1,
                SkipProcessing    => 1,
            },
            SPident   => { type => '_SPACE_', sectionname => 'citizenship' },
            SPcontact => { type => '_SPACE_', sectionname => 'contact' },
            SPdetails => { type => '_SPACE_', sectionname => 'details' },

        },
        order => [
        qw(strNationalNum strPersonNo strSalutation strStatus strLocalFirstname strPreferredName strMiddlename strLocalSurname strMaidenName dtDOB strPlaceofBirth strCountryOfBirth strMotherCountry strFatherCountry intGender strAddress1 strAddress2 strSuburb strState strPostalCode strCountry strPhoneHome strPhoneWork strPhoneMobile strPager strFax strEmail strEmail2 SPcontact intDeceased intDeRegister strPreferredLang strPassportIssueCountry strPassportNationality strPassportNo dtPassportExpiry dtPoliceCheck dtPoliceCheckExp strPoliceCheckRef strEmergContName strEmergContNo strEmergContNo2 strEmergContRel strP1Salutation strP1FName strP1SName intP1Gender strP1Phone strP1Phone2 strP1PhoneMobile strP1Email strP1Email2 strP2Salutation strP2FName strP2SName intP2Gender strP2Phone strP2Phone2 strP2PhoneMobile strP2Email strP2Email2 strEyeColour strHairColour strHeight strWeight 
        ),

        map("strNatCustomStr$_", (1..15)),
        map("dblNatCustomDbl$_", (1..10)),
        map("dtNatCustomDt$_", (1..5)),
        map("intNatCustomLU$_", (1..10)),
        map("intNatCustomBool$_", (1..5)),
        qw(
        strNotes SPdetails dtLastUpdate 
        )
        ],
        fieldtransform => {
            textcase => {
                strLocalFirstname => $field_case_rules->{'strLocalFirstname'} || '',
                strLocalSurname   => $field_case_rules->{'strLocalSurname'}   || '',
                strSuburb    => $field_case_rules->{'strSuburb'}    || '',
            }
        },
        sections => [
        [ 'regoform',       q{} ],
        [ 'details',        'Personal Details' ],
        [ 'contact',        'Contact Details' ],
        [ 'identification', 'Identification' ],
        [ 'profile',        'Profile' ],
        [ 'contracts',      'Contracts' ],
        [ 'citizenship',    'Citizenship' ],
        [ 'parent',         'Parent/Guardian' ],
        [ 'custom1',        $Data->{'SystemConfig'}{'MF_CustomGroup1'} ],
        [ 'other',          'Other Details' ],
        [ 'records',        'Initial Person Records' ],
        ],
        options => {
            labelsuffix          => ':',
            hideblank            => 1,
            target               => $Data->{'target'},
            formname             => 'm_form',
            submitlabel          => $Data->{'lang'}->txt( 'Update ' . $Data->{'LevelNames'}{$Defs::LEVEL_PERSON} ),
            introtext            => $Data->{'lang'}->txt('HTMLFORM_INTROTEXT'),
            buttonloc            => $Data->{'SystemConfig'}{'HTMLFORM_ButtonLocation'} || 'both',
            OptionAfterProcessed => 'display',
            updateSQL            => qq[
            UPDATE tblPerson
            SET --VAL--
            WHERE tblPerson.intPersonID=$personID
            ],
            addSQL => qq[
            INSERT INTO tblPerson (intRealmID, strStatus, --FIELDS--)
            VALUES ($Data->{'Realm'},  'INPROGRESS', --VAL--)
            ],
            NoHTML               => 1,
            afterupdateFunction  => \&postPersonUpdate,
            afterupdateParams    => [ $option, $Data, $Data->{'db'}, $personID, $field ],
            afteraddFunction     => \&postPersonUpdate,
            afteraddParams       => [ $option, $Data, $Data->{'db'} ],
            beforeaddFunction    => \&prePersonAdd,
            beforeaddParams      => [ $option, $Data, $Data->{'db'} ],
            afteraddAction       => 'edit',

            auditFunction  => \&auditLog,
            auditAddParams => [
            $Data,
            'Add',
            'Person'
            ],
            auditEditParams => [
            $personID,
            $Data,
            'Update',
            'Person',
            ],
            auditEditParamsAddFields => 1,

            LocaleMakeText        => $Data->{'lang'},
            pre_button_bottomtext => $Data->{'SystemConfig'}{'PersonFooterText'} || '',
        },
        carryfields => {
            client => $client,
            a      => $action,
        },
    );


    ######################################################
    # generate custom fileds definitions
    ######################################################

    # map("strNatCustomStr$_", (1..15)),
    for my $i (1..15) {
        my $fieldname = "strNatCustomStr$i";
        $FieldDefinitions{'fields'}{$fieldname} = {
            label => $CustomFieldNames->{$fieldname}[0] || '',
            value => $field->{$fieldname},
            type  => 'text',
            size  => '30',
            maxsize     => '50',
            sectionname => 'other',
            readonly    => ( $Data->{'clientValues'}{'authLevel'} < $Defs::LEVEL_NATIONAL and $Data->{'SystemConfig'}{"NationalOnly_$fieldname"} ? 1 : 0 ),
        };
    }

    # map("dblNatCustomDbl$_", (1..10)),
    for my $i (1..10) {
        my $fieldname = "dblNatCustomDbl$i";
        $FieldDefinitions{'fields'}{$fieldname} = {
            label => $CustomFieldNames->{$fieldname}[0] || '',
            value => $field->{$fieldname},
            type  => 'text',
            size  => '10',
            maxsize     => '15',
            sectionname => 'other',
            readonly    => ( $Data->{'clientValues'}{'authLevel'} < $Defs::LEVEL_NATIONAL and $Data->{'SystemConfig'}{"NationalOnly_$fieldname"} ? 1 : 0 ),
        };
    }

    # map("dtNatCustomDt$_", (1..5)),
    for my $i (1..5) {
        my $fieldname = "dtNatCustomDt$i";
        $FieldDefinitions{'fields'}{$fieldname} = {
            label => $CustomFieldNames->{$fieldname}[0] || '',
            value => $field->{$fieldname},
            type  => 'date',
            format      => 'dd/mm/yyyy',
            sectionname => 'other',
            validate    => 'DATE',
            readonly    => ( $Data->{'clientValues'}{'authLevel'} < $Defs::LEVEL_NATIONAL and $Data->{'SystemConfig'}{"NationalOnly_$fieldname"} ? 1 : 0 ),
        };
    }

    # map("intNatCustomLU$_", (1..10)),
    my @intNatCustomLU_DefsCodes = (undef, -53, -54, -55, -64, -65, -66, -67, -68,-69,-70);
    for my $i (1..10) {
        my $fieldname = "intNatCustomLU$i";
        $FieldDefinitions{'fields'}{$fieldname} = {
            label => $CustomFieldNames->{$fieldname}[0] || '',
            value => $field->{$fieldname},
            type  => 'lookup',
            options     => $DefCodes->{$intNatCustomLU_DefsCodes[$i]},
            order       => $DefCodesOrder->{$intNatCustomLU_DefsCodes[$i]},
            firstoption => [ '', " " ],
            sectionname => 'other',
            readonly    => ( $Data->{'clientValues'}{'authLevel'} < $Defs::LEVEL_NATIONAL and $Data->{'SystemConfig'}{"NationalOnly_$fieldname"} ? 1 : 0 ),
        };
    }

    # map("intNatCustomBool$_", (1..5)),
    for my $i (1..5) {
        my $fieldname = "intNatCustomBool$i";
        $FieldDefinitions{'fields'}{$fieldname} = {
            label => $CustomFieldNames->{$fieldname}[0] || '',
            value => $field->{$fieldname},
            type  => 'checkbox',
            sectionname   => 'other',
            displaylookup => { 1 => 'Yes', 0 => 'No' },
            readonly      => ( $Data->{'clientValues'}{'authLevel'} < $Defs::LEVEL_NATIONAL and $Data->{'SystemConfig'}{"NationalOnly_$fieldname"} ? 1 : 0 ),
        };
    }

    my $resultHTML = '';
    my $fieldperms = $Data->{'Permissions'};

    my $memperm = ProcessPermissions($fieldperms, \%FieldDefinitions, 'Person',);

    if($Data->{'SystemConfig'}{'AllowDeRegister'}) {
        $memperm->{'intDeRegister'}=1;
    }

    my %configchanges = ();
    if ( $Data->{'SystemConfig'}{'PersonFormReLayout'} ) {
        %configchanges = eval( $Data->{'SystemConfig'}{'PersonFormReLayout'} );
    }

    return \%FieldDefinitions if $Data->{'RegoForm'};
    return ( \%FieldDefinitions, $memperm ) if $returndata;
    my $processed = 0;
    my $header ='';
    my $tabs = '';
    ( $resultHTML, $processed, $header, $tabs ) = handleHTMLForm( \%FieldDefinitions, $memperm, $option, '', $Data->{'db'}, \%configchanges );

    if ($option ne 'display') {
        $resultHTML .= '';
    }
$tabs = '
<div class="new_tabs_wrap">
<ul class="new_tabs">
  '.$tabs.'
</ul>
	<span class="showallwrap"><a href="#showall" class="showall">Show All</a></span>
</div>
								';
my $person_photo = qq[
        <div class="person-edit-info">
<div class="photo">$photolink</div>
        <span class="button-small mobile-button"><a href="?client='.$client.'&amp;a=P_PH_d">Add/Edit Photo</a></span>
        <h4>Documents</h4>
        <span class="button-small generic-button"><a href="?client='.$client.'&amp;a=DOC_L">Add Document</a></span>
      </div>
];
$person_photo = '' if($option eq 'add');
$tabs = '' if($option eq 'add');
	$resultHTML =qq[
 $tabs 
$person_photo
      <div class="person-edit-form">$resultHTML</div><style type="text/css">.pageHeading{font-size:48px;font-family:"DINMedium",sans-serif;letter-spacing:-2px;margin:40px 0;}.ad_heading{margin: 36px 0 0 0;}</style>] if!$processed;
    $resultHTML = qq[<p>$Data->{'PersonClrdOut'}</p> $resultHTML] if $Data->{'PersonClrdOut'};
    $option = 'display' if $processed;
    my $chgoptions = '';
    my $title = ( !$field->{strLocalFirstname} and !$field->{strLocalSurname} ) ? "Add New $Data->{'LevelNames'}{$Defs::LEVEL_PERSON}" : "$field->{strLocalFirstname} $field->{strLocalSurname}";
    if ( $option eq 'display' ) {

        $chgoptions .= qq[<a href="$Data->{'target'}?client=$client&amp;a=P_DEL"  onclick="return confirm('Are you sure you want to Delete this $Data->{'LevelNames'}{$Defs::LEVEL_PERSON}');"><img src="images/delete_icon.gif" border="0" alt="Delete $Data->{'LevelNames'}{$Defs::LEVEL_PERSON}" title="Delete $Data->{'LevelNames'}{$Defs::LEVEL_PERSON}"></a>]
          if ( allowedAction( $Data, 'm_d' ) and $Data->{'SystemConfig'}{'AllowPersonDelete'} );

        $chgoptions = '' if $Data->{'SystemConfig'}{'LockPerson'};

        $chgoptions = qq[<div class="changeoptions">$chgoptions</div>] if $chgoptions;

        $resultHTML = $resultHTML;

        my @taboptions = ();
        my @tabdata    = ();
        my ( $clubStatus, $clubs, undef) = showClubTeams( $Data, $personID );
        $clubs ||= '';
        push @taboptions, [ 'memclubs_dat', $Data->{'LevelNames'}{ $Defs::LEVEL_CLUB . "_P" } ] if $clubs;
        push @tabdata, qq[<div id="memclubs_dat">$clubs</div>] if $clubs;

        if ( $clubStatus == $Defs::RECSTATUS_INACTIVE and $Data->{'clientValues'}{'authLevel'} == $Defs::LEVEL_CLUB ) {
            $chgoptions = '';
            $title .= " - <b><i>Restricted Access</i></b> ";
        }

        $title = $chgoptions . $title;
        $title .= " - ON PERMIT " if $Data->{'PersonOnPermit'};

        my $otherassocs = checkOtherAssocs( $Data, $personID ) || '';
        if ($otherassocs) {
            push @tabdata, qq[<div id="otherassocs_dat">$otherassocs</div>];
            push @taboptions, [ 'otherassocs_dat', 'Associations' ];
        }
        my $clearancehistory = clearanceHistory( $Data, $personID ) || '';
        if ($clearancehistory) {
            push @tabdata, qq[<div id="clearancehistory_dat">$clearancehistory</div>];
            my $txt_Clr = $Data->{'SystemConfig'}{'txtCLR'} || 'Clearance';
            push @taboptions, [ 'clearancehistory_dat', "$txt_Clr History" ];
        }

        my $tabstr    = '';
        my $tabheader = '';

        #for my $i (0 .. $#taboptions)	{
        #	#$tabstr .= qq{<h3><a href = "#">$taboptions[$i][1]</a></h3>};
        #	$tabheader.= qq{<li><a href = "#$taboptions[$i][0]">$taboptions[$i][1]</a></li>};
        #	$tabstr .= $tabdata[$i] ? $tabdata[$i] : '<div></div>';
        #}
        $tabheader = qq[<ul>$tabheader</ul>] if $tabheader;
	if ($tabstr) {
            $Data->{'AddToPage'}->add( 'js_bottom', 'inline', "jQuery('#persontabs').tabs();" );

            $resultHTML .= qq[
				<div class = "small-widget-text">
				<div id="persontabs" style="float:left;clear:right;width:99%;">
					$tabheader
					$tabstr
				</div><!-- end persontabs -->
				</div>
			];
        }

    }
    return ( $resultHTML, $title );
}

sub loadPersonDetails {
    my ( $db, $id) = @_;
    return {} if !$id;

    my $statement = qq[
	SELECT 
		tblPerson.*, 
		DATE_FORMAT(dtPassportExpiry,'%d/%m/%Y') AS dtPassportExpiry, 
		DATE_FORMAT(dtDOB,'%d/%m/%Y') AS dtDOB, 
		dtDOB AS dtDOB_RAW, 
		DATE_FORMAT(dtPoliceCheck,'%d/%m/%Y') AS dtPoliceCheck, 
		DATE_FORMAT(dtPoliceCheckExp,'%d/%m/%Y') AS dtPoliceCheckExp, 
		DATE_FORMAT(dtNatCustomDt1,'%d/%m/%Y') AS dtNatCustomDt1, 
		DATE_FORMAT(dtNatCustomDt2,'%d/%m/%Y') AS dtNatCustomDt2, 
		DATE_FORMAT(dtNatCustomDt3,'%d/%m/%Y') AS dtNatCustomDt3, 
		DATE_FORMAT(dtNatCustomDt4,'%d/%m/%Y') AS dtNatCustomDt4, 
		DATE_FORMAT(dtNatCustomDt5,'%d/%m/%Y') AS dtNatCustomDt5, 
		MN.strNotes
		FROM 
			tblPerson 
			LEFT JOIN tblPersonNotes as MN ON (
				MN.intPersonID = tblPerson.intPersonID
			)
    	WHERE 
		    tblPerson.intPersonID = ?
	];

    my $query = $db->prepare($statement);
    $query->execute( $id);
    my $field = $query->fetchrow_hashref();
    if ($field) {
        if ( !defined $field->{dtDOB} ) {
            $field->{dtDOB_year} = $field->{dtDOB_month} = $field->{dtDOB_day} = $field->{dtDOB} = '';
        }
        else {
            ( $field->{dtDOB_year}, $field->{dtDOB_month}, $field->{dtDOB_day} ) = $field->{dtDOB_RAW} =~ /(\d\d\d\d)-(\d\d)-(\d\d)/;
        }
    }

    $query->finish;

    foreach my $key ( keys %{$field} ) {
        if ( !defined $field->{$key} ) { $field->{$key} = ''; }
    }
    return $field;
}

sub postPersonUpdate {
    my ( $id, $params, $action, $Data, $db, $personID, $fields ) = @_;

    $personID ||= 0;
    $id ||= $personID;
    return ( 0, undef ) if !$db;

    my $assocID = $Data->{'clientValues'}{'assocID'} || 0;
    $Data->{'cache'}->delete( 'swm', "PersonObj-$id-$assocID" ) if $Data->{'cache'};

    my %types        = ();
    my $assocSeasons = Seasons::getDefaultAssocSeasons($Data);
    $types{'intPlayerStatus'} = $params->{'d_intPlayer'} if exists( $params->{'d_intPlayer'} );
    $types{'intCoachStatus'}  = $params->{'d_intCoach'}  if exists( $params->{'d_intCoach'} );
    $types{'intUmpireStatus'} = $params->{'d_intUmpire'} if exists( $params->{'d_intUmpire'} );
    $types{'intMiscStatus'}  = $params->{'d_intMisc'}  if exists( $params->{'d_intMisc'} );
    $types{'intVolunteerStatus'}  = $params->{'d_intVolunteer'}  if exists( $params->{'d_intVolunteer'} );

    my $genAgeGroup ||= new GenAgeGroup( $Data->{'db'}, $Data->{'Realm'}, $Data->{'RealmSubType'}, $Data->{'clientValues'}{'assocID'} );
    my $st = qq[
		SELECT DATE_FORMAT(dtDOB, "%Y%m%d"), intGender
		FROM tblPerson
		WHERE intPersonID = ?
	];
    my $qry = $db->prepare($st);
    $qry->execute($id);
    my ( $DOBAgeGroup, $Gender ) = $qry->fetchrow_array();
    $DOBAgeGroup ||= '';
    $Gender      ||= 0;
    my $ageGroupID = $genAgeGroup->getAgeGroup( $Gender, $DOBAgeGroup ) || 0;

    updatePersonNotes( $db, $id, $params );

    if ( $action eq 'add' ) {
        $types{'intMSRecStatus'} = 1;
        if ($id) {

        }
        getAutoPersonNum( $Data, undef, $id, $Data->{'clientValues'}{'assocID'} );
        #Seasons::insertPersonSeasonRecord( $Data, $id, $assocSeasons->{'newRegoSeasonID'}, $Data->{'clientValues'}{'assocID'}, 0, $ageGroupID, \%types ) if ($id);
        if ( $params->{'isDuplicate'} ) {
            my $st = qq[
                UPDATE tblPerson SET intSystemStatus=$Defs::PERSONSTATUS_POSSIBLE_DUPLICATE 
                WHERE intPersonID=$id
            ];
            $db->do($st);
            return ( 0, DuplicateExplanation($Data) );
        }
        else {
            my $cl = setClient( $Data->{'clientValues'} ) || '';
            my %cv = getClient($cl);
            $cv{'personID'}     = $id;
            $cv{'currentLevel'} = $Defs::LEVEL_PERSON;
            my $clm = setClient( \%cv );

            return (
                0, qq[
                <div class="OKmsg"> $Data->{'LevelNames'}{$Defs::LEVEL_PERSON} Added Successfully</div><br>
                <a href="$Data->{'target'}?client=$clm&amp;a=P_HOME">Display Details for $params->{'d_strLocalFirstname'} $params->{'d_strLocalSurname'}</a><br><br>
                <b>or</b><br><br>
                <a href="$Data->{'target'}?client=$cl&amp;a=P_A&amp;l=$Defs::LEVEL_PERSON">Add another $Data->{'LevelNames'}{$Defs::LEVEL_PERSON}</a>
                ]
            );

            #</RE>
        }
    }
    else {
        my $status = $params->{'d_strStatus'} || $params->{'strStatus'} || 0;
        if ( $status == 1 ) {
            my $st = qq[UPDATE tblPerson SET intSystemStatus = 1 WHERE intPersonID = $id AND intSystemStatus = 0 LIMIT 1];
            $db->do($st);
        }
        warn("INSERT PRODUCTS");

        ## CHECK IF FIRSTNAME, SURNAME OR DOB HAVE CHANGED
        my $firstname_p = $params->{'d_strLocalFirstname'} || $params->{'strLocalFirstname'} || '';
        my $lastname_p  = $params->{'d_strLocalSurname'}   || $params->{'strLocalSurname'}   || '';
        my $dob_p       = $params->{'d_dtDOB'}        || $params->{'dtDOB'}        || '';
        my $email_p     = $params->{'d_strEmail'}     || $params->{'strEmail'}     || '';

        my $firstname_f = $fields->{'strLocalFirstname'} || '';
        my $lastname_f  = $fields->{'strLocalSurname'}   || '';
        my $dob_f       = $fields->{'dtDOB'}        || '';
        my $email_f     = $fields->{'strEmail'}     || '';

        my ( $d, $m, $y ) = split /\//, $dob_f;
        $dob_f = qq[$y-$m-$d];
        my ( $dob_p_y, $dob_p_m, $dob_p_d ) = split /-/, $dob_p if ($dob_p);
        $dob_p = sprintf( "%02d-%02d-%02d", $dob_p_y, $dob_p_m, $dob_p_d ) if ($dob_p);

        my $dupl_check = 0;
        $dupl_check = 1 if ( $firstname_p and $firstname_p ne $firstname_f );
        $dupl_check = 1 if ( $lastname_p  and $lastname_p ne $lastname_f );
        $dupl_check = 1 if ( $dob_p       and $dob_p ne $dob_f );

        if ( $dupl_check == 1 ) {
            my $st = qq[UPDATE tblPerson SET intSystemStatus = 2 WHERE intPersonID = $id LIMIT 1];
            $db->do($st);
        }

    }

    return ( 1, '' );
}

sub prePersonAdd {
    my ( $params, $action, $Data, $db, $typeofDuplCheck ) = @_;

    if ($Data->{'SystemConfig'}{'checkPrimaryClub'} or $Data->{'SystemConfig'}{'DuplicatePrevention'}) {

        my %newPerson = (
            firstname => $params->{'d_strLocalFirstname'},
            surname   => $params->{'d_strLocalSurname'},
            dob       => $params->{'d_dtDOB'},
        );
        
        my $resultHTML = '';

        #At some stage PrimaryClub and DuplicatePrevention may/should become intertwined.
        #Currently, PrimaryClub workings haven't been finalised; nor has primary club been set for each person.

        if ($Data->{'SystemConfig'}{'checkPrimaryClub'}) {
            my $format = 1; #This should be set to 2 when the TransferLink part is working...mick

            $resultHTML = checkPrimaryClub($Data, \%newPerson, $format); 
        }

        if (!$resultHTML) {
            if ($Data->{'SystemConfig'}{'DuplicatePrevention'}) {
                my $prefix = (exists $params->{'formID'} and $params->{'formID'}) ? 'yn' : 'd_int';
 
                my @personTypes = ($prefix.'Player', $prefix.'Coach', $prefix.'MatchOfficial', $prefix.'Official', $prefix.' Misc', $prefix.' Volunteer');

                my @registeringAs = ();

                foreach my $personType (@personTypes) {
                    push @registeringAs, $personType if (exists $params->{$personType} and $params->{$personType});
                }

                $resultHTML = duplicate_prevention($Data, \%newPerson, \@registeringAs);
            }
        }

        return (0, $resultHTML) if $resultHTML;
    }

    #This Function checks for duplicates
    my $realmID = $Data->{'Realm'} || 0;

    $typeofDuplCheck ||= '';

    my $duplcheck = $typeofDuplCheck || Duplicates::isCheckDupl($Data) || '';

    if ($duplcheck) {

        #Check for Duplicates
        my @FieldsToCheck = Duplicates::getDuplFields($Data);
        return ( 1, '' ) if !@FieldsToCheck;

        my $st        = q{};
        my $wherestr  = q{};
        my $joinCheck = q{};

        my ( @st_fields, @where_fields, @joinCheck_fields );

        if ( $params->{'ID'} ) {
            $wherestr .= 'AND tblPerson.intPersonID <> ?';
            push @where_fields, $params->{'ID'};
        }

        for my $i (@FieldsToCheck) {
            if ( $i =~ /^dt/ and $Data->{'RegoFormID'} ) {

                $wherestr .= qq[ AND $i=COALESCE(STR_TO_DATE(?,'%d/%m/%Y'), STR_TO_DATE(?, '%Y-%m-%d'))];

                my $date = $params->{ 'd_' . $i };
                push @where_fields, $date, $date;
            }
            else {
                $wherestr .= " AND  $i = ?";
                push @where_fields, $params->{ 'd_' . $i };
            }
        }

        if ( $params->{'ID_IN'} ) {
            $wherestr     = 'AND tblPerson.intPersonID = ?';
            @where_fields = ( $params->{'ID_IN'} );
        }

        if ( $duplcheck eq 'realm' ) {
            $st = qq[
				SELECT tblPerson.intPersonID
				FROM tblPerson
                WHERE  tblPerson.intRealmID = ? AND tblPerson.intSystemStatus <> ?
					$wherestr
                ORDER BY tblPerson.intSystemStatus
				LIMIT 1
			];
            @st_fields = (@joinCheck_fields, $realmID, $Defs::PERSONSTATUS_DELETED, @where_fields,);
        }
        my $q = $db->prepare($st);
        $q->execute(@st_fields);
        my $dupl = $q->fetchrow_array;
        $q->finish();
        $dupl ||= 0;
        $params->{'isDuplicate'} = $dupl;

    }
    return ( 1, '' );
}

sub DuplicateExplanation {
    my ($Data) = @_;

    my $msg = '<div class="warningmsg">Person is Possible Duplicate</div>';
    my $currentLevel = $Data->{'clientValues'}{'currentLevel'} || $Defs::LEVEL_NONE;

    my $client = setClient( $Data->{'clientValues'} ) || '';
    my $link = "$Data->{'target'}?client=$client&amp;a=DUPL_L";

    if ( $currentLevel == $Defs::LEVEL_ASSOC ) {
        $msg .= qq[
			<p>The $Data->{'LevelNames'}{$Defs::LEVEL_PERSON} you have added possibly duplicates another record that already exists in this system.</p>
			<p>This $Data->{'LevelNames'}{$Defs::LEVEL_PERSON} <b>has</b> been temporarily added but their details will not be available.</p>
			<p>You should resolve this and any other duplicates as soon as possible by proceeding to the <b>Duplicate Resolution</b> section.</p>
			<p><a href="$link">Resolve Duplicates</a></p>
		];
    }
    elsif ( $currentLevel < $Defs::LEVEL_ASSOC ) {
        $msg .= qq[
			<p>The $Data->{'LevelNames'}{$Defs::LEVEL_PERSON} you have added possibly duplicates another record that already exists in this system.  </p>
			<p>This $Data->{'LevelNames'}{$Defs::LEVEL_PERSON} <b>has</b> been temporarily added but their details will not be available. They will remain this way until your $Data->{'LevelNames'}{$Defs::LEVEL_ASSOC} has resolved this issue.</p>
		];
    }
    elsif ( $currentLevel > $Defs::LEVEL_ASSOC ) {
        $msg .= qq[
			<p>The $Data->{'LevelNames'}{$Defs::LEVEL_PERSON} you have added possibly duplicates another record that already exists in this system.  </p>
			<p>This $Data->{'LevelNames'}{$Defs::LEVEL_PERSON} <b>has</b> been temporarily added but their details will not be available. </p>
			<p>You need to proceed to the $Data->{'LevelNames'}{$Defs::LEVEL_ASSOC} and choose the <b>Duplicate Resolution</b> option to resolve this issue.</p>
		];
    }
    return $msg;
}

sub getAutoPersonNum {
    my ( $Data, $genCode, $personID, $assocID ) = @_;

    if ( $Data->{'SystemConfig'}{'GenPersonNo'} ) {
        my $num_field = $Data->{'SystemConfig'}{'GenNumField'} || 'strNationalNum';
        my $CreateCodes = 0;
        if ( exists $Data->{'SystemConfig'}{'GenNumAssocIn'} ) {
            my @assocs = split /\|/, $Data->{'SystemConfig'}{'GenNumAssocIn'};
            for my $i (@assocs) { $CreateCodes = 1 if $i == $assocID; }
        }
        else { $CreateCodes = 1; }
        if ($CreateCodes) {
            $genCode ||= new GenCode( $Data->{'db'}, $Data->{'Realm'} );
            my $num = $genCode->getNumber( '', '', $num_field ) || '';
            if ($num) {
                my $st = qq[
						UPDATE tblPerson SET $num_field = ?
						WHERE intPersonID = ?
				];
                $Data->{'db'}->do( $st, undef, $num, $personID );
                return $num;
            }
        }
    }
    return undef;
}

sub showClubTeams {
    my ( $Data, $personID ) = @_;

    my $aID = $Data->{'clientValues'}{'assocID'} || 0;    #Current Association
                                                          #Check and Display what other assocs this person may be in
    my $st = qq[
		SELECT DISTINCT 
            tblClub.intClubID, 
            tblClub.strName, 
            MC.intGradeID, 
            MC.strContractYear, 
            MC.strContractNo, 
            MC.intPrimaryClub, 
            G.strGradeName, 
            MC.intStatus, 
            MC.intPermit, 
            tblClub.strStatus
		FROM tblClub 
			INNER JOIN tblPerson_Clubs AS MC ON (tblClub.intClubID=MC.intClubID)
			INNER JOIN tblAssoc_Clubs AS AC ON (tblClub.intClubID=AC.intClubID)
			LEFT JOIN tblClubGrades AS G ON (G.intGradeID=MC.intGradeID)
		WHERE MC.intPersonID=$personID
			AND AC.intAssocID = $aID
			AND AC.strStatus <> $Defs::RECSTATUS_DELETED
			AND MC.intStatus <> $Defs::RECSTATUS_DELETED
		ORDER BY strName, intStatus DESC, intPermit ASC
	];
    my $query = $Data->{'db'}->prepare($st);
    $query->execute;

    my $body       = '';
    my $clubs      = '';
    my $clubStatus = '';
    my $cnt        = 0;
    my %hasClub    = ();
    while ( my $dref = $query->fetchrow_hashref() ) {
        ## GET THE NAME OF THE GRADE FOR THE PERSON IF ALLOW CLUB GRADES IS ENABLED IN SYS CONFIG
        my $gradeName = '&nbsp;';
        next if exists $hasClub{ $dref->{intClubID} };
        $hasClub{ $dref->{intClubID} } = 1;
        if ( $Data->{'SystemConfig'}{'AllowClubGrades'} ) {
            $gradeName = qq[($dref->{'strGradeDesc'})] if $dref->{'strGradeDesc'};
        }
        my $status = ( $dref->{intStatus} == $Defs::RECSTATUS_INACTIVE ) ? qq[<i>(Inactive)</i>] : '&nbsp;';
        my $permit = ( $dref->{intPermit} == 1 ) ? qq[<i>On Permit</i>] : '&nbsp;';

        my $primaryClub = ( $dref->{'intPrimaryClub'} )   ? qq{[Primary Club]} : '&nbsp;';
        my $class       = $cnt % 2 == 0                   ? 'rowshade'         : '';
        my $deleted     = ( $dref->{strStatus} == -1 ) ? qq[ (Deleted)]     : '';
        $clubs .= qq[
			<tr>
				<td class="$class">$dref->{'strName'}$deleted</td>
				<td class="$class">$gradeName</td>
				<td class="$class">$primaryClub</td>
				<td class="$class">$status&nbsp;$permit</td>
			</tr>
		];
        if ( $Data->{'clientValues'}{'clubID'} and $Data->{'clientValues'}{'clubID'} != $Defs::INVALID_ID and $Data->{'clientValues'}{'clubID'} == $dref->{intClubID} ) {
            $clubStatus = $dref->{intStatus};
        }
        $cnt++;
    }
    my $editclubsbutton = '';
    my $client          = setClient( $Data->{'clientValues'} ) || '';
    if ( $Data->{'clientValues'}{'authLevel'} >= $Defs::LEVEL_ASSOC and !$Data->{'SystemConfig'}{'NoClubs'} and allowedAction( $Data, 'mc_e' ) ) {
        $editclubsbutton = qq[
			<form action="$Data->{'target'}" method="POST" >
				<input type="hidden" name="a" value="P_CLB_">
				<input type="hidden" name="client" value="$client">
				<input type="submit" class="button proceed-button" value="Edit $Data->{'LevelNames'}{$Defs::LEVEL_CLUB."_P"}">
			</form>
		];
    }
    $editclubsbutton = '' if $Data->{'SystemConfig'}{'LockClub'};
    if ( !$Data->{'SystemConfig'}{'NoClubs'} ) {
        $clubs ||= '';
        $clubs = qq[
			<table class="listTable" style="width:100%;">$clubs</table>
				<br>
				$editclubsbutton
		];
    }

    return ( $clubStatus, $clubs, '');
}

sub checkOtherAssocs {
    my ( $Data, $personID ) = @_;

    my $aID = $Data->{'clientValues'}{'assocID'} || 0;    #Current Association
                                                          #Check and Display what other assocs this person may be in

    my $st = qq[
		SELECT strName, MA.strStatus
		FROM tblAssoc INNER JOIN tblPerson_Associations AS MA ON (tblAssoc.intAssocID=MA.intAssocID)
		WHERE intPersonID = ?
			AND tblAssoc.intAssocID <> ?
			AND MA.strStatus <> $Defs::RECSTATUS_DELETED
		ORDER BY strName
	];
    my $query = $Data->{'db'}->prepare($st);
    $query->execute(
                     $personID,
                     $aID,
    );
    my $body = '';
    while ( my $dref = $query->fetchrow_hashref() ) {
        my $act = $dref->{'strStatus'} == $Defs::RECSTATUS_ACTIVE ? 'Active' : 'Inactive';

        $body .= qq[$dref->{'strName'} <i>($act)</i><br>\n];
    }
    if ($body) {
        $body = qq[
			<div class="sectionheader">Other $Data->{'LevelNames'}{$Defs::LEVEL_ASSOC.'_P'}</div>
				$body
		];
    }

    return $body;
}

sub delete_person {
    my ( $Data, $personID ) = @_;

    my $aID = $Data->{'clientValues'}{'assocID'} || 0;    #Current Association
    return '' if ( !( allowedAction( $Data, 'm_d' ) and $Data->{'SystemConfig'}{'AllowPersonDelete'} ) );
######## NEEDS THINK ABOUT WR WARREN warren wsc

    my $st = qq[UPDATE tblPerson_Associations SET strStatus=$Defs::RECSTATUS_DELETED WHERE intPersonID=$personID AND intAssocID=$aID];
    $Data->{'db'}->do($st);
    $Data->{'clientValues'}{'personID'} = $Defs::INVALID_ID;
    {
        if ( $Data->{'clientValues'}{'teamID'} and $Data->{'clientValues'}{'teamID'} != $Defs::INVALID_ID ) {
            $Data->{'clientValues'}{'currentLevel'} = $Defs::LEVEL_TEAM;
        }
        elsif ( $Data->{'clientValues'}{'clubID'} and $Data->{'clientValues'}{'clubID'} != $Defs::INVALID_ID ) {
            $Data->{'clientValues'}{'currentLevel'} = $Defs::LEVEL_CLUB;
        }
        else {
            $Data->{'clientValues'}{'currentLevel'} = $Defs::LEVEL_ASSOC;
        }
        $Data->{'clientValues'}{'currentLevel'} = $Defs::INVALID_ID if $Data->{'clientValues'}{'authLevel'} < $Data->{'clientValues'}{'currentLevel'};
    }

    return ( qq[<div class="OKmsg">$Data->{'LevelNames'}{$Defs::LEVEL_PERSON} deleted successfully</div>], "Delete $Data->{'LevelNames'}{$Defs::LEVEL_PERSON}" );

}

sub PersonDupl {
    my ( $action, $Data, $personID ) = @_;

    $personID ||= 0;
    return '' if !$personID;
    return '' if !Duplicates::isCheckDupl($Data);

    if ( $action eq 'P_DUP_S' ) {
        my $st = qq[
			UPDATE tblPerson
			SET intSystemStatus = $Defs::PERSONSTATUS_POSSIBLE_DUPLICATE
			WHERE intPersonID = $personID
			LIMIT 1
		];
        my $query = $Data->{'db'}->prepare($st);
        $query->execute;
        my $msg = qq[
			<p class="OKmsg">$Data->{'LevelNames'}{$Defs::LEVEL_PERSON} has been marked as a duplicate</p>
		];
        if ( $Data->{'clientValues'}{'authLevel'} == $Defs::LEVEL_ASSOC ) {
            my $client = setClient( $Data->{'clientValues'} ) || '';
            my $dupllink = "$Data->{'target'}?client=$client&amp;a=DUPL_L";
            $msg .= qq[<p>To resolve this duplicate click <a href="$dupllink">Resolve Duplicates</a>.</p>];
        }
        auditLog( $personID, $Data, 'Mark as Duplicates', 'Duplicates' );
        return ( $msg, "$Data->{'LevelNames'}{$Defs::LEVEL_PERSON} marked as a duplicate" );
    }
    else {
        my $client = setClient( $Data->{'clientValues'} ) || '';
        my $st = qq[SELECT * FROM tblPerson WHERE intPersonID = $personID];
        my $query = $Data->{'db'}->prepare($st);
        $query->execute;
        my $dref = $query->fetchrow_hashref();

        my $msg = qq[
			<form action="$Data->{'target'}" method="POST" style="float:left;" onsubmit="document.getElementById('btnsubmit').disabled=true;return true;">
				<p>If you believe the $Data->{'LevelNames'}{$Defs::LEVEL_PERSON} named below is a possible duplicate, click the <b>'Mark as Duplicate'</b> button.  </p>

		<p>This will mark this $Data->{'LevelNames'}{$Defs::LEVEL_PERSON} as a duplicate for your $Data->{'LevelNames'}{$Defs::LEVEL_ASSOC} to verify and resolve.</p>
			<p> <b>$dref->{strLocalFirstname} $dref->{strLocalSurname}</b></p>
			<p>
				<span class="warningmsg">NOTE: Only mark the duplicate $Data->{'LevelNames'}{$Defs::LEVEL_PERSON}, not the $Data->{'LevelNames'}{$Defs::LEVEL_PERSON} you believe may be the original</span>.</p><br><br>
				<input type="hidden" name="a" value="P_DUP_S">
				<input type="hidden" name="client" value="$client">
				<input type="submit" value="Mark as Duplicate" id="btnsubmit" name="btnsubmit"  class="button proceed-button">
			</form>
		];
        return ( $msg, 'Mark as Duplicate' );
    }
}

sub check_valid_date {
    my ($date) = @_;
    my ( $d, $m, $y ) = split /\//, $date;
    use Date::Calc qw(check_date);
    return check_date( $y, $m, $d );
}

sub _fix_date {
    my ($date) = @_;
    return '' if !$date;
    my ( $dd, $mm, $yyyy ) = $date =~ m:(\d+)/(\d+)/(\d+):;
    if ( !$dd or !$mm or !$yyyy ) { return ''; }
    if ( $yyyy < 100 ) { $yyyy += 2000; }
    return "$yyyy-$mm-$dd";
}


sub showSeasonSummary {

    my ( $Data, $personID ) = @_;

    my $body = '';
    my ( $memseason_vals, $memseasons ) = listPersonSeasons( $Data, $personID );
    my $season_Name = $Data->{'SystemConfig'}{'txtSeason'} || 'Season';
    if ($memseasons) {
        my %Title = ();
        $Title{1} = "$Data->{'LevelNames'}{$Defs::LEVEL_ASSOC} Summary";
        $Title{2} = "$Data->{'LevelNames'}{$Defs::LEVEL_CLUB} Summary";
        $Title{3} = "Full $season_Name Summary";
        my $count = 1;
        for my $section ( @{$memseason_vals} ) {
            my $title = $Title{$count};
            $count++;
            $body .= qq[<div class="sectionheader">$title</div>$section];
        }
    }
    return ( $body, 'Season Summary' );
}


1;
