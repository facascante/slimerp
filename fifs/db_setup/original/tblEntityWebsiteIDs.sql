DROP TABLE IF EXISTS tblEntityWebsiteIDs;
CREATE TABLE tblEntityWebsiteIDs (
	intAssocID INT NOT NULL,
	intEntityTypeID INT NOT NULL,
	intEntityID INT NOT NULL,
	intHasEditor INT DEFAULT 0,
	dtUpdated datetime,
	intWebsite_ID INT,
	PRIMARY KEY (intEntityTypeID, intEntityID),
	KEY index_assocID (intAssocID)

);
