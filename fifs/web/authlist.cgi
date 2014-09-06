#!/usr/bin/perl -w

#
# $Header: svn://svn/SWM/trunk/web/authlist.cgi 10456 2014-01-16 03:51:34Z eobrien $
#

use DBI;
use CGI qw(:cgi escape unescape);

use strict;

use lib ".", "..", "../..", "user";

use Defs;
use Utils;
use UserSession;
use UserList;
use PageMain;
use Lang;

main();

sub main {

    my %Data = ();
    my $db   = connectDB();
    $Data{'db'} = $db;
    my $lang = Lang->get_handle() || die "Can't get a language handle!";
    $Data{'lang'} = $lang;
    my $target = 'authlist.cgi';
    $Data{'target'} = $target;
    $Data{'cache'}  = new MCache();
    my $resultsentry = param('results') || 0;

    my $user = new UserSession( 
        db    => $db,
        cache => $Data{'cache'}, 
    );
    $user->load();

    my $uID = $user->id() || 0;
    if ( !$uID ) {
        $Data{'RedirectTo'} = "$Defs::base_url/";
    }
    $Data{'UserName'} = $user->fullname();

    my $body = getAuthOrgLists(
        \%Data,
        $uID,
    );

    my $title = 'User Authorisation';

    $Data{'HTMLHead'} = '<link rel="stylesheet" type="text/css" href="css/userstyle.css"> 
  <script type="text/javascript" src="js/noappbreak.js"></script>
  <!--[if IE]>
    <link rel="stylesheet" type="text/css" href="css/user_ie.css" />
  <![endif]-->

  <!--[if lt IE 9]>
    <link rel="stylesheet" type="text/css" href="css/user_ie_old.css" />
  <![endif]-->
	<meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1">
';
    pageForm(
              $title,
              $body,
              {},
              '',
              \%Data,
    );
}

