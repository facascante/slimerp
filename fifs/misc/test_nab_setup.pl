#!/usr/bin/perl

#
# $Header: svn://svn/SWM/trunk/misc/test_nab_setup.pl 8250 2013-04-08 08:24:36Z rlee $
#

use strict;
use lib '..', '../web';

use Defs;
use Utils;

use Getopt::Std;
use HTTP::Request::Common qw(POST);
use LWP::UserAgent;
use CGI qw(param unescape escape);

use vars qw($opt_a $opt_c $opt_m);

&getopts('a:c:m:');
if (!$opt_a and !$opt_c and !$opt_m) {
    &usage('Please provide the ID of the club or association or the name of the merchant account that you wish to check.');
    exit;
}

my $where = '';

if ($opt_a) {
    $where = qq[intEntityID = $opt_a
                AND intEntityTypeID = 5
            ];
}
elsif ($opt_c) {
    $where = qq[intEntityID = $opt_c
                AND intEntityTypeID = 3
            ];
}
elsif ($opt_m) {
    $where = qq[strMerchantAccUserName = '$opt_m'];
}

my $db = connectDB();
my $st = qq[
		    SELECT
			    strMerchantAccUsername,
			    strMerchantAccPassword
		    FROM
			    tblBankAccount
		    WHERE
                $where
		    LIMIT 1
	];


my $qry= $db->prepare($st) or die print $!;
$qry->execute();
my $dref = $qry->fetchrow_hashref();
my $NABUsername = $dref->{'strMerchantAccUsername'};
my $NABPassword = $dref->{'strMerchantAccPassword'} || 'abcd1234';

if (!$NABPassword or !$NABUsername) {
    print "Unable to determine NAB username or password, please check the bank account set-up for the club or association you wish to test.\n";
    exit;
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
     
if (length($Values{'FINGERPRINT_RESPONSE'}) == 40){
    print "Set-up appears to be OK.\n";
}
else {
    print "Error with Fingerprint identification.\n";
    print "Please check user name and password.\n";
}
print "Returned content was:\n";
print "\n$content\n";

exit;        

sub usage {
    my $error = shift;
    print "ERROR: ";
    print "$error\n";
    print "       usage:./test_nab_setup.pl -a assocID or -c clubID or -m merchant account\n\n";
    exit;
}

  
