DROP TABLE IF EXISTS tblPassportAuth;

CREATE table tblPassportAuth (
	intPassportID INT NOT NULL,
	intEntityTypeID INT NOT NULL,
	intEntityID INT NOT NULL,
	intAssocID INT NOT NULL DEFAULT 0 ,
	intLogins INT DEFAULT 0,
	intReadOnly TINYINT DEFAULT 0,
	intRoleID INT NOT NULL DEFAULT 0,
	dtLastlogin DATETIME,
	dtCreated DATETIME,

	PRIMARY KEY (intPassportID, intEntityTypeID, intEntityID),
	KEY index_entity(intEntityTypeID, intEntityID)
);
