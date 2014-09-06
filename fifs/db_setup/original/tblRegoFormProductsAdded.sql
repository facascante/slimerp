CREATE TABLE tblRegoFormProductsAdded (
    intRegoFormProductAddedID int NOT NULL AUTO_INCREMENT,
    intRegoFormID             int DEFAULT NULL,
    intAssocID                int NOT NULL DEFAULT 0,
    intClubID                 int NOT NULL DEFAULT 0,
    intProductID              int NOT NULL DEFAULT 0,
    intRegoTypeLevel          int DEFAULT 0,
    intIsMandatory            tinyint DEFAULT 0,
    intSequence               smallint DEFAULT 0,
    PRIMARY KEY (intRegoFormProductAddedID),
    KEY index_regoFormAssocClubID (intRegoFormID,intAssocID, intClubID)
);
