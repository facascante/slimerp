use strict;
use warnings;

package DashboardPassport;

use lib ".", "..", "../..";

use base qw(Passport);
use Crypt::CBC;
use Digest::MD5 qw(md5_base64);
use POSIX qw(strftime);
use DashboardUtils qw(:constants);
use Data::Dumper;
use Log;

sub getLoginParams {
    my $self = shift;
    my ($additional_params) = @_;
    my %params = (
                   'lu' => DASHBOARD_LOGIN_URL,
                   'lt' => $self->getLoginToken(),
    );

    if ($additional_params) {
        for my $k ( keys %{$additional_params} ) {
            $params{$k} = $additional_params->{$k};
        }
    }
    return \%params;
}

sub getLogoutParams {
    my $self = shift;

    my $cgi = new CGI;
    my $sessionkey = $cgi->cookie(DASHBOARD_COOKIE_PASSPORT) || '';

    my %params = (
                   'sk' => $sessionkey,
    );

    return \%params;
}


sub verifyCallbackToken {
    my $self = shift;
    my ( $Data, $callback_token, $errors ) = @_;

    my $l = $Data->{'lang'};
    my %result = (
                   'Result'        => '',
                   'TimeStamp'     => '',
                   'FailureReason' => CALLBACK_TOKEN_INVALID,
    );

    if ( !$callback_token ) {
        $result{'Result'}        = 'FAILURE';
        $result{'FailureReason'} = CALLBACK_TOKEN_INVALID;
    }
    else {
        my $cipher = Crypt::CBC->new( -key    => CALLBACK_ENCRYPTION_KEY,
                                      -cipher => "Crypt::Blowfish" );

        my $now = strftime '%Y%m%d%H%M', gmtime;

        my $decrypted_token = $cipher->decrypt_hex($callback_token);

        my ( $md5, $timestamp, $token_id ) = split( /\./, $decrypted_token );

        $result{'TimeStamp'} = $timestamp || '';

        if ( !( $md5 && $timestamp && $token_id ) ) {
            $result{'Result'}        = 'FAILURE';
            $result{'FailureReason'} = CALLBACK_TOKEN_INVALID;
            push @{$errors}, $l->txt('Token invalid');
        }
        elsif ( ( $timestamp <= ( $now - 60 ) ) || $timestamp >= ( $now + 60 ) ) {
            $result{'Result'} = 'FAILURE';

            $result{'FailureReason'} = CALLBACK_TOKEN_EXPIRED;
            push @{$errors}, $l->txt('<div class="alert alert-warning">Your login session has expired</div>');
        }
        else {
            my $md5_verify = md5_base64( CALLBACK_HASH_SECRET . $timestamp );

            if ( $md5_verify ne $md5 ) {
                $result{'Result'}        = 'FAILURE';
                $result{'FailureReason'} = CALLBACK_TOKEN_INVALID;
                push @{$errors}, $l->txt('Token failed verification step 1');
            }
            else {
                my $st = qq[
                        SELECT strPassportCallbackToken, dtExpired
                        FROM tblPassportLoginToken
                        WHERE intPassportLoginTokenID = ?
                    ];

                my $q = $Data->{'db'}->prepare($st);
                $q->execute($token_id);
                my ( $md5_verify2, $date_expired ) = $q->fetchrow_array();
                $q->finish();

                if ($md5_verify2) {
                    $st = qq[
                        UPDATE tblPassportLoginToken
                        SET dtExpired = now()
                        WHERE intPassportLoginTokenID = ?
                    ];

                    $q = $Data->{'db'}->prepare($st);
                    $q->execute($token_id);
                    $q->finish();

                    if ($date_expired) {
                        $result{'Result'}        = 'FAILURE';
                        $result{'FailureReason'} = CALLBACK_TOKEN_EXPIRED;
                        push @{$errors}, $l->txt('Your login session has expired.');
                    }
                    elsif ( $md5_verify2 ne $md5 ) {
                        $result{'Result'}        = 'FAILURE';
                        $result{'FailureReason'} = CALLBACK_TOKEN_INVALID;
                        push @{$errors}, $l->txt('Token failed verification step 2');
                    }
                    else {
                        $result{'Result'}        = 'SUCCESS';
                        $result{'FailureReason'} = 0;
                    }
                }
                else {
                    $result{'Result'}        = 'FAILURE';
                    $result{'FailureReason'} = CALLBACK_TOKEN_INVALID;
                    push @{$errors}, $l->txt('Token not found');
                }

            }

        }
    }
    return \%result;
}

sub getLoginToken {
    my $self = shift;
    my $now  = strftime '%Y%m%d%H%M', gmtime;
    my $md5  = md5_base64( CALLBACK_HASH_SECRET . $now );
    my $cipher = Crypt::CBC->new( -key    => CALLBACK_ENCRYPTION_KEY,
                                  -cipher => "Crypt::Blowfish" );

    my $st = qq[
        INSERT INTO tblPassportLoginToken (strPassportCallbackToken,dtCreated)
        VALUES (?,now());
    ];

    my $q = $self->{'db'}->prepare($st);
    $q->execute($md5);
    my $token_id = $q->{'mysql_insertid'};
    $q->finish();

    my $token = $cipher->encrypt_hex("$md5.$now.$token_id");

    my ( $tokenreq_ok, $tokenreq ) =
      $self->_connect(
                       'GetLoginToken',
                       {
                          'CallbackURL'   => DASHBOARD_LOGIN_URL,
                          'CallbackToken' => $token,
                          'Timestamp'     => $now,
                       }
      );

    my $login_token = $tokenreq->{'Response'}{'Data'}{'LoginToken'} || '';
    return $login_token;
}

sub loadSession {
    my $self = shift;
    my ($sessionK) = @_;

    # This function returns information about the passport account
    # currently logged in

    my $output = new CGI;
    my $sessionkey = $sessionK || $output->cookie(DASHBOARD_COOKIE_PASSPORT) || '';
    return undef if !$sessionkey;

    my $cache = $self->{'cache'} || undef;

    my ( $tokenreq_ok, $tokenreq ) = ( '', '' );
    if ($cache) {
        my $cacheval = $cache->get( 'dash', 'DPSKEY_' . $sessionkey );
        if ($cacheval) {
            $tokenreq_ok = $cacheval->[0];
            $tokenreq    = $cacheval->[1];
        }
    }
    if ( !$tokenreq_ok ) {
        ( $tokenreq_ok, $tokenreq ) =
          $self->_connect(
                           'GetToken',
                           {
                              SessionKey => $sessionkey,
                           }
          );
        return undef if !$tokenreq_ok;
        $cache->set( 'dash', "DPSKEY_$sessionkey", [ $tokenreq_ok, $tokenreq ], undef, 60 * 10 ) if $cache;    #Cache for 10min
    }
    return undef if !$tokenreq_ok;
    my $token = $tokenreq->{'Response'}{'Data'}{'PassportToken'} || '';
    my $id    = $tokenreq->{'Response'}{'Data'}{'PassportID'}    || '';

    $self->{'ID'} = $id if $id;

    if ( $token and $id ) {
        my ( $inforeq_ok, $inforeq ) = ( '', '' );
        if ($cache) {
            my $cacheval2 = $cache->get( 'dash', 'DPTOK_' . $token );
            if ($cacheval2) {
                $inforeq_ok = $cacheval2->[0];
                $inforeq    = $cacheval2->[1];
            }
        }
        if ( !$inforeq_ok ) {
            ( $inforeq_ok, $inforeq ) =
              $self->_connect(
                               'PassportInfo',
                               {
                                  PassportToken => $token,
                               },
              );
            $cache->set( 'dash', "DPTOK_$token", [ $inforeq_ok, $inforeq ], undef, 60 * 10 ) if $cache;    #Cache for 10min
        }
        if ($inforeq_ok) {
            $self->{'Info'} = $inforeq->{'Response'}{'Data'};
        }
    }
}

1;
