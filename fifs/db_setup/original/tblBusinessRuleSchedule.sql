DROP TABLE tblBusinessRuleSchedule;

CREATE table tblBusinessRuleSchedule	(
	intBusinessRuleScheduleID		INT NOT NULL AUTO_INCREMENT,
	intBusinessRuleID		INT default 0,
	strScheduleName	VARCHAR(100) default '',
	intRealmID INT default 0,
	intRealmSubTypeID INT default 0,
	intScheduleByTableType INT default 0,
	intScheduleByID INT default 0,
	intDayToRun TINYINT default 0,
	dtLastRun datetime default '0000-00-00 00:00:00',
	tTimeStamp 		TIMESTAMP,

PRIMARY KEY (intBusinessRuleScheduleID),
INDEX index_ruleID (intBusinessRuleID),
INDEX index_intScheduleByID (intScheduleByID, intScheduleByTableType)
);
