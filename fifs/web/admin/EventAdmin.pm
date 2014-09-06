#
# $Header: svn://svn/SWM/trunk/web/admin/EventAdmin.pm 10064 2013-12-01 22:50:03Z tcourt $
#

package EventAdmin;

require Exporter;
@ISA =  qw(Exporter);
@EXPORT = qw(handle_event);
@EXPORT_OK = qw(handle_event);

use lib "..","../..","../sp_publisher","../comp";
use DBI;
use CGI qw(param unescape escape);
use strict;
use Defs;
use Utils;
use AdminCommon;
use DeQuote;
use FormHelpers;
use HTMLForm;


sub handle_event {
  my($db, $action, $target, $eventID)=@_;
  my $eID=param('eID') || $eventID || 0;
  my $body='';
  my $menu='';
  if($action eq 'list') {
		($body,$menu)=list_events($db, $target); 
  }
  else  {
		$body=event_record($db, $eID, $target, $action);
  }

  return ($body,$menu);
}

# *********************SUBROUTINES BELOW****************************


sub list_events	{
  my ($db, $target) = @_;

  my $event_name_IN = param('event_name') || '';
  my $realm_IN = param('realmID') || '';

  my $strWhere='';
  if ($event_name_IN) {
    $strWhere .= " AND " if $strWhere;
    $strWhere .= "strEventName LIKE '%".$event_name_IN."%'";
  }
  if ($realm_IN) {
    $strWhere .= " AND " if $strWhere;
    $strWhere .= "tblEvent.intRealmID = $realm_IN ";
  }
	$strWhere = "WHERE $strWhere" if $strWhere;

  my $statement=qq[
		SELECT intEventID, strEventName, strRealmName, strUsername, strPassword
		FROM tblEvent
			LEFT JOIN tblRealms ON (tblEvent.intRealmID=tblRealms.intRealmID)
			LEFT JOIN tblAuth ON (tblAuth.intID=tblEvent.intEventID AND tblAuth.intLevel=$Defs::LEVEL_EVENT)
		$strWhere
		ORDER BY strEventName
  ];

  my $query = $db->prepare($statement) or query_error($statement);
  $query->execute() or query_error($statement);
  my $count=0;
  my $body='';
  while(my $dref= $query->fetchrow_hashref()) {
    foreach my $key (keys %{$dref}) { if(!defined $dref->{$key})  {$dref->{$key}='';} }
    $dref->{strEventName} = $dref->{strEventName} || '&nbsp;';
    $dref->{strRealmName} ||= '&nbsp;';
    my $class='';
    my $classborder='commentborder';
    if($count++%2==1) {
      $class=q[ class="commentshaded" ];
      $classborder="commentbordershaded";
    }
		my $extralink='';
		if($dref->{intRecStatus}<0)	{
			$classborder.=" greytext";
			$extralink=qq[ class="greytext"];
		}
    $body.=qq[
      <tr>
        <td class="$classborder"><a $extralink href="$target?action=edit&amp;eID=$dref->{intEventID}">$dref->{strEventName}</a></td>
	<td class="$classborder"><a target="new_window" href="$Defs::base_url/authenticate.cgi?i=$dref->{intEventID}&amp;t=$Defs::LEVEL_EVENT">LOGIN</a></td>
	<td class="$classborder"><a href="$target?action=approve&amp;eID=$dref->{intEventID}">Approve All</a></td>
        <td class="$classborder">$dref->{strRealmName}</td>
      </tr>
    ];
  }
  if(!$body)  {
    $body.=qq[
    <table cellpadding="1" cellspacing="0" border="0" width="90%" align="center">
      <tr>
				<td colspan="3" align="center"><b><br> No Search Results were found<br><br></b></td>
      </tr>
    </table>
    <br>
    ];
  }
  else  {
    $body=qq[
		 <table cellpadding="1" cellspacing="0" border="0" width="95%" align="center">
			<tr>
        <th style="text-align:left;">Event Name</th>
        <th style="text-align:left;">&nbsp;</th>
        <th style="text-align:left;">&nbsp;</th>
        <th style="text-align:left;">Realm</th>
      </tr>

      $body
    </table><br>
    ];
  }

  return ($body,'');
}


sub checkusername	{
	my ($db,$username,$id)=@_;
	#Check that this password is valid and not already in use

	return (0,'Username cannot begin with a number') if $username=~/^'\d/;
	my $st=qq[ 
		SELECT intAuthID 
		FROM tblAuth 
		WHERE strUsername=$username
			AND intLevel >= $Defs::LEVEL_ASSOC
			AND NOT (intLevel=$Defs::LEVEL_ASSOC AND intID=$id)
	];
	my $q=$db->prepare($st);
	$q->execute();
	my($found)=$q->fetchrow_array() || 0;
	$q->finish();
	if($found)	{
		return (0,'Username already in use');
	}
	return (1,'');
}

sub loadEventDetails {
  my($db, $id) = @_;

  return () if !$id;

	my $field=();
	return $field if !$id;
  my $statement=qq[
		SELECT *, DATE_FORMAT(dtRegoStart,'%d/%m/%Y') AS dtRegoStart, DATE_FORMAT(dtRegoEnd,'%d/%m/%Y') AS dtRegoEnd, DATE_FORMAT(dtArrivalStart,'%d/%m/%Y') AS dtArrivalStart, DATE_FORMAT(dtDepartEnd,'%d/%m/%Y') AS dtDepartEnd, tblAuth.strUsername, tblAuth.strPassword
		FROM tblEvent
			LEFT JOIN tblAuth ON (tblAuth.intID=tblEvent.intEventID AND tblAuth.intLevel=$Defs::LEVEL_EVENT)
		WHERE intEventID = $id
		LIMIT 1
  ];
  my $query = $db->prepare($statement);
  $query->execute;
  $field=$query->fetchrow_hashref();
  $query->finish;

  foreach my $key (keys %{$field})  { if(!defined $field->{$key}) {$field->{$key}='';} }
  return $field;
}



sub event_record	{
	my($db, $eid, $target, $action)=@_;

	my $field=loadEventDetails($db,$eid);

  my %FieldDefinitions=(
    fields=>  {
      strEventName => {
        label => 'Event Name',
        value => $field->{strEventName},
        type  => 'text',
        size  => '40',
        maxsize => '60',
        compulsory=>1,
      },
      strEmail => {
        label => 'Email Address of the Organiser',
        value => $field->{strEmail},
        type  => 'text',
        size  => '50',
        maxsize => '250',
        validate => 'EMAIL',
      },
      strAccredCardFile => {
        label => 'Accreditation Card Filename',
        value => $field->{strAccredCardFile },
        type  => 'text',
        size  => '50',
        maxsize => '250',
      },
      strAccredAppFormFile=> {
        label => 'Application Form Filename',
        value => $field->{strAccredAppFormFile},
        type  => 'text',
        size  => '50',
        maxsize => '250',
      },
      intAccredCard => {
        label => 'Activate Accreditation Card',
        value => $field->{intAccredCard},
        type  => 'checkbox',
      },
      intPoliceCheckActive => {
        label => 'Active Police Check Info',
        value => $field->{intPoliceCheckActive},
        type  => 'checkbox',
      },
      intConsentFormActive => {
        label => 'Consent Form Configured',
        value => $field->{intConsentFormActive},
        type  => 'checkbox',
      },
      intArrivalDepartActive => {
        label => 'Arrival Departures',
        value => $field->{intArrivalDepartActive},
        type  => 'checkbox',
      },
      intUniformsActive => {
        label => 'Uniforms',
        value => $field->{intUniformsActive},
        type  => 'checkbox',
      },
      intBioActive => {
        label => 'Hide BIO option from Accred Categories screen',
        value => $field->{intBioActive},
        type  => 'checkbox',
      },
      intAllowEventCopy => {
        label => 'Allow Event Copy',
        value => $field->{intAllowEventCopy},
        type  => 'checkbox',
      },
      strUsername => {
        label => 'Username',
        value => $field->{strUsername},
        type  => 'text',
				readonly => 1,
				SkipProcessing => 1,
      },
      strPassword => {
        label => 'Password',
        value => $field->{strPassword},
        type  => 'text',
				readonly => 1,
				SkipProcessing => 1,
      },
		},
    order => [qw(strEventName intAccredCard strAccredAppFormFile strAccredCardFile intRealmID intPoliceCheckActive intConsentFormActive intArrivalDepartActive intUniformsActive intBioActive intAllowEventCopy strUsername strPassword)],
    options => {
      labelsuffix => ':',
      hideblank => 1,
      target => $target,
      formname => 'e_form',
      submitlabel => "Update Event",
      introtext => 'auto',
      NoHTML => 1,
      updateSQL => qq[
        UPDATE tblEvent
          SET --VAL--
        WHERE intEventID=$eid
        ],
      addSQL => qq[
        INSERT INTO tblEvent (intRealmID, tTimeStamp, --FIELDS--)
        VALUES (8, CURRENT_DATE(), --VAL--)
      ],
    },
    carryfields =>  {
      action=> $action,
			eID=>$eid,
    },
  );
  my $resultHTML='';
  ($resultHTML, undef )=handleHTMLForm(\%FieldDefinitions, undef, $action, '',$db);

	return qq[<div class="pageHeading">Edit Event</div>].$resultHTML;
}

