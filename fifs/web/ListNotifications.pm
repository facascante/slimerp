#
# $Header: svn://svn/SWM/trunk/web/ListNotifications.pm 11080 2014-03-21 04:05:17Z cgao $
#

package ListNotifications;

## LAST EDITED -> 10/09/2007 ##

require Exporter;
@ISA =  qw(Exporter);
@EXPORT = qw(listNotifications);
@EXPORT_OK = qw(listNotifications);

use strict;
use CGI qw(param unescape escape);

use lib '.', "..";
use Defs;
use Reg_common;
use FormHelpers;
use CGI;
use GridDisplay;

sub listNotifications {
  my($Data) = @_;
  my $assocID = $Data->{'clientValues'}{'assocID'} || 0;
  my $clubID = ($Data->{'clientValues'}{'clubID'}>0) ? $Data->{'clientValues'}{'clubID'} : 0;
	my $entityID = $clubID || $assocID;
	my $entityTypeID = $Data->{'clientValues'}{'currentLevel'} || 0;
  my $db=$Data->{'db'};
  my $resultHTML = '';
  my $lang = $Data->{'lang'};
  my %textLabels = (
    'assoc' => $lang->txt('Association'),
    'listOfNots' => $lang->txt('List of Notifications'),
    'name' => $lang->txt('Name'),
    'noNotificationsFound' => $lang->txt('No Notifications can be found in the database.'),
    'status' => $lang->txt('Status'),
  );
  my $orignodename='';
  my $statement =qq[
    SELECT 
			intNotificationID,
			strTitle,
			strMoreInfo,
			intNotificationStatus,
			DATE_FORMAT(N.dtDateTime,'%d/%m/%Y') AS dtDateTime
    FROM 
      tblNotifications as N
    WHERE 
      N.intEntityID = ?
			AND N.intEntityTypeID= ?
    ORDER BY 
			N.intNotificationID DESC
  ];
  my $query = $db->prepare($statement);
  $query->execute($entityID, $entityTypeID);
  my $found = 0;
  my $client=setClient($Data->{'clientValues'});
  my $currentname='';

  $found = 0;
  my @rowdata  = ();
  while (my $dref = $query->fetchrow_hashref()) {
    my %row = ();
    for my $i (qw(intNotificationID strTitle strMoreInfo dtDateTime)) {
      $row{$i} = $dref->{$i};
    }
	my $editLink = ( $Data->{'clientValues'}{'authLevel'} == $entityTypeID )? "$Data->{'target'}?client=$client&amp;a=NOTS_DT&amp;nID=$dref->{intNotificationID}" : '';
    $row{'id'} = $dref->{'intNotificationID'};
    $row{'notificationStatus'} = $Defs::notificationStatus{$dref->{'intNotificationStatus'}};
    $row{'SelectLink'} = $editLink;
    push @rowdata, \%row;
    $found++;
  }
  if (!$found) {
    $resultHTML .= textMessage($textLabels{'noNotficationsFound'});
  }
  else  {
    my $memfieldlabels=FieldLabels::getFieldLabels($Data,$Defs::LEVEL_PERSON);
    my @headers = (
			{
			    type => 'Selector',
					field => 'SelectLink',
      },
      {
        name => $Data->{'lang'}->txt('Notification ID'),
        field => 'intNotificationID',
				width=>30,
      },
      {
        name => $Data->{'lang'}->txt('Title'),
        field => 'strTitle',
      },
      {
        name => $Data->{'lang'}->txt('Date/Time'),
        field => 'dtDateTime',
				width=>30,
      },
      {
        name => $Data->{'lang'}->txt('Status'),
        field => 'notificationStatus',
				width=>30,
      },
    );
    my $grid  = showGrid(
      Data => $Data,
      columns => \@headers,
      rowdata => \@rowdata,
      gridid => 'grid',
      width => '99%',
      height => 700,
    );
    $resultHTML = qq[
      <table class="listTable">
        $grid
      </table>
    ];
  }
  my $title = $textLabels{'listOfNots'};
  return ($resultHTML, $title);
}

1;
