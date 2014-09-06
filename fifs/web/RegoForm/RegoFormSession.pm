#
# $Header: svn://svn/SWM/trunk/web/RegoForm/RegoFormSession.pm 9865 2013-11-14 00:42:54Z sregmi $
#

package RegoFormSession;
require Exporter;

use strict;

use lib '.', '..', '../..';

use CGI qw(param unescape Vars);
use Reg_common;
use DeQuote;
use Utils;
use MD5;

sub new {

  my $this = shift;
  my $class = ref($this) || $this;
  my %params=@_;
	my $db = $params{'db'} || undef;
  my $self ={};
  ##bless selfhash to class
  bless $self, $class;

	$self->{'sessionkey'} = $params{'key'} || '';
	$self->{'formID'} = $params{'FormID'} || '';
	$self->{'AdultNumber'} = 0;
  $self->{'ChildNumber'} = 0;
  $self->{'Members'} = ();

	$self->load($db) if($self->{'sessionkey'} and $db);
	$self->_createSessionKey() if !$self->{'sessionkey'};
  return $self;
}


sub id {
  my $self = shift;
	return $self->{'sessionkey'} || 0;
}

sub formID {
  my $self = shift;
	return $self->{'formID'} || 0;
}

sub total {
  my $self = shift;
  return $self->{'TotalAdults'}+$self->{'TotalChildren'};
}

sub setTotalNumbers	{
  my $self = shift;
	my($db, $adults, $children) = @_;
	$adults ||= 0;
	$children ||= 0;
	if(!$self->{'DBRows'})	{
		#No record in the table as yet to store this against
		$self->addToSession(
			db => $self->{'db'},
			FormID => $self->formID(),
		);
	}

	my $st = qq[
		UPDATE tblRegoFormSession
		SET 
			intTotalAdult = ?,
			intTotalChild = ?
		WHERE
			strSessionKey = ?
	];
	my $q = $db->prepare($st);
	$q->execute(
		$adults,
		$children,
		$self->{'sessionkey'}
	);

	$self->{'TotalAdults'} = $adults || 0;
	$self->{'TotalChildren'} = $children ||  0;
}

sub load {
  my $self = shift;
  my($db)=@_;
	return undef if !$db;
	return undef if !$self->{'sessionkey'};

	my $st = qq[
		SELECT 
			intRegoFormSessionID,
			strSessionKey,
			intMemberID,
			intTempID,
			intFormID,
			intNumber,
			intChild,
			tTimestamp,
			strTransactions,
			intTotalAdult,
			intTotalChild,
			intStatus
		FROM 
			tblRegoFormSession
		WHERE strSessionKey = ?
		ORDER BY intNumber
	];
	my $q = $db->prepare($st);
	$q->execute($self->{'sessionkey'});
	$self->{'AdultNumber'} = 0;
	$self->{'ChildNumber'} = 0;
	$self->{'TotalAdults'} = 0;
	$self->{'TotalChildren'} = 0;
	$self->{'Members'} = ();
	while(my $dref = $q->fetchrow_hashref())	{
		$self->{'DBRows'} = 1;
		$self->{'FormID'} = $dref->{'intFormID'} || 0;
		$self->{'TotalAdults'} ||= $dref->{'intTotalAdult'} || 0;
		$self->{'TotalChildren'} ||= $dref->{'intTotalChild'} || 0;
		push @{$self->{'Members'}}, {
			intMemberID => $dref->{'intMemberID'},
			intTempID => $dref->{'intTempID'},
			adultNumber => (!$dref->{'intChild'} ? ++$self->{'AdultNumber'}: 0),
			childNumber => ($dref->{'intChild'} ? ++$self->{'ChildNumber'}: 0),
			transactions => [split(',',$dref->{'strTransactions'})],
		} if ($dref->{'intMemberID'} or $dref->{'intTempID'});
	}
  return 1;
}

sub getMemberSessionNum {
  my $self = shift;
	my ($memberID) = @_;
	return (0,0) if !$memberID;
	for my $i (@{$self->{'Members'}})	{
		return (
			$self->{'AdultNumber'} || 0, 
			$self->{'ChildNumber'} || 0,
		) if $i->{'intMemberID'} == $memberID;

	}
	return (0,0);
}
	

sub _createSessionKey	{
  my $self = shift;
	
  my $m = new MD5;
	$m->reset();
	$m->add($$ , time() , rand(time) );
	my $key = $m->hexdigest();
	$self->{'sessionkey'} = $key;
	return $key;
}

sub getSessionMemberDetails	{
  my $self = shift;
	my ($db) = @_;
	
	return undef if !$db;
	return undef if !scalar($self->{'Members'});
	my $mID =  $self->{'Members'}[0]{'intMemberID'} || 0;
	return undef if !$mID;
	my $st = qq[
		SELECT 
			strAddress1,
			strAddress2,
			strSuburb,
			strState,
			strPostalCode,
			strCountry,
			strPhoneHome,
			strEmail,
			strP1FName,
			strP1SName,
			strP2FName,
			strP2SName,
			strP1Email,
			strP2Email,
			strP1Phone,
			strP2Phone,
			intP1AssistAreaID,
			intP2AssistAreaID
		FROM tblMember
		WHERE intMemberID = ?
	];
	my $q = $db->prepare($st);
	$q->execute($mID);
	my $dref = $q->fetchrow_hashref();
	$q->finish();

	return $dref || undef;
}

sub setSessionCookie {
  my $self = shift;
	return [
		$Defs::COOKIE_REGFORMSESSION,
		$self->{'sessionkey'},
		'+1h',
	];

}

sub resetSessionCookie {
  my $self = shift;
    my ($db) = @_;
    #following command will remove all the records belong to this session fron tblRegoFormSession 
    # is it safe to remove them or we need them??
=c
    $self->cleanupForm(
            $db,
            -1,
        );
=cut
      return [
        $Defs::COOKIE_REGFORMSESSION,
        "00",
        '-1h',
    ];

}

sub getMultiPersonSelector {
  my $self = shift;
	
	my(
        $name,
        $allowMultiAdults, 
        $allowMultiChild,
        $current_selection,
	) = @_;

	return '' if !$name;
	return '' if (!($allowMultiAdults or $allowMultiChild));
	my @options = ();
	if($allowMultiAdults)	{
		my $newnum = $self->{'AdultNumber'} + 1;
		push @options, [ "adult", "Adult ($newnum)"];
	}
	if($allowMultiChild)	{
		my $newnum = $self->{'ChildNumber'} + 1;
		push @options, [ "child", "Child ($newnum)"];
	}
	my $optionstr = '';
	my $cnt = 0;

	for my $i (@options)	{

        my $checked;
        if ($current_selection) {
            if ($i->[0] eq $current_selection) {
                $checked = ' CHECKED ';
            }
        }
        else {
            $checked = $cnt == 0 ? ' CHECKED ' : q{};
        }


		$optionstr .= qq{<input type="radio" name="$name" value="$i->[0]" id="d_$cnt$name" $checked><label for="d_$cnt$name">$i->[1]</label>};
		$cnt++;
	}
	return qq[ <div class="multiperson-block">$optionstr</div>	];	
}

sub setTempID {
    
    my $self = shift;
    my %params = @_;
    my $db = $params{'db'} || return undef;
    my $memberID = $params{'MemberID'} || 0;
    my $formID = $params{'FormID'} || return undef;
}
sub addToSession {
  my $self = shift;
	my %params = @_;

	my $db = $params{'db'} || return undef;
	my $memberID = $params{'MemberID'} || 0;
	my $isTemp = $params{'isTemp'} || 0;
	my $formID = $params{'FormID'} || return undef;
	my $status = $params{'Status'} || 0;
	my $child = $params{'Child'} || 0;
	if(!$child)	{
		my $next = ($self->getNextRegoType())[0] || '';
		$child = 1 if $next=~/Child/;
	}
	my $intRealID = $isTemp ? 0 : $memberID;
	my $intTempID = $isTemp ? $memberID : 0;
	my $txns = $params{'Transactions'} || ();
  my $txnlist = $txns ? join (',',@{$txns}) : '';
	if(!$memberID
		and $self->{'FormID'}
		and $self->{'DBRows'}
		and !$self->{'Members'})	{
		#We have loaded the session and there is already a record with no memberID
	
		return 1;
	}

	my $st = qq[
		INSERT INTO tblRegoFormSession (
			strSessionKey,
			intMemberID,
            intTempID,
			intFormID,
			intNumber,
			intChild,
			intStatus,
			tTimestamp,
			strTransactions,
			intTotalAdult,
			intTotalChild
		)
		VALUES (
			?,	
			?,	
			?,	
			?,	
			?,	
			?,	
			?,	
			NOW(),	
			?,
			?,
			?
		)
	];
	my $number = $self->{'Members'} 
		? ((scalar(@{$self->{'Members'}})+1) || 0)
		: 1;
	my $q = $db->prepare($st);
	$q->execute(
		$self->{'sessionkey'},
		$intRealID,
        $intTempID,
		$formID,
		$number,
		$child,
		$status,
		$txnlist,
		$self->{'TotalAdults'} || 0,
		$self->{'TotalChildren'} ||  0,
	);
	if($memberID or $intTempID)	{
		$self->{'AdultNumber'}++ if !$child;
		$self->{'ChildNumber'}++ if $child;
		push @{$self->{'Members'}}, {
			intMemberID => $intRealID,
			intTempID => $intTempID,
            isTemp =>$isTemp,
			adultNumber => $self->{'AdultNumber'} || 0,
			childNumber => $self->{'ChildNumber'} || 0,
			transactions => $txns,
		};
	}

	$q->finish();
	return 1;
}

sub getTransactions {
  my $self = shift;
	
	my @txns = ();
	for my $m (@{$self->{'Members'}})	{
        my $ID = $m->{'isTemp'}? $m->{'intTempID'} : $m->{'intMemberID'};
		for my $t (@{$m->{'transactions'}})	{
			push @txns, [ $ID, $t];
		}
	}
	return \@txns;
}

sub cleanupForm {
	#To make sure that a session is only used in one form at a time
	#If attempting to use a session on multiple forms it will delete the 
  #previous session data
  my $self = shift;
	my($db, $formID) = @_;
	return 0 if !$formID;
	return 0 if !$self->{'sessionkey'};
  #return 1 if !scalar($self->{'Members'});

	my $st = qq[
		DELETE FROM tblRegoFormSession
		WHERE strSessionKey = ?
			AND intFormID != ?
	];	
	my $q = $db->prepare($st);
	$q->execute(
		$self->{'sessionkey'},
		$formID,
	);
	$self->{'DBRows'} = 0;
	return 1;
}

sub getRegoType	{
  my $self = shift;
	my($type) = @_;
	$type ||= '';
	my $num = 0;
	if($type eq 'adult')	{
		my $num = ++$self->{'AdultNumber'};
		$num = 'Plus' if $num > 3;
		return "Adult$num";
	}
	elsif($type eq 'child')	{
		my $num = ++$self->{'ChildNumber'};
		$num = 'Plus' if $num > 3;
		return "Child$num";
	}
	return '';
}

sub getNextRegoType	{
  my $self = shift;
	my $num = 0;

	if($self->{'AdultNumber'} < $self->{'TotalAdults'})	{
		my $num = $self->{'AdultNumber'} + 1;
		my $numstring = "Adult $num";
		$num = 'Plus' if $num > 3;
		return ("Adult$num", $numstring, $self->{'TotalAdults'});
	}
	elsif($self->{'ChildNumber'} < $self->{'TotalChildren'})	{
		my $num = $self->{'ChildNumber'} + 1;
		my $numstring = "Child $num";
		$num = 'Plus' if $num > 3;
		return ("Child$num", $numstring, $self->{'TotalChildren'});
	}
	return ('','','');
}

sub MemberNames {
  my $self = shift;
  my($db, $return_array)=@_;
	return undef if !$db;
	return undef if !$self->{'sessionkey'};
	return undef if !$self->{'Members'} ;
	return undef if !scalar(@{$self->{'Members'}});

	$return_array ||= 0;
	my @ids = ();
	my %idToNumber = ();
	for my $i (@{$self->{'Members'}})	{
		push @ids, $i->{'intMemberID'};
		$idToNumber{$i->{'intMemberID'}} = [$i->{'adultNumber'}, $i->{'childNumber'}];
	}	
	my $memlist = join(',',@ids);
	return undef if !$memlist;

	my $st = qq[
		SELECT 
			intMemberID,
			strFirstname,
			strSurname,
      ATH.strUsername,
      ATH.strPassword
    FROM tblMember as M
      LEFT JOIN tblAuth as ATH ON (
        ATH.intID = M.intMemberID 
        AND ATH.intLevel = $Defs::LEVEL_MEMBER
      )

		WHERE intMemberID IN ($memlist)
		ORDER BY strSurname, strFirstname
	];
	my $q = $db->prepare($st);
	$q->execute();
	my %memdata = ();
	my @memdata_array = ();
	while(my $dref = $q->fetchrow_hashref())	{
		my $mID = $dref->{'intMemberID'} || next;
		my $type = $idToNumber{$mID}[0]
			? 'Adult '.$idToNumber{$mID}[0]
			: 'Child '.$idToNumber{$mID}[1];
		$memdata{$mID} = {
			FirstName => $dref->{'strFirstname'} || '',
			Surname => $dref->{'strSurname'} || '',
			Type => $type || '',
			MemberID => $mID,
			Username => $Defs::LEVEL_MEMBER.$dref->{'strUsername'} || '',
			Password => $dref->{'strPassword'} || '',
		};
		push @memdata_array, $memdata{$mID};
	}
	return \@memdata_array if $return_array;
  return \%memdata;
}

sub isComplete {
  my $self = shift;

	if(!$self->{'TotalAdults'}
		and !$self->{'TotalChildren'}
	)	{
		#Not using  multi reg
		return 1;
	}

	if(
		$self->{'AdultNumber'} >= $self->{'TotalAdults'}
		and $self->{'ChildNumber'} >= $self->{'TotalChildren'}
	)	{
		return 1;
	}
	return 0;
}

sub Summary {
  my $self = shift;

	my($db) = @_;
	return undef if !$db;
	return undef if $self->isComplete();
	$self->load($db);
	my $members = $self->MemberNames($db);
  my @txns = ();
  for my $m (@{$self->{'Members'}}) {
    for my $t (@{$m->{'transactions'}}) {
      push @txns, $t;
    }
  }

	my $txn_list = join(',',@txns);
	my %txn_info = ();
	#Get transaction details
	if($txn_list)	{
		my $st = qq[
			SELECT 
				T.intTransactionID,
				T.curAmount,
				P.strName
			FROM 
				tblTransactions AS T
				INNER JOIN tblProducts AS P
					ON T.intProductID = P.intProductID
			WHERE 
				T.intTransactionID IN ($txn_list)
		];
		my $q = $db->prepare($st);
		$q->execute();
		while(my $dref = $q->fetchrow_hashref())	{
			$txn_info{$dref->{'intTransactionID'}} = {
				amount => $dref->{'curAmount'} || 0,
				name => $dref->{'strName'} || '',
			};
		}
	}

	my @summary = ();
	my $totalcost = 0;
	for my $m (@{$self->{'Members'}})	{
		my $mID = $m->{'intMemberID'} || next;
		my %member_transactions = ();
		my $membercost = 0;
    for my $t (@{$m->{'transactions'}}) {
			$member_transactions{$t} = $txn_info{$t};
			$totalcost += $txn_info{$t}{'amount'} || 0;
			$membercost += $txn_info{$t}{'amount'} || 0;
    }
		
		my %row = (
			Details => $members->{$mID},
			Transactions => \%member_transactions,
			MemberCost => $membercost,	
			ItemCount => scalar(@{$m->{'transactions'}}),
		);
		push @summary, \%row;
	}
	my %summary = (
		Members => \@summary,
		TotalCost => $totalcost || 0,
	);
	return \%summary;
}


sub getSessionSequenceNumber {
	my $self = shift;

	return (($#{$self->{'Members'}} || 0) + 1) || 1;

}

sub loadTempData {
    my $self = shift;
    my ($db) = @_;
    my $sessionkey = $self->id();
    return undef if !$db;
    return undef if !$sessionkey;
    
    my @tempMembers = ();
    
    
    my $st = qq[ SELECT 
                    *
                 FROM
                    tblTempMember
                 WHERE
                    strSessionKey = ?    
    ];
    my $q = $db->prepare($st);
    $q->execute($sessionkey);
    
    while(my $dref = $q->fetchrow_hashref())    {
        
        push @tempMembers, {
            Username => "-",
            tID => $dref->{'intTempMemberID'},
            Password => "-",
          
        } if ($dref->{'intTempMemberID'});
    }
  return \@tempMembers;
}
# FF We need to update session table with real member ID
# it's not called anywhere yet
sub setRealMemberID {
  my $self = shift;
    my($db, $intTempID, $intRealID )= @_;
    my $st =qq[UPDATE 
                    tblRegoFormSession
                SET         
                    intMemberID = ?
               WHERE 
                    intTempID = ?
            ];
    my $q = $db->prepare($st) or query_error($st);
    $q->execute($intRealID,$intTempID);
    
}

1;
