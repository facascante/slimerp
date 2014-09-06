CREATE TABLE tblRegoFormPrimary (
    intRegoFormPrimaryID    INT NOT NULL AUTO_INCREMENT,
    intEntityTypeID         TINYINT UNSIGNED NOT NULL DEFAULT 0,
    intEntityID             INT NOT NULL DEFAULT 0,
    intRegoFormID           INT NOT NULL DEFAULT 0,
    tTimeStamp              TIMESTAMP NOT NULL default CURRENT_TIMESTAMP on update CURRENT_TIMESTAMP,
    PRIMARY KEY (intRegoFormPrimaryID),
    UNIQUE KEY index_entityTypeEntityID (intEntityTypeID, intEntityID)
);
