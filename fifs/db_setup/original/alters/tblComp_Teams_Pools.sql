CREATE TABLE tblComp_Teams_Pools (
  intCompTeamPoolID    INT NOT NULL AUTO_INCREMENT,
  intCompID        INT DEFAULT 0,
  intTeamID        INT DEFAULT 0,
  intPoolID         INT DEFAULT 0,
  intTeamNumber    INT DEFAULT 0,
  intRecStatus     INT DEFAULT 0,
  intFinishPosition INT DEFAULT 0,
  tTimeStamp       TIMESTAMP,

  PRIMARY KEY (intCompTeamPoolID),
  KEY index_StageID (intTeamID),
  KEY index_PoolID (intPoolID),
  KEY index_CompID (intCompID),
  UNIQUE KEY index_id (intCompID, intTeamID, intPoolID)
);

