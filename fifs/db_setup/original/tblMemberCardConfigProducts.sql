DROP TABLE IF EXISTS tblMemberCardConfigProducts;
CREATE TABLE tblMemberCardConfigProducts	(
	intMemberCardConfigID INT NOT NULL,
	intProductID INT NOT NULL,
	intTXNStatus TINYINT DEFAULT 1,

	PRIMARY KEY (intMemberCardConfigID, intProductID)

);

