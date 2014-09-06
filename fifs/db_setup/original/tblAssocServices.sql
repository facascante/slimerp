-- MySQL dump 10.8
--
-- Host: localhost    Database: regoNew
-- ------------------------------------------------------
-- Server version	4.1.7-standard-log

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8 */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE="NO_AUTO_VALUE_ON_ZERO" */;

--
-- Table structure for table `tblAssocServices`
--

DROP TABLE IF EXISTS `tblAssocServices`;
CREATE TABLE `tblAssocServices` (
  `intAssocServicesID` int(11) NOT NULL auto_increment,
  `intAssocID` int(11) NOT NULL default '0',
  `strContact1Name` varchar(100) default NULL,
  `strContact1Title` varchar(50) default NULL,
  `strContact1Phone` varchar(50) default NULL,
  `strContact2Name` varchar(100) default NULL,
  `strContact2Title` varchar(50) default NULL,
  `strContact2Phone` varchar(50) default NULL,
  `strVenueName` varchar(100) default NULL,
  `strVenueAddress` varchar(100) default NULL,
  `strVenueSuburb` varchar(100) default NULL,
  `strVenueState` varchar(50) default NULL,
  `strVenueCountry` varchar(60) default NULL,
  `strVenuePostalCode` varchar(15) default NULL,
  `intMon` tinyint(4) default NULL,
  `intTue` tinyint(4) default NULL,
  `intWed` tinyint(4) default NULL,
  `intThu` tinyint(4) default NULL,
  `intFri` tinyint(4) default NULL,
  `intSat` tinyint(4) default NULL,
  `intSun` tinyint(4) default NULL,
  `strSessionDurations` varchar(100) default NULL,
  `strTimes` varchar(100) default NULL,
  `dtStart` date default NULL,
  `dtFinish` date default NULL,
  `strEmail` varchar(255) default NULL,
  `strFax` varchar(20) default NULL,
  `strVenueAddress2` varchar(100) default NULL,
	tTimeStamp TIMESTAMP,
  PRIMARY KEY  (`intAssocServicesID`),
  KEY `intAssocID` (`intAssocID`),
);

