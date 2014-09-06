DROP TABLE IF EXISTS tblTempNodeAssocs;
CREATE table tblTempNodeAssocs (
	intRealmID INT NOT NULL DEFAULT 0,
	intNodeID INT NOT NULL DEFAULT 0,
	intAssocID INT NOT NULL DEFAULT 0,

	PRIMARY KEY (intRealmID, intNodeID,intAssocID)
);
 
