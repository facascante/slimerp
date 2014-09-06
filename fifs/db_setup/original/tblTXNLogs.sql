--
-- Table structure for table `tblTXNLogs`
--

DROP TABLE IF EXISTS `tblTXNLogs`;
CREATE TABLE `tblTXNLogs` (
	intTXNID int(11) NOT NULL default '0',
	intTLogID int(11) NOT NULL default '0',
	tTimeStamp TIMESTAMP,
  PRIMARY KEY  (intTXNID,intTLogID)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
