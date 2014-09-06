#
# $Header: svn://svn/SWM/trunk/web/BaseObject2.pm 11352 2014-04-23 01:57:49Z mstarcevic $
#

package BaseObject2;

use lib 'comp';
use BaseObject;
our @ISA = qw(BaseObject);

use strict;

use Utils;

sub load {
    my $self = shift;
    my %params = @_;
    my $dbh    = $params{'db'};
    my $id     = $params{'ID'} || 0;
    return undef if !$dbh;
    return undef if !$id;

    $self = $self->new(@_);

    my $sql = ($self->can('_getSQL'))
        ? $self->_getSQL()
        : getSimpleSQL('*', $self->_getTableName(), $self->_getKeyName(), 1);


    my @args = ($id);

    _doQuery($self, $sql, \@args);

    return $self;
}

sub loadWhere {
    my $this = shift;
    my (%params) = @_;

    my $dbh   = $params{'dbh'};
    my $where = $params{'where'} || '';

    return undef if !$dbh or !$where;

    my @fields = ('*');

    my $self = new $this(db=>$dbh);
    my ($sql, @bindVals) = getSelectSQL($self->_getTableName(), \@fields, $where);
    $sql .= " LIMIT 1";

    _doQuery($self, $sql, \@bindVals);
    $self->{'ID'} = $self->getValue($self->_getKeyName());

    return $self;
}

sub deleteWhere { 
    my $self = shift;
    my (%params) = @_;

    my $dbh   = $params{'dbh'};
    my $where = $params{'where'} || '';
    return undef if !$dbh or !$where;

    my ($sql, @bindVals) = getDeleteSQL($self->_getTableName(), $where);

    my $q = $dbh->prepare($sql);
    $q->execute(@bindVals);

    return 1;
}

sub updateWhere {
    my $self = shift;
    my (%params) = @_;

    my $dbh    = $params{'dbh'};
    my $fields = $params{'fields'} || '';
    my $where  = $params{'where'}  || '';
    return undef if !$dbh or !$fields or !$where;

    my ($sql, @bindVals) = getUpdateSQL($self->_getTableName(), $fields, $where);

    my $q = $dbh->prepare($sql);
    $q->execute(@bindVals);

    return 1;
}

sub save {
    my ($self, $dbh) = @_;

    return 0 if !$self->{'dbfields'};

    my $tableName = $self->_getTableName();
    my $keyName   = $self->_getKeyName();

    my @fields  = ();
    my @values  = ();

    my @ondupFields = ();
    my @ondupValues = ();

    my $temphash = $self->{'dbfields'};
    foreach my $tempkey (keys %$temphash) {
        push @fields, $tempkey;
        push @values, $temphash->{$tempkey};
    }

    if (exists $self->{'ondupfields'}) {
        my $temparr = $self->{'ondupfields'};
        foreach my $tempitem (@$temparr) {
            push @ondupFields, $tempitem;
            push @ondupValues, $self->{'dbfields'}{$tempitem};
        }
    }

    my $ID = $self->{'ID'};
    my $result = 0;

    if ($ID and !@ondupFields) {
        my $where = "$keyName=$ID";
        $result = $self->_updateRow($tableName, \@fields, \@values, $where);
    }
    else {
        $result = $self->_insertRow($tableName, \@fields, \@values, \@ondupFields, \@ondupValues);
    }

    return $result;
}

sub isDefined {
    my $self = shift;
    my $isDefined = (defined $self->{'ID'}) ? 1 : 0;
    return $isDefined;
}

sub isUndefined {
    my $self = shift;
    my $isUndefined = (!defined $self->{'ID'}) ? 1 : 0;
    return $isUndefined;
}

#a public method (needed well after the private one established). 
sub getTableName {
    my $self = shift;
    my $tableName = ($self->can('_getTableName')) ? $self->_getTableName() : undef;
    return $tableName; 
}

#a public method (needed well after the private one established). 
sub getKeyName {
    my $self = shift;
    my $keyName = ($self->can('_getKeyName')) ? $self->_getKeyName() : undef;
    return $keyName; 
}

sub getList { 
    my $self = shift;

    my (%params) = @_;
    my $dbh      = $params{'dbh'};
    my $fields   = $params{'fields'}   || [];
    my $where    = $params{'where'}    || [];
    my $order    = $params{'order'}    || [];
    my $format   = $params{'format'}   || 'objaref';
    my $keyField = $params{'keyfield'} || '';
    return undef if !$dbh;

    my $asArrayRef   = $format eq 'allaref';
    my $asHashRef    = $format eq 'allhref';
    my $asArrayOfObj = $format eq 'objaref';

    return undef if !$asArrayRef and !$asHashRef and !$asArrayOfObj;
    return undef if $asHashRef and !$keyField; 

    @$fields[0] = $self->_getKeyName() if !@$fields and $asArrayOfObj;
    @$fields[0] = '*' if !@$fields;

    my ($sql, @bindVals) = getSelectSQL($self->_getTableName(), $fields, $where, $order);

    my $q = $dbh->prepare($sql);
    $q->execute(@bindVals);

    my $retExpr;

    if ($asArrayRef) {
        $retExpr = $q->fetchall_arrayref();
    }
    elsif ($asHashRef) {
        $retExpr = $q->fetchall_hashref($keyField);
    }
    else { #as an arrayref of objects...
        my @objs = ();

        while (my $dref = $q->fetchrow_hashref()) {
            my $obj = $self->load(db=>$dbh, ID=>$dref->{$self->_getKeyName()});
            push @objs, $obj;
        }
        $retExpr = \@objs;
    }
    
    $q->finish();

    return $retExpr;
}

sub _doQuery{
    my $self = shift;
    my ($sql, $params) = @_;

    my $q = $self->{'db'}->prepare($sql);
    my $i = 0;
    foreach (@$params) {
        $i++;
        $q->bind_param($i, $_);
    }

    $q->execute();

    if (!$DBI::err) {
        $self->{'DBData'} = $q->fetchrow_hashref();
    }
    else {
        $self->LogError($DBI::err);
    }

    $q->finish();
}

sub _insertRow {
    my $self = shift;
    my ($tablename, $fields, $values, $ondupFields, $ondupValues) = @_;

    $ondupFields ||= [];
    $ondupValues ||= [];

    my $dbh = $self->{'db'};
    my $fldstr = '';
    my $valstr = '';
    my $count  = 0;
    
    my $current_date = 'CURRENT_DATE';

    foreach (@$fields) {
        $count++;
        $fldstr .= ', ' if $count > 1;
        $valstr .= ', ' if $count > 1;
        $fldstr .= "$_";
        $valstr .= (@$values[$count-1] !~ /$current_date\(\)/) ? '?' : "$current_date()";
    }

    my $sql = qq[insert into $tablename ($fldstr) values ($valstr)];
    if (@$ondupFields) {
        my $setstr = '';
        $count = 0;
        foreach (@$ondupFields) {
            $count++;
            $setstr .= ', ' if $count > 1;
            $setstr .= "$_=?";
        }
        $sql .= qq[ on duplicate key update $setstr];
    }
 
    my $q  = $dbh->prepare($sql);
    $count = 0;
    foreach (@$values) {
        if ($_ !~ /$current_date\(\)/) {
            $count++;
            $q->bind_param($count, $_);
        }
    }

    #no need to provide for current_date in ondup
    if (@$ondupFields) {
        foreach (@$ondupValues) {
            $count++;
            $q->bind_param($count, $_);
        }
    }

    $q->execute();

    my $insertID = $q->{mysql_insertid};

    $q->finish;

    return $insertID;
}

sub _updateRow {
    my $self = shift;
    my ($tablename, $fields, $values, $where) = @_;

    my $dbh = $self->{'db'};

    my $setstr = '';
    my $count  = 0;

    foreach (@$fields) {
        $count++;
        $setstr .= ', ' if $count > 1;
        $setstr .= "$_=?";
    }

    my $sql = qq[update $tablename set $setstr];
    $sql .= " where $where" if $where;
    my $q   = $dbh->prepare($sql);

    $count = 0;
    foreach (@$values) {
        $count++;
        $q->bind_param($count, $_);
    }

    $q->execute();

    $q->finish;

    return 1;
}

1;
