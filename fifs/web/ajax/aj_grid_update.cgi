#!/usr/bin/perl 

#
# $Header: svn://svn/SWM/trunk/web/ajax/aj_grid_update.cgi 10492 2014-01-21 00:32:53Z apurcell $
#

use strict;
use warnings;
use lib "..",".","../..";
use CGI qw(param);
use Defs;
use Reg_common;
use Utils;
use JSON;
use Lang;
use AuditLog;

main();	

sub main	{
	# GET INFO FROM URL
  my $client = param('client') || '';
  my $colfield = param('col') || '';
  my $value = param('val') || 0;
  my $action = param('a') || '';
  my $gridid = param('id') || '';
  my $ID = $gridid || '';#param('key') || '';
	$value = 1 if $value eq 'checked';
  my %Data=();
  my $target='main.cgi';
  $Data{'target'}=$target;
  my %clientValues = getClient($client);
  $Data{'clientValues'} = \%clientValues;
  my $db=allowedTo(\%Data);
	$Data{'db'} = $db;
  my $lang= Lang->get_handle() || die "Can't get a language handle!";
  $Data{'lang'}=$lang;

  ($Data{'Realm'}, $Data{'RealmSubType'})=getRealm(\%Data);
	my $assocID=$Data{'clientValues'}{'assocID'} || '';
	$assocID ='' if $assocID == $Defs::INVALID_ID;
	my $level=$Data{'clientValues'}{'currentLevel'};
	return if !$assocID and $level <=$Defs::LEVEL_ASSOC;
	my %actionlevel = (
	    edit_facility => $Defs::LEVEL_NATIONAL,
		edit_stat_assoc => $Defs::LEVEL_ASSOC,
		edit_stat_club => $Defs::LEVEL_CLUB,
	);

	my $changelevel = $actionlevel{$action} || 0;
 	my $valid = validate_Access(\%Data, $changelevel, $ID, $action);

	my $done = 0;
	
	if($db and $valid)	{
		$done = update_Statuses(
			\%Data, 
			$ID, 
			$value, 
			$changelevel, 
			$colfield,
			$action
		);
	}

  my $json = to_json({
    complete => $done || 0,
    results => 1,
  });
  print "Content-type: application/x-javascript\n\n$json";
}


sub update_Statuses {
  my(
		$Data, 
		$ID, 
		$value, 
		$level, 
		$field,
		$action
	)=@_;

	return if !$ID;
	return if !$level;
	
	my $realmID = $Data->{'Realm'} || 0;
    $realmID = '' if $realmID == $Defs::INVALID_ID;
	
	my $assocID = $Data->{'clientValues'}{'assocID'} || '';
	$assocID = '' if $assocID == $Defs::INVALID_ID;

	my $clubID = $Data->{'clientValues'}{'clubID'} || '';
	$clubID = '' if $clubID == $Defs::INVALID_ID;

	my $currentlevel=$Data->{'clientValues'}{'currentLevel'};
	return if !$assocID and $currentlevel <=$Defs::LEVEL_ASSOC;

	my $st = '';
	my @values = ();
	if ( $level == $Defs::LEVEL_NATIONAL ){
	    if ( $action eq 'edit_facility'){
	        if ($field eq 'intRecStatus')  {
                $st = qq[
                    UPDATE 
                        tblFacilities 
                    SET
                        intRecStatus = ? 
                    WHERE 
                        intFacilityID = ?
                        AND intRealmID = ?
                ];
                push @values, $value;
                push @values, $ID;
                push @values, $realmID;
            }
	    }
	}
	elsif($level==$Defs::LEVEL_ASSOC) {
		$st=qq[ 
			UPDATE tblAssoc SET intRecStatus=? 
			WHERE intAssocID=?
			AND intRecStatus <> $Defs::RECSTATUS_DELETED
		];
		push @values, $value;
		push @values, $ID;
	}
	elsif($level==$Defs::LEVEL_CLUB) {
		$st=qq[ 
		UPDATE tblAssoc_Clubs SET intRecStatus=?
		WHERE intClubID=?
			AND intAssocID= ?
			AND intRecStatus <> $Defs::RECSTATUS_DELETED
		];
		my $st2=qq[
                UPDATE tblClub SET intRecStatus=?
                WHERE intClubID=?
                        AND intRecStatus <> $Defs::RECSTATUS_DELETED
                ];
		my $q2=$Data->{'db'}->prepare($st2);
        	$q2->execute($value,$ID);
        	
		push @values, $value;
		push @values, $ID;
		push @values, $assocID;
	}
	return '' if !$st;
	my $q=$Data->{'db'}->prepare($st);

	$q->execute(@values);

	return 1;
}

sub validate_Access	{

	my (
		$Data, 
		$changelevel,
		$changeID,
		$action
	) = @_;
	return 0 if !$changelevel;
	return 0 if !$changeID;
	my $currentlevel = $Data->{'clientValues'}{'currentLevel'};
	my $id = getID($Data->{'clientValues'});
	my $realm = $Data->{'Realm'} || 0;
	
	my $st = '';
	my @values = ();
	my $ret;
	
	if ($action eq 'edit_facility' && $currentlevel == $Defs::LEVEL_NATIONAL ){
	    
	    $st = qq[
            SELECT intFacilityID
            FROM tblFacilities
            WHERE intFacilityID = ?
                AND intRealmID = ?
        ];

        my $q = $Data->{'db'}->prepare($st);
        $q->execute(
            $changeID,
            $realm,
        );

        ($ret) = $q->fetchrow_array();
	}
	else{
	    #non action dependant
    	if(
    		$changelevel >= $Defs::LEVEL_ZONE
    		and $currentlevel > $Defs::LEVEL_ZONE)	{
    
    		$st = qq[
    			SELECT intNodeLinksID
    			FROM tblNodeLinks
    			WHERE intParentNodeID = ?
    				AND intChildNodeID = ?
    		];
    	}
    	elsif(
    		$changelevel == $Defs::LEVEL_ASSOC
    		and $currentlevel == $Defs::LEVEL_ZONE)	{
    
    		$st = qq[
    			SELECT intAssocID
    			FROM tblAssoc_Node
    			WHERE intNodeID = ?
    				AND intAssocID = ?
    		];
    	}
    	elsif(
    		$changelevel == $Defs::LEVEL_CLUB
    		and $currentlevel == $Defs::LEVEL_ASSOC)	{
    
    		$st = qq[
    			SELECT intAssocClubID
    			FROM tblAssoc_Clubs
    			WHERE intAssocID = ?
    				AND intClubID = ?
    		];
    	}
    	my $q = $Data->{'db'}->prepare($st);
    	$q->execute(
    		$id,
    		$changeID,
    	);
    	auditLog(getID($Data->{'clientValues'}) || 0, $Data, 'Update', 'Status');
    	($ret) = $q->fetchrow_array();
    }
	return $ret || 0;
}

1;
