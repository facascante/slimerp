#!/usr/bin/perl -w

#
# $Header: svn://svn/SWM/trunk/web/locator/coach.cgi 8249 2013-04-08 08:14:07Z rlee $
#

use strict;
use lib ".", "..", "../../";
use Utils;
use CGI;

my $cgi = new CGI;

my $memberID = $cgi->param('coachID');
my $content = '';   

if ($memberID !~/^\d+$/) {
    $content = qq[<p>Invalid ID supplied.<br />Please check and try again.</p>];
}
else {
    my $dbh = connectDB();
    
    my $query = qq[SELECT M.intMemberID, A.strName, strNationalNum, strFirstname, strSurname, 
                   DATE_FORMAT(dtDOB, "%d/%m/%Y"), strCustomStr3, strCustomStr4, 
                   strMemberCustomNotes1, strMemberCustomNotes2,strMemberCustomNotes4
                   FROM tblMember as M 
                   INNER JOIN tblMemberNotes as MN ON (MN.intNotesMemberID = M.intMemberID) 
                   INNER JOIN tblMember_Associations as MA ON (MA.intMemberID = M.intMemberID AND MA.intAssocID=MN.intNotesAssocID) 
                   INNER JOIN tblAssoc as A ON (A.intAssocID=MA.intAssocID AND A.intAssocTypeID=8) 
                   WHERE M.intMemberID = $memberID
                   AND M.intRealmID=2 and MA.intCustomBool2=1
                   ];

    my $sth = $dbh->prepare($query);
    $sth->execute();
    
    my ($memberID,$state,$nationalNo,$firstname,$surname,$dob,$custom3,$custom4,$customNote1,$customNote2,$customNote4) = $sth->fetchrow_array();
    $content = qq[
                  <p>$state</p>
                  <p>$nationalNo</p>
                  <p>$firstname</p>
                  <p>$surname</p>
                  <p>$dob</p>
                  <p>$custom3</p>
                  <p>$custom4</p>
                  <p>$customNote1</p>
                  <p>$customNote2</p>
                  <p>$customNote4</p>
              ];
}


print "Content-type: text/html\n\n";
my $doctype = qq[<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01//EN" 
                    "http://www.w3.org/TR/html4/strict.dtd">
                ];
print $doctype;

my $page= qq[<html>
             <head>
             <style type="text/css" media="screen">
              body {
                    color:#000000;
                    font-family:arial,helvetica,sans-serif;
                    font-size:90%;
                    }
             </style>
             <title></title>
             </head>
             <body>
             $content
             </body>
             </html>
             ];

print $page;
exit;
