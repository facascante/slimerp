DROP TABLE IF EXISTS tblEntityTypeRoles;
CREATE TABLE tblEntityTypeRoles (
    intEntityTypeRoleID int NOT NULL AUTO_INCREMENT,
    intRealmID int default 0,
    intSubRealmID int default 0 ,
    strSport varchar(20) default '',
    strPersonType varchar(30) default '',
    strEntityRoleKey varchar(30) default '',
    strEntityRoleName varchar(30) default '',
    tTimestamp timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (intEntityTypeRoleID),
    UNIQUE KEY KEY_strEntityRoleKey (strEntityRoleKey),
        KEY index_intRealmID (intRealmID),
        KEY index_intSubRealmID (intSubRealmID)
) DEFAULT CHARSET=utf8 COMMENT='This table shows the strPersonEntityRole values available';
