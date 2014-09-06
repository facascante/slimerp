DROP TABLE IF EXISTS tblRealmSubTypes;

CREATE TABLE tblRealmSubTypes	(
	intSubTypeID INT AUTO_INCREMENT NOT NULL,
	intRealmID INT NOT NULL,
	strSubTypeName VARCHAR(100) NOT NULL,

	PRIMARY KEY (intSubTypeID),
	KEY index_realm (intRealmID)


);
