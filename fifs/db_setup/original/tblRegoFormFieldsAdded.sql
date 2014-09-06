CREATE TABLE tblRegoFormFieldsAdded (
    intRegoFormFieldAddedID INT NOT NULL AUTO_INCREMENT,
    intRegoFormID           INT NOT NULL DEFAULT 0,
    intAssocID              INT NOT NULL DEFAULT 0,
    intClubID               INT NOT NULL DEFAULT 0,
    strFieldName            TEXT,
    intType                 INT NOT NULL DEFAULT 0,
    intDisplayOrder         INT NOT NULL DEFAULT 0,
    strText                 TEXT,
    intStatus               TINYINT DEFAULT '1',
    strPerm                 VARCHAR(50) DEFAULT NULL,
    PRIMARY KEY (intRegoFormFieldAddedID),
    KEY index_regoFormAssocClubID (intRegoFormID, intAssocID, intClubID)
);
