jQuery(function() {
	jQuery( "#ROallfields" ).accordion({
		collapsible: true,
		fillSpace: true
	}).disableSelection();
	jQuery( ".connectedSortable" ).sortable({
		helper: "clone",
		appendTo: 'body',
		cancel: ':input,button,.chzn-drop',
		remove: function(event, ui)	{
			var parent = jQuery(this).attr("id");
			var child = jQuery(ui.item).children(':first-child').attr("id");
			jQuery('#' + child).data('parent',parent);
		},
		placeholder: "ui-state-highlight"
		
	}).sortable("option", "connectWith", '.connectedSortable');
	jQuery("#reportform").submit(function () {
		 var activefields = [];
		 jQuery('#ROselectedfields .RO_fieldblock').each(function() {
			 activefields.push(jQuery(this).attr('id'));
		 })
		 jQuery('#ROselectedfieldlist').val(activefields.join(','));
	});
	jQuery(".ROButRun").click(function () {
		jQuery('#reportform').attr('target','_report');
	});
	loadSaved();
	$(".dateinput").datepicker({ dateFormat: 'dd/mm/yy', autoSize: true, changeMonth: true, changeYear: true, yearRange: '1900:2020'});
	$(".timeinput").timepicker({ dateFormat: 'dd/mm/yy', autoSize: true, changeMonth: true, changeYear: true, yearRange: '1900:2020'});
	$(".datetimeinput").datetimepicker({minDate: '01/01/1900', maxDate: '01/01/2020'});
});

function applyDropDownExtra(selector) {
	jQuery(selector).each(function ()	{
		jQuery(this).chosen({ disable_search_threshold: 5 });
		var container = jQuery(this).parent().find('.chzn-container, .chzn-drop');
		container.css('width','auto');
		container.css('min-width',container.width()+10);
	});
}

function displaybox(fieldname, nodropdownextra)  {
		var selectedoption = jQuery('#fid_comp_' + fieldname).val();
		switch(selectedoption)  {
			case "":
			case "isnotblank":
			case "isblank":
				jQuery("#d1_"+fieldname).hide();
				jQuery("#d2_"+fieldname).hide();
				break;
			case "between":
				jQuery("#d1_"+fieldname).css("display", "inline");
				jQuery("#d2_"+fieldname).css("display", "inline");
				break;
			default:
				jQuery("#d1_"+fieldname).css("display", "inline");
				if(jQuery("#d2_"+fieldname))  {
					jQuery("#d2_"+fieldname).hide();
				}
		}
		if(!nodropdownextra)	{
			applyDropDownExtra("#d1_"+fieldname + ' select');
		}
}

function removefield (liID)	{
	var node = jQuery('#' + liID);
	var parent = node.parent();
	var newparent = node.data('parent');
	parent.appendTo('#' + newparent);
}

function loadSaved ()	{
	var reportname = jQuery('#SavedReportName').val();
	jQuery('#ROsavedname').val(reportname);
	var json = jQuery('#SavedReportData').val();
	if(!json)	{return false };
	var JSONobj = jQuery.parseJSON(json);
	
	if(!JSONobj)	{
		return false 
	}
	var jsonfields = JSONobj.fields;
	jQuery.each(jsonfields, function(index, row) {
		var fieldname = row.name;
		var field = jQuery('#fld_' + fieldname);
		var fieldparent = field.parent();
		var grandparent = fieldparent.parent();
		var grandparent2 = grandparent.attr("id");
		field.data('parent',grandparent.attr("id"));
		fieldparent.appendTo('#ROselectedfields-list');
		if(row.comp)	{
			var id = '#fid_comp_' + fieldname;
			jQuery(id).val(row.comp);
			displaybox(fieldname,1);
		}
		jQuery('#f_chk_' + fieldname).attr('checked', row.display ? true : false);
		if(row.v1 != undefined && row.v1.length)	{
			var vals = row.v1.split('\0');
			jQuery('[name=f_'+ fieldname + '_1]').val(vals);
		}
		if(row.v2 != undefined && row.v2.length)	{
			var vals = row.v2.split('\0');
			jQuery('[name=f_'+ fieldname + '_2]').val(vals);
		}
	});
	var jsonoptions = JSONobj.options;
	jQuery.each(jsonoptions, function(key, value) {
		if(key == undefined)	{
			next;
		}
		if(key == 'RecordFilter')	{
			jQuery('[name=RO_RecordFilter]').filter('[value="' + value + '"]').attr('checked', true);
		}
		if(key == 'SortBy1' )	{
			jQuery('[name=RO_SortBy1]').val(value);
		}
		if(key == 'SortByDir1' )	{
			jQuery('[name=RO_SortByDir1]').val(value);
		}
		if(key == 'SortBy2' )	{
			jQuery('[name=RO_SortBy2]').val(value);
		}
		if(key == 'SortByDir2' )	{
			jQuery('[name=RO_SortByDir2]').val(value);
		}
		if(key == 'GroupBy' )	{
			jQuery('[name=RO_GroupBy]').val(value);
		}
		if(key == 'Output' )	{
			jQuery('[name=RO_OutputType]').filter('[value="' + value + '"]').attr('checked', true);
		}
		if(key == 'OutputEmail' )	{
			jQuery('[name=RO_OutputEmail]').val(value);
		}
		if(/^_EXT/.test(key))	{
			jQuery('[name=' + key + ']').val(value);
		}
	});
	applyDropDownExtra('#ROselectedfields .RO_valfields select');
}
