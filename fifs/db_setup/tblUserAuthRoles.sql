DROP TABLE IF EXISTS tblUserAuthRoles;
CREATE TABLE tblUserAuthRoles (
    userId INT UNSIGNED NOT NULL,
    entityTypeId INT NOT NULL,
    entityId INT NOT NULL,
    roleId  INT NOT NULL,

    PRIMARY KEY (userId, entityTypeId, entityId, roleId)
);

