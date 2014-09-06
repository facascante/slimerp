DROP TABLE IF EXISTS tblTransactionSplit;

CREATE TABLE tblTransactionSplit	(
  intTXNSplitLogID int NOT NULL auto_increment,
  intExportBankFileID int NOT NULL,
  intTransactionID INT NOT NULL,
  intTransLogID INT NOT NULL,
  intRealmID INT NOT NULL,
  intSplitID INT NOT NULL,
  intSplitItemID INT NOT NULL,
  curSplitAmount decimal(10,2),
  intSplitType tinyint NOT NULL default 0, ## eg: Fee ?
  tTimeStamp        TIMESTAMP,

  PRIMARY KEY (intTXNSplitLogID),
  KEY index_intTransactionID (intTransactionID)
);

