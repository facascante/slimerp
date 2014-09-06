package PersonRegisterWhat;
require Exporter;
@ISA = qw(Exporter);
@EXPORT = @EXPORT_OK = qw(
	displayPersonRegisterWhat
    optionsPersonRegisterWhat
);

use lib '.', '..', "comp", 'RegoForm', "dashboard", "RegoFormBuilder",'PaymentSplit', "user";
use strict;
use Utils;
use Reg_common;
use TTTemplate;
use Log;
use EntityTypeRoles;
use Person;
use Entity;
use CGI qw(param);

use Data::Dumper;

sub displayPersonRegisterWhat   {
    my(
        $Data,
        $personID,
        $entityID,
        $dob,
        $gender,
        $originLevel,
        $continueURL,
    ) = @_;

    my %templateData = (
        originLevel => $originLevel || 0,
        personID => $personID || 0,
        entityID => $entityID || 0,
        dob => $dob || '',
        gender => $gender || 0,
        client => $Data->{'client'} || '',
        realmID => $Data->{'Realm'} || 0,
        realmSubTypeID => $Data->{'RealmSubType'} || 0,
        continueURL => $continueURL || '',
    );

    my $body = runTemplate(
        $Data, 
        \%templateData, 
        "registration/what.templ"
    );
    return $body || '';
}



sub optionsPersonRegisterWhat {
    my (
        $Data,
        $realmID,
        $subRealmID,
        $originLevel,
        $registrationNature,
        $personType,
        $personEntityRole,
        $personLevel,
        $sport,
        $ageLevel,
        $personID,
        $entityID,
        $dob,
        $gender,
        $lookingFor,
    ) = @_;

    my $pref= undef;
    $pref = loadPersonDetails($Data->{'db'}, $personID) if ($personID);

    my %lfTable = (
        type => 'strPersonType',
        nature => 'strRegistrationNature',
        level => 'strPersonLevel',
        age => 'strAgeLevel',
        sport => 'strSport',
        role => 'strPersonEntityRole',
    );
    my $role_ref = getEntityTypeRoles($Data, $sport, $personType);
    my %lfLabelTable = (
        type => \%Defs::personType,
        role=> $role_ref,
        nature => \%Defs::registrationNature,
        level => \%Defs::personLevel,
        age => \%Defs::ageLevel,
        sport => \%Defs::sportType,
    );
    
    my $lookingForField = $lfTable{$lookingFor} || '';
    return (undef,'Invalid item to look for') if !$lookingForField;

    my @retdata = ();
    my @values = ();
    my $st = '';
    my ($MATRIXwhere, $ERAwhere) = ('','');
    my @MATRIXvalues = (
        $originLevel,
        $realmID,
        $subRealmID
    );
    my @ERAvalues = (
        $entityID,
        $realmID,
        $subRealmID
    );

    ### LETS BUILD UP THE SQL WHERE STATEMENTS TO HELP NARROW SELECTION
    if($sport)  {
        push @MATRIXvalues, $sport;
        push @ERAvalues, $sport;
        $MATRIXwhere .= " AND strSport = ? ";
        $ERAwhere .= " AND strSport = ? ";
    }
    if($registrationNature)  {
        push @MATRIXvalues, $registrationNature;
        $MATRIXwhere .= " AND strRegistrationNature = ? ";
    }
    if($personType)  {
        push @MATRIXvalues, $personType;
        push @ERAvalues, $personType;
        $MATRIXwhere .= " AND strPersonType = ? ";
        $ERAwhere .= " AND strPersonType = ? ";
    }
    if($personEntityRole)  {
        push @MATRIXvalues, $personEntityRole;
        $MATRIXwhere .= " AND strPersonEntityRole IN ('', ?) ";
    }
    if($personLevel)  {
        push @MATRIXvalues, $personLevel;
        push @ERAvalues, $personLevel;
        $MATRIXwhere .= " AND strPersonLevel = ? ";
        $ERAwhere .= " AND strPersonLevel = ? ";
    }
    if($ageLevel)  {
        push @MATRIXvalues, $ageLevel;
        push @ERAvalues, $ageLevel;
        $MATRIXwhere .= " AND strAgeLevel IN ('ALL_AGES', ?) ";
        $ERAwhere .= " AND strAgeLevel IN ('ALL_AGES', ?) ";
    }
    if(defined $pref->{'intGender'})  {
        push @ERAvalues, $pref->{'intGender'} || 0;
        $ERAwhere .= " AND intGender IN (0, ?) ";
    }


    if ($entityID)  {
        my $eref= loadEntityDetails($Data->{'db'}, $entityID);
        my $entityType = $eref->{'strEntityType'} || '';
        my $entityLevel = $eref->{'intEntityLevel'} || 0;
        if ($entityLevel)  {
            push @MATRIXvalues, $entityLevel;
            $MATRIXwhere .= qq[ AND intEntityLevel = ?];
        }
        if ($entityType)    {
            push @MATRIXvalues, $entityType;
            $MATRIXwhere .= qq[ AND strEntityType IN ('', ?)];
        }
    }

    if (! checkMatrixOK($Data, $MATRIXwhere, \@MATRIXvalues))   {
        return (\@retdata, '');
    }
    
    ### ALL OK, LETS RETURN NEXT SET OF SELECTIONS
    if ($lookingForField eq 'strPersonEntityRole')  {
        my $roledata_ref = returnEntityRoles($role_ref);
        return ($roledata_ref, '');
    }
    elsif ($entityID and $lookingForField ne 'strRegistrationNature')   {
        $st = qq[
            SELECT DISTINCT $lookingForField
            FROM tblEntityRegistrationAllowed
            WHERE
                intEntityID = ?
                AND intRealmID = ?
                AND intSubRealmID IN (0,?)
                $ERAwhere
        ];
        @values = @ERAvalues;
    }
    else    {
        $st = qq[
            SELECT DISTINCT $lookingForField
            FROM tblMatrix
            WHERE
                intOriginLevel  = ?
                AND intRealmID = ?
                AND intSubRealmID IN (0,?)
                $MATRIXwhere
        ];
        @values = @MATRIXvalues;
    }
    

    my $q = $Data->{'db'}->prepare($st);
    $q->execute(@values);
    my $lookup = ();
    while(my $val = $q->fetchrow_array())   {
        if($val)    {
            my $label = $lfLabelTable{$lookingFor}{$val};
            $label = $Data->{'lang'}->txt($lfLabelTable{$lookingFor}{$val});
            push @retdata, {
                name => $label,
                value => $val,
            };
        }
    }
    return (\@retdata, '');
}



#### FUNCTIONS #####

sub returnEntityRoles   {

    my ($role_ref) = @_;
    my @retdata=();
    foreach my $key (keys %{$role_ref})   {
        push @retdata, {
            name => $role_ref->{$key},
            value => $key,
        };
     }
     if (! @retdata) {
        push @retdata, {
            name => '-',
            value => '-',
        };
     }
     return \@retdata;
}

sub checkMatrixOK   {

    my ($Data, $where, $values_ref) = @_;

    my $st = qq[
        SELECT COUNT(intMatrixID) as CountNum
        FROM tblMatrix
        WHERE
            intOriginLevel  = ?
            AND intRealmID = ?
            AND intSubRealmID IN (0,?)
            $where
    ];
    my $q = $Data->{'db'}->prepare($st);
    $q->execute(@{$values_ref});
    return $q->fetchrow_array() || 0;
}
1;
