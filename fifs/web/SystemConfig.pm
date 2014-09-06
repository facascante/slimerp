#
# $Header: svn://svn/SWM/trunk/web/SystemConfig.pm 11354 2014-04-23 02:05:55Z mstarcevic $
#

package SystemConfig;
require Exporter;
@ISA =  qw(Exporter);
@EXPORT = qw(getSystemConfig getLocalConfig);
@EXPORT_OK = qw(getSystemConfig getLocalConfig);


use strict;

# Load the system config Table from the Database 
# Return a reference to a hash containing the values

sub getSystemConfig {

	my ($Data) = @_;

	my %systemConfig=();

	my $db=$Data->{'db'};
	my $realmID=$Data->{'Realm'} || 0;
	my $subtypeID=$Data->{'RealmSubType'} || 0;
	my $statement = qq[
		SELECT strOption, strValue, intSubTypeID, strBlob
		FROM tblSystemConfig 
			LEFT JOIN tblSystemConfigBlob ON tblSystemConfig.intSystemConfigID = tblSystemConfigBlob.intSystemConfigID
		WHERE intRealmID IN(?, 0)
			ORDER BY intRealmID ASC, intSubTypeID ASC
	];


	my $query = $db->prepare($statement) or query_error($statement);
	$query->execute($realmID) or query_error($statement);
	while(my($DB_option, $DB_val, $DB_subtypeID, $DB_blob) = $query->fetchrow_array())  {
		$DB_val='' if !defined $DB_val;
		$DB_blob='' if !defined $DB_blob;
		$DB_val =$DB_blob if $DB_blob ne '';
		$systemConfig{$DB_option}=$DB_val;
	}
	$query->finish;
    $systemConfig{'TYPE_NAME_3'} = 'Official' if  !defined $systemConfig{'TYPE_NAME_3'};
	return \%systemConfig;
}

sub getLocalConfig {

  my ($Data) = @_;

	my %localConfig=();

	 my $db=$Data->{'db'};
	 my $realmID=$Data->{'Realm'} || 0;
	 my $subtypeID=$Data->{'RealmSubType'} || 0;

	if ($Data->{'clientValues'}{'assocID'} and $Data->{'clientValues'}{'assocID'} != $Defs::INVALID_ID)	{
		my $statement = qq[
			SELECT 
				strOption, 
				strValue
			FROM 
				tblLocalConfig as L
				INNER JOIN tblAssoc as A ON (
					A.intLocalisationID = L.intLocalisationID
				)
			WHERE A.intAssocID = ?
		];
		my $query = $db->prepare($statement) or query_error($statement);
		$query->execute($Data->{'clientValues'}{'assocID'});
		while(my($DB_option, $DB_val) = $query->fetchrow_array())  {
			$DB_val='' if !defined $DB_val;
			$localConfig{$DB_option}=$DB_val;
		}
		$query->finish;

	}
	return \%localConfig;
}

1;


# Options Available
#
# GenMemberNo
# GenNumField
# GenNumAssocIn
# DuplCheck
# DuplicateFields
# DuplResolveSameNatNum
# DuplLowPriorityAssoc
# AllowTXNs
# AllowProdTXNs
# AllowClearances
# AllowOnlineRego
# DefaultSport
# OnlySport
# AccredExpose
# NationalNumName
# NatTeamName ('National Team' Supported)

# RepAccred
# RepCompLevel
# 
# ParentBodyAccess
# DefCodesXXX
# NoClubs
# NoTeams
# NoComps
# NoMemberTypes
# NoAuditLog
# NoNavStats
# NoMemberTags
# DefaultListAction

# MemberFormReLayout
# Schools
# DontCheckAssocConfig - Don't worry if the assoc hasn't set it's own fields

# NoView
# AddNewMemberNavOption
# Page_Title_List_xxxx
# List_Instrution_xxxx
# IconsAsNavbar
# NoVersionInfo
# NoListDetails
# MemberListFields
# MemberListHeaders
# AllowMemberDelete
# MemberFooterText
# AllowClubGrades - Displays a drop down list of grades on the Member Edit Screen
# AllowStatusChange - Allows for the status of Clubs, Teams and Members to be changed. Also adds a date expiry field.
# DisplayAssocOfficials - Displays members who have been set as Association Officials on the Association Details Screens
# AllowPrimaryClub - Enables the option of selecting a primary club
