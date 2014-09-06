#!/usr/bin/perl

use strict;
use lib '.', '..','../web';
use CGI qw(param);
use Defs;
use Utils;
use DBI;

main();

sub main {
        
    my $result;
    my $db = connectDB();
        
    my $st = qq[
        SELECT distinct a.intMemberID 
        FROM tblAccreditation a 
        INNER JOIN tblDuplChanges dc ON a.intMemberID = dc.intOldID
        ORDER BY a.tTimeStamp
    ];

  my $query = $db->prepare($st) or query_error($st);
  $query->execute() or query_error($st);
  my $body = "<html><body><h1>Accreditation - Duplicate Resolve Errors</h1>
        <table border=1><tr><td>Count</td><td>Old MemberID</td><td>New MemberID</td></tr>";
  my $memberID;
  my $count = 0;
  
  while(my $dref= $query->fetchrow_hashref()) {

       $memberID = check_duplicate_resolved( $db, $dref->{intMemberID} );

       if ($memberID == $dref->{intMemberID}) {
          $body .= qq[
          <tr>
                  <td>No Change</td>
                  <td>$dref->{intMemberID}</td>
                  <td>$memberID</td>
          </tr>         
        ];
       }
        else {
           $count = $count + 1;
          $body .= qq[
          <tr>
                  <td>$count</td>
                  <td>$dref->{intMemberID}</td>
                  <td>$memberID</td>
          </tr>
        ];
      }

        

  }

$body .= "</table></body></html>";

print "Content-type: text/html\n\n";
print $body;
    
disconnectDB($db);
   
}

sub check_duplicate_resolved {
    my ( $db, $memberID, $recursion_count ) = @_;

    $recursion_count ||= 0;

    my $st = qq[
        SELECT DISTINCT DC.intNewID, M.intMemberID
        FROM tblDuplChanges DC
    LEFT JOIN tblMember M ON M.intMemberID = DC.intNewID
        WHERE DC.intOldID = ?
    ];

    my $q = $db->prepare($st);
    $q->execute( $memberID );
    my ( $newMemberID, $checkedMemberID ) = $q->fetchrow_array(); 
    #checking if member exists to stop circular referencing
    return $checkedMemberID if ($checkedMemberID);
    if ( $newMemberID and $recursion_count < 10 ) {

        #Added a recursion count to stop it getting into an infinite loop if there are
        #circular references in the database
        return check_duplicate_resolved( $db, $newMemberID, $recursion_count + 1 );
    }
    else {
        if ( $recursion_count == 10 ) {
            my $body_text = qq[
                Circular reference detected in tblDuplChanges for member ID $memberID.
            ];
            return 'Circular' . $memberID;
        }
        return $memberID;
    }
}

