#
# $Header: svn://svn/SWM/trunk/web/DeQuote.pm 8251 2013-04-08 09:00:53Z rlee $
#

package DeQuote;
require Exporter;
@ISA =  qw(Exporter);
@EXPORT = qw(deQuote);
@EXPORT_OK = qw(deQuote);


sub deQuote	{
	my ($db, @params)=@_;
	my $re=qr/^\d+$/;
	for $param (@params)	{
		#Check Param Type
		if(ref $param eq "SCALAR")	{
			if(defined $$param and $$param=~$re){next;}
			$$param=$db->quote($$param);
		}
		elsif(ref $param eq "HASH")	{
			foreach my $key (keys %{$param})	{
				if(ref $param->{$key})	{deQuote($db,$param->{$key});next;}
				if(defined $param->{$key} and $param->{$key}=~$re){next;}
				$param->{$key}=$db->quote($param->{$key});
			}
		}
		elsif(ref $param eq "ARRAY")	{
			for my $arrayparam (@{$param})	{
				if(ref $arrayparam)	{deQuote($db,$arrayparam);next;}
				if(defined $arrayparam and $arrayparam=~$re){next;}
				$arrayparam	= $db->quote($arrayparam);
			}
		}
		elsif(ref $param eq "REF")	{
			deQuote($db,$param)
		}
	}
}
