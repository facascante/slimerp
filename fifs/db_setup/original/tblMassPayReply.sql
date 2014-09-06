DROP TABLE IF EXISTS tblPayment_MassPayReply;

CREATE TABLE tblPayment_MassPayReply	(
	intReplyID INT NOT NULL AUTO_INCREMENT,
	intBankFileID INT NOT NULL,
	strResult VARCHAR(20),
	tmTimeStamp TIMESTAMP,
	strText TEXT,
	 strMassPaySend TEXT DEFAULT '',

	PRIMARY KEY (intReplyID),
		KEY index_intBankFileID (intBankFileID)
	
);

