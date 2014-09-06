#
# $Header: svn://svn/SWM/trunk/web/ClubCharacteristics.pm 8251 2013-04-08 09:00:53Z rlee $
#

package ClubCharacteristics;

require Exporter;
@ISA =  qw(Exporter);
@EXPORT = qw(getClubCharacteristicsBlock getCurrentCharacteristics updateCharacteristics getAvailableCharacteristics);
@EXPORT_OK = qw(getClubCharacteristicsBlock getCurrentCharacteristics updateCharacteristics getAvailableCharacteristics);

use strict;
use lib "..",".";

use Defs;

sub getCurrentCharacteristics	{
	my($Data, $clubID) = @_;

	my %cchars = ();
	if(ref $clubID)	{
		my @ids = ();
		for my $c (@{$clubID})	{
			push @ids, $c if $c =~/^\d+$/;
		}

		my $id_str = join(',',@ids);
		if(!$id_str or $id_str eq '0')	{
			return undef ;
		}
		my $st = qq[
			SELECT intCharacteristicID, intClubID
			FROM tblClubCharacteristics
			WHERE intClubID IN ($id_str)
		];
		my $q=$Data->{'db'}->prepare($st);
		$q->execute();
		while( my ($cc, $cID)=$q->fetchrow_array())	{
			$cchars{$cID}{$cc} = 1;
		}
	}
	else	{
		my $st = qq[
			SELECT intCharacteristicID
			FROM tblClubCharacteristics
			WHERE intClubID = ?
		];
		my $q=$Data->{'db'}->prepare($st);
		$q->execute( $clubID);
		while( my ($cc)=$q->fetchrow_array())	{
			$cchars{$cc} = 1;
		}
	}
	return \%cchars;
}


sub updateCharacteristics	{
	my($Data, $clubID, $newchars) = @_;

	my $st_d = qq[
		DELETE FROM tblClubCharacteristics
		WHERE intClubID = ?
	];
	my $q_d=$Data->{'db'}->prepare($st_d);
	$q_d->execute( $clubID);
	$q_d->finish();

	my $st = qq[
		INSERT INTO tblClubCharacteristics
		(intCharacteristicID, intClubID)
		VALUES (?,?)
	];
	my $q=$Data->{'db'}->prepare($st);
	for my $k (keys %{$newchars})	{
		$q->execute($k, $clubID);
	}

	return 1;
}

sub getAvailableCharacteristics	{
	my($Data, $locator) = @_;

	my $locatorstring = $locator
		? ' AND intLocator = 1 '
		: '';
	my $st = qq[
		SELECT *
		FROM tblOrgCharacteristics
		WHERE intRealmID = ?
			AND intSubRealmID IN (0,?)
			AND intRecStatus >= 0
			AND intEntityLevel = $Defs::LEVEL_CLUB
			$locatorstring
		ORDER BY intOrder, intSubRealmID ASC
	];
	my $q=$Data->{'db'}->prepare($st);
	$q->execute( $Data->{'Realm'}, $Data->{'RealmSubType'} );
	my @chars = ();
	while( my $dref =$q->fetchrow_hashref())	{
		push @chars, $dref;
	}
	return \@chars;
}

sub getClubCharacteristicsBlock	{
	my($Data, $clubID) = @_;

	my $cchars = getCurrentCharacteristics($Data, $clubID);
	my $allchars = getAvailableCharacteristics($Data);

	my $body = '';
	for my $char (@{$allchars})	{
		my $checked = $cchars->{$char->{'intCharacteristicID'}} ? ' CHECKED ' : '';
		$body .= qq[
			<input type = "checkbox" value = "1" $checked name = "cc_cb_$char->{'intCharacteristicID'}" id = "id_cc_cb_$char->{'intCharacteristicID'}"> <label for = "id_cc_cb_$char->{'intCharacteristicID'}">$char->{'strName'}</label><br>
		];
	}
	return $body;
}
1;
