#
# $Header: svn://svn/SWM/trunk/web/Reports/ReportAdvanced_FundsReceived.pm 9155 2013-08-05 23:07:47Z dhanslow $
#

package Reports::ReportAdvanced_FundsReceived;

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
      MYOB => 1,
			Products => 1,
		},
	);

	my %config = (
		Name => 'Funds Received Report',

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

			AssocName=> [
				qq[$Data->{'LevelNames'}{$Defs::LEVEL_ASSOC}],
				{
					active=>1, 
					displaytype=>'text', 
					fieldtype=>'text', 
					allowsort => 1
				}
			],
			StateName=> [ ($currentLevel>= $Defs::LEVEL_STATE) ? qq[$Data->{'LevelNames'}{$Defs::LEVEL_STATE}] : '', { active=>1, displaytype=>'text', fieldtype=>'text', allowsort => 1 } ],
			RegionName=> [ ($currentLevel>= $Defs::LEVEL_REGION) ? qq[$Data->{'LevelNames'}{$Defs::LEVEL_REGION}] : '', { active=>1, displaytype=>'text', fieldtype=>'text', allowsort => 1 } ],
			ZoneName=> [ ($currentLevel>= $Defs::LEVEL_ZONE) ? qq[$Data->{'LevelNames'}{$Defs::LEVEL_ZONE}] : '', { active=>1, displaytype=>'text', fieldtype=>'text', allowsort => 1 } ],
			intAssocTypeID => [((scalar(keys %{$CommonVals->{'SubRealms'}}) and  $currentLevel > $Defs::LEVEL_ASSOC)? ($Data->{'LevelNames'}{$Defs::LEVEL_ASSOC}.' Type') : ''),{displaytype=>'lookup', fieldtype=>'dropdown', dropdownoptions=> $CommonVals->{'SubRealms'}, allowsort=>1, allowgrouping => 1}],
				intTransactionID => [
				'Transaction ID' ,
				{
					active=>1, 
					displaytype=>'text', 
					fieldtype=>'text', 
					allowsort => 1
				}
			],
			PaymentFor => [	
				'Payment For',
				{
					active=>1, 
					displaytype=>'text', 
					fieldtype=>'text', 
					allowsort => 1,
					dbfield=>'IF(T.intTableType=1, CONCAT(M.strSurname, ", ", M.strFirstname), Team.strName)'
				}
			],
			PaymentForID => [	
				'Payment For ID',
				{
					active=>1, 
					displaytype=>'text', 
					fieldtype=>'text', 
					allowsort => 1,
					dbfield=>'IF(T.intTableType=1, M.strNationalNum, Team.intTeamID)',
				}
			],
		
			PaymentFrom => [
				'Payment From',
				{
					active=>1, 
					displaytype=>'text', 
					fieldtype=>'text', 
					allowsort => 1, 
					dbfield=>'IF(RF.intClubID>0, C.strName, A.strName)'
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
                                        total=>1
                                }
                        ],
			curMoney => [
				'Money Received (after fees)',
				{
					active=>1, 
					displaytype=>'currency', 
					fieldtype=>'text', 
					allowsort=>1, 
					total=>1
				}
			],			
			intLogID => [
				'Payment Log ID',
				{
					displaytype=>'text', 
					fieldtype=>'text', 
					dbfield=>'TL.intLogID'
				}
			],
      intMyobExportID=> [
        'SP Invoice Run',
        {
          displaytype=>'lookup',
          fieldtype=>'dropdown',
          dropdownoptions => $CommonVals->{'MYOB'}{'Values'},
          active=>1,
          dbfield=>'intMyobExportID'
        }
      ],
			intAmount => [
				'Order Total)',
				{
					displaytype=>'currency', 
					fieldtype=>'text', 
					allowsort=>1, 
					total=>1, 
					dbfield=>'TL.intAmount'
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
					dbfield=>'T.dtPaid',
				#	sortfield=>'T.dtPaid',
				}
			],
			dtSettlement=> [
				'Settlement Date',
				{
					displaytype=>'date', 
					fieldtype=>'date', 
					allowsort=>1, 
					dbformat=>' DATE_FORMAT(TL.dtSettlement,"%d/%m/%Y")',  
					dbfield=>'DATE(TL.dtSettlement)', 
					allowgrouping=>1, 
					sortfield=>'TL.dtSettlement',
				}
			],
			intExportBankFileID => [
				'Distribution ID',
				{
					displaytype=>'text', 
					fieldtype=>'text', 
					dbfield=>'intExportBankFileID'
				}
			],
      dtRun=> [
        'Date Funds Sent by SP',
        {
          displaytype=>'date',
          fieldtype=>'date',
          allowsort=>1,
          dbformat=>' DATE_FORMAT(dtRun,"%d/%m/%Y")',
          allowgrouping=>1,
          sortfield=>'dtRun_RAW',
					dbfield=>'DATE(dtRun)', 
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
			ClubPaymentID=> [
				qq[$Data->{'LevelNames'}{$Defs::LEVEL_CLUB} Payment for],
				{
					active=>1, 
					displaytype=>'text', 
					fieldtype=>'text', 
					dbfield=>'PaymentClub.strName', 
          allowgrouping=>1,
					allowsort=>1, 
				}
			],
            TXNClub=> [
                'Transaction Club',
                {
                    displaytype=>'text',
					fieldtype=>'text', 
					active=>1, 
                    fieldtype=>'text',
                    dbfield=>'TXNClub.strName',
                }
            ],
		intClubCategoryID=> [ scalar(keys %{$CommonVals->{'EntityCategories'}{$Defs::LEVEL_CLUB}}) ? "$Data->{'LevelNames'}{$Defs::LEVEL_CLUB} Category" : '',
        {
          displaytype=>'lookup',
          fieldtype=>'dropdown',
          dropdownoptions=> $CommonVals->{'EntityCategories'}{$Defs::LEVEL_CLUB},
          allowgrouping=>1,
        }
      ],
      intAssocCategoryID=> [
        scalar(keys %{$CommonVals->{'EntityCategories'}{$Defs::LEVEL_ASSOC}}) ? "$Data->{'LevelNames'}{$Defs::LEVEL_ASSOC} Category" : '',
        {
          displaytype=>'lookup',
          fieldtype=>'dropdown',
          dropdownoptions=> $CommonVals->{'EntityCategories'}{$Defs::LEVEL_ASSOC},
          allowgrouping=>1,
        }
      ],
	
		},

		Order => [qw(
			intTransactionID
			intProductID
			PaymentFor
			PaymentForID
			PaymentFrom
			curAmount
			curMoney
			TLstrReceiptRef
			strTXN
			intLogID
			dtPaid
			intExportBankFileID
			dtRun
			intMyobExportID
			AssocName
			intAssocTypeID
			intAssocCategoryID
			intClubCategoryID
			StateName
			RegionName
			ZoneName
      ClubPaymentID
      TXNClub
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
  my $intID = $self->{'EntityID'} || 0;
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

    $sql = qq[
			SELECT  
				T.intTransactionID,
				T.intStatus,
				T.curAmount,
				T.intQty,
				T.dtTransaction,
				DATE_FORMAT(T.dtPaid,"%d/%m/%Y %H:%i") AS dtPaid, 
				T.dtPaid AS dtPaid_RAW,
				T.intExportAssocBankFileID,
				IF(T.intTableType=$Defs::LEVEL_PERSON, CONCAT(M.strLocalSurname, ", ", M.strLocalFirstname), Entity.strLocalName) as PaymentFor,
				IF(T.intTableType=$Defs::LEVEL_PERSON, M.strNationalNum, Entity.intEntityID) as PaymentForID,
				TL.intAmount,
				TL.strTXN,
				TL.intPaymentType,
				T.intProductID,
				TL.intPaymentType,
				TL.intLogID,
				ML.intExportBankFileID,
				ML.curMoney,
				IF(RF.intClubID>0, C.strName, A.strName) as PaymentFrom,
				DATE_FORMAT(BFE.dtRun,"%d/%m/%Y") AS dtRun,
				BFE.dtRun AS dtRun_RAW,
				ML.intMyobExportID,
				NState.strName as StateName,
				NRegion.strName as RegionName,
				NZone.strName as ZoneName,
				TXNEntity.strLocalName as TXNEntity,
				PaymentEntity.strLocalName as EntityPaymentID
			FROM tblMoneyLog as ML
				LEFT JOIN tblTransactions as T ON (T.intTransactionID = ML.intTransactionID)
				LEFT JOIN tblTransLog as TL ON (TL.intLogID = T.intTransLogID)
				LEFT JOIN tblRegoForm as RF ON (RF.intRegoFormID= TL.intRegoFormID)
				LEFT JOIN tblPerson as M ON (
					M.intPersonID = T.intID
					AND T.intTableType = $Defs::LEVEL_PERSON
				)
				LEFT JOIN tblEntity as Entity ON (
					Entity.intEntityID = T.intID
					AND T.intTableType > $Defs::LEVEL_PERSON
				)
				LEFT JOIN tblExportBankFile as BFE ON (
					BFE.intExportBSID= ML.intExportBankFileID
				)
				LEFT JOIN tblTempNodeStructure as TNS ON (TNS.intAssocID=T.intAssocID)
				LEFT JOIN tblNode as NState ON (NState.intNodeID = TNS.int30_ID)
				LEFT JOIN tblNode as NRegion ON (NRegion.intNodeID = TNS.int20_ID)
				LEFT JOIN tblNode as NZone ON (NZone.intNodeID = TNS.int10_ID)
LEFT JOIN tblEntity as TXNEntity ON (TXNEntity.intEntityID=T.intTXNEntityID)
LEFT JOIN tblEntity as PaymentEntity ON (PaymentEntity.intEntityID=intEntityPaymentID)
				WHERE T.intRealmID = $Data->{'Realm'}
					AND ML.intLogType IN ($Defs::ML_TYPE_SPLIT)
					AND ML.intEntityID = $intID
					AND ML.intEntityType = $currentLevel
					AND ML.intExportBankFileID > 0
					AND TL.intPaymentType IN ($Defs::PAYMENT_ONLINEPAYPAL, $Defs::PAYMENT_ONLINENAB)
					$where_list

    ];
    return ($sql,'');
  }
}

1;
