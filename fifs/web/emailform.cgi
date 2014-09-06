#!/usr/bin/perl -w
use CGI qw(param unescape escape cookie); 
use lib ".", "..";

use Defs;
use Lang;
use TTTemplate; 
use Utils;
use PageMain;
use DBI;


$lang = Lang->get_handle() || die 
my $title=$lang->txt('APPNAME') || 'SportingPulse Membershi'; 

my %Data = (); #empty hash; 
$Data{lang} = $lang;	 
#$Data{cache}  = new MCache(); 
my $url_param = param('url_key');
$Data{url_param} = $url_param;



my $body = runTemplate(
    \%Data,
    {},
    'user/url_link_reminder.templ',
);
pageForm($title, $body, {}, '', \%Data);
