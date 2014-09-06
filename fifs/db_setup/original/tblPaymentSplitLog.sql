DROP TABLE IF EXISTS tblPaymentSplitLog;

CREATE TABLE tblPaymentSplitLog (
  intLogID int NOT NULL auto_increment,
  intExportBankFileID int NOT NULL,
  intEntityTypeID int NOT NULL,
  intEntityID int NOT NULL,
  intAssocID int NOT NULL,
  intClubID int NOT NULL,
  strBankCode varchar(20),
  strAccountNo varchar(30),
  strAccountName varchar(250),
  strMPEmail varchar(127),
  curAmount decimal(10,2),
  intFeesType tinyint NOT NULL default 0,
	tTimeStamp        TIMESTAMP,
  PRIMARY KEY (intLogID),
  KEY index_intIDs (intExportBankFileID, intLogID),
  KEY intThing_key (intEntityTypeID, intEntityID)
);
