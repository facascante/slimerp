CREATE table tblEntityCategories	(
    intEntityCategoryID	INT NOT NULL AUTO_INCREMENT,
    intRealmID       INT NOT NULL,
    intSubRealmID       INT NOT NULL,
    intAssocID 				INT DEFAULT 0,
    intEntityType 		TINYINT,
		strCategoryName		VARCHAR(100),
		strCategoryDesc		TEXT,
		tTimeStamp        TIMESTAMP,
PRIMARY KEY (intEntityCategoryID),
KEY index_intRealm(intRealmID, intSubRealmID),
KEY index_intEntityType(intEntityType)
);
 
