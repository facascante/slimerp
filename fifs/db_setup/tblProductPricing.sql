DROP TABLE IF EXISTS `tblProductPricing`;
CREATE TABLE `tblProductPricing` (
  `intProductPricingID` int(11) NOT NULL AUTO_INCREMENT,
  `curAmount` decimal(12,2) DEFAULT '0.00',
  `intProductID` int(11) DEFAULT '0',
  `intRealmID` int(11) DEFAULT '0',
  `intID` int(11) DEFAULT '0',
  `intLevel` int(11) DEFAULT '0',
  `intPricingType` tinyint(4) DEFAULT '0',
  `curAmount_Adult1` decimal(12,2) DEFAULT '0.00',
  `curAmount_Adult2` decimal(12,2) DEFAULT '0.00',
  `curAmount_Adult3` decimal(12,2) DEFAULT '0.00',
  `curAmount_AdultPlus` decimal(12,2) DEFAULT '0.00',
  `curAmount_Child1` decimal(12,2) DEFAULT '0.00',
  `curAmount_Child2` decimal(12,2) DEFAULT '0.00',
  `curAmount_Child3` decimal(12,2) DEFAULT '0.00',
  `curAmount_ChildPlus` decimal(12,2) DEFAULT '0.00',
  PRIMARY KEY (`intProductPricingID`),
  UNIQUE KEY `index_Dupe` (`intProductID`,`intID`,`intLevel`),
  KEY `index_intRealmID` (`intRealmID`),
  KEY `index_intID` (`intID`),
  KEY `index_intProductID` (`intProductID`),
  KEY `index_intLevel` (`intLevel`)
) DEFAULT CHARSET=utf8;

