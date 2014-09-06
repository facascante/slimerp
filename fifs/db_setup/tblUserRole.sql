DROP TABLE IF EXISTS tblUserRole;
CREATE TABLE `tblUserRole` (
  `roleID` int(11) NOT NULL AUTO_INCREMENT,
  `entityID` int(11) NOT NULL DEFAULT '0',
  `title` varchar(100) NOT NULL DEFAULT '',
  `dtDeletedDate` datetime DEFAULT NULL,
  `tTimeStamp` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`roleID`),
  KEY `index_intEntityID` (`entityID`)
) DEFAULT CHARSET=utf8;