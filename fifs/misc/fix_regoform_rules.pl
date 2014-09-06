#!/usr/bin/perl

#
# $Header: svn://svn/SWM/trunk/misc/fix_regoform_rules.pl 8250 2013-04-08 08:24:36Z rlee $
#

use strict;
use lib '..','../web','../web/comp';
use Defs;
use Utils;

main ();

sub main {
    my $dbh = connectDB();

    my $st = qq[
        SELECT intRegoFormRuleID, intRegoFormID, strFieldName
        FROM tblRegoFormRules
    ];

    my $q = $dbh->prepare($st);
    $q->execute();

    print "\n\nProcessing regoform rules...\n";

    my $total_recs   = 0;
    my $fixed_recs   = 0;
    my $deleted_recs = 0;

    while (my $href = $q->fetchrow_hashref()) {
        my $rfr_ruleid    = $href->{intRegoFormRuleID};
        my $rfr_formid    = $href->{intRegoFormID};
        my $rfr_fieldname = $href->{strFieldName};
        my ($fixed, $deleted) = process_rule($dbh, $rfr_ruleid, $rfr_formid, $rfr_fieldname);
        $total_recs++;
        $fixed_recs++ if $fixed;
        $deleted_recs++ if $deleted;
    }

    print "Total recs   = $total_recs\n";
    print "Fixed recs   = $fixed_recs\n";
    print "Deleted recs = $deleted_recs\n\n";
    print "Completed\n\n";
}

sub process_rule {
    my ($dbh, $rfr_ruleid, $rfr_formid, $rfr_fieldname) = @_;
    
    my $st = qq[
        SELECT intRegoFormFieldID, strFieldName
        FROM tblRegoFormFields
        WHERE intRegoFormID=? AND strFieldName=?
    ];

    my $q = $dbh->prepare($st);
    $q->execute(
        $rfr_formid,
        $rfr_fieldname
    );

    my $fixed   = 0;
    my $deleted = 0;

    while (my $href = $q->fetchrow_hashref()) {
        my $rff_fieldid   = $href->{intRegoFormFieldID};
        my $rff_fieldname = $href->{strFieldName};
        fix_rule($dbh, $rfr_ruleid, $rfr_formid, $rff_fieldid, $rff_fieldname);
        $fixed = 1;
    }

    if (!$fixed) {
      delete_rule($dbh, $rfr_ruleid, $rfr_formid);
      $deleted = 1;
    }

    return ($fixed, $deleted);
}

sub fix_rule {
    my ($dbh, $rfr_ruleid, $rfr_formid, $rff_fieldid, $rff_fieldname) = @_;
    
    my $st = qq[
        UPDATE tblRegoFormRules
        SET intRegoFormFieldID=?, strFieldName=?
        WHERE intRegoFormRuleID=? and intRegoFormID=?
    ];

    my $q = $dbh->prepare($st);
    $q->execute($rff_fieldid, $rff_fieldname, $rfr_ruleid, $rfr_formid);
    $q->finish;

    die '*Aborted* => Error occurred when updating records from database.' if ($DBI::err);
}

sub delete_rule {
    my ($dbh, $rfr_ruleid, $rfr_formid) =@_;

    my $st = qq[
        DELETE FROM tblRegoFormRules
        WHERE intRegoFormRuleID=? AND intRegoFormID=?
     ];

    my $q = $dbh->prepare($st);
    $q->execute($rfr_ruleid, $rfr_formid);
    $q->finish;

    die '*Aborted* => Error occurred when deleting records from database.' if ($DBI::err);

    return;
}
