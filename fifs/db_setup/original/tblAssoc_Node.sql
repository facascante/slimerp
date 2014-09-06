DROP TABLE tblAssoc_Node;
 
CREATE table tblAssoc_Node (
    intAssocID  INT NOT NULL,
    intNodeID   INT NOT NULL,
	intPrimary	TINYINT NOT NULL DEFAULT 1,
PRIMARY KEY (intNodeID, intAssocID),
KEY index_intAssocID(intAssocID),
KEY index_intPrimary (intPrimary),
KEY index_intNodeID(intNodeID)
);
 
