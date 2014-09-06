DROP TABLE IF EXISTS `tblDefCodes`;
CREATE TABLE `tblDefCodes` (
  `intCodeID` int(11) NOT NULL AUTO_INCREMENT,
  `intAssocID` int(11) NOT NULL DEFAULT '0',
  `intType` int(11) DEFAULT NULL,
  `strName` varchar(100) DEFAULT '',
  `tTimeStamp` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `intRealmID` int(11) NOT NULL DEFAULT '0',
  `intRecStatus` tinyint(4) DEFAULT '0',
  `intSubTypeID` int(11) DEFAULT '0',
  `intDisplayOrder` smallint(6) DEFAULT '0',
  PRIMARY KEY (`intCodeID`),
  KEY `index_intAssocID` (`intAssocID`),
  KEY `index_intAssocIDTypeID` (`intAssocID`,`intType`),
  KEY `index_strName` (`strName`),
  KEY `index_Lookup` (`intAssocID`,`intType`),
  KEY `IDNEX_intRecStatus` (`intRecStatus`),
  KEY `index_intRealmAssoc` (`intRealmID`,`intAssocID`),
  KEY `index_intRealmAssocType` (`intRealmID`,`intAssocID`,`intType`)
) DEFAULT CHARSET=utf8;

