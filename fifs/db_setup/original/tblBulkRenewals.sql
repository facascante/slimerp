DROP TABLE IF EXISTS tblBulkRenewals;
CREATE TABLE tblBulkRenewals	(
	intBulkRenewalID INT NOT NULL AUTO_INCREMENT,
	intRenewalType TINYINT DEFAULT 0,
	strTemplate VARCHAR(200),
	strFromAddress VARCHAR(200),
	intEntityTypeID INT NOT NULL,
  intEntityID INT NOT NULL,
	dtAdded DATETIME,
	dtSent DATETIME,

	PRIMARY KEY (intBulkRenewalID),
	KEY index_dtSent(dtSent)

);
