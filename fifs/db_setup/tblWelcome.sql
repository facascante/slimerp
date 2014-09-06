DROP TABLE tblWelcome;

CREATE TABLE `tblWelcome` (
  `intWelcomeID` int(11) NOT NULL AUTO_INCREMENT,
  `intRealmID` int(11) NOT NULL DEFAULT '0',
  `intEntityID` int(11) NOT NULL DEFAULT '0',
  `strWelcomeText` mediumtext,
  `intRealmSubTypeID` int(11) DEFAULT '0',
  PRIMARY KEY (`intWelcomeID`),
  KEY `index_intRealmEntity` (`intRealmID`,`intEntityID`)
) DEFAULT CHARSET=utf8;

