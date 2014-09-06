DROP TABLE tblAssoc_Clubs;
 
#
# Table               : tblAssoc_Clubs
# Description         : Clubs the Association has.
#---------------------
# intAssocClubID      : Automatic Association Club ID 
# intAssocID          : Association ID
# intClubID           : Club ID 
#
CREATE table tblAssoc_Clubs (
    intAssocClubID   INT NOT NULL AUTO_INCREMENT,
    intAssocID       INT NOT NULL,
    intClubID        INT NOT NULL,
PRIMARY KEY (intAssocClubID),
KEY index_intAssocID(intAssocID),
KEY index_intClubID(intClubID)
);
 
