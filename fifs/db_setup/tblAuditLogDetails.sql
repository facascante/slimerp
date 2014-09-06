DROP TABLE IF EXISTS `tblAuditLogDetails`;
CREATE TABLE `tblAuditLogDetails` (
  `intAuditLogDetailsID` int(11) NOT NULL AUTO_INCREMENT,
  `intAuditLogID` int(11) NOT NULL,
  `strField` varchar(30) DEFAULT '',
  `strPreviousValue` varchar(90) DEFAULT '',
  PRIMARY KEY (`intAuditLogDetailsID`),
  KEY `index_intAuditLogID` (`intAuditLogID`)
) DEFAULT CHARSET=utf8;
