#!/usr/bin/perl -w
#
# $Header: svn://svn/SWM/trunk/web/index.cgi 10277 2013-12-15 21:15:06Z tcourt $
#

use strict;
use lib ".", "..", 'user';
use CGI qw(param unescape escape cookie);
use CGI qw(:standard -debug);
use Defs;
use Lang;
use TTTemplate; 
use Utils;
use UserObj;
use PageMain;
use DBI;

my $lang= Lang->get_handle() || die "Can't get a language handle!";
# need this one for other languages 

my $title=$lang->txt('APPNAME') || 'SportingPulse Membership'; 

my %Data = (); #empty hash 
$Data{lang} = $lang;	 
$Data{'cache'}  = new MCache(); 
my $error = '';
my $action = param('a') || '';


if($action eq 'RESET_PASSWD'){ 
	my $email = param('email'); 
	my $dbh = connectDB(); 
	my $userObj = new UserObj('db',$dbh);
	if( !defined($userObj->load('email',$email)) ){ 
	    $error = "Sorry. Email address does not exist in our system.";
	}
	else { 		
	    my $stringRandom = $userObj->getPasswdChangeKey();
	    print "Location: emailform.cgi?url_key=$stringRandom\n\n";
	}		
}
my $body = runTemplate(
    \%Data,
    {'Error' => $error},
    'user/forgot_password_form.templ',
);

pageForm(
	$title,
	$body,
	{},
	'',
	\%Data,
);
