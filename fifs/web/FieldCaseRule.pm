#
# $Header: svn://svn/SWM/trunk/web/FieldCaseRule.pm 8251 2013-04-08 09:00:53Z rlee $
#

package FieldCaseRule;
require Exporter;
@ISA       = qw(Exporter);
@EXPORT    = qw(get_field_case_rules apply_field_case_rule);
@EXPORT_OK = qw(get_field_case_rules apply_field_case_rule);

use strict;
use Reg_common;
use HTMLForm;

sub get_field_case_rules {
    my ($params) = @_;
    my $dbh = $params->{'dbh'};
    return if !$dbh;

    my $realm_id    = $params->{'realmID'}    || 0;
    my $subrealm_id = $params->{'subrealmID'} || 0;

    if (!$realm_id) {
        my $client = $params->{'client'} || '';
        return if !$client;

        my %clientValues = getClient($client);
        my %Data = ();

        $Data{'clientValues'} = \%clientValues;
        $Data{'db'} = $dbh;
        ($realm_id, $subrealm_id) = getRealm(\%Data);

        return if !$realm_id;
    }

    my $this_type_only = $params->{'type'} || '';

    my $sql = q[
        SELECT strType, strDBFName, strCase, intSubRealmID
        FROM tblFieldCaseRules 
        WHERE intRealmID=? and intRecStatus=?
        ORDER BY intSubRealmID ASC
    ];

    my $query = $dbh->prepare($sql);

    $query->execute($realm_id, 1);

    my %CaseRules = ();

    while (my $case_rule = $query->fetchrow_hashref()) {

        next if ($case_rule->{intSubRealmID}) and ($case_rule->{intSubRealmID} != $subrealm_id);
        next if ($this_type_only) and ($case_rule->{strType} ne $this_type_only);

        my $type      = $case_rule->{strType};
        my $fieldname = $case_rule->{strDBFName};
        my $case      = $case_rule->{strCase};

        if ($this_type_only) { 
            $CaseRules{$fieldname} = $case;
        }
        else {
            $CaseRules{$type}{$fieldname} = $case;
        }
    }

    return \%CaseRules;
}

sub apply_field_case_rule {
    my ($rules, $type, $fieldname, $text) = @_;

    return if !defined $text;

    $rules ||= '';
    $type  ||= '';

    return $text if !$text;
    return $text if !$rules;
    return $text if !$fieldname;
    return $text if $type !~ /Member|Club|Comp|Team/;
    return $text if !exists $rules->{$type}{$fieldname};

    my $case = $rules->{$type}{$fieldname};
    my $new_text = apply_case_rule($text, $case);

    return $new_text;
}

1;
