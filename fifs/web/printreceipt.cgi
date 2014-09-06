#! /usr/bin/perl -w

#
# $Header: svn://svn/SWM/trunk/web/printreceipt.cgi 10128 2013-12-03 04:03:40Z tcourt $
#

## LAST EDITED -> 18/7/2001 ##

use strict;
use CGI qw(param escape unescape);

use lib '.','..',"comp",'PaymentSplit','RegoFormBuilder';

use Reg_common;
use PageMain;
use Defs;
use Utils;
use SystemConfig;
use ConfigOptions;
use Lang;
use TTTemplate;
use Payments;

main();

sub main	{

	# GET INFO FROM URL
	my $action = param('a') || '';
	my $client = param('client') || '';
	my $txlogIDs= param('ids') || '';

	my %clientValues = getClient($client);
	my %Data=();
	my $target='printreceipt.cgi';
	$Data{'target'}=$target;
	$Data{'clientValues'} = \%clientValues;
	# AUTHENTICATE
	my $db=allowedTo(\%Data);
  ($Data{'Realm'}, $Data{'RealmSubType'})=getRealm(\%Data);
	$Data{'SystemConfig'}=getSystemConfig(\%Data);
    my $lang   = Lang->get_handle('', $Data{'SystemConfig'}) || die "Can't get a language handle!";
  $Data{'lang'}=$lang;
	my $assocID=getAssocID(\%clientValues) || '';
	my $DataAccess_ref=getDataAccess(\%Data);
  $Data{'Permissions'}=GetPermissions(
    \%Data,
    $Data{'clientValues'}{'currentLevel'},
    getID($Data{'clientValues'}, $Data{'clientValues'}{'currentLevel'}),
    $Data{'Realm'},
    $Data{'RealmSubType'},
    $Data{'clientValues'}{'authLevel'},
    0,
  );

	my $pageHeading= '';
	my $resultHTML = '';
	my $ID=getID(\%clientValues);
	$Data{'client'}=$client;


	my %receiptData= ();
	if($txlogIDs)	{
		my $st =qq[
			SELECT 
				tblTransLog.*, 
				IF(T.intTableType = $Defs::LEVEL_CLUB, Entity.strLocalName, CONCAT(strLocalFirstname,' ',strLocalSurname)) as Name, 
				DATE_FORMAT(dtLog,'%d/%m/%Y %h:%i') as dtLog_FMT,
				DATE_FORMAT(dtSettlement,'%d/%m/%Y') as dtSettlement,
				Entity.strLocalName as strEntityName

			FROM tblTransLog 
				INNER JOIN tblTXNLogs as TXNLog ON (TXNLog.intTLogID = tblTransLog.intLogID)
				INNER JOIN tblTransactions as T ON (T.intTransactionID = TXNLog.intTXNID)
				LEFT JOIN tblPerson as M ON (M.intPersonID= T.intID and T.intTableType=$Defs::LEVEL_MEMBER)
				LEFT JOIN tblEntity as Entity on (Entity.intEntityID= T.intID and T.intTableType=$Defs::LEVEL_CLUB)
			WHERE intLogID  IN (?)
				AND T.intRealmID = ?
		];
		my $q= $db->prepare($st);
		$q->execute(
			$txlogIDs,
			$Data{'Realm'},
		);

		while(my $field=$q->fetchrow_hashref())	{
			foreach my $key (keys %{$field})  { if(!defined $field->{$key}) {$field->{$key}='';} }
			$field->{'PaymentType'} = $Defs::paymentTypes{$field->{'intPaymentType'}} || '';
			$receiptData{$field->{'intLogID'}}{'Info'} = $field;
		}
		$q->finish();

		my $st_trans = qq[
			SELECT 
				M.strLocalSurname, 
				M.strLocalFirstName, 
				E.*, 
				P.strName, 
				P.strGroup
			FROM tblTransactions as T
				LEFT JOIN tblPerson as M ON (M.intPersonID = T.intID and T.intTableType=$Defs::LEVEL_MEMBER)
				LEFT JOIN tblProducts as P ON (P.intProductID = T.intProductID)
				LEFT JOIN tblEntity as E on (E.intEntityID = T.intID and T.intTableType=$Defs::LEVEL_CLUB)
			WHERE intTransLogID IN (?)
			AND T.intRealmID = ?
		];
		my $qry_trans = $db->prepare($st_trans);
    $qry_trans->execute(
			$txlogIDs,
			$Data{'Realm'},
		);
		while(my $field=$qry_trans->fetchrow_hashref())	{
			foreach my $key (keys %{$field})  { if(!defined $field->{$key}) {$field->{$key}='';} }
			$field->{'InvoiceNo'} = Payments::TXNtoInvoiceNum($field->{intTransactionID});
			push @{$receiptData{$field->{'intTransLogID'}}{'Items'}}, $field;
		}
		$qry_trans->finish();

		my %ContentData = ();
		for my $k (keys %receiptData)	{
			push @{$ContentData{'Receipts'}}, $receiptData{$k};
		}

		my $filename = $Data{'SystemConfig'}{'receiptFilename'} || 'standardreceipt';
		#$receiptData{'BodyLoad'} = qq[ onload="window.print();close();" ];
		$resultHTML = runTemplate(
			\%Data, 
			\%ContentData,
			"txn_receipt/$filename.templ"
		);

	}
	else	{
		$resultHTML = 'Invalid Transactions';
	}

	my $title=$lang->txt($Defs::page_title || 'Receipt');
	print "Content-type: text/html\n\n";
	print $resultHTML;

	disconnectDB($db);

}

