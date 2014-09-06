DROP TABLE tblClearance;
#
CREATE table tblClearance (
	intClearanceID     				INT NOT NULL AUTO_INCREMENT,
	intMemberID		INT(11) NOT NULL DEFAULT 0,
	intDestinationClubID		INT(11) NOT NULL DEFAULT 0,
	intSourceClubID			INT(11) NOT NULL DEFAULT 0,
	intDestinationAssocID		INT(11) NOT NULL DEFAULT 0,
	intSourceAssocID			INT(11) NOT NULL DEFAULT 0,
	intRealmID			INT(11) NOT NULL DEFAULT 0,
	intCurrentPathID			INT(11) NOT NULL DEFAULT 0,
	strPhoto			VARCHAR(100),
	dtApplied			DATETIME,
	tTimeStamp			TIMESTAMP,
	strReasonForClearance		TEXT,
	intClearanceStatus		INTEGER,
	dtFinalised	DATETIME,

PRIMARY KEY (intClearanceID),
	KEY index_intMemberID(intMemberID),
	KEY index_intDestinationClubID(intDestinationClubID),
	KEY index_intSourceClubID(intSourceClubID),
	KEY index_intDestinationAssocID(intDestinationAssocID),
	KEY index_intSourceAssocID(intSourceAssocID),
	KEY index_intRealmID(intRealmID),
	KEY index_intClearanceStatus(intClearanceStatus),
	KEY index_intCurrentPathID(intCurrentPathID)
);
 
