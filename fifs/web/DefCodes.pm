#
# $Header: svn://svn/SWM/trunk/web/DefCodes.pm 11504 2014-05-07 02:49:58Z apurcell $
#

package DefCodes;

require Exporter;
@ISA =  qw(Exporter);
@EXPORT = qw(getDefCodesTypes handle_defcodes getCustomLookupTypes getCustomFieldsToTypes getDefCodes);
@EXPORT_OK = qw(getDefCodesTypes handle_defcodes getCustomLookupTypes getCustomFieldsToTypes getDefCodes);

use lib '..', '.';

use strict;
use CGI qw(escape unescape param);
use Defs;
use Reg_common;
use DeQuote;
require AuditLog;
require CustomFields;
use TTTemplate;

my %DefCodesTypes	= (
	 #-2 => 'Discliplines',
    #-5 => 'Season Types',
    -9 => 'Occupations',
    -8 => 'Ethnicity',
	-10 => 'Hair Colours',
	-11 => 'Eye Colours',
	-14 => 'Official Types',
	-15 => 'Accreditation Levels',
	-16 => 'Misc. Official Types',
	-17 => 'Match Officials Types',
	#-18 => 'Coach Types',
	#-19 => 'Discipline Types',
	-31 => 'ID Document Types',
	-32 => 'Accreditation Providers',
	-33 => 'State Teams',
	-34 => 'National Teams',
	-35 => 'Accreditation Courses',
	-37 => 'Reason for Clearance',
	-38 => 'Reason for Denial',
    -40 => 'Match Official Accred Custom DDL 1',
    -41 => 'Match Official Accred Custom DDL 2',
    -42 => 'Match Official Accred Custom DDL 3',
    -43 => 'Coach Accred Custom DDL 1',
    -44 => 'Coach Accred Custom DDL 2',
    -45 => 'Coach Accred Custom DDL 3',
    -46 => 'Match Official Accred Custom DDL 4',
    -47 => 'Match Official Accred Custom DDL 5',
	-50 => 'Custom Lookup 1',
	-51 => 'Custom Lookup 2',
	-52 => 'Custom Lookup 3',
	# BELOW ARE ADDED FOR SWC v7
	-56 => 'Volunteer Official Type',
	-57 => 'Custom Lookup 4',
	-58 => 'Custom Lookup 5',
	-59 => 'Custom Lookup 6',
	-60 => 'Custom Lookup 7',
	-61 => 'Custom Lookup 8',
	-62 => 'Custom Lookup 9',
	-63 => 'Custom Lookup 10',
	-81 => 'Custom Club Lookup 1',
	-82 => 'Custom Club Lookup 2',
	-83 => 'Custom Club Lookup 3',
	-84 => 'Custom Club Lookup 4',
	-85 => 'Custom Club Lookup 5',
	-86 => 'Custom Club Lookup 6',
	-87 => 'Custom Club Lookup 7',
	-88 => 'Custom Club Lookup 8',
	-89 => 'Custom Club Lookup 9',
	-90 => 'Custom Club Lookup 10',
	-91 => 'Languages',
	#-92 => 'Other 1 Official Types', #(SWC ONLY)
	#-93 => 'Other 2 Official Types', #(SWC ONLY)
	-96 => 'Misc Pos Level', #(SWM ONLY)

    -97 => 'Custom Lookup 11',
    -98 => 'Custom Lookup 12',
    -99 => 'Custom Lookup 13',
    -100 => 'Custom Lookup 14',
    -101 => 'Custom Lookup 15',
    -102 => 'Custom Lookup 16',
    -103 => 'Custom Lookup 17',
    -104 => 'Custom Lookup 18',
    -105 => 'Custom Lookup 19',
    -106 => 'Custom Lookup 20',
    -107 => 'Custom Lookup 21',
    -108 => 'Custom Lookup 22',
    -109 => 'Custom Lookup 23',
    -110 => 'Custom Lookup 24',
    -111 => 'Custom Lookup 25',


    ## New Accreditation System Def Codes ##
    ## -500 to -550 is reserved for this. ##

    -501 => 'Accreditation: Sport',
    -502 => 'Accreditation: Level',
    -503 => 'Accreditation: Provider',
    -504 => 'Accreditation: Status',
    #-505 => 'Type',
    -506 => 'Course Number',

    ## Participation Module Def Codes     ##
    ## -551 to -599 is reserved for this. ##

    #-551 => 'Participation: Custom DDL 1',
    #-552 => 'Participation: Custom DDL 2',
    #-552 => 'Participation: Custom DDL 3',
    #-553 => 'Participation: Custom DDL 4',

    ## ################################## ##

	
	-1001 => 'How did you find out - options (Online Only)',  ##Online Only 
	-1002 => 'Areas of assistance offered (Online Only)',  ##Online Only 
	-1003 => 'Accreditation Result (Online Only)',  ##Online Only
	-1004 => 'Watch Sport on TV',  ##Online Only
	-1005 => 'Age Group Category',  ##Online Only
	#-53 => 'National Custom Lookup 1', # Not Editable
	#-54 => 'National Custom Lookup 2', # Not Editable
	#-55 => 'National Custom Lookup 3', # Not Editable
	#-64 => 'National Custom Lookup 4', # Not Editable
	#-65 => 'National Custom Lookup 5', # Not Editable
	#-66 => 'National Custom Lookup 6', # Not Editable
	#-67 => 'National Custom Lookup 7', # Not Editable
	#-68 => 'National Custom Lookup 8', # Not Editable
	#-69 => 'National Custom Lookup 9', # Not Editable
	#-70 => 'National Custom Lookup 10', # Not Editable

    # Team Entry Module -1100
    -1100 => 'Team Entry Nomination Type',
                       

);

my %CustomFieldsToTypes	= (
	-50 => 'intCustomLU1',
	-51 => 'intCustomLU2',
	-52 => 'intCustomLU3',
	-57 => 'intCustomLU4',
	-58 => 'intCustomLU5',
	-59 => 'intCustomLU6',
	-60 => 'intCustomLU7',
	-61 => 'intCustomLU8',
	-62 => 'intCustomLU9',
	-63 => 'intCustomLU10',
	-81 => 'intClubCustomLU1',
	-82 => 'intClubCustomLU2',
	-83 => 'intClubCustomLU3',
	-84 => 'intClubCustomLU4',
	-85 => 'intClubCustomLU5',
	-86 => 'intClubCustomLU6',
	-87 => 'intClubCustomLU7',
	-88 => 'intClubCustomLU8',
	-89 => 'intClubCustomLU9',
	-90 => 'intClubCustomLU10',
	-71 => 'intTeamCustomLU1',
	-72 => 'intTeamCustomLU2',
	-73 => 'intTeamCustomLU3',
	-74 => 'intTeamCustomLU4',
	-75 => 'intTeamCustomLU5',
	-76 => 'intTeamCustomLU6',
	-77 => 'intTeamCustomLU7',
	-78 => 'intTeamCustomLU8',
	-79 => 'intTeamCustomLU9',
	-80 => 'intTeamCustomLU10',
	-97 => 'intCustomLU11',
	-98 => 'intCustomLU12',
	-99 => 'intCustomLU13',
	-100 => 'intCustomLU14',
	-101 => 'intCustomLU15',
	-102 => 'intCustomLU16',
	-103 => 'intCustomLU17',
	-104 => 'intCustomLU18',
	-105 => 'intCustomLU19',
	-106 => 'intCustomLU20',
	-107 => 'intCustomLU21',
	-108 => 'intCustomLU22',
	-109 => 'intCustomLU23',
	-110 => 'intCustomLU24',
	-111 => 'intCustomLU25',
	-53  => 'intNatCustomLU1',
    -54  => 'intNatCustomLU2',
    -55  => 'intNatCustomLU3',
    -64  => 'intNatCustomLU4',
    -65  => 'intNatCustomLU5',
    -66  => 'intNatCustomLU6',
    -67  => 'intNatCustomLU7',
    -68  => 'intNatCustomLU8',
    -69  => 'intNatCustomLU9',
    -70  => 'intNatCustomLU10',
);

sub getDefCodesTypes {
  return %DefCodesTypes;
}
sub getCustomFieldsToTypes {
  return %CustomFieldsToTypes;
}
sub getCustomLookupTypes	{
	my($fieldname) = @_;
	for my $k (keys %CustomFieldsToTypes)	{
		return $k if $CustomFieldsToTypes{$k} eq $fieldname;
	}
	return 0;
}

sub getDefCodes {
    my (%params)   = @_;
    my $dbh        = $params{'dbh'};
    my $realmID    = $params{'realmID'};
    my $subRealmID = $params{'subRealmID'} || 0;
    my $assocID    = $params{'assocID'}    || -1;
    my $hideCodes  = $params{'hideCodes'}  || '';
    my $onlyTypes  = $params{'onlyTypes'}  || '';

    return undef if !$dbh;
    return undef if !$realmID;

    my %DefCodes = ();
    my %DefCodesOrder = ();

    $hideCodes = qq[AND intCodeID NOT IN ($hideCodes)] if $hideCodes;
    $onlyTypes = qq[AND intType IN ($onlyTypes)] if $onlyTypes;

    my $sql = qq[
        SELECT 
            intType, 
            intCodeID, 
            strName, 
            intSubTypeID,
            intDisplayOrder
        FROM 
            tblDefCodes
        WHERE 
            intRealmID=?
            AND (intAssocID=? OR intAssocID=0)
            AND intRecStatus<>$Defs::RECSTATUS_DELETED
            $hideCodes
            $onlyTypes
        ORDER BY intType, intDisplayOrder, strName
      ];
      my $q = $dbh->prepare($sql);

      $q->execute($realmID, $assocID);

      while (my ($intType, $intCodeID, $strName, $intSubTypeID, $intDisplayOrder) = $q->fetchrow_array) {
          next if ($intSubTypeID and $intSubTypeID != $subRealmID);
          $DefCodes{$intType}{$intCodeID} = $strName || '';
          push @{$DefCodesOrder{$intType}}, $intCodeID;
      }

      return (\%DefCodes, \%DefCodesOrder);
}

sub handle_defcodes	{
	my($Data, $action)=@_;
	my $type=param('t') || '';
	my $id=param('lki') || 0;
  my $cl = setClient($Data->{'clientValues'});
	my $body='';
	if($action eq 'A_LK_U')	{
		$body=update_defcodes($Data, $type, $id);
		$action = 'A_LK_L';
	}
	if($action eq 'A_LK_L')	{
		$body.=list_defcodes($Data,$type);
	}
	elsif($action eq 'A_LK_E') {
		$body.=detail_defcodes($Data,$type, $id);
	}
	else	{
		$body.= show_menu($Data);
	}
	my $title="Manage Lookup Information";
	$title.=" - $DefCodesTypes{$type}" if $type;
	return ($body,$title);
}


sub list_defcodes	{
	my($Data, $type)=@_;
    my $realmID=$Data->{'Realm'} || 0;
    my $subtypeID=$Data->{'RealmSubType'} || 0;
	my $target=$Data->{'target'};
	my $cl = setClient($Data->{'clientValues'});
    my $assocID=$Data->{'clientValues'}{'assocID'} || $Defs::INVALID_ID;
    my $st=qq[
        SELECT intCodeID, strName, intAssocID, intSubTypeID
        FROM tblDefCodes
        WHERE intType = ?
            AND intRealmID = ?
            AND (intAssocID = ? OR intAssocID=0)
            AND intRecStatus<>$Defs::RECSTATUS_DELETED
        ORDER BY intDisplayOrder, strName
        ];
        my $query = $Data->{'db'}->prepare($st);
    $query->execute($type, $realmID, $assocID);
    my $i=0;
    my @defCodes = ();
    while (my $dref=$query->fetchrow_hashref())	{
        next if($dref->{'intSubTypeID'} and $dref->{'intSubTypeID'}!= $subtypeID);
        push @defCodes, {
            intCodeID  => $dref->{'intCodeID'},
            strName    => $dref->{'strName'},
            intAssocID => $dref->{'intAssocID'},
        }
    }
	my $sysconf_type="DefCodes$type";
	my $allowadds= (!$Data->{'SystemConfig'}{$sysconf_type} or 
					$Data->{'SystemConfig'}{$sysconf_type} == $Defs::CONFIG_DEFCODES_MODIFY_ADD  or 
					$Data->{'SystemConfig'}{$sysconf_type} == $Defs::CONFIG_DEFCODES_MODIFY_BOTH) 
			? 1 : 0;

    $allowadds = 0 if $Data->{'SystemConfig'}{'removeAddForDC'.$type};

    my $typeKey = getRegoPassword(abs($type));

    my %templateData = (
        allowAdds     => $allowadds,
        editAction    => 'A_LK_E',
        clearAction   => 'A_LK_CT',
        selectAction  => 'A_LK_ST',
        deleteAction  => 'A_LK_D',
        returnAction  => 'A_LK_',
        target        => $target,
        client        => $cl,
        dcType        => $type, 
        tkey          => $typeKey,
        defCodes      => \@defCodes,
    );

    my $templateFile = 'defcodes/list.templ';
    my $body = runTemplate($Data, \%templateData, $templateFile);

	return $body;
}


sub show_menu	{
	my($Data) = @_;
	my $customfieldnames = CustomFields::getCustomFieldNames($Data);
	my $cl  = setClient($Data->{'clientValues'});
	my @options = ();
	for my $key (keys %DefCodesTypes	)	{
		my $name = $DefCodesTypes{$key} || '';
		if($CustomFieldsToTypes{$key})	{
			$name = $customfieldnames->{$CustomFieldsToTypes{$key} || ''}[0] || $DefCodesTypes{$key} || '';
			if($name ne $DefCodesTypes{$key})	{
				$name .= " ($DefCodesTypes{$key})";
			}
		}
		push @options, [$name, "$Data->{'target'}?client=$cl&amp;a=A_LK_L&amp;t=$key"];
	}
	push @options, ['Division', "$Data->{'target'}?client=$cl&amp;a=ASSGR_L&amp;"];
	my $optionlist = '';
	for my $i (sort {uc($a->[0]) cmp uc($b->[0])} @options)	{
		my $name = $Data->{'lang'}->txt($i->[0]) || next;
		$optionlist .=qq{<li><a href="$i->[1]">$name</a></li>};
	}
	my $body=qq[
		<p>This section allows you to maintain the values that are present in drop down boxes present through the system.  Choose the type of value you wish to manage from the list below.
		</p>
		<ul>
			$optionlist
		</ul>
	];
	return $body;
}


sub detail_defcodes	{
	my($Data, $type, $id)=@_;

	my $realmID=$Data->{'Realm'} || 0;
	my $target=$Data->{'target'};
	my $cl  = setClient($Data->{'clientValues'});
	my $assocID=$Data->{'clientValues'}{'assocID'} || $Defs::INVALID_ID;

	my $st=qq[
		SELECT intCodeID, strName, intAssocID
		FROM tblDefCodes
		WHERE intType = ?
			AND intRealmID = ?
			AND intAssocID = ?
			AND intCodeID = ?
			AND intRecStatus<>$Defs::RECSTATUS_DELETED
		LIMIT 1
	];
	my $query = $Data->{'db'}->prepare($st);
	$query->execute(
		$type,
		$realmID,
		$assocID,
		$id,
	);
	my $dref=$query->fetchrow_hashref();
	$query->finish();
	my $name=$dref->{'strName'} || '';

	my $body=qq[
		<form action="$Data->{'target'}" method="post">
			<table class="lkTable">
			<tr>
				<td class="label">Name</td>
				<td class="data"><input type="text" name="name" value="$name" size="40" maxlength="50"></td>
			</tr>
			<tr>
				<td class="label">&nbsp;</td>
				<td class="data"><br><br><input type="submit" value=" Update " class = "button proceed-button">	</td>
			</tr>
			</table>
			<input type="hidden" name="a" value="A_LK_U">
			<input type="hidden" name="client" value="].unescape($cl).qq[">
			<input type="hidden" name="lki" value="$id">
			<input type="hidden" name="t" value="$type">
		</form>
	];
	return $body;
}


sub update_defcodes	{
	my($Data, $type, $id)=@_;
	my $realmID=$Data->{'Realm'} || 0;
 	my $target=$Data->{'target'};
 	my $cl = setClient($Data->{'clientValues'});
	my $assocID=$Data->{'clientValues'}{'assocID'} || $Defs::INVALID_ID;

	my $name=param('name') || '';
  $name=~s/>/&gt;/g;
  $name=~s/</&lt;/g;
	return '' if !$name;
	my $st='';
  my $audit_type = '';
	my @values = ();
	if($id)	{
		$st=qq[
			UPDATE tblDefCodes 
			SET strName = ?
			WHERE intType = ?
				AND intRealmID = ?
				AND intAssocID = ?
				AND intCodeID = ?
		];
    $audit_type = "Update";
		@values = (
			$name,
			$type,
			$realmID,
			$assocID,
			$id,
		);
	}
	else	{
		$st=qq[
			INSERT INTO tblDefCodes
			(intAssocID, intRealmID, intType, strName, intRecStatus)
			VALUES (?,?,?,?,1)
		];
 		@values = (
			$assocID,
			$realmID,
			$type,
			$name,
		);
   $audit_type = "Add";
	}
  my $query = $Data->{'db'}->prepare($st);
  $query->execute(@values);
  $id = $query->{mysql_insertid} unless ($id);
	if($DBI::err)	{
		return '<div class="warningmsg">There was a problem changing that record</div>';
	}
  AuditLog::auditLog($id, $Data, $audit_type, 'Lookup Information');
	return '';
}

1;
