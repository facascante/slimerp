CREATE TABLE tblProductPriceRange (
    intProductPriceRangeID  INT NOT NULL AUTO_INCREMENT,
    intProductID            INT NOT NULL,
    curAmountMin       decimal(12,2) DEFAULT 0.00,
    curAmountMax       decimal(12,2) DEFAULT 0.00,

    PRIMARY KEY (intProductPriceRangeID),
    UNIQUE KEY index_product_id (intProductID)

);


