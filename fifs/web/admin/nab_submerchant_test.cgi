#!/usr/bin/perl -w

#
# $Header: svn://svn/SWM/trunk/web/admin/nab_submerchant_test.cgi 8249 2013-04-08 08:14:07Z rlee $
#

use strict;
use lib "../..","..",".";
use CGI qw(param unescape escape);
use HTTP::Request::Common qw(POST);
use LWP::UserAgent;
use Defs;
use Utils;
use Defs;
use AdminPageGen;

main();

sub main {
	my $db = connectDB();

	my $a= param('a') || '';
	my $body = '<div style="padding-left:10px"><h3>Test NAB Sub-Merchant Set-Up</h3>';
    
    if ($a eq 'run') {
        $body .= run_setup_check($db);
    }
	else {
        $body .= setup_check_form();
    }
	$body .= '</body>';
    disconnectDB($db);
    print_adminpageGen($body, "", "");
}


sub run_setup_check {
    my $db = shift;
    my $sm_code = param('sm-code');
    
    if (!$sm_code) {
        return '<p><strong>Please enter a valid sub merchant code.</strong><p>';
    }

    
    my $st = qq[
                SELECT
			    strMerchantAccUsername,
			    strMerchantAccPassword
                FROM
			    tblBankAccount
                WHERE
                strMerchantAccUserName = ?
                LIMIT 1
            ];


    my $qry= $db->prepare($st) or die print $!;
    $qry->execute($sm_code);
    my $dref = $qry->fetchrow_hashref();
    my $NABUsername = $dref->{'strMerchantAccUsername'};
    my $NABPassword = $dref->{'strMerchantAccPassword'} || 'abcd1234';
    
    if (!$NABPassword or !$NABUsername) {
        return "Unable to determine NAB username or password, please check the bank account set-up for the club or association you wish to test.\n";
    }
    
    
    my ($second, $minute, $hour, $dayOfMonth, $month, $yearOffset, $dayOfWeek, $dayOfYear, $daylightSavings) = gmtime();
    my $year = 1900 + $yearOffset;
    $month++;
    $second= sprintf("%02s", $second);
    $minute= sprintf("%02s", $minute);
    $hour= sprintf("%02s", $hour);
    $month = sprintf("%02s", $month);
    $dayOfMonth = sprintf("%02s", $dayOfMonth);
    my $gmt_time =  "$year$month$dayOfMonth$hour$minute$second";
    
    
    my %Values= (
                 EPS_AMOUNT=>0,
                 EPS_TIMESTAMP=>$gmt_time,
                 EPS_MERCHANT=>$NABUsername,
                 EPS_PASSWORD=>$NABPassword,
                 EPS_REFERENCEID=>12345678,
             );
    
    my $fingerprint_url = "https://transact.nab.com.au/live/directpost/genfingerprint";
    
    # my $req = POST $Defs::{'NAB_LIVE_FINGERPRINT_URL'}, \%Values;
    my $req = POST $fingerprint_url, \%Values;
    my $ua = LWP::UserAgent->new();
    $ua->timeout(360);
    
    my $content = $ua->request($req)->as_string;
    
    my $blankLineFound=0;
    for my $line (split /\n|&/,$content)  {
        $line=~s/[\n\r]$//g;
        next if ($line and ! $blankLineFound);
        if (!$line) {
            $blankLineFound=1;
            next;
        }
        $Values{'FINGERPRINT_RESPONSE'} = $line;
        last;
    }
    
    my $response = '';
    
    if (length($Values{'FINGERPRINT_RESPONSE'}) == 40){
        $response = "<p><strong>Set-up appears to be OK.</strong></p>";
    }
    else {
        $response = qq[<p><strong>Error with Fingerprint identification.<br>
                       Please check user name and password.</strong></p>];
    }
    $response .= "<p><strong>Returned content was:</strong>&nbsp;<code>$content</code></p>";
}

sub setup_check_form {
    
    my $html = '';
    my $action = 'run';
    
    $html .= qq[<form name="nab_submerchant_test" action="nab_submerchant_test.cgi" method="post">	
                <table>
                  <tr>
                    <td>Sub Merchant Code</td>
                    <td><input type="text" name="sm-code" /></td>
                 </tr>
                </table>
			    <input type="hidden" name="a" value="$action"><br>
                <input type="submit" name="submit" value="Check Set-Up">
                </form>
            ];
        
    return $html;
    
}
