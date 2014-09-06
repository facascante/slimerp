DROP TABLE IF EXISTS tblPaymentSplitItem;

CREATE TABLE tblPaymentSplitItem (
  intItemID int NOT NULL auto_increment,
  intSplitID int NOT NULL,
  intLevelID smallint NOT NULL default 0,
  strOtherBankCode varchar(20),
  strOtherAccountNo varchar(30),
  strOtherAccountName varchar(250),
  curAmount decimal(10,2),
  dblFactor double,
  intRemainder tinyint NOT NULL default 0,
  PRIMARY KEY (intItemID),
  KEY index_intSplitID (intSplitID)
);
