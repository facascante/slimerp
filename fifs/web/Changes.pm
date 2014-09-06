#
# $Header: svn://svn/SWM/trunk/web/Changes.pm 8251 2013-04-08 09:00:53Z rlee $
#

package Changes;

require Exporter;
@ISA =  qw(Exporter);
@EXPORT = qw(displayChanges);
@EXPORT_OK = qw(displayChanges getLatestChanges);

use strict;

use lib "..";
use Defs;
use Utils;
use Reg_common;

sub displayChanges {
	my($Data)=@_;

	my $statement = qq[
		SELECT strText, DATE_FORMAT(dtDate,"%d/%m/%Y") AS dtDatefmt
		FROM tblVersions
		ORDER BY dtDate DESC
		LIMIT 20
	];

	my $query = $Data->{'db'}->prepare($statement);
	$query->execute;

	my $subBody='';
	while(my $dref=$query->fetchrow_hashref())	{
		$dref->{'strText'} ||='';
		$subBody.=qq[
		<div>
			<div class="sectionheader" >$dref->{'dtDatefmt'}</div>
			$dref->{'strText'}
		</div>
		];
	}

	return ($subBody,'Changes/Announcements');
}

sub getLatestChanges	{
	my($Data)=@_;

	my $statement = qq[
		SELECT strText, DATE_FORMAT(dtDate,"%d/%m/%Y") AS dtDatefmt
		FROM tblVersions
		WHERE dtDate > DATE_ADD(CURRENT_DATE(), INTERVAL -7 DAY)
		ORDER BY dtDate DESC
		LIMIT 3
	];

	my $query = $Data->{'db'}->prepare($statement);
	$query->execute;

	my $subBody='';
	while(my $dref=$query->fetchrow_hashref())	{
		my $text=$dref->{'strText'} || '';
		if(length $text > 300)	{
			$text = substr $text,0,300;
			$text.='...';
		}
		$subBody.=qq[
		<div>
			<div style="font-weight:bold;">$dref->{'dtDatefmt'}</div>
			$text
		</div>
		];
	}

	return '' if !$subBody;
	my $client=setClient($Data->{'clientValues'});
	$subBody=qq[
		<div class="newchangesbox">
			<div class="heading">Changes/Announcements</div>
			$subBody
			<a href="$Data->{'target'}?a=CHG&amp;client=$client">more ...</a>
		</div>
	];
	return $subBody;
}
