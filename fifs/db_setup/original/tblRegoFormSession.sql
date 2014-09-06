DROP TABLE IF EXISTS tblRegoFormSession;
CREATE TABLE tblRegoFormSession	(
	intRegoFormSessionID INT NOT NULL AUTO_INCREMENT,
	strSessionKey  CHAR(40) NOT NULL,
	intMemberID INT NOT NULL,
	intFormID INT NOT NULL,
	intNumber TINYINT DEFAULT 1,
	intChild TINYINT DEFAULT 0,
	tTimestamp TIMESTAMP,
	strTransactions VARCHAR(255) DEFAULT '', #Comma separated list of transaction IDs

PRIMARY KEY (intRegoFormSessionID),
	KEY index_session (strSessionKey)	

);
