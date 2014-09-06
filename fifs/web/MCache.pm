#
# $Header: svn://svn/SWM/trunk/web/MCache.pm 8251 2013-04-08 09:00:53Z rlee $
#

package MCache;

use lib "..";
use Defs;
use Cache::Memcached::Fast;

use strict;

my %cachetypes = (
	sww => 1, #Sportzware Websites
	swm => 2, #Sportzware Membership
	mem => 3, #MySport based queries that would be useful in multiple systems
	ls => 4, #Livestats
);

sub new {

  my $this = shift;
  my $class = ref($this) || $this;
  my $self ={ };

	if(@Defs::MemCacheServers)	{
		$self->{'OBJ'} = new Cache::Memcached::Fast({
			servers => \@Defs::MemCacheServers,
		});
	}
	else	{
		warn("No Memcache servers defined");
		$self->{'OBJ'} = undef;
	}

  bless $self, $class;

  return $self;
}

sub set {
	#Insert/Update value into Memcache
	my $self = shift;
	my (
		$type,
		$key,
		$value,
		$group,
		$expiry,

	) = @_;
	return undef if !$self->{'OBJ'};
	return undef if !$key;
	$value ||= '';
	$group ||= '';
	$expiry ||= 0;
	my $typeprefix =$cachetypes{$type} || '';
	my $ret = $self->{'OBJ'}->set("$typeprefix~$key", $value, $expiry);
	if($ret and $group)	{
		$self->_addtogroup(
			$type,
			$group,
			$key,	
		);
	}
	return $ret;
}

sub get {
	#Get value from Memcache
	my $self = shift;
	my (
		$type,
		$key,
	) = @_;
	return undef if !$self->{'OBJ'};
	return undef if !$key;
	my $typeprefix =$cachetypes{$type} || '';

	return $self->{'OBJ'}->get("$typeprefix~$key");
}

sub delete {
	#Get value from Memcache
	my $self = shift;
	my (
		$type,
		$key,
	) = @_;
	return undef if !$self->{'OBJ'};
	return undef if !$key;
	my $typeprefix =$cachetypes{$type} || '';

	return $self->{'OBJ'}->delete("$typeprefix~$key");
}

sub _addtogroup {
	my $self = shift;
	my (
		$type,
		$group,
		$key,
	) = @_;
	return undef if !$self->{'OBJ'};
	my $typeprefix =$cachetypes{$type} || '';
	my $groupkey =  "$typeprefix~$group";
	my $existingnum = $self->{'OBJ'}->get("$groupkey-0") || 0;
	if(!$existingnum)	{
		$self->{'OBJ'}->set("$groupkey-0",0);
	}
	my $newnum = $self->{'OBJ'}->incr("$groupkey-0") || 0;
	$self->{'OBJ'}->set("$groupkey-$newnum", "$typeprefix~$key");
}

sub delgroup {
	my $self = shift;
	my (
		$type,
		$group,
	) = @_;
	return undef if !$self->{'OBJ'};
	my $typeprefix =$cachetypes{$type} || '';
	my $groupkey =  "$typeprefix~$group";
	my @groupkeys = ();
	for my $i (0 .. $self->{'OBJ'}->get("$groupkey-0"))	{
		push @groupkeys, "$groupkey-$i";
	}

	my $groupvalues= $self->{'OBJ'}->get_multi(@groupkeys);

	my @groupvals = values %{$groupvalues};
	$self->{'OBJ'}->delete_multi(@groupkeys);
	$self->{'OBJ'}->delete_multi(@groupvals);
	return 1;
}

sub stats	{
	my $self = shift;
	#This is not supported by the api so we'll do it the old fashioned way
	use Net::Telnet ();
	my ($host,$port) = split/:/, $Defs::MemCacheServers[0]{'address'};
	my $connection = new Net::Telnet (
		Host => $host,
		Port => $port,
		Timeout => 10,
	);
	$connection->print("stats");
	my %stats= ();
	while(1)	{
		my $line =  $connection->getline();
		chomp $line;
		if($line =~/END/)	{
			$connection->close();
			last;
		}
		my($k, $v) = $line =~/^STAT\s*(.*)\s+(.*)$/;
		$stats{$k} = $v;
	}
	return \%stats;
}

1;

