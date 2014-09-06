#!/usr/bin/perl

#
# Header$
#

use strict;
use lib '..', '../../', '../web';
use Defs;
use Utils;

use CGI;

my $cgi = new CGI();
my $dbh = connectDB();

my $html = '';

if ($cgi->param('action') eq 'apply') { # apply updates and report.
    $html = apply_update($dbh, $cgi);
}       
elsif ($cgi->param('action') eq 'verify') {
    $html = verify_update($dbh, $cgi);
}
else { # display default screen
    $html = default_page_content();
}

print "Content-type: text/html\n\n";
print $html;

exit;

sub default_page_content {
    my $content = '';
    
    $content  = qq[
                   <h1>Resend NAB payments by Export File for an Entity</h1>
                   <p>Please provide the following details:</p>
                   <form action="resend_nab_payments.cgi" method="post">

                   NAB Export File ID: <input type="text" name="export_file_id" /><br />
                   Entity Type: <select name="entity_type"><option value="3">Club</option><option value="5">Association</option></select><br />
                   Entity ID: <input type="text" name="entity_id" /><br />
                   <input type="submit" value="Check Update" />

                   <input type="hidden" name="action" value="verify" />
                   </form>
               
               ];
    
    return render_page($content);
}

sub verify_update {
    my ($dbh, $cgi) = @_;

    my $export_file = $cgi->param('export_file_id');
    my $entity_type = $cgi->param('entity_type');
    my $entity_id   = $cgi->param('entity_id');
   
    if (!$entity_type or !$entity_id or !$export_file) {
        return unable_to_proceed_message('Please proivde entity type, entity id and export file.');
    }
    
    
    my ($account_number, $bsb_number, $account_name) = get_bank_account_details($dbh, $entity_type, $entity_id);
    
    if (!$account_number or !$bsb_number or !$account_name) {
        return unable_to_proceed_message('Unable to obtain account details.');
    }
    
    my $html = qq[
                  <h1>Resend NAB payments by Export File for an Entity</h1>
                  <h2>You are about to re-schedule the outstanding money for export file $export_file to be resent for the following entity:</h2>
                  <ul>
                  <li>Account Name: $account_name</li>
                  <li>Account Number: $account_number</li>
                  <li>BSB Number: $bsb_number</li>
                  </ul>
                  <p>Click "Apply Update" to continue or "Cancel" to start again<p>
                  <form action="resend_nab_payments.cgi" method="post">
                  
                  <input type="submit" value="Apply Update" />
                  <input type="hidden" name="export_file_id" value="$export_file" />
                  <input type="hidden" name="entity_type" value="$entity_type" />
                  <input type="hidden" name="entity_id" value="$entity_id" />
                  <input type="hidden" name="action" value="apply" />
                  </form>
                  <button onclick="window.location.href='resend_nab_payments.cgi'">Cancel</button>
               
              ];
    
    return $html;
}

sub unable_to_proceed_message {
    my $message = shift;
    
    return qq[<p>ERROR: $message</p>
              <p><a href="resend_nab_payments.cgi">Click here to try again</a></p>
          ];
    
}


sub render_page {
    my ($content, $title) = @_;
    
    if (!$title) {
        $title = 'Resend NAB payments';
    } 
    
    my $html = qq[
                  <!DOCTYPE html> 
                  <html lang="en">
                  <head>
                  <meta charset="utf-8">
                  <title>$title</title>
                  </head>
                  <body>
                  $content
                  </body>
                  </html>
              ];
    
    return $html;
}

sub get_bank_account_details {
    my ($dbh, $entity_type, $entity_id)  = @_;
    
    my $sth = $dbh->prepare(qq[
                               SELECT strAccountNo, strBankCode, strAccountName 
                               FROM tblBankAccount 
                               WHERE intEntityTypeID = ?
                               AND intEntityID = ?
                           ]);
                            
    
    $sth->execute($entity_type, $entity_id);
    my ($account_no, $bsb_code, $account_name) =$sth->fetchrow_array();
    

    return ($account_no, $bsb_code, $account_name);
}


sub apply_update {
    my ($dbh, $cgi) = @_;
    
    my $export_file = $cgi->param('export_file_id');
    my $entity_type = $cgi->param('entity_type');
    my $entity_id   = $cgi->param('entity_id');
   
    my ($account_number, $bsb_number, $account_name) = get_bank_account_details($dbh, $entity_type, $entity_id);

    if (!$entity_type or !$entity_id or !$export_file or !$account_number or !$bsb_number or !$account_name) {
        return unable_to_proceed_message("There's been a problem, no changes made, please try again");
    }


    my $log_file = '/u/data/log/nab/nab_export_file_resends.log';
    open (LOG, ">>$log_file") || return unable_to_proceed_message('Unable to open log file.');
    
    
    print LOG "Updating $account_name for failed export: $export_file\n"; 
    
    my $sth1 = $dbh->prepare(qq
                            [SELECT DISTINCT strAccountNo, strBankCode, strAccountName 
                             FROM tblMoneyLog
                             WHERE intEntityType = ?#$entity_type
                             AND intEntityID = ? #$entity_id
                             AND intExportBankFileID = ?#$export_file
                            ]);
    
    $sth1->execute($entity_type, $entity_id, $export_file);
    my ($existing) = $sth1->fetchall_arrayref();
    
    foreach my $existing_details (@{$existing}) {
        print LOG "Existing values: $existing_details->[0], $existing_details->[1], $existing_details->[2]\n";
    }
    

    
    my $sth2 = $dbh->prepare(
                            qq[
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
    
    $sth2->execute($account_number, $bsb_number, $account_name, $entity_type, $entity_id, $export_file);
    my $rows = $sth2->rows;

    print LOG "Updating details to: $account_number, $bsb_number, $account_name\n";
    print LOG "Complete: $rows records updated.\n\n";
    close LOG;
    
    my $html = qq[
                  <h1>Resend NAB payments by Export File for an Entity</h1>
                  <h2>Update Summary</h2>

                  <p>Updated $rows records for:</p>

                  <ul>
                  <li>Export File: $export_file</li>
                  <li>Account Name: $account_name</li>
                  <li>Account Number: $account_number</li>
                  <li>BSB Number: $bsb_number</li>
                  </ul>
                  
                  <p><a href="resend_nab_payments.cgi">Click here to resend more NAB payments</a></p>
              ];
    
    return $html;
}








 
# print "Complete: $rows updated.\n";


