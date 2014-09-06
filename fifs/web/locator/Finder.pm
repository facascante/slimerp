#
# $Header: svn://svn/SWM/trunk/web/locator/Finder.pm 10138 2013-12-03 20:24:41Z tcourt $
#

package Finder;

require Exporter;
@ISA =  qw(Exporter);
@EXPORT = qw(search_results);
@EXPORT_OK = qw(search_results);

use strict;
use lib ".", "..", "../..";
use DBI;
use CGI qw(:standard escape param);
use DeQuote;
use FormHelpers;
use Contacts;
use TTTemplate;
use FinderCustom;
use Utils;

sub search_results {
	my ($Data, $FinderDefs, $db) = @_;
  my $search_IN = param('search_value') || '';
  my $postcode_IN = safe_param('postcode','number') || '';
  my $yob_IN = safe_param('yob','number') || '';
  my $realmID = $Data->{'Realm'};
  my $subRealmID = $Data->{'RealmSubType'};
  my $clubLevel = safe_param('club_level_only','number') || 0;
  my $club_WHERE = '';
  my $clubLevelAssoc = safe_param('club_level_only_assoc','number') || 0;
	my $search_type = param('centre_search_type') || 0;
  my $error = '';	
  my $result = '';
  my @values = ();
	$postcode_IN = $search_IN if ($search_type == 1 and $search_IN =~ /^\d{4}$/);
  $postcode_IN =~ s/\.//g;
  if ($postcode_IN =~ /^\d{4}$/ or $search_IN) {
    my $extra_JOIN = '';
    my $club_WHERE = $clubLevel ? qq[ AND S.intClubID > 0] : qq[ AND S.intClubID = 0] ;
		my $sub_realm_WHERE = '';
		my $dob_WHERE = '';
 		my $extra_WHERE = '';
    $sub_realm_WHERE = qq[ AND A.intAssocTypeID IN ($subRealmID)] if $subRealmID;
    ($subRealmID, $club_WHERE, $sub_realm_WHERE, $dob_WHERE) = get_custom_sql($realmID, $subRealmID, $club_WHERE, $sub_realm_WHERE, $dob_WHERE);
		if ($search_IN and $search_type == 2)	{
 	    my $postcode = ($postcode_IN) ? $postcode_IN : $search_IN;
  		$extra_JOIN = qq[LEFT JOIN tblAssocServicesPostalCode AS ASPC ON (ASPC.intAssocID = A.intAssocID AND ASPC.intClubID = S.intClubID)];
		  $extra_WHERE = qq [
				AND (
			];
			if ($postcode_IN) {
				$extra_WHERE .= qq[
					ASPC.strPostalCode LIKE ? or
					C.strPostalCode LIKE ? or 
      	];
        push @values, '%'.$postcode_IN.'%';
        push @values, '%'.$postcode_IN.'%';
			}
			else {
				$extra_WHERE .= qq[
					ASPC.strPostalCode LIKE ? or
					C.strPostalCode LIKE ? or 
      	];
        push @values, '%'.$search_IN.'%';
        push @values, '%'.$search_IN.'%';
			}
      $extra_WHERE .= qq[
					C.strName LIKE ? or 
					C.strSuburb LIKE ? or 
					C.strGroundPostalCode LIKE ? or 
					C.strGroundSuburb LIKE ? or 
					S.strVenuePostalCode LIKE ? or 
					S.strVenueSuburb LIKE ?
				)
			];
        push @values, '%'.$search_IN.'%';
        push @values, '%'.$search_IN.'%';
        push @values, '%'.$search_IN.'%';
        push @values, '%'.$search_IN.'%';
        push @values, '%'.$search_IN.'%';
        push @values, '%'.$search_IN.'%';
		}
		elsif ($search_IN and $search_type == 3) {
			if ($clubLevel) {
				$extra_WHERE .= qq[
					AND C.strName LIKE ?
				];
        push @values, '%'.$search_IN.'%';
			}
			else {
				$extra_WHERE .= qq[
					AND A.strName LIKE ?
				];
        push @values, '%'.$search_IN.'%';
			}
		}
		else {
  		$extra_JOIN = qq[LEFT JOIN tblAssocServicesPostalCode AS ASPC ON (ASPC.intAssocID = A.intAssocID AND ASPC.intClubID = S.intClubID)];
  		$extra_WHERE = qq[AND ASPC.strPostalCode LIKE ?];
      push @values, '%'.$postcode_IN.'%';
		}
    $extra_WHERE .= qq[AND A.intAssocID IN ($clubLevelAssoc)] if ($clubLevelAssoc and $clubLevel);
		my $statement = qq[
			SELECT 
				DISTINCT 
				A.intAssocID, 
				S.intClubID, 
				S.strContact1Name, 
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
				S.intRegisterID, 
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
				SR.strSubTypeName, 
				A.intAssocTypeID
			FROM tblAssoc AS A 
				INNER JOIN tblAssocServices AS S ON A.intAssocID=S.intAssocID  
				LEFT JOIN tblClub as C ON (C.intClubID = S.intClubID) 
				LEFT JOIN tblRealmSubTypes as SR ON (SR.intSubTypeID = A.intAssocTypeID)
				$extra_JOIN
			WHERE 
        S.intPublicShow = 1
      	$club_WHERE
				$sub_realm_WHERE
				$dob_WHERE
      	$extra_WHERE
      	AND A.intRealmID = ?
			LIMIT $FinderDefs->{'Limit'}
		];	
    push @values, $realmID;
		print STDERR qq[FINDER SQL \n $statement \n @values \n];
	  my $query = $db->prepare($statement);
		$query->execute(@values);
    my %SearchResults = ();
    my @organisations = ();
  	my $rowCount = 0;
  	while (my $row = $query->fetchrow_hashref())   {
   		$rowCount++;
    	$row->{'strName'} ||= '';
    	$row->{'ClubName'} ||= '';
    	$row->{'SubRealmName'} ||= '';
    	$row->{'yob'} = $yob_IN;
    	$row->{'postcode'} = $postcode_IN;
    	$row->{'search_value'} = $search_IN;
    	$row->{'days'} = _format_days($row);
      $row->{'register_btn'} = _generate_register_btn($row, $rowCount, $db); 
   		$row->{'realmID'} = $realmID;
      $Data->{'clientValues'}{'assocID'} = $row->{'intAssocID'};
      $Data->{'clientValues'}{'clubID'} = $row->{'intClubID'};
      my %OrgData = (
        'Details' => $row,
        'Contacts' => getLocatorContacts($Data)
      );
      push @organisations, \%OrgData;
		}
    $SearchResults{'results'} = \@organisations;
    my $file = $FinderDefs->{'SearchResults'};
    $file = $FinderDefs->{'NoResults'} unless ($rowCount);;
    $SearchResults{'Title'} = $FinderDefs->{'Brand'};
    $SearchResults{'CSS'} = $FinderDefs->{'Style'};
    $SearchResults{'Header'} = $FinderDefs->{'DefaultHeader'};
    $SearchResults{'Copyright'} = $FinderDefs->{'DefaultCopyright'};
    $SearchResults{'realmID'} = $realmID;
    $SearchResults{'subRealmID'} = $subRealmID;
    $SearchResults{'clubLevelOnly'} = $clubLevel;
    $result = runTemplate(
      $Data,
      \%SearchResults,
      $FinderDefs->{'directory'} . "/$file"
    ); 
	}
  else {
    $result = runTemplate(
      $Data,
      {
        'Title'=>$FinderDefs->{'Brand'}, 
        'CSS'=>$FinderDefs->{'Style'},
        'Header'=>$FinderDefs->{'DefaultHeader'},
        'Copyright'=>$FinderDefs->{'DefaultCopyright'}
      }, 
      $FinderDefs->{'directory'} . "/" . $FinderDefs->{'Error'}
    );
  }
	return ($result);
}

sub _format_days {
  my ($row) = @_;
  my $days = '';
  foreach my $day (
    ['intMon', 'Monday'], 
    ['intTue', 'Tuesday'],
    ['intWed', 'Wednesday'], 
    ['intThu', 'Thursday'],
    ['intFri', 'Friday'],
    ['intSat', 'Saturday'],
    ['intSun', 'Sunday'],
  ) {
    $days .= ', ' if ($days and $row->{$day->[0]});
    $days .= ($row->{$day->[0]}) ? $day->[1] : '';
  }
  return $days;
}

sub _generate_register_btn {
  my ($row, $count, $db) = @_;
  #-- THE FOLLOWING JAVASCRIPT IS REQUIRED IN THE HEADER -- ##
  #-- OF THE TEMPLATE FILE WHERE THIS BUTTON APPEARS.    -- ##
  #
  #<script language="JavaScript1.2" type="text/javascript">
  #  function checkclub (formname) {
  #    if(document[formname]['cID'].options[document[formname]['cID'].selectedIndex].value == 0) {
  #      alert('You must select a club');
  #      return false;
  #    }
  #    else  {
  #       return true;
  #    }
  #  }
  #</script>
  return '' unless ($row->{'intAllowRegoForm'} and !$row->{'intClubID'});
  my $register_btn = '';
  my $club = '';
  my $onsubmit = '';
  my $regoType = 1;
  my $formname = "regof$count";
  my $showButton = 1;
  my $selectButtonText = 'Register';
  if ($row->{'intRegisterID'} == 2) {
    my $clublist = _getClubs($db, $row->{'intAssocID'});
    $clublist->{0} = ' -- Select a Club --';
    $ club = '<BR>' . drop_down('cID',$clublist, 0,'',1,0);
    $selectButtonText = 'Register to Club';
    $onsubmit=qq[ onsubmit="return checkclub('$formname');" ];
    $regoType=4;
  }
  $showButton = 0 if ! $row->{'intRegisterID'};
  $register_btn = $showButton ? qq[
    <form method="post" action="../regoform.cgi" name="$formname" $onsubmit>
      <input type="hidden" name="aID" value="$row->{intAssocID}">
      <input type="hidden" name="regoType" value="$regoType">
      <input type="hidden" name="nh" value="1">
      <input type="submit" name="selectbut" value="$selectButtonText">
      $club
    </form>
  ] : '';
  return $register_btn;
}

sub _getClubs {
  my($db, $assocID) = @_;
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
  while(my($id, $name)=$q->fetchrow_array()) {
    next if !$id;
    next if !$name;
    $clubs{$id}=$name;
  }
	return \%clubs;
}

1;
