package PersonUtils;
require Exporter;
@ISA    = qw(Exporter);
@EXPORT = @EXPORT_OK = qw(
  formatPersonName
);

use strict;
use lib '.', '..', 'Clearances';
use Defs;

sub formatPersonName {

    my ($Data, $firstname, $surname, $gender) = @_;
    
    return "$firstname $surname";
}

1;

