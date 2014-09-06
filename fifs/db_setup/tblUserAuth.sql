DROP TABLE IF EXISTS tblUserAuth;
CREATE TABLE tblUserAuth (
    userId INT UNSIGNED NOT NULL,
    entityTypeId INT NOT NULL,
    entityId INT NOT NULL,
    lastLogin   DATETIME,
    readOnly    TINYINT DEFAULT 0,

    PRIMARY KEY (userId, entityTypeId, entityId)
);

