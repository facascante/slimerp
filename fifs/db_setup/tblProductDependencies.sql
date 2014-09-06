DROP TABLE IF EXISTS `tblProductDependencies`;
CREATE TABLE `tblProductDependencies` (
  `intProductDependencyID` int(11) NOT NULL AUTO_INCREMENT,
  `intProductID` int(11) NOT NULL,
  `intDependentProductID` int(11) NOT NULL,
  `intRealmID` int(11) DEFAULT '0',
  `intID` int(11) DEFAULT '0',
  `intLevel` int(11) DEFAULT '0',
  PRIMARY KEY (`intProductDependencyID`),
  KEY `index_intRealmID` (`intRealmID`),
  KEY `index_intIDLevel` (`intID`,`intLevel`),
  KEY `index_intProductID` (`intProductID`)
) DEFAULT CHARSET=utf8;
