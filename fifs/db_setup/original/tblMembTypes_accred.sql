DROP TABLE IF EXISTS tblMembTypes_accred;
 
#
# Table               : tblMembTypes_accred
# Description         : Member Information for all Accreditations 
#---------------------

CREATE table tblMembTypes_accred (
    intAccredNO        INT NOT NULL AUTO_INCREMENT,
    intAssocID         INT NOT NULL,
    intExtKey          INT NOT NULL,
    intMemberNO        INT NOT NULL,
    intMemberTypes     INT NOT NULL,
    intSportID         INT NOT NULL,
    intTypeID          INT NOT NULL,
    intLevelID         INT NOT NULL,
    dtDate             DATE,
    dtExpiry           DATE,
    strStatus          VARCHAR(10),
PRIMARY KEY (intAccredNO),
KEY index_intAssocID(intMemberNO),
KEY index_intMemberID(intTypeID),
KEY index_intTypeID(intLevelID)
);
 
