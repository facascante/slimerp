#!/usr/bin/perl -w

#
# $Header: svn://svn/SWM/trunk/web/linkmember.cgi 10951 2014-03-12 07:27:29Z eobrien $
#

use DBI;
use CGI qw(:cgi escape unescape);

use strict;

use lib ".", "..", "../..", "passport", "comp";

use Defs;
use Utils;
use Passport;
use PageMain;
use Reg_common;
use Lang;
use PassportLink;
use PassportList;
use InstanceOf;
use TTTemplate;

main();

sub main {

    my %Data      = ();
    my $memberkey = param('mk') || '';
    my $db        = connectDB();
    $Data{'db'} = $db;
    my $lang = Lang->get_handle() || die "Can't get a language handle!";
    $Data{'lang'} = $lang;
    my $target = 'linkmember.cgi';
    $Data{'target'} = $target;
    $Data{'cache'}  = new MCache();

    my $memberID = validateMemberKey($memberkey) || 0;

    my $passport = new Passport( db    => $db,
                                 cache => $Data{'cache'}, );
    $passport->loadSession();
    my $pID = $passport->id() || 0;

    warn("GOT pID") if $pID;

    my $body = '';
    if ($memberID) {
        if ($pID) {
            $body = linkMember(
                                \%Data,
                                $passport,
                                $memberID,
            );
        }
        else {
            $body = getMemberLinkPage(
                                       \%Data,
                                       $memberID,
            );
        }
    }
    else {
        $body = 'Invalid Member Code';
    }

    my $title = 'Add Member to your Passport';

    $Data{'HTMLHead'} = '<link rel="stylesheet" type="text/css" href="css/passportstyle.css"> 
  <!--[if IE]>
    <link rel="stylesheet" type="text/css" href="css/passport_ie.css" />
  <![endif]-->

  <!--[if lt IE 9]>
    <link rel="stylesheet" type="text/css" href="css/passport_ie_old.css" />
  <![endif]-->
';
    pageForm(
              $title,
              $body,
              {},
              '',
              \%Data,
    );
}

sub validateMemberKey {
    my ($memberkey) = @_;

    my ( $memberID, $code ) = split /f/, $memberkey, 2;

    return 0 if !$memberID;
    return 0 if !$code;

    my $newcode = getRegoPassword($memberID);
    return $memberID if $code eq $newcode;
    return 0;
}

sub getMemberLinkPage {
    my (
         $Data,
         $memberID,
    ) = @_;

    my $templateFile = 'passport/linkmember.templ';
    my $memberObj = getInstanceOf( $Data, 'member', $memberID );
    return '' if !$memberObj;

    my $passportURL = passportURL(
                                   $Data,
                                   {},
                                   '',
                                   '',
                                   {
                                      cbs => 'swm',
                                      cbc => $memberID . 'f' . getRegoPassword($memberID),
                                   },
    ) || '';
    my $body = runTemplate(
                            $Data,
                            {
                               PassportLinkURL => $passportURL,
                               FirstName       => $memberObj->getValue('strFirstname') || '',
                               FamilyName      => $memberObj->getValue('strSurname') || '',
                               DOB             => $memberObj->getValue('dtDOB') || '',
                               Gender          => $Defs::PersonGenderInfo{ $memberObj->getValue('intGender') } || '',
                            },
                            $templateFile,
    );

    return $body;
}

sub linkMember {
    my (
         $Data,
         $passport,
         $memberID,
    ) = @_;

    my $error   = '';
    my @errors  = ();
    my $success = '';

    $passport->link_member( $memberID, $Data->{'lang'}, \@errors );

    if (@errors) {
        $error = join( ', ', @errors );
    }
    else {
        $success = 'Member is now Linked';
    }

    my $templateFile = 'passport/linkmember_finish.templ';
    my $body = runTemplate(
                            $Data,
                            {
                               Error   => $error,
                               Success => $success,
                            },
                            $templateFile,
    );

}
