DROP TABLE IF EXISTS tblBulkRenewalsRecipient;
CREATE TABLE tblBulkRenewalsRecipient	(
	intBulkRenewalID INT NOT NULL,
	intEntityTypeID INT NOT NULL,
	intEntityID INT NOT NULL,
	strAddress VARCHAR(250),
	dtAdded DATETIME,
	strContent TEXT,

	PRIMARY KEY (intBulkRenewalID, intEntityTypeID, intEntityID, strAddress),
		KEY index_person (intEntityTypeID, intEntityID)

);
