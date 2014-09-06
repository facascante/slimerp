DROP TABLE IF EXISTS tblFieldPermissions;
CREATE TABLE tblFieldPermissions (
	intRealmID INT NOT NULL,
	intSubRealmID INT NOT NULL,
	intEntityTypeID INT NOT NULL DEFAULT 0,
	intEntityID INT NOT NULL DEFAULT 0,
	strFieldType VARCHAR(20) DEFAULT '', 
	strFieldName VARCHAR(30) DEFAULT '',
	strPermission VARCHAR(20) DEFAULT '',
	intRoleID INT NOT NULL DEFAULT 0,

	PRIMARY KEY (intEntityTypeID, intEntityID, intRealmID, strFieldType, strFieldName, intRoleID),
	KEY index_intRealm (intRealmID, intSubRealmID)	
);

#Field Type: Member, MemberChild, MemberRegoForm, TeamChild, Team, TeamRegoForm, Club, ClubChild
#Permission : ReadOnly, Compulsory, Edit, AddOnlyCompulsory, ChildDefine, Hidden

