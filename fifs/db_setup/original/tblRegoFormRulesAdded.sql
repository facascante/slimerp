CREATE TABLE tblRegoFormRulesAdded (
    intRegoFormRuleAddedID  INT NOT NULL AUTO_INCREMENT,
    intRegoFormID           INT NOT NULL DEFAULT 0,
    intAssocID              INT NOT NULL DEFAULT 0,
    intClubID               INT NOT NULL DEFAULT 0,
    intRegoFormFieldAddedID INT DEFAULT NULL,
    strFieldName            TEXT,
    strGender               CHAR DEFAULT NULL,
    dtMinDOB                DATE DEFAULT NULL,
    dtMaxDOB                DATE DEFAULT NULL,
    ynPlayer                CHAR NOT NULL DEFAULT 'N',
    ynCoach                 CHAR NOT NULL DEFAULT 'N',
    ynMatchOfficial         CHAR NOT NULL DEFAULT 'N',
    ynOfficial              CHAR NOT NULL DEFAULT 'N',
    ynMisc                  CHAR NOT NULL DEFAULT 'N',
    intStatus               TINYINT DEFAULT 1,
    PRIMARY KEY (intRegoFormRuleAddedID),
    KEY index_regoFormAssocClubID (intRegoFormID, intAssocID, intClubID)
);
