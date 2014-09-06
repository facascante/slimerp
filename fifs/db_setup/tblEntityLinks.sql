CREATE table tblEntityLinks (
    intEntityLinksID   INT NOT NULL AUTO_INCREMENT,
    intParentEntityID  INT NOT NULL,
    intChildEntityID 	 INT NOT NULL,
	intPrimary			 TINYINT NOT NULL DEFAULT 1,
    tTimeStamp timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

PRIMARY KEY (intEntityLinksID),
KEY index_intParentEntityID (intParentEntityID),
KEY index_intChildEntityID (intChildEntityID),
KEY index_intPrimary(intPrimary)
);
 
