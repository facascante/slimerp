drop table IF EXISTS tblPersonEntityRole;

CREATE table tblPersonEntityRole (
    intPersonEntityRoleID INTEGER NOT NULL AUTO_INCREMENT,
	intRealmID			INT DEFAULT 0,
	intPersonID			INT DEFAULT 0,
	intEntityID			INT DEFAULT 0,
	intRoleID	INT DEFAULT 0,
	
	intReceiveOffers	TINYINT DEFAULT 0,
	intProductUpdates 	TINYINT DEFAULT 0,

	intFnCompAdmin		TINYINT DEFAULT 0,
	intFnSocial			TINYINT DEFAULT 0,
	intFnWebsite		TINYINT DEFAULT 0,
	intFnClearances		TINYINT DEFAULT 0,
	intFnSponsorship	TINYINT DEFAULT 0,
	intFnPayments		TINYINT DEFAULT 0,
	intFnLegal			TINYINT DEFAULT 0,

	intPrimaryContact	TINYINT DEFAULT 0,
	intShowInLocator	TINYINT DEFAULT 0,

	tTimeStamp      	TIMESTAMP,

	PRIMARY KEY (intPersonEntityRoleID),
	KEY index_intRealmID(intRealmID),
	KEY index_intPersonID(intPersonID),
	KEY index_EntityID(intEntityID)
);
