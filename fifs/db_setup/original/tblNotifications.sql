DROP TABLE IF EXISTS tblNotifications;
CREATE TABLE tblNotifications (
	intNotificationID INT NOT NULL AUTO_INCREMENT,
	intEntityTypeID INT NOT NULL,
	intEntityID INT NOT NULL,
	dtDateTime DATETIME,
	strNotificationType VARCHAR(30) DEFAULT '',
	strTitle VARCHAR(100) DEFAULT '',
	intReferenceID INT NOT NULL DEFAULT 0,
	strMoreInfo TEXT DEFAULT '',
	strURL VARCHAR(250) NOT NULL DEFAULT '',

	PRIMARY KEY (intNotificationID),
	UNIQUE KEY index_unique( intEntityTypeID, intEntityID, strNotificationType, intReferenceID)
);
