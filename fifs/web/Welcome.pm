#
# $Header: svn://svn/SWM/trunk/web/Welcome.pm 10386 2014-01-07 22:33:19Z tcourt $
#

package Welcome;
require Exporter;

@ISA =  qw(Exporter);
@EXPORT = qw(getWelcomeText handle_welcome);

use strict;
use CGI qw(param unescape);
use Reg_common;
use Changes qw(getLatestChanges);
use NagScreen;
use ServicesContacts;
use AuditLog;

sub getWelcomeText  {
  my ($Data, $entityID)=@_;
 
  my $realmID=$Data->{'Realm'} || 0;
  $entityID ||= 0;
  my $clubID=$Data->{'clientValues'}{'clubID'} || 0;
  my $subtypeID=$Data->{'RealmSubType'} || 0;
  my $st=qq[
    SELECT intEntityID, strWelcomeText, intRealmSubTypeID
    FROM tblWelcome
    WHERE intRealmID= ?
      AND (intEntityID = ? OR intEntityID=0)
  ];
  my $query = $Data->{'db'}->prepare($st);
  $query->execute(
    $realmID,
    $entityID,
  );
  my %Welcomes=();
  my $found=0;
  while (my $dref=$query->fetchrow_hashref())  {
    next if($dref->{'intRealmSubTypeID'} and $dref->{'intRealmSubTypeID'}!= $subtypeID);
    $dref->{'strWelcomeText'}||='';
    $dref->{'strWelcomeText'}=~s/[\n]/<br>/g;
    $Welcomes{$dref->{'intEntityID'}}=$dref->{'strWelcomeText'};
    $found=1 if $dref->{'strWelcomeText'} || '';
  }
  $Welcomes{0}||='';

  $Welcomes{$entityID} = defaulttext($Data) if !$found;
  $Welcomes{0}.='<br><br>' if $Welcomes{0};
  #if($Data->{'clientValues'}{'currentLevel'} == $Defs::LEVEL_ASSOC)  {
    #$Welcomes{$entityID} .= qq[
      #<a href = "$Data->{'target'}?client=$Data->{'client'}&amp;a=A_WEL_" class="edit-link">Edit</a>
    #];
  #}
  
  my $changes=getLatestChanges($Data) || '';
  $changes .='<br>' if $changes;
  linkify(\$Welcomes{0});
  linkify(\$Welcomes{$entityID});

  my $nagscreen = '';
  if($Data->{'SystemConfig'}{'NagScreen'}
    and $Data->{'SystemConfig'}{'NagScreen'}=~/\.templ/)  {
    $nagscreen = show_nag_screen($Data);
  }

  my $days_since_last_login = param('days') || 0;
  my $login_message = '';
  if ($Data->{'SystemConfig'}{'display_login_message'} and $days_since_last_login > $Data->{'SystemConfig'}{'display_login_message'}) {
    $login_message = $Data->{'SystemConfig'}{'login_message_text'};
  }

  my $body=qq[
    $login_message
    $nagscreen
    $changes
    $Welcomes{0}
    $Welcomes{$entityID}
  ];


    my $killMsg='';
    ($killMsg , undef) = checkServicesContacts($Data, $Defs::LEVEL_CLUB, $clubID) if ($clubID>0);
  #$body = $killMsg if $killMsg;
  

  return ($body, $killMsg || '');
}



sub defaulttext  {
  my ($Data) = @_;
  my $lang   = Lang->get_handle('', $Data->{'SystemConfig'}) || die "Can't get a language handle!";
  my $default_text = ($Data->{'SystemConfig'}{'CUSTOM_DEFAULT_TEXT'}) ? $Data->{'SystemConfig'}{'CUSTOM_DEFAULT_TEXT'} : $lang->txt('WELCOME');
  return $default_text;
}



sub handle_welcome  {
  my($Data, $action)=@_;

  my $body='';
  if($action eq 'A_WEL_U')  {
    $body=update_welcome($Data);
  }
  else   {
    $body.=edit_welcome($Data);
  }
  my $title=$Data->{'lang'}->txt('Edit Welcome Message');
  return ($body,$title);
}


sub edit_welcome  {
  my($Data)=@_;

  my $realmID=$Data->{'Realm'} || 0;
  my $target=$Data->{'target'};
  my $cl  = setClient($Data->{'clientValues'});
  my $unesc_cl=unescape($cl);
  my $entityID=$Data->{'clientValues'}{'entityID'} || $Defs::INVALID_ID;

  my $st=qq[
    SELECT strWelcomeText
    FROM tblWelcome
    WHERE intEntityID = ?
  ];
  my $query = $Data->{'db'}->prepare($st);
  $query->execute($entityID);
  my $body='';
  my %DBData=();
  my ($welcometext) =$query->fetchrow_array();

  $welcometext||='';
  my $uwm = $Data->{'lang'}->txt('Update');

  $body=$Data->{'lang'}->txt('TO_UPD_WELCOME', $uwm).qq[
  <form action="$target" method="POST">
    <input type="hidden" name="a" value="A_WEL_U">
    <input type="hidden" name="client" value="$unesc_cl">
        <textarea name="welmsg" cols="70" rows="20">$welcometext</textarea>
    <p>
        <input type="submit" value="$uwm" class = "button proceed-button"><br>
    </p>
  </form>
  ];

  return $body;

}

sub update_welcome {
  my($Data, $type, $id)=@_;
  my $realmID=$Data->{'Realm'} || 0;
  my $entityID=$Data->{'clientValues'}{'entityID'} || $Defs::INVALID_ID;
  {
    my $st_del=qq[DELETE FROM tblWelcome WHERE intEntityID= ? AND intRealmID= ? ];
    my $query = $Data->{'db'}->prepare($st_del);
    $query->execute(
      $entityID,
      $realmID,
    );
  }
  my $welmsg=param('welmsg') || '';
  my $st_insert=qq[
    INSERT INTO tblWelcome 
      (intEntityID, intRealmID, strWelcomeText)
      VALUES (?,?,?)
  ];
  my $query = $Data->{'db'}->prepare($st_insert);
  $query->execute(
    $entityID,
    $realmID,
    $welmsg,
  );
  $id = $query->{mysql_insertid} unless ($id);
  my $subBody='';
  if($DBI::err)  {
    $subBody=qq[<div class="warningmsg">].$Data->{'lang'}->txt('There was a problem changing the welcome message').'</div>';
  }
  else  { 
    $subBody.=qq[<div class="OKmsg">].$Data->{'lang'}->txt('Welcome Message Updated').'</div>';
    auditLog($id, $Data, 'Update', 'Welcome Message');
  }
  return $subBody;
}

sub linkify {
  my($stringref)=@_;
  $$stringref =~s/(\s+?|>)([\w\.]+@[\w\-\.]+)(\s+?|<)/$1<a href="mailto:$2">$2<\/a>$3/g;  $$stringref =~s/^([\w\.]+@[\w\-\.]+)$/<a href="mailto:$1">$1<\/a>/g;

  $$stringref =~s/(\s+?|[^"]>)(http:\/\/.*?)(\s+?|<)/$1<a href="$2" target="_blank">$2<\/a>$3/g;
  $$stringref =~s/(\s+?|[^"]>)(www\..*?)(\s+?|<)/$1<a href="http:\/\/$2" target="_blank">$2<\/a>$3/g;
  $$stringref =~s/^(http:\/\/.*?)$/<a href="$1" target="_blank">$1<\/a>/g;
  $$stringref =~s/^(www\..*?)$/<a href="http:\/\/$1" target="_blank">$1<\/a>/g;
}


1;
