#
# $Header: svn://svn/SWM/trunk/web/NagScreen.pm 11219 2014-04-03 04:10:49Z dhanslow $
#

package NagScreen;
require Exporter;
@ISA       = qw(Exporter);
@EXPORT    = qw(show_nag_screen);
@EXPORT_OK    = qw(show_nag_screen);

use strict;
use lib '.', '..';
use Defs;
use Utils;
use CGI qw(escape);

sub show_nag_screen {
	my($Data)=@_;

	my $width=450;
	my $height=310;

	my $esc_cl = escape($Data->{'client'});
	my $url="$Defs::base_url/nagscreen.cgi?client=$esc_cl&amp;TB_iframe=true&amp;height=$height&amp;width=$width;";

	my $body=qq[
	<script type="text/javascript" src="$Defs::base_url/js/thickbox.js"></script>
	<script type="text/javascript" src="$Defs::base_url/js/jscookie.js"></script>
	<style type="text/css" media="all">\@import "$Defs::base_url/css/thickbox.css";</style>

  <script language="JavaScript1.1" type="text/javascript">
	\$(document).ready(function() {
    var val = GetCookie('SWM-NAGSCREEN_LS');
    if(val == null ) {
			SetCookie('SWM-NAGSCREEN_LS',1,60);
			tb_show('Live Score Notification', '$url', null); 
    }
	}
	);
	</script>
	];
warn $body;
	return $body;
}

1;
