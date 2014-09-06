#
# $Header: svn://svn/SWM/trunk/web/ProdTransactions.pm 9083 2013-07-26 01:55:22Z tcourt $
#

package ProdTransactions;

require Exporter;
@ISA =  qw(Exporter);
@EXPORT = qw(displayProdTransactions updateProdTransactions handleProdTransactions insertDefaultRegoTransaction);
@EXPORT_OK = qw(displayProdTransactions updateProdTransactions handleProdTransactions insertDefaultRegoTransaction);

use strict;
use CGI qw(param unescape escape);

use lib '.';
use Reg_common;
use Defs;
use Utils;
use FormHelpers;
use HTMLForm;
use List;

use Payments;

# GET INFORMATION RELATING TO THIS MEMBERS TYPE (IE. COACH, PLAYER ETC)

sub handleProdTransactions	{
	my($action, $Data, $memberID, $assocID)=@_;


	my $ID=param("tID") || 0;
	my $type=param("ty") || $Defs::MEMBER_TYPE_PLAYER;
	my $edit=param("e") || 0;

  my $resultHTML='';
	my $heading='';

	

  if ($action eq 'M_PRODTXN_LIST') {
		($resultHTML,$heading) = listProdTransactions($Data, $memberID, $assocID);
  }
  elsif ($action eq 'M_PRODTXN_EDIT') {
		($resultHTML,$heading) = displayProdTransaction($Data, $memberID, $ID, 1);
  }
  elsif ($action eq 'M_PRODTXN_ADD') {
		($resultHTML,$heading) = displayProdTransaction($Data, $memberID, 0, 1);
  }
  elsif ($action eq 'M_PRODTXN_DEL') {
		($resultHTML,$heading) = deleteProdTransaction($Data, $memberID, $ID);
  }
  if ($action eq 'M_PRODTXN_FAILURE') {
	my $intLogID=param("ci") || '';
		processTransLogFailure($Data->{'db'}, $intLogID);
		($resultHTML,$heading) = ("FAILURE , do we need to update DB ?", "FAILURE");
  }

	$heading||='Transactions';
  return ($resultHTML,$heading);

}

sub deleteProdTransaction   {

        my ($Data, $intMemberID, $id) = @_;
        my $db=$Data->{'db'} || undef;

        my $st = qq[
                DELETE FROM tblProdTransactions
                WHERE intMemberID = $intMemberID
                        AND intTransactionID = $id
			LIMIT 1
        ];
        my $query = $db->prepare($st);
        $query->execute;

	my $client=setClient($Data->{'clientValues'}) || '';
	my $body = qq[Transaction has been deleted
<br>
<div class="OKmsg">Record updated successfully</div> <br>
                                        <a href="$Data->{'target'}?client=$client&amp;a=M_PRODTXN_LIST">Return to Transactions</a>
];
return ($body, "Transaction deleted");
}


sub displayProdTransaction	{

  my($Data, $memberID, $id, $edit) = @_;

	my $db=$Data->{'db'} || undef;
	my $assocID= $Data->{'clientValues'}{'assocID'} || -1;
  my $client=setClient($Data->{'clientValues'}) || '';
	my $target=$Data->{'target'} || '';
	my $option=$edit ? ($id ? 'edit' : 'add')  :'display' ;
	my $type2=param("ty2") || '';

  my $resultHTML = '';
	my $toplist='';

	my %DataVals=();
	my $statement=qq[
		SELECT P.strName, T.* , DATE_FORMAT(dtTransaction ,"%d/%m/%Y") AS dtTransaction, DATE_FORMAT(dtPaid ,"%d/%m/%Y") AS dtPaid

		FROM tblProdTransactions as T INNER JOIN tblProducts as P ON (P.intProductID = T.intProductID)
		WHERE intMemberID=$memberID
			AND T.intTransactionID = $id
	];

	my $query = $db->prepare($statement);
	my $RecordData={};
	$query->execute;
	my $dref=$query->fetchrow_hashref();
	my $txnupdate=qq[
		UPDATE tblProdTransactions
			SET --VAL--, dtPaid = if(intStatus=1 and dtPaid IS NULL, SYSDATE(), dtPaid)
		WHERE intTransactionID=$id
	];
	my $txnadd=qq[
		INSERT INTO tblProdTransactions (intMemberID, intAssocID, dtTransaction, --FIELDS--, dtPaid)
			VALUES ($memberID, $Data->{'clientValues'}{'assocID'}, SYSDATE(), --VAL--,  if(intStatus=1, SYSDATE(), NULL))
	];
  my $st_prods=qq[ SELECT intProductID, strName FROM tblProducts WHERE intRealmID = $Data->{'Realm'} and (intAssocID =0 or intAssocID=$Data->{'clientValues'}{'assocID'})];
  my $st_paymenttypes=qq[ SELECT intPaymentTypeID, strPaymentType FROM tblPaymentTypes WHERE intRealmID = $Data->{'Realm'} and (intAssocID =0 or intAssocID=$Data->{'clientValues'}{'assocID'})];
  my ($prods_vals,$prods_order)=getDBdrop_down_Ref($Data->{'db'},$st_prods,'');
  my ($paytypes_vals,$paytypes_order)=getDBdrop_down_Ref($Data->{'db'},$st_paymenttypes,'');


	my %FieldDefs = (
		TXN => {
			fields => {
				strReceiptRef=> {
					label => 'Receipt Ref',
					type => 'text',
					size => 30,
					value => $dref->{'strReceiptRef'},
				},
				intStatus=> {
			        label => "Paid ?",
                	value => $dref->{'intStatus'},
                	type  => 'checkbox',
                	displaylookup => {$Defs::TXN_PAID => $Defs::ProdTransactionStatus{$Defs::TXN_PAID}, $Defs::TXN_UNPAID => $Defs::ProdTransactionStatus{$Defs::TXN_UNPAID}},
            	},
				intDelivered=> {
			        label => "Delivered ?",
                	value => $dref->{'intDelivered'},
                	type  => 'checkbox',
                	displaylookup => {0=>'Undelivered', 1=>'Delivered'},
            	},
				dtPaid=> {
					label => 'Date Paid',
					type => 'text',
					readonly=>1,
					size => 30,
					value => $dref->{'dtPaid'},
				},
				intQty=> {
					label => 'Quantity',
					type => 'text',
					size => 8,
					value => $dref->{'intQty'},
				},
				curAmountPaid=> {
					label => 'Amount Paid',
					type => 'text',
					size => 8,
					value => $dref->{'curAmountPaid'},
				},
				curAmountDue=> {
					label => 'Amount Due',
					type => 'text',
					size => 8,
					value => $dref->{'curAmountDue'},
				},
				strNotes=> {
					label => 'Notes',
					type => 'textarea',
					value => $dref->{'strNotes'},
					rows => 5,
                	cols=> 45,
				},
			intPaymentType=> {
          		label => 'Payment Type',
          		type => 'lookup',
          		value => $dref->{'intPaymentType'},
          		options =>  $paytypes_vals,
          		firstoption => ['','Select Payment Type'],
        	},
			intProductID => {
          		label => 'Product',
          		type => 'lookup',
          		compulsory => 1,
          		value => $dref->{'intProductID'},
          		options =>  $prods_vals,
          		firstoption => ['','Select Product'],
        	},
		},
		order => [qw(intProductID curAmountDue curAmountPaid intPaymentType dtPaid intQty strReceiptRef intStatus intDelivered strNotes)],
			options => {
				labelsuffix => ':',
				hideblank => 1,
				target => $Data->{'target'},
				formname => 'txn_form',
				submitlabel => 'Update Member Transaction',
				introtext => 'auto',
				buttonloc => 'bottom',
				updateSQL => $txnupdate,
				addSQL => $txnadd,
				beforeaddFunction => \&preTXNAddUpdate,
				beforeupdateFunction => \&preTXNAddUpdate,
				beforeaddParams => [$option,$Data,$Data->{'db'}, $client, $memberID, 0],
				beforeupdateParams => [$option,$Data,$Data->{'db'}, $client, $memberID, $id],

        auditFunction=> \&auditLog,
        auditAddParams => [
          $Data,
          'Create',
          'Product Transactions'
        ],
        auditEditParams => [
          $id,
          $Data,
          'Update',
          'Product Transactions'
        ],

				stopAfterAction => 1,
				updateOKtext => qq[
					<div class="OKmsg">Record updated successfully</div> <br>
					<a href="$Data->{'target'}?client=$client&amp;a=M_PRODTXN_LIST">Return to Transaction</a>
				],
				addOKtext => qq[
					<div class="OKmsg">Record updated successfully</div> <br>
					<a href="$Data->{'target'}?client=$client&amp;a=M_PRODTXN_LIST">Return to Transaction</a>
				],
			},
			sections => [ ['main','Details'], ],
			carryfields =>  {
				client => $client,
				a=> 'M_PRODTXN_EDIT',
				tID => $id,
			},
		},
	);
	($resultHTML, undef )=handleHTMLForm($FieldDefs{'TXN'}, undef, $option, '',$db);

	if($option eq 'display')	{
		$resultHTML .=allowedAction($Data, 'txn_e') ?qq[ <a href="$target?a=M_PRODTXN_EDIT&amp;tID=$dref->{'intTransactionID'}&amp;client=$client">Edit Details</a> ] : '';
	}



		$resultHTML=qq[
			<div>This member does not have any Transaction information to display.</div>
		] if !ref $dref;

		$resultHTML=qq[
				<div class="alphaNav">$toplist</div>
				<div>
					$resultHTML
				</div>
		];
		my $heading=qq[Transactions];
		return ($resultHTML,$heading);
}

sub preTXNAddUpdate	{

	my($params, $action, $Data,$db, $client, $memberID, $transID)=@_;

	$memberID ||= 0;
	$transID ||=0;
	my $assocID = $Data->{'clientValues'}{'assocID'} || 0;
	my $prodID = $params->{'d_intProductID'} || 0;
	
	my $st = qq[
		SELECT T.intTransactionID
		FROM tblProdTransactions as T INNER JOIN tblProducts as P ON (T.intProductID = P.intProductID)
		WHERE T.intMemberID = $memberID
			AND T.intAssocID = $assocID
			AND T.intProductID = $prodID
			AND P.intAssocUnique = 1
	];
	$st .= qq[ AND T.intTransactionID <> $transID] if $transID;
	$st .= qq[
		LIMIT 1
	];
    	my $query = $db->prepare($st) or query_error($st);
    	$query->execute or query_error($st);
    	my ($intExistingTransactionID) = $query->fetchrow_array();
	$intExistingTransactionID ||= 0;

	my $error_text = qq[
		<div class="warningmsg">You are only allowed to have one instance of the selected product</div>
		<a href="$Data->{'target'}?client=$client&amp;a=M_PRODTXN_LIST">Return to Transaction</a>
	];
	return (0,$error_text) if $intExistingTransactionID;
	return (1,'');
		
	
}

sub insertDefaultRegoTransaction	{

    my ($db, $intMemberID, $intAssocID) = @_;

    $intAssocID ||= 0;
    $intMemberID ||= 0;

    my $statement = qq[
        SELECT intDefaultRegoProductID, PP.curAmount, P.curDefaultAmount
        FROM tblAssoc LEFT JOIN tblProductPricing as PP ON (PP.intProductID = tblAssoc.intDefaultRegoProductID AND PP.intID = $intAssocID and intLevel=$Defs::LEVEL_ASSOC)
			LEFT JOIN tblProducts as P ON (P.intProductID = tblAssoc.intDefaultRegoProductID)
        WHERE tblAssoc.intAssocID = $intAssocID
    ];
    my $query = $db->prepare($statement) or query_error($statement);
    $query->execute or query_error($statement);
    my ($intDefaultProductID, $PPamount, $defaultAmount) = $query->fetchrow_array();
	$intDefaultProductID ||= 0;
	$PPamount ||= 0;
	$defaultAmount ||=0;

    my $intProductID = $intDefaultProductID || return;
	
	my $amount = $PPamount || $defaultAmount || 0;

    $statement = qq[
        SELECT intTransactionID
        FROM tblProdTransactions
        WHERE intMemberID = $intMemberID
            AND intProductID = $intProductID
        	AND intAssocID = $intAssocID
    ];
    $query = $db->prepare($statement) or query_error($statement);
    $query->execute or query_error($statement);
    my $count = $query->fetchrow_array() || 0;

    if (! $count)   {
        $statement = qq[
            INSERT INTO tblProdTransactions
            (intStatus, curAmountDue, intProductID, intQty, dtTransaction, intMemberID, intAssocID)
            VALUES (0,$amount, $intProductID, 1, SYSDATE(), $intMemberID, $intAssocID)
        ];
        $query = $db->prepare($statement) or query_error($statement);
        $query->execute or query_error($statement);

        #$statement = qq[
            #UPDATE tblMember
            #SET intConsentSignatureSighted= 0
            #WHERE intMemberID = $intMemberID
            #LIMIT 1
        #];
        #$query = $db->prepare($statement) or query_error($statement);
        #$query->execute or query_error($statement);
    }
    return;

}
1;
