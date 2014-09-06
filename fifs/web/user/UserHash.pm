package UserHash;
require Exporter;
@ISA =  qw(Exporter);
@EXPORT = qw(checkHash newHash);
@EXPORT_OK = qw(checkHash newHash);

use strict;

use Data::Random qw(:all);
use MD5;

sub checkHash {
  my(
    $string,
    $existingHash,
  ) = @_;
  #extract salt from existing hash
  my $salt = substr $existingHash,0,6;

  my $newHash = _newHash($string, $salt);

  return 1 if $newHash eq $existingHash;
}


sub newHash  {
  my($string) = @_;

  return _newHash($string, '');
}

sub _newHash  {
  my(
    $string, 
    $salt
  ) = @_;

  if(!$salt)  {
    my  @validChars = (qw(1 2 3 4 5 6 7 8 9 0 A B C D E F G H I J K L M N O P Q R S T U V W X Y Z a b c d e f g h i j k l m n o p q r s t u v w x y z ! @ $ % ^ & * : ; ? ~));
    my @random_chars = rand_chars( set => \@validChars, size => 6);
    $salt = join('',@random_chars);
  }

  my $m = new MD5;
  $m->reset();
  $m->add($salt, $string);

  my $hash = $m->hexdigest();
  return $salt.$hash;
}
