DROP TABLE IF EXISTS tblAssocConfig ;
 
CREATE table tblAssocConfig (
	intAssocConfigID INT NOT NULL AUTO_INCREMENT,
  	intAssocID 			INT NOT NULL,
  	strOption VARCHAR (100) NOT NULL,
  	strValue	VARCHAR (250) NOT NULL,
  	tTimeStamp        TIMESTAMP,
		
	PRIMARY KEY (intAssocConfigID),
	KEY index_AssocID(intAssocID),
	KEY index_strOption(strOption),
	UNIQUE KEY index_AssocOption(intAssocID,strOption)
);
 
