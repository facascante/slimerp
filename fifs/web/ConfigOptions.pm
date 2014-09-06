package ConfigOptions;
require Exporter;
@ISA =  qw(Exporter);
@EXPORT = qw(GetPermissions ProcessPermissions AllowPermissionUpgrade getFieldsList);
@EXPORT_OK = qw(GetPermissions ProcessPermissions AllowPermissionUpgrade getAssocSubType getFieldsList);

use strict;
use Utils;
use DBUtils;
use Log;
use Data::Dumper;

#TypeID
#

sub GetPermissions {
    my (
        $Data, 
        $EntityTypeID, 
        $EntityID, 
        $RealmID, 
        $SubRealmID, 
        $authLevel, 
        $returnraw
    ) = @_;

    my $db = $Data->{'db'};

    $EntityID ||= 0;
    $EntityTypeID ||= 0;
    $RealmID ||= 0;
    $returnraw ||= 0;
    $authLevel ||= $Data->{'clientValues'}{'authLevel'} || 0;

    my @fields=();
    my %permissions=();

    if($EntityTypeID =~ /[^\d\-]/ or $RealmID =~ /[^\d]/) {
        return \%permissions;
    }
    my $regoform = 0;
    if($authLevel eq 'regoform')	{
        $regoform = 1;
        $authLevel = 0;
    }

    my $fieldname = '';
    my $where = '';

    my $clubID = $Data->{'clientValues'}{'clubID'};
    $clubID = 0 if $clubID < 0;

    my @structureIDs = ();
    my $levelID = $EntityID;

    if($levelID)	{
        my $st = qq[
            SELECT
                intParentLevel,
                intParentID
            FROM
                tblTempEntityStructure AS T
            WHERE
                T.intRealmID = ? 
                AND intChildID = ?
            LIMIT 1
        ];
        my $q = $db->prepare($st);
        $q->execute($RealmID, $EntityID);
        while(my $dref = $q->fetchrow_hashref())  {
            push @structureIDs, [$dref->{'intParentLevel'}, $dref->{'intParentID'}];
        }
        $q->finish;
        push @structureIDs, [$EntityTypeID, $EntityID];
    }

    my $structure_where = '';
    my @vals = ($RealmID);
    push @structureIDs, [$Defs::LEVEL_CLUB, $clubID] if $clubID;
    if($EntityTypeID < 0)	{
        push @structureIDs, [$EntityTypeID, $EntityID];
    }
    for my $r (@structureIDs)	{
        $structure_where .= qq{ OR ( intEntityTypeID = $r->[0] AND intEntityID = ?) };
        push @vals, $r->[1];
    }

    my $authRoleID = $Data->{'AuthRoleID'} || 0;
    my $st = qq[
        SELECT 
            intRealmID,
            intSubRealmID,
            intEntityTypeID,
            intEntityID,
            strFieldType,
            strFieldName,
            strPermission,
            intRoleID
        FROM 
            tblFieldPermissions
        WHERE
            intRealmID = ?
            AND ((intEntityTypeID = 0 AND intEntityID = 0) $structure_where)
            AND intRoleID IN (0,$authRoleID)
        ORDER BY intRoleID DESC
    ];
    my $q = $db->prepare($st);
    $q->execute(@vals);
    my %PermissionsRaw = ();
    my %fields_by_type = ();
    my $hasRoleID = 0;
    while(my $dref = $q->fetchrow_hashref())	{
        next if($dref->{'intSubRealmID'} and $dref->{'intSubRealmID'} != $SubRealmID);
        if($dref->{'intRoleID'})	{
            next if !$Data->{'AuthRoleID'}; #User does not have a role
            if($Data->{'AuthRoleID'} and $dref->{'intRoleID'} != $Data->{'AuthRoleID'} )	{
                next; #Not for my role
            }
            $hasRoleID = 1; #Some valid role records exist
            $PermissionsRaw
            {$dref->{'strFieldType'}."Child"}
            {$dref->{'intEntityTypeID'} || 'REALM'}
            {$dref->{'strFieldName'}}
            = $dref->{'strPermission'};

        }
        if($hasRoleID and !$dref->{'intRoleID'} and $Data->{'AuthRoleID'})	{
            next;
            #If there are some permissions with roleID - ignore the ones that
            #aren't defined by role
        }
        $PermissionsRaw
        {$dref->{'strFieldType'}}
        {$dref->{'intEntityTypeID'} || 'REALM'}
        {$dref->{'strFieldName'}} = $dref->{'strPermission'};
        my $fieldgroup = '';
        if( $dref->{'strFieldType'} eq 'Member' or $dref->{'strFieldType'} eq 'MemberChild')	{
            $fieldgroup = 'Member'; 
        }
        elsif( $dref->{'strFieldType'} eq 'Club' or $dref->{'strFieldType'} eq 'ClubChild')	{
            $fieldgroup = 'Club' ;
        }
        else {
            $fieldgroup = $dref->{'strFieldType'} || '';
        }

        $fields_by_type{$fieldgroup}{$dref->{'strFieldName'}} = 1;
    }
    return \%PermissionsRaw if $returnraw;

    #Check Permissions
    my @levels_to_check = (
        'REALM',
        $Defs::LEVEL_NATIONAL,
        $Defs::LEVEL_STATE,
        $Defs::LEVEL_REGION,
        $Defs::LEVEL_ZONE,
    );
    push @levels_to_check, $Defs::LEVEL_CLUB if $clubID;

    my @fieldgroups = (qw(Member Club));
    if($regoform)	{
        @fieldgroups = (qw(MemberRegoForm ));
    }
    for my $fieldgroup (@fieldgroups)	{
        for my $field (keys %{$fields_by_type{$fieldgroup}})	{
            my $above = 1;
            for my $level (@levels_to_check)	{
                my $type = $fieldgroup;
                $above = 0 if $level eq $EntityTypeID;
                $type .= 'Child' if($above and !$regoform);
                my $val_at_level = $PermissionsRaw{$type}{$level}{$field} || '';
                if($val_at_level and ((!$permissions{$fieldgroup}{$field} or $permissions{$fieldgroup}{$field} eq 'ChildDefine') or ($above and	AllowPermissionUpgrade($permissions{$fieldgroup}{$field},$val_at_level))))	{
                    $permissions{$fieldgroup}{$field} = $val_at_level;
                }
            }
        }
    }

    #OK we now have the field permissions sorted,
    #Let's load the other types of permissions

    #if($assocID)	{
        #my $sql = qq[
            #SELECT   
                #intEntityID,
                #intLevelID,
                #strType,
                #strPerm,
                #strValue,
                #intSubTypeID
            #FROM tblConfig
            #WHERE 
                #(intEntityID = ? OR intEntityID= 0)
                #AND intLevelID = ?
                #AND intRealmID = ?
                #AND strType <> ''
            #ORDER BY 
                #intTypeID ASC, 
                #intEntityID DESC, 
                #intSubTypeID ASC
        #];
        #my $data = query_data($sql, $assocID, $Defs::LEVEL_ASSOC, $RealmID);
        #for my $dref (@$data) {
            #next if($dref->{'intSubTypeID'} and $dref->{'intSubTypeID'} != $SubRealmID);
            #$permissions{$dref->{'strType'}}{$dref->{'strPerm'}}=[$dref->{'strValue'},$dref->{'intLevelID'}, $dref->{'intEntityID'}];
        #}
    #}
    return \%permissions;
}

sub AllowPermissionUpgrade	{
    my( $oldperm, $newperm,) = @_;

    return 1 if !$oldperm;
    return 0 if !$newperm;
    return 1 if $oldperm eq $newperm;
    my %AllowedUpgrades = (
        ReadOnly => { },	
        Hidden => { },	
        Editable => { 
            Compulsory => 1,
            AddOnlyCompulsory => 1,
        },	
        Compulsory => { 
            AddOnlyCompulsory => 1,
        },	
        AddOnlyCompulsory => { },	
        ChildDefine => { 
            Hidden => 1,
            Editable => 1,
            ReadOnly => 1,
            Compulsory => 1,
            AddOnlyCompulsory => 1,
        },	
    );
    return ($AllowedUpgrades{$oldperm} and $AllowedUpgrades{$oldperm}{$newperm}) ? 1 : 0;
}

sub ProcessPermissions	{
    my( $perms, $Fields, $display_type)=@_;
    my %newperms=();
    $display_type ||= 'Editable';

    for my $f (keys %{$perms->{$display_type}})	{
        if ( $f =~ /^(\w+)\.(\w+)$/ ){ #For groups of dynamic fields
            my $regex = '^' . $1;

            foreach my $field ( grep {/$regex/} keys %{$Fields->{fields}} ){

                my $v = $perms->{$display_type}{$f} || 'Editable';
                if( $v eq 'Hidden' or $v eq 'ChildDefine')   {
                    $newperms{$field}=0;    
                    next;   
                }
                elsif($field =~ '_header_') { 
                    #Hey relax guy, I'm just your average Joe. Take a rest. 
                }
                elsif($v eq 'ReadOnly') { $Fields->{'fields'}{$field}{'readonly'}=1; }
                elsif($v eq 'Compulsory')   { $Fields->{'fields'}{$field}{'compulsory'}=1; }
                elsif($v eq 'AddOnlyCompulsory')    { 
                    $Fields->{'fields'}{$field}{'noedit'}=1; 
                    $Fields->{'fields'}{$field}{'compulsory'}=1; 
                }

                $newperms{$field}=1;
            }
        }
        else{ # For individual fields
            my $v = $perms->{$display_type}{$f} || 'Editable';
            if( $v eq 'Hidden' or $v eq 'ChildDefine')   {
                $newperms{$f}=0;    
                next;   
            }
            elsif($v eq 'ReadOnly') { $Fields->{'fields'}{$f}{'readonly'}=1; }
            elsif($v eq 'Compulsory')   { $Fields->{'fields'}{$f}{'compulsory'}=1; }
            elsif($v eq 'AddOnlyCompulsory')    { 
                $Fields->{'fields'}{$f}{'noedit'}=1; 
                $Fields->{'fields'}{$f}{'compulsory'}=1; 
            }
            $newperms{$f}=1;
        }
    }
    return \%newperms;
}

sub getAssocSubType {
    my($db, $assocID)=@_;

    return 0 unless $assocID =~ /^\d+$/;

    my $query = $db->prepare(qq[
        SELECT intAssocTypeID
        FROM tblAssoc
        WHERE intAssocID = ?
        LIMIT 1
    ]);
    $query->execute($assocID);
    my($subtype)= $query->fetchrow_array();
    $query->finish;
    return $subtype||0;
}

sub getFieldsList	{
    my ($data, $fieldtype) = @_;

    my @memberFields =(qw(

        strNationalNum
        strPersonNo
        strStatus
        strSalutation
        strLocalFirstname
        strPreferredName
        strMiddlename
        strLocalSurname
        strMaidenName
        dtDOB
        strPlaceofBirth
        strCountryOfBirth
        strMotherCountry
        strFatherCountry
        intGender
        strAddress1
        strAddress2
        strSuburb
        strState
        strPostalCode
        strCountry
        strPhoneHome
        strPhoneWork
        strPhoneMobile
        strPager
        strFax
        strEmail
        strEmail2
        SPcontact
        intDeceased
        intDeRegister
        strPreferredLang
        strPassportIssueCountry
        strPassportNationality
        strPassportNo
        dtPassportExpiry
        dtPoliceCheck
        dtPoliceCheckExp
        strPoliceCheckRef
        strEmergContName
        strEmergContNo
        strEmergContNo2
        strEmergContRel
        strP1Salutation
        strP1FName
        strP1SName
        intP1Gender
        strP1Phone
        strP1Phone2
        strP1PhoneMobile
        strP1Email
        strP1Email2
        strP2Salutation
        strP2FName
        strP2SName
        intP2Gender
        strP2Phone
        strP2Phone2
        strP2PhoneMobile
        strP2Email
        strP2Email2
        strEyeColour
        strHairColour
        strHeight
        strWeight
        strNotes

        strNatCustomStr1
        strNatCustomStr2
        strNatCustomStr3
        strNatCustomStr4
        strNatCustomStr5
        strNatCustomStr6
        strNatCustomStr7
        strNatCustomStr8
        strNatCustomStr9
        strNatCustomStr10
        strNatCustomStr11
        strNatCustomStr12
        strNatCustomStr13
        strNatCustomStr14
        strNatCustomStr15
        dblNatCustomDbl1
        dblNatCustomDbl2
        dblNatCustomDbl3
        dblNatCustomDbl4
        dblNatCustomDbl5
        dblNatCustomDbl6
        dblNatCustomDbl7
        dblNatCustomDbl8
        dblNatCustomDbl9
        dblNatCustomDbl10
        dtNatCustomDt1
        dtNatCustomDt2
        dtNatCustomDt3
        dtNatCustomDt4
        dtNatCustomDt5
        intNatCustomLU1
        intNatCustomLU2
        intNatCustomLU3
        intNatCustomLU4
        intNatCustomLU5
        intNatCustomLU6
        intNatCustomLU7
        intNatCustomLU8
        intNatCustomLU9
        intNatCustomLU10
        intNatCustomBool1
        intNatCustomBool2
        intNatCustomBool3
        intNatCustomBool4
        intNatCustomBool5

        ));
    return \@memberFields if $fieldtype eq 'Person';

    my @clubFields = (qw(
        strFIFAID
        strLocalName
        strLocalShortName
        strLatinName
        strLatinShortName
        strStatus
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

        intClubClassification
        ));

    return \@clubFields if $fieldtype eq 'Club';

    my %readonlyfields =( #These fields can only be Read only or hidden
        dtLastUpdate => 1,
        dtRegisteredUntil=> 1,
        strNationalNum => 1,
        #strMemberNo => 1,
        dtCreatedOnline => 1,
        ClubName => 1,
        strFIFAID => 1,
    );

    my @hiddenfields	= (qw(
        strSchoolName
        strSchoolSuburb
    ));
}

sub getTeamClubID	{
    my( $db, $teamID,) = @_;
    return 0 if !$db;
    return 0 if !$teamID;
    my $st = qq[
        SELECT intClubID
        FROM tblTeam
        WHERE intTeamID = ?
    ];
    my $q = $db->prepare($st);
    $q->execute($teamID);
    my ($clubID) = $q->fetchrow_array();
    $q->finish();
    return $clubID || 0;

}

1;
# vim: set et sw=4 ts=4:
