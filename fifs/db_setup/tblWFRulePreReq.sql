DROP TABLE IF EXISTS tblWFRulePreReq;
CREATE TABLE tblWFRulePreReq (
  intWFRulePreReqID int(11) NOT NULL AUTO_INCREMENT,
  intWFRuleID int(11) NOT NULL,
  intPreReqWFRuleID int(11) NOT NULL,
  dtDeletedDate datetime,
  tTimeStamp timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (intWFRulePreReqID),
  KEY index_intEntityID (intWFRuleID)
) DEFAULT CHARSET=utf8;
