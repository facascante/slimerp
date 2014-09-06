#!/usr/bin/perl

#
# $Header: svn://svn/SWM/trunk/misc/moneylogInsert.pl 8250 2013-04-08 08:24:36Z rlee $
#

use strict;

use lib "..","../web","../web/comp", "../web/user", '../web/RegoForm', "../web/dashboard", "../web/RegoFormBuilder",'../web/PaymentSplit', "../web/Clearances";

use Defs;
use Utils;
use DBI;
use WorkFlow;
use UserObj;
use CGI qw(unescape);
use RegistrationAllowed;
use PersonRegistration;
use Data::Dumper;

main();

sub main	{


	my %Data = ();
	my $db = connectDB();
    my $personID= 10759090;
    my $gender=1;
    my $entityID = 19;
    my $originID = 19;
    my $originLevel = 3;
    my $pRegID = 1;
	$Data{'db'} = $db;
	$Data{'Realm'} = 1;
	$Data{'RealmSubType'} = 0;

    my $st = qq[
        DELETE FROM tblPersonRegistration_$Data{'Realm'}
        WHERE intPersonID = ?
    ];
    my $q= $db->prepare($st);
    $q->execute($personID);

    my %RegFields = ();
    $RegFields{'personID'} = $personID;
    $RegFields{'gender'} = $gender;
    $RegFields{'personType'} = 'PLAYER';
    $RegFields{'current'} = 1;
    $RegFields{'personSubType'} = 'SubTypePlayer';
    $RegFields{'personEntityRole'} = 'entityRole';
    $RegFields{'personLevel'} = 'AMATEUR';
    $RegFields{'sport'} = 'FOOTBALL';
    $RegFields{'ageLevel'} = 'SENIOR';
    $RegFields{'registrationNature'} = 'NEW';
    $RegFields{'entityID'} = $entityID;
    $RegFields{'originID'} = $originID;
    $RegFields{'originLevel'} = $originLevel;
    my $pRId = 0;
    my %Filters=();

        print "OK.. lets go\n";
        ($pRId, undef) = addRegistration(\%Data, \%RegFields);
        print "DONE\n";
        print "\n\n\n~~~~~PLAYER~~~~\n";
        $Filters{'personType'} = 'PLAYER';
        my (undef, $regos_ref) = getRegistrationData(\%Data, $personID, \%Filters);
        print Dumper($regos_ref);
        print "\n\n\n~~~~~COACH~~~~\n";
        $Filters{'personType'} = 'COACH';
        my (undef, $regos_ref) = getRegistrationData(\%Data, $personID, \%Filters);
        print Dumper($regos_ref);
    print "\n\n\n\n\n";

    ##Now lets do an update
    print "~~UPDATE~~";
        $Filters{'personType'} = 'PLAYER';
        $Filters{'personRegistrationID'} = $pRId;
        my (undef, $regos_ref) = getRegistrationData(\%Data, $personID, \%Filters);
        my $reg_ref = $regos_ref->[0];
        $reg_ref->{'dtFrom'} = '2014-01-07';
        updatePersonRegistration(\%Data, $personID, $pRId, $reg_ref);
        my (undef, $get_ref) = getRegistrationData(\%Data, $personID, \%Filters);
        print Dumper($get_ref);


    print "\n\n\nDONE\n";

}
