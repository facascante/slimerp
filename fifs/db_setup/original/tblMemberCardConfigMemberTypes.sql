DROP TABLE IF EXISTS tblMemberCardConfigMemberTypes;
CREATE TABLE tblMemberCardConfigMemberTypes	(
	intMemberCardConfigID INT NOT NULL AUTO_INCREMENT,
	intTypeID INT NOT NULL,
	intActive TINYINT DEFAULT 1,

	PRIMARY KEY (intMemberCardConfigID, intTypeID)

);

