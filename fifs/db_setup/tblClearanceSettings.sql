DROP TABLE tblClearanceSettings;

CREATE TABLE `tblClearanceSettings` (
  `intClearanceSettingID` int(11) NOT NULL AUTO_INCREMENT,
  `intID` int(11) NOT NULL DEFAULT '0',
  `intTypeID` int(11) NOT NULL DEFAULT '0',
  `intAssocTypeID` int(11) DEFAULT '0',
  `intAutoApproval` int(11) NOT NULL DEFAULT '0',
  `curDefaultFee` decimal(12,2) DEFAULT NULL,
  `dtDOBStart` datetime DEFAULT NULL,
  `dtDOBEnd` datetime DEFAULT NULL,
  `tTimeStamp` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `intRuleDirection` tinyint(4) DEFAULT '0',
  `intCheckAssocID` int(11) DEFAULT '0',
  `intPrimaryApprover` tinyint(4) DEFAULT '0',
  `intClearanceType` tinyint(4) DEFAULT '0',
  PRIMARY KEY (`intClearanceSettingID`),
  KEY `index_intID` (`intID`),
  KEY `index_intAssocTypeID` (`intAssocTypeID`),
  KEY `index_intTypeID` (`intTypeID`)
) DEFAULT CHARSET=utf8;
