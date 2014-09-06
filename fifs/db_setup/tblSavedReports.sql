DROP TABLE tblSavedReports;

CREATE table tblSavedReports (
    intReportID	     INTEGER NOT NULL AUTO_INCREMENT,
    strReportName		VARCHAR(50) NOT NULL,
    intLevelID         INT NOT NULL,
    intID            INT NOT NULL,
		strReportType VARCHAR(50),
    strReportData TEXT,
PRIMARY KEY (intReportID),
KEY index_user (intLevelID, intID, strReportType)
);

