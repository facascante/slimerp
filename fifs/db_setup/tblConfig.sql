DROP TABLE IF EXISTS `tblConfig`;
CREATE TABLE `tblConfig` (
  `intConfigID` int(11) NOT NULL AUTO_INCREMENT,
  `intEntityID` int(11) NOT NULL DEFAULT '0',
  `intLevelID` int(11) NOT NULL DEFAULT '0',
  `intTypeID` int(11) NOT NULL DEFAULT '0',
  `strPerm` varchar(40) DEFAULT NULL,
  `strValue` varchar(250) DEFAULT NULL,
  `tTimeStamp` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `intRealmID` int(11) NOT NULL DEFAULT '0',
  `intSubTypeID` int(11) NOT NULL DEFAULT '0',
  `strType` varchar(20) DEFAULT '',
  PRIMARY KEY (`intConfigID`),
  KEY `index_Entity` (`intLevelID`,`intEntityID`),
  KEY `index_EntityType` (`intLevelID`,`intEntityID`,`intTypeID`),
  KEY `index_EntityTypePerm` (`intLevelID`,`intEntityID`,`intTypeID`,`strPerm`),
  KEY `index_intRealmID` (`intRealmID`),
  KEY `index_multi` (`intRealmID`,`intLevelID`,`intEntityID`,`intTypeID`)
) DEFAULT CHARSET=utf8;

