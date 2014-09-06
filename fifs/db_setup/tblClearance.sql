DROP TABLE tblClearance;

CREATE TABLE tblClearance (
  intClearanceID int(11) NOT NULL AUTO_INCREMENT,
  intPersonID int(11) NOT NULL DEFAULT '0',
  intDestinationEntityID int(11) NOT NULL DEFAULT '0',
  strDestinationEntityName varchar(100) DEFAULT NULL,
  intSourceEntityID int(11) NOT NULL DEFAULT '0',
  strSourceEntityName varchar(100) DEFAULT NULL,
  intRealmID int(11) NOT NULL DEFAULT '0',
  intCurrentPathID int(11) NOT NULL DEFAULT '0',
  strPhoto varchar(100) DEFAULT NULL,
  dtApplied datetime DEFAULT NULL,
  tTimeStamp timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  strReasonForClearance text,
  strOtherNotes text,
  intClearanceStatus int(11) DEFAULT NULL,
  dtFinalised datetime DEFAULT NULL,
  intReasonForClearanceID int(11) DEFAULT '0',
  intCreatedFrom int(11) DEFAULT '0',
  strFilingNumber varchar(20) DEFAULT '',
  intClearancePriority int(11) DEFAULT '0',
  intRecStatus int(11) DEFAULT '0',
  intPlayerActive tinyint(4) DEFAULT '0',
  strReason varchar(100) DEFAULT NULL,
  intClearanceYear int(11) DEFAULT '0',
  dtReminder date DEFAULT NULL,
    strPersonType varchar(20) default '', /* player, coach, referee */
    strPersonSubType varchar(50) default '', /*?? or ID */
    strPersonLevel varchar(10) DEFAULT '', /* pro, amateur */
    strPersonEntityRole varchar(50) DEFAULT '', /* Referee, Head Coach, Delegate, Other */
    strSport varchar(20) default '',
    intOriginLevel TINYINT DEFAULT 0, /* Self, club, Reg, MA */
    strAgeLevel VARCHAR(100) default '',

  PRIMARY KEY (intClearanceID),
  KEY index_intPersonID (intPersonID),
  KEY index_intDestinationEntityID (intDestinationEntityID),
  KEY index_intSourceEntityID (intSourceEntityID),
  KEY index_intRealmID (intRealmID),
  KEY index_intClearanceStatus (intClearanceStatus),
  KEY index_intCurrentPathID (intCurrentPathID),
  KEY index_intClearanceYear (intClearanceYear),
  KEY index_FromYear (intCreatedFrom,intClearanceYear),
  KEY index_dtApplied (dtApplied)
) DEFAULT CHARSET=utf8;
