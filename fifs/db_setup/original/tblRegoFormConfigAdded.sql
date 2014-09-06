CREATE TABLE tblRegoFormConfigAdded (
    intRegoFormConfigAddedID INT NOT NULL AUTO_INCREMENT,
    intRegoFormID            INT NOT NULL DEFAULT 0,
    intEntityTypeID          TINYINT UNSIGNED NULL DEFAULT 0,
    intEntityID              INT NOT NULL DEFAULT 0,
    strTermsCondHeader       VARCHAR(100) DEFAULT NULL,
    strTermsCondText         TEXT,
    intTC_AgreeBox           TINYINT UNSIGNED DEFAULT 0,
    PRIMARY KEY (intRegoFormConfigAddedID),
    KEY index_regoFormEntityTypeEntityID (intRegoFormID, intEntityTypeID, intEntityID)
);
