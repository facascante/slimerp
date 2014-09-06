#!/usr/bin/perl -w

#
# $Header: svn://svn/SWM/trunk/web/locator/coaches.cgi 8249 2013-04-08 08:14:07Z rlee $
#

use strict;
use lib ".", "..", "../../";
use Utils;

my $dbh = connectDB();


print "Content-type: text/html\n\n";
my $doctype = qq[<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01//EN" "http://www.w3.org/TR/html4/strict.dtd">];
print "$doctype\n";


my $page_start = qq[
                    <html>
                    <head>
                    <style type="text/css" media="screen">
                      body {
                       color:#000000;
                       font-family:arial,helvetica,sans-serif;
                       font-size:90%;
                       margin:0;
                       padding:0;
                      }
                      ul { list-style-type: none; }
                    </style>
                    <title></title>
                    </head>
                    <body>
                   ];
print $page_start;

my $query = qq[SELECT M.intMemberID, strFirstname , strSurname FROM tblMember as M 
               INNER JOIN tblMemberNotes as MN ON (MN.intNotesMemberID = M.intMemberID) 
               INNER JOIN tblMember_Associations as MA ON (MA.intMemberID = M.intMemberID AND MA.intAssocID=MN.intNotesAssocID) 
               INNER JOIN tblAssoc as A ON (A.intAssocID=MA.intAssocID AND A.intAssocTypeID=8) 
               WHERE M.intRealmID=2 and MA.intCustomBool2=1
               ORDER BY strSurname];

my $sth = $dbh->prepare($query);
$sth->execute();


my $coaches = '';
while (my ($memberID,$firstname,$surname) = $sth->fetchrow_array()) {
    $coaches .= qq[<li>
                     <a href="http://reg.sportingpulse.com/v5/locator/coach.cgi?coachID=$memberID">$surname, $firstname - $memberID</a>
                   </li>
                   ];
}


my $content = qq[
                 <ul>
                 $coaches
                 </ul>
              ];

print $content;
print "</body></html>\n";
exit;

