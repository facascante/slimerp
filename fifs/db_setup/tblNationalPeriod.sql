DROP TABLE IF EXISTS tblNationalPeriod;
CREATE TABLE tblNationalPeriod (
  intNationalPeriodID INT NOT NULL AUTO_INCREMENT,
  strNationalPeriodName VARCHAR(100),
  strSport VARCHAR(20) DEFAULT '',
  intRealmID INT,
  intSubRealmID INT,
  dtFrom DATE,
  dtTo DATE,
  PRIMARY KEY (intNationalPeriodID),
  KEY index_intRealm(intRealmID, intSubRealmID, strSport)
);
