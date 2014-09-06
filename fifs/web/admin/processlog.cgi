#!/usr/bin/perl -w

#
# $Header: svn://svn/SWM/trunk/web/admin/processlog.cgi 9152 2013-08-05 05:51:46Z drum $
#

use strict;
use lib ".", "..", "../..";
use DBI;
use CGI qw(param unescape escape url);
use Defs;
use Utils;
use Defs;
use Date::Calc qw(Today);
use ExportEmailData;
use AdminPageGen;

main();

sub main {
    my $body = "";

    my $db = Utils::connectDB();
    if ($db) {
        my $this_script = CGI::url(-absolute => 1);
        my $type = CGI::param("type") || undef;
        my $realmID = CGI::param("realmID") || undef;
        my $assocID = CGI::param("assocID") || undef;
        my $dtStarted = CGI::param("dtStarted") || undef;
        if ($dtStarted) {
            $dtStarted = CGI::unescape($dtStarted);
        }

        if (! $assocID) {
            $body = _getProcessLogReport($db, $this_script, $type, $realmID);
        }
        else {
            $body = _getProcessRunLogReport($db, $this_script, $assocID, $dtStarted);
        }

        Utils::disconnectDB($db);
    }

    AdminPageGen::print_adminpageGen($body, "", "");
}

sub _getProcessLogReport	{
	my ($db, $this_script, $type, $realmID) = @_;

    my $where = "";
    if ($type || $realmID) {
        $where = "WHERE ";
        if ($type) {
            $where .= "PL.intTypeID = " . $type;
        }
        if ($realmID) {
            if ($type) {
                $where .= " AND ";
            }
            $where .= "A.intRealmID = " . $realmID;
        }
    }

    my $st = qq[
        SELECT 
            PL.*,
            A.strName as AssocName,
            A.intRealmID as intRealmID
        FROM
        tblCompProcessLog as PL
            INNER JOIN tblAssoc as A ON (
                A.intAssocID=PL.intAssocID
            )
        $where
        ORDER BY
            dtStarted DESC
    ];

	my $body = qq[
<h2 style="text-align:center;">tblCompProcessLog</h2>
<table border="1" style="margin-left:auto; margin-right:auto;">
	<tr>
		<th>#</th>	
		<th>Assoc Name</th>	
		<th>Assoc ID</th>	
		<th>CompID</th>	
		<th>Realm ID</th>	
		<th>Log Type ID</th>	
		<th>Log Name</th>	
		<th>Pool ID</th>	
		<th>dt Added</th>	
		<th>dt Started</th>	
		<th>dt Completed</th>	
		<th>Status</th>	
	</tr>
	];

	my $query = $db->prepare($st);
	$query->execute;

	my $count=1;
	while (my $dref =$query->fetchrow_hashref()) {
        my $realm_url = "$this_script?realmID=$dref->{'intRealmID'}";
        if ($type) {
            $realm_url .= "&type=" . $type;
        }

        my $type_url = "$this_script?type=$dref->{'intTypeID'}";
        if ($realmID) {
            $type_url .= "&realmID=" . $realmID;
        }

        my $compprocesslogrun_url = "";
        if ($dref->{'dtStarted'}) {
            $compprocesslogrun_url = "$this_script?assocID=" . $dref->{'intAssocID'} . "&dtStarted=" . CGI::escape($dref->{'dtStarted'});
        }

        $body .= qq[ <tr> ];
		$body .= qq[
                <td>$count.</td>
				<td>$dref->{'AssocName'}</td>
				<td>$dref->{'intAssocID'}</td>
				<td>$dref->{'intCompID'}</td>
				<td><a href="$realm_url">$dref->{'intRealmID'}</a></td>
				<td><a href="$type_url">$dref->{'intTypeID'}</a></td>
				<td>$dref->{'strProcessName'}</td>
				<td>$dref->{'intPoolID'}</td>
				<td>$dref->{'dtAdded'}</td>
        ];

        if ($dref->{'dtStarted'}) {
            if ($compprocesslogrun_url) {
                $body .= qq[ <td><a href="$compprocesslogrun_url">$dref->{'dtStarted'}</a></td> ];
            }
            else {
                $body .= qq[ <td>$dref->{'dtStarted'}</td> ];
            }
        }
        else {
            $body .= qq[ <td>&nbsp;</td> ];
        }

        if ($dref->{'dtCompleted'}) {
            $body .= qq[ <td>$dref->{'dtCompleted'}</td> ];
        }
        else {
            $body .= qq[ <td>&nbsp;</td> ];
        }

        my $status = $dref->{'intStatus'};
        if ($dref->{'intStatus'} == $Defs::PROCESSLOG_WAITING) {
            $status = 'Waiting';
        }
        elsif ($dref->{'intStatus'} == $Defs::PROCESSLOG_RUNNING) {
            $status = 'Running';
        }
        elsif ($dref->{'intStatus'} == $Defs::PROCESSLOG_COMPLETED) {
            $status = 'Completed';
        }
        elsif ($dref->{'intStatus'} == $Defs::PROCESSLOG_FAILED) {
            $status = 'Failed';
        }
        $body .= qq[ <td>$status</td> ];

        $body .= qq[ </tr> ];
		$count++;
	}

	$body .= qq[</table>];
	return $body;
}

sub _getProcessRunLogReport	{
	my ($db, $this_script, $assocID, $dtStarted) = @_;

    my $where = "";
    if ($assocID || $dtStarted) {
        $where = "WHERE ";
        if ($assocID) {
            $where .= "PLR.intAssocID = " . $assocID;
        }
        if ($dtStarted) {
            if ($assocID) {
                $where .= " AND ";
            }
            $where .= "PLR.dtStarted = '" . $dtStarted . "'";
        }
    }

    my $st = qq[
        SELECT 
            PLR.*,
            A.strName as AssocName,
            A.intRealmID as intRealmID
        FROM
            tblCompProcessLogRun as PLR
            INNER JOIN tblAssoc as A ON (
                A.intAssocID=PLR.intAssocID
            )
        $where
        ORDER BY
            dtAdded
    ];

	my $body = qq[
<h2 style="text-align:center;">tblCompProcessLogRun</h2>
<table border="1" style="margin-left:auto; margin-right:auto;">
	<tr>
		<th>#</th>	
		<th>Assoc Name</th>	
		<th>Assoc ID</th>	
		<th>Realm ID</th>	
		<th>Process Name</th>	
		<th>dt Added</th>	
		<th>dt Started</th>	
		<th>dt Ended</th>	
	</tr>
	];

	my $query = $db->prepare($st);
	$query->execute;

	my $count=1;
	while (my $dref =$query->fetchrow_hashref()) {
		$body .= qq[
            <tr>
                <td>$count.</td>
				<td>$dref->{'AssocName'}</td>
				<td>$dref->{'intAssocID'}</td>
				<td>$dref->{'intRealmID'}</a></td>
				<td>$dref->{'strProcessName'}</td>
				<td>$dref->{'dtAdded'}</td>
				<td>$dref->{'dtStarted'}</td>
				<td>$dref->{'dtEnded'}</td>
			</tr>
		];
		$count++;
	}

	$body .= qq[</table>];
	return $body;
}
