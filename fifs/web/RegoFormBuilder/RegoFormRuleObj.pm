package RegoFormRuleObj;

use lib;
use BaseObject2;
our @ISA = qw(BaseObject2);

use strict;

use Readonly;

# constants
Readonly::Scalar our $PROGRAM_NEW       => 1;
Readonly::Scalar our $PROGRAM_RETURNING => 2;

sub _getTableName {
    return 'tblRegoFormRules';
}

sub _getKeyName {
    return 'intRegoFormRuleID';
}

1;
