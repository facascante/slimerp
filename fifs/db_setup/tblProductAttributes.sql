DROP TABLE IF EXISTS `tblProductAttributes`;
CREATE TABLE `tblProductAttributes` (
  `intProductAttributeID` int(11) NOT NULL AUTO_INCREMENT,
  `intProductID` int(11) NOT NULL,
  `intAttributeType` int(11) NOT NULL,
  `strAttributeValue` varchar(50) NOT NULL,
  `intRealmID` int(11) DEFAULT '0',
  `intID` int(11) DEFAULT '0',
  `intLevel` int(11) DEFAULT '0',
  PRIMARY KEY (`intProductAttributeID`),
  KEY `index_intRealmID` (`intRealmID`),
  KEY `index_intIDLevel` (`intID`,`intLevel`),
  KEY `index_intProductID` (`intProductID`)
) DEFAULT CHARSET=utf8;

