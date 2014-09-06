-- DROP TABLE IF EXISTS `tblMemberRecordType`;
CREATE TABLE IF NOT EXISTS `tblMemberRecordType` (
  `intMemberRecordTypeID` int(11) NOT NULL AUTO_INCREMENT,
  `intMemberRecordTypeParentID` int(11) NOT NULL DEFAULT 0,
  `strName` varchar(100) NOT NULL,
  `intEntityTypeID` int(11) NOT NULL DEFAULT 0,
  `intEntityID` int(11) NOT NULL DEFAULT 0,
  `intRealmID` int(11) NOT NULL DEFAULT 0,
  `intSubRealmID` int(11) DEFAULT 0,
  `intLinkable` int(11) NOT NULL DEFAULT 1,
  `strNote` VARCHAR(255) NULL,
  `intStatus` int(11) NOT NULL DEFAULT 0,
  `intRecStatus` int(11) NOT NULL DEFAULT 0,
  `dtCreated` date DEFAULT NULL,
  `tTimeStamp` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`intMemberRecordTypeID`)
) ENGINE=InnoDB  DEFAULT CHARSET=latin1 AUTO_INCREMENT=0 ;

INSERT INTO `tblMemberRecordType` (`intMemberRecordTypeID`, `intMemberRecordTypeParentID`, `strName`, `intEntityTypeID`, `intEntityID`, `intRealmID`, `intSubRealmID`, `intLinkable`, `intStatus`, `dtCreated`) VALUES
(-1, -1, 'No Parent', 0, 0, 0, 0, 1, 0, SYSDATE()),
(1, -1, 'Player', 100, 3868, 35, 0, 1, 0, SYSDATE()),
(2, -1, 'Coach', 100, 3868, 35, 0, 1, 0, SYSDATE()),
(3, 1, 'Junior Player', 5, 14291, 35, 0, 1, 0, SYSDATE()),
(4, 1, 'Senior Player', 5, 14291, 35, 0, 1, 0, SYSDATE()),
(5, 2, 'Junior Coach', 5, 14291, 35, 0, 1, 0, SYSDATE()),
(6, 2, 'Senior Coach', 5, 14291, 35, 0, 1, 0, SYSDATE()),
(7, 3, 'A - Junior Player', 3, 95758, 35, 0, 1, 0, SYSDATE()),
(8, 3, 'B - Junior Player', 3, 95758, 35, 0, 1, 0, SYSDATE()),
(9, 4, 'A - Senior Player', 3, 95758, 35, 0, 1, 0, SYSDATE()),
(10, 4, 'B - Senior Player', 3, 95758, 35, 0, 1, 0, SYSDATE());
