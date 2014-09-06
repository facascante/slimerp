#!/usr/bin/perl -w

#
# $Header: svn://svn/SWM/trunk/web/authlist.cgi 10456 2014-01-16 03:51:34Z eobrien $
#

use strict;
use warnings;

use DBI;
use CGI qw(:cgi escape unescape);

use lib ".", "..", "../..", "../passport";

use Defs;
use Utils;

use DashboardPassport;
use Crypt::CBC;
use MCache;
use DashboardUtils qw(:constants);
use TTTemplate;
use Lang;

use PassportLink;
use Digest::MD5 qw(md5_base64);

main();

sub main {
    my $db = connectDB();
    my $lang = Lang->get_handle() || die "Can't get a language handle!";

    my %Data = (
                 'db'          => $db,
                 'lang'        => $lang,
                 'cache'       => new MCache(),
                 'PassportURL' => {
                                    'login'  => PASSPORT_LOGIN_URL,
                                    'logout' => PASSPORT_LOGOUT_URL,
                 },
    );

    my $section    = param('Section');
    my $action     = param('a');
    my $member_key = param('m');
    my $realm_id   = param('r');

    if ($member_key) {
        my $dashboard_id = _decode_member_key( $member_key, $realm_id );
        if ($dashboard_id) {
            $Data{Realm} = $realm_id;
            $Data{DMID}  = $dashboard_id;
            $Data{DMKey} = $member_key;
        }
    }

    if ( $section =~ /auth/i ) {
        if ( $action =~ /logout/i ) {
            if ($action =~ /_page/i) {
                _dashboard_logout_page( \%Data );
            }
            else {
                _dashboard_auth_logout( \%Data );
            }
        }
        else {
            _dashboard_auth( \%Data );
        }
    }
    else {
        _check_authentication( \%Data );
        if ( $section eq 'md' ) {
            _dashboard_member_details( \%Data );
        }
        elsif ( $section eq 'ec' ) {
            _dashboard_emergency_contact( \%Data );
        }
        elsif ( $section eq 'home' ) {
            _dashboard_member_home( \%Data );
        }
        else {
            _dashboard_member_home( \%Data );
        }
    }
    disconnectDB($db);
}

sub _decode_member_key {
    my ( $member_key, $realm_id ) = @_;

    my $cipher = Crypt::CBC->new( -key    => DASHBOARD_ENCRYPTION_KEY,
                                  -cipher => "Crypt::Blowfish" );

    my ( $member_enc, $member_md5 ) = split( /\./, $member_key );

    if ( $member_enc and $member_md5 ) {
        my $dashboard_id = $cipher->decrypt_hex($member_enc);
        if ( $dashboard_id and ( md5_base64( $dashboard_id . '.' . $realm_id . '.' . DASHBOARD_MEMBER_SECRET ) eq $member_md5 ) ) {
            return $dashboard_id;
        }
    }
    return 0;
}

sub _check_authentication {
    my ($Data) = @_;
    my $passport = new DashboardPassport( db    => $Data->{'db'},
                                          cache => $Data->{'cache'}, );
    $passport->loadSession();
    my $pID = $passport->id() || 0;

    if ( !$pID ) {
        redirectPassportLogin(
                               $Data,
                               undef,
                               $passport->getLoginParams(),
        );
    }
    else {
        my $st = qq[
        SELECT  pm.intPassportID,
                m.intMemberID,
                m.strFirstName,
                m.strSurname,
                m.intGender,
                concat(m.strAddress1,' ',m.strAddress2) as strAddress,
                m.strSuburb,
                m.strState,
                m.strCountry,
                m.dtDOB,
                m.strPhoneHome,
                m.strPhoneWork,
                m.strPhoneMobile,
                m.strNationalNum,
                m.strPostalCode,
                m.strEmail,
                m.strEmail2
        FROM tblPassportMember pm
        INNER JOIN tblMember m on m.intMemberID = pm.intMemberID
        INNER JOIN tblDashboardMember dm on m.intMemberID = dm.intMemberID
        WHERE pm.intPassportID = ?;
    ];

        my $q = $Data->{db}->prepare($st);
        $q->execute($pID);
        my $member_details = $q->fetchrow_hashref();
        $q->finish();
        if ($member_details) {
            $Data->{MemberDetails} = $member_details;
        }
    }
}

sub _dashboard_member_home {
    my ($Data) = @_;

    my $member_details = undef;
    if ( 0 and $Data->{DMID} ) {
        my $st = qq[
        SELECT  pm.intPassportID,
                m.intMemberID,
                m.strFirstName,
                m.strSurname,
                m.intGender,
                concat(m.strAddress1,' ',m.strAddress2) as strAddress,
                m.strSuburb,
                m.strState,
                m.strCountry,
                m.dtDOB,
                m.strPhoneHome,
                m.strPhoneWork,
                m.strPhoneMobile,
        FROM tblPassportMember pm
        INNER JOIN tblMember m on m.intMemberID = pm.intMemberID
        INNER JOIN tblDashboardMember dm on m.intMemberID = dm.intMemberID
        WHERE dm.intDashboardID = ?;
    ];

        my $q = $Data->{db}->prepare($st);
        $q->execute( $Data->{DMID} );
        $member_details = $q->fetchrow_hashref();
        $q->finish();
    }

    my $page_content = runTemplate(
                                    $Data,
                                    {
                                       MemberKey => $Data->{DMKey} || '',
                                       MemberDetails => $Data->{MemberDetails},
                                       Target        => DASHBOARD_BASE_URL,
                                       FirstName     => qq[Test],
                                    },
                                    "dashboard/home.templ"
    );

    my %TemplateData = (
                         MemberKey => $Data->{DMKey} || '',
                         MemberDetails => $Data->{MemberDetails},
                         Target        => DASHBOARD_BASE_URL,
                         BodyClass     => 'loggedin member-home',
                         PageTitle     => 'Profile',
                         LoggedIn      => 1,
                         PageContent   => $page_content,
    );

    my $body = runTemplate( $Data, \%TemplateData, "dashboard/wrapper.templ" );

    print "Content-type: text/html", "\n\n";
    print $body;
}

sub _dashboard_member_details {
    my ($Data) = @_;

    my $member_details = undef;
    if ( 0 and $Data->{DMID} ) {
        my $st = qq[
        SELECT  pm.intPassportID,
                m.intMemberID,
                m.strFirstName,
                m.strSurname,
                m.intGender,
                concat(m.strAddress1,' ',m.strAddress2) as strAddress,
                m.strSuburb,
                m.strPostalCode,
                m.strState,
                m.strCountry,
                m.dtDOB,
                m.strPhoneHome,
                m.strPhoneWork,
                m.strPhoneMobile
        FROM tblPassportMember pm
        INNER JOIN tblMember m on m.intMemberID = pm.intMemberID
        INNER JOIN tblDashboardMember dm on m.intMemberID = dm.intMemberID
        WHERE dm.intDashboardID = ?;
    ];

        my $q = $Data->{db}->prepare($st);
        $q->execute( $Data->{DMID} );
        $member_details = $q->fetchrow_hashref();
        $q->finish();
    }

    my $page_content = runTemplate(
                                    $Data,
                                    {
                                       MemberKey => $Data->{DMKey} || '',
                                       MemberDetails => $Data->{MemberDetails},
                                       Target        => DASHBOARD_BASE_URL,
                                       FirstName     => qq[Test],
                                    },
                                    "dashboard/personal_details.templ"
    );

    my %TemplateData = (
                         MemberKey => $Data->{DMKey} || '',
                         MemberDetails => $Data->{MemberDetails},
                         Target        => DASHBOARD_BASE_URL,
                         BodyClass     => 'loggedin detailsform',
                         PageTitle     => 'Personal Details',
                         LoggedIn      => 1,
                         PageContent   => $page_content,
    );

    my $body = runTemplate( $Data, \%TemplateData, "dashboard/wrapper.templ" );

    print "Content-type: text/html", "\n\n";
    print $body;
}

sub _dashboard_emergency_contact {
    my ($Data) = @_;

    my $page_content = runTemplate(
                                    $Data,
                                    {
                                       MemberKey => $Data->{DMKey} || '',
                                       Target    => DASHBOARD_BASE_URL,
                                       FirstName => qq[Test],
                                    },
                                    "dashboard/emergency_contact.templ"
    );

    my %TemplateData = (
                         MemberKey => $Data->{DMKey} || '',
                         MemberDetails => $Data->{MemberDetails},
                         Target        => DASHBOARD_BASE_URL,
                         BodyClass     => 'loggedin emergency',
                         PageTitle     => 'Emergency Contact',
                         LoggedIn      => 1,
                         PageContent   => $page_content,
    );

    my $body = runTemplate( $Data, \%TemplateData, "dashboard/wrapper.templ" );

    print "Content-type: text/html", "\n\n";
    print $body;
}

sub _dashboard_logout_page {
    my ($Data) = @_;
    my $page_content = qq[<p>You have logged out successfully.</p>];    #'
    my %TemplateData = (
                         MemberKey => $Data->{DMKey} || '',
                         Target    => DASHBOARD_BASE_URL,
                         BodyClass => 'logout',
                         PageTitle => 'Logout',
                         LoggedIn  => 0,
                         PageContent => $page_content,
    );

    my $body = runTemplate( $Data, \%TemplateData, "dashboard/wrapper.templ" );

    print "Content-type: text/html", "\n\n";
    print $body;
}

sub _dashboard_auth_logout {
    my ($Data) = @_;

    my $cgi = new CGI;
    my $sessionkey = $cgi->cookie(DASHBOARD_COOKIE_PASSPORT) || '';

    my $passportURL = passportURL(
                                   $Data,
                                   undef,
                                   'logout',
                                   DASHBOARD_LOGOUT_URL,
                                   undef,
    );

    my $cookie_string = $cgi->cookie(
                                      -name     => DASHBOARD_COOKIE_PASSPORT,
                                      -value    => '',
                                      -domain   => $Defs::cookie_domain,
                                      -secure   => $Defs::DevelMode ? 0 : 1,
                                      -expires  => '-1d',
                                      -httponly => 1,
                                      -path     => "/"
    );
    my $p3p = q[policyref="/w3c/p3p.xml", CP="ALL DSP COR CURa ADMa DEVa TAIi PSAa PSDa IVAi IVDi CONi OTPi OUR BUS IND PHY ONL UNI COM NAV DEM STA"];
    print $cgi->redirect(
                          -uri    => $passportURL,
                          -cookie => [$cookie_string],
                          -P3P    => $p3p
    );
}

sub _dashboard_auth {
    my ($Data) = @_;
    my $action         = param('a')      || 'LOGIN';
    my $url            = param('url')    || DASHBOARD_BASE_URL || '';
    my $sessionkey     = param('sk')     || '';
    my $callback_token = param('token')  || '';
    my $errors         = param("errors") || '';
    my $verify_params  = param("v-p")    || '';

    my $cgi = new CGI;

    my $params = $cgi->Vars;

    if ($verify_params) {
        my $qs = $cgi->query_string();
        $qs =~ s/;v\-p=[^;]*//g;

        my $passport = new DashboardPassport( db    => $Data->{'db'},
                                              cache => $Data->{'cache'}, );

        my @errors = split( /\|/, $errors );

        my $verify_result = $passport->verifyCallbackToken( $Data, $callback_token, \@errors );

        my $url_md5 = md5_base64( $qs . $verify_result->{'TimeStamp'} );
        if ( $url_md5 ne $verify_params ) {    #URL must have been tampered with
            die 'Request not allowed';
        }

        if ( $action eq 'LOGIN' and ( @errors or ( $verify_result->{'Result'} ne 'SUCCESS' ) ) ) {
            $action = 'FORM';
        }

        if ( $action eq 'LOGIN' ) {

            $passport->loadSession($sessionkey);
            my $mID = $passport->id() || 0;

            my $header = '';

            my $p3p           = q[policyref="/w3c/p3p.xml", CP="ALL DSP COR CURa ADMa DEVa TAIi PSAa PSDa IVAi IVDi CONi OTPi OUR BUS IND PHY ONL UNI COM NAV DEM STA"];
            my $cookie_string = '';
            if ($mID) {
                $cookie_string = $cgi->cookie(
                                               -name     => DASHBOARD_COOKIE_PASSPORT,
                                               -value    => $sessionkey,
                                               -domain   => $Defs::cookie_domain,
                                               -secure   => $Defs::DevelMode ? 0 : 1,
                                               -expires  => '+90d',
                                               -httponly => 1,
                                               -path     => "/"
                );
            }
            else {
                $cookie_string = $cgi->cookie(
                                               -name   => 'pp_swm_failedlogin',
                                               -value  => 1,
                                               -domain => $Defs::cookie_domain,
                                               -path   => "/"
                );
            }
            $header = $cgi->redirect(
                                      -uri    => $url,
                                      -cookie => [$cookie_string],
                                      -P3P    => $p3p
            );

            print $header;
        }
        elsif ( $action eq 'FORM' ) {

            my $passport_login = PASSPORT_LOGIN_URL;
            my $formParams     = '';

            my $params = passportParams(
                                         $url,
                                         undef,
                                         $passport->getLoginParams(),
            );

            for my $k ( keys %{$params} ) {
                my $paramValue = $params->{$k};
                $formParams .= qq[<input type="hidden" name="$k" value="$paramValue"/>];
            }

            my $error_message = '';
            if (@errors) {
                foreach my $error (@errors) {
                    $error_message .= $error . '<br/>';
                }
            }

            my $page_content = runTemplate(
                                            $Data,
                                            {
                                               MemberKey => $Data->{DMKey} || '',
                                               Target => $passport_login,
                                               ErrorMessage => $error_message,
                                               FormParams   => $formParams,
                                            },
                                            "dashboard/login.templ"
            );

            my %TemplateData = (
                                 PageTitle   => 'Login',
                                 ShowNav     => 0,
                                 PageContent => $page_content,
            );

            my $body = runTemplate( $Data, \%TemplateData, "dashboard/wrapper.templ" );

            print "Content-type: text/html", "\n\n";
            print $body;

        }

    }
    else {
        die 'Request not allowed';
    }
}

