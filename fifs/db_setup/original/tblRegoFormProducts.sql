drop table if exists tblRegoFormProducts;
CREATE table tblRegoFormProducts (
  intRegoFormProductsID      INT NOT NULL AUTO_INCREMENT, 
  intAssocID  INT NOT NULL,
  intRealmID INT NOT NULL,
  intSubRealmID INT NOT NULL DEFAULT 0,
	intProductID INT NOT NULL,

PRIMARY KEY (intRegoFormProductsID),
	KEY index_intRealmID (intRealmID, intSubRealmID),
	KEY index_intAssocID (intAssocID)
);
 
