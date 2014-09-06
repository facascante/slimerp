#!/usr/bin/perl -T

#
# $Header: svn://svn/SWM/trunk/web/viewdupl.cgi 10108 2013-12-03 01:31:15Z tcourt $
#

use strict;
use warnings;
use CGI qw(param);
use lib "..",".";
use Defs;
use Reg_common;
use Utils;
use Lang;
use SystemConfig;
use ConfigOptions;
use PageMain;

main();	

sub main	{
	# GET INFO FROM URL
	my $client=param('client') || '';
  my $action = safe_param('a','action') || '';

  my %Data=();
  my $target='lookupmanage.cgi';
  $Data{'target'}=$target;
  my %clientValues = getClient($client);
  $Data{'clientValues'} = \%clientValues;
  my $db=allowedTo(\%Data);
  ($Data{'Realm'},$Data{'RealmSubType'})=getRealm(\%Data);

  getDBConfig(\%Data);
  $Data{'SystemConfig'}=getSystemConfig(\%Data);
  my $lang   = Lang->get_handle('', $Data{'SystemConfig'}) || die "Can't get a language handle!";
  $Data{'lang'}=$lang;

  $Data{'LocalConfig'}=getLocalConfig(\%Data);
  my $assocID=getAssocID(\%clientValues) || '';
  $clientValues{'currentLevel'} = safe_param('cl','number') if (safe_param('cl','number') and safe_param('cl','number') <= $clientValues{'authLevel'});

  my $DataAccess_ref=getDataAccess(\%Data);
  $Data{'Permissions'}=GetPermissions(
    \%Data,
    $clientValues{'authLevel'},
    getID(\%clientValues, $clientValues{'authLevel'}),
    $Data{'Realm'},
    $Data{'RealmSubType'},
    $clientValues{'authLevel'},
    0,
  );

  $Data{'DataAccess'}=$DataAccess_ref;

	my ($resultHTML , $pageHeading)= viewDuplicateInfo(\%Data);

  # BUILD PAGE
  $client=setClient(\%clientValues);
  $clientValues{INTERNAL_db} = $db;
	#my $pageHeading = '';
  $resultHTML ||= textMessage("An invalid Action Code has been passed to me.");
  $resultHTML=qq[
    <div class="pageHeading">$pageHeading</div>
    $resultHTML
  ] if $pageHeading;

  printBasePage($resultHTML, 'Sportzware Membership');

  disconnectDB($db);

}

sub viewDuplicateInfo	{

	my ($Data) = @_;

	my $memberID = $Data->{'clientValues'}{'memberID'};

	my $st_mem = qq[
		SELECT 
			strFirstname,
			strSurname,
			DATE_FORMAT(dtDOB, "%d/%m/%Y") as DOB,
			intGender,
			strAddress1,
			strAddress2,
			strSuburb,
			strPostalCode
		FROM
			tblMember as M 
		WHERE
			M.intMemberID=?
		LIMIT 1
	];
	my $qry_mem = $Data->{'db'}->prepare($st_mem);
	$qry_mem->execute($memberID);
	my $mref=$qry_mem->fetchrow_hashref();

	my $st = qq[
		SELECT 
			DISTINCT
			A.intAssocID,
			A.strName as AssocName,
			MA.intRecStatus
		FROM
			tblMember_Associations as MA 
			INNER JOIN tblAssoc as A ON (
				A.intAssocID=MA.intAssocID
			)
		WHERE
			MA.intMemberID=?
		ORDER BY 
			A.strName
	];

	my $qry = $Data->{'db'}->prepare($st);
	$qry->execute($memberID);
	my $body=qq[
		<div><span class="label">Gender:</span> $Defs::PersonGenderInfo{$mref->{'intGender'}}</div>
		<div><span class="label">Date of Birth:</span> $mref->{'DOB'}</div>
	];
	$body .= qq[ <div><span class="label">Address Line 1:</span> $mref->{'strAddress1'}</div> ] if ($mref->{'strAddress1'});
	$body .= qq[ <div><span class="label">Address Line 2:</span> $mref->{'strAddress2'}</div> ] if ($mref->{'strAddress2'});
	$body .= qq[ <div><span class="label">Suburb:</span> $mref->{'strSuburb'}</div> ] if ($mref->{'strSuburb'});
	$body .= qq[ <div><span class="label">Postal Code:</span> $mref->{'strPostalCode'}</div> ] if ($mref->{'strPostalCode'});

	my $st_clubs = qq[
		SELECT
			DISTINCT
			C.strName as ClubName,
			MC.intStatus,
			MC.intPermit,
			DATE_FORMAT(MC.dtPermitStart, "%d/%m/%Y") as PermitStart,
			DATE_FORMAT(MC.dtPermitEnd, "%d/%m/%Y") as PermitEnd
		FROM
			tblMember_Clubs as MC
			INNER JOIN tblAssoc_Clubs as AC ON (
				AC.intClubID=MC.intClubID
			)
			INNER JOIN tblClub as C ON (
				C.intClubID=MC.intClubID
			)
		WHERE
			MC.intMemberID=?
			AND AC.intAssocID=?
		ORDER BY
			C.strName
	];
	my $qry_clubs = $Data->{'db'}->prepare($st_clubs);
	while (my $dref=$qry->fetchrow_hashref()) {
		$body .= qq[<div class="sectionheader">$dref->{'AssocName'}</div>];
		$qry_clubs->execute($memberID, $dref->{'intAssocID'});
		my $subBody=qq[
			<table class="listTable" style="width:100%;">
				<tr>
					<td><b>$Data->{'LevelNames'}{$Defs::LEVEL_CLUB}</b></td>
					<td><b>Status</b></td>
				</tr>
		];
		my $clubCount=0;
		while (my $cref=$qry_clubs->fetchrow_hashref()) {
			$clubCount++;
			my $onPermit= ($cref->{'intPermit'}) ? qq[ (On Permit) ] : '';
			my $status = 'Active';
			$status='Inactive' if ($cref->{'intStatus'} == 0);
			$status='Deleted' if ($cref->{'intStatus'} == -1);
			$subBody .= qq[
				<tr>
					<td>$cref->{ClubName}</td>
					<td>$status$onPermit</td>
				</tr>
			];
		}
		$subBody .= qq[</table>];
		$body .= $subBody if ($clubCount);
	}

	return ($body, "$mref->{'strFirstname'} $mref->{'strSurname'}");

}


