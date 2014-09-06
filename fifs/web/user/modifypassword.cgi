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
my $lang = Lang->get_handle() || die "Can't get a language handle!";
$Data{lang} = $lang;
my $target = 'modifypassword.cgi';
$Data{'target'} = $target;
$Data{'cache'}  = new MCache();

my $UserTempDataUid = '';
my $body = '';

#check first for existing parameter 
my $url_key = param('url_key') || '';
my $uId = isURL_Key_Valid($url_key);
if(defined ($uId)){
     $UserTempDataUid = $uId;
}

my $template = 'user/modify_user_password.templ';  

$body = runTemplate(
    \%Data,
   {UserTempDataUid => $UserTempDataUid,
    URL_Key => $url_key,
   },
    $template,
); 

my $title = 'Modify Password'; 

pageForm(
	$title,
	$body,
	{},
	'',
	\%Data,
);
sub isURL_Key_Valid{ 
	my $url_key = shift;
	my $query = "SELECT userId FROM tblUserHash WHERE strPasswordChangeKey != '' AND strPasswordChangeKey = ?";
	my $dbh = connectDB();
	my $sth = $dbh->prepare($query);
	$sth->execute($url_key); 
	my ($uId) = $sth->fetchrow_array();
	$sth->finish();
	return $uId;		
}
