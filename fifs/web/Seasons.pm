#
# $Header: svn://svn/SWM/trunk/web/Seasons.pm 11617 2014-05-20 05:57:52Z sliu $
#

package Seasons;
require Exporter;
@ISA = qw(Exporter);
@EXPORT=qw(handleSeasons insertMemberSeasonRecord memberSeasonDuplicateResolution viewDefaultAssocSeasons getDefaultAssocSeasons syncAllowSeasons checkForMemberSeasonRecord seasonRollver isMemberInSeason);
@EXPORT_OK=qw(handleSeasons insertMemberSeasonRecord memberSeasonDuplicateResolution viewDefaultAssocSeasons getDefaultAssocSeasons syncAllowSeasons checkForMemberSeasonRecord seasonRollver isMemberInSeason);

use lib ".","..","comp";

use strict;

use Reg_common;
use Utils;
use HTMLForm;
use AuditLog;
use CGI qw(unescape param);
use FormHelpers;
use MemberPackages;
use GenAgeGroup;
use GridDisplay;
require AgeGroups;
require Transactions;


sub handleSeasons   {
    my ($action, $Data)=@_;
    my $seasonID       = param('seasonID') || 0;
    my $memberSeasonID = param('msID')     || 0;
    my $resultHTML = '';
    my $title      = '';
    if($action eq 'SN_L_U') {
        $resultHTML = setDefaultAssocSeasonConfig($Data);
    } 
    if ($action =~/^SN_DT/) {
        #Season Details
       ($resultHTML,$title)=season_details($action, $Data, $seasonID);
    }
    elsif ($action =~/^SN_L/) {
        #List Seasons
        my $tempResultHTML = '';
        ($tempResultHTML,$title)=listSeasons($Data);
        $resultHTML .= $tempResultHTML;
    }
    elsif ($action =~/^SN_MSview/) {
        #List Seasons
        ($resultHTML,$title)=memberSeason_details($Data, $memberSeasonID, $action);
    }
    return ($resultHTML,$title);
}

sub checkMSRecordExistance  {
    my ($Data, $seasonID, $memberID) = @_;
    my $MStablename = "tblMember_Seasons_$Data->{'Realm'}";
    my $st = qq[
        SELECT
            COUNT(*) as MSCount
        FROM 
            $MStablename
        WHERE
            intMSRecStatus=1
            AND intAssocID = $Data->{'clientValues'}{'assocID'}
            AND intClubID=0
            AND intSeasonID=$seasonID
            AND intMemberID = $memberID
    ];
    my $query = $Data->{'db'}->prepare($st);
    $query->execute();
    my $count = $query->fetchrow_array() || 0;
    if (! $count)   {
        insertMemberSeasonRecord($Data, $memberID, $seasonID, $Data->{'clientValues'}{'assocID'}, 0, 0, undef());
    }
}

sub checkForMemberSeasonRecord  {

    my ($Data, $compID, $teamID, $memberID) = @_;

    $compID ||= 0;
    $teamID ||= 0;
    $memberID ||= 0;

    ## In List.pm, if logged in as a TEAM, you can roll all players INTO a Comp using the green tick.
    ## When this happens, we will set the Data variable so the below works
    # ## Check List.pm line
    return '' if (! $Data->{'memberListIntoComp'});
    $Data->{'memberListIntoComp'}=0;  ## Reset it back.  USE THIS LINE AS WELL.
    
    my $st = qq[
        SELECT intNewSeasonID
        FROM tblAssoc_Comp
        WHERE intAssocID = $Data->{'clientValues'}{'assocID'} AND intCompID = $compID
    ];
    my $q=$Data->{'db'}->prepare($st);
    $q->execute();
    my($seasonID)=$q->fetchrow_array() || 0;

    $st = qq[
        SELECT T.intClubID
        FROM tblTeam as T
            INNER JOIN tblMember_Clubs as MC ON (MC.intMemberID = ? AND MC.intClubID = T.intClubID AND MC.intStatus = $Defs::RECSTATUS_ACTIVE)
        WHERE T.intTeamID = $teamID
    ];
    my $qClub=$Data->{'db'}->prepare($st);

    my $assocSeasons = getDefaultAssocSeasons($Data);
    $seasonID ||= $assocSeasons->{'currentSeasonID'};

    my %types = ();

    if (!$types{'intPlayerStatus'} and !$types{'intCoachStatus'} and !$types{'intUmpireStatus'} and !$types{'intOfficialStatus'} 
    and !$types{'intMiscStatus'} and !$types{'intVolunteerStatus'} and !$types{'intOther1Status'} and !$types{'intOther2Status'}) {
        $types{'intPlayerStatus'}    = 1 if ($assocSeasons->{'defaultMemberType'} == $Defs::MEMBER_TYPE_PLAYER);
        $types{'intCoachStatus'}     = 1 if ($assocSeasons->{'defaultMemberType'} == $Defs::MEMBER_TYPE_COACH);
        $types{'intUmpireStatus'}    = 1 if ($assocSeasons->{'defaultMemberType'} == $Defs::MEMBER_TYPE_UMPIRE);
        $types{'intOfficialStatus'}  = 1 if ($assocSeasons->{'defaultMemberType'} == $Defs::MEMBER_TYPE_OFFICIAL);
        $types{'intMiscStatus'}      = 1 if ($assocSeasons->{'defaultMemberType'} == $Defs::MEMBER_TYPE_MISC);
        $types{'intVolunteerStatus'} = 1 if ($assocSeasons->{'defaultMemberType'} == $Defs::MEMBER_TYPE_VOLUNTEER);
    }

    $types{'intMSRecStatus'} = 1;

    my $genAgeGroup ||=new GenAgeGroup ($Data->{'db'},$Data->{'Realm'}, $Data->{'RealmSubType'}, $Data->{'clientValues'}{'assocID'});
    if ($memberID)  {
        my $st_member = qq[
            SELECT DATE_FORMAT(dtDOB, "%Y%m%d") as DOBAgeGroup, intGender
            FROM tblMember
            WHERE intMemberID = $memberID
        ];
        my $qry_member=$Data->{'db'}->prepare($st_member);
            $qry_member->execute();
            my ($DOBAgeGroup, $Gender)=$qry_member->fetchrow_array();
        my $ageGroupID=$genAgeGroup->getAgeGroup($Gender, $DOBAgeGroup) || 0;
        ## FOR A SINGLE MEMBER IN TEAM
        insertMemberSeasonRecord($Data, $memberID, $seasonID, $Data->{'clientValues'}{'assocID'}, 0, $ageGroupID, \%types);
        insertMemberSeasonRecord($Data, $memberID, $assocSeasons->{'newRegoSeasonID'}, $Data->{'clientValues'}{'assocID'}, 0, $ageGroupID, \%types) if (! $assocSeasons->{'allowSeasons'});
            $qClub->execute($memberID);
            my($clubID)=$qClub->fetchrow_array() || 0;
        $clubID = 0 if ($clubID == $Defs::INVALID_ID);
        ### INSERT SEASON CLUB RECORD IF MEMBER_CLUB RECORD EXISTS
        insertMemberSeasonRecord($Data, $memberID, $seasonID, $Data->{'clientValues'}{'assocID'}, $clubID, $ageGroupID, \%types) if $clubID;
        insertMemberSeasonRecord($Data, $memberID, $assocSeasons->{'newRegoSeasonID'}, $Data->{'clientValues'}{'assocID'}, $clubID, $ageGroupID, \%types) if ($clubID and ! $assocSeasons->{'allowSeasons'});
    }
    else    {
        ## FOR A ENTIRE TEAM
        $st = qq[
            SELECT MT.intMemberID, DATE_FORMAT(M.dtDOB, "%Y%m%d") as DOBAgeGroup, intGender
            FROM tblMember_Teams as MT
                INNER JOIN tblMember as M ON (M.intMemberID = MT.intMemberID AND M.intStatus <> $Defs::RECSTATUS_DELETED)
            WHERE MT.intTeamID = $teamID AND MT.intCompID = $compID AND MT.intStatus = $Defs::RECSTATUS_ACTIVE
        ];
        my $q=$Data->{'db'}->prepare($st);
            $q->execute();
            while (my ($memberID, $DOBAgeGroup, $Gender)=$q->fetchrow_array())  {
            my $ageGroupID=$genAgeGroup->getAgeGroup($Gender, $DOBAgeGroup) || 0;
            insertMemberSeasonRecord($Data, $memberID, $seasonID, $Data->{'clientValues'}{'assocID'}, 0, $ageGroupID, \%types);
            insertMemberSeasonRecord($Data, $memberID, $assocSeasons->{'newRegoSeasonID'}, $Data->{'clientValues'}{'assocID'}, 0, $ageGroupID, \%types) if ! $assocSeasons->{'allowSeasons'};
                $qClub->execute($memberID);
                my($clubID)=$qClub->fetchrow_array() || 0;
            $clubID = 0 if ($clubID == $Defs::INVALID_ID);
            ### INSERT SEASON CLUB RECORD IF MEMBER_CLUB RECORD EXISTS
            insertMemberSeasonRecord($Data, $memberID, $seasonID, $Data->{'clientValues'}{'assocID'}, $clubID, $ageGroupID, \%types) if $clubID;
            insertMemberSeasonRecord($Data, $memberID, $assocSeasons->{'newRegoSeasonID'}, $Data->{'clientValues'}{'assocID'}, $clubID, $ageGroupID, \%types) if ($clubID and ! $assocSeasons->{'allowSeasons'});
        }
    }
}

sub syncAllowSeasons    {
    my ($db, $intAssocID, $SWC_AppVer) = @_;

    $intAssocID || return;
    $SWC_AppVer || return;
    
    if ($SWC_AppVer =~ /^7/)    {
        $db->do(qq[UPDATE tblAssoc SET intAllowSeasons=1 WHERE intAssocID=$intAssocID]);
    }
}
        
sub memberSeason_details    {
    my($Data, $memberSeasonID, $action) = @_;

    my $txt_Name           = $Data->{'SystemConfig'}{'txtSeason'}    || 'Season';
    my $txt_Names          = $Data->{'SystemConfig'}{'txtSeasons'}   || 'Seasons';
    my $txt_AgeGroupName   = $Data->{'SystemConfig'}{'txtAgeGroup'}  || 'Age Group';
    my $txt_AgeGroupsNames = $Data->{'SystemConfig'}{'txtAgeGroups'} || 'Age Groups';

    my $tablename = "tblMember_Seasons_$Data->{'Realm'}";

    my $db=$Data->{'db'} || undef;
    my $client = setClient($Data->{'clientValues'}) || '';
    my $target = $Data->{'target'} || '';
    my $option = ($action =~ /EDIT$/) ? 'edit' : 'display';

    $option = 'add' if $action =~ /ADD$/;# and allowedAction($Data, 'sn_a');

    my $subType = $Data->{'RealmSubType'} || 0;
    my $resultHTML = '';
    my %DataVals=();

    my $strWhere = '';
    $strWhere .= qq[ AND MS.intSeasonID = ] . param("d_intSeasonID") if param("d_intSeasonID");
    $strWhere .= param("d_intClubID") ?  qq[ AND MS.intClubID = ] . param("d_intClubID") : qq[ AND MS.intClubID=0];

    $strWhere = qq[ AND MS.intMemberSeasonID = $memberSeasonID] if ($memberSeasonID); 
    if (! param("d_intSeasonID") and ! $memberSeasonID) {
        $strWhere = qq[ AND MS.intMemberSeasonID = 0];
    }

    my $statement=qq[
        SELECT 
            MS.*, 
            S.strSeasonName, 
            C.strName as ClubName, 
            DATE_FORMAT(MS.dtInPlayer,    "%d-%M-%Y") as DateInPlayer, 
            DATE_FORMAT(MS.dtInCoach,     "%d-%M-%Y") as DateInCoach, 
            DATE_FORMAT(MS.dtInUmpire,    "%d-%M-%Y") as DateInUmpire, 
            DATE_FORMAT(MS.dtInOfficial,  "%d-%M-%Y") as DateInOfficial, 
            DATE_FORMAT(MS.dtInMisc,      "%d-%M-%Y") as DateInMisc, 
            DATE_FORMAT(MS.dtInVolunteer, "%d-%M-%Y") as DateInVolunteer, 
            DATE_FORMAT(MS.dtInOther1,    "%d-%M-%Y") as DateInOther1, 
            DATE_FORMAT(MS.dtInOther2,    "%d-%M-%Y") as DateInOther2
        FROM 
            $tablename as MS
            INNER JOIN tblSeasons as S ON (S.intSeasonID = MS.intSeasonID)
            LEFT JOIN tblClub as C ON (C.intClubID = MS.intClubID)
        WHERE
            MS.intAssocID = $Data->{'clientValues'}{'assocID'}
            AND MS.intMemberID = $Data->{'clientValues'}{'memberID'}
            $strWhere
    ];

    my $query = $db->prepare($statement);
    my $RecordData={};
    $query->execute();
    my $dref=$query->fetchrow_hashref();
    $memberSeasonID = $dref->{intMemberSeasonID} if ! $memberSeasonID and $dref->{intMemberSeasonID};

    if ($memberSeasonID and $action =~ /ADD/)   {
        $option = 'edit';
        $action =~ s/ADD/EDIT/;
    }
    if (param('d_intSeasonID') and $action =~ /ADD/)    {
        $dref->{intSeasonID} = param('d_intSeasonID') || 0;
        my $genAgeGroup ||=new GenAgeGroup ($Data->{'db'},$Data->{'Realm'}, $Data->{'RealmSubType'}, $Data->{'clientValues'}{'assocID'});
        my $st = qq[
            SELECT intGender, DATE_FORMAT(dtDOB, "%Y%m%d") as DOBAgeGroup
            FROM tblMember 
            WHERE intMemberID = $Data->{'clientValues'}{'memberID'}
        ];
    my $query = $db->prepare($st);
    $query->execute();
        my ($Gender, $DOBAgeGroup) = $query->fetchrow_array();
    my $ageGroupID=$genAgeGroup->getAgeGroup ($Gender, $DOBAgeGroup) || 0;
        $dref->{intPlayerAgeGroupID} = $ageGroupID || 0;
    }
    my $msupdate = qq[
        UPDATE $tablename
        SET 
            --VAL--, 
            dtInPlayer    = IF(intPlayerStatus    = 1 and (dtInPlayer    IS NULL or dtInPlayer    = '0000-00-00'), CURDATE(), dtInPlayer), 
            dtInCoach     = IF(intCoachStatus     = 1 and (dtInCoach     IS NULL or dtInCoach     = '0000-00-00'), CURDATE(), dtInCoach), 
            dtInUmpire    = IF(intUmpireStatus    = 1 and (dtInUmpire    IS NULL or dtInUmpire    = '0000-00-00'), CURDATE(), dtInUmpire), 
            dtInOfficial  = IF(intOfficialStatus  = 1 and (dtInOfficial  IS NULL or dtInOfficial  = '0000-00-00'), CURDATE(), dtInOfficial), 
            dtInMisc      = IF(intMiscStatus      = 1 and (dtInMisc      IS NULL or dtInMisc      = '0000-00-00'), CURDATE(), dtInMisc), 
            dtInVolunteer = IF(intVolunteerStatus = 1 and (dtInVolunteer IS NULL or dtInVolunteer = '0000-00-00'), CURDATE(), dtInVolunteer), 
            dtInOther1    = IF(intOther1Status    = 1 and (dtInOther1    IS NULL or dtInOther1    = '0000-00-00'), CURDATE(), dtInOther1), 
            dtInOther2    = IF(intOther2Status    = 1 and (dtInOther2    IS NULL or dtInOther2    = '0000-00-00'), CURDATE(), dtInOther2) 
        WHERE 
            intMemberSeasonID = $memberSeasonID
            AND intAssocID    = $Data->{'clientValues'}{'assocID'}
            AND intMemberID   = $Data->{'clientValues'}{'memberID'}
    ];
    my $msadd = qq[
        INSERT IGNORE INTO $tablename (
            intAssocID, 
            intMemberID, 
            dtInPlayer, 
            dtInCoach, 
            dtInUmpire, 
            dtInOfficial, 
            dtInMisc, 
            dtInVolunteer, 
            dtInOther1, 
            dtInOther2, 
            --FIELDS--
        )
        VALUES (
            $Data->{'clientValues'}{'assocID'}, 
            $Data->{'clientValues'}{'memberID'}, 
            IF(intPlayerStatus    = 1, CURDATE(), NULL), 
            IF(intCoachStatus     = 1, CURDATE(), NULL), 
            IF(intUmpireStatus    = 1, CURDATE(), NULL), 
            IF(intOfficialStatus  = 1, CURDATE(), NULL), 
            IF(intMiscStatus      = 1, CURDATE(), NULL), 
            IF(intVolunteerStatus = 1, CURDATE(), NULL), 
            IF(intOther1Status    = 1, CURDATE(), NULL), 
            IF(intOther2Status    = 1, CURDATE(), NULL), 
            --VAL--
        )
    ];
      my $st_seasons=qq[ 
          SELECT intSeasonID, strSeasonName 
          FROM tblSeasons 
          WHERE intRealmID = $Data->{'Realm'} 
              AND (intAssocID=$Data->{'clientValues'}{'assocID'} OR intAssocID =0) 
              AND (intRealmSubTypeID = $subType OR intRealmSubTypeID= 0)
              AND intArchiveSeason <> 1
              AND intLocked <> 1
          ORDER BY intSeasonOrder, strSeasonName
      ];
      #AND (intRealmSubTypeID = $Data->{'RealmSubType'} OR intRealmSubTypeID= 0)
    my ($seasons_vals,$seasons_order)=getDBdrop_down_Ref($Data->{'db'},$st_seasons,'');
      
      my $defaultClubID = $Data->{'clientValues'}{'clubID'} || 0;
      $defaultClubID= 0 if ($defaultClubID == $Defs::INVALID_ID);
      my $clubWHERE = ($Data->{'clientValues'}{'authLevel'} == $Defs::LEVEL_CLUB and $defaultClubID) ? qq[ WHERE C.intClubID = $defaultClubID] : '';
      my $st_clubs=qq[ 
          SELECT C.intClubID, strName
          FROM tblClub as C 
              INNER JOIN tblAssoc_Clubs as AC ON (AC.intClubID = C.intClubID
                  AND AC.intAssocID = $Data->{'clientValues'}{'assocID'})
              INNER JOIN tblMember_Clubs as MC ON (MC.intClubID = C.intClubID
                  AND MC.intMemberID = $Data->{'clientValues'}{'memberID'}
                  AND MC.intStatus <> $Defs::RECSTATUS_DELETED)
              $clubWHERE
          ORDER BY C.strName
      ];
    my ($clubs_vals,$clubs_order)=getDBdrop_down_Ref($Data->{'db'},$st_clubs,'');

      my $AgeGroups=AgeGroups::getAgeGroups($Data);
      my $st_ageGroups=qq[ 
          SELECT intAgeGroupID, IF(intRecStatus<1, CONCAT(strAgeGroupDesc, ' (Inactive)'),  strAgeGroupDesc) as strAgeGroupDesc
          FROM tblAgeGroups
          WHERE intRealmID = $Data->{'Realm'} 
              AND (intAssocID=$Data->{'clientValues'}{'assocID'} OR intAssocID =0) 
              AND (intRealmSubTypeID = $subType OR intRealmSubTypeID = 0)
              AND intRecStatus<>-1
          ORDER BY strAgeGroupDesc
      ];
    my ($ageGroups_vals,$ageGroups_order) = getDBdrop_down_Ref($Data->{'db'},$st_ageGroups,'');

    my $levelName = ($action =~ /CADD$/ or $dref->{intClubID}) 
        ? $Data->{'LevelNames'}{$Defs::LEVEL_CLUB} 
        : $Data->{'LevelNames'}{$Defs::LEVEL_ASSOC};

    my $MemberPackages=getMemberPackages($Data) || '';

    
    if (! $memberSeasonID and $action =~ /ADD/ and $Data->{'SystemConfig'}{'checkLastSeasonTypesFilter'})   {
        my $clubWHERE = ($Data->{'clientValues'}{'clubID'} and $Data->{'clientValues'}{'clubID'} != $Defs::INVALID_ID) 
            ? qq[ AND intClubID = $Data->{'clientValues'}{'clubID'}] 
            : qq[ AND intClubID=0];

        my $st = qq[
            SELECT
                intPlayerStatus,
                intCoachStatus,
                intUmpireStatus,
                intOfficialStatus,
                intMiscStatus,
                intVolunteerStatus
            FROM
                $tablename
            WHERE  
                intMemberID = $Data->{'clientValues'}{'memberID'}
                AND intAssocID = $Data->{'clientValues'}{'assocID'}
                $clubWHERE
                AND intSeasonID IN ($Data->{'SystemConfig'}{'checkLastSeasonTypes'})
                AND intMSRecStatus =1
            ORDER BY intSeasonID DESC
            LIMIT 1
        ];
        my $query = $db->prepare($st);
        $query->execute();
        my $lastref=$query->fetchrow_hashref();
        $dref->{intPlayerStatus}    = 1 if ($lastref->{intPlayerStatus});
        $dref->{intCoachStatus}     = 1 if ($lastref->{intCoachStatus});
        $dref->{intUmpireStatus}    = 1 if ($lastref->{intUmpireStatus});
        $dref->{intOfficialStatus}  = 1 if ($lastref->{intOfficialStatus});
        $dref->{intMiscStatus}      = 1 if ($lastref->{intMiscStatus});
        $dref->{intVolunteerStatus} = 1 if ($lastref->{intVolunteerStatus});
    }

    my $txt_SeasonName= $Data->{'SystemConfig'}{'txtSeason'} || 'Season';
    my %FieldDefs = (
      fields => {
          SeasonName => {
              label => "$txt_Name Name",
              value => $dref->{strSeasonName},
              type  => 'text',
              readonly => 1, 
              sectionname => 'main',
          },
          intMSRecStatus=> {
              label => qq[Participated in this $txt_SeasonName?],
              value => $dref->{intMSRecStatus},
              type  => 'checkbox',
              default => 1,
              displaylookup => {1 => 'Yes', -1 => 'No'},
              sectionname => 'main',
          },
          intSeasonID => {
              label => $option eq 'add' ? "$txt_Name Name" : '',
              value => $dref->{intSeasonID},
              type  => 'lookup',
              options => $seasons_vals,
              firstoption => ['',"Choose $txt_Name"],
              compulsory => $option eq 'add' ? 1 : 0,
          },
          ClubName => {
              label => $dref->{intClubID} ? "$Data->{'LevelNames'}{$Defs::LEVEL_CLUB} Name" : '',
              value => $dref->{ClubName},
              type  => 'text',
              readonly =>1, 
              sectionname => 'main',
          },
          intClubID => {
              label => ($action =~ /CADD$/) ? "$Data->{'LevelNames'}{$Defs::LEVEL_CLUB} Name" : '',
              value => $dref->{intClubID} || (($Data->{'clientValues'}{'clubID'} and $Data->{'clientValues'}{'clubID'} != $Defs::INVALID_ID) ? $Data->{'clientValues'}{'clubID'} : 0),
              type  => 'lookup',
              options => $clubs_vals,
              firstoption => ['',"Choose $Data->{'LevelNames'}{$Defs::LEVEL_CLUB} (from list of $Data->{'LevelNames'}{$Defs::LEVEL_CLUB.'_P'} registered to)"],
              compulsory => ($option eq 'add' and $action =~ /CADD$/) ? 1 : 0,
          },
          intSeasonMemberPackageID=> {
              label => "$levelName $txt_Name Member Package",
              value => $dref->{intSeasonMemberPackageID},
              type => 'lookup',
              options => $MemberPackages,
              firstoption => [''," "],
          },
          intPlayerAgeGroupID => {
              label => "$txt_AgeGroupName",
              value => $dref->{intPlayerAgeGroupID},
              type => 'lookup',
              options => $ageGroups_vals,
              firstoption => ['',"Choose $txt_AgeGroupName"],
          },
          intPlayerStatus => {
              label => "Player in $levelName?",
              value => $dref->{intPlayerStatus},
              type => 'checkbox',
              displaylookup => {1 => 'Yes', 0 => 'No'},
              sectionname => 'main',
              readonly =>($option eq 'edit' and $Data->{'SystemConfig'}{'LockSeasons'}) ? 1 : 0,
          },
          intPlayerFinancialStatus=> {
              label => "Player Financial in $levelName?",
              value => $dref->{intPlayerFinancialStatus},
              type => 'checkbox',
              displaylookup => {1 => 'Yes', 0 => 'No'},
              readonly=>($option eq 'edit' and $Data->{'SystemConfig'}{'LockSeasons'}) ? 1 : 0,
              sectionname => 'main',
          },
          DateInPlayer=> {
              label => "Date Player created in $levelName",
              value => $dref->{DateInPlayer},
              type => 'date',
              readonly=>1,
              sectionname => 'main',
          },
          intCoachStatus => {
              label => "Coach in $levelName?",
              value => $dref->{intCoachStatus},
              type => 'checkbox',
              displaylookup => {1 => 'Yes', 0 => 'No'},
              readonly=>($option eq 'edit' and $Data->{'SystemConfig'}{'LockSeasons'}) ? 1 : 0,
              sectionname => 'main',
          },
          intCoachFinancialStatus=> {
              label => "Coach Financial in $levelName?",
              value => $dref->{intCoachFinancialStatus},
              type => 'checkbox',
              readonly=>($option eq 'edit' and $Data->{'SystemConfig'}{'LockSeasons'}) ? 1 : 0,
              displaylookup => {1 => 'Yes', 0 => 'No'},
              sectionname => 'main',
          },
          DateInCoach=> {
              label => "Date Coach created in $levelName",
              value => $dref->{DateInCoach},
              type => 'date',
              readonly=>1,
              sectionname => 'main',
          },
          intUmpireStatus => {
              label => "Match Official in $levelName?",
              value => $dref->{intUmpireStatus},
              type => 'checkbox',
              displaylookup => {1 => 'Yes', 0 => 'No'},
              readonly=>($option eq 'edit' and $Data->{'SystemConfig'}{'LockSeasons'}) ? 1 : 0,
              sectionname => 'main',
          },
          intUmpireFinancialStatus=> {
              label => "Match Official Financial in $levelName?",
              value => $dref->{intUmpireFinancialStatus},
              type => 'checkbox',
              displaylookup => {1 => 'Yes', 0 => 'No'},
              readonly=>($option eq 'edit' and $Data->{'SystemConfig'}{'LockSeasons'}) ? 1 : 0,
              sectionname => 'main',
          },
          DateInUmpire=> {
              label => "Date Match Official created in $levelName",
              value => $dref->{DateInUmpire},
              type => 'date',
              readonly=>1,
              sectionname => 'main',
          },
          intOfficialStatus => {
              label => "Official in $levelName?",
              value => $dref->{intOfficialStatus},
              type => 'checkbox',
              displaylookup => {1 => 'Yes', 0 => 'No'},
              readonly=>($option eq 'edit' and $Data->{'SystemConfig'}{'LockSeasons'}) ? 1 : 0,
              sectionname => 'main',
          },
          intOfficialFinancialStatus=> {
              label => "Official Financial in $levelName?",
              value => $dref->{intOfficialFinancialStatus},
              type => 'checkbox',
              displaylookup => {1 => 'Yes', 0 => 'No'},
              readonly=>($option eq 'edit' and $Data->{'SystemConfig'}{'LockSeasons'}) ? 1 : 0,
              sectionname => 'main',
          },
          DateInOfficial=> {
              label => "Date Official created in $levelName",
              value => $dref->{DateInOfficial},
              type => 'date',
              readonly=>1,
              sectionname => 'main',
          },
          intMiscStatus => {
              label => "Misc in $levelName?",
              value => $dref->{intMiscStatus},
              type => 'checkbox',
              displaylookup => {1 => 'Yes', 0 => 'No'},
              readonly=>($option eq 'edit' and $Data->{'SystemConfig'}{'LockSeasons'}) ? 1 : 0,
              sectionname => 'main',
          },
          intMiscFinancialStatus=> {
              label => "Misc Financial in $levelName?",
              value => $dref->{intMiscFinancialStatus},
              type => 'checkbox',
              readonly=>($option eq 'edit' and $Data->{'SystemConfig'}{'LockSeasons'}) ? 1 : 0,
              displaylookup => {1 => 'Yes', 0 => 'No'},
              sectionname => 'main',
          },
          DateInMisc=> {
              label => "Date Misc created in $levelName",
              value => $dref->{DateInMisc},
              type => 'date',
              readonly=>1,
              sectionname => 'main',
          },
          intVolunteerStatus => {
              label => "Volunteer in $levelName?",
              value => $dref->{intVolunteerStatus},
              type => 'checkbox',
              displaylookup => {1 => 'Yes', 0 => 'No'},
              readonly=>($option eq 'edit' and $Data->{'SystemConfig'}{'LockSeasons'}) ? 1 : 0,
              sectionname => 'main',
          },
          intVolunteerFinancialStatus=> {
              label => "Volunteer Financial in $levelName?",
              value => $dref->{intVolunteerFinancialStatus},
              type => 'checkbox',
              readonly=>($option eq 'edit' and $Data->{'SystemConfig'}{'LockSeasons'}) ? 1 : 0,
              displaylookup => {1 => 'Yes', 0 => 'No'},
              sectionname => 'main',
          },
          DateInVolunteer=> {
              label => "Date Volunteer created in $levelName",
              value => $dref->{DateInVolunteer},
              type => 'date',
              readonly=>1,
              sectionname => 'main',
          },
          intOther1Status => {
              label => $Data->{'SystemConfig'}{'Seasons_Other1'} ? "$Data->{'SystemConfig'}{'Seasons_Other1'} in $levelName?" : '',
              value => $dref->{intOther1Status},
              type => 'checkbox',
              displaylookup => {1 => 'Yes', 0 => 'No'},
              readonly=>($option eq 'edit' and $Data->{'SystemConfig'}{'LockSeasons'}) ? 1 : 0,
              sectionname => 'main',
          },
          intOther1FinancialStatus=> {
              label => $Data->{'SystemConfig'}{'Seasons_Other1'} ? "$Data->{'SystemConfig'}{'Seasons_Other1'} Financial in $levelName?" : '',
              value => $dref->{intOther1FinancialStatus},
              type => 'checkbox',
              displaylookup => {1 => 'Yes', 0 => 'No'},
              readonly=>($option eq 'edit' and $Data->{'SystemConfig'}{'LockSeasons'}) ? 1 : 0,
              sectionname => 'main',
          },
          DateInOther1 => {
              label => $Data->{'SystemConfig'}{'Seasons_Other1'} ? "Date $Data->{'SystemConfig'}{'Seasons_Other1'} created in $levelName?" : '',
              value => $dref->{DateInOther1},
              type => 'date',
              readonly => 1,
              sectionname => 'main',
          },
          intOther2Status => {
              label => $Data->{'SystemConfig'}{'Seasons_Other2'} ? "$Data->{'SystemConfig'}{'Seasons_Other2'} in $levelName?" : '',
              value => $dref->{intOther2Status},
              type => 'checkbox',
              readonly => ($option eq 'edit' and $Data->{'SystemConfig'}{'LockSeasons'}) ? 1 : 0,
              displaylookup => {1 => 'Yes', 0 => 'No'},
              sectionname => 'main',
          },
          intOther2FinancialStatus=> {
              label => $Data->{'SystemConfig'}{'Seasons_Other2'} ? "$Data->{'SystemConfig'}{'Seasons_Other2'} Financial in $levelName?" : '',
              value => $dref->{intOther2FinancialStatus},
              type => 'checkbox',
              displaylookup => {1 => 'Yes', 0 => 'No'},
              readonly=>($option eq 'edit' and $Data->{'SystemConfig'}{'LockSeasons'}) ? 1 : 0,
              sectionname => 'main',
          },
          DateInOther2 => {
              label => $Data->{'SystemConfig'}{'Seasons_Other2'} ? "Date $Data->{'SystemConfig'}{'Seasons_Other2'} created in $levelName?" : '',
              value => $dref->{DateInOther2},
              type => 'date',
              readonly=>1,
              sectionname => 'main',
          },
      },
      order => [
          qw(
              SeasonName 
              intSeasonID 
              intMSRecStatus 
              ClubName 
              intClubID 
              intSeasonMemberPackageID 
              intPlayerAgeGroupID 
              intPlayerStatus 
              intPlayerFinancialStatus 
              DateInPlayer 
              intCoachStatus 
              intCoachFinancialStatus 
              DateInCoach 
              intUmpireStatus 
              intUmpireFinancialStatus 
              DateInUmpire 
              intOfficialStatus 
              intOfficialFinancialStatus 
              DateInOfficial 
              intMiscStatus 
              intMiscFinancialStatus 
              DateInMisc
              intVolunteerStatus 
              intVolunteerFinancialStatus 
              DateInVolunteer
              intOther1Status 
              intOther1FinancialStatus 
              DateInOther1 
              intOther2Status 
              intOther2FinancialStatus 
              DateInOther2
          )
      ],
      options => {
          labelsuffix => ':',
          hideblank => 1,
          target => $Data->{'target'},
          formname => 'ms_form',
          submitlabel => "Update $txt_Name Summary",
          introtext => 'auto',
          buttonloc => 'bottom',
          updateSQL => $msupdate,
          addSQL => $msadd,
          afteraddFunction => \&postMemberSeasonAdd,
          afteraddParams => [$option,$Data,$Data->{'db'}, $memberSeasonID],
          afterupdateFunction => \&postMemberSeasonUpdate,
          afterupdateParams => [$option,$Data,$Data->{'db'}, $memberSeasonID],
          updateOKtext => qq[
              <div class="OKmsg">Record updated successfully</div> <br>
              <a href="$Data->{'target'}?client=$client&amp;a=M_HOME">Return to Member Record</a>
          ],
          addOKtext => qq[
              <div class="OKmsg">Record added successfully</div> <br>
              <a href="$Data->{'target'}?client=$client&amp;a=M_HOME">Return to Member Record</a>
          ],
          addBADtext => qq[
              <div class="OKmsg">Record was not inserted</div> <br>
              <a href="$Data->{'target'}?client=$client&amp;a=M_HOME">Return to Member Record</a>
          ],
          updateBADtext => qq[
              <div class="OKmsg">Record was not updated</div> <br>
              <a href="$Data->{'target'}?client=$client&amp;a=M_HOME">Return to Member Record</a>
          ],
          auditFunction=> \&auditLog,
          auditAddParams => [
              $Data,
              'Add Season',
              'Member'
          ],
          auditEditParams => [
              $memberSeasonID,
              $Data,
              'Update Season',
              'Member'
          ],
      },
      sections => [ ['main','Details'], ],
      carryfields =>  {
          client => $client,
          a => $action,
          msID => $memberSeasonID,
      },
    );
    ($resultHTML, undef ) = handleHTMLForm(\%FieldDefs, undef, $option, '',$db);
        if (! $resultHTML)  {
            $resultHTML .= qq[
                <div class="warningmsg">$txt_Name record may already exist</div> <br>
                <a href="$Data->{'target'}?client=$client&amp;a=M_HOME">Return to Member Record</a>
            ];
        }
    my $editDetailsLink = '';
    if (!$Data->{'ReadOnlyLogin'} and $option eq 'display' and ! ($Data->{'clientValues'}{'authLevel'} <= $Defs::LEVEL_CLUB and ! $dref->{intClubID})) {
        $editDetailsLink .= qq[ <a href="$target?a=SN_MSviewEDIT&amp;msID=$memberSeasonID&amp;client=$client">Edit details</a> ];
    }
    $editDetailsLink = '' if ($Data->{'clientValues'}{'authLevel'} == $Defs::LEVEL_CLUB and $Data->{'SystemConfig'}{'Club_MemberEditOnly'});
    $editDetailsLink = '' if $Data->{'SystemConfig'}{'LockSeasonsFullEditLock'};

    # if LockSeasonsCRL is set all levels above club can edit season record. 
    $editDetailsLink = '' if ($Data->{'SystemConfig'}{'LockSeasonsCRL'} and $Data->{'clientValues'}{'authLevel'} <$Defs::LEVEL_ASSOC);
    $resultHTML .= $editDetailsLink;
    $resultHTML=qq[<div>Cannot find Member $txt_Name record.</div>] if !ref $dref;
    $resultHTML = qq[<div>$resultHTML</div>];
    return ($resultHTML, "$txt_Name Summary");
}

sub postMemberSeasonAdd {
  my ($id, $params, $action, $Data, $db, $memberSeasonID) = @_;
  my $nationalSeasonID = getNationalReportingPeriod($Data->{db}, $Data->{'Realm'}, $Data->{'RealmSubType'});
  my $st = qq[
    UPDATE tblMember_Seasons_$Data->{'Realm'}
    SET intNatReportingGroupID = ?
    WHERE intMemberSeasonID = ?
  ];
  my $q = $Data->{db}->prepare($st);
  $q->execute($nationalSeasonID, $id);
  postMemberSeasonUpdate($id,$params, $action,$Data,$db, $memberSeasonID);
}

sub postMemberSeasonUpdate    {
  my ($id,$params, $action,$Data,$db, $memberSeasonID) = @_;
  $memberSeasonID||=0;
    my $tablename = "tblMember_Seasons_$Data->{'Realm'}";
    $id ||= $memberSeasonID;
    my $st =qq[
        SELECT MS.intSeasonID, DATE_FORMAT(M.dtDOB, "%Y%m%d") as DOBAgeGroup, M.intGender, MS.intClubID
        FROM $tablename as MS
            INNER JOIN tblMember as M ON (M.intMemberID = MS.intMemberID)
        WHERE MS.intMemberID = $Data->{'clientValues'}{'memberID'}
            AND MS.intAssocID = $Data->{'clientValues'}{'assocID'}
            AND MS.intMemberSeasonID = $id
    ];
    
  my $query = $db->prepare($st);
  $query->execute();
    my ($seasonID, $DOBAgeGroup, $Gender, $intClubID) =$query->fetchrow_array();
    $seasonID ||= 0;
    my $assocSeasons = getDefaultAssocSeasons($Data);
    if ($seasonID and $Data->{'clientValues'}{'assocID'} and $Data->{'clientValues'}{'memberID'} and $id)   {
    #Transactions::insertDefaultRegoTXN($db, $Defs::LEVEL_MEMBER, $Data->{'clientValues'}{'memberID'}, $Data->{'clientValues'}{'assocID'});
        ## I think this is to get Member.Interests updated
        my $genAgeGroup ||=new GenAgeGroup ($Data->{'db'},$Data->{'Realm'}, $Data->{'RealmSubType'}, $Data->{'clientValues'}{'assocID'});
        my $ageGroupID=$genAgeGroup->getAgeGroup ($Gender, $DOBAgeGroup) || 0;
        my %types=();
        $types{'intPlayerStatus'}    = $params->{'d_intPlayerStatus'}    if ($params->{'d_intPlayerStatus'});
        $types{'intCoachStatus'}     = $params->{'d_intCoachStatus'}     if ($params->{'d_intCoachStatus'});
        $types{'intUmpireStatus'}    = $params->{'d_intUmpireStatus'}    if ($params->{'d_intUmpireStatus'});
        $types{'intOfficialStatus'}  = $params->{'d_intOfficialStatus'}  if ($params->{'d_intOfficialStatus'});
        $types{'intMiscStatus'}      = $params->{'d_intMiscStatus'}      if ($params->{'d_intMiscStatus'});
        $types{'intVolunteerStatus'} = $params->{'d_intVolunteerStatus'} if ($params->{'d_intVolunteerStatus'});
        $types{'intOther1Status'}    = $params->{'d_intOther1Status'}    if ($params->{'d_intOther1Status'});
        $types{'intOther2Status'}    = $params->{'d_intOther2Status'}    if ($params->{'d_intOther2Status'});
        $types{'intMSRecStatus'}     = $params->{'d_intMSRecStatus'} == 1 ? 1 : -1;
    $types{'userselected'}=1;
        insertMemberSeasonRecord($Data, $Data->{'clientValues'}{'memberID'}, $seasonID, $Data->{'clientValues'}{'assocID'}, $intClubID, $ageGroupID, \%types);
        ## UNREMOVED THIS
        if (($intClubID or $Data->{'clientValues'}{'clubID'} > 0) and $types{'intMSRecStatus'} == 1)    {
            ## Lets remove the "types"
            if (! $Data->{'SystemConfig'}{'Seasons_StatusClubToAssoc'}) {
                delete $types{'intPlayerStatus'};
                delete $types{'intCoachStatus'};
                delete $types{'intUmpireStatus'};
                delete $types{'intOfficialStatus'};
                delete $types{'intMiscStatus'};
                delete $types{'intVolunteerStatus'};
                delete $types{'intOther1Status'};
                delete $types{'intOther2Status'};
            }
            insertMemberSeasonRecord($Data, $Data->{'clientValues'}{'memberID'}, $seasonID, $Data->{'clientValues'}{'assocID'}, 0, $ageGroupID, \%types);
        }

        if ($assocSeasons->{'newRegoSeasonID'} and $Data->{'SystemConfig'}{'Seasons_activateMembers'} and $types{'intMSRecStatus'} == 1) {
                        my $st = qq[
                                UPDATE tblMember_Associations
                                SET intRecStatus = $Defs::RECSTATUS_ACTIVE
                                WHERE intMemberID = $Data->{'clientValues'}{'memberID'}
                                        AND intAssocID = $Data->{'clientValues'}{'assocID'}
                        ];
                        my $qry= $Data->{'db'}->prepare($st);
                        $qry->execute or query_error($st);
                }
    }
}

sub season_details  {
    my ($action, $Data, $seasonID)=@_;

  my $lang = $Data->{'lang'};
    my $option='display';
    $option='edit' if $action eq 'SN_DTE' and allowedAction($Data, 'sn_e');
    $option='add' if $action eq 'SN_DTA' and allowedAction($Data, 'sn_a');
  $seasonID=0 if $option eq 'add';
    my $field=loadSeasonDetails($Data->{'db'}, $seasonID, $Data->{'Realm'}, $Data->{'RealmSubType'}, $Data->{'clientValues'}{'assocID'}) || ();
    my $intAssocID = $Data->{'clientValues'}{'assocID'} >= 0 ? $Data->{'clientValues'}{'assocID'} : 0;
    my $txt_Name= $lang->txt($Data->{'SystemConfig'}{'txtSeason'}) || $lang->txt('Season');
    my $txt_Names= $lang->txt($Data->{'SystemConfig'}{'txtSeasons'}) || $lang->txt('Seasons');
    
  my $client=setClient($Data->{'clientValues'}) || '';

    my $lockedlabel = "$txt_Name Locked";
    my $archivelabel = "$txt_Name Archived";

    $lockedlabel = '' if !$seasonID;
    $archivelabel = '' if !$seasonID;

    my %FieldDefinitions=(
        fields=>    {
            strSeasonName => {
                label => "$txt_Name Name",
                value => $field->{strSeasonName},
                type  => 'text',
                size  => '40',
                maxsize => '100',
                compulsory => 1,
                sectionname=>'details',
            },
            intSeasonOrder=> {
                label => "$txt_Name Order",
                value => $field->{intSeasonOrder},
                type  => 'text',
                size  => '15',
                maxsize => '15',
                validate => 'NUMBER',
                sectionname=>'details',
            },
            intArchiveSeason=> {
                label => $archivelabel,
                value => $field->{intArchiveSeason},
                type  => 'checkbox',
                displaylookup => {1 => 'Yes', 0 => 'No'},
                sectionname=>'details',
            },
            intLocked => {
                 label => $lockedlabel,
                 value => $field->{intLocked},
                 type  => 'checkbox',
                 displaylookup => {1 => 'Yes', 0 => 'No'},
                 sectionname=>'details',
            },
        },
        order => [qw(strSeasonName intSeasonOrder intArchiveSeason intLocked)],
        sections => [
            ['details',"$txt_Name Details"],
        ],  
        options => {
            labelsuffix => ':',
            hideblank => 1,
            target => $Data->{'target'},
            formname => 'n_form',
            submitlabel => "Update $txt_Name",
            introtext => 'auto',
            NoHTML => 1,
            updateSQL => qq[
                UPDATE tblSeasons
                    SET --VAL--
                WHERE intSeasonID = $seasonID AND intAssocID = $intAssocID
            ],
            addSQL => qq[
                INSERT INTO tblSeasons
                    (intRealmID, intRealmSubTypeID, intAssocID, dtAdded,  --FIELDS-- )
                VALUES 
                    ($Data->{'Realm'}, $Data->{'RealmSubType'}, $intAssocID, SYSDATE(), --VAL-- )
            ],
            auditFunction=> \&auditLog,
            auditAddParams => [
                $Data,
                'Add',
                'Seasons'
            ],
            auditEditParams => [
                $seasonID,
                $Data,
                'Update',
                'Seasons'
            ],
            LocaleMakeText => $Data->{'lang'},
        },
        carryfields =>  {
            client => $client,
            a => $action,
            seasonID => $seasonID,
        },
    );
    my $resultHTML='';
    ($resultHTML, undef )=handleHTMLForm(\%FieldDefinitions, undef, $option, '',$Data->{'db'});
    my $title=qq[$txt_Name - $field->{strSeasonName}];
    if($option eq 'display')  {
        my $chgoptions='';
        $chgoptions.=qq[<span class = "button-small generic-button"><a href="$Data->{'target'}?client=$client&amp;a=SN_DTE&amp;seasonID=$seasonID">Edit $txt_Name</a></span> ] if allowedAction($Data, 'sn_e');
        $chgoptions=qq[<div class="changeoptions">$chgoptions</div>] if $chgoptions;
        $chgoptions= '' if ($Data->{'clientValues'}{'authLevel'} != $Defs::LEVEL_NATIONAL and ! $field->{intAssocID});
        $chgoptions= '' if ($Data->{'clientValues'}{'authLevel'} != $Defs::LEVEL_NATIONAL and $Data->{'SystemConfig'}{'Seasons_NationalOnly'});
        $title=$chgoptions.$title;
    }
    $title="Add New $txt_Name" if $option eq 'add';
    my $text = qq[<p><a href="$Data->{'target'}?client=$client&amp;a=SN_L">Click here</a> to return to list of $txt_Names</p>];
    $resultHTML = $text.qq[<br><br>].$resultHTML.qq[<br><br>$text];

    return ($resultHTML,$title);
}


sub loadSeasonDetails {
    my($db, $id, $realmID, $realmSubType, $assocID) = @_;
    return {} if !$id;

    $realmID ||= 0;
    $realmSubType ||=0;
    $assocID ||= 0;

    my $statement=qq[
        SELECT *
        FROM tblSeasons
        WHERE intSeasonID = $id 
            AND intRealmID = $realmID
            AND (intAssocID = $assocID OR intAssocID = 0)
            AND (intRealmSubTypeID = $realmSubType OR intRealmSubTypeID= 0)
    ];

    my $query = $db->prepare($statement);
    $query->execute();

    my $field=$query->fetchrow_hashref();
    $query->finish;
                                                                                                          
    foreach my $key (keys %{$field})  { if(!defined $field->{$key}) {$field->{$key}='';} }
    return $field;
}

sub insertMemberSeasonRecord    {

    # The following columns are handled via $types hash:
    # intPlayerAgeGroupID, 
    # intPlayerStatus, 
    # intPlayerFinancialStatus, 
    # intCoachStatus, 
    # intCoachFinancialStatus, 
    # intUmpireStatus, 
    # intUmpireFinancialStatus, 
    # intOfficialStatus, 
    # intOfficialFinancialStatus, 
    # intMiscStatus, 
    # intMiscFinancialStatus,
    # intVolunteerStatus, 
    # intVolunteerFinancialStatus,


    my ($Data, $intMemberID, $intSeasonID, $intAssocID, $intClubID, $intPlayerAgeGroupID, $types, $update_time, $rereg) = @_;
    $intMemberID || return;
    $intSeasonID || return;
    $intAssocID || return;
    $intClubID ||= 0;
    $intClubID = 0 if ($intClubID == $Defs::INVALID_ID);
    $intPlayerAgeGroupID ||= 0;
    my $tablename = "tblMember_Seasons_$Data->{'Realm'}";

    ## -- GET NATIONAL REPORTING SEASON ID
    my $nationalSeasonID = getNationalReportingPeriod($Data->{db}, $Data->{'Realm'}, $Data->{'RealmSubType'}, $intSeasonID);
    ## --

    my ($insert_cols, $insert_vals, $update_status, $update_financials, $update_dates) = ('', '', '', '', '');
    my $recStatus = '';
    $types->{'intMSRecStatus'} = 1 if ! defined $types->{'intMSRecStatus'};
    $types->{'userselected'} ||= 0;
    ## Don't run from screen where the user can actually affect the results
    if (!$types->{'userselected'} and $intSeasonID == $Data->{'SystemConfig'}{'Seasons_defaultNewRegoSeason'} and $Data->{'SystemConfig'}{'checkLastSeasonTypesFilter'}) {
        my $clubWHERE = ($intClubID>0) ? qq[ AND intClubID = $intClubID] : qq[ AND intClubID=0];
        my $st = qq[
            SELECT
                intPlayerStatus,
                intCoachStatus,
                intUmpireStatus,
                intOfficialStatus,
                intMiscStatus,
                intVolunteerStatus
            FROM
                $tablename
            WHERE  
                intMemberID = $intMemberID
                AND intAssocID = $intAssocID
                $clubWHERE
                AND intSeasonID IN ($Data->{'SystemConfig'}{'checkLastSeasonTypes'})
                AND intMSRecStatus = 1
            ORDER BY 
                intSeasonID DESC
            LIMIT 1
        ]; 
        my $query = $Data->{'db'}->prepare($st); 
        $query->execute();
        my $lastref=$query->fetchrow_hashref();
        $types->{intPlayerStatus}    = 2 if ($lastref->{intPlayerStatus}    and !$types->{intPlayerStatus});
        $types->{intCoachStatus}     = 2 if ($lastref->{intCoachStatus}     and !$types->{intCoachStatus});
        $types->{intUmpireStatus}    = 2 if ($lastref->{intUmpireStatus}    and !$types->{intUmpireStatus});
        $types->{intOfficialStatus}  = 2 if ($lastref->{intOfficialStatus}  and !$types->{intOfficialStatus});
        $types->{intMiscStatus}      = 2 if ($lastref->{intMiscStatus}      and !$types->{intMiscStatus});
        $types->{intVolunteerStatus} = 2 if ($lastref->{intVolunteerStatus} and !$types->{intVolunteerStatus});
    }
    foreach my $type (keys %{$types})   {
        next if ($type eq 'intOfficial'); #should this still be the case?
        next if ($type eq 'intMisc');     #should this? and if so, why not volunteer as well?
        next if ($type eq 'userselected');
        $types->{$type} ||= 0;
        if ($type ne 'intMSRecStatus')  {
            $insert_cols .= qq[, $type];
            my $value = $types->{$type};
            $value = 1 if ($value =~/1/ and $type =~ /Status/);
            $value=1 if ($value==2);
            $insert_vals .= qq[, $value];
        }
        if ($type eq 'intPlayerStatus' and $types->{$type} >= 1)    {
            $insert_cols .= qq[, dtInPlayer];
            $insert_vals .= qq[, CURDATE()];
            if ($types->{$type} == 1)   {
                $update_dates.= qq[, dtInPlayer= IF(dtInPlayer > '0000-00-00', dtInPlayer, CURDATE())];
            }
        }
        if ($type eq 'intCoachStatus' and $types->{$type} >= 1) {
            $insert_cols .= qq[, dtInCoach];
            $insert_vals .= qq[, CURDATE()];
            if ($types->{$type} == 1)   {
                $update_dates.= qq[, dtInCoach= IF(dtInCoach > '0000-00-00', dtInCoach, CURDATE())];
            }
        }
        if ($type eq 'intUmpireStatus' and $types->{$type} >= 1)    {
            $insert_cols .= qq[, dtInUmpire];
            $insert_vals .= qq[, CURDATE()];
            if ($types->{$type} == 1)   {
                $update_dates.= qq[, dtInUmpire= IF(dtInUmpire > '0000-00-00', dtInUmpire, CURDATE())];
            }
        }
        if ($type eq 'intOfficialStatus' and $types->{$type} >= 1)    {
            $insert_cols .= qq[, dtInOfficial];
            $insert_vals .= qq[, CURDATE()];
            if ($types->{$type} == 1)   {
                $update_dates.= qq[, dtInOfficial= IF(dtInOfficial > '0000-00-00', dtInOfficial, CURDATE())];
            }
        }
        if ($type eq 'intMiscStatus' and $types->{$type} >= 1) {
            $insert_cols .= qq[, dtInMisc];
            $insert_vals .= qq[, CURDATE()];
            if ($types->{$type} == 1) {
                $update_dates.= qq[, dtInMisc= IF(dtInMisc > '0000-00-00', dtInMisc, CURDATE())];
            }
        }
        if ($type eq 'intVolunteerStatus' and $types->{$type} >= 1) {
            $insert_cols .= qq[, dtInVolunteer];
            $insert_vals .= qq[, CURDATE()];
            if ($types->{$type} == 1) {
                $update_dates.= qq[, dtInVolunteer= IF(dtInVolunteer > '0000-00-00', dtInVolunteer, CURDATE())];
            }
        }
        if ($type eq 'intOther1Status' and $types->{$type} == 1)    {
            $insert_cols .= qq[, dtInOther1];
            $insert_vals .= qq[, CURDATE()];
            $update_dates.= qq[, dtInOther1= IF(dtInOther1 > '0000-00-00', dtInOther1, CURDATE())];
        }
        if ($type eq 'intOther2Status' and $types->{$type} == 1)    {
            $insert_cols .= qq[, dtInOther2];
            $insert_vals .= qq[, CURDATE()];
            $update_dates.= qq[, dtInOther2= IF(dtInOther2 > '0000-00-00', dtInOther2, CURDATE())];
        }
        if ($type eq 'intMSRecStatus')  {
            $recStatus = qq[, intMSRecStatus = $types->{$type}];
        }   
        if ($type !~ /Financial|intMSRecStatus|userselected/)   {
            my $value = $types->{$type};
            $types->{$type}= 1 if ($value =~/1/ and $type =~ /Status/);
            $update_status .= qq[, $type = $types->{$type}] if ($value < 2 and $type ne 'intSeasonMemberPackageID');
            $update_status .= qq[, $type = $types->{$type}] if ($type eq 'intSeasonMemberPackageID');
        }
        $update_financials .= qq[, $type = $types->{$type}] if ($type =~ /Financial/);
    }
    if ($intPlayerAgeGroupID)   {
        $insert_cols .= qq[, intPlayerAgeGroupID];
        $insert_vals .= qq[, $intPlayerAgeGroupID];
    }
    my $timeStamp = qq[ tTimeStamp=NOW() ];
    $timeStamp = qq[ tTimeStamp = "$update_time" ] if $update_time;
    if (exists $Data->{'fromsync'} and $Data->{'fromsync'} and exists $Data->{'fromsync_memberID'} and $Data->{'fromsync_memberID'} =~ /^S/) {
        $update_status='';
        $update_financials='';
        $update_dates='';
    }

    my $status  = 1;
    my $pending = 0;

    my $update_pending = '';

    if ($Data->{'SystemConfig'}{'AllowPendingRegistration'} and defined $rereg and !$rereg) {
        my $pendingTypes = getPendingTypes($Data->{'SystemConfig'});
        foreach my $type (keys %{$types})   {
            #there is only one pending field; set it to 1 if any of the types coming thru allow pending.
            if (exists $pendingTypes->{$type} and $pendingTypes->{$type}) {
                $status  = 0;
                $pending = 1;
                $insert_cols   .= qq[, intPlayerPending];
                $insert_vals   .= qq[, $pending];
                $recStatus      = qq[, intMSRecStatus=$status];
                $update_pending = qq[, intPlayerPending=$pending];
                last;
            }
        }
    } 

    if (!$pending) {
        if($Data->{'SystemConfig'}{'AllowPendingRegistration'} and $rereg == 2) {
            $recStatus = '';
        }
    }

    my $st = qq[
        INSERT INTO $tablename (
            intMSRecStatus, 
            intMemberID, 
            intAssocID, 
            intClubID, 
            intSeasonID,
            intNatReportingGroupID
            $insert_cols
        )
        VALUES (
            $status, 
            $intMemberID, 
            $intAssocID, 
            $intClubID, 
            $intSeasonID,
            $nationalSeasonID
            $insert_vals
        )
        ON DUPLICATE KEY 
            UPDATE $timeStamp $update_status $update_financials $update_dates $update_pending $recStatus
    ];

    my $query = $Data->{'db'}->prepare($st);
    $query->execute();

    my $ID = 0;

    if (exists $Data->{'fromsync'}) {
        $st = qq[
            SELECT 
                intMemberSeasonID
            FROM 
                $tablename
            WHERE
                intMemberID=$intMemberID
                AND intAssocID=$intAssocID
                AND intClubID=$intClubID
                AND intSeasonID=$intSeasonID
        ];
        $query = $Data->{'db'}->prepare($st);
        $query->execute();
        $ID = $query->fetchrow_array() || 0;
    }
    if ($types->{'intMSRecStatus'} and $types->{'intMSRecStatus'} == -1 and $intClubID == 0)    {
        ## The Assoc record was being marked as deleted, so do all club records aswell
        $st = qq[
            UPDATE 
                $tablename
            SET 
                intMSRecStatus=-1
            WHERE 
                intMemberID=$intMemberID
                AND intAssocID=$intAssocID
                AND intSeasonID=$intSeasonID
                AND intClubID>0 
        ];
    my $query = $Data->{'db'}->prepare($st);
    $query->execute();
    }
    ### Now lets go update the interest flags
    $st = qq[
        SELECT 
            MAX(intPlayerStatus)    as PlayerStatus, 
            MAX(intCoachStatus)     as CoachStatus, 
            MAX(intUmpireStatus)    as UmpireStatus,
            MAX(intOfficialStatus)  as OfficialStatus,
            MAX(intMiscStatus)      as MiscStatus,
            MAX(intVolunteerStatus) as VolunteerStatus
        FROM 
            $tablename
        WHERE 
            intMemberID = $intMemberID
            AND intMSRecStatus=1
    ];
    $query = $Data->{'db'}->prepare($st);
    $query->execute();

    my ($PlayerStatus, $CoachStatus, $UmpireStatus, $OfficialStatus, $MiscStatus, $VolunteerStatus ) = $query->fetchrow_array();

    $PlayerStatus    ||= 0;
    $CoachStatus     ||= 0;
    $UmpireStatus    ||= 0;
    $OfficialStatus  ||= 0;
    $MiscStatus      ||= 0;
    $VolunteerStatus ||= 0;

    $st = qq[
        UPDATE tblMember
        SET 
            intPlayer    = $PlayerStatus, 
            intCoach     = $CoachStatus, 
            intUmpire    = $UmpireStatus,
            intOfficial  = $OfficialStatus,
            intMisc      = $MiscStatus,
            intVolunteer = $VolunteerStatus
        WHERE 
            intMemberID = $intMemberID
    ];

    $Data->{'db'}->do($st);

    if ($Data->{'SystemConfig'}{'Seasons_StatusClubToAssoc'} or $Data->{'SystemConfig'}{'Seasons_FinancialsClubToAssoc'}) {
        $update_status = '';
        $st = qq[
            SELECT 
                COUNT(intMemberID)               as Count, 
                MAX(intPlayerStatus)             as PlayerStatus, 
                MAX(intCoachStatus)              as CoachStatus, 
                MAX(intUmpireStatus)             as UmpireStatus, 
                MAX(intOfficialStatus)           as OfficialStatus, 
                MAX(intMiscStatus)               as MiscStatus, 
                MAX(intVolunteerStatus)          as VolunteerStatus, 
                MAX(intOther1Status)             as Other1Status, 
                MAX(intOther2Status)             as Other2Status, 
                MAX(intPlayerFinancialStatus)    as PlayerFinancialStatus, 
                MAX(intCoachFinancialStatus)     as CoachFinancialStatus, 
                MAX(intUmpireFinancialStatus)    as UmpireFinancialStatus, 
                MAX(intOfficialFinancialStatus)  as OfficialFinancialStatus, 
                MAX(intMiscFinancialStatus)      as MiscFinancialStatus, 
                MAX(intVolunteerFinancialStatus) as VolunteerFinancialStatus, 
                MAX(intOther1FinancialStatus)    as Other1FinancialStatus, 
                MAX(intOther2FinancialStatus)    as Other2FinancialStatus
            FROM 
                $tablename
            WHERE 
                intMemberID=$intMemberID
                AND intAssocID=$intAssocID
                AND intClubID>0
                AND intSeasonID=$intSeasonID
                AND intMSRecStatus=1
        ];
        $query = $Data->{'db'}->prepare($st);
        $query->execute();
        my ($count, $PlayerStatus, $CoachStatus, $UmpireStatus, $OfficialStatus, $MiscStatus, $VolunteerStatus, 
            $Other1Status, $Other2Status, $PFStatus, $CFStatus, $UFStatus, $OFStatus, $MFStatus, $VFStatus, $O1FStatus, $O2FStatus) = $query->fetchrow_array();

        $PlayerStatus    ||= 0;
        $CoachStatus     ||= 0;
        $UmpireStatus    ||= 0;
        $OfficialStatus  ||= 0;
        $MiscStatus      ||= 0;
        $VolunteerStatus ||= 0;
        $Other1Status    ||= 0;
        $Other2Status    ||= 0;

        my $timeStamp = qq[NOW()];

        if (exists $Data->{'fromsync'}) {
            $timeStamp = qq[tTimeStamp ];
        }

        if ($Data->{'SystemConfig'}{'Seasons_StatusClubToAssoc'})   {
            $update_status .= qq[ , intPlayerStatus    = $PlayerStatus];
            $update_status .= qq[ , intCoachStatus     = $CoachStatus];
            $update_status .= qq[ , intUmpireStatus    = $UmpireStatus];
            $update_status .= qq[ , intOfficialStatus  = $OfficialStatus];
            $update_status .= qq[ , intMiscStatus      = $MiscStatus];
            $update_status .= qq[ , intVolunteerStatus = $VolunteerStatus];
            $update_status .= qq[ , intOther1Status    = $Other1Status];
            $update_status .= qq[ , intOther2Status    = $Other2Status];
        }

        if ($Data->{'SystemConfig'}{'Seasons_FinancialsClubToAssoc'})   {
            $update_status .= qq[ , intPlayerFinancialStatus    = 1] if $PFStatus;
            $update_status .= qq[ , intCoachFinancialStatus     = 1] if $CFStatus;
            $update_status .= qq[ , intUmpireFinancialStatus    = 1] if $UFStatus;
            $update_status .= qq[ , intOfficialFinancialStatus  = 1] if $OFStatus;
            $update_status .= qq[ , intMiscFinancialStatus      = 1] if $MFStatus;
            $update_status .= qq[ , intVolunteerFinancialStatus = 1] if $VFStatus;
            $update_status .= qq[ , intOther1FinancialStatus    = 1] if $O1FStatus;
            $update_status .= qq[ , intOther2FinancialStatus    = 1] if $O2FStatus;
        }

        $st = qq[
            UPDATE 
                $tablename
            SET 
                tTimeStamp=$timeStamp 
                $update_status
            WHERE 
                intMemberID=$intMemberID
                AND intAssocID=$intAssocID
                AND intClubID=0
                AND intSeasonID=$intSeasonID
        ];
        $Data->{'db'}->do($st) if $count;
    }

    if ($Data->{'RegoFormID'} and $Data->{'RegoFormID'} > 0)    {
          $st = qq[
              UPDATE 
                  $tablename
              SET 
                  intUsedRegoForm=1, 
                  dtLastUsedRegoForm = NOW(), 
                  intUsedRegoFormID=$Data->{'RegoFormID'}
              WHERE 
                  intMemberID = $intMemberID
                  AND intAssocID = $intAssocID
                  AND intClubID IN (0, $intClubID)
                  AND intSeasonID = $intSeasonID
          ];
          $Data->{'db'}->do($st);
    }

    if ($Data->{'SystemConfig'}{'Seasons_rolloverDateRegistered'})  {
        my $st = qq[
            UPDATE tblMember_Associations
            SET
                dtLastRegistered=NOW()
            WHERE
                intMemberID = $intMemberID
                AND intAssocID = $intAssocID
            LIMIT 1
        ];
        $Data->{'db'}->do($st);
    }

    return $ID;
}

sub getPendingTypes {
    my ($systemConfig) = @_;

    my @allowPendingTypes = (
        ['intPlayerStatus',   'Player'    ],
        ['intCoachStatus',    'Coach'     ],
        ['intUmpireStatus',   'Umpire'    ],
        ['intOfficialStatus', 'Official'  ],
        ['intMiscStatus',     'Misc'      ],
        ['intVolunteer',      'Volunteer' ],
    );

    my %pendingTypes = ();

    foreach my $item (@allowPendingTypes) {
        my $fieldName  = @$item[0];
        my $configName = 'AllowPending_'.@$item[1];
        $pendingTypes{$fieldName} = (exists $systemConfig->{$configName}) ? $systemConfig->{$configName} : 1;
    }

    return \%pendingTypes;
}

sub memberSeasonDuplicateResolution {

    my ($Data, $assocID, $fromID, $toID) = @_;
    
    my $realmID = $Data->{'Realm'} || 0;
    my $tablename = "tblMember_Seasons_$realmID";
    $Data->{'db'}->do(qq[UPDATE IGNORE $tablename SET intMemberID = $toID WHERE intMemberID=$fromID AND intAssocID = $assocID]);

    my $assocSeasons = getDefaultAssocSeasons($Data);
    my %types=();
    $types{'intMSRecStatus'} = 1;

    insertMemberSeasonRecord($Data, $toID, $assocSeasons->{'newRegoSeasonID'}, $assocID, 0, 0, undef) if ! $assocSeasons->{'allowSeasons'};

    ## Now lets handle the remaining duplicate records

    my $st = qq[
        SELECT 
            intClubID, intSeasonID, intPlayerAgeGroupID, 
            intPlayerStatus,          intPlayerFinancialStatus, 
            intCoachStatus,           intCoachFinancialStatus, 
            intUmpireStatus,          intUmpireFinancialStatus, 
            intOfficialStatus,        intOfficialFinancialStatus, 
            intMiscStatus,            intMiscFinancialStatus, 
            intVolunteerStatus,       intVolunteerFinancialStatus, 
            intOther1Status,          intOther2Status, 
            intOther1FinancialStatus, intOther2FinancialStatus
        FROM 
            $tablename
        WHERE 
            intMemberID = $fromID
            AND intAssocID=$assocID
    ];

    my $query = $Data->{'db'}->prepare($st) or query_error($st);

    $query->execute or query_error($st);

    my @MemberSeasons = qw(
        intPlayerAgeGroupID 
        intPlayerStatus          intPlayerFinancialStatus 
        intCoachStatus           intCoachFinancialStatus 
        intUmpireStatus          intUmpireFinancialStatus 
        intOfficialStatus        intOfficialFinancialStatus 
        intMiscStatus            intMiscFinancialStatus 
        intVolunteerStatus       intVolunteerFinancialStatus 
        intOther1Status          intOther2Status 
        intOther1FinancialStatus intOther2FinancialStatus
    );

    while(my $dref = $query->fetchrow_hashref())  {
        my $update_vals='';
        for my $type (@MemberSeasons)   {
            if ($dref->{$type})     {
                $update_vals .= qq[, ] if $update_vals;
                $update_vals .= qq[ $type=$dref->{$type}];
            }
        }
        if ($update_vals)       {
            $Data->{'db'}->do(qq[
                UPDATE IGNORE $tablename 
                SET 
                    $update_vals 
                WHERE 
                    intAssocID = $assocID 
                    AND intMemberID = $toID 
                    AND intClubID = $dref->{intClubID} 
                    AND intSeasonID = $dref->{intSeasonID}
            ]);
        }
    }

    $st = qq[
        SELECT 
            MAX(intPlayerStatus)    as PlayerStatus, 
            MAX(intCoachStatus)     as CoachStatus, 
            MAX(intUmpireStatus)    as UmpireStatus, 
            MAX(intOfficialStatus)  as OfficialStatus, 
            MAX(intMiscStatus)      as MiscStatus, 
            MAX(intVolunteerStatus) as VolunteerStatus
        FROM 
            $tablename
        WHERE 
            intMemberID = $toID
    ];

    $query = $Data->{'db'}->prepare($st);
    $query->execute();

    my ($PlayerStatus, $CoachStatus, $UmpireStatus, $OfficialStatus, $MiscStatus, $VolunteerStatus) = $query->fetchrow_array();

    $PlayerStatus    ||= 0;
    $CoachStatus     ||= 0;
    $UmpireStatus    ||= 0;
    $OfficialStatus  ||= 0;
    $MiscStatus      ||= 0;
    $VolunteerStatus ||= 0;

    $st = qq[
        UPDATE tblMember
        SET 
            intPlayer    = $PlayerStatus, 
            intCoach     = $CoachStatus, 
            intUmpire    = $UmpireStatus, 
            intOfficial  = $OfficialStatus, 
            intMisc      = $MiscStatus, 
            intVolunteer = $VolunteerStatus
        WHERE 
            intMemberID = $toID
    ];
    $Data->{'db'}->do($st);


}

sub viewDefaultAssocSeasons {
    my ($Data) = @_;

    my $realmID=$Data->{'Realm'} || 0;
    my $assocID=$Data->{'clientValues'}{'assocID'} || $Defs::INVALID_ID;
    my ($Seasons, $maxSeasonID) =getSeasons($Data);
    my $cl  = setClient($Data->{'clientValues'});

    my $st = qq[
        SELECT intCurrentSeasonID, intNewRegoSeasonID
        FROM tblAssoc
        WHERE intAssocID = $assocID
    ];

    my $query = $Data->{'db'}->prepare($st);
    $query->execute();

    my ($currentSeasonID, $newRegoSeasonID) = $query->fetchrow_array();
    $currentSeasonID ||= 0;
    $newRegoSeasonID ||= 0;

    if ($maxSeasonID and (! $currentSeasonID or ! $newRegoSeasonID))    {
        ## Don't allow blank currentSeason or new RegoSeason
        $currentSeasonID ||= $Data->{'SystemConfig'}{'Seasons_defaultCurrentSeason'} || $maxSeasonID;
        $newRegoSeasonID ||= $Data->{'SystemConfig'}{'Seasons_defaultNewRegoSeason'} || $maxSeasonID;
        $Data->{'db'}->do(qq[UPDATE tblAssoc SET intCurrentSeasonID = $currentSeasonID, intNewRegoSeasonID = $newRegoSeasonID WHERE intAssocID = $assocID]);
    }
    
    my $txt_Name= $Data->{'SystemConfig'}{'txtSeason'} || 'Season';
    my $txt_Names= $Data->{'SystemConfig'}{'txtSeasons'} || 'Seasons';

    my $subBody='';

    if (! $Data->{'SystemConfig'}{'Seasons_NationalOnly'})  {
        $subBody .= qq[
            <div class="sectionheader">Default $txt_Name Settings</div>
            <p>Choose your default <b>CURRENT $txt_Name</b> for the $Data->{'LevelNames'}{$Defs::LEVEL_ASSOC}. Press the 'Update' button to save your selection.</p>

            <form action="$Data->{'target'}" method="post">
        ].drop_down('currentSeasonID',$Seasons,undef,$currentSeasonID,1,0).qq[

            <p>Choose your default <b>NEW REGISTRATION $txt_Name</b> for the $Data->{'LevelNames'}{$Defs::LEVEL_ASSOC}. Press the 'Update' button to save your selection.</p>
        ].drop_down('newregoSeasonID',$Seasons,undef,$newRegoSeasonID,1,0).qq[
            <input type="hidden" name="a" value="SN_L_U">
            <input type="hidden" name="client" value="
        ].unescape($cl).qq[">
            <br><br><input type="submit" value=" Update "  class = "button proceed-button">
            </form>
        ];
    }
    else {
        $subBody .= qq[
            <div class="sectionheader">Default $txt_Name Settings</div>
            <p><b>These are locked, and set by National body only</b></p>
            <p><b>CURRENT $txt_Name</b> for the $Data->{'LevelNames'}{$Defs::LEVEL_ASSOC}.</p>
        ].drop_down('currentSeasonID',$Seasons,undef,$currentSeasonID,1,0).qq[

            <p><b>NEW REGISTRATION $txt_Name</b> for the $Data->{'LevelNames'}{$Defs::LEVEL_ASSOC}. </p>
        ].drop_down('newregoSeasonID',$Seasons,undef,$newRegoSeasonID,1,0);
        
    }

    return $subBody;
}

sub getSeasons  {
    my($Data, $allseason, $blankseason)=@_;
    $allseason ||= 0;
    $blankseason ||= 0;
    my $assocID=$Data->{'clientValues'}{'assocID'} || $Defs::INVALID_ID;
  
    my $subType = $Data->{'RealmSubType'} || 0;

    my $checkLocked = $Data->{'HideLocked'} ? qq[ AND intLocked <> 1] : '';
    my $subTypeSeasonOnly = $Data->{'SystemConfig'}->{'OnlyUseSubRealmSeasons'} ? '' : 'OR intRealmSubTypeID= 0';
    my $st=qq[
        SELECT 
            intSeasonID, strSeasonName, intArchiveSeason 
        FROM 
            tblSeasons 
        WHERE 
            intRealmID = $Data->{'Realm'}
            $checkLocked
        ORDER BY intSeasonOrder
    ]; 

    my $query = $Data->{'db'}->prepare($st);
    $query->execute();

    my $body='';
    my %Seasons=();
    my $maxID = 0;

    while (my ($id,$name)=$query->fetchrow_array()) {
        $maxID = $id;
        $Seasons{$id}=$name||'';
    }

    my $txt_SeasonName= $Data->{'SystemConfig'}{'txtSeason'} || 'Season';
    my $txt_SeasonNames= $Data->{'SystemConfig'}{'txtSeasons'} || 'Seasons';

    if ($Data->{'BlankSeason'} || $blankseason) {
        $Seasons{-1} = join(
            q{},
            '--',
            $Data->{lang}->txt("No $txt_SeasonName"),
            '/',
            $Data->{lang}->txt($Data->{'LevelNames'}{$Defs::LEVEL_COMP}),
            '--',
        );
    }
    else {
        $Seasons{-2} = join(
            q{},
            '--',
            $Data->{lang}->txt("No $txt_SeasonName"),
            '--',
        );
    }

    if ($Data->{'AllSeasons'} || $allseason) {
        $Seasons{-99} = join(
            q{},
            '--',
            $Data->{lang}->txt("All $txt_SeasonNames"),
            '--',
        );
    }

    return (\%Seasons, $maxID);
}

sub setDefaultAssocSeasonConfig {

    my ($Data) = @_;

    my $currentSeasonID = param('currentSeasonID') || 0;
    my $newregoSeasonID = param('newregoSeasonID') || 0;

    if ($Data->{'clientValues'}{'assocID'} and $Data->{'clientValues'}{'assocID'} != $Defs::INVALID_ID)     {
        my $txt_Name= $Data->{'SystemConfig'}{'txtSeason'} || 'Season';
        my $txt_Names= $Data->{'SystemConfig'}{'txtSeasons'} || 'Seasons';
        my $st = qq[
            UPDATE tblAssoc
            SET intCurrentSeasonID = $currentSeasonID, intNewRegoSeasonID = $newregoSeasonID
            WHERE intAssocID =$Data->{'clientValues'}{'assocID'}
        ];
        $Data->{'db'}->do($st);
        return qq[ <div class="OKmsg"> $txt_Name Settings updated successfully</div><br>];
    }
    return '';

}
sub getDefaultAssocSeasons  {

    my ($Data) = @_;

    my $assocID=$Data->{'OverrideAssocID'} || $Data->{'clientValues'}{'assocID'} || $Defs::INVALID_ID;
    my ($Seasons, $maxSeasonID) =getSeasons($Data);
    my $st = qq[
        SELECT intCurrentSeasonID, intNewRegoSeasonID, intAllowSeasons, intDefaultMemberTypeID
        FROM tblAssoc
        WHERE intAssocID = $assocID
    ];
    my $query = $Data->{'db'}->prepare($st);
    $query->execute();
    my ($currentSeasonID, $newRegoSeasonID, $allowSeasons, $defaultMemberType) = $query->fetchrow_array();
    $currentSeasonID ||= $Data->{'SystemConfig'}{'Seasons_defaultCurrentSeason'} || $maxSeasonID;
    $newRegoSeasonID ||= $Data->{'SystemConfig'}{'Seasons_defaultNewRegoSeason'} || $maxSeasonID;

    my %values = ();
    $values{'currentSeasonID'} = $currentSeasonID;
    $values{'currentSeasonName'} = $Seasons->{$currentSeasonID} || '';
    $values{'newRegoSeasonID'} = $newRegoSeasonID;
    $values{'newRegoSeasonName'} = $Seasons->{$newRegoSeasonID} || '';
    $values{'allowSeasons'} = $allowSeasons;
    $values{'defaultMemberType'} = $defaultMemberType || 0;

    return (\%values);
}

sub seasonRollover  {
    my($Data, $update_type, $members_ref)=@_;
    my $cgi=new CGI;
    my %params=$cgi->Vars();
    my $assocID=$Data->{'clientValues'}{'assocID'} || '';
    $assocID ='' if $assocID == $Defs::INVALID_ID;
    my $clubID=$Data->{'clientValues'}{'clubID'} || '';
    $clubID = 0 if $clubID == $Defs::INVALID_ID;
    my $teamID=$Data->{'clientValues'}{'teamID'} || '';
    $teamID = 0 if $teamID == $Defs::INVALID_ID;
    my $level=$Data->{'clientValues'}{'currentLevel'};
    return if !$assocID and $level <=$Defs::LEVEL_ASSOC;

    my %Rollover=();
    my $assocSeasons = getDefaultAssocSeasons($Data);
    my $genAgeGroup ||=new GenAgeGroup ($Data->{'db'},$Data->{'Realm'}, $Data->{'RealmSubType'}, $assocID);
    my $fromSeasonID = $params{'Seasons_rolloverFrom'} || 0;
    my $MStablename = "tblMember_Seasons_$Data->{'Realm'}";
    my $count=0;
    for my $mID (@{$members_ref})   {
        next if ! $mID;
        my $st = qq[
            SELECT 
                DATE_FORMAT(M.dtDOB, "%Y%m%d"), M.intGender, MS.intPlayerStatus, MS.intCoachStatus, MS.intUmpireStatus, 
                 MS.intOfficialStatus, MS.intMiscStatus, MS.intVolunteerStatus, MS.intOther1Status, MS.intOther2Status
            FROM 
                tblMember as M
            LEFT JOIN 
                $MStablename as MS ON (
                    MS.intMemberID = M.intMemberID 
                    AND MS.intSeasonID = $fromSeasonID
                    AND MS.intClubID = 0
                    AND MS.intAssocID = $assocID
                    AND MS.intMSRecStatus = 1
                )
           WHERE M.intMemberID = $mID
        ]; 

        my $qry= $Data->{'db'}->prepare($st); 
        $qry->execute or query_error($st);

        my ($DOBAgeGroup, $Gender, $PlayerStatus, $CoachStatus, $UmpireStatus, $OfficialStatus, $MiscStatus, $VolunteerStatus, $Other1Status, $Other2Status) = $qry->fetchrow_array();
        my %types=();

        $types{'intPlayerStatus'}    = 1 if ($PlayerStatus);
        $types{'intCoachStatus'}     = 1 if ($CoachStatus);
        $types{'intUmpireStatus'}    = 1 if ($UmpireStatus);
        $types{'intOfficialStatus'}  = 1 if ($OfficialStatus);
        $types{'intMiscStatus'}      = 1 if ($MiscStatus);
        $types{'intVolunteerStatus'} = 1 if ($VolunteerStatus);
        $types{'intOther1Status'}    = 1 if ($Other1Status);
        $types{'intOther2Status'}    = 1 if ($Other2Status);
        $types{'intMSRecStatus'}     = 1;
        $DOBAgeGroup ||= '';
        $Gender ||= 0;

        my $ageGroupID =$genAgeGroup->getAgeGroup($Gender, $DOBAgeGroup) || 0;
        insertMemberSeasonRecord($Data, $mID, $params{'Seasons_rolloverTo'}, $assocID, 0, $ageGroupID, \%types) if ($mID);
        $count++;
        if ($params{'Seasons_includeClubs'} or $clubID or $teamID)  {
            my $club_WHERE = $clubID ? qq[ AND MC.intClubID = $clubID] : '';
            my $season_WHERE = ($params{'Seasons_rolloverFrom'} > 0) ? qq[ AND MS.intSeasonID = $params{'Seasons_rolloverFrom'} ] : '';
            my $team_JOIN = $teamID ? qq[ INNER JOIN tblTeam as T ON (T.intTeamID = $teamID and MC.intClubID = T.intClubID)] : '';
            my $st = qq[
                SELECT DISTINCT 
                    MC.intClubID, MS.intPlayerStatus, MS.intCoachStatus, MS.intUmpireStatus, MS.intOfficialStatus, 
                    MS.intMiscStatus, MS.intVolunteerStatus, MS.intOther1Status, MS.intOther2Status
                FROM tblMember_Clubs as MC
                    LEFT JOIN $MStablename as MS ON (MS.intMemberID = MC.intMemberID 
                        AND MS.intClubID = MC.intClubID
                        AND MS.intAssocID = $assocID
                        AND MS.intMSRecStatus = 1)
                    $team_JOIN
                WHERE MC.intMemberID = $mID
                    AND MC.intStatus <> $Defs::RECSTATUS_DELETED
                    $club_WHERE
                    $season_WHERE
                ]; 
                my $qry= $Data->{'db'}->prepare($st); 
                $qry->execute or query_error($st);
                while (my $dref = $qry->fetchrow_hashref()) {
                my %types=();
                $types{'intPlayerStatus'}    = 1 if ($dref->{intPlayerStatus});
                $types{'intCoachStatus'}     = 1 if ($dref->{intCoachStatus});
                $types{'intUmpireStatus'}    = 1 if ($dref->{intUmpireStatus});
                $types{'intOfficialStatus'}  = 1 if ($dref->{intOfficialStatus});
                $types{'intMiscStatus'}      = 1 if ($dref->{intMiscStatus});
                $types{'intVolunteerStatus'} = 1 if ($dref->{intVolunteerStatus});
                $types{'intOther1Status'}    = 1 if ($dref->{intOther1Status});
                $types{'intOther2Status'}    = 1 if ($dref->{intOther2Status});
                insertMemberSeasonRecord($Data, $mID, $params{'Seasons_rolloverTo'}, $assocID, $dref->{'intClubID'}, $ageGroupID, \%types);
            }
        }
        if (($params{'Seasons_activateMembers'}) or ($assocSeasons->{'newRegoSeasonID'} and $Data->{'SystemConfig'}{'Seasons_activateMembers'})) {
            my $st = qq[
                UPDATE tblMember_Associations
                SET intRecStatus = $Defs::RECSTATUS_ACTIVE
                WHERE intMemberID = $mID
                    AND intAssocID = $assocID
            ];
            my $qry= $Data->{'db'}->prepare($st); 
            $qry->execute or query_error($st);
        }
        if ($Data->{'SystemConfig'}{'Seasons_rolloverDateRegistered'})  {
            my $st = qq[
                UPDATE 
                    tblMember_Associations
                SET         
                    dtLastRegistered=NOW()
                WHERE 
                    intMemberID = $mID
                    AND intAssocID = $assocID
                LIMIT 1
            ];
            $Data->{'db'}->do($st);
        }
        if ( $Data->{'Realm'} == 2 and $Data->{'RealmSubType'} == 2 ) {
            my $st = qq[
                SELECT
                    SG.intNextGradeID
                FROM
                    tblSchoolGrades AS SG
                    INNER JOIN tblMember AS M ON ( M.intGradeID=SG.intGradeID AND M.intMemberID=$mID )
            ];
            my $q = $Data->{'db'}->prepare($st);
            $q->execute();
            my $nextGradeID = $q->fetchrow_array() || 0;
            $st = qq[
                UPDATE tblMember
                SET intGradeID=$nextGradeID
                WHERE intMemberID=$mID
            ];
            $Data->{'db'}->do($st);
        }
  }
    return $count;
}

sub seasonToClubRollover    {
    my($Data, $rolloverClubID, $members_ref)=@_;

    my $cgi=new CGI;
    my %params=$cgi->Vars();

    my ($assocToID, $rolloverAssocName, $clubToID, $rolloverClubName, $toSeasonID) = ListMembers::getRolloverClub($Data, $rolloverClubID);
    return if ! $assocToID or ! $clubToID;


    my $assocID=$Data->{'clientValues'}{'assocID'} || '';
    $assocID ='' if $assocID == $Defs::INVALID_ID;
    my $clubID=$Data->{'clientValues'}{'clubID'} || '';
    $clubID = 0 if $clubID == $Defs::INVALID_ID;

    my $assocSeasons = getDefaultAssocSeasons($Data);
    my $genAgeGroup ||=new GenAgeGroup ($Data->{'db'},$Data->{'Realm'}, $Data->{'RealmSubType'}, $assocID);
    my $fromSeasonID = $params{'Seasons_rolloverFrom'} || 0;
    my $MStablename = "tblMember_Seasons_$Data->{'Realm'}";
    my $count=0;
    for my $mID (@{$members_ref}) {
        next if ! $mID;
        my $st = qq[
            SELECT 
                DATE_FORMAT(M.dtDOB, "%Y%m%d"), M.intGender, MS.intPlayerStatus, MS.intCoachStatus, MS.intUmpireStatus, 
                MS.intOfficialStatus, MS.intMiscStatus, MS.intVolunteerStatus, MS.intOther1Status, MS.intOther2Status
            FROM tblMember as M
            LEFT JOIN $MStablename as MS ON (MS.intMemberID = M.intMemberID 
                AND MS.intSeasonID = $fromSeasonID
                AND MS.intClubID = 0
                AND MS.intAssocID = $assocID
                AND MS.intMSRecStatus = 1
            )
            WHERE M.intMemberID = $mID
        ]; 
        my $qry= $Data->{'db'}->prepare($st); 
        $qry->execute or query_error($st);
        my ($DOBAgeGroup, $Gender, $PlayerStatus, $CoachStatus, $UmpireStatus, $OfficialStatus, $MiscStatus, $VolunteerStatus, $Other1Status, $Other2Status) = $qry->fetchrow_array();
        my %types=();
        $types{'intPlayerStatus'}    = 1 if ($PlayerStatus);
        $types{'intCoachStatus'}     = 1 if ($CoachStatus);
        $types{'intUmpireStatus'}    = 1 if ($UmpireStatus);
        $types{'intOfficialStatus'}  = 1 if ($OfficialStatus);
        $types{'intMiscStatus'}      = 1 if ($MiscStatus);
        $types{'intVolunteerStatus'} = 1 if ($VolunteerStatus);
        $types{'intOther1Status'}    = 1 if ($Other1Status);
        $types{'intOther2Status'}    = 1 if ($Other2Status);
        $types{'intMSRecStatus'}     = 1;
        $DOBAgeGroup ||= '';
        $Gender ||= 0;
        my $ageGroupID =$genAgeGroup->getAgeGroup($Gender, $DOBAgeGroup) || 0;
        if ($Data->{'SystemConfig'}{'allowMS_to_Club_rollover_ToSeason'})   {
            insertMemberSeasonRecord($Data, $mID, $toSeasonID, $assocToID, 0, $ageGroupID, \%types) if ($mID);
            insertMemberSeasonRecord($Data, $mID, $toSeasonID, $assocToID, $clubToID, $ageGroupID, \%types) if ($mID);
        }

        my $upd_st = qq[
            UPDATE 
                tblMember_Associations
            SET 
                intRecStatus=1
            WHERE
                intMemberID= $mID
                AND intAssocID = $assocToID
            LIMIT 1
        ];
        $Data->{'db'}->do($upd_st);
        my $ins_st = qq[
            INSERT IGNORE INTO tblMember_Associations
                (intMemberID, intAssocID, intRecStatus)
            VALUES 
                ($mID, $assocToID, 1)
        ];
        $Data->{'db'}->do($ins_st);
        $ins_st = qq[
            INSERT INTO tblMember_Types
                (intMemberID, intTypeID, intSubTypeID, intActive, intAssocID, intRecStatus)
            VALUES 
                ($mID,$Defs::MEMBER_TYPE_PLAYER,0,1,$assocToID, 1)
        ];
        $Data->{'db'}->do($ins_st);
#        Transactions::insertDefaultRegoTXN($Data->{'db'}, $Defs::LEVEL_MEMBER, $mID, $assocToID);
        $ins_st = qq[
            INSERT INTO tblMember_Clubs
                (intMemberID, intClubID, intStatus)
            VALUES 
                ($mID, $clubToID, 1)
        ];
        $Data->{'db'}->do($ins_st);

        if ( $Data->{'Realm'} == 2 and $Data->{'RealmSubType'} == 2 ) {
            my $st = qq[
                SELECT
                    SG.intNextGradeID
                FROM
                    tblSchoolGrades AS SG
                    INNER JOIN tblMember AS M ON ( M.intGradeID=SG.intGradeID AND M.intMemberID=$mID )
            ];
            my $q = $Data->{'db'}->prepare($st);
            $q->execute();
            my $nextGradeID = $q->fetchrow_array() || 0;
            $st = qq[
                UPDATE tblMember
                SET intPlayer=1, intGradeID=$nextGradeID
                WHERE intMemberID=$mID
            ];
            $Data->{'db'}->do($st);
        }
        else {
            my $mem_st = qq[UPDATE tblMember SET intPlayer = 1 WHERE intMemberID = $mID LIMIT 1];
            $Data->{'db'}->do($mem_st);
        }

        $upd_st = qq[UPDATE tblMember_Associations SET intRecStatus=0 WHERE intMemberID= $mID AND intAssocID = $assocID LIMIT 1];
        $Data->{'db'}->do($upd_st);
        $count++;
    }
    return $count;
}

sub isMemberInSeason  {
    my($Data, $memberID, $assocID, $clubID, $seasonID)= @_;
    return (0, 0) if !$seasonID or !$memberID or !$assocID;
    $clubID = 0 if $clubID == $Defs::INVALID_ID;
    $clubID ||= 0;
    my $MStablename = "tblMember_Seasons_$Data->{'Realm'}";
    my $st=qq[
        SELECT intMemberSeasonID, intMSRecStatus
        FROM $MStablename
        WHERE intMemberID =?
            AND intAssocID = ?
            AND intClubID = ?
            AND intSeasonID = ?
        LIMIT 1
    ];
    my $qry= $Data->{'db'}->prepare($st);
    $qry->execute($memberID, $assocID, $clubID, $seasonID);
    my($id, $status) = $qry->fetchrow_array();
    $qry->finish();
    return ($id and $status == 1)  ? ($id, 1) : ($id, $status);
}

sub listSeasons {
    my($Data) = @_;
    my $lang = $Data->{'lang'};
    my $resultHTML = '';
    my $txt_Name  = $lang->txt($Data->{'SystemConfig'}{'txtSeason'}) || $lang->txt('Season');
    my $txt_Names = $lang->txt($Data->{'SystemConfig'}{'txtSeasons'}) || $lang->txt('Seasons');
    my $subTypeSeasonOnly = $Data->{'SystemConfig'}->{'OnlyUseSubRealmSeasons'} ? '' : 'OR intRealmSubTypeID= 0';

    my $statement=qq[
        SELECT 
            intSeasonID, 
            strSeasonName, 
            DATE_FORMAT(dtAdded, '%d/%m/%Y') AS dtAdded, 
            dtAdded AS dtAdded_RAW, 
            intAssocID,
            intArchiveSeason
        FROM tblSeasons
        WHERE intRealmID = ?
            AND (intAssocID = ? OR intAssocID =0)
            AND (intRealmSubTypeID = ? $subTypeSeasonOnly)
        ORDER BY intSeasonOrder, strSeasonName
    ];

    my $query = $Data->{'db'}->prepare($statement);
    $query->execute(
          $Data->{'Realm'},
          $Data->{'clientValues'}{'assocID'},
          $Data->{'RealmSubType'},
    );

    my $client = $Data->{'client'};
    my @rowdata = ();
    while (my $dref= $query->fetchrow_hashref()) {
        $dref->{AddedBy} = $dref->{intAssocID} 
            ? $Data->{'LevelNames'}{$Defs::LEVEL_ASSOC} 
            : $Data->{'LevelNames'}{$Defs::LEVEL_NATIONAL};
        push @rowdata, {
            id => $dref->{'intSeasonID'} || 0,
            SelectLink       => "$Data->{'target'}?client=$client&amp;a=SN_DT&amp;seasonID=$dref->{intSeasonID}",
            strSeasonName    => $dref->{'strSeasonName'} || '',
            AddedBy          => $dref->{AddedBy} || '',
            dtAdded          => $dref->{dtAdded} || '',
            dtAdded_RAW      => $dref->{dtAdded_RAW} || '',
            intArchiveSeason => ($dref->{intArchiveSeason}==1)?"Yes":"No",
        };
    }

    my $title=$txt_Names;
    my $addlink=qq[<span class = "button-small generic-button"><a href="$Data->{'target'}?client=$client&amp;a=SN_DTA">Add</a></span>];

    if (($Data->{'SystemConfig'}{'Seasons_NationalOnly'} and $Data->{'clientValues'}{'authLevel'} < $Defs::LEVEL_NATIONAL)
    or ($Data->{'SystemConfig'}{'Seasons_CantAddSeasons'} and $Data->{'clientValues'}{'authLevel'} < $Defs::LEVEL_NATIONAL)) {
        $addlink = '';
    }

    my $modoptions=qq[<div class="changeoptions">$addlink</div>];
    $title=$modoptions.$title;

    my @headers = (
        {
          type => 'Selector',
          field => 'SelectLink',
        },
        {
          name =>   $txt_Name,
          field =>  'strSeasonName',
        },
        {
          name =>   $Data->{'lang'}->txt('Date Added'),
          field =>  'dtAdded',
        },
        {
          name =>   $Data->{'lang'}->txt('Added By'),
          field =>  'AddedBy',
        },
        {
          name =>   $Data->{'lang'}->txt('Archived'),
          field =>  'intArchiveSeason',
          width => 20,
        },
    );
    $resultHTML .= showGrid(
        Data => $Data,
        columns => \@headers,
        rowdata => \@rowdata,
        gridid => 'grid',
        height => 500,
    );

    if ($Data->{'clientValues'}{'assocID'} and $Data->{'clientValues'}{'assocID'} != $Defs::INVALID_ID) {
        $resultHTML = Seasons::viewDefaultAssocSeasons($Data) . "<br><br>$resultHTML";
    }

    return ($resultHTML,$title);

}

sub getNationalReportingPeriod {
    my ($db, $realmID, $subRealmID) = @_;
    $subRealmID ||= 0;
    my $st = qq[
        SELECT
            intNationalPeriodID
        FROM
            tblNationalPeriod
        WHERE
            intRealmID = ?
            AND (intSubRealmID = ? or intSubRealmID = 0)
            AND (dtStart < now() AND dtEnd > now())
    ];
    my $q = $db->prepare($st);
    $q->execute($realmID, $subRealmID);
    my $nationalPeriodID = $q->fetchrow_array();
    $nationalPeriodID ||= 0;
    return $nationalPeriodID;
}

1;
