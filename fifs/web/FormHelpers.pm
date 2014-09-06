#
# $Header: svn://svn/SWM/trunk/web/FormHelpers.pm 9350 2013-08-27 02:54:04Z apurcell $
#

package FormHelpers;

require Exporter;
@ISA =  qw(Exporter);
@EXPORT = qw(txt_field drop_down getDBdrop_down getDBdrop_down_Ref checkbox get_drop_down_list);
@EXPORT_OK = qw(txt_field drop_down getDBdrop_down getDBdrop_down_Ref checkbox get_drop_down_list);

use strict;

#Last Modified: 19/08/2004

sub txt_field {
  my ($name, $value, $size, $maxsize, $class)=@_;
  $value='' if !defined $value;
	$class ||= '';
  return qq[<input type="text" name="$name"  size="$size" value="$value" maxlength="$maxsize" class="$class">];
}


sub drop_down { 
  my ($name, $options_ref, $order_ref, $default, $size, $multi, $otherstyle, $class, $required)=@_;
  return '' if(!$name or !$options_ref);
  if(!defined $default) {$default=''; }
	$otherstyle ||= '';
	$multi||='';
	$required||='';
	$size||=1;
	$class ||= '';

  if(!$order_ref) {
    #Make sure the order array is set up if not already passed in
    my @order=();
    for my $i (sort {$options_ref->{$a} cmp $options_ref->{$b}} keys %{$options_ref})  { push @order, $i;  }
    $order_ref=\@order;
  }
  
  my $subBody='';
  for my $val (@{$order_ref}) {
    my $selected='';
		if(ref $default)	{
			for my $i (@{$default})	{
				$selected = 'SELECTED' if $val eq $i;
			}
		}
		else	{
			$selected = 'SELECTED' if $val eq $default;
		}
    $subBody .= qq[ <option $selected value="$val">$options_ref->{$val}</option>];
  }

	$multi=' multiple ' if $multi;
	$required=' required="Yes" ' if $required;
    #<select name="$name" size="$size" $multi >
  $subBody=qq[
    <select name="$name" size="$size" $multi style="$otherstyle" class = "$class" id = "dd_$name">
      $subBody
    </select>
  ];
  return $subBody; 
}

sub getDBdrop_down_Ref	{
    my($db, $statement, $preoption,$blank_if_no_values, $lang)=@_;
	$blank_if_no_values||=0;

    my $txt = $lang ? sub { $lang->txt($_[0]) } : sub { $_[0] } ;

	return '' if (!$db or !$statement );

  my %values=();
  my @order=();
	if($preoption)	{
		$values{''}=$preoption;
		push @order,'';
	}
	my $query = $db->prepare($statement);
	$query->execute;
	while(my ($id,$name)= $query->fetchrow_array()) {
        $values{$id} = &{ $txt }($name);
		push @order, $id;
  }
	return (undef,undef) if($blank_if_no_values and scalar(@order)==0 );
	return (undef,undef) if($blank_if_no_values and scalar(@order)==1 and $preoption );

	return (\%values, \@order);
}


sub getDBdrop_down	{
    my(
        $name,
        $db,
        $statement,
        $value,
        $preoption,
        $size,
        $multi,
        $blank_if_no_values,
        $lang,
    ) = @_;
	
	$blank_if_no_values||=0;
    my($value_ref, $order_ref) = getDBdrop_down_Ref(
        $db,
        $statement,
        $preoption,
        $blank_if_no_values,
        $lang,
    );
	return '' if(!defined $value_ref or !defined $order_ref) ;
  return drop_down($name, $value_ref, $order_ref, $value, $size, $multi) || '';

}


sub checkbox	{
  my ($name, $value, $val)=@_;
	my $checked = $value ? 'CHECKED' : '';
  if(!defined $val or $val eq '')	{$val='1';	}
  return qq[<input type="checkbox" name="$name" $checked  value="$val">];
}

sub get_drop_down_list {
  my ($db, $options, $name, $multiple) = @_;
  my $html = '';
  $multiple = "multiple" if $multiple;
  foreach my $key (sort {$options->{$a} cmp $options->{$b}} keys %{$options}) {
    if ($key ne 'Y' or $key ne 'N') {
      next if ($key eq '');
    }
    else {
      next if ($key < 1);
    }
    $html .= qq[<option value="$key">$options->{$key}</option>];
  }
  $html = qq[<select name="$name" class="chzn-select" $multiple style="width:200px;"><option value=""></option>$html</select>] if $html;
  return $html;
}

