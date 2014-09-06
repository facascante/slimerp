#
# $Header: svn://svn/SWM/trunk/web/techadmin/TechAdminPageGen.pm 9344 2013-08-26 06:19:42Z dhanslow $
#

package TechAdminPageGen;

require Exporter;
@ISA =  qw(Exporter);
@EXPORT = qw(print_adminpageGen create_tabs);
@EXPORT_OK = qw(print_adminpageGen create_tabs);

use strict;
use lib "..","../..";
use Defs;

sub print_adminpageGen {
	my($body, $page_title, $page_heading, $extra_ref)=@_;
	my $otherevents=$extra_ref->{onload} || '';
	print "Content-Type: text/html\n\n";
	print qq[
	<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN">
	<html>
	<head>
	<link rel="stylesheet" type="text/css" href="../css/style.css">
	<link rel="stylesheet" type="text/css" href="adminstyle.css">
	<title>$page_title</title>
	</head>
	<body>
    <div id="spheader"><img src="../images/membership_1.jpg" alt="" title=""><img src="../images/membership_2.jpg" alt="" title=""><img src="../images/membership_3.jpg" alt="" title=""><img src="../images/membership_4.jpg" alt="" title=""></div>
		$body
	</body>
</html>
	];
}

sub create_tabs	{
	my($subBody, $tabs_ref, $activetab, $name, $menu)=@_;
	$name||='';
	$menu||='';
	my $body=qq[<br><br>\n
	<table cellpadding="1" cellspacing="0" border="0" width="90%" align="center">
		<tr>
			<td class="blackbg">
				<table cellpadding="0" cellspacing="0" border="0" width="100%" align="center">
					<tr>
	];
	for my $i (0 .. $#$tabs_ref)	{
		my $bgclass='inactiveformbg';
		if($i!=0)	{$body.=qq[<td class="blackbg" align="center" width="1"></td>\n];}
		if($i==$activetab)	{
			$bgclass='formbg';
		}
		$body.=qq[	<td class="$bgclass tab" align="center" valign="middle"><a href="$tabs_ref->[$i][0]" class="tabheading">$tabs_ref->[$i][1]</a></td>\n];
	}
  $body.=qq[
					</tr>
					<tr>
	];
	for my $i (0 .. $#$tabs_ref)	{
		my $bgclass='blackbg';
		if($i==$activetab)	{$bgclass='formbg';}
		if($i!=0)	{$body.=qq[		<td class="blackbg" align="center" width="1"></td>\n];}
		$body.=qq[		<td class="$bgclass" align="center"></td>\n];
	}
	$body.=qq[
					</tr>
					<tr>
						<td colspan="].(($#$tabs_ref+1)*2).qq[" class="formbg"></td>
					</tr>
					<tr>
						<td colspan="].(($#$tabs_ref+1)*2).qq[" class="formbg">
							<table cellpadding="3" cellspacing="0" border="0" width="100%" align="center">
							<tr>
								<td class="name" align="left">&nbsp; $name</td>
								<td class="name" align="right">$menu &nbsp;</td>
							</tr>
							<tr>
								<td class="formbg" colspan="2">$subBody</td>
							</tr>
						</table>
					</tr>
				</table>
			</td>
		</tr>
	</table>
	];
	return $body;
}
1;
