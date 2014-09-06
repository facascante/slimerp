#
# $Header: svn://svn/SWM/trunk/web/ContactsObj.pm 8305 2013-04-16 23:47:31Z fkhezri $
#

package ContactsObj;

use lib;
use BaseObject2;
our @ISA = qw(BaseObject2);

use strict;

use ContactsSQL;

sub _getSQL {
    my $sql = getContactsSQL();
    return $sql;
}

sub getList {
    my $self = shift;
    my (%params) = @_;

    my $dbh      = $params{'dbh'};
    my $assoc_id = $params{'associd'} || 0;
    return undef if !$dbh;
    return undef if !$assoc_id; 

    my $club_id          = $params{'clubid'}           || 0;
    my $getregistrations = $params{'getregistrations'} || 0;
    my $getpayments      = $params{'getpayments'}      || 0;
    my $getprimary       = $params{'getprimary'}       || 0;
    my $getClearances    = $params{'getclearances'}    || 0;

    my $sql = getContactsSQL(
        associd          => $assoc_id, 
        clubid           => $club_id, 
        getregistrations => $getregistrations, 
        getpayments      => $getpayments,
        getprimary       => $getprimary,
	getclearances       => $getClearances
    );

    my $q = $dbh->prepare($sql);

    my @bind_vars = ();
    push @bind_vars, $assoc_id;
    push @bind_vars, $club_id; #clubid needed even if 0.
    push @bind_vars, $getregistrations if $getregistrations;
    push @bind_vars, $getpayments      if $getpayments;
    push @bind_vars, $getprimary       if $getprimary;
    push @bind_vars, $getClearances    if $getClearances;
   
    my $count = 0;
    foreach (@bind_vars) {
        $count++;
        $q->bind_param($count, $_);
    }
    $q->execute();

    my @contacts = ();

    while (my $dref = $q->fetchrow_hashref()) {
        push @contacts, $dref;
    }
    
    $q->finish();

    return \@contacts; 
}

1;
