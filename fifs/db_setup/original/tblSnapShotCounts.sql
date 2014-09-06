DROP TABLE IF EXISTS tblSnapShotCounts;
CREATE TABLE tblSnapShotCounts(
	intEntityTypeID INT NOT NULL,
	intEntityID INT NOT NULL,
	intYear INT NOT NULL,
	intMonth TINYINT NOT NULL,
	intSeasonID INT NOT NULL DEFAULT 0,
	intGender TINYINT DEFAULT 0,
	intAgeGroupID INT DEFAULT 0,
	intNewMembers INT NOT NULL DEFAULT 0,
	intRegoFormMembers INT NOT NULL DEFAULT 0,
	intMembers INT NOT NULL DEFAULT 0, ## Regardless of MA status
	intPermitMembers INT NOT NULL DEFAULT 0,
	intPlayer INT NOT NULL DEFAULT 0,
	intCoach INT NOT NULL DEFAULT 0,
	intUmpire INT NOT NULL DEFAULT 0,
	intOther1 INT NOT NULL DEFAULT 0,
	intOther2 INT NOT NULL DEFAULT 0,
	intComps INT NOT NULL DEFAULT 0,
	intCompTeams INT NOT NULL DEFAULT 0,
	intTotalTeams INT NOT NULL DEFAULT 0,
	intClubs INT NOT NULL DEFAULT 0,
	intClrIn INT NOT NULL DEFAULT 0,
	intClrOut INT NOT NULL DEFAULT 0,
	intClrPermitIn INT NOT NULL DEFAULT 0,
	intClrPermitOut INT NOT NULL DEFAULT 0,
	intTxns INT NOT NULL DEFAULT 0,
	curTxnValue DECIMAL(10,2) DEFAULT 0,
	intNewTribunal INT NOT NULL DEFAULT 0,
	

	PRIMARY KEY (intYear, intMonth, intEntityTypeID, intEntityID, intGender, intAgeGroupID),
		KEY index_Entity(intEntityTypeID, intEntityID)
);
