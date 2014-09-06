DROP TABLE tblBusinessRules;

CREATE table tblBusinessRules	(
	intBusinessRuleID		INT NOT NULL AUTO_INCREMENT,
	strRuleName	VARCHAR(100) default '',
	strDescription TEXT,
	strFunction VARCHAR(100) default '',
	intParamTableType INT default 0,
	intNumParams INT default 0,
	strNotificationHeaderText TEXT,
	strNotificationRowsText TEXT,
	strNotificationRowsURLs text,
	strRequiredOption VARCHAR(100) default '',
	strRuleOption VARCHAR(100) default '',
	intRuleOutcomeType INT default 0,
	intOutcomeRows TINYINT default 0,
	intAcknowledgeDtLastRun INT DEFAULT 0,
	tTimeStamp 		TIMESTAMP,

PRIMARY KEY (intBusinessRuleID)
);


INSERT INTO tblBusinessRules VALUES (0,'Venue Long/Lat check','Checks if any Venues are missing Longtitude or Latitude', 'BusinessRules::checkVenues', 0,0,'You have Venue/s missing Long or Lat:', '~ref1_link~ is missing long or lat','','(dblLat=0 or dblLong=0)',1,1,1, NOW());
INSERT INTO tblBusinessRules VALUES (0,'Member DOB in Comp check','Checks if any Members playing in wrong DOB for a Season', 'BusinessRules::checkMemberDOBInComp', 101,1,'You have a Member playing in an incorrect Competition:', '~ref1_link~ player for ~ref2_name~ in ~ref3_name~ with an incorrect DOB','','',1,2,1, NOW());
