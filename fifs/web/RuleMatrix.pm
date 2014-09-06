package RuleMatrix;
require Exporter;
@ISA = qw(Exporter);
@EXPORT = @EXPORT_OK = qw(
	getRuleMatrix
);

use strict;
use Utils;
use Reg_common;
use TTTemplate;
use Log;


sub getRuleMatrix   {
    my (
        $Data,
        $originLevel,
        $entityLevel,
        $entityOfLevel,
        $entityType,
        $ruleFor,
        $reg_ref
    ) = @_;

    my @values = (
        $Data->{'Realm'},
        $Data->{'RealmSubType'},
        $entityOfLevel || 0,
    );
    my $where = '';
    if($reg_ref->{'sport'})  {
        push @values, $reg_ref->{'sport'};
        $where .= " AND strSport = ? ";
    }
    if($reg_ref->{'registrationNature'})  {
        push @values, $reg_ref->{'registrationNature'};
        $where .= " AND strRegistrationNature = ? ";
    }
    if($reg_ref->{'personType'})  {
        push @values, $reg_ref->{'personType'};
        $where .= " AND strPersonType = ? ";
    }
    if($reg_ref->{'personLevel'})  {
        push @values, $reg_ref->{'personLevel'};
        $where .= " AND strPersonLevel = ? ";
    }
    if($reg_ref->{'ageLevel'})  {
        push @values, $reg_ref->{'ageLevel'};
        $where .= " AND strAgeLevel = ? ";
    }
    if($originLevel)  {
        push @values, $originLevel;
        $where .= " AND intOriginLevel= ? ";
    }
    if($entityLevel)  {
        push @values, $entityLevel;
        $where .= " AND intEntityLevel = ?"
    }
    if($entityType)  {
        push @values, $entityType;
        $where .= " AND strEntityType IN ('', ?) ";
    }
    if($ruleFor)  {
        push @values, $ruleFor;
        $where .= " AND strWFRuleFor = ? " ;
    }

    my $st = qq[
        SELECT 
            *
        FROM 
            tblMatrix
        WHERE
            intRealmID = ?
            AND intSubRealmID IN (0,?)
            AND intOfEntityLevel = ?
            $where
        LIMIT 1
    ];
    my $q = $Data->{'db'}->prepare($st);
    $q->execute(@values);
    my $dref= $q->fetchrow_hashref();
    return $dref;
}

1;
