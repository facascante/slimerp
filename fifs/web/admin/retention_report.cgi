#!/usr/bin/perl -w

#
# $Header: svn://svn/SWM/trunk/web/admin/pms_stats.cgi 9861 2013-11-11 02:56:53Z fkhezri $
#

use strict;
use lib "../..","..",".","../comp";
use DBI;
use CGI qw(param unescape escape);
use Defs;
use Utils;
use HTMLForm qw(_date_selection_box);
use Defs;
use Date::Calc qw(Today);
use ExportEmailData;
use AdminPageGen;

main();

sub main    {
	my $db    = connectDB();
	$db->{mysql_auto_reconnect} = 1;
        $db->{wait_timeout} = 3700;
        $db->{mysql_wait_timeout} = 3700;
	my $body = runReport($db);
	disconnectDB($db) if $db;
    	print_adminpageGen($body, "", "");
}


sub runReport	{

	my ($db) = @_;
	
	my $st = qq[
SELECT M.intMemberID, A1.intAssocID as A1assocID, A1.strName as '2012A', A2.strName as '2013A', A2.intAssocID as A2assocID, C2.strName as '2013C', C2.intClubID as C2clubID,AC2.intAssocID as AC2assocID
FROM

tblTempNodeStructure TNS
INNER JOIN tblAssoc A1 ON A1.intAssocID = TNS.intAssocID
INNER JOIN tblMember_Seasons_2 S1 ON S1.intAssocID = A1.intAssocID AND S1.intClubID=0 AND S1.intSeasonID=2989 AND S1.intMSRecStatus>-1
INNER JOIN tblMember M ON M.intMemberID = S1.intMemberID AND M.intStatus>-1 AND M.intRealmID=2
LEFT JOIN tblMember_Seasons_2 S2 ON S1.intMemberID = S2.intMemberID AND S2.intSeasonID=3023 AND S2.intMSRecStatus>-1 
LEFT JOIN tblAssoc A2 ON A2.intAssocID = S2.intAssocID AND S2.intClubID=0
LEFT JOIN tblAssoc AC2 ON AC2.intAssocID = S2.intAssocID AND S2.intClubID>0
LEFT JOIN tblClub C2 ON C2.intClubID = S2.intClubID

WHERE TNS.int30_id = 3955
GROUP BY M.intMemberID, C2.intClubID, A2.intAssocID, AC2.intAssocID	];
#warn "$st";
#WHERE TNS.int10_id = 5899 AND A1.intAssocID=17881
	my $body = qq[
<table cellpadding=8 cellspacing=0 border=1>
	<tr>
		<th>2012 Count (A)</th>	
		<th>Assoc Name</th>	
		<th>2013 Count (A)</th>	
		<th>Assoc Name</th>	
		<th>2013 Count (C)</th>	
		<th>Club Name</th>	
	</tr>
	];

	my $query = $db->prepare($st);
	$query->execute;

	my %origCount;
	my %assocCount;
	my %clubCount;
	my @clubToAssoc;
	my @assocName;
	my @clubName;
	while (my $dref =$query->fetchrow_hashref())	{
                       foreach my $key (keys %{$dref}) {
			 if(!defined $dref->{$key})      {
                                        $dref->{$key}=0;
                         }       }

				$clubName[$dref->{'C2clubID'}] = $dref->{'2013C'} if($dref->{'C2clubID'} and undef($clubName[$dref->{'C2clubID'}]));	
				$assocName[$dref->{'A1assocID'}] = $dref->{'2012A'} if($dref->{'A1assocID'} and undef($assocName[$dref->{'A1assocID'}] ));	
				$assocName[$dref->{'A2assocID'}] = $dref->{'2013A'} if($dref->{'A2assocID'} and undef($assocName[$dref->{'A2assocID'}]));	
				$clubToAssoc[$dref->{'C2clubID'}] = $dref->{'AC2assocID'} if($dref->{'C2clubID'} and $dref->{'AC2assocID'});	
				$origCount{$dref->{'A1assocID'}}{$dref->{'intMemberID'}} = 1;	
				$assocCount{$dref->{'A1assocID'}}{$dref->{'A2assocID'}}{$dref->{'intMemberID'}} = 1 if(!$dref->{'C2clubID'});	
				$clubCount{$dref->{'A1assocID'}}{$dref->{'C2clubID'}}{$dref->{'intMemberID'}} = 1 if(!$dref->{'A2assocID'});	
	}

	foreach my $i (keys %clubCount)        {
	foreach my $j (keys %{$clubCount{$i}})        {
		my $origTotal = keys %{$origCount{$i}} || 0;
		my $assocTotal = keys %{$assocCount{$i}{$clubToAssoc[$j]}} || 0;
		my $clubTotal = keys %{$clubCount{$i}{$j}} || 0;
		$body .=qq[<tr>
                <td>$origTotal</td>
                <td>$assocName[$i]</td>
                <td>$assocTotal</td>
                <td>$assocName[$clubToAssoc[$j]]</td>
                <td>$clubTotal</td>
                <td>$clubName[$j]</td>
        	</tr>
		];

	  }
	 }

	#use Data::Dumper;
	#print STDERR Dumper(\%clubCount);


	$body .= qq[</table>];
	return $body;


}
1;
