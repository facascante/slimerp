#
# $Header: svn://svn/SWM/trunk/web/PaymentSplit.pm 8251 2013-04-08 09:00:53Z rlee $
#

package PaymentSplit;
require Exporter;
@ISA = qw(Exporter);
@EXPORT = qw(handlePaymentSplit);
@EXPORT_OK = qw(handlePaymentSplit);

use strict;
use Reg_common;
use CGI qw(unescape Vars param);
use Defs;
use PaymentSplitObj;
use PaymentSplitItemObj;
use PaymentSplitFeesObj;
use PaymentSplitList;
use PaymentSplitItemList;
use PaymentSplitValueCheck;


sub handlePaymentSplit {
    my ($action, $Data, $entityID, $typeID) = @_;
    my $resultHTML = '';
    my $title = '';
    my $client = setClient($Data->{'clientValues'});
    $typeID ||= 0;

    if ($action =~ /^A_PS_showsplits/) {
        ($resultHTML, $title) = show_splits($Data, $entityID, $typeID);
    }
    elsif ($action =~ /^A_PS_showitems/) {
        ($resultHTML, $title) = show_items($Data, $client);
    }
    elsif ($action =~ /^A_PS_newsplit/) {
        ($resultHTML, $title) = new_split($Data, $client);
    }
    elsif ($action =~ /^A_PS_editsplit/) {
        ($resultHTML, $title) = edit_split($Data, $client);
    }
    elsif ($action =~ /^A_PS_deletesplit/) {
        ($resultHTML, $title) = delete_split($Data, $client);
    }
    elsif ($action =~ /^A_PS_updnew/) {
        update_new_split($Data, $entityID, $typeID);
        ($resultHTML, $title) = show_splits($Data, $entityID, $typeID);
    }
    elsif ($action =~ /^A_PS_updedit/) {
        ($resultHTML, $title) = update_edited_split($Data, $client);
        ($resultHTML, $title) = show_items($Data, $client) if !$resultHTML;
    }
    elsif ($action =~ /^A_PS_upddelete/) {
        update_deleted_split($Data);
        ($resultHTML, $title) = show_splits($Data, $entityID, $typeID);
    }

    return ($resultHTML, $title);
}


sub show_items {
    my ($Data, $client) = @_;
    my $splitID         = param('splitID')   || '';
    my $splitName       = param('splitName') || '';
    return '' if !$splitID;

    my ($body, $header) = listPaymentSplitItems($Data, $splitID, $splitName);

    $body .= qq[
	 	<a href="$Data->{'target'}?client=$client&amp;a=A_PS_showsplits">Return to Payment Splits</a>
    ];

    return ($body, $header);
}


sub show_splits {
    my ($Data, $entityID, $typeID) = @_;
    my ($body, $header) = listPaymentSplits($Data, $entityID, $typeID);
    return ($body, $header);
}

sub build_split {
    my ($split_no, $is_remainder, $dref) = @_;

    my $method = '';
    my $split_desc = '';
    my $rbAmountChecked     = '';
    my $txtAmountValue      = '';
    my $rbPercentageChecked = '';
    my $txtPercentageValue  = '';
    my $rbEntityChecked     = '';
    my $optNationalSelected = '';
    my $optStateSelected    = '';
    my $optRegionSelected   = '';
    my $optZoneSelected     = '';
    my $optAssocSelected    = '';
    my $optClubSelected     = '';
    my $rbAccountChecked    = '';
    my $txtBranchNoValue    = '';
    my $txtAccountNoValue   = '';
    my $txtAccountNameValue = '';

    my $checked  = ' checked';
    my $selected = ' selected';

    $is_remainder ||= 0;

    if ($dref) {
        if (!$is_remainder) {
            if ($dref->{'curAmount'} != '0.00') {
                $rbAmountChecked = $checked;
                $txtAmountValue = $dref->{'curAmount'};
            }
            else {
                $rbPercentageChecked = $checked;
                $txtPercentageValue  = sprintf('%.2f', $dref->{'dblFactor'} * 100);
            }
        }
        if ($dref->{'intLevelID'}) {
            $rbEntityChecked = $checked;
            if ($dref->{'intLevelID'} == $Defs::LEVEL_NATIONAL) {
                $optNationalSelected = $selected;
            }
            elsif ($dref->{'intLevelID'} == $Defs::LEVEL_STATE) {
                $optStateSelected = $selected;
            }
            elsif ($dref->{'intLevelID'} == $Defs::LEVEL_REGION) {
                $optRegionSelected = $selected;
            }
            elsif ($dref->{'intLevelID'} == $Defs::LEVEL_ZONE) {
                $optZoneSelected = $selected;
            }
            elsif ($dref->{'intLevelID'} == $Defs::LEVEL_ASSOC) {
                $optAssocSelected = $selected;
            }
            elsif ($dref->{'intLevelID'} == $Defs::LEVEL_CLUB) {
                $optClubSelected = $selected;
            }
        }
        else {
            $rbAccountChecked      = $checked;
            $txtBranchNoValue      = $dref->{'strOtherBankCode'};
            $txtAccountNoValue     = $dref->{'strOtherAccountNo'};
            $txtAccountNameValue   = $dref->{'strOtherAccountName'};
        }

    		$txtBranchNoValue      = $dref->{'strOtherBankCode'};
    		$txtAccountNoValue     = $dref->{'strOtherAccountNo'};
    		$txtAccountNameValue   = $dref->{'strOtherAccountName'};
    }
    elsif ($is_remainder) {
        $rbEntityChecked  = $checked;
        $optAssocSelected = $selected;
    		#$txtBranchNoValue      = $dref->{'strOtherBankCode'};
    		#$txtAccountNoValue     = $dref->{'strOtherAccountNo'};
    		#$txtAccountNameValue   = $dref->{'strOtherAccountName'};
    }
    
my $otherBankAccountDetails = '';
		if ($txtAccountNoValue or $txtBranchNoValue)	{
			$otherBankAccountDetails = qq[
			 		<input type="hidden" name="txtBranchNo$split_no" value="$txtBranchNoValue">BSB Number: $txtBranchNoValue<br>
			 		<input type="hidden" name="txtAccountNo$split_no" value="$txtAccountNoValue">Account Number: $txtAccountNoValue<br>
			 		<input type="hidden" name="txtAccountName$split_no" value="$txtAccountNameValue">Account Name: $txtAccountNameValue<br>
			];
		}

    if (!$is_remainder) {
        $split_desc = "Split $split_no";
        $method = qq[
            <fieldset class="psplit-inner" id="fsMethod">
                <legend>Method</legend>
                <table class="fs-method">
                    <tr>
                        <td><input type="radio" name="rbMethod$split_no" id="rbAmount$split_no" value="amount" class="ROnb"$rbAmountChecked>Amount</td>
                        <td>
                            <label for="txtAmount" class="label">(&#36;)</label>
                            <input type="text" name="txtAmount$split_no" id="txtAmount$split_no" class="inamount" value="$txtAmountValue"/>
                        </td>
                    </tr>
                    <tr>
                        <td><input type="radio" name="rbMethod$split_no" id="rbPercentage$split_no" value="percentage" class="ROnb"$rbPercentageChecked>Percentage</td>
                        <td>
                            <input type="text" name="txtPercentage$split_no" id="txtPercentage$split_no"class="inpercent" value="$txtPercentageValue"/>
                            <label for="txtPercentage" class="label">%</label>
                        </td>
                    </tr>
                </table>
            </fieldset>
					];
    }
    else {
        $split_desc = 'Remainder (Compulsory)';
    }
    
		    my $split = qq[
        <div class="psplit-outer">
            <h3>$split_desc</h3>
            $method
            <fieldset class="psplit-inner" id="fsRecipient">
                <legend>Recipient</legend>
                <table class="fs-recipient">
                    <tr>
                        <td>
                            <select name="optEntity$split_no" id="optEntity$split_no">
                                <option value=""></option>
                                <option value="national" $optNationalSelected>National</option>  
                                <option value="state" $optStateSelected>State</option>       
                                <option value="region" $optRegionSelected>Region</option>    
                                <option value="zone" $optZoneSelected>Zone</option>       
                                <option id="optAssoc$split_no" value="association" $optAssocSelected>Association</option> 
                                <option value="club" $optClubSelected>Club</option>                        
                            </select>
                        </td>
                        <td>&nbsp</td>
                    </tr>
                </table>
            </fieldset>
				];
				if ($otherBankAccountDetails)	{
					$split .= qq[
            <fieldset class="psplit-inner" id="fsExt">
                <legend>External Bank Account</legend>
								<div class="bold">To edit please contact SportingPulse</div>
						$otherBankAccountDetails
            </fieldset>
					];
				}
				$split .= qq[
            <fieldset class="psplit-inner delete-icon" id="fsClear" onclick="clearSplit($split_no, $is_remainder)">
                <img src="images/delete.png" border="0" alt="Clear split" title="Clear split">
            </fieldset>
            
        </div>
    ];
    return $split;
}


#
# This is the original table from the code above. Left in here because at some stage it will get resurrected in some form.
# The bank details (and eventually the alternative email address) are suppressed.
# The radio button to select between an entity and bank details has been removed as the only selection that can currently occur is the entity.
#
#
#               <table>
#                   <tr>
#                       <td>
#                           <input type="radio" name="rbRecipient$split_no" id="rbEntity$split_no" value="entity" class="ROnb" $rbEntityChecked/>
#                           <select name="optEntity$split_no" id="optEntity$split_no">
#                               <option value=""></option>
#                               <option value="national" $optNationalSelected>National</option>  
#                               <option value="state" $optStateSelected>State</option>       
#                               <option value="region" $optRegionSelected>Region</option>    
#                               <option value="zone" $optZoneSelected>Zone</option>       
#                               <option id="optAssoc$split_no" value="association" $optAssocSelected>Association</option> 
#                               <option value="club" $optClubSelected>Club</option>                        
#                           </select>
#                       </td>
#                       <td>&nbsp</td>
#                   </tr>
#                   
#                   <tr>
#                       <td><input type="radio" name="rbRecipient$split_no" id="rbAccount$split_no" value="account" class="ROnb"$rbAccountChecked>Branch No.</td>
#                       <td><input type="text" class="value" name="txtBranchNo$split_no" id="txtBranchNo$split_no" value="$txtBranchNoValue"</td>
#                   </tr>
#                   <tr>
#                       <td><label id="lblAccount">Account No.</label></td>
#                       <td><input type="text" class="value" name="txtAccountNo$split_no" id="txtAccountNo$split_no" value="$txtAccountNoValue"</td>
#                   </tr>
#                   <tr>
#                       <td><label id="lblAccount">Account Name</label></td>
#                       <td><input type="text" class="value accountname" name="txtAccountName$split_no" id="txtAccountName$split_no" value="$txtAccountNameValue"</td>
#                   </tr>
#               </table>




sub build_form {
    my ($Data, $client, $aVal, $splitID, $splitName, $splits) = @_;

    my ($feesAmount, $feesFactor) = PaymentSplitFeesObj->getTotalFees($Data->{'Realm'}, $Data->{'RealmSubType'}, $Data->{'db'});
 
    my $feesPercent = sprintf("%.2f", $feesFactor * 100);
    $feesAmount     = sprintf("%.2f", $feesAmount);

        #<p class="psnote">Note: Transaction fees = &#36;$feesAmount plus $feesPercent% of transaction value.</p><br>
    my $build_form_html = qq[
        <p>Enter up to $Defs::PS_MAX_SPLITS splits plus the <span class="bold">compulsory</span> Remainder split. When finished, press the 'Update' button.</p>
        <script type="text/javascript" src="js/CheckPaymentSplit.js"></script>
        <form action="$Data->{'target'}" class="payment-split" method="post" onsubmit="return verifyForm($Defs::PS_REMAINDER_SPLIT)"/>
            <label class="label" for="txtSplitName">Split Name:</label>
            <input type="text" class="value" value="$splitName" name="splitName" id="txtSplitName"/><br>
            $splits
            <br><br>
            <input type="hidden" name="a" value="$aVal">
            <input type="hidden" name="client" value="$client">
            <input type="hidden" name="splitID" value="$splitID">
            <input type="submit" name="btnSubmit" value="Update" class = "button proceed-button">
        </form>
    ];

    return $build_form_html;
}


sub new_split {
    my ($Data, $client) = @_;

    my $header = 'Add Payment Split';
    
    my $splits = '';

    for my $splitNo (1 .. $Defs::PS_REMAINDER_SPLIT) {      
        $splits .= build_split($splitNo, ($splitNo >= $Defs::PS_REMAINDER_SPLIT), '');
    }

    my $body  = build_form($Data, $client, 'A_PS_updnew', 0, '', $splits);

    return ($body, $header);
}


sub edit_split {
    my ($Data, $client) = @_;

    my $splitID   = param('splitID')   || '';
    my $splitName = param('splitName') || '';
    return '' if !$splitID;

    my $header = "Edit Payment Split - $splitName";

    my $splitItems = PaymentSplitItemObj->getList($splitID, $Data->{'db'});

    my $splits        = '';
    my $splitNo       = 0;
    my $drefRemainder = '';

    # build from all the items on file except for the remainder item (which will be the last)
    for my $dref(@{$splitItems}) {
        if (!$dref->{'intRemainder'}) {
            $splitNo++;
            $splits .= build_split($splitNo, 0, $dref);
        }
        else {
            $drefRemainder = $dref;
            last; # stop the loop (just in case)
        }
    }

    # insert any 'empty' splits to make up the ones before the remainder item
    while ($splitNo < $Defs::PS_MAX_SPLITS) {
        $splitNo++;
        $splits .= build_split($splitNo, 0, '');
    }

    # add the remainder item
    $splits .= build_split($Defs::PS_REMAINDER_SPLIT, 1, $drefRemainder);

    my $body = build_form($Data, $client, 'A_PS_updedit', $splitID, $splitName, $splits);

    return ($body, $header);
}


sub checkSplitInUse {
    my ($Data, $splitID) = @_;
    
}

sub delete_split {
    my ($Data, $client) = @_;

    my $splitID   = param('splitID') || '';
    my $splitName = param('splitName') || '';
    return '' if !$splitID;

    my $header = 'Delete Payment Split';

    # not absolutely the optimum place to check if in use but...
    my $sql = qq[
        SELECT COUNT(intProductID) AS numSplits
        FROM tblProducts
        WHERE intPaymentSplitID=$splitID
    ];

    my $query = $Data->{'db'}->prepare($sql);
    $query->execute;

    my ($numSplits) = $query->fetchrow_array();

    $query->finish;

    my $body = '';

    if ($numSplits) {
        ($body, $header) = show_items($Data, $client);
        $body = qq[
            <div class="warningmsg">Unable to delete this Payment Split as it is in use on $numSplits product(s).</div><br>
        ] . $body;
        return ($body, $header);
    }

    $body = qq[
        <form action="$Data->{'target'}" method="post">
            <p>You have opted to delete the following Payment Split:</p>
            <p><span class="label">Split Name:</span> $splitName<br/><br/>
            <input type="hidden" name="a" value="A_PS_upddelete">
            <input type="hidden" name="client" VALUE="$client">
            <input type="hidden" name="splitID" VALUE="$splitID">
            <input type="hidden" name="splitName" value="$splitName">
            <input type="submit" name="btnsubmit" value="Delete">
        </form>
    ];
    return ($body, $header);
}


sub update_items {
    my ($splitID, $dbh)   = @_;

    my $remainder_split  = $Defs::PS_MAX_SPLITS + 1;

    my $levelID          = 0;
    my $remainder        = 0;
    my $amount           = 0.00;
    my $percentage       = 0;
    my $factor           = 0;
    my $otherBankCode    = '';
    my $otherAccountNo   = '';
    my $otherAccountName = '';
    my $rbMethod         = '';
    my $byAmount         = '';
    my $rbRecipient      = '';
    my $useEntity        = '';
    my $entity           = '';

    for my $splitNo (1 .. $remainder_split) {
        $rbMethod = param("rbMethod$splitNo") || '';
        $byAmount = ($rbMethod eq 'amount');

        $remainder = ($splitNo >= $remainder_split)
            ? 1
            : 0;

        if ($rbMethod or $remainder) {
            $useEntity = 1;                                         # temporarily inserted re suppression of bank account details
            #$rbRecipient = param("rbRecipient$splitNo" || '');     # temporarily commented out re suppression of bank account details
            #$useEntity   = ($rbRecipient eq 'entity');             # temporarily commented out re suppression of bank account details

            if ($byAmount) {
                $amount     = param("txtAmount$splitNo") || 0.00;
                $percentage = 0;
            }
            else {
                $amount     = 0.00;
                $percentage = param("txtPercentage$splitNo") || '';
            }

            $factor = ($percentage)
                ? $percentage / 100
                : 0;

            if ($useEntity) {
                $entity = param("optEntity$splitNo") || '';
                if ($entity eq 'national') {
                    $levelID = $Defs::LEVEL_NATIONAL
                }
                elsif ($entity eq 'state') {
                    $levelID = $Defs::LEVEL_STATE
                }
                elsif ($entity eq 'region') {
                    $levelID = $Defs::LEVEL_REGION
                }
                elsif ($entity eq 'zone') {
                    $levelID = $Defs::LEVEL_ZONE
                }
                elsif ($entity eq 'association') {
                    $levelID = $Defs::LEVEL_ASSOC
                }
                elsif ($entity eq 'club') {
                    $levelID = $Defs::LEVEL_CLUB
                }
                $otherBankCode    = '';
                $otherAccountNo   = '';
                $otherAccountName = '';
                $otherBankCode    = param("txtBranchNo$splitNo")    || '';
                $otherAccountNo   = param("txtAccountNo$splitNo")   || '';
                $otherAccountName = param("txtAccountName$splitNo") || '';
            }
            else {
                $levelID          = 0;
                $otherBankCode    = param("txtBranchNo$splitNo")    || '';
                $otherAccountNo   = param("txtAccountNo$splitNo")   || '';
                $otherAccountName = param("txtAccountName$splitNo") || '';
            }
             
            my $item = PaymentSplitItemObj->new(
                splitID          => $splitID,
                levelID          => $levelID,
                otherBankCode    => $otherBankCode,
                otherAccountNo   => $otherAccountNo,
                otherAccountName => $otherAccountName,
                amount           => $amount,
                factor           => $factor,
                remainder        => $remainder
            );
     
            $item->save($dbh);
        }
    }
}


sub update_new_split {
    my ($Data, $entityID, $typeID) = @_;

    my $dbh = $Data->{'db'};
    my $splitName = param('splitName') || '';
    return '' if !$splitName;

    my $split = PaymentSplitObj->new(
        ruleID    => $Data->{'SystemConfig'}{'PaymentSplitRuleID'},
        typeID    => $typeID,
        entityID  => $entityID,
        splitName => $splitName
    );

    my $splitID = $split->save($dbh);

    update_items($splitID, $dbh);

    return;
}


sub update_edited_split {
    my ($Data, $client) = @_;

    my $dbh = $Data->{'db'};

    my $splitID   = param('splitID')   || '';
    my $splitName = param('splitName') || '';
    return '' if !$splitID or !$splitName;

    my ($body, $header) = checkPaymentSplitValue($Data, $client, $splitID, $splitName);
    return ($body, $header) if $body;

    my $split = PaymentSplitObj->load($splitID, $dbh);

    $split->setSplitName($splitName);

    $split->save($dbh);

    PaymentSplitItemObj->delete($splitID, $dbh);

    update_items($splitID, $dbh);

    return;
}


sub update_deleted_split {
    my ($Data) = @_;

    my $splitID = param('splitID') || '';
    return '' if !$splitID;

    PaymentSplitObj->delete($splitID, $Data->{'db'});

    return;
}


1;
