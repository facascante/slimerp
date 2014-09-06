#!/usr/bin/perl -w

#
# $Header: svn://svn/SWM/trunk/automatic/product_renewals.pl 8250 2013-04-08 08:24:36Z rlee $
#

use DBI;
use lib "..";
use lib "../web";
$ENV{PATH}="/bin";
use Defs;
use Utils;
use strict;
use TTTemplate;
use TemplateEmail;
use Lang;

main();

sub main    {

    my %Data = ();
    my $db=connectDB();
    $Data{'db'} = $db;
    my $lang = Lang->get_handle() || die "Can't get a language handle!";
    $Data{'lang'} = $lang;
		my $max_renewal_days = 60;

    my $statement = qq[
        SELECT 
					T.intProductID,
					T.intRealmID,
					T.intAssocID,
					T.intID,
					T.intTableType,
					T.dtEnd,
					DATE_FORMAT(T.dtEnd,"%b %e") AS dtEndFMT,
					P.strName,			
					PR.strRenewText1,
					PR.strRenewText2,
					PR.strRenewText3,
					PR.strRenewText4,
					PR.strRenewText5,
					PR.intRenewDays1,
					PR.intRenewDays2,
					PR.intRenewDays3,
					PR.intRenewDays4,
					PR.intRenewDays5,
					PR.intRenewProductID,
					PR.intRenewRegoFormID,
					DATEDIFF(T.dtEnd, SYSDATE()) AS DaysRemaining
					

        FROM tblTransactions AS T
					INNER JOIN tblProducts AS P
						ON T.intProductID = P.intProductID
					LEFT JOIN tblProductRenew AS PR
						ON PR.intProductID = P.intProductID
				WHERE 
					T.dtEnd >= DATE_SUB(SYSDATE(), INTERVAL $max_renewal_days DAY)
					AND T.dtEnd <= DATE_ADD(SYSDATE(), INTERVAL $max_renewal_days DAY)
					AND T.intRenewed = 0
    ];
    my $query = $db -> prepare($statement);
    $query->execute;
		my %IDs = ();
		my @renewal_emails = ();
    while (my $dref = $query -> fetchrow_hashref()) {
			for my $cnt ( 1 .. 5)	{
				my $text = $dref->{'strRenewText'. $cnt} || '';
				my $days = $dref->{'intRenewDays'. $cnt} || 0;

				if(
					$text 
					and $days == $dref->{'DaysRemaining'}
				)	{
					push @renewal_emails, [$cnt, $dref];
					$IDs{$dref->{'intTableType'}}{$dref->{'intID'}} = 1;
				}
			}
		}

		#lookup email addresses
		my %addresses = ();
		my $memberID_str = join(',',keys %{$IDs{$Defs::LEVEL_MEMBER}});
		if($memberID_str)	{
			my $st = qq[
				SELECT 
					intMemberID, 
					strEmail
				FROM tblMember
				WHERE 
					intMemberID IN ($memberID_str)
			];
			my $query = $db -> prepare($st);
			$query->execute();
			while (my $dref = $query->fetchrow_hashref()) {
				$addresses{$Defs::LEVEL_MEMBER}{$dref->{'intMemberID'}} = $dref->{'strEmail'} || next;	
			}
		}
		my $teamID_str = join(',',keys %{$IDs{$Defs::LEVEL_TEAM}});
		if($teamID_str)	{
			my $st = qq[
				SELECT 
					intTeamID, 
					strEmail
				FROM tblTeam
				WHERE 
					intTeamID IN ($teamID_str)
			];
			my $query = $db -> prepare($st);
			$query->execute();
			while (my $dref = $query -> fetchrow_hashref()) {
				$addresses{$Defs::LEVEL_TEAM}{$dref->{'intTeamID'}} = $dref->{'strEmail'} || next;	
			}
		}		

		for my $dat (@renewal_emails)	{
			my $cnt = $dat->[0] || next;
			my $dref = $dat->[1] || next;
			my $address = $addresses{$dref->{'intTableType'}}{$dref->{'intID'}} || '';
			next if !$address;
			setupRenewal(
				\%Data,
				$db,
				$dref,
				$cnt,
				$address,
			);
		}
    disconnectDB($db);
}


sub setupRenewal	{
	my(
		$Data, 
		$db, 
		$dref,
		$cnt,
		$address,
	) = @_;

	return if !$address;
	return if !$dref;
	return if !$db;

	my $text = $dref->{'strRenewText'.$cnt} || return '';
	my $message = qq[
		<p>Your '$dref->{'strName'}' is due to expire on $dref->{'dtEndFMT'}.</p>
		$text
	];
	if($dref->{'intRenewRegoFormID'})	{
		my $url = "$Defs::base_url/regoform.cgi?fID=$dref->{'intRenewRegoFormID'}";
		$message .= qq[<p><a href = "$url">To renew click here</a><p>];
	}

	my $subject = "Your '$dref->{'strName'}' is about to expire";
	my $replyto = $Defs::null_email;


	my $st = qq[
		INSERT INTO tblCommunicatorMessage (
			dtAdded, 
			intMessageTypeID, 
			intEntityTypeID, 
			intEntityID, 
			strSubject, 
			strMessage, 
			strReplyTo, 
			intNumRecipients, 
			intMessageCategoryID,
			intPriority
		)
		VALUES (
			NOW(),
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
	my $q= $db->prepare($st);
	$q->execute(
		1,
		0,
		0,
		$subject,
		$message,
		$replyto,
		1,
		0,
		0
	);
	my $msgID = $q->{mysql_insertid} || 0;
	return '' if !$msgID;

	my $st_rcpt = qq[
		INSERT INTO tblCommunicatorRecipient (
			intMessageID,
			intEntityTypeID,
			intEntityID,
			strAddress,
			dtAdded
		)
		VALUES (
			?,
			?,
			?,
			?,
			NOW()
		)
	];
	my $q_rcpt = $db->prepare($st_rcpt);
	$q_rcpt->execute(
		$msgID,
		$dref->{'intTableType'},
		$dref->{'intID'},
		$address,
	);
}
