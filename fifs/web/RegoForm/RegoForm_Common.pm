#
# $Header: svn://svn/SWM/trunk/web/RegoForm/RegoForm_Common.pm 8950 2013-07-15 06:24:58Z fkhezri $
#

package RegoForm_Common;
require Exporter;
@ISA =  qw(Exporter);
@EXPORT = qw(ProcessRegoFormPermissions generateRandomPassword _getTeamCompNames);
@EXPORT_OK = qw(ProcessRegoFormPermissions generateRandomPassword _getTeamCompNames);

use strict;

use lib "..","../..";
use Utils;

sub ProcessRegoFormPermissions	{
	my(
		$perms, 
		$Fields, 
	) = @_;
	my %newperms=();
	for my $f (keys %{$perms})	{

	#	next( if $perms->{$f}{'type'} ne 'Field';
		my $v = $perms->{$f}{'perm'} || 'Editable';
		if(
			!$perms->{$f}{'type'}
			or $perms->{$f}{'type'} ne 'Field')	{
			$v = 'Editable' 
		}

		if(	
			$v eq 'Hidden'
			or $v eq 'ChildDefine'
		)	{
			$newperms{$f}=0;	
			next;	
		}
		elsif($v eq 'ReadOnly')	{ $Fields->{'fields'}{$f}{'readonly'}=1; }
		elsif($v eq 'Compulsory')	{ $Fields->{'fields'}{$f}{'compulsory'}=1; }
		elsif($v eq 'AddOnlyCompulsory')	{ 
			$Fields->{'fields'}{$f}{'noedit'}=1; 
			$Fields->{'fields'}{$f}{'compulsory'}=1; 
		}
		$newperms{$f}=1;	
	}
	return \%newperms;
}

sub generateRandomPassword {
	#Generate random password
	srand();
	my $salt=(rand()*100000);
	my $salt2=(rand()*100000);
	my $k=crypt($salt2,$salt);
	#Clean out some rubbish in the key
	$k=~s /['\/\.\%\&]//g;
	$k=substr($k,0,8);
	$k=lc $k;
	return $k;
}

sub _getTeamCompNames {
    my($Data, $compID, $teamID, $assocID, $clubID) = @_;

    my $teamname = '';
    my $compname = '';
    my $assocname = '';
    my $clubname = '';
    my $st = '';
    if($teamID) {
        $st = qq[ SELECT strName FROM tblTeam WHERE intTeamID = ? ];
        my $q= $Data->{'db'}->prepare($st);
        $q->execute($teamID);
        ($teamname) = $q->fetchrow_array();
    }
    if($compID) {
        $st = qq[ SELECT strTitle FROM tblAssoc_Comp WHERE intCompID = ? ];
        my $q= $Data->{'db'}->prepare($st);
        $q->execute($compID);
        ($compname) = $q->fetchrow_array();
    }
    if($assocID) {
        $st = qq[ SELECT strName FROM tblAssoc WHERE intAssocID = ? ];
        my $q= $Data->{'db'}->prepare($st);
        $q->execute($assocID);
        ($assocname) = $q->fetchrow_array();
    }
    if($clubID) {
        $st = qq[ SELECT strName FROM tblClub WHERE intClubID = ? ];
        my $q= $Data->{'db'}->prepare($st);
        $q->execute($clubID);
        ($clubname) = $q->fetchrow_array();
    }
    return(
        $teamname || '',
        $compname || '',
        $assocname || '',
        $clubname || '',
    );
}

1;
