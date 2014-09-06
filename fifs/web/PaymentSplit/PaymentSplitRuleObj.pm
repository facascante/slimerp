#
# $Header: svn://svn/SWM/trunk/web/PaymentSplitRuleObj.pm 8251 2013-04-08 09:00:53Z rlee $
#

package PaymentSplitRuleObj;

use strict;
use DeQuote;


sub new {
    my ($class, %args) = @_;

    my $self = {
        _ruleID    => $args{ruleID},
        _realmID   => $args{realmID},
        _ruleName  => $args{ruleName},
        _finInst   => $args{finInst},
        _userName  => $args{userName},
        _userNo    => $args{userNo},
        _fileDesc  => $args{fileDesc},
        _bsb       => $args{bsb},
        _accountNo => $args{accountNo},
        _currencyCode => $args{currencyCode},
        _remitter  => $args{remitter},
        _refPrefix => $args{refPrefix},
        _transCode => $args{transCode},
        _timeStamp => $args{timeStamp}
    };

    $self = bless ($self, $class);

    return $self;
}


###############################################################################
# Getters
###############################################################################


sub getRuleID {
    my ($self) = shift;
    return $self->{_ruleID};
}


sub getRealmID {
    my ($self) = shift;
    return $self->{_realmID};
}


sub getRuleName {
    my ($self) = shift;
    return $self->{_ruleName};
}


sub getFinInst {
    my ($self) = shift;
    return $self->{_finInst};
}


sub getUserName {
    my ($self) = shift;
    return $self->{_userName};
}


sub getUserNo {
    my ($self) = shift;
    return $self->{_userNo};
}


sub getFileDesc {
    my ($self) = shift;
    return $self->{_fileDesc};
}


sub getBSB {
    my ($self) = shift;
    return $self->{_bsb};
}


sub getAccountNo {
    my ($self) = shift;
    return $self->{_accountNo};
}

sub getCurrencyCode{
    my ($self) = shift;
    return $self->{_currencyCode};
}


sub getRemitter {
    my ($self) = shift;
    return $self->{_remitter};
}


sub getRefPrefix {
    my ($self) = shift;
    return $self->{_refPrefix};
}


sub getTransCode {
    my ($self) = shift;
    return $self->{_transCode};
}


sub getTimeStamp {
    my ($self) = shift;
    return $self->{_timeStamp};
}


sub getList {
    my ($self, $realmID, $dbh) = @_;
    my $where   = qq[intRealmID=$realmID];
    my $orderBy = qq[ORDER BY strRuleName];
    return _processQuery($where, $orderBy, $dbh);
}


###############################################################################
# Setters
###############################################################################


sub setRealmID {
    my ($self, $realmID) = @_;
    $self->{_realmID} = $realmID if defined $realmID;
}


sub setRuleName {
    my ($self, $ruleName) = @_;
    $self->{_ruleName} = $ruleName if defined $ruleName;
}


sub setFinInst {
    my ($self, $finInst) = @_;
    $self->{_finInst} = $finInst if defined $finInst;
}


sub setUserName {
    my ($self, $userName) = @_;
    $self->{_userName} = $userName if defined $userName;
}


sub setUserNo {
    my ($self, $userNo) = @_;
    $self->{_userNo} = $userNo if defined $userNo;
}


sub setFileDesc {
    my ($self, $fileDesc) = @_;
    $self->{_fileDesc} = $fileDesc if defined $fileDesc;
}


sub setBSB {
    my ($self, $bsb) = @_;
    $self->{_bsb} = $bsb if defined $bsb;
}


sub setAccountNo {
    my ($self, $accountNo) = @_;
    $self->{_accountNo} = $accountNo if defined $accountNo;
}

sub setCurrencyCode {
    my ($self, $currencyCode) = @_;
    $self->{_currencyCode} = $currencyCode if defined $currencyCode;
}


sub setRemitter {
    my ($self, $remitter) = @_;
    $self->{_remitter} = $remitter if defined $remitter;
}


sub setRefPrefix {
    my ($self, $refPrefix) = @_;
    $self->{_remitter} = $refPrefix if defined $refPrefix;
}


sub setTransCode {
    my ($self, $transCode) = @_;
    $self->{_remitter} = $transCode if defined $transCode;
}


sub setTimeStamp {
    my ($self, $timeStamp) = @_;
    $self->{_timeStamp} = $timeStamp if defined $timeStamp;
}


###############################################################################
# Persistence
###############################################################################


sub load {
    my ($self, $ruleID, $dbh) = @_;

    my $where   = qq[intRuleID = $ruleID];
    my $orderBy = '';
    my $dref    = _processQuery($where, $orderBy, $dbh);

    my $paymentSplitRule = @{$dref}[0];

    return ($paymentSplitRule)
        ? $self->new(
            ruleID    => $paymentSplitRule->{'intRuleID'},
            realmID   => $paymentSplitRule->{'intRealmID'},
            ruleName  => $paymentSplitRule->{'strRuleName'},
            finInst   => $paymentSplitRule->{'strFinInst'},
            userName  => $paymentSplitRule->{'strUserName'},
            userNo    => $paymentSplitRule->{'strUserNo'},
            fileDesc  => $paymentSplitRule->{'strFileDesc'},
            bsb       => $paymentSplitRule->{'strBSB'},
            accountNo => $paymentSplitRule->{'strAccountNo'},
            remitter  => $paymentSplitRule->{'strRemitter'},
            refPrefix => $paymentSplitRule->{'strRefPrefix'},
            transCode => $paymentSplitRule->{'strTransCode'},
            timeStamp => $paymentSplitRule->{'tTimeStamp'}
          )
        : '';
}


sub delete {
    my ($self, $ruleID, $dbh) = @_;

    my $sql = qq[
        DELETE FROM tblPaymentSplitRule
        WHERE intRuleID=$ruleID
    ];

    my $query = $dbh->prepare($sql);
    $query->execute;

}


sub save {
    my ($self, $dbh) = @_;

    my $ruleID    = $self->getRuleID;
    my $realmID   = $self->getRealmID;
    my $ruleName  = $self->getRuleName;
    my $finInst   = $self->getFinInst;
    my $userName  = $self->getUserName;
    my $userNo    = $self->getUserNo;
    my $fileDesc  = $self->getFileDesc;
    my $bsb       = $self->getBSB;
    my $accountNo = $self->getAccountNo;
    my $remitter  = $self->getRemitter;
    my $refPrefix = $self->getRefPrefix;
    my $transCode = $self->getTransCode;
    my $timeStamp = $self->getTimeStamp;

    my $sql = '';

    deQuote($dbh, \$ruleName);

    if ($ruleID) {
        $sql .= qq[
            UPDATE tblPaymentSplitRule
            SET intRealmID=$realmID,
                strRuleName=$ruleName,
                strFinInst=$finInst,
                strUserName=$userName,
                strUserNo=$userNo,
                strFileDesc=$fileDesc,
                strBSB=$bsb,
                strAccountNo=$accountNo,
                strRemitter=$remitter,
                strRefPrefix=$refPrefix,
                strTransCode=$transCode,
                tTimeStamp=$timeStamp
            WHERE intRuleID=$ruleID
        ];
    }
    else {
        $sql .= qq[
            INSERT INTO tblPaymentSplitRule (
                intRealmID, strRuleName, strFinInst, strUserName, strUserNo, strFileDesc, strBSB, strAccountNo,
                strRemitter, strRefPrefix, strTransCode, tTimeStamp
            )
            VALUES (
                $realmID, $ruleName, $finInst, $userName, $userNo, $fileDesc, $bsb, $accountNo,
                $remitter, $refPrefix, $transCode, $timeStamp
            )
        ];
    }

    my $query = $dbh->prepare($sql);
    $query->execute;

    if (!$ruleID) { 
        $ruleID = $query->{'mysql_insertid'} 
    }

    $query->finish();

    return $ruleID;
}


###############################################################################
# Privates
###############################################################################


sub _processQuery {
    my ($where, $orderBy, $dbh) = @_;

    my $sql = qq[
        SELECT *
        FROM tblPaymentSplitRule
        WHERE $where
        $orderBy
    ]; 
    
    my $query = $dbh->prepare($sql);
    my @paymentSplitRules = ();

    $query->execute;

    while (my $dref = $query->fetchrow_hashref()) {
        push @paymentSplitRules, $dref;
    }

    $query->finish();

    return \@paymentSplitRules;
}

1;
