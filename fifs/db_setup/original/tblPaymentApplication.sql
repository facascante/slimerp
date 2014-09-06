DROP TABLE IF EXISTS tblPaymentApplication;
CREATE TABLE tblPaymentApplication	(
	intApplicationID INT AUTO_INCREMENT NOT NULL,
	intEntityTypeID INT NOT NULL,
	intEntityID INT NOT NULL,
	intRealmID INT NOT NULL,

	strOrgName VARCHAR(200),
	strACN VARCHAR(50),
	strABN VARCHAR(50),
	strContact VARCHAR(200),
	strContactPhone VARCHAR(50),
	strMailingAddress VARCHAR(255),
	strSuburb VARCHAR(200),
	strPostalCode VARCHAR(20),
	strOrgPhone VARCHAR(50),
	strOrgFax VARCHAR(50),
	strOrgEmail VARCHAR(255),
	strPaymentEmail VARCHAR(255),
	strAgreedBy VARCHAR(255),
	dtCreated DATETIME,

	PRIMARY KEY (intApplicationID),
		KEY index_entity(intEntityTypeID, intEntityID),
		KEY index_realm(intRealmID)
);
