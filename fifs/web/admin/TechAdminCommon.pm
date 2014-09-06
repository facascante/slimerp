#
# $Header: svn://svn/SWM/trunk/web/admin/TechAdminCommon.pm 10068 2013-12-01 22:52:55Z tcourt $
#

package TechAdminCommon;
require Exporter;
@ISA =	qw(Exporter);
@EXPORT = qw(create_selectbox fix_date currency );
@EXPORT_OK = qw(create_selectbox fix_date currency );

use lib "..","../..";
use Defs;
use strict;
use CGI qw(escape);

sub create_selectbox {
	#Create HTML Select Box from Hash Ref passed in
	my($data_ref, $current_data, $name, $preoptions,$action, $type)=@_;
	if(!$name)	{return '';}
	if(!$preoptions)	{$preoptions='';}
	if(!$action)	{$action='';}
	my $subBody='';
	my $selected='';
	if($type and $type==3)	{
		for my $i (@{$data_ref})	{
			if ($current_data and $current_data eq $i) {$selected =" SELECTED ";}
			else	{$selected="";}
			$subBody .= qq[ <option $selected value="$i">$i</option>\n ];
		}
	}
	elsif($type and $type==2)	{
		foreach my $i (sort { $data_ref->{$a}[1] <=> $data_ref->{$b}[1] } keys %{$data_ref})       {
			if ($current_data and $current_data ==$i) {$selected =" SELECTED ";}
			else	{$selected="";}
			$subBody .= qq[ <option $selected value="$i">$data_ref->{$i}[0]</option>\n ];
		}
	}
	else	{
		foreach my $i (sort { $data_ref->{$a} cmp $data_ref->{$b} } keys %{$data_ref})       {
			if ($current_data and $current_data eq $i) {$selected =" SELECTED ";}
			else	{$selected="";}
			$subBody .= qq[ <option $selected value="$i">$data_ref->{$i}</option>\n ];
		}
	}
	$subBody=qq[
		<select name="$name" size="1" $action>
			$preoptions
			$subBody
		</select>
	];
	return $subBody;
}

sub fix_date	{
	my($date,%extra)=@_;
	if(exists $extra{NODAY} and $extra{NODAY})	{
		my($mm,$yyyy)=$date=~m:(\d+)/(\d+):;
		if(!$mm or !$yyyy)	{	return ("Invalid Date",'');}
		if($yyyy <100)	{$yyyy+=2000;}
		return ("","$yyyy-$mm-01");
	}
	my($dd,$mm,$yyyy)=$date=~m:(\d+)/(\d+)/(\d+):;
	if(!$dd or !$mm or !$yyyy)	{	return ("Invalid Date",'');}
	if($yyyy <100)	{$yyyy+=2000;}
	return ("","$yyyy-$mm-$dd");
}


sub currency  {
  $_[0]||=0;
  my $text= sprintf "%.2f",$_[0];
  $text= reverse $text;
  $text=~s/(\d\d\d)(?=\d)(?!\d*\.)/$1,/g;
  return scalar reverse $text;
}

1;
