#
# $Header: svn://svn/SWM/trunk/web/PaymentSplitObj.pm 8251 2013-04-08 09:00:53Z rlee $
#

package PaymentSplitObj;

use strict;
use DeQuote;


sub new {
    my ($class, %args) = @_;

    my $self = {
        _splitID   => $args{splitID},
        _ruleID    => $args{ruleID},
        _typeID    => $args{typeID},
        _entityID  => $args{entityID},
        _splitName => $args{splitName}
    };

    $self = bless ($self, $class);

    return $self;
}


###############################################################################
# Getters
###############################################################################


sub getSplitID {
    my ($self) = shift;
    return $self->{_splitID};
}


sub getRuleID {
    my ($self) = shift;
    return $self->{_ruleID};
}


sub getTypeID {
    my ($self) = shift;
    return $self->{_typeID};
}


sub getEntityID {
    my ($self) = shift;
    return $self->{_entityID};
}

sub getSplitName {
    my ($self) = shift;
    return $self->{_splitName};
}


sub getList {
    my ($self, $entityID, $typeID, $dbh) = @_;
    my $where   = qq[(intEntityTypeID=$typeID) AND (intEntityID=$entityID)];
    my $orderBy = qq[ORDER BY strSplitName];
    return _processQuery($where, $orderBy, $dbh);
}


sub getListByRule {
    my ($self, $ruleID, $dbh) = @_;
    my $where   = qq[(intRuleID=$ruleID)];
    my $orderBy = qq[ORDER BY intSplitID];
    return _processQuery($where, $orderBy, $dbh);
}


###############################################################################
# Setters
###############################################################################


sub setRuleID {
    my ($self, $ruleID) = @_;
    $self->{_ruleID} = $ruleID if defined $ruleID;
}


sub setTypeID {
    my ($self, $typeID) = @_;
    $self->{_typeID} = $typeID if defined $typeID;
}


sub setEntityID {
    my ($self, $entityID) = @_;
    $self->{_entityID} = $entityID if defined $entityID;
}

sub setSplitName {
    my ($self, $splitName) = @_;
    $self->{_splitName} = $splitName if defined $splitName;
}


###############################################################################
# Persistence
###############################################################################


sub load {
    my ($self, $splitID, $dbh) = @_;

    my $where   = qq[intSplitID = $splitID];
    my $orderBy = '';
    my $dref    = _processQuery($where, $orderBy, $dbh);

    my $paymentSplit = @{$dref}[0];

    return ($paymentSplit)
        ? $self->new(
            splitID   => $paymentSplit->{'intSplitID'},
            ruleID    => $paymentSplit->{'intRuleID'},
            typeID    => $paymentSplit->{'intEntityTypeID'},
            entityID  => $paymentSplit->{'intEntityID'},
            splitName => $paymentSplit->{'strSplitName'}
          )
        : '';
}


sub delete {
    my ($self, $splitID, $dbh) = @_;

    PaymentSplitItemObj->delete($splitID, $dbh);

    my $sql = qq[
        DELETE FROM tblPaymentSplit
        WHERE intSplitID=$splitID
    ];

    my $query = $dbh->prepare($sql);
    $query->execute;

}


sub save {
    my ($self, $dbh) = @_;

    my $splitID   = $self->getSplitID;
    my $ruleID    = $self->getRuleID;
    my $typeID    = $self->getTypeID;
    my $entityID  = $self->getEntityID;
    my $splitName = $self->getSplitName;


    my $sql = '';

    deQuote($dbh, \$splitName);

    if ($splitID) {
        $sql .= qq[
            UPDATE tblPaymentSplit
            SET intRuleID=$ruleID,
                intEntityTypeID=$typeID,
                intEntityID=$entityID,
                strSplitName=$splitName
            WHERE intSplitID=$splitID
        ];
    }
    else {
        $sql .= qq[
            INSERT INTO tblPaymentSplit (
                intRuleID, intEntityTypeID, intEntityID, strSplitName
            )
            VALUES (
                $ruleID, $typeID, $entityID, $splitName
            )
        ];
    }

    my $query = $dbh->prepare($sql);
    $query->execute;

    if (!$splitID) { 
        $splitID = $query->{'mysql_insertid'} 
    }

    $query->finish();

    return $splitID;
}


###############################################################################
# Privates
###############################################################################


sub _processQuery {
    my ($where, $orderBy, $dbh) = @_;

    my $sql = qq[
        SELECT *
        FROM tblPaymentSplit
        WHERE $where
        $orderBy
    ]; 
    
    my $query = $dbh->prepare($sql);
    my @paymentSplits = ();

    $query->execute;

    while (my $dref = $query->fetchrow_hashref()) {
        push @paymentSplits, $dref;
    }

    $query->finish();

    return \@paymentSplits;
}

1;
