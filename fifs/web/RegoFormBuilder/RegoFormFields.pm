#
# $Header: svn://svn/SWM/trunk/web/RegoFormFields.pm 11473 2014-05-02 06:05:26Z sliu $
#

package RegoFormFields;
require Exporter;
@ISA =  qw(Exporter);
@EXPORT = qw(get_fields_list);
@EXPORT_OK = qw(get_fields_list);

use strict;
use ConfigOptions;

sub get_fields_list {
    my ($data, $field_type) = @_;

    return 0 if $field_type ne 'Member' and $field_type ne 'Team';

    my $fields_list = getFieldsList($data, $field_type);

    my @fields_to_remove = qw(
        intPlayer
        intCoach
        intUmpire
        intOfficial
        intMisc
        intVolunteer
        intDefaulter
    ) if $field_type eq 'Member';

    remove_fields($fields_list, \@fields_to_remove) if @fields_to_remove;

    return $fields_list;
}

sub remove_fields {
    my ($fields_list, $fields_to_remove) = @_;
    for my $d(@$fields_to_remove) {
        my $index = 0;
        $index++ until @$fields_list[$index] eq $d;
        splice(@$fields_list, $index, 1);
    }
    return 1;
}

1;
