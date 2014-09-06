// regoformfieldorder.js
    
// Could possibly have a function to return 'hdr' or 'txt' according to the thtyp rather than having 
// the same if statements everywhere...

jQuery().ready(function(){

    // event handlers

    jQuery("#sortable").sortable({
        update: function(event, ui){                                              
            var newOrder = jQuery('#sortable').sortable('serialize', {key:'foo'});
            newOrder = newOrder.replace(/&foo=/g, '|');
            newOrder = newOrder.replace('foo=', '');
            updateOrder(newOrder);
        } 
    });
    jQuery("#sortable").disableSelection();

    jQuery('#avfields').on('click', 'a.edthdr', (function(e){
        e.preventDefault();
        showTxtHdrBlock(1, jQuery(this).attr("id").replace('edt_', ''));
    }));

    jQuery('#avfields').on('click', 'a.edttxt', (function(e){
        e.preventDefault();
        showTxtHdrBlock(2, jQuery(this).attr("id").replace('edt_', ''));
    }));

    jQuery('#avfields').on('click', 'a.config', (function(e){
        e.preventDefault();
        var fieldID = jQuery(this).attr("id");
        fieldID = fieldID.replace('cfg_', '');
        jQuery("#sID").val(fieldID);
        jQuery("#configForm").submit();
    }));

    jQuery('#avfields').on('click', 'a.remhdr', (function(e){ 
        e.preventDefault();
        if (confirm('Remove selected block?')){
            var fieldID = jQuery(this).attr("id");
            fieldID = fieldID.replace('rem_', '');
            removeTxtHdr(fieldID);
        }
    }));

    jQuery(".addhdrblkjs").click(function(e){
        e.preventDefault();
        showTxtHdrBlock(1, 0);
    });

    jQuery(".addtxtblkjs").click(function(e){
        e.preventDefault();
        showTxtHdrBlock(2, 0);
    });

    jQuery(".savhdrblkjs").click(function(e){
        e.preventDefault();
        var fieldTyp = 1;
        var fieldID = jQuery("#hdrbl").attr('name');
        fieldID = fieldID.replace('hdrbl_', '');
        if (fieldID == 0)
            addTxtHdrBlock(fieldTyp, jQuery("#hdrbl").val(), jQuery("#hdrbc").val());
        else
            updTxtHdrBlock(fieldID, fieldTyp, jQuery("#hdrbl").val(), jQuery("#hdrbc").val());
    });

    jQuery(".savtxtblkjs").click(function(e){
        e.preventDefault();
        var fieldTyp = 2;
        var fieldID = jQuery("#txtbl").attr('name');
        fieldID = fieldID.replace('txtbl_', '');
	 if (fieldID == 0)
            addTxtHdrBlock(fieldTyp, jQuery("#txtbl").val(), jQuery("#txtbc").val());
        else
            updTxtHdrBlock(fieldID, fieldTyp, jQuery("#txtbl").val(), jQuery("#txtbc").val());
    });

    // functions

    function getClient(){
        return jQuery("#cff_client").val();
    }

    function getFormID(){
        return jQuery("#cff_formID").val();
    }

    function getFormKey(){
        return jQuery("#cff_formKey").val();
    }

    function updateOrder(newOrder){
        var request = jQuery.ajax({
            url: "ajax/aj_regoform_fields_order_update.cgi", 
            type: "POST",
            data: "client=" + getClient() + "&amp;fid=" + getFormID() + "&amp;fky=" + getFormKey() + "&amp;order=" + newOrder,
            dataType: 'json'
        });
        checkRequest(request);
    }

    function showTxtHdrBlock(thtyp, fieldID){
        var thstr;

        if (thtyp == 1) thstr = 'hdr'; else thstr = 'txt';

        jQuery('#' + thstr + 'bl').attr('name', thstr + 'bl_' + fieldID);
        jQuery('#' + thstr + 'bc').attr('name', thstr + 'bc_' + fieldID);

        if (fieldID != 0) {
            getTxtHdr(thtyp, fieldID);
        }
        else {
            jQuery('#' + thstr + 'bl').val('');
            jQuery('#' + thstr + 'bc').val('');
            jQuery('#reorder').hide();
            jQuery('#' + thstr + 'blk').show();
        }
    }

    function removeTxtHdr(fieldID){
        var request = jQuery.ajax({
            url: "ajax/aj_regoform_txthdr_remove.cgi", 
            type: "POST",
            data: "client=" + getClient() + "&amp;fid=" + getFormID() + "&amp;fky=" + getFormKey() + "&amp;fldid=" + fieldID,
            dataType: 'json'
        });
        checkRequest(request);
        if (request.done)
            jQuery('li').remove('#foo_'+fieldID);
    }

    function addTxtHdrBlock(thtyp, thbl, thbc){
        var request = jQuery.ajax({
            url: "ajax/aj_regoform_txthdr_add.cgi", 
            type: "POST",
            data: "client=" + getClient() + "&amp;fid=" + getFormID() + "&amp;fky=" + getFormKey() + "&amp;typ=" + thtyp + "&amp;bl=" +encodeURIComponent( thbl) + "&amp;bc=" +encodeURIComponent( thbc),
        });
        checkRequest(request);
        updateDOM(request);

        var thstr;

        if (thtyp == 1) thstr = 'hdr'; else thstr = 'txt';

        jQuery("#" + thstr + "blk").hide();
        jQuery("#reorder").show();
    }

    function getTxtHdr(thtyp, fieldID){
        var thstr;

        if (thtyp == 1) thstr = 'hdr'; else thstr = 'txt';

        jQuery.getJSON(
            'ajax/aj_regoform_txthdr_get.cgi', 
            'client=' + getClient() + '&amp;fid=' + getFormID() + '&amp;fky=' + getFormKey() + '&amp;fldid=' + fieldID,
            function(jsondata){
                if (jsondata.result == 'Success'){
                    $("#" + thstr + "bl").attr("name", thstr + "bl_" + fieldID);
                    $("#" + thstr + "bl").val(jsondata.blabel);
                    $("#" + thstr + "bc").attr("name", thstr + "bc_" + fieldID);
                    $("#" + thstr + "bc").val(jsondata.bcontent);
                    jQuery("#reorder").hide();
                    jQuery("#" + thstr + "blk").show();
                }
            }
        );
    }

    function updTxtHdrBlock(fieldID, thtyp, thbl, thbc){
    var request = jQuery.ajax({
            url: 'ajax/aj_regoform_txthdr_update.cgi', 
            type: 'POST',
            data: 'client=' + getClient() + '&amp;fid=' + getFormID() + '&amp;fky=' + getFormKey() + '&amp;fldid=' + fieldID + '&amp;typ=' + thtyp + '&amp;bl=' +encodeURIComponent(thbl) + '&amp;bc=' +encodeURIComponent(thbc),
        });
        checkRequest(request);
        request.done(function(jsondata){
            var rsltObj = jQuery.parseJSON(jsondata);
            if (rsltObj.result == 'Success'){
                jQuery('#joo_' + fieldID).html(rsltObj.flabel);
                var thstr;
                if (thtyp == 1) thstr = 'hdr'; else thstr = 'txt';
                jQuery("#" + thstr + "blk").hide();
                jQuery("#reorder").show();
            }
        });
    }

    function checkRequest(request){
        request.fail(function(jqXHR, textStatus){
            jQuery("#msgarea").html("Request failed: " + textStatus);
            jQuery("#msgarea").show();
        });
    }

    function updateDOM(request){
        request.done(function(jsondata){
            var rsltObj = jQuery.parseJSON(jsondata);
            if (rsltObj.result == 'Success'){
                var htmlBlock = '';

                var thstr;
                var extraClass;
                if (rsltObj.typ == 1){
                    thstr = 'hdr';
                    extraClass = ' RO_headerblock';
                } else {
                    thstr = 'txt';
                    extraClass = ' RO_textblock';
                }

                var useFid = rsltObj.source + 's' + rsltObj.fid;

                htmlBlock  = '<li class="fieldblock-li" id="foo_' + useFid + '">';
                htmlBlock += '    <div class="RO_fieldblock' + extraClass + '"><div class="move-icon"></div>';
                htmlBlock += '        <div class="fieldlinks">';
                htmlBlock += '            <span class="button-small generic-button"><a class="remhdr thspecial" id="rem_' + useFid + '" href="">Remove</a></span>';
                htmlBlock += '            <span class="button-small generic-button"><a class="config thspecial" id="cfg_' + useFid + '" href="">Rules</a></span>';
                htmlBlock += '            <span class="button-small generic-button"><a class="edt' + thstr + ' thspecial" id="edt_' + useFid + '" href="">Edit</a></span>';
                htmlBlock += '        </div>';
                htmlBlock += '        <div class="RO_fieldname" id="joo_' + useFid + '">' + rsltObj.flabel + '</div>';
                htmlBlock += '    </div>';
                htmlBlock += '</li>';
                jQuery("#sortable").append(htmlBlock);
                jQuery("#avfields").scrollTop(jQuery("#avfields")[0].scrollHeight);
            }
        });
    }

    function mouseHandler(e){
        if (jQuery(this).hasClass('picked')){
            jQuery(this).removeClass('picked');
        } else {
            jQuery(".picked").removeClass('picked');
            jQuery(this).addClass('picked');
        } 
    }

    function start(){
        jQuery('#avfields li').bind('click', mouseHandler);
    }   

    jQuery(document).ready(start);

});
