DROP TABLE IF EXISTS tblPaymentSplitFees;

CREATE TABLE tblPaymentSplitFees (
  intFeesID int NOT NULL auto_increment,
  intRealmID int NOT NULL,
  intSubTypeID int NOT NULL default 0,
  intFeesType tinyint NOT NULL,
  strBankCode varchar(20),
  strAccountNo varchar(30),
  strAccountName varchar(250),
  curAmount decimal(10,2),
  dblFactor double,
  PRIMARY KEY (intFeesID),
  KEY index_intRealm (intRealmID, intSubTypeID)
);





