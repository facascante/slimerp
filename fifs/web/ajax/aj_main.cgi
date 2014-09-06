#!/usr/bin/perl

use strict;
use warnings;

use lib '..','../..';

use Lang;
use Reg_common;
use SystemConfig;
use Utils;
use MCache;
use CGI qw(param);
use JSON;

main(); 

sub main {
    my $key1         = param('key1')   || '';
    my $key2         = param('key2')   || '';
    my $contentType  = safe_param('contentType', 'word') || 'application/json';

    my $keyCheck     = getRegoPassword($key1);
    doError('An invalid call has been attempted.', $contentType) if ($key2 ne $keyCheck);

    my $client       = param('client')         || '';
    my $function     = safe_param('f', 'word') || '';
    my $lang         = Lang->get_handle()      || doError("Can't get a language handle!", $contentType);
    my %clientValues = getClient($client);
    my $q            = new CGI;

    my %Data = ();

    $Data{'lang'}         = $lang;
    $Data{'clientValues'} = \%clientValues;
    $Data{'contentType'}  = $contentType;
    $Data{'params'}       = $q->Vars();
    $Data{'cache'}        = new MCache();

    my $dbh = allowedTo(\%Data);

    ($Data{'Realm'}, $Data{'RealmSubType'}) = getRealm( \%Data );
    $Data{'SystemConfig'} = getSystemConfig(\%Data);

    my $ajObj = undef;

    my $objName = 'Aj_'.$function;

    if ($objName) {
		eval "require $objName";
        $ajObj = $objName->new();
    }
    else {
        doError('Invalid function code has been passed.', $contentType);
    }

    my $content = $ajObj->getContent(\%Data);

    disconnectDB($dbh);

    print "Content-type:$contentType\n\n";
    print $content;
}

sub doError {
    my ($message, $contentType) = @_;
    my $content = '';
    if ($contentType =~ /json/) {
        $content = to_json({result=>'Error', message=>$message});
    }
    elsif ($contentType =~ /html/) {
        $content = qq[<div class="error">$message<div>];
    }
    else {
        $content = $message;
    }
    printStuff($content);
    die "$message\n";
}

sub printStuff {
    my ($stuff, $contentType) = @_;
    print "Content-type:$contentType\n\n";
    print $stuff;
    return
}
