DROP TABLE tblDBLevelConfig;

CREATE table tblDBLevelConfig (
	intDBConfigID				INTEGER NOT NULL AUTO_INCREMENT,
	intDBConfigGroupID	INTEGER NOT NULL,
	intLevelID					INTEGER NOT NULL,
	intPlural						TINYINT NOT NULL DEFAULT 0,
	intSubTypeID						INTEGER NOT NULL DEFAULT 0,
	strName							VARCHAR(150),

	PRIMARY KEY (intDBConfigID),
	KEY index_intDBConfigGroupID (intDBConfigGroupID),
	KEY index_intLevelID (intLevelID)
);
