// The lines commented out throughout are only done so temporarily, re
// the temporary suppression of bank account details in PaymentSplits

function clearSplit(aiItemNo, aiRemainder) {
    var rbEntityId  = 'rbEntity'  + aiItemNo;
    var s;

    if (aiRemainder == 0) {
        s = 'rbAmount' + aiItemNo;
        document.getElementById(s).checked = false;
        s = 'txtAmount' + aiItemNo;
        document.getElementById(s).value = '';
        s = 'rbPercentage' + aiItemNo;
        document.getElementById(s).checked = false;
        s = 'txtPercentage' + aiItemNo;
        document.getElementById(s).value = '';
        document.getElementById(rbEntityId).checked = false;
        s = 'optEntity' + aiItemNo;
        document.getElementById(s).selectedIndex = -1;
    }
    else { 
        document.getElementById(rbEntityId).checked = true;
        s = 'optAssoc' + aiItemNo;
        document.getElementById(s).selected = 'selected';
    }

    //s = 'rbAccount' + aiItemNo;
    //document.getElementById(s).checked = false;
    //s = 'txtBranchNo' + aiItemNo;
    //document.getElementById(s).value = '';
    //s = 'txtAccountNo' + aiItemNo;
    //document.getElementById(s).value = '';
    //s = 'txtAccountName' + aiItemNo;
    //document.getElementById(s).value = '';
    
    return
}

function isBlank(s) {
    var c, i;
            
    if (s == null) { return true }
    if (s == '')   { return true }

    for (i = 0; i < s.length; i++) {
        c = s.charAt(i);
        if ((c != ' ') && (c != '\n') && (c != '')) { return false }
    }

    return true;
}

function checkNumber(s, aiMin, aiMax, asName, aiItemNo) {
    var errMsg = '';
    var v = parseFloat(s);

    if (isNaN(v) || ((aiMin != null) && (v < aiMin)) || ((aiMax != null) && (v > aiMax))) {
        errMsg += asName + ' must be a number';
        if (aiMin != null) 
        errMsg += ' >= ' + aiMin;
        if ((aiMax != null) && (aiMin != null)) 
            errMsg += ' and <= ' + aiMax
        else if (aiMax != null)
            errMsg += ' < ' + aiMax;
    }
    else if (s.indexOf(".") < s.length - 3 && s.indexOf(".")!=-1) {
        errMsg += asName + " can only be 2 decimal places at most" ;
    }

    if (errMsg) { errMsg += ' in Split ' + aiItemNo + '.\n'; }

    return errMsg;
}

function checkSplitName() {
    var txtSplitNameId = 'txtSplitName';

    var errMsg = '';
    var e;

    e = document.getElementById(txtSplitNameId);
    if (isBlank(e.value))
        errMsg += 'Split Name must be entered.\n\n';

    return errMsg;
}

function checkItem(aiItemNo, aiRemainderItem) {
    var optEntityId      = 'optEntity'      + aiItemNo;
    //var rbEntityId       = 'rbEntity'       + aiItemNo;
    //var rbAccountId      = 'rbAccount'      + aiItemNo;
    var txtAmountId      = 'txtAmount'      + aiItemNo;
    var txtPercentId     = 'txtPercentage'  + aiItemNo;
    //var txtBranchNoId    = 'txtBranchNo'    + aiItemNo;
    //var txtAccountNoId   = 'txtAccountNo'   + aiItemNo;
    //var txtAccountNameId = 'txtAccountName' + aiItemNo;

    //var isEntityChecked    = document.getElementById(rbEntityId).checked;
    //var isAccountChecked   = document.getElementById(rbAccountId).checked;

    var errMsg = '';
    var e, itemDesc;

    if (aiItemNo != aiRemainderItem) {
        var rbAmountId       = 'rbAmount'       + aiItemNo;
        var rbPercentId      = 'rbPercentage'   + aiItemNo;

        var isAmountChecked    = document.getElementById(rbAmountId).checked;
        var isPercentChecked   = document.getElementById(rbPercentId).checked;

        //var x, y;

        //x = (isAmountChecked || isPercentChecked);
        //y = (isEntityChecked || isAccountChecked);

        //if (x != y)
            //errMsg = 'Method and Recipient must both be selected/unselected in Split ' + aiItemNo + '.\n';

        if (isAmountChecked) {
            e = document.getElementById(txtAmountId);
            if (isBlank(e.value))
                errMsg += 'Amount must be entered in Split ' + aiItemNo + '.\n'
            else
                errMsg += checkNumber(e.value, 0.01, null, 'Amount', aiItemNo);
        }

        if (isPercentChecked) {
            e = document.getElementById(txtPercentId);
            if (isBlank(e.value))
                errMsg += 'Percentage must be entered in Split ' + aiItemNo + '.\n'
            else
                errMsg += checkNumber(e.value, 0.01, 100, 'Percentage', aiItemNo);
        }
    }

/* --------------------------------------------------------------------------------
   The following code replaces the code commented out below temporarily. Re the
   suppression of the bank account details. */
// --------------------------------------------------------------------------------


    if ((isAmountChecked) || (isPercentChecked)) {
        e = document.getElementById(optEntityId);
        if (e.selectedIndex < 1)
            errMsg += 'Entity value must be selected in Split ' + aiItemNo + '.\n';
    }

// --------------------------------------------------------------------------------

/*
    if (isEntityChecked) {
        e = document.getElementById(optEntityId);
        if (e.selectedIndex < 1)
            errMsg += 'Entity value must be selected in Split ' + aiItemNo + '.\n';
    }

    if (isAccountChecked) {
        e = document.getElementById(txtBranchNoId);
        if (aiItemNo != aiRemainderItem)
            itemDesc = 'Split ' + aiItemNo
        else
            itemDesc = 'Remainder Split'; 
        if (isBlank(e.value))
            errMsg += 'Branch No. must be entered in ' + itemDesc + '.\n';
        e = document.getElementById(txtAccountNoId); 
        if (isBlank(e.value))
            errMsg += 'Account No. must be entered in ' + itemDesc + '.\n'
        e = document.getElementById(txtAccountNameId); 
        if (isBlank(e.value))
            errMsg += 'Account Name must be entered in ' + itemDesc + '.\n'
    }
*/
    if (errMsg) 
        errMsg += '\n' 
    else if (aiItemNo != aiRemainderItem) {
        if (isPercentChecked) {
            TotPercent += document.getElementById(txtPercentId).value * 1;
        }
    }

    return errMsg;
}

function verifyForm(aiRemainderItem) {
    var msg = '';
    var i;

    TotPercent = 0;

    msg += checkSplitName();

    for (i = 1; i <= aiRemainderItem; i++)
        msg += checkItem(i, aiRemainderItem);

    if (TotPercent > 100)
        msg += 'Total percentage entered cannot exceed 100.\n\n';

    if (msg) {
        alert(msg);
        return false;
    }
    return true;
}
