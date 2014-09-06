package RegoForm::RegoFormBaseObj;

use strict;
use CGI qw(:cgi escape);

use lib "..","../..";
use strict;
use RegoFormSession;
use ConfigOptions;
use Logo;
use TTTemplate;
use RegoFormObj; #this is the more 'generic', uncoupled one.
use RegoFormConfigObj; #similarly uncoupled.
use RegoFormAddedObj;
use RegoFormConfigAddedObj;
use RegoFormLayoutsObj;
use RegoFormRuleObj;
use RegoFormRuleAddedObj;
use RegoFormNrsUtils;
use Reg_common;
use Log;

sub new {

  my $this   = shift;
  my $class  = ref($this) || $this;
  my %params = @_;
  my $self   = {};
  ##bless selfhash to class
  bless $self, $class;

    #Set Defaults
    $self->{'ID'}             = $params{'ID'};
    $self->{'db'}             = $params{'db'};
    $self->{'Data'}           = $params{'Data'};
    $self->{'Lang'}           = $params{'Lang'};
    $self->{'CarryFields'}    = $params{'CarryFields'}   || ();
    $self->{'SystemConfig'}   = $params{'SystemConfig'};

    $self->{'LocalConfig'}    = $params{'LocalConfig'};
    $self->{'Permissions'}    = $params{'Permissions'};
    $self->{'ClientValues'}   = $params{'ClientValues'};
    $self->{'Passport'}       = $params{'Passport'}      || 0;
    $self->{'Target'}         = $params{'Target'}        || '';
    $self->{'cgi'}            = $params{'cgi'}           || new CGI;
    $self->{'RunDetails'}     = ();
    $self->{'RunParams'}      = ();
    $self->{'CookiesToWrite'} = ();

    $self->{'DEBUG'} ||= 0;

    return undef if !$self->{'db'};
    return undef if !$self->{'ID'};
    return undef if $self->{'ID'} !~ /^\d+$/;
 
    my $earlyExit = $params{'earlyExit'} || 0;

    $self->_loadFormDetails();
    $self->loadOrgDetails();

    return $self if $earlyExit;
    $self->_loadFormText();
    $self->_loadFields();
    $self->_loadFieldRules();

    return $self;
}

sub _loadFormDetails {
    my $self = shift;

    my $st = qq[SELECT * FROM tblRegoForm WHERE intRegoFormID = ?];
    my $q = $self->{'db'}->prepare($st);
    $q->execute($self->ID());
    $self->{'DBData'} = $q->fetchrow_hashref();
    $q->finish();
}

sub ID {
  my $self = shift;
  return $self->{'ID'} || 0;
}

sub getValue  {
    my $self = shift;
    my($field)=@_;
    return $self->{'DBData'}{$field};
}

sub Name    {
    my $self = shift;
    return $self->{'DBData'}{'strRegoFormName'} || '';
}

sub Title {
    my $self = shift;
    return $self->{'DBData'}{'strTitle'} 
        || $self->{'RunDetails'}{'EntityDetails'}{'strName'} 
        || $self->{'RunDetails'}{'NationalDetails'}{'strName'} 
        || '';
}

sub formAvailable {
    my $self = shift;
    return 1 if ($self->{'DBData'}{'intStatus'} == 1);
    return 0;
}

sub FormType    {
    my $self = shift;
    return $self->{'DBData'}{'intRegoType'} || 0;
}

sub FormEntityType  {
    my $self = shift;
    my $regoType = $self->{'DBData'}{'intRegoType'};
    return 'Member' if ($regoType == $Defs::REGOFORM_TYPE_MEMBER_ASSOC or $regoType == $Defs::REGOFORM_TYPE_MEMBER_CLUB or $regoType == $Defs::REGOFORM_TYPE_MEMBER_PROGRAM);
    return '';
}

sub AssocID {
    my $self = shift;
    return $self->{'DBData'}{'intAssocID'} || 0;
}

sub ClubID  {
    my $self = shift;
    my $clubID = $self->{'RunDetails'}{'ClubID'} || $self->{'DBData'}{'intClubID'} || 0;
    $clubID = 0 if $clubID < 0;
    return $clubID;
}

sub EntityTypeID { #only used for node forms at this stage
    my $self = shift;
    return $self->{'Data'}{'nfEntityTypeID'} || 0;
}

sub EntityID { #only used for node forms at this stage
    my $self = shift;
    return $self->{'Data'}{'nfEntityID'} || 0;
}

sub RealmID {
    my $self = shift;
   return $self->{'RunDetails'}{'AssocDetails'}{'intRealmID'} || $self->{'Data'}{'Realm'};
}

sub SubRealmID {
    my $self = shift;
    return $self->{'RunDetails'}{'AssocDetails'}{'intAssocTypeID'} || 0;
}

sub ParentBodyFormID {
    my $self = shift;
    return $self->{'DBData'}{'intParentBodyFormID'} || 0;
}

sub CreatedLevel {
    my $self = shift;
    return $self->{'DBData'}{'intCreatedLevel'} || 0;
}

sub isNodeForm {
    my $self = shift;
    my $isNodeForm = ($self->{'DBData'}{'intCreatedLevel'} > $Defs::LEVEL_ASSOC) ? 1 : 0;
    return $isNodeForm;
}

sub isLinkedForm {
    my $self = shift;
    my $isLinkedForm = ($self->{'DBData'}{'intParentBodyFormID'}) ? 1 : 0;
    return $isLinkedForm;
}

sub getText {
    my $self = shift;
    my($field, $replaced) = @_;
    $replaced ||= 0;
    return '' if !$field;

    my $val = $self->{'Text'}{$field}{'value'} || '';
    if($replaced and $val !~ /<br.>/)   {
        $val =~s/\n/<br>/g;
    }
    return $val || '';
}

# --- Placeholder functions - may be overridden

sub display {
    my $self = shift;
    my($fields) = @_;

    #Setup the variables and values we are going to need
    $self->_setupRun();

    #check to see if the form is active and regoforms are allowed
    my $disabled = $self->isAllowed();
    if($disabled)   {
        return ($disabled, $self->{'CookiesToWrite'});
    }
    
    #Call function based on current process index
    my $next = 1;
    my $retvalue = '';
    my $body = '';
    while($next) {
        ($retvalue, $next) = $self->runNextFunction();
        $body .= $retvalue;
        $next = $self->incrementCurrentProcessIndex() if $next == 1;
    }
    
    return ($body, $self->{'CookiesToWrite'});
}

sub _setupRun   {
    my $self = shift;

    $self->getProcessOrder();

    my $cgi = $self->{'cgi'};
    $self->{'RunParams'} = {};
    for my $param (keys %{$cgi->Vars()}) {
        $self->{'RunParams'}{$param} = join(',', $cgi->param($param));
    }

	if(
		$self->{'RunParams'}{'eID'}
	)	{
		$self->{'RunDetails'}{'EntityID'} =  $self->{'RunParams'}{'eID'} || 0;
		$self->loadOrgDetails(); #Reload org details
	}

    $self->validateLoginKey();
    $self->loadAuthorisedEntityDetails();
    $self->setCurrentProcessIndex($self->{'RunParams'}->{'rfp'});

    $self->validateSession();
    $self->addCarryField('fID', $self->ID());
    $self->addCarryField('clubID', $self->ClubID() || 0);
    $self->addCarryField('teamID', $self->{'RunDetails'}{'TeamID'} || 0);

    $self->loadLogo();

    return 1;
}

sub Navigation {
    #May need to be overriden in child class to define correct order of steps
  my $self = shift;

    my $navstring = '';
    my $meter = '';
    my @navoptions = ();
    my $step = 1;
    my $step_in_future = 0;
    my $currentnavconfig = $self->{'ProcessOrder'}[$self->{'CurrentIndex'}][3] || '';
    return '' if $currentnavconfig eq 'NoNav';
    for my $i (0 .. $#{$self->{'ProcessOrder'}})    {
        my $current = 0;
        if($self->{'ProcessOrder'}[$i][2])  {
            $current = 1 if $i == $self->{'CurrentIndex'};
            my $name = $self->{'Lang'}->txt($self->{'ProcessOrder'}[$i][2] || '');
            push @navoptions, [
                $name,
                $current || $step_in_future || 0,
            ];
            my $currentclass = '';
            $currentclass = 'nav-currentstep' if $current;
            $currentclass = 'nav-futurestep' if $step_in_future;
            $currentclass ||= 'nav-completedstep';
            $meter = $step if $current;
            #$meter .= qq[ <span class="meter-$current"></span> ];
            $navstring .= qq[ <li class = "step step-$step $currentclass"><img src="images/tick.png" class="tick-image"><span class="step-num">$step.</span> <span class="br-mobile"><br></span>$name</li> ];
            $step_in_future = 2 if $current;
            $step++;
        }
    }
    my (undef, $multiregname,$totalreg_of_type) = $self->{'Session'}->getNextRegoType();
    my $returnHTML = '';
    $totalreg_of_type ||= 0;
    if($totalreg_of_type > 1)   {
        $multiregname .= " of $totalreg_of_type";
    }
    $returnHTML .= qq[<div class = "rego-multi-name">].$self->{'Lang'}->txt('Registering').qq[ $multiregname</div>] if $multiregname;
    $returnHTML .= qq[<ul class = "form-nav">$navstring</ul><div class="meter"><span class="meter-$meter"></span></div> ] if $navstring;
   

    if(wantarray)   {
        return ($returnHTML, \@navoptions);
    }
    return $returnHTML || '';
}

# ------------------  Process Order Management Functions

sub incrementCurrentProcessIndex    {
  my $self = shift;

    if($self->{'CurrentIndex'} < $#{$self->{'ProcessOrder'}})   {
        $self->{'CurrentIndex'}++;
        return 1;
    }
    return 0;
}

sub setCurrentProcessIndex {
  my $self = shift;
    my($index) = @_;

    if($index and $index =~ /^[a-zA-Z]+$/ and $self->{'ProcessOrderLookup'}{$index})   {
        $self->{'CurrentIndex'} = $self->{'ProcessOrderLookup'}{$index};
        return 1;
    }
    $self->{'CurrentIndex'} = 0;
    return 0;
}


sub getProcessOrder {
  my $self = shift;

    $self->setProcessOrder();
    for my $i (0 .. $#{$self->{'ProcessOrder'}})    {
        $self->{'ProcessOrderLookup'}{$self->{'ProcessOrder'}[$i][0]} = $i;
    }
}

sub setProcessOrder {
    #May need to be overriden in child class to define correct order of steps
  my $self = shift;
    #columns,
  # action key
  #function to call
    # label for navigation
    if ($self->{'SystemConfig'} and !$self->{'SystemConfig'}{'use_new_process_order'}) {
        $self->{'ProcessOrder'} = [
            ['t',  'display_choose_regotype', 'Registration Type'],
            ['vt', 'validate_choose_regotype'],
            ['i',  'display_initial_info', 'Initial Information'],
            ['vi', 'validate_initial_info'],
            ['d',  'display_form', 'Full Information'],
            ['vd', 'validate_form'],
            ['p',  'payment', 'Payment Options'],
        ];
    }
    else{
        $self->{'ProcessOrder'} = [
            ['t', \&display_choose_regotype, 'Registration Type'],
            ['vt', \&validate_choose_regotype],
            ['i', \&display_initial_info, 'Initial Information'],
            ['vi', \&validate_initial_info],
            ['d', \&display_form, 'Full Information'],
            ['vd', \&validate_form],
            ['p', \&payment, 'Payment Options'],
        ];
    }
    
}


sub runNextFunction {
  my $self = shift;

    my $retvalue = '';
    my $next = 0;
    if($self->{'ProcessOrder'}[$self->{'CurrentIndex'}]) {
        if($self->{'SystemConfig'} and $self->{'SystemConfig'}{'use_new_process_order'}) {
            my $sub_name = $self->{'ProcessOrder'}[$self->{'CurrentIndex'}][1];
            my $sub_ref = $self->can($sub_name);
            if ($sub_ref){
                ($retvalue, $next) = &$sub_ref($self); 
            }
        }
        else{
            ($retvalue, $next) = $self->{'ProcessOrder'}[$self->{'CurrentIndex'}][1]($self);
        }
    }
    return ($retvalue, $next);  
}

sub isAllowed   {
  my $self = shift;

    if($self->{'SystemConfig'} and !$self->{'SystemConfig'}{'AllowOnlineRego'})   {
        return $self->error_message('This organisation is not configured to allow online registrations');
    }
    if($self->{'RunDetails'}{'AssocDetails'} and !$self->{'RunDetails'}{'AssocDetails'}{'intAllowRegoForm'})   {
        return $self->error_message('This organisation is not configured to allow online registrations');
    }
    if(!$self->formAvailable())   {
        return $self->error_message('This form is no longer available');
    }
    return '';
}

sub validateSession {
    my $self = shift;

  my $sessionID = $self->{'cgi'}->cookie($Defs::COOKIE_REGFORMSESSION) || '';
  my $session = undef;
  if(!$sessionID) {
      $session = new RegoFormSession( FormID => $self->ID() );
      my $newsession = $session->setSessionCookie();
      push @{$self->{'CookiesToWrite'}}, $newsession;
      $sessionID = $session->id();
  }
  else  {
    #cleanup session  - 
    #if the session is not for this form, then delete all existing data for the other form
    $session = new RegoFormSession(key => $sessionID, db => $self->{'db'}, FormID => $self->ID());
    $session->cleanupForm($self->{'db'}, $self->ID());
  }
    $self->{'Session'} = $session;
}

sub _loadFormTextAssocClubForm {
    my $self = shift;

    my $st = qq[
        SELECT   
            intAssocID,
            intSubRealmID,
            strPageOneText,
            strTopText,
            strBottomText,
            strSuccessText,
            strAuthEmailText,
            strIndivRegoSelect,
            strTeamRegoSelect,
            strPaymentText,
            strTermsCondHeader,
            strTermsCondText,
            intTC_AgreeBox,
            intRegoFormID
        FROM     
            tblRegoFormConfig
        WHERE    
            (intAssocID = 0 OR intAssocID = ?)
            AND (intSubRealmID = ? OR intSubRealmID=0)
            AND intRealmID = ?
            AND intRegoFormID IN(0, ?)
        ORDER BY 
            intSubRealmID ASC, 
            intAssocID ASC, 
            intRegoFormID ASC
    ];
    my $q = $self->{'db'}->prepare($st);
    my $subtype = $self->{'RunDetails'}{'AssocDetails'}{'intAssocTypeID'} || 0;
    $q->execute($self->AssocID(), $subtype, $self->{'RunDetails'}{'AssocDetails'}{'intRealmID'}, $self->ID());

    my $textFields = _getTextFields(1);
    my $showterms = 0;
    $self->{'Text'} = ();

    while (my $dref = $q->fetchrow_hashref()) {
        $showterms = 1 if $dref->{'intTC_AgreeBox'};
        foreach my $textField (@$textFields) {
            $self->{'Text'}{$textField}{'value'} ||= $dref->{$textField};
        }
    }

    my $TC_AgreeBox_text = $self->{'SystemConfig'}{'regoform_CustomTCText'} || $self->{'Lang'}->txt('I have read and agree to the Terms and Conditions');

    if($showterms)  {
        $self->{'Text'}{'TC_AgreeBox'}{'value'} = qq[
            <input type="checkbox" value="1" name="tcagree" id="tcbox"><span class="bold"><label for="tcbox" class="tcbox">$TC_AgreeBox_text</label></span><img src="images/compulsory.gif" alt="" border=0>
        ];

        my $tcLevel = $self->CreatedLevel() ;

        if (!$tcLevel) {
            $tcLevel =  ($self->ClubID()) ? $Defs::LEVEL_CLUB : $Defs::LEVEL_ASSOC;
        }

        $self->addCarryField("tcagree_$tcLevel", -1); #set to -1 to force carryover. facilitates other end updating of tblTermsMember;.
    }
}

sub _loadFormTextNodeForm {
    my $self = shift;

    my @termsAndConditions = ();
    my $showAgreeBox       = 0;

    my $dbh    = $self->{'db'};
    my $formID = $self->ID();

    #load the t&cs for the form.
    my $regoFormConfigObj = RegoFormConfigObj->loadByRegoFormID(dbh=>$dbh, regoFormID=>$self->ID());
    my $tcLevel           = $self->CreatedLevel() ; #level will definitely be set by nature of being a node form.

    _addToTermsAndConditions($regoFormConfigObj, \@termsAndConditions, $tcLevel, $self);

    #load the added t&cs for the form
    _loadAddedTermsAndConditions($dbh, $formID, \@termsAndConditions, $tcLevel, $self);

    _processTermsAndConditions(\@termsAndConditions, $self);

    #load fields other than TCs. these will come from assoc/club form.
    my $textFields = _getTextFields();

    foreach my $textField (@$textFields) {
        $self->{'Text'}{$textField}{'value'} = $regoFormConfigObj->getValue($textField);
    }

    return 1;
}

sub _loadFormTextLinkedForm {
    my $self = shift;

    my @termsAndConditions = ();
    my $showAgreeBox       = 0;

    my $dbh    = $self->{'db'};
    my $formID = $self->ParentBodyFormID();

    #load the t&cs for the parent body form.
    my $regoFormConfigObj = RegoFormConfigObj->loadByRegoFormID(dbh=>$dbh, regoFormID=>$formID);
    my $regoFormObj       = RegoFormObj->load(db=>$self->{'db'}, ID=>$formID);
    my $tcLevel           = $regoFormObj->getValue('intCreatedLevel') || $Defs::LEVEL_NATIONAL;

    _addToTermsAndConditions($regoFormConfigObj, \@termsAndConditions, $tcLevel, $self);

    #load the added t&cs for the parent body form
    _loadAddedTermsAndConditions($dbh, $formID, \@termsAndConditions, $tcLevel, $self);

    #load the TCs for the assoc/club form.
    $formID = $self->ID();
    $regoFormConfigObj = RegoFormConfigObj->loadByRegoFormID(dbh=>$dbh, regoFormID=>$self->ID());

    $tcLevel = $self->CreatedLevel() ;
    if (!$tcLevel) {
        $tcLevel = ($self->ClubID()) ? $Defs::LEVEL_CLUB : $Defs::LEVEL_ASSOC;
    }

    _addToTermsAndConditions($regoFormConfigObj, \@termsAndConditions, $tcLevel, $self);
    
    _processTermsAndConditions(\@termsAndConditions, $self);

    #load fields other than TCs. these will come from assoc/club form.
    my $textFields = _getTextFields();

    foreach my $textField (@$textFields) {
        $self->{'Text'}{$textField}{'value'} = $regoFormConfigObj->getValue($textField);
    }

    return 1;
}

sub _loadAddedTermsAndConditions {
    my ($dbh, $formID, $termsAndConditions, $tcLevel, $self) = @_;

    my $entityStructure = getEntityStructure($self->{'Data'}, $self->EntityTypeID(), $self->EntityID(), $tcLevel, 1); #get topdown.

    foreach my $entityArr (@$entityStructure) {
        next if @$entityArr[0] >= $tcLevel; #[0] is entityTypeID, [1] is entityID. createdLevel won't have any added fields.
        my $regoFormConfigAddedObj = RegoFormConfigAddedObj->loadByFormEntityTypeEntityID(dbh=>$dbh, formID=>$formID, entityTypeID=>@$entityArr[0], entityID=>@$entityArr[1]);
        _addToTermsAndConditions($regoFormConfigAddedObj, $termsAndConditions, @$entityArr[0], $self) if $regoFormConfigAddedObj->isDefined();

    }

    return 1;
}

sub _processTermsAndConditions {
    my ($termsAndConditions, $self) = @_;

    my $showAgreeBox = 1;

    #note that the tandc class within the anchors below is used as a jquery selector in terms.templ
    if (@$termsAndConditions) {
        if ($showAgreeBox) {
            my $TC_AgreeBox_text = $self->{'SystemConfig'}{'regoform_CustomTCText'} || $self->{'Lang'}->txt('I understand that by registering I have agreed to the <% Terms and Conditions of participation %>'); #template delimiters used to isolate text for Terms and Conditions link.

            my $before = $TC_AgreeBox_text;
            my $tcLink;
            my $after;

            ($before, $tcLink, $after) = $TC_AgreeBox_text =~ /(.*)<% (.*) %>(.*)/ if $TC_AgreeBox_text =~ /<% (.*) %>/;

            $self->{'Text'}{'TC_AgreeBox'}{'value'} = qq[
                <input type="checkbox" value="1" name="tcagree" id="tcbox"><label for="tcbox"">$before</label><a class="tandc" href="#">$tcLink</a>$after <img src="images/compulsory.gif" alt="" border=0>
            ];
        }
        else {
            my $TC_text = $self->{'Lang'}->txt('Terms and Conditions');
            $self->{'Text'}{'TC_AgreeBox'}{'value'} = qq[
                <a class="tandc" href="#">$TC_text</a>
                <input type="hidden" name="tcagree" value="1">
            ];
        }
    }

    my %templateData = (termsAndConditions => $termsAndConditions);
    my $templateFile = 'regoform/common/terms.templ';
    $self->{'Text'}{'TC_js'}{'value'} = runTemplate($self->{'Data'}, \%templateData, $templateFile);


   return 1;
}

sub _addToTermsAndConditions {
    my ($regoFormConfigObj, $termsAndConditions, $tcLevel, $self) = @_;

    if ($regoFormConfigObj->getValue('strTermsCondHeader') or $regoFormConfigObj->getValue('strTermsCondText')) {
        push @$termsAndConditions, {
            strTermsCondHeader => $regoFormConfigObj->getValue('strTermsCondHeader'),
            strTermsCondText   => $regoFormConfigObj->getValue('strTermsCondText'),
        };

        $self->addCarryField("tcagree_$tcLevel", -1); #set to -1 to force carryover. check at other end to see if val changed to 1.
    }

    return;
}

sub _getTextFields {
    my ($incTCs) = @_;

    my @textFields = qw(
        strPageOneText
        strTopText
        strBottomText
        strSuccessText
        strAuthEmailText
        strIndivRegoSelect
        strTeamRegoSelect
        strPaymentText
    );

    push @textFields, qw(strTermsCondHeader strTermsCondText) if $incTCs; 

    return \@textFields;
}


sub _loadFieldsNodeLinkedForm {
    my $self = shift;

    my $regoFormObj = RegoFormLayoutsObj->load(db=>$self->{'db'}, ID=>$self->ID());
    my $layoutFields = $regoFormObj->getLayouts(Data=>$self->{'Data'}, entityTypeID=>$self->EntityTypeID(), entityID=>$self->EntityID());

    $self->{'Fields'}{'Order'} = ();
    $self->{'Fields'}{'Info'}  = ();
    $self->{'Fields'}{'Used'}  = ();

    foreach my $field (@$layoutFields ) { #already sorted
        my $fieldName   = @$field[0]; 
        my $fieldOrder  = @$field[1];
        my $fieldText   = @$field[2];
        my $fieldId     = @$field[3];
        my $fieldType   = @$field[4];
        my $fieldSource = @$field[5];
        my $fieldOwner  = @$field[6];
        my $fieldKey    = @$field[7];
        my $fieldPerm   = @$field[8];

        my $type = 'Field';
        $type = 'Header'    if $fieldType == 1;
        $type = 'TextBlock' if $fieldType == 2;

        $fieldName .= '_'.$fieldId if $type ne 'Field';

        push @{$self->{'Fields'}{'Order'}}, $fieldName;

        $self->{'Fields'}{'Used'}{$fieldName} = $#{$self->{'Fields'}{'Order'}};

        $self->{'Fields'}{'Info'}{$fieldName} = {
            type    => $type,
            perm    => $fieldPerm,
            order   => $fieldOrder,
            text    => $fieldText || '',
            source  => $fieldSource,
            fieldId => $fieldId,
        };
    }
}

sub _loadFieldsAssocClubForm {
  my $self = shift;

    my $baseFieldPermissions = undef;

    {
        #Get clubID of the owner of the form - not the current clubID
        my $clubID = $self->{'DBData'}{'intClubID'} || 0;
        
        my $etID = $clubID ? $Defs::LEVEL_CLUB : $Defs::LEVEL_ASSOC;
        my $eID = $clubID ? $clubID : $self->AssocID();

        $baseFieldPermissions = GetPermissions(
            { db => $self->{'db'}, clientValues=>{clubID=>$clubID, assocID=>$self->AssocID()} },
            $etID, $eID, $self->{'RunDetails'}{'AssocDetails'}{'intRealmID'}, $self->{'RunDetails'}{'AssocDetails'}{'intAssocTypeID'} || 0, 'regoform', 0,
        );
    }
    my $st = qq[
        SELECT   
            strFieldName, intType, intDisplayOrder, strText, strPerm, intRegoFormFieldID
        FROM      
            tblRegoFormFields
        WHERE
            intRegoFormID = ?
        ORDER BY  
            intDisplayOrder
    ];
    my $q= $self->{'db'}->prepare($st);
    $q->execute( $self->ID());

    $self->{'Fields'}{'Order'} = ();
    $self->{'Fields'}{'Info'} = ();
    $self->{'Fields'}{'Used'} = ();

    my $formentity = $self->FormEntityType();
    my %seenfield = ();

    while (my $dref = $q->fetchrow_hashref()) {
        my $fieldname = $dref->{'strFieldName'} || '';
        next if $seenfield{$fieldname};
        $seenfield{$fieldname} = 1;
        
        my $type = 'Field';
        $type = 'Header'       if $dref->{'intType'} == 1;
        $type = 'TextBlock'    if $dref->{'intType'} == 2;

        $fieldname .= '_'.$dref->{'intRegoFormFieldID'} if($type ne 'Field');

        push @{$self->{'Fields'}{'Order'}}, $fieldname;
        $self->{'Fields'}{'Used'}{$fieldname} = $#{$self->{'Fields'}{'Order'}};
        my $perm = $dref->{'strPerm'};

        #Check the governing body doesn't have a more restrictive permission
        if (!AllowPermissionUpgrade($baseFieldPermissions->{$formentity.'RegoForm'}{$fieldname}, $perm)) {
            $perm = $baseFieldPermissions->{$formentity.'RegoForm'}{$fieldname};
        }
        $self->{'Fields'}{'Info'}{$fieldname} = {
            type  => $type,
            perm  => $perm,
            order => $dref->{'intDisplayOrder'},
            text  => $dref->{'strText'} || '',
        };
    }
}

sub ProcessHTMLForm_OtherBlocks {
  my $self = shift;
    my( $FieldDefinitions) = @_;

    for my $key (keys %{$self->{'Fields'}{'Info'}}) {
        my $fieldinfo = $self->{'Fields'}{'Info'}{$key} || next;
        my $type = $fieldinfo->{'type'} || '';
        my $perm = $fieldinfo->{'perm'} || '';
        next if $perm eq 'Hidden';
        next if $type eq 'Field';
        if($type eq 'Header')   {
            $FieldDefinitions->{'fields'}{$key}{'type'} = 'htmlrow';
            $FieldDefinitions->{'fields'}{$key}{'label'} = 'textvalue';
            my $val = $fieldinfo->{'text'} || '';
            $FieldDefinitions->{'fields'}{$key}{'value'} = qq[
                <tr> <td class = "sectionheader" colspan = "2">$val</td></tr>
            ];
        }
        elsif ($type eq 'TextBlock')    {
            $FieldDefinitions->{'fields'}{$key}{'type'} = 'htmlrow';
            $FieldDefinitions->{'fields'}{$key}{'label'} = 'textvalue';
            my $val = $fieldinfo->{'text'} || '';
            if($val !~/<br>/i and $val !~/<p>/i)    {
                $val =~s/\n/<br>/g;
            }
            $FieldDefinitions->{'fields'}{$key}{'value'} = qq[
                <tr> <td colspan = "2">$val</td></tr>
            ];
        }
    }
}

sub _loadFieldRulesNodeLinkedForm {
    my $self = shift;

    my $ruleFieldnames = _getRuleFieldnames();

    $self->{'FieldRules'} = ();

    foreach my $fieldname (@{$self->{'Fields'}{'Order'}}) {
        my $added             = ($self->{'Fields'}{'Info'}{$fieldname}{'source'} >= 3) ? 'Added' : '';
        my $regoFormRuleClass = 'RegoFormRule'.$added.'Obj';
        my $rffKeyName        = 'intRegoFormField'.$added.'ID';
        my $keyName           = $regoFormRuleClass->getKeyName();
        my %where             = (intRegoFormID=>$self->ID(), $rffKeyName=>$self->{'Fields'}{'Info'}{$fieldname}{'fieldId'}, intStatus=>1);
        my $regoFormRuleObj   = $regoFormRuleClass->loadWhere(dbh=>$self->{'db'}, where=>\%where);

        if ($regoFormRuleObj->isDefined()) {
            foreach my $ruleFn(@$ruleFieldnames) {
                $self->{'FieldRules'}{$fieldname}{$ruleFn} = $regoFormRuleObj->getValue($ruleFn) || '';
            }
        }
    }
}

sub _loadFieldRulesAssocClubForm {
    my $self = shift;

    my $ruleFieldnames = _getRuleFieldnames();

    my $st = qq[
        SELECT rfr.*, rff.strFieldName, rff.intType
        FROM   tblRegoFormRules rfr
        INNER JOIN tblRegoFormFields rff ON rfr.intRegoFormFieldID=rff.intRegoFormFieldID
        WHERE  rfr.intRegoFormID = ?
    ];
    my $q = $self->{'db'}->prepare($st);
    $q->execute($self->ID());
    $self->{'FieldRules'} = ();
    while(my $dref = $q->fetchrow_hashref())    {
        my $fieldname = $dref->{'strFieldName'} || '';
        $fieldname .= '_'.$dref->{'intRegoFormFieldID'} if $dref->{'intType'} =~ /^1|2|3|4/;

        foreach my $ruleFn(@$ruleFieldnames) {
            $self->{'FieldRules'}{$fieldname}{$ruleFn} = $dref->{$ruleFn} || '';
        }
    }
}

sub _getRuleFieldnames {

    my @ruleFieldnames = qw(
        strGender
        dtMinDOB
        dtMaxDOB
        ynPlayer
        ynCoach
        ynMatchOfficial
        ynOfficial
        ynMisc
        ynVolunteer
        intProgramFilter
    );

    return \@ruleFieldnames;

}
    
sub checkForDuplicate {
  my $self = shift;

    return (0, '',);
}

sub SessionSummary  {
  my $self = shift;
    return '' if !$self->{'Session'};
    my $summary_info = $self->{'Session'}->Summary($self->{'db'});
    return '' if !$summary_info;
    return '' if !scalar(keys %{$summary_info});;

  my %PageData = ( 
        Summary => $summary_info,
        CurrencySymbol => $self->{'Data'}{'LocalConfig'}{'DollarSymbol'} || '$',
  ); 
 
  my $templatename = 'regoform/common/session_summary.templ'; 
  my $pagedata = ''; 
  if($templatename) { 
    $pagedata = runTemplate( 
      $self->{'Data'}, 
      \%PageData, 
      $templatename, 
    ); 
  } 
    return $pagedata || '';
}

sub loadLogo {
  my $self = shift;

    $self->{'FormLogo'} = showLogo(
        $self->{'Data'},
        $Defs::LEVEL_ENTITY,
        $self->EntityID,
        '',
        0,
        100,
        0,
    );
}

sub Logo    {
  my $self = shift;

    return $self->{'FormLogo'} || '';
}


# --------------- Utility functions



sub error_message   {
  my $self = shift;
    my ($msg) = @_;
    my $msg_lang = $self->{'Lang'}->txt($msg) || return '';
    return qq[
        <div class = "msg-error">$msg_lang</div>
    ];
}

sub loadOrgDetails  {
  my $self = shift;
    if($self->{'RunDetails'}{'EntityID'})    {
        my $st = qq[
            SELECT *
            FROM tblEntity
            WHERE intEntityID = ?
                AND strStatus = 'APPROVED'
        ];
        my $q = $self->{'db'}->prepare($st);
        $q->execute($self->{'RunDetails'}{'EntityID'});
        $self->{'RunDetails'}{'EntityDetails'} = $q->fetchrow_hashref();
        $q->finish();
    }
}

sub setCarryFields {
  my $self = shift;
    my($fields) = @_;
    $self->{'CarryFields'} = $fields;
}

sub deleteCarryField {
  my $self = shift;
    my($fieldname) = @_;
    return $self->addCarryField($fieldname,'');
}

sub addCarryField {
  my $self = shift;
    my($fieldname, $value) = @_;
    return 0 if !$fieldname;
    if($value)  {
        $self->{'CarryFields'}{$fieldname} = $value;
    }
    else    {
        delete $self->{'CarryFields'}{$fieldname};
    }
    return 1;
}

sub stringifyCarryField {
  my $self = shift;
    my $string = '';
    for my $k (keys %{$self->{'CarryFields'}})  {
        my $name = $k;
        my $value = $self->{'CarryFields'}{$k};
        $value = '' if !defined $value;
        $name =~s/"/\"/g;
        $value =~s/"/\"/g;
        $string .=qq[<input type = "hidden" name = "$name" value = "$value">];
    }
    return $string;
}

sub stringifyURLCarryField {
  my $self = shift;
    my $string = '';
    for my $k (keys %{$self->{'CarryFields'}})  {
        my $name = $k;
        my $value = escape($self->{'CarryFields'}{$k});
        $string .= "$name=$value&amp;";
    }
    return $string;
}

sub getCarryFields {
  my $self = shift;
    my ($fieldname) = @_;
    if($fieldname)  {
        return $self->{'CarryFields'}{$fieldname};
    }
    my %tempcarry = %{$self->{'CarryFields'}};
    return  \%tempcarry;
}

# ------------------- Stub Functions ---


sub display_choose_regotype { return ('',1);}
sub validate_choose_regotype {return ('',1);}
sub display_initial_info {return ('',1);}
sub validate_initial_info {return ('',1);}
sub display_form {return ('',1);}
sub validate_form {return ('',1);}
sub payment {return ('',1);}

sub loadAuthorisedEntityDetails{ return undef;};
sub loadPassportLinkedEntities{ return undef;};
1;
