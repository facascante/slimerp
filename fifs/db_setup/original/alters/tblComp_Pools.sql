DROP TABLE tblComp_Pools;
CREATE TABLE tblComp_Pools (
  intCompPoolID             INT NOT NULL AUTO_INCREMENT,
  intCompID                 INT DEFAULT 0,
  intStageID                INT DEFAULT 0,
  intPoolNumber             INT DEFAULT 0,
  intPoolType               TINYINT DEFAULT 0,
  strPoolName               VARCHAR(50) DEFAULT '',
  intPoolNumRounds          INT(11) DEFAULT 0,
  intPoolNumTeam            INT(11) DEFAULT 0,
  intPoolMatchInterval INT(11) DEFAULT 0,
  intPoolFixtureConfigID    INT(11) DEFAULT 0,
  intPoolFinalsConfigID     INT(11) DEFAULT 0,
  intPoolLocked             TINYINT DEFAULT 0,
  intRecStatus              INT DEFAULT 0,
  tTimeStamp                TIMESTAMP,

  PRIMARY KEY (intCompPoolID),
  KEY index_StageID (intStageID),
  KEY index_CompID (intCompID)
);

