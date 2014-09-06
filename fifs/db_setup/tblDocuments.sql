DROP TABLE IF EXISTS tblDocuments;
CREATE TABLE tblDocuments (
    intDocumentID int NOT NULL AUTO_INCREMENT,
    intDocumentTypeID INT DEFAULT 0,
    intEntityLevel tinyint default 0, /*Person, Entity */
    intEntityID INT DEFAULT 0, /* ID of the Person, Entity*/
    strApprovalStatus TINYINT DEFAULT 0, /* PENDING , APPROVED, REJECTED */
    strDeniedNotes  TEXT default '',
    dtAdded datetime,
    strPath VARCHAR(50) NOT NULL,
    strFilename VARCHAR(50) NOT NULL,
    strOrigFilename VARCHAR(250) NOT NULL,
    strExtension CHAR(4),
    intBytes INT DEFAULT 1,
    tTimeStamp timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

  PRIMARY KEY (intDocumentID),
  KEY index_DocumentType(intDocumentID),
  KEY index_Entity(intEntityLevel , intEntityID),
) DEFAULT CHARSET=utf8;

