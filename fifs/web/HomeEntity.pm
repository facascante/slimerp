package HomeEntity;
require Exporter;
@ISA = qw(Exporter);
@EXPORT=qw(showEntityHome);
@EXPORT_OK =qw(showEntityHome);

use lib "dashboard";

use strict;
use Reg_common;
use Utils;
use Welcome;
use InstanceOf;

use Logo;
use TTTemplate;
use Dashboard;
use Notifications;

sub showEntityHome	{
	my ($Data, $entityID)=@_;

	my $client = $Data->{'client'} || '';
	my $entityObj = getInstanceOf($Data, 'entity', $entityID);

  my ($welcome, $killmessage) = getWelcomeText($Data, $entityID);
  $killmessage ||= 0;
  return ($killmessage,'') if $killmessage;
	my $allowedit = allowedAction($Data, 'e_e') ? 1 : 0;
	my $logo = showLogo(
      $Data,
      $Defs::LEVEL_NODE,
      $entityID,
      $client,
      $allowedit,
    );

	my ($dashboard, undef) = showDashboard(
    $Data,
    $client,
    $Defs::LEVEL_NODE,
    $entityID,
  );
	my ($notifications, $notificationCount) = getNotifications(
		$Data,
		$Defs::LEVEL_NODE,
    $entityID,
	);

	my $name = $entityObj->name();
	my %TemplateData = (
		Welcome => $welcome,
		Logo => $logo,
		Name => $name,
		ReadOnlyLogin => $Data->{'ReadOnlyLogin'},
		EditDetailsLink => "$Data->{'target'}?client=$client&amp;a=E_DTE",
		EditDashboardLink => "$Data->{'target'}?client=$client&amp;a=DASHCFG_",
		Dashboard => $dashboard,
		Notifications => $notifications,
		Details => {
			Address => $entityObj->getValue('strAddress') || '',
			Town => $entityObj->getValue('strTown') || '',
			Region => $entityObj->getValue('strRegion') || '',
			Country => $entityObj->getValue('strISOCountry') || '',
			PostalCode => $entityObj->getValue('strPostalCode') || '',
			Phone => $entityObj->getValue('strPhone') || '',
			Fax => $entityObj->getValue('strFax') || '',
			URL => $entityObj->getValue('strWebURL') || '',
			Email => $entityObj->getValue('strEmail') || '',
			Contact => $entityObj->getValue('strContact') || '',
		},
	);
	my $resultHTML = runTemplate(
		$Data,
		\%TemplateData,
		'dashboards/entity.templ',
	);

	my $title = $name;
	return ($resultHTML, '');
}


1;

