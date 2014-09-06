package RegoFormConfigObj;

use lib;
use BaseObject2;
our @ISA = qw(BaseObject2);

use strict;

use Utils;
use RegoFormConfigSQL;

sub _getTableName {
    return 'tblRegoFormConfig';
}

sub _getKeyName {
    return 'intRegoFormConfigID';
}

sub loadByRegoFormID {
    my $this = shift;
    my (%params) = @_;

    my $dbh = $params{'dbh'};
    my $regoFormID = $params{'regoFormID'};

    my $self = new $this(db=>$dbh);
    my $sql  = getByRegoFormIdSQL();
    my @args = ($regoFormID);

    $self->_doQuery($sql, \@args);
    $self->{'ID'} = $self->getValue('intRegoFormConfigID');

    return $self;
}

sub getListOfTermsSetByParentBody {
    my $self = shift;

    my %params = @_;
    my $dbh        = $params{'dbh'};
    my $realmID    = $params{'realmID'}    || 0;
    my $subRealmID = $params{'subRealmID'} || 0;
    my $assocID    = $params{'assocID'}    || 0;

    return undef if !$dbh;
    return undef if !$realmID or !$subRealmID or !$assocID;

    my $sql = getListOfTermsSetByParentBodySQL(idOnly=>1);

    my @bindVars = ($realmID, $subRealmID, $assocID);

    my $q = getQueryPreparedAndBound($dbh, $sql, \@bindVars);
   
    $q->execute();

    my @regoFormConfigObjs = ();

    while (my $dref = $q->fetchrow_hashref()) {
        my $regoFormConfigObj = $self->load(db=>$dbh, ID=>$dref->{'intRegoFormConfigID'});
        push @regoFormConfigObjs, $regoFormConfigObj;
    }
    
    $q->finish();

    return \@regoFormConfigObjs;
}

1;
