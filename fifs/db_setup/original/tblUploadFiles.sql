DROP TABLE IF EXISTS tblUploadedFiles ;
CREATE TABLE tblUploadedFiles	(
	intFileID INT NOT NULL AUTO_INCREMENT,
	intFileType TINYINT DEFAULT 0,
	intEntityTypeID INT NOT NULL,
	intEntityID INT NOT NULL,
	intAddedByTypeID INT NOT NULL,
	intAddedByID INT NOT NULL,
	strTitle VARCHAR(200) NOT NULL,
	strPath VARCHAR(50) NOT NULL,
	strFilename VARCHAR(50) NOT NULL,
	strOrigFilename VARCHAR(250) NOT NULL,
	strExtension CHAR(4),
	intBytes INT DEFAULT 1,
	dtUploaded DATETIME,
	intPermissions TINYINT DEFAULT 1,

	PRIMARY KEY (intFileID),
	KEY entity_key (intEntityTypeID, intEntityID, intFileType)
);
