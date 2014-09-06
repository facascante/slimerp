#!/usr/bin/perl -w

#
# $Header: svn://svn/SWM/trunk/web/admin/index.cgi 9899 2013-11-21 02:51:34Z fkhezri $
#

use lib "../..","..",".","../RegoForm/";
#use lib "/u/regonew_live","/u/regonew_live/web","/u/regonew_live/web/admin";
use DBI;
use CGI qw(param unescape escape);
use Defs;
use Utils;
use strict;
use CopyMemberWizard;
use Data::Dumper;

main();

sub main	{

# Variables coming in
	my $header = "Content-type: text/html\n\n";
	my $body = "";
	my $title = "$Defs::sitename Administration";
	
	my $output=new CGI;
	my $action = param('action') || param('a') || '1';
	my $step_number = param('step_number');
 	my $realm= param('realm') || '';
	
	my $option = param('option') || '';
	my $realmID = param('realmID') || '';
	my $realmName = param('RealmName') || '';
	
	my $AssocID = param('Assoc') ||  param('fromAssoc') ||  '';
	my $fromClub= param('fromClub') || '';
	my $AssocName = param('AssocName') ||  param('fromAssocName') ||  '';
	my $fromClubName= param('fromClubName') || '';
	
	my $toAssoc = param('toAssoc') || '';
	my $toClub= param('toClub') || '';
	my $toAssocName = param('toAssocName') || '';
	my $toClubName= param('toClubName') || '';
	
	my $FromseasonID= param('FromseasonID') || '';
	my $FromseasonName= param('FromseasonName') || '';
	my $ToseasonID= param('ToseasonID') || '';
	my $ToseasonName= param('ToseasonName') || '';
	
	my $clearOut = param('clearOut') || "false";
	my $activeOldAssoc = param('activeOldAssoc') || "false";
	my $activeNewAssoc = param('activeNewAssoc') || "false";
    
	my $query;
	my $statement;
	my $db=connectDB();
	if($action eq "Load"){
	    if ($option eq 'getRealm')    {
	       
		$statement = qq[
		    SELECT
			R.intRealmID,
			R.strRealmName
		    FROM
			tblRealms AS R
		    ORDER BY
			R.strRealmName
		];
		$query = $db->prepare($statement) or query_error($statement);
		$query->execute() or query_error($statement);
		$body = qq[<option value ="0">Choose a realm</option>];
		while(my $dref= $query->fetchrow_hashref()) {
		    $body .= qq[
				<option value ="$dref->{intRealmID}">$dref->{strRealmName}</option>
			    ];
		}
	    }
	    elsif($option eq 'getAssoc'){
	       
		$statement = qq[
		    SELECT
			intAssocID,
			strName
		    FROM
			tblAssoc 
		    WHERE 
			intRealmID = ?
			AND intRecStatus != -1
		    ORDER By
			strName
		];
		$query = $db->prepare($statement) or query_error($statement);
		$query->execute($realmID) or query_error($statement);
		$body .= qq[<option value ="0">Choose a Association</option>];
		while(my $dref= $query->fetchrow_hashref()) {
		    $body .= qq[
				<option value ="$dref->{intAssocID}">$dref->{strName}</option>
			    ];
		 }
	    }
	    elsif ($option eq 'getClub') {
		$statement = qq[
		    SELECT
			DISTINCT
			tblClub.intClubID,
			tblClub.strName
		    FROM
			tblClub
			JOIN tblAssoc_Clubs ON tblClub.intClubID=tblAssoc_Clubs.intClubID
			JOIN tblAssoc ON tblAssoc.intAssocID=tblAssoc_Clubs.intAssocID
		    WHERE 
			tblAssoc.intAssocID = ? AND tblClub.intRecStatus <> $Defs::RECSTATUS_DELETED
		    ORDER BY tblClub.strName
		];
		$query = $db->prepare($statement) or query_error($statement);
		$query->execute($AssocID) or query_error($statement);
		$body .= qq[<option value ="0">Choose a Club</option>];
		while(my $dref= $query->fetchrow_hashref()) {
		$body .= qq[
			    <option value ="$dref->{intClubID}">$dref->{strName}</option>
			];
		}
		
	    }
        elsif ($option eq 'getFromSeason') {
		$statement = qq[
		    SELECT
			intAssocTypeID
		    FROM
			tblAssoc
		    WHERE 
			intAssocID = ?
		];
		$query = $db->prepare($statement) or query_error($statement);
		$query->execute($AssocID) or query_error($statement);
		my $subRealm =$query->fetchrow_array() || 0; 
		$statement = qq[
		    SELECT
			intSeasonID,
			strSeasonName
		    FROM
			tblSeasons
		    WHERE 
			intRealmID = ?
			AND (intRealmSubTypeID = ? OR intRealmSubTypeID =0)
			AND (intAssocID = ? OR intAssocID =0)
			ORDER BY intSeasonOrder, strSeasonName
		];
		$query = $db->prepare($statement) or query_error($statement);
		$query->execute($realmID,$subRealm,$AssocID) or query_error($statement);
		$body .= qq[<option value ="0">Choose a Season</option>];
		while(my $dref= $query->fetchrow_hashref()) {
		    $body .= qq[
				<option value ="$dref->{intSeasonID}">$dref->{strSeasonName}</option>
			    ];
		}
		
	    }
        elsif ($option eq 'getToSeason') {
		$statement = qq[
		    SELECT
			intAssocTypeID
		    FROM
			tblAssoc
		    WHERE 
			intAssocID = ?
		];
		$query = $db->prepare($statement) or query_error($statement);
		$query->execute($AssocID) or query_error($statement);
		my $subRealm =$query->fetchrow_array() || 0; 
		$statement = qq[
		    SELECT
			intSeasonID,
			strSeasonName
		    FROM
			tblSeasons
		    WHERE 
			intRealmID = ?
			AND (intRealmSubTypeID = ? OR intRealmSubTypeID =0)
			AND (intAssocID = ? OR intAssocID =0)
			ORDER BY intSeasonOrder, strSeasonName
		];
		$query = $db->prepare($statement) or query_error($statement);
		$query->execute($realmID,$subRealm,$toAssoc) or query_error($statement);
		$body .= qq[<option value ="0">Choose a Season</option>];
		while(my $dref= $query->fetchrow_hashref()) {
		    $body .= qq[
				<option value ="$dref->{intSeasonID}">$dref->{strSeasonName}</option>
			    ];
		}
		
	    } 
        elsif ($option eq "review") {
		
		$body =qq[Realm: $realmName ($realmID) <br/>
			    From Assoc:  :$AssocName ($AssocID)<br/>
			    From Club: $fromClubName ($fromClub)<br/>
			    From Season: $FromseasonName ($FromseasonID)<br/>
			    To Assoc: $toAssocName ($toAssoc) <br/>
			    To Club: $toClubName ($toClub) <br/>
			    To Season: $ToseasonName ($ToseasonID)<br/>
			    
			    ];
			    $body .= qq[Clear out From Source association:];
			    $body .= $clearOut eq 'true' ?"Yes":"No";
			    $body .= qq[<br/>Keep member active in source association: ];
			    $body .= $activeOldAssoc eq 'true' ?"Yes":"No";
			    $body .= qq[<br/>change status for all transfered member to active in destination club:];
			    $body .= $activeNewAssoc eq 'true' ?"Yes":"No";
			    $body .= qq[<br/>];
					
		my ($res, undef,undef)= cal_MembeNumber($db, $AssocID,$fromClub,$FromseasonID);
		$body .= qq[$res<br/><b>Please Do not click on "Finish" if you believe the numbers are not matching with reality.</b>];
	    }
    
	} 
     elsif ($action eq  "Finish") {
	    my %params=();
	    $params{'ClearOut'} = ($clearOut eq 'false') ? 0:1 ;
	    $params{'ActiveNewAssoc'} = ($activeNewAssoc eq 'false') ? 0:1 ;
	    $params{'ActiveOldAssoc'} = ($activeOldAssoc eq 'false') ? 0:1 ;
	    $body = Copy_Members($db, $AssocID,$fromClub,$toAssoc,$toClub,$FromseasonID,$ToseasonID,\%params);
	   
	}
	else {
	    $body = qq[Something is wrong!!];
	}
    
    disconnectDB($db) if $db;
    my $contentType ="html";
    print "Content-type:$contentType\n\n";
    print $body;
}


