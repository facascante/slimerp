#!/usr/bin/perl

use strict;
use warnings;
use lib "..",'RegoFormBuilder';
use CGI qw(param);
use Reg_common;
use Utils;
use RegoFormObj;
use TTTemplate;
use PageMain;

main(); 

sub main {
    my $client = param('client') || '';
    my $formID = param('fid')    || 0;

    process_error('A formID must be provided.') if !$formID;

    my %Data = ();
    my %clientValues = getClient($client);

    $Data{'clientValues'} = \%clientValues;
    $Data{'db'}           = allowedTo(\%Data);


    my $dbh = $Data{'db'};


    my $RegoFormObj = RegoFormObj->load(db=>$dbh, ID=>$formID);

    process_error('Invalid formID provided.') if !$RegoFormObj;

    my $realmID  = $RegoFormObj->getValue('intRealmID');
    my $formType = $RegoFormObj->getValue('intRegoType');

    my $regoFormObjs = RegoFormObj->getListOfParentBodyForms(dbh=>$dbh, realmID=>$realmID, formTypes=>$formType, assocID=>$Data{'clientValues'}{'assocID'});

    my @pbForms = ();

    {
        for my $RegoFormObj(@$regoFormObjs) {
            push @pbForms, {
                'formID'   => $RegoFormObj->getValue('intRegoFormID'),
                'formName' => $RegoFormObj->getValue('strRegoFormName'),
            };
        }
    }

    my %templateData = (
        target  => 'main.cgi',
        client  => $client,
        action  => 'A_ORF_r',
        formID  => $formID,
        pbForms => \@pbForms,
    );

    my $templateFile = 'regoform/backend/list_parent_body_forms.templ';
    my $body = runTemplate(\%Data, \%templateData, $templateFile);

    disconnectDB($dbh);

    printBasePage($body, 'Sportzware Membership');
}

sub process_error {
    my ($message) = @_;
    die "$message";
}
