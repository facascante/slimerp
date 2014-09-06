#!/usr/bin/perl -w

#
# $Header: svn://svn/SWM/trunk/web/bcode.cgi 10144 2013-12-03 21:36:47Z tcourt $
#

use strict;
use CGI qw(param unescape);
use Barcode::Code128;


	my $txt=$ENV{QUERY_STRING} || '';
	if($txt=~/=/)	{
		$txt=param('txt');
	}
	$txt=unescape($txt);
	my $code=new Barcode::Code128;
	if(param('w'))	{
		$code->option('width',param('w'));
	}
	$code->option('border',0);
	$code->option('show_text',param('st')||0);
	$code->option('transparent_text',1);
	$code->option('font_margin',2);
	$code->option('font_align','right');
	$code->option('font','small');
	$code->option('padding','1');
	
	print "Content-Type: image/png\n\n";
	exit if !$txt;
	print $code->png($txt);
