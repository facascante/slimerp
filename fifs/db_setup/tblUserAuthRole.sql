DROP TABLE IF EXISTS tblUserAuthRole;
CREATE TABLE `tblUserAuthRole` (
  `userId` int(10) unsigned NOT NULL,
  `entityTypeId` int(11) NOT NULL,
  `entityId` int(11) NOT NULL,
  `roleId` int(11) NOT NULL,
  PRIMARY KEY (`userId`,`entityTypeId`,`entityId`,`roleId`)
) DEFAULT CHARSET=utf8;

