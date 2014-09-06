#!/usr/bin/perl

#
# Header$
#

use strict;
use lib '..', '../web';

use Defs;
use Utils;

use Getopt::Long;

my $entity_type = 0;
my $entity_id = 0;
my $export_file = 0;

GetOptions ('entity_type=i'=>\$entity_type,'entity_id=i'=>\$entity_id, 'export_file=i'=>\$export_file);
if (!$entity_type or !$entity_id or !$export_file)	{
    &usage('Please provide the entity type, entity id and export file');
    exit;
}

my $dbh = connectDB();


my ($account_number, $bsb_number, $account_name) = $dbh->selectrow_array(qq[
                                                                            SELECT strAccountNo, strBankCode, strAccountName 
                                                                            FROM tblBankAccount 
                                                                            WHERE intEntityTypeID = $entity_type
                                                                            AND intEntityID = $entity_id
                                                                        ]);


if (!$account_number or !$bsb_number or !$account_name) {
    die "Unable to obtain account details: account name:$account_name>, account number:$account_number, bsb number: $bsb_number\n";
}

my $log_file = 'nab_export_file_resends.log';
open (LOG, ">>$log_file") || die "Unable to create log file\n$!\n";

print "Updating $account_name for failed export: $export_file\n"; 
print LOG "Updating $account_name for failed export: $export_file\n"; 


my ($existing) = $dbh->selectall_arrayref(qq[
                                          SELECT DISTINCT strAccountNo, strBankCode, strAccountName 
                                          FROM tblMoneyLog
                                          WHERE intEntityType = $entity_type
                                          AND intEntityID = $entity_id
                                          AND intExportBankFileID = $export_file
                                          ]);

foreach my $existing_details (@{$existing}) {
    print LOG "Existing values: $existing_details->[0], $existing_details->[1], $existing_details->[2]\n";
}


my $sth = $dbh->prepare(qq[
            UPDATE tblMoneyLog 
            SET strAccountNo = ?, 
            strBankCode = ?,
            strAccountName = ?,
            intExportBankFileID = 0, 
            intMYOBExportID = 0
            WHERE intEntityType = ?
            AND intEntityID = ?
            AND intExportBankFileID = ?
        ]);

$sth->execute($account_number, $bsb_number, $account_name, $entity_type, $entity_id, $export_file);
my $rows = $sth->rows;

print LOG "Updating details to: $account_number, $bsb_number, $account_name\n";
print LOG "Complete: $rows updated.\n\n";
 
print "Complete: $rows updated.\n";

exit;

sub usage {
    my $error = shift;
    print "\nERROR:\n";
    print "\t$error\n";
    print "\tusage:./resend_nab_payments.pl --entity_type entity_type --entity_id entity_id --export_file export_file\n\n";

    exit;
}
