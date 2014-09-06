-- MySQL dump 10.13  Distrib 5.5.37, for debian-linux-gnu (x86_64)
--
-- Host: localhost    Database: fifasponline
-- ------------------------------------------------------
-- Server version	5.5.37-0ubuntu0.14.04.1-log

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;

--
-- Table structure for table `tblRegoForm`
--

DROP TABLE IF EXISTS `tblRegoForm`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `tblRegoForm` (
  `intRegoFormID` int(11) NOT NULL AUTO_INCREMENT,
  `intAssocID` int(11) NOT NULL DEFAULT '0',
  `intRealmID` int(11) NOT NULL DEFAULT '0',
  `intSubRealmID` int(11) NOT NULL DEFAULT '0',
  `intClubID` int(11) DEFAULT NULL,
  `strRegoFormName` text,
  `intRegoType` int(11) NOT NULL DEFAULT '0',
  `intRegoTypeLevel` int(11) DEFAULT '0',
  `intNewRegosAllowed` int(11) NOT NULL DEFAULT '0',
  `ynPlayer` char(1) DEFAULT NULL,
  `ynCoach` char(1) DEFAULT NULL,
  `ynMatchOfficial` char(1) DEFAULT NULL,
  `ynOfficial` char(1) DEFAULT NULL,
  `ynMisc` char(1) DEFAULT NULL,
  `intStatus` tinyint(4) DEFAULT '1',
  `intLinkedFormID` int(11) DEFAULT '0',
  `intAllowMultipleAdult` tinyint(4) DEFAULT '0',
  `intAllowMultipleChild` tinyint(4) DEFAULT '0',
  `intPreventTypeChange` tinyint(4) DEFAULT '0',
  `intAllowClubSelection` tinyint(4) DEFAULT '0',
  `intClubMandatory` tinyint(4) DEFAULT '0',
  `dtCreated` datetime DEFAULT NULL,
  `tTimeStamp` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `intTemplate` tinyint(4) DEFAULT '0',
  `intTemplateLevel` tinyint(4) DEFAULT '0',
  `intTemplateSourceID` int(11) DEFAULT '0',
  `intTemplateAssocID` int(11) DEFAULT '0',
  `intTemplateEntityID` int(11) DEFAULT '0',
  `dtTemplateExpiry` datetime DEFAULT NULL,
  `strTitle` varchar(100) DEFAULT '',
  `ynOther1` char(1) DEFAULT 'N',
  `ynOther2` char(1) DEFAULT 'N',
  `intNewBits` smallint(6) DEFAULT NULL,
  `intRenewalBits` smallint(6) DEFAULT NULL,
  `intPaymentBits` smallint(6) DEFAULT NULL,
  `intPaymentCompulsory` tinyint(4) DEFAULT '0',
  `intCreatedLevel` tinyint(3) unsigned DEFAULT '0',
  `intParentBodyFormID` int(11) DEFAULT '0',
  `intCreatedID` int(3) DEFAULT '0',
  PRIMARY KEY (`intRegoFormID`),
  KEY `index_intAssocID` (`intAssocID`),
  KEY `index_intClubID` (`intClubID`),
  KEY `index_intRegoType` (`intRegoType`)
) ENGINE=MyISAM AUTO_INCREMENT=36491 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

-- Dump completed on 2014-07-09 11:43:44
