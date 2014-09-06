#
# $Header: svn://svn/SWM/trunk/web/MoveCombos.pm 8251 2013-04-08 09:00:53Z rlee $
#

package MoveCombos;
require Exporter;

@ISA =  qw(Exporter);
@EXPORT = qw(getMoveSelectBoxes);

use strict;


sub getMoveSelectBoxes {
	my($Data, $divID, $fromlabel, $tolabel,  $fromdata, $todata, $width, $height, $activeorder) =@_;
	my $fromdatastr='';
	my $todatastr='';
	$width ||= 270;
	$height ||= 360;
	for my $i (@{$fromdata})  {
		my $name=$i->[1] || next;
		$fromdatastr.='<li id = "ms'.$divID.'-'.$i->[0].'" class = "movecombobox-item">'.$name.'</li>';
	}
	for my $i (@{$todata})  {
		my $name=$i->[1] || next;
		$todatastr.='<li id = "ms'.$divID.'-'.$i->[0].'" class = "movecombobox-item">'.$name.'</li>';
	}

	my $js=qq~
		movecombos('$divID', '$activeorder');
	~;
	my $page = qq[
		<div id = "$divID" class = "movecomboboxes_wrapper">
			<fieldset class = "movecomboboxes_box_wrapper" style = "width:].$width.qq[px;height:].$height.qq[px;">
				<legend>$fromlabel</legend>
				<ul id = "leftbox_$divID" class = "movecomboboxes movecomboxes-left" style = "width:].$width.qq[px;height:].($height-20).qq[px">$fromdatastr </ul>
			</fieldset>
			<fieldset class = "movecomboboxes_box_wrapper" style = "width:].$width.qq[px;height:].$height.qq[px;">
				<legend>$tolabel</legend>
				<ul id = "rightbox_$divID" class = "movecomboboxes movecomboxes-right" style = "width:].$width.qq[px;height:].($height-20).qq[px">$todatastr </ul>
			</fieldset>
		</div>
	];
	$Data->{'AddToPage'}->add('js_bottom','file','js/movecomboboxes.js');
	$Data->{'AddToPage'}->add('js_bottom','inline',$js);
	return $page;
}

1;
