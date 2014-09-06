#! /usr/bin/perl -w

#
# $Header: svn://svn/SWM/trunk/misc/clone_regos.pl 9190 2013-08-09 03:47:05Z dhanslow $
#

use lib '../web/';

use strict;
use CGI;

use Utils;

use Getopt::Long;

#-----------------------------------------------------------------------------

my $formID;
my $realmID;
my $subRealmID;
my $assocID;
my @to_assocs;
my @clubs;

my @forms;

GetOptions (
    'assoc=i' => \$assocID,
    'to_assoc=i' => \@to_assocs,
    'club=i' => \@clubs,
    'form=i'  => \$formID,
    'realm=i' => \$realmID,
    'subrealm=i' => \$subRealmID,
    'help|?'  => \&message,
);

unless (
    $formID and
    ($realmID or $subRealmID or $assocID or @clubs or @to_assocs)
) {
    usage();
}

if (
    ((not not $realmID)
    + (not not $subRealmID)
    + (not not $assocID)
    + (not not scalar @clubs))
        > 1
) {
    usage();
}

if (
    ((not not scalar @to_assocs)
    + (not not $assocID)
    + (not not scalar @clubs))
        > 1
) {
    usage();
}

#-----------------------------------------------------------------------------

my $db = connectDB();

my $get_form_statement = <<"EOS";
SELECT *
FROM   tblRegoForm
WHERE  intRegoFormID = $formID
EOS

my $get_form_query = $db->prepare($get_form_statement);
$get_form_query->execute();
my $src_form = $get_form_query->fetchrow_hashref();

if (@clubs) {

    my $get_club_info_statement = <<"EOS";
SELECT    A.intAssocID, A.intRealmID, A.intAssocTypeID, AC.intClubID, 4
FROM      tblAssoc A
LEFT JOIN tblAssoc_Clubs AC ON AC.intAssocID = A.intAssocID
WHERE     AC.intClubID = ?
EOS
    my $get_club_info_query = $db->prepare($get_club_info_statement);

    my @club_list;
    foreach my $club (@clubs) {
        $get_club_info_query->execute($club);
        push @club_list, [ $get_club_info_query->fetchrow_array() ];
    }
    @forms = @club_list;
}

elsif ($realmID or $subRealmID or @to_assocs) {

    my @where;
    push @where, "intRealmID = $realmID" if $realmID;
    push @where, "intAssocTypeID = $subRealmID" if $subRealmID;

    foreach my $assocID (@to_assocs) {
        push @where, "intAssocID = $assocID";
    }

    my $where = join(' OR ', @where);

    my $get_assocs_statement = <<"EOS";
SELECT intAssocID, intRealmID, intAssocTypeID, -1, 1
FROM   tblAssoc
WHERE  $where
EOS

    my $get_assocs_query = $db->prepare($get_assocs_statement);
    $get_assocs_query->execute();

    @forms = @{ $get_assocs_query->fetchall_arrayref() };
}
else {
    my $get_assoc_statement = <<"EOS";
SELECT *
FROM   tblAssoc
WHERE  intAssocID = $assocID
EOS

    my $get_assoc_query = $db->prepare($get_assoc_statement);
    $get_assoc_query->execute();
    my $assoc = $get_assoc_query->fetchrow_hashref();

    my $realmID    = $assoc->{'intRealmID'};
    my $subRealmID = $assoc->{'intAssocTypeID'};

    my $get_clubs_statement = <<"EOS";
SELECT intAssocID, $realmID, $subRealmID, intClubID, 4
FROM   tblAssoc_Clubs
WHERE  intAssocID = $assocID
AND    intRecStatus = 1
EOS

    my $get_clubs_query = $db->prepare($get_clubs_statement);
    $get_clubs_query->execute();
    @forms = @{ $get_clubs_query->fetchall_arrayref() };

    ## Also create an assoc-wide Member to Club form.
    push @forms, [ $assocID, $realmID, $subRealmID, -1, 4 ];
}

my $get_fields_statement = <<"EOS";
SELECT *
FROM   tblRegoFormFields
WHERE  intRegoFormID = $formID
EOS
my $get_fields_query = $db->prepare($get_fields_statement);
$get_fields_query->execute();

my @fields = @{ $get_fields_query->fetchall_arrayref({}) };

my $get_config_statement = <<"EOS";
SELECT *
FROM   tblRegoFormConfig
WHERE  intRegoFormID = $formID
EOS
my $get_config_query = $db->prepare($get_config_statement);
$get_config_query->execute();

my @config = @{ $get_config_query->fetchall_arrayref({}) };

my $get_rules_statement = <<"EOS";
SELECT *
FROM   tblRegoFormRules
WHERE  intRegoFormID = $formID
EOS
my $get_rules_query = $db->prepare($get_rules_statement);
$get_rules_query->execute();

my @rules = @{ $get_rules_query->fetchall_arrayref({}) };

#-----------------------------------------------------------------------------

my $form_title         = dq($db->quote($src_form->{'strRegoFormName'}));
my $form_regos_allowed = dq($db->quote($src_form->{'intNewRegosAllowed'}));
my $form_status        = dq($db->quote($src_form->{'intStatus'}));

my $form_player   = dq($db->quote($src_form->{'ynPlayer'}))        || 'NULL';
my $form_coach    = dq($db->quote($src_form->{'ynCoach'}))         || 'NULL';
my $form_umpire   = dq($db->quote($src_form->{'ynMatchOfficial'})) || 'NULL';
my $form_official = dq($db->quote($src_form->{'ynOfficial'}))      || 'NULL';
my $form_misc     = dq($db->quote($src_form->{'ynMisc'}))          || 'NULL';


my $form_linked     		= dq($db->quote($src_form->{'intLinkedFormID'}))          || 'NULL';
my $form_allowClub     		= dq($db->quote($src_form->{'intAllowClubSelection'}))          || 'NULL';
my $form_clubMand     		= dq($db->quote($src_form->{'intClubMandatory'}))          || 'NULL';
my $form_template     		= dq($db->quote($src_form->{'intTemplate'}))          || 'NULL';
my $form_templateLevel    	= dq($db->quote($src_form->{'intTemplateLevel'}))          || 'NULL';
my $form_templateSourceID 	= dq($db->quote($src_form->{'intTemplateSourceID'}))          || 'NULL';
my $form_templateAssocID  	= dq($db->quote($src_form->{'intTemplateAssocID'}))          || 'NULL';
my $form_templateEntityID 	= dq($db->quote($src_form->{'intTemplateEntityID'}))          || 'NULL';
my $form_templateExpiry   	= dq($db->quote($src_form->{'dtTemplateExpiry'}))          || 'NULL';
my $form_strTitle     		= dq($db->quote($src_form->{'strTitle'}))          || 'NULL';
my $form_ynOther1    		= dq($db->quote($src_form->{'ynOther1'}))          || 'NULL';
my $form_ynOther2     		= dq($db->quote($src_form->{'ynOther2'}))          || 'NULL';




my $form_allow_multiple_adult
    = dq($db->quote($src_form->{'intAllowMultipleAdult'})) || 'NULL';

my $form_allow_multiple_child
    = dq($db->quote($src_form->{'intAllowMultipleChild'})) || 'NULL';

my $form_prevent_type_change
    = dq($db->quote($src_form->{'intPreventTypeChange'}))  || 'NULL';

#-----------------------------------------------------------------------------

my $create_form_statement = <<"EOS";
INSERT INTO tblRegoForm (
    intAssocID,
    intRealmID,
    intSubRealmID,
    intClubID,
    strRegoFormName,
    intRegoType,
    intRegoTypeLevel,
    intNewRegosAllowed,
    ynPlayer,
    ynCoach,
    ynMatchOfficial,
    ynOfficial,
    ynMisc,
    intStatus,
    intAllowMultipleAdult,
    intAllowMultipleChild,
    intPreventTypeChange,
	intLinkedFormID, 
	intAllowClubSelection, 
	intClubMandatory, 
	intTemplate, 
	intTemplateLevel, 
	intTemplateSourceID, 
	intTemplateAssocID, 
	intTemplateEntityID, 
	dtTemplateExpiry, 
	strTitle, 
	ynOther1, 
	ynOther2 
)
VALUES (
    ?,
    ?,
    ?,
    ?,
    $form_title,
    ?,
    1,
    $form_regos_allowed,
    $form_player,
    $form_coach,
    $form_umpire,
    $form_official,
    $form_misc,
    $form_status,
    $form_allow_multiple_adult,
    $form_allow_multiple_child,
    $form_prevent_type_change,
	$form_linked,
	$form_allowClub,
	$form_clubMand,
	$form_template,
	$form_templateLevel,  
	$form_templateSourceID,
	$form_templateAssocID,
	$form_templateEntityID,
	$form_templateExpiry, 
	$form_strTitle,      
	$form_ynOther1,   
	$form_ynOther2  
)
EOS

my $create_form_query = $db->prepare($create_form_statement);

my $create_fields_statement = <<"EOS";
INSERT INTO tblRegoFormFields (
    intRegoFormID,
    strFieldName,
    intType,
    intDisplayOrder,
    strText,
    intStatus,
	strPerm
)
VALUES (
    ?,
    ?,
    ?,
    ?,
    ?,
    ?,
	?
)
EOS
my $create_fields_query = $db->prepare($create_fields_statement);

my $create_config_statement = <<"EOS";
INSERT INTO tblRegoFormConfig (
    intRegoFormID,
    intAssocID,
    intRealmID,
    intSubRealmID,
    strPageOneText,
    strTopText,
    strBottomText,
    strSuccessText,
    strAuthEmailText,
    strIndivRegoSelect,
    strTeamRegoSelect,
    strPaymentText,
    strTermsCondText,
    intTC_AgreeBox,
	strTermsCondHeader
)
VALUES (
    ?,
    ?,
    ?,
    ?,
    ?,
    ?,
    ?,
    ?,
    ?,
    ?,
    ?,
    ?,
    ?,
    ?,
	?
)
EOS
my $create_config_query = $db->prepare($create_config_statement);

my $create_rules_statement = <<"EOS";
INSERT INTO tblRegoFormRules (
    intRegoFormID,
	intRegoFormFieldID,    
    strFieldName,
    strGender,
    dtMinDOB,
    dtMaxDOB,
    ynPlayer,
    ynCoach,
    ynMatchOfficial,
    ynOfficial,
    ynMisc,
    intStatus
)
VALUES (
    ?,
	?,
    ?,
    ?,
    ?,
    ?,
    ?,
    ?,
    ?,
    ?,
    ?,
    ?
)
EOS
my $create_rules_query = $db->prepare($create_rules_statement);

#-----------------------------------------------------------------------------

foreach my $form (@forms) {
    $create_form_query->execute( @$form );

    my $formID = $create_form_query->{mysql_insertid};

    foreach my $field (@fields) {

        $create_fields_query->execute(
            $formID,
            $field->{'strFieldName'},
            $field->{'intType'},
            $field->{'intDisplayOrder'},
            $field->{'strText'},
            $field->{'intStatus'},
    		$field->{'strPerm'},
	);
    }

    foreach my $config (@config) {

        $create_config_query->execute(
            $formID,
            $form->[0],
            $config->{'intRealmID'},
            $config->{'intSubRealmID'},
            $config->{'strPageOneText'},
            $config->{'strTopText'},
            $config->{'strBottomText'},
            $config->{'strSuccessText'},
            $config->{'strAuthEmailText'},
            $config->{'strIndivRegoSelect'},
            $config->{'strTeamRegoSelect'},
            $config->{'strPaymentText'},
            $config->{'strTermsCondText'},
            $config->{'intTC_AgreeBox'},
        	$config->{'strTermsCondHeader'},
	);
    }

    foreach my $rule (@rules) {

 my $ruleLookup = qq[
                SELECT intRegoFormFieldID
                FROM tblRegoFormFields
                WHERE strFieldName = "$rule->{'strFieldName'}"
                AND intRegoFormID= $formID;
        ];
        my $rule_query = $db->prepare($ruleLookup) or query_error($ruleLookup);
        $rule_query->execute or query_error($ruleLookup);
        my $aref = $rule_query->fetchrow_hashref();
        my $intRegoFormFieldID = $aref->{intRegoFormFieldID};

        $create_rules_query->execute(
            $formID,
            $rule->{'strFieldName'},
        	 $intRegoFormFieldID,
            $rule->{'strGender'},
            $rule->{'dtMinDOB'},
            $rule->{'dtMaxDOB'},
            $rule->{'ynPlayer'},
            $rule->{'ynCoach'},
            $rule->{'ynMatchOfficial'},
            $rule->{'ynOfficial'},
            $rule->{'ynMisc'},
            $rule->{'intStatus'},
        );
    }

    print "Form $formID created for Assoc $form->[0], Club $form->[3]\n";
}
#-----------------------------------------------------------------------------

sub dq {
    my $str = shift;
    $str =~ s/^'(.*)'$/"$1"/g;
    return $str;
}
#-----------------------------------------------------------------------------
sub usage {

    print <<"EOS";
Usage: $0 [ --help ] --form=<formID> --to_assoc=<assocID1> [ --to_assoc=<assocID2> .. ] | [ --realm=<realmID> [ --to_assoc=<assocID1> .. ] | --subrealm=<subRealmID> [ --to_assoc=<assocID1> .. ] | --assoc=<assocID> | --club=<clubID1> [ --club=<clubID2> ... ] ]

EOS
    exit;
}

sub message {

    print <<"EOS";

Creates a registration form for each club in the supplied list of clubs; or
for each club in the association <assocID>; or for each association in the
realm <realmID>, subrealm <subRealmID> or in a list of associations specified
with the --to_assoc flag - which may be used in addition to or instead of a
realm or subrealm.

The form being copied can be of any type, but forms copied to associations
will be created as Member to Association forms, and those copied to clubs will
be Member to Club forms.

EOS

    usage();
}
