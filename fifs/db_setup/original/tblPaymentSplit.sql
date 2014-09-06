DROP TABLE IF EXISTS tblPaymentSplit;

CREATE TABLE tblPaymentSplit (
  intSplitID int NOT NULL auto_increment,
  intRuleID int NOT NULL,
  intEntityTypeID int NOT NULL,
  intEntityID int NOT NULL,
  strSplitName varchar(100) NOT NULL,
  PRIMARY KEY (intSplitID),
  KEY intThing_key (intEntityTypeID, intEntityID)
);
