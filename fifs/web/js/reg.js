function dialogform(url, title, width, height,data) {
	var d = jQuery('<div><iframe id="modalIframeId" width="100%" height="99%" marginWidth="0" marginHeight="0" frameBorder="0" scrolling="auto" src = "' + url +'"></iframe>').dialog({
			modal: true,
			autoOpen: false,
			//open: function () { jQuery(this).load(url); },         
			close: function(ev, ui) { jQuery(this).dialog('destroy'); },
			height: height || 500,
			width: width || 600,
			resizable: false,
			title: title,
			buttons: { 
				"Close": function() { jQuery(this).dialog("destroy"); }
			}
	});
	d.dialog('open');
	if(data) {d.html(unescape(data));}
}

// Regs new simple tab code 9/8/2013

$('ul.new_tabs').each(function(){
  // For each set of tabs, we want to keep track of
  // which tab is active and it's associated content
  var $active, $content, $links = $(this).find('a');

  // If the location.hash matches one of the links, use that as the active tab.
  // If no match is found, use the first link as the initial active tab.
  $active = $($links.filter('[href="'+location.hash+'"]')[0] || $links[0]);
  $active.addClass('active');
  $content = $($active.attr('href'));

  // Hide the remaining content
  $links.not($active).each(function () {
    $($(this).attr('href')).hide();
  });

  // Bind the click event handler
  $(this).on('click', 'a', function(e){
    // Make the old tab inactive.
    $active.removeClass('active');
		$('.showall').removeClass('active');
		$('.HTF_table tbody').hide();
		$content.hide();

		

    // Update the variables with the new link and content
    $active = $(this);
    $content = $($(this).attr('href'));

    // Make the tab active.
    $active.addClass('active');
    $content.show();

    // Prevent the anchor's default click action
    e.preventDefault();
  });
	$('.showall').click(function() {
		$('.showall').addClass('active');
		$('.HTF_table tbody').attr('style', 'display:block;');
		$('ul.new_tabs a').removeClass('active');
	});
});
