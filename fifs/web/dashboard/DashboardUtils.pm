package DashboardUtils;

use strict;
use warnings;

require Exporter;

our @ISA = qw(Exporter);

use lib "../..";

use CGI qw(script_name);
use Defs;

our %constants;

BEGIN {
    my $cgi = new CGI();

    my $base_url = "$Defs::base_url/dashboard/";

    %constants = (
                   CALLBACK_TOKEN_EXPIRED    => -200,
                   CALLBACK_TOKEN_INVALID    => -201,
                   CALLBACK_ENCRYPTION_KEY   => '5da727ae-4183-42f7-96d5-c49e37fce327',
                   CALLBACK_HASH_SECRET      => '730c24a7-d788-4b4c-94c8-402b2994271a',
                   DASHBOARD_ENCRYPTION_KEY  => 'ae0c8f3b-b6c8-40b9-831f-708fbcde08e7',
                   DASHBOARD_MEMBER_SECRET   => '72938d76-f3a1-45d0-aa88-dce8283f6639',
                   DASHBOARD_COOKIE_PASSPORT => '_SP_MD',
                   DASHBOARD_BASE_URL        => $base_url,
                   DASHBOARD_LOGIN_URL       => "$base_url?Section=Auth",
                   DASHBOARD_LOGOUT_URL      => "$base_url?Section=Auth;a=logout_page",
                   PASSPORT_LOGIN_URL        => "$Defs::PassportURL/remote/login.cgi",
                   PASSPORT_LOGOUT_URL       => "$Defs::PassportURL/remote/logout.cgi"
    );
}

use constant \%constants;

our @EXPORT_OK = ( keys %constants );

our %EXPORT_TAGS = ( constants => [ keys %constants ] );

1;
