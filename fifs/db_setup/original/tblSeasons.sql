-- Created 080718 for the new Seasons development
DROP TABLE IF EXISTS tblSeasons;

#
# Table               : tblSeasons
# Description         : Defines seasons by Association and/or Realm
#---------------------

CREATE table tblSeasons	(
	intSeasonID		INT NOT NULL AUTO_INCREMENT,
    	intRealmID            	INT DEFAULT 0,
    	intRealmSubTypeID       INT DEFAULT 0,
    	intAssocID            	INT DEFAULT 0,
	strSeasonName		VARCHAR(100),
	intSeasonOrder		INT DEFAULT 0, -- Is it worth having an order for the seasons list
	intArchiveSeason	TINYINT(4) DEFAULT 0, -- Is it worth having an order for the seasons list
	dtAdded		DATE,
	dtClearanceStart	DATE,
	dtClearanceEnd		DATE,
	tTimeStamp 		TIMESTAMP,

PRIMARY KEY (intSeasonID),
KEY index_intAssocID(intAssocID),
KEY index_intRealm(intRealmID, intRealmSubTypeID)
);

