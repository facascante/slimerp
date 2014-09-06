// Javascript include file to perform SP Passport cookie management
// Version 0.01
 
// This script requires jQuery to operate
   
function SPPassport	( fnArgs ){
	// Setup anything needed
	// Option Arguments 
  // - toolbar 1 or 0
	// Make call to passport server to get valid cookie
	if(fnArgs.toolbar)	{
		var elementID = fnArgs.ToolbarID || 'sp_passportToolbar';
		var toolbar = globalnav_html();
		jQuery('body').prepend(toolbar);
	}

	jQuery.getJSON("https://passport.sportingpulse.com/PassportSession/?callback=?", function(data) {
		if(data.name) {
			jQuery('#SPPassportName').text(data.name);
			jQuery('.spp_loggedout').hide();
			jQuery('.spp_loggedin').show();
		}
	});
}
	function globalnav_html()	{
		var html = ''
+ ' <style type="text/css"> '
+ ' #globalnav {background: url("https://reg.sportingpulse.com/images/global_nav_sprite.png") repeat-x scroll 0 -33px transparent;  float: left;  height: 32px;  width: 100%;}'
+ ' #globalnav-inner {margin: 0 auto;width: 996px;}'
+ ' .gnav-logo {background: url("https://reg.sportingpulse.com/images/global_nav_sprite.png") no-repeat scroll 0 -3px transparent;cursor: pointer;display: block;float: left;height: 32px;margin: 0;position: relative;width: 159px;}'
+ ' .gnav-splogo {background: url("https://reg.sportingpulse.com/images/global_nav_sprite.png") repeat-x scroll 0 -162px transparent;display: inline;float: left;height: 26px;margin: 2px 10px;width: 104px;}'
+ ' .navoptions {float: right;}'
+ ' .sp-sign-in-out-wrap {float: right;font-size: 12px;line-height: 32px;}'
+ ' .sp-sign-in-out-wrap a {float: left;color: #FFF;height: 32px;padding: 0 10px;display: block;}'
+ ' .sp-sign-in-out-wrap a:hover {background-image: #116faa;background-image: -webkit-linear-gradient(top, #2277b0 50%, #0066a4 50%);background-image: -moz-linear-gradient(top, #2277b0 50%, #0066a4 50%);background-image: -o-linear-gradient(top, #2277b0 50%, #0066a4 50%);background-image: -ms-linear-gradient(top, #2277b0 50%, #0066a4 50%);background-image: linear-gradient(top, #2277b0 50%, #0066a4 50%);}'
+ ' #gnav-arrow-wrap {float: right;display: inline;width: 159px;height: 32px;}'
+ ' #gnav-arrow {background: url("https://reg.sportingpulse.com/images/global_nav_sprite.png") repeat scroll -23px -353px transparent;display: inline;float: left;height: 11px;margin: 11px 9px 0;width: 13px;}'
+ ' .arrowup #gnav-arrow {background-position: -13px -352px;width: 13px;}'
+ ' </style> '
+ ' <div id="pushdown-wrapper" style="display:none;"> </div> '
+ '<div id="globalnav">'
+ '  <div id="globalnav-inner">'
+ '  <div class="gnav-logo"><div id="gnav-arrow-wrap"><div class="gnav-splogo"></div><div id="gnav-arrow"></div></div></div>'
+ '    <div class="sp-sign-in-out-wrap">'
+ '      <div class="spp_loggedout">'
+ '				<a href="http://support.sportingpulse.com/">Support</a>'
+ '        <a href="https://passport.sportingpulse.com/login/">SP Passport</a>'
+ '      </div>'
+ '      <div class="spp_loggedin" style="display:none;">'
+ '        <div class="navoptions">'
+ '          <a href="https://passport.sportingpulse.com/account/?"><span id="SPPassportName"></span></a>'
+ '          <a href="http://support.sportingpulse.com/">Support</a>'
+ '					<a href="https://passport.sportingpulse.com/logout/?">Sign out</a>'
+ '        </div>'
+ '      </div>'
+ '    </div>'
+ '  </div>'
+ '</div>'
+ '';
	return html;
}
jQuery(window).load(function(){
	jQuery("#gnav-arrow-wrap").click(function () {
		loadglobnavdata();
		jQuery("#pushdown-wrapper").slideToggle("slow");
		jQuery("#globalnav").toggleClass("arrowup");
	});

	function loadglobnavdata() {
	jQuery.ajax({
		dataType: "jsonp",
		url: "https://reg.sportingpulse.com/v5/js/globalnav.js",
		jsonpCallback : 'gncb',
		success: function(data)     {
		jQuery('#pushdown-wrapper').html(data.data || '');
	}
	});
	}
    if ( (jQuery.browser.msie && jQuery.browser.version < 9.0) )
        {
        jQuery('body').addClass('old-ie');
    }			
});

  function clickclear(thisfield, defaulttext) {
    if (thisfield.value == defaulttext) {
    thisfield.value = "";
    }
  }

  function clickrecall(thisfield, defaulttext) {
    if (thisfield.value == "") {
    thisfield.value = defaulttext;
    }
  }
