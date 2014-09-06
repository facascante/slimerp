#
# $Header: svn://svn/SWM/trunk/web/RegoForm/RegoForm_MemberFunctions.pm 11589 2014-05-16 05:01:52Z sliu $
#

package RegoForm_MemberFunctions;
require Exporter;
@ISA =  qw(Exporter);

@EXPORT = qw(
	updateRegoFormPhoto 
	setMemberTypes 
	rego_postMemberUpdate 
	getAgeGroupID
	rego_addTempMember
	rego_addRealMember
);
@EXPORT_OK = qw(
	updateRegoFormPhoto 
	setMemberTypes 
	rego_postMemberUpdate 
	getAgeGroupID
	rego_addTempMember
	rego_addRealMember
);

use lib '.', '..', '../..', "../comp", '../RegoForm', "../dashboard", "../RegoFormBuilder",'../PaymentSplit', "../user";
use RegoForm_Products;
use RegoForm_Common;
use RegoForm_Notifications;
use Reg_common;
use Person;
use TTTemplate;
use Payments;
use File::Copy;
use MemberFunctions;
use TemplateEmail;
use strict;
use Gateway_Common;
use Payments;
use Utils;
use DBUtils;

#use TempNodeStructureObj;
use Log;

sub setMemberTypes  {

	## Function is used to make sure the member types for re-registering members is handled correctly.
	## If re-registering then grabs LAST SEASONS {SystemConfig}{rego_checkLastSeasonTypes} in the tblMember_Seasons_XX table.

	my ($Data, $FieldDefinitions, $indivID, $assocID, $clubID, $type, $duplicateID) = @_;

	$type ||= 0;
	$duplicateID ||= -1;
	$clubID ||= 0;
	$assocID ||= 0;
	$indivID ||= 0;

	return if (! $Data->{'SystemConfig'}{'rego_setMemberTypes'});

    my $lastSeason = $Data->{'SystemConfig'}{'rego_checkLastSeasonTypes'} || 0;
	my $MStablename = "tblMember_Seasons_$Data->{'Realm'}";

    my $st = qq[
        SELECT
            intPlayerStatus    as intPlayer,
            intCoachStatus     as intCoach,
            intUmpireStatus    as intUmpire,
            intOfficialStatus  as intOfficial,
            intMiscStatus      as intMisc,
            intVolunteerStatus as intVolunteer
        FROM
            $MStablename as MS
            INNER JOIN tblAssoc as A ON (A.intAssocID = ?)
        WHERE
            MS.intMemberID IN (?, ?)
            AND MS.intAssocID = ?
            AND MS.intClubID = ?
            AND MS.intSeasonID IN ($lastSeason, A.intNewRegoSeasonID)
            AND MS.intMSRecStatus = 1
        ORDER BY
            MS.intSeasonID DESC
        LIMIT 1
    ];

	my $qry= $Data->{'db'}->prepare($st);
	$qry->execute($assocID, $indivID, $duplicateID, $assocID, $clubID );
	my ($player, $coach, $umpire, $official, $misc, $volunteer) =  $qry->fetchrow_array();

	if ($type == 1) {
		## SEASONS %types
        $FieldDefinitions->{'intPlayerStatus'}    = 1 if $player;
        $FieldDefinitions->{'intCoachStatus'}     = 1 if $coach;
        $FieldDefinitions->{'intUmpireStatus'}    = 1 if $umpire;
        $FieldDefinitions->{'intOfficialStatus'}  = 1 if $official;
        $FieldDefinitions->{'intMiscStatus'}      = 1 if $misc;
        $FieldDefinitions->{'intVolunteerStatus'} = 1 if $volunteer;
	}
	else    {
		$FieldDefinitions->{'fields'}{'intPlayer'}{'value'}    = $player    if $player;
		$FieldDefinitions->{'fields'}{'intCoach'}{'value'}     = $coach     if $coach;
		$FieldDefinitions->{'fields'}{'intUmpire'}{'value'}    = $umpire    if $umpire;
		$FieldDefinitions->{'fields'}{'intOfficial'}{'value'}  = $official  if $official;
		$FieldDefinitions->{'fields'}{'intMisc'}{'value'}      = $misc      if $misc;
		$FieldDefinitions->{'fields'}{'intVolunteer'}{'value'} = $volunteer if $volunteer;
	}
}

sub updateRegoFormPhoto {
    my ($Data, $assocID, $memberID, $tempfile_prefix) = @_;

    return '' if $tempfile_prefix =~ /[^a-zA-Z0-9]/;

    my $old_orig_file="$Defs::fs_upload_dir/temp/$tempfile_prefix.jpg";
    my $old_temp_file="$Defs::fs_upload_dir/temp/$tempfile_prefix".'_temp.jpg';

    my $orig_file = '';
    my $temp_file = '';

    {
      my $path = '';
      my $l=6 - length($memberID);
      my $pad_num=('0' x $l).$memberID;
      my (@nums)=$pad_num=~/(\d\d)/g;
      for my $i (0 .. $#nums-1) {
        $path.="$nums[$i]/";
        if( !-d "$Defs::fs_upload_dir/$path") { mkdir "$Defs::fs_upload_dir/$path",0755; }
      }
      $orig_file="$Defs::fs_upload_dir/$path$memberID.jpg";
      $temp_file="$Defs::fs_upload_dir/$path$memberID".'_temp.jpg';
    }

    if(-e $old_orig_file and -e $old_temp_file) {
      #Move file
      move($old_orig_file, $orig_file);
      move($old_temp_file, $temp_file);
      my $statement=qq[UPDATE tblMember SET intPhoto=1 WHERE intMemberID = ?];
      my $q = $Data->{'db'}->prepare($statement);
      $q->execute($memberID);
      $q->finish();
    }

    return '';
}

sub rego_postMemberUpdate  {
	my($id, $params, $action, $Data, $db, $indivID, $self, $isTemp) = @_;
    	my $usePassportFeature =$Data->{'SystemConfig'}{'usePassportInRegos'};
	my $printOnPaymentSummary =  $Data->{'SystemConfig'}{'printOnPaymentSummary'};

	my $cgi = new CGI;

	$id ||= $indivID ||= 0;
	$isTemp ||= 0;

	return (0, undef) unless $db;

	my $session = $self->{'Session'};

	my $txns_added = [];

    my $teamcode = $params->{'d_teamcode'} || $params->{'teamcode'} || 0;
	my $clubID   = $params->{'clubID'} || 0;
	if($clubID==0) {
	    my $st = qq[ SELECT strValue FROM tblAssocConfig WHERE intAssocID = ? AND strOption = 'RegoForm_AutoLoadMembersIntoClubID' ];
        my $q  = $db->prepare($st);
        $q->execute($self->AssocID());
		$clubID = $q->fetchrow_array() || 0;
	}
	my $assocID = $self->AssocID();

    my $useCompID = 0;
	$useCompID = $self->{'RunParams'}{'compID'} if exists $self->{'RunParams'}{'compID'};
    $Data->{'clientValues'}{'compID'} = $useCompID if $useCompID;

	my ($teamID, undef) = getTeamCodeID($Data, $teamcode, $self->AssocID());
	$teamID ||= $params->{'teamID'} || 0;
    if ($teamID) {
        $clubID = handleTeamAndGetClub($Data, $db, $params, $id, $teamID, $clubID, $assocID, $useCompID);
    }
	
	if($id) {
		if ($params->{'newCode'} and $params->{'newCode'} > 0)    {
			my $st = qq[
				UPDATE tblEOI
				SET intNewMemberID = ?
				WHERE intAssocID = ?
						AND intEOIID = ?
			];
			my $q = $db->prepare($st);
			$q->execute($id, $assocID, $params->{'newCode'} || '');
		}

		{
			my $st= qq[
				UPDATE tblMember
				SET intCreatedFrom = $Defs::CREATED_BY_REGOFORM
				WHERE intMemberID = ?
			];
			my $q = $db->prepare($st);
			$q->execute( $id);
		}

		if ( $assocID and $assocID != $Defs::INVALID_ID ) {
			my @cfieldnames = qw(
					strCustomStr1
					strCustomStr2
					strCustomStr3
					strCustomStr4
					strCustomStr5
					strCustomStr6
					strCustomStr7
					strCustomStr8
					strCustomStr9
					strCustomStr10
					strCustomStr11
					strCustomStr12
					strCustomStr13
					strCustomStr14
					strCustomStr15
					strCustomStr16
					strCustomStr17
					strCustomStr18
					strCustomStr19
					strCustomStr20
					strCustomStr21
					strCustomStr22
					strCustomStr23
					strCustomStr24
					strCustomStr25
					dblCustomDbl1
					dblCustomDbl2
					dblCustomDbl3
					dblCustomDbl4
					dblCustomDbl5
					dblCustomDbl6
					dblCustomDbl7
					dblCustomDbl8
					dblCustomDbl9
					dblCustomDbl10
					dblCustomDbl11
					dblCustomDbl12
					dblCustomDbl13
					dblCustomDbl14
					dblCustomDbl15
					dblCustomDbl16
					dblCustomDbl17
					dblCustomDbl18
					dblCustomDbl19
					dblCustomDbl20
					dtCustomDt1
					dtCustomDt2
					dtCustomDt3
					dtCustomDt4
					dtCustomDt5
					dtCustomDt6
					dtCustomDt7
					dtCustomDt8
					dtCustomDt9
					dtCustomDt10
					dtCustomDt11
					dtCustomDt12
					dtCustomDt13
					dtCustomDt14
					dtCustomDt15
					intCustomLU1
					intCustomLU2
					intCustomLU3
					intCustomLU4
					intCustomLU5
					intCustomLU6
					intCustomLU7
					intCustomLU8
					intCustomLU9
					intCustomLU10
					intCustomLU11
					intCustomLU12
					intCustomLU13
					intCustomLU14
					intCustomLU15
					intCustomLU16
					intCustomLU17
					intCustomLU18
					intCustomLU19
					intCustomLU20
					intCustomLU21
					intCustomLU22
					intCustomLU23
					intCustomLU24
					intCustomLU25
					intCustomBool1
					intCustomBool2
					intCustomBool3
					intCustomBool4
					intCustomBool5
					intCustomBool6
					intCustomBool7
					intMemberPackageID
					dtFirstRegistered
					dtLastRegistered
					curMemberFinBal
					strLoyaltyNumber
					intLifeMember
					intMailingList
			);

			my @cfieldvals = ();

			foreach my $f (@cfieldnames)  {
				push @cfieldvals, $params->{'d_'.$f};
			}

			my $cfield_nam = join(',',@cfieldnames) || q{};
			my $cfield_val = join(',', map { '?' } @cfieldvals)  || q{};

			if ($action eq 'add') {
				my $sth = exec_sql(qq[
					INSERT INTO tblMember_Associations (
						intMemberID,
						intAssocID,
						intRecStatus,
                        intFinancialActive,
						$cfield_nam
					)
					VALUES (
						?,
						?,
						$Defs::RECSTATUS_ACTIVE,
                        0,
						$cfield_val
					)
				], $id, $assocID, @cfieldvals);

			}
			if (!$isTemp) {#if it's not a temp then we need transactions
				$txns_added = insertRegoTransaction($Data, $id, $params, $assocID, $Defs::LEVEL_MEMBER, $session, $teamID, $clubID);
			}
		}

		Member::updateMemberNotes($db, $assocID, $id,$params);

		if ($params->{'mySportID'} and $id)  {
			insertMySportSWM_linkage($db, $params->{'mySportID'}, $Data->{'Realm'}, $assocID, $clubID, $teamID, $id, 0);
		}

		Member::getAutoMemberNum($Data, undef, $id, $assocID,) if $action eq 'add';

		Member::setupMemberTypes($Data, $id, $params, $assocID);

		if($action eq 'add' and $params->{'isDuplicate'})  {
			my $st = qq[
				UPDATE tblMember 
				SET intStatus=$Defs::MEMBERSTATUS_POSSIBLE_DUPLICATE
				WHERE intMemberID = ?
			];
			my $q = $db->prepare($st);
			$q->execute($id);
		}

		my $strPassword = generateRandomPassword();
		my $strUsername = "1$id";

		my $ageGroupID = getAgeGroupID($Data, $db, $assocID, $id);

		my $assocSeasons = Seasons::getDefaultAssocSeasons($Data);
		my %types=();

		$types{'intPlayerStatus'}    = $params->{'ynPlayer'}        if exists ($params->{'ynPlayer'});
		$types{'intCoachStatus'}     = $params->{'ynCoach'}         if exists ($params->{'ynCoach'});
		$types{'intUmpireStatus'}    = $params->{'ynMatchOfficial'} if exists ($params->{'ynMatchOfficial'});
		$types{'intOfficialStatus'}  = $params->{'ynOfficial'}      if exists ($params->{'ynOfficial'});
		$types{'intMiscStatus'}      = $params->{'ynMisc'}          if exists ($params->{'ynMisc'});
		$types{'intVolunteerStatus'} = $params->{'ynVolunteer'}     if exists ($params->{'ynVolunteer'});
		$types{'userselected'}       = 1;
		$types{'intMSRecStatus'}     = 1;

		$params->{'ID'}              = $id;
		$params->{'assocID_check'}   = $assocID;
		$params->{'assocID'}         = $assocID;

		setMemberTypes($Data, \%types, $id, $assocID, 0, 1, $params->{'isDuplicate'});
	      
		my $rereg = 0;
		if ($action eq 'add') {
			my $st = qq[
				INSERT INTO tblAuth (
					strUsername, 
					strPassword,    
					intLevel, 
					intID, 
					dtCreated
				)
				VALUES (
					?, 
					?, 
					1, 
					?, 
					SYSDATE()
				)
			];
			my $q = $db->prepare($st);
			$q->execute($id, $strPassword, $id);
		}
		else {
  			my $st = qq[ SELECT strPassword FROM tblAuth
                WHERE strUsername = ?
                AND intLevel = ?
                AND intID = ? 
            ];
            my $q  = $db->prepare($st);
            $q->execute($id, 1, $id);
		    my $strPasswordTemp = $strPassword;
            $strPassword = $q->fetchrow_array();
			$rereg = 1;
			if (!$strPassword) {
			    my $st = qq[
                    INSERT INTO tblAuth (
                        strUsername,
                        strPassword,
                        intLevel,
                        intID,
                        dtCreated
                    )
                    VALUES (
                        ?,
                        ?,
                        1,
                        ?,
                        SYSDATE()
                    )
               ];
                    my $q = $db->prepare($st);
                    $q->execute($id, $strPasswordTemp, $id,);
            }
		}
        
        my $seasonID = $params->{'season'} || $assocSeasons->{'newRegoSeasonID'};
		Seasons::insertMemberSeasonRecord($Data, $id, $seasonID, $assocID, 0, $ageGroupID, \%types, undef, $rereg);
      
		if ($teamID) {
			$clubID = handleTeamAndGetClub($Data, $db, $params, $id, $teamID, $clubID, $assocID, $useCompID);
		}

		if ($clubID) {
			$params->{'clubID_check'} = $clubID if ($clubID and $clubID > 0);
			$Data->{'clientValues'}{'clubID'} = $clubID if ($clubID and $clubID > 0);
			Member::preMemberAdd($params, '', $Data, $Data->{'db'});
			setMemberTypes($Data, \%types, $id, $assocID, $clubID, 1, $params->{'isDuplicate'});
			Seasons::insertMemberSeasonRecord($Data, $id, $assocSeasons->{'newRegoSeasonID'}, $assocID, $clubID, $ageGroupID, \%types, undef, $rereg);
			my $st = qq[
					SELECT COUNT(*) as MCount
					FROM   tblMember_Clubs
					WHERE  intMemberID = ?
					AND    intClubID = ?
					AND    intStatus = $Defs::RECSTATUS_ACTIVE
			];
			my $q = $db->prepare($st);
			$q->execute($id, $clubID);
			my ($MCcount) = $q->fetchrow_array();
			$MCcount ||= 0;

			if(!$MCcount) {
				my $st = qq[
					INSERT IGNORE INTO  tblMember_Clubs (
						intMemberID,
						intClubID,
						intStatus,
						tTimeStamp
					)
					VALUES (
						?,
						?,
						$Defs::RECSTATUS_ACTIVE,
						NOW()
					)
				];
				my $q = $db->prepare($st);
				$q->execute($id, $clubID);
			}
		}
		
		if ($params->{'programID'}){
		    require ProgramObj;
		    
		    # Get program Obj
		    my $program_obj = ProgramObj->new(
                'ID' => $params->{'programID'},
                'db' => $db,
            );
		    
		    # Add memeber
		    $program_obj->enrol_member({
		        'member_id' => $id,
		        'new_to_program' => $params->{'program_new'} || 0,
		    });
		}
		
        #do update for optins and t&cs.
        checkForTermsAndConditions($id, $params, $Data);

		$Data->{'clientValues'}{'memberID'} = $id;

		my $checkOut = '';
		my $sID = $session->id();
		if (!$isTemp) {

		$session->addToSession(
				db           => $Data->{'db'},
				MemberID     => $id,
				FormID       => $params->{'fID'} || 0,
				Transactions => $txns_added,
				Status       => 1,
		);

		if ($session->id() and $session->isComplete())	{
			my %Transactions=();
			my $sessionTrans = $session->getTransactions();
			my $st = qq[
				SELECT intProductType
				FROM
					tblTransactions as T
					INNER JOIN tblProducts as P ON (P.intProductID=T.intProductID)
				WHERE
					T.intTransactionID=?
			];

			my $q = $db->prepare($st);

			for my $i (@{$sessionTrans})  {
				my $t = $i->[1];
				$q->execute($t);
				my ($prodType) = $q->fetchrow_array();
				next if $prodType == 2;
				next if (exists $Transactions{$t});
				$Transactions{$t}=1;
				next if $i->[0]== $id;
				push @$txns_added, $t;
			}
		}

		if($txns_added and  @{$txns_added} ) {
			$checkOut = Payments::checkoutConfirm($Data, $Defs::PAYMENT_ONLINENAB, $txns_added,1) || q{};
		}
		
		
		}
		if( $params->{'d_PhotoUpload'} )  {
			updateRegoFormPhoto($Data, $assocID, $id, $params->{'d_PhotoUpload'}); #MemberID
		}

		my $successmessage = $self->getText('strSuccessText',1);
		my $teamname = $self->{'RunDetails'}{'TeamDetails'}{'strName'} || '';
		my $clubname = $self->{'RunDetails'}{'ClubDetails'}{'strName'} || '';
		my $assocname = $self->{'RunDetails'}{'AssocDetails'}{'strName'} || '';

        my $reg_target = $Data->{'target'} || 'regoform.cgi';
		my $formURL = qq[$Defs::base_url/$reg_target?aID=$assocID&amp;fID=$params->{'fID'}];

		my $multiperson = ($self->getValue('intAllowMultipleAdult') or $self->getValue('intAllowMultipleChild')) ? 1 : 0;

		my $multi_person_details = undef;
		$multi_person_details = $session->MemberNames($db,1);# if $multiperon;
		my $sessionKey = $session->id();
		my $target = qq[$reg_target?session=$sessionKey];
		
		my $form_type;
		if($self->FormType() == $Defs::REGOFORM_TYPE_MEMBER_ASSOC) {
			$form_type = 'ASSOC';
		}
		elsif($self->FormType() == $Defs::REGOFORM_TYPE_MEMBER_TEAM) {
			$form_type = 'TEAM';
		}
		elsif($self->FormType() == $Defs::REGOFORM_TYPE_MEMBER_CLUB) {
			$form_type = 'CLUB';
		}
		elsif($self->FormType() == $Defs::REGOFORM_TYPE_MEMBER_PROGRAM) {
            $form_type = 'PROGRAM';
        }
        my %MemberRegoData = (
            PrintButton    =>$printOnPaymentSummary,
			Username => $strUsername,
			Password => $strPassword,
			MultiPersonDetails => $multi_person_details,
			CheckOut => $checkOut,
			Success => $successmessage,
			FormParams => $params,
			MemberID => $id,
			ClubID => $clubID,
			TeamID => $teamID,
			AssocID => $assocID,
			TeamName => $teamname,
			ClubName => $clubname,
			CompName => '',
			AssocName => $assocname,
			FormURL => $formURL,
			FormID => $params->{'fID'} || 0,
			AllowMultiPerson => $multiperson || 0,
			Target => $target,
			ReRegistration => $rereg,
			CompulsoryPayment => $self->getValue('intPaymentCompulsory') || 0,
			usePassportFeature => $usePassportFeature,
            regoForm_HIDE_PaymentText => $Data->{'SystemConfig'}{'regoForm_HIDE_PaymentText'}, 
			
			formType => $form_type,
			sessionKey => $sessionKey,
			isTemp => $isTemp,
		);
		my $templatefile = '';
=c
		if($self->FormType() == $Defs::REGOFORM_TYPE_MEMBER_ASSOC) {
	        $templatefile = 'regoform/member-to-assoc/reg-confirmation.templ';
		}
		elsif($self->FormType() == $Defs::REGOFORM_TYPE_MEMBER_TEAM) {
		    $templatefile = 'regoform/member-to-team/reg-confirmation.templ';
		}
		elsif($self->FormType() == $Defs::REGOFORM_TYPE_MEMBER_CLUB) {
		    $templatefile = 'regoform/member-to-club/reg-confirmation.templ';
		}
=cut
		if($session->isComplete()  and !$checkOut){
			my $nocookie = $session->resetSessionCookie($db);
			push @{$self->{'CookiesToWrite'}}, $nocookie;
		}
		$templatefile = 'regoform/member-to-club/reg-confirmation.templ';
		my $auth_body = runTemplate($Data, \%MemberRegoData, $templatefile,);
        if ($Data->{'SystemConfig'}{'regoForm_sendAuthEmail'}) {
          ### SEND EMAIL TO MEMBER
            my $sentemail = sendAuthEmail($self, $Data, $assocID, $id, $strUsername, $strPassword, $teamID, $rereg);
        }
        if($usePassportFeature){
	    	if(!$self->{'Passport'} or ($self->{'RunParams'}{'passportaccount'} and $self->{'RunParams'}{'passportaccount'}  eq 'new'))	{
	    		#Send passport invite email
	    		my $email = $params->{'d_strEmail'} || '';

	    		my $linkurl = "$Defs::base_url/linkmember.cgi?mk=$id".'f'.getRegoPassword($id);

	    		my ($sentemail, $msg) = sendTemplateEmail(
	    			$Data,
	    			'regoform/passportinvite.templ',
	    			{
	    				PassportLinkURL => $linkurl,
	    				UsePassport => $usePassportFeature,
	    			},
	    			$email,
	    			'Manage your registration through SP Passport',
	    			$Defs::admin_email,
	    			'',
	    			'',
	    		);
	    	}
	    	elsif($self->{'Passport'})	{
	    		my $passportID = $self->{'Passport'}->id();
	    		my $st = qq[
	    			INSERT IGNORE INTO tblPassportMember 
	    				(intPassportID, intMemberID)
	    			VALUES 
                        (?,?)
	    		];	
	    		my $q = $Data->{'db'}->prepare($st);
	    		$q->execute($passportID, $id);
	    	}
        }
		return (1, $auth_body);
	}
	return (1, q{});
}

#this will apply to both linked and unlinked forms.
sub checkForTermsAndConditions {
    my ($id, $params, $Data) = @_;

    my $dbh = $Data->{'db'};

    my $checkField= 'tcagree_';

    foreach my $param (keys %$params) {
        if ($param =~ /$checkField/) {
            #no need to check for level as T&Cs are compulsory so will only ever be set on.
            my $tcLevel = $param;
            $tcLevel =~ s/^$checkField//;

            my $termsMemberObj = TermsMemberObj->new(db=>$dbh);
            my $dbfields    = 'dbfields';
            my $ondupfields = 'ondupfields';

            $termsMemberObj->{$dbfields}    = ();
            $termsMemberObj->{$ondupfields} = ();

            $termsMemberObj->{$dbfields}{'intLevel'}    = $tcLevel;
            $termsMemberObj->{$dbfields}{'intFormID'}   = $params->{'formID'};
            $termsMemberObj->{$dbfields}{'intMemberID'} = $id;

            $termsMemberObj->{$ondupfields} = ['intFormID'];

            $termsMemberObj->save();
        }
    }
    return 1;
}

sub getTeamCodeID {

  my ($Data, $teamcode, $assocID) = @_;

	$teamcode =~ /^\d(\d+)$/;
	$teamcode = $1 || 0;

	my $st = qq[
		SELECT A.intID, T.strName, T.intTeamID
		FROM tblAuth as A
			INNER JOIN tblTeam as T ON (T.intTeamID = A.intID)
		WHERE A.intID = ?
			AND A.intLevel = ?
			AND A.intAssocID = ?
		LIMIT 1
	];
	my $query = $Data->{'db'}->prepare($st);
	$query->execute($teamcode, $Defs::LEVEL_TEAM, $assocID);
	my $tref = $query->fetchrow_hashref() || undef;

	my $teamID = $tref->{intID} || 0;

	return ($teamID, $tref);
}


sub handleTeamAndGetClub {
	my ($Data, $db, $params, $id, $teamID, $clubID, $assocID, $useCompID) = @_;

	$params->{'teamID_check'} = $teamID if ($teamID > 0);

	my $st_teamclub = qq[
		SELECT DISTINCT
			T.intClubID,
			intMemberClubID
		FROM
				tblTeam AS T
		LEFT JOIN
			tblMember_Clubs AS MC
			ON (
				MC.intClubID = T.intClubID
				AND MC.intStatus = $Defs::RECSTATUS_ACTIVE
				AND MC.intMemberID = ?
				AND MC.intPermit=0
			)
		WHERE
				T.intTeamID = ?
		LIMIT 1
	];

	my $qry_teamclub = $db->prepare($st_teamclub);
	$qry_teamclub->execute( $id, $teamID );
	my $hasMC=0;
	($clubID, $hasMC) = $qry_teamclub->fetchrow_array();

	$clubID ||= 0;
	$hasMC  ||= 0;

	my $st = qq[
		SELECT 
			CT.intCompID,
			AC.intNewSeasonID
		FROM   tblComp_Teams as CT
			INNER JOIN tblAssoc_Comp as AC ON (
				AC.intCompID=CT.intCompID
			)
			INNER JOIN tblAssoc as A ON (A.intAssocID=AC.intAssocID)
		WHERE  CT.intTeamID = ?
		AND    CT.intRecStatus=1
		AND    (
			AC.dtStart>=NOW() 
			OR AC.dtStart='0000-00-00' 
			OR AC.intNewSeasonID>=A.intNewRegoSeasonID
		)
		AND AC.intRecStatus=1
	];
	my $query = $Data->{'db'}->prepare($st);
	$query->execute( $teamID );

	my $comps_count = 0;
	my %types=();

	$types{'intPlayerStatus'}    = $params->{'ynPlayer'}        if exists ($params->{'ynPlayer'});
	$types{'intCoachStatus'}     = $params->{'ynCoach'}         if exists ($params->{'ynCoach'});
	$types{'intUmpireStatus'}    = $params->{'ynMatchOfficial'} if exists ($params->{'ynMatchOfficial'});
	$types{'intOfficialStatus'}  = $params->{'ynOfficial'}      if exists ($params->{'ynOfficial'});
	$types{'intMiscStatus'}      = $params->{'ynMisc'}          if exists ($params->{'ynMisc'});
	$types{'intVolunteerStatus'} = $params->{'ynVolunteer'}     if exists ($params->{'ynVolunteer'});
	$types{'userselected'}       = 1;
	$types{'intMSRecStatus'}     = 1;

	$params->{'ID'} = $id;
	$params->{'assocID_check'} = $assocID;
	$params->{'assocID'} = $assocID;
	setMemberTypes($Data, \%types, $id, $assocID, 0, 1, $params->{'isDuplicate'});
	my $ageGroupID = getAgeGroupID($Data, $db, $assocID, $id);

	my $st_insert = qq[
		INSERT IGNORE INTO tblMember_Teams (
			intMemberID,
			intTeamID,
			tTimeStamp,
			intStatus,
			intCompID
		)
		VALUES (
			?,
			?,
			NOW(),
			1,
			?
		)
	];
	my $q_i = $db->prepare($st_insert);

    # cater for situation where member may have been been in the team and then been deleted before rejoining
    my $st_update = qq[
        UPDATE tblMember_Teams
        SET intStatus=?
        WHERE intMemberID=? AND intTeamID=? AND intCompID=? AND intStatus=?
        LIMIT 1
    ];
    my $q_u = $db->prepare($st_update);

	while (my $dref = $query->fetchrow_hashref()) {
        next if $useCompID and $dref->{'intCompID'} != $useCompID;
		$comps_count++;
		$q_i->execute($id, $teamID, $dref->{'intCompID'} || 0);
        $q_u->execute(1, $id, $teamID, $dref->{'intCompID'} || 0, -1);

		my $seasonID = $dref->{'intNewSeasonID'} || 0;
		if ($seasonID)  {
			Seasons::insertMemberSeasonRecord($Data, $id, $seasonID, $assocID, 0, $ageGroupID, \%types);
			Seasons::insertMemberSeasonRecord($Data, $id, $seasonID, $assocID, $clubID, $ageGroupID, \%types) if ($clubID);
		}
	}

	if(!$comps_count)	{
		$q_i->execute($id, $teamID, 0);
        $q_u->execute(1, $id, $teamID, 0, -1);
	}

	$st = qq[
		SELECT DISTINCT
			T.intClubID,
			intMemberClubID
		FROM
			tblTeam AS T
		LEFT JOIN
			tblMember_Clubs AS MC
			ON (
				MC.intClubID = T.intClubID
				AND MC.intStatus = $Defs::RECSTATUS_ACTIVE
				AND MC.intMemberID = ?
				AND MC.intPermit=0
			)
		WHERE
				T.intTeamID = ?
		LIMIT 1
	];

	$qry_teamclub = $db->prepare($st);
	$qry_teamclub->execute( $id, $teamID );
	$hasMC = 0;
	($clubID, $hasMC) = $qry_teamclub->fetchrow_array();

	$clubID ||= 0;
	$hasMC  ||= 0;

	if ($clubID and not $hasMC) {

		my $st_ct = qq[
			INSERT INTO tblMember_Clubs (
				intMemberID,
				intClubID,
				intStatus
			)
			VALUES (
				?,
				?,
				$Defs::RECSTATUS_ACTIVE
			)
		];
		my $q_ct = $db->prepare($st_ct);
		$q_ct->execute(
			$id,
			$clubID,
		);
	}

	return $clubID
}

sub rego_addTempMember  {
	my($params, $action, $Data, $db, $indivID, $self) = @_;
	my $json = $params->{'json'};
	# step 1: insert a temp row for each member
	# step 2: check to see if it's time to display the payment page 
	# step 3: display payment(extract from curent post update function ) and wait for the payment gatewy success respond
	# step 4: if all is good run rego_getTempMember function to get data and add member in real db
	#         if not(payment is not done, abandoned form, etc.)  clean up periodically every week(??) 
	my $session = $self->{'Session'};
	my $formID = $self->{'ID'};
	my $sessionKey = $session->id();
	my $teamID = $self->{'RunDetails'}{'TeamID'} || 0;
	my $clubID = $self->{'RunDetails'}{'ClubID'} || 0;
    if($clubID) {
            $Data->{'clientValues'}{'clubID'} = $clubID if ($clubID and $clubID > 0);
    }
	my $assocID = $self->AssocID();
	my $rereg;
	$rereg = $indivID ? 1:0;
	my $txns_added = [];
    
	my $number = $session->getSessionSequenceNumber(); # get the num from session
	my $st = qq[
        INSERT INTO tblTempMember (
			strSessionKey,
			intRealID,
			strJson,
			intFormID,
			intAssocID,
			intClubID,
			intTeamID,
			intLevel,
			intNum
        )
        VALUES (
            ?,
            ?,
            ?,
            ?,
            ?,
            ?,
            ?,
			?,
            ?
        )
    ];
	my $q = $db->prepare($st);

	$q->execute($sessionKey, $indivID, $json, $formID, $assocID, $clubID, $teamID, $Defs::LEVEL_MEMBER, $number); 

    my $intTempID = $q->{mysql_insertid};

    $txns_added = insertRegoTransaction($Data, $intTempID, $params, $assocID, $Defs::LEVEL_MEMBER, $session, $teamID, $clubID, 1);

    if($txns_added and  @{$txns_added} ) {
		my $txnlist = $txns_added ? join (',',@{$txns_added}) : '';
		my $update_st = qq[UPDATE tblTempMember SET strTransactions = ?  WHERE intTempMemberID = ?];
		my $update_q = $db->prepare($update_st);
		$update_q->execute($txnlist, $intTempID);
    }
    $session->addToSession(
		db => $db,
		MemberID => $intTempID,
		FormID => $formID || 0,
		Transactions => $txns_added,
		Status => 1,
		isTemp => 1,
    );

    if ($session->id() and $session->isComplete())  {
		my %Transactions=();
		my $sessionTrans = $session->getTransactions();
		my $st =qq[
			SELECT
				intProductType
			FROM
				tblTransactions as T
			INNER JOIN tblProducts as P
				ON (P.intProductID=T.intProductID)
			WHERE
				T.intTransactionID=?
		];
		my $q1 = $db->prepare($st);
    
	    for my $i (@{$sessionTrans})  {
		   my $t = $i->[1];
		   $q1->execute($t);
		   my ($prodType) = $q1->fetchrow_array();
		   next if $prodType == 2;
		   next if (exists $Transactions{$t});
		   $Transactions{$t}=1;
		   next if $i->[0] == $intTempID;
		   next if $i->[2] == $intTempID;
		   push @$txns_added, $t;
	    }
	}
    my $checkOut ='';
	$Data->{'sessionKey'} = $session->id();
    if($txns_added and  @{$txns_added} ) {
	    $checkOut = Payments::checkoutConfirm($Data, $Defs::PAYMENT_ONLINENAB, $txns_added,1) || q{};
    }
=c
        if( $params->{'d_PhotoUpload'} )  {
		updateRegoFormPhoto(
			$Data,
			$assocID,
			$id, #MemberID
			$params->{'d_PhotoUpload'},
		);
        }
=cut
    my $usePassportFeature =  $self->{'Data'}{'SystemConfig'}{'usePassportInRegos'};
    my $successmessage = $self->getText('strSuccessText',1);
    my $teamname = $self->{'RunDetails'}{'TeamDetails'}{'strName'} || '';
    my $clubname = $self->{'RunDetails'}{'ClubDetails'}{'strName'} || '';
    my $assocname = $self->{'RunDetails'}{'AssocDetails'}{'strName'} || '';
    my $target = $Data->{'target'} || 'regoform.cgi';
    my $formURL = qq[$Defs::base_url/$target?aID=$assocID&amp;fID=$formID];

    my $multiperson = ($self->getValue('intAllowMultipleAdult') or $self->getValue('intAllowMultipleChild')) ? 1 : 0;

	my $multi_person_details = undef;
	$multi_person_details = $session->loadTempData($db);# if $multiperon;
	my $form_type;
	if($self->FormType() == $Defs::REGOFORM_TYPE_MEMBER_ASSOC) {
        $form_type = 'ASSOC';
    }
    elsif($self->FormType() == $Defs::REGOFORM_TYPE_MEMBER_TEAM) {
        $form_type = 'TEAM';
    }
    elsif($self->FormType() == $Defs::REGOFORM_TYPE_MEMBER_CLUB) {
        $form_type = 'CLUB';
    }
    elsif($self->FormType() == $Defs::REGOFORM_TYPE_MEMBER_PROGRAM) {
        $form_type = 'PROGRAM';
    }
    my %MemberRegoData = (
        CheckOut => $checkOut,
        ClubID => $clubID,
        TeamID => $teamID,
        AssocID => $assocID,
        TeamName => $teamname,
        ClubName => $clubname,
        CompName => '',
        AssocName => $assocname,
        FormURL => $formURL,
        FormID => $formID || 0,
        Target => $target,
		ReRegistration => $rereg,
		MultiPersonDetails=>$multi_person_details,
        CompulsoryPayment => $self->getValue('intPaymentCompulsory') || 0,
        usePassportFeature => $usePassportFeature,
		formType => $form_type,
		isTemp => 1,
    );
    my $templatefile = '';
	$templatefile = 'regoform/member-to-club/reg-confirmation.templ';
	my $intRealID;
	my $auth_body;
    if($checkOut eq '' and $session->isComplete()){
	    #my $action = 'edit';
	    my $st_update_temp = qq[
	    		UPDATE
	    		    tblTempMember
	    		SET
	    		     intRealID = ?,
	    		     intStatus = 1
	    		WHERE
	    		    intTempMemberID =?
                            ];
	    	    
	    my $st = qq[ 
            SELECT
	    		intTempMemberID,
	    		intFormID,
	    		strSessionKey
	    	FROM
	    		tblTempMember 
	    	WHERE
	    		strSessionKey =?
	    	AND intStatus = 0];
	    my $qry = $db->prepare($st) or query_error($st);
	    $qry->execute($sessionKey);
	    my $i =1;
	    while (my $dref = $qry->fetchrow_hashref()) {
	    	$i++;
	    	$intTempID = $dref->{'intTempMemberID'};
	    	
	    	($intRealID , $auth_body) =  rego_addRealMember($Data,$db,$intTempID,$session, $self,$action);
	    	
	    	my $update_qry = $db->prepare($st_update_temp) or query_error($st_update_temp);
	    	$update_qry->execute($intRealID,$intTempID);
	    }
    }
    else {
	    $auth_body = runTemplate($Data, \%MemberRegoData, $templatefile,);
	}
    
    return ( 1, $auth_body );
	
}

sub rego_addRealMember  {
	my($Data, $db, $intTempID, $sessionKey, $formObj, $action)= @_;
=c
	step 1: select from tempDB usig session key
	step 2: deserilize json
	step 3: try to retrieve the member object and add member (do you need to run preadd??)
	step 4: run postAdd/postUpdate Function (remember youremoved the product and paymet from the post function!!)
	step 5: finaliaz the process, clean up sessions, show thank youz 
=cut  
	my $where = $intTempID ? qq[ intTempMemberID =$intTempID] : qq[ strSessionKey = '$sessionKey' ];
	my $st= qq[ 
        SELECT 
	        intRealID,
		    strJson
	   FROM
			tblTempMember
	    WHERE 
			$where
	];
	my $q = $db->prepare($st);
	$q->execute;
	my ($intRealID, $json_string) = $q->fetchrow_array();
	my $j = new JSON;
	my $deserial = JSON::from_json($json_string); 
	my @params = $deserial->{'afteraddParams'};
    $formObj->{'RunParams'} =$params[0];
    if(
        $formObj->{'RunParams'}{'clubID'}
        or $formObj->{'RunParams'}{'teamID'}
    )   {
        $formObj->{'RunDetails'}{'ClubID'} =  $formObj->{'RunParams'}{'clubID'} || 0;
        $formObj->{'RunDetails'}{'TeamID'} =  $formObj->{'RunParams'}{'teamID'} || 0;
    }
    $formObj->loadOrgDetails();
    
    my $client = $Data->{'client'};
    if($client){
        my %clientValues = getClient($client);
        $Data->{'clientValues'} = \%clientValues;
    }
	if(!$intRealID) {
		$intRealID =  insert_real_member($Data,$db,$deserial);
	}
    else {
		$action = 'edit';
        update_real_member($Data,$db,$deserial,$intRealID);
	}
	
	$action ||= 'add';
	my $session = $formObj->{'Session'};
	if (!$session) {
		#return (0,q{});
		$session = new RegoFormSession(
			key => $sessionKey,
			db => $db,
			FormID => $formObj->ID(),
		);	
	} 
	
	$session->setRealMemberID($db, $intTempID, $intRealID);
	$formObj->{'Session'} = $session;
	my $isTemp = 1;
	my ($sign , $auth_body) = rego_postMemberUpdate($intRealID,@params,$action,  $Data,$db ,$intRealID,$formObj,$isTemp);
    
	#update Session table and add intMemberID
	return ($intRealID, $auth_body);

}
sub update_real_member {
    my ($Data,$db, $input_array,$intRealID) = @_;
    my ( @values, @values_placeholder ) = ();
    while (my ($key, $value) = each(%$input_array)) {
        next if $key eq 'afteraddParams';
        push @values_placeholder, "$key = ?";

        push @values, $value;
    }
     my $placeholders = join( ", ", @values_placeholder );

    my $sql = qq[
            UPDATE tblMember, tblMember_Associations
            SET --VAL--
            WHERE tblMember.intMemberID=$intRealID
                AND tblMember_Associations.intMemberID=$intRealID
                AND tblMember_Associations.intAssocID=$Data->{'clientValues'}{'assocID'}
            ];
    $sql =~ s/--VAL--/$placeholders/;
    my $query = exec_sql( $sql, @values );
    if ($DBI::err) {
                return ( 0,
                       '<div class="warningmsg"></div>' );
            }
     else {
        #AUDIT  SHOUL HAPPEN HERE##
=c
                if ( $fields_ref->{'options'}{'auditFunction'} ) {
                    my @params = ();
                    push @params,
                      @{ $fields_ref->{'options'}{'auditEditParams'} }
                      if $fields_ref->{'options'}{'auditEditParams'};
                    if (   $fields_ref->{'options'}{'auditEditParamsAddFields'}
                        && %fields_changes )
                    {
                        push @params, \%fields_changes;
                    }
                    $fields_ref->{'options'}{'auditFunction'}->(@params);
                }
                return ( 1,
                    $fields_ref->{'options'}{'updateOKtext'}
                      || '<div class="OKmsg">'
                      . langlookup( $fields_ref, 'Record updated successfully' )
                      . $return_html
                      . '</div>' );
=cut  
          }


    return $intRealID ;
}

sub insert_real_member {
	my ($Data,$db, $input_array) = @_;
	
	my $valuelist ='';
	my $fieldlist =''; 
	my $intRealID;
    
    
	while (my ($key, $value) = each(%$input_array)) {
	    next if $key eq 'afteraddParams';
		$valuelist.=',' if $valuelist;
		$fieldlist.=',' if $fieldlist;
		$fieldlist.= $key;
		$valuelist.=$db->quote($value);
	}
	
	my $st = qq[
		INSERT INTO tblMember 
            (intRealmID, dtCreatedOnline, --FIELDS--)
		VALUES 
            ($Data->{'Realm'}, CURRENT_DATE(), --VAL--)
    ];
	$st=~s/--VAL--/$valuelist/;
	$st=~s/--FIELDS--/$fieldlist/;
	my $query = $db->prepare($st);
	$query->execute();
	$intRealID = $query->{mysql_insertid};

	return $intRealID ;
}
1;
