#
# $Header: svn://svn/SWM/trunk/web/Contacts.pm 10938 2014-03-11 23:42:50Z cchurchill $
#

package Contacts;
require Exporter;
@ISA = qw(Exporter);
@EXPORT=qw(handleContacts showContacts getLocatorContacts);
@EXPORT_OK=qw(handleContacts showContacts getLocatorContacts);

use strict;
use Reg_common;
use Utils;
use AuditLog;
use ServicesContacts;
use CGI qw(escape unescape param);

sub handleContacts {
	my ($action, $Data, $entityTypeID, $entityID)=@_;

	my $resultHTML='';
	my $title='';
	if ($action =~/^CON_SLIST/) {
		($resultHTML,$title)=submitContacts($Data);
		$action = 'CON_LIST';
    auditLog($entityID, $Data, 'Update', 'Contacts');
	}
	if ($action =~/^CON_LIST/) {
		($resultHTML,$title)=listContacts($Data, $entityTypeID, $entityID);
	}
	return ($resultHTML,$title);
}


sub listContacts	{

	my ($Data, $entityTypeID, $entityID) = @_;

	my $header='Common Roles and Contacts';
	my $assocID = $Data->{'clientValues'}{'assocID'} || 0;
	my $clubID = $Data->{'clientValues'}{'clubID'} || 0;
	my $teamID = $Data->{'clientValues'}{'teamID'} || 0;

	my $realmID = $Data->{'Realm'} || 0;
	my $realmSubTypeID = $Data->{'RealmSubType'} || 0;

  my $client=setClient($Data->{'clientValues'});
	my $unesc_cl=unescape(setClient($Data->{'clientValues'})) || '';

	$clubID = 0 if (! $clubID or $clubID == $Defs::INVALID_ID);
	$teamID = 0 if (! $teamID or $teamID == $Defs::INVALID_ID);

	my $st = qq[
		SELECT
			R.intRoleID,
			R.strRoleName,
            R.intShowAtTop,
            R.intAllowMultiple,
			C.*
		FROM
			tblContactRoles as R
			LEFT JOIN tblContacts as C ON (
				C.intContactRoleID = R.intRoleID
				AND C.intAssocID = $assocID
				AND C.intClubID  = $clubID
				AND C.intTeamID  = $teamID
			)
		WHERE 
			R.intRealmID IN (0, $realmID)
			AND R.intRealmSubTypeID IN (0, $realmSubTypeID)
		ORDER BY
			R.intRoleOrder, intPrimaryContact DESC, strContactSurname, strContactFirstname
	];
	my $query = $Data->{'db'}->prepare($st) or query_error($st);
    $query->execute or query_error($st);


	my $count = 0;
	my $body = qq[
    <p>Use this section to update the important contacts for your organisation.  Click on the arrow to complete details for each individual, ensuring you indicate which functional responsibilities they take.  Only one person can be the primary contact, but multiple people might take responsibility for sponsors and fundraising for example.  <br> While you should list your full committee, it is fine to have spare positions if there are certain positions your constitution does not allow for. For example, you may not have a registrar.  If that is the case, simply leave that blank.   <br> In the bottom section you can add extra committee positions or provide additional functional roles.   We use generic titles, so use the one that approximates best the roles you have.</p><br>
<script type="text/javascript">
		function toggleRow(count, action){
			var elementopen = 'controw-open-' + count;
			var elementclosed = 'controw-collapsed-' + count;
			var rowopen = document.getElementById(elementopen);
			var rowclosed = document.getElementById(elementclosed);
			var displayStyle = document.defaultView ? "table-row-group" : "block";
			
			if(action)	{
				rowclosed.style.display = 'none';
				rowopen.style.display = displayStyle;
			}
			else {
				rowopen.style.display = 'none';
				rowclosed.style.display = displayStyle;
			}
		}
</script>
		<form action="$Data->{'target'}" method="POST">
			<input type="submit" name="submit" value=" Save "><br><br>
		<table class="rolestable">
			<tr>
				<td colspan="6" class="pageHeading">Board or Committee Roles</td>
				<td colspan="8" class="pageHeading">Functional Responsibilities</td>
            </tr>
	];
     my $txt_Clr = $Data->{'SystemConfig'}{'txtCLR'} || 'Clearance';

	my $labels = qq[
			<tr>
				<th colspan="4" style="border-bottom:0px;">&nbsp;</th>
			<td colspan="2">&nbsp;</td>
				<th class="">Primary Contact</th>
				<th class="">Competition Admin</th>
				<th class="">Social Activities</th>
				<th class="">Website & Publicity</th>
				<th class="">$txt_Clr & Permits</th>
				<th class="">Sponsors & Fundraising</th>
				<th class="">Finance & Payments</th>
				<th class="">Legal & Contracts</th>
				<th class="">Registrations</th>
			</tr>
	];
	$body .= $labels;
    my @Roles=();
    my $lastRoleID=0;
    my $lastRoleCount=0;
    my $lastRoleCountNeeded=0;

	while (my $dref = $query->fetchrow_hashref) {
        if ($lastRoleID != $dref->{'intRoleID'})    {
            if ($lastRoleCount<$lastRoleCountNeeded)    {
                my $last_ref = $Roles[$#Roles];
                for my $i ($lastRoleCount..$lastRoleCountNeeded-1)    {
                    push @Roles, {
                        intRoleID=>$last_ref->{'intRoleID'},
                        strRoleName=>$last_ref->{'strRoleName'},
                        intShowAtTop=>$last_ref->{'intShowAtTop'},
                        intAllowMultiple=>$last_ref->{'intAllowMultiple'},
                    };
                }
            }
            $lastRoleCount=0;
        }
        push @Roles, $dref;
        $lastRoleID = $dref->{'intRoleID'};
        $lastRoleCountNeeded = $dref->{'intShowAtTop'} || 0;
        $lastRoleCount++;
    }

    if ($lastRoleCount<$lastRoleCountNeeded)    {
        my $last_ref = $Roles[$#Roles];
        for my $i ($lastRoleCount..$lastRoleCountNeeded)    {
            push @Roles, {
                intRoleID=>$last_ref->{'intRoleID'},
                strRoleName=>$last_ref->{'strRoleName'},
                intShowAtTop=>$last_ref->{'intShowAtTop'},
                intAllowMultiple=>$last_ref->{'intAllowMultiple'},
            };
        }
    }
	my $roles='';
    my $subBody='';
	my %Roles=();
	for my $dref (@Roles)   {
		$roles .= qq[<option value="$dref->{'intRoleID'}">$dref->{'strRoleName'}</option>] if (! exists $Roles{$dref->{'intRoleID'}} and $dref->{'intAllowMultiple'});
    	$Roles{$dref->{'intRoleID'}}=1;
		my $open = 0;
		my $closedstyle= $open 
			? "display:none;"
			: '';
		my $openstyle= $open 
			? ''
			: "display:none;";

		my $contactrowoptions = getContactRowOptionsHTML($count, $dref, 0);
		my $blankmessage = 'Add new Name Here';
		$blankmessage = '' if ($dref->{'strContactFirstname'} or $dref->{'strContactSurname'});
		$dref->{'strRoleName'} =~s/\s/&nbsp;/g;
		if ($dref->{'intShowAtTop'} >= 1)   {
			$body .= qq[
				<tbody id="controw-collapsed-$count" style="$closedstyle">
					<tr class="roleheader">
						<td colspan="2"><a href="#" onclick="toggleRow($count, 1);return false;" class="contactstoggle"><img src="images/arrow_open.jpg" alt="Open"></a><b>$dref->{strRoleName}</b></td>
						<td colspan="2">$dref->{'strContactFirstname'} $dref->{'strContactSurname'}$blankmessage</td>
						$contactrowoptions
					</tr>
				</tbody>
				<tbody id="controw-open-$count" style="$openstyle">
					<tr class="roleheader">
						<td colspan="2"><a href="#" onclick="toggleRow($count, 0);return false;" class="contactstoggle"><img src="images/arrow_closed.jpg" alt="Close"></a><b>$dref->{strRoleName}</b></td>
						<td colspan="2">$dref->{'strContactFirstname'} $dref->{'strContactSurname'}
						<input type="hidden" name="roleID_$count" value="$dref->{'intRoleID'}">
						</td>
						<td colspan="2">&nbsp;</td>
					</tr>
			];
			$body .= insertContactRow($count, $dref,0);
			$body .= '</tbody>';
		}
		else    {
			next if (
				! $dref->{'strContactFirstname'} 
				and ! $dref->{'strContactSurname'} 
				and ! $dref->{'strContactEmail'} 
				and ! $dref->{'strContactMobile'}
			);
			$subBody .= qq[
				<tbody id="controw-collapsed-$count" style="$closedstyle">
					<tr class="roleheader">
						<td colspan="2"><a href="#" onclick="toggleRow($count, 1);return false;" class="contactstoggle"><img src="images/arrow_open.jpg" alt="Open"></a><b>$dref->{strRoleName}</b></td>
						<td colspan="2">$dref->{'strContactFirstname'} $dref->{'strContactSurname'}</td>
						$contactrowoptions
					</tr>
				</tbody>
				<tbody id="controw-open-$count" style="$openstyle">
					<tr class="roleheader">
						<td colspan="2"><a href="#" onclick="toggleRow($count, 0);return false;" class="contactstoggle"><img src="images/arrow_closed.jpg" alt="Close"></a><b>$dref->{strRoleName}</b></td>
						<td colspan="2">$dref->{'strContactFirstname'} $dref->{'strContactSurname'}
						<input type="hidden" name="roleID_$count" value="$dref->{'intRoleID'}">
						</td>
						<td colspan="2">&nbsp;</td>
					</tr>
			];
			$subBody .= insertContactRow($count, $dref,0);
			$subBody .= '</tbody>';
		}
		$count++;
	}
	$body .= qq[
			<tr>
				<td colspan="14">&nbsp;</td>
			</tr>
			<tr>
				<td colspan="6" class="pageHeading">Other Roles and Contacts</td>
				<td colspan="8" class="pageHeading">Functional Responsibilities</td>
			</tr>
            $labels
            $subBody
	];

	### INSERT 3 BLANK ONES
	for my $i (1..3)	{
		$count++;
		my $contactrowoptions = getContactRowOptionsHTML($count, undef, 0);
		$body .= qq[
			<tbody id="controw-collapsed-$count" style="">
				<tr class="roleheader">
					<td colspan="2"><a href="#" onclick="toggleRow($count, 1);return false;" class="contactstoggle"><img src="images/arrow_open.jpg" alt="Open"></a><b>Choose a Role</b></a></td>
					<td colspan="2">Add a new name now !</td>
					$contactrowoptions
			<td colspan="2">&nbsp;</td>
				</tr>
			</tbody>
			<tbody id="controw-open-$count" style="display:none;">
				<tr class="roleheader">
					<td colspan="4"><a href="#" onclick="toggleRow($count, 0);return false;" class="contactstoggle"><img src="images/arrow_closed.jpg" alt="Close"></a><select name="roleID_$count"><option value="0" SELECTED>--Select a Role--</option>$roles</select></b></td>
			<td colspan="2">&nbsp;</td>
				</tr>
		];
		$body .= insertContactRow($count, undef,1);
		$body .= '</tbody>';
	}
	$body .= qq[
		</table>
			<input type="hidden" name="a" value="CON_SLIST">
			<input type="hidden" name="count" value="$count">
			<input type="hidden" name="client" value="$unesc_cl">
			<br><br><br><input type="submit" name="submit" value=" Save ">
		</form>
	];

	my $scMenu = getServicesContactsMenu($Data, $entityTypeID, $entityID, $Defs::SC_MENU_SHORT, $Defs::SC_MENU_CURRENT_OPTION_CONTACTS);
	$body = $scMenu.$body;

	return ($body, $header);
}

sub insertContactRow	{

	my ($count, $dref, $new) = @_;

	$new = 1 if !$dref->{'intContactID'};
	my $showInLocator= ($dref->{'intShowInLocator'} == 1) ? 'CHECKED' : '';
		
	my $clubOffers = ($new or $dref->{'intReceiveOffers'} ==1) ? 'CHECKED' : '';
	my $productUpdates= ($new or $dref->{'intProductUpdates'} ==1) ? 'CHECKED' : '';

	my $contactrowoptions = getContactRowOptionsHTML($count, $dref, 1);

	my $genderSelect = qq[<select name="contactGender_$count">];
	$dref->{'intContactGender'} ||= 0;
  for my $k (keys %Defs::PersonGenderInfo)  {
			my $selected = ($k == $dref->{'intContactGender'}) ? 'SELECTED' : '';
			$genderSelect .= qq[<option value="$k" $selected>$Defs::PersonGenderInfo{$k}</option>];
	}
	$genderSelect .= qq[</select>];

	my $body = qq[
		<tr class="contactrow">
			<td class="label">Firstname:</td>
			<td class="value"> <input size="10" type="text" name="contactFirstname_$count" value="$dref->{'strContactFirstname'}"> </td>
			<td class="label">Surname: </td>
			<td class="value"><input size="15" type="text" name="contactSurname_$count" value="$dref->{'strContactSurname'}"></td>
			<td class="label">Gender: </td>
			<td class="value">$genderSelect</td>
			$contactrowoptions
		</tr>
		<tr class="contactrow" >
			<td class="label">Email:</td>
			<td class="value"><input size="15" type="text" name="contactEmail_$count" value="$dref->{'strContactEmail'}"></td>
			<td class="label">Mobile:</td>
			<td class="value"> <input size="15" type="text" name="contactMobile_$count" value="$dref->{'strContactMobile'}"></td>
			<td colspan="2">&nbsp;</td>
		</tr>
		<tr class="contactrow contactrowbottom">
			<td colspan="2" class="label">Publish on Locator: <input type="checkbox" name="showInLocator_$count" value="1" $showInLocator> </td>
		</tr>

		];

	return $body;
}

sub submitContacts	{

	my ($Data) = @_;

	my $assocID = $Data->{'clientValues'}{'assocID'} || 0;
	my $clubID = $Data->{'clientValues'}{'clubID'} || 0;
	my $teamID = $Data->{'clientValues'}{'teamID'} || 0;

	my $realmID = $Data->{'Realm'} || 0;
	my $realmSubTypeID = $Data->{'RealmSubType'} || 0;

	$clubID = 0 if (! $clubID or $clubID == $Defs::INVALID_ID);
	$teamID = 0 if (! $teamID or $teamID == $Defs::INVALID_ID);

	my $cgi=new CGI;
    my %params=$cgi->Vars();

	my $st = qq[
		DELETE FROM tblContacts
		WHERE
			intRealmID = $realmID
			AND intAssocID = $assocID
			AND intClubID = $clubID
			AND intTeamID = $teamID
	];
	$Data->{'db'}->do($st);

	my $count = $params{'count'} || 0;


	$st = qq[
		INSERT INTO tblContacts
		(
			intRealmID,
			intAssocID,
			intClubID,
			intTeamID,
			intContactRoleID,
			strContactFirstname,
			strContactSurname,
			intContactGender,
			strContactEmail,
			strContactMobile,
			intFnCompAdmin,
			intFnSocial,
			intFnWebsite,
			intFnClearances,
			intFnSponsorship,
			intFnPayments,
			intFnLegal,
			intFnRegistrations,
			intShowInLocator,
			intPrimaryContact,
			intReceiveOffers,
			intProductUpdates,
            dtLastUpdated
		)
		VALUES (
			$realmID,
			$assocID,
			$clubID,
			$teamID,
			?,
			?,
			?,
			?,
			?,
			?,
			?,
			?,
			?,
			?,
			?,
			?,
			?,
			?,
			?,
			?,
			?,
			?,
            NOW()
		)
	];
	my $query = $Data->{'db'}->prepare($st) or query_error($st);
	for my $i (0..$count)	{
		my $contactFirstname = $params{"contactFirstname_$i"} || '';
		my $contactSurname = $params{"contactSurname_$i"} || '';
		my $contactGender = $params{"contactGender_$i"} || 0;
		my $contactEmail = $params{"contactEmail_$i"} || '';
		my $contactMobile = $params{"contactMobile_$i"} || '';
		my $fnCompAdmin = $params{"fnCompAdmin_$i"} || 0;
		my $fnSocial = $params{"fnSocial_$i"} || 0;
		my $fnWebsite= $params{"fnWebsite_$i"} || 0;
		my $fnClearances= $params{"fnClearances_$i"} || 0;
		my $fnSponsorship= $params{"fnSponsorship_$i"} || 0;
		my $fnPayments= $params{"fnPayments_$i"} || 0;
		my $fnLegal= $params{"fnLegal_$i"} || 0;
		my $fnRegistrations= $params{"fnRegistrations_$i"} || 0;
		my $showInLocator= $params{"showInLocator_$i"} || 0;
		my $primaryContact = ($params{"primaryContact"} == $i) ? 1 : 0;
		my $clubOffers = $params{"clubOffers_$i"} || 0;
		my $productUpdates= $params{"productUpdates_$i"} || 0;

		next if (! $contactFirstname and ! $contactSurname and ! $contactEmail and ! $contactMobile);
		my $roleID = $params{"roleID_$i"} || next;

    	$query->execute(
			$roleID, 
			$contactFirstname, 
			$contactSurname, 
			$contactGender,
			$contactEmail, 
			$contactMobile, 
			$fnCompAdmin,
			$fnSocial,
			$fnWebsite,
			$fnClearances,
			$fnSponsorship,
			$fnPayments,
			$fnLegal,
			$fnRegistrations,
			$showInLocator,
			$primaryContact,
			$clubOffers,
			$productUpdates
		) or query_error($st);
	}
	
}

sub getLocatorContacts	{
  my ($Data, $showallcontacts) = @_;
  my $assocID = $Data->{'clientValues'}{'assocID'} || 0;
	my $clubID = $Data->{'clientValues'}{'clubID'} || 0;
	my $teamID = $Data->{'clientValues'}{'teamID'} || 0;
	my $realmID = $Data->{'Realm'} || 0;
	my $realmSubTypeID = $Data->{'RealmSubType'} || 0;
	$showallcontacts ||= 0;
	my $locatorWhere = 'AND C.intShowInLocator=1';
	$locatorWhere = '' if $showallcontacts;
	$clubID = 0 if (! $clubID or $clubID == $Defs::INVALID_ID);
	$teamID = 0 if (! $teamID or $teamID == $Defs::INVALID_ID);
  my $st = qq[
		SELECT
			R.intRoleID,
			R.strRoleName,
      R.intShowAtTop,
      R.intAllowMultiple,
			C.*
		FROM
			tblContactRoles as R
			LEFT JOIN tblContacts as C ON (
				C.intContactRoleID = R.intRoleID
				AND C.intAssocID = ?
				AND C.intClubID  = ?
				AND C.intTeamID  = ?
			)
		WHERE 
			R.intRealmID IN (0, $realmID)
			AND R.intRealmSubTypeID IN (0, $realmSubTypeID)
			$locatorWhere
		ORDER BY
			R.intRoleOrder, intPrimaryContact DESC
	];
	my $query = $Data->{'db'}->prepare($st) or query_error($st);
  $query->execute(
		$assocID,
		$clubID,
		$teamID,
	);
	my @Contacts=();
 	while (my $dref = $query->fetchrow_hashref) {
    next if (! $dref->{strContactFirstname} and ! $dref->{strContactSurname} and ! $dref->{strContactEmail}); # and ! $dref->{strContactMobile});
		my %Contact=();
		$Contact{'Firstname'} = $dref->{'strContactFirstname'} || '';
		$Contact{'Surname'} = $dref->{'strContactSurname'} || '';
		$Contact{'Mobile'} = $dref->{'strContactMobile'} || '';
		$Contact{'Email'} = $dref->{'strContactEmail'} || '';
		$Contact{'Role'} = $dref->{'strRoleName'} || '';
		$Contact{'PrimaryContact'} = $dref->{'intPrimaryContact'} || 0;
		$Contact{'Clearances'} = $dref->{'intFnClearances'} || 0;
		push @Contacts, \%Contact;
  }
  return \@Contacts;
}

sub showContacts    {

    my ($Data, $locatorOnly, $editlink) = @_;

    my $assocID = $Data->{'clientValues'}{'assocID'} || 0;
	my $clubID = $Data->{'clientValues'}{'clubID'} || 0;
	my $teamID = $Data->{'clientValues'}{'teamID'} || 0;

	my $realmID = $Data->{'Realm'} || 0;
	my $realmSubTypeID = $Data->{'RealmSubType'} || 0;

	$clubID = 0 if (! $clubID or $clubID == $Defs::INVALID_ID);
	$teamID = 0 if (! $teamID or $teamID == $Defs::INVALID_ID);

    my $locatorWHERE = $locatorOnly ? qq[ AND C.intShowInLocator=1] : '';
    my $st = qq[
		SELECT
			R.intRoleID,
			R.strRoleName,
            R.intShowAtTop,
            R.intAllowMultiple,
			C.*
		FROM
			tblContactRoles as R
			LEFT JOIN tblContacts as C ON (
				C.intContactRoleID = R.intRoleID
				AND C.intAssocID = $assocID
				AND C.intClubID  = $clubID
				AND C.intTeamID  = $teamID
			)
		WHERE 
			R.intRealmID IN (0, $realmID)
			AND R.intRealmSubTypeID IN (0, $realmSubTypeID)
            $locatorWHERE
		ORDER BY
			R.intRoleOrder, intPrimaryContact DESC
	];
	my $query = $Data->{'db'}->prepare($st) or query_error($st);
    $query->execute or query_error($st);

  	my $count = 0;
	my $body = qq[
		<table width="60%;" class="listTable">
        <tr>
            <th>&nbsp;</th>
            <th>Role</th>
            <th>Firstname</th>
            <th>Surname</th>
            <th>Mobile</th>
            <th>Email</th>
        </tr>
        <tr>
            <td colspan="6"><i><b>All of these contacts will appear on your locator.  If you wish to change who appears then do through the contacts page.</b></i></td>
        </tr>
	];
     
  	while (my $dref = $query->fetchrow_hashref) {
        next if (! $dref->{strContactFirstname} and ! $dref->{strContactSurname} and ! $dref->{strContactEmail} and ! $dref->{strContactMobile});
        $count++;
        my $primaryContact = $dref->{'intPrimaryContact'} == 1 ? qq[<i>Primary Contact</i>] : '';
        $body .= qq[
            <tr>
                <td>$primaryContact</td>
                <td>$dref->{strRoleName}</td>
                <td>$dref->{strContactFirstname}</td>
                <td>$dref->{strContactSurname}</td>
                <td>$dref->{strContactMobile}</td>
                <td>$dref->{strContactEmail}</td>
            </tr>
        ];
    }
    $body .= qq[</table>];
     $body = '<p>To add contacts to this locator, do so in the contacts page.</p>' if ! $count;
     $body = '' if !$count and !$editlink;


    return $body;
}

sub getContactRowOptionsHTML {

	my ($count, $dref, $editable) = @_;

	my $fnCompAdmin = ($dref->{'intFnCompAdmin'} == 1) ? 'CHECKED' : '';
	my $fnSocial = ($dref->{'intFnSocial'} == 1) ? 'CHECKED' : '';
	my $fnWebsite= ($dref->{'intFnWebsite'} == 1) ? 'CHECKED' : '';
	my $fnClearances= ($dref->{'intFnClearances'} == 1) ? 'CHECKED' : '';
	my $fnSponsorship= ($dref->{'intFnSponsorship'} == 1) ? 'CHECKED' : '';
	my $fnPayments= ($dref->{'intFnPayments'} == 1) ? 'CHECKED' : '';
	my $fnLegal= ($dref->{'intFnLegal'} == 1) ? 'CHECKED' : '';
	my $fnRegistrations= ($dref->{'intFnRegistrations'} == 1) ? 'CHECKED' : '';
	my $primaryContact = ($dref->{'intPrimaryContact'} ==1) ? 'CHECKED' : '';
		
	my $body = '';
	if($editable)	{
		$body = qq[
			<td class="contacttype" rowspan="3">
				<input type="radio" name="primaryContact" value="$count" $primaryContact>
			</td>
			<td class="contacttype" rowspan="3">
				<input type="checkbox" name="fnCompAdmin_$count" $fnCompAdmin value="1">
			</td>
			<td class="contacttype" rowspan="3">
				<input type="checkbox" name="fnSocial_$count" $fnSocial value="1">
			</td>
			<td class="contacttype" rowspan="3">
				<input type="checkbox" name="fnWebsite_$count" $fnWebsite value="1">
			</td>
			<td class="contacttype" rowspan="3">
				<input type="checkbox" name="fnClearances_$count" $fnClearances value="1">
			</td>
			<td class="contacttype" rowspan="3">
				<input type="checkbox" name="fnSponsorship_$count" $fnSponsorship value="1">
			</td>
			<td class="contacttype" rowspan="3">
				<input type="checkbox" name="fnPayments_$count" $fnPayments value="1">
			</td>
			<td class="contacttype" rowspan="3">
				<input type="checkbox" name="fnLegal_$count" $fnLegal value="1">
			</td>
			<td class="contacttype" rowspan="3">
				<input type="checkbox" name="fnRegistrations_$count" $fnRegistrations value="1">
			</td>
		];
	}
	else	{
		$body = qq[
			<td colspan="2">&nbsp;</td>
			<td class="contacttype" rowspan="3">
				<input type="radio" $primaryContact disabled>
			</td>
			<td class="contacttype" rowspan="3">
				<input type="checkbox" $fnCompAdmin  disabled>
			</td>
			<td class="contacttype" rowspan="3">
				<input type="checkbox" $fnSocial  disabled>
			</td>
			<td class="contacttype" rowspan="3">
				<input type="checkbox"$fnWebsite disabled>
			</td>
			<td class="contacttype" rowspan="3">
				<input type="checkbox"$fnClearances disabled>
			</td>
			<td class="contacttype" rowspan="3">
				<input type="checkbox"$fnSponsorship disabled>
			</td>
			<td class="contacttype" rowspan="3">
				<input type="checkbox"$fnPayments disabled>
			</td>
			<td class="contacttype" rowspan="3">
				<input type="checkbox"$fnLegal disabled>
			</td>
			<td class="contacttype" rowspan="3">
				<input type="checkbox"$fnRegistrations disabled>
			</td>
		];


	}
	return $body;
}
	
1;
