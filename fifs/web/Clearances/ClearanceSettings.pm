#
# $Header: svn://svn/SWM/trunk/web/ClearanceSettings.pm 8530 2013-05-22 05:57:47Z cgao $
#

package ClearanceSettings;

require Exporter;
@ISA =  qw(Exporter);
@EXPORT = qw(handleClearanceSettings);
@EXPORT_OK = qw(handleClearanceSettings);

use strict;
use CGI qw(param unescape escape);

use lib '.', '..', '../..', "../comp", '../RegoForm', "../dashboard", "../RegoFormBuilder",'../PaymentSplit', "../user";
use Reg_common;
use Defs;
use Utils;
use FormHelpers;
use HTMLForm;
use AuditLog;
use ClearancesList;

sub handleClearanceSettings	{
### PURPOSE: main function to handle clearance Settings.

### NOTES: Any level can have 0 to many clearance setting records.  These record handle what to do when a clearance reaches them.  The levels can approve, deny and/or apply fees.  They can do this based on a Date of Birth range.  So for example members born between 1980-1-1 and 1990-1-1 are given one settings record and people born before another.

### This is launched from the Clearance Settings link on each level (and within red-spanner for level).

	my($action, $Data)=@_;

    my $lang = $Data->{'lang'};
	my $id=0;
        my $intID=0;
        $intID = $Data->{'clientValues'}{'clubID'} if ($Data->{'clientValues'}{'currentLevel'} == $Defs::LEVEL_CLUB);
        $intID = $Data->{'clientValues'}{'zoneID'} if ($Data->{'clientValues'}{'currentLevel'} == $Defs::LEVEL_ZONE);
        $intID = $Data->{'clientValues'}{'regionID'} if ($Data->{'clientValues'}{'currentLevel'} == $Defs::LEVEL_REGION);
        $intID = $Data->{'clientValues'}{'stateID'} if ($Data->{'clientValues'}{'currentLevel'} == $Defs::LEVEL_STATE);
        $intID = $Data->{'clientValues'}{'natID'} if ($Data->{'clientValues'}{'currentLevel'} == $Defs::LEVEL_NATIONAL);

        my $intTypeID = $Data->{'clientValues'}{'currentLevel'};

	my $edit=param("e") || 0;
	my $csID=param("csID") || 0;

 	my $resultHTML='';
	my $heading='';

  	if ($action eq 'CLRSET_LIST' or $action eq 'CLRSET_') {
		($resultHTML,$heading) = listClearanceSettings($Data, $intID, $intTypeID);
  	}
  	elsif ($action eq 'CLRSET_EDIT') {
		($resultHTML,$heading) = displayClearanceSetting($Data, $intID, $intTypeID, $csID, 1);
  	}
  	elsif ($action eq 'CLRSET_ADD') {
		($resultHTML,$heading) = displayClearanceSetting($Data, $intID, $intTypeID, 0, 1);
  	}
  	elsif ($action eq 'CLRSET_DEL') {
		($resultHTML,$heading) = deleteClearanceSetting($Data, $intID, $csID);
  	}
	$heading||=$lang->txt('Transfer Settings');
 	return ($resultHTML,$heading);
}


sub deleteClearanceSetting	{

## function to delete a settings record for a level.
	my ($Data, $ID, $csID) = @_;
	my $db=$Data->{'db'} || undef;
    my $lang = $Data->{'lang'};

  	my $client=setClient($Data->{'clientValues'}) || '';
	my $st = qq[
		DELETE FROM tblClearanceSettings
		WHERE intClearanceSettingID = $csID
			AND intID = $ID
	];
	my $query = $db->prepare($st);
	$query->execute;

	my $resultHTML = qq[<div class="OKmsg">] . $lang->txt('Record deleted successfully') . qq[</div> <br> <a href="$Data->{'target'}?client=$client&amp;a=CLRSET_LIST">] . $lang->txt('Return to Transfer Settings') . qq[</a>];
  auditLog($csID, $Data, 'Delete', $lang->txt('Transfer Settings'));

	return ($resultHTML, $lang->txt("Transfer Settings"));	
}

sub displayClearanceSetting	{

## function that uses HTMLForm to allow insert of clearance settings.  

  my($Data, $ID, $intTypeID, $csID, $edit) = @_;
    my $lang = $Data->{'lang'};

	my $db=$Data->{'db'} || undef;
  	my $client=setClient($Data->{'clientValues'}) || '';
	my $target=$Data->{'target'} || '';
	my $option=$edit ? ($csID ? 'edit' : 'add')  :'display' ;

  	my $resultHTML = '';
	my $toplist='';

	my %DataVals=();
	my $statement=qq[
		SELECT CS.*, DATE_FORMAT(dtDOBStart,'%d/%m/%Y') AS dtDOBStart, DATE_FORMAT(dtDOBEnd,'%d/%m/%Y') AS dtDOBEnd
		FROM tblClearanceSettings as CS
		WHERE intClearanceSettingID = $csID
			AND intID = $ID
	];

	my $query = $db->prepare($statement);
	my $RecordData={};
	$query->execute;
	my $dref=$query->fetchrow_hashref();
	my $clrupdate=qq[
		UPDATE tblClearanceSettings
			SET --VAL--
		WHERE intClearanceSettingID = $csID
	];
	my $clradd=qq[
		INSERT INTO tblClearanceSettings (intID, intTypeID, --FIELDS--)
			VALUES ($ID, $intTypeID, --VAL--)
	];
    
	my %FieldDefs = (
		CLR => {
			fields => {
				                intAutoApproval=> {
                                        label => $lang->txt('Auto Approval'),
                                        value => $dref->{'intAutoApproval'},
                                        type  => 'lookup',
                                        options => \%Defs::ClearanceApprovals,
                                        ffirstoption => [$Defs::CLR_MANUAL,$Defs::ClearanceApprovals{$Defs::CLR_MANUAL}],
                                        compulsory => 1,
                                },
				                intRuleDirection=> {
                                        label => $lang->txt('Rule applies to'),
                                        value => $dref->{'intRuleDirection'},
                                        type  => 'lookup',
                                        options => \%Defs::ClearanceDirections,
                                        compulsory => 1,
                                        ffirstoption => [$Defs::CLR_BOTH,$Defs::ClearanceDirections{$Defs::CLR_BOTH}],
                                },
                                dtDOBStart => {
                                        label => $lang->txt('DOB Start Range (earliest date)'),
                                        value=> $dref->{'dtDOBStart'},
					                    format => 'dd/mm/yyyy',
                                        type => 'date',
                                        datetype => 'dropdown',
					                    validate => 'DATE',
                                },
                                dtDOBEnd => {
                                        label => $lang->txt('DOB End Range (latest date)'),
                                        value=> $dref->{'dtDOBEnd'},
					                    format => 'dd/mm/yyyy',
                                        type => 'date',
                                        datetype => 'dropdown',
					                    validate => 'DATE',
                                },
		},
		order => [qw(intAutoApproval intRuleDirection dtDOBStart dtDOBEnd)],
			options => {
				labelsuffix => ':',
				hideblank => 1,
				target => $Data->{'target'},
				formname => 'clr_form',
				submitlabel => $lang->txt('Update Settings'),
				introtext => 'auto',
				buttonloc => 'bottom',
				updateSQL => $clrupdate,
				addSQL => $clradd,
				stopAfterAction => 1,
        auditFunction=> \&auditLog,
        auditAddParams => [
          $Data,
          'Add',
          $lang->txt('Transfer Settings')
        ],
        auditEditParams => [
          $csID,
          $Data,
          'Update',
          $lang->txt('Transfer Settings')
        ],
				updateOKtext => qq[<div class="OKmsg">] . $lang->txt('Record updated successfully') . qq[</div> <br>
					<a href="$Data->{'target'}?client=$client&amp;a=CLRSET_LIST">] . $lang->txt('Return to Transfer Settings') . qq[</a>],
				addOKtext=> qq[<div class="OKmsg">] . $lang->txt('Record updated successfully') . qq[</div> <br>
					<a href="$Data->{'target'}?client=$client&amp;a=CLRSET_LIST">] . $lang->txt('Return to Transfer Settings') . qq[</a>],
			},
			sections => [ ['main',$lang->txt('Details')], ],
			carryfields =>  {
				client => $client,
				a=> 'CLRSET_EDIT',
				csID => $csID,
			},
		},
	);
	($resultHTML, undef )=handleHTMLForm($FieldDefs{'CLR'}, undef, $option, '',$db);

	if($option eq 'display')	{
#		$resultHTML .=allowedAction($Data, 'txn_e') ?qq[ <a href="$target?a=M_TXN_EDIT&amp;tID=$dref->{'intTransactionID'}&amp;client=$client">Edit Details</a> ] : '';
	}



		$resultHTML=qq[<div>] . $lang->txt('This member does not have any Transaction information to display') . qq[.</div>] if !ref $dref;

		$resultHTML=qq[
				<div class="alphaNav">$toplist</div>
				<div>
					$resultHTML
				</div>
		];
		my $heading=$lang->txt('Transfer Settings');
		return ($resultHTML,$heading);
}
1;
