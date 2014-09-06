#
# $Header: svn://svn/SWM/trunk/web/Reports/ReportAdvanced_FundsReceivedBelowSameAcc.pm 9343 2013-08-26 06:10:36Z dhanslow $
#

package Reports::ReportAdvanced_FundsReceivedBelowSameAcc;

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
			EntityCategories => 1,
		},
	);

	my %config = (
		Name => 'Funds Received within Structure Report',

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
			PaymentForID=> [	
				'Payment For ID',
				{
					active=>1, 
					displaytype=>'text', 
					fieldtype=>'text', 
					allowsort => 1,
					dbfield=>'IF(T.intTableType=1, M.strNationalNum, Entity.intEntityID)'
				}
			],

			TXNTeamJoined => [	
				'Member joined Team',
				{
					active=>1, 
					displaytype=>'text', 
					fieldtype=>'text', 
					allowsort => 1,
				}
			],
		PaymentFor => [	
				'Payment For',
				{
					active=>1, 
					displaytype=>'text', 
					fieldtype=>'text', 
					allowsort => 1,
					dbfield=>'IF(T.intTableType=1, CONCAT(M.strLocalSurname, ", ", M.strLocalFirstname), Entity.strLocalName)'
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
intEntityType=> [
				'Level Receiving Funds',
				{
					active=>1, 
					displaytype=>'lookup', 
					fieldtype=>'dropdown', 
					dropdownoptions => \%Defs::LevelNames, 
					allowsort=>1, 
					multiple=>1, 
					size=>3,
					dbfield=>'ML.intEntityType',
				}
			],

			strProductName => [
				'Product Name',
				{
					displaytype=>'text', 
					fieldtype=>'text', 
					dbfield=>'strProductName'
				}
			],
			strProductGroup=> [
				'Product Grouping',
				{
					displaytype=>'text', 
					fieldtype=>'text', 
					dbfield=>'strProductGroup'
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
			strBankCode=> [
				'BSB Paid Into',
				{
					displaytype=>'text', 
					fieldtype=>'text', 
					dbfield=>'ML.strBankCode'
				}
			],
				strAccountNo=> [
				'Account No Paid Into',
				{
					displaytype=>'text', 
					fieldtype=>'text', 
					dbfield=>'ML.strAccountNo'
				}
			],
			strAccountName=> [
				'Account Name Paid Into',
				{
					displaytype=>'text', 
					fieldtype=>'text', 
					dbfield=>'ML.strAccountName'
				}
			],
			strMPEmail=> [
				'Payment Email',
				{
					displaytype=>'text', 
					fieldtype=>'text', 
					dbfield=>'ML.strMPEmail'
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
				'Order Total',
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
        'Date Funds Sent From SP',
        {
          displaytype=>'date',
          fieldtype=>'date',
          allowsort=>1,
          dbformat=>' DATE_FORMAT(dtRun,"%d/%m/%Y")',
          allowgrouping=>1,
          sortfield=>'dtRun',
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
					displaytype=>'text', 
					fieldtype=>'text', 
					dbfield=>'PaymentClub.strName', 
					dbfrom=>"LEFT JOIN tblClub as PaymentClub ON (PaymentClub.intClubID=intClubPaymentID)",
				}
			],
			intClubCategoryID=> [
        scalar(keys %{$CommonVals->{'EntityCategories'}{$Defs::LEVEL_CLUB}}) ? "$Data->{'LevelNames'}{$Defs::LEVEL_CLUB} Category" : '',
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
			strProductName
			strProductGroup
			intEntityType
			strAccountName
			strMPEmail
			PaymentFor
			PaymentForID
			PaymentFrom
			TXNTeamJoined
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
	my $tempNodeStructureWHERE = '';
	$tempNodeStructureWHERE = qq[ AND int100_ID = $intID ] if ($currentLevel == $Defs::LEVEL_NATIONAL);
	$tempNodeStructureWHERE = qq[ AND int30_ID = $intID ] if ($currentLevel == $Defs::LEVEL_STATE);
	$tempNodeStructureWHERE = qq[ AND int20_ID = $intID ] if ($currentLevel == $Defs::LEVEL_REGION);
	$tempNodeStructureWHERE = qq[ AND int10_ID = $intID ] if ($currentLevel == $Defs::LEVEL_ZONE);
	$tempNodeStructureWHERE = qq[ AND TNS.intAssocID = $intID ] if ($currentLevel == $Defs::LEVEL_ASSOC);
	$tempNodeStructureWHERE = qq[ AND ML.intClubID = $intID ] if ($currentLevel == $Defs::LEVEL_CLUB);
  { #Work out SQL

    $where_list=' AND '.$where_list if $where_list and ($where_levels or $current_where);

    $sql = qq[
			SELECT 
				T.intTransactionID,
				P.strName as strProductName,
				P.strGroup as strProductGroup,
				T.intStatus,
				T.curAmount,
				T.intQty,
				T.dtTransaction,
				DATE_FORMAT(T.dtPaid,"%d/%m/%Y %H:%i") AS dtPaid, 
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
				ML.strBankCode,
				ML.intEntityType,
				ML.strAccountNo,
				ML.strAccountName,
				ML.strMPEmail,
				IF(RF.intClubID>0, C.strName, A.strName) as PaymentFrom,
				TXNTeam.strName as TXNTeamJoined,
				DATE_FORMAT(BFE.dtRun,"%d/%m/%Y") AS dtRun,
				ML.intMyobExportID,
				NState.strName as StateName,
				NRegion.strName as RegionName,
				NZone.strName as ZoneName
			FROM tblMoneyLog as ML
				LEFT JOIN tblBankAccount as BA ON (BA.intEntityID=$intID and BA.intEntityTypeID=$currentLevel)
				LEFT JOIN tblTransactions as T ON (T.intTransactionID = ML.intTransactionID)
				LEFT JOIN tblProducts as P ON (P.intProductID=T.intProductID)
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
				LEFT JOIN tblEntity as TXNEntity ON ( T.intTXNEntityID= TXNEntity.intEntityID)
				LEFT JOIN tblExportBankFile as BFE ON (
					BFE.intExportBSID= ML.intExportBankFileID
				)
				LEFT JOIN tblTempNodeStructure as TNS ON (TNS.intAssocID=T.intAssocID)
				LEFT JOIN tblNode as NNational ON (NNational.intNodeID = TNS.int100_ID)
				LEFT JOIN tblNode as NState ON (NState.intNodeID = TNS.int30_ID)
				LEFT JOIN tblNode as NRegion ON (NRegion.intNodeID = TNS.int20_ID)
				LEFT JOIN tblNode as NZone ON (NZone.intNodeID = TNS.int10_ID)
				WHERE T.intRealmID = $Data->{'Realm'}
					AND ML.intLogType IN ($Defs::ML_TYPE_SPLIT)
					$tempNodeStructureWHERE
					AND ML.intExportBankFileID > 0
					AND TL.intPaymentType IN ($Defs::PAYMENT_ONLINEPAYPAL, $Defs::PAYMENT_ONLINENAB)
					$where_list
					AND (
						(
							(
								ML.strBankCode=BA.strBankCode
								OR REPLACE(ML.strBankCode , '-', '') = REPLACE(BA.strBankCode, '-','')
							)

							AND (
								ML.strAccountNo=BA.strAccountNo
								OR CAST(ML.strAccountNo AS SIGNED)=CAST(BA.strAccountNo AS SIGNED)
							)
						)
						OR
						(BA.strMPEmail !='' AND ML.strMPEmail=BA.strMPEmail AND BA.strMPEmail IS NOT NULL)
					)

    ];
    return ($sql,'');
  }
}

1;
