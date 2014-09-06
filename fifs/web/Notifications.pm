#
# $Header: svn://svn/SWM/trunk/web/Notifications.pm 11080 2014-03-21 04:05:17Z cgao $
#

package Notifications;
require Exporter;

@ISA =  qw(Exporter);
@EXPORT = qw(getNotifications deleteNotification addNotification handleNotifications);
@EXPORT_OK = qw(getNotifications deleteNotification addNotification handleNotifications);

use strict;
use Reg_common;
use CGI qw(escape unescape param);

use ListNotifications;
use HTMLForm;
use AuditLog;
use Utils;


sub handleNotifications	{
  my ($action, $Data, $client, $typeID, $ID) = @_;

  my $notificationID= param('nID') || 0;
  my $resultHTML='';
  my $title='';
  if ($action =~/^NOTS_DT/) {
    #Participation Details
    ($resultHTML,$title)=notification_details(
      $action,
      $Data,
      $notificationID
    );
  }
  elsif ($action =~/^NOTS_L/) {
    #List Notifications 
    my $tempResultHTML = '';
    ($tempResultHTML,$title)=listNotifications($Data);
    $resultHTML .= $tempResultHTML;
  }

  return ($resultHTML,$title);
}

sub getNotifications {
	my (
		$Data, 
		$entityTypeID, 
		$entityID,
	)=@_;


	return [] if !$entityTypeID;
	return [] if !$entityID;
	my $st = qq[
		SELECT 
			intNotificationID,
			dtDateTime,
			strNotificationType,
			strTitle,
			intReferenceID,
			strMoreInfo,
			strMoreInfoURLs,
			strURL
		FROM tblNotifications
		WHERE
			intEntityTypeID = ?
			AND intEntityID = ?
			AND intNotificationStatus=0
		ORDER BY intNotificationID DESC
	];
	my $q = $Data->{'db'}->prepare($st);
	$q->execute(
		$entityTypeID, 
		$entityID,
	);
	my @notifications	= ();
	my $client = setClient($Data->{'clientValues'});
	my $count=0;
    my $regoform_notifications_ref = {};
    my $q_regoform = $Data->{'db'}->prepare("SELECT DISTINCT F.intRegoFormID, F.strRegoFormName FROM tblRegoForm AS F INNER JOIN tblRegoFormNotifications AS FN ON F.intRegoFormID=FN.intRegoFormID WHERE FN.intRegoFormNotificationID=?");
	while(my $dref = $q->fetchrow_hashref())	{
		$count++;
		next if $count > 6;
		my $url = $dref->{'strURL'} || '';
		$url = qq[$Data->{'target'}?client=$client&amp;a=NOTS_DT&amp;nID=$dref->{'intNotificationID'}] if ! $url;
		$url =~s/XXX_CLIENT_XXX/$client/g;
		$dref->{'strMoreInfo'} =~s/XXX_CLIENT_XXX/$client/g;
		my $more_urls = $dref->{'strMoreInfoURLs'} || '';
		$more_urls =~s/XXX_CLIENT_XXX/$client/g;

        my $nodisplay_in_dashboard = 0;
        if ( $dref->{'strNotificationType'} eq 'RegoForm' ) {
            if ( $dref->{'intReferenceID'} > 0 ) {
                $nodisplay_in_dashboard = 1;
                my ( $form_id, $form_name ) = ( 0, '' );
                $q_regoform->execute( $dref->{'intReferenceID'} );
                ( $form_id, $form_name ) = $q_regoform->fetchrow_array();

                if ( $form_id != 0 and $form_name ne '' ) {
                    $regoform_notifications_ref->{$form_id}->{'count'} += 1;
                    $regoform_notifications_ref->{$form_id}->{'form_name'} = $form_name;
                }
            }
        }

		push @notifications, {
			date => $dref->{'dtDateTime'},
			id => $dref->{'intNotificationID'},
			type => $dref->{'strNotificationType'},
			title => $dref->{'strTitle'},
			refID => $dref->{'intReferenceID'},
			url => $url,
			more_urls => $more_urls,
			info => $dref->{'strMoreInfo'},
            nodisplay => $nodisplay_in_dashboard,
		};
	}

    for my $regoform_notification ( values %$regoform_notifications_ref ) {
        my $title = '';
        if ( $regoform_notification->{'count'} > 1 ) {
            $title = "There have been $regoform_notification->{'count'} changes";
        }
        else {
            $title = "There has been $regoform_notification->{'count'} change";
        }
        $title .= " to $regoform_notification->{'form_name'}.";
        push @notifications, {
            title => $title,
            url => $Defs::base_url . "/main.cgi?client=$client&amp;a=NOTS_L",
            nodisplay => 0,
        };
    }

	return (\@notifications, $count);
}

sub deleteNotification {
	my (
		$Data, 
		$entityTypeID, 
		$entityID,
		$notificationID,
		$type,
		$refID
	)=@_;
	if($notificationID)	{
		my $st = qq[
			DELETE FROM tblNotifications
			WHERE
				intEntityTypeID = ?
				AND intEntityID = ?
				AND intNotificationID = ?
		];
		my $q = $Data->{'db'}->prepare($st);
		$q->execute(
			$entityTypeID, 
			$entityID,
			$notificationID,
		);
		return 1;
	}
	if($type)	{
		my $st = qq[
			DELETE FROM tblNotifications
			WHERE
				intEntityTypeID = ?
				AND intEntityID = ?
				AND strNotificationType = ?
				AND intReferenceID = ?
		];
		my $q = $Data->{'db'}->prepare($st);
		$q->execute(
			$entityTypeID, 
			$entityID,
			$type,
			$refID || 0,
		);
		return 1;
	}
}

sub addNotification {
	my (
		$Data, 
		$entityTypeID, 
		$entityID,
		$notificationData,
	)=@_;

	# NotificationData is a hash ref containing the following values
	# type - Type of notification
	# title - title of the notification
	# refID - Reference ID for this particular notification
	# more - more information text
	# url - url to click through

	return 0 if !$entityTypeID;
	return 0 if !$entityID;
	return 0 if !$notificationData;
	return 0 if !ref $notificationData;

	my $st = qq[
		INSERT INTO tblNotifications (			
			intEntityTypeID,
			intEntityID,
			dtDateTime,
			strNotificationType,
			strTitle,
			intReferenceID,
			strMoreInfo,
			strURL,
			strMoreInfoURLs
		)
		VALUES (
			?,
			?,
			NOW(),
			?,
			?,
			?,
			?,
			?,
			?
		)
		ON DUPLICATE KEY UPDATE
			dtDateTime = NOW(),
			strTitle = ?,
			strMoreInfo = ?,
			strURL = ?,
			strMoreInfoURLs = ?
	];
	my $q = $Data->{'db'}->prepare($st);
	$q->execute(
		$entityTypeID,
		$entityID,
		$notificationData->{'type'} || '',
		$notificationData->{'title'} || '',
		$notificationData->{'refID'} || 0,
		$notificationData->{'more'} || '',
		$notificationData->{'url'} || '',
		$notificationData->{'more_urls'} || '',

		$notificationData->{'title'} || '',
		$notificationData->{'more'} || '',
		$notificationData->{'url'} || '',
		$notificationData->{'more_urls'} || '',
	);

	return 1;
}
 
 ####

sub notification_details	{
	my ($action, $Data, $notificationID)=@_;

    my $entityID = $Data->{'clientValues'}{'_intID'};
    my $entityTypeID = $Data->{'clientValues'}{'currentLevel'};
	my $field=loadNotificationDetails($Data->{'db'}, $entityID, $entityTypeID, $notificationID) || ();
	my $option='edit';
	#$option='edit' if $action eq 'N_DTE' and $Data->{'clientValues'}{'authLevel'} >= $typeID;
	
	my $client=setClient($Data->{'clientValues'}) || '';
	$field->{'strMoreInfo'} =~s/XXX_CLIENT_XXX/$client/g;
	$field->{'strMoreInfoURLs'} =~s/XXX_CLIENT_XXX/$client/g;

	my @memberURLs = $field->{'strMoreInfoURLs'} =~ m/(XXX_MEMBERCLIENT\d+_XXX)/g;
	foreach my $memberURL (@memberURLs)	{
		$memberURL =~ /(\d+)/;
		my $memberID = $1;
		$Data->{'clientValues'}{'memberID'} = $memberID;
		$Data->{'clientValues'}{'currentLevel'} = $Defs::LEVEL_MEMBER;
		my $client=setClient($Data->{'clientValues'}) || '';
		$field->{'strMoreInfoURLs'} =~s/$memberURL/$client/g;
	}

	my @teamURLs = $field->{'strMoreInfoURLs'} =~ m/(XXX_TEAMCLIENT\d+_XXX)/g;
	foreach my $teamURL (@teamURLs)	{
		$teamURL =~ /(\d+)/;
		my $teamID = $1;
		$Data->{'clientValues'}{'teamID'} = $teamID;
		$Data->{'clientValues'}{'currentLevel'} = $Defs::LEVEL_TEAM;
		my $client=setClient($Data->{'clientValues'}) || '';
		$field->{'strMoreInfoURLs'} =~s/$teamURL/$client/g;
	}
	my %FieldDefinitions=(
		fields=>	{
			strTitle => {
				label => 'Title',
				value => $field->{strTitle},
				type  => 'text',
				size  => '40',
				maxsize => '150',
        readonly =>1,
			},
			dateTime=> {
				label => 'Notification Date',
				value => $field->{dateTime},
				type  => 'date',
				size  => '40',
				maxsize => '150',
        readonly =>1,
			},
			strMoreInfo=> {
				label => 'Details',
				value => $field->{strMoreInfo},
				type  => 'text',
				size  => '30',
				maxsize => '50',
        readonly =>1,
			},
			strMoreInfoURLs=> {
				label => 'More URLs',
				value => $field->{strMoreInfoURLs},
				type  => 'text',
				size  => '30',
				maxsize => '50',
        readonly =>1,
			},
			strNotes => {
				label => 'User Notes',
				value => $field->{strNotes},
				type  => 'textarea',
				rows => 5,
				cols=> 45,
			},
			intNotificationStatus=> {
        label => 'Notification Status',
        value => $field->{intNotificationStatus},
        type  => 'lookup',
        options => \%Defs::notificationStatus,
        firstoption => ['',"Choose Status"],
      },
		},
		order => [qw(strTitle dateTime strMoreInfo strMoreInfoURLs strNotes intNotificationStatus)],
		options => {
			labelsuffix => ':',
			hideblank => 1,
			target => $Data->{'target'},
			formname => 'n_form',
      submitlabel => $Data->{'lang'}->txt('Update'),
      introtext => $Data->{'lang'}->txt('HTMLFORM_INTROTEXT'),
			NoHTML => 1, 
			updateSQL => qq[
        UPDATE tblNotifications
          SET --VAL--
        WHERE intNotificationID=$notificationID
				],
			auditFunction=> \&auditLog,
      auditAddParams => [
        $Data,
        'Add',
        'Notification'
      ],
      auditEditParams => [
        $notificationID,
        $Data,
        'Update',
        'Notification'
      ],
      LocaleMakeText => $Data->{'lang'},
		},
		carryfields =>	{
			client => $client,
			a=> $action,
			nID => $notificationID
		},
	);
	my $resultHTML='';
	($resultHTML, undef )=handleHTMLForm(\%FieldDefinitions, undef, $option, '',$Data->{'db'});
	my $title=$field->{strName};
	my $viewAll = qq[<div style="float:right;"><a href="$Data->{'target'}?client=$client&amp;a=NOTS_L">View All Notifications</a></div>];
	my $breadcrumbs = HTML_breadcrumbs(
		[
			'Notifications',
			'main.cgi',
			{ client => $client, a => 'NOTS_L' },
		],
	);
  if($option eq 'display')  {
    my $chgoptions='';
    #$chgoptions.=qq[<div style="float:right;"><a href="$Data->{'target'}?client=$client&amp;a=N_DTE"><img src="images/edit_icon.gif" border="0" alt="Edit"></a></div> ] if($Data->{'clientValues'}{'authLevel'} >= $typeID and allowedAction($Data, 'n_e'));
		$title=$chgoptions.$title;
    my $editlink = allowedAction($Data, 'n_e') ? 1 : 0;
  }
  $resultHTML=$breadcrumbs.$resultHTML;

	return ($resultHTML,$title);
}

sub HTML_breadcrumbs {
    my @html_links;

    while ( my $link_params = shift ) {
        push @html_links, HTML_link( @{ $link_params } );
    }

    my $cgi = new CGI;

    return $cgi->div(
        { -class => 'config-bcrumbs', },
        join('&nbsp;&raquo;&nbsp;', grep(/^.+$/, @html_links)),
    ) ;
}


sub loadNotificationDetails {
  my($db, $entityID, $entityTypeID, $id) = @_;
                                                                                                        
  my $statement=qq[
    SELECT 
			*,
			DATE_FORMAT(dtDateTime, "%d/%m/%Y") as dateTime
    FROM tblNotifications
    WHERE intNotificationID=?
			AND intEntityID=?
			AND intEntityTypeID=?
  ];
  my $query = $db->prepare($statement);
  $query->execute($id, $entityID, $entityTypeID);
	my $field=$query->fetchrow_hashref();
  $query->finish;
                                                                                                        
  foreach my $key (keys %{$field})  { if(!defined $field->{$key}) {$field->{$key}='';} }
  return $field;
}

1;
