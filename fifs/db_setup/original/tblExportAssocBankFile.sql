DROP TABLE IF EXISTS `tblExportAssocBankFile`;
CREATE TABLE `tblExportAssocBankFile` (
	intExportID int(11) NOT NULL auto_increment,
  	intExportBankFileID int(11) default NULL,
  	intSplitID int(11) default NULL,
  	intRealmID int(11) default NULL,
  	intAssocID int(11) default NULL,
  	intProductID int(11) default NULL,
	tTimeStamp TIMESTAMP,
	dtRun datetime,

  PRIMARY KEY  (`intExportID`),
  KEY `index_splitID` (`intSplitID`),
  KEY `index_exportBankFileID` (`intExportBankFileID`),
  KEY `index_assocID` (`intAssocID`),
  KEY `index_productID` (`intProductID`),
  KEY `index_realmID` (`intRealmID`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

