#
# $Header: svn://svn/SWM/trunk/web/Otp.pm 8251 2013-04-08 09:00:53Z rlee $
#

##++
##     Otp v1.0
##     Last modified: March 2nd, 2000
##
##     Copyright (c) 2000 by Trans-Euro I.T Ltd
##     All Rights Reserved
##
##     E-Mail: tigger@marketrends.net
##
##     Permission  to  use,  copy, and distribute is hereby granted,
##     providing that the above copyright notice and this permission
##     appear in all copies and in supporting documentation.
##--

=head1 NAME

  Otp - Perl module to encrypt a string against a key.

=head1 SYNOPSIS

  use Otp;
 
  $y =  new Otp;

  $s = "1111 2222 5454 7777";
  $t = $y->Otp($s,"A key");
  $u = $y->Otp($t,"A key");

  print "The source string is  $s\n";
  print "The encrypted string  $t\n";
  print "The original string   $u\n";

  exit;

=head1 DESCRIPTION

  This module can be used to encrypt and decrypt
  character strings. Using an xor operation.
  As long as the same 'key' is used, the original
  string can always be derived from its encryption.
  The 'key' may be any length although keys longer
  than the string to be encrypted are truncated.

=head1 COPYRIGHT INFORMATION


  Copyright (c) 2000 Marketrends Productions,
                           Trans-Euro I.T Ltd.

  Permission to use, copy, and  distribute  is  hereby granted,
  providing that the above copyright notice and this permission
  appear in all copies and in supporting documentation.

=cut

package        Otp;
require        Exporter;
@ISA       = qw(Exporter);
@EXPORT    = qw(Otp new version);
@EXPORT_OK = qw(Otp new version);

sub new {
    my    $object = {};
    bless $object;
    return $object;
}

sub version {
    return "1.00";
}

sub Otp{
    shift;
    local ($_P1)= @_;
    shift;
    local ($_K1)= @_;
 
 if (!defined($_P1) || !defined($_K1)) {return ''; }    
    my @_p = ();
    my @_k = ();
    my @_e = ();
    my $_l = "";
    my $_i = 0;
    my $_r = "";

    while ( length($_K1) < length($_P1) ) { $_K1=$_K1.$_K1;}

    $_K1=substr($_K1,0,length($_P1));

    @_p=split(//,$_P1);
    @_k=split(//,$_K1);

    foreach $_l (@_p) {
       $_e[$_i] = chr(ord($_l) ^ ord($_k[$_i]));
       $_i++;
                      }

    $_r = join '',@_e;

    return $_r;    
}

1;

