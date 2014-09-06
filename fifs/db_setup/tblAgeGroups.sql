DROP TABLE IF EXISTS tblAgeGroups;

CREATE table tblAgeGroups	(
	intAgeGroupID		INT NOT NULL AUTO_INCREMENT,
    intSeasonID     INT NOT NULL,
	strAgeGroupDesc		VARCHAR(100),
	intActive 		TINYINT DEFAULT 0, 
	intAgeFrom TINYINT NOT NULL 0,
	intAgeTo TINYINT NOT NULL 0,
    dtAgeAsDate DATE,
	tTimeStamp 		TIMESTAMP,

PRIMARY KEY (intAgeGroupID),
KEY index_season(intSeasonID, intActive)
);

