DROP TABLE IF EXISTS tblReports;
CREATE TABLE tblReports (
	intReportID INT NOT NULL AUTO_INCREMENT,
	strName VARCHAR(255) NOT NULL,
	strDescription TEXT,
	intType TINYINT,
	strFilename VARCHAR(200),
	strFunction VARCHAR(200),
	strGroup VARCHAR(100),
	intParameters TINYINT DEFAULT 0,
	intOrder INT DEFAULT 1,
	strRequiredOptions TEXT,

	PRIMARY KEY (intReportID)

);
