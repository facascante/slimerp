DROP TABLE IF EXISTS tblRegoFormNotificationItems;
CREATE TABLE tblRegoFormNotificationItems (
    intRegoFormNotificationItemID INT NOT NULL AUTO_INCREMENT,
    intRegoFormNotificationID INT NOT NULL,
    strType VARCHAR(100) NOT NULL,
    strTypeName VARCHAR(100) DEFAULT '',
    strOldValue VARCHAR(100) DEFAULT '',
    strNewValue VARCHAR(100) DEFAULT '',
    dtCreated DATETIME DEFAULT NULL,

    PRIMARY KEY (intRegoFormNotificationItemID)
);
