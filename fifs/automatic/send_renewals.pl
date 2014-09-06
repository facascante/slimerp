#!/usr/bin/perl -w

#
# $Header: svn://svn/SWM/trunk/automatic/send_renewals.pl 10578 2014-02-03 02:45:14Z tcourt $
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

    my $db = connectDB();
    $db->{mysql_auto_reconnect} = 1;
    $db->{wait_timeout} = 3700;
    $db->{mysql_wait_timeout} = 3700;

    $Data{'db'} = $db;
    my $lang = Lang->get_handle() || die "Can't get a language handle!";
    $Data{'lang'} = $lang;

    my $statement = qq[
        SELECT *
        FROM tblBulkRenewals
        WHERE dtSent IS NULL
    ];
    my $query = $db -> prepare($statement);
    $query->execute;
    while (my $dref = $query -> fetchrow_hashref()) {
        sendRenewals(\%Data, $db, $dref);       
  }
    disconnectDB($db);
}


sub sendRenewals {
    my($Data, $db, $dref)=@_;
    my $messageID=$dref->{'intBulkRenewalID'} || return '';
    my $commMessageID = 0;
    my $fromname = 'Sporting Pulse';
	if($dref->{'intEntityTypeID'} == $Defs::LEVEL_CLUB) {
        	my $st = qq[SELECT strName FROM tblClub WHERE intClubID= ?];
        	my $query = $db->prepare($st);
        	$query->execute($dref->{'intEntityID'});
        	$fromname = $query->fetchrow_array() || '';
	} elsif($dref->{'intEntityTypeID'} == $Defs::LEVEL_ASSOC) {
        	my $st = qq[SELECT strName FROM tblAssoc WHERE intAssocID= ?];
        	my $query = $db->prepare($st);
        	$query->execute($dref->{'intEntityID'});
        	$fromname = $query->fetchrow_array() || '';
	}    
    #$fromaddress = $dref->{'strFromAddress'} || $Defs::null_email;
    my $fromaddress = "$fromname <donotreply\@sportingpulse.com>";
    my $template = '';
    my $subject = '';
    my $comm_type = 0;
    if($dref->{'intRenewalType'} == 1)  {
        #team renewal
        $template = 'team/coordinator.templ';
        $subject = 'Invitation to join new season competition';
        $comm_type = 3;
    }
    elsif($dref->{'intRenewalType'} == 2)   {
        #member renewal
        $comm_type = 4;
        $subject = 'Invitation to re-register';
        if($dref->{'intEntityTypeID'} == $Defs::LEVEL_CLUB) {
            $template = 'emails/renewals/club/renew.templ';
        }
        else    {
            $template = 'emails/renewals/assoc/renew.templ';
        }
    }
    elsif($dref->{'intRenewalType'} == 6)   {
        #Passport Invitation
        $comm_type = 6;
        $subject = 'Link your details with a SP Passport Account';
        $template = $dref->{'strTemplate'} || '';
    }
    elsif($dref->{'intRenewalType'} == 3)   {
        #campaign
        $comm_type = 5;
        $template = 'emails/campaigns/supportyoursport/memberemail.templ';
    }

    my $st=qq[
        SELECT 
            strAddress, 
            strContent,
            intEntityTypeID,
            intEntityID
    
    FROM tblBulkRenewalsRecipient AS BRR
        WHERE   intBulkRenewalID = ?
    ];
    my $q= $db->prepare($st);
    $q->execute($messageID); 
    my @emails = ();
    while (my $address_ref = $q->fetchrow_hashref())    {
        my $c = $address_ref->{'strContent'} || next;
        my %dat = ();
        my @v = split '\|', $address_ref->{'strContent'};
        for my $v (@v)  {
            my($k, $v) = split/=/, $v,2;
            $dat{$k} = $v;
        }
        
        if ($comm_type ne 5) {
            push @emails,   [
                $address_ref->{'strAddress'} || next,
                \%dat,
                $dref->{'intEntityTypeID'},
                $dref->{'intEntityID'},
            ];
        }
        else {
            push @emails,   [
                $address_ref->{'strAddress'} || next,
                \%dat,
                $Defs::LEVEL_MEMBER,
                $dat{'MemberID'},
            ];
        }
    }

    if ($comm_type eq 5) {
        my $messageText = '';
        if (@emails) {
            $subject = $emails[0][1]{'Subject'};
            $messageText = $emails[0][1]{'Message'};
        }
       else {
           $subject = 'Campaign invite';
           $messageText = 'Lorem ipsum dolor sit amet, comnsectetur adipiscing elit.';
       }
    }

     #Log Message
    my $st_log_msg = qq[
        INSERT INTO tblCommunicatorMessage (
            intMessageTypeID,
            intEntityTypeID,
            intEntityID,
            strSubject,
            strMessage,
            intNumRecipients,
            dtAdded,
            dtSent
        )
        VALUES (
            $comm_type,
            $dref->{'intEntityTypeID'},
            $dref->{'intEntityID'},
            ?,
            ?,
            ?,
            NOW(),
            NOW()
        )
    ];

    my %RegoData = ();

		if ($comm_type == 5) {
        %RegoData = (
            MemberName => '<<Member Name>>',
            MessageFromClub => '<<Message From Club>>',
            CampaignNo => '<<Campaign No>>',
            CampaignName => '<<Campaign Name>>',
            CampaignDesc => '<<Campaign Desc>>',
            baseURL => '<<baseURL>>',
            SignupURL => '',

        );
        my $msg = runTemplate(
            $Data,
            \%RegoData,
            $template,
        );

        my $q_log= $db->prepare($st_log_msg);
        $q_log->execute(
                $subject,
                $msg,
                scalar(@emails)
        );
	$commMessageID = $q_log->{'mysql_insertid'} || 0;

    }
    else	{
        %RegoData = (
            MemberName => '<<Member Name >>',
            MemberEmail => '<<Member Email>>',

            AssocName => '<<Association Name >>',
            AssocEmail => '<<Association Email>>',
            AssocID => '',
            ClubName => '<< Club Name >>',
            ClubID => '',

            TeamID => '<<Team Code>>',
            TeamName  => '<<Team Name>>',
            TeamContact => '<<Team Contact>>',
            TeamEmail => '<<Team Email>>',

            FormID => '',
            FormURL => '',
            SignupURL => '',

            editable_1 => '<< editable_1 >>',
            editable_2 => '<< editable_2 >>',

        );
        my $msg = runTemplate(
            $Data,
            \%RegoData,
            $template,
        );
        my $q_log= $db->prepare($st_log_msg);
        $q_log->execute(
                $subject,
                $msg,
                scalar(@emails)
        );
				$commMessageID = $q_log->{'mysql_insertid'} || 0;
    }
    my $st_log_rcpt = qq[
        INSERT INTO tblCommunicatorRecipient (
            intMessageID,
            intEntityTypeID,
            intEntityID,
            strAddress,
            dtAdded
        )
        VALUES (
            $commMessageID,
            ?,
            ?,
            ?,
            NOW()
        )
    ];
    my $q_logrcpt = $db->prepare($st_log_rcpt);

    my $numsent = 0;
    #Mark as sent
    my $st_upd = "UPDATE tblBulkRenewals SET dtSent=NOW() where intBulkRenewalID = $messageID";
    $db->do($st_upd);                                                                          

    my $fullTemplatePath = $template;
		$fullTemplatePath =~ s/emails\///;

    for my $e (@emails) {
 			my $sent =  sendTemplateEmail(
            $Data,
            $fullTemplatePath,
            $e->[1],
            $e->[0],
            $subject,
            $fromaddress,
        );
        $q_logrcpt->execute(
            $e->[2],
            $e->[3],
            $e->[0],
        );
        $numsent++ if $sent;
    }

};
