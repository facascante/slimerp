drop table if exists tblRegoFormOrder;

CREATE table tblRegoFormOrder (
    intRegoFormOrderID INT NOT NULL AUTO_INCREMENT, 
    intRegoFormID      INT NOT NULL DEFAULT 0,
    intEntityTypeID    TINYINT UNSIGNED NOT NULL DEFAULT 0,
    intEntityID        INT NOT NULL DEFAULT 0,
    intDisplayOrder    INT DEFAULT 0,
    intSource          TINYINT UNSIGNED NOT NULL DEFAULT '1' COMMENT '1=>node & normal form fields, 2=>linked, 3=>added (tblRegoFormFieldsAdded), 4=block (tblRegoFormBlock)',
    intFieldID         INT NOT NULL DEFAULT 0 COMMENT 'intSource will indicate where from',
    tTimestamp         TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    PRIMARY KEY (intRegoFormOrderID),
    KEY index_regoFormEntityTypeEntity (intRegoFormID, intEntityTypeID, intEntityID),
    UNIQUE KEY index_regoFormEntityTypeEntitySourceField (intRegoFormID, intEntityTypeID, intEntityID, intSource, intFieldID)
);
