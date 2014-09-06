#!/usr/bin/perl

#
# $Header: svn://svn/SWM/trunk/misc/add_regions.pl 8250 2013-04-08 08:24:36Z rlee $
#

use warnings;

use lib "..","../web";
use Defs;
use Utils;
use strict;

my $db=connectDB();

my $linenumber=1;
my $topnode=0;
my ($realmID, $topTypeID)=(0,0);
my $LevelArray=getLevelArray();
my $currentparent=0;
my $startingindex=0;
my $lastID=0;
my $last_level=0;
my $lastname='';
my @parent_array=();
my @DBLinkArray=();
my @DBAssocNode=();
my $st_add=qq[
	INSERT INTO tblNode (strName, intTypeID, intStatusID, intDataAccess, intRealmID, intSubTypeID)
	VALUES (?,?,?,?,?,?)
];
my $q_add=$db->prepare($st_add);
my $st_a_add=qq[
	INSERT INTO tblAssoc (strName, intDataAccess, intRealmID, intAssocTypeID)
	VALUES (?,?,?,?)
];
my $q_a_add=$db->prepare($st_a_add);
my $st_a_link	=qq[
	INSERT INTO tblAssoc_Node (intNodeID, intAssocID)
	VALUES (?,?)
];
my $q_a_link=$db->prepare($st_a_link);
my $st_link	=qq[
	INSERT INTO tblNodeLinks (intParentNodeID, intChildNodeID)
	VALUES (?,?)
];
my $q_link=$db->prepare($st_link);
my $st_un_add=qq[
	INSERT INTO tblAuth (strUsername, strPassword, intLevel, intAssocID, intID, dtCreated)
	VALUES (?,?,?,?,?,NOW())
];
my $q_un_add=$db->prepare($st_un_add);

my @UsernamesToAdd=();
my $RealmSubType=0;
while(<STDIN>)	{
	chomp();
	my $line=$_;
	if($linenumber==1)	{
		die("Invalid file format - no parent node defined") if $line!~/\-\d+/;
		$topnode=$line;
		$topnode=~s/[^\d]//g;
		($realmID, $topTypeID)=getTopInfo($db, $topnode);
		$currentparent=$topnode;
		#Find index in array for levels	
		for my $i (0 .. $#$LevelArray){
			if($LevelArray->[$i]==$topTypeID)	{
				$startingindex=$i;
				last;
			}	
		}
		$last_level=$startingindex;
		$lastID=$topnode;
		$linenumber++;
		next;
	}
	my $num_levels=()=$line=~/\t/g;
	my $currentlevel=$startingindex+1+$num_levels;
	if($line=~/\*/)	{ #Assoc
		$currentlevel=$#$LevelArray;
	}
	my $status=$Defs::NODE_SHOW;
	my $DataAccess=$Defs::DATA_ACCESS_FULL;

	if($currentlevel > $last_level)	{
		push @parent_array, [$lastID, $last_level];
		if(($currentlevel -1) != $last_level)	{
			fillinlevels($lastname, $currentlevel, $last_level, $db, $LevelArray, \@parent_array, $q_add, \@DBLinkArray, $realmID, $RealmSubType);
		}
	}
	elsif($currentlevel < $last_level)	{
		my $diff=$last_level-$currentlevel;
		for my $i (1 ..$diff)	{pop @parent_array;}
	}
	$line=~s/^\t+//g; #Get rid of +s
	$line=~s/^\*//g; #Get rid of +s
	if($line=~/\[/)	{
		#other data
		my($l,$dat)=$line=~/(.*)\s*\[(.*)\].*$/;
		my @extra_data=split /,/, $dat;
		$status=$extra_data[0] if $extra_data[0] ne '';	
		$DataAccess=$extra_data[1] if $extra_data[1] ne '';	
		$RealmSubType=$extra_data[2] if $extra_data[2] ne '';	
		$line=$l;
	}
	my $newID=0;
	if($LevelArray->[$currentlevel] == $Defs::LEVEL_ASSOC)	{
		$q_a_add->execute($line, $DataAccess, $realmID, $RealmSubType);
		$newID=$q_a_add->{mysql_insertid};
		push @DBAssocNode, [$parent_array[$#parent_array][0], $newID];
		push @UsernamesToAdd, [$newID, $LevelArray->[$currentlevel]];
	}
	else	{
		$q_add->execute($line, $LevelArray->[$currentlevel], $status, $DataAccess, $realmID, $RealmSubType);
		$newID=$q_add->{mysql_insertid};
		push @DBLinkArray, [$parent_array[$#parent_array][0], $newID];
		push @UsernamesToAdd, [$newID, $LevelArray->[$currentlevel]];
	}
	$last_level=$currentlevel;
	$lastID=$newID;
	$lastname=$line;
	$linenumber++;
}

for my $i (@DBLinkArray)	{
	$q_link->execute($i->[0],$i->[1]);
}
for my $i (@DBAssocNode)	{
	$q_a_link->execute($i->[0],$i->[1]);
}
for my $i (@UsernamesToAdd)	{
	my $un="AUBBAH";
	my $aID=0;
	if($i->[1] == $Defs::LEVEL_ASSOC)	{
		$un.='a';
		$aID=$i->[0];
	}
	$un.=$i->[0];
	my $pw=getpass();
	$q_un_add->execute($un, $pw, $i->[1],$aID, $i->[0]);
}



# Subs ----

sub getTopInfo	{
	my($db, $id)=@_;
	my $st=qq[
		SELECT intNodeID, intRealmID, intTypeID
		FROM tblNode
		WHERE intNodeID=$id
	];
	my $q=$db->prepare($st);
	$q->execute();
	my ($nodeID, $realmID, $typeID)=$q->fetchrow_array();
	$q->finish();
	die("Invalid top node ID - doesn't exist") if !$nodeID;
	return ($realmID||0, $typeID||0);	
}


sub getLevelArray	{
	my @levels=(
  $Defs::LEVEL_TOP , #0
  $Defs::LEVEL_INTERNATIONAL , #1
  $Defs::LEVEL_INTREGION , #2
  $Defs::LEVEL_INTZONE , #3
  $Defs::LEVEL_NATIONAL ,#4
  $Defs::LEVEL_STATE ,#5
  $Defs::LEVEL_REGION ,#6
  $Defs::LEVEL_ZONE ,#7
  $Defs::LEVEL_ASSOC ,#8
	);
	return \@levels;
}

sub fillinlevels	{
	my ($lastname, $currentlevel, $last_level, $db, $LevelArray, $parent_array, $q_add, $DBLinkArray, $realmID, $RealmSubType)=@_;
	for my $i ($last_level+1 .. $currentlevel -1)	{
		#Add new node
		#$lastname.=" - ($LevelArray->[$i])";
		$q_add->execute($lastname, $LevelArray->[$i], $Defs::NODE_HIDE, $Defs::DATA_ACCESS_FULL, $realmID, $RealmSubType);
		my $newID=$q_add->{mysql_insertid};
		push @DBLinkArray, [$parent_array->[$#$parent_array][0], $newID];
		push @{$parent_array}, [$newID,$LevelArray->[$i]];
	}
}

sub getpass {
	srand();
	#srand(time() ^ ($$ + ($$ << 15)) );
	my $salt=(rand()*100000);
	my $salt2=(rand()*100000);
	my $k=crypt($salt2,$salt);
	#Clean out some rubbish in the key
	$k=~s /['\/\.\%\&]//g;
	$k=substr($k,0,8);
	$k=lc $k;

  return $k;
}

#
=head1 Format
-1    #top node id with - in front
Tabs
each tab chracter indent indicates another level down
Name []
    - A text name for each level added
    - Assocs are prefixed with a * and will be added at the appropriate level and       
     intervening levels automatically filled in
    after a name a series of other options can be added
		[Status,DataAccces, RealmSubType]

=cut
