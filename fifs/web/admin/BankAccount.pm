#
# $Header: svn://svn/SWM/trunk/web/admin/BankAccount.pm 11016 2014-03-19 00:22:06Z ppascoe $
#

package BankAccount;

use lib "..","../..";
use CGI qw(param);
use DBI;

require Exporter;
@ISA =  qw(Exporter);
@EXPORT = qw(BankAccount);
@EXPORT_OK = qw(BankAccount);



use strict;

use Utils;
use Defs;
use ConfigOptions;
use DeQuote;
use AdminPageGen;
use Data::Dumper;
use Switch;
#use ConfigOptions;
use Data::Dumper;

sub BankAccount	{
my($db,$target)=@_;


	my $body  = '';
	my $ID = param("teamID") || param('aID') ||param("clubID") || param("intAssocID") || param("nodeID") || 0;
	my $type = param('type')||0;
	my $sectionID = param('sID') || 0;
	my $action = param('action') || '';
	my $updateAction = param('updateAction') ||'';
	my $new_strKey= param('new_strKey') || '';
	my $new_strValue= param('new_strValue') || '';
	my $strDB_Name= param('db_name') || '';
    	my %assocConfig;
	my $returnPAGE = '';
	my $strIDName = '';
    #while(my $dref= $query->fetchrow_hashref())  {
       # $assocConfig{$dref->{strOption}}{$dref->{strKey}} = $dref->{strValue} || $dref->{strValue_Long};
    #}
	switch ($action){
		case /ASSOC_BankAccount/{
						$type=5;	
						$strIDName = 'aID';
						$returnPAGE ='ASSOC_BankAccount_UPDATE';
					}
		case /CLUB_BankAccount/	{
						$type = 3;
						$strIDName = 'clubID';
                                                $returnPAGE ='CLUB_BankAccount_UPDATE';
					}
		case /TEAM_BankAccount/ {
						# No Bank Accountintis set for Teams in Current System.
						$type = 2;
						$strIDName = 'teamID';
                                                $returnPAGE ='TEAM_BankAccount_UPDATE';
					}
		case /LOGIN_NODE/         {	$type = param('level');
						warn("SWITCH CASE");	
						$strIDName = 'nodeID';
                                                $returnPAGE ='LOGIN_NODE_BankAccount_UPDATE';
						}
		else		{$type = 0}
	}

	warn("ActionToCheck:: $action  strIDName:: $strIDName");
	if ($action =~ /_BankAccount_UPDATE/)      {
                #update bank account
                $body.=updateBankAccount($db, $ID ,$type);
                $action = 'BankAccount_ok';
        }
	if ($action =~ /_BankAccount/ or $action eq 'BankAccount_ok')	{
		#Show the back account detail
		warn("Action:: $action");
	#$body .= getHeader();
		$body.=viewBankAccount($db, $ID,$type,$target,$strIDName,$returnPAGE);
	
	}
	#if ($action eq 'ASSOC_BankAccount_update')	{
		#update bank account
	#	$body.=updateBankAccount($db, $ID ,5);
	#	$action = 'ASSOC_BankAccount_ok';
	#}
#return $body;
}

sub viewBankAccount	{

	my ($db, $intEntityID, $type,$target,$stIDName,$returnPage) = @_;
	
	 if (!AdminCommon::verify_hash()) {
		return("Error in Querystring hash");
	} 
		
	$intEntityID ||= 0;
	print STDERR Dumper(@_);
	my $body = '<table style="margin-left:auto;margin-right:auto;"><tr><td class="formbg">';

	my $statement = qq[
		SELECT strBankCode  ,  strAccountNo , strAccountName
		FROM tblBankAccount
		WHERE intEntityID = $intEntityID AND intEntityTypeID = $type
	];
	my $query = $db->prepare($statement) or query_error($statement);
    	$query->execute or query_error($statement);
	warn($statement);
	my @keys = ();
	$body .= qq[
                <div class="displaybox" style="clear:both;margin-top:20px;">
                <form method="post" action="">
                <input type="hidden" name="$stIDName" value="$intEntityID">
                <input type="hidden" name="action" value="$returnPage">
		<input type="hidden" name="level" value="$type">
                <table border="1" cellpadding="3" cellspacing="3" bordercolor="black" style="margin-left:auto;margin-right:auto;" align="center">

        ];	
	my $priorConfigArea = '';
	my $counter=0;
	my $bgcolor='';
	while (my $dref = $query->fetchrow_hashref())	{
		if($priorConfigArea ne 1) {
		$body .= qq[
			 <tr>
					 <td colspan="4" style='color:white;background-color:#1376B0;padding:0px;'><h1 style='padding-left:15px;margin-bottom:0px;padding-5px;';>Bank Account</h1></td>
			 </tr>
			<tr>
                        <th>Bank Code</th>
                        <th>Account name</th>
                        <th>Account Number</th>
			</tr>

			];

			$priorConfigArea = 1;
		}
		
		if($counter%2==0){
		$bgcolor='#ffffff';
		}
		else{
		$bgcolor='#90D3F9';
		}
		my $style = qq[style="background-color:$bgcolor"];
		$body .= qq[
			<tr>
				<td $style><input tpe="text" size ="30" name = "DB_strBankCode" value ="$dref->{strBankCode}"></td>
				<td $style><input type="text" size="30" name="DB_strAccountName" value="$dref->{strAccountName}"></td>
				<td $style><input type="text" size="30" name="DB_strAccountNo" value="$dref->{strAccountNo}"></td>
			</tr>
		];
		$counter++;	
		}
	 my $userAction = '';
	if($counter>0){
		$userAction = '<input type="submit" name="save" style="align:center;" value="U P D A T E">';
	}
	else{
		$userAction = ' No Account Detail was found!';
	}
	$body .= qq[
		</table>
		$userAction
		</form>
	];
	
	$body .= qq[
		<br><br>
				<br>
		</div></td></tr></table>	];
	return $body;
}

sub updateBankAccount	{
	
	my ($db, $intID,$type) = @_;
	$intID ||= 0;

	my $output=new CGI;
    	my %fields = $output->Vars;
print STDERR Dumper( %fields);
    #Get rid of non stat fields
	my $strError = '';
	my @statements = ();
	
	for my $key (keys %fields)	{
        if($key=~/^DB_/)	{
			my $newkey=$key;
        		$newkey=~s/^DB_//g;
			my $statement = qq[
				UPDATE tblBankAccount
				SET  $newkey = "$fields{$key}"
				WHERE intEntityID = $intID
					AND intEntityTypeID = $type
			];
			push @statements, $statement;
		print STDERR "\n\n".$statement."\n\n";
		}
	}

	if ($strError)	{
		return $strError;
	}
	else	{
		for my $statement (@statements)	{
			my $query = $db->prepare($statement) or query_error($statement);
    		$query->execute or query_error($statement);
		}
		return "OK";
	}
	
}


