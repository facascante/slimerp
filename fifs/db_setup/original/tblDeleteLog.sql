CREATE table tblDeleteLog   (
    intDeleteLogID      INTEGER NOT NULL AUTO_INCREMENT,
	intRealmID			INT DEFAULT 0,
	intAssocID			INT DEFAULT 0,
	intCompID			INT DEFAULT 0,
	intDeleteType       INT DEFAULT 0, #eg: Match
	intEntityTable      INT DEFAULT 0,
	intEntityID         INT DEFAULT 0,

	tTimeStamp      	TIMESTAMP,

		PRIMARY KEY (intDeleteLogID),
		KEY index_intRealmID(intRealmID),
		KEY index_intAssocID(intAssocID),
		KEY index_compID(intCompID),
		KEY index_ID(intEntityTable, intEntityID)
);
