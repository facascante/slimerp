CREATE TABLE tblRegoFormAdded (
    intRegoFormAddedID   INT NOT NULL AUTO_INCREMENT,
    intRegoFormID        INT NOT NULL DEFAULT 0,
    intEntityTypeID      TINYINT UNSIGNED NULL DEFAULT 0,
    intEntityID          INT NOT NULL DEFAULT 0,
    intPaymentCompulsory TINYINT DEFAULT '0',
    PRIMARY KEY (intRegoFormAddedID),
    KEY index_regoFormEntityTypeEntityID (intRegoFormID, intEntityTypeID, intEntityID)
);
