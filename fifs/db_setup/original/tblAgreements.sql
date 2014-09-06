DROP TABLE IF EXISTS tblAgreements;
CREATE TABLE tblAgreements	(
	intAgreementID INT NOT NULL AUTO_INCREMENT,
	intEntityFor INT NOT NULL, #Whether this is an assoc or club agreement
	strName VARCHAR(200) NOT NULL,
	strAgreement TEXT DEFAULT '',		
	dtExpiryDate DATE,
	dtStartDate DATE,
	tTimeStamp TIMESTAMP,

	intRealmID INT NOT NULL,
	intSubRealmID INT DEFAULT 0,
	intCountryID INT DEFAULT 0,
	intStateID INT DEFAULT 0,
	intRegionID INT DEFAULT 0,
	intZoneID INT DEFAULT 0,
	intAssocID INT DEFAULT 0,

	PRIMARY KEY (intAgreementID),
	KEY index_realm(intRealmID),
	KEY index_country(intCountryID),
	KEY index_state(intStateID),
	KEY index_region(intRegionID),
	KEY index_zone(intZoneID),
	KEY index_assoc(intAssocID)
);
