DROP TABLE IF EXISTS tblCustomReportsUser;

CREATE table tblCustomReportsUser (
    intCustomReportID   INT NOT NULL,
    intUserID        	INT NOT NULL,
    intUserTypeID      	INT NOT NULL,
    intRealmID		INT NOT NULL,
    intSubRealmID INT NOT NULL,

PRIMARY KEY (intRealmID, intSubRealmID, intUserTypeID, intUserID, intCustomReportID)
);
