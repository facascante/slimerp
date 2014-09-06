DROP TABLE tblComp_Pool_ProgressionRules;
CREATE TABLE tblComp_Pool_ProgressionRules  (
  intCompRuleID             INT NOT NULL AUTO_INCREMENT,
  intCompID                 INT DEFAULT 0,
  intToPoolID               INT DEFAULT 0,
  intToTeamNumber           INT DEFAULT 0,
  intFromPoolID             INT DEFAULT 0,
  intFromStageID            INT DEFAULT 0,
  intFromTeamID             INT DEFAULT 0,
  intFromProgressionType    INT DEFAULT 0,
  intFromPositionNumber     INT DEFAULT 0,
  tTimeStamp                TIMESTAMP,

  PRIMARY KEY (intCompRuleID),
  KEY index_CompPoolID (intCompID, intToPoolID),
  UNIQUE KEY index_IDs (intCompID, intToPoolID, intToTeamNumber)
);

