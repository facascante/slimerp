DROP TABLE IF EXISTS tblEntityContacts;
CREATE TABLE tblEntityContacts	(
	intEntityTypeID INT NOT NULL,
	intEntityID INT NOT NULL,
	tLastUpdated TIMESTAMP,

	strPrimaryContactName VARCHAR(255),
	strPrimaryContactEmail VARCHAR(255),
	strPrimaryContactPhone VARCHAR(150),

	strClearancesContactName VARCHAR(255),
	strClearancesContactEmail VARCHAR(255),
	strClearancesContactPhone VARCHAR(150),

	strWebsiteContactName VARCHAR(255),
	strWebsiteContactEmail VARCHAR(255),
	strWebsiteContactPhone VARCHAR(150),

	strAdvertisingContactName VARCHAR(255),
	strAdvertisingContactEmail VARCHAR(255),
	strAdvertisingContactPhone VARCHAR(150),

	strPaymentsContactName VARCHAR(255),
	strPaymentsContactEmail VARCHAR(255),
	strPaymentsContactPhone VARCHAR(150),

	strRegistrationsContactName VARCHAR(255),
	strRegistrationsContactEmail VARCHAR(255),
	strRegistrationsContactPhone VARCHAR(150),

	strGBContactName VARCHAR(255),
	strGBContactEmail VARCHAR(255),
	strGBContactPhone VARCHAR(150),

	strContractsContactName VARCHAR(255),
	strContractsContactEmail VARCHAR(255),
	strContractsContactPhone VARCHAR(150),

	strFundRaisingContactName VARCHAR(255),
	strFundRaisingContactEmail VARCHAR(255),
	strFundRaisingContactPhone VARCHAR(150),

	strSocialContactName VARCHAR(255),
	strSocialContactEmail VARCHAR(255),
	strSocialContactPhone VARCHAR(150),

	strGoodsServicesContactName VARCHAR(255),
	strGoodsServicesContactEmail VARCHAR(255),
	strGoodsServicesContactPhone VARCHAR(150),

	PRIMARY KEY (intEntityTypeID, intEntityID)

);
