DROP TABLE IF EXISTS tblRegoFormNotifications;
CREATE TABLE tblRegoFormNotifications (
    intRegoFormNotificationID INT NOT NULL AUTO_INCREMENT,
    intEntityTypeID INT NOT NULL,
    intEntityID INT NOT NULL,
    intRegoFormID INT DEFAULT 0,
    dtCreated DATETIME DEFAULT NULL,
    strTitle VARCHAR(200) DEFAULT '',
    intNotifiedStatus TINYINT(4) DEFAULT 0,
    dtNotified DATETIME DEFAULT NULL,

    PRIMARY KEY (intRegoFormNotificationID)
);
