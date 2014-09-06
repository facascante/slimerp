DROP TABLE IF EXISTS tblVerifiedEmail ;
CREATE TABLE tblVerifiedEmail	(
	strEmail VARCHAR(255),
	dtVerified DATETIME,
	strKey VARCHAR(20),
PRIMARY KEY (strEmail)
);
