

CREATE TABLE tblProgramTemplates (
    intProgramTemplateID     INT NOT NULL AUTO_INCREMENT,
    intRealmID     INT NOT NULL,
    intSubRealmID  INT DEFAULT -1,
    intStatus      INT NOT NULL DEFAULT 0,
    strTemplateName VARCHAR(200) DEFAULT '',
    strProgramName  VARCHAR(200) DEFAULT '',
    strProgramDescription VARCHAR(500),
    dtMinDOB       DATE,
    dtMaxDOB       DATE,
    intMinSuggestedAge INT,
    intMaxSuggestedAge INT,
    dtMinStartDate DATE,
    dtMaxStartDate DATE,
    intAllowMinAgeExceptions TINYINT DEFAULT 0,
    intAllowMaxAgeExceptions TINYINT DEFAULT 0,
    intMinDuration    INT,
    intMaxDuration    INT,
    intMinNumSessions INT,
    intMaxNumSessions INT,
    intRegoFormID     INT,
    intOnMemberEnrolmentStatus INT,

    PRIMARY KEY (intProgramTemplateID),
    KEY index_realms (intRealmID, intSubRealmID)
);
