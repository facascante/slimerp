CREATE TABLE tblTermsMember (
    intTermsMemberID INT NOT NULL AUTO_INCREMENT,
    intMemberID      INT DEFAULT 0,
    intLevel         TINYINT UNSIGNED DEFAULT 0,
    intFormID        INT DEFAULT 0,
    tTimestamp       TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (intTermsMemberID),
        KEY index_memberLevel (intMemberID, intLevel)
);

