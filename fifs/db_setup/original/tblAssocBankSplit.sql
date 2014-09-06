DROP TABLE IF EXISTS `tblAssocBankSplit`;
CREATE TABLE `tblAssocBankSplit` (
	intAssocSplitID int(11) NOT NULL auto_increment,
	intAssocID int(11) NOT NULL default 0,
	intSplitID int(11) NOT NULL default 0,
	intProductID int(11) default 0,
  	intRealmID int(11) default NULL,
	strDescription varchar(100) default '',

	curMinAmountCheck decimal(16,2) default 0,

	curAmount_1 decimal(16,2) default 0,
	intUseRemainder_1 tinyint(4) default 0,
  	strBSB_1 varchar(10) default NULL,
  	strAccountName_1 varchar(100) default NULL,
  	strAccountNum_1 varchar(20) default NULL,
	strFILE_TransCode_1 varchar(2) default '',
	strFILE_AccountTitle_1 varchar(40) default '',
	strFILE_RemitterName_1 varchar(20) default '',

	curAmount_2 decimal(16,2) default 0,
	intUseRemainder_2 tinyint(4) default 0,
  	strBSB_2 varchar(10) default NULL,
  	strAccountName_2 varchar(100) default NULL,
  	strAccountNum_2 varchar(20) default NULL,
	strFILE_TransCode_2 varchar(2) default '',
	strFILE_AccountTitle_2 varchar(40) default '',
	strFILE_RemitterName_2 varchar(20) default '',

	curAmount_3 decimal(16,2) default 0,
	intUseRemainder_3 tinyint(4) default 0,
  	strBSB_3 varchar(10) default NULL,
  	strAccountName_3 varchar(100) default NULL,
  	strAccountNum_3 varchar(20) default NULL,
	strFILE_TransCode_3 varchar(2) default '',
	strFILE_AccountTitle_3 varchar(40) default '',
	strFILE_RemitterName_3 varchar(20) default '',

	curAmount_4 decimal(16,2) default 0,
	intUseRemainder_4 tinyint(4) default 0,
  	strBSB_4 varchar(10) default NULL,
  	strAccountName_4 varchar(100) default NULL,
  	strAccountNum_4 varchar(20) default NULL,
	strFILE_TransCode_4 varchar(2) default '',
	strFILE_AccountTitle_4 varchar(40) default '',
	strFILE_RemitterName_4 varchar(20) default '',

	tTimeStamp TIMESTAMP,

  PRIMARY KEY  (`intAssocSplitID`),
  KEY `index_intSplitID` (`intSplitID`),
  KEY `index_realmID` (`intRealmID`),
  KEY `index_intAssocID` (`intAssocID`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

