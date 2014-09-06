#!/usr/bin/perl -w

#
# $Header: svn://svn/SWM/trunk/misc/sales_numbers.pl 8250 2013-04-08 08:24:36Z rlee $
#

use lib "../web","..";
use Defs;
use Utils;
use DBI;
use Date::Calc qw(Today Add_Delta_YM);
use FileHandle;
use strict;

my %Data=();
my $db=connectDB();

$db->{mysql_auto_reconnect} = 1;
        $db->{wait_timeout} = 3700;
        $db->{mysql_wait_timeout} = 3700;

	my $realm_st = qq[
		SELECT NS.intRealmID, NS.intAssocID, A.strName as AssocName, S.strName as StateName, R.strRealmName
		FROM tblRealms as R
			INNER JOIN tblTempNodeStructure as NS ON (NS.intRealmID = R.intRealmID)
			INNER JOIN tblAssoc as A ON (NS.intAssocID = A.intAssocID)
        		LEFT JOIN tblNode AS S  ON S.intNodeID=int30_ID
		WHERE R.intRealmID NOT IN (6,35)
		ORDER BY R.intRealmID , NS.intAssocID
	];
    	my $realm_qry = $db->prepare($realm_st) or query_error($realm_st);
  my @agebands=(
    ['0-4',0,4],
    ['4-11',4,11],
    ['12-14',12,14],
    ['15-17',15,17],
    ['18-24',18,24],
    ['25-34',25,34],
    ['35-44',35,44],
    ['45-54',45,54],
    ['55-64',55,64],
    ['65 and over',65,200],
    ['Unknown',0,0],
  );
	my %states=();
  {
    my ($today_year,$today_month,$today_day)= Today();

    my %upperage=();
    my $sql='';
    my $cnt=0;
    for my $ageband (@agebands) {
      next if !$ageband->[2];
      my($y, $m, $d)=Add_Delta_YM($today_year, $today_month, $today_day, $ageband->[2]*-1,0);
      $upperage{$ageband->[0]}="$y-$m-$d";
      $sql.=qq[ IF(dtDOB > '$upperage{$ageband->[0]}', '$ageband->[0]', ];
      $cnt++;
    }
    $sql.=qq[ 'Unknown' ]. (')' x $cnt);


    	my $header = qq[REALM	STATE	ASSOC	CLUB	GENDER	POSTAL CODE	PLAYER	OTHER	AGE	COUNT\n];
    $realm_qry->execute or query_error($realm_st);
	my $rID=0;
	my $realmName='';
	my $body='';




    while(my($realmID, $assocID, $assocName, $state, $realm ) = $realm_qry -> fetchrow_array()) {
	if ($rID != $realmID) {
		$rID=$realmID;
		$realmName=$realm;
	}
    my $seasonWHERE= qq[ AND MS.intSeasonID = A.intCurrentSeasonID ];
    $seasonWHERE = qq[ AND MS.intSeasonID = 16 ] if $realmID == 2;
    $seasonWHERE = qq[ AND MS.intSeasonID = 197 ] if $realmID == 3;
    my $statement=qq[
	SELECT C.strName as ClubName, intPlayer, IF(intCoach=1 or intOfficial=1 or intUmpire=1 or intMisc=1 or intVolunteer=1, 1, 0) as OtherTypes, intGender, M.strPostalCode, $sql as agerange, COUNT(M.intMemberID) AS numMembers

	FROM
		tblTempNodeStructure as NS
        	INNER JOIN tblMember_Associations AS MA ON  MA.intAssocID = NS.intAssocID
            INNER JOIN tblAssoc as A ON (A.intAssocID = MA.intAssocID)
        	INNER JOIN tblMember AS M ON  MA.intMemberID=M.intMemberID
            INNER JOIN tblMember_Seasons_$realmID as MS ON (
                MS.intMemberID = M.intMemberID
                AND MS.intAssocID=MA.intAssocID
                AND MS.intMSRecStatus=1
            )
        	INNER JOIN tblClub AS C ON  MS.intClubID = C.intClubID
	WHERE
        	M.intStatus=1
        	AND MA.intRecStatus <> -1
		    AND NS.intRealmID=$realmID
		    AND NS.intAssocID=$assocID
            $seasonWHERE
	GROUP BY 
		ClubName, 
		intGender, 
		M.strPostalCode,  
		intPlayer, 
		OtherTypes, 
		agerange
    ];

    ## INNER JOIN tblClub WAS LEFT JOIN
    my $query = $db->prepare($statement) or query_error($statement);
	$query->execute() or query_error($statement);
    	while(my($clubName, $player, $othertype, $gender, $postCode, $age, $count) = $query -> fetchrow_array()) {
		$count||=0;
		$state||='';
		$realm||='';
		$gender||='';
		my $TXTgender='';
		$TXTgender = 'M' if $gender and $gender==1;
		$TXTgender = 'F' if $gender and $gender==2;
		$assocName||='';
		$clubName||='';
		$postCode||='';
      		$age||='Unknown';
      		$clubName||='--None--';
		$player||=0;
		$othertype||=0;
      		$clubName='--None--' if ($clubName eq 'NULL');
	        $body .= qq[$realm\t$state\t$assocName\t$clubName\t$TXTgender\t$postCode\t$player\t$othertype\t$age\t$count\n];
        }
    }
	if ($body)	{
			$body = $header.$body;
    			my $filename = "SALES_FILES/sales_swm.csv";
			my $DATAFILE  = new FileHandle;
        		my @errors    = ();
        		open $DATAFILE, ">>$filename" || push @errors, "Cannot open file $filename";
        		my $fileopen = 0;
		        $fileopen    = 1 if !@errors;
        		print $DATAFILE qq[$body] if $fileopen;
		        close $DATAFILE if $fileopen;
			$body = '';
		}


}
exit;


