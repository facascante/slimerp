ALTER TABLE tblTransactions
    ADD COLUMN intTXNEntityTypeID INT DEFAULT 0,
    ADD COLUMN intTXNEntityID INT DEFAULT 0,
    ADD INDEX index_TXNEntity (intTXNEntityTypeID, intTXNEntityID);
