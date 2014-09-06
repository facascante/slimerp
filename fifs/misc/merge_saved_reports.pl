#!/usr/bin/perl

#
# $Header: svn://svn/SWM/trunk/misc/merge_saved_reports.pl 8250 2013-04-08 08:24:36Z rlee $
#

use strict;
use lib '..','../web','../web/comp';
use Defs;
use Utils;

#A flum to merge the non-matching saved reports that on regdb1 and regdb2. 

main ();

sub main {
    my $update = check_args();
    my $st = get_sql();
    my $dbh1 = connectDB();
    my $dbh2 = connectDB('reporting');
    my $reports_ref1 = get_reports($dbh1, $st, 1);
    my $reports_ref2 = get_reports($dbh2, $st, 2);

    remove_identical($reports_ref1, $reports_ref2);
    my $reports_to_add = combine_report_lists($reports_ref1, $reports_ref2);
    
    my $num = scalar keys %$reports_to_add;
    print "Confirming reports to re-add = $num\n";

    if ($update) {
        print "Doing the update run...\n";
        do_the_update($reports_to_add, $dbh1, $dbh2);
    }

    print "Completed\n";
}

sub check_args {
    my $num_args = $#ARGV;
    my $update   = 0;

    if ($num_args > -1) {
        my $err = ($num_args == 0) ? 0 : 1;
        if (!$err) {
            my $arg1 = $ARGV[0];
            $err++ if $arg1 ne '-update';
        }
        die 'Usage merge_saved_reports.pl -update' if $err;
        $update = 1;
    }
    return $update;
}

sub  get_sql {

    my $st = qq[
        SELECT 
            intSavedReportID,
            strReportName, 
            intLevelID, 
            intID, 
            strReportType, 
            strReportData,
            intReportID
        FROM 
            tblSavedReports
    ];

    return $st;
}

sub get_reports {
    my ($dbh, $st, $sno) = @_;

    print "Retrieving saved reports from regdb$sno...\n";

    my $q = $dbh->prepare($st);
    $q->execute();
    my %reports_hash = ();

    while (my $href = $q->fetchrow_hashref()) {
        my $key = $href->{intSavedReportID};
        $reports_hash{$key} = {
            intSavedReportID => $href->{intSavedReportID},
            strReportName    => $href->{strReportName},
            intLevelID       => $href->{intLevelID},
            intID            => $href->{intID},
            strReportType    => $href->{strReportType},
            strReportData    => $href->{strReportData},
            intReportID      => $href->{intReportID},
        }
    }
    my $num = scalar keys %reports_hash;
    print "Keys in hash$sno before removals = $num\n";
    return (\%reports_hash);
}

sub remove_identical {
    my ($reports_ref1, $reports_ref2) = @_;
    
    print "Removing identical records...\n";

    foreach my $key (keys %$reports_ref1) {
        if (exists $reports_ref2->{$key}) {
            if ($reports_ref1->{$key}{strReportName} eq $reports_ref2->{$key}{strReportName} and
                $reports_ref1->{$key}{intLevelID}    == $reports_ref2->{$key}{intLevelID}    and
                $reports_ref1->{$key}{intID}         == $reports_ref2->{$key}{intID}         and
                $reports_ref1->{$key}{strReportType} eq $reports_ref2->{$key}{strReportType} and
                $reports_ref1->{$key}{strReportData} eq $reports_ref2->{$key}{strReportData}) {
                    delete $reports_ref1->{$key};
                    delete $reports_ref2->{$key};
            }
        }
    }

    print "Removing duplicate records...\n";

    foreach my $key1 (keys %$reports_ref1) {
        foreach my $key2 (keys %$reports_ref2) {
            if ($reports_ref1->{$key1}{strReportName} eq $reports_ref2->{$key2}{strReportName} and
                $reports_ref1->{$key1}{intLevelID}    == $reports_ref2->{$key2}{intLevelID}    and
                $reports_ref1->{$key1}{intID}         == $reports_ref2->{$key2}{intID}         and
                $reports_ref1->{$key1}{strReportType} eq $reports_ref2->{$key2}{strReportType} and
                $reports_ref1->{$key1}{strReportData} eq $reports_ref2->{$key2}{strReportData}) {
                    print "deleting duplicate report from regdb2: $key2\n";
                    delete $reports_ref2->{$key2};
            }
        }
    }

    my $num1 = scalar keys %$reports_ref1;
    my $num2 = scalar keys %$reports_ref2;
    print "Regdb1 keys after removals $num1\n";
    print "Regdb2 keys after removals $num2\n";

    return;
}

sub combine_report_lists {
    my ($reports_ref1, $reports_ref2) = @_;

    print "Combining report lists...\n";
    my $num1 = scalar keys %$reports_ref1;
    my $num2 = scalar keys %$reports_ref2;
    print "Regdb1 reports to be re-added $num1\n";
    print "Regdb2 reports to be re-added $num2\n";

    my %reports_to_add = ();
    my $temp_report_id = 0;

    $temp_report_id = process_reports_ref(\%reports_to_add, $temp_report_id, $reports_ref1, 1);
    $temp_report_id = process_reports_ref(\%reports_to_add, $temp_report_id, $reports_ref2, 2);

    print "Reports to be re-added $temp_report_id\n";

    return (\%reports_to_add);
}

sub process_reports_ref {
    my ($reports_to_add, $temp_report_id, $reports_ref, $sno) = @_;

    foreach my $key (keys %$reports_ref) {
        $temp_report_id++;
        $reports_to_add->{$temp_report_id} = {
            sno              => $sno,
            origID           => $reports_ref->{$key}{intSavedReportID},
            intSavedReportID => $temp_report_id,
            strReportName    => $reports_ref->{$key}{strReportName},
            intLevelID       => $reports_ref->{$key}{intLevelID},
            intID            => $reports_ref->{$key}{intID},
            strReportType    => $reports_ref->{$key}{strReportType},
            strReportData    => $reports_ref->{$key}{strReportData},
            intReportID      => $reports_ref->{$key}{intReportID},
        }
    }
    return $temp_report_id;
}

sub do_the_update {
    my ($reports_to_add, $dbh1, $dbh2) = @_;

    my $delete_st1 = qq[DELETE FROM tblSavedReports where intSavedReportID IN (-1];

    my $delete_st2 = $delete_st1;

    foreach my $key (keys %$reports_to_add) {
        my $sno              = $reports_to_add->{$key}{sno};
        my $origID           = $reports_to_add->{$key}{origID};
        $delete_st1 .= ','.$origID if $sno == 1;
        $delete_st2 .= ','.$origID if $sno == 2;
    }

    $delete_st1 .= ')';
    $delete_st2 .= ')';
    
    $dbh1->do($delete_st1);
    $dbh2->do($delete_st2);

    my $insert_st = qq[
        INSERT INTO tblSavedReports
            (strReportName, intLevelID, intID, strReportType, strReportData, intReportID)
        VALUES
            (?, ?, ?, ?, ?, ?)
    ];
    foreach my $key (keys %$reports_to_add) {
        my $q = $dbh1->prepare($insert_st);
        $q->exectute(
            $reports_to_add->{$key}{strReportName},
            $reports_to_add->{$key}{intLevelID},
            $reports_to_add->{$key}{intID},
            $reports_to_add->{$key}{strReportType},
            $reports_to_add->{$key}{strReportData},
            $reports_to_add->{$key}{intReportID}
        );
    }
}

