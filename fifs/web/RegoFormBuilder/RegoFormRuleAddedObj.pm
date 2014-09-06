package RegoFormRuleAddedObj;

use lib;
use BaseObject2;
our @ISA = qw(BaseObject2);

use strict;

sub _getTableName {
    return 'tblRegoFormRulesAdded';
}

sub _getKeyName {
    return 'intRegoFormRuleAddedID';
}

1;
