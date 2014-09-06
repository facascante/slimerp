#
# $Header: svn://svn/SWM/trunk/web/GlobalAuth.pm 8251 2013-04-08 09:00:53Z rlee $
#

package GlobalAuth;

require Exporter;
@ISA =  qw(Exporter);

@EXPORT = qw(
	validateGlobalAuth
);

@EXPORT_OK = qw(
	validateGlobalAuth
);

use lib "..","../comp";
use Defs;
use strict;

sub validateGlobalAuth {
	my (
		$Data,
		$userID,
		$entityTypeID,
		$entityID,
	) = @_;

	my $admin = 0;
	my $cache = $Data->{'cache'} || undef;
	$admin = $cache->get('swm',"GLOBALADMIN_$userID") if $cache;

	if(!$admin)	{
		my $st =qq[
			SELECT intUserID 
			FROM tblGlobalAuth
			WHERE intUserID = ?
		];
		my $q = $Data->{'db'}->prepare($st);
		$q->execute($userID);
		($admin) = $q->fetchrow_array();
		$q->finish();
		$cache->set('swm',"GLOBALADMIN_$userID",1,'',60*8) if $cache;
		return 1 if $admin;
	}
    return 0;
}


1;
