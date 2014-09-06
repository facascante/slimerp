#
# $Header: svn://svn/SWM/trunk/web/admin/ClearDollar.pm 8251 2013-04-08 09:00:53Z rlee $
#

package ClearDollar;

require Exporter;
@ISA =  qw(Exporter);
@EXPORT = qw(handle_clearDollar);
@EXPORT_OK = qw(handle_clearDollar);

use lib "..","../..","../sp_publisher";
use DBI;
use CGI qw(param unescape escape);
use strict;
use Defs;
use Utils;
use AdminCommon;
use DeQuote;
use FormHelpers;
use NodeStructure;
use Products;

sub handle_clearDollar	{
  my($db, $action, $target)=@_;
  my $body='';
  my $menu='';
  if($action eq 'CLEAR_dollar') {
		$body=clearDollar($db, $target);
  }
  if($action eq 'CLEAR_dollar_submit') {
		$body=clearDollarSubmit($db, $target);
  }
  return ($body,$menu);
}

# *********************SUBROUTINES BELOW****************************

sub clearDollar	{

	my ($db, $target) = @_;

	my $entityID=param('intEntityID') || return 'ERROR';
	my $entityTypeID=param('intEntityTypeID') || return 'ERROR';

	my $st = qq[
		SELECT 
			* 
		FROM
			tblPaymentApplication
		WHERE
			intEntityID=?
			AND intEntityTypeID=?
		ORDER BY intPaymentType DESC
	];
    my $q = $db->prepare($st);
    $q->execute($entityID, $entityTypeID);
	my $dref = $q->fetchrow_hashref();
	my $form = qq[
    	<form name="clear_dollar" action="$target" method="post">
			<P>You are about to clear the Payment Email for: $dref->{strPaymentEmail}</p>
			<p>Enter Pwd: <input type="text" name="clear_pwd" value=""></p>
			<select name="clear_paymentType">
				<option value="0" SELECTED>--Select Payment Type--</option>
				<option value="$Defs::PAYMENT_ONLINEPAYPAL" >PayPal</option>
				<option value="$Defs::PAYMENT_ONLINENAB" >NAB</option>
			</select>
			<input type="hidden" name="intEntityID" value="$entityID">
			<input type="hidden" name="intEntityTypeID" value="$entityTypeID">
			<input type="hidden" name="action" value="CLEAR_dollar_submit">
			<input type="submit" name="submit" value="Clear">
		</form>
	];

	return $form;

}
sub clearDollarSubmit	{

	my ($db, $target) = @_;

	my $entityID=param('intEntityID') || return 'ERROR';
	my $entityTypeID=param('intEntityTypeID') || return 'ERROR';
	my $pwd = param('clear_pwd') || '';
	my $type = param('clear_paymentType') || '';

	if (uc($pwd) ne 'GET IT ON' or ! $type)	{
		return "NOPE,wrong and must select a Payment Type";
	}

	if ($type == $Defs::PAYMENT_ONLINEPAYPAL)	{
		my $st = qq[
			UPDATE 
				tblBankAccount 
			SET
				strMPEmail=''
			WHERE
				intEntityID=?
				AND intEntityTypeID=?
			LIMIT 1
		];
    my $q = $db->prepare($st);
    $q->execute($entityID, $entityTypeID);
	}
	if ($type == $Defs::PAYMENT_ONLINENAB)	{
		my $st = qq[
			UPDATE 
				tblBankAccount 
			SET
				strBankCode='', strAccountNo=''
			WHERE
				intEntityID=?
				AND intEntityTypeID=?
			LIMIT 1
		];
    my $q = $db->prepare($st);
    $q->execute($entityID, $entityTypeID);
	}

	my $st = qq[
		UPDATE
			tblPaymentApplication
		SET
			strPaymentEmail=''
		WHERE
			intEntityID=?
			AND intEntityTypeID=?
			AND intPaymentType = ?
		LIMIT 1
	];	
    my $q = $db->prepare($st);
    $q->execute($entityID, $entityTypeID, $type);
	return "Cleared";
}
1;
