#
# $Header: svn://svn/SWM/trunk/web/RegoForm/RegoForm_Member.pm 11625 2014-05-21 01:53:42Z sliu $
#

package RegoForm::RegoForm_Member;

use strict;
use lib '.', '..', '../..', "../comp", '../RegoForm', "../dashboard", "../RegoFormBuilder",'../PaymentSplit', "../user";
use RegoForm::RegoFormBaseObj;
our @ISA =qw(RegoForm::RegoFormBaseObj);

use TTTemplate;
use CGI;
use HTML::FillInForm;
use Date::Calc;
use Person;
use ConfigOptions;
use HTMLForm;
use RegoForm_Common;
use RegoForm_Products;
use RegoForm_MemberFunctions;
use RegoForm_Auth;
use RegoForm_Notifications;
use RegoForm_MemberPasswordReminder;
use PassportLink;
use FormHelpers;
use InstanceOf;
use PrimaryClub;
use DuplicatePrevention;
use List::Util qw/first/;
use Log;
use Data::Dumper;

sub setProcessOrder {
    my $self = shift;
  
    if ($self->{'SystemConfig'} and $self->{'SystemConfig'}{'use_new_process_order'}) {
        $self->{'ProcessOrder'} = [
            ['t',  'display_choose_regotype', 'Choose Type'],
            ['vt', 'validate_choose_regotype', '','NoNav'],
            ['i',  'display_initial_info', 'Basic Info'],
            ['vi', 'validate_initial_info'],
            ['d',  'display_form', 'Extra Info'],
            ['vd', 'validate_form'],
            ['p',  'payment', 'Summary'],
        ];
        if ($self->getValue('intAllowMultipleAdult') or $self->getValue('intAllowMultipleChild')) {
            unshift @{$self->{'ProcessOrder'}}, ['vm', 'validate_choose_multi', '', ''];
            unshift @{$self->{'ProcessOrder'}}, ['m', 'display_choose_multi', '', 'NoNav'];
        }
    }
    else{
        $self->{'ProcessOrder'} = [
            ['t', \&display_choose_regotype, 'Choose Type'],
            ['vt', \&validate_choose_regotype, '','NoNav'],
            ['i', \&display_initial_info, 'Basic Info'],
            ['vi', \&validate_initial_info],
            ['d', \&display_form, 'Extra Info'],
            ['vd', \&validate_form],
            ['p', \&payment, 'Summary'],
        ];
        if ($self->getValue('intAllowMultipleAdult') or $self->getValue('intAllowMultipleChild')) {
            unshift @{$self->{'ProcessOrder'}}, ['vm', \&validate_choose_multi, '', ''];
            unshift @{$self->{'ProcessOrder'}}, ['m', \&display_choose_multi, '', 'NoNav'];
        }
    }
}

sub display_choose_multi { 
    my $self = shift;

    my %PageData = (
        HiddenFields => $self->stringifyCarryField(),
        Target => $self->{'Data'}{'target'},
        AssocID => $self->AssocID(),
        FormID => $self->ID(),
        MultiAdult => $self->getValue('intAllowMultipleAdult') || 0,
        MultiChild => $self->getValue('intAllowMultipleChild') || 0,
        Errors => $self->{'RunDetails'}{'Errors'} || [],
        CompulsoryPayment => $self->getValue('intPaymentCompulsory') || 0,
    );

    my $templatename = 'regoform/common/choose_multiple.templ';
    my $pagedata = '';
    if($templatename)   {
        $pagedata = runTemplate($self->{'Data'}, \%PageData, $templatename);
    }

    return ($pagedata,0);

}

sub validate_choose_multi {
    my $self = shift;

    my $numadults = $self->{'RunParams'}{'num_adults'} || 0;
    my $numchild = $self->{'RunParams'}{'num_child'} || 0;

    my $session = $self->{'Session'};
    $session->cleanupForm($self->{'db'}, -1,); #Reset session
    $session->addToSession(db => $self->{'db'}, FormID => $self->ID());
    $session->setTotalNumbers($self->{'db'}, $numadults,$numchild);
    if(!$numadults and !$numchild)  {
        push @{$self->{'RunDetails'}{'Errors'}}, $self->{'Lang'}->txt('You must select how many people you are registering.');
    }

    if($self->{'RunDetails'}{'Errors'}) {
        #There are errors - reset where we are to go back to the form again
        $self->setCurrentProcessIndex('m');
        return ('',2);
    }
    return ('',1);
}

sub display_choose_regotype { 
    my $self = shift;

    my $NewRegosAllowed = $self->NewMemberRegosAllowed();
    my $hideNewButton = $self->AssocHideBtn();
    my $cartmembers = '';
    my $PassportEntities = $self->loadPassportLinkedEntities();
    my @PassportEntities = ();
    my $usePassportFeature =  $self->{'Data'}{'SystemConfig'}{'usePassportInRegos'};
    for my $i (sort {$PassportEntities->{$a}{'name'} cmp $PassportEntities->{$b}{'name'} } keys %{$PassportEntities})   {
        push @PassportEntities, {
            id => $i,
            name => $PassportEntities->{$i}{'name'} || '',
            problem => $PassportEntities->{$i}{'problem'} || '',
        };
    }
    
    my $passportID = $self->{'Passport'} ? $self->{'Passport'}->id() : 0;
    my $LevelName_Club = $self->{'Data'}->{'LevelNames'}{$Defs::LEVEL_CLUB};
    my %PageData = (
        FormTitle             => $self->{'DBData'}{'strTitle'} || '',
        LevelName_Club        => $self->{'Data'}->{'LevelNames'}{$Defs::LEVEL_CLUB},
        LevelName_Program     => 'Program',
        AssocName             => $self->{'RunDetails'}{'AssocDetails'}{'strName'} || '',
        ClubName              => $self->{'RunDetails'}{'ClubDetails'}{'strName'} || '',
        TopText               => $self->getText('strIndivRegoSelect',1) || '',
        AllowNewRegos         => $NewRegosAllowed,
        HiddenFields          => $self->stringifyCarryField(),
        HiddenFieldsString    => $self->stringifyURLCarryField(),
        Target                => $self->{'Data'}{'target'},
        HideNewButton         => $hideNewButton,
        AssocID               => $self->AssocID(),
        ClubID                => $self->ClubID(),
        FormID                => $self->ID(),
        ExistingMemberTitle   => $self->{'SystemConfig'}{'rego_txtExistingTitle'} || 'Existing Individual',
        SystemNoNewMembers    => $self->{'SystemConfig'}{'regoNO_NEW'} || 0,
        SystemNewCodeRequired => $self->{'SystemConfig'}{'rego_NewCodeRequired'} || 0,
        NewMemberTitle        => $self->{'SystemConfig'}{'rego_txtNewButtonTitle'} || 'New Individual',
        NewMemberText         => $self->{'SystemConfig'}{'rego_txtNewButtonBlob'} || '',
        NewButtonText         => $self->{'SystemConfig'}{'rego_txtNewButton'} || 'New Individual Sign-up',
        NewCodeTitle          => $self->{'SystemConfig'}{'rego_txtNewCodeButtonTitle'} || 'New Individual',
        NewCodeText           => $self->{'SystemConfig'}{'rego_txtNewCodeButtonBlob'} || '',
        NewCodeButtonText     => $self->{'SystemConfig'}{'rego_txtNewCodeButton'} ||  'New Individual Sign-up',
        CartMembers           => $cartmembers,
        TeamCode              => $self->{'RunParams'}{'teamcode'} || '',
        ClubList              => $self->_getAssocClubList(),
        Errors                => $self->{'RunDetails'}{'Errors'} || [],
        MultiRegName          => $self->{'Session'}->getNextRegoType() || '',
        MultipleMemberNumber  => $self->{'Session'}->getSessionSequenceNumber(),
        PassportID            => $passportID || 0,
        PassportEntities      => \@PassportEntities,
        PassportLoginURL      => passportURL( {}, {}, 'login'),
        PassportSignupURL     => passportURL( {}, {}, 'signup'),
        CompulsoryPayment     => $self->getValue('intPaymentCompulsory') || 0,
        usePassportFeature    => $usePassportFeature,
        NewRegoTitle_CLUB     => $self->{'SystemConfig'}{'rego_NewRegoTitle_CLUB'} || qq[I am registering to this $LevelName_Club for the first time],
        NewRegoTitle_ASSOC     => $self->{'SystemConfig'}{'rego_NewRegoTitle_ASSOC'} || 'I am registering for the first time',
        ReturningRegoTitle_CLUB     => $self->{'SystemConfig'}{'rego_ReturningRegoTitle_CLUB'} || qq[I have played in this $LevelName_Club before and have my username and password],
        ReturningRegoTitle_ASSOC     => $self->{'SystemConfig'}{'rego_ReturningRegoTitle_ASSOC'} ||qq[I have registered previously and I know my username and password],
    	NewRegoTitle_PROGRAM  => $self->{'SystemConfig'}{'rego_NewRegoTitle_PROGRAM'} || qq[I am registering to this Program for the first time],
        NewReturningRegoTitle_PROGRAM  => $self->{'SystemConfig'}{'rego_NewReturningRegoTitle_PROGRAM'} || qq[I am returning to this Program],
    );

    my $templatename = '';
    my $formtype = $self->FormType();
    if($formtype == $Defs::REGOFORM_TYPE_MEMBER_ASSOC) {
        $templatename = $usePassportFeature? 'regoform/member-to-assoc/welcome.templ':'regoform/member-to-assoc/welcomeNoPassport.templ' ;
    }
    elsif($formtype == $Defs::REGOFORM_TYPE_MEMBER_TEAM) {
        $templatename = $usePassportFeature? 'regoform/member-to-team/welcome.templ': 'regoform/member-to-team/welcomeNoPassport.templ';
    }
    elsif($formtype == $Defs::REGOFORM_TYPE_MEMBER_CLUB) {
        $templatename = $usePassportFeature?'regoform/member-to-club/welcome.templ':'regoform/member-to-club/welcomeNoPassport.templ';
    }
    elsif($formtype == $Defs::REGOFORM_TYPE_MEMBER_PROGRAM) {
        $templatename = 'regoform/member-to-program/welcomeNoPassport.templ';
    }
    
    my $pagedata = '';
    if($templatename)   {
        $pagedata = runTemplate(
            $self->{'Data'},
            \%PageData,
            $templatename,
        );
    }

    return ($pagedata,0);
}

sub validate_choose_regotype {
    my $self = shift;

    my $action = $self->{'RunParams'}{'a'} || '';
    my $formtype = $self->FormType();
    if($action eq 'LOGIN')  {
    #Handle Login
        my $username = $self->{'RunParams'}{'d_username'} || '';
        my $password = $self->{'RunParams'}{'d_password'} || '';
        my $passport_linkedMemberID = $self->{'RunParams'}{'d_ppmID'} || 0;

        my $key = '';
        if(
            ($username and $password)
            or ( $passport_linkedMemberID and $self->{'Passport'})
        )   {
            my $passportID = $self->{'Passport'} ? $self->{'Passport'}->id() : 0;
            $key = $self->generateLoginKey(
                $username,
                $password,
                $passport_linkedMemberID,
                $passportID,
            );
        }
        if($key)    {
            $self->{'AuthKey'} = $key;
            $self->validateLoginKey();
            $self->loadAuthorisedEntityDetails();
        }
        else    {
            push @{$self->{'RunDetails'}{'Errors'}}, 
                $self->{'Lang'}->txt('Please check your supplied username and password and try again.');
        }
    }
    elsif($action eq 'PWD') {
        my $retvalue = $self->HandlePasswordReminder();
        $self->setCurrentProcessIndex('vt');
        return ($retvalue,0);
    }
    elsif($action eq 'RETURNING') {
        $self->addCarryField('program_returning', 1);
        $action = 'NEW';
    }
    elsif($action eq 'NEW') {
        $self->addCarryField('program_new', 1);
    }
    else
    {
        $self->addCarryField('UseNewCode',1);
        $self->addCarryField('newCode',$self->{'RunParams'}{'newCode'});
    }
    if($self->{'RunParams'}{'d_teamcode'})  {
        my $teamcode = $self->{'RunParams'}{'d_teamcode'} || 0;
        my ($teamID, undef) = $self->getTeamCodeID($teamcode);

        if($teamID) {
            $self->addCarryField('teamID',$teamID);
            $self->addCarryField('teamcode',"2".$teamID);
            $self->{'RunDetails'}{'TeamID'} =  $teamID || 0;
            $self->{'RunParams'}{'teamcode'} =  "2".$teamID || 0;
            $self->loadOrgDetails(); #Reload org details
        }
        elsif ($formtype == $Defs::REGOFORM_TYPE_MEMBER_TEAM) {
            push @{$self->{'RunDetails'}{'Errors'}}, $self->{'Lang'}->txt('You must enter a valid team code');
        }
    }
    if($formtype == $Defs::REGOFORM_TYPE_MEMBER_TEAM and !$self->{'RunParams'}{'d_teamcode'})    {
        push @{$self->{'RunDetails'}{'Errors'}}, $self->{'Lang'}->txt('You must enter a team code');
    }

    if($self->{'RunDetails'}{'Errors'}) {
        #There are errors - reset where we are to go back to the form again
        $self->setCurrentProcessIndex('t');
        return ('',2);
    }

    return ('',1);
}

sub display_initial_info {
    my $self = shift;
    my $Data = $self->{'Data'};
    my $usePassportFeature =  $self->{'Data'}{'SystemConfig'}{'usePassportInRegos'};


    #Make sure the fields have the right permissions
    
    my $memberdetails = $self->{'EntityDetails'} || undef;

    my $firstname_permission = $self->{'Fields'}{'Info'}{'strFirstname'}{'perm'} || 'Compulsory';
    my $surname_permission   = $self->{'Fields'}{'Info'}{'strSurname'}{'perm'}   || 'Compulsory';
    my $dob_permission       = $self->{'Fields'}{'Info'}{'dtDOB'}{'perm'}        || 'Compulsory';
    my $gender_permission    = $self->{'Fields'}{'Info'}{'intGender'}{'perm'}    || 'Compulsory';

    if ($firstname_permission eq 'AddOnlyCompulsory' and $self->{'RunDetails'}{'ReRegister'}) {
        $firstname_permission = 'ReadOnly';
    }
    if ($surname_permission eq 'AddOnlyCompulsory')  {
        $surname_permission = $self->{'RunDetails'}{'ReRegister'} ? 'ReadOnly' : 'Compulsory';
    }
    if ($dob_permission eq 'AddOnlyCompulsory') {
        $dob_permission = $self->{'RunDetails'}{'ReRegister'} ? 'ReadOnly' : 'Compulsory';
    }
    if ($gender_permission eq 'AddOnlyCompulsory') {
        $gender_permission = $self->{'RunDetails'}{'ReRegister'} ? 'ReadOnly' : 'Compulsory';
    }

    my $show_type_question = 0;

    if ($self->getValue('intAllowMultipleAdult') and $self->getValue('intAllowMultipleChild'))   {
        my $nexttype = ($self->{'Session'}->getNextRegoType())[1] || '';
        $show_type_question = 1 if !$nexttype;
    }
    
    my $types = $self->getAllMemberTypes();
    my @typedata = ();
    for my $type (@{$types})    {
        if($self->{'DBData'}{$type->[0]}
            and $self->{'DBData'}{$type->[0]} eq 'Y')   {
            push @typedata, {
                field => $type->[0],
                name => $type->[1],
                seasonfield => $type->[2],
            };
        }
    }

    # get allowed member record type list
    # TODO: get mrt list from current level? or regoform level?
    my $valid_member_record_types = {};

    my %existingtypes = ();
    my $memberID = $memberdetails ?  $memberdetails->{'intMemberID'} || 0 : 0;
    setMemberTypes($self->{'Data'}, \%existingtypes, $memberID, $self->AssocID(), 0, 1,);
    my %PassportPrefilDetails = ();
    my $passportID = $self->{'Passport'} ? $self->{'Passport'}->id() : 0;

    if ($usePassportFeature){
        if (!$memberID and $self->{'Passport'})  {
            my $passport = $self->{'Passport'};
            %PassportPrefilDetails = (
                FirstName => $passport->name(),
                FamilyName => $passport->getInfo('FamilyName') || '',
            );
            my $gender = $passport->getInfo('Gender') || '';
            $PassportPrefilDetails{'Gender'} = 1 if $gender eq 'M';
            $PassportPrefilDetails{'Gender'} = 2 if $gender eq 'F';
            my $dob = $passport->getInfo('DOB') || '';
            if($dob) {
                my ($y,$m,$d) = split /-/,$dob;
                $PassportPrefilDetails{'DOB_Y'} = $y;
                $PassportPrefilDetails{'DOB_M'} = $m;
                $PassportPrefilDetails{'DOB_D'} = $d;
            }
        }
    }

    my $teamsummary = '';
    my $compID      = 0; 
    my $compSelect  = '';
    if($self->FormType == $Defs::REGOFORM_TYPE_MEMBER_TEAM) {
        ($teamsummary, $compID, $compSelect) = $self->getTeamFormSummaryInfo();
    }
    my @currentyear = (localtime())[5];
    my $dobyear = $currentyear[0] + 1900-1;

    my %PageData = (
        FormTitle           => $self->{'DBData'}{'strTitle'} || '',
        AssocName           => $self->{'RunDetails'}{'AssocDetails'}{'strName'} || '',
        ClubName            => $self->{'RunDetails'}{'ClubDetails'}{'strName'} || '',
        HiddenFields        => $self->stringifyCarryField(),
        Target              => $self->{'Data'}{'target'},
        AssocID             => $self->AssocID(),
        FormID              => $self->ID(),
        TopText             => $self->getText('strPageOneText',1) || '',
        FirstNamePermission => $firstname_permission,
        SurnamePermission   => $surname_permission,
        DOBPermission       => $dob_permission,
        GenderPermission    => $gender_permission,
        ReRegister          => $self->{'RunDetails'}{'ReRegister'} || 0,
        MemberData          => $memberdetails,
        TeamSummary         => $teamsummary || '',
        CompID              => $compID || 0,
        CompSelect          => $compSelect || '',
        TypeData            => \@typedata,
        PreventTypeChange   => $self->{'DBData'}{'intPreventTypeChange'} || 0,
        Errors              => $self->{'RunDetails'}{'Errors'} || [],
        AskAdultChild       => $show_type_question || 0,
        CheckMinimumDOBYear => $dobyear,
        ExistingTypes       => \%existingtypes,
        PassportDetails     => \%PassportPrefilDetails,
        PassportID          => $passportID,
        CompulsoryPayment   => $self->getValue('intPaymentCompulsory') || 0,
    );

    #Use the same template for all member forms
    my $templatename = 'regoform/member-to-assoc/initial_info.templ';
    my $pagedata = runTemplate($self->{'Data'}, \%PageData, $templatename);
    my ($dob_y, $dob_m, $dob_d) = split /\-/,$memberdetails->{'dtDOB_RAW'} || '';
    my $returnHTML = '';
    my %fillindata = (
            d_intGender => $memberdetails->{'intGender'},
            d_dtDOB_day => $dob_d || '',
            d_dtDOB_mon => $dob_m || '',
            d_dtDOB_year => $dob_y || '',
    );
    if($self->{'RunDetails'}{'Errors'} )    {
        %fillindata = %{$self->{'RunParams'}};
    }
    $returnHTML = HTML::FillInForm->fill(\$pagedata, \%fillindata);
    $returnHTML ||= $pagedata;

    return ($returnHTML, 0);
}

sub validate_initial_info {
    my $self = shift;

    if ($self->{'Fields'}{'Info'}{'strFirstname'}{'perm'} =~/Compulsory/ and !$self->{'RunParams'}{'d_strFirstname'}) {
        push @{$self->{'RunDetails'}{'Errors'}}, $self->{'Lang'}->txt('No Legal First Name Specified');
    }

    if ($self->{'Fields'}{'Info'}{'strSurname'}{'perm'} =~/Compulsory/ and !$self->{'RunParams'}{'d_strSurname'}) {
        push @{$self->{'RunDetails'}{'Errors'}}, $self->{'Lang'}->txt('No Family Name Specified');
    }

    my ($d,$m,$y) = split /\//, $self->get_dob() || '';

    if ($self->{'Fields'}{'Info'}{'dtDOB'}{'perm'} =~/Compulsory/ and !( $y and $m and $d)) {
        push @{$self->{'RunDetails'}{'Errors'}}, $self->{'Lang'}->txt('No Date of Birth Specified');
    }

    if ($y and $m and $d and !Date::Calc::check_date($y,$m,$d)) {
        push @{$self->{'RunDetails'}{'Errors'}}, $self->{'Lang'}->txt('Invalid Date of Birth Specified');
    }

    if ($self->{'Fields'}{'Info'}{'intGender'}{'perm'} =~/Compulsory/ and !$self->{'RunParams'}{'d_intGender'}) {
        push @{$self->{'RunDetails'}{'Errors'}}, $self->{'Lang'}->txt('No Gender Specified');
    }

    my $types = $self->getAllMemberTypes();
    
    my @registeringAs = ();

    for my $type (@{$types})    {
        if($self->{'DBData'}{$type->[0]} )  {
            if($self->{'DBData'}{$type->[0]} eq 'Y')    { #does the regoform allow the type?
                if($self->{'RunParams'}{$type->[0]})    { #has the person registered as this type
                    $self->addCarryField($type->[0], 1);
                    push @registeringAs, $type->[0];
                }
            }
        }
    }

    if($self->{'RunDetails'}{'Errors'}) {
        #There are errors - reset where we are to go back to the form again
        $self->setCurrentProcessIndex('i');
        return ('',2);
    }

    #although this works here, not sure if it's the best spot for it. May be better placed in the checkMemberDuplicates sub further along...
    #assumption here is that firstname, surname and dob will always (be compulsory and) have been input.
    if (!$self->{'RunDetails'}{'ReRegister'}) { #XXX what if re-registering as a type for which dupes are to be prevented? #mick
        if ($self->{'SystemConfig'}{'checkPrimaryClub'} or $self->{'SystemConfig'}{'DuplicatePrevention'}) {
            my $dob = $self->{'RunParams'}{'d_dtDOB'};
            my($d,$m,$y) = split('/',$dob);
                $m ||= 0;
                $d ||= 0;
                $y ||= 0;
                $d='0'.$d if length($d) ==1;
                $m='0'.$m if length($m) ==1;
                $dob = "$y-$m-$d"; 

            my %newMember = (
                firstname => $self->{'RunParams'}{'d_strFirstname'},
                surname   => $self->{'RunParams'}{'d_strSurname'},
                dob       => $dob,
            );
             
            my $resultHTML = '';

            if ($self->{'SystemConfig'}{'checkPrimaryClub'}) {
                my $format = 1; #will always only want the short format.
                $resultHTML = checkPrimaryClub($self->{'Data'}, \%newMember, $format);
            }

            if (!$resultHTML) {
                if ($self->{'SystemConfig'}{'DuplicatePrevention'}) {
                    $resultHTML = duplicate_prevention($self->{'Data'}, \%newMember, \@registeringAs);
                }
            }

            if ($resultHTML) {
                #the resultHTML will actually contain an error message which could be displayed (and is elsewhere eg Member.pm).
                #however, here it is just used as a test for a dup member.
                my $errmsg = $self->{'Lang'}->txt('A member with the same name and date of birth already exists!');
                my $acDefault = ($self->ClubID()) ? 'club' : 'association';
                $acDefault   .= ' you want to register to';

                my $acDetails = ($self->ClubID()) ? 'Club' : 'Assoc';
                $acDetails .= 'Details';

                my $acName = $self->{'RunDetails'}{$acDetails}{'strName'} || $acDefault;

                $errmsg .= "   Please contact $acName to request a transfer.";

                push @{$self->{'RunDetails'}{'Errors'}}, $errmsg;
                $self->setCurrentProcessIndex('i');
                return ('',2);
            }
        }
    }

    my $tempCompID=$self->{'RunParams'}{'d_intCompID'};
    if ($self->{'RunParams'}{'d_intCompID'}) {
        $self->addCarryField('compID', $self->{'RunParams'}{'d_intCompID'});
    }

    my $adult = $self->getValue('intAllowMultipleAdult') || 0;
    my $child = $self->getValue('intAllowMultipleChild') || 0;
    if ($adult or $child) {
        my $nexttype = ($self->{'Session'}->getNextRegoType())[1] || '';
        if(!$nexttype)  {
            my $type = $self->{'RunParams'}{'rego_multitype'} || '';
            if (!$type) {
                if ($child and !$adult) {
                    $type = 'Child';
                }
                else {
                    $type = 'Adult';
                }
            }
            if($type) {
                $self->{'Session'}->addToSession(
                    db => $self->{'db'},
                    FormID => $self->ID(),
                );
                $self->{'Session'}->setTotalNumbers(
                    $self->{'db'},
                    $type eq 'Adult' ? 1 : 0,
                    $type eq 'Child' ? 1 : 0,
                );
                $self->{'Session'}->load($self->{'db'});
            }
        }
    }
    
    return ('',1);
}

sub display_form {
    my $self = shift;
    #OK the guts of the system
    #need to set this up to display the member form

    my ($resultHTML, undef) = $self->setupMember_HTMLForm();

    return ($resultHTML,0);
}

sub setupMember_HTMLForm {
    my $self = shift;

    my $usePassportFeature =  $self->{'Data'}{'SystemConfig'}{'usePassportInRegos'};
    my $memberID = $self->{'AuthorisedID'} || 0;
    my $prefilldata = $self->{'Session'}->getSessionMemberDetails($self->{'db'});
    my $total_in_session = $self->{'Session'}->total() || 0;
    $prefilldata = {} if $total_in_session < 2;
    my @firstpagefields = (qw(strFirstname strSurname dtDOB intGender ));
    for my $f (@firstpagefields)    {
        if(exists $self->{'RunParams'}{'d_'.$f})    {
            my $v = $self->{'RunParams'}{'d_'.$f} || '';
            if($f =~/^dt/)  {
                $v =~s /(\d\d\d\d)-(\d{1,2})-(\d{1,2})/$3\/$2\/$1/;
            }
            $prefilldata->{$f} = $v || '';
            $self->addCarryField('d_'.$f, $v);
        }
    }

    my %PassportPrefilDetails = ();
    my $passportID = $self->{'Passport'} ? $self->{'Passport'}->id() : 0;

    if ($usePassportFeature) {
        if($self->{'RunParams'}{'loadedpassport'} and $self->{'Passport'})  {
            my $passport = $self->{'Passport'};
            $prefilldata->{'strEmail'}       ||= $passport->email(),
            $prefilldata->{'strPhoneMobile'} ||= $passport->getInfo('PhoneMobile') || '',
            $prefilldata->{'strPhoneHome'}   ||= $passport->getInfo('PhoneHome')   || '',
            $prefilldata->{'strState'}       ||= $passport->getInfo('State')       || '',
            $prefilldata->{'strSuburb'}      ||= $passport->getInfo('Suburb')      || '',
            $prefilldata->{'strPostalCode'}  ||= $passport->getInfo('PostalCode')  || '',
            $prefilldata->{'strCountry'}     ||= $passport->getInfo('Country')     || '',
            $prefilldata->{'strAddress1'}    ||= $passport->getInfo('Address1')    || '',
            $prefilldata->{'strAddress2'}    ||= $passport->getInfo('Address2')    || '',
        }
    }
    
  my $Data = $self->{'Data'};
  $Data->{'SystemConfig'}{'hide_webcam_tab'} = '' if ($self->{ID} and $Data->{'SystemConfig'}{'hide_webcam_tab'} and  $Data->{'SystemConfig'}{'hide_webcam_tab'} != $self->{ID});

    my $FieldDefinitions = Member::member_details('', $Data, $memberID, $prefilldata);

    #Deal with fields that appeared on the previous page
    for my $f (@firstpagefields)    {
        $FieldDefinitions->{'fields'}->{$f}{'readonly'} = 1;
    }

    my $registeras = '';
    {
        my $types = $self->getAllMemberTypes();
        my $allowedtypes = 0;
        for my $type (@{$types})    {
            if($self->{'DBData'}{$type->[0]} and $self->{'DBData'}{$type->[0]} eq 'Y')  {
                $allowedtypes++;
                if($self->{'RunParams'}{$type->[0]})    {
                    $registeras .= qq[<li>$type->[1]</li>];
                }
            }
        }
        $registeras = ($allowedtypes > 1 and $registeras)
        ? qq[<p>Registering as:<ul>$registeras</ul></p>]
        : '';
    }


    my $introtext = $self->getText('strTopText',1) .'<br><br>' .$registeras;

    $FieldDefinitions->{'options'}{'introtext'} = $introtext;
    my $products = getRegoProducts({
        Data      => $self->{'Data'},
        level     => $Defs::LEVEL_MEMBER,
        level_ID  => $memberID,
        realm_ID  => $self->{'RunDetails'}{'AssocDetails'}{'intRealmID'} || 0,
        assoc_ID  => $self->AssocID(),
        club_ID   => $self->getCarryFields('clubID') || 0,
        program_ID => $self->getCarryFields('programID') || 0,
        form_ID   => $self->ID(),
        form_club_ID => $self->getValue('intClubID'), #the club ID of the form - not the session
        default_product_ID  => $self->{'RunDetails'}{'AssocDetails'}{'intDefaultRegoProductID'} || 0,
        member_details      => {
                Gender => $self->{'RunParams'}{'d_intGender'} || '',
                DOB => $self->{'RunParams'}{'d_dtDOB'} || '',
        },
        multiperson_type    => ($self->{'Session'}->getNextRegoType())[0] || '',
        filter_params       => $self->{'RunParams'},
        parent_body_form_ID => $self->ParentBodyFormID(),
        is_node_form        => $self->isNodeForm(),
    });

    my $passportlinktext = '';
    if($self->{'Passport'} and $self->{'Passport'}->email())    {
        $passportlinktext = qq[
            <div class = "passportaccountlink">
                <div class="ppacclink-row">
                    <input type = "radio" name = "passportaccount" value = "existing" id = "ppacnt_existing" checked>
                    <label for = "ppacnt_existing" >Link this registration to my SP Passport.</label>
                </div>
                <div class="ppacclink-row"> 
                    <input type = "radio" name = "passportaccount" value = "new" id = "ppacnt_new">
                    <label for = "ppacnt_new">I&#39m registering for someone else. Send them an email about SP Passport.</label>
                </div>
            </div>

        ];
    }

    my $tcHdr = $self->getText('strTermsCondHeader', 1);
    $tcHdr = qq[<p class="sectionheader">$tcHdr</p>] if $tcHdr;

    $FieldDefinitions->{'options'}{'pre_button_bottomtext'} = join(
          '<br>',
          $products, 
            $self->getText('strBottomText',1),
            (exists $self->{'Optins'}) ? $self->{'Optins'} : '',
            (exists $self->{'Text'}{'TC_js'}{'value'}) ? $self->{'Text'}{'TC_js'}{'value'} : '', 
            $tcHdr.$self->getText('strTermsCondText',1), #$tcHdr on it's own line creates an extra linefeed...
            $self->getText('TC_AgreeBox',1),
            $passportlinktext,
    );
    my $carryfields = $self->getCarryFields();

    for my $k (keys %{$carryfields})    {
        $FieldDefinitions->{'carryfields'}{$k} = $carryfields->{$k} || '';
    }
    $FieldDefinitions->{'carryfields'}{'rfp'} = 'vd';
    $FieldDefinitions->{'carryfields'}{'newCode'} = $self->{'RunParams'}{'newCode'};
    $FieldDefinitions->{'options'}{'buttonloc'}             = 'bottom';

        #CompulsoryPayment => $self->getValue('intPaymentCompulsory') || 0,
    $FieldDefinitions->{'options'}{'submitlabelnondisable'} = 'Confirm';
    if($self->getValue('intPaymentCompulsory')) {
        $FieldDefinitions->{'options'}{'submitlabelnondisable'} = 'Continue';
    }
    $FieldDefinitions->{'options'}{'afteraddFunction'} = \&rego_postMemberUpdate;

    $FieldDefinitions->{'options'}{'beforeaddFunction'} = \&Member::preMemberAdd;

    my $check = $self->checkMemberDuplicates($self->{'RunParams'}); 
    return $check if $check;

  my $memperm = ProcessRegoFormPermissions($self->{'Fields'}{'Info'}, $FieldDefinitions);
    for my $fieldname (@{$self->{'Fields'}{'Order'}})   {
        my $meets_field_rule = $self->MeetsFieldRule($fieldname);
        $memperm->{$fieldname} = 0 if !$meets_field_rule;
    }

    my %configchanges = ();
    if($self->{'SystemConfig'}{'MemberRegoFormReLayout'}) {
        %configchanges = eval($self->{'SystemConfig'}{'MemberRegoFormReLayout'});
    }

    if($self->{'SystemConfig'}{'Schools'} and $memperm->{'intSchoolID'}) {
        $memperm->{'strSchoolName'}   = 1;
        $memperm->{'strSchoolSuburb'} = 1;
    }
    $memperm->{'intPlayer'}    = 0;
    $memperm->{'intCoach'}     = 0;
    $memperm->{'intUmpire'}    = 0;
    $memperm->{'intOfficial'}  = 0;
    $memperm->{'intMisc'}      = 0;
    $memperm->{'intVolunteer'} = 0;

    $FieldDefinitions->{'options'}{'afterupdateFunction'} = \&rego_postMemberUpdate;
    my $option = $memberID ? 'edit' : 'add';
    $FieldDefinitions->{'options'}{'afterupdateParams'} = [$option,$self->{'Data'},$self->{'db'}, $memberID, $self];
    $FieldDefinitions->{'options'}{'afteraddParams'} = [$option,$self->{'Data'},$self->{'db'}, 0, $self];
    my $tempAdd =0;
    
    if($self->getValue('intPaymentCompulsory') and !$Data->{'SystemConfig'}{'NotUseCompulsoryPay'} ){
        $tempAdd =1;
        $FieldDefinitions->{'options'}{'tempAddFunction'} = \&rego_addTempMember;
        $FieldDefinitions->{'options'}{'tempAddParams'} = [$option,$self->{'Data'},$self->{'db'}, $memberID, $self];
    }
    $FieldDefinitions->{'options'}{'CompulsoryPayment'} = $self->getValue('intPaymentCompulsory') || 0;

    $configchanges{'order'} ||= $self->{'Fields'}{'Order'};
    my @neworder = ();
    foreach my $field (@{ $configchanges{'order'} } ) {
        $configchanges{sectionname}{$field} = 'regoform';
        push @neworder,  $field;
        if($field eq 'intSchoolID' and !$self->{'SystemConfig'}{'MemberRegoFormReLayout'})  {
            push @neworder, 'strSchoolName';
            push @neworder, 'strSchoolSuburb';
            $configchanges{sectionname}{'strSchoolName'} = 'regoform';
            $configchanges{sectionname}{'strSchoolSuburb'} = 'regoform';
        }
    }
    $configchanges{'order'} = \@neworder;# if $self->{'SystemConfig'}{'Schools'};
    
    $memperm = q{} unless keys %$memperm;

  $self->ProcessHTMLForm_OtherBlocks($FieldDefinitions);

    my $type = 'add';
    $type = 'edit' if $memberID;
    my $resultHTML = '';
    my $ok = 0;

    ( $resultHTML, $ok ) = handleHTMLForm($FieldDefinitions, $memperm, $type, 0, $self->{'db'}, \%configchanges, $tempAdd);

    return ($resultHTML || '', $ok);
}

sub validate_form {
    my $self = shift;

    my $memberID = $self->{'AuthorisedID'} || 0;

    my $resultHTML = '';
    my $error = 0;

    ($resultHTML, $error) = checkMandatoryProducts($self->{'Data'}, $memberID, $Defs::LEVEL_MEMBER, $self->{'RunParams'});
    
    if ($self->getText('TC_AgreeBox') and !$self->{'RunParams'}{'tcagree'}) {
            $error = 1;

            $resultHTML .= qq[
                <div class = "warningmsg" style = "font-size:13px;">
                    You must agree to the Terms and Conditions before continuing.  Click the back button on your browser
                </div>
            ];
    }
    {
        my $ret = checkAllowedProductCount (
            $self->{'Data'},
            $memberID,
            $Defs::LEVEL_MEMBER,
            $self->ID(),
            $self->{'RunParams'},
            $self->AssocID(),
            $self->{'RunDetails'}{'AssocDetails'}{'intRealmID'} || 0,
        );
        $resultHTML .= $ret if $ret;
        $error = 1 if $ret;
    }

    my $retvalue = '';
    my $ok =0;
    
    if(!$error) {
        ($retvalue, $ok) = $self->setupMember_HTMLForm();
    }
    $resultHTML .= $retvalue || '';

    if(!$ok)    {
        $self->setCurrentProcessIndex('d');
        return ($resultHTML,0);
    }
    if(!$self->{'Session'}->isComplete() and $ok)   {
        $self->setCurrentProcessIndex('t');
        $self->deleteCarryField('ak');
        return ('',2);
    }
    return ($resultHTML,1);
}

sub payment {return ('',1);}


sub NewMemberRegosAllowed {
    my $self = shift;
    return $self->{'SystemConfig'}{'rego_NewRegosOverRide'} || $self->{'DBData'}{'intNewRegosAllowed'} || 0;
}

sub AssocHideBtn {
    my $self = shift;

    ## Some associations just won't allow the new button

    # 1 = Hide "New" button
    # 2 = Hide "New Code" button
    # 3 = Hide both the "New" and the "New Code" buttons

    return $self->{'RunDetails'}{'AssocDetails'}{'intHideRegoFormNew'}
        || 0;
}


sub _getAssocClubList   {
    my $self = shift;
    my $st = qq[
        SELECT     
            C.intClubID, 
            C.strName
        FROM       
            tblClub as C
            INNER JOIN tblAssoc_Clubs as AC
                ON (AC.intClubID = C.intClubID)
        WHERE      
            AC.intAssocID = ?
            AND C.intRecStatus=1
            AND AC.intRecStatus=1
        ORDER BY   C.strName
    ];
    my $q = $self->{'db'}->prepare($st);
    $q->execute(
            $self->AssocID(),
    );
    my $club_list = $q->fetchall_arrayref({});
    $q->finish();
    return $club_list;
}

sub checkMemberDuplicates { 
    my $self = shift;
    my ($params) = @_;

    # This function is run after the first page of a member rego form.
    # It checks the type of form and then does a series of tests.
    #   ## newCode check only runs if that module is switched on via SystemConfig and uses tblEOI
    # The rest of the options are done by Realm in systemconfig.

    my $clubID = $self->ClubID() || $params->{'clubID'} || 0;
    $clubID = 0 if $clubID =~ /[^\d]/;
    my $teamID = $self->{'RunDetails'}{'TeamID'} || 0;
    my $assocID = $self->AssocID();
    my $db = $self->{'db'};

    #XXX Should the dup prevention code go here? #mick

    if ($self->{'SystemConfig'}{'rego_NewCodeRequired'} and $params->{'UseNewCode'}) {
        my $clubWHERE = $clubID ? qq[ AND intClubID=$clubID ] : '';
        my $st = qq[
            SELECT intEOIID
            FROM tblEOI
            WHERE intAssocID = ?
                $clubWHERE
                AND strSurname=?
                AND strFirstname=?
                AND dtDOB  = COALESCE( STR_TO_DATE( ?,'%d/%m/%Y'), STR_TO_DATE(?, '%Y-%m-%d') )
                AND intNewMemberID=0
        ];
        my $qry= $db->prepare($st);
        $qry->execute(
            $self->AssocID(),
            $params->{'d_strSurname'},
            $params->{'d_strFirstname'},
            $params->{'d_dtDOB'},
            $params->{'d_dtDOB'}
        );
        my $eoiID = $qry->fetchrow_array() || 0;
        $params->{'newCode'} ||= 0;
        return '' if ($eoiID and $eoiID == $params->{'newCode'});

        return ($self->{'SystemConfig'}{'rego_NewCodeNotFoundMessage'} || 'New Code not found');
    }
    if ($self->NewMemberRegosAllowed() == 1 and !$self->{'AuthorisedID'} and !$params->{'ID_IN'}) {
        Member::preMemberAdd($params, '', $self->{'Data'}, $db);
        if ($params->{isDuplicate})  {
            return ($self->{'SystemConfig'}{'rego_NoDuplicateAllowedMessage'} || 'Duplicated Record');
        }
    }
    if ($self->NewMemberRegosAllowed() == 4 and !$self->{'AuthorisedID'}) {
        $params->{'teamID_check'} = $params->{'teamID'} if ($params->{'teamID'} and $params->{'teamID'} > 0);
        $params->{'clubID_check'} = $clubID if ($clubID and $clubID > 0);
        $params->{'assocID_check'} = $params->{'assocID'} if $assocID > 0;
        Member::preMemberAdd($params, '', $self->{'Data'}, $db);
        if ( not $params->{isDuplicate})  {
                return ($self->{'SystemConfig'}{'rego_NoNewAllowedMessage'} || 'Could not find record for this user.');
        }
    }
    if ($self->NewMemberRegosAllowed() == 5 and !$self->{'AuthorisedID'}) {
        #Only allow new if already in Assoc

        Member::preMemberAdd($params, '', $self->{'Data'}, $db,'assoc');
        if (!$params->{isDuplicate})  {
            return ('We could not find a record of you in this league');
        }
    }

    my $memberID = $self->{'AuthorisedID'} || $params->{'isDuplicate'} || $params->{'ID_IN'} || 0;

    if($self->{'SystemConfig'}{'rego_checkClearedOut'} and $memberID and $clubID and $clubID > 0 and $params->{'ynPlayer'} == 1) {
        my $st = qq[
            SELECT
                COUNT(intMemberID) as Count
            FROM
                tblMember_ClubsClearedOut
            WHERE 
                intAssocID = ?
                AND intClubID = ?
                AND intRealmID = ?
                AND intMemberID = ?
        ];
        my $qry= $db->prepare($st);
        $qry->execute($assocID, $clubID, $self->RealmID(), $memberID);
        my $count =  $qry->fetchrow_array() || 0;
        if ($count) {
            return $self->{'SystemConfig'}{'rego_ClearedOutMessage'} || 'This member has been transferred out.';
        }
    }
    my $MStablename = "tblMember_Seasons_".$self->RealmID();
    if($self->{'SystemConfig'}{'rego_checkNewSeasonTypes'} and $memberID and $params->{'ynPlayer'} == 1) {
        my $st = qq[
            SELECT 
                MS.intMemberSeasonID, 
                MS.intPlayerStatus
            FROM
                $MStablename as MS
                INNER JOIN tblAssoc as A ON (A.intAssocID = MS.intAssocID)
            WHERE
                MS.intMemberID = ?
                AND MS.intAssocID = ?
                AND MS.intClubID = ?
                AND MS.intSeasonID = A.intNewRegoSeasonID
                AND MS.intMSRecStatus =1 
        ];
        my $qry= $db->prepare($st);
        $qry->execute($memberID, $assocID, $clubID);
        my ($msID, $msPlayer)=  $qry->fetchrow_array();
        $msID ||= 0;
        $msPlayer ||= 0;
        return '' if ($msID and $msPlayer);
    }
    if($self->{'SystemConfig'}{'rego_checkLastSeasonTypes'}  and $params->{'ynPlayer'} == 1 and $memberID) {
        my $st = qq[
            SELECT 
                MS.intMemberSeasonID
            FROM
                $MStablename as MS
            WHERE
                MS.intMemberID = ?
                AND MS.intAssocID = ?
                AND MS.intClubID = ?
                AND MS.intSeasonID <= ?
                AND MS.intMSRecStatus =1 
                AND MS.intPlayerStatus=1
        ];
        my $qry= $db->prepare($st);
        $qry->execute($memberID, $assocID, $clubID, $self->{'SystemConfig'}{'rego_checkLastSeasonTypes'} || 0);
        my ($msID)=  $qry->fetchrow_array();
        $msID ||= 0;
        return '' if ($msID);
        return $self->{'SystemConfig'}{'rego_NotLastSeasonPlayerMessage'} || 'This member was not a player in the Last Season.';
    }
    return '';
}

sub getAllMemberTypes   {
    my $self = shift;
    my @types = (
        ['ynPlayer',        $self->{'SystemConfig'}{'PlayerLabel'}    || 'Player',         'intPlayerStatus'],
        ['ynCoach',         $self->{'SystemConfig'}{'CoachLabel'}     || 'Coach',          'intCoachStatus'],
        ['ynMatchOfficial', $self->{'SystemConfig'}{'UmpireLabel'}    || 'Match Official', 'intUmpireStatus'],
        ['ynOfficial',      $self->{'SystemConfig'}{'OfficialLabel'}  || 'Official',       'intOfficial'],
        ['ynMisc',          $self->{'SystemConfig'}{'MiscLabel'}      || 'Misc',           'intMisc'],
        ['ynVolunteer',     $self->{'SystemConfig'}{'VolunteerLabel'} || 'Volunteer',      'intVolunteer'],
    );
    if ($self->{'SystemConfig'}{'Seasons_Other1'}) {
        push @types, ['ynOther1', $self->{'SystemConfig'}{'Season_Other1'} || 'Other 1', 'intOther1Status'];
    }
    if ($self->{'SystemConfig'}{'Seasons_Other2'}) {
        push @types, ['ynOther2', $self->{'SystemConfig'}{'Seasons_Other2'} || 'Other 2', 'intOther2Status'];
    }
    return \@types;
}

sub loadAuthorisedEntityDetails { 
    my $self = shift;

    return undef if !$self->{'AuthorisedID'};
    my $details  = Member::loadMemberDetails($self->{'db'}, $self->{'AuthorisedID'}, $self->AssocID());
    $self->{'EntityDetails'} = $details;
}

sub getTeamCodeID       {
    my $self = shift;
    my ($teamcode) = @_;

    $teamcode =~ /^\d(\d+)$/;
    $teamcode = $1 || 0;

    my $st = qq[
        SELECT A.intID, T.strName, T.intTeamID
        FROM tblAuth as A
            INNER JOIN tblTeam as T ON (T.intTeamID = A.intID)
        WHERE A.intID = ?
            AND A.intLevel = ?
            AND A.intAssocID = ?
        LIMIT 1
    ];
    my $query = $self->{'db'}->prepare($st);
    $query->execute($teamcode, $Defs::LEVEL_TEAM, $self->AssocID());
    my $tref = $query->fetchrow_hashref() || undef;
    my $teamID = $tref->{intID} || 0;

    return ($teamID, $tref);
}

sub getTeamFormSummaryInfo  {
    my $self = shift;
    return '' if !$self->{'RunDetails'}{'TeamID'};

    my $dbh     = $self->{'db'};
    my $teamID  = $self->{'RunDetails'}{'TeamID'};
    my $assocID = $self->AssocID();

    my ($teamName, $teamContact, $assocName) = getTeamDetails($dbh, $teamID, $assocID);

    my $cid      = '';
    my $cname    = '';
    my $count    = 0;
    my $compName = '';
    my %compHash = ();

    my $compID = $self->getCarryFields('compID') || 0;

    if ($compID) {
        my $compObj = getInstanceOf($self->{'Data'}, 'comp', $compID);
        $compName   = $compObj->getValue('strTitle');
        $count      = 1;
    }
    else {
        my $comps = getComps($dbh, $teamID);

        for my $href(@$comps) {
            $cid   = $href->{'intCompID'};
            $cname = $href->{'strTitle'};
            $compHash{$cid} = $cname;
            $count++;
        }

        $compID   = ($count == 1) ? $cid   : 0;
        $compName = ($count == 1) ? $cname : '';
    }

    my $theComp = ($compName)
        ?qq[the <b>$compName</b> competition which is being conducted by ]
        : '';

    my $body = qq[
        <br>
        <br>
        <p>You are about to join <b>$teamName</b> in $theComp<b>$assocName</b>.</p>
        <table style = "width:auto;">
            <tr>
                <td><b>Your Team Name:</b></td>
                <td>$teamName</td>
            </tr>
            <tr>
                <td><b>Your Team Coordinator:</b></td>
                <td>$teamContact</td>
            </tr>
        </table>
    ];

    my $compSelect = '';

    if ($count > 1) {
        $compSelect .= q[<div style="margin-left:7px"><b>Select a competition:</b>];
        $compSelect .= drop_down('d_intCompID', \%compHash, undef, undef, 1, 0);
        $compSelect .= q[<br><br></div>];
    }

    return ($body, $compID, $compSelect);
}

sub getTeamDetails {
    my ($dbh, $teamID, $assocID) = @_;

    my $sql = q[
        SELECT 
            T.strName AS TeamName, 
            A.strName AS AssocName, 
            T.strContact
        FROM
            tblTeam AS T
        INNER JOIN 
            tblAssoc AS A ON T.intAssocID = A.intAssocID
        WHERE 
            T.intTeamID = ? AND 
            A.intAssocID = ?
        LIMIT 1
    ];

    my @bindVars = ($teamID, $assocID);
    my $teams = doQuery($dbh, $sql, \@bindVars);
    my $teamName    = '';
    my $teamContact = '';
    my $assocName   = '';

    for my $href(@$teams) {
        $teamName    = $href->{'TeamName'}   || '';
        $teamContact = $href->{'strContact'} || '';
        $assocName   = $href->{'AssocName'}  || '';
    }

    return ($teamName, $teamContact, $assocName);
}

sub getComps {
    my ($dbh, $teamID) = @_;

    my $sql = q[
        SELECT
            AC.intCompID,
            AC.strTitle
        FROM 
            tblComp_Teams as CT
        INNER JOIN 
            tblAssoc_Comp as AC ON AC.intCompID=CT.intCompID
        INNER JOIN 
            tblAssoc as A ON (A.intAssocID=AC.intAssocID)
        WHERE  
            CT.intTeamID=? AND
            CT.intRecStatus=1 AND
            AC.intRecStatus=1 AND (
                AC.dtStart>=NOW() OR
                AC.dtStart='0000-00-00' OR
                AC.intNewSeasonID>=A.intNewRegoSeasonID
            )
        ORDER BY strTitle
    ];

    my @bindVars = ($teamID);
    my $comps = doQuery($dbh, $sql, \@bindVars);

    return $comps;

}

sub doQuery {
    my ($dbh, $sql, $params) = @_;

    return undef if !$dbh;
    return undef if !$sql;

    my $q = $dbh->prepare($sql);

    my $count = 0;
    foreach (@$params) {
        $count++;
        $q->bind_param($count, $_);
    }

    $q->execute;

    my @results = ();

    while (my $href = $q->fetchrow_hashref()) {
        push @results, $href;
    }

    $q->finish();

    return \@results;
}
sub MeetsFieldRule  {
    my $self = shift;
    my ($fieldname) = @_;

    my $field_rules = $self->{'FieldRules'}{$fieldname} || undef;
    return 1 if !$field_rules;
    if($field_rules->{'strGender'}) {
        my $genderIn = $self->{'RunParams'}{'d_intGender'} || 0;
        return 0 if $genderIn != $field_rules->{'strGender'};
    }
    my $type_checks = 0;
    my $type_checks_valid = 0;
    if($field_rules->{'ynPlayer'} and $field_rules->{'ynPlayer'} eq 'Y')    {
        $type_checks = 1;
        $type_checks_valid = 1 if $self->{'RunParams'}{'ynPlayer'};
    }
    if($field_rules->{'ynCoach'} and $field_rules->{'ynCoach'} eq 'Y')  {
        $type_checks = 1;
        $type_checks_valid = 1 if $self->{'RunParams'}{'ynCoach'};
    }
    if($field_rules->{'ynMatchOfficial'} and $field_rules->{'ynMatchOfficial'} eq 'Y')  {
        $type_checks = 1;
        $type_checks_valid = 1 if $self->{'RunParams'}{'ynMatchOfficial'};
    }
    if($field_rules->{'ynOfficial'} and $field_rules->{'ynOfficial'} eq 'Y')    {
        $type_checks = 1;
        $type_checks_valid = 1 if $self->{'RunParams'}{'ynOfficial'};
    }
    if($field_rules->{'ynMisc'} and $field_rules->{'ynMisc'} eq 'Y')    {
        $type_checks = 1;
        $type_checks_valid = 1 if $self->{'RunParams'}{'ynMisc'};
    }
    if($field_rules->{'ynVolunteer'} and $field_rules->{'ynVolunteer'} eq 'Y')    {
        $type_checks = 1;
        $type_checks_valid = 1 if $self->{'RunParams'}{'ynVolunteer'};
    }
    if($type_checks and !$type_checks_valid)    {
        return 0;
    }

    my $dtDOB_temp = $self->{'RunParams'}{'d_dtDOB'};
    if($dtDOB_temp =~ /\//) {
        $dtDOB_temp =~s /(\d{1,2})\/(\d{1,2})\/(\d\d\d\d)/$3-$2-$1/;
    }
    if($field_rules->{'dtMinDOB'})  {

        return 0 if $dtDOB_temp lt $field_rules->{'dtMinDOB'};
    }
    if($field_rules->{'dtMaxDOB'})  {
        return 0 if $dtDOB_temp gt $field_rules->{'dtMaxDOB'};
    }

    return 1;
}

sub loadPassportLinkedEntities  {
    my $self = shift;

    return undef if !$self->{'Passport'};
    my $passportID = $self->{'Passport'}->id() || 0;

    my $st = qq[
        SELECT
            M.intMemberID,
            M.strFirstname,
            M.strSurname
        FROM
            tblMember AS M
            INNER JOIN tblPassportMember AS PM
            ON M.intMemberID = PM.intMemberID
        WHERE
            PM.intPassportID = ?
            AND M.intRealmID = ?
    ];
    my $q = $self->{'db'}->prepare($st);
    $q->execute(
            $passportID,
            $self->{'RunDetails'}{'AssocDetails'}{'intRealmID'} || 0,
    );
    my %entities = ();
    while(my $dref = $q->fetchrow_hashref())    {
        $entities{$dref->{'intMemberID'}}{'name'} = "$dref->{'strSurname'}, $dref->{'strFirstname'}";
    }
    $q->finish();

    my $types = $self->getAllMemberTypes();

  my @typedata = ();
    my $countFormTypes = 0;
  for my $type (@{$types})  {
    if($self->{'DBData'}{$type->[0]}
      and $self->{'DBData'}{$type->[0]} eq 'Y') {
                $countFormTypes++;
    }
  }
    
    for my $id (keys %entities) {
        my %params = (
            #AuthorisedID => $id,
            UseNewCode => 0,
            clubID => $self->{'RunParams'}{'clubID'} || 0,
            ID_IN => $id,
        );
        if ($countFormTypes ==1 and $self->{'DBData'}{'ynPlayer'} eq 'Y')   {
            $params{'ynPlayer'} = 1;
        }
        my $val = $self->checkMemberDuplicates(\%params);
        $entities{$id}{'problem'} = $val || '';
    }

    return \%entities;
}

sub get_dob {
    my $self = shift;
    
    $self->{'RunParams'}{'d_dtDOB'} ||= join('/',
        sprintf("%02d",$self->{'RunParams'}{'d_dtDOB_day'} || ''),
        sprintf("%02d",$self->{'RunParams'}{'d_dtDOB_mon'} || ''),
        $self->{'RunParams'}{'d_dtDOB_year'},
    );

    return $self->{'RunParams'}{'d_dtDOB'} || '';
}

sub get_mrt_for_regoform {
    my ($self, $data) = @_;
    my $extra = {
        entity_type => $self->EntityTypeID(),
        entity_id   => $self->EntityID(),
        realm       => $data->{'Realm'},
        subrealm    => $data->{'RealmSubType'},
    };
    my $mrt_list = get_mrt_select_options($data, $extra);

    return $mrt_list;
}

sub get_register_as_mrt_list {
    my ($self, $data) = @_;

    my $mrt_list = $self->get_mrt_for_regoform($data);
    my @allowed_list = split(',', $self->getValue('strAllowedMemberRecordTypes'));

    my $result = {};
    for my $id (keys %$mrt_list) {
        if ((first {$_==$id} @allowed_list)) {
            $result->{$id} = $mrt_list->{$id};
        }
    }
    return $result;
}

1;
