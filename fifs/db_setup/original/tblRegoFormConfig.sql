drop table if exists tblRegoFormConfig;
CREATE table tblRegoFormConfig (
  intRegoFormConfigID      INT NOT NULL AUTO_INCREMENT, 
  intAssocID  INT NOT NULL,
  intRealmID INT NOT NULL,
  intSubRealmID INT NOT NULL DEFAULT 0,
	strTopText TEXT,
	strBottomText TEXT,
	strSuccessText TEXT,

PRIMARY KEY (intRegoFormConfigID),
	KEY index_intRealmID (intRealmID, intSubRealmID),
	KEY index_intAssocID (intAssocID)
);
 
