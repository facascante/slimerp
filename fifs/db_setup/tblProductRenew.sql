DROP TABLE IF EXISTS `tblProductRenew`;
CREATE TABLE `tblProductRenew` (
  `intProductID` int(11) NOT NULL,
  `strRenewText1` text,
  `strRenewText2` text,
  `strRenewText3` text,
  `strRenewText4` text,
  `strRenewText5` text,
  `intRenewDays1` int(11) DEFAULT '0',
  `intRenewDays2` int(11) DEFAULT '0',
  `intRenewDays3` int(11) DEFAULT '0',
  `intRenewDays4` int(11) DEFAULT '0',
  `intRenewDays5` int(11) DEFAULT '0',
  `intRenewProductID` int(11) NOT NULL DEFAULT '0',
  `intRenewRegoFormID` int(11) NOT NULL DEFAULT '0',
  PRIMARY KEY (`intProductID`),
  KEY `index_renewproduct` (`intRenewProductID`)
) DEFAULT CHARSET=utf8;

