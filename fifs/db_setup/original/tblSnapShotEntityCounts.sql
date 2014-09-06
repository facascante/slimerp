DROP TABLE IF EXISTS tblSnapShotEntityCounts_2;
CREATE TABLE tblSnapShotEntityCounts_2(
	intEntityTypeID INT NOT NULL,
	intEntityID INT NOT NULL,
	intYear INT NOT NULL,
	intMonth TINYINT NOT NULL,
	intSeasonID INT NOT NULL DEFAULT 0,
	intClubs INT NOT NULL DEFAULT 0,
	intComps INT NOT NULL DEFAULT 0,
	intCompTeams INT NOT NULL DEFAULT 0,
	intTotalTeams INT NOT NULL DEFAULT 0,
	intClrIn INT NOT NULL DEFAULT 0,
	intClrOut INT NOT NULL DEFAULT 0,
	intClrPermitIn INT NOT NULL DEFAULT 0,
	intClrPermitOut INT NOT NULL DEFAULT 0,
	intTxns INT NOT NULL DEFAULT 0,
	curTxnValue DECIMAL(10,2) DEFAULT 0,
	intNewTribunal INT NOT NULL DEFAULT 0,
	

	PRIMARY KEY (intYear, intMonth, intEntityTypeID, intEntityID),
		KEY index_Entity(intEntityTypeID, intEntityID)
);
