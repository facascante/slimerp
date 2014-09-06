DROP TABLE IF EXISTS `tblDuplChanges`;
CREATE TABLE `tblDuplChanges` (
  `intDuplChangesID` int(11) NOT NULL AUTO_INCREMENT,
  `intEntityID` int(11) NOT NULL DEFAULT '0',
  `intOldID` int(11) NOT NULL DEFAULT '0',
  `intNewID` int(11) NOT NULL DEFAULT '0',
  `tTimeStamp` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `intISSUE` int(11) DEFAULT '0',
  PRIMARY KEY (`intDuplChangesID`),
  KEY `index_intEntityIDtstamp` (`intEntityID`,`tTimeStamp`),
  KEY `index_intOldID` (`intOldID`),
  KEY `index_intNewID` (`intNewID`),
  KEY `index_intEntityIDtstampNew` (`intEntityID`,`tTimeStamp`,`intNewID`),
  KEY `index_intEntityIDtstampOld` (`intEntityID`,`tTimeStamp`,`intOldID`)
) DEFAULT CHARSET=utf8;

