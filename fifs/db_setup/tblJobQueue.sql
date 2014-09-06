CREATE TABLE tblJobQueue(
    intTaskID int NOT NULL AUTO_INCREMENT,
    intRealmID  INT DEFAULT 0,
    
    strTaskType VARCHAR(30) NOT NULL DEFAULT, /* APPROVEDOC, APPROVEMEMBER,APROVEVENUE, HANDLEREJECTION */
    intMatrixID INT NOT NULL,
    intApprovalStatus INT default 0, /* pending, Approved, Denied */
    strReviewNotes text, /* extended review notes */

    /* IDs the task is related to */
    intEntityID INT NOT NULL default 0,
    intPersonID INT NOT NULL default 0,
    intDocumentID INT NOT NULL default 0,
    intPersonRegistrationID INT NOT NULL default 0,

    dtAdded DATETIME, 
    dtCompleted DATETIME, 

    tTimeStamp timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

  PRIMARY KEY (intTaskID),
) DEFAULT CHARSET=utf8;
