#
# $Header: svn://svn/SWM/trunk/web/AddToPage.pm 8251 2013-04-08 09:00:53Z rlee $
#

package AddToPage;

use lib "..";
use Defs;

use strict;

sub new {

  my $this = shift;
  my $class = ref($this) || $this;
  my $self ={ };

	$self->{'TopJSFiles'} = [];
	$self->{'BottomJSFiles'} = [];
	$self->{'TopJSInline'} = [];
	$self->{'BottomJSInline'} = [];
	$self->{'CSSFiles'} = [];
	$self->{'CSSInline'} = [];

  bless $self, $class;

  return $self;
}

sub add{
	my $self = shift;
	my (
		$type, #css/js
		$includetype, # file/inline
		$value,
	) = @_;

	my $key = $self->_getkey(
		$type, 
		$includetype, 
	);
	if($key)	{
		push @{$self->{$key}}, $value;
		return 1;
	}
	return 0;
}


sub get{
	my $self = shift;
	my (
		$type, #css/js
		$includetype, # file/inline
	) = @_;

	my $key = $self->_getkey(
		$type, 
		$includetype, 
	);
	return '' if !$key;
	my %found = ();

	my $string = '';
	for my $val (@{$self->{$key}})	{
		next if $found{$val};
		$found{$val} = 1;
		if($type eq 'css')	{
			if($includetype eq 'inline')	{
				$string .= $val;
			}
			elsif($includetype eq 'file')	{
				$string .= qq[<link rel="stylesheet" type="text/css" href="$val">];
			}
		}
		elsif($type =~/^js_/)	{
			if($includetype eq 'inline')	{
				$string .= $val;
			}
			elsif($includetype eq 'file')	{
				$string .= qq[<script type="text/javascript" src="$val"></script>];
			}
		}
	}
	my $output = $string || '';
	return '' if !$string;
	if($includetype eq 'inline')	{
		if($type eq 'css')	{
			$output = qq[<style type="text/css">].optimiseCSS($string)."</style>";
		}
		elsif($type =~/^js_/)	{
			$output = qq[ <script type="text/javascript"> jQuery().ready(function() { $string });</script> ];
		}
	}
	return $output;
}


#----------------
sub _getkey {
	my $self = shift;
	my (
		$type, #css/js
		$includetype, # file/inline
	) = @_;

	my %allowedtypes = (
		css => 'CSS',
		js_top => 'TopJS',
		js_bottom => 'BottomJS',
	);
	my %allowedincludetypes = (
		file => 'Files',
		inline => 'Inline',
	);
	if(
		!$type 
		or !$includetype
	)	{
		return undef;
	}
	return undef if !$allowedtypes{$type};
	return undef if !$allowedincludetypes{$includetype};

	return $allowedtypes{$type}.$allowedincludetypes{$includetype};
}

sub optimiseCSS {
  my($css) = @_;
  $css=~s/[\t\n]//g;
  $css=~s/\s*([;,{}])\s*/$1/gs;
  return $css;
}


1;
