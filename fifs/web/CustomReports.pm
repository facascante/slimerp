#
# $Header: svn://svn/SWM/trunk/web/CustomReports.pm 9998 2013-11-28 22:52:38Z tcourt $
#

package CustomReports;
require Exporter;

###########################
# CREATED: 23/10/07       #
# CREATED BY: TC          #
# LAST MODIFIED: 24/10/07 #
# LAST <ODIFIED BY: TC    #
###########################

@ISA =  qw(Exporter);
@EXPORT = qw(handleCustomReports getCustomReportsMenu displayCustomReport runTemplateReportDataRoutine);
@EXPORT_OK = qw(handleCustomReports getCustomReportsMenu displayCustomReport runTemplateReportDataRoutine);

use strict;
use CGI qw(param unescape Vars);

use lib '.','..','comp','sportstats';
use Reg_common;
use Defs;
use Utils;
use SearchLevels;
use Template;
use MediaReportData;


sub handleCustomReports {
	my ($Data, $action, $reptype) = @_;
	my ($resultHTML, $title) = ('','');
	my $crID=param('crID') || 0;
	return ('Invalid Report','Invalid Report') if !$crID;
	($resultHTML, $title)=displayCustomReport($Data, $crID);
	return ($resultHTML, $title);
}

sub getCustomReportsMenu {
	my ($Data)=@_;
	my $clientValues_ref=$Data->{'clientValues'};
	my $client=$Data->{'client'};
	my $currentLevel = $clientValues_ref->{'currentLevel'};
	my $userLevel=$clientValues_ref->{'authLevel'} || 0;
	my $userID=getID($clientValues_ref, $clientValues_ref->{'authLevel'}) || 0;
	my $aID=getAssocID($clientValues_ref) || 0;
	my $realmID = $Data->{'Realm'} || 0;
	my $subRealmID = $Data->{'RealmSubType'} || 0;
	my $crbuttons='';
	my $where_subRealmID = $subRealmID ? "intSubRealmID IN (0,$subRealmID)" : " intSubRealmID=0 ";
	my $db = $Data->{'db'};
	my $st = qq[
		SELECT intCustomReportID, strName 
		FROM tblCustomReportsUser AS U
			INNER JOIN tblCustomReports AS C ON (C.intCustomReportsID=U.intCustomReportID)
		WHERE U.intRealmID=$realmID
			AND $where_subRealmID
			AND intUserTypeID IN (0,$currentLevel)
			AND intUserID IN (0,$userID)
			AND $currentLevel >= intMinLevel
			AND $currentLevel <= intMaxLevel 
	];
  my $q = $db->prepare($st);
	$q->execute();
	while (my $dref = $q->fetchrow_hashref()) {
		$crbuttons.=qq[
		<form action ="$Data->{'target'}" target="report" method="POST" name="cr_$dref->{intCustomReportID}">
			<input type="hidden" name="a" value="REP_REPORT">
			<input type="hidden" name="client" value="$client">
			<input type="hidden" name="reptype" value="CR">
			<input type="hidden" name="crID" value="$dref->{intCustomReportID}">
			<input type="submit" value="$dref->{strName}">
		</form> 
		];
	}
	$crbuttons=qq[ <div class="sectionheader">Custom Reports</div> $crbuttons ] if $crbuttons;
	return $crbuttons;
}

sub displayCustomReport	{
	my($Data, $crID, $params)=@_;
	
	my $st=qq[
			SELECT * 
			FROM tblCustomReports
			WHERE intCustomReportsID=$crID
	];
	my $q = $Data->{'db'}->prepare($st);
	$q->execute();
	my $dref = $q->fetchrow_hashref();
	$q->finish();

	my %options=();
	if($dref->{'strConfig'})	{
		my @options=split /\|/, $dref->{'strConfig'};
		for my $i (@options)	{
			my ($k, $v)=split /:/, $i;
			$options{$k}=$v if $k;
		}
	}
	my $reportLevel = $options{'reportLevel'} || $Data->{'clientValues'}{'currentLevel'};
	my $reportEntity= $options{'reportEntity'} || $Defs::LEVEL_MEMBER;
	my $reportStats= $options{'Stats'} || 0;
	my $reportNotMemberTeam= $options{'NotMemberTeam'} || 0;
  
	$options{'CR_ID'} = $dref->{'intCustomReportsID'};
	$options{'CR_Title'} = $dref->{'strName'};
  
	my ($from_levels, $where_levels, $select_levels, $current_from, $current_where) = 
        getLevelQueryStuff($reportLevel,  $reportEntity, $Data, $reportStats, $reportNotMemberTeam);
    
	my $sqlpre=$dref->{'strSQL'} || '';
	$sqlpre='$sql=qq['.$sqlpre.'];';
	my $sql='';
	eval($sqlpre);
    
	my $report='';
	if($dref->{'intTypeID'} == 2)	{
		#Do templated report
		$report=runTemplateReport($Data, $sql, \%options, $dref->{'strTemplateFile'});
	}
    elsif($dref->{'intTypeID'} == 3){
        $report=runTemplateReportDataRoutine($Data,$dref->{'strTemplateFile'},$dref->{'strDataRoutine'}, $params) 
    }
	else	{
		#Do Other report
	}
	my $title=$dref->{'strName'} || 'Report';
	return ($report, $title);
}


sub runTemplateReport	{
	my($Data, $sql, $options, $TemplateFile)=@_;
	my $q = $Data->{'db'}->prepare($sql);
	$q->execute();
	my @DBData=();
	while (my $dref = $q->fetchrow_hashref())	{
		push @DBData, $dref;
	}
	$q->finish();
    
	return 'No Results' if !scalar(@DBData);
 	my $config = {
                  INCLUDE_PATH => [$Defs::fs_customreports_dir],  # or list ref
                  INTERPOLATE  => 1,               # expand "$var" in plain text
                  POST_CHOMP   => 1,               # cleanup whitespace
              };
	my $template= Template->new($config);
	my $outputstr='';
	my %templateData = ( 
		data => \@DBData,
		CR_Title => $options->{'CR_Title'},
		CR_ID => $options->{'CR_ID'}
	);
	$template->process($TemplateFile, \%templateData, \$outputstr)
			|| print STDERR $template->error(), "\n";
	return $outputstr;
}

sub runTemplateReportDataRoutine {
    my ($Data,$template,$routine, $params) = @_;
    my ($object, $method) = split(/::/,$routine,-1);
    my $template_data = $object->$method($Data,$params);
    my $config = {
      INCLUDE_PATH => [$Defs::fs_customreports_dir],  # or list ref
      INTERPOLATE  => 1,                              # expand "$var" in plain text
      POST_CHOMP   => 1,                              # cleanup whitespace
    };
    my $tt = Template->new($config);
    my $result = '';
    $tt->process($template,$template_data,\$result) || print STDERR $tt->error(), "\n";
    return $result;
}

1;
