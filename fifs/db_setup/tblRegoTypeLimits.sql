DROP TABLE IF EXISTS tblRegoTypeLimits;
CREATE TABLE tblRegoTypeLimits(
    intLimitID int NOT NULL AUTO_INCREMENT,
    intRealmID int default 0,
    intSubRealmID int default 0 ,
    strSport varchar(20) default '',
    strPersonType varchar(30) default '',
    strPersonEntityRole varchar(30) default '',
    strPersonLevel varchar(30) default '',
    strAgeLevel varchar(30) default '',
    intLimit int default 0,
    tTimestamp timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (intLimitID),
        KEY index_intRealmID (intRealmID),
        KEY index_intSubRealmID (intSubRealmID)
) DEFAULT CHARSET=utf8 COMMENT='This table contains the registration limits';
