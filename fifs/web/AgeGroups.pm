#
# $Header: svn://svn/SWM/trunk/web/AgeGroups.pm 9491 2013-09-10 05:13:35Z tcourt $
#

package AgeGroups;
require Exporter;
@ISA = qw(Exporter);
@EXPORT=qw(handleAgeGroups getAgeGroups);
@EXPORT_OK=qw(handleAgeGroups getAgeGroups);

use strict;
use CGI qw(unescape param);
use Reg_common;
use Utils;
use HTMLForm;
use AuditLog;
use FormHelpers;
use GridDisplay;
require DefCodes;

sub handleAgeGroups	{
	my ($action, $Data)=@_;

	my $ageGroupID = param('ageGroupID') || 0;
	my $memberSeasonID = param('msID') || 0;
	my $resultHTML='';
	my $title='';
	if ($action =~/^AGEGRP_DT/) {
		#AgeGroup Details
		($resultHTML,$title)=ageGroup_details($action, $Data, $ageGroupID);
	}
	elsif ($action =~/^AGEGRP_L/) {
		#List AgeGroups
		my $tempResultHTML = '';
		($tempResultHTML,$title)=listAgeGroups($Data);
		$resultHTML .= $tempResultHTML;
	}
	
	return ($resultHTML,$title);
}

sub ageGroup_details	{
	my ($action, $Data, $ageGroupID)=@_;

	my $option='display';
	$option='edit' if $action eq 'AGEGRP_DTE' and allowedAction($Data, 'agegrp_e');
	$option='add' if $action eq 'AGEGRP_DTA' and allowedAction($Data, 'agegrp_a');
	$ageGroupID=0 if $option eq 'add';
	my $field=loadAgeGroupDetails($Data->{'db'}, $ageGroupID, $Data->{'Realm'}, $Data->{'RealmSubType'}, $Data->{'clientValues'}{'assocID'}) || ();
	my $intAssocID = $Data->{'clientValues'}{'assocID'} >= 0 ? $Data->{'clientValues'}{'assocID'} : 0;
	my $txt_Name= $Data->{'SystemConfig'}{'txtAgeGroup'} || 'Age Group';
	my $txt_Names= $Data->{'SystemConfig'}{'txtAgeGroups'} || 'Age Groups';
	
	my %genderoptions=();
	for my $k (keys %Defs::genderInfo)        {
		next if !$k and $Data->{'SystemConfig'}{'NoUnspecifiedGender'};
		$genderoptions{$k}=$Defs::genderInfo{$k} || '';
	}

    my ($DefCodes, $DefCodesOrder) = DefCodes::getDefCodes(
        dbh        => $Data->{'db'}, 
        realmID    => $Data->{'Realm'},
        subRealmID => $Data->{'RealmSubType'},
        assocID    => $intAssocID,
    );
       
  my $client=setClient($Data->{'clientValues'}) || '';
	my %FieldDefinitions=(
		fields=>	{
			strAgeGroupDesc => {
				label => "$txt_Name Name",
				value => $field->{strAgeGroupDesc},
				type  => 'text',
				size  => '40',
				maxsize => '100',
				compulsory => 1,
				sectionname=>'details',
			},
			dtDOBStart=> {
				label => 'Date of Birth Start Range',
				value => $field->{dtDOBStart},
				type  => 'date',
                datetype => 'dropdown',
				sectionname => 'details',
				compulsory => 1,
				posttext=>' <i>Older end of Date Range(eg 01 - Jan - 1970)</i>',
			},
			dtDOBEnd=> {
				label => 'Date of Birth End Range.',
				value => $field->{dtDOBEnd},
				type  => 'date',
                datetype => 'dropdown',
				sectionname => 'details',
				compulsory => 1,
				posttext=>' <i>Younger end of Date Range(eg 31 - Dec - 2000)</i>',
			},
			intAgeGroupGender => {
				label => 'Gender',
				value => $field->{intAgeGroupGender},
				type  => 'lookup',
				options => \%genderoptions,
				sectionname => 'details',
				firstoption => [''," "], 
				compulsory => 1,
			},
			intCategoryID => {
				label => 'Category',
				value => $field->{'intCategoryID'},
				type  => 'lookup',
				options => $DefCodes->{-1005},
				order => $DefCodesOrder->{-1005},
				sectionname => 'details',
				firstoption => [''," "], 
			},
			intRecStatus=> {
				label => "$txt_Name Active",
				value => $field->{intRecStatus},
				type  => 'checkbox',
				sectionname => 'details',
				default => 1,
				displaylookup => {1 => 'Yes', 0 => 'No'},
			},
		},
		order => [qw(strAgeGroupDesc dtDOBStart dtDOBEnd intAgeGroupGender intCategoryID intRecStatus)],
		sections => [
			['details',"$txt_Name Details"],
		],	
		options => {
			labelsuffix => ':',
			hideblank => 1,
			target => $Data->{'target'},
			formname => 'n_form',
      submitlabel => "Update $txt_Name",
      introtext => 'auto',
			NoHTML => 1,
      updateSQL => qq[
        UPDATE tblAgeGroups
          SET --VAL--
        WHERE intAgeGroupID = $ageGroupID
					AND intAssocID = $intAssocID
			],
      addSQL => qq[
        INSERT INTO tblAgeGroups
          (intRealmID, intRealmSubTypeID, intAssocID, dtAdded,  --FIELDS-- )
					VALUES ($Data->{'Realm'}, $Data->{'RealmSubType'}, $intAssocID, SYSDATE(), --VAL-- )
			],
      auditFunction=> \&auditLog,
      auditAddParams => [
        $Data,
        'Add',
        'Age Groups',
      ],
      auditEditParams => [
        $ageGroupID,
        $Data,
        'Update',
        'Age Groups',
      ],
      LocaleMakeText => $Data->{'lang'},
		},
    carryfields =>  {
      client => $client,
      a=> $action,
			ageGroupID => $ageGroupID,
    },
  );
	my $resultHTML='';
	($resultHTML, undef )=handleHTMLForm(\%FieldDefinitions, undef, $option, '',$Data->{'db'});
	my $title=qq[$txt_Name - $field->{strAgeGroupDesc}];
	if($option eq 'display')  {
		my $chgoptions='';
		$chgoptions.=qq[<span class = "button-small generic-button"><a href="$Data->{'target'}?client=$client&amp;a=AGEGRP_DTE&amp;ageGroupID=$ageGroupID">Edit</a></span> ] if allowedAction($Data, 'agegrp_e');
		$chgoptions=qq[<div class="changeoptions">$chgoptions</div>] if $chgoptions;
		$chgoptions= '' if (! $field->{intAssocID});
		$chgoptions= '' if ($Data->{'SystemConfig'}{'AgeGroups_NationalOnly'});
		$title=$chgoptions.$title;
	}
	$title="Add New $txt_Name" if $option eq 'add';
	my $text = qq[<p><a href="$Data->{'target'}?client=$client&amp;a=AGEGRP_L">Click here</a> to return to list of $txt_Names</p>];
	$resultHTML = $resultHTML.$text;

	return ($resultHTML,$title);
}


sub loadAgeGroupDetails {
	my($db, $id, $realmID, $realmSubType, $assocID) = @_;

  return {} if !$id;

	$realmID ||= 0;
	$realmSubType ||=0;
	$assocID ||= 0;

  my $statement=qq[
    		SELECT *
    		FROM tblAgeGroups
    		WHERE intAgeGroupID = $id 
			AND intRealmID = $realmID
			AND (intAssocID = $assocID OR intAssocID = 0)
			AND (intRealmSubTypeID IN (0,$realmSubType))
	];
	my $query = $db->prepare($statement);
	$query->execute;
	my $field=$query->fetchrow_hashref();
	$query->finish;

	foreach my $key (keys %{$field})  { 
		if(!defined $field->{$key}) {$field->{$key}='';} 
	}
	return $field;
}

sub getAgeGroups	{

	my($Data, $blankagegroups, $allagegroups)=@_;
	$blankagegroups ||= 0;
	$allagegroups ||= 0;
  my $assocID=$Data->{'clientValues'}{'assocID'} || $Defs::INVALID_ID;
  
	my $st=qq[
		SELECT intAgeGroupID, strAgeGroupDesc , intAgeGroupGender
		FROM tblAgeGroups
		WHERE intRealmID = $Data->{'Realm'}
			AND (intRealmSubTypeID IN (0, $Data->{'RealmSubType'}))
			AND intRecStatus=1
		ORDER BY dtDOBStart, strAgeGroupDesc
	]; 

	my $query = $Data->{'db'}->prepare($st);
	$query->execute();
	my $body='';
	my %AgeGroups=();
	my $maxID = 0;
	while (my ($id,$name, $intAgeGroupGender)=$query->fetchrow_array()) {
		$maxID = $id;
		my $gender = $intAgeGroupGender ? qq[- ($Defs::genderInfo{$intAgeGroupGender})] : '';
		$AgeGroups{$id}=qq[$name$gender] || '';
	}
	my $txt_AgeGroupName= $Data->{'SystemConfig'}{'txtAgeGroup'} || 'Age Group';
	my $txt_AgeGroupNames= $Data->{'SystemConfig'}{'txtAgeGroups'} || 'Age Groups';

    if ($Data->{'BlankAgeGroup'} || $blankagegroups) {
        $AgeGroups{-1} = join(
            q{},
            '--',
            $Data->{lang}->txt("No $txt_AgeGroupName"),
            '--',
        );
    }

    if ($Data->{'AllAgeGroups'} || $allagegroups) {
        $AgeGroups{-99} = join(
            q{},
            '--',
            $Data->{lang}->txt("All $txt_AgeGroupNames"),
            '--',
        );
    }

	return (\%AgeGroups, $maxID);
}

sub listAgeGroups {

	my($Data) = @_;

	my $resultHTML = '';
	my $client = unescape($Data->{client});
	my $txt_Name= $Data->{'SystemConfig'}{'txtAgeGroup'} || 'Age Group';
	my $txt_Names= $Data->{'SystemConfig'}{'txtAgeGroups'} || 'Age Groups';

  my $statement=qq[
    SELECT intAgeGroupID, strAgeGroupDesc, intAssocID,  DATE_FORMAT(dtDOBStart, '%d/%m/%Y') AS dtDOBStart,  DATE_FORMAT(dtDOBEnd, '%d/%m/%Y') AS dtDOBEnd, intRecStatus, intAgeGroupGender
    FROM tblAgeGroups
    WHERE intRealmID = ?
      AND (intAssocID = ? OR intAssocID =0)
      AND (intRealmSubTypeID IN(0, ? ))
			AND intRecStatus<>-1
    ORDER BY dtDOBStart, strAgeGroupDesc
  ];

  my $query = $Data->{'db'}->prepare($statement);
  $query->execute(
    $Data->{'Realm'},
    $Data->{'clientValues'}{'assocID'},
    $Data->{'RealmSubType'},
	);

  my %tempClientValues = getClient($client);
	my @rowdata = ();
  while (my $dref= $query->fetchrow_hashref()) {
    my $tempClient = setClient(\%tempClientValues);
    $dref->{AgeGroupGender} = $dref->{intAgeGroupGender} 
			? $Defs::genderInfo{$dref->{intAgeGroupGender}} 
			: '';
    $dref->{AddedBy} = $dref->{intAssocID} 
			? $Data->{'LevelNames'}{$Defs::LEVEL_ASSOC} 
			: $Data->{'LevelNames'}{$Defs::LEVEL_NATIONAL};
		my $link = '';
		if ($dref->{intAssocID} > 0 or $Data->{clientValues}{authLevel} == $Defs::LEVEL_NATIONAL)	{
			$link = "$Data->{'target'}?client=$tempClient&amp;a=AGEGRP_DTE&amp;ageGroupID=$dref->{intAgeGroupID}" 
		}

    push @rowdata, {
      id => $dref->{'intAgeGroupID'} || 0,
      strAgeGroupDesc => $dref->{'strAgeGroupDesc'} || '',
      AgeGroupGender => $dref->{'AgeGroupGender'} || '',
      AddedBy => $dref->{'AddedBy'} || '',
      dtDOBStart => $dref->{'dtDOBStart'} || '',
      dtDOBEnd => $dref->{'dtDOBEnd'} || '',
      intRecStatus => $dref->{'intRecStatus'} || '',
      SelectLink => $link || '',
		};
  }

  my $addlink='';
  my $title=$txt_Names;
  {
    my $tempClient = setClient(\%tempClientValues);
    $addlink=qq[<span class = "button-small generic-button"><a href="$Data->{'target'}?client=$tempClient&amp;a=AGEGRP_DTA">Add</a></span>];
    $addlink = '' if ($Data->{'SystemConfig'}{'AgeGroups_NationalOnly'} and $Data->{'clientValues'}{'authLevel'} < $Defs::LEVEL_NATIONAL);
  }

  my $modoptions=qq[<div class="changeoptions">$addlink</div>];
  $title=$modoptions.$title;

  my @headers = (
    {
      type => 'Selector',
      field => 'SelectLink',
    },
    {
      name =>   "$txt_Name Name",
      field =>  'strAgeGroupDesc',
    },
    {
      name =>   "$txt_Name Gender",
      field =>  'AgeGroupGender',
    },
    {
      name =>   $Data->{'lang'}->txt('Added By'),
      field =>  'AddedBy',
    },
    {
      name =>   $Data->{'lang'}->txt('DOB Start Range'),
      field =>  'dtDOBStart',
    },
    {
      name =>   $Data->{'lang'}->txt('DOB End Range'),
      field =>  'dtDOBEnd',
    },
    {
      name =>   'Active',
      field =>  'intRecStatus',
      editor => 'checkbox',
      type => 'tick',
    },
	);


  my $grid  = showGrid(
    Data => $Data,
    columns => \@headers,
    rowdata => \@rowdata,
    gridid => 'grid',
    width => '99%',
  );

	$resultHTML = qq[
		$grid
	];

	return ($resultHTML,$title);

}


1;
