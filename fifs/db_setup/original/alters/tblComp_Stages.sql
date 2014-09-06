CREATE TABLE tblComp_Stages (
  intCompStageID INT NOT NULL AUTO_INCREMENT,
  intCompID        INT DEFAULT 0,
  intStageNumber   INT DEFAULT 0,
  intStageType     TINYINT DEFAULT 0,
  strStageName     VARCHAR(50) DEFAULT '',
  intRecStatus     INT DEFAULT 0,
  tTimeStamp       TIMESTAMP,

  PRIMARY KEY (intCompStageID),
  KEY index_CompID (intCompID)
);

