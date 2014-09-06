DROP TABLE tblClearanceDevelopmentFees;
CREATE table tblClearanceDevelopmentFees (
	intDevelopmentFeeID   INT NOT NULL AUTO_INCREMENT,
	curDevelopmentFee	DECIMAL(12,2) default 0,
	strTitle varchar(50) default '',
	strNotes TEXT,
	intRealmID INT default 0,
	tTimeStamp TIMESTAMP,

PRIMARY KEY (intDevelopmentFeeID),
	KEY index_intRealmID(intRealmID)
);
 
