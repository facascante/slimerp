CREATE TABLE `tblRolePerson` (
  `intRolePersonID` int(11) NOT NULL AUTO_INCREMENT,
  `intPersonID` int(11) NOT NULL,
  `intRoleID` int(11) NOT NULL,
  `intEntityID` int(11) NOT NULL,
  `dtDeletedDate` datetime DEFAULT NULL,
  `tTimeStamp` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`intPersonID`,`intRolePersonID`),
  KEY `index_intRolePersonID` (`intRolePersonID`)
) DEFAULT CHARSET=utf8;
