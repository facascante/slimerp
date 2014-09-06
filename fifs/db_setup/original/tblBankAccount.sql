DROP TABLE IF EXISTS tblBankAccount;

CREATE TABLE tblBankAccount (
  intEntityTypeID int NOT NULL,
  intEntityID int NOT NULL,
  strBankCode varchar(20),
  strAccountNo varchar(30),
  strAccountName varchar(250),
  PRIMARY KEY (intEntityTypeID, intEntityID)
);
