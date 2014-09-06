DROP TABLE IF EXISTS tblFieldCaseRules;

CREATE TABLE tblFieldCaseRules (
    intFieldCaseRulesID  int NOT NULL auto_increment,
    intRealmID           int NOT NULL default 0,
    strType              varchar(20) NOT NULL,
    strDBFName           varchar(30) NOT NULL,
    strCase              varchar(10) NOT NULL default 'title',
    intRecStatus         tinyint NOT NULL default 1,
    tTimeStamp           timestamp,

    PRIMARY KEY (intFieldCaseRulesID),
    KEY index_RealmTypeID (intRealmID, strType, intFieldCaseRulesID)
);
