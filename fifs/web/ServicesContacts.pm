#
# $Header: svn://svn/SWM/trunk/web/ServicesContacts.pm 11245 2014-04-07 05:22:39Z apurcell $
#

package ServicesContacts;
require Exporter;
@ISA = qw(Exporter);
@EXPORT=qw(getServicesContactsMenu checkServicesContacts getServicesContactsEmail get_service_contacts);
@EXPORT_OK=qw(getServicesContactsMenu checkServicesContacts getServicesContactsEmail get_service_contacts);

use strict;
use Readonly;
use Reg_common;
use TTTemplate;
use SQL::Abstract;

# Service Contact Readonly constants

# Package constants
Readonly::Scalar our $CONTACTS_CLEARANCES => 1;
Readonly::Scalar our $CONTACTS_PAYMENTS   => 2;
Readonly::Scalar our $CONTACTS_COMPS      => 3;
Readonly::Scalar our $CONTACTS_REGOS      => 4;
Readonly::Scalar our $CONTACTS_PRIMARY    => 5;

Readonly::Scalar our $CONTACT_METHOD_EMAIL  => 6;
Readonly::Scalar our $CONTACT_METHOD_MOBILE => 7;

# local constants
Readonly::Hash my %CONTACTS_TO_COLUMN_MAP => (
    $CONTACTS_CLEARANCES => 'intFnClearances',
    $CONTACTS_PAYMENTS   => 'intFnPayments',
    $CONTACTS_REGOS      => 'intFnRegistrations',
    $CONTACTS_COMPS      => 'intFnCompAdmin',
    $CONTACTS_PRIMARY    => 'intPrimaryContact',
);

Readonly::Hash my %CONTACT_METHODS_TO_COLUMN_MAP => (
    $CONTACT_METHOD_EMAIL  => 'strContactEmail',
    $CONTACT_METHOD_MOBILE => 'strContactMobile',
);

sub getServicesContactsMenu  {
	my(
		$Data, 
		$entityTypeID, 
		$entityID,
        $menuType, 
        $currentOption
	) = @_;
		
        my $client=setClient($Data->{'clientValues'}) || '';

        my (undef, $checks_ref) = checkServicesContacts($Data, $entityTypeID, $entityID);

				my $compulsory = 0;
				my $l = $Data->{'lang'};
        if ($menuType == $Defs::SC_MENU_SHORT)  {
            my $menu = '';
            if ($entityTypeID == $Defs::LEVEL_ASSOC)   {
								my $icon = getStatusIcon($checks_ref->{'detailsCompleted'}, $checks_ref->{'detailsMandatory'});
								my $linkcontent = $icon.qq[<span class="contserv-text">].$l->txt('Details').qq[</span>];
                my $menuitem = ($currentOption == $Defs::SC_MENU_CURRENT_OPTION_DETAILS)
                    ? qq[<span class="contserv-menuitem-current">$linkcontent</span>]
                    : qq[<a href="$Data->{'target'}?client=$client&amp;a=A_DTE">$linkcontent</a>];
								$menu .= qq[<div class="contserv-menuitem">$menuitem</div>];
            }
            if ($entityTypeID == $Defs::LEVEL_CLUB)   {
								my $icon = getStatusIcon($checks_ref->{'detailsCompleted'}, $checks_ref->{'detailsMandatory'});
								my $linkcontent = $icon.qq[<span class="contserv-text">].$l->txt('Details').qq[</span>];
                my $menuitem = ($currentOption == $Defs::SC_MENU_CURRENT_OPTION_DETAILS)
                    ? qq[<span class="contserv-menuitem-current">$linkcontent</span>]
                    : qq[<a href="$Data->{'target'}?client=$client&amp;a=C_DTE">$linkcontent</a>];
								$menu .= qq[<div class="contserv-menuitem">$menuitem</div>];
            }
            #if ($Data->{'SystemConfig'}{'ServicesContacts_usesContacts'})   {
            {
								my $icon = getStatusIcon($checks_ref->{'contactsCompleted'}, $checks_ref->{'contactsMandatory'});
								my $linkcontent = $icon.qq[<span class="contserv-text">].$l->txt('Contacts').qq[</span>];
                my $menuitem = ($currentOption == $Defs::SC_MENU_CURRENT_OPTION_CONTACTS)
                    ? qq[<span class="contserv-menuitem-current">$linkcontent</span>]
                    : qq[<a href="$Data->{'target'}?client=$client&amp;a=CON_LIST">$linkcontent</a>];
								$menu .= qq[<div class="contserv-menuitem">$menuitem</div>];
            }
            if ($Data->{'SystemConfig'}{'ServicesContacts_usesAgreements'})   {
								my $icon = getStatusIcon($checks_ref->{'agreementsCompleted'}, $checks_ref->{'agreementsMandatory'});
								my $linkcontent = $icon.qq[<span class="contserv-text">].$l->txt('Agreements').qq[</span>];
                my $menuitem = ($currentOption == $Defs::SC_MENU_CURRENT_OPTION_AGREEMENTS)
                    ? qq[<span class="contserv-menuitem-current">$linkcontent</span>]
                    : qq[<a href="$Data->{'target'}?client=$client&amp;a=AGREE_L">$linkcontent</a>];
								$menu .= qq[<div class="contserv-menuitem">$menuitem</div>];
            }
            if ($entityTypeID == $Defs::LEVEL_ASSOC and $Data->{'SystemConfig'}{'AssocServices'})   {
								my $icon = getStatusIcon($checks_ref->{'servicesCompleted'}, $checks_ref->{'servicesMandatory'});
								my $linkcontent = $icon.qq[<span class="contserv-text">].$l->txt('Locator').qq[</span>];
                my $menuitem = ($currentOption == $Defs::SC_MENU_CURRENT_OPTION_SERVICES)
                    ? qq[<span class="contserv-menuitem-current">$linkcontent</span>]
                    : qq[<a href="$Data->{'target'}?client=$client&amp;a=A_SV_DTE">$linkcontent</a>];
								$menu .= qq[<div class="contserv-menuitem">$menuitem</div>];
            }
            if ($entityTypeID == $Defs::LEVEL_CLUB and $Data->{'SystemConfig'}{'AssocClubServices'})   {
								my $icon = getStatusIcon($checks_ref->{'servicesCompleted'}, $checks_ref->{'servicesMandatory'});
								my $linkcontent = $icon.qq[<span class="contserv-text">].$l->txt('Locator').qq[</span>];
                my $menuitem = ($currentOption == $Defs::SC_MENU_CURRENT_OPTION_SERVICES)
                    ? qq[<span class="contserv-menuitem-current">$linkcontent</span>]
                    : qq[<a href="$Data->{'target'}?client=$client&amp;a=A_SV_DTE">$linkcontent</a>];
								$menu .= qq[<div class="contserv-menuitem">$menuitem</div>];
            }
						$menu = qq[<div class="contactsserv-menu">$menu</div>];                
            
            return $menu;
        }
}

sub getStatusIcon	{
	my($ok, $compulsory) = @_;
	if($ok)	{
		return qq[<img src="images/gridcell_tick.png" alt="Completed">];
	}
	else	{
		if($compulsory)	{
			return qq[<img src="images/incomplete.jpg" alt="Incomplete and compulsory">];
		}
		else	{
			return qq[<img src="images/inactive.jpg" alt="Incomplete">];
		}
	}
}


sub checkServicesContacts   {

	my(
		$Data, 
		$entityTypeID, 
		$entityID,
	) = @_;
    my $dbh = $Data->{db};
    
    my $killMsg='';
	
    my $client=setClient($Data->{'clientValues'}) || '';
	my $assocID = $Data->{'clientValues'}{'assocID'} || 0;
	my $clubID = $Data->{'clientValues'}{'clubID'} || 0;
    my $teamID = $Data->{'clientValues'}{'teamID'} || 0;
    $clubID = 0 if (! $clubID or $clubID == $Defs::INVALID_ID);
    $teamID = 0 if (! $teamID or $teamID == $Defs::INVALID_ID);
    my $realmID = $Data->{'Realm'} || 0;
    my %checks=();
    {
        $checks{'servicesCompleted'} = 0;
        $checks{'servicesMandatory'} = 0;
        $checks{'detailsCompleted'} = 0;
        $checks{'detailsMandatory'} = 0;
        $checks{'contactsMandatory'} = 0;
        $checks{'contactsCompleted'} = 0;
        $checks{'agreementsMandatory'} = 0;
        $checks{'agreementsCompleted'} = 0;
    }

    ## DETAILS CHECKING
    my $isNew=0;
	{
        my $table = '';
	    my $idfield = '';
	    if($entityTypeID == $Defs::LEVEL_ASSOC)	{
		    $table = 'tblAssoc';
		    $idfield = 'intAssocID';
	    }
	    elsif($entityTypeID == $Defs::LEVEL_CLUB)	{
		    $table = 'tblClub';
		    $idfield = 'intClubID';
	    }
		my $st = qq[
			SELECT DATE_FORMAT(dtUpdated, "%Y%m%d"), intSPAgreement_NewEntity
			FROM $table
			WHERE $idfield = ?
		];
		my $q= $dbh->prepare($st);
		$q->execute( $entityID );
		my $perm=0;
		$perm =1 if ($entityTypeID == $Defs::LEVEL_ASSOC);
		if ($entityTypeID == $Defs::LEVEL_CLUB and $Data->{'clientValues'}{'assocID'} and $Data->{'clientValues'}{'assocID'} > 0)	{
			my $st_perm = qq[
			SELECT 
				strValue
			FROM
				tblConfig
			WHERE
				intEntityID=$Data->{'clientValues'}{'assocID'}
				AND strPerm = 'c_c_e'
				AND intLevelID = 5
			LIMIT 1
			];
			my $q_perm= $dbh->prepare($st_perm);
			$q_perm->execute();
			$perm = $q_perm->fetchrow_array() || 0;
		}
		my $detail_date = '';
		($detail_date, $isNew) = $q->fetchrow_array();
		$q->finish;
        $checks{'detailsMandatory'} = 1 if ($Data->{'clientValues'}{'authLevel'} == $Defs::LEVEL_CLUB and $Data->{'SystemConfig'}{'ServicesContacts_ClubDetailsMandatory'} and $Data->{'clientValues'}{'currentLevel'} == $Defs::LEVEL_CLUB);
        $checks{'detailsMandatory'} = 1 if ($Data->{'clientValues'}{'authLevel'} == $Defs::LEVEL_ASSOC and $Data->{'SystemConfig'}{'ServicesContacts_AssocDetailsMandatory'} and $Data->{'clientValues'}{'currentLevel'} == $Defs::LEVEL_ASSOC);
        $checks{'detailsCompleted'} = 1 if (! $Data->{'SystemConfig'}{'dtContactServices'} or $Data->{'SystemConfig'}{'dtContactServices'} le $detail_date);
        my $details = ($entityTypeID == $Defs::LEVEL_CLUB) ? 'C_DTE' : 'A_DTE';
        $checks{'detailsLink'}  = "$Data->{'target'}?client=$client&amp;a=$details" if ($checks{'detailsMandatory'} and ! $checks{'detailsCompleted'} and $perm);
	}

    ## SERVICES CHECKING
    {
		my $st = qq[
			SELECT COUNT(intAssocServicesID) as Count
			FROM tblAssocServices
			WHERE 
                intAssocID = $assocID
                AND intClubID = $clubID
		];
		my $q= $dbh->prepare($st);
		$q->execute();
		my $services_count= $q->fetchrow_array() || 0;
		$q->finish;
        $checks{'servicesMandatory'} = 1 if ($Data->{'clientValues'}{'authLevel'} == $Defs::LEVEL_CLUB and $Data->{'SystemConfig'}{'ServicesContacts_ClubServicesMandatory'} and $Data->{'clientValues'}{'currentLevel'} == $Defs::LEVEL_CLUB);
        $checks{'servicesMandatory'} = 1 if ($Data->{'clientValues'}{'authLevel'} == $Defs::LEVEL_ASSOC and $Data->{'SystemConfig'}{'ServicesContacts_AssocServicesMandatory'} and $Data->{'clientValues'}{'currentLevel'} == $Defs::LEVEL_ASSOC);
        $checks{'servicesCompleted'} = 1 if ($services_count);
				$checks{'servicesLink'} = "$Data->{'target'}?client=$client&amp;a=A_SV_DTE" if ($checks{'servicesMandatory'} and ! $checks{'servicesCompleted'});
	}

    ## CONTACTS CHECKING
	{

		my $st = qq[
			SELECT 
                COUNT(C.intContactID) as Count, 
                MAX(DATE_FORMAT(dtLastUpdated, "%Y%m%d")) as MaxDateUpdated
			FROM tblContacts as C
                INNER JOIN tblContactRoles as R ON (
                    R.intRoleID=C.intContactRoleID
                )
			WHERE 
				C.intRealmID = $realmID
				AND C.intAssocID = $assocID
				AND C.intClubID = $clubID
				AND C.intTeamID = $teamID

		];
                #AND R.intShowAtTop=1
		my $q= $dbh->prepare($st);
		$q->execute();
		my ($contacts_count, $dtContactsUpdated) = $q->fetchrow_array();
		$q->finish;
        $checks{'contactsMandatory'} = 1 if ($Data->{'clientValues'}{'authLevel'} == $Defs::LEVEL_CLUB and $Data->{'SystemConfig'}{'ServicesContacts_ClubContactsMandatory'} and $Data->{'clientValues'}{'currentLevel'} == $Defs::LEVEL_CLUB);
        $checks{'contactsMandatory'} = 1 if ($Data->{'clientValues'}{'authLevel'} == $Defs::LEVEL_ASSOC and $Data->{'SystemConfig'}{'ServicesContacts_AssocContactsMandatory'}  and $Data->{'clientValues'}{'currentLevel'} == $Defs::LEVEL_ASSOC);
        $checks{'contactsCompleted'} = 1 if ($contacts_count and 
            (
                ! $Data->{'SystemConfig'}{'Contacts_dtContactsUpdated'} 
                or $Data->{'SystemConfig'}{'Contacts_dtContactsUpdated'} le $dtContactsUpdated
            )
        );
        $checks{'contactsLink'} = "$Data->{'target'}?client=$client&amp;a=CON_LIST" if ($checks{'contactsMandatory'} and ! $checks{'contactsCompleted'});
	}

    ## AGREEMENTS CHECKING
	{
		my $st = qq[
			SELECT COUNT(A.intAgreementID) as Count, COUNT(AE.intAgreementID) as CountAgreed, SUM(intCheckNewEntityOnly) as NumNewOnly
			FROM tblAgreements as A
                LEFT JOIN tblAgreementsEntity as AE ON (
                    AE.intAgreementID = A.intAgreementID
				    AND intEntityTypeID = ?
				    AND intEntityID = ?
                )
                INNER JOIN tblTempNodeStructure as T ON (
                    T.intAssocID = $Data->{'clientValues'}{'assocID'}
                )
			WHERE 
                intEntityFor = ?
                AND dtExpiryDate >= SYSDATE()
                AND dtStartDate <= SYSDATE()
                AND A.intRealmID = $Data->{'Realm'}
                AND A.intSubRealmID IN (0, $Data->{'RealmSubType'})
                AND A.intCountryID IN (0, int100_ID)
                AND A.intStateID IN (0, int30_ID)
                AND A.intRegionID IN (0, int20_ID)
                AND A.intZoneID IN (0, int10_ID)
                AND A.intAssocID IN (0, $Data->{'clientValues'}{'assocID'})
		];
		my $q= $dbh->prepare($st);
		$q->execute( $entityTypeID, $entityID , $entityTypeID);
		my ($totalAgreements, $numAgreed, $numNewOnly)= $q->fetchrow_array();
        $totalAgreements ||= 0;
        $numAgreed ||= 0;
		$q->finish;

    $checks{'agreementsMandatory'} = 1 if ($Data->{'clientValues'}{'authLevel'} == $Defs::LEVEL_CLUB and $Data->{'SystemConfig'}{'ServicesContacts_ClubAgreementsMandatory'} and $Data->{'clientValues'}{'currentLevel'} == $Defs::LEVEL_CLUB);
    $checks{'agreementsMandatory'} = 1 if ($Data->{'clientValues'}{'authLevel'} == $Defs::LEVEL_ASSOC and $Data->{'SystemConfig'}{'ServicesContacts_AssocAgreementsMandatory'} and $Data->{'clientValues'}{'currentLevel'} == $Defs::LEVEL_ASSOC);
    $totalAgreements = $totalAgreements-1 if (!$isNew and $numNewOnly);
    $checks{'agreementsCompleted'} = 1 if ($totalAgreements<=$numAgreed or ! $totalAgreements);
	  $checks{'agreementsLink'} = "$Data->{'target'}?client=$client&amp;a=AGREE_L" if ($checks{'agreementsMandatory'} and ! $checks{'agreementsCompleted'});
	}

    $checks{'help_override'} = $Data->{'SystemConfig'}{'AssocConfig'}{'help_text_override'} || $Data->{'SystemConfig'}{'help_text_override'} || '';

	my $kill = 0;
	for my $k ((qw(agreementsLink contactsLink servicesLink detailsLink)))	{
		$kill = 1 if $checks{$k};
	}
		
	$killMsg = $kill  ? runTemplate($Data, \%checks, "contacts/lockout.templ") : '';
	$Data->{'ClearNavBar'} =1 if $kill;

	return ($killMsg, \%checks);
}

sub getServicesContactsEmail {

    my ($Data, $entityType, $entityID, $section) = @_;

	my $assocID = $Data->{'clientValues'}{'assocID'} || 0;
	my $clubID = $Data->{'clientValues'}{'clubID'} || 0;
    my $teamID = $Data->{'clientValues'}{'teamID'} || 0;
		$assocID ||= $entityID if $entityType == $Defs::LEVEL_ASSOC;
		$clubID ||= $entityID if $entityType == $Defs::LEVEL_CLUB;
    return '' if ($entityType > $Defs::LEVEL_ASSOC or $entityType < $Defs::LEVEL_CLUB);
    $clubID = 0 if (! $clubID or $clubID == $Defs::INVALID_ID);
    $teamID = 0 if (! $teamID or $teamID == $Defs::INVALID_ID);
    my $realmID = $Data->{'Realm'} || 0;
    my $where = '';
    $where = qq[ AND intAssocID=$entityID and intClubID=0] if ($entityType == $Defs::LEVEL_ASSOC);
    $where = qq[ AND intClubID=$entityID ] if ($entityType == $Defs::LEVEL_CLUB);
    $where = qq[
			AND intAssocID = $assocID
			AND intClubID = $clubID
    ] if ! $where;

	my $sectionWHERE = '';	
	$sectionWHERE =' AND intFnClearances=1' if ($section == $Defs::SC_CONTACTS_CLEARANCES);
	$sectionWHERE =' AND intFnPayments=1' if ($section == $Defs::SC_CONTACTS_PAYMENTS);
	$sectionWHERE =' AND intFnRegistrations=1' if ($section == $Defs::SC_CONTACTS_REGOS);
#	$sectionWHERE =' AND intFnCompAdmin=1' if ($section == $Defs::SC_CONTACTS_COMPS); 
    my $st = qq[
    	SELECT
            DISTINCT
        	strContactEmail
        FROM 
        	tblContacts
       	WHERE
			intRealmID = $realmID
            $where
			AND strContactEmail <> ''
			$sectionWHERE
	order by intPrimaryContact desc;
    ];
	my $q= $Data->{'db'}->prepare($st);
	$q->execute();
	my $emails='';
	while (my $dref = $q->fetchrow_hashref())	{
		$emails.=qq[$dref->{'strContactEmail'};];
	}
	if (! $emails)	{
	  $st = qq[
    	SELECT
            DISTINCT
        	strContactEmail
        FROM 
        	tblContacts
       	WHERE
			intRealmID = $realmID
            $where
			AND intPrimaryContact=1
    ];
		$q= $Data->{'db'}->prepare($st);
		$q->execute();
		while (my $dref = $q->fetchrow_hashref())	{
			$emails.=qq[$dref->{'strContactEmail'};];
		}
	}

    return $emails;
}

sub get_service_contacts{
    my ($params) = @_;

    my ($dbh, $assoc_id, $club_id, $contact_types, $required_methods) =
        @{$params}{qw/ dbh assoc_id club_id contact_types required_methods /};

    return if (!$dbh or !$assoc_id or ($assoc_id == $Defs::INVALID_ID));
    
    my %where =(
       'intAssocID' => $assoc_id,
    );
    
    if ($club_id && ($club_id != $Defs::INVALID_ID)){
        $where{'intClubID'} = $club_id;
    }
    else{
        $where{'intClubID'} = 0;
    }
    
    #TODO: Teams and Members not yet supported
    $where{'intTeamID'} = 0;
    $where{'intMemberID'} = 0;
        
    # Sort out contacts
    my @contacts = ();
    if (defined $contact_types){
        if (ref($contact_types) eq 'ARRAY'){
            @contacts = @$contact_types;
        }
        elsif ($contact_types){
            push @contacts, $contact_types;
        }
    }
    
    foreach my $contact (@contacts){
        next if(!exists $CONTACTS_TO_COLUMN_MAP{$contact});      
        $where{$CONTACTS_TO_COLUMN_MAP{$contact}} = 1;
    }
    
    # Sort out required contact methods
    my @contact_methods = ();
    if (defined $required_methods){
        if (ref($required_methods) eq 'ARRAY'){
            @contact_methods = @$required_methods;
        }
        elsif ($required_methods){
            push @contact_methods, $required_methods;
        }
    }
    
    foreach my $contact_method (@contact_methods){
        next if(!exists $CONTACT_METHODS_TO_COLUMN_MAP{$contact_method});      
        $where{$CONTACT_METHODS_TO_COLUMN_MAP{$contact_method}}{'!='} = undef;
    }
    
    my @order = ({ '-desc' => $CONTACTS_TO_COLUMN_MAP{$CONTACTS_PRIMARY}});  
    
    my $sql = SQL::Abstract->new;

    my ($stmt, @bind) = $sql->select('tblContacts', '*', \%where, \@order);
    
    my $sth = $dbh->prepare($stmt);
    $sth->execute(@bind);
    
    my @contacts_list;
    
    while (my $dref = $sth->fetchrow_hashref() ){
        push @contacts_list, $dref;
    }
    
    return \@contacts_list;
    
}


1;
