DROP TABLE IF EXISTS tblTempEntityStructure;
CREATE TABLE tblTempEntityStructure(
    intRealmID INT NOT NULL DEFAULT 0,
    intParentID INT NOT NULL DEFAULT 0,
    intParentLevel INT NOT NULL DEFAULT 0,
    intChildID INT NOT NULL DEFAULT 0,
    intChildLevel INT NOT NULL DEFAULT 0,
    intDirect TINYINT NOT NULL DEFAULT 0,
    intDataAccess TINYINT NOT NULL DEFAULT 10,
    intPrimary           TINYINT NOT NULL DEFAULT 1,
    tTimeStamp                    TIMESTAMP,

    PRIMARY KEY(intParentID, intChildID),
    KEY index_intRealmID(intRealmID),
    KEY index_parentclevel(intParentID, intChildLevel)
);

