#!/usr/bin/perl -w

#
# $Header: svn://svn/SWM/trunk/automatic/clearance_dtDue.pl 8820 2013-06-27 23:42:31Z dhanslow $
#

use lib "../web","..","../web/comp/";
use Defs;
use Utils;
use DBI;
use strict;
use Lang;
use SystemConfig;
use Clearances;


{
my $db=connectDB();

my $lastupdate='';
	my %Data=();
        my $lang= Lang->get_handle() || die "Can't get a language handle!";
        $Data{'lang'}=$lang;
        my $target='main.cgi';
        $Data{'target'}=$target;
        $Data{'db'}=$db;
        # AUTHENTICATE
        ($Data{'Realm'}, $Data{'RealmSubType'})= (2,0);
        $Data{'SystemConfig'}=getSystemConfig(\%Data);


	my $st = qq[
		SELECT 
			C.intClearanceID,
			CPDestinationAssocID.intClearancePathID as ToPathID,
			C.intDestinationAssocID
		FROM tblClearance as C
			INNER JOIN tblSystemConfig as SC ON (SC.intRealmID=C.intRealmID
				AND SC.strOption = 'Clearance_ApproveDateDue'
			)
			INNER JOIN tblClearancePath as CP ON (CP.intClearanceID = C.intClearanceID
				AND CP.intClearancePathID = C.intCurrentPathID
			)
			LEFT JOIN tblClearancePath as CPDestinationAssocID ON (CPDestinationAssocID.intClearanceID = C.intClearanceID
				AND CPDestinationAssocID.intID = C.intDestinationAssocID
				AND CPDestinationAssocID.intTypeID=5
			)
		WHERE 
			dtDue >= DATE_ADD(CURRENT_DATE(), INTERVAL -7 DAY)
			AND dtDue < CURRENT_DATE()
			AND intCreatedFrom=0
			AND C.intClearanceStatus=0
			AND CP.intClearanceStatus<>2
			AND intClearanceYear>=2013
			AND C.intRealmID=2
			AND C.intSourceClubID >0
			AND C.intDestinationClubID >0
			AND C.intCurrentPathID < CPDestinationAssocID.intClearancePathID
			AND (CP.intID <> C.intDestinationAssocID 
				OR CP.intID <> C.intDestinationClubID
			)
	];

        my $query = $db->prepare($st);
        $query->execute;
	my @clearances=();
        while (my($intClearanceID, $ToPathID, $assocID) = $query->fetchrow_array) {
		$intClearanceID ||= 0;
		$Data{'clientValues'}{'assocID'} = $assocID; #Needed for Inserting final records
		$ToPathID ||= 0;
		next if (! $intClearanceID or ! $ToPathID);
		my $st_path = qq[
			UPDATE 
				tblClearancePath
			SET
				intClearanceStatus = 1,
				strApprovedBy = 'TIME LIMIT APPLIED'
			WHERE
				intClearanceID = $intClearanceID
				AND intClearancePathID < $ToPathID
				AND intClearanceStatus=0
		];
		$db->do($st_path);
		my $st_clr= qq[
			UPDATE 
				tblClearance
			SET 
				intCurrentPathID = $ToPathID
			WHERE 
				intClearanceID = $intClearanceID
		];
		$db->do($st_clr);

		## DAVID: MIGHT BE WORTH CALLING THIS:
		checkAutoConfirms(\%Data, $intClearanceID, $ToPathID);
		push @clearances, $intClearanceID;

		$st = qq[
                        SELECT
                                intClearancePathID,
                                intClearanceStatus
                        FROM
                                tblClearancePath
                        WHERE
                                intClearanceID = $intClearanceID
                        ORDER BY
                                intOrder DESC
                        LIMIT 1
                ];
                my $query = $db->prepare($st) or query_error($st);
                $query->execute or query_error($st);
                my ($intFinalCPID, $intClearanceStatus) = $query->fetchrow_array();

                if ($intClearanceStatus == $Defs::CLR_STATUS_APPROVED)  {
                        finaliseClearance(\%Data, $intClearanceID);
                }

		###sendCLREmail(\%Data, $intClearanceID, 'AFL_REMINDER');
	}
	for my $clrID (@clearances) {
		sendCLREmail(\%Data, $clrID, 'AFL_REMINDER');
	}
	
}


