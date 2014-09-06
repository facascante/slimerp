#!/usr/bin/perl -w

#
# $Header: svn://svn/SWM/trunk/web/locator/coach_data.cgi 8249 2013-04-08 08:14:07Z rlee $
#

use strict;
use lib ".", "..", "../../";

use CGI qw(:cgi escape unescape);
use Utils;

my $cgi = new CGI;
my $memberID = $cgi->param('coachID');
return '' if !$memberID;


my %Fields = (
              Name =>                {'dbfield' => 'CONCAT(strFirstname," ", strSurname)', label=>'', htmlstart=>'<h1 class="csc-firstHeader">', htmlend=>'</h1>'},
              CurrentClubPosition => {'dbfield' => 'CONCAT(strCustomStr3," - ", strCustomStr4)', label=>'', htmlstart=>'<p class="bodytext"><b>', htmlend=>'</b></p>'},
              DOB =>                 {'dbfield' => 'DATE_FORMAT(dtDOB, "%d/%m/%Y")', label=>'<b>DOB:</b>', labelnohtml=> 'DOB', htmlstart=>'<p class="bodytext">', htmlend=>'</p>'},
              PlayingRecord =>       {'dbfield' => 'strMemberCustomNotes4', label=>'<b>Playing record:</b><br />',  labelnohtml=>'Playing record', htmlstart=>'<p class="bodytext">', htmlend=>'</p>'},
              CoachingRecord =>      {'dbfield' => 'strMemberCustomNotes1', label=>'<b>Coaching record:</b><br />', lablenohtml=>'Coaching record', htmlstart=>'<p class="bodytext">', htmlend=>'</p>'},
              CoachingRoleSkills =>  {'dbfield' => 'strMemberCustomNotes3', label=>'', label=>'', htmlstart=>'<p class="bodytext">', htmlend=>'</p>'},
          );


my @FieldsOrder = qw(Name CurrentClubPosition DOB PlayingRecord CoachingRecord CoachingRoleSkills);
if ($cgi->param('fields')) {
    @FieldsOrder = split(/\|/, $cgi->param('fields'));
}

my $select_fields = '';
foreach my $field(@FieldsOrder) {
    $select_fields .= $Fields{$field}->{dbfield} . " AS $field,";
}
$select_fields =~s/,$//;


my $dbh = connectDB();

my $query = qq[SELECT $select_fields FROM tblMember as M 
               INNER JOIN tblMemberNotes as MN ON (MN.intNotesMemberID = M.intMemberID) 
               INNER JOIN tblMember_Associations as MA ON (MA.intMemberID = M.intMemberID AND MA.intAssocID=MN.intNotesAssocID) 
               INNER JOIN tblAssoc as A ON (A.intAssocID=MA.intAssocID AND A.intAssocTypeID=8) 
               WHERE M.intMemberID = $memberID
               AND M.intRealmID=2 and MA.intCustomBool2=1
               ];

my $sth = $dbh->prepare($query);
$sth->execute();
my $hashref = $sth->fetchrow_hashref();

my $output='';
$output .=  "Content-type: application/x-javascript\n\n";
foreach my $field (@FieldsOrder) {
    my $value = $hashref->{$field};
    $value=~s/[\r|\n]+/<br>/g;
	$value =~ s/\'/\\\'/g;

    my $line = '';
    
    $line .= $Fields{$field}->{htmlstart} if !$cgi->param('dataonly');
    $line .= $Fields{$field}->{label} if !$cgi->param('dataonly');
    $line .= $value;
    $line .= $Fields{$field}->{htmlend} if !$cgi->param('dataonly');

    $output .= "document.writeln('$line');\n" if $line ne '';
    
}
print $output;
exit;




