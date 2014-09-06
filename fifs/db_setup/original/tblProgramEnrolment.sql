CREATE TABLE tblProgramEnrolment (
    intProgramEnrolmentID  INT NOT NULL AUTO_INCREMENT,
    intProgramID    INT NOT NULL,
    intMemberID     INT NOT NULL,
    intNewToProgram INT DEFAULT 1,
    intStatus       INT NOT NULL DEFAULT 1,

    PRIMARY KEY (intProgramEnrolmentID),
    UNIQUE KEY index_program_member (intProgramID, intMemberID)
);
