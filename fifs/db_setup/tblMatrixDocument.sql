CREATE TABLE `tblMatrixDocument` (
    intMatrixID INT NOT NULL,
    intDocumentTypeID INT NOT NULL,
    intRequired TINYINT DEFAULT 0,
    intApprovalLevel TINYINT DEFAULT 0,
    intAllowExisting TINYINT DEFAULT 0,

    tTimeStamp timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

  PRIMARY KEY (intMatrixID, intDocumentTypeID)
) DEFAULT CHARSET=utf8;
