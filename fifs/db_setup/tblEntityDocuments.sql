DROP TABLE IF EXISTS tblEntityDocuments;
CREATE TABLE tblEntityDocuments(
    intDocumentTypeID INT DEFAULT 0,
    intEntityLevel tinyint default 0, /*Region, Club*/
    intEntityType int default 0, /* Club, School */
    intRequired TINYINT DEFAULT 0, /* 1 = Yes */

  PRIMARY KEY (intDocumentTypeID, intEntityLevel, intEntityType)
) DEFAULT CHARSET=utf8;

