#
# $Header: svn://svn/SWM/trunk/web/GenCode.pm 8251 2013-04-08 09:00:53Z rlee $
#

package GenCode;

use Exporter;
@EXPORT=qw(new);

use lib "../web";
use strict;
use Utils;

#This code generates new unique membership numbers based on conditions contained in tblGenerate
# NB This code requires that only one instance is running at one time or concurrency issues may occur.

sub new {

  my $this = shift;
  my $class = ref($this) || $this;
  my ($db, $realm)=@_;
  my %fields=();
	$fields{db}=$db || '';
	$fields{availablenums}=();
	$fields{'realm'}=$realm || '';
	
	#Setup Values
	my $statement=qq[
					SELECT intMemberLength, strMemberPrefix, strMemberSuffix, intMaxNum, intCurrentNum, intGenType, intAlphaCheck, intMinNum
					FROM tblGenerate
						WHERE intRealmID=$realm
					LIMIT 1
	];
	my $query=$db->prepare($statement) or query_error($statement);
	$query->execute or query_error($statement);
	$fields{Data}= $query->fetchrow_hashref();
	if(!$fields{Data})	{ $fields{Data}{intGenType}=0;	}
	$query->finish();

	my $self={%fields};
  bless $self, $class;
  ##bless selfhash to GenCode;
  ##return the blessed hash
  return $self;
}


sub getNumber	{
	#return a new member number

	my $self = shift;
	my($prefixEval,$suffixEval, $field)=@_;

	if(!$prefixEval)	{
		if($self->{Data}{strMemberPrefix})	{ $prefixEval=eval($self->{Data}{strMemberPrefix}); }
		else	{ $prefixEval=''; }
	}
	if(!$suffixEval)	{
		if($self->{Data}{strMemberSuffix})	{ $suffixEval=eval($self->{Data}{strMemberSuffix}); }
		else	{ $suffixEval=''; }
	}
	if(!defined $self->{availablenums} or !@{$self->{availablenums}})	{	$self->genCodeNo($prefixEval,$suffixEval, $field);	}
	my $newnum=shift @{$self->{availablenums}} || 0;
	$self->{LastNum}=$newnum;
	return $newnum;
}

sub genCodeNo	{
	#db : Database Handle
	#maxnum : Maximum Number to randomise to

	my $self = shift;
	my($prefixEval,$suffixEval, $field)=@_;

	$self->{Data}{intAlphaCheck}||=0;
	$self->{Data}{intMinNum}||=0;
	$field||='strNationalNum';
	if($self->{Data}{intGenType}==1)	{
		#Random Numbers
		my $numtogen=2;
		if(!$self->{Data}{intMemberLength})	{ return -1;	}
		my $gen_length=$self->{Data}{intMemberLength}-length($prefixEval)-length($suffixEval);
		if($self->{Data}{intAlphaCheck}>0)	{$gen_length--;}
		if($gen_length <=0)	{ return -1;	}
		my $gen_num=(10**$gen_length)-1;
		if($self->{Data}{intMaxNum}< $gen_num)	{$gen_num=$self->{Data}{intMaxNum};}
		srand();
		my $statement=qq[
			SELECT DISTINCT $field
			FROM tblMember
			WHERE $field IN (?)
				AND intRealmID= $self->{'realm'}
			LIMIT $numtogen
		];
		my $query=$self->{db}->prepare($statement) or query_error($statement);
		for my $tries (0 .. 6)	{
			my %possible=();
			for my $i (0 .. $numtogen)	{
				if($gen_num <= $i)	{last;}
				my $randNumber=int(rand($gen_num-$self->{Data}{intMinNum}));
				$randNumber+=$self->{Data}{intMinNum};
				if($randNumber==0)	{next;}
				$randNumber=sprintf("%0*d",$gen_length, $randNumber);
				my $try_code=$prefixEval.$randNumber.$suffixEval;
				if($self->{Data}{intAlphaCheck})       {
					my $checkLetter=genCheckLetter($try_code);
					if($self->{Data}{intAlphaCheck}==1)	{ $try_code=$try_code.$checkLetter; }
					elsif($self->{Data}{intAlphaCheck}==2)	{ $try_code=$checkLetter.$try_code; }
				}
				$possible{$try_code}=1;
			}
			my $possiblelist=join(',',keys %possible);
			$query->execute($possiblelist);
			while(my ($existingkey)=$query->fetchrow())	{ 
				delete($possible{$existingkey});
			}
			push @{$self->{availablenums}}, keys %possible;
			if(@{$self->{availablenums}})	{last;}
		}
	}
	elsif($self->{Data}{intGenType}==2)	{
		#Sequential Numbers
		my $statement_UPD=qq[
			UPDATE tblGenerate
			SET intCurrentNum=LAST_INSERT_ID(intCurrentNum+1)
			WHERE intRealmID= $self->{'realm'}
			LIMIT 1
		];
		$self->{'db'}->do($statement_UPD);
		my $st_getnum=qq[SELECT LAST_INSERT_ID()];
		my $query=$self->{db}->prepare($st_getnum) or query_error($st_getnum);
		$query->execute or query_error($st_getnum);
		($self->{LastNum})=$query->fetchrow() ;
		$self->{LastNum}||= $self->{Data}{intMinNum} || 0;
		my $newnum=$self->{LastNum};
		if($newnum < $self->{Data}{intMinNum}) 	{$newnum=$self->{Data}{intMinNum};}
		#$newnum++;
		my $gen_length=$self->{Data}{intMemberLength}-length($prefixEval)-length($suffixEval);
		if($self->{Data}{intAlphaCheck}>0)	{$gen_length--;}
		$newnum=sprintf("%0*d",$gen_length, $newnum);
		if($self->{Data}{intAlphaCheck})       {
			my $checkLetter=genCheckLetter($newnum);
			if($self->{Data}{intAlphaCheck}==1)	{ $newnum=$newnum.$checkLetter; }
			elsif($self->{Data}{intAlphaCheck}==2)	{ $newnum=$checkLetter.$newnum; }
		}
		push @{$self->{availablenums}}, $newnum;
	}
}

sub genCheckLetter	{
	my($code)=@_;
	my $total_char=0;
	my @alpha_array=qw(A B C D E F G H I J K L M N O P Q R S T U V W X Y Z);

	my @letter_array=split //,$code;
	for my $i (0 .. $#letter_array)	{
		next if $letter_array[$i]!~/\d/;
		$total_char+=$letter_array[$i];
	}
	my $index=($total_char%26);	
	return $alpha_array[$index];
}

sub Active	{
	my $self=shift;
	if($self->{Data}{intGenType})	{ return 1;	}
	else	{ 	return 0;	}
}

sub getPrefix	{
	my $self=shift @_;
	return $self->{Data}{strMemberPrefix} || '';
}

sub getSuffix	{
	my $self=shift @_;
	return $self->{Data}{strMemberSuffix} || '';
}
1;
