DROP TABLE IF EXISTS `tblRegoForm`;
CREATE TABLE `tblRegoForm` (
  `intRegoFormID` int(11) NOT NULL AUTO_INCREMENT,
  `intRealmID` int(11) NOT NULL DEFAULT '0',
  `intSubRealmID` int(11) NOT NULL DEFAULT '0',
  `intEntityID` int(11) NOT NULL DEFAULT '0',

  `strRegoFormName` text,
  `intRegoType` int(11) NOT NULL DEFAULT '0',
  `intRegoTypeLevel` int(11) DEFAULT '0',
  `intNewRegosAllowed` int(11) NOT NULL DEFAULT '0',
  `intStatus` tinyint(4) DEFAULT '1',
  `intAllowMultipleAdult` tinyint(4) DEFAULT '0',
  `intAllowMultipleChild` tinyint(4) DEFAULT '0',
  `intPreventTypeChange` tinyint(4) DEFAULT '0',
  `intAllowClubSelection` tinyint(4) DEFAULT '0',
  `intClubMandatory` tinyint(4) DEFAULT '0',
  `dtCreated` datetime DEFAULT NULL,
  `tTimeStamp` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `strTitle` varchar(100) DEFAULT '',
  `intNewBits` smallint(6) DEFAULT NULL,
  `intRenewalBits` smallint(6) DEFAULT NULL,
  `intPaymentBits` smallint(6) DEFAULT NULL,
  `intPaymentCompulsory` tinyint(4) DEFAULT '0',
  PRIMARY KEY (`intRegoFormID`),
  KEY `index_intEntityID` (`intEntityID`),
  KEY `index_intRegoType` (`intRegoType`)
) DEFAULT CHARSET=utf8;
