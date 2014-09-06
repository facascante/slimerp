-- MySQL dump 10.9
--
-- Host: localhost    Database: SWMosep
-- ------------------------------------------------------
-- Server version	4.1.16

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8 */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;

--
-- Table structure for table `tblTransLog`
--

DROP TABLE IF EXISTS `tblTransLog`;
CREATE TABLE `tblTransLog` (
  `intLogID` int(11) NOT NULL auto_increment,
  `dtLog` datetime default NULL,
  `intAmount` decimal(16,2) default NULL,
  `strTXN` varchar(200) default NULL,
  `strResponseCode` varchar(10) default NULL,
  `strResponseText` varchar(100) default NULL,
  `strComments` text,
  `intPaymentType` int(11) default NULL,
  `strBSB` varchar(50) default NULL,
  `strBank` varchar(100) default NULL,
  `strAccountName` varchar(100) default NULL,
  `strAccountNum` varchar(100) default NULL,
  `intRealmID` int(11) default NULL,
  `intCurrencyID` int(11) default '0',
  `strReceiptRef` varchar(100) default NULL,
  `intStatus` tinyint(4) default '0',
  `intPartialPayment` tinyint(4) default '0',
tTimeStamp TIMESTAMP,
  PRIMARY KEY  (`intLogID`),
  KEY `index_realmID` (`intRealmID`),
  KEY `index_paymentType` (`intPaymentType`),
  KEY `intCurrencyID` (`intCurrencyID`),
  KEY `intStatus` (`intStatus`),
  KEY `intPartialPayment` (`intPartialPayment`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

