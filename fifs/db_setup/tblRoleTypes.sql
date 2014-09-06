drop table if exists tblRoleTypes;

#
# Table               : tblContactRoles
# Description         : Contact Roles
#---------------------
CREATE table tblRoleTypes (
    intRoleID       	INTEGER NOT NULL AUTO_INCREMENT,
	intRealmID			INT DEFAULT 0,
	intRealmSubTypeID	INT DEFAULT 0,
	
	intRoleOrder		INT DEFAULT 0,
	intShowAtTop		INT DEFAULT 0,
	intAllowMultiple	INT DEFAULT 0,
	
	strRoleName			VARCHAR(50) DEFAULT '',

	tTimeStamp      	TIMESTAMP,

	PRIMARY KEY (intRoleID),
	KEY index_Realm(intRealmID, intRealmSubTypeID)
) DEFAULT CHARSET=utf8;
