#
# $Header: svn://svn/SWM/trunk/web/MemberPackages.pm 10045 2013-12-01 22:30:55Z tcourt $
#

package MemberPackages;

require Exporter;
@ISA =  qw(Exporter);
@EXPORT = qw(getMemberPackages handle_mempackages);

use lib '.', '..';

use strict;
use Defs;
use Reg_common;
use CGI qw(escape unescape param);
use DeQuote;
use AuditLog;


sub getMemberPackages	{
	my($Data)=@_;
	my $realmID=$Data->{'Realm'} || 0;
  my $assocID=$Data->{'clientValues'}{'assocID'} || $Defs::INVALID_ID;

	my $st=qq[
		SELECT intMemberPackagesID, strPackageName
		FROM tblMemberPackages
		WHERE intRealmID=$realmID	
			AND intAssocID=$assocID
	];
  my $query = $Data->{'db'}->prepare($st);
  $query->execute();
	my $body='';
	my %Packages=();
	while (my ($id,$name)=$query->fetchrow_array())	{
		$Packages{$id}=$name||'';
	}
	return \%Packages;
}

sub handle_mempackages {
	my($Data, $action)=@_;

	my $id=param('lki') || 0;
	my $body='';
	if($action eq 'A_MP_U')	{
		$body=update_mempackages($Data, $id);
		$action = 'A_MP_L';
	}
	if($action eq 'A_MP_E')	{
		$body.=detail_mempackages($Data,$id);
	}
	else	{
		$body.=list_mempackages($Data);
	}
	my $title="Member Packages";
	return ($body,$title);
}


sub list_mempackages	{
	my($Data)=@_;

	my $realmID=$Data->{'Realm'} || 0;
  my $target=$Data->{'target'};
  my $cl  = setClient($Data->{'clientValues'});
	my $assocID=$Data->{'clientValues'}{'assocID'} || $Defs::INVALID_ID;

	my $st=qq[
		SELECT intMemberPackagesID, strPackageName, intAssocID
		FROM tblMemberPackages
		WHERE intRealmID= $realmID
			AND (intAssocID = $assocID OR intAssocID=0)
		ORDER BY strPackageName
	];
  my $query = $Data->{'db'}->prepare($st);
  $query->execute();
	my $body='';
	my $i=0;
	while (my $dref=$query->fetchrow_hashref())	{
		my $link= qq[<a href="$target?client=$cl&amp;lki=$dref->{'intMemberPackagesID'}&amp;a=A_MP_E">Edit</a>];
		$link='Locked' if !$dref->{'intAssocID'};
		my $shade=$i%2==0? 'class="rowshade" ' : '';
		$i++;
		$body.=qq[
			<tr>
				<td $shade>$dref->{'strPackageName'}</td>
				<td $shade>$link</td>
			</tr>
		];
	}
	if($body)	{
		$body=qq[
			<table class="listTable">
				$body
			</table>
		];
	}
	else	{
		$body.=qq[<div class="warningmsg">No Records could be found</div>];
	}
	my $allowadds=1;

	my $addlink= qq[<a href="$target?client=$cl&amp;a=A_MP_E">Add a New Package</a>];
	my $addstr= $allowadds ? qq[If you wish to add a new record click the '$addlink' link.] : '';
	$addlink='' if !$allowadds;
	$body=qq[
		<p>Choose a value from the list below to edit.  Some options may be locked by your national/international body and cannot be edited.  $addstr</p>
		$body
		<p>
		$addlink
		</p>
	];
	return $body;
}


sub detail_mempackages	{
	my($Data, $id)=@_;

	my $realmID=$Data->{'Realm'} || 0;
  my $target=$Data->{'target'};
  my $cl  = setClient($Data->{'clientValues'});
	my $assocID=$Data->{'clientValues'}{'assocID'} || $Defs::INVALID_ID;

	my $st=qq[
		SELECT intMemberPackagesID, strPackageName, intAssocID
		FROM tblMemberPackages
		WHERE intRealmID= $realmID
			AND (intAssocID = $assocID OR intAssocID=0)
			AND intMemberPackagesID= $id
		LIMIT 1
	];
  my $query = $Data->{'db'}->prepare($st);
  $query->execute();
	my $dref=$query->fetchrow_hashref();
	$query->finish();
	my $name=$dref->{'strPackageName'} || '';

	my $body=qq[
		<p>Enter the name of the membership package in the box provided and then press the Update button.</p>
		<form action="$Data->{'target'}" method="post">
			<table class="lkTable">
			<tr>
				<td class="label">Name</td>
				<td class="data"><input type="text" name="name" value="$name" size="40" maxlength="50"></td>
			</tr>
			<tr>
				<td class="label">&nbsp;</td>
				<td class="data"><br><br><input type="submit" value=" Update " class = "button proceed-button">	</td>
			</tr>
			</table>
			<input type="hidden" name="a" value="A_MP_U">
			<input type="hidden" name="client" value="].unescape($cl).qq[">
			<input type="hidden" name="lki" value="$id">
		</form>
	];
	return $body;
}

sub update_mempackages	{
	my($Data, $id)=@_;

	my $realmID=$Data->{'Realm'} || 0;
  my $target=$Data->{'target'};
  my $cl  = setClient($Data->{'clientValues'});
	my $assocID=$Data->{'clientValues'}{'assocID'} || $Defs::INVALID_ID;

	my $name=param('name') || '';
  $name=~s/>/&gt;/g;
  $name=~s/</&lt;/g;
	return '' if !$name;
	deQuote($Data->{'db'},\$name);
	my $st='';
  my $audit_type = '';
	if($id)	{
		$st=qq[
			UPDATE tblMemberPackages
			SET strPackageName=$name
			WHERE intRealmID= $realmID
				AND intAssocID = $assocID 
				AND intMemberPackagesID= $id
		];
    $audit_type = 'Update';
	}
	else	{
		$st=qq[
			INSERT INTO tblMemberPackages
							(intAssocID, intRealmID, strPackageName)
			VALUES ($assocID, $realmID,$name)
		];
    $audit_type = 'Add';
	}
  my $query = $Data->{'db'}->prepare($st);
  $query->execute();
  $id = $query->{mysql_insertid} unless ($id);
  if($DBI::err) {
    return '<div class="warningmsg">There was a problem changing that record</div>';
  }
  auditLog($id, $Data, $audit_type, 'Membership Packages');
	return '';
}



1;
