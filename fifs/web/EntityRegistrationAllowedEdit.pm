package EntityRegistrationAllowedEdit;
require Exporter;
@ISA = qw(Exporter);

@EXPORT = @EXPORT_OK = qw(
	handleEntityRegistrationAllowedEdit
  	rule_details
);

use strict;
use Reg_common;
use Utils;
use HTMLForm;
use AuditLog;
use CGI qw(unescape param);
use FormHelpers;
use GridDisplay;
use Log;
use RegistrationAllowed;
#imported RegistrationAllowed
require RecordTypeFilter;


# This program edits the rules that determine what types of registration each entity will accept
# It maintains tblEntityRegistrationAllowed

sub handleEntityRegistrationAllowedEdit    {
    my ($action, $Data)=@_;

    my $resultHTML='';
    my $title='';
    my $intEntityRegistrationAllowedID = safe_param('RID','number') || '0';
    
    if ($action =~/^ERA_ADD/) {
        ($resultHTML,$title) = rule_details($action, $Data,$intEntityRegistrationAllowedID);
    }
    elsif ($action =~/^ERA_DELETE/) {
        ($resultHTML,$title) = rule_details($action, $Data,$intEntityRegistrationAllowedID);
    }
    else {
        #List Rules
        my $tempResultHTML = '';
        ($tempResultHTML,$title) = listRules($Data);
        $resultHTML .= $tempResultHTML;
    };
        
    return ($resultHTML,$title);
}

sub rule_details   {
    my ($action, $Data, $intEntityRegistrationAllowedID)=@_;

	# Check for change of QS    return '' if ($venueID and !venueAllowed($Data, $venueID));

	my $db = $Data->{db};
	my $option = '';
	if ($action eq 'ERA_ADD') {
		$option = 'add';
	}
	elsif($action eq 'ERA_DELETE'){ 
		$option = 'delete';
	}
	
    #	else {
    #		$option = 'delete';
    #	};

    # $option='edit' if $action eq 'VENUE_DTE' and allowedAction($Data, 'venue_e');
    # $option='add' if $action eq 'VENUE_DTA' and allowedAction($Data, 'venue_a');
    # $intEntityRegistrationAllowedID = 0 if $option eq 'add';

    my $client = setClient($Data->{'clientValues'}) || '';
    my $entityID = getID($Data->{'clientValues'},$Data->{'clientValues'}{'currentLevel'});

    my $field = loadRuleDetails($Data->{'db'}, $Data, $intEntityRegistrationAllowedID) || ();
    #changed the last parameter from $entityID to $intEntityRegistrationAllowedID
    
    my %genderoptions = ();
    for my $k ( keys %Defs::PersonGenderInfo ) {
        next if !$k;
        next if ($k eq $Defs::GENDER_NONE );
        $genderoptions{$k} = $Defs::PersonGenderInfo{$k} || '';
    }
        
    ### Move variable declarations here ###
    my %FieldDefinitions;
    my $resultHTML='';
    my $title;
    if($option eq 'add'){
         %FieldDefinitions = (
           fields=>  {
             strPersonType => {
               label => 'Person Type',
               value => $field->{strPersonType},
               type  => 'lookup',
               options     => \%Defs::personType,
               sectionname => 'details',
                compulsory=>1,
               firstoption => [ '', " " ],
             },
             strSport=> {
               label=> 'Sport',
               value => $field->{strSport},
               type  => 'lookup',
               options     => \%Defs::sportType,
       	sectionname => 'details',
               firstoption => [ '', " " ],
                compulsory=>1,
             },
               intGender => {
                       label       => 'Gender',
                       value       => $field->{intGender},
                       type        => 'lookup',
                       options     => \%genderoptions,
                       sectionname => 'details',
                       firstoption => [ '', " " ],
                compulsory=>1,
             },
             strPersonLevel => {
               label => 'Person Level',
               value => $field->{strPersonLevel},
               type  => 'lookup',
       	       options     => \%Defs::personLevel,
               sectionname => 'details',
               firstoption => [ '', " " ],
                compulsory=>1,
             },      
             strRegistrationNature => {
               label => 'Registration Nature',
               value => $field->{strRegistrationNature},
               type  => 'lookup',
       	       options     => \%Defs::registrationNature,
       	       sectionname => 'details',
               firstoption => [ '', " " ],
             },
             strAgeLevel => {
               label => 'Age Level',
               value => $field->{strAgeLevel},
               type  => 'lookup',
              	options     => \%Defs::ageLevel,
              	sectionname => 'details',
               firstoption => [ '', " " ],
                compulsory=>1,
             },
        },
        order => [qw(
    		strPersonType
    		strSport
                intGender
    		strPersonLevel
    		strAgeLevel
        )],
        sections => [ 
            [ 'details', "Registration Details" ], 
        ],
        options => {
          labelsuffix => ':',
          hideblank => 1,
          target => $Data->{'target'},
          formname => 'n_form',
          submitlabel => $Data->{'lang'}->txt('Update'),
          introtext => $Data->{'lang'}->txt('HTMLFORM_INTROTEXT'),
          NoHTML => 1, 
          beforeaddFunction => \&isRegoAllowedToSystem,
          beforeaddParams => [$Data, $Data->{'clientValues'}{'authLevel'}, $field->{strRegistrationNature}, $Data->{'clientValues'}{'currentLevel'}],
          addSQL => qq[
              INSERT IGNORE INTO tblEntityRegistrationAllowed (
                  intRealmID,
                  intSubRealmID,
                  intEntityID, 
                  --FIELDS-- 
              )
              VALUES (
                  $Data->{'Realm'},
                  $Data->{'RealmSubType'},
                  $entityID, 
                  --VAL-- 
              )
          ],
          auditFunction=> \&auditLog,
          auditAddParams => [
            $Data,
            'Add',
            'Rule'
          ],
    
          afteraddFunction => \&postRuleAdd,
          afteraddParams => [$option,$Data,$Data->{'db'}],
    
          LocaleMakeText => $Data->{'lang'},
        },
        carryfields =>  {
          client => $client,
          a=> $action,
        },
  );
    $resultHTML='';
   ($resultHTML, undef )=handleHTMLForm(\%FieldDefinitions, undef, $option, '',$Data->{'db'});
    $title=qq[Registration Accepted];
    }
    ##### DELETING A RULE ####
    elsif($option eq 'delete'){ 
                                                                                                             
       my $statement=qq[ DELETE FROM tblEntityRegistrationAllowed WHERE intEntityRegistrationAllowedID = ? AND intEntityID = ? ];
       my $query = $db->prepare($statement);
       $query -> execute($intEntityRegistrationAllowedID,$entityID);
       $query->finish();
       $title = $Data->{lang}->txt("Registration Rule Deleted");
     
   } #### END ELSEIF  (FOR DELETING A RULE) ###
    
    
    #my $chgoptions='';
    
    # if($option eq 'display')  {
        # Edit Venue.
    #    $chgoptions.=qq[<span class = "button-small generic-button"><a href="$Data->{'target'}?client=$client&amp;a=VENUE_DTE&amp;venueID=$venueID">Edit Venue</a></span> ] if allowedAction($Data, 'venue_e');
    #}
    #if ($option eq 'delete') {
    # Delete Venue.
    #    my $ruleObj = new EntityObj('db'=>$Data->{db},ID=>$intEntityRegistrationAllowedID);
        
    #    $chgoptions.=qq[<span class = "button-small generic-button"><a href="$Data->{'target'}?client=$client&amp;a=ERA_DELETE&amp;venueID=$intEntityRegistrationAllowedID" onclick="return confirm('Are you sure you want to delete this venue');">Delete Rule</a> ] if $ruleObj->canDelete();
    #}
    
    #$chgoptions=qq[<div class="changeoptions">$chgoptions</div>] if $chgoptions;
    
    #$title=$chgoptions.$title;
    
    if ($option eq 'add') {
	    $title=$Data->{lang}->txt("Add New Registration Type");     	
    }
    my $text = qq[<p style = "clear:both;"><a href="$Data->{'target'}?client=$client&amp;a=ERA_LIST"> ] . $Data->{lang}->txt("Click here") . q[</a> ] . $Data->{lang}->txt("to return to list of current registration types accepted") . q[</p>];
     
    if($option eq 'delete'){
       my $delMsg = q[ <div class="OKmsg"> ] . $Data->{lang}->txt("Registration rule deleted"). q[ </div><br> ];
       $resultHTML = $text.$resultHTML.$delMsg.$text;
    }
    else {
       $resultHTML = $text.$resultHTML.$text;
    }
   

    return ($resultHTML,$title);
}

sub loadRuleDetails {
  my($db, $Data, $intEntityRegistrationAllowedID) = @_;
                       
  my $entityID = getID($Data->{'clientValues'},$Data->{'clientValues'}{'currentLevel'});                       
                                                                                                        
  my $statement=qq[
    SELECT 
		strPersonType,
		strSport,
		strPersonLevel,
		strRegistrationNature,
                intGender,
		strAgeLevel
    FROM tblEntityRegistrationAllowed
    WHERE intEntityRegistrationAllowedID = ?
    	and intEntityID = ?
  ];
  my $query = $db->prepare($statement);
  $query -> execute(
  	$intEntityRegistrationAllowedID,
  	$entityID,
  	 );
  my $field=$query->fetchrow_hashref();
  $query->finish;
                                                                                                        
  foreach my $key (keys %{$field}){ 
       if(!defined $field->{$key}){ 
           $field->{$key}='';          
       } 
        
 }
  return $field;
}

sub listRules  {
    my($Data) = @_;

	my $body = '';
   	my $st = '';
	my $q = '';
	my $db = $Data->{'db'};
	my $entityID = getID($Data->{'clientValues'},$Data->{'clientValues'}{'currentLevel'});

    $st =qq[
      SELECT 
        intEntityRegistrationAllowedID,
        strPersonType,
        strSport,
        intGender,
        strPersonLevel,
        strRegistrationNature,
        strAgeLevel
      FROM tblEntityRegistrationAllowed 
      WHERE intEntityID = ?
      ORDER BY strPersonType, strSport, strPersonLevel, strRegistrationNature, strAgeLevel
    ];
    
	$q = $db->prepare($st) or query_error($st);
	$q->execute($entityID);
        my $results = 0;
        my @rowdata = ();
    
    while (my $dref = $q->fetchrow_hashref) {
      $results = 1;     
      push @rowdata, {
        id => $dref->{'intEntityRegistrationAllowedID'} || 0,
        strPersonType => $dref->{'strPersonType'} || '',
        strSport => $dref->{'strSport'} || '',
        Gender => $Defs::genderInfo{$dref->{'intGender'}} || '',
        strPersonLevel => $dref->{'strPersonLevel'} || '',
        strAgeLevel => $dref->{'strAgeLevel'} || '',
        DeleteLink => qq[<span class = "button-small generic-button"><a href="$Data->{'target'}?client=$Data->{client}&amp;a=ERA_DELETE&amp;RID=$dref->{'intEntityRegistrationAllowedID'}" onclick="return confirm('Are you sure you want to delete this rule');">] . $Data->{'lang'}->txt("Delete Rule") . q [ </a></span> ],
      };
    }
    $q->finish;

	#PP add to language file
    my $addlink = qq[<span class = "button-small generic-button"><a href="$Data->{'target'}?client=$Data->{client}&amp;a=ERA_ADD">] . $Data->{'lang'}->txt("Add new Rule") . q[ </a></span> ];
    my $title = $Data->{lang}->txt("Registrations accepted by my organisation");
 
    my $modoptions = qq[<div class="changeoptions">$addlink</div>];
    $title=$modoptions.$title;
    my $rectype_options = '';

    my @headers = (
        {
            name  => $Data->{'lang'}->txt('PersonType'),
            field => 'strPersonType',
        },
        {
            name  => $Data->{'lang'}->txt('Sport'),
            field => 'strSport',
        },
        {
            name  => $Data->{'lang'}->txt('PersonLevel'),
            field => 'strPersonLevel',
        },
        {
            name  => $Data->{'lang'}->txt('AgeLevel'),
            field => 'strAgeLevel',
        },
        {
            name  => $Data->{'lang'}->txt('Gender'),
            field => 'Gender',
        },
        {
            name =>   $Data->{'lang'}->txt(' '),
     	    field =>  'DeleteLink',
	    type => 'HTML',         
        },
    );
    

    my $grid  = showGrid(
        Data    => $Data,
        columns => \@headers,
        rowdata => \@rowdata,
        gridid  => 'grid',
        width   => '99%',
    );

    $body = qq[
        <div class="grid-filter-wrap">
            <div style="width:99%;">$rectype_options</div>
            $grid
        </div>
    ];

    return ($body,$title);
}

sub postRuleAdd {
  my($id,$params,$action,$Data,$db)=@_;
  return undef if !$db;
  
  #PP Check to see if this is valid, ie if it already exists, return an error message
  
  if($action eq 'add')  {

    {
      my $client = setClient($Data->{'clientValues'}) || '';

      return (0,q[
        <div class="OKmsg"> ] . $Data->{lang}->txt("Registration type added successfully") . qq[ </div><br>
        <a href="$Data->{'target'}?client=$client&amp;a=ERA_List"> ] . $Data->{lang}->txt("Add another Registration Type") . q[ </a>

      ]);
    }
    
  }
  else {
  	 {
	      my $client = setClient($Data->{'clientValues'}) || '';
	
	      return (0,qq[
	        <div class="OKmsg"> $Data->{lang}->txt("Registration rule deleted.") </div><br>
	        <a href="$Data->{'target'}?client=$client&amp;a=ERA_List">$Data->{lang}->txt("Add another Registration Type")</a>
	
	      ]);
    }
  }
}


sub ruleAllowed    {
    #Check if this user is allowed access to this entity
    my ($Data, $venueID) = @_;

    #Get parent entity and check that the user has access to that

    return 0 if !$Data->{'clientValues'}{'currentLevel'} == $Defs::LEVEL_VENUE;
    my $st = qq[
        SELECT
            intParentEntityID
        FROM
            tblEntityLinks AS EL
                INNER JOIN tblEntity AS E
                    ON EL.intChildEntityID = E.intEntityID
        WHERE
            intChildEntityID = ?
            AND intEntityLevel = $Defs::LEVEL_VENUE
        LIMIT 1
    ];
    my $query = $Data->{'db'}->prepare($st);
    $query->execute($venueID);
    my ($parentID) = $query->fetchrow_array();
    $query->finish();
    return 0 if !$parentID;
    my $authID = getID($Data->{'clientValues'}, $Data->{'clientValues'}{'authLevel'});
    return 1 if($authID== $parentID);
    $st = qq[
        SELECT
            intRealmID
        FROM
            tblTempEntityStructure
        WHERE
            intParentID = ?
            AND intChildID = ?
            AND intDataAccess = $Defs::DATA_ACCESS_FULL
        LIMIT 1
    ];
    $query = $Data->{'db'}->prepare($st);
    $query->execute($authID, $parentID);
    my ($found) = $query->fetchrow_array();
    $query->finish();
    return $found ? 1 : 0;
}
1;


