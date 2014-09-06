#
# $Header: svn://svn/SWM/trunk/web/ListTransactions.pm 9565 2013-09-20 05:46:06Z tcourt $
#

package ListTransactions;

## LAST EDITED -> 10/09/2007 ##

require Exporter;
@ISA =  qw(Exporter);
@EXPORT = qw(listProdTransactions);
@EXPORT_OK = qw(listProdTransactions);

use strict;
use CGI qw(param unescape escape);

use lib '.', "..";
use Defs;
use Reg_common;
use FormHelpers;
use CGI;
use GridDisplay;
use Seasons;

sub listProdTransactions {
  my($Data, $personID, $assocID) = @_;

print STDERR qq[TCTCTCTCTCTC \n\n];

  $personID ||= 0;
  $assocID ||= 0;
  my $db=$Data->{'db'};
  my $resultHTML = '';
  my $lang = $Data->{'lang'};
  my %textLabels = (
    'addTran' => $lang->txt('Add a Transaction'),
    'amountDue' => $lang->txt('Amount Due'),
    'amountPaid' => $lang->txt('Amount Paid'),
    'assoc' => $lang->txt('Association'),
    'listOfTrans' => $lang->txt('List of Transactions'),
    'name' => $lang->txt('Name'),
    'noTransFound' => $lang->txt('No Transactions can be found in the database.'),
    'qty' => $lang->txt('Qty'),
    'status' => $lang->txt('Status'),
  );
  my $orignodename='';
  my $statement =qq[
    SELECT 
      P.strName, 
      T.*, 
      E.strLocalName as EntityName
    FROM 
      tblProdTransactions as T
      INNER JOIN tblProducts as P ON P.intProductID = T.intProductID
      LEFT JOIN tblEntity as E ON (E.intEntityID = T.intEntityID)
    WHERE 
      T.intPersonID = ?
  ];
  if ($Data->{'clientValues'}{'assocID'})  {
    $statement .= qq[
      AND (T.intAssocID=$Data->{'clientValues'}{'assocID'} or P.intAssocUnique = 1)
    ]
  }
  $statement .= qq[
    ORDER BY T.dtTransaction
  ];
  my $query = $db->prepare($statement);
  $query->execute($personID);
  my $found = 0;
  my $client=setClient($Data->{'clientValues'});
  my $currentname='';
#  while (my $dref = $query->fetchrow_hashref) {
#    $dref->{status} = $dref->{intStatus} == $Defs::TXN_PAID ? $Defs::ProdTransactionStatus{$Defs::TXN_PAID} : $Defs::ProdTransactionStatus{$Defs::TXN_UNPAID};
#    $dref->{delete} = qq[<a href="$Data->{target}?a=M_PRODTXN_DEL&amp;client=$client&amp;tID=$dref->{intTransactionID}">Delete</a>];
#    $dref->{delete} = '' if ($dref->{intAssocID} != $Data->{'clientValues'}{'assocID'});
#    $dref->{delete} = '' if $Data->{'ReadOnlyLogin'};
#    $resultHTML.=list_row($dref, [qw(strName AssocName intQty curAmountDue curAmountPaid status delete)],["$Data->{'target'}?client=$client&amp;a=M_PRODTXN_EDIT&amp;tID=$dref->{intTransactionID}"],($found)%2) if ($dref->{intAssocID} == $Data->{'clientValues'}{'assocID'});
#    $resultHTML.=list_row($dref, [qw(strName AssocName intQty curAmountDue curAmountPaid status delete)],[""],($found)%2) if ($dref->{intAssocID} != $Data->{'clientValues'}{'assocID'});
#    $found++;
#  }
#  $query->finish;

  $found = 0;
  my @rowdata  = ();
  while (my $dref = $query->fetchrow_hashref()) {
    my %row = ();
    for my $i (qw(intTransactionID strName intQty EntityName intAmount dtStart dtEnd strNotes)) {
      $row{$i} = $dref->{$i};
    }
    $row{'id'} = $dref->{'intTransactionID'};
    push @rowdata, \%row;
    $found++;
  }
  if (!$found) {
    $resultHTML .= textMessage($textLabels{'noTransFound'});
  }
  else  {

    my $memfieldlabels=FieldLabels::getFieldLabels($Data,$Defs::LEVEL_PERSON);
    my @headers = (
      {
        type => 'RowCheckbox',
      },
      {
        name => $Data->{'lang'}->txt('Invoice Number'),
        field => 'intTransactionID',
      },
      {
        name => $Data->{'lang'}->txt('Item Name'),
        field => 'strName',
      },
      {
        name => $Data->{'lang'}->txt('Quantity'),
        field => 'intQty',
      },
      {
        name => $Data->{'lang'}->txt('Association'),
        field => 'AssocName',
      },
      {
        name => $Data->{'lang'}->txt('Amount'),
        field => 'intAmount',
      },
      {
        name => $Data->{'lang'}->txt('Start Date'),
        field => 'dtStart',
      },
      {
        name => $Data->{'lang'}->txt('End Date'),
        field => 'dtEnd',
      },
      {
        name => $Data->{'lang'}->txt('Notes'),
        field => 'strNotes',
      },
    );
    my $grid  = showGrid(
      Data => $Data,
      columns => \@headers,
      rowdata => \@rowdata,
      gridid => 'grid',
      width => '99%',
      height => 700,
    );
    $resultHTML = qq[
      <table class="listTable">
        $grid
      </table>
    ];
  }
  my $title = $textLabels{'listOfTrans'};
  my $addlink=qq[<div class="changeoptions"><a href="$Data->{'target'}?client=$client&amp;a=M_PRODTXN_ADD"><img src="images/add_icon.gif" border="0" alt="$textLabels{'addTran'}" title="$textLabels{'addTran'}"></a></div>];
  $addlink = '' if $Data->{'ReadOnlyLogin'};
  $title = $addlink.$title;
  return ($resultHTML, $title);
}

1;
