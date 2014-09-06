CREATE TABLE `tblTempMember` (
`intTempMemberID` int(11) NOT NULL AUTO_INCREMENT,
`intRealID`  int(11) DEFAULT '0',
`strSessionKey` char(40) NOT NULL,
`strJson` text NOT NULL,
`strTransactions` varchar(255) DEFAULT '',
`intFormID` int(11) NOT NULL,
`intAssocID` int(11) NOT NULL,
`intClubID` int(11) NOT NULL,
`intTeamID` int(11) NOT NULL,
`intNum` int(11) NOT NULL,
`intStatus` tinyint(4) DEFAULT '0',
`intLevel` tinyint(4) DEFAULT '0',
`intTransLogID` int(11) NOT NULL,
`tTimestamp` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
PRIMARY KEY (`intTempMemberID`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

