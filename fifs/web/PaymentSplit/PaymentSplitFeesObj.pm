#
# $Header: svn://svn/SWM/trunk/web/PaymentSplitFeesObj.pm 8251 2013-04-08 09:00:53Z rlee $
#

package PaymentSplitFeesObj;

use strict;
use DeQuote;


sub new {
    my ($class, %args) = @_;

    my $self = {
        _feesID           => $args{feesID},
        _realmID          => $args{realmID},
        _subTypeID        => $args{subTypeID},
        _feesType         => $args{feesType},
        _bankCode         => $args{bankCode},
        _accountNo        => $args{accountNo},
        _accountName      => $args{accountName},
        _amount           => $args{amount},
        _factor           => $args{factor},
        _mpEmail          => $args{mpEmail},
        _curMaxFeePoint   => $args{curMaxFeePoint},
        _curMaxFee   => $args{curMaxFee},
        _feeAllocationType 	  => $args{feeAllocationType}
    };

    $self = bless ($self, $class);

    return $self;
}


###############################################################################
# Getters
###############################################################################


sub getFeesID {
    my ($self) = shift;
    return $self->{_feesID};
}


sub getRealmID {
    my ($self) = shift;
    return $self->{_realmID};
}


sub getSubTypeID {
    my ($self) = shift;
    return $self->{_subTypeID};
}


sub getFeesType {
    my ($self) = shift;
    return $self->{_feesType};
}


sub getBankCode {
    my ($self) = shift;
    return $self->{_bankCode};
}


sub getAccountNo {
    my ($self) = shift;
    return $self->{_accountNo};
}


sub getAccountName {
    my ($self) = shift;
    return $self->{_accountName};
}


sub getAmount {
    my ($self) = shift;
    return $self->{_amount};
}


sub getFactor {
    my ($self) = shift;
    return $self->{_factor};
}


sub getcurMaxFeePoint {
    my ($self) = shift;
    return $self->{_curMaxFeePoint};
}

sub getcurMaxFee {
    my ($self) = shift;
    return $self->{_curMaxFee};
}
sub getMPEmail {
    my ($self) = shift;
    return $self->{_mpEmail};
}

sub getFeeType {
    my ($self) = shift;
    return $self->{_feeAllocationType};
}


sub getList {
    my ($self, $realmID, $subTypeID, $intFeesType, $dbh) = @_;
	my $feesType = '';
	$feesType = qq[(intFeesType = $intFeesType) AND ] if $intFeesType;

    my $where   = qq[$feesType (intRealmID=$realmID) AND (intSubTypeID=$subTypeID)];
	
    my $orderBy = qq[ORDER BY intFeesID];
    
    my $paymentSplitFees = _processQuery($where, $orderBy, $dbh);

    if (!@$paymentSplitFees and $subTypeID) {
        $where   = qq[$feesType (intRealmID=$realmID) AND (intSubTypeID=0)];
        $paymentSplitFees = _processQuery($where, $orderBy, $dbh);
    }

    return $paymentSplitFees;
}


sub getTotalFees {
    my ($self, $realmID, $subTypeID, $dbh) = @_;
    my $paymentSplitFees = getList($self, $realmID, $subTypeID, 1, $dbh);

    my $totAmount  = 0;
    my $totFactor = 0;

    for my $dref(@{$paymentSplitFees}) {
        $totAmount  += $dref->{'curAmount'};
        $totFactor += $dref->{'dblFactor'};
    }

    return ($totAmount, $totFactor);
}


###############################################################################
# Setters
###############################################################################


sub setRealmID {
    my ($self, $realmID) = @_;
    $self->{_realmID} = $realmID if defined $realmID;
}


sub setSubTypeID {
    my ($self, $subTypeID) = @_;
    $self->{_subTypeID} = $subTypeID if defined $subTypeID;
}


sub setFeesType {
    my ($self, $feesType) = @_;
    $self->{_feesType} = $feesType if defined $feesType;
}

sub setBankCode {
    my ($self, $bankCode) = @_;
    $self->{_bankCode} = $bankCode if defined $bankCode;
}


sub setAccountNo {
    my ($self, $accountNo) = @_;
    $self->{_accountNo} = $accountNo if defined $accountNo;
}


sub setAccountName {
    my ($self, $accountName) = @_;
    $self->{_accountName} = $accountName if defined $accountName;
}


sub setAmount {
    my ($self, $amount) = @_;
    $self->{_amount} = $amount if defined $amount;
}


sub setFactor {
    my ($self, $factor) = @_;
    $self->{_factor} = $factor if defined $factor;
}


sub setMPEmail {
    my ($self, $mpEmail) = @_;
    $self->{_mpEmail} = $mpEmail if defined $mpEmail;
}
sub setFeeType {
    my ($self, $feeAllocationType) = @_;
    $self->{_feetype} = $feeAllocationType if defined $feeAllocationType;
}


###############################################################################
# Persistence
###############################################################################


sub load {
    my ($self, $feesID, $dbh) = @_;
    
    my $where   = qq[intFeesID = $feesID];
    my $orderBy = '';
    my $dref    = _processQuery($where, $orderBy, $dbh);

    my $paymentSplitFees = @{$dref}[0];

    return ($paymentSplitFees)
        ? $self->new(
            feesID      => $paymentSplitFees->{'intFeesID'},
            realmID     => $paymentSplitFees->{'intRealmID'},
            subTypeID   => $paymentSplitFees->{'intSubTypeID'},
            feesType    => $paymentSplitFees->{'intFeesType'},
            bankCode    => $paymentSplitFees->{'strBankCode'},
            accountNo   => $paymentSplitFees->{'strAccountNo'},
            accountName => $paymentSplitFees->{'strAccountName'},
            amount      => $paymentSplitFees->{'curAmount'},
            factor      => $paymentSplitFees->{'dblFactor'},
            mpEmail     => $paymentSplitFees->{'strMPEmail'},
            curMaxFeePoint => $paymentSplitFees->{'curMaxFeePoint'},
            curMaxFee => $paymentSplitFees->{'curMaxFee'},
            feeAllocationType     => $paymentSplitFees->{'intFeeAllocationType'}
          )
        : '';
}


sub delete {
    my ($self, $feesID, $dbh) = @_;

    my $sql = qq[
        DELETE FROM tblPaymentSplitFees
        WHERE intFeesID=$feesID
    ];

    my $query = $dbh->prepare($sql);
    $query->execute;

}


sub save {
    my ($self, $dbh) = @_;

    my $feesID      = $self->getFeesID;
    my $realmID     = $self->getRealmID;
    my $subTypeID   = $self->getSubTypeID;
    my $feesType    = $self->getFeesType;
    my $bankCode    = $self->getBankCode;
    my $accountNo   = $self->getAccountNo;
    my $accountName = $self->getAccountName;
    my $amount      = $self->getAmount;
    my $factor      = $self->getFactor;
    my $mpEmail     = $self->getMPEmail;
    my $feeAllocationType = $self->getFeeType;

    my $sql = '';

    deQuote($dbh, \$bankCode);
    deQuote($dbh, \$accountNo);
    deQuote($dbh, \$accountName);
    deQuote($dbh, \$mpEmail);

    if ($feesID) {
        $sql = qq[
            UPDATE tblPaymentSplitFees
            SET intRealmID=$realmID,
                intSubTypeID=$subTypeID,
                intFeesType=$feesType,
                strBankCode=$bankCode,
                strAccountNo=$accountNo,
                strAccountName=$accountName,
                curAmount=$amount,
                dblFactor=$factor,
                strMPEmail=$mpEmail
            WHERE intFeesID=$feesID
        ];
    }
    else {
        $sql = qq[
            INSERT INTO tblPaymentSplitFees (
                intRealmID, intSubTypeID, intFeesType, strBankCode, strAccountNo,
                strAccountName, curAmount, dblFactor, strMPEmail
            )
            VALUES (
                $realmID, $subTypeID, $feesType, $bankCode, $accountNo,
                $accountName, $amount, $factor, $mpEmail
            )
        ];
    }

    my $query = $dbh->prepare($sql);
    $query->execute;

    if (!$feesID) { 
        $feesID = $query->{'mysql_insertid'} 
    }

    $query->finish();

    return $feesID;
}


###############################################################################
# Privates
###############################################################################


sub _processQuery {
    my ($where, $orderBy, $dbh) = @_;

    my $sql = qq[
        SELECT *
        FROM tblPaymentSplitFees
        WHERE $where
        $orderBy
    ]; 

    my $query = $dbh->prepare($sql);
    my @paymentSplitFees = ();

    $query->execute;

    while (my $dref = $query->fetchrow_hashref()) {
        push @paymentSplitFees, $dref;
    }
    
    $query->finish();

    return \@paymentSplitFees;
}


1;
