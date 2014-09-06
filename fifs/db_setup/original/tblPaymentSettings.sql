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
-- Table structure for table `tblTransactions`
--

DROP TABLE IF EXISTS `tblTransactions`;
CREATE TABLE `tblTransactions` (
  `intTransactionID` int(11) NOT NULL auto_increment,
  `intStatus` tinyint(4) default '0',
  `strNotes` text,
  `curAmount` decimal(12,2) default NULL,
  `intQty` int(11) default '0',
  `dtTransaction` datetime default NULL,
  `dtPaid` datetime default NULL,
  `tLastUpdated` timestamp NOT NULL default CURRENT_TIMESTAMP on update CURRENT_TIMESTAMP,
  `intDelivered` tinyint(11) default '0',
  `intMemberID` int(11) default '0',
  `intAssocID` int(11) default '0',
  `intRealmID` int(11) default '0',
  `intID` int(11) default '0',
  `intTableType` tinyint(4) default '0',
  `intPaymentType` int(11) default '0',
  `strReceiptRef` varchar(100) default NULL,
  `intProductID` int(11) default NULL,
  `intTransLogID` int(11) default '0',
  `intCurrencyID` int(11) default '0',
  `intTempLogID` int(11) default '0',
  PRIMARY KEY  (`intTransactionID`),
  KEY `index_intStatus` (`intStatus`),
  KEY `index_intMemberID` (`intMemberID`),
  KEY `index_intAssocID` (`intAssocID`),
  KEY `transLogID` (`intTransLogID`),
  KEY `paymentType` (`intPaymentType`),
  KEY `intRealmID` (`intRealmID`),
  KEY `intID` (`intID`),
  KEY `intTableType` (`intTableType`),
  KEY `intProductID` (`intProductID`),
  KEY `intCurrencyID` (`intCurrencyID`),
  KEY `intTempLogID` (`intTempLogID`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

