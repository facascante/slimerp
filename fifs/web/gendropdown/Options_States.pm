package Options_States;

use strict;
use warnings;

use Options_Base;

our @ISA = qw(Options_Base);

sub getOptions {

    my %Options  = ();
    my $count    = 0;

    my %States = (
        800  => 'NT',
        2000 => 'NSW',
        2600 => 'ACT',
        3000 => 'VIC',
        4000 => 'QLD',
        5000 => 'SA',
        6000 => 'WA',
        7000 => 'TAS',
    );

    foreach my $key (keys %States) {
        $count++;
        $Options{$count} = {
            id   => $key,
            desc => $States{$key},
        };
    }

    return \%Options;
}

sub getSelectName {
    return 'stateID';
}

sub getSelectID {
    return 'd_stateID';
}

sub getSelectDesc {
    return 'state';
}

sub getDefaultValue {
    return 0;
}

1;
