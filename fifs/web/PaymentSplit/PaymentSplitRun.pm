#
# $Header: svn://svn/SWM/trunk/web/PaymentSplitRun.pm 8251 2013-04-08 09:00:53Z rlee $
#

package PaymentSplitRun;

require Exporter;
@ISA       = qw(Exporter);
@EXPORT    = qw(handlePaymentSplitRun);
@EXPORT_OK = qw(handlePaymentSplitRun);

use strict;
use CGI qw(param unescape escape);

use lib '.';
use Reg_common;
use Defs;
use Utils;       # is this needed?

use PaymentSplitRuleObj;
use BankAccountObj;
use PaymentSplitExport;


sub handlePaymentSplitRun {
    my ($action, $Data) = @_;

    my $client = setClient($Data->{'clientValues'}) || '';

    my $resultHTML = '';
    my $title      = '';

    if ($action =~ /^PSR_opt/) {
        ($resultHTML, $title) = get_options($Data, $client);
    }
    elsif ($action =~ /^PSR_run/) {
        ($resultHTML, $title) = do_export($Data, $client);
    }
    elsif ($action =~ /^PSR_prev/) {
        ($resultHTML, $title) = view_previous($Data);
    }

    return ($resultHTML, $title);
}


sub view_previous {
    my ($Data) = @_;

    my $sql = qq[
        SELECT 
            e.intExportBSID, 
            bs.strSplitName, 
            e.strFilename, 
            DATE_FORMAT(dtRun, "%d/%m/%Y") as dtRun_FORMATTED
        FROM 
            tblExportBankFile as e 
            INNER JOIN tblBankSplit as bs ON (e.intBankSplitID = bs.intSplitID)
        WHERE 
            bs.intRealmID = $Data->{'Realm'}
        ORDER BY 
            dtRun DESC;
    ];

    my $query = $Data->{'db'}->prepare($sql);
    $query->execute or query_error($sql);

    my $body = qq[
        <table class="listTable"><tr>
            <th>Name</th>
            <th>Date Run</th>
            <th>File</th>
        </tr>
    ];

    my $count = 0;
    while (my $dref = $query->fetchrow_hashref()) {
        $count++;
        $body .= qq[
            <tr>
                <td>$dref->{strSplitName}</td>
                <td>$dref->{dtRun_FORMATTED}</td>
        ];
        my $client = setClient($Data->{'clientValues'}) || '';
        if ($dref->{strFilename}) {
            $body .= qq[
                <td><a target="_blank" href="bank_file.cgi?client=$client&amp;exportbsid=$dref->{intExportBSID}">download file</a></td>];
        }
        else {
            $body .= qq[<td>--no data--</td>];
        }
    }
    
    $body .= qq[</table>];
    $body = qq[<p>No exports found</p>] if !$count;

    return ($body, "Previous Splits");
}


sub get_options {
    my ($Data, $client) = @_;

    my $header = 'Payment Split Run';

    my %tempClientValues = getClient($client);
    my $viewText = 'View previous files';

    my $viewFiles = qq[
        <div class="changeoptions">
            <a href="$Data->{'target'}?client=$client&amp;a=PSR_prev&amp;l=$tempClientValues{currentLevel}">
                <img src="images/sml_view_icon.gif" border="0" alt="$viewText" title="$viewText">
            </a>
        </div>
    ];

    $header = $viewFiles.$header;

    my $rules = PaymentSplitRuleObj->getList($Data->{'Realm'}, $Data->{'db'});

    my $selections = '';
   
    for my $dref(@{$rules}) {
        $selections .= qq[
            <option value="$dref->{'intRuleID'}">$dref->{'strRuleName'}</option>
        ] if $dref->{'strFinInst'} ne 'PAYPAL_NAB';
    }

    my $body = qq[
        <script type="text/javascript">
            function isBlank(s) {
                var c, i;
                if (s == null) return true;
                if (s == '')   return true;
                for (i = 0; i < s.length; i++) {
                    c = s.charAt(i);
                    if ((c != ' ') && (c != '\\n') && (c != '')) return false;
                }
                return true;
            }
            function checkFields() {
                var errMsg = '';
                if (document.getElementById('optRuleID').selectedIndex < 1)
                    errMsg += 'Payment Split Rule must be selected.\\n';
                if (isBlank(document.getElementById('txtEmail').value))
                    errMsg += 'Email address must be specified.\\n';
                if (errMsg) {
                    alert(errMsg);
                    return false;
                }
                return true;
            }
            function formSubmit() {
                if (checkFields()) {
                    if (confirm('Are you sure you want to continue?')) {
                        document.getElementById('btnContinue').disabled = true;
                        return true;
                    }
                }
                return false;
            }
        </script>

        <form action="$Data->{'target'}" method="POST" name="frmOptions" onsubmit="return formSubmit()">
            <p>Select the appropriate <b>rule</b> and adjust the recipient <b>email address</b> (if need be).</b></p><br>
            <p>Press the <b>Continue</b> button when ready to create the export file...</p><br>
            <label class="label": for "optRuleID">Payment Split Rule:</label>
            <select name="ruleID" id="optRuleID">
                <option value=""></option>
                $selections
            </select>
            <br><br>
            <label class="label": for "txtEmail">Email address:</label>
            <input type="text" name="email" id="txtEmail" value="$Data->{'SystemConfig'}{'BankSplit_email'}">
            <input type="hidden" name="a" value="PSR_run">
            <input type="hidden" name="client" value="$client">
            <br><br>
            <input type="submit" name="btnContinue" id="btnContinue" value="Continue">
        </form>
    ];

    return ($body, $header);
}


sub buildErrMsg {
    my $errMsg = @_;    

    my $result = qq[
        <div class="warningmsg">
            <p>$errMsg</p><br>
            <p>Unable to run export.</p>
        </div>
    ];
    return $result;
}


sub do_export {
    my ($Data, $client) = @_;

    my $ruleID = param("ruleID") || 0;
    my $email  = param("email")  || $Defs::admin_email;

    my $header = 'Bank File Export';
    my $errMsg = '';

    # untaint the ruleID
    $ruleID =~/(^\d+$)/; 
    $ruleID =$1;

    if (!$ruleID) {
        $errMsg = buildErrMsg('A Payment Split Rule has not been selected.');
        return ($errMsg, $header);
    }

    my $dbh = $Data->{'db'};

    # ensure default account has been set up
    my $defaultAccount = BankAccountObj->load($Defs::LEVEL_NATIONAL, $Data->{'clientValues'}{'natID'}, $dbh);
    
    if (!$defaultAccount) {
        $errMsg = buildErrMsg('A default account has not been set up at the National level.');
        return ($errMsg, $header);
    }

    my $rule = PaymentSplitRuleObj->load($ruleID, $dbh);
    my $paymentType = $Defs::PAYMENT_ONLINECREDITCARD;

    my $splitCount = doPaymentSplitExport($Data, $ruleID, $defaultAccount, $paymentType, $email);

    my $body = '';

    $body = ($splitCount)
        ? qq[<p class="OKmsg">The Payment Split Export has been run and emailed to $email</p><br>]
        : qq[<p class="warningmsg">There are no records to be exported.</p><br>];

    return ($body, $header);
}

1;
