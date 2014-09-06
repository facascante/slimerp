#
# $Header: svn://svn/SWM/trunk/web/RegoFormUtils.pm 8251 2013-04-08 09:00:53Z rlee $
#

package RegoFormUtils;

require Exporter;
@ISA       = qw(Exporter);
@EXPORT    = qw(get_notif_bits pack_notif_bits get_emails_list);
@EXPORT_OK = qw(get_notif_bits pack_notif_bits get_emails_list);

use strict;

use List::MoreUtils qw(uniq);

sub get_notif_bits {
    my ($char) = @_;

    #the bits will come out as 16, 8, 4, 2, 1 respectively.
    my $assoc_bit   = $char & (1<<4);
    my $club_bit    = $char & (1<<3);
    my $member_bit  = $char & (1<<1);
    my $parents_bit = $char & (1<<0);

    #the bits will be left with their values unaltered because calling programs will (at this point at least) test for > 0 value.
    return ($assoc_bit, $club_bit, $member_bit, $parents_bit);
}

sub pack_notif_bits {
    my ($assoc_bit, $club_bit, $member_bit, $parents_bit) = @_;

    #just a precaution because if bits are rewritten with their extracted values (see get_notif_bits), things will be thrown out.
    $assoc_bit   = 1 if $assoc_bit   > 1;
    $club_bit    = 1 if $club_bit    > 1;
    $member_bit  = 1 if $member_bit  > 1;
    $parents_bit = 1 if $parents_bit > 1;

    my @arr  = (0, 0, 0, $assoc_bit, $club_bit, $member_bit, $parents_bit);
    my $str  = join('', @arr);
    my $char = ord pack ('B8', $str);

    return $char;
}

sub get_emails_list {
    my ($contacts, $format) = @_;

    $format ||= 0; #format 0 = return an array ref (default). format 1 = return a semi-colon delimited string.

    my @emails = ();
    for my $dref(@$contacts) {
        push @emails, $dref->{strContactEmail} if $dref->{strContactEmail};
    }

    my @unique_emails = uniq(@emails);

    return \@unique_emails if !$format;

    my $emails_str = join(';', @unique_emails);
    $emails_str   .= ';' if $emails_str;

    return $emails_str;
}

1;
