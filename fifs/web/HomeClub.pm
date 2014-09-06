package HomeClub;
require Exporter;
@ISA = qw(Exporter);
@EXPORT=qw(showClubHome);
@EXPORT_OK =qw(showClubHome);

use lib "dashboard";

use strict;
use Reg_common;
use Utils;
use Welcome;
use InstanceOf;

use ServicesContacts;
use Contacts;
use Logo;
use TTTemplate;
use Dashboard;
use Notifications;

sub showClubHome  {
  my ($Data, $clubID)=@_;

  my $client = $Data->{'client'} || '';
  my $clubObj = getInstanceOf($Data, 'club');

  my ($welcome, $killmessage) = getWelcomeText($Data, $clubID);
  $killmessage ||= 0;
  return ($killmessage,'') if $killmessage;
  my $allowedit = allowedAction($Data, 'c_e') ? 1 : 0;
  my $logo = showLogo(
      $Data,
      $Defs::LEVEL_CLUB,
      $clubID,
      $client,
      $allowedit,
    );
  my $scMenu = $allowedit
    ? getServicesContactsMenu($Data, $Defs::LEVEL_CLUB, $clubID, $Defs::SC_MENU_SHORT,0)
    : '';
  my $contacts = getLocatorContacts($Data,1);
  my ($dashboard, undef) = showDashboard(
    $Data,
    $client,
    $Defs::LEVEL_CLUB,
    $clubID,
  );
  my ($notifications, $notificationCount)  = getNotifications(
    $Data,
    $Defs::LEVEL_CLUB,
    $clubID,
  );

  my $name = $clubObj->name();
  my %TemplateData = (
    Welcome => $welcome,
    ReadOnlyLogin => $Data->{'ReadOnlyLogin'},
    Logo => $logo,
    Name => $name,
    ContactsMenu => $scMenu,
    Contacts => $contacts,
    EditDetailsLink => "$Data->{'target'}?client=$client&amp;a=C_DTE",
    EditContactsLink => "$Data->{'target'}?client=$client&amp;a=CON_LIST",
    EditDashboardLink => "$Data->{'target'}?client=$client&amp;a=DASHCFG_",
    Dashboard => $dashboard,
    Notifications => $notifications,
    Details => {
      Address => $clubObj->getValue('strAddress') || '',
      Town => $clubObj->getValue('strTown') || '',
      Region => $clubObj->getValue('strRegion') || '',
      Country => $clubObj->getValue('strISOCountry') || '',
      PostalCode => $clubObj->getValue('strPostalCode') || '',
      Phone => $clubObj->getValue('strPhone') || '',
      Fax => $clubObj->getValue('strFax') || '',
      Email => $clubObj->getValue('strEmail') || '',
    },
  );
  my $resultHTML = runTemplate(
    $Data,
    \%TemplateData,
    'dashboards/club.templ',
  );

  my $title = $name;
  return ($resultHTML, '');
}


1;

