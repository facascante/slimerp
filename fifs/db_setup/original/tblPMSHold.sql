DROP TABLE tblPMSHold;
#
CREATE table tblPMSHold (
	intPMSHoldingBayID    				INT NOT NULL AUTO_INCREMENT,
    strMassPayEmail                 VARCHAR(200) DEFAULT '',
	intRealmID			            INT(11) DEFAULT 0,
    intTransLogOnHoldID             INT(11) DEFAULT 0,
    intMassPayReturnedOnID            INT(11) DEFAULT 0,
    intHoldStatus                   TINYINT DEFAULT 0,
    curAmountToHold                 decimal(16,2) default 0,
    curBalanceToHold                decimal(16,2) default 0,
	dtHeld 			                DATETIME,
	tTimeStamp			            TIMESTAMP,
	strHeldComments                 TEXT,

PRIMARY KEY (intPMSHoldingBayID),
	KEY index_strMassPayEmail(strMassPayEmail),
	KEY index_intTransLogID (intTransLogOnHoldID),
	KEY index_intRealmID(intRealmID),
    UNIQUE KEY index_unique (strMassPayEmail, intTransLogOnHoldID)

);
 
