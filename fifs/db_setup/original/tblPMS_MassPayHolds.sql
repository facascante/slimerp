DROP TABLE tblPMS_MassPayHolds;
#
CREATE table tblPMS_MassPayHolds (
	intHoldID    				    INT NOT NULL AUTO_INCREMENT,
	intPMSHoldingBayID    			INT NOT NULL,
    curHold                 decimal(16,2) default 0,
    intMassPayHeldOnID              INT DEFAULT 0,
    intRealmID              INT DEFAULT 0,
    intHoldStatus               TINYINT DEFAULT 0,
	dtHeld 			                DATETIME,
	tTimeStamp			            TIMESTAMP,

PRIMARY KEY (intHoldID),
	KEY index_intID(intPMSHoldingBayID)
);
 
