DROP TABLE IF EXISTS tblMemberCardConfig;
CREATE TABLE tblMemberCardConfig	(
	intMemberCardConfigID INT NOT NULL AUTO_INCREMENT,
	strName VARCHAR(200),
	intRealmID INT NOT NULL,
	intSubRealmID INT NOT NULL DEFAULT 0,
	intAssocID INT NOT NULL DEFAULT 0,
	intPrintFromLevelID INT DEFAULT 0,
	intBulkPrintFromLevelID INT DEFAULT 0,
	strFilename VARCHAR(200),

	PRIMARY KEY (intMemberCardConfigID),
	INDEX index_realm (intRealmID, intAssocID),
	INDEX index_assoc (intAssocID)

);

