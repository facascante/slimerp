#
# $Header: svn://svn/SWM/trunk/web/admin/AdminCommon.pm 11454 2014-05-01 05:13:22Z ppascoe $
#

package AdminCommon;
require Exporter;
@ISA =	qw(Exporter);
@EXPORT = qw(passportLogins create_selectbox fix_date currency);
@EXPORT_OK = qw(passportLogins create_selectbox fix_date currency );

use lib "..","../..";
use Defs;
use strict;
use CGI qw(escape param);
use AdminPageGen;
use Digest::MD5 qw(md5_base64);
use URI::Escape;

our $BUSINESS_USER_TYPE_SPANZ = 1;

sub create_selectbox {
	#Create HTML Select Box from Hash Ref passed in
	my($data_ref, $current_data, $name, $preoptions,$action, $type)=@_;
	if(!$name)	{return '';}
	if(!$preoptions)	{$preoptions='';}
	if(!$action)	{$action='';}
	my $subBody='';
	my $selected='';
	if($type and $type==3)	{
		for my $i (@{$data_ref})	{
			if ($current_data and $current_data eq $i) {$selected =" SELECTED ";}
			else	{$selected="";}
			$subBody .= qq[ <option $selected value="$i">$i</option>\n ];
		}
	}
	elsif($type and $type==2)	{
		foreach my $i (sort { $data_ref->{$a}[1] <=> $data_ref->{$b}[1] } keys %{$data_ref})       {
			if ($current_data and $current_data ==$i) {$selected =" SELECTED ";}
			else	{$selected="";}
			$subBody .= qq[ <option $selected value="$i">$data_ref->{$i}[0]</option>\n ];
		}
	}
	else	{
		foreach my $i (sort { $data_ref->{$a} cmp $data_ref->{$b} } keys %{$data_ref})       {
			if ($current_data and $current_data eq $i) {$selected =" SELECTED ";}
			else	{$selected="";}
			$subBody .= qq[ <option $selected value="$i">$data_ref->{$i}</option>\n ];
		}
	}
	$subBody=qq[
		<select name="$name" size="1" $action>
			$preoptions
			$subBody
		</select>
	];
	return $subBody;
}

sub fix_date	{
	my($date,%extra)=@_;
	if(exists $extra{NODAY} and $extra{NODAY})	{
		my($mm,$yyyy)=$date=~m:(\d+)/(\d+):;
		if(!$mm or !$yyyy)	{	return ("Invalid Date",'');}
		if($yyyy <100)	{$yyyy+=2000;}
		return ("","$yyyy-$mm-01");
	}
	my($dd,$mm,$yyyy)=$date=~m:(\d+)/(\d+)/(\d+):;
	if(!$dd or !$mm or !$yyyy)	{	return ("Invalid Date",'');}
	if($yyyy <100)	{$yyyy+=2000;}
	return ("","$yyyy-$mm-$dd");
}


sub currency  {
  $_[0]||=0;
  my $text= sprintf "%.2f",$_[0];
  $text= reverse $text;
  $text=~s/(\d\d\d)(?=\d)(?!\d*\.)/$1,/g;
  return scalar reverse $text;
}

sub passportLogins
{
  my($db, $entityTypeID, $entityID)=@_;
  my $st =  qq[
  SELECT
                        intPassportID,
                        intReadOnly,
                        DATE_FORMAT(dtLastLogin,'%d %M %Y') as dtLastLogin_FMT
                FROM
                        tblPassportAuth
                WHERE
                        intEntityTypeID = ?
                        AND intEntityID = ?
        ];
        my $q = $db->prepare($st);
        $q->execute(
                $entityTypeID,
                $entityID,
        );
  my @authlist = ();
        my %authdetails = ();
  while(my($DB_intPassportID, $readonly, $lastlogin)=$q->fetchrow_array()) {
                $authdetails{$DB_intPassportID} = [$readonly, $lastlogin];
    push @authlist, $DB_intPassportID;
	}

 my $PassportData = undef;
  if(@authlist) {
    my $passport = new Passport(
      db => $db,
    );
    $PassportData = $passport->bulkdetails(\@authlist);
  }
        my $memberlist = '';
  if($PassportData) {
    for my $member (
      sort {
        $a->{'FamilyName'} cmp $b->{'FamilyName'}
        or $a->{'FirstName'} cmp $b->{'FirstName'}
      }
      @{$PassportData}
    ) {
      my $name = join (' ',($member->{'FirstName'} || ''), ($member->{'FamilyName'} || ''));
      next if !$member->{'Email'};
      next if $member->{'Status'} != 2;
                        my $memberID = $member->{'PassportID'};
# Email => $member->{'Email'},
 #                               ReadOnly => $authdetails{$member->{'PassportID'}}[0] || 0,
  #                              LastLogin => $authdetails{$member->{'PassportID'}}[1] || '',

                        $memberlist.=qq[
                                <tr>
                                <td>$name</td>
                                <td>$member->{'Email'}</td>
				<td>$authdetails{$member->{'PassportID'}}[0] </td>
				<td>$authdetails{$member->{'PassportID'}}[1]</td>
                                <td><a href="$Defs::PassportURL/admin/member_admin.cgi?pID=$memberID&a=P_login">Login</a></td>
				</tr>
];
                }
}
return $memberlist;
}

# Routines to check that the person has not played around with the query strings

sub create_hash_qs {
	my ($realm_id,$node_id,$assoc_id,$club_id,$member_id) = @_;
	
	my $hash_string = create_hash($realm_id,$node_id,$assoc_id,$club_id,$member_id);

	$hash_string = uri_escape($hash_string);
	
    return $hash_string;
}

sub create_hash {
	my ($realm_id,$node_id,$assoc_id,$club_id,$member_id) = @_;

	my $SHARED_SECRET = 'MIGHTY_DEMONS'; #Not a term used very often
	my $hash_string = md5_base64($realm_id . '-' . $node_id . '-' . $assoc_id . '-' . $club_id . '-' . $member_id);

    return $hash_string;
}

sub verify_hash {
	my $temp_hash;
	
	my $realm_id = param('realmID') || 0;
  	my $node_id = param('nodeID') || 0;
  	my $assoc_id = param('intAssocID') || param('assocID')  || param('entityID') || param('aID') || param("swmid") || 0;
	my $club_id = param("clubID") || 0;
  	my $member_id = param('useID') || 0;
  	my $qs_hash = param('hash') || 0;
	
	if (AdminPageGen::get_user_level() > 10) {
		return 1;		
	}
	elsif ($realm_id == 0 && $node_id == 0 && $assoc_id == 0 && $club_id == 0 && $member_id == 0) {
		# must be a base screen, so nothing to check
		return 1;
	}
	else {
		$temp_hash = create_hash($realm_id,$node_id,$assoc_id,$club_id,$member_id);
		
		if ($temp_hash eq $qs_hash) {
			return 1;
		}
		else {
			return 0;
		}		
	}

}

sub get_realmid {
	
	#Added PP 2014-03-12 Allows the Admin screen to limit users to specific Realms
	our %access_realmid = (
		#AFL
		tcostanzo => '2,39',
				);

	return $access_realmid{get_username()};

}

sub get_username {
	
	my $username="devel";
	if($Defs::DevelMode!=1){
		$username =  $ENV{'REMOTE_USER'} || 'trialacc' || return 0;
	}

	return $username;

}

1;


