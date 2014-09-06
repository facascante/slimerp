CREATE TABLE tblToDo (
    intToDoID int NOT NULL AUTO_INCREMENT,
    intRealmID  INT DEFAULT 0,

    /* Who is doing the task */
    intOwnerEntityID INT DEFAULT 0, /* ID of the Person, Entity*/
    intOwnerEntityLevel INT DEFAULT 0,
    intOwnerRoleID INT DEFAULT 0,

    /* IDs the task is related to */
    intEntityID INT NOT NULL default 0,
    intPersonID INT NOT NULL default 0,
    intDocumentID INT NOT NULL default 0,
    intPersonRegistrationID INT NOT NULL default 0,

    strTaskType VARCHAR(30) NOT NULL DEFAULT, /* APPROVEDOC, APPROVEMEMBER,APROVEVENUE, HANDLEREJECTION */

    strStatus VARCHAR(30) DEFAULT '', /*pending, approved, rejected*/
    strNotes text NOT NULL default '',

    dtAdded DATETIME, 
    dtCompleted DATETIME, 

    tTimeStamp timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,


  PRIMARY KEY (intTaskID),
) DEFAULT CHARSET=utf8;
