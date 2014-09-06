#
# $Header: svn://svn/SWM/trunk/web/BankAccountObj.pm 8251 2013-04-08 09:00:53Z rlee $
#

package BankAccountObj;

use strict;
use DeQuote;


sub new {
    my ($class, %args) = @_;

    my $self = {
        _typeID      => $args{typeID},
        _entityID    => $args{entityID},
        _bankCode    => $args{bankCode},
        _accountNo   => $args{accountNo},
        _accountName => $args{accountName},
        _mpEmail     => $args{mpEmail},
    };

    $self = bless ($self, $class);

    return $self;
}


###############################################################################
# Getters
###############################################################################


sub getTypeID {
    my ($self) = shift;
    return $self->{_typeID};
}


sub getEntityID {
    my ($self) = shift;
    return $self->{_entityID};
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



###############################################################################
# Setters
###############################################################################


sub setTypeID {
    my ($self, $typeID) = @_;
    $self->{_typeID} = $typeID if defined $typeID;
}


sub setEntityID {
    my ($self, $entityID) = @_;
    $self->{_entityID} = $entityID if defined $entityID;
}


sub setBankCode {
    my ($self, $bankcode) = @_;
    $self->{_bankcode} = $bankcode if defined $bankcode;
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


###############################################################################
# Persistence
###############################################################################


sub load {
    my ($self, $typeID, $entityID, $dbh) = @_;

    my $sql = qq[
        SELECT *
        FROM tblBankAccount
        WHERE intEntityTypeID = $typeID AND intEntityID=$entityID
    ]; 
    my $query = $dbh->prepare($sql);

    $query->execute;

    my ($intEntityTypeID, $intEntityID, $strBankCode, $strAccountNo, $strAccountName, $strMPEmail) = $query->fetchrow_array();

    $intEntityTypeID ||= 0;
    $intEntityID     ||= 0;
    $strBankCode     ||= '';
    $strAccountNo    ||= '';
    $strAccountName  ||= '';
    $strMPEmail      ||= '';

    $query->finish();

    return ($intEntityID)
        ? $self->new(
            typeID      => $intEntityTypeID,
            entityID    => $intEntityID,
            bankCode    => $strBankCode,
            accountNo   => $strAccountNo,
            accountName => $strAccountName,
            mpEmail     => $strMPEmail
          )
        : '';
}


sub delete {
    my ($self, $typeID, $entityID, $dbh) = @_;

    my $sql = qq[
        DELETE FROM tblBankAccount
        WHERE intEntityTypeID=$typeID AND intEntityID=$entityID
    ];

    my $query = $dbh->prepare($sql);
    $query->execute;

}


sub save {
    my ($self, $dbh) = @_;

    my $typeID      = $self->getTypeID;
    my $entityID    = $self->getEntityID;
    my $bankCode    = $self->getBankCode;
    my $accountNo   = $self->getAccountNo;
    my $accountName = $self->getAccountName;
    my $mpEmail     = $self->getMPEmail;

    my $sql = '';

    deQuote($dbh, \$bankCode);
    deQuote($dbh, \$accountNo);
    deQuote($dbh, \$accountName);
    deQuote($dbh, \$mpEmail);

    $sql .= qq[
        INSERT INTO tblBankAccount (
            intEntityTypeID, intEntityID, strBankCode, strAccountNo, strAccountName, strMPEmail
        )
        VALUES (
            $typeID, $entityID, $bankCode, $accountNo, $accountName, $mpEmail
        )
        ON DUPLICATE KEY UPDATE
            strBankCode=$bankCode,
            strAccountNo=$accountNo,
            strAccountName=$accountName,
            strMPEmail=$mpEmail
    ];

    my $query = $dbh->prepare($sql);
    $query->execute;

    $query->finish();

    return 1;
}


1;
