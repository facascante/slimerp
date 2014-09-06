DROP TABLE IF EXISTS tblReportEntity;
CREATE TABLE tblReportEntity (
	intReportID INT NOT NULL,
	intRealmID INT NOT NULL,
	intSubRealmID INT NOT NULL,
	intEntityTypeID INT NOT NULL,
	intEntityID INT NOT NULL,
	intMinLevel INT NOT NULL,
	intMaxLevel INT NOT NULL,

PRIMARY KEY (
	intReportID,
	intRealmID,
	intSubRealmID,
	intEntityTypeID,
	intEntityID
)
);
