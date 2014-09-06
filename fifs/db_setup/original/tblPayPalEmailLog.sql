DROP TABLE IF EXISTS tblPayPalEmailLog;

CREATE TABLE tblPayPalEmailLog	(
	intPayPalEmailLogID INT NOT NULL AUTO_INCREMENT,
	intEntityTypeID INT NOT NULL,
	intEntityID INT NOT NULL,
	tTimestamp TIMESTAMP,
	strEmail VARCHAR(250),
	strUsername VARCHAR(30) NOT NULL,
	intLoginEntityTypeID INT NOT NULL,
	intLoginEntityID INT NOT NULL,

	PRIMARY KEY(intPayPalEmailLogID),
	KEY index_entity(intEntityTypeID, intEntityID)

);
