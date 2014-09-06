DROP TABLE IF EXISTS tblMemberCardPrinted;
CREATE TABLE tblMemberCardPrinted (
  intMemberCardPrintedID int(11) NOT NULL auto_increment,
	intMemberCardConfigID INT NOT NULL,
	intMemberID INT NOT NULL,
  dtPrinted datetime default NULL,
  strUsername varchar(30) default NULL,
  intQty int(11) default '1',
  intCount int(11) default '1',
  PRIMARY KEY  (intMemberCardPrintedID),
  KEY key_intMemberID (intMemberID, intMemberCardConfigID),
  KEY key_intCardType (intMemberCardConfigID)
);

