DROP TABLE IF EXISTS tblSystemConfigBlob ;
 
CREATE TABLE `tblSystemConfigBlob` (
  `intSystemConfigID` int(11) NOT NULL DEFAULT '0',
  `strBlob` text NOT NULL,
  PRIMARY KEY (`intSystemConfigID`)
) DEFAULT CHARSET=utf8;
