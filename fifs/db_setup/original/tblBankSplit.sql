DROP TABLE IF EXISTS `tblBankSplit`;
CREATE TABLE `tblBankSplit` (
	intSplitID int(11) NOT NULL auto_increment,
	strSplitName varchar(100) default '',
	strFILE_Header_FinInst varchar(10) default '',
	strFILE_Header_UserName varchar(30) default '',
	strFILE_Header_UserNumber varchar(30) default '',
	strFILE_Header_Desc varchar(30) default '',
	
  	intRealmID int(11) default NULL,
	tTimeStamp TIMESTAMP,

  PRIMARY KEY  (`intSplitID`),
  KEY `index_realmID` (`intRealmID`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

