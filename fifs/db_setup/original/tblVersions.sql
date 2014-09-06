DROP TABLE IF EXISTS tblVersions;

CREATE TABLE tblVersions (
	intVersionID INT AUTO_INCREMENT NOT NULL,
	strText TEXT	NOT NULL,
	dtDate DATE NOT NULL,

	PRIMARY KEY	(intVersionID),
	INDEX indexDate (dtDate)
);
