package LangBase;

@EXPORT= (qw/txt lexicon/);
use Locale::Maketext::Gettext;
use base ('Locale::Maketext::Gettext');

sub txt (@) { 
  my $self=shift @_;
  return '' if !$_[0];

  my @temp = @_;
  $temp[0] =~ s/^\n+//m;
  $temp[0] =~ s/\n+$//m;

  my $s = $self->maketext(@temp); 
  return $s;
  #return qq[<span style="color:red !important;">$s</span>];
} 

# I decree that this project's first language is English.

no warnings 'once';
#%Lexicon = (
  #'_AUTO' => 1,
  # That means that lookup failures can't happen -- if we get as far
  #  as looking for something in this lexicon, and we don't find it,
  #  then automagically set $Lexicon{$key} = $key, before possibly
  #  compiling it.
  
  # The exception is keys that start with "_" -- they aren't auto-makeable.

#);
# End of lexicon.


# a copy of quant without the print of the num first
# maybe quantNoNum or even integrate with quant
sub quant2 {
    my($handle, $num, @forms) = @_;

    return $num if @forms == 0; # what should this mean?
    return $forms[2] if @forms > 2 and $num == 0; # special zeroth case

    return( $handle->numerate($num, @forms) );
}

sub getNumberOf {
    my $result = 'Number of ' . $_[1];
    return $result;
}


sub getSearchingFrom {
    my $result = 'Searching from ' . $_[1] . ' down';
    return $result;
}

#sub lexicon { eval( '%' . substr(ref(shift),0,8) . '::Lexicon') || () }

1;  # End of module.


package LangBase::en_us;
use base qw(Locale::Maketext::Gettext);
return 1;

package LangBase::fr_fr;
use base qw(Locale::Maketext::Gettext);
return 1;



