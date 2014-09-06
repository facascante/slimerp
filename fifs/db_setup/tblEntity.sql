DROP TABLE IF EXISTS tblEntity;
CREATE TABLE tblEntity (
  intEntityID int(11) NOT NULL AUTO_INCREMENT,
    intEntityLevel INT DEFAULT 0,
    intRealmID INT DEFAULT 0,
    intSubRealmID INT DEFAULT 0,
    intDataAccess   TINYINT NOT NULL DEFAULT 10,
    strEntityType VARCHAR(30) DEFAULT '', /* School, Club */
    strStatus VARCHAR(20) default '', /*ACTIVE, INACTIVE, PENDING, SUSPENDED, DESOLVED */
    intRealmApproved tinyint default 0,
    intCreatedByEntityID INT default 0,
    strFIFAID varchar(30) default '',

    strLocalName varchar(100) default '',
    strLocalShortName varchar(100) default '',
    strLocalFacilityName varchar(150) DEFAULT '',
    strLatinName    varchar(100) default '',
    strLatinShortName varchar(100) default '',
    strLatinFacilityName varchar(150) DEFAULT '',

    dtFrom date,
    dtTo date,
    strISOCountry varchar(10) default '',
    strRegion varchar(50) default '',
    strPostalCode varchar(15) DEFAULT '',
    strTown varchar(100) default '',
    strAddress varchar(200) default '',
    strWebURL varchar(200) default '',
    strEmail varchar(200) default '',
    strPhone varchar(20) DEFAULT '',
    strFax varchar(20) DEFAULT '',

    strContactTitle varchar(50) DEFAULT NULL,
    strContact  varchar(50) DEFAULT NULL,
    strContactEmail varchar(200) DEFAULT NULL,
    strContactPhone varchar(50) DEFAULT NULL,
    dtAdded datetime,
    tTimeStamp timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    /*Venue Entity Fields */
    intCapacity int(11) DEFAULT '0',
    intCoveredSeats int(11) DEFAULT '0',
    intUncoveredSeats int(11) DEFAULT '0',
    intCoveredStandingPlaces int(11) DEFAULT '0',
    intUncoveredStandingPlaces int(11) DEFAULT '0',
    intLightCapacity int(11) DEFAULT '0',
    strGroundNature varchar(100) DEFAULT '', /* Grass, Turf -- comma seperated ? */
    strDiscipline varchar(100) default '', /* list of sports -- comma seperated ? */
    strMapRef varchar(20) DEFAULT '',
    intMapNumber int(11) DEFAULT '0',
    dblLat double DEFAULT '0',
    dblLong double DEFAULT '0',
    strDescription text, 

    strPaymentNotificationAddress VARCHAR(250),
    strEntityPaymentBusinessNumber VARCHAR(100) DEFAULT '',
    strEntityPaymentInfo TEXT,
    intPaymentRequired TINYINT DEFAULT 0,
    intIsPaid TINYINT DEFAULT 0,
  PRIMARY KEY (`intEntityID`),
  KEY `index_intRealmID` (`intRealmID`),
  KEY `index_strFIFAID` (`strFIFAID`),
  KEY `index_intEntityLevel` (`intEntityLevel`)
) DEFAULT CHARSET=utf8;

