DROP TABLE IF EXISTS tblDashboardConfig;
CREATE TABLE tblDashboardConfig (
	intDashboardConfigID INT NOT NULL AUTO_INCREMENT,
	intEntityTypeID INT NOT NULL,
	intEntityID INT NOT NULL,
	strDashboardItemType VARCHAR(50),
	strDashboardItem VARCHAR(50),
	intOrder INT NOT NULL DEFAULT 5,

	PRIMARY KEY (intDashboardConfigID),
		KEY  index_entity (intEntityTypeID, intEntityID)
);

