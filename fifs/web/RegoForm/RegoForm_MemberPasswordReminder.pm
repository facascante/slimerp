#
# $Header: svn://svn/SWM/trunk/web/RegoForm/RegoForm_MemberPasswordReminder.pm 10500 2014-01-21 04:43:45Z fkhezri $
#

package RegoForm_MemberPasswordReminder;
require Exporter;
@ISA =  qw(Exporter);

@EXPORT = qw(
	HandlePasswordReminder
  sendPwdReminder
);
@EXPORT_OK = qw(
	HandlePasswordReminder
  sendPwdReminder
);

use lib "..","../..";
use Defs;
use Utils;
use TemplateEmail;
use RegoForm_Common;
use strict;
use Data::Dumper;

sub HandlePasswordReminder {
	my $self = shift;

	my $emailaddress = $self->{'RunParams'}{'emailaddress'} || '';
	my $natNum  = $self->{'RunParams'}{'natnumber'}  || '';
	my $surname = $self->{'RunParams'}{'surname'}  || '';

	my $resultHTML = '';
	if($emailaddress)	{
		my $countSent = sendPwdReminder($self->{'Data'}, $self->AssocID(), $emailaddress);
		if ($countSent) {
			$resultHTML = qq[
				<div class="OKmsg">Your password reminder has been sent</div><br>
				<p>Your password has been emailed to the address you provided.</p>
				<p>Please be patient, it may take a few minutes to receive it.  Remember to check your SPAM folder if you have not received it.</p>
				<p>Click your browser's back button to return to the login page</p>
			];
		}
		else    {
			$resultHTML = qq[<div class="warningmsg">No matches found for this email address<br/ > Please contact your organization  for username and password to process your registration online.</div>];
			print STDERR Dumper($self->{'Data'});
			$emailaddress='';
		}
	}

	if (
		$self->{'SystemConfig'}{'AllowStupidPwdReminder'}
		and ($natNum or $surname)
	) {
		$resultHTML = showPwdReminder($self->{'Data'}, $self->AssocID(), $natNum, $surname);
		if ($resultHTML) {
			$resultHTML = qq[
				<div class="sectionheader">Username and Password Reminder</div>
				<div class="OKmsg">Your Details have been found</div>
				$resultHTML
				<p>Click your browser's back button to return to the login page</p>
			];
    }
	}

	if (! $emailaddress and ! $natNum and ! $surname) {
		my $hiddenfields = $self->stringifyCarryField();
		my $body = qq[
<form method="POST" action="$self->{'Data'}{target}">
  <input type="hidden" name="a" value="PWD">
  <input type="hidden" name="rfp" value="vt">
	$hiddenfields
  <div class="sectionheader">Username or Password Reminder via Email</div>
  $resultHTML
  <p>
    Please enter your email address below<br>
    <b>Email Address</b>&nbsp;<input type="text" value="" name="emailaddress">
  </p>
  <p>
    When you click <b>Send me my Username and Password</b> you will receive
    an email with all usernames and passwords that are assigned to this emails
    address.<br>
    Please make sure that you have allowed incoming email from
    sportingpulse.com, and check your junk mail for your password reminder.
  </p>
  <input type="submit" name="submit" value="Send me my Username and Password">
</form>
		];

		if ($self->{'SystemConfig'}{'AllowStupidPwdReminder'})  {
		my $hiddenfields = $self->stringifyCarryField();
			$body .= qq[
<form method="POST" action="$self->{'Data'}{target}">
	<input type="hidden" name="a" value="PWD">
  <input type="hidden" name="rfp" value="vt">
	$hiddenfields
	<div class="sectionheader">Username or Password Reminder</div>
	<p>Please enter your National Number and Surname below</p>
	<table>
		<tr>
			<td><b>National Number</b></td>
			<td><input type="text" value="" name="natnumber"></td>
		</tr>
		<tr>
			<td><b>Surname</b></td>
			<td><input type="text" value="" name="surname"></td>
		</tr>
	<table>
	<p>
		When you click <b>Show me my Username and Password</b> you will be shown
		the username and password which match this National Number and Surname.
	</p>
	<input type="submit" name="submit" value="Show me my Username and Password">
</form>
			];
		}
		$resultHTML = $body;
	}

	return $resultHTML || '';
}

sub showPwdReminder {
	my ($Data, $assocID, $natNum, $surname) = @_;
	my $tNatNum= $natNum;
	my $tSurname= $surname;

	my $st = qq[
		SELECT    
			CONCAT(M.strFirstname, " " , M.strSurname) as MemberName,
			M.strEmail,
			ATH.strUsername,
			ATH.strPassword,
			ATH.intAuthID,
			M.intMemberID,
			MA.intAssocID
		FROM tblMember as M
			LEFT JOIN tblMember_Associations as MA ON ( 
				M.intMemberID = MA.intMemberID
				AND MA.intAssocID = ?
				AND MA.intRecStatus <> ? 
			)

			LEFT JOIN tblAuth as ATH ON (
				ATH.intID = M.intMemberID 
				AND ATH.intLevel = ?
			)

		WHERE 
			M.strNationalNum = ?
			AND M.strSurname = ?
			AND M.intStatus <> ?
			AND M.intRealmID = ?
		LIMIT 1
	];
	my $query = $Data->{'db'}->prepare($st);
	$query->execute(
		$assocID,
		$Defs::RECSTATUS_DELETED,
		$Defs::LEVEL_MEMBER,
		$natNum,
		$surname,
		$Defs::MEMBERSTATUS_DELETED,
		$Data->{'Realm'},
	);

	my $body = '';
	my $assocname= '';
	my $dref=$query->fetchrow_hashref();
	if ($dref->{intMemberID})       {
		if (! $dref->{intAuthID})       {
			my $strPassword = generateRandomPassword();

			my $st_ins = qq[
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
					$Defs::LEVEL_MEMBER,
					?, 
					SYSDATE() 
				)
			];

			my $q = $Data->{'db'}->prepare($st_ins);
			$q->execute(
				$dref->{intMemberID},
				$strPassword,
				$dref->{intMemberID},
			);

			$dref->{strUsername} = $dref->{intMemberID};
			$dref->{strPassword} = $strPassword;
		}
	  my $username = "1".$dref->{strUsername};
	  if ($dref->{intAssocID} == $assocID)    {
			$body = qq[
				<table>
					<tr><td><b>National Number</b></td><td>$tNatNum</td></tr>
					<tr><td><b>Surname</b></td><td>$tSurname</td></tr>
					<tr><td><b>Username</b></td><td><b>$username</b></td></tr>
					<tr><td><b>Password</b></td><td><b>$dref->{strPassword}</b></td></tr>
				</table>
			];
		}
	}

	$body = qq[Record not  found] if ! $body;

	return $body;
}

sub sendPwdReminder {
  my ($Data, $assocID, $email) = @_;
  my $tEmail = $email;

	return 0 if !$email;
	my $st = qq[
		SELECT
			CONCAT(M.strFirstname, " " , M.strSurname) as MemberName,
			M.strEmail,
			ATH.strUsername,
			ATH.strPassword,
			ATH.intAuthID,
			M.intMemberID,
			A.strName
		FROM
	tblMember as M

	INNER JOIN tblMember_Associations as MA
			ON (M.intMemberID = MA.intMemberID AND MA.intAssocID = ?)

	INNER JOIN tblAssoc as A ON (A.intAssocID = MA.intAssocID)

	LEFT JOIN tblAuth as ATH
			ON (ATH.intID = M.intMemberID and ATH.intLevel = ?)

	WHERE
			(M.strEmail = ? OR M.strP1Email = ? OR M.strP2Email = ?)
			AND M.intStatus <> ?
			AND MA.intRecStatus <> ?
			AND M.intDeRegister <> 1
	];
	my $query = $Data->{'db'}->prepare($st);

	$query->execute(
		$assocID,
		$Defs::LEVEL_MEMBER,
		$email,
		$email,
		$email,
		$Defs::MEMBERSTATUS_DELETED,
		$Defs::RECSTATUS_DELETED,
	);

	my $body = '';
	my $count=0;
	my $assocname= '';
	my @members = ();
	while (my $dref=$query->fetchrow_hashref()) {
			$assocname = $dref->{strName};
			$count++;
			if (! $dref->{intAuthID}) {
				my $strPassword = generateRandomPassword();
				my $st_ins= qq[
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
				$Data->{db}->do(
					$st_ins,
					undef,
					$dref->{intMemberID},
					$strPassword,
					$dref->{intMemberID},
				);
				$dref->{strUsername} = $dref->{intMemberID};
				$dref->{strPassword} = $strPassword;
		}
		my $username = "1".$dref->{strUsername};
		push @members, {
			MemberName => $dref->{'MemberName'} || '',
			Username => $username || '',
			Password => $dref->{'strPassword'} || '',
		};
	}
	my %TemplateData = (
		AssocName => $assocname,
		UserList => \@members,
		UsePassport => $Data->{'SystemConfig'}{'usePassportInRegos'},
	);
	my $emailresponse = 0;
	if($tEmail and @members)	{
		$emailresponse = sendTemplateEmail (
			$Data,
			'regoform/password_reminder.templ',
			\%TemplateData,
			$tEmail,
			"Password reminder for $assocname",
			"$Defs::null_email_name <$Defs::null_email>",
			$Data->{'SystemConfig'}{'regoFormPwd_CC'} || '',
			'',
		);
	}
	return $emailresponse || 0;
}

1;
