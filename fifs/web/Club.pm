package Club;
require Exporter;
@ISA = qw(Exporter);
@EXPORT=qw(handleClub loadClubDetails);
@EXPORT_OK=qw(handleClub loadClubDetails);

use strict;
use Reg_common;
use Utils;
use HTMLForm;
use AuditLog;
use CustomFields;
use ConfigOptions qw(ProcessPermissions);
use ClubCharacteristics;
use RecordTypeFilter;
use GridDisplay;

use ServicesContacts;
use Contacts;
use Logo;
use HomeClub;
use FieldCaseRule;
use DefCodes;
use TransLog;
use Transactions;
use EntityStructure;
use WorkFlow;
use RuleMatrix;
use InstanceOf;

sub handleClub  {
  my ($action, $Data, $clubID, $typeID)=@_;

  my $resultHTML='';
  my $clubName=
  my $title='';
  $typeID=$Defs::LEVEL_CLUB if $typeID==$Defs::LEVEL_NONE;
  if ($action =~/^C_DT/) {
    #Club Details
      ($resultHTML,$title)=club_details($action, $Data, $clubID);
  }
  elsif ($action =~/C_CFG_/) {
    #Club Configuration
  }
  elsif ($action =~/^C_L/) {
        ($resultHTML,$title)=listClubs($Data, $clubID);
  }
  elsif ($action=~/^C_HOME/) {
      ($resultHTML,$title)=showClubHome($Data,$clubID);
  }
  elsif ( $action =~ /^C_TXN_/ ) {
        ( $resultHTML, $title ) = Transactions::handleTransactions( $action, $Data, $clubID, 0);
    }
  elsif ( $action =~ /^C_TXNLog/ ) {
        ( $resultHTML, $title ) = TransLog::handleTransLogs( $action, $Data, $clubID, 0);
    }


  return ($resultHTML,$title);
}


sub club_details  {
  my ($action, $Data, $clubID)=@_;

  my $option='display';
  $option='edit' if $action eq 'C_DTE' and allowedAction($Data, 'c_e');
  $option='add' if $action eq 'C_DTA' and allowedAction($Data, 'c_a');
  $clubID=0 if $option eq 'add';
  my $field=loadClubDetails($Data->{'db'}, $clubID,$Data->{'clientValues'}{'assocID'}) || ();
  my $client=setClient($Data->{'clientValues'}) || '';

  my $club_chars = getClubCharacteristicsBlock($Data, $clubID) || '';

  my $field_case_rules = get_field_case_rules({dbh=>$Data->{'db'}, client=>$client, type=>'Club'});

  my $authID = getID($Data->{'clientValues'}, $Data->{'clientValues'}{'authLevel'});

  my $paymentRequired = 0;
  if ($option eq 'add')   {
      my %Reg=();
      $Reg{'registrationNature'}='NEW';
      my $matrix_ref = getRuleMatrix($Data, $Data->{'clientValues'}{'authLevel'}, getLastEntityLevel($Data->{'clientValues'}), $Defs::LEVEL_CLUB, $field->{'strEntityType'}, 'ENTITY', \%Reg);
      $paymentRequired = $matrix_ref->{'intPaymentRequired'} || 0;
  }
  my %keyparams = (); 
  foreach my $i (keys $Data->{clientValues}){
   $keyparams{$i} = $Data->{clientValues}{$i};
  }
  my %FieldDefinitions=(
    fields=>  {
      strFIFAID => {
        label => 'FIFA ID',
        value => $field->{strFIFAID},
        type  => 'text',
        size  => '40',
        maxsize => '150',
        readonly =>($Data->{'clientValues'}{authLevel} < $Defs::LEVEL_NATIONAL),
      },
      strLocalName => {
        label => 'Name',
        value => $field->{strLocalName},
        type  => 'text',
        size  => '40',
        maxsize => '150',
      },
      strLocalShortName => {
        label => 'Short Name',
        value => $field->{strLocalShortName},
        type  => 'text',
        size  => '30',
        maxsize => '50',
      },      
      strLatinName => {
        label => 'Name (Latin)',
        value => $field->{strLatinName},
        type  => 'text',
        size  => '40',
        maxsize => '150',
      },
      strLatinShortName => {
        label => 'Short Name (Latin)',
        value => $field->{strLatinShortName},
        type  => 'text',
        size  => '30',
        maxsize => '50',
      },
      strEntityType => {
        label => "Subtype",
        value => $field->{strEntityType},
        type => 'lookup',
        options => \%Defs::clubLevelSubtype,
        firstoption => [ '', 'Select Type' ],
     },
      strStatus => {
          label => 'Status',
          value => $field->{strStatus},
          type => 'lookup',  
          options => \%Defs::entityStatus,
          readonly => $Data->{'clientValues'}{'authLevel'} >= $Defs::LEVEL_NATIONAL ? 0 : 1,
          noadd         => 1,
     },
      strContact => {
        label => 'Contact Person',
        value => $field->{strContact},
        type  => 'text',
        size  => '30',
        maxsize => '50',
      },
      strContactTitle => {
        label => 'Contact Person Title',
        value => $field->{strContactTitle},
        type  => 'text',
        size  => '30',
        maxsize => '50',
      },
      strContactEmail => {
        label => 'Contact Person Email',
        value => $field->{strContactEmail},
        type  => 'text',
        size  => '30',
        maxsize => '250',
        validate => 'EMAIL',
      },
      strContactPhone => {
        label => 'Contact Person Phone',
        value => $field->{strContactPhone},
        type  => 'text',
        size  => '30',
        maxsize => '50',
      },

      strAddress => {
        label => 'Address',
        value => $field->{strAddress},
        type  => 'text',
        size  => '40',
        maxsize => '50',
      },
      strTown => {
        label => 'Town',
        value => $field->{strTown},
        type  => 'text',
        size  => '30',
        maxsize => '50',
      },
      strRegion => {
        label => 'Region',
        value => $field->{strRegion},
        type  => 'text',
        size  => '30',
        maxsize => '50',
      },
      strISOCountry => {
        label => 'Country (ISO)',
        value => $field->{strISOCountry},
        type  => 'text',
        size  => '30',
        maxsize => '50',
      },
      strPostalCode => {
        label => 'Postal Code',
        value => $field->{strPostalCode},
        type  => 'text',
        size  => '15',
        maxsize => '15',
      },
      strPhone => {
        label => 'Phone',
        value => $field->{strPhone},
        type  => 'text',
        size  => '20',
        maxsize => '20',
      },
      strFax => {
        label => 'Fax',
        value => $field->{strFax},
        type  => 'text',
        size  => '20',
        maxsize => '20',
      },
      strEmail => {
        label => 'Email',
        value => $field->{strEmail},
        type  => 'text',
        size  => '35',
        maxsize => '250',
        validate => 'EMAIL',
      },
      strWebURL => {
        label => 'Web',
        value => $field->{strWebURL},
        type  => 'text',
        size  => '35',
        maxsize => '250',
      },
      strNotes => {
        label => 'Notes',
        value => $field->{strNotes},
        type => 'textarea',
        rows => '10',
        cols => '40',
      },
      SP1  => {
        type =>'_SPACE_',
      },
      clubcharacteristics => {
        label => 'Which of the following are appropriate to your club?',
        value => $club_chars,
        type  => 'htmlblock',
        sectionname => 'clubdetails',
        SkipProcessing => 1,
        nodisplay => 1,
      },
    },
    order => [qw(
        strFIFAID
        strLocalName
        strLocalShortName
        strLatinName
        strLatinShortName
        strEntityType
        strStatus
        dtFrom
        dtTo
        strISOCountry
        strRegion
        strPostalCode
        strTown
        strAddress
        strWebURL
        strEmail
        strPhone
        strFax
        strContactTitle
        strContactEmail
        strContactPhone
        strContact
        clubcharacteristics
    )],
    fieldtransform => {
      textcase => {
      strName => $field_case_rules->{'strName'} || '',
      }
    },
    options => {
      labelsuffix => ':',
      hideblank => 1,
      target => $Data->{'target'},
      formname => 'n_form',
      submitlabel => $Data->{'lang'}->txt('Update'),
      introtext => $Data->{'lang'}->txt('HTMLFORM_INTROTEXT'),
      NoHTML => 1, 
      updateSQL => qq[
        UPDATE tblEntity
          SET --VAL--
        WHERE intEntityID=$clubID
      ],
      addSQL => qq[
        INSERT INTO tblEntity (
            intRealmID,
            intEntityLevel,
            intCreatedByEntityID,
            intDataAccess,
            strStatus,
            --FIELDS--
         )
          VALUES (
            $Data->{'Realm'},
            $Defs::LEVEL_CLUB,
            $authID,
            $Defs::DATA_ACCESS_FULL,
            "PENDING",
             --VAL-- )
        ],
      auditFunction=> \&auditLog,
      auditAddParams => [
        $Data,
        'Add',
        'Club'
      ],
      auditEditParams => [
        $clubID,
        $Data,
        'Update',
        'Club'
      ],
      afteraddFunction => \&postClubAdd,
      afteraddParams => [$option,$Data,$Data->{'db'}],
      afterupdateFunction => \&postClubUpdate,
      afterupdateParams => [$option,$Data,$Data->{'db'}, $clubID],
      LocaleMakeText => $Data->{'lang'},
    },
    carryfields =>  {
      client => $client,
      a=> $action,
    },
  );
  my $fieldperms=$Data->{'Permissions'};

  my $clubperms=ProcessPermissions(
    $fieldperms,
    \%FieldDefinitions,
    'Club',
  );
  $clubperms->{'clubcharacteristics'} = 1;
my $resultHTML='' ;
($resultHTML, undef )=handleHTMLForm(\%FieldDefinitions, $clubperms, $option, '',$Data->{'db'});
  my $title=$field->{'strLocalName'} || '';
  my $scMenu = (allowedAction($Data, 'c_e'))
    ? getServicesContactsMenu($Data, $Defs::LEVEL_CLUB, $clubID, $Defs::SC_MENU_SHORT, $Defs::SC_MENU_CURRENT_OPTION_DETAILS)
    : '';
  my $logodisplay = '';
  my $editlink = (allowedAction($Data, 'c_e')) ? 1 : 0;
  if($option eq 'display')  {
    $resultHTML .= showContacts($Data,0, $editlink);
    my $chgoptions='';
    $chgoptions.=qq[<span class = "button-small generic-button"><a href="$Data->{'target'}?client=$client&amp;a=C_DTE">Edit $Data->{'LevelNames'}{$Defs::LEVEL_CLUB}</a></span>] if allowedAction($Data, 'c_e');

    $chgoptions=qq[<div class="changeoptions">$chgoptions</div>] if $chgoptions;
    $title=$chgoptions.$title;
    $logodisplay = showLogo(
      $Data,
      $Defs::LEVEL_CLUB,
      $clubID,
      $client,
      $editlink,
    );
  }
  $resultHTML = $scMenu.$logodisplay.$resultHTML;
  $title="Add New $Data->{'LevelNames'}{$Defs::LEVEL_CLUB}" if $option eq 'add';
  return ($resultHTML,$title);
}



sub loadClubDetails {
  my($db, $id) = @_;
                                                                                                        
  my $statement=qq[
    SELECT 
     intEntityID,
     intEntityLevel,
     intRealmID,
     strEntityType,
     strStatus,
     intRealmApproved,
     intCreatedByEntityID,
     strFIFAID,
     strLocalName,
     strLocalShortName,
     strLocalFacilityName,
     strLatinName,
     strLatinShortName,
     strLatinFacilityName,
     dtFrom,
     dtTo,
     strISOCountry,
     strRegion,
     strPostalCode,
     strTown,
     strAddress,
     strWebURL,
     strEmail,
     strPhone,
     strFax,
     strContactTitle,
     strContactEmail,
     strContactPhone,
     dtAdded,
     tTimeStamp
    FROM tblEntity
    WHERE intEntityID = ?
  ];
  my $query = $db->prepare($statement);
  $query->execute($id);
  my $field=$query->fetchrow_hashref();
  $query->finish;
                                                                                                        
  foreach my $key (keys %{$field})  { if(!defined $field->{$key}) {$field->{$key}='';} }
  return $field;
}


sub postClubAdd {
  my($id,$params,$action,$Data,$db)=@_;
  return undef if !$db;
  if($action eq 'add')  {
    if($id) {
      my $entityID = getID($Data->{'clientValues'});
      my $st=qq[
        INSERT INTO tblEntityLinks (intParentEntityID, intChildEntityID)
        VALUES (?,?)
      ];
      my $query = $db->prepare($st);
      $query->execute($entityID, $id);
      $query->finish();
        
    ### A call TO createTempEntityStructure FROM EntityStructure   ###
    createTempEntityStructure($Data); 
    ### End call to createTempEntityStructure FROM EntityStructure###
      addWorkFlowTasks($Data, 'ENTITY', 'NEW', $Data->{'clientValues'}{'authLevel'}, $id,0,0, 0);
    }

    my %clubchars = ();
    for my $k (keys %{$params})  {
      if($k =~ /^cc_cb/)  {
        my $id = $k;
        $id =~s/^cc_cb//;
        $clubchars{$id} = 1;
      }
    }
    if(scalar(keys %clubchars))  {
      updateCharacteristics(
        $Data,
        $id,
        \%clubchars,
      );
    }
    {
      my $cl=setClient($Data->{'clientValues'}) || '';
      my %cv=getClient($cl);
      $cv{'clubID'}=$id;
      $cv{'currentLevel'} = $Defs::LEVEL_CLUB;
      my $clm=setClient(\%cv);
      return (0,qq[
        <div class="OKmsg"> $Data->{'LevelNames'}{$Defs::LEVEL_CLUB} Added Successfully</div><br>
        <a href="$Data->{'target'}?client=$clm&amp;a=C_DT">Display Details for $params->{'d_strLocalName'}</a><br><br>
        <b>or</b><br><br>
        <a href="$Data->{'target'}?client=$cl&amp;a=C_DTA&amp;l=$Defs::LEVEL_CLUB">Add another $Data->{'LevelNames'}{$Defs::LEVEL_CLUB}</a>

      ]);
    }
    
  } ### end if  add
  
} ## end sub

sub postClubUpdate {
  my($id,$params,$action,$Data,$db, $clubID)=@_;
  return undef if !$db;
  $clubID ||= $id || 0;

  my %clubchars = ();
  for my $k (keys %{$params}) {
    if($k =~ /^cc_cb_/)  {
      my $id = $k;
      $id =~s/^cc_cb_//;
      $clubchars{$id} = 1;
    }
  }
  if(scalar(keys %clubchars)) {
    updateCharacteristics(
      $Data,
      $clubID,
      \%clubchars,
    );
  }

  $Data->{'cache'}->delete('swm',"ClubObj-$clubID") if $Data->{'cache'};

}

sub listClubs   {
  my($Data, $entityID) = @_;

  my $db=$Data->{'db'};
  my $resultHTML = '';

  my $lang = $Data->{'lang'};
  my %textLabels = (
      'contact' => $lang->txt('Contact'),
      'email' => $lang->txt('Email'),
      'name' => $lang->txt('Name'),
      'phone' => $lang->txt('Phone'),
  );

  my $client=setClient($Data->{'clientValues'});
  my %tempClientValues = getClient($client);
  my $currentname='';
  my @rowdata = ();
  my $statement =qq[
    SELECT 
      PN.intEntityID AS PNintEntityID, 
      CN.strLocalName, 
      CN.strContact, 
      CN.strPhone, 
      CN.strEmail, 
      CN.intEntityID AS CNintEntityID, 
      CN.intEntityLevel AS CNintEntityLevel, 
      PN.strLocalName AS PNName, 
      CN.strStatus
    FROM tblEntity AS PN 
      LEFT JOIN tblEntityLinks ON PN.intEntityID=tblEntityLinks.intParentEntityID 
      JOIN tblEntity as CN ON CN.intEntityID=tblEntityLinks.intChildEntityID
    WHERE PN.intEntityID = ?
      AND CN.strStatus <> 'DELETED'
      AND CN.intEntityLevel = $Defs::LEVEL_CLUB
      AND CN.intDataAccess>$Defs::DATA_ACCESS_NONE
    ORDER BY CN.strLocalName
  ];
  my $query = $db->prepare($statement);
  $query->execute($entityID);
  my $results=0;
  while (my $dref = $query->fetchrow_hashref) {
    $results=1;
    $tempClientValues{currentLevel} = $dref->{CNintEntityLevel};
    setClientValue(\%tempClientValues, $dref->{CNintEntityLevel}, $dref->{CNintEntityID});
    my $tempClient = setClient(\%tempClientValues);
    push @rowdata, {
      id => $dref->{'CNintEntityID'} || 0,
      strName => $dref->{'strLocalName'} || '',
      SelectLink => "$Data->{'target'}?client=$tempClient&amp;a=C_HOME",
      strContact => $dref->{'strContact'} || '',
      strPhone => $dref->{'strPhone'} || '',
      strEmail => $dref->{'strEmail'} || '',
      strStatus => $dref->{'strStatus'} || '',
      strStatusText => $Data->{'lang'}->txt($Defs::entityStatus{$dref->{'strStatus'}} || ''),
    };
  }
  $query->finish;

  my $list_instruction= $Data->{'SystemConfig'}{"ListInstruction_Club"} 
        ? qq[<div class="listinstruction">$Data->{'SystemConfig'}{"ListInstruction_Club"}</div>] 
        : '';
  $list_instruction=eval($list_instruction) if $list_instruction;

  my @headers = (
    {
      type => 'Selector',
      field => 'SelectLink',
    },
    {
      name =>   $Data->{'lang'}->txt('Name'),
      field =>  'strName',
    },
    {
      name =>   $Data->{'lang'}->txt('Contact'),
      field =>  'strContact',
    },
    {
      name =>   $Data->{'lang'}->txt('Phone'),
      field =>  'strPhone',
      width => 50,   
    },
    {
      name =>   $Data->{'lang'}->txt('Email'),
      field =>  'strEmail',
    },
    {
        name   => $Data->{'lang'}->txt('Status'),
        field  => 'strStatusText',
        width  => 30,
    },

  );
  my $filterfields = [
    {
      field => 'strName',
      elementID => 'id_textfilterfield',
      type => 'regex',
    },
    {
      field => 'strStatus',
      elementID => 'dd_actstatus',
      allvalue => 'ALL',
    }
  ];
  my $grid  = showGrid(
    Data => $Data,
    columns => \@headers,
    rowdata => \@rowdata,
    filters => $filterfields,
    gridid => 'grid',
    width => '99%',
  );
  my $rectype_options=show_recordtypes(
        $Data,
        $Data->{'lang'}->txt('Name'),
        '',
        \%Defs::entityStatus,
        { 'ALL' => $Data->{'lang'}->txt('All'), },
  ) || '';

  $resultHTML = qq[ 
      <div style="width:99%;">$rectype_options</div>
    $list_instruction
    $grid
  ];

  my $obj = getInstanceOf($Data, 'entity', $entityID);
  if($obj)   {
      $currentname = $obj->getValue('strLocalName') || '';
  }
  my $title=$Data->{'SystemConfig'}{"PageTitle_List_".$Defs::LEVEL_CLUB} 
    || "$Data->{'LevelNames'}{$Defs::LEVEL_CLUB.'_P'} in $currentname"; ###needs translation ->  WHAT in WHAT? 

  my $addlink='';
  {
      $addlink=qq[<span class = "button-small generic-button"><a href="$Data->{'target'}?client=$client&amp;a=C_DTA">].$Data->{'lang'}->txt('Add').qq[</a></span>];

  }

  my $modoptions=qq[<div class="changeoptions">$addlink</div>];
  $title=$modoptions.$title;
  
  return ($resultHTML,$title);
}
1;
