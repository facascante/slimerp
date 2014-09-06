#
# $Header: svn://svn/SWM/trunk/web/PaymentSplitMyobExportObj.pm 8251 2013-04-08 09:00:53Z rlee $
#

package PaymentSplitMyobExportObj;

use strict;


sub new {
    my ($class, %args) = @_;

    my $self = {
        _myobExportID => $args{myobExportID},
        _paymentType  => $args{paymentType},
        _includeTo    => $args{includeTo},
        _totalInvs    => $args{totalInvs},
        _totalAmount  => $args{totalAmount},
        _run          => $args{run},
        _currencyRun  => $args{currencyRun},
        _runName => $args{runName}
    };

    $self = bless ($self, $class);

    return $self;
}


###############################################################################
# Getters
###############################################################################


sub getMyobExportID {
    my ($self) = shift;
    return $self->{_myobExportID};
}

sub getRunName  {
    my ($self) = shift;
    return $self->{_runName};
}

sub getCurrencyRun {
    my ($self) = shift;
    return $self->{_currencyRun};
}

sub getPaymentType {
    my ($self) = shift;
    return $self->{_paymentType};
}


sub getIncludeTo {
    my ($self) = shift;
    return $self->{_includeTo};
}


sub getTotalInvs {
    my ($self) = shift;
    return $self->{_totalInvs};
}


sub getTotalAmount {
    my ($self) = shift;
    return $self->{_totalAmount};
}


sub getRun {
    my ($self) = shift;
    return $self->{_run};
}


sub getList {
    my ($self, $dbh) = @_;
    my $where   = qq[1=1];
    my $orderBy = qq[ORDER BY intMyobExportID];
    return _processQuery($where, $orderBy, $dbh);
}


###############################################################################
# Setters
###############################################################################


sub setCurrencyRun  {
    my ($self, $currencyRun) = @_;
    $self->{_currencyRun} = $currencyRun if defined $currencyRun;
}

sub setRunName  {
    my ($self, $runName) = @_;
    $self->{_runName} = $runName if defined $runName;
}

sub setPaymentType {
    my ($self, $paymentType) = @_;
    $self->{_paymentType} = $paymentType if defined $paymentType;
}

sub setIncludeTo {
    my ($self, $includeTo) = @_;
    $self->{_includeTo} = $includeTo if defined $includeTo;
}


sub setTotalInvs {
    my ($self, $totalInvs) = @_;
    $self->{_totalInvs} = $totalInvs if defined $totalInvs;
}


sub setTotalAmount {
    my ($self, $totalAmount) = @_;
    $self->{_totalAmount} = $totalAmount if defined $totalAmount;
}


sub setRun {
    my ($self, $run) = @_;
    $self->{_run} = $run if defined $run;
}


###############################################################################
# Persistence
###############################################################################


sub load {
    my ($self, $myobExportID, $dbh) = @_;
    
    my $where   = qq[intMyobExportID = $myobExportID];
    my $orderBy = '';
    my $dref    = _processQuery($where, $orderBy, $dbh);

    my $paymentSplitMyobExport = @{$dref}[0];

    return ($paymentSplitMyobExport)
        ? $self->new(
            myobExportID => $paymentSplitMyobExport->{'intMyobExportID'},
            paymentType  => $paymentSplitMyobExport->{'intPaymentType'},
            includeTo    => $paymentSplitMyobExport->{'dtIncludeTo'},
            totalInvs    => $paymentSplitMyobExport->{'intTotalInvs'},
            totalAmount  => $paymentSplitMyobExport->{'curTotalAmount'},
            run          => $paymentSplitMyobExport->{'dtRun'},
            currencyRun  => $paymentSplitMyobExport->{'strCurrencyRun'},
            runName      => $paymentSplitMyobExport->{'strRunName'}
          )
        : '';
}


sub delete {
    my ($self, $myobExportID, $dbh) = @_;

    my $sql = qq[
        DELETE FROM tblPaymentSplitMyobExport
        WHERE intMyobExportID=$myobExportID
    ];

    my $query = $dbh->prepare($sql);
    $query->execute;

}


sub save {
    my ($self, $dbh) = @_;

    my $myobExportID = $self->getMyobExportID;
    my $paymentType  = $self->getPaymentType;
    my $includeTo    = $self->getIncludeTo;
    my $totalInvs    = $self->getTotalInvs;
    my $totalAmount  = $self->getTotalAmount;
    my $run          = $self->getRun;
    my $currencyRun  = $self->getCurrencyRun;
    my $runName      = $self->getRunName;


    my $sql = '';

    if ($myobExportID) {
        $sql = qq[
            UPDATE tblPaymentSplitMyobExport
            SET intPaymentType=$paymentType,
                dtIncludeTo=$includeTo,
                intTotalInvs=$totalInvs,
                curTotalAmount=$totalAmount,
                dtRun=$run,
                strCurrencyRun = "$currencyRun",
                strRunName="$runName"
            WHERE intMyobExportID=$myobExportID
        ];
    }
    else {
        $sql = qq[
            INSERT INTO tblPaymentSplitMyobExport (
                intPaymentType, dtIncludeTo, intTotalInvs, curTotalAmount, dtRun, strCurrencyRun, strRunName
            )
            VALUES (
                $paymentType, $includeTo, $totalInvs, $totalAmount, NOW(), "$currencyRun", "$runName"
            )
        ];
    }

    my $query = $dbh->prepare($sql);
    $query->execute;

    if (!$myobExportID) { 
        $myobExportID = $query->{'mysql_insertid'} 
    }

    $query->finish();

    return $myobExportID;
}


###############################################################################
# Privates
###############################################################################


sub _processQuery {
    my ($where, $orderBy, $dbh) = @_;

    my $sql = qq[
        SELECT *
        FROM tblPaymentSplitMyobExport
        WHERE $where
        $orderBy
    ]; 

    my $query = $dbh->prepare($sql);
    my @paymentSplitMyobExport = ();

    $query->execute;

    while (my $dref = $query->fetchrow_hashref()) {
        push @paymentSplitMyobExport, $dref;
    }
    
    $query->finish();

    return \@paymentSplitMyobExport;
}


1;
