package Entity;
require Exporter;
@ISA = qw(Exporter);
@EXPORT=qw(handleEntity loadEntityDetails);
@EXPORT_OK=qw(handleEntity loadEntityDetails);

use strict;
use Reg_common;
use Utils;
use HTMLForm;
use AuditLog;
use Logo;
use GridDisplay;
use HomeEntity;


sub handleEntity  {
  my ($action, $Data, $entityID, $entityLevel)=@_;

  my $resultHTML='';
  my $entityName=
  my $title='';
  return ('','') if $entityLevel < $Defs::LEVEL_ZONE;

  if ($action =~/^E_DT/) {
    #Entity Details
      ($resultHTML,$title)=entity_details($action, $Data, $entityID, $entityLevel);
  }
  elsif ($action eq 'E_L') {
    #List Entity Children
      ($resultHTML,$title)=listEntities($Data, $entityID, $entityLevel);
  }
  elsif ($action eq 'E_HOME') {
      ($resultHTML,$title)=showEntityHome($Data, $entityID);
  }

  return ($resultHTML,$title);
}


sub entity_details  {
  my ($action, $Data, $entityID, $entityLevel)=@_;

  return '' if $entityLevel < $Defs::LEVEL_ZONE;
  my $field=loadEntityDetails($Data->{'db'}, $entityID) || ();
  my $option='display';
  $option='edit' if $action eq 'E_DTE' and $Data->{'clientValues'}{'authLevel'} >= $entityLevel;
  
  my $client=setClient($Data->{'clientValues'}) || '';
  my %FieldDefinitions=(
    fields=>  {
      strFIFAID => {
        label => 'FIFA ID',
        value => $field->{strFIFAID},
        type  => 'text',
        size  => '40',
        maxsize => '150',
        readonly =>1,
      },
      strLocalName => {
        label => 'Name',
        value => $field->{strLocalName},
        type  => 'text',
        size  => '40',
        maxsize => '150',
        readonly =>1,
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
        readonly =>1,
      },
      strLatinShortName => {
        label => 'Short Name (Latin)',
        value => $field->{strLatinShortName},
        type  => 'text',
        size  => '30',
        maxsize => '50',
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
    },
    order => [qw(
        strFIFAID strLocalName strLocalShortName strLatinName strLatinShortName dtFrom dtTo strISOCountry strRegion strPostalCode strTown strAddress strWebURL strEmail strPhone strFax strContactTitle strContactEmail strContactPhone strContact
    )],
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
                WHERE intEntityID=$entityID
            ],
      auditFunction=> \&auditLog,
      auditAddParams => [
        $Data,
        'Add',
        'Entity'
      ],
      auditEditParams => [
        $entityID,
        $Data,
        'Update',
        'Entity'
      ],
      afterupdateFunction => \&postEntityUpdate,
      afterupdateParams => [$option,$Data,$Data->{'db'}, $entityID],

      LocaleMakeText => $Data->{'lang'},
    },
    carryfields =>  {
      client => $client,
      a=> $action,
    },
  );
  my $resultHTML='';
  ($resultHTML, undef )=handleHTMLForm(\%FieldDefinitions, undef, $option, '',$Data->{'db'});
  my $title=$field->{strName};
  my $logodisplay = '';
  if($option eq 'display')  {
    my $chgoptions='';
    $chgoptions.=qq[<div style="float:right;"><a href="$Data->{'target'}?client=$client&amp;a=E_DTE"><img src="images/edit_icon.gif" border="0" alt="].$Data->{'lang'}->txt('Edit') .qq["></a></div> ] if($Data->{'clientValues'}{'authLevel'} >= $entityLevel and allowedAction($Data, 'e_e'));
    $resultHTML=$resultHTML;
    $title=$chgoptions.$title;
    my $editlink = allowedAction($Data, 'e_e') ? 1 : 0;
    $logodisplay = showLogo(
      $Data,
      $entityLevel,
      $entityID,
      $client,
      $editlink,
    );
  }

  $resultHTML = $logodisplay. $resultHTML;

  return ($resultHTML,$title);
}


sub loadEntityDetails {
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

sub postEntityUpdate {
  my($id,$params,$action,$Data,$db, $entityID)=@_;
  return undef if !$db;
  $entityID ||= $id || 0;

  $Data->{'cache'}->delete('swm',"EntityObj-$entityID") if $Data->{'cache'};

}


sub listEntities {
  my($Data, $entityID, $entityLevel) = @_;

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
  my $newentityLevel=$entityLevel;
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
      AND CN.intEntityLevel = ?
      AND CN.intDataAccess>$Defs::DATA_ACCESS_NONE
    ORDER BY CN.strLocalName
  ];
  my $query = $db->prepare($statement);
  $query->execute($entityID, $entityLevel);
  my $results=0;
  while (my $dref = $query->fetchrow_hashref) {
    $results=1;
    $currentname||=$dref->{PNName};
    $tempClientValues{currentLevel} = $dref->{CNintEntityLevel};
    setClientValue(\%tempClientValues, $dref->{CNintEntityLevel}, $dref->{CNintEntityID});
    my $tempClient = setClient(\%tempClientValues);
    push @rowdata, {
      id => $dref->{'CNintEntityID'} || 0,
      strName => $dref->{'strLocalName'} || '',
      SelectLink => "$Data->{'target'}?client=$tempClient&amp;a=E_HOME",
      strContact => $dref->{'strContact'} || '',
      strPhone => $dref->{'strPhone'} || '',
      strEmail => $dref->{'strEmail'} || '',
    };
  }
  $query->finish;

  my $list_instruction= $Data->{'SystemConfig'}{"ListInstruction_$newentityLevel"} 
        ? qq[<div class="listinstruction">$Data->{'SystemConfig'}{"ListInstruction_$newentityLevel"}</div>] 
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
  );
  
  my $grid  = showGrid(
    Data => $Data,
    columns => \@headers,
    rowdata => \@rowdata,
    gridid => 'grid',
    width => '99%',
  );

  $resultHTML = qq[ 
    $list_instruction
    $grid
  ];

  my $title=$Data->{'SystemConfig'}{"PageTitle_List_$newentityLevel"} 
    || "$Data->{'LevelNames'}{$newentityLevel.'_P'} in $currentname"; ###needs translation ->  WHAT in WHAT? 
    $title = $Data->{'lang'}->txt($title);
  return ($resultHTML,$title);
}

1;


