// injury.js

function doOther(name, elemID){
    var other = 0;

    jQuery(name + ' :selected').each(function(i, selected){
        if (jQuery(selected).text().toLowerCase() === 'other - please specify'){
            other++;
            return false;
        }
    });

  if (other) {
      if (jQuery(elemID).parent().parent().is(':hidden')){
          jQuery(elemID).parent().parent().css('display', 'table-row');
          jQuery(elemID).attr('required', 'required');
          jQuery(elemID).parent().append('<img src="images/compulsory.gif" alt="Compulsory Field" title="Compulsory Field" id="othercf"/>');
      }
  }
  else if (jQuery(elemID).parent().parent().is(':visible')){
      jQuery(elemID).removeAttr('required');
      jQuery(elemID).val('');
      jQuery('#othercf').remove();
      jQuery(elemID).parent().parent().css('display', 'none');
  }
}
