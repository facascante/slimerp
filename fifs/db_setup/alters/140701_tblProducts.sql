ALTER TABLE tblProducts DROP INDEX index_intAssocID;
ALTER TABLE tblProducts CHANGE intAssocID intEntityID INT DEFAULT 0;
ALTER TABLE tblProducts ADD INDEX index_intEntityID (intEntityID);
