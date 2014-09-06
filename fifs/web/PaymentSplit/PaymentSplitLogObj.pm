#
# $Header: svn://svn/SWM/trunk/web/PaymentSplitLogObj.pm 8251 2013-04-08 09:00:53Z rlee $
#

package PaymentSplitLogObj;

use strict;
use DeQuote;


sub new {
    my ($class, %args) = @_;

    my $self = {
        _logID            => $args{logID},
        _exportBankFileID => $args{exportBankFileID},
        _entityTypeID     => $args{entityTypeID},
        _entityID         => $args{entityID},
        _assocID          => $args{assocID},
        _clubID           => $args{clubID},
        _bankCode         => $args{bankCode},
        _accountNo        => $args{accountNo},
        _accountName      => $args{accountName},
        _mpEmail          => $args{mpEmail},
        _amount           => $args{amount},
        _feesType         => $args{feesType}
    };

    $self = bless ($self, $class);

    return $self;
}


###############################################################################
# Getters
###############################################################################


sub getLogID {
    my ($self) = shift;
    return $self->{_logID};
}


sub getExportBankFileID {
    my ($self) = shift;
    return $self->{_exportBankFileID};
}


sub getEntityTypeID {
    my ($self) = shift;
    return $self->{_entityTypeID};
}


sub getEntityID {
    my ($self) = shift;
    return $self->{_entityID};
}


sub getAssocID {
    my ($self) = shift;
    return $self->{_assocID};
}


sub getClubID {
    my ($self) = shift;
    return $self->{_clubID};
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


sub getMPEmail {
    my ($self) = shift;
    return $self->{_mpEmail};
}


sub getAmount {
    my ($self) = shift;
    return $self->{_amount};
}


sub getFeesType {
    my ($self) = shift;
    return $self->{_feesType};
}


sub getList {
    my ($self, $exportBankFileID, $dbh) = @_;
    my $where   = qq[intExportBankFileID = $exportBankFileID];
    my $orderBy = qq[ORDER BY intLogID];
    return _processQuery($where, $orderBy, $dbh);
}


###############################################################################
# Setters
###############################################################################


sub setExportBankFileID {
    my ($self, $exportBankFileID) = @_;
    $self->{_exportBankFileID} = $exportBankFileID if defined $exportBankFileID;
}


sub setEntityTypeID {
    my ($self, $entityTypeID) = @_;
    $self->{_entityTypeID} = $entityTypeID if defined $entityTypeID;
}


sub setEntityID {
    my ($self, $entityID) = @_;
    $self->{_entityID} = $entityID if defined $entityID;
}


sub setAssocID {
    my ($self, $assocID) = @_;
    $self->{_assocID} = $assocID if defined $assocID;
}


sub setClubID {
    my ($self, $clubID) = @_;
    $self->{_clubID} = $clubID if defined $clubID;
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


sub setMPEmail {
    my ($self, $mpEmail) = @_;
    $self->{_mpEmail} = $mpEmail if defined $mpEmail;
}


sub setAmount {
    my ($self, $amount) = @_;
    $self->{_amount} = $amount if defined $amount;
}


sub setFeesType {
    my ($self, $feesType) = @_;
    $self->{_feesType} = $feesType if defined $feesType;
}


###############################################################################
# Persistence
###############################################################################


sub load {
    my ($self, $logID, $dbh) = @_;
    
    my $where   = qq[intLogID = $logID];
    my $orderBy = '';
    my $dref    = _processQuery($where, $orderBy, $dbh);

    my $paymentSplitLog = @{$dref}[0];

    return ($paymentSplitLog)
        ? $self->new(
            logID            => $paymentSplitLog->{'intLogID'},
            exportBankFileID => $paymentSplitLog->{'intExportBankFileID'},
            entityTypeID     => $paymentSplitLog->{'intEntityTypeID'},
            entityID         => $paymentSplitLog->{'intEntityID'},
            assocID          => $paymentSplitLog->{'intAssocID'},
            clubID           => $paymentSplitLog->{'intClubID'},
            bankCode         => $paymentSplitLog->{'strBankCode'},
            accountNo        => $paymentSplitLog->{'strAccountNo'},
            accountName      => $paymentSplitLog->{'strAccountName'},
            mpEmail          => $paymentSplitLog->{'strMPEmail'},
            amount           => $paymentSplitLog->{'curAmount'},
            feesType         => $paymentSplitLog->{'intFeesType'}
          )
        : '';
}


sub delete {
    my ($self, $logID, $dbh) = @_;

    my $sql = qq[
        DELETE FROM tblPaymentSplitLog
        WHERE intLogID=$logID
    ];

    my $query = $dbh->prepare($sql);
    $query->execute;

}


sub save {
    my ($self, $dbh) = @_;

    my $logID            = $self->getLogID;
    my $exportBankFileID = $self->getExportBankFileID;
    my $entityTypeID     = $self->getEntityTypeID;
    my $entityID         = $self->getEntityID;
    my $assocID          = $self->getAssocID;
    my $clubID           = $self->getClubID;
    my $bankCode         = $self->getBankCode;
    my $accountNo        = $self->getAccountNo;
    my $accountName      = $self->getAccountName;
    my $mpEmail          = $self->getMPEmail;
    my $amount           = $self->getAmount;
    my $feesType         = $self->getFeesType;

    my $sql = '';

    deQuote($dbh, \$bankCode);
    deQuote($dbh, \$accountNo);
    deQuote($dbh, \$accountName);
    deQuote($dbh, \$mpEmail);

    if ($logID) {
        $sql = qq[
            UPDATE tblPaymentSplitLog
            SET intExportBankFileID=$exportBankFileID,
                intEntityTypeID=$entityTypeID,
                intEntityID=$entityID,
                intAssocID=$assocID,
                intClubID=$clubID,
                strBankCode=$bankCode,
                strAccountNo=$accountNo,
                strAccountName=$accountName,
                strMPEmail=$mpEmail,
                curAmount=$amount,
                intFeesType=$feesType
            WHERE intLogID=$logID
        ];
    }
    else {
        $sql = qq[
            INSERT INTO tblPaymentSplitLog (
                intExportBankFileID, intEntityTypeID, intEntityID, intAssocID, intClubID, strBankCode, 
                strAccountNo, strAccountName, strMPEmail, curAmount, intFeesType
            )
            VALUES (
                $exportBankFileID, $entityTypeID, $entityID, $assocID, $clubID, $bankCode, 
                $accountNo, $accountName, $mpEmail, $amount, $feesType
            )
        ];
    }

    my $query = $dbh->prepare($sql);
    $query->execute;

    if (!$logID) { 
        $logID = $query->{'mysql_insertid'} 
    }

    $query->finish();

    return $logID;
}


###############################################################################
# Privates
###############################################################################


sub _processQuery {
    my ($where, $orderBy, $dbh) = @_;

    my $sql = qq[
        SELECT *
        FROM tblPaymentSplitLog
        WHERE $where
        $orderBy
    ]; 
    
    my $query = $dbh->prepare($sql);
    my @paymentSplitLogs = ();

    $query->execute;

    while (my $dref = $query->fetchrow_hashref()) {
        push @paymentSplitLogs, $dref;
    }
    
    $query->finish();

    return \@paymentSplitLogs;
}


1;
