CREATE TABLE `tblQualification` (
  `intQualificationID` int(11) NOT NULL AUTO_INCREMENT,
  `strName` varchar(150) DEFAULT NULL,
  `intType` int(11) DEFAULT NULL,
  `intDefaultLength` int(11) DEFAULT NULL,
  `intMinLevel` int(11) DEFAULT NULL,
  `intRealmID` int(11) DEFAULT NULL,
  `intEntityType` int(11) DEFAULT NULL,
  `intEntityID` int(11) DEFAULT NULL,
  `intEducationID` int(11) DEFAULT NULL,
  `intRecStatus` int(11) DEFAULT '1',
  `tTimeStamp` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`intQualificationID`),
  INDEX index_realm (intRealmID),
  INDEX index_RealmStatus (intRealmID, intRecStatus)
);
