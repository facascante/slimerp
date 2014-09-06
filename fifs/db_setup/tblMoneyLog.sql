DROP TABLE IF EXISTS tblMoneyLog;
CREATE TABLE tblMoneyLog (
	intMoneyLogID int(11) NOT NULL auto_increment,
  	curMoney decimal(16,2) default NULL,
	tTimeStamp TIMESTAMP,
	intRealmID INT(11) DEFAULT 0,
	intRealmSubTypeID INT(11) DEFAULT 0,
	intEntityID INT(11) DEFAULT 0,
	intTransactionID INT(11) DEFAULT 0,
	intTransLogID INT(11) DEFAULT 0,
	strFrom VARCHAR(100) DEFAULT '',
	dtEntered date,
	strMPEmail varchar(255) DEFAULT '',
	intExportBankFileID INT(11) DEFAULT 0,
	intMYOBExportID INT(11) DEFAULT 0,
	intEntityType INT(11) DEFAULT 0,
	intEntityID INT(11) DEFAULT 0,
	intLogType INT(11) DEFAULT 0,
	strBankCode VARCHAR(100) DEFAULT '',
	strAccountNo VARCHAR(100) DEFAULT '',
	strAccountName VARCHAR(100) DEFAULT '',
	intRuleID INT(11) DEFAULT 0,
	intSplitID INT(11) DEFAULT 0,
	intSplitItemID INT(11) DEFAULT 0,
	strCurrencyCode VARCHAR(10) DEFAULT '',
	dblGSTRate double DEFAULT 0,
	

  PRIMARY KEY  (intMoneyLogID),
  KEY index_realmID (intRealmID),
  KEY index_logType(intLogType),
  KEY index_txnIDs (intTransLogID, intTransactionID),
  KEY index_Entity(intEntityID)
) DEFAULT CHARSET=utf8;
