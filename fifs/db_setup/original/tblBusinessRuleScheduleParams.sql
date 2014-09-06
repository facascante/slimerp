DROP TABLE tblBusinessRuleScheduleParams;

CREATE table tblBusinessRuleScheduleParams	(
	intBusinessRuleParamID		INT NOT NULL AUTO_INCREMENT,
	intBusinessRuleScheduleID		INT default 0,
	intParamTableType INT default 0,
	intParamID INT default 0,
	tTimeStamp 		TIMESTAMP,

PRIMARY KEY (intBusinessRuleParamID),
INDEX index_scheduleID (intBusinessRuleScheduleID),
INDEX index_Params (intParamID, intParamTableType)
);
