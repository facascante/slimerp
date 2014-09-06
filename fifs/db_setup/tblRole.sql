CREATE TABLE `tblRole` (
  `intRoleID` int(11) NOT NULL AUTO_INCREMENT,
  `intEntityID` int(11) NOT NULL DEFAULT '0',
  `intRealmID` int(11) NOT NULL DEFAULT '0',
  `strTitle` varchar(100) NOT NULL DEFAULT '',
  `dtDeletedDate` datetime DEFAULT NULL,
  `tTimeStamp` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`intRealmID`,`intRoleID`),
  KEY `index_intEntityID` (`intRoleID`)
) DEFAULT CHARSET=utf8;
