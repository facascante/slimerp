package GenDropDown;

require Exporter;

@ISA       = qw(Exporter);
@EXPORT    = qw(genDropdownOptions);
@EXPORT_OK = qw(genDropdownOptions);

use strict;
use warnings;

use lib;

sub genDropdownOptions {
    my ($Data, $params) = @_;

    my %optTypes = (
        1 => 'Seasons',
        2 => 'Comps',
        3 => 'Forms',
        4 => 'States',
        5 => 'Venues',
        6 => 'Teams',
    );

    my $optionsObj;

    my $objName = 'Options_'.$optTypes{$params->{'optType'}};

    if ($objName) {
		eval "require $objName";
        $optionsObj = $objName->new();
    }
    else {
        return undef;
    }

    my $Options = $optionsObj->getOptions($Data, $params);

    my $format = (exists $params->{'format'}) ? $params->{'format'} : 'hashref';

    my $asSelect  = $format eq 'select';
    my $asJSON    = $format eq 'json';
    my $asHashref = (!$asSelect and !$asJSON) ? 1 : 0;

    return $optionsObj->createSelect($Data, $params, $Options) if $asSelect;
    return $optionsObj->createJSON($Options)   if $asJSON;
    return $Options;
}

1;
