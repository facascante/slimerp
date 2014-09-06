package Postcodes;

require Exporter;
@ISA       = qw(Exporter);
@EXPORT    = qw(get_states_list get_state_hash get_state_map get_state_abbr_map get_state_from_postcode get_wildsearch);
@EXPORT_OK = qw(get_states_list get_state_hash get_state_map get_state_abbr_map get_state_from_postcode get_wildsearch);

use strict;
use DBUtils;
use Log;
use Data::Dumper;

my %states_map = (
    'ACT' => 'Australian Capital Territory',
    'NSW' => 'New South Wales',
    'NT'  => 'Northern Territory',
    'QLD' => 'Queensland',
    'SA'  => 'South Australia',
    'TAS' => 'Tasmania',
    'VIC' => 'Victoria',
    'WA'  => 'Western Australia',
);

sub get_states_list {
    return keys %states_map;
}

sub get_state_map {
    return \%states_map;
}

sub get_state_abbr_map {
    my %result = reverse %states_map;
    return \%result;
}

sub get_state_hash {
    my %result = ();
    my $val = 1;
    for my $key (sort keys %states_map) {
        $result {$val++} = $key;
    }

    return \%result;
}

sub get_state_from_postcode {
    my ($postcode) = @_;

    $postcode =~ s/^\s+|\s+$//g;

    return '' if $postcode !~ /^\d{4}$/;

    return 'ACT'
      if ( $postcode >= 2600 and $postcode <= 2618 )
      or $postcode =~ /29../;
    return 'NSW' if $postcode =~ /2.../;
    return 'NT'  if $postcode =~ /0[89]../;
    return 'QLD' if $postcode =~ /4.../;
    return 'SA'  if $postcode =~ /5.../;
    return 'TAS' if $postcode =~ /7.../;
    return 'VIC' if $postcode =~ /3.../;
    return 'WA'  if $postcode =~ /6.../;

    return '';
}

sub get_wildsearch {
    my ($key, $limit, $data)= @_;
    my $dbh = $data->{'db'};
    
    return [] if (not $data->{'SystemConfig'}{'EnablePostCodeData'});

    my $res = query_data(qq[
        SELECT strPostcode AS postcode, strSuburb AS suburb, strState AS state 
        FROM tblPostcodes
        WHERE strPostcode LIKE ? OR strSuburb LIKE ? OR strState LIKE ?
        LIMIT ?
        ], "$key%", "%$key%", "%$key%", "$limit");
    DEBUG Dumper($res);
    return $res;

    my $stat = query_stat(qq[
        SELECT strPostcode AS postcode, strSuburb AS suburb, strState AS state 
        FROM tblPostcodes
        WHERE strPostcode LIKE ? OR strSuburb LIKE ? OR strState LIKE ?
        LIMIT ?
        ], "$key%", "%$key%", "%$key%", "$limit");

    my $ds = $stat->fetchall_arrayref();

    DEBUG Dumper($ds);

    my @result = map(join('|', @{$_}), @{$ds});
    return \@result;
}

1;

# vim: set et sw=4 ts=4:
