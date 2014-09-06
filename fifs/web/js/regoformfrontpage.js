jQuery(document).ready(function() {
  jQuery('.accordianheader').click(function(){
    var current = jQuery(this).next('.accordianblock').attr("id");
    jQuery('.accordianblock:visible').filter(function() {
      var tid = jQuery(this).attr("id");
      if(current == tid)  {
        return false;
      }
      return true;
    }).slideToggle();
    jQuery('.accordianheader').removeClass('activebar').addClass('inactivebar');
		if(!jQuery(this).next('.accordianblock').is(':visible'))	{
			jQuery(this).removeClass('inactivebar').addClass('activebar');
		};
    jQuery(this).next('.accordianblock').slideToggle();
  });
});

