#
# $Header: svn://svn/SWM/trunk/web/AuthMaintenance.pm 8492 2013-05-16 02:20:28Z cgao $
#

package AuthMaintenance;

require Exporter;
@ISA = qw(Exporter);
@EXPORT = qw(handleAuthMaintenance);
@EXPORT_OK = qw(handleAuthMaintenance);

use strict;
use Reg_common;
use Utils;
use CGI qw(unescape param popup_menu);
use AuditLog;
use TTTemplate;
#use Passport;
use GridDisplay;

sub handleAuthMaintenance {
	my (
		$action, 
		$Data, 
		$entityTypeID, 
		$entityID
	) = @_;
	my $client = setClient($Data->{'clientValues'});
	my $resultHTML  = q{};
	my $title       = 'User Management';
	my $ret         = q{};

	if(!$entityTypeID or !$entityID)	{
		$entityTypeID = $Data->{'clientValues'}{'currentLevel'};
		$entityID = getID($Data->{'clientValues'}, $entityTypeID);
	}
	my $typename = $Defs::LevelNames{$entityTypeID} || '';
	$title .= ' - ' . $typename;

	if ($action =~/^AM_d/) {


		$resultHTML .= auth_delete(
			$Data,
			$entityTypeID, 
			$entityID, 
			$client,
		);
	}
	elsif ($action =~/^AM_a/) {
		$resultHTML .= auth_add (
			$Data,
			$entityTypeID, 
			$entityID, 
			$client,
		);
	  $resultHTML.=$ret;
		$action = 'FC_C_d';
	}
	$resultHTML .= auth_list (
		$Data,
		$entityTypeID, 
		$entityID, 
		$client,
	);
	
  return (
		$resultHTML, 
		$title
	);
}

sub auth_list {
	my (
		$Data,
		$entityTypeID, 
		$entityID, 
		$client,
	) = @_;

	my $db = $Data->{'db'};
	my $st = qq[
		SELECT
			intPassportID,
			intReadOnly,
			DATE_FORMAT(dtLastLogin,'%Y-%m-%d (%d %M %Y)') as dtLastLogin_FMT
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
	my $addaction = 'AM_a';
	my $addaction2 = '';
	my $delaction = 'AM_d';
	my $delaction2 = '';
	if($entityTypeID == $Defs::LEVEL_VENUE)	{
	$addaction = 'VENUE_USER';
		$addaction2 = 'AM_a';
		$delaction = 'VENUE_USER';
		$delaction2 = 'AM_d&venueID='.$entityID;
	}
	my @outputdata = ();
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
      next if !$member->{'Status'} == 2;
			push @outputdata, {
				id => $member->{'PassportID'} || next,
				PassportID => $member->{'PassportID'} || next,
				Name => $name,
				Email => $member->{'Email'},
				ReadOnly => $authdetails{$member->{'PassportID'}}[0] || 0,
				AccessLevel => $authdetails{$member->{'PassportID'}}[0] ? 'Restricted Access' : 'Full',
				LastLogin => $authdetails{$member->{'PassportID'}}[1] || '',
				DeleteLink => qq[<a href = "$Data->{'target'}?a=$delaction&amp;a2=$delaction2&amp;id=$member->{'PassportID'}&amp;client=$client&amp;id=$member->{'PassportID'}" onclick = "return confirm('Are you sure you want to remove $name?');">Delete</a>],
			};
    }
  }
	my @headers = (
    {
      name =>   $Data->{'lang'}->txt('Name'),
      field =>  'Name',
    },
    {
      name =>   $Data->{'lang'}->txt('Email'),
      field =>  'Email',
    },
    {
      name =>   $Data->{'lang'}->txt('Access'),
      field =>  'AccessLevel',
    },
    {
      name =>   $Data->{'lang'}->txt('Last Login'),
      field =>  'LastLogin',
	},
    {
      name =>   $Data->{'lang'}->txt(' '),
      field =>  'DeleteLink',
			type => 'HTML',
    },
	);

  my $grid  = showGrid(
    Data => $Data,
    columns => \@headers,
    rowdata => \@outputdata,
    gridid => 'grid',
    width => '99%',
  );

	my $body = runTemplate(
		$Data, 
		{
			AuthList => \@outputdata,
			Grid => $grid,
			client => $client,
			Target => $Data->{'target'},
			TypeName => $Defs::LevelNames{$entityTypeID} || '',
			AddAction => $addaction,
			AddAction2 => $addaction2,
			ID => $entityID,
		},
		'auth/authlist.templ',
	);

	return $body;
}

sub auth_delete {
	my (
		$Data,
		$entityTypeID, 
		$entityID, 
		$client,
	) = @_;

	my $db = $Data->{'db'};

	my $id = param('id') || '';
	return '' if !$id;
	
	my $st = qq[
		DELETE FROM tblPassportAuth
		WHERE 
			intEntityTypeID = ?
			AND intEntityID = ?
			AND intPassportID = ?
	];
	my $q = $db->prepare($st);
	$q->execute(
		$entityTypeID, 
		$entityID, 
		$id,
	);
	$q->finish();
auditLog($id, $Data, 'Delete', 'User Management');
	return qq[<div class = "OKmsg">User access removed</div>];
}

sub auth_add {
	my (
		$Data,
		$entityTypeID, 
		$entityID, 
		$client,
	) = @_;

	my $db = $Data->{'db'};

	my $newemail = param('newemail') || '';
	my $readonly = param('readonly') || 0;
	return '' if !$newemail;
	return '' if !$entityTypeID;
	return '' if !$entityID;
	my $assocID = $Data->{'clientValues'}{'assocID'} || 0;
	$assocID = 0 if $assocID < 0;
	
	my $passport = new Passport(
		db => $db,
	);
	my($DB_intMemberID, $status) = $passport->isMember($newemail);
	$DB_intMemberID = 0 if $status != 2;

	if($DB_intMemberID) {

		my $st = qq[
			INSERT INTO tblPassportAuth	(
				intEntityTypeID,
				intEntityID,
				intPassportID,
				intAssocID,
				dtCreated,
				intReadOnly
			)
			VALUES (
				?,
				?,
				?,
				?,
				NOW(),
				?
			)
		];
		my $q = $db->prepare($st);
		$q->execute(
			$entityTypeID, 
			$entityID, 
			$DB_intMemberID,
			$assocID,
			$readonly,
		);
		$q->finish();

auditLog($DB_intMemberID, $Data, 'Add', 'User Management');
		$passport->addModule('SPMEMBERSHIPADMIN', $newemail);
	}
	else	{
		return qq[<div class = "warningmsg">I'm sorry I cannot find that user</div>];
	}

	return qq[<div class = "OKmsg">User access granted</div>];
}
1;
