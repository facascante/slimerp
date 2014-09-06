DROP TABLE IF EXISTS tblPersonNotes;
CREATE TABLE tblPersonNotes (
    intPersonID INT NOT NULL,
    strNotes    TEXT default '',
    tTimeStamp            TIMESTAMP,

  PRIMARY KEY (intPersonID)
);

