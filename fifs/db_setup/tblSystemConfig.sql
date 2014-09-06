DROP TABLE IF EXISTS tblSystemConfig ;
 
CREATE TABLE `tblSystemConfig` (
  `intSystemConfigID` int(11) NOT NULL AUTO_INCREMENT,
  `intTypeID` smallint(6) NOT NULL DEFAULT '0',
  `strOption` varchar(100) NOT NULL DEFAULT '',
  `strValue` varchar(250) NOT NULL DEFAULT '',
  `tTimeStamp` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `intRealmID` int(11) DEFAULT NULL,
  `intSubTypeID` int(11) NOT NULL DEFAULT '0',
  PRIMARY KEY (`intSystemConfigID`),
  KEY `index_TypeID` (`intTypeID`),
  KEY `index_strOption` (`strOption`),
  KEY `index_TypeOption` (`intTypeID`,`strOption`),
  KEY `index_intRealm` (`intRealmID`),
  KEY `index_RealmOption` (`intRealmID`,`strOption`)
) DEFAULT CHARSET=utf8;
