DROP TABLE tblDefMembTypes;

#
# Table               : tblDefMembTypes
# Description         : Member Types Definitions
#---------------------
# intMembTypesNO      : Member Type Number
# intAssocID	      : Association ID
# intMembType	      : Member Types ID
# strName	      : Name of Code
#

CREATE table tblDefMembTypes (
    intMemberTypeNO INTEGER NOT NULL AUTO_INCREMENT,
    intAssocID	    INTEGER NOT NULL DEFAULT 0,
    intMembType	    INTEGER NOT NULL DEFAULT 0,
    strName         VARCHAR (50) NOT NULL,
PRIMARY KEY (intMemberTypeNO),
KEY index_lookup(intMembType, intAssocID)
);
