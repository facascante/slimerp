#
# $Header: svn://svn/SWM/trunk/web/Reports/ReportAdvanced_TXSold.pm 8251 2013-04-08 09:00:53Z rlee $
#

package Reports::ReportAdvanced_TXSold;

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
			MYOB => 1,
		},
	);

  my $txt_Clr = $Data->{'SystemConfig'}{'txtCLR'} || 'Clearance';

	my %config = (
		Name => 'Transactions Sold Report',

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


			intPaymentType=> [
				'Payment Type',
				{
					active=>1, 
					displaytype=>'lookup', 
					fieldtype=>'dropdown', 
					dropdownoptions => \%Defs::paymentTypes, 
					allowsort=>1, 
					dbfield=>'TL.intPaymentType'
				}
			],
			strTXN=> [
				'PayPal Reference Number',
				{
					displaytype=>'text', 
					fieldtype=>'text', 
					dbfield=>'TL.strTXN', 
					active=>1
				}
			],
			intLogID=> [
				'Payment Log ID',
				{
					displaytype=>'text', 
					fieldtype=>'text', 
					dbfield=>'TL.intLogID', 
					allowgrouping=>1, 
					active=>1
				}
			],
			dtSettlement=> [
				'Settlement Date',
				{
					active=>1, 
					displaytype=>'date', 
					fieldtype=>'datetime', 
					allowsort=>1, 
					dbformat=>' DATE_FORMAT(dtSettlement,"%d/%m/%Y %H:%i")'
				}
			],
			intAmount => [
				'Total Amount Paid',
				{
					displaytype=>'currency', 
					fieldtype=>'text', 
					allowsort=>1, 
					dbfield=>'TL.intAmount', 
					active=>1
				}
			],
			SplitAmount=> [
				'Split Amount',
				{
					displaytype=>'currency', 
					fieldtype=>'text', 
					allowsort=>1, 
					total=>1, 
					active=>1
				}
			],
			SplitLevel=> [
				'Split Level',
				{
					displaytype=>'text', 
					fieldtype=>'text', 
					allowsort=>1, 
					active=>1
				}
			],
			PaymentFor=> [
				'Payment For',
				{
					active=>1, 
					displaytype=>'text', 
					fieldtype=>'text', 
					allowsort => 1
				}
			],
			intExportBankFileID=> [
				'PayPal Distribution ID',
				{
					displaytype=>'text', 
					fieldtype=>'text', 
					dbfield=>'intExportAssocBankFileID'
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
			dtRun=> [
				'Date Funds Received',
				{
					displaytype=>'date', 
					fieldtype=>'date', 
					allowsort=>1, 
					dbformat=>' DATE_FORMAT(dtRun,"%d/%m/%Y")',  
					allowgrouping=>1, 
					sortfield=>'TL.dtSettlement'
				}
			],
		},

		Order => [qw(
			intLogID 
			intPaymentType 
			strTXN 
			intAmount 
			dtSettlement 
			PaymentFor 
			SplitLevel 
			SplitAmount 
			intMyobExportID
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

		my $clubWHERE = $currentLevel == $Defs::LEVEL_CLUB 
			? qq[ AND ML.intClubID = $intID ] 
			: '';
		$sql = qq[
      SELECT DISTINCT
				TL.intLogID,
				TL.intAmount,
				TL.strTXN,
				TL.intPaymentType,
				ML.intLogType,
				ML.intEntityType,
				ML.intMyobExportID,
				dtSettlement,
				IF(T.intTableType=$Defs::LEVEL_PERSON, CONCAT(M.strLocalSurname, ", ", M.strLocalFirstname), Entity.strLocalName) as PaymentFor,
				SUM(ML.curMoney) as SplitAmount,
				IF(ML.intEntityType = $Defs::LEVEL_NATIONAL, 'National Split',
						IF(ML.intEntityType = $Defs::LEVEL_STATE, 'State Split',
								IF(ML.intEntityType = $Defs::LEVEL_REGION, 'Region Split',
										IF(ML.intEntityType = $Defs::LEVEL_ZONE, 'Zone Split',
										    IF(ML.intEntityType = $Defs::LEVEL_CLUB, 'Club Split',
										        IF((ML.intEntityType = 0 AND intLogType IN (2,3)), 'Fees', '')
										    )
										)
								)
						)
				) as SplitLevel
			FROM
				tblTransLog as TL
				INNER JOIN tblMoneyLog as ML ON (
						ML.intTransLogID = TL.intLogID
						AND ML.intLogType IN ($Defs::ML_TYPE_SPMAX, $Defs::ML_TYPE_LPF, $Defs::ML_TYPE_SPLIT)
				)
				LEFT JOIN tblTransactions as T ON (
						T.intTransactionID = ML.intTransactionID
				)
				LEFT JOIN tblPerson as M ON (
						M.intPersonID = T.intID
						AND T.intTableType = $Defs::LEVEL_PERSON
				)
				LEFT JOIN tblEntity as Entity ON (
						Entity.intEntityID = T.intID
						AND T.intTableType = $Defs::LEVEL_PERSON
				)
				LEFT JOIN tblRegoForm as RF ON (
						RF.intRegoFormID= TL.intRegoFormID
				)
			WHERE TL.intRealmID = $Data->{'Realm'}
				$clubWHERE
				$where_list
			GROUP BY TL.intLogID
    ];
    return ($sql,'');
  }
}

1;
