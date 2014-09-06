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
use RegistrationItem;
use Data::Dumper;

main();

sub main	{


	my %Data = ();
	my $db = connectDB();
    my $entityID=19;
    my $personRegistrationID = 1;
    my $venueID=749;
	$Data{'db'} = $db;
	$Data{'Realm'} = 1;
	$Data{'RealmSubType'} = 0;
    my %RegFields = ();
    $RegFields{'personType'} = 'PLAYER';
    $RegFields{'personLevel'} = 'AMATEUR';
    $RegFields{'sport'} = 'FOOTBALL';
    $RegFields{'ageLevel'} = 'SENIOR';
    $RegFields{'gender'} = 1;
            print "OK TO CONTINUE FOR ENTITY\n";
        if (isRegoAllowedToSystem(\%Data, $Defs::ORIGIN_SELF, 'NEW', \%RegFields))    {
            print "OK TO CONTINUE - PLAYER\n";
            addWorkFlowTasks(\%Data, 'REGO', 'NEW', $Defs::ORIGIN_SELF, 0,0,$personRegistrationID, 0); ## Person Rego
            my $products = getRegistrationItems(\%Data, 'REGO', 'PRODUCT', $Defs::ORIGIN_SELF, 'NEW', $entityID, $Defs::LEVEL_CLUB, 0, \%RegFields);
            my $docs = getRegistrationItems(\%Data, 'REGO', 'DOCUMENT', $Defs::ORIGIN_SELF, 'NEW', $entityID, $Defs::LEVEL_CLUB, 0, \%RegFields);
    print STDERR Dumper($products);
    print STDERR "\n\nDOCS" . Dumper($docs);
            
        }
        else    {
            print "NOT OK TO CONTINUE - PLAYER\n";
        }
    $RegFields{'personType'} = 'COACH';
    $RegFields{'personLevel'} = 'AMATEUR';
    $RegFields{'sport'} = 'FUTSAL';
    $RegFields{'ageLevel'} = 'SENIOR';
    if (isRegoAllowedToSystem(\%Data, $Defs::ORIGIN_SELF, 'NEW', \%RegFields))    {
        print "OK TO CONTINUE - COACH\n";
    }
    else    {
        print "NOT OK TO CONTINUE - COACH\n";
    }
    

    addWorkFlowTasks(\%Data, 'ENTITY', 'NEW', $Defs::ORIGIN_SELF, $venueID,0,0, 0); ##Venue
#    addWorkFlowTasks(\%Data, 'DOCUMENT', $Defs::ORIGIN_SELF, 0,0,0, 1); ##Document

}
