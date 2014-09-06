// defcodeoptionsorder.js
    
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

    jQuery('.fieldlinks').on('click', 'a.delopt', (function(e){ 
        e.preventDefault();
        var optionID=jQuery(this).attr("id");
        jQuery("#dialog-modal").dialog({
            modal: true,
            resizable: false,
            buttons: {
                'Delete': function(){
                    optionID = optionID.replace('del_', '');
                    deleteOption(optionID);
                    jQuery(this).dialog("close");
                },
                'Cancel': function(){
                    jQuery(this).dialog("close");
                }
            }
        });
    }));

    jQuery(function(){
   	    jQuery("#sortable").sortable({
  		    placeholder:"ui-state-highlight"
        });
        jQuery("#sortable").disableSelection();
	});

    // functions

    function getClient(){
        return jQuery("#cff_client").val();
    }

    function getType(){
        return jQuery("#cff_type").val();
    }

    function getKey(){
        return jQuery("#cff_key").val();
    }

    function updateOrder(newOrder){
        var request = jQuery.ajax({
            url: "ajax/aj_defcode_options_order_update.cgi", 
            type: "POST",
            data: "client=" + getClient() + "&amp;type=" + getType() + "&amp;key=" + getKey() + "&amp;order=" + newOrder,
            dataType: 'json'
        });
        checkRequest(request);
    }

    function deleteOption(optID){
        var request = jQuery.ajax({
            url: "ajax/aj_defcode_option_delete.cgi", 
            type: "POST",
            data: "client=" + getClient() + "&amp;type=" + getType() + "&amp;key=" + getKey() + "&amp;optid=" + optID,
            dataType: 'json'
        });
        checkRequest(request);
        if (request.done)
            jQuery('li').remove('#foo_'+optID);
    }

    function checkRequest(request){
        request.fail(function(jqXHR, textStatus){
            jQuery("#msgarea").html("Request failed: " + textStatus);
            jQuery("#msgarea").show();
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
