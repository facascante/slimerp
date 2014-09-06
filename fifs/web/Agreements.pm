#
# $Header: svn://svn/SWM/trunk/web/Agreements.pm 8251 2013-04-08 09:00:53Z rlee $
#

package Agreements;
require Exporter;
@ISA = qw(Exporter);
@EXPORT=qw(handleAgreements);
@EXPORT_OK=qw(handleAgreements);

use strict;
use Reg_common;
use HTMLForm;
use FormHelpers;

use ServicesContacts;
use CGI qw(param unescape escape);

sub handleAgreements    {
	my ($action, $Data, $entityTypeID, $entityID)=@_;

	my $resultHTML='';
	my $title='';
	if ($action =~/^AGREE_L/) {
		($resultHTML,$title)=listAgreements(
			$Data, 
			$entityTypeID, 
			$entityID
		);
	}
    if ($action =~/^AGREE_V/) {
        my $q=new CGI;
        my %params=$q->Vars();

        my $agreementID= $params{'agID'} || 0;
		($resultHTML,$title)=viewAgreementDetails(
			$Data, 
			$entityTypeID, 
			$entityID,
            $agreementID
		);
	}

    my $scMenu = getServicesContactsMenu($Data, $entityTypeID, $entityID, $Defs::SC_MENU_SHORT, $Defs::SC_MENU_CURRENT_OPTION_AGREEMENTS);
	
		$resultHTML  = $scMenu . $resultHTML;
	return ($resultHTML,$title);
}

sub listAgreements  {

    my ($Data, $entityTypeID, $entityID) = @_;

     my $client=setClient($Data->{'clientValues'}) || '';
    my $st= qq[
        SELECT
            A.intAgreementID,
            A.strName as AgreementName,
            DATE_FORMAT(AE.dtAgreed,'%d/%m/%Y') AS DateAgreed,
            strAgreedBy as AgreedBy
 		FROM tblAgreements as A
                LEFT JOIN tblAgreementsEntity as AE ON (
                    AE.intAgreementID = A.intAgreementID
				    AND intEntityTypeID = $entityTypeID
				    AND intEntityID = $entityID
                )
                INNER JOIN tblTempNodeStructure as T ON (
                    T.intAssocID = $Data->{'clientValues'}{'assocID'}
                )
			WHERE 
                intEntityFor = $entityTypeID
                AND A.intRealmID = $Data->{'Realm'}
                AND A.intSubRealmID IN (0, $Data->{'RealmSubType'})
                AND A.intCountryID IN (0, int100_ID)
                AND A.intStateID IN (0, int30_ID)
                AND A.intRegionID IN (0, int20_ID)
                AND A.intZoneID IN (0, int10_ID)
                AND A.intAssocID IN (0, $Data->{'clientValues'}{'assocID'})
            ORDER BY
                AE.intAgreementID DESC,
                dtAgreed DESC
		];
    
		my $qry= $Data->{'db'}->prepare($st);
		$qry->execute();

        my $body = qq[
            <p>Your organisation has indicated its acceptance of the following agreements. <br><br> Agreements are placed here from time to time and use of your database will in some cases be suspended where an urgent agreement needs to be acknowledged.<br><br>  
            Where an agreement below is showing as <span style="color:red;">Not Yet Agreed To</span>, you should click through and agree to this now.   You will need to have completed contact details for an agreement to be acknowledged.</p><br>
            <table class="listTable" width="80%">
                <tr>
                    <th>Agreement Name</th>
                    <th>Date Agreed</th>
                    <th>Agreed By</th>
                </tr>
        ];

        my $count=0;
        while (my $dref = $qry->fetchrow_hashref()) {
            $count++;
            my $msg = (! $dref->{AgreedBy}) ? qq[<span class="warningmsg">Not yet agreed to</span>] : '';
            $body .= qq[
                <tr>
                    <td><a href="$Data->{'target'}?client=$client&amp;a=AGREE_V&amp;agID=$dref->{intAgreementID}">$dref->{AgreementName}</a></td>
                    <td>$msg$dref->{DateAgreed}</td>
                    <td>$msg$dref->{AgreedBy}</td>
                </tr>
            ];
        }
		$qry->finish;

        $body .= qq[</table>];
        $body = qq[<div class="warningmsg">No agreements have been found</div>] if ! $count;
        return ($body, 'List Agreements');
}


sub viewAgreementDetails    {
	my (
		$Data,
		$entityTypeID, 
		$entityID,
        $agreementID
	) = @_;


	my $field=loadAgreementDetails(
		$Data, 
		$entityTypeID, 
		$entityID,
        $agreementID,
	) || ();

	my $option='display';
    my $action='AGREE_V';
  if($Data->{'clientValues'}{'authLevel'} >= $Defs::LEVEL_CLUB) {
    $option=$field->{'intEntityID'} 
			? 'edit' 
			: 'add';
  }

    my $introText = qq[<p>This agreement requires your acknowledgement.  Please read the agreement and choose an option from the agreed by box below the agreement.<br><b>Note:</b>   if you have not yet completed details for your President, Vice President or Secretary in the Contacts page then you will not be able to acknowledge this agreement.</p><br>];
    if ($field->{'strAgreedBy'})    {
        $option='display';
        $introText = qq[
            <p>The following has been agreed to.</p>
        ];

    }
    my $assocID = $Data->{'clientValues'}{'assocID'} || 0;
    my $clubID = $Data->{'clientValues'}{'clubID'} || 0;
    my $teamID = $Data->{'clientValues'}{'teamID'} || 0;

    my $realmID = $Data->{'Realm'} || 0;
    my $realmSubTypeID = $Data->{'RealmSubType'} || 0;

    $clubID = 0 if (! $clubID or $clubID == $Defs::INVALID_ID);
    $teamID = 0 if (! $teamID or $teamID == $Defs::INVALID_ID);

	if(
		$Data->{'DataAccess'}{$Data->{'clientValues'}{'currentLevel'}}{getID($Data->{'clientValues'})} < $Defs::DATA_ACCESS_FULL
	)	{
		#$option = 'display';
	}
  my $client=setClient($Data->{'clientValues'}) || '';

    my ($assocName, $clubName)=('','');
    if ($field->{'AgreementText'} =~ /CLUBNAME|ASSOCNAME/ and 
        ($assocID or $clubID)) {
        my $st = qq[
            SELECT DISTINCT
                A.strName as AssocName,
                C.strName as ClubName
            FROM 
                tblAssoc as A 
                LEFT JOIN tblAssoc_Clubs as AC ON (
                    AC.intAssocID=A.intAssocID
                    AND AC.intClubID=$clubID
                )
                LEFT JOIN tblClub as C ON (
                    C.intClubID = AC.intClubID
                    AND C.intClubID=$clubID
                )
            WHERE A.intAssocID = $assocID
            LIMIT 1
        ];

        my $query = $Data->{'db'}->prepare($st);
        $query->execute();
        ($assocName, $clubName)=$query->fetchrow_array();
        $query->finish;
    }

    $field->{AgreementText} =~ s/ASSOCNAME/$assocName/g;
    $field->{AgreementText} =~ s/CLUBNAME/$clubName/g;

     my $st_contacts=qq[
        SELECT 
            DISTINCT
            CONCAT(strContactSurname, ', ', strContactFirstname,' (', strRoleName, ')') as Value,
            CONCAT(strContactSurname, ', ', strContactFirstname,' (', strRoleName, ')') as Name
        FROM
            tblContacts as C
            LEFT JOIN tblContactRoles as CR ON (
                C.intContactRoleID = CR.intRoleID
            )
        WHERE 
            C.intRealmID = $Data->{'Realm'}
            AND C.intAssocID = $assocID
            AND C.intClubID = $clubID
            AND C.intTeamID = $teamID
        ORDER BY
            strContactSurname,
            strContactFirstname,
            strRoleName
    ];
    my ($contacts_vals,$contacts_order)=getDBdrop_down_Ref($Data->{'db'},$st_contacts,'');
    
	my %FieldDefinitions = (
		fields=>	{
			AgreementName=> {
				label => 'Agreement Name',
				value => $field->{AgreementName},
				type  => 'textvalue',
			},
			AgreementText=> {
				label => 'Agreement',
				value => $field->{AgreementText},
				type  => 'textvalue',
			},
            strAgreedBy=> {
                label => $field->{strAgreedBy} ? '' : 'Agreed By',
                value => $field->{strAgreedBy},
                type  => 'lookup',
                options => $contacts_vals,
                firstoption => ['',"Select Contact"],
                compulsory=> 1,
            },
            displayAgreedBy =>  {
                label => $field->{strAgreedBy} ? 'Agreed By' : '',
                value => $field->{strAgreedBy},
                type  => 'text',
                readonly => '1',
            },
            DateAgreed=> {
				label => 'Date Agreed',
				value => $field->{DateAgreed},
				type  => 'textvalue',
			},
		},
		order => [qw(
			AgreementName
			AgreementText
            strAgreedBy
            displayAgreedBy
            dtAgreed
		)],
 
		options => {
			labelsuffix => ':',
			hideblank => 1,
			target => $Data->{'target'},
			formname => 'n_form',
			submitlabel => 'Update Agreement Details',
			introtext => $introText,
			addSQL => qq[
				INSERT INTO tblAgreementsEntity(intAgreementID, intEntityTypeID, dtAgreed, intEntityID, --FIELDS--)
				VALUES ($agreementID, $entityTypeID, NOW(), $entityID, --VAL--)
			],
			NoHTML => 1,
			stopAfterAction => 1,

      auditFunction=> \&auditLog,
      auditAddParams => [
        $Data,
        'Add',
        'Agreement'
      ],
      auditEditParams => [
        $agreementID,
        $Data,
        'Update',
        'Agreement'
      ],

			LocaleMakeText => $Data->{'lang'},
		},
    carryfields =>  {
      client => $client,
      a=> $action,
      agID=>$agreementID,
    },

	);
	my $resultHTML='';
    ($resultHTML, undef )=handleHTMLForm(\%FieldDefinitions, undef, $option, '',$Data->{'db'});
	my $title='Contact Details';

	return ($resultHTML,$title);
}

sub loadAgreementDetails	{
	my (
        $Data,
		$entityTypeID, 
		$entityID,
        $agreementID,
	) = @_;
    my $statement=qq[
        SELECT 
            A.strName as AgreementName,
            A.strAgreement as AgreementText,
            AE.strAgreedBy,
            DATE_FORMAT(dtAgreed,'%d/%m/%Y') as DateAgrred
  	    FROM 
            tblAgreements as A
            LEFT JOIN tblAgreementsEntity as AE ON (
                AE.intAgreementID = A.intAgreementID
			    AND intEntityTypeID = $entityTypeID
				AND intEntityID = $entityID
            )
            INNER JOIN tblTempNodeStructure as T ON (
                T.intAssocID = $Data->{'clientValues'}{'assocID'}
            )
			WHERE 
                intEntityFor = $entityTypeID
                AND A.intAgreementID = $agreementID
                AND A.intRealmID = $Data->{'Realm'}
                AND A.intSubRealmID IN (0, $Data->{'RealmSubType'})
                AND A.intCountryID IN (0, int100_ID)
                AND A.intStateID IN (0, int30_ID)
                AND A.intRegionID IN (0, int20_ID)
                AND A.intZoneID IN (0, int10_ID)
                AND A.intAssocID IN (0, $Data->{'clientValues'}{'assocID'})
    ];
    my $query = $Data->{'db'}->prepare($statement);
    $query->execute();
    my $field=$query->fetchrow_hashref();
    $query->finish;
    foreach my $key (keys %{$field})  { if(!defined $field->{$key}) {$field->{$key}='';} }

    return $field;
}
1;
