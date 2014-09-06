package UserObj;
require Exporter;
@ISA =  qw(Exporter);

use lib "..","../..";
use Defs;
use UserHash;
use Utils;

use strict;

sub new {
  my $this = shift;
  my $class = ref($this) || $this;
  my %params = @_;
  my $self = {};
  $self->{'ID'}=$params{'id'};
  $self->{'db'}=$params{'db'};
  bless $self, $class;
  if($self->{'ID'}) {
    $self->load();
  }
  return $self;
}

sub ID  {
  my $self = shift;
  return $self->{'ID'};
}

sub load {
  my $self = shift;
  my %params = @_;
  my $id = $self->ID() || 0;
  my $email = $params{'email'} || '';
  return undef if(!$id and !$email);

  $self->_load_Details(email => $email);
  return undef if !$self->{'DBData'};

  return 1;
}

sub update {
  my $self = shift;
  my($updatedata) = @_;
  for my $k (keys %{$updatedata})  {
    $self->{'DBData'}{$k} = $updatedata->{$k};
  }
  $self->write();
}

sub write {
  my $self = shift;
  if($self->ID())  {
    #Update User
    
    my $st=qq[
      UPDATE tblUser
      SET
        email = ?,
        firstName = ?,
        familyName = ?,
        status = ?
      WHERE userId = ?
    ];
    my $q = $self->{'db'}->prepare($st);
     $q->execute(
      $self->{'DBData'}{'email'},
      $self->{'DBData'}{'firstName'},
      $self->{'DBData'}{'familyName'},
      $self->{'DBData'}{'status'},
      $self->ID()
    );
  }
  else  {
    # Add New User
    
    my $confirmkey = newHash(time());
    $confirmkey =~ s/[^0-9a-zA-Z]//g;
    $confirmkey = substr($confirmkey,0,20);
    $self->{'DBData'}{'confirmKey'} = $confirmkey || '';
    my $st=qq[
      INSERT INTO tblUser (
        email,
        firstName,
        familyName,
        status,
        confirmKey,
        created
      )
      VALUES (
        ?,
        ?,
        ?,
        $Defs::USER_STATUS_NOTCONFIRMED,
        ?,
        NOW()
      )
    ];
    my $q = $self->{'db'}->prepare($st);
    $q->execute(
      $self->{'DBData'}{'email'},
      $self->{'DBData'}{'firstName'},
      $self->{'DBData'}{'familyName'},
      $self->{'DBData'}{'confirmKey'},
    );
    $self->{'ID'}=$q->{'mysql_insertid'};
    $self->{'DBData'}{'userId'} = $q->{'mysql_insertid'};

    if (!$DBI::errstr) {
    }
  }
  if ($DBI::errstr) {
    print STDERR qq[ERROR:: $DBI::errstr \n\n];
  }
}

sub setStatus  {
  my $self = shift;
  my($newstatus) = @_;
  my $id = $self->ID() || 0;
  return undef if !$id;
  return undef if !$newstatus;
  return undef if $newstatus !~/^\d+$/;

  $self->update(
    {
      status => $newstatus,
    }
  );
  return $newstatus;  
}

sub setPassword {
  my $self = shift;
  my($newpassword) = @_;
  my $id = $self->ID() || 0;
  return undef if !$id;
  return undef if !$newpassword;

  my $hash  = newHash($id.$newpassword);
  my $st = qq[
    INSERT INTO tblUserHash (
      userId,
      passwordHash
    )
    VALUES (
      ?,
      ?
    )
    ON DUPLICATE KEY UPDATE passwordHash = ?, strPasswordChangeKey = '' 
  ];
  
  my $q = $self->{'db'}->prepare($st);
  $q->execute(
    $id,
    $hash,
    $hash,
  );
  $self->{'DBData'}{'passwordHash'} = $hash;
  return 1;
}

# Accessors ------------------------------
#
 #Generic Accessor
sub getValue {
  my $self = shift;
  my ($field) = @_;
  return undef if !$field;
  return $self->{'DBData'}{$field};
}

sub setValue {
  my $self = shift;
  my ($field, $value) = @_;
  return undef if !$field;
  $self->{'DBData'}{$field} = $value;
  return 1;
}

 #Specific Accessor

sub Name {
  my $self = shift;
  return $self->FullName();
}

sub FirstName {
  my $self = shift;
  return $self->{'DBData'}{'firstName'} || '';
}

sub FamilyName {
  my $self = shift;
  return $self->{'DBData'}{'familyName'} || '';
}

sub FullName {
  my $self = shift;
  my $name = join(' ',$self->FirstName(), $self->FamilyName());
  return $name;
}

sub Email  {
  my $self = shift;
  return $self->{'DBData'}{'email'} || '';
}

sub Status {
  my $self = shift;
  return $self->{'DBData'}{'status'} || $Defs::USER_STATUS_INVALID
} 
#### Setting a new password change key ##### 
sub getPasswdChangeKey {
    my $self = shift; 
    my $id = $self->ID() || 0;
    return undef if(!$id); 
    
    my $query = "UPDATE tblUserHash SET strPasswordChangeKey = ? WHERE userID = ?";
    my $sth = $self->{'db'}->prepare($query);
    my $url_key = $self->_generateConfirmKey();
    $sth->execute($url_key,$id);
    return $url_key || '';    
}

 # ---- Internal functions
sub _load_Details {
  my $self = shift;
  my $id = $self->ID() || 0;
  my %params = @_;
  my $email = $params{'email'} || '';
  return undef if(!$id and !$email);

  my $field = '';

  my $value = '';
  if($id)  {
    $field = 'P.userId';
    $value = $id;
  }
  elsif($email)  {
    $field = 'P.email';
    $value = $email;
  }
  return undef if !$value;

  my $st = qq[ 
    SELECT P.userId AS PID, 
      P_H.*,
      P.*
    FROM tblUser AS P
      LEFT JOIN tblUserHash AS P_H ON (
        P.userId = P_H.userId  
      )
    WHERE 
      $field = ?
      AND status <> $Defs::USER_STATUS_DELETED
  ];
  my $q = $self->{'db'}->prepare($st);
  $q->execute($value);
  my $dref=$q->fetchrow_hashref();
  $q->finish();
  return undef if !$dref;
  for my $k (keys %{$dref})  {
    $self->{'DBData'}{$k} = $dref->{$k};
  }
  $self->{'ID'} = $dref->{'PID'};
  
  return 1;
}



sub _generateConfirmKey {
  my $confirmkey='';
  srand(time() ^ ($$ + ($$ << 15)) );
  my $salt=(rand()*100000);
  my $salt2=(rand()*100000);
  $confirmkey=crypt($salt2,$salt);
  #Clean out some rubbish in the key
  $confirmkey=~s /['\/\.\%\&]//g;
  $confirmkey=substr($confirmkey,0,30);
  return $confirmkey;
}



1;
