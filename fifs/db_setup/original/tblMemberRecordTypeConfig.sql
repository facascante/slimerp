DROP TABLE IF EXISTS `tblMemberRecordTypeConfig`;

CREATE TABLE IF NOT EXISTS `tblMemberRecordTypeConfig` (
  `intMemberRecordTypeConfigID` int(11) NOT NULL AUTO_INCREMENT,
  `intEntityTypeID` int(11) NOT NULL DEFAULT 0,
  `intEntityID` int(11) NOT NULL DEFAULT 0,
  `intRealmID` int(11) NOT NULL DEFAULT 0,
  `intSubRealmID` int(11) NOT NULL DEFAULT 0,
  `strName` varchar(255) NOT NULL,
  `strValue` varchar(255) NOT NULL,
  PRIMARY KEY (`intMemberRecordTypeConfigID`)
) ENGINE=InnoDB  DEFAULT CHARSET=latin1 AUTO_INCREMENT=0 ;
