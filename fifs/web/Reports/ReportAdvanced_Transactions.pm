#
# $Header: svn://svn/SWM/trunk/web/Reports/ReportAdvanced_Transactions.pm 11151 2014-03-27 23:12:43Z dhanslow $
#

package Reports::ReportAdvanced_Transactions;

use strict;
use lib ".";
use ReportAdvanced_Common;
use Reports::ReportAdvanced;
our @ISA =qw(Reports::ReportAdvanced);


use strict;

sub _getConfiguration {
	my $self = shift;

	my $currentLevel = $self->{'EntityTypeID'} || 0;
	my $Data = $self->{'Data'};
	my $SystemConfig = $self->{'SystemConfig'};
	my $clientValues = $Data->{'clientValues'};
	my $CommonVals = getCommonValues(
		$Data,
		{
			SubRealms => 1,
      FieldLabels => 1,
      DefCodes => 1,
			Products => 1,
			EntityCategories => 1,
			Seasons =>1,
		},
	);

  my $txt_Clr = $Data->{'SystemConfig'}{'txtCLR'} || 'Clearance';
	my $txt_SeasonName= $Data->{'SystemConfig'}{'txtSeason'} || 'Season';
	my $txt_SeasonNames= $Data->{'SystemConfig'}{'txtSeasons'} || 'Seasons';
	my $hideSeasons = $CommonVals->{'Seasons'}{'Hide'} || 0;


	my %config = (
		Name => 'Detailed Transactions Report',

		StatsReport => 0,
		MemberTeam => 0,
		ReportEntity => 3,
		ReportLevel => 0,
		Template => 'default_adv',
    TemplateEmail => 'default_adv_CSV',
		DistinctValues => 1,
    SQLBuilder => \&SQLBuilder,
    DefaultPermType => 'NONE',

		Fields => {
			
			StateName=> [ ($currentLevel>= $Defs::LEVEL_STATE) ? qq[$Data->{'LevelNames'}{$Defs::LEVEL_STATE}] : '', { 'dbfield'=>'NState.strName', active=>1, displaytype=>'text', fieldtype=>'text', allowsort => 1, dbfield=>'NState.strName'  } ],
			RegionName=> [ ($currentLevel>= $Defs::LEVEL_REGION) ? qq[$Data->{'LevelNames'}{$Defs::LEVEL_REGION}] : '', {dbfield=>'NRegion.strName', active=>1, displaytype=>'text', fieldtype=>'text', allowsort => 1, dbfield=>'NRegion.strName' } ],
			ZoneName=> [ ($currentLevel>= $Defs::LEVEL_ZONE) ? qq[$Data->{'LevelNames'}{$Defs::LEVEL_ZONE}] : '', { dbfield=>'NZone.strName',active=>1, displaytype=>'text', fieldtype=>'text', allowsort => 1,, dbfield=>'NZone.strName'  } ],
			strTitle=> ["Competition Name",{displaytype=>'text', fieldtype=>'text', active=>1, allowgrouping=>1, allowsort=>1 , dbfield=>'strTitle'}],

			intTransactionID => [
				'Transaction ID' ,
				{
					active=>1, 
					displaytype=>'text', 
					fieldtype=>'text', 
					allowsort => 1,
					dbfield=>'T.intTransactionID'
				}
			],
			PaymentFor => [	
				'Payment For',
				{
					active=>1, 
					displaytype=>'text', 
					fieldtype=>'text', 
					allowsort => 1,
			}
			],
			intProductID=> [
				'Product',
				{
					active=>1, 
					displaytype=>'lookup', 
					fieldtype=>'dropdown', 
					dropdownoptions => $CommonVals->{'Products'}{'Options'},  
					dropdownorder=> $CommonVals->{'Products'}{'Order'}, 
					allowsort=>1, 
					multiple=>1, 
					size=>3,
					dbfield=>'T.intProductID',
				}
			],
			curAmount => [
				'Line Item Total',
				{
					active=>1, 
					displaytype=>'currency', 
					fieldtype=>'text', 
					allowsort=>1, 
					total=>1
				}
			],
			curPerItem => [
                                'Item Cost',
                                {
                                        active=>1,
                                        displaytype=>'currency',
                                        fieldtype=>'text',
                                        allowsort=>1,
                                        total=>1,
                                	dbfield=>'T.curPerItem'	
				}
                        ],

			intQty => [
				'Quantity',
				{
					displaytype=>'text', 
					fieldtype=>'text', 
					allowsort => 1, 
					total=>1,
					dbfield=>'T.intQty'
				}
			],
			strReceiptRef => [
				'Manual Receipt Reference',
				{
					displaytype=>'text', 
					fieldtype=>'text', 
					dbfield=>'TL.strReceiptRef',
				}
			],
			intPaymentType=> [
				'Payment Type',
				{
					active=>1, 
					displaytype=>'lookup', 
					fieldtype=>'dropdown', 
					dropdownoptions => \%Defs::paymentTypes, 
					allowsort=>1, 
					dbfield=>'TL.intPaymentType', 
					allowgrouping=>1
				}
			],
			strTXN=> [
				'Bank Reference Number',
				{
					displaytype=>'text', 
					fieldtype=>'text', 
					dbfield=>'TL.strTXN',
				}
			],
			intLogID => [
				'Payment Log ID',
				{
					displaytype=>'text', 
					fieldtype=>'text', 
					dbfield=>'TL.intLogID',
					allowsort=>1, 
				}
			],
			intAmount => [
				'Order Total',
				{
					displaytype=>'currency', 
					fieldtype=>'text', 
					allowsort=>1, 
					total=>1, 
					dbfield=>'TL.intAmount'
				}
			],
			dtTransaction=> [
				'Transaction Date',
				{
					active=>1, 
					displaytype=>'date', 
					fieldtype=>'datetime', 
					allowsort=>1, 
					dbformat=>' DATE_FORMAT(T.dtTransaction,"%d/%m/%Y %H:%i")', 
					dbfield=>'T.dtTransaction', 
					sortfield=>'T.dtTransaction'
				}
			],
			dtPaid=> [
				'Payment Date',
				{
					active=>1, 
					displaytype=>'date', 
					fieldtype=>'datetime', 
					allowsort=>1, 
					dbformat=>' DATE_FORMAT(T.dtPaid,"%d/%m/%Y %H:%i")', 
					dbfield=>'T.dtPaid'
				}
			],
			dtSettlement=> [
				'Settlement Date',
				{
					displaytype=>'date', 
					fieldtype=>'date', 
					allowsort=>1, 
					dbformat=>' DATE_FORMAT(TL.dtSettlement,"%d/%m/%Y")',  
					dbfield=>'TL.dtSettlement', 
					allowgrouping=>1, 
					sortfield=>'TL.dtSettlement'
				}
			],
			intStatus=> [
				'Transaction Status',
				{
					active=>1, 
					displaytype=>'lookup', 
					fieldtype=>'dropdown', 
					dropdownoptions => \%Defs::TransactionStatus , 
					allowsort=>1, 
					dbfield=>'T.intStatus'
				}
			],
			TXNNotes=> [
				'Transaction Notes',
				{
					displaytype=>'text', 
					fieldtype=>'text', 
					dbfield=>'T.strNotes'
				}
			],
			TLComments=> [
				'Payment Notes',
				{
					displaytype=>'text', 
					fieldtype=>'text', 
					dbfield=>'TL.strComments'
				}
			],
			intExportAssocBankFileID => [
				'Distribution ID',
				{
					displaytype=>'text', 
					fieldtype=>'text', 
					dbfield=>'intExportAssocBankFileID'
				}
			],
			EntityPaymentID=> [
				qq[$Data->{'LevelNames'}{$Defs::LEVEL_PERSON} $Data->{'LevelNames'}{$Defs::LEVEL_CLUB}],
				{
					displaytype=>'text', 
					fieldtype=>'text', 
					dbfield=>'PaymentEntity.strLocalName', 
				}
			],
		},

		Order => [qw(
			intTransactionID
			intProductID
			PaymentFor
			curPerItem
			intQty
			curAmount
			strReceiptRef
			intPaymentType
			strTXN
			intLogID
			TLComments
			intAmount
			dtTransaction
			dtPaid
			intStatus
			TXNNotes
			EntityPaymentID
			strTitle
			intNewSeasonID
		)],
		OptionGroups => {
			default => ['Details',{}],
		},

		Config => {
			FormFieldPrefix => 'c',
			FormName => 'txnform_',
			EmailExport => 1,
			limitView  => 5000,
			EmailSenderAddress => $Defs::admin_email,
			SecondarySort => 1,
			RunButtonLabel => 'Run Report',
		},
	);
	$self->{'Config'} = \%config;
}

sub SQLBuilder  {
  my($self, $OptVals, $ActiveFields) =@_ ;
  my $currentLevel = $self->{'EntityTypeID'} || 0;
  my $Data = $self->{'Data'};
  my $clientValues = $Data->{'clientValues'};
  my $SystemConfig = $Data->{'SystemConfig'};

  my $from_levels = $OptVals->{'FROM_LEVELS'};
  my $from_list = $OptVals->{'FROM_LIST'};
  my $where_levels = $OptVals->{'WHERE_LEVELS'};
  my $where_list = $OptVals->{'WHERE_LIST'};
  my $current_from = $OptVals->{'CURRENT_FROM'};
  my $current_where = $OptVals->{'CURRENT_WHERE'};
  my $select_levels = $OptVals->{'SELECT_LEVELS'};

  my $sql = '';
  { #Work out SQL

    $where_list=' AND '.$where_list if $where_list and ($where_levels or $current_where);
		my $RealmLPF_Ids = $SystemConfig->{'LPF_ids'} 
			? $SystemConfig->{'LPF_ids'} 
			: 0;

    my $txnClub_WHERE = '';
    my $Club_JOIN= '';
    if ($currentLevel == $Defs::LEVEL_CLUB and $self->{'EntityID'})  {
            $txnClub_WHERE= qq[ AND T.intTXNClubID IN (0, $self->{'EntityID'})];
            $txnClub_WHERE.= qq[ AND ((TL.intEntityPaymentID IN (0, $self->{'EntityID'}) or TL.intEntityPaymentID IS NULL) AND  (Team.intClubID = $self->{'EntityID'} OR MC.intClubID=$self->{'EntityID'})) ];
						$Club_JOIN = qq[ LEFT JOIN tblPerson_Clubs as MC ON (M.intPersonID=MC.intMemberID AND MC.intClubID=$self->{'EntityID'} AND MC.intStatus=1) ];
		}
        my $tns_WHERE = '';
		$tns_WHERE = qq[AND int100_ID=$clientValues->{'natID'}] if ($currentLevel == $Defs::LEVEL_NATIONAL);
		$tns_WHERE = qq[AND int30_ID=$clientValues->{'stateID'}] if ($currentLevel == $Defs::LEVEL_STATE);
		$tns_WHERE = qq[AND int20_ID=$clientValues->{'regionID'}] if ($currentLevel == $Defs::LEVEL_REGION);
		$tns_WHERE = qq[AND int10_ID=$clientValues->{'zoneID'}] if ($currentLevel == $Defs::LEVEL_ZONE);

    $sql = qq[
      SELECT DISTINCT
				T.intTransactionID, 
				T.intStatus, 
				T.curAmount, 
				T.curPerItem,
				T.intQty, 
				T.dtTransaction, 
				T.dtPaid, 
				T.intExportAssocBankFileID, 
				IF(
					T.intTableType=$Defs::LEVEL_PERSON, 
					CONCAT(M.strLocalSurname, ", ", M.strLocalFirstname), 
					Team.strName
				) as PaymentFor, 
				TL.intAmount, 
				TL.strTXN, 
				TL.strReceiptRef,
				TL.intPaymentType, 
				T.intProductID, 
				TL.intPaymentType, 
				TL.intLogID, 
				T.strNotes as TXNNotes,  
				TL.strComments as TLComments,  
				PaymentEntity.strLocalName AS EntityPaymentID,
				P.strName,
			FROM tblTransactions as T
				LEFT JOIN tblProducts as P ON (P.intProductID=T.intProductID)
				LEFT JOIN tblTransLog as TL ON (TL.intLogID = T.intTransLogID)
				LEFT JOIN tblPerson as M ON (M.intPersonID = T.intID AND T.intTableType = $Defs::LEVEL_PERSON AND M.intStatus!=-1)
				LEFT JOIN tblEntity as Entity ON (Entity.intEntityID = T.intID AND T.intTableType = $Defs::LEVEL_CLUB)
				LEFT JOIN tblEntity as PaymentEntity ON (PaymentEntity.intEntityID = TL.intEntityPaymentID)
				$Club_JOIN
			WHERE T.intRealmID = $Data->{'Realm'}
				 AND NOT (
         	T.intProductID IN ($RealmLPF_Ids)
         	AND T.intStatus = 0 
         )
				AND (
					(T.intTableType=$Defs::LEVEL_PERSON AND M.intPersonID IS NOT NULL) OR
					(T.intTableType=$Defs::LEVEL_CLUB AND Team.intTeamID IS NOT NULL)
				    ) 
				 AND T.intStatus <> -1
				$tns_WHERE
        $txnClub_WHERE
				$where_list
 ];
warn $sql;
    return ($sql,'');
  }
}

1;
