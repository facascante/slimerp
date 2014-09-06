#!/usr/bin/perl -w

#
# $Header: svn://svn/SWM/trunk/automatic/businessrules.pl 9460 2013-09-10 02:32:37Z tcourt $
#

use lib ".", "..", "../web", "../web/BusinessRules", "../web/comp", "../web/sportstats";
use Defs;
use Utils;
use DBI;
use strict;
use Lang;
use SystemConfig;
use BusinessRules;
use Notifications;

{
	my $db=connectDB();
  $db->{mysql_auto_reconnect} = 1;
  $db->{wait_timeout} = 3700;
  $db->{mysql_wait_timeout} = 3700;

	my $lastupdate='';
	my %Data=();
  my $lang= Lang->get_handle() || die "Can't get a language handle!";
  $Data{'lang'}=$lang;
  my $target='main.cgi';
  $Data{'target'}=$target;
  $Data{'db'}=$db;

	my $dayOfWeek= (localtime)[6];

	my $st = qq[
		SELECT 
			R.intBusinessRuleID, 
			R.strRuleName, 
			R.strFunction, 
			R.intParamTableType, 
			R.strNotificationHeaderText,
			R.strNotificationRowsText, 
			R.strNotificationRowsURLs, 
			R.strRequiredOption, 
			R.strRuleOption, 
			R.intRuleOutcomeType, 
			R.intOutcomeRows, 
			S.strScheduleName as ScheduleName, 
			R.intAcknowledgeDtLastRun,
			S.intBusinessRuleScheduleID,
			S.intRealmID, 
			S.intRealmSubTypeID,
			S.intScheduleByTableType, 
			S.intScheduleByID, 
			S.intDayToRun, 
			S.dtLastRun 
		FROM 
			tblBusinessRuleSchedule as S 
			INNER JOIN tblBusinessRules as R ON (
				R.intBusinessRuleID=S.intBusinessRuleID
			)
		WHERE
			intDayToRun IN (?,99)
	];

	my $st_updateSchedule = qq[
		UPDATE tblBusinessRuleSchedule
		SET
			dtLastRun=NOW()
		WHERE
			intBusinessRuleScheduleID=?
	];
  my $qry_updateSchedule = $db->prepare($st_updateSchedule);
  my $qry = $db->prepare($st);
  $qry->execute($dayOfWeek);
  while (my $dref = $qry->fetchrow_hashref) {
		print "\n\nRUN FUNCTION: $dref->{'strFunction'}\n";
  	($Data{'Realm'}, $Data{'RealmSubType'})= ($dref->{'intRealmID'}, $dref->{'intRealmSubTypeID'});
  	$Data{'SystemConfig'}=getSystemConfig(\%Data);
		my $function = $dref->{'strFunction'};#"BusinessRules::checkVenues";
		my ($count, $rows_ref) = &{\&$function}(\%Data, $dref);
		my @Rows=();
		my $resultBody='';
		my $resultBodyURLs='';
		foreach my $row (@{$rows_ref}) {
			my $rowBody = $dref->{'strNotificationRowsText'};
			foreach my $key (keys %{$row})	{
				$rowBody =~ s/$key/$row->{$key}/g;
			}
			my $rowBodyURLs = $dref->{'strNotificationRowsURLs'};
			foreach my $key (keys %{$row})	{
				$rowBodyURLs =~ s/$key/$row->{$key}/g;
			}
			$resultBody .= $rowBody .qq[<br>];
			$resultBodyURLs .= $rowBodyURLs .qq[<br>];
			push @Rows, {body=>$rowBody, url=>$row->{'url'}, more_urls=>$rowBodyURLs};
		}
					
		if ($dref->{'intRuleOutcomeType'} == $Defs::BUSINESSRULE_OUTCOME_NOTIFICATION)	{
				if ($dref->{'intOutcomeRows'} ==1)	{
					my %Notification=();
					$Notification{'title'} = $dref->{'strRuleName'};
					$Notification{'title'} .= qq[- $dref->{'ScheduleName'}] if $dref->{'ScheduleName'};
					$Notification{'type'} = getRuleKey("$dref->{'intBusinessRuleID'}.$dref->{'intBusinessRuleScheduleID'}");
					$Notification{'more'} = $resultBody;
					$Notification{'url'} = $dref->{'url'};
					$Notification{'more_urls'} = $resultBodyURLs;
					addNotification(\%Data, $dref->{'intScheduleByTableType'}, $dref->{'intScheduleByID'}, \%Notification) if $resultBody;
					## Write as 1 row
					#print $resultBody;
				}
			else	{
				#print qq[COUNT: $count \n];
				my $resultCount=0;
				foreach my $row (@Rows) {
						$resultCount++;
						my %Notification=();
						$Notification{'title'} = $dref->{'strRuleName'};
						$Notification{'title'} .= qq[- $dref->{'ScheduleName'}] if $dref->{'ScheduleName'};
						$Notification{'more'} = $row->{'body'};
						$Notification{'url'} = $row->{'url'};
						$Notification{'more_urls'} = $row->{'more_urls'};
						$Notification{'type'} = $resultCount . getRuleKey("$dref->{'intBusinessRuleID'}.$dref->{'intBusinessRuleScheduleID'}");
						addNotification(\%Data, $dref->{'intScheduleByTableType'}, $dref->{'intScheduleByID'}, \%Notification);
					#print $row->{'body'}."\n";
				}
			}
  	$qry_updateSchedule->execute($dref->{'intBusinessRuleScheduleID'});
		}
		#print qq[\n];
	}
}

sub getRuleKey{
	my ($ruleID) = @_;

  my @date=(localtime())[0..5];
  $date[5] += 1900;
  $date[4] ++;
  @date= map { sprintf "%02d", $_} @date;
  return "$ruleID-$date[5]$date[4]$date[3]$date[2]$date[1]$date[0]";
}

