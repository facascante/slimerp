DROP TABLE IF EXISTS tblPassportMember;
CREATE TABLE tblPassportMember (
	intPassportID INT NOT NULL,
	intMemberID INT NOT NULL,
	tTimeStamp TIMESTAMP,

	PRIMARY KEY (intPassportID, intMemberID),
	KEY index_member(intMemberID)
);
