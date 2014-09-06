#
# $Header: svn://svn/SWM/trunk/web/CustomFields.pm 9404 2013-09-02 04:03:30Z mstarcevic $
#

package CustomFields;
require Exporter;

@ISA =  qw(Exporter);
@EXPORT = qw(getCustomFieldNames handle_customfields);
@EXPORT = qw(getCustomFieldNames getCFNumbertoFName handle_customfields);

use strict;
use CGI qw(param unescape);
use Reg_common;
use DeQuote;
use AuditLog;

require DefCodes;

my @custom_fields = (
    { 'displayname' => 'Custom Text Field',        'dbname' => 'strCustomStr',         'numbers' => [ 1 .. 25 ], 'type' => 'member' },
    { 'displayname' => 'Custom Number Field',      'dbname' => 'dblCustomDbl',         'numbers' => [ 1 .. 20 ], 'type' => 'member' },
    { 'displayname' => 'Custom Date Field',        'dbname' => 'dtCustomDt',           'numbers' => [ 1 .. 15 ], 'type' => 'member' },
    { 'displayname' => 'Custom Lookup',            'dbname' => 'intCustomLU',          'numbers' => [ 1 .. 25 ], 'type' => 'member' },
    { 'displayname' => 'Custom Checkbox',          'dbname' => 'intCustomBool',        'numbers' => [ 1 ..  7 ], 'type' => 'member' },

    { 'displayname' => 'Custom Club Text Field',   'dbname' => 'strClubCustomStr',     'numbers' => [ 1 .. 15 ], 'type' => 'club'   },
    { 'displayname' => 'Custom Club Number Field', 'dbname' => 'dblClubCustomDbl',     'numbers' => [ 1 .. 10 ], 'type' => 'club'   },
    { 'displayname' => 'Custom Club Date Field',   'dbname' => 'dtClubCustomDt',       'numbers' => [ 1 ..  5 ], 'type' => 'club'   },
    { 'displayname' => 'Custom Club Lookup',       'dbname' => 'intClubCustomLU',      'numbers' => [ 1 .. 10 ], 'type' => 'club'   },
    { 'displayname' => 'Custom Club Checkbox',     'dbname' => 'intClubCustomBool',    'numbers' => [ 1 ..  5 ], 'type' => 'club'   },

    { 'displayname' => 'Custom Team Text Field',   'dbname' => 'strTeamCustomStr',     'numbers' => [ 1 .. 15 ], 'type' => 'team'   },
    { 'displayname' => 'Custom Team Number Field', 'dbname' => 'dblTeamCustomDbl',     'numbers' => [ 1 .. 10 ], 'type' => 'team'   },
    { 'displayname' => 'Custom Team Date Field',   'dbname' => 'dtTeamCustomDt',       'numbers' => [ 1 ..  5 ], 'type' => 'team'   },
    { 'displayname' => 'Custom Team Lookup',       'dbname' => 'intTeamCustomLU',      'numbers' => [ 1 .. 10 ], 'type' => 'team'   },
    { 'displayname' => 'Custom Team Checkbox',     'dbname' => 'intTeamCustomBool',    'numbers' => [ 1 ..  5 ], 'type' => 'team'   },

    { 'displayname' => 'Custom Member Notes',      'dbname' => 'strMemberCustomNotes', 'numbers' => [ 1 ..  5 ], 'type' => 'member' },
);

my %DefaultNames = getDefaultNames();

sub getCFNumbertoFName  {
    my $i = 1;
    my %CFNumbertoFName = ();

    for my $c (@custom_fields) {
        for my $n ( @{ $c->{'numbers'} } ) {
            $CFNumbertoFName{$i} = $c->{'dbname'} . $n;
            $i++;
        }
    }

    return \%CFNumbertoFName;
}

sub getDefaultNames {
    my %DefaultNames = ();

    for my $c (@custom_fields) {
        for my $i ( @{ $c->{'numbers'} } ) {
            $DefaultNames{ $c->{'dbname'} . $i } = $c->{'displayname'} . ' ' . $i;
        }
    }

    $DefaultNames{'strPackageName'} = 'Member Package';

    return %DefaultNames;
}

sub getDBNamesByType {
    my $type = shift;

    my @dbnames = ();
    for my $c (@custom_fields) {
        next if ( $c->{'type'} ne $type );

        for my $n ( @{ $c->{'numbers'} } ) {
            push @dbnames, $c->{'dbname'} . $n;
        }
    }

    return @dbnames;
}

sub getCustomFieldNames	{
	my($Data, $subtypeID)=@_;
	my $db=$Data->{'db'};
	my $realmID=$Data->{'Realm'} || 0;
  $subtypeID||=$Data->{'RealmSubType'} || 0;
	my $assocID=$Data->{'clientValues'}{'assocID'} || 0;
	$assocID=0 if $assocID == $Defs::INVALID_ID;
	my %CustomFieldNames=();
	if($db)	{
		my $statement=qq[
			SELECT 
        strDBFName, 
        strName, 
        intLocked, 
        intSubTypeID
			FROM 
        tblCustomFields
			WHERE 
        intRealmID= $realmID
				AND (intAssocID = $assocID OR intAssocID=0)
			ORDER 
        BY intAssocID  DESC, 
        intSubTypeID ASC 
		];
	  my $query = $db->prepare($statement);
		$query->execute;
    while (my($dbf, $name, $locked, $subtype) = $query->fetchrow_array) {
    	next if($subtype and $subtype != $subtypeID);
	    $CustomFieldNames{$dbf}=[$name, $locked];
    }
	}
	for my $f (keys %DefaultNames)	{
		$CustomFieldNames{$f}=[$DefaultNames{$f},0] if !exists $CustomFieldNames{$f};
	}
	return \%CustomFieldNames;
}


sub handle_customfields{
	my($Data, $action)=@_;

	my $id=param('cfi') || 0;
	my $body='';
	if($action eq 'A_CF_U')	{
		$body=update_customfields($Data, $id);
		$action = 'A_CF_L';
	}
	if($action eq 'A_CF_E')	{
		$body.=detail_customfields($Data, $id);
	}
	else	{
		my ($memBody, $teamBody, $clubBody)=list_customfields($Data);
		my $l = $Data->{'lang'};
		$body.= qq[
			<script type="text/javascript">
				jQuery(function() {
					jQuery('#customfieldTabs').tabs();
				});
			</script>

			<div id="customfieldTabs" style="float:left;clear:right;width:99%;">
				<ul>
					<li><a href="#customfields_members">].$l->txt('Member Custom Fields').qq[</a></li>
					<li><a href="#customfields_clubs">].$l->txt('Club Custom Fields').qq[</a></li>
					<li><a href="#customfields_teams">].$l->txt('Team Custom Fields').qq[</a></li>
				</ul>
				<div id = "customfields_members">$memBody</div>
				<div id = "customfields_clubs">$clubBody</div>
				<div id = "customfields_teams">$teamBody</div>
			</div>
		];

	}
	my $title="Manage Custom Fields";
	return ($body,$title);
}

sub list_customfields {
	my($Data)=@_;

	my $realmID=$Data->{'Realm'} || 0;
  my $target=$Data->{'target'};
  my $cl  = setClient($Data->{'clientValues'});
  my $unesc_cl=unescape($cl);
	my $assocID=$Data->{'clientValues'}{'assocID'} || $Defs::INVALID_ID;

	my $st=qq[
		SELECT * 
		FROM tblCustomFields
		WHERE intRealmID= $realmID
			AND intAssocID = $assocID 
		ORDER BY strDBFName
	];
  my $query = $Data->{'db'}->prepare($st);
  $query->execute();
	my $body='';
	my %DBData=();
	while (my $dref=$query->fetchrow_hashref())	{
		$DBData{$dref->{'strDBFName'}}=[$dref->{'strName'}, $dref->{'intCustomFieldsID'}, $dref->{'intAssocID'}];
	}
    for my $f ( getDBNamesByType('member') ) {
		my $name=$DefaultNames{$f} || '';
		my $defname=$DefaultNames{$f} || '';
		#my $locked=0;
		if(exists $DBData{$f})	{
			$name=$DBData{$f}[0] || '';
			#$locked=1 if !$DBData{$f}[2];
		}
		my $link= qq[<input type="text" name="cf_$f" value="$name" maxlength="30">];
		my $managelink = '';
		my $lookuptype = DefCodes::getCustomLookupTypes($f) || 0;
		if($lookuptype)	{
			my $link = "lookupmanage.cgi?client=$cl&amp;a=A_LK_L&amp;t=$lookuptype";
			$managelink = qq[<a href = "#" onclick = "dialogform('$link','$defname');return false;">Manage</a>];
		}
		$body.=qq[
			<tr>
				<td class="label">$defname: </td>
				<td class="value">$link</td>
				<td class="value">$managelink</td>
			</tr>
		];
	}
	if($body)	{
		$body=qq[
			<table >
				$body
			</table>
		];
	}
	else	{
		$body.=qq[<div class="warningmsg">No Records could be found</div>];
	}
	my $memBody=qq[
		<p>Change the names of the custom fields below. </p>
	<form action="$target" method="POST">
		<input type="hidden" name="a" value="A_CF_U">
		<input type="hidden" name="client" value="$unesc_cl">
		<p>
				<input type="submit" value="Update Custom Fields" class = "button proceed-button"><br><br>
		</p>
		$body
		<p>
				<input type="submit" value="Update Custom Fields" class = "button proceed-button"><br>
		</p>
	</form>
	];
	$memBody = qq[<div id="customfields_members">$memBody<br></div>];

	$body = '';
    for my $f ( getDBNamesByType('team') ) {
		my $name=$DefaultNames{$f} || '';
		my $defname=$DefaultNames{$f} || '';
		#my $locked=0;
		if(exists $DBData{$f})	{
			$name=$DBData{$f}[0] || '';
			#$locked=1 if !$DBData{$f}[2];
		}
		my $link= qq[<input type="text" name="cf_$f" value="$name">];
		my $managelink = '';
		my $lookuptype = DefCodes::getCustomLookupTypes($f) || 0;
		if($lookuptype)	{
			my $link = "lookupmanage.cgi?client=$cl&amp;a=A_LK_L&amp;t=$lookuptype";
			$managelink = qq[<a href = "#" onclick = "dialogform('$link','$defname',660);return false;">Manage</a>];
		}
	 $body.=qq[
			<tr>
				<td class="label">$defname: </td>
				<td class="value">$link</td>
				<td class="value">$managelink</td>
			</tr>
		];
	}
	if($body)	{
		$body=qq[
			<table >
				$body
			</table>
		];
	}
	else	{
		$body.=qq[<div class="warningmsg">No Records could be found</div>];
	}
	my $teamBody=qq[
		<p>Change the names of the custom fields below. </p>
	<form action="$target" method="POST">
		<input type="hidden" name="a" value="A_CF_U">
		<input type="hidden" name="client" value="$unesc_cl">
		<p>
				<input type="submit" value="Update Custom Fields" class = "button proceed-button"><br><br>
		</p>
		$body
		<p>
				<input type="submit" value="Update Custom Fields" class = "button proceed-button"><br>
		</p>
	</form>
	];
	$teamBody = qq[<div id="customfields_teams">$teamBody<br></div>];


	$body = '';

    for my $f ( getDBNamesByType('club') ) {
		my $name=$DefaultNames{$f} || '';
		my $defname=$DefaultNames{$f} || '';
		#my $locked=0;
		if(exists $DBData{$f})	{
			$name=$DBData{$f}[0] || '';
			#$locked=1 if !$DBData{$f}[2];
		}
		my $link= qq[<input type="text" name="cf_$f" value="$name">];
		my $managelink = '';
		my $lookuptype = DefCodes::getCustomLookupTypes($f) || 0;
		if($lookuptype)	{
			my $link = "lookupmanage.cgi?client=$cl&amp;a=A_LK_L&amp;t=$lookuptype";
			$managelink = qq[<a href = "#" onclick = "dialogform('$link','$defname',660);return false;">Manage</a>];
		}
		$body.=qq[
			<tr>
				<td class="label">$defname: </td>
				<td class="value">$link</td>
				<td class="value">$managelink</td>
			</tr>
		];
	}
	if($body)	{
		$body=qq[
			<table >
				$body
			</table>
		];
	}
	else	{
		$body.=qq[<div class="warningmsg">No Records could be found</div>];
	}
	my $clubBody=qq[
		<p>Change the names of the custom fields below. </p>
	<form action="$target" method="POST">
		<input type="hidden" name="a" value="A_CF_U">
		<input type="hidden" name="client" value="$unesc_cl">
		<p>
				<input type="submit" value="Update Custom Fields" class = "button proceed-button"><br><br>
		</p>
		$body
		<p>
				<input type="submit" value="Update Custom Fields" class = "button proceed-button"><br>
		</p>
	</form>
	];
	$clubBody = qq[<div id="customfields_clubs">$clubBody<br></div>];

	return ($memBody, $teamBody, $clubBody);

}

sub update_customfields {
	my($Data, $type, $id)=@_;
	my $realmID=$Data->{'Realm'} || 0;
  my $target=$Data->{'target'};
  my $cl = setClient($Data->{'clientValues'});
	my $assocID=$Data->{'clientValues'}{'assocID'} || $Defs::INVALID_ID;
  my $q=new CGI;
  my %params=$q->Vars();
	my $st_insert=qq[
		INSERT INTO tblCustomFields
			(intAssocID, intRealmID, strDBFName, strName)
			VALUES ($assocID, $realmID, ?, ?)
	];
	my $st_upd=qq[
		UPDATE tblCustomFields SET strName=?
			WHERE intAssocID =$assocID
				AND intRealmID = $realmID
				AND strDBFName = ?
	];	
	my $query_insert=$Data->{'db'}->prepare($st_insert);
	my $query_upd=$Data->{'db'}->prepare($st_upd);
	my $subBody='';
	my %CurrentNames=();
	{
		#Get Current List of Names
		my $st=qq[
			SELECT strDBFName, intRecStatus
			FROM tblCustomFields
			WHERE intRealmID= $realmID
				AND intAssocID = $assocID
			ORDER BY strDBFName
		];

		my $q=$Data->{'db'}->prepare($st);
		$q->execute();
		while(my $dref=$q->fetchrow_hashref())  {
			$CurrentNames{$dref->{'strDBFName'}}=$dref->{'intRecStatus'};
		}
	}
	for my $k (keys %params)	{
		if($k=~/^cf_/)	{
			my $newkey=$k;
			$newkey=~s/^cf_//;
			my $val=$params{$k} || '';
			next if !$val;
			$val=~s/>/&gt;/g;
			$val=~s/</&lt;/g;
			if(exists $CurrentNames{$newkey})	{ $query_upd->execute($val,$newkey); }
			else	{ $query_insert->execute($newkey,$val); }
		$subBody.=qq[<div class="warningmsg">There was a problem changing that record ($val)</div>] if $DBI::err;
		}
	}
  auditLog($type, $Data, 'Update', 'Custom Fields');
	$subBody.=qq[<div class="OKmsg">Custom Fields Updated</div>];
	return $subBody;
}

1;
