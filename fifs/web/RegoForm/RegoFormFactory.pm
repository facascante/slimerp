package RegoForm::RegoFormFactory;

require Exporter;
@ISA =  qw(Exporter);

@EXPORT = qw(getRegoFormObj);
@EXPORT_OK = qw(getRegoFormObj);

use strict;

use lib '.','..','../..';

use Lang;
use Reg_common;
use Defs;
use Utils;
use SystemConfig;
use ConfigOptions;
require PageMain;

sub getRegoFormObj	{
	my ($formID, $DataIn, $db, $cgi, $carryfields, $passport, $earlyExit) = @_;

	my %Data = %{$DataIn};
	$passport ||= undef;

	return undef if !$formID;
	return undef if !$db;

	my $formtype = 0;
	my $realmID = 0;
	my $subrealmID = 0;
	my $assocID = 0;
	my $clubID = 0;
    #extra fields for node level forms issued at node level (and therefore not having assoc/club ids).
    my $createdLevel   = 0;
    my $regoRealmID    = 0;
    my $regoSubrealmID = 0;

    #manipulate the fields used in the sql to cater for forms created at node level (these wont have an assocID or clubID set
    #and subsequently have them (assocID and clubID)  sent through the url and put into the Data hash).
    my $assocSelect = 'A.intAssocID';
    my $assocJoin   = 'R.intAssocID';
    my $clubSelect  = 'R.intClubID';

    if (exists $Data{'spAssocID'} and $Data{'spAssocID'} > 0) {
        $assocSelect = $Data{'spAssocID'};
        $assocJoin   = $assocSelect;

        if (exists $Data{'spClubID'} and $Data{'spClubID'} > 0) {
            $clubSelect = $Data{'spClubID'};
        }
    }

    my $joinCondition = "A.intAssocID=$assocJoin";

	{
		my $st = qq[
			SELECT 
				R.intRegoType,
                R.intRealmID AS RegoRealmID,
                R.intSubRealmID AS RegoSubRealmID,
                R.intCreatedLevel,
				A.intRealmID,
				A.intAssocTypeID,
				$assocSelect,
				$clubSelect
			FROM
				tblRegoForm AS R
                LEFT JOIN tblAssoc AS A ON $joinCondition
			WHERE
				R.intRegoFormID = ?
			LIMIT 1
		];
		my $q = $db->prepare($st);
		$q->execute($formID);
		($formtype, $regoRealmID, $regoSubrealmID, $createdLevel, $realmID, $subrealmID, $assocID, $clubID) = $q->fetchrow_array();
		$q->finish();

        #for a node created form issued by the node, realm and subrealm will be set from the regoform.
        my $useRealmID = $realmID;
        my $useSubrealmID = $subrealmID;
        if (!$useRealmID) {
            #initially thought to only have this for node levels. but can be a failsafe for any level.
            $useRealmID = $regoRealmID if $regoRealmID;
            $useSubrealmID = $regoSubrealmID if $regoSubrealmID;
        }
		$Data{'Realm'} = $useRealmID;
		$Data{'RealmSubType'} = $useSubrealmID || 0;

        $Data{'clientValues'}{'assocID'} = $assocID;
        $Data{'clientValues'}{'clubID'} = $clubID;
        $Data{'clientValues'}{'authLevel'} = ($clubID>0) ? $Defs::LEVEL_CLUB : $Defs::LEVEL_ASSOC;
        $Data{'RegoForm'} = 1;
        $Data{'RegoFormID'} = $formID;

		getDBConfig(\%Data);
		$Data{'SystemConfig'} = getSystemConfig(\%Data);
		$Data{'LocalConfig'} = getLocalConfig(\%Data);
	}
	my $obj = undef;
	my $objectname = '';
	if($formtype == $Defs::REGOFORM_TYPE_MEMBER_ASSOC)	{
		$objectname = 'RegoForm::RegoForm_Member';
	}
	elsif($formtype == $Defs::REGOFORM_TYPE_MEMBER_CLUB)	{
		$objectname = 'RegoForm::RegoForm_Member_Club';
	}
	elsif($formtype == $Defs::REGOFORM_TYPE_MEMBER_PROGRAM) {
        $objectname = 'RegoForm::RegoForm_Member_Program';
    }
		
	if($objectname)	{
		eval "require $objectname";
		$obj = $objectname->new(
			ID           => $formID,
			Data         => \%Data,
			db           => $db,
			Lang         => $Data{'lang'},
			Target       => $Data{'target'},
			SystemConfig => $Data{'SystemConfig'},
			LocalConfig  => $Data{'LocalConfig'},
			CarryFields  => $carryfields,
			cgi          => $cgi,
			Passport     => $passport,
            earlyExit    => $earlyExit,
		);
	}

	return $obj;
}

1;




