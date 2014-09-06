function movecombos(divID, order_field)  {
	jQuery( '#leftbox_' + divID).sortable({
		connectWith: "ul",
		placeholder: "ui-state-highlight",
		helper: "clone",
		dropOnEmpty: true 
	});

	jQuery( '#rightbox_' + divID).sortable({
		connectWith: "ul",
		placeholder: "ui-state-highlight",
		helper: "clone",
		dropOnEmpty: true 
	});
	jQuery( '#rightbox_' + divID).bind('sortupdate',function(event, ui){
		updateOrder(divID, order_field);
	});
	jQuery( '#leftbox_' + divID + ', #rightbox_' + divID ).disableSelection();
	updateOrder(divID, order_field);
}


function updateOrder(divID, order_field)	{
	var order = [];
	jQuery('#rightbox_' + divID + ' .movecombobox-item').each(function() {
		var v = jQuery(this).attr('id').replace('ms'+divID+'-', '');
		order.push(v);
	})
	jQuery('#' + order_field).val(order.join('|'));
};
