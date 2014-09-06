-- MySQL dump 10.13  Distrib 5.5.20, for Linux (x86_64)
--
-- Host: localhost    Database: prod_regoSWM_20140223
-- ------------------------------------------------------
-- Server version	5.5.20

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
-- Table structure for table `tblEntityTypes`
--

DROP TABLE IF EXISTS `tblEntityTypes`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `tblEntityTypes` (
  `intEntityTypeID` int(11) NOT NULL,
  `strEntityTypeName` varchar(255) NOT NULL,
  PRIMARY KEY (`intEntityTypeID`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `tblEntityTypes`
--

LOCK TABLES `tblEntityTypes` WRITE;
/*!40000 ALTER TABLE `tblEntityTypes` DISABLE KEYS */;
INSERT INTO `tblEntityTypes` VALUES (-50,'Event'),(-49,'Event Accred'),(-48,'Event Transort'),(-47,'Venue'),(-1,'None'),(1,'Member'),(2,'Team'),(3,'Club'),(4,'Comp'),(5,'Association'),(10,'Zone'),(20,'Region'),(30,'State'),(100,'National'),(110,'International Zone'),(200,'Internaltional'),(400,'Top');
/*!40000 ALTER TABLE `tblEntityTypes` ENABLE KEYS */;
UNLOCK TABLES;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

-- Dump completed on 2014-04-28 12:45:19
