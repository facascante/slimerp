DROP TABLE IF EXISTS tblCustomReports;

CREATE table tblCustomReports (
    intCustomReportsID  INT NOT NULL AUTO_INCREMENT,
    strName		VARCHAR(30),
    strSQL		TEXT,	
    intTypeID      	INT NOT NULL,
    strConfig		TEXT,
    strTemplateFile	VARCHAR(30),
    intMinLevel        	INT NOT NULL,
    intMaxLevel        	INT NOT NULL,
	PRIMARY KEY (intCustomReportsID),
	KEY index_strName (strName)
);
