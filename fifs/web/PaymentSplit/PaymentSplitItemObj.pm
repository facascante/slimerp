#
# $Header: svn://svn/SWM/trunk/web/PaymentSplitItemObj.pm 8251 2013-04-08 09:00:53Z rlee $
#

package PaymentSplitItemObj;

use strict;
use DeQuote;


sub new {
    my ($class, %args) = @_;

    my $self = {
        _itemID           => $args{itemID},
        _splitID          => $args{splitID},
        _levelID          => $args{levelID},
        _otherBankCode    => $args{otherBankCode},
        _otherAccountNo   => $args{otherAccountNo},
        _otherAccountName => $args{otherAccountName},
        _amount           => $args{amount},
        _factor           => $args{factor},
        _remainder        => $args{remainder},
        _mpEmail          => $args{mpEmail}
    };

    $self = bless ($self, $class);

    return $self;
}


###############################################################################
# Getters
###############################################################################


sub getItemID {
    my ($self) = shift;
    return $self->{_itemID};
}


sub getSplitID {
    my ($self) = shift;
    return $self->{_splitID};
}


sub getLevelID {
    my ($self) = shift;
    return $self->{_levelID};
}


sub getOtherBankCode {
    my ($self) = shift;
    return $self->{_otherBankCode};
}


sub getOtherAccountNo {
    my ($self) = shift;
    return $self->{_otherAccountNo};
}


sub getOtherAccountName {
    my ($self) = shift;
    return $self->{_otherAccountName};
}


sub getAmount {
    my ($self) = shift;
    return $self->{_amount};
}


sub getFactor {
    my ($self) = shift;
    return $self->{_factor};
}


sub getRemainder {
    my ($self) = shift;
    return $self->{_remainder};
}


sub getMPEmail {
    my ($self) = shift;
    return $self->{_mpEmail};
}


sub getList {
    my ($self, $splitID, $dbh) = @_;
    my $where   = qq[intSplitID = $splitID];
    my $orderBy = qq[ORDER BY intItemID];
    return _processQuery($where, $orderBy, $dbh);
}


###############################################################################
# Setters
###############################################################################


sub setSplitID {
    my ($self, $splitID) = @_;
    $self->{_splitID} = $splitID if defined $splitID;
}


sub setLevelID {
    my ($self, $levelID) = @_;
    $self->{_levelID} = $levelID if defined $levelID;
}

sub setOtherBankCode {
    my ($self, $otherBankCode) = @_;
    $self->{_otherBankCode} = $otherBankCode if defined $otherBankCode;
}


sub setOtherAccountNo {
    my ($self, $otherAccountNo) = @_;
    $self->{_otherAccountNo} = $otherAccountNo if defined $otherAccountNo;
}


sub setOtherAccountName {
    my ($self, $otherAccountName) = @_;
    $self->{_otherAccountName} = $otherAccountName if defined $otherAccountName;
}


sub setAmount {
    my ($self, $amount) = @_;
    $self->{_amount} = $amount if defined $amount;
}


sub setFactor {
    my ($self, $factor) = @_;
    $self->{_factor} = $factor if defined $factor;
}


sub setRemainder {
    my ($self, $remainder) = @_;
    $self->{_remainder} = $remainder if defined $remainder;
}


sub setMPEmail {
    my ($self, $mpEmail) = @_;
    $self->{_mpEmail} = $mpEmail if defined $mpEmail;
}


###############################################################################
# Persistence
###############################################################################


sub load {
    my ($self, $itemID, $dbh) = @_;
    
    my $where   = qq[intItemID = $itemID];
    my $orderBy = '';
    my $dref    = _processQuery($where, $orderBy, $dbh);

    my $paymentSplitItem = @{$dref}[0];

    return ($paymentSplitItem)
        ? $self->new(
            itemID           => $paymentSplitItem->{'intItemID'},
            splitID          => $paymentSplitItem->{'intSplitID'},
            levelID          => $paymentSplitItem->{'intLevelID'},
            otherBankCode    => $paymentSplitItem->{'strOtherBankCode'},
            otherAccountNo   => $paymentSplitItem->{'strOtherAccountNo'},
            otherAccountName => $paymentSplitItem->{'strOtherAccountName'},
            amount           => $paymentSplitItem->{'curAmount'},
            factor           => $paymentSplitItem->{'dblFactor'},
            remainder        => $paymentSplitItem->{'intRemainder'},
            mpEmail          => $paymentSplitItem->{'strMPEmail'}
          )
        : '';
}


sub delete {
    my ($self, $splitID, $dbh) = @_;

    my $sql = qq[
        DELETE FROM tblPaymentSplitItem
        WHERE intSplitID=$splitID
    ];

    my $query = $dbh->prepare($sql);
    $query->execute;

}


sub save {
    my ($self, $dbh) = @_;

    my $itemID            = $self->getItemID;
    my $splitID           = $self->getSplitID;
    my $levelID           = $self->getLevelID;
    my $otherBankCode     = $self->getOtherBankCode;
    my $otherAccountNo    = $self->getOtherAccountNo;
    my $otherAccountName  = $self->getOtherAccountName;
    my $amount            = $self->getAmount;
    my $factor            = $self->getFactor;
    my $remainder         = $self->getRemainder;
    my $mpEmail           = $self->getMPEmail;

    my $sql = '';

    #deQuote($dbh, \$otherBankCode);
    #deQuote($dbh, \$otherAccountNo);
    #deQuote($dbh, \$otherAccountName);
    deQuote($dbh, \$mpEmail);

    if ($itemID) {
        $sql = qq[
            UPDATE tblPaymentSplitItem
            SET intSplitID=$splitID,
                intLevelID=$levelID,
                strOtherBankCode=?,
                strOtherAccountNo=?,
                strOtherAccountName=?,
                curAmount=$amount,
                dblFactor=$factor,
                intRemainder=$remainder,
                strMPEmail=$mpEmail
            WHERE intItemID=$itemID
        ];
    }
    else {
        $sql = qq[
            INSERT INTO tblPaymentSplitItem (
                intSplitID, intLevelID, strOtherBankCode, strOtherAccountNo,
                strOtherAccountName, curAmount, dblFactor, intRemainder, strMPEmail
            )
            VALUES (
                $splitID, $levelID, ?, ?, ?, $amount, $factor, $remainder, $mpEmail
            )
        ];
    }

    my $query = $dbh->prepare($sql);
    $query->execute($otherBankCode, $otherAccountNo, $otherAccountName);

    if (!$itemID) { 
        $itemID = $query->{'mysql_insertid'} 
    }

    $query->finish();

    return $itemID;
}


###############################################################################
# Privates
###############################################################################


sub _processQuery {
    my ($where, $orderBy, $dbh) = @_;

    my $sql = qq[
        SELECT *
        FROM tblPaymentSplitItem
        WHERE $where
        $orderBy
    ]; 
    my $query = $dbh->prepare($sql);
    my @paymentSplitItems = ();

    $query->execute;

    while (my $dref = $query->fetchrow_hashref()) {
        push @paymentSplitItems, $dref;
    }
    
    $query->finish();

    return \@paymentSplitItems;
}


1;
