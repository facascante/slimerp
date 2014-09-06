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
use PageMain;
use Lang;
use Login;
use TTTemplate;

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
    my $email = param('email') || '';
    my $password = param('pw') || '';

    my($sessionKey, $errors) = login(\%Data, $email, $password);

warn("TEST :$sessionKey:");
    my $body = '';
    if($sessionKey) {
warn("IN HERE $Defs::COOKIE_LOGIN");
        push @{$Data{'WriteCookies'}}, [
            $Defs::COOKIE_LOGIN,
            $sessionKey,
            '3h',
        ];
        $Data{'RedirectTo'} = "$Defs::base_url/authlist.cgi";
    }
    else    {
      $body = runTemplate(
        \%Data,
        {'errors' => $errors},
        'user/loginerror.templ',
      );
    }

    my $title = 'Login';

    pageForm(
              $title,
              $body,
              {},
              '',
              \%Data,
    );
}

