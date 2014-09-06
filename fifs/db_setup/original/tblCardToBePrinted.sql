DROP TABLE IF EXISTS tblCardToBePrinted;
CREATE TABLE tblCardToBePrinted	(
	intMemberID INT NOT NULL,
	intMemberCardConfigID INT NOT NULL,

PRIMARY KEY (intMemberID, intMemberCardConfigID),
KEY index_cardtype (intMemberCardConfigID)

);
