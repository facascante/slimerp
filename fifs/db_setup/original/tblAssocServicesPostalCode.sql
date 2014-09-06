DROP TABLE IF EXISTS tblAssocServicesPostalCode;

CREATE TABLE tblAssocServicesPostalCode	(
	intAssocID INT NOT NULL,
	strPostalCode VARCHAR(15) NOT NULL,

	PRIMARY KEY (intAssocID, strPostalCode),
	KEY index_strPostalCode (strPostalCode)
);

