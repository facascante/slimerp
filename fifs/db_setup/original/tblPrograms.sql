

CREATE TABLE tblPrograms (
    intProgramID   INT NOT NULL AUTO_INCREMENT,
    intProgramTemplateID  INT NOT NULL,
    intStatus      INT NOT NULL DEFAULT 0,
    intAssocID     INT NOT NULL,
    intFacilityID  INT NOT NULL,
    strProgramName VARCHAR(200),
    dtStartDate    date NOT NULL,
    tmStartTime    TIME NOT NULL,
    intMinSuggestedAge INT,
    intMaxSuggestedAge INT,
    dtMaxDOB       DATE,
    dtMinDOB       DATE,
    intAllowMinAgeExceptions TINYINT DEFAULT 0,
    intAllowMaxAgeExceptions TINYINT DEFAULT 0,
    intDuration    INT,
    intVenueRequiredMins     INT,
    intMon TINYINT DEFAULT 0,
    intTue TINYINT DEFAULT 0,
    intWed TINYINT DEFAULT 0,
    intThu TINYINT DEFAULT 0,
    intFri TINYINT DEFAULT 0,
    intSat TINYINT DEFAULT 0,
    intSun TINYINT DEFAULT 0,
    intNumSessions   INT,
    intCapacity      INT,
    intOnMemberEnrolmentStatus INT,
    
    

    PRIMARY KEY (intProgramID),
    KEY index_assoc (intAssocID),
    KEY index_program_template (intProgramTemplateID),
    KEY index_facility (intFacilityID)
);
