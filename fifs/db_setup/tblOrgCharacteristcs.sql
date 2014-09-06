DROP TABLE IF EXISTS tblOrgCharacteristics;
CREATE TABLE tblOrgCharacteristics (
	intCharacteristicID INT NOT NULL AUTO_INCREMENT,
	intRealmID INT NOT NULL DEFAULT 0,
	intSubRealmID INT NOT NULL DEFAULT 0,
	intEntityLevel INT NOT NULL DEFAULT 0,
	strName VARCHAR(200),
	strAbbrev VARCHAR(20),
	intLocator TINYINT DEFAULT 0,
	intOrder TINYINT UNSIGNED DEFAULT 50,
	intRecStatus TINYINT DEFAULT 1,

	PRIMARY KEY (intCharacteristicID),
	INDEX index_realm(intRealmID)
);

