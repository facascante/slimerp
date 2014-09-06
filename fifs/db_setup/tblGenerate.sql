DROP TABLE tblGenerate;
CREATE TABLE `tblGenerate` (
  `intGenerateID` int(11) NOT NULL AUTO_INCREMENT,
  `intMemberLength` int(11) DEFAULT '5',
  `strMemberPrefix` varchar(40) NOT NULL DEFAULT '',
  `strMemberSuffix` varchar(40) NOT NULL DEFAULT '',
  `intMaxNum` int(11) DEFAULT '10000',
  `intCurrentNum` int(11) NOT NULL DEFAULT '100',
  `intAlphaCheck` int(11) DEFAULT '0',
  `intGenType` int(11) DEFAULT '0',
  `intMinNum` int(11) NOT NULL DEFAULT '0',
  `tTimeStamp` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `intRealmID` int(11) NOT NULL DEFAULT '0',
  PRIMARY KEY (`intGenerateID`)
) DEFAULT CHARSET=utf8;

