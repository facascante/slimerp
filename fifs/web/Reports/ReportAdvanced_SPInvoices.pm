#
# $Header: svn://svn/SWM/trunk/web/Reports/ReportAdvanced_SPInvoices.pm 8251 2013-04-08 09:00:53Z rlee $
#

package Reports::ReportAdvanced_SPInvoices;

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
		Name => 'SportingPulse Invoice Report',

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
					size=>3
				}
			],
			curAmount => [
				'Original Product Amount',
				{
					active=>1, 
					displaytype=>'currency', 
					fieldtype=>'text', 
					allowsort=>1, 
					total=>1
				}
			],
			curMoney => [
				'Fees Amount',
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
					dropdownorder=> $CommonVals->{'MYOB'}{'Order'}, 
          active=>1,
          dbfield=>'intMyobExportID'
        }
      ],
			intAmount => [
				'Original Total Payment Amount',
				{
					displaytype=>'currency', 
					fieldtype=>'text', 
					allowsort=>1, 
					total=>1, 
					dbfield=>'TL.intAmount'
				}
			],
			dtPaid=> [
				'Date Original Transaction Paid',
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
			intExportBankFileID => [
				'Distribution ID',
				{
					displaytype=>'text', 
					fieldtype=>'text', 
					dbfield=>'intExportBankFileID'
				}
			],
      dtRun=> [
        'Date Fees Taken',
        {
          displaytype=>'date',
          fieldtype=>'date',
          allowsort=>1,
          dbformat=>' DATE_FORMAT(dtRun,"%d/%m/%Y")',
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
			ClubPaymentID=> [
				qq[$Data->{'LevelNames'}{$Defs::LEVEL_CLUB} Payment for],
				{
					displaytype=>'text', 
					fieldtype=>'text', 
					dbfield=>'PaymentClub.strName', 
					dbfrom=>"LEFT JOIN tblClub as PaymentClub ON (PaymentClub.intClubID=intClubPaymentID)",
				}
			],
		},

		Order => [qw(
			intLogID
			intMyobExportID
			curMoney
			dtRun
			intExportBankFileID
			intAmount
			dtPaid
			PaymentFor
			PaymentFrom
			TLstrReceiptRef
			strTXN
			StateName
			RegionName
			ZoneName
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

		my $WHERE = '';
		if ($currentLevel == 5)	{
			$WHERE = qq[ AND ML.intAssocID = $intID AND (RF.intClubID IS NULL or RF.intClubID <= 0) ];
		}
		if ($currentLevel == 3)	{
			$WHERE = qq[ AND ML.intClubID = $intID ];
		}

    $sql = qq[
			SELECT 
				T.intTransactionID,
				T.intStatus,
				TL.intAmount,
				T.curAmount,
				T.dtTransaction,
				T.dtPaid,
				T.intExportAssocBankFileID,
				IF(T.intTableType=$Defs::LEVEL_PERSON, CONCAT(M.strLocalSurname, ", ", M.strLocalFirstname), Entity.strLocalName) as PaymentFor,
				TL.intAmount,
				TL.strTXN,
				TL.intPaymentType,
				T.intProductID,
				TL.intPaymentType,
				TL.intLogID,
				ML.intExportBankFileID,
				ML.curMoney,
				IF(RF.intClubID>0, C.strName, A.strName) as PaymentFrom,
				BFE.dtRun,
				ML.intMyobExportID,
				NState.strName as StateName,
				NRegion.strName as RegionName,
				NZone.strName as ZoneName
			FROM tblMoneyLog as ML
				LEFT JOIN tblTransactions as T ON (T.intTransactionID = ML.intTransactionID)
				LEFT JOIN tblTransLog as TL ON (TL.intLogID = T.intTransLogID)
				LEFT JOIN tblRegoForm as RF ON (RF.intRegoFormID= TL.intRegoFormID)
				LEFT JOIN tblClub as C ON (C.intClubID = RF.intClubID)
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
				WHERE ML.intRealmID = $Data->{'Realm'}
					AND ML.intLogType IN ($Defs::ML_TYPE_SPMAX, $Defs::ML_TYPE_LPF, $Defs::ML_TYPE_GATEWAYFEES)
					$WHERE
					AND ML.intExportBankFileID > 0
					AND TL.intPaymentType IN ($Defs::PAYMENT_ONLINEPAYPAL, $Defs::PAYMENT_ONLINENAB)
					$where_list

    ];
    return ($sql,'');
  }
}

1;
