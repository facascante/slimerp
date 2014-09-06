DROP TABLE tblClearanceDatesDue;
#
CREATE table tblClearanceDatesDue (
	intRealmID 	INT(11) DEFAULT 0, 
	intStateID 	INT(11) DEFAULT 0, 
	dtApplied	DATE,
	dtDue		DATE,
	dtReminder	DATE,

	KEY index_intStateIDRealmID(intStateID, intRealmID)
);
 
