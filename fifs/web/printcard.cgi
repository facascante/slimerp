#! /usr/bin/perl -w

#
# $Header: svn://svn/SWM/trunk/web/printcard.cgi 10771 2014-02-21 00:20:57Z cgao $
#

## LAST EDITED -> 18/7/2001 ##

use strict;
use CGI qw(param escape unescape);

use lib '.','..','../..',"PaymentSplit";
use Reg_common;
use PageMain;
use Navbar;
use Defs;
use Utils;
use SystemConfig;
use ConfigOptions;
use Lang;
use TTTemplate;
use SearchLevels;
use MemberCard;
use AuditLog;
use Logo;

main();

sub main	{

	# GET INFO FROM URL
	my $action = param('a') || 'MEMCARD_prev';
	my $cardtype = param('ctID') || '';
	my $client = param('client') || '';
	my $memberIDs= param('ids') || '';

	my %clientValues = getClient($client);
  my %temp_clientValues = getClient($client);
	my %Data=();
	my $target='printcard.cgi';
	$Data{'target'}=$target;
	$Data{'clientValues'} = \%clientValues;
	# AUTHENTICATE
	my $db=allowedTo(\%Data);
  ($Data{'Realm'}, $Data{'RealmSubType'})=getRealm(\%Data);
	$Data{'SystemConfig'}=getSystemConfig(\%Data);
    my $lang   = Lang->get_handle('', $Data{'SystemConfig'}) || die "Can't get a language handle!";
    $Data{'lang'}=$lang;

	my $assocID=getAssocID(\%clientValues) || '';
	my $DataAccess_ref=getDataAccess(\%Data);
	$Data{'Permissions'}=GetPermissions(
		\%Data,
		$Data{'clientValues'}{'currentLevel'},
		getID($Data{'clientValues'}, $Data{'clientValues'}{'currentLevel'}),
		$Data{'Realm'},
		$Data{'RealmSubType'},
		$Data{'clientValues'}{'authLevel'},
		0,
	);

	my $pageHeading= '';
	my $resultHTML = '';
	my $ID=getID(\%clientValues);
	$Data{'client'}=$client;
	my $preview = $action eq 'MEMCARD_print' ? 0 : 1;

  my $realmID = $Data{'Realm'} || 0;

	my $cardConfigData = ();
	{
		my $st = qq[ 
      SELECT 
        tblMemberCardConfig.*,
        tblMemberCardTemplates.strMemberCardTemplate AS strMemberCardTemplate 
      FROM 
        tblMemberCardConfig 
        LEFT JOIN tblMemberCardTemplates USING (intMemberCardTemplateID)
      WHERE 
        tblMemberCardConfig.intMemberCardConfigID = ? 
    ];
		my $q = $db->prepare($st);
		$q->execute($cardtype);
		$cardConfigData=$q->fetchrow_hashref();
		$q->finish();
    $cardConfigData->{'strMemberCard'} = $cardConfigData->{'strMemberCardTemplate'} if $cardConfigData->{'strMemberCardTemplate'};
	}
  my $currentLevel = $Data{'clientValues'}{'currentLevel'} || 0;

  my ($from_levels, $where_levels, $select_levels, $current_from, $current_where)=getLevelQueryStuff($currentLevel,  $Defs::LEVEL_MEMBER, \%Data,0,1);

	if($memberIDs)	{
	
		if($currentLevel == $Defs::LEVEL_MEMBER)	{
			$current_from .= qq[ 
				INNER JOIN tblMember_Associations ON (
					tblMember_Associations.intMemberID = tblMember.intMemberID
					AND tblMember_Associations.intAssocID = $assocID
				)
				INNER JOIN tblAssoc ON (
					tblMember_Associations.intAssocID = tblAssoc.intAssocID
				)
			];
		}
		$where_levels = "AND $where_levels" if $where_levels;
		my $st =qq[
		SELECT DISTINCT
			tblMember.*,
      (YEAR(CURDATE())-YEAR(tblMember.dtDOB))-(RIGHT(CURDATE(),5)<RIGHT(tblMember.dtDOB,5)) AS intAge,
      (YEAR(NOW()) - YEAR(tblMember.dtDOB)) AS intAgeInYear,
      DATE_FORMAT(tblMember.dtDOB, '%y') AS intYearOfBirth,
      YEAR(tblMember.dtDOB) AS intYearOfBirth_Full,
			tblMember_Associations.intRecStatus,
			DATE_FORMAT(dtPassportExpiry,'%d/%m/%Y') AS dtPassportExpiry,
			DATE_FORMAT(dtNatCustomDt1,'%d/%m/%Y') AS dtNatCustomDt1,
			DATE_FORMAT(dtNatCustomDt2,'%d/%m/%Y') AS dtNatCustomDt2,
			DATE_FORMAT(dtCustomDt1,'%d/%m/%Y') AS dtCustomDt1,
			DATE_FORMAT(dtCustomDt2,'%d/%m/%Y') AS dtCustomDt2,
			DATE_FORMAT(dtDOB,'%d/%m/%Y') AS dtDOB,
			DATE_FORMAT(dtLastRegistered,'%d/%m/%Y') AS dtLastRegistered,
			DATE_FORMAT(dtRegisteredUntil,'%d/%m/%Y') AS dtRegisteredUntil,
			DATE_FORMAT(dtFirstRegistered,'%d/%m/%Y') AS dtFirstRegistered,
			DATE_FORMAT(dtPoliceCheck,'%d/%m/%Y') AS dtPoliceCheck,
			DATE_FORMAT(dtPoliceCheckExp,'%d/%m/%Y') AS dtPoliceCheckExp,
			DATE_FORMAT(dtCreatedOnline,'%d/%m/%Y') AS dtCreatedOnline,
			DATE_FORMAT(tblMember.tTimeStamp,'%d/%m/%Y') AS tTimeStamp,
			tblMember_Associations.strCustomStr1,
			tblMember_Associations.strCustomStr2,
			tblMember_Associations.strCustomStr3,
			tblMember_Associations.strCustomStr4,
			tblMember_Associations.strCustomStr5,
			tblMember_Associations.strCustomStr6,
			tblMember_Associations.dblCustomDbl1,
			tblMember_Associations.dblCustomDbl2,
			tblMember_Associations.dblCustomDbl3,
			tblMember_Associations.dblCustomDbl4,
			tblMember_Associations.dblCustomDbl5,
			tblMember_Associations.dblCustomDbl6,
			tblMember_Associations.dblCustomDbl7,
			tblMember_Associations.dblCustomDbl8,
			tblMember_Associations.dblCustomDbl9,
			tblMember_Associations.dblCustomDbl10,
			tblMember_Associations.intCustomLU1,
			tblMember_Associations.intCustomLU2,
			tblMember_Associations.intCustomLU3,
			tblMember_Associations.intCustomLU4,
			tblMember_Associations.intCustomLU5,
			tblMember_Associations.intCustomLU6,
			tblMember_Associations.intCustomLU7,
			tblMember_Associations.intCustomLU8,
			tblMember_Associations.intCustomLU9,
			tblMember_Associations.intCustomLU10,
			tblMember_Associations.strCustomStr7,
			tblMember_Associations.strCustomStr8,
			tblMember_Associations.strCustomStr9,
			tblMember_Associations.strCustomStr10,
			tblMember_Associations.strCustomStr11,
			tblMember_Associations.strCustomStr12,
			tblMember_Associations.strCustomStr13,
			tblMember_Associations.strCustomStr14,
			tblMember_Associations.strCustomStr15,
			tblMember_Associations.intCustomBool1,
			tblMember_Associations.intCustomBool2,
			tblMember_Associations.intCustomBool3,
			tblMember_Associations.intCustomBool4,
			tblMember_Associations.intCustomBool5,
			DATE_FORMAT(tblMember_Associations.dtCustomDt1,'%d/%m/%Y') AS dtCustomDt1,
			DATE_FORMAT(tblMember_Associations.dtCustomDt2,'%d/%m/%Y') AS dtCustomDt2,
			DATE_FORMAT(tblMember_Associations.dtCustomDt3,'%d/%m/%Y') AS dtCustomDt3,
			DATE_FORMAT(tblMember_Associations.dtCustomDt4,'%d/%m/%Y') AS dtCustomDt4,
			DATE_FORMAT(tblMember_Associations.dtCustomDt5,'%d/%m/%Y') AS dtCustomDt5,
			DATE_FORMAT(dtNatCustomDt3,'%d/%m/%Y') AS dtNatCustomDt3,
			DATE_FORMAT(dtNatCustomDt4,'%d/%m/%Y') AS dtNatCustomDt4,
			DATE_FORMAT(dtNatCustomDt5,'%d/%m/%Y') AS dtNatCustomDt5,
			tblMember_Associations.intLifeMember,
			tblMember_Associations.curMemberFinBal,
			tblMember_Associations.intFinancialActive,
			tblMember_Associations.intMemberPackageID,
			tblMember_Associations.strLoyaltyNumber,
			tblMember_Associations.intMailingList,

			tblSchool.strName AS strSchoolName,
			tblSchool.strSuburb AS strSchoolSuburb,

			tblAssoc.intAssocID,
			tblAssoc.intAssocTypeID,
			tblAssoc.strName AS strAssocName,

      S.strSeasonName,

			T.intTransactionID AS PROD_intTransactionID,
			T.intStatus AS PROD_intStatus,
			T.curAmount AS PROD_curAmount,
			T.intQty AS PROD_intQty,
			DATE_FORMAT(T.dtTransaction,'%d/%m/%Y') AS PROD_dtTransaction,
			DATE_FORMAT(T.dtPaid,'%d/%m/%Y') AS PROD_dtPaid,
			DATE_FORMAT(T.dtStart,'%d/%m/%Y') AS PROD_dtStart,
			DATE_FORMAT(T.dtEnd,'%d/%m/%Y') AS PROD_dtEnd,
			DATE_FORMAT(T.dtEnd,'%Y%m%d') AS PROD_dtEndRaw,
			T.intDelivered AS PROD_intDelivered,
			P.strName AS PROD_strName,
			P.strProductNotes AS PROD_strProductNotes,
			P.strGroup AS PROD_strGroup,

			C.intClubID AS CLUB_intClubID,
			C.strName AS CLUB_strName,
 			MC.intPrimaryClub AS CLUB_intPrimaryClub,
			MC.intStatus AS CLUB_intStatus,
			AC.intAssocID AS CLUB_intAssocID,

      MN.strMemberMedicalNotes,

			MT.intMemberTypeID AS TYPE_intMemberTypeID,
      MT.intTypeID AS TYPE_intTypeID,
      MT.intSubTypeID AS TYPE_intSubTypeID,
      MT.intActive AS TYPE_intActive,
      MT.strString1 AS TYPE_strString1,
      MT.strString2 AS TYPE_strString2,
      MT.strString3 AS TYPE_strString3,
      MT.strString4 AS TYPE_strString4,
      MT.strString5 AS TYPE_strString5,
      MT.strString6 AS TYPE_strString6,
      MT.intInt1 AS TYPE_intInt1,
			DC1.strName AS TYPE_intInt1Name,
      MT.intInt2 AS TYPE_intInt2,
			DC2.strName AS TYPE_intInt2Name,
      MT.intInt3 AS TYPE_intInt3,
      MT.intInt4 AS TYPE_intInt4,
      MT.intInt5 AS TYPE_intInt5,
      MT.intInt6 AS TYPE_intInt6,
      MT.intInt7 AS TYPE_intInt7,
      MT.intInt8 AS TYPE_intInt8,
      MT.intInt9 AS TYPE_intInt9,
      MT.intInt10 AS TYPE_intInt10,
			DATE_FORMAT(MT.dtDate1,'%d/%m/%Y') AS TYPE_dtDate1,
			DATE_FORMAT(MT.dtDate2,'%d/%m/%Y') AS TYPE_dtDate2,
			DATE_FORMAT(MT.dtDate2,'%Y%m%d') AS TYPE_dtDate2_RAW,
			DATE_FORMAT(MT.dtDate3,'%d/%m/%Y') AS TYPE_dtDate3,
			MT.intAssocID AS TYPE_intAssocID,
      MT.intRecStatus AS TYPE_intRecStatus,

      MS.intMemberSeasonID AS SEASON_intMemberSeasonID,
      MS.intMSRecStatus AS SEASON_intMSRecStatus,
      MS.intPlayerAgeGroupID AS SEASON_intPlayerAgeGroupID,
      MS.intPlayerStatus AS SEASON_intPlayerStatus,
      MS.intPlayerFinancialStatus AS SEASON_intPlayerFinancialStatus,
      MS.intCoachStatus AS SEASON_intCoachStatus,
      MS.intCoachFinancialStatus AS SEASON_intCoachFinancialStatus,
      MS.intUmpireStatus AS SEASON_intUmpireStatus,
      MS.intUmpireFinancialStatus AS SEASON_intUmpireFinancialStatus,
      MS.intMiscStatus AS SEASON_intMiscStatus,
      MS.intMiscFinancialStatus AS SEASON_intMiscFinancialStatus,
      MS.intVolunteerStatus AS SEASON_intVolunteerStatus,
      MS.intVolunteerFinancialStatus AS SEASON_intVolunteerFinancialStatus,
      MS.intOther1Status AS SEASON_intOther1Status,
      MS.intOther1FinancialStatus AS SEASON_intOther1FinancialStatus,
      MS.intOther2Status AS SEASON_intOther2Status,
      MS.intOther2FinancialStatus AS SEASON_intOther2FinancialStatus,
      MS.intAssocID AS SEASON_intAssocID,
      MS.intClubID AS SEASON_intClubID,

			MemT.intTeamID AS TEAM_intTeamID,
			MemT.intMTFinancial AS TEAM_intMTFinancial,
			MemT.intStatus AS TEAM_intMTStatus,
			AssC.strTitle AS TEAM_strCompName,
			tblTeam.strName AS TEAM_strTeamName,

      Accred.intAccreditationID AS ACCRED_intAccreditationID,
      DC3.strName AS ACCRED_intSport,
      DC5.strName AS ACCRED_intLevel,
      DC4.strName AS ACCRED_intProvider,
      DATE_FORMAT(Accred.dtApplication, '%d/%m/%Y') AS ACCRED_dtApplication,
      DATE_FORMAT(Accred.dtStart, '%d/%m/%Y')  AS ACCRED_dtStart,
      DATE_FORMAT(Accred.dtExpiry, '%d/%m/%Y') AS ACCRED_dtExpiry,
      DATE_FORMAT(Accred.dtExpiry, '%Y%m%d') AS ACCRED_dtExpiryRaw,
      Accred.intReaccreditation AS ACCRED_intReaccreditation,
      Accred.intStatus AS ACCRED_intStatus,
      Accred.intRecStatus AS ACCRED_intRecStatus,
      Accred.strCourseNumber AS ACCRED_strCourseNumber,
      Accred.strParticipantNumber AS ACCRED_strParticipantNumber,
      Qual.strName AS ACCRED_strQualName,
      Qual.intType AS ACCRED_intType

		FROM 
      $from_levels 
      $current_from
			LEFT JOIN tblSchool ON (tblMember.intSchoolID=tblSchool.intSchoolID)
			LEFT JOIN tblTransactions AS T
				ON (
					tblMember.intMemberID  = T.intID
					AND T.intTableType = $Defs::LEVEL_MEMBER
				)
			LEFT JOIN tblProducts AS P ON T.intProductID = P.intProductID
			LEFT JOIN tblMember_Clubs AS MC ON tblMember.intMemberID = MC.intMemberID
			LEFT JOIN tblClub AS C ON MC.intClubID = C.intClubID
			LEFT JOIN tblAssoc_Clubs AS AC ON C.intClubID = AC.intClubID AND AC.intAssocID= tblAssoc.intAssocID
      LEFT JOIN tblMember_Types AS MT ON MT.intMemberID = tblMember.intMemberID
			LEFT JOIN tblDefCodes AS DC1 ON DC1.intCodeID = MT.intInt1 AND DC1.intRecStatus <> -1
			LEFT JOIN tblDefCodes AS DC2 ON DC2.intCodeID = MT.intInt2 AND DC2.intRecStatus <> -1
      LEFT JOIN tblSeasons AS S ON S.intSeasonID = tblAssoc.intCurrentSeasonID
      LEFT JOIN tblMemberNotes AS MN ON MN.intNotesMemberID = tblMember.intMemberID
      LEFT JOIN tblMember_Seasons_$realmID AS MS ON MS.intMemberID = tblMember.intMemberID AND MS.intMSRecStatus <> -1 AND MS.intSeasonID = tblAssoc.intCurrentSeasonID
			LEFT JOIN tblMember_Teams AS MemT ON (MemT.intMemberID = tblMember.intMemberID)
			LEFT JOIN tblAssoc_Comp AS AssC ON (AssC.intCompID = MemT.intCompID AND AssC.intNewSeasonID = tblAssoc.intCurrentSeasonID AND MemT.intStatus <> -1)
			LEFT JOIN tblTeam ON (tblTeam.intTeamID = MemT.intTeamID)
      LEFT JOIN tblAccreditation AS Accred ON (Accred.intMemberID = tblMember.intMemberID)
			LEFT JOIN tblDefCodes AS DC3 ON DC3.intCodeID = Accred.intSport AND DC3.intRecStatus <> -1
			LEFT JOIN tblDefCodes AS DC4 ON DC4.intCodeID = Accred.intProvider AND DC4.intRecStatus <> -1
			LEFT JOIN tblDefCodes AS DC5 ON DC5.intCodeID = Accred.intLevel AND DC5.intRecStatus <> -1
      LEFT JOIN tblQualification AS Qual ON (Accred.intQualificationID = Qual.intQualificationID) 
		WHERE 1=1  
      $where_levels 
      $current_where 
			AND tblMember.intMemberID IN ($memberIDs)
    ORDER BY
      tblMember.strSurname, tblMember.strFirstname
		];

		my $q= $db->prepare($st);
		$q->execute();#$memberIDs);
		my %ContentData = ();
		my $lastMemberID = 0;
		my %assocs = ();
		my %exists = ();
		my %teamexists = ();
		while (my $field=$q->fetchrow_hashref())	{
			foreach my $key (keys %{$field})  { if(!defined $field->{$key}) {$field->{$key}='';} }
			my %proddata = ();
			my %clubdata = ();
			my %typedata = ();
			my %seasondata = ();
			my %teamdata = ();
			my %accreddata = ();
			#$assocs{$field->{'intAssocID'}} = 1;
			foreach my $key (keys %{$field})  { 
				if($key =~ /^PROD_/)	{
					my $newkey = $key;
					$exists{$field->{'PROD_intTransactionID'}} ||= 0;	
					next if $exists{$field->{'PROD_intTransactionID'}} == 13;
					$newkey =~ s/^PROD_//g;
					$proddata{$newkey} = $field->{$key};
					$exists{$field->{'PROD_intTransactionID'}} = $exists{$field->{'PROD_intTransactionID'}} + 1;
				}
				if($key =~ /^CLUB_/)	{
					my $newkey = $key;
          my $exist_key = $field->{'CLUB_intClubID'} . "_" . $field->{'intMemberID'} . "_" . $field->{'CLUB_intStatus'};
          $exists{$exist_key} ||= 0;
					next if $exists{$exist_key} == 5;
					$newkey =~ s/^CLUB_//g;
					$clubdata{$newkey} = $field->{$key};
					$exists{$exist_key} = $exists{$exist_key} + 1;
				}
        if($key =~ /^TYPE_/)  {
					$exists{$field->{'TYPE_intMemberTypeID'}} ||= 0;
					next if $exists{$field->{'TYPE_intMemberTypeID'}} == 28;
          my $newkey = $key;
          $newkey =~ s/^TYPE_//g;
          $typedata{$newkey} = $field->{$key};
					$exists{$field->{'TYPE_intMemberTypeID'}} = $exists{$field->{'TYPE_intMemberTypeID'}} + 1;
		    }
        if($key =~ /^SEASON_/)  {
          next if $exists{'S_'.$field->{'SEASON_intMemberSeasonID'}} == 15;
          my $newkey = $key;
          $newkey =~ s/^SEASON_//g;
          $seasondata{$newkey} = $field->{$key};
          $exists{'S_'.$field->{'SEASON_intMemberSeasonID'}} = $exists{'S_'.$field->{'SEASON_intMemberSeasonID'}} + 1;
        }
        if($key =~ /^TEAM_/)  {
          my $newkey = $key;
					my $exist_key = $field->{'TEAM_intTeamID'} . '_' . $field->{'TEAM_intMTStatus'};	
          next if $exists{$exist_key} == 5;
          $newkey =~ s/^TEAM_//g;
          $teamdata{$newkey} = $field->{$key};
          $exists{$exist_key} = $exists{$exist_key} + 1;
        }
        if ($key =~ /^ACCRED_/) {
          my $newkey = $key;
          my $exist_key = $field->{'ACCRED_intAccreditationID'};
          next if $exists{$exist_key} == 15;
          $newkey =~ s/^ACCRED_//g;
          $accreddata{$newkey} = $field->{$key};
          $exists{$exist_key} = $exists{$exist_key} + 1;
        }
			}
			unless ($field->{'intMemberID'} == $lastMemberID)	{
        $temp_clientValues{'memberID'} = $field->{'intMemberID'};
        $temp_clientValues{'currentLevel'} = $Defs::LEVEL_MEMBER;
        my $newcl = setClient(\%temp_clientValues);
        $field->{'client'} = $newcl;
			  push @{$ContentData{'Members'}}, $field;
			}
			$lastMemberID = $field->{'intMemberID'};
			push @{$ContentData{'Members'}[$#{$ContentData{'Members'}}]{'Transactions'}}, \%proddata if $proddata{'intTransactionID'};
			push @{$ContentData{'Members'}[$#{$ContentData{'Members'}}]{'Clubs'}}, \%clubdata if $clubdata{'intClubID'};
			push @{$ContentData{'Members'}[$#{$ContentData{'Members'}}]{'Types'}}, \%typedata if $typedata{'intMemberTypeID'};
			push @{$ContentData{'Members'}[$#{$ContentData{'Members'}}]{'Seasons'}}, \%seasondata if $seasondata{'intMemberSeasonID'};
			push @{$ContentData{'Members'}[$#{$ContentData{'Members'}}]{'Accred'}}, \%accreddata if $accreddata{'intAccreditationID'};
  
      if ($teamdata{'intTeamID'} and $teamdata{'strCompName'} and $teamexists{$field->{'intMemberID'}}{$teamdata{'intTeamID'}}{$teamdata{'intMTStatus'}} != 1) {
        push @{$ContentData{'Members'}[$#{$ContentData{'Members'}}]{'Teams'}}, \%teamdata;
        $teamexists{$field->{'intMemberID'}}{$teamdata{'intTeamID'}}{$teamdata{'intMTStatus'}} = 1;
      }
		}
		$q->finish();

		$ContentData{'client'} = $client;
		$ContentData{'e_client'} = escape($client);
		$ContentData{'assocID'} = $assocID;

    $ContentData{'assoc_logo'} = showLogo(\%Data, $Defs::LEVEL_ASSOC, $assocID, '', '', '');


		# Get DefCodes Data
		{
			#my $assoclist = join(',', keys %assocs);
			#$assoclist = $assoclist ? $assoclist.',0'	: '0';
			my $assoclist = $assocID ? $assocID . ',0'      : '0';
			my $st = qq[
				SELECT intCodeID, strName
				FROM tblDefCodes
				WHERE intRealmID = ?
				AND intAssocID IN ($assoclist)
			];
			my $q= $db->prepare($st);
			$q->execute($Data{'Realm'});
			while(my($id, $name) = $q->fetchrow_array())	{
				next if !$id;
				next if !$name;
				$ContentData{'DefCodes'}{$id} = $name || '';
			}
			$q->finish();

      $st = qq[
        SELECT intAgeGroupID, strAgeGroupDesc
        FROM tblAgeGroups
        WHERE intRealmID = ?
        AND intAssocID IN ($assoclist)
      ];
      $q = $db->prepare($st);
      $q->execute($Data{'Realm'});
      while(my($id, $name) = $q->fetchrow_array())  {
        next if !$id;
        next if !$name;
        $ContentData{'AgeGroups'}{$id} = $name || '';
      }
      $q->finish();
		}

		my $filename = $cardConfigData->{'strFilename'} || '';
		my $e_client = escape($client);
		my $url = "$target?a=MEMCARD_print&amp;ctID=$cardtype&amp;ids=$memberIDs&amp;client=$e_client";
		if($preview)	{
			$ContentData{'PreviewText'} = qq[
			<div style="margin-left:20px;">
				<h1>Preview of Card</h1>
				<p style="border-bottom:1px solid #999999;margin-bottom:20px;padding-bottom:20px;">Press the 'Print' button to print the card. <br><br><input type="button" value=" Print " onclick='window.open("$url","accredcardprint","toolbar=no,location=no,status=no,menubar=no,scrollbars=none,titlebar=no,width=400,height=200");window.close();'> &nbsp; &nbsp; <input type="button" value=" Cancel " onclick='window.close();'></p>
			</div>
			];
			$ContentData{'BodyLoad'} = '';
		}
		else	{
			$ContentData{'BodyLoad'} = qq[ onload="window.print();close();" ];
			$ContentData{'PreviewText'} = '';
		}
    if ($cardConfigData->{'strMemberCard'}) {
      $ContentData{'content'} = runTemplate(\%Data, \%ContentData, "", $cardConfigData->{'strMemberCard'});
      $resultHTML = runTemplate(\%Data, \%ContentData, "membercard/MemberCard_Wrapper.templ");
    }
    else {
		  $resultHTML = runTemplate(\%Data, \%ContentData, "membercard/$filename.templ");
    }
		if(!$preview and $memberIDs =~/^\d+$/)	{
			#For single printing
			updateCardPrinted($db, $cardtype, $memberIDs, \%Data) 
		}
    else {
      #For bulk printing
      auditLog($cardtype, \%Data, 'Bulk Print', 'Card Printing') if ($action ne 'MEMCARD_bulk');
    }
	}
	else	{
		$resultHTML = 'Invalid Members';
	}

	my $title=$lang->txt($Defs::page_title);
	print "Content-type: text/html\n\n";
	print $resultHTML;

	disconnectDB($db);

}

sub updateCardPrinted	{
	my($db, $cardtypeID, $memberID, $Data)=@_;

	my $st_count = qq[
		SELECT MAX(intCount)
		FROM tblMemberCardPrinted
		WHERE 
			intMemberCardConfigID = ?
			AND intMemberID = ?
	];
  my $q_count= $db->prepare($st_count);
  $q_count->execute($cardtypeID, $memberID);
	my($count) = $q_count->fetchrow_array();
	$count ||= 0;
	$q_count->finish();

	my $st = qq[
		INSERT INTO tblMemberCardPrinted (
			intMemberCardConfigID, 
			intMemberID, 
			dtPrinted, 
			strUsername, 
			intQty, 
			intCount
		)
		VALUES (
			?,
			?,
			NOW(),
			?,
			1,
			?
		)
	];
  my $q= $db->prepare($st);
  $q->execute(
		$cardtypeID,
		$memberID, 
		$Data->{'UserName'},
		$count
	);
	$q->finish();
  $Data->{'NoClearActionRequired'} = 1;
	MemberCard::toggleToPrintFlag($Data, $cardtypeID, $memberID, 0);
  auditLog($cardtypeID, $Data, 'Print', 'Card Printing');
	return '';
}
