#!/usr/bin/perl -w
use DBI;
use CGI qw(:cgi escape unescape);

use strict;

use lib ".", "..", "../..", "user";

use Defs;
use Utils;
use PageMain;
use Lang;
use TTTemplate;
use UserObj;
my %Data = (); 
use DBI;
my $lang = Lang->get_handle() || die "Can't get a language handle!";
$Data{lang} = $lang;



#get posted values
my $newpasswd = param('new_passwd') || '';
my $confirm_passwd = param('confirm_passwd') || '';
my $uId = param('uId') || '';
my $url_key = param('url_key') || '';

my $error = undef;

#validate password again 
if($newpasswd ne $confirm_passwd){ 
	$error .= 'Passwords do not match.<br />';
}
if(length($newpasswd) < 6){
	$error .= 'Password should be atleast 6 characters long.<br />';
}

#validate if user id corresponds to clients url key
my $dbh = connectDB(); 
if(!verifyUserHasKey($dbh,$url_key)){
	$error .= 'URL key is not valid for this user. <br />';
}

#update password
if(!defined($error)){ 
     my %cfg = (id => $uId, db => $dbh);
     my $myUserObj = new UserObj(%cfg);	
     $myUserObj->setPassword($newpasswd);     
}

my $template = 'user/update_password_msg.templ';  

my $body = runTemplate(
    \%Data,
    {Errors => $error,},
    $template,
); 

my $title = 'SportingPulse User Password Update'; 

pageForm(
	$title,
	$body,
	{},
	'',
	\%Data,
);

sub verifyUserHasKey{
	my($db,$key) = @_;
	my $query = "SELECT userId FROM tblUserHash WHERE strPasswordChangeKey = ?";	
	my $sth = $db->prepare($query);
	$sth->execute($key);
	my($uId_frm_db) = $sth->fetchrow_array();
	$sth->finish();
	return 1 if($uId_frm_db == $uId); 
	return 0;	
}