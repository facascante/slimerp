ALTER TABLE tblRealms ADD COLUMN intBusinessUnitType Int(11) NOT NULL DEFAULT 1;
ALTER TABLE tblRealmSubTypes ADD COLUMN intBusinessUnitType Int(11) NOT NULL DEFAULT 1;

UPDATE tblRealms SET intBusinessUnitType = 2 WHERE intRealmID IN (54,57,60,64);
UPDATE tblRealmSubTypes SET intBusinessUnitType = 2 WHERE intRealmID IN (54,57,60,64);

UPDATE tblRealmSubTypes SET intBusinessUnitType = 2 WHERE intRealmID = 13 AND intSubTypeID NOT IN (6,23,40);